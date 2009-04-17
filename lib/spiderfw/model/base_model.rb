require 'spiderfw/model/element'
require 'iconv'

module Spider; module Model
    
    
    class BaseModel
        include Spider::Logger
        include DataTypes
        
        attr_accessor :_parent, :_parent_element
        attr_reader :model, :loaded_elements
        
        class <<self
            attr_reader :attributes, :elements_order, :integrated_models, :extended_models, :polymorphic_models, :sequences
        end
        
        
        
        # Copies this class' elements to the subclass.
        def self.inherited(subclass)
            # FIXME: might need to clone every element
            @subclasses ||= []
            @subclasses << subclass
            subclass.instance_variable_set("@elements", @elements.clone) if @elements
            subclass.instance_variable_set("@elements_order", @elements_order.clone) if @elements_order
            subclass.instance_variable_set("@mapper_procs_subclass", @mapper_procs_subclass.clone) if @mapper_procs_subclass
            subclass.instance_variable_set("@mapper_modules", @mapper_modules.clone) if @mapper_modules
        end
        
        def self.app
            return @app if @app
            app = self
            while (!app.include?(Spider::App))
                app = app.parent_module
            end
            @app = app
        end
        
        #######################################
        #   Model definition methods          #
        #######################################
        
        # Defines an element belonging to the model.
        def self.element(name, type, attributes={}, &proc)
            @elements ||= {}
            @elements_order ||= []
            if type.class == Class
                default_attributes = case type.name
                when 'String'
                    {:length => 255}
                else
                    {}
                end
            else
                default_attributes = {}
            end
            attributes = default_attributes.merge(attributes)
            # if (type.class == Class && Model.base_type(type)) 
            #                 type = Model.base_type(type)
            #             els
            if (type.class == Hash)
                type = create_inline_model(name, type)
                attributes[:inline] = true
            end
            if (attributes[:integrated_from])
                if (attributes[:integrated_from].class == String)
                    parts = attributes[:integrated_from].split('.')
                    attributes[:integrated_from] = @elements[parts[0].to_sym]
                    attributes[:integrated_from_element] = parts[1].to_sym if parts[1]
                end
                if (!attributes[:integrated_from_element])
                    attributes[:integrated_from_element] = name
                end
            end


            orig_type = type
            assoc_type = nil
            if (attributes[:multiple] && (!attributes[:add_reverse]) && (!attributes[:reverse] || \
                # FIXME! the first check is needed when the referenced class has not been parsed yet 
                # but now it assumes that the reverse is not multiple if it is not defined
                (!type.elements[attributes[:reverse]] || type.elements[attributes[:reverse]].multiple?)))
                if (attributes[:through])
                    assoc_type = attributes[:through]
                else
                    attributes[:anonymous_model] = true
                    attributes[:owned] = true unless attributes[:owned] != nil
                    first_model = self.first_definer(name)
                    assoc_type_name = Spider::Inflector.camelize(name)
                    create_junction = true
                    if (first_model.const_defined?(assoc_type_name) )
                        assoc_type = first_model.const_get(assoc_type_name)
                        if (!assoc_type.attributes[:sub_model]) # other kind of inline model
                            assoc_type_name += 'Junction'
                            create_junction = false if (first_model.const_defined?(assoc_type_name))
                        else
                            create_junction = false
                        end
                    end
                    attributes[:junction] = true
                    attributes[:junction_id] ||= :id
                    self_name = first_model.short_name.gsub('/', '_').downcase.to_sym
                    attributes[:reverse] = self_name
                    other_name = Spider::Inflector.underscore(orig_type.short_name == self.short_name ? orig_type.name : orig_type.short_name).gsub('/', '_').downcase.to_sym
                    other_name = :"#{other_name}_ref" if (orig_type.elements[other_name])
                    attributes[:junction_their_element] = other_name
                    if (create_junction)
                        assoc_type = first_model.const_set(assoc_type_name, Class.new(BaseModel)) # FIXME: maybe should extend self, not the type
                        assoc_type.attributes[:sub_model] = self
                        assoc_type.element(attributes[:junction_id], Fixnum, :primary_key => true, :autoincrement => true, :hidden => true)
                        assoc_type.element(self_name, self, :hidden => true, :reverse => name) # FIXME: must check if reverse exists?
                        # FIXME! fix in case of clashes with existent elements
                        assoc_type.element(other_name, orig_type)
                        assoc_type.integrate(other_name, :hidden => true, :no_pks => true) # FIXME: in some cases we want the integrated elements
                        if (proc)                                   #        to be hidden, but the integrated el instead
                            attributes[:extended] = true
                            attributes[:keep_junction] = true
                            assoc_type.class_eval(&proc)
                        end
                    end
                    attributes[:association_type] = assoc_type
                end
                through_model = type
            end
            rev_model = assoc_type ? assoc_type : self
            if (attributes[:add_reverse])
                unless (orig_type.elements[attributes[:add_reverse]])
                    attributes[:reverse] ||= attributes[:add_reverse]
                    orig_type.element(attributes[:add_reverse], rev_model, :reverse => name, :added_reverse => true, 
                        :delete_cascade => attributes[:reverse_delete_cascade])
                end
            elsif (attributes[:add_multiple_reverse])
                unless (orig_type.elements[attributes[:add_reverse]])
                    attributes[:reverse] ||= attributes[:add_multiple_reverse]
                    orig_type.element(attributes[:add_multiple_reverse], rev_model, :reverse => name, :multiple => true, 
                        :added_reverse => true, :delete_cascade => attributes[:reverse_delete_cascade])
                end
            end
            if (attributes[:lazy] == nil)
                if (type.subclass_of?(BaseModel) && attributes[:multiple])
                    # FIXME: we can load eagerly single relations if we can do a join
                    attributes[:lazy] = true
                else
                    attributes[:lazy] = :default
                end
            end
            
            @elements[name] = Element.new(name, type, attributes)
            
            if (attributes[:element_position])
                @elements_order.insert(attributes[:element_position], name)
            else
                @elements_order << name
            end
            
            # class element getter
            unless respond_to?(name)
                (class << self; self; end).instance_eval do
                    define_method("#{name}") do
                        @elements[name]
                    end
                end
            end
            
            ivar = :"@#{ name }"

            #instance variable getter
            define_method(name) do
                element = self.class.elements[name]
                if (element.integrated?)
                    integrated = get(element.integrated_from.name)
                    return integrated.send(element.integrated_from_element) if integrated
                    return nil
                end
                if element_has_value?(name) || element_loaded?(name)
                    val = instance_variable_get(ivar) 
                    val.set_parent(self, name) if val && element.model?
                    return val
                end

#                Spider.logger.debug("Element not loaded #{name} (i'm #{self.class} #{self.object_id})")
                if autoload? && primary_keys_set?
                    mapper.load_element(self, self.class.elements[name])
                    val = instance_variable_get(ivar)
                    prepare_value(name, val)
                elsif (element.model?)
                    val = instance_variable_set(ivar, instantiate_element(name))
                end
                val.set_parent(self, name) if element.model? && val
                return val
            end

            #instance_variable_setter
            define_method("#{name}=") do |val|
                element = self.class.elements[name]
                #@_autoload = false unless element.primary_key?
                if (element.integrated?)
                    integrated_obj = get(element.integrated_from)
                    unless integrated_obj
                        integrated_obj = instantiate_element(element.integrated_from.name)
                        set(element.integrated_from, integrated_obj)
                    end
                    #integrated_obj.autoload = false
                    res = integrated_obj.send("#{element.integrated_from_element}=", val)
                    @modified_elements[name] = true unless element.primary_key?
                    return res
                end
                if (val && element.model?)
                    if (element.multiple?)
                        unless (val.is_a?(QuerySet))
                            qs = instantiate_element(name)
                            if (val.is_a?(Enumerable))
                                val.each do |row|
                                    row = element.type.new(row) unless row.is_a?(BaseModel)
                                    qs << row
                                end
                            else
                                qs << val
                            end
                            val = qs
                        end
                    else
                        val = element.model.new(val) unless val.is_a?(BaseModel)
                    end
                end
                val = prepare_child(element.name, val)
                old_val = instance_variable_get(ivar)
                check(name, val)
                @modified_elements[name] = true unless element.primary_key?
                instance_variable_set(ivar, val)
                notify_observers(name, old_val)
                #extend_element(name)
            end
            
            if (attributes[:integrate])
                integrate(name, attributes[:integrate])
            end
            if (@subclasses)
                @subclasses.each do |sub|
                    sub.elements[name] = @elements[name].clone
                    sub.elements_order << name
                end
            end
            return @elements[name]

        end
        
        def self.remove_element(el)
            el = el.name if el.is_a?(Element)
            @elements.delete(el)
            @elements_order.delete(el)
        end
            
        
        def self.integrate(element_name, params={})
            params ||= {}
            elements[element_name].attributes[:integrated_model] = true
            model = elements[element_name].model
            self.attributes[:integrated_models] ||= {}
            self.attributes[:integrated_models][model] = element_name
            params[:except] ||= []
            model.each_element do |el|
                next if params[:except].include?(el.name)
                next if elements[el.name] # don't overwrite existing elements
                attributes = el.attributes.clone.merge({
                    :integrated_from => elements[element_name]
                })
                attributes[:hidden] = params[:hidden] unless (params[:hidden].nil?)
                if (add_rev = attributes[:add_reverse] || attributes[:add_multiple_reverse])
                    attributes[:reverse] = add_rev
                    attributes.delete(:add_reverse)
                    attributes.delete(:add_multiple_reverse)
                end
                attributes.delete(:primary_key) unless (params[:keep_pks])
                element(el.name, el.type, attributes)
            end
        end
        
        def self.element_attributes(element_name, attributes)
            elements[element_name].attributes.merge!(attributes)
        end
        
        def self.many(name, type, attributes={}, &proc)
            attributes[:multiple] = true
            attributes[:association] ||= :many
            element(name, type, attributes, &proc)
        end
                
        def self.choice(name, type, attributes={}, &proc)
            attributes[:association] = :choice
            element(name, type, attributes, &proc)
        end
        
        def self.multiple_choice(name, type, attributes={}, &proc)
            attributes[:association] = :multiple_choice
            many(name, type, attributes, &proc)
        end
        
        
        # Saves the element definition and evals it when first needed, avoiding problems with classes not
        # available yet when the model is defined.
        def self.define_elements(&proc)
            @elements_definition = proc
        end
        
        def self.create_inline_model(name, hash)
            model = self.const_set(Spider::Inflector.camelize(name), Class.new(InlineModel))
            model.instance_eval do
                hash.each do |key, val|
                    element(:id, key.class, :primary_key => true)
                    if (val.class == Hash)
                        # TODO: allow passing of multiple values like {:element1 => 'el1', :element2 => 'el2'}
                    else
                        element(:desc, val.class)
                    end
                    break
                end
            end
            model.data = hash
            return model
        end
        
        def self.submodels
            elements.select{ |name, el| el.model? }.map{ |name, el| el.model }
        end
        
        def self.extend_model(model, params={})
            if (model == superclass) # first undo table per class inheritance
                @elements = {}
                @elements_order = []
            end
            primary_keys.each{ |k| remove_element(k) } if (params[:replace_pks]) 
            unless (params[:no_local_pk] || !elements_array.select{ |el| el.attributes[:local_pk] }.empty?)
                # FIXME: check if :id is already defined
                element(:id, Fixnum, :autoincrement => true, :local_pk => true)
            end
            integrated_name = params[:name]
            if (!integrated_name)
                integrated_name = (self.parent_module == model.parent_module) ? model.short_name : model.name
                integrated_name = Spider::Inflector.underscore(integrated_name).gsub('/', '_')
            end
            integrated_name = integrated_name.to_sym
            @extended_models ||= {}
            @extended_models[model] = integrated_name
            attributes = {}
            attributes[:hidden] = true unless (params[:hide_integrated] == false)
            attributes[:delete_cascade] = params[:delete_cascade]
            integrated = element(integrated_name, model, attributes)
            integrate(integrated_name, :keep_pks => true)
            if (params[:add_polymorphic])
                model.polymorphic(self, :through => integrated_name)
            end
        end
        
        def self.inherit_storage
            self.attributes[:inherit_storage] = true
            (class << self; self; end).instance_eval do
                define_method(:storage) do
                    superclass.storage
                end
            end
        end
        
        def self.condition(condition)
            self.attributes[:condition] = condition
        end
            
        
        def self.group(name, &proc)
            proxy = Class.new(ProxyModel).proxy(name.to_s+'_', self)
            proxy.instance_eval(&proc)
            proxy.each_element do |el|
                element(name.to_s+'_'+el.name.to_s, el.type, el.attributes.clone)
            end
            define_method(name) do
                @proxies ||= {}
                return @proxies[name] ||= proxy.new
            end
            
        end
        
        def self.polymorphic(model, options)
            through = options[:through] || Spider::Inflector.underscore(self.name).gsub('/', '_')
            through = through.to_sym
            @polymorphic_models ||= {}
            @polymorphic_models[model] = {:through => through}
        end

        def self.attributes(val=nil)
            @attributes ||= {}
            if (val)
                @attributes.merge!(val)
            end
            @attributes
        end
        
        def self.attribute(name, value)
            @attributes ||= {}
            @attributes[name] = value
        end
        
        def self.sequence(name)
            @sequences ||= []
            @sequences << name
        end
        
        def self.sequences
            @sequences ||= []
        end
        
        #####################################################
        #   Methods returning information about the model   #
        #####################################################
        
        def self.short_name
            return self.name.match(/([^:]+)$/)[1]
        end
        
        def self.managed?
            return false
        end
        
        def self.to_s
            self.name
        end
        
        def self.label(sing=nil, plur=nil)
            @label = sing if sing
            @label_plural = plur if plur
            @label || self.name
        end
        
        def self.label_plural(val=nil)
            @label_plural = val if (val)
            @label_plural || self.name
        end
        
        ########################################################
        #   Methods returning information about the elements   #
        ########################################################

        def self.ensure_elements_eval
            if @elements_definition
                instance_eval(&@elements_definition)
                @elements_definition = nil
            end
        end
        
        def self.elements
            ensure_elements_eval
            return @elements
        end
        
        def self.elements_array
            ensure_elements_eval
            @elements_order.map{ |key| @elements[key] }
        end

        
        def self.each_element
            ensure_elements_eval
            @elements_order.each do |name|
                yield elements[name]
            end
        end
        
        def self.has_element?(name)
            return elements[name] ? true : false
        end
        
        def self.primary_keys
            elements.values.select{|el| el.attributes[:primary_key]}
        end
        
        def self.first_definer(element_name)
            if (self.superclass.elements && self.superclass.elements[element_name])
                return self.superclass.first_definer(element_name)
            end
            if (self.attributes[:integrated_models])
                self.attributes[:integrated_models].keys.each do |mod|
                    return mod.first_definer(element_name) if (mod.elements[element_name])
                end
            end
            return self
        end
        
        ##############################################################
        #   Storage, mapper and loading (Class methods)       #
        ##############################################################
        
        def self.mapper_include(mod)
            @mapper_modules ||= []
            @mapper_modules << mod
        end
        
        def self.with_mapper(*params, &proc)
            @mapper_procs ||= []
            @mapper_procs << proc
        end
        
        def self.with_mapper_subclasses(*params, &proc)
            @mapper_procs_subclass ||= []
            @mapper_procs_subclass << proc
        end
        
        def self.with_mapper_for(*params, &proc)
            @mapper_procs ||= []
            @mapper_procs << proc
        end
        
        def self.use_storage(name=nil)
            @use_storage = name if name
            @use_storage
        end
        
        def self.storage
            return @storage if @storage
            if (!@use_storage && self.attributes[:sub_model])
                @use_storage = self.attributes[:sub_model].use_storage
            end
            return @use_storage ? get_storage(@use_storage) : get_storage
        end
        
        # Mixin!
        def self.get_storage(storage_string='default')
            storage_regexp = /([\w\d]+?):(.+)/
            if (storage_string !~ storage_regexp)
                orig_string = storage_string
                storage_conf = Spider.conf.get('storages')[storage_string]
                storage_string = storage_conf['url'] if storage_conf
                if (!storage_string || storage_string !~ storage_regexp)
                    raise ModelException, "No storage '#{orig_string}' found"
                end
            end
            type, url = $1, $2
            storage = Storage.get_storage(type, url)
            storage.configure(storage_conf) if storage_conf
            return storage
        end
         
        def self.mapper
            return @mapper if @mapper
            return @mapper = get_mapper(storage)
        end

        def self.get_mapper(storage)
#            map_class = self.attributes[:inherit_storage] ? superclass : self
            mapper = storage.get_mapper(self)
            if (@mapper_modules)
                @mapper_modules.each{ |mod| mapper.extend(mod) }
            end
            if (@mapper_procs)
                @mapper_procs.each{ |proc| mapper.instance_eval(&proc) }
            end
            if (@mapper_procs_subclass)
                @mapper_procs_subclass.each{ |proc| mapper.instance_eval(&proc) }
            end
            return mapper
        end

        # Finds objects according to query. Returns a QuerySet.
        # Accepts a Query, or a Condition and a Request (optional)
        def self.find(*params)
            if (params[0] && params[0].is_a?(Query))
                query = params[0]
            else
                condition = Condition.and(params[0])
                request = Request.new(params[1])
                query = Query.new(condition, request)
            end
            return QuerySet.new(self, query)
        end
        
        def self.all
            return self.find
        end
        
        def self.where(&proc)
            qs = QuerySet.new(self)
            qs.where(&proc)
            return qs
        end
        
        def self.load(*params)
            res = find(*params)
            return res[0]
        end
        
        def self.free_query_condition(q)
            c = Condition.or
            self.elements_array.each do |el|
                if (el.type == String || el.type == Text)
                    c.set(el.name, 'ilike', '%'+q+'%')
                end
            end
            return c
        end
        
        def self.count(condition=nil)
            mapper.count(condition)
        end
        
        
        #################################################
        #   Instance methods                            #
        #################################################

        def initialize(values=nil)
            @_autoload = true
            @_has_values = false
            @loaded_elements = {}
            @modified_elements = {}
            @value_observers = {}
            @all_values_observers = []
            @_extra = {}
            @model = self.class
            @all_values_observers << Proc.new do |element, old_value|
                @_has_values = true
                Spider::Model.unit_of_work.add(self) if (Spider::Model.unit_of_work)
            end
            if (values)
                if (values.is_a? Hash)
                    values.each do |key, val|
                        set(key, val)
                    end
                elsif (values.is_a? BaseModel)
                    values.each_val do |name, val|
                        set(name, val) if self.class.has_element?(name)
                    end
                 # Single unset key, single value
                elsif ((empty_keys = self.class.primary_keys.select{ |key| !element_has_value?(key) }).length == 1)
                    set(empty_keys[0], values)
                end
            end
        end
        
        def identity_mapper
            return Spider::Model.identity_mapper if Spider::Model.identity_mapper
            @identity_mapper ||= IdentityMapper.new
        end
        
        def identity_mapper=(im)
            @identity_mapper = im
        end
        
        def instantiate_element(name)
            element = self.class.elements[name]
            if (element.model?)
                if (element.multiple?)
                    val = QuerySet.new(element.model)
                else
                    val = element.type.new
                end
                val.autoload = autoload?
            end       
            return prepare_child(name, val)
        end
        
        def prepare_child(name, obj)
            return obj if obj.nil?
            element = self.class.elements[name]
            if (element.model?)
                # convert between junction and real type if needed
                if (obj.is_a?(QuerySet) && element.attributes[:junction])
                    obj.no_autoload do
                        if (element.attributes[:keep_junction] && obj.model == element.type)
                            qs = QuerySet.new(element.model)
                            obj.each{ |el_obj| 
                                qs << {element.reverse => self, element.attributes[:junction_their_element] => el_obj}
                            }
                            obj = qs
                        elsif (!element.attributes[:keep_junction] && obj.model == element.model)
                            qs = QuerySet.new(element.type, obj.map{ |el_obj| el_obj.get(element.attributes[:junction_their_element])})
                            obj = qs
                        end 
                    end
                end
                obj.identity_mapper = self.identity_mapper
                # FIXME: cleanup the single reverse thing, doesn't have much sense now with junctions
                # if (element.has_single_reverse? && (!element.attributes[:junction] || element.attributes[:keep_junction]))
                #                     obj.no_autoload do
                #                         obj.set(element.attributes[:reverse], self) unless obj.get(element.attributes[:reverse]) == self
                #                     end
                #                 end
                if (element.attributes[:junction] && element.attributes[:keep_junction])
                    obj.append_element = element.attributes[:junction_their_element]
                end
                if (element.attributes[:set] && element.attributes[:set].is_a?(Hash))
                    element.attributes[:set].each{ |k, v| obj.set(k, v) }
                end
            else
                obj = prepare_value(element, obj)
            end
            return obj
        end
        
        def all_children(path)
            children = []
            no_autoload do
                el = path.shift
                if element_has_value?(el) && children = get(el)
                    if path.length >= 1
                        children = children.all_children(path)
                    end
                end
            end
            return children
        end
        
        def set_parent(obj, element)
            @_parent = obj
            @_parent_element = element
        end
        
        
        #################################################
        #   Get and set                                 #
        #################################################
        
        def get(element)
            element = element.name if (element.class == Spider::Model::Element)
            first, rest = element.to_s.split('.', 2)
            if (rest)
                return nil unless element_has_value?(first.to_sym)
                return send(first).get(rest)
            end
            return send(element)
        end
        
        def get_no_load(element)
            res = nil
            no_autoload do
                res = get(element)
            end
            return res
        end

        def set(element, value)
            element = element.name if (element.class == Element)
            first, rest = element.to_s.split('.', 2)
            return send(first).set(rest) if (rest)
            return send("#{element}=", value)
        end
        
        def [](element)
            element = element.name if element.is_a?(Element)
            if (self.class.elements[element])
                get(element)
            else
                @_extra[element]
            end
        end
        
        def []=(element, value)
            element = element.name if element.is_a?(Element)
            if (self.class.elements[element])
                set(element, value)
            else
                @_extra[element] = value
            end
        end
            
        
        def set_hash(hash)
            hash.each { |key, val| set(key, val) }
        end
        
        def prepare_value(element, value)
            element = self.class.elements[element] unless element.is_a?(Element)
            if (element.type.subclass_of?(Spider::DataType))
                value = element.type.new(value) unless value.is_a?(element.type)
                element.type.take_attributes.each do |a|
                    value.attributes[a] = element.attributes[a]
                end
            else
                case element.type.name
                when 'DateTime'
                    value = DateTime.parse(value) if value.is_a?(String)
                when 'String'
                when 'Spider::DataTypes::Text'
                    value = value.to_s
                end
            end
            value
        end
        
        # Sets a value without calling the associated setter; used by the mapper
        def set_loaded_value(element, value)
            element_name = element.is_a?(Element) ? element.name : element
            element = self.class.elements[element_name]
            if (element.integrated?)
                get(element.integrated_from).set_loaded_value(element.integrated_from_element, value)
            else
                value = prepare_child(element.name, value) if element.model?
                instance_variable_set("@#{element_name}", value)
            end
            value.loaded = true if (value.is_a?(QuerySet))
            element_loaded(element_name)
            @modified_elements[element_name] = false
        end
        
        def element_loaded(element_name)
            element_name = element_name.name if (element_name.class == Element)
            @loaded_elements[element_name] = true
            if (@_parent && @_parent.is_a?(QuerySet))
                @_parent.element_loaded(element_name)
            end
        end
        
        def element_loaded?(element)
            element = element.name if (element.class == Element)
            return @loaded_elements[element]
        end        

        
        def check(name, val)
            element = self.class.elements[name]
            element.type.check(val) if (element.type.respond_to?(:check))
            if (checks = element.attributes[:check])
                checks = {(_("%s is not in the correct format") % element.label) => checks} unless checks.is_a?(Hash)
                checks.each do |msg, check|
                    test = case check
                    when Regexp
                        val == nil || val.empty? ? true : check.match(val)
                    when Proc
                        Proc.call(msg)
                    end
                    raise FormatError.new(element, msg) unless test
                end
            end
        end
        
        def polymorphic_become(model)
            raise ModelException, "#{self.class} is not polymorphic for #{model}" unless self.class.polymorphic_models[model]
            obj = model.new
            obj.set(self.class.polymorphic_models[model][:through], self)
            return obj
        end
        
        def subclass(model)
            obj = model.new
            elements_array.each do |el|
                obj.set(el, self.get(el)) if element_has_value?(el)
            end
            return obj
        end
            
        def autoload?
            @_autoload
        end
        
        def autoload=(bool)
            autoload(bool, false)
        end
        
        def autoload(bool, traverse=true)
            return if @_tmp_autoload_walk
            @_tmp_autoload_walk = true
            @_autoload = bool
            if (traverse)
                self.class.elements_array.select{ |el| el.model? && element_has_value?(el.name)}.each do |el|
                    val = get(el)
                    val.autoload = bool if val.respond_to?(:autoload=)
                end
            end
            @_tmp_autoload_walk = nil
        end
        
        def no_autoload
            prev_autoload = autoload?
            self.autoload = false
            yield
            self.autoload = prev_autoload
        end
        
        ##############################################################
        #   Methods for getting information about element values     #
        ##############################################################
        
        def ==(other)
            return false unless other
            self.class.primary_keys.each do |k|
                return false unless get(k) == other.get(k)
            end
            return true
        end
        
        ##############################################################
        #   Iterators                                                #
        ##############################################################
        
        def each
            self.class.elements.each do |name, el|
                yield name, get(name)
            end
        end

        def each_val
            self.class.elements.select{ |name, el| element_has_value?(name) }.each do |name, el|
                yield name, get(name)
            end
        end
        
        def primary_keys
            self.class.primary_keys.map{ |k| get(k) }
        end

            
        
        # Returns true if the element instance variable is set
        #--
        # FIXME: should probably try to get away without this method
        # it is the only method that relies on the mapper
        def element_has_value?(element)
            element_name = (element.is_a?(Element)) ? element.name : element
            element = self.class.elements[element_name]
            if (element.integrated?)
                return false unless obj = instance_variable_get(:"@#{element.integrated_from.name}")
                return obj.element_has_value?(element.integrated_from_element)
            end
            if (element.attributes[:computed_from])
                element.attributes[:computed_from].each{ |el| return false unless element_has_value?(el) }
                return true
            end
            if (!mapper.mapped?(element))
                return send("#{element_name}?") if (respond_to?("#{element_name}?"))
                return get(element) == nil ? false : true if (!mapper.mapped?(element))
            end
            return instance_variable_get(:"@#{element_name}") == nil ? false : true
        end

        
        def element_modified?(element)
            element = element.is_a?(Element) ? element : self.class.elements[element]
            set_mod = @modified_elements[element.name]
            return set_mod if set_mod
            if (element.integrated?)
                return element_modified?(element) unless integrated = get_no_load(element.integrated_from)
                return integrated.element_modified?(element.integrated_from_element)
            end
            if element_has_value?(element) && (val = get(element)).respond_to?(:modified?)
                return val.modified?
            end
            return false
        end
        
        def elements_modified?(*elements)
            elements.each{ |el| return true if element_modified?(el) }
            return false
        end
        
        def modified?
            return true unless @modified_elements.reject{ |key, val| !val }.empty?
            self.class.elements_array.select{ |el| 
                !el.model? && element_has_value?(el) && el.type.is_a?(Spider::DataType)
            }.each do |el|
                return true if get(el).modified?
            end
            return false
        end
        
        def set_modified(request)
            request.each do |key, val| # FIXME: go deep
                @modified_elements[key] = true
            end
        end
        
        def reset_modified_elements
            @modified_elements = {}
        end
        
        # Returns true if all primary keys have a value; false if some primary key
        # is not set or the model has no primary key
        def primary_keys_set?
            primary_keys = self.class.primary_keys
            return false unless primary_keys.length > 0
            primary_keys.each do |el|
                if (el.integrated?)
                    return false unless (int_obj = instance_variable_get(:"@#{el.integrated_from.name}"))
                    #return false unless int_obj.instance_variable_get(:"@#{el.integrated_from_element}")
                    return false unless int_obj.element_has_value?(el.integrated_from_element)
                else
                    return false unless self.instance_variable_get(:"@#{el.name}")
                end
            end
            return true
        end
        
        def empty?
            return @_has_values
        end
        
        def merge!(obj)
            obj.class.elements_array.select{ |el| obj.element_has_value?(el) && !el.integrated?}.each do |el|
                val = obj.get(el)
                if (!val.is_a?(BaseModel) && val.respond_to?(:clone))
                    begin; val = val.clone; rescue TypeError; end;
                end
                set_loaded_value(el, val)
            end
            @loaded_elements.merge!(obj.loaded_elements)
        end
        
        def clone
            obj = self.class.new
            obj.merge!(self)
            return obj
        end
        
        def keys_to_condition
            c = Condition.and
            self.class.primary_keys.each do |key|
                val = get(key)
                if (key.model?)
                    c[key.name] = val.keys_to_condition
                else
                    c[key.name] = val
                end
            end
            return c
        end
        
        def in_storage? # FIXME! this must be more generic
            self.class.primary_keys.each do |key|
                return false unless element_has_value?(key)
            end
            return true
        end

        
        #################################################
        #   Object observers methods                    #
        #################################################
        
        def observe_all_values(&proc)
            @all_values_observers << proc
        end
        
        def notify_observers(element_name, old_val)
            @value_observers[element_name].each { |proc| proc.call(self, element_name, old_val) } if (@value_observers[element_name])
            @all_values_observers.each { |proc| proc.call(self, element_name, old_val) }
        end
        
        
        
        ##############################################################
        #   Storage, mapper and schema loading (instance methods)    #
        ##############################################################
        
        def storage
            return @storage ||= self.class.storage
        end
        
        def use_storage(storage)
            @storage = self.class.get_storage(storage)
            @mapper = self.class.get_mapper(@storage)
        end
        
        def mapper
            @storage ||= self.class.storage
            @mapper ||= self.class.get_mapper(@storage)
            return @mapper
        end
        
        def mapper=(mapper)
            @mapper = mapper
        end
        
        ##############################################################
        #   Saving and loading from storage methods                  #
        ##############################################################
        
        def save
            mapper.save(self)
            reset_modified_elements
        end
        
        def save_all
            mapper.save_all(self)
        end
        
        def insert
            mapper.insert(self)
            reset_modified_elements
        end
        
        def update
            mapper.update(self)
            reset_modified_elements
        end
        
        def delete
            mapper.delete(self)
        end
        
        def load(*params)
            if (params[0].is_a? Query)
                query = params[0]
            else
                return false unless primary_keys_set?
                query = Query.new
                if (params[0].is_a?(Request))
                    query.request = params.shift
                elsif (params[0].is_a?(Hash))
                    query.request = Request.new(params.shift)
                end
                
                elements = params.length > 0 ? params : self.class.elements.keys
                return true unless elements.select{ |el| !element_loaded?(el) }.length > 0
                elements.each do |name|
                    query.request[name] = true
                end
                query.condition.conjunction = :and
                self.class.primary_keys.each do |key|
                    query.condition[key.name] = get(key.name)
                end
            end
            #clear_values()
            return mapper.load(self, query) 
        end
        
        
        def clear_values()
            self.class.elements.each_key do |element_name|
                instance_variable_set(:"@#{element_name}", nil)
            end
        end
        
        ##############################################################
        #   Method missing                                           #
        ##############################################################
        
        # Autogenerated methods are:
        # load_by_#{primary_key}( *primary_keys ) : 
        #    creates a query with the primary_key set in its condition,
        #    and loads with it
        #
        #    If the model has more than one primary key, a ModelException is raised
        def method_missing(method, *args)
            case method.to_s
            when /load_by_(.+)/
                element = $1
                if !self.class.elements[element.to_sym].attributes[:primary_key]
                    raise ModelException, "load_by_ called for element #{element} which is not a primary key"
                elsif self.class.primary_keys.length > 1
                    raise ModelException, "can't call #{method} because #{element} is not the only primary key"
                end
                query = Query.new
                query.condition[element.to_sym] = args[0]
                load(query)
            else
                if (self.class.attributes[:integrated_models])
                    self.class.attributes[:integrated_models].each do |model, name|
                        obj = send(name)
                        if (obj.respond_to?(method))
                            return obj.send(method, *args)
                        end
                    end
                end
                raise NoMethodError.new(
                "undefined method `#{method}' for " +
                "#{self.class.name}"
                )
            end
        end
        
        # def self.clone
        #     cloned = super
        #     els = @elements
        #     els_order = @elements_order
        #     cloned.class_eval do
        #          @elements = els.clone if els
        #          @elements_order = els_order.clone if els_order
        #      end
        #      cloned.instance_eval do
        #          def name
        #              return @name
        #          end
        #      end
        #      cloned.instance_variable_set(:'@use_storage', @use_storage)
        #      return cloned
        # end
        
        def to_s
            self.class.each_element do |el|
                if (el.type == String && !el.primary_key?)
                    v = get(el)
                    return v ? v.to_s : ''
                end
            end
            el = self.class.elements_array[0]
            if element_has_value?(el)
                v = get(el)
                return v  ? v.to_s : ''
            end
            return ''
        end
        
        def inspect
            self.class.name+': {' +
            self.class.elements_array.select{ |el| (element_loaded?(el) || element_has_value?(el)) && !el.hidden? } \
                .map{ |el| ":#{el.name} => #{get(el.name).to_s}"}.join(',') + '}'
        end
        
        
        def to_json(state=nil, &proc)
            ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
            if (@tmp_json_seen && !block_given?)
                pks = self.class.primary_keys.map{ |k| get(k).to_json }
                pks = pks[0] if pks.length == 1
                return pks.to_json
            end
            @tmp_json_seen = true
            json = ""
            #Spider::Model.with_identity_mapper do |im|
                self.class.elements_array.select{ |el| el.attributes[:integrated_model] }.each do |el|
                    (int = get(el)) && int.instance_variable_set("@tmp_json_seen", true)
                end
                if (block_given?)
                    select_elements = Proc.new{ true }
                else
                    select_elements = Proc.new{ |name, el|
                        !el.hidden?
                        #  &&
                        # #!el.attributes[:integrated_model]  && 
                        # (element_has_value?(el) || (el.integrated? && element_has_value?(el.integrated_from)))
                     }
                 end
                
                json = "{" +
                        self.class.elements.select(&select_elements).map{ |name, el|
                             if (block_given?)
                                 val = yield(self, el)
                                 val ? "#{name}: #{val}" : nil
                             else
                                 val = get(name)
                                 if (el.type == 'text' || el.type == 'longText')
                                     val = ic.iconv(val + ' ')[0..-2]
                                 end
                                 val = val.to_json
                                 "#{name}: #{val}"
                             end
                        }.select{ |pair| pair}.join(',') + "}"
                @tmp_json_seen = false
                self.class.elements_array.select{ |el| el.attributes[:integrated_model] }.each do |el|
                    (int = get(el)) && int.instance_variable_set("@tmp_json_seen", false)
                end
            #end
            return json
        end
        
        def cut(*params, &proc)
            h = {}
            if (params[0].is_a?(String))
                return sprintf(params[0], *params[1..-1].map{ |el| get(el) })
            elsif (params[0].is_a?(Fixnum))
                p = params.shift
                if (p < 1)
                    if (block_given?)
                        return proc.call(self)
                    else
                        return self.to_s
                    end
                end
                lev = p
                where = {}
                self.class.elements_array.each { |el| where[el.name] = lev-1}
            end
            if (params[0].is_a?(Hash))
                where ||= {}
                where.merge!(params[0])
            else
                where ||= {}
                params.each{ |p| where[p] = 0 if p.is_a?(Symbol)}
            end
            Spider::Model.with_identity_mapper do |im|
                where.keys.each do |name|
                    if (where[name].is_a?(Proc))
                        val = where[name].call(self, name)
                    else
                        el = self.class.elements[name]
                        raise ModelException, "Element #{name} does not exist" unless el
                        val = get(el)
                        val = val.cut(where[name], &proc) if el.model? && val
                    end
                    h[name] = val
                end
            end
            return h
        end
        
        def to_hash()
            h = {}
            self.class.elements.select{ |name, el| element_loaded? el }.each do |name, el|
                h[name] = get(name)
            end
            return h
        end
        
    end
    
end; end
