require 'spiderfw/model/datatypes'
require 'spiderfw/model/unit_of_work'
require 'spiderfw/model/identity_mapper'

module Spider 
    
    module Model
        
        @base_types = [
            String, Spider::DataTypes::Text, Fixnum, Float, BigDecimal, DateTime, Spider::DataTypes::Bool
        ]
        class <<self; attr_reader :base_types; end
        
        def self.base_type(klass)
            k = klass
            while (k && !base_types.include?(k))
                k = simplify_type(k)
            end
            return k
        end
        
        def self.ruby_type(klass)
            map_types = {
                Spider::DataTypes::Text => String,
                Spider::DataTypes::Bool => FalseClass,
                Spider::DataTypes::Binary => String
            }
            return map_types[klass] if map_types[klass]
            return klass
        end
        
        def self.simplify_type(klass)
            map_types = {
                
            }
            return klass if base_types.include?(klass)
            return t if t = map_types[klass]
            return klass.maps_to if (klass.subclass_of?(Spider::DataType) && klass.maps_to)
            return klass.superclass if klass.superclass
            return nil
        end
        
        
        def self.unit_of_work
            Thread.current[:unit_of_work]
        end
        
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
        
        def self.put(obj, check=false)
            if (identity_mapper)
                return identity_mapper.put(obj, check)
            else
                return obj
            end
        end
        
        
        def self.identity_mapper
            Thread.current[:identity_mapper]
        end
        
        def self.identity_mapper=(im)
            Thread.current[:identity_mapper] = im
        end
        
        def self.with_unit_of_work(&proc)
            return if unit_of_work
            UnitOfWork.new(&proc)
        end
        
        def self.with_identity_mapper(&proc)
            if identity_mapper
                yield identity_mapper
            else
                IdentityMapper.new do |im|
                    yield im
                end
            end
        end
        
        def self.sync_schema(model_or_app, force=false, options={})
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
                Spider::Logger.debug("SYNCING #{m}")
                m.mapper.sync_schema(force, options) if m.mapper.respond_to?(:sync_schema)
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
                storage_tables.each do |table_name, storage|
                    if !tables.include?(table_name) && (dt == true || table_name[0..dt.length] == dt)
                        storage.drop_table(table_name) 
                    end
                end
            end
        end
        
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
        
        class ModelException < RuntimeError
        end
        
        class FormatError < ::FormatError
            attr_reader :element, :value
            
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