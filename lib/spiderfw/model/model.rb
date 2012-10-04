require 'spiderfw/model/datatypes'
require 'spiderfw/model/unit_of_work'
require 'spiderfw/model/identity_mapper'

module Spider 
    
    # Spider::Model is the namespace containing all data-related classes and modules.
    # 
    # In addition, it implements some helper methods.
    #
    # See {BaseModel} for the base class that must be subclassed by app's models.
    module Model
        
        @base_types = [
            String, Spider::DataTypes::Text, Fixnum, Float, BigDecimal, Date, DateTime, Time,
            Spider::DataTypes::Bool, Spider::DataTypes::PK
        ]
        
        # Returns a list of the base types, which must be handled by all mappers.
        # 
        # String, Spider::DataTypes::Text, Fixnum, Float, BigDecimal, Date, DateTime, Spider::DataTypes::Bool.
        #
        # These types must be handled by all mappers.
        # @return [Array] An array of base types
        def self.base_types
            @base_types
        end
        
        # Returns the base type corresponding to a class.
        #
        # For BaseModels, the class itself will be returned; otherwise, will walk superclasses and DataType info 
        # until one of the {Model.base_types} is found.
        #
        # @param [Class] class
        # @return [Class] The Base Type
        def self.base_type(klass)
            k = klass
            while (k && !base_types.include?(k))
                k = simplify_type(k)
            end
            return k
        end
        
        # @param [Class] A DataType subclass
        # @return [Class] The Ruby class corresponding to a Spider DataType
        def self.ruby_type(klass)
            map_types = {
                Spider::DataTypes::Text => String,
                Spider::DataTypes::Bool => FalseClass,
                Spider::DataTypes::Binary => String,
                Spider::DataTypes::FilePath => String
            }
            return map_types[klass] if map_types[klass]
            return klass
        end
        
        # @private
        # An iteration in the search for base type.
        # @param [Class] class
        # @return [Class] simplified type
        def self.simplify_type(klass)
            map_types = {
                
            }
            return klass if base_types.include?(klass)
            return klass if klass <= Spider::Model::BaseModel
            return t if t = map_types[klass]
            return klass.maps_to if klass.subclass_of?(Spider::DataType) && klass.maps_to
            return klass.superclass if klass.superclass
            return nil
        end

        
        # Retrieves an object corresponding to gived values from the IdentityMapper, or puts it there if not found.
        # @param [Class>BaseModel] The model
        # @parm [Object] val A BaseModel instance, or a Hash of values, or a primary key for the model 
        # @param [bool] set_loaded If true, when instantiating an object from hash values, set the values as
        #                          if they were loaded from the storage
        # @return [BaseModel] The object retrieved from the IdentityMapper
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
        # @param [BaseMode] object to place into the IdentityMapper
        # @param [bool] check If true, if the object already exists in the IdentityMapper it will be merged.
        #                     If false, if the object already exists it will be overwritten.
        # @return [BaseModel] The object, as present in the IdentityMapper after the put
        def self.put(obj, check=false)
            if (identity_mapper)
                return identity_mapper.put(obj, check)
            else
                return obj
            end
        end
        
        # @return [IdentityMapper] The current IdentityMapper, if active
        def self.identity_mapper
            Spider.current[:identity_mapper]
        end
        
        # @param [IdentityMapper] im The IdentityMapper to activate for the current request
        # @return [IdentityMapper]
        def self.identity_mapper=(im)
            Spider.current[:identity_mapper] = im
        end
        
        # Starts a new Unit Of Work
        # @return [UnitOfWork]
        def self.start_unit_of_work
            uow = UnitOfWork.new
            uow.start
        end
        
        # Stops the current Unit Of Work
        # @return [void]
        def self.stop_unit_of_work
            Spider.current[:unit_of_work].stop
        end
        
        # @param [Proc] proc If supplied and no Unit Of Work is running, executes the block inside 
        #                    a new Unit Of Work
        # @return [UnitOfWork] the current Unit Of Work, if no block was passed; otherwise, the Unit Of Work that
        #                      was used to run the block 
        def self.unit_of_work(&proc)
            uow = Spider.current[:unit_of_work]
            if !uow
                if proc
                    uow = UnitOfWork.new(&proc)
                end
            end
            return uow
        end
        
        # Sets the UnitOfWork to use for the current request
        # @param [UnitOfWork] uow
        # @return [UnitOfWork]
        def self.unit_of_work=(uow)
            Spider.current[:unit_of_work] = uow
        end
        
        # Executes a block inside a new Unit Of Work
        # 
        # **Note**: you should almost always use {Model.in_unit} instead, since 
        # a Unit Of Work without an Identity Mapper can be problematic.
        # @param [Proc] proc The block to execute
        # @return [UnitOfWork] The Unit Of Work that was used to run the block
        def self.with_unit_of_work(&proc)
            with_identity_mapper do
                return unit_of_work(&proc)
            end
        end
        
        # Executes a block without running in Unit Of Work
        # @param [Proc] proc The block to run without a unit of work
        # @return [UnitOfWork] The previously active Unit Of Work (if any)
        def self.no_unit_of_work(&proc)
            uow = self.unit_of_work
            self.unit_of_work = nil
            yield
            self.unit_of_work = uow
        end
        
        # @return [bool] True if there is an active Unit Of Work, false otherwise
        def self.unit_of_work_running?
            self.unit_of_work && self.unit_of_work.running?
        end
        
        # Executes a block without Identity Mapper
        # @param [Proc] proc The block to run without the Identity Mapper
        # @return [IdentityMapper] The previously active Identity Mapper (if any)
        def self.no_identity_mapper(&proc)
            im = self.identity_mapper
            self.identity_mapper = nil
            yield
            self.identity_mapper = im
        end
        
        # Executes a block without Identity Mapper and Unit Of Work
        # @param [Proc] proc The block to run
        # @return [UnitOfWork] The previously active Unit Of Work (if any)
        def self.no_context(&proc)
            uow = self.unit_of_work
            self.unit_of_work = nil
            im = self.identity_mapper            
            self.identity_mapper = nil
            yield
            self.identity_mapper = im
            self.unit_of_work = uow
            
        end
                
        # Executes a block in the context of the current IdentityMapper, if one is active.
        # If no IdentityMapper is running, the code is executed inside a new Identity Mapper
        # @param [Proc] proc The block to run
        # @return [IdentityMapper] The used Identity Mapper
        def self.with_identity_mapper(&proc)
            if identity_mapper
                yield identity_mapper
            else
                IdentityMapper.new do |im|
                    yield im
                end
            end
        end
        
        # Executes a block inside a Unit Of Work and Identity Mapper
        # @param [Proc] proc The block to run
        # @return [void]
        def self.in_unit(&proc)
            uow = self.unit_of_work
            self.start_unit_of_work unless uow
            self.with_identity_mapper do
                begin
                    yield Spider::Model.unit_of_work
                
                    self.unit_of_work.commit unless uow
                ensure
                    self.stop_unit_of_work unless uow
                end
            end
            
        end
        
        # Syncs the schema for a model, or for all models within an app, with the storage.
        # @param [Class>BaseModel|Module>Spider::App] model_or_app
        # @param [bool] force If true, allow operations that could cause data loss
        # @param [Hash] options Options can be:
        #                       * :no_sync     Don't actually run the sync, only check the operations to run
        #                       * :drop_tables Drop unneeded tables
        # @return [void]
        def self.sync_schema(model_or_app, force=false, options={})
            
            # FIXME: this is clearly db specific. Move somewhere else.
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
		    m.after_sync if m.respond_to?(:after_sync)	
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
        
        # Load YAML data to the storage
        # @param [String] file File to load data from
        # @param [bool] truncate If true, delete all data from the models in the file before inserting new data
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
            loaded = []
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
                        loaded << obj
                    end
                end
            end
            loaded
        end
        
        # Generic Model error.
        class ModelException < RuntimeError
        end
        
        # Error raised when data can't be accepted.
        class FormatError < ::FormatError
            # @return [Element] 
            attr_reader :element
            # @return [Object]
            attr_reader :value
            
            # Takes an Element, the value, and a message.
            # The message should be a format specification; it will be %'d with the value.
            #   error = FormatError.new(my_element, 3, "Element value %s is wrong.")
            #   error.to_s  => "Element value 3 is wrong."
            # @param [Element] value
            # @param [Object] value
            # @param [String] message The error message
            def initialize(element, value, message)
                @element = element
                @message = message
                @value = value
                super(message)
            end
            
            
            def to_s
                label = @element.label
                Spider::GetText.in_domain('spider'){
                    _(@message) % label
                }
            end
            
        end
        
        # Error raised when data is of the wrong type
        class TypeError < ArgumentError
        end
        
        # Sorts an Array of models, placing subclasses before superclasses.
        # 
        # If :association_dependencies is true, models having an association to another model will be placed after the associated
        # model.
        #
        # This can be used to insert a dump of data, ensuring later models only depend on already inserted objects.
        # @param [Array] models An array of BaseModel subclasses
        # @param [Hash] options Options can be:
        #                       * :association_dependencies  If true, sort associated models before the model associating them
        # @return [Array] The sorted array
        def self.sort(models, options={})
            options = {
                :association_dependencies => true
            }.merge(options)
            sorter = Sorter.new(models, options)
            sorter.sort
        end
        
        require 'tsort'
        
        # Helper class from sorting models using TSort
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
        
        # Helper class for sorting models
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
