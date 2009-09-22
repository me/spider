require 'spiderfw/env'

require 'rubygems'
require 'find'
require 'spiderfw/autoload'
require 'spiderfw/requires'

require 'spiderfw/version'


module Spider
    
    class << self
        # Everything here must be thread safe!!!
        
        # An instance of the shared logger.
        attr_reader :logger
        # An hash of registered Spider::App, indexed by name.
        attr_reader :apps
        # An hash of registred Spider::App modules, indexed by path.
        attr_reader :apps_by_path
        # An hash of registred Spider::App modules, indexed by short name (name without namespace).
        attr_reader :apps_by_short_name
        # The current runmode (test, devel or production).
        attr_reader :runmode
        # An hash of runtime paths.
        # :root::           The base runtime path.
        # :apps::           Apps folder.
        # :core_apps::      Spider apps folder.
        # :config::         Config folder.
        # :views::          Runtime views folder.
        # :var::            Var folder. Must be writable. Contains cache, logs, and other files written by the server.
        # :data::           Data folder. Holds static and dynamic files. Some subdirs may have to be writable.
        # :certs::          Certificates folder.
        # ::tmp::           Temp folder. Must be writable.
        # ::log::           Log location.
        attr_reader :paths
        # Current locale.
        attr_accessor :locale
        # Current Home
        attr_reader :home
        
        # Initializes the runtime environment. This method is called when spider is required. Apps may implement
        # an app_init method, that will be called after Spider::init is done.
        def init(force=false)
            return if @init_done && !force
            @paths = {}
            @apps_to_load = []
            @apps ||= {}
            @apps_by_path ||= {}
            @apps_by_short_name ||= {}
            @loaded_apps = {}
            @root = $SPIDER_RUN_PATH
            @home = Home.new(@root)
            @locale = ENV['LANG']
            @resource_types = {}
            register_resource_type(:views, :extensions => ['shtml'])
            setup_paths(@root)
            all_apps = find_all_apps
            all_apps.each do |path|
                require path+'/config/options.rb' if File.exist?(path+'/config/options.rb')
            end
            load_configuration($SPIDER_PATH+'/config')
            load_configuration(@root+'/config')
            start_loggers
#            @controller = Controller
            @paths[:spider] = $SPIDER_PATH
            @runmode = nil
            
            self.runmode = $SPIDER_RUNMODE if $SPIDER_RUNMODE
            if ($SPIDER_CONFIG_SETS)
                $SPIDER_CONFIG_SETS.each{ |set| @configuration.include_set(set) }
            end
            if File.exist?($SPIDER_RUN_PATH+'/init.rb')
                @home.instance_eval(File.read($SPIDER_RUN_PATH+'/init.rb'), $SPIDER_RUN_PATH+'/init.rb')
            end
            @logger.close(STDERR)
            @logger.open(STDERR, Spider.conf.get('debug.console.level')) if Spider.conf.get('debug.console.level')
            @apps.each do |name, mod|
                GetText.bindtextdomain(mod.short_name) if File.directory?(mod.path+'/po')
                mod.app_init if mod.respond_to?(:app_init)
            end
            
            @init_done=true
            # routes_file = "#{@paths[:config]}/routes.rb"
            # if (File.exist?(routes_file))
            #     load(routes_file)
            # end
            # else
            #     @apps.each do |name, app|
            #         @controller.route('/'+app.name.gsub('::', '/'), app.controller, :ignore_case => true)
            #     end
            # end
        end
        
        # 
        # def stop
        #     @apps.each do |name, mod|
        #         mod.app_stop if mod.respond_to?(:app_stop)
        #     end
        # end


        # Invoked before a server is started. Apps may implement the app_startup method, that will be called.
        def startup
            @apps.each do |name, mod|
                mod.app_startup if mod.respond_to?(:app_startup)
            end
        end
        
        # Invoked when a server is shutdown. Apps may implement the app_shutdown method, that will be called.        
        def shutdown
            @apps.each do |name, mod|
                mod.app_shutdown if mod.respond_to?(:app_shutdown)
            end
        end
        
        # Closes any open loggers, and opens new ones based on configured settings.
        def start_loggers
            @logger = Spider::Logger
            @logger.close_all
            @logger.open(STDERR, Spider.conf.get('debug.console.level')) if Spider.conf.get('debug.console.level')
            if (File.exist?(@paths[:log]))
                @logger.open(@paths[:log]+'/error.log', :ERROR) if Spider.conf.get('log.errors')
                if (Spider.conf.get('log.debug.level'))
                    @logger.open(@paths[:log]+'/debug.log', Spider.conf.get('log.debug.level'))
                end
            end
        end
        
        # Sets the default paths (see #paths).
        def setup_paths(root)
            @paths[:root] = root
            @paths[:apps] = root+'/apps'
            @paths[:core_apps] = $SPIDER_PATH+'/apps'
            @paths[:config] = root+'/config'
            @paths[:layouts] = root+'/layouts'
            @paths[:var] = root+'/var'
            @paths[:certs] = @paths[:config]+'/certs'
            @paths[:tmp] = root+'/tmp'
            @paths[:data] = root+'/data'
            @paths[:log] = @paths[:var]+'/log'
        end
        
        # Finds an app by name, looking in paths[:apps] and paths[:core_apps]. Returns the found path.
        def find_app(name)
            path = nil
            [@paths[:apps], @paths[:core_apps]].each do |base|
                test = base+'/'+name
                if (File.exist?(test+'/_init.rb'))
                    path = test
                    break
                end
            end
            return path
        end
        
        def find_apps(name)
            [@paths[:apps], @paths[:core_apps]].each do |base|
                test = base+'/'+name
                if (File.exist?(test))
                    return find_apps_in_folder(test)
                end
            end
        end
        
        def load_app(name)
            paths = find_apps(name)
            paths.each do |path|
                load_app_at_path(path)
            end
        end
        
        def load_app_at_path(path)
            return if @loaded_apps[path]
            @loaded_apps[path] = true
            last_name = path.split('/')[-1]
            app_files = ['_init.rb', last_name+'.rb', 'config/options.rb', 'cmd.rb']
            app_files.each{ |f| require path+'/'+f if File.exist?(path+'/'+f)}
        end
        
        def load_apps(*l)
            l.each do |app|
                load_app(app)
            end
        end
        
        def load_all_apps
            find_all_apps.each do |path|
                load_app_at_path(path)
            end
        end
        
        def find_all_apps
            app_paths = []
            Find.find(@paths[:core_apps], @paths[:apps]) do |path|
                if (File.basename(path) == '_init.rb')
                    app_paths << File.dirname(path)
                    Find.prune
                elsif (File.exist?("#{path}/_init.rb"))
                    app_paths << path
                    Find.prune
                end
            end
            return app_paths
        end
        
        def find_apps_in_folder(path)
            path += '/' unless path[-1].chr == '/'
            return unless File.directory?(path)
            return [path] if File.exist?(path+'/_init.rb')
            found = []
            Dir.new(path).each do |f|
                next if f[0].chr == '.'
                if (File.exist?(path+f+'/_init.rb'))
                    found << path+f
                else
                    found += find_apps_in_folder(path+f)
                end
            end
            return found
        end
        
        def add_app(mod)
            @apps[mod.name] = mod
            @apps_by_path[mod.relative_path] = mod
            @apps_by_short_name[mod.short_name] = mod
        end
        
        def load_configuration(path)
            return unless File.directory?(path)
            path += '/' unless path[-1] == ?o
            require path+'options.rb' if File.exist?(path+'options.rb')
            Dir.new(path).each do |f|
                f.untaint # FIXME: security parse
                case f
                when /^\./
                    next
                when /\.(yaml|yml)$/
                    begin
                        @configuration.load_yaml(path+f)
                    rescue ConfigurationException => exc
                        if (exc.type == :yaml)
                            @logger.error("Configuration file #{path+f} is not falid YAML")
                        else
                            raise
                        end
                    end
                end
                #load(package_path+'/config/'+f)
            end
        end
        
        # Returns the default controller.
        def controller
            require 'spiderfw/controller/spider_controller'
            SpiderController
        end
        
        # Sets routes on the #controller for the given apps.
        def route_apps(*apps)
            @route_apps = apps.empty? ? true : apps
            if (@route_apps)
                apps_to_route = @route_apps == true ? self.apps.values : @route_apps.map{ |name| self.apps[name] }
            end
            if (apps_to_route)
                apps_to_route.each{ |app| @home.controller.route_app(app) }
            end
        end
        
        # Adds a resource type
        # name must be a symbol, extensions an array of extensions (strings, without the dot) for this resource.
        # Options may be:
        # :extensions   an array of possible extensions. If given, find_resource will try appending the extensions
        #               when looking for the file.
        # :path         the path of the resource relative to resource root; if not given, name will be used.
        # 
        def register_resource_type(name, options={})
            @resource_types[name] = {
                :extensions => options[:extensions],
                :path => options[:path] || name.to_s
            }
        end
        
        # Returns the full path of a resource.
        # resource_type may be :views, or any other type registered with #register_resource_type
        # path is the path of the resource, relative to the resource folder
        # cur_path, if provided, is the current working path
        # owner_class, if provided, must respond to *app*
        # 
        # Will look for the resource in the runtime root first, than in the
        # app's :"#{resource_type}_path", and finally in the spider folder.
        def find_resource(resource_type, path, cur_path=nil, owner_class=nil)
            # FIXME: security check for allowed paths?
            def first_found(extensions, path)
                extensions.each do |ext|
                    full = path
                    full += '.'+ext if ext
                    return full if (File.exist?(full))
                end
                return nil
            end
            
            resource_config = @resource_types[resource_type]
            raise "Unknown resource type #{resource_type}" unless resource_config
            resource_rel_path = resource_config[:path]
            extensions = [nil] + resource_config[:extensions]
            path.strip!
            if (path[0..3] == 'ROOT')
                path.sub!(/^ROOT/, Spider.paths[:root])
                return Resource.new(path, @home)
            elsif (path[0..5] == 'SPIDER')
                path.sub!(/^SPIDER/, $SPIDER_PATH)
                return Resource.new(path, self)
            elsif (cur_path)
                if (path[0..1] == './')
                    return Resource.new(first_found(extensions, cur_path+path[1..-1]), owner_class)
                elsif (path[0..1] == '../')
                    return Resource.new(first_found(extensions, File.dirname(cur_path)+path[2..-1]), owner_class)
                end
            end
            app = nil
            if (path[0].chr == '/')
                Spider.apps_by_path.each do |p, a|
                    if (path.index(p) == 1)
                        app = a
                        path = path[p.length+2..-1]
                        break
                    end
                end
            else
                app = owner_class.app if (owner_class && owner_class.app)
            end
            return Resource.new(cur_path+'/'+path, owner_class) if cur_path && File.exist?(cur_path+'/'+path) # !app
            search_locations = [["#{Spider.paths[:root]}/#{resource_rel_path}/#{app.relative_path}", @home]]
            if app.respond_to?("#{resource_type}_path")
                search_locations << [app.send("#{resource_type}_path"), app]
            else
                search_locations << [app.path+'/'+resource_rel_path, app]
            end
            search_locations << [$SPIDER_PATH+'/'+resource_rel_path, self]
            search_locations.each do |p|
                found = first_found(extensions, p[0]+'/'+path)
                return Resource.new(found, p[1]) if found
            end
            return Resource.new(path)
        end
        
        def find_resource_path(resource_type, path, cur_path=nil, owner_class=nil)
            res = find_resource(resource_type, path, cur_path, owner_class)
            return res ? res.path : nil
        end
        
        
        # Source file management

        def sources_in_dir(path)
            loaded = []
            $".each do |file|
                basename = File.basename(file)
                next if (basename == 'spider.rb' || basename == 'options.rb')
                if (file[0..path.length-1] == path)
                   loaded.push(file)
                else
                    $:.each do |dir|
                        file_path = dir+'/'+file
                        if (FileTest.exists?(file_path) && file_path =~ /^#{path}/)
                            loaded.push(file_path)
                        end
                    end
                end
            end
            return loaded
        end

        def reload_sources_in_dir(dir)
            self.sources_in_dir(dir).each do |file|
                load(file)
            end
        end

        def reload_sources
            logger.debug("Reloading sources")
            logger.debug(@apps)
            self.reload_sources_in_dir($SPIDER_PATH)
            @apps.each do |name, mod|
                dir = mod.path
                logger.debug("Reloading app #{name} in #{dir}\n")
                self.reload_sources_in_dir(dir)
            end
        end
        
        def runmode=(mode)
            raise "Can't change runmode" if @runmode
            @runmode = mode
            @configuration.include_set(mode)
            case mode
            when 'devel' || 'test'
                if (RUBY_VERSION_PARTS[1] == '8')
                    require 'ruby-debug'
                end
            end
        end
        
        def test_setup
        end
        
        def test_teardown
        end
        
        def _test_setup
            @apps.each do |name, mod|
                mod.test_setup if mod.respond_to?(:test_setup)
            end
        end
        
        def _test_teardown
            @apps.each do |name, mod|
                mod.test_teardown if mod.respond_to?(:test_teardown)
            end
        end
        
    end
    
end


# load instead of require for reload_sources to work correctly
load 'spiderfw/config/options/spider.rb'
Spider::init()
