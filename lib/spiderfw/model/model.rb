require 'spiderfw/model/datatypes'
require 'spiderfw/model/unit_of_work'
require 'spiderfw/model/identity_mapper'

module Spider 
    
    module Model
        
        @base_types = [
            String, Spider::DataTypes::Text, Fixnum, Float, BigDecimal, Date, DateTime, Time,
            Spider::DataTypes::Bool, Spider::DataTypes::PK
        ]
        
        # Base types are:
        #
        # String, Spider::DataTypes::Text, Fixnum, Float, BigDecimal, Date, DateTime, Spider::DataTypes::Bool.
        #
        # These types must be handled by all mappers.
        def self.base_types
            @base_types
        end
        
        # Returns the base type corresponding to class. Will walk superclasses and DataType info until
        # a base type is found.
        def self.base_type(klass)
            k = klass
            while (k && !base_types.include?(k))
                k = simplify_type(k)
            end
            return k
        end
        
        # TODO: remove?
        def self.ruby_type(klass) #:nodoc:
            map_types = {
                Spider::DataTypes::Text => String,
                Spider::DataTypes::Bool => FalseClass,
                Spider::DataTypes::Binary => String,
                Spider::DataTypes::FilePath => String
            }
            return map_types[klass] if map_types[klass]
            return klass
        end
        
        # An iteration in the search for base type.
        def self.simplify_type(klass) #:nodoc:
            map_types = {
                
            }
            return klass if base_types.include?(klass)
            return klass if klass <= Spider::Model::BaseModel
            return t if t = map_types[klass]
            return klass.maps_to if klass.subclass_of?(Spider::DataType) && klass.maps_to
            return klass.superclass if klass.superclass
            return nil
        end

        
        # Returns the identity-mapped object
        def self.get(model, val=nil, set_loaded=false)
            if (val && !val.is_a?(Hash))
                if (model.primary_keys.length == 1)
                    val = {model.primary_keys[0].name => val}
                else
                    raise ModelException, "Can't get without primary keys"
                end
            end
            if identity_mapper
                return identity_mapper.get(model, val, set_loaded)
            else
                return model.new(val)
            end
        end
        
        # Puts an object into the IdentityMapper
        def self.put(obj, check=false)
            if (identity_mapper)
                return identity_mapper.put(obj, check)
            else
                return obj
            end
        end
        
        def self.identity_mapper #:nodoc:
            Spider.current[:identity_mapper]
        end
        
        def self.identity_mapper=(im) #:nodoc:
            Spider.current[:identity_mapper] = im
        end
        
        def self.start_unit_of_work
            uow = UnitOfWork.new
            uow.start
        end
        
        def self.stop_unit_of_work
            Spider.current[:unit_of_work].stop
        end
        
        def self.unit_of_work(&proc) #:nodoc:
            uow = Spider.current[:unit_of_work]
            if !uow
                if proc
                    uow = UnitOfWork.new(&proc)
                end
            end
            return uow
        end
        
        
        def self.unit_of_work=(uow)
            Spider.current[:unit_of_work] = uow
        end
        
        def self.with_unit_of_work(&proc)
            with_identity_mapper do
                return unit_of_work(&proc)
            end
        end
        
        def self.no_unit_of_work(&proc)
            uow = self.unit_of_work
            self.unit_of_work = nil
            yield
            self.unit_of_work = uow
        end
        
        def self.unit_of_work_running?
            self.unit_of_work && self.unit_of_work.running?
        end
        
        def self.no_identity_mapper(&proc)
            im = self.identity_mapper
            self.identity_mapper = nil
            yield
            self.identity_mapper = im
        end
        
        def self.no_context(&proc)
            uow = self.unit_of_work
            self.unit_of_work = nil
            im = self.identity_mapper            
            self.identity_mapper = nil
            yield
            self.identity_mapper = im
            self.unit_of_work = uow
            
        end
                
        # Executes the block in the context of the main IdentityMapper.
        def self.with_identity_mapper(&proc)
            if identity_mapper
                yield identity_mapper
            else
                IdentityMapper.new do |im|
                    yield im
                end
            end
        end
        
        def self.in_unit(&proc)
            uow = self.unit_of_work
            self.start_unit_of_work unless uow
            self.with_identity_mapper do
                yield Spider::Model.unit_of_work
                unless uow
                    self.unit_of_work.commit
                    self.stop_unit_of_work 
                end
            end
            
        end
        
        # Syncs the schema with the storage.
        #--
        # FIXME: this is clearly db specific. Move somewhere else.
        def self.sync_schema(model_or_app, force=false, options={}) #:nodoc:
            models = []
            mod = const_get_full(model_or_app)
            if (mod.is_a?(Module) && mod.include?(Spider::App))
                mod.models.each { |m| models << m }
            elsif (mod.subclass_of?(Spider::Model::BaseModel))
                models << mod
            end
            storages = []
            tables = []
            models.each do |m|
                unless (options[:no_sync])
                    Spider::Logger.debug("SYNCING #{m}")
                    m.mapper.sync_schema(force, options) if m.mapper.respond_to?(:sync_schema)
                end
                if (options[:drop_tables] && m.mapper.respond_to?(:schema))
                    storages << m.mapper.storage unless storages.include?(m.mapper.storage)
                    tables += m.mapper.schema.get_schemas.keys
                end
            end
            if (options[:drop_tables])
                dt = options[:drop_tables]
                tables.flatten
                storage_tables = {}
                storages.each do |s|
                    s.list_tables.each do |t|
                        storage_tables[t] = s
                    end
                end
                tables_to_drop = []
                storage_tables.each do |table_name, storage|
                    if !tables.include?(table_name) && (dt == true || table_name.index(dt) == 0)
                        tables_to_drop << table_name
                    end
                end
                raise Spider::Model::Mappers::SchemaSyncUnsafeConversion.new(tables_to_drop) unless tables_to_drop.empty?
                tables_to_drop.each{ |t| storage.drop_table(t) }
            end
        end
        
        # Load YAML data
        def self.load_fixtures(file, truncate=false)
            if (file =~ /\.([^\.]+)$/)
                extension = $1
            else
                raise ArgumentError, "Can't determine type of fixtures file #{file}"
            end
            data = {}
            case extension
            when 'yml'
                require 'yaml'
                data = YAML.load_file(file)
            end
             # Ruby 1.9: steps are not needed with ordered hashes
            data = [data] unless data.is_a?(Array)
            data.each do |step|
                step.each do |mod_name, mod_data|
                    mod = const_get_full(mod_name)
                    mod.mapper.truncate! if truncate
                    mod_data.each do |row|
                        h = {}
                        row.each do |k, v|
                            if v.is_a?(String)
                                if v[0..1] == '@@'
                                    v = v[1..-1]
                                elsif v[0].chr == '@'
                                    v = eval(v[1..-1].to_s)
                                end
                            end
                            h[k] = v
                        end
                        obj = mod.new(h)
                        obj.insert
                    end
                end
            end
        end
        
        # Generic Model error.
        
        class ModelException < RuntimeError
        end
        
        # Error raised when data can't be accepted.
        
        class FormatError < ::FormatError
            attr_reader :element, :value
            
            # Takes an Element, the value, and a message.
            # The message should be a format specification; it will be %'d with the value.
            #   error = FormatError.new(my_element, 3, "Element value %s is wrong.")
            #   error.to_s  => "Element value 3 is wrong."
            def initialize(element, value, message)
                @element = element
                @message = message
                @value = value
                super(message)
            end
            
            
            def to_s
                @message % @value
            end
            
        end
        
        class TypeError < ArgumentError
        end
        
        def self.sort(models, options={})
            options = {
                :association_dependencies => true
            }.merge(options)
            sorter = Sorter.new(models, options)
            sorter.sort
        end
        
        require 'tsort'
        
        class Sorter
            include TSort
            
            def initialize(models, options={})
                @model_tasks = {}
                @processed_deps = {}
                @processed = {}
                @models = models
                @options = options
                @models.each{ |m| collect_dependencies(m) }
            end
            
            def tsort_each_node(&block)
                 @model_tasks.each_value(&block)
             end

             def tsort_each_child(node, &block)
                 node.dependencies.each(&block)
             end

             def collect_dependencies(model)
                 return if model.subclass_of?(Spider::Model::InlineModel)
                 @processed_deps[model] = true
                 @model_tasks[model] ||= SortTask.new(model)
                 if @models.include?(model.superclass)
                     @model_tasks[model.superclass] ||= SortTask.new(model.superclass)
                     @model_tasks[model] << @model_tasks[model.superclass]
                 end
                 if @options[:association_dependencies]
                     model.elements.each do |name, element|
                         if element.model? && !element.attributes[:added_reverse] && @models.include?(element.type)
                             @model_tasks[element.type] ||= SortTask.new(element.type)
                             @model_tasks[model] << @model_tasks[element.type]
                         end
                     end
                 end
             end


             def sort
                 tasks = tsort
                 tasks.map{ |t| t.model }
             end


             def length
               @model_tasks.keys.length
             end
            
        end
        
        class SortTask
            attr_reader :model, :dependencies
            
            def initialize(model)
                @model = model
                @dependencies = []
            end
            
            def <<(model)
                @dependencies << model
            end
            
            def eql?(other)
                @model == other.model
            end
            
            def inspect
                "#{@model.name} -> (#{dependencies.map{|d| d.model.name }.join(', ')})"
            end
                
        end
        
    end
    

end

require 'spiderfw/model/query_funcs'
require 'spiderfw/model/base_model'
require 'spiderfw/model/mappers/mapper'
require 'spiderfw/model/mixins/mixins'
require 'spiderfw/model/extended_models/managed'
require 'spiderfw/model/inline_model'
require 'spiderfw/model/storage'
require 'spiderfw/model/request'
require 'spiderfw/model/condition'
require 'spiderfw/model/query'
require 'spiderfw/model/query_set'
require 'spiderfw/model/unit_of_work'
require 'spiderfw/model/proxy_model'
require 'spiderfw/model/mixins/tree'
require 'spiderfw/model/mixins/list'