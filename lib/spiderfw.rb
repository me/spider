
$SPIDER_PATH = File.expand_path(File.dirname(__FILE__)+'/..')
$SPIDER_LIB = $SPIDER_PATH+'/lib'
$SPIDER_RUN_PATH = Dir.pwd
ENV['GETTEXT_PATH'] += ',' if (ENV['GETTEXT_PATH'])
ENV['GETTEXT_PATH'] ||= ''
ENV['GETTEXT_PATH'] += $SPIDER_PATH+'/data/locale,'+$SPIDER_RUN_PATH+'/data/locale'
#$:.push($SPIDER_LIB+'/spiderfw')
$:.push(Dir.pwd)

$:.push($SPIDER_PATH)
#p $:


require 'rubygems'
require 'find'
require 'spiderfw/autoload'
require 'spiderfw/requires'

require 'spiderfw/version'

module Spider
    
    class << self
        # Everything here must be thread safe!!!
        attr_reader :logger, :controller, :apps, :server
        
        def init(force=false)
            return if @init_done && !force
            @paths = {}
            @apps_to_load = []
            @apps ||= {}
            @root = Dir.pwd
            @logger = Spider::Logger
            @logger.open(STDERR, :DEBUG)
#            @controller = Controller
            @server = {}
            @paths[:spider] = $SPIDER_PATH
            setup_paths(@root)
            load_configuration($SPIDER_PATH+'/config')
            load_configuration(@root+'/config')
            load(@root+'/init.rb') if File.exist?(@root+'/init.rb')
            GetText.locale = config.get('locale')

            # if (Spider.config['debugger.start'])
            #     Debugger.start
            # end
            init_apps
            @init_done=true
            # routes_file = "#{@paths[:config]}/routes.rb"
            # if (File.exist?(routes_file))
            #     load(routes_file)
            # end
            # else
            #     @apps.each do |name, app|
            #         @controller.route('/'+app.name.gsub('::', '/'), app.controller_class, :ignore_case => true)
            #     end
            # end
        end
        
    
        def setup_paths(root)
            setup_paths_full(root)
        end
    
        def setup_paths_full(root)
            @paths[:root] = root
            @paths[:apps] = root+'/apps'
            @paths[:config] = root+'/config'
            @paths[:layouts] = root+'/layouts'
            @paths[:var] = root+'/var'
            @paths[:certs] = @paths[:config]+'/certs'
            @paths[:tmp] = root+'/tmp'
        end
        
        def paths
            @paths
        end
        
        def load_apps(*l)
            l.each { |app| @apps_to_load << app }
        end
        
        def load_all_apps
            Find.find(@paths[:apps]) do |path|
                if (File.basename(path) == '_init.rb')
                    @apps_to_load << File.dirname(path)[0..$SPIDER_RUN_PATH+'/apps/'.length-1]
                    Find.prune
                elsif (File.exist?("#{path}/_init.rb"))
                    @apps_to_load << path[0..$SPIDER_RUN_PATH+'/apps/'.length-1]
                    Find.prune
                end
            end
        end
        
        def init_apps
            Logger.debug("Loading apps:")
            Logger.debug(@apps_to_load)
            @apps_to_load.uniq.each do |app|
                if (File.exist?($SPIDER_RUN_PATH+'/apps/'+app) && File.exist?($SPIDER_RUN_PATH+'/apps/'+app+'/_init.rb'))
                    require($SPIDER_RUN_PATH+'/apps/'+app+'/_init.rb')
                elsif (File.exist?($SPIDER_PATH+'/apps/'+app) && File.exist?($SPIDER_PATH+'/apps/'+app+'/_init.rb'))
                    require($SPIDER_PATH+'/apps/'+app+'/_init.rb')                    
                else
                    Logger.error("App #{app} not found")
                end
            end
        end
        
        def add_app(mod)
            @apps[mod.name] = mod
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
        
    end
    
end

# load instead of require for reload_sources to work correctly
load 'spiderfw/config/options/spider.rb'
Spider::init()
