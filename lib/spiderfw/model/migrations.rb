require 'spiderfw/model/migrations/migration'
require 'spiderfw/model/migrations/replace'

module Spider
    
    module Migrations
        
        def self.replace(model, element, values)
            Spider::Migrations::Replace.new(model, element, values)
        end
        
        
    end
    
end