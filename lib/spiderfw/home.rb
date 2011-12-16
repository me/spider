require 'pathname'
require 'spiderfw/spider'
require 'spiderfw/app'


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
        
        def apps_path
            @apps_path = Spider.paths[:apps] if Spider.respond_to?(:paths)
            @apps_path ||= File.join(@path, 'apps')
        end

        def pub_path
            controller.pub_path
        end

        def pub_url
            controller.pub_url
        end

        def list_apps
            apps_dir = Pathname.new(self.apps_path)
            paths = Spider.find_all_apps(self.apps_path)
            apps = []
            paths.each do |path|
                dir = Pathname.new(path)
                apps << dir.relative_path_from(apps_dir).to_s
            end
            apps
        end
        
        def apps
            apps = {}
            list_apps.each do |path|
                spec_file = Dir.glob(File.join(self.apps_path, path, "*.appspec")).first
                spec = nil
                if spec_file
                    spec = Spider::App::AppSpec.load(spec_file)
                    app_name = spec.app_id
                else
                    app_name = path
                end
                apps[app_name] = {
                    :path => path,
                    :spec => spec
                }
            end
            apps
        end

    end


end