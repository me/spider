require 'pathname'

module Spider

    class Home
        attr_reader :path

        def initialize(path)
            @path = path
        end

        def controller
            require 'spiderfw/controller/home_controller'
            Spider::HomeController
        end

        def route_apps
            Spider.route_apps
        end

        def load_apps(*args)
            Spider.load_apps(*args)
        end

        def list_apps
            apps_path = Spider.respond_to?(:paths) ? Spider.paths[:apps] : File.join(@path, 'apps')
            apps_dir = Pathname.new(apps_path)
            apps = []
            Dir.glob("#{apps_path}/**/_init.rb").each do |path|
                dir = Pathname.new(File.dirname(path))
                apps << dir.relative_path_from(apps_dir).to_s
            end
            apps
        end

    end


end