module Spider; module Test
    
    def self.load_fixtures(app)
        path = File.join(app.path, 'test', 'fixtures')
        Dir.glob(File.join(path), '*.yml').each do |yml|
            Spider::Model.load_fixtures(yml)
        end
    end
    
end; end