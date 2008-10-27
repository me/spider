module Spider 
    
    module Model
        
        def self.unit_of_work=(uow)
            @unit_of_work = uow
        end
        
        def self.unit_of_work
            @unit_of_work
        end
        
        class ModelException < RuntimeError
        end
        
    end
    
    Model.autoload(:BaseModel, 'spiderfw/model/base_model')
    Model.autoload(:Mixins, 'spiderfw/model/mixins/mixins')
    Model.autoload(:Managed, 'spiderfw/model/extended_models/managed')
    Model.autoload(:Storage, 'spiderfw/model/storage')
    Model.autoload(:Request, 'spiderfw/model/request')
    Model.autoload(:Condition, 'spiderfw/model/condition')
    Model.autoload(:Query, 'spiderfw/model/query')
    Model.autoload(:ObjectSet, 'spiderfw/model/object_set')
    Model.autoload(:UnitOfWork, 'spiderfw/model/unit_of_work')

end