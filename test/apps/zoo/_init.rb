module Zoo
    @description = ""
    @version = 0.1
    @path = File.dirname(__FILE__)
    include Spider::App
    
    def self.test_setup
        Spider::Model.sync_schema(self)
    end
        
end

require 'apps/zoo/models/animal'