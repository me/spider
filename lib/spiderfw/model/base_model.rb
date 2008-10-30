require 'spiderfw/model/element'

module Spider; module Model
    
    class BaseModel
        
        @@base_types = {
            'text' => {:klass => String},
            'longText' => {:klass => String},
            'int' => {:klass => Fixnum},
            'real' => {:klass => Float},
            'dateTime' => {:klass => Time},
            'binary' => {:klass => String}
        }
        
        # Copies this class' elements to the subclass.
        def self.inherited(subclass)
            # FIXME: might need to clone every element
            subclass.instance_variable_set("@elements", @elements.clone) if @elements
        end
        
        #######################################
        #   Model definition methods          #
        #######################################
        
        # Defines an element belonging to the model.
        def self.element(name, type, attributes={}, &proc)
            @elements ||= {}
            default_attributes = case type
            when 'text'
                {:length => 255}
            else
                {}
            end
            attributes = default_attributes.merge(attributes)
            if type.class == String && !@@base_types[type]
                require($SPIDER_PATH+'/lib/model/types/'+type+'.rb')
                type = Spider::Model::Types.const_get(Spider::Model::Types.classes[type]).new
            end
            @elements[name] = Element.new(name, type, attributes)
            ivar = :"@#{ name }"

            #instance variable getter
            define_method(name) do
                val = instance_variable_get(ivar)
                return val if val
                if primary_keys_set?
                    mapper.load_element(self, self.class.elements[name])
                elsif (self.class.elements[name].attributes[:multiple])
                    instance_variable_set(ivar, QuerySet.new)
                elsif (self.class.elements[name].model?)
                    instance_variable_set(ivar, self.class.elements[name].type.new)
                end
                return instance_variable_get(ivar)
            end

            #instance_variable_setter
            define_method("#{name}=") do |val|
                old_val = instance_variable_get(ivar)
                instance_variable_set(ivar, val)
                notify_observers(name, old_val)
                #extend_element(name)
            end
            
            if (proc)
                raise ModelException, "Element extension is implemented only for n <-> n elements" unless (@elements[name].multiple? && !@elements[name].has_single_reverse?)
                @elements[name].clone_model
                @elements[name].model.class_eval(&proc)
            end
            
            return @elements[name]

        end
        
        def self.has_many(name, type, attributes, &proc)
            attributes[:multiple] = true
            attributes[:association] = :has_many
            element(name, type, attributes, &proc)
        end
        
        # Saves the element definition and evals it when first needed, avoiding problems with classes not
        # available yet when the model is defined.
        def self.define_elements(&proc)
            @elements_definition = proc
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
        
        ########################################################
        #   Methods returning information about the elements   #
        ########################################################
        
        def self.elements
            if @elements_definition
                instance_eval(&@elements_definition)
                @elements_definition = nil
            end
            return @elements
        end
        
        def self.each_element
            elements.each_value do |element|
                yield element
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
        
        def self.storage
            return @storage if @storage
            return get_storage()
        end
        
        # Mixin!
        def self.get_storage(storage_string=nil)
             if (!storage_string)
                 # TODO: implement per-model and per-namespace configuration
                 type = Spider.conf.get('storage.type')
                 url = Spider.conf.get('storage.url')
             elsif (storage_string =~ /([\w\d]+?):(.+)/)
                 type = $1
                 url = $2
             else
                 # TODO: implement named storages
             end
             storage = Storage.get_storage(type, url)
             return storage
         end
         
         def self.mapper
             return @mapper if @mapper
             return get_mapper(storage)
         end

         def self.get_mapper(storage)
             mapper = storage.get_mapper(self)
             return mapper
         end
         
         # Finds objects according to query. Returns a QuerySet.
         def self.find(query)
             mapper.find(query)
         end
        
        
        #################################################
        #   Instance methods                            #
        #################################################

        def initialize(values=nil)
            @value_observers = {}
            @all_values_observers = []
            @all_values_observers << Proc.new do |element, old_value|
                Spider::Model.unit_of_work.add(self) if (Spider::Model.unit_of_work)
            end
            if (values)
                values.each do |key, val|
                    set(key, val)
                end
            end
        end
        
        #################################################
        #   Get and set                                 #
        #################################################
        
        def get(element)
            element = element.name if (element.class == Spider::Model::Element)
            first, rest = element.to_s.split('.', 2)
            if (rest)
                return nil unless element_has_value?(first)
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
        
        # Sets a value without calling the associated setter; used by the mapper
        def set_loaded_value(element, value)
            instance_variable_set("@#{element.name}", value)
        end
            
        
        ##############################################################
        #   Methods for getting information about element values     #
        ##############################################################

        
        # Returns true if the element instance variable is set
        def element_has_value?(element)
            element = element.name if (element.class == Element)
            return instance_variable_get(:"@#{element}") ? true : false
        end
        
        # Returns true if all primary keys have a value; false if some primary key
        # is not set or the model has no primary key
        def primary_keys_set?
            primary_keys = self.class.primary_keys
            return false unless primary_keys.length > 0
            primary_keys.each do |el|
                return false unless self.instance_variable_get(:"@#{el.name}")
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
            @storage ||= self.class.storage
            return @storage
        end
        
        def use_storage(storage)
            @storage = self.class.get_storage(storage)
            @mapper = self.class.get_mapper(@storage)
        end
        
        def mapper
            @storage ||= self.class.get_storage()
            @mapper ||= self.class.get_mapper(@storage)
            return @mapper
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
        
        def load(query=nil)
            if (!query)
                raise ModelException, "Can't load object without a query or primary keys set" unless primary_keys_set?
                query = Query.new
                self.class.elements.each do |name, element|
                    query.request[name] if element_has_value?(element)
                end
                self.class.primary_keys.each do |key|
                    query.condition[key.name] = get(key.name)
                end
            end
            clear_values()
            mapper.load(self, query)
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
                raise NoMethodError.new(
                "undefined method `#{method}' for " +
                "#{self}:#{self.class.name}"
                )
            end
        end
        
        
        
    end
    
end; end