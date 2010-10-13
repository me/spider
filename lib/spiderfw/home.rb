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
            apps_dir = Pathname.new(Spider.paths[:apps])
            apps = []
            Dir.glob("#{Spider.paths[:apps]}/**/_init.rb").each do |path|
                dir = Pathname.new(File.dirname(path))
                apps << dir.relative_path_from(apps_dir).to_s
            end
            apps
        end

    end


end