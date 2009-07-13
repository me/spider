require 'spiderfw/model/datatypes'
require 'spiderfw/model/unit_of_work'
require 'spiderfw/model/identity_mapper'

module Spider 
    
    module Model
        
        @base_types = [
            String, Spider::DataTypes::Text, Fixnum, Float, BigDecimal, Date, DateTime, Spider::DataTypes::Bool
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
                Spider::DataTypes::Binary => String
            }
            return map_types[klass] if map_types[klass]
            return klass
        end
        
        # An iteration in the search for base type.
        def self.simplify_type(klass) #:nodoc:
            map_types = {
                
            }
            return klass if base_types.include?(klass)
            return t if t = map_types[klass]
            return klass.maps_to if (klass.subclass_of?(Spider::DataType) && klass.maps_to)
            return klass.superclass if klass.superclass
            return nil
        end
        
        # FIXME: Tread global variables are no good in no-threaded mode
        def self.unit_of_work #:nodoc:
            Thread.current[:unit_of_work]
        end
        
        # Returns the identity-mapped object
        def self.get(model, val)
            if (!val.is_a?(Hash))
                if (model.primary_keys.length == 1)
                    val = {model.primary_keys[0].name => val}
                else
                    raise ModelException, "Can't get without primary keys"
                end
            end
            if identity_mapper
                return identity_mapper.get(model, val)
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
        
        # FIXME: no good
        def self.identity_mapper #:nodoc:
            Thread.current[:identity_mapper]
        end
        
        # FIXME: no good
        def self.identity_mapper=(im) #:nodoc:
            Thread.current[:identity_mapper] = im
        end
        
        # Creates a new unit of work with the proc
        def self.with_unit_of_work(&proc) #:nodoc: TODO: test
            return if unit_of_work
            UnitOfWork.new(&proc)
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
        def self.load_fixtures(file)
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
                    mod_data.each do |row|
                        obj = mod.new(row)
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
        
    end
    

end

require 'spiderfw/model/base_model'
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