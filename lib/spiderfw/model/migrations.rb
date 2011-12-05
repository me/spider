require 'spiderfw/model/migrations/migration'
require 'spiderfw/model/migrations/previous_model'
require 'spiderfw/model/migrations/irreversible_migration'
require 'spiderfw/model/migrations/replace'
require 'spiderfw/model/migrations/drop_element'
require 'spiderfw/model/migrations/drop_table'
require 'spiderfw/model/migrations/rename_element'

module Spider
    
    module Migrations
        
        def self.replace(model, element, values)
            Spider::Migrations::Replace.new(model, element, values)
        end

        def self.drop_element!(model, element, options={})
        	Spider::Migrations::DropElement.new(model, element, options={})
        end

        def self.drop_table!(model, options={})
            Spider::Migrations::DropTable.new(model, options={})
        end

        def self.rename_element(model, element, new_element, options={})
            RenameElement.new(model, element, new_element, options={})
        end

        def self.previous_model(model, previous=nil)
            model.send(:include, PreviousModel)
            if previous
                model.previous_model_of(previous)
            end
        end
        
        
    end
    
end