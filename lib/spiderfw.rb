require 'spiderfw/env'

require 'rubygems'
require 'find'
require 'fileutils'
require 'pathname'
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
        # Current Home
        attr_reader :home
        # Registered resource types
        attr_reader :resource_types
        # Main site
        attr_accessor :site
        
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
            Locale.default = Spider.conf.get('i18n.default_locale')
            @resource_types = {}
            register_resource_type(:views, :extensions => ['shtml'])
            setup_paths(@root)
            all_apps = find_all_apps
            all_apps.each do |path|
                opts = File.join(path, 'config/options.rb')
                require opts if File.exist?(opts)
            end
            @runmode = nil
            self.runmode = $SPIDER_RUNMODE if $SPIDER_RUNMODE
            load_configuration File.join($SPIDER_PATH, 'config')
            load_configuration File.join(@root, 'config')
            start_loggers
#            @controller = Controller
            @paths[:spider] = $SPIDER_PATH

            if ($SPIDER_CONFIG_SETS)
                $SPIDER_CONFIG_SETS.each{ |set| @configuration.include_set(set) }
            end
            init_file = File.join($SPIDER_RUN_PATH, 'init.rb')
            if File.exist?(init_file)
                @home.instance_eval(File.read(init_file), init_file)
            end
            @logger.close(STDERR)
            @logger.open(STDERR, Spider.conf.get('debug.console.level')) if Spider.conf.get('debug.console.level')
            GetText::LocalePath.memoize_clear # since new paths have been added to GetText
            @apps.each do |name, mod|
                GetText.bindtextdomain(mod.short_name) if File.directory?(mod.path+'/po')
                mod.app_init if mod.respond_to?(:app_init)
            end
            @init_done=true
        end
        
        # 
        # def stop
        #     @apps.each do |name, mod|
        #         mod.app_stop if mod.respond_to?(:app_stop)
        #     end
        # end


        # Invoked before a server is started. Apps may implement the app_startup method, that will be called.
        def startup
            unless File.exists?(File.join(Spider.paths[:root], 'init.rb'))
                raise "The server must be started from the root directory"
            end
            if (Spider.conf.get('template.cache.reload_on_restart'))
                FileUtils.touch("#{Spider.paths[:tmp]}/templates_reload.txt")
            end
            if domain = Spider.conf.get('site.domain')
                ssl_port = Spider.conf.get('site.ssl') ? Spider.conf.get('site.ssl_port') : nil
                Spider.site = Site.new(domain, Spider.conf.get('site.port'), ssl_port)
            elsif File.exists?(Site.cache_file)
                Spider.site = Site.load_cache
            end
            if (Spider.conf.get('request.mutex'))
                mutex_requests!
            end
            @apps.each do |name, mod|
                mod.app_startup if mod.respond_to?(:app_startup)
            end
            @startup_done = true
        end
        
        def startup_done?
            @startup_done
        end
        
        # Invoked when a server is shutdown. Apps may implement the app_shutdown method, that will be called.        
        def shutdown
            return unless Thread.current == Thread.main
            Debugger.post_mortem = false if Object.const_defined?(:Debugger) && Debugger.post_mortem?
            @apps.each do |name, mod|
                mod.app_shutdown if mod.respond_to?(:app_shutdown)
            end
        end
        
        def current
            Spider::Request.current
        end
        
        def request_started
            @request_mutex.lock if (@request_mutex)
            Spider::Request.current = {
                :_start => Time.now
            }
        end
        
        def request_finished
            # Spider.logger.info("Done in #{(Time.now - Spider::Request.current[:_start])*1000}ms")
            Spider::Request.reset_current
            @request_mutex.unlock if (@request_mutex)
        end
        
        def mutex_requests!
            @request_mutex = Mutex.new
        end
        
        def request_mutex
            @request_mutex
        end
        
        def request_mutex=(val)
            @request_mutex = val
        end
        
        
        # Closes any open loggers, and opens new ones based on configured settings.
        def start_loggers
            @logger = Spider::Logger
            @logger.close_all
            @logger.open(STDERR, Spider.conf.get('debug.console.level')) if Spider.conf.get('debug.console.level')
            begin
                FileUtils.mkpath(@paths[:log]) unless File.exist?(@paths[:log])
            rescue => exc
                @logger.error("Unable to create log folder")
            end
            if (File.exist?(@paths[:log]))
                @logger.open(File.join(@paths[:log], 'error.log'), :ERROR) if Spider.conf.get('log.errors')
                if (Spider.conf.get('log.debug.level'))
                    @logger.open(File.join(@paths[:log], 'debug.log'), Spider.conf.get('log.debug.level'))
                end
            end
            $LOG = @logger
        end
        
        # Sets the default paths (see #paths).
        def setup_paths(root)
            @paths[:root] = root
            @paths[:apps] = File.join(root, 'apps')
            @paths[:core_apps] = File.join($SPIDER_PATH, 'apps')
            @paths[:config] = File.join(root, 'config')
            @paths[:layouts] = File.join(root, 'layouts')
            @paths[:var] = File.join(root, 'var')
            @paths[:certs] = File.join(@paths[:config], 'certs')
            @paths[:tmp] = File.join(root, 'tmp')
            @paths[:data] = File.join(root, 'data')
            @paths[:log] = File.join(@paths[:var], 'log')
        end
        
        # Finds an app by name, looking in paths[:apps] and paths[:core_apps]. Returns the found path.
        def find_app(name)
            path = nil
            [@paths[:apps], @paths[:core_apps]].each do |base|
                test = File.join(base, name)
                if File.exist?(File.join(test, '_init.rb'))
                    path = test
                    break
                end
            end
            return path
        end
        
        def find_apps(name)
            [@paths[:apps], @paths[:core_apps]].each do |base|
                test = File.join(base, name)
                if File.exist?(test)
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
            relative_path = path
            if path.index(Spider.paths[:root])
                home = Pathname.new(Spider.paths[:root])
                pname = Pathname.new(path)
                relative_path = pname.relative_path_from(home).to_s
            end
            @loaded_apps[path] = true
            last_name = File.basename(path)
            app_files = ['_init.rb', last_name+'.rb', 'cmd.rb']
            app_files.each{ |f| require File.join(relative_path, f) if File.exist?(File.join(path, f)) }
            GetText::LocalePath.add_default_rule(File.join(path, "data/locale/%{lang}/LC_MESSAGES/%{name}.mo"))
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
                elsif File.exist?(File.join(path, '_init.rb'))
                    app_paths << path
                    Find.prune
                end
            end
            return app_paths
        end
        
        def find_apps_in_folder(path)
            return unless File.directory?(path)
            return [path] if File.exist?(File.join(path, '_init.rb'))
            found = []
            Dir.new(path).each do |f|
                next if f[0].chr == '.'
                found_path = File.join(path, f)
                if File.exist?(File.join(found_path, '/_init.rb'))
                    found << found_path
                else
                    found += find_apps_in_folder(found_path)
                end
            end
            return found
        end
        
        def add_app(mod)
            @apps[mod.name] = mod
            @apps_by_path[mod.relative_path] = mod
            @apps_by_short_name[mod.short_name] = mod
        end
        
        def app?(path_or_name)
            return true if @apps_by_path[path_or_name]
            return true if @apps_by_short_name[path_or_name]
            return false
        end
        
        def load_configuration(path)
            return unless File.directory?(path)
            opts = File.join(path, 'options.rb')
            require opts if File.exist?(opts)
            Dir.new(path).each do |f|
                f.untaint # FIXME: security parse
                case f
                when /^\./
                    next
                when /\.(yaml|yml)$/
                    begin
                        @configuration.load_yaml(File.join(path, f))
                    rescue ConfigurationException => exc
                        if (exc.type == :yaml)
                            @logger.error("Configuration file #{path+f} is not valid YAML")
                        else
                            raise
                        end
                    end
                end
            end
        end
        
        # Returns the default controller.
        def controller
            require 'spiderfw/controller/spider_controller'
            SpiderController
        end
        
        # Sets routes on the #controller for the given apps.
        def route_apps(*apps)
            options = {}
            if apps[-1].is_a?(Hash)
                options = apps.pop
            end
            @route_apps = apps.empty? ? true : apps
            if (@route_apps)
                apps_to_route = @route_apps == true ? self.apps.values : @route_apps.map{ |name| self.apps[name] }
            end
            if options[:except]
                apps_to_route.reject{ |app| options[:except].include?(app) }
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
        
        def path
            $SPIDER_PATH
        end
        
        def relative_path
            '/spider'
        end
        
        # Returns the full path of a resource.
        # resource_type may be :views, or any other type registered with #register_resource_type
        # path is the path of the resource, relative to the resource folder
        # cur_path, if provided, is the current working path
        # owner_class, if provided, must respond to *app*
        # 
        # Will look for the resource in the runtime root first, than in the
        # app's :"#{resource_type}_path", and finally in the spider folder.
        def find_resource(resource_type, path, cur_path=nil, owner_classes=nil, search_paths=[])
            owner_classes = [owner_classes] unless owner_classes.is_a?(Enumerable)
            # FIXME: security check for allowed paths?
            def first_found(extensions, path)
                extensions.each do |ext|
                    full = path
                    full += '.'+ext if ext
                    return full if (File.exist?(full))
                end
                return nil
            end
            
            search_paths ||= []
            owner_classes.each do |owner_class| # FIXME: refactor
                next if owner_class.is_a?(Spider::Home) # home is already checked for other owner_classes
                                                        # FIXME: maybe it shouldn't get here?
                owner_class = nil if owner_class == NilClass
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
                path_app = nil
                if (path[0].chr == '/')
                    first_part = path[1..-1].split('/')[0]
                    Spider.apps_by_path.each do |p, a|
                        if path.index(p+'/') == 1 # FIXME: might not be correct
                        #if first_part == p
                            path_app = a
                            path = path[p.length+2..-1]
                            break
                        end
                    end
                    app = path_app
                elsif owner_class <= Spider::App
                    app = owner_class
                else
                    app = owner_class.app if (owner_class && owner_class.app)
                end
                return Resource.new(cur_path+'/'+path, owner_class) if cur_path && File.exist?(cur_path+'/'+path) # !app
                raise "Can't find owner app for resource #{path}" unless app
                search_locations = resource_search_locations(resource_type, app)
                search_paths.each do |p|
                    p = [p, owner_class] unless p.is_a?(Array)
                    search_locations << p
                end
                search_locations.each do |p|
                    found = first_found(extensions, p[0]+'/'+path)
                    definer = path_app || p[1]
                    return Resource.new(found, definer) if found
                end
            end
            return Resource.new(path)
        end
        
        def resource_search_locations(resource_type, app=nil)
            resource_config = @resource_types[resource_type]
            resource_rel_path = resource_config[:path]
            app_rel_path = app && app.respond_to?(:relative_path) ? app.relative_path : nil
            root_search = File.join(Spider.paths[:root], resource_rel_path)
            root_search = File.join(root_search, app_rel_path) if app_rel_path
            # unless cur_path && cur_path == File.join(root_search, path)
            search_locations = [[root_search, @home]]
            # end
            if app
                if app.respond_to?("#{resource_type}_path")
                    search_locations << [app.send("#{resource_type}_path"), app]
                else
                    search_locations << [File.join(app.path, resource_rel_path), app]
                end
            end
            spider_path = File.join($SPIDER_PATH, resource_rel_path)
            search_locations << [spider_path, self]
            search_locations
        end
        
        def list_resources(resource_type, owner_class=nil, start=nil, search_paths = [])
            app = nil
            if owner_class <= Spider::App
                app = owner_class
            else
                app = owner_class.app if (owner_class && owner_class.app)
            end
            search_locations = resource_search_locations(resource_type, app)
            resource_config = @resource_types[resource_type]
            extensions = resource_config[:extensions]
            search_paths.each do |p|
                p = [p, owner_class] unless p.is_a?(Array)
                search_locations << p
            end
            res = []
            search_locations.reverse.each do |p|
                pname = Pathname.new(p[0])
                base = p[0]
                base = File.join(base, start) if start
                extensions.each do |ext|
                    Dir.glob(File.join(base, "*.#{ext}")).each do |f|
                        res << (Pathname.new(f).relative_path_from(pname)).to_s
                    end
                end
            end
            res.uniq
            
        end
        
        def find_resource_path(resource_type, path, cur_path=nil, owner_classes=nil, search_paths=[])
            res = find_resource(resource_type, path, cur_path, owner_classes, search_paths)
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
                        file_path = File.join(dir, file)
                        if (file_path =~ /^#{path}/)  # FileTest.exists?(file_path) && 
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
            crit = Thread.critical
            Thread.critical = true
            $".each do |file|
                if file =~ /^(#{$SPIDER_RUN_PATH}|apps)/ 
                 #   logger.debug("RELOADING #{file}")
                    load(file)
                else
                #    logger.debug("SKIPPING #{file}")
                end
            end
            Thread.critical = crit
        end
        
        def runmode=(mode)
            raise "Can't change runmode" if @runmode
            @runmode = mode
            @configuration.include_set(mode)
            if mode == 'devel' || File.exists?(File.join($SPIDER_RUN_PATH,'tmp', 'debug.txt'))
                init_debug
            end
            if (mode != 'production')
                Spider.paths[:var] = File.join(Spider.paths[:var], mode)
            end
        end
        
        def init_debug
            begin
                require 'ruby-debug'
                if File.exists?(File.join($SPIDER_RUN_PATH,'tmp', 'debug.txt'))
                    Debugger.wait_connection = true
                    Debugger.start_remote
                    File.delete(File.join($SPIDER_RUN_PATH,'tmp', 'debug.txt'))
                else
                    Debugger.start
                end
            rescue LoadError, RuntimeError; end
        end
        
        def locale
            Locale.current[0]
        end
        
        def i18n(l = self.locale)
            Spider::I18n.provider(l)
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
