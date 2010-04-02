module Spider

    module Worker
        @description = ""
        @version = 0.1
        @short_name = 'worker'
        @path = File.dirname(__FILE__)
        include Spider::App
        @gem_dependencies = ['rufus-scheduler >2.0.0']
    end
    
end


Spider.register_resource_type :worker, :path => 'config/worker', :extensions => ['rb']