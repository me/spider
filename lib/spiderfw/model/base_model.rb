require 'spiderfw/model/element'

module Spider; module Model
    
    
    class BaseModel
        include Spider::Logger
        include DataTypes
        
        class <<self; attr_reader :integrated_models, :extended_models, :polymorphic_models; end
        
        @@base_types = {
            'text' => {:klass => String},
            'longText' => {:klass => String},
            'int' => {:klass => Fixnum},
            'real' => {:klass => Float},
            'dateTime' => {:klass => Time},
            'binary' => {:klass => String},
            'bool' => {:klass => FalseClass}
        }
        
        @@map_types = {
            String => 'text',
            Text => 'longText',
            Fixnum => 'int',
            DateTime => 'dateTime',
            Bool => 'bool'
        }
        
        
        # Copies this class' elements to the subclass.
        def self.inherited(subclass)
            # FIXME: might need to clone every element
            subclass.instance_variable_set("@elements", @elements.clone) if @elements
            subclass.instance_variable_set("@elements_order", @elements_order.clone) if @elements_order
        end
        
        def self.app
            @app ||= self.parent_module
        end
        
        #######################################
        #   Model definition methods          #
        #######################################
        
        # Defines an element belonging to the model.
        def self.element(name, type, attributes={}, &proc)
            @elements ||= {}
            @elements_order ||= []
            default_attributes = case type
            when 'text'
                {:length => 255}
            else
                {}
            end
            attributes = default_attributes.merge(attributes)
            if (type.class == Class && @@map_types[type]) 
                type = @@map_types[type]
            elsif (type.class == Hash)
                type = create_inline_model(type)
                attributes[:inline] = true
            elsif (type.class == String && !@@base_types[type])
                require($SPIDER_PATH+'/lib/model/types/'+type+'.rb')
                type = Spider::Model::Types.const_get(Spider::Model::Types.classes[type]).new
            end
            if (attributes[:add_reverse])
                unless (type.elements[attributes[:add_reverse]])
                    attributes[:reverse] = attributes[:add_reverse]
                    type.element(attributes[:add_reverse], self, :reverse => name)
                end
            elsif (attributes[:add_multiple_reverse])
                unless (type.elements[attributes[:add_reverse]])
                    attributes[:reverse] = attributes[:add_multiple_reverse]
                    type.element(attributes[:add_multiple_reverse], self, :reverse => name, :multiple => true)
                end
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
            @elements[name] = Element.new(name, type, attributes)
            if (attributes[:element_position])
                @elements_order.insert(attributes[:element_position], name)
            else
                @elements_order << name
            end
            
            # class element getter
            (class << self; self; end).instance_eval do
                define_method("#{name}") do
                    @elements[name]
                end
            end
            
            ivar = :"@#{ name }"

            #instance variable getter
            define_method(name) do
                element = self.class.elements[name]
                if (element.integrated?)
                    return get(element.integrated_from.name).send(element.integrated_from_element)
                end
                return instance_variable_get(ivar) if element_has_value?(name) || element_loaded?(name)
                if autoload? && primary_keys_set?
                    mapper.load_element(self, self.class.elements[name])
                elsif (self.class.elements[name].attributes[:multiple])
                    qs = QuerySet.new(self.class.elements[name].model) # or get the element queryset?
                    qs.autoload = autoload?
                    instance_variable_set(ivar, qs)
                elsif (self.class.elements[name].model?)
                    obj = self.class.elements[name].type.new
                    obj.autoload = autoload?
                    instance_variable_set(ivar, obj)
                end
                return instance_variable_get(ivar)
            end

            #instance_variable_setter
            define_method("#{name}=") do |val|
                element = self.class.elements[name]
                if (element.integrated?)
                    integrated_obj = get(element.integrated_from)
                    integrated_obj.autoload = false
                    return integrated_obj.send("#{element.integrated_from_element}=", val)
                end
                if (element.model? && !val.is_a?(BaseModel) && !val.is_a?(QuerySet))
                    val = element.model.new(val)
                    val.autoload = autoload?
                else
                    val = prepare_value(element, val)
                end
                old_val = instance_variable_get(ivar)
                check(name, val)
                instance_variable_set(ivar, val)

                notify_observers(name, old_val)
                #extend_element(name)
            end
            
            if (proc)
                raise ModelException, "Element extension is implemented only for n <-> n elements" unless (@elements[name].multiple? && !@elements[name].has_single_reverse?)
                @elements[name].extend_model
                @elements[name].attributes[:extended] = true
                @elements[name].attributes[:queryset_model] = self
                @elements[name].model.class_eval(&proc)
            end
            
            return @elements[name]

        end
        
        def self.has_many(name, type, attributes={}, &proc)
            attributes[:multiple] = true
            attributes[:association] = :has_many
            element(name, type, attributes, &proc)
        end
        
        def self.owns_many(name, type, attributes={}, &proc)
            attributes[:owner] = true
            has_many(name, type, attributes, &proc)
        end
        
        def self.choice(name, type, attributes={}, &proc)
            attributes[:association] = :choice
            element(name, type, attributes, &proc)
        end
        
        # This should be used only on extended models
        def self.add_element(name, type, attributes={})
             el = element(name, type, attributes)
             el.attributes[:added] = true
             @elements[name] = el
             (@added_elements ||= []) << el
        end
        
        
        # Saves the element definition and evals it when first needed, avoiding problems with classes not
        # available yet when the model is defined.
        def self.define_elements(&proc)
            @elements_definition = proc
        end
        
        def self.create_inline_model(hash)
            model = Class.new(InlineModel)
            model.instance_eval do
                hash.each do |key, val|
                    element(:id, key.class, :primary_key => true)
                    if (val.class == Hash)
                        # TODO: allow to pass multiple values as {:element1 => 'el1', :element2 => 'el2'}
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
            integrated_name = params[:name] || Spider::Inflector.underscore(model.name).gsub('/', '_')
            integrated_name = integrated_name.to_sym
            @extended_models ||= {}
            @extended_models[model] = integrated_name
            integrated_attributes = {:integrated_model => true, :superclass => true}
            integrated = element(integrated_name, model, integrated_attributes)
            model.each_element do |el|
                attributes = el.attributes.clone
                attributes[:integrated_from] = integrated
                if (add_rev = attributes[:add_reverse] || attributes[:add_multiple_reverse])
                    attributes[:reverse] = add_rev
                    attributes.delete(:add_reverse)
                    attributes.delete(:add_multiple_reverse)
                end 
                element(el.name, el.type, attributes)
            end
            if (params[:add_polymorphic])
                model.polymorphic(self, :through => integrated_name)
            end
        end
        
        def self.group(name, &proc)
            require 'spiderfw/model/proxy_model'
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

        
        #####################################################
        #   Methods returning information about the model   #
        #####################################################
        
        def self.short_name
            return self.name.match(/([^:]+)$/)
        end
        
        def self.managed?
            return false
        end
        
        def self.to_s
            self.name
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
        
        # Returns elements added by extending an element inside another model
        def self.added_elements
            return @added_elements || []
        end
        
        ##############################################################
        #   Storage, mapper and loading (Class methods)       #
        ##############################################################
        
        def self.with_mapper(*params, &proc)
            @mapper_proc = proc
        end
        
        def self.with_mapper_for(*params, &proc)
            @mapper_proc = proc
        end
        
        def self.use_storage(name)
            @use_storage = name
        end
        
        def self.storage
            return @storage if @storage
            return @use_storage ? get_storage(@use_storage) : get_storage
        end
        
        # Mixin!
        def self.get_storage(storage_string='default')
            storage_regexp = /([\w\d]+?):(.+)/
            if (storage_string !~ storage_regexp)
                orig_string = storage_string
                storage_string = Spider.conf.get('storages')[storage_string]
                if (!storage_string || storage_string !~ storage_regexp)
                    raise ModelException, "No named storage found for #{orig_string}"
                end
            end
            type, url = $1, $2
            storage = Storage.get_storage(type, url)
            return storage
        end
         
        def self.mapper
            return @mapper if @mapper
            return get_mapper(storage)
        end

        def self.get_mapper(storage)
            mapper = storage.get_mapper(self)
            if (@mapper_proc)
                mapper.instance_eval(&@mapper_proc)
            end
            return mapper
        end

        # Finds objects according to query. Returns a QuerySet.
        # Accepts a Query, or a Condition and a Request (optional)
        def self.find(*params)
            if (params[0] && params[0].is_a?(Query))
                mapper.find(params[0])
            else
                mapper.find(Query.new(params[0], params[1]))
            end
        end
        
        def self.all
            return self.find()
        end
        
        def self.load(*params)
            res = find(*params)
            return res[0]
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
            @value_observers = {}
            @all_values_observers = []
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
                elsif (self.class.primary_keys.length == 1) # Single key, single value
                    set(self.class.primary_keys[0], values)
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
        
        def create_child(element, val=nil)
            element = element.name if element.is_a?(Element)
            obj = identity_mapper.get(element.model, val)
            obj.identity_mapper = self.identity_mapper
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

        def set(element, value)
            element = element.name if (element.class == Element)
            first, rest = element.to_s.split('.', 2)
            return send(first).set(rest) if (rest)
            return send("#{element}=", value)
        end
        
        def prepare_value(element, value)
            case element.type
            when 'dateTime'
                value = DateTime.parse(value) if value.is_a?(String)
            when 'text'
            when 'longText'
                value = value.to_s
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
                instance_variable_set("@#{element_name}", value)
            end
            @loaded_elements[element_name] = true
        end
        
        def check(name, val)
            self.class.elements[name].type.check(val) if (self.class.elements[name].type.respond_to?(:check))
            if (checks = self.class.elements[name].attributes[:check])
                checks = {(_("%s is not in the correct format") % val) => checks} unless checks.is_a?(Hash)
                checks.each do |msg, check|
                    test = case check
                    when Regexp
                        msg =~ check
                    when Proc
                        Proc.call(msg)
                    end
                    raise FormatError, msg unless test
                end
            end
        end
        
        def polymorphic_become(model)
            raise ModelException, "#{self.class} is not polymorphic for #{model}" unless self.class.polymorphic_models[model]
            obj = model.new
            obj.set(self.class.polymorphic_models[model][:through], self)
            return obj
        end
        
        def autoload?
            @_autoload
        end
        
        def autoload=(bool)
            return if @_tmp_autoload_walk
            @_tmp_autoload_walk = true
            @_autoload = bool
            self.class.elements_array.select{ |el| el.model? && element_has_value?(el.name)}.each do |el|
                get(el).autoload = bool
            end
            @_tmp_autoload_walk = nil
        end
        
        def no_autoload
            prev_autoload = autoload?
            autoload = false
            yield
            autoload = prev_autoload
        end
        
        ##############################################################
        #   Methods for getting information about element values     #
        ##############################################################

        def each_val
            self.class.elements.select{ |name, el| element_has_value?(name) }.each do |name, el|
                yield name, get(name)
            end
        end
            
        
        # Returns true if the element instance variable is set
        #--
        # FIXME: should probably try to get away without this method
        # it is the only method that relies on the mapper
        def element_has_value?(element)
            element = element.name if (element.class == Element)
            return get(element) == nil ? false : true if (!mapper.mapped?(element) || self.class.elements[element].integrated?)
            return instance_variable_get(:"@#{element}") == nil ? false : true
        end
        
        def element_loaded?(element)
            element = element.name if (element.class == Element)
            return @loaded_elements[element]
        end
        
        # Returns true if all primary keys have a value; false if some primary key
        # is not set or the model has no primary key
        def primary_keys_set?
            primary_keys = self.class.primary_keys
            return false unless primary_keys.length > 0
            primary_keys.each do |el|
                if (el.integrated?)
                    return false unless (int_obj = instance_variable_get(:"@#{el.integrated_from.name}"))
                    return false unless int_obj.instance_variable_get(:"@#{el.integrated_from_element}")
                else
                    return false unless self.instance_variable_get(:"@#{el.name}")
                end
            end
            return true
        end
        
        def empty?
            return @_has_values
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
            return @mapper ||= self.class.get_mapper(@storage)
        end
        
        def mapper=(mapper)
            @mapper = mapper
        end
        
        ##############################################################
        #   Saving and loading from storage methods                  #
        ##############################################################
        
        def save
            mapper.save(self)
        end
        
        def save_all
            mapper.save_all(self)
        end
        
        def insert
            mapper.insert(self)
        end
        
        def update
            mapper.update(self)
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
                    query.request[name]
                end
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
                if (self.class.integrated_models)
                    self.class.integrated_models.each do |model, name|
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
                return get(el) if (element_has_value?(el) && el.type == 'text' && !el.primary_key?)
            end
            el = self.class.elements_array[0]
            return get(el) if element_has_value?(el)
            return ''
        end
        
        def inspect
            self.class.name+': {' +
            self.class.elements_array.select{ |el| element_loaded?(el) && !el.hidden? } \
                .map{ |el| ":#{el.name} => #{get(el.name).to_s}"}.join(',') + '}'
        end
        
        
        def to_json
            #debugger
            if (@tmp_json_seen)
                return self.class.primary_keys.map{ |k| get(k).to_json }
            end
            @tmp_json_seen = true
            self.class.elements_array.select{ |el| el.attributes[:integrated_model] }.each do |el|
                (int = get(el)) && int.instance_variable_set("@tmp_json_seen", true)
            end
            json = ""
            get_json = lambda{
                return  "{" +
                    self.class.elements.select{ |name, el| 
                        !el.attributes[:integrated_model]  && 
                        (element_loaded?(el) || (el.integrated? && element_loaded?(el.integrated_from)))
                     }.map{ |name, el|
                         "#{name}: #{get(name).to_json}\n"
                    }.join(',') + "}"
            }
            json = get_json.call
            @tmp_json_seen = false
            self.class.elements_array.select{ |el| el.attributes[:integrated_model] }.each do |el|
                (int = get(el)) && int.instance_variable_set("@tmp_json_seen", false)
            end
            return json
        end
        
        def to_hash()
            h = {}
            self.class.elements.select{ |name, el| element_loaded? el }.each do |name, el|
                h[name.to_s] = get(name)
            end
            return h
        end
             
        
        
    end
    
end; end