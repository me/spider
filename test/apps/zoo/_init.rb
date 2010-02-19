module Zoo
    @description = ""
    @version = 0.1
    @path = File.dirname(__FILE__)
    include Spider::App
    
    def self.test_setup
        Spider::Model.sync_schema(self, true)
        self.models.each do |mod|
            mod.mapper.delete_all!
        end
        Spider::Model.load_fixtures(@path+'/data/fixtures.yml')
    end
        
end

require 'apps/zoo/models/animal'
Zoo.models.each do |mod|
    mod.use_storage 'test'
end