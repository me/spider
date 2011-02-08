module Spider; module Test
    
    def self.load_fixtures!(app)
        load_fixtures(app, true)
    end
    
    def self.load_fixtures(app, truncate=false)
        path = File.join(app.path, 'test', 'fixtures')
        Dir.glob(File.join(path, '*.yml')).each do |yml|
            Spider::Model.load_fixtures(yml, truncate)
        end
    end
    
end; end

