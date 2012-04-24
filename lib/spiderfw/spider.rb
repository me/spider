require 'spiderfw/env'

require 'rubygems'
require 'etc'
require 'backports'
require 'find'
require 'fileutils'
require 'pathname'
require 'spiderfw/autoload'
require 'spiderfw/requires'

require 'spiderfw/version'
require 'timeout'

begin
    require 'fssm'
rescue LoadError
end


# The main Spider module. 
#
# It contains methods to manage the environment and the lifecycle of 
# the application.
module Spider
    
    @apps = {}; @apps_by_path = {}; @apps_by_short_name = {}; @loaded_apps = {}
    @paths = {}
    @resource_types = {}
    @spawner = nil
    
    class << self
        # Everything here must be thread safe!!!
        
        # An instance of the shared logger.
        # @return [Spider::Logger]
        attr_reader :logger
        # An hash of registered Spider::App, indexed by name.
        # @return [Array]
        attr_reader :apps
        # An hash of registred Spider::App modules, indexed by path.
        # @return [Hash]
        attr_reader :apps_by_path
        # An hash of registred Spider::App modules, indexed by short name (name without namespace).
        # @return [Hash]
        attr_reader :apps_by_short_name
        # The current runmode (test, devel or production).
        # @return [String]
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
        # :tmp::           Temp folder. Must be writable.
        # :log::           Log location.
        # @return [Hash]
        attr_reader :paths
        # Current Home
        # @return [Spider::Home]
        attr_reader :home
        # Registered resource types
        # @return [Array]
        attr_reader :resource_types
        # Main site
        # @return [Site]
        attr_accessor :site

        attr_accessor :spawner
        
        # Initializes the runtime environment. This method is called when spider is required. Apps may implement
        # an app_init method, that will be called after Spider::init is done.
        # @param [force=false] Force init, even if it is already done.
        # @returns [true]
        def init(force=false)
            return if @init_done && !force
            
            init_base(force)
            
            start_loggers

#            @controller = Controller
            @paths[:spider] = $SPIDER_PATH

            if ($SPIDER_CONFIG_SETS)
                $SPIDER_CONFIG_SETS.each{ |set| @configuration.include_set(set) }
            end
            init_file = File.join($SPIDER_RUN_PATH, 'init.rb')
            ENV['BUNDLE_GEMFILE'] ||= File.join($SPIDER_RUN_PATH, 'Gemfile')
            if File.exists?(ENV['BUNDLE_GEMFILE']) && File.exists?(File.join($SPIDER_RUN_PATH, 'Gemfile.lock'))
                require 'bundler/setup' 
            end
            
            if File.exist?(init_file)
                @home.instance_eval(File.read(init_file), init_file)
            end
            
            init_apps
            @init_done=true
        end
        
        # Sets up GetText for each app, and runs app_init on them, if the app implement it.
        # @returns [nil]
        def init_apps
            @apps.each do |name, mod|
                repos = []
                if File.directory?(File.join(mod.path, 'po'))
                    repos <<  FastGettext::TranslationRepository.build(mod.short_name, :path => File.join(mod.path, 'data', 'locale'))
                end
                home_pot = File.join(mod.base_path, 'po', "#{mod.short_name}.pot")
                home_locale = File.join(mod.base_path, 'data', 'locale')
                if File.file?(home_pot) && File.directory?(home_locale)
                    repos << FastGettext::TranslationRepository.build(mod.short_name, :path => home_locale)
                end
                unless repos.empty?
                    FastGettext.add_text_domain(mod.short_name, :type => :chain, :chain => repos)
                end
            end
            @apps.each do |name, mod|
                mod.app_init if mod.respond_to?(:app_init)
            end
        end
        
        # @return [TrueClass|FalseClass] True if init has already been done
        def init_done?
            @init_done
        end
        
        # Loads configuration, sets up Locale and GetText, sets paths and the default Logger.
        # The runmode is also set at this phase, if it is defined as $SPIDER_RUNMODE or in configuration.
        # @param [force=false] Force init_base, even if it is already done.
        # @returns [true]
        def init_base(force=false)
            return if @init_base_done && !force
            l = Spider.locale.to_s
            l = $1 if l =~ /(\w\w)_+/
            FastGettext.locale = l
            
            @apps_to_load = []
            @root = $SPIDER_RUN_PATH
            @home = Home.new(@root)
            
            require 'spiderfw/config/options/spider.rb'

            setup_paths(@root)
            all_apps = find_all_apps
            all_apps.each do |path|
                load_configuration(File.join(path, 'config'))
            end
            @runmode = nil
            load_configuration File.join($SPIDER_PATH, 'config')
            begin
                user_rc = File.join(Etc.getpwuid.dir, '.spider.conf.yml')
                if File.file?(user_rc)
                    load_configuration_file(user_rc)
                end
            rescue NoMethodError # No getpwuid under windows
            end
            load_configuration File.join(@root, 'config')
            self.runmode = $SPIDER_RUNMODE || 'devel'
            Locale.default = Spider.conf.get('i18n.default_locale')
            setup_env
            @logger = Spider::Logger
            @init_base_done = true
        end
        

        # Creates runtime folders: 'tmp', 'var', 'var/memory' and 'var/data'
        # @return [void]
        def setup_env
            unless File.exists?(File.join(Spider.paths[:root], 'init.rb'))
                raise "This command must be run from the root directory"
            end
            FileUtils.mkdir_p(Spider.paths[:tmp])
            FileUtils.mkdir_p(Spider.paths[:var])
            FileUtils.mkdir_p(File.join(Spider.paths[:var], 'memory'))
            FileUtils.mkdir_p(File.join(Spider.paths[:var], 'data'))
            
        end


        # Invoked before a long running service started. Apps may implement the app_startup method, that will be called.
        # @return [void]
        def startup
            init
            setup_env
            if Spider.conf.get('template.cache.reload_on_restart')
                FileUtils.touch("#{Spider.paths[:tmp]}/templates_reload.txt")
            end
            unless Spider.runmode == 'test'
                if domain = Spider.conf.get('site.domain')
                    ssl_port = Spider.conf.get('site.ssl') ? Spider.conf.get('site.ssl_port') : nil
                    Spider.site = Site.new(domain, Spider.conf.get('site.port'), ssl_port)
                end
            end
            if Spider.conf.get('request.mutex')
                mutex_requests!
            end
            @apps.each do |name, mod|
                mod.app_startup if mod.respond_to?(:app_startup)
            end
            @startup_done = true
            at_exit do
                Spider.shutdown
            end
        end
        
        # Called before the main process starts up.
        # 
        # This happens, for example, when Spider server is started from command line; the main process can then
        # spawn other processes, as supporting listeners or workers.
        # 
        # Note that in some environments (e.g. Phusion Passenger) there will not be a main process, so
        # this method will not be called.
        def main_process_startup
            if defined?(FSSM)
                monitor = FSSM::Monitor.new

                monitor.path(Spider.paths[:tmp], 'restart.txt') do
                    create { |base, relative| Process.kill 'HUP', $$ }
                    update { |base, relative| Process.kill 'HUP', $$ }            

                end

                if Spider.conf.get('template.cache.use_fssm')
                    monitor.path(Spider.paths[:root]) do
                        glob '**/*.shtml'
                        create { |base, relative| FileUtils.rm_rf(File.join(Spider.paths[:var], 'cache', 'templates')) }
                        update { |base, relative| FileUtils.rm_rf(File.join(Spider.paths[:var], 'cache', 'templates')) }                                    
                    end
                    monitor.path($SPIDER_PATH) do
                        glob '**/*.shtml'
                        create { |base, relative| FileUtils.rm_rf(File.join(Spider.paths[:var], 'cache', 'templates')) }
                        update { |base, relative| FileUtils.rm_rf(File.join(Spider.paths[:var], 'cache', 'templates')) }                                    
                    end
                    FileUtils.rm_rf(File.join(Spider.paths[:var], 'cache', 'templates'))
                end

                @fssm_thread = Thread.new do
                    monitor.run
                end
                Spider.output("Monitoring restart.txt")

            else
                Spider.output("FSSM not installed, unable to monitor restart.txt")
                if Spider.conf.get('template.cache.use_fssm')
                    raise "Unable to use FSSM for monitoring templates; use template.cache.disable instead"
                end
            end
            trap('TERM'){ Spider.main_process_shutdown; exit }
            trap('INT'){ Spider.main_process_shutdown; exit }
            trap('HUP'){ Spider.respawn! } unless RUBY_PLATFORM =~ /win32|mingw32/
            
            if @main_process_startup_blocks
                @main_process_startup_blocks.each{ |block| block.call }
            end
            
        end
        
        # @param [Proc] proc A block that will be called when #main_process_startup is run
        # @return [Proc] The passed proc
        def on_main_process_startup(&proc)
            @main_process_startup_blocks ||= []
            @main_process_startup_blocks << proc
        end
        
        # @return [true] True if startup has been done
        def startup_done?
            @startup_done
        end
        
        # @param [Proc] proc A block that will be called when #shutdown is run
        # @return [Proc] The passed proc
        def on_shutdown(&block)
            @shutdown_blocks ||= []
            @shutdown_blocks << block
        end
        
        # Invoked when a server is shutdown. Apps may implement the app_shutdown method, that will be called.        
        # @return [void]
        def shutdown(force=false)
            unless force
                #return unless Thread.current == Thread.main
                return if @shutdown_done
            end
            @shutdown_done = true
            Spider.logger.debug("Shutdown")
            if @running_threads
                begin
                    Timeout.timeout(Spider.conf.get('process.shutdown_timeout')) do
                        @running_threads.each do |thr|
                            thr.join if thr.alive?
                        end
                    end
                rescue => exc
                    Spider.logger.error(exc)
                    @running_threads.each do |thr|
                        begin
                            thr.kill
                        rescue => exc
                        end
                    end
                end
            end
            Debugger.post_mortem = false if Object.const_defined?(:Debugger) && Debugger.post_mortem?
            @apps.each do |name, mod|
                mod.app_shutdown if mod.respond_to?(:app_shutdown)
            end
            if @shutdown_blocks
                @shutdown_blocks.each{ |b| b.call }
            end
        end
        
        # Force shutdown, even if it has been done already
        # @return [void]
        def shutdown!
            shutdown(true)
        end

        # Adds a running thread to the application. The app will wait for running threads
        # when shutting down.
        # @param [Thread] thread to add
        # @return [void]
        def add_thread(thr)
            @running_threads ||= []
            @threads_mutex ||= Mutex.new
            @threads_mutex.synchronize do
                @running_threads << thr
            end
        end

        # Removes a running thread. See {add_thread}.
        # @param [Thread] The thread to remove
        # @return [void]
        def remove_thread(thr)
            @threads_mutex.synchronize do
                @running_threads.delete(thr)
            end
        end
        
        # Called when the main process is shut down. See also {main_process_startup}.
        # @return [void]
        def main_process_shutdown
            if startup_done?
                shutdown!
            end
            if @main_process_shutdown_blocks
                @main_process_shutdown_blocks.each{ |b| b.call }
            end
        end
        
        # @param [Proc] proc A block that will be called when {main_process_shutdown} is run
        # @return [Proc] The passed proc
        def on_main_process_shutdown(&block)
            @main_process_shutdown_blocks ||= []
            @main_process_shutdown_blocks << block
        end
        
        # Restarts the application.
        #
        # Note that this actually touches the restart file (tmp/restart.txt by default), so the same
        # effect can by achieved by manually touching the file
        # @return [void]
        def restart!
            FileUtils.touch(@paths[:restart_file])
        end

        # @return [Hash] An Hash of data local to the current request.
        def current
            Spider::Request.current
        end
        
        # Called when a new request is started.
        # @return [void]
        def request_started
            @request_mutex.lock if (@request_mutex)
            Spider::Request.current = {
                :_start => Time.now
            }
        end
        
        # Called when a new request is finished.
        # @return [void]
        def request_finished
            # Spider.logger.info("Done in #{(Time.now - Spider::Request.current[:_start])*1000}ms")
            Spider::Request.reset_current
            @request_mutex.unlock if (@request_mutex)
        end
        
        # Run a lock around requests, ensuring only one request is run at a time.
        # This is usually not needed, except for testing and special situations.
        # @return [void]
        def mutex_requests!
            @request_mutex = Mutex.new
        end
        
        # @return [Mutex] The current Request Mutex, if set
        def request_mutex
            @request_mutex
        end
        
        # Sets the current Request Mutex
        # @param [Mutex] 
        # @return [Mutex]
        def request_mutex=(val)
            @request_mutex = val
        end
        
        
        # Closes any open loggers, and opens new ones based on configured settings.
        # @param [bool] force to start loggers even if already started.
        # @return [true]
        def start_loggers(force=false)
            init_base
            return if @logger_started && !force
            @logger.close_all
            @logger.open(STDERR, Spider.conf.get('log.console')) if Spider.conf.get('log.console')
            begin
                FileUtils.mkdir(@paths[:log]) unless File.exist?(@paths[:log])
            rescue => exc
                @logger.error("Unable to create log folder") if File.exist?(File.dirname(@paths[:log]))
            end
            if @paths[:log] && File.exist?(@paths[:log])
                @logger.open(File.join(@paths[:log], 'error.log'), :ERROR) if Spider.conf.get('log.errors')
                if Spider.conf.get('log.level')
                    @logger.open(File.join(@paths[:log], Spider.conf.get('log.file_name')), Spider.conf.get('log.level'))
                end
            end
            if RUBY_PLATFORM =~ /java/ && Spider.conf.get('log.apache_commons')
                begin
                    require 'spiderfw/utils/loggers/apache_commons_logger'
                    l = Spider::Loggers::ApacheCommonsLogger.new
                    @logger.add('apache_commons_logger', l)
                rescue NameError
                    $stderr << "Warning: Unable to load Java class org.apache.commons.logging.LogFactory\n"
                end
            end
            $LOG = @logger
            Object.const_set(:LOGGER, @logger)
            @logger_started = true
        end
        
        
        # Sets the default paths (see {paths}).
        # @return [Hash] The paths Hash
        def setup_paths(root)
            @paths[:root] = root
            @paths[:apps] = File.join(root, 'apps')
            @paths[:core_apps] = $SPIDER_PATHS[:core_apps]
            @paths[:config] = File.join(root, 'config')
            @paths[:layouts] = File.join(root, 'layouts')
            @paths[:var] = File.join(root, 'var')
            @paths[:certs] = File.join(@paths[:config], 'certs')
            @paths[:tmp] = File.join(root, 'tmp')
            @paths[:data] = File.join(root, 'data')
            @paths[:log] = File.join(@paths[:var], 'log')
            @paths[:restart_file] = File.join(@paths[:tmp], 'restart.txt')
            @paths.each do |k, path|
                @paths[k] = File.expand_path(File.readlink(path)) if File.symlink?(path)
            end
            @paths
        end

        # @return [Array] paths to look for apps
        def app_paths
            paths = [$SPIDER_PATHS[:core_apps]]
            paths.unshift(@paths[:apps]) if @paths[:apps]
            paths
        end
        
        # Finds an app by name, looking in paths[:apps] and paths[:core_apps].
        # @return [String|nil] The path of the found app, or nil if it was not found.
        def find_app(name)
            path = nil
            app_paths.each do |base|
                test = File.join(base, name)
                if File.exist?(File.join(test, '_init.rb'))
                    path = test
                    break
                end
            end
            return path
        end
        
        # Finds sub-apps (apps inside another one)
        # @param [String] name
        # @return [Array] An Array of apps found at path name
        def find_apps(name)
            app_paths.each do |base|
                test = File.join(base, name)
                if File.exist?(test)
                    return find_apps_in_folder(test)
                end
            end
        end
        
        # Loads the given app
        # @param [String] name
        # @return [void]
        def load_app(name)
            paths = find_apps(name)
            paths.each do |path|
                load_app_at_path(path)
            end
        end
        
        # Loads the app inside the give folder
        # @param [String] path
        # @return [void]
        def load_app_at_path(path)
            return if @loaded_apps[path]
            relative_path = path
            if Spider.paths[:root] && path.index(Spider.paths[:root])
                home = Pathname.new(Spider.paths[:root])
                pname = Pathname.new(path)
                relative_path = pname.relative_path_from(home).to_s
            end
            @loaded_apps[path] = true
            last_name = File.basename(path)
            app_files = ['_init.rb', last_name+'.rb', 'cmd.rb']
            app_files.each{ |f| require File.join(relative_path, f) if File.exist?(File.join(path, f)) }
        end
        
        # Loads a list of apps
        # @param [*apps]
        # @return [void]
        def load_apps(*l)
            if l.empty?
                l = Spider.conf.get('apps')
            end
            l.each do |app|
                load_app(app)
            end
        end
        
        # Loads all apps inside the defined app paths (see {app_paths})
        # @return [void]
        def load_all_apps
            find_all_apps.each do |path|
                load_app_at_path(path)
            end
        end
        
        # @param [Array] An Array of paths to look into. Will use {app_paths} if nil.
        # @return [Array] An Array of paths for all found apps
        def find_all_apps(paths=nil)
            paths ||= self.app_paths

            app_paths = []
            Find.find(*paths) do |path|
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
        
        # @param [String] path
        # @return [Array] An array of all apps found inside path
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
        
        # Registers an App with Spider
        # @param [Spider::App] mod The App module
        # @return [void]
        def add_app(mod)
            @apps[mod.name] = mod
            @apps_by_path[mod.relative_path] = mod
            @apps_by_short_name[mod.short_name] = mod
        end
        
        # @param [String] path_or_name
        # @return [bool] True if there is an app at given path or with given name, False otherwise
        def app?(path_or_name)
            return true if @apps_by_path[path_or_name]
            return true if @apps_by_short_name[path_or_name]
            return false
        end
        
        # Returns the dependencies for given apps, based on the apps' spec.
        # 
        # Options accepts:
        # * :optional  whether to include optional apps in the dependencies
        # @param [Arrray] An Array of App names
        # @param [Hash] options 
        # @return [Array] The dependencies for the given apps
        def get_app_deps(apps, options={})
            new_apps = apps.clone
            specs = {}
            init_base
            while !new_apps.empty? && curr = new_apps.pop
                raise "Could not find app #{curr}" unless Spider.home.apps[curr]
                spec = Spider.home.apps[curr][:spec]
                specs[curr] = spec
                new_apps += spec.depends.reject{ |app| specs[app] }
                new_apps += spec.depends_optional.reject{ |app| specs[app] } if options[:optional]
            end
            specs.keys
        end
        
        # Used by configuration editor
        #-- TODO
        def activate_apps(apps, specs=nil)
            require 'spiderfw/config/configuration_editor'
            init_base
            unless specs
                specs = {}
                Spider.home.apps.each do |k, v|
                    specs[k] = v[:spec] if apps.include?(k)
                end
            end
            editor = Spider::ConfigurationEditor.new
            Spider.config.loaded_files.each do |f|
                editor.load(f)
            end
            c_apps = Spider.config.get('apps') || []
            c_apps = (c_apps + apps).uniq
            editor.set('apps', Spider.apps_load_order(c_apps, specs))
            editor.save
        end
        
        # @param [Array] apps The apps to order
        # @param [Hash] specs A Hash of the apps' {AppSpec}s, indexed by app short name
        # @return [Array] the order in which to load apps, based on their specs.
        def apps_load_order(apps, specs)
            # TODO
            require 'spiderfw/app'
            sort = Spider::App::RuntimeSort.new
            apps.each do |a|
                sort.add(specs[a] ? specs[a] : a)
            end
            sort.tsort.reject{ |a| a.nil? }
        end
        

        # Loads configuration YAML files found inside path
        # @param [String] path
        # @return [void]
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
                    load_configuration_file(File.join(path, f))
                end
            end
        end

        # Loads a YAML configuration file
        # @param [String] path to the file
        # @return [void]
        def load_configuration_file(file)
            begin
                @configuration.load_yaml(file)
            rescue ConfigurationException => exc
                if exc.type == :yaml
                    err = "Configuration file #{path+f} is not valid YAML"
                    Spider.output(err, :ERROR)
                else
                    raise
                end
            end
        end
        
        # Returns the default controller Class ({SpiderController}).
        # @return [Class]
        def controller
            require 'spiderfw/controller/spider_controller'
            SpiderController
        end
        
        # Sets routes on the controller for the given apps.
        # @param [Array] An array of app names to route.
        # @return [void]
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
        # 
        # Resources can be searched with {find_resource}. They will be searched first inside the home, then 
        # inside the app's folder. This way, home can override app resources. See also {find_resource}.
        # 
        # Options may be:
        # * :extensions   an Array of possible extensions. If given, find_resource will try appending the extensions
        #                 when looking for the file.
        # * :path         the path of the resource relative to resource root; if not given, name will be used.
        # 
        # @param [Symbol] name
        # @param [Hash] options
        # @return [void]
        def register_resource_type(name, options={})
            @resource_types[name] = {
                :extensions => options[:extensions],
                :path => options[:path] || name.to_s
            }
        end
        
        Spider.register_resource_type(:views, :extensions => ['shtml'])
        
        # @return [String] $SPIDER_PATH
        def path
            $SPIDER_PATH
        end
        
        # @return [String] '/spider'
        def relative_path
            '/spider'
        end
        
        # Returns the full path of a resource.
        # 
        # Spider provides the following resources:
        # * :views (:filetypes => ['.shtml'])
        # * :js and :css (:path => 'public')
        #
        # Apps can define their own resource types (see {register_resource_type}).
        #
        # This method will look for the resource in the runtime root first, than in the
        # app's :"#{resource_type}_path", and finally in the spider's gem folder.
        # 
        # For example:
        # 
        # find_resource(:views, 'abc/my_view', nil, [MyApp]) will look into:
        # * /home/views/my_app/abc/my_view.shtml
        # * /home/views/apps/my_app/views/abc/my_view.shtml
        # * /lib/spider/views/abc/my_view.shtml
        # 
        # 
        # @param [Symbol] resource_type
        # @param [String] path
        # @param [String] cur_path Current path: if set, will be used to resolve relative paths
        # @param [Array] owner_classes An Array of Classes, which must respond to .app (i.e., they must belong to an App). 
        #                              If set, will be used to determine the apps to look into.
        # @param [Array] search_paths An Array of additional paths to look inside
        # @return [Resource]

        def find_resource(resource_type, path, cur_path=nil, owner_classes=nil, search_paths=[])
            owner_classes = [owner_classes] unless owner_classes.is_a?(Enumerable)
            
            def first_found(extensions, path)
                extensions.each do |ext|
                    full = path
                    full += '.'+ext if ext
                    return full if File.file?(full)
                end
                return nil
            end
            
            search_paths ||= []
            owner_classes.each do |owner_class| # FIXME: refactor
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
                        return Resource.new(first_found(extensions, File.dirname(cur_path)+path[1..-1]), owner_class)
                    elsif (path[0..2] == '../')
                        return Resource.new(first_found(extensions, File.dirname(File.dirname(cur_path))+path[2..-1]), owner_class)
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
                elsif owner_class.is_a?(Spider::Home)
                    app = owner_class
                elsif owner_class <= Spider::App || owner_class == Spider
                    app = owner_class
                else
                    app = owner_class.app if (owner_class && owner_class.app)
                end
                return Resource.new(cur_path+'/'+path, owner_class) if cur_path && File.file?(cur_path+'/'+path) # !app
                raise "Can't find owner app for resource #{path}" unless app
                search_locations = resource_search_locations(resource_type, app)
                search_paths.each do |p|
                    p = [p, owner_class] unless p.is_a?(Array)
                    search_locations << p
                end
                search_locations.each do |p|
                    found = first_found(extensions, p[0]+'/'+path)
                    next if found == cur_path
                    definer = path_app || p[1]
                    return Resource.new(found, definer) if found
                end
            end
            resource_type, path, cur_path=nil, owner_classes=nil, search_paths
            return Resource.new(path)
        end
        
        # @param [Symbol] resource_type
        # @param [Spider::App] the App who owns the resource
        # @return [Array] An array of places to look for resources of type resource_type belonging to app
        def resource_search_locations(resource_type, app=nil)
            resource_config = @resource_types[resource_type]
            resource_rel_path = resource_config[:path]
            app_rel_path = app && app.respond_to?(:relative_path) ? app.relative_path : nil
            search_locations = []
            unless Spider.conf.get('resources.disable_custom')
                root_search = File.join(Spider.paths[:root], resource_rel_path)
                root_search = File.join(root_search, app_rel_path) if app_rel_path
                # unless cur_path && cur_path == File.join(root_search, path)
                search_locations = [[root_search, @home]]
                # end
            end
            if app
                if app.respond_to?("#{resource_type}_path")
                    search_locations << [app.send("#{resource_type}_path"), app]
                else
                    search_locations << [File.join(app.path, resource_rel_path), app]
                end
                if Spider.runmode == 'test'
                    search_locations << [File.join(app.path, 'test', resource_rel_path), app]
                end
            end
            spider_path = File.join($SPIDER_PATH, resource_rel_path)
            search_locations << [spider_path, self]
            search_locations
        end
        
        # Returns an Array of all resources of a certain type
        # @param [Symbol] resource_type
        # @param [owner_class] the owner of the resource (must respond to .app)
        # @param [String] start A subfolder to start looking from
        # @params [Array] An array of additional places to search
        # @return [Array] An array of resources
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
        
        # See also {find_resource}
        # @param [Symbol] resource_type
        # @param [String] path
        # @param [String] cur_path Current path: if set, will be used to resolve relative paths
        # @param [Array] owner_classes An Array of Classes, which must respond to .app (i.e., they must be inside an app). 
        #                              If set, will be used to determine the apps to look into.
        # @param [Array] search_paths An Array of additional paths to look inside
        # @return [String|nil] the path of the found Resource, or nil if not found
        def find_resource_path(resource_type, path, cur_path=nil, owner_classes=nil, search_paths=[])
            res = find_resource(resource_type, path, cur_path, owner_classes, search_paths)
            return res ? res.path : nil
        end
        
        
        # Source file management


        # @private
        # Lists all sources inside a path.
        # @param [String] path
        # @return [void]
        #-- TODO: fix or remove
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


        # @private
        # Reloads all application inside a folder.
        # @return [void]
        #-- TODO: fix or remove
        def relo
            ad_sources_in_dir(dir)
            self.sources_in_dir(dir).each do |file|
                load(file)
            end
        end

        # @private
        # Reloads all application sources.
        # @return [void]
        #-- TODO: fix or remove
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
         
        # Terminates the current process and starts a new one
        # @return [void]
        def respawn!
            require 'rbconfig'
            Spider.logger.info("Restarting")
            ruby = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name']).sub(/.*\s.*/m, '"\&"')
            Spider.main_process_shutdown
            return if $SPIDER_NO_RESPAWN
            cmd = $SPIDER_SCRIPT || $0
            args = $SPIDER_PROC_ARGS || ARGV
            Spider.logger.debug("CWD: #{Dir.pwd}")
            if RUBY_PLATFORM =~ /win32|mingw32/
                start_cmd = "start cmd /C #{ruby} #{cmd} #{args.join(' ')}"
                Spider.logger.debug(start_cmd)
                IO.popen(start_cmd)
                sleep 5
            else
                start_cmd = "#{ruby} #{cmd} #{args.join(' ')}"
                Spider.logger.debug(start_cmd)
                exec(start_cmd)
            end
        end
        
        # Sets the current runmode.
        # 
        # Note: the runmode can't be changed when set; the method will raise an error if trying to 
        # set a runmode when one is already set.
        # @param [String] mode
        # @return [void]
        def runmode=(mode)
            raise "Can't change runmode" if @runmode
            @runmode = mode
            @configuration.include_set(mode)
            if Spider.conf.get('debugger.start') || File.exists?(File.join($SPIDER_RUN_PATH,'tmp', 'debug.txt'))
                init_debug
                debug_txt = File.join($SPIDER_RUN_PATH,'tmp', 'debug.txt')
                if File.exists?(debug_txt)
                    File.delete(debug_txt)
                end
            end
            Spider.paths[:var] = File.join(Spider.paths[:var], mode) if mode != 'production'
            Bundler.require(:default, @runmode.to_sym) if defined?(Bundler)
        end

        # Starts the debugger (ruby-debug, or Pry if debugger.pry configuration is true)
        def init_debug
            if Spider.conf.get('debugger.pry')
                begin
                    init_pry_debug
                rescue Exception
                    init_ruby_debug
                end
            else
                init_ruby_debug
            end
        end

        # @private
        # Inits the pry debugger
        # @return [void]
        def init_pry_debug
            require 'pry'
            require 'pry-nav'
            require 'pry-stack_explorer'
            if File.exists?(File.join($SPIDER_RUN_PATH,'tmp', 'debug.txt'))
                require 'pry-remote'
            end
            Pry::Commands.alias_command "l=", "whereami"
        end
        
        # @private
        # Inits ruby-debug
        # @return [void]
        def init_ruby_debug
            begin
                require 'ruby-debug'
                if File.exists?(File.join($SPIDER_RUN_PATH,'tmp', 'debug.txt'))
                    Debugger.wait_connection = true
                    Debugger.start_remote
                else
                    Debugger.start
                end
            rescue LoadError, RuntimeError => exc
                msg = _('Unable to start debugger. Ensure ruby-debug is installed (or set debugger.start to false).')
                Spider.output(exc.message)
                Spider.output(msg)
            end
        end
        
        # @return [Locale::Tag] The current locale
        def locale
            begin
                @current_locale = Locale.current[0]
            rescue
                # There are problems with subsequent requests on Windows, 
                # so use cached locale if Locale.current fails
                l = @current_locale
                l ||= Locale::Tag.parse(Spider.conf.get('locale')) if Spider.conf.get('locale')
                l ||= Locale::Tag.parse('en')
            end
        end
        
        # @param [Locale::Tag]
        # @return [Spider::I18n::Provider] A provider for the given locale
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

        # @return [bool] True if spider is running in interactive mode (i.e. run from the command line), false otherwise
        def interactive?
            !!$SPIDER_INTERACTIVE
        end
        
        # Outputs a string, to the console or to log
        # @param [String] str String to output
        # @param [Symbol] level Log level
        # @return [void]
        def output(str, level=:INFO)
            use_log = !Spider.interactive? && @logger_started
            if use_log
                @logger.log(level, str)
            else
                str = "#{level}: #{str}" if level == :ERROR
                puts str
            end
        end
        
    end
    
end
