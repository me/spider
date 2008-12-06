require 'spiderfw/model/datatypes'
require 'spiderfw/model/unit_of_work'
require 'spiderfw/model/identity_mapper'

module Spider 
    
    module Model
        
        
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
        
        class ModelException < RuntimeError
        end
        
    end
    
    Model.autoload(:BaseModel, 'spiderfw/model/base_model')
    Model.autoload(:Mixins, 'spiderfw/model/mixins/mixins')
    Model.autoload(:Managed, 'spiderfw/model/extended_models/managed')
    Model.autoload(:InlineModel, 'spiderfw/model/inline_model')    
    Model.autoload(:Storage, 'spiderfw/model/storage')
    Model.autoload(:Request, 'spiderfw/model/request')
    Model.autoload(:Condition, 'spiderfw/model/condition')
    Model.autoload(:Query, 'spiderfw/model/query')
    Model.autoload(:QuerySet, 'spiderfw/model/query_set')
    Model.autoload(:UnitOfWork, 'spiderfw/model/unit_of_work')

end