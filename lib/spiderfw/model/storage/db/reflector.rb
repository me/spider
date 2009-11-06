module Spider; module Model; module Storage; module Db
    
    class Reflector
       
       def reflect_table(storage, table_name, target)
           mod = Class.new(Spider::Model::BaseModel)
           model_name = table_to_model_name(table_name)
           target.const_set(model_name, mod)
           table = storage.describe_table(table_name)
           table[:columns].each do |column_name, column|
               name, type, attributes = field_to_element(table_name, column_name, column, storage)
               mod.element(name, type, attributes)
           end
           mod.attributes[:db_table]  = table_name
           return mod
       end
       
       def table_to_model_name(table_name)
           model_name = Spider::Inflector.camelize(table_name)
       end
       
       def column_to_element_name(column_name)
           name = Inflector.underscore(column_name)
       end
       
       def field_to_element(table_name, column_name, column_details, storage)
           type, attributes = storage.reflect_column(table_name, column_name, column_details)
           attributes[:primary_key] = true if (column_details[:primary_key])
           attributes[:db_column_name] = column_name
           return column_to_element_name(column_name), type, attributes
       end
        
    end
    
    
end; end; end; end