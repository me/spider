
$SPIDER_PATH = File.expand_path(File.dirname(__FILE__)+'/..')
$SPIDER_LIB = $SPIDER_PATH+'/lib'
#$:.push($SPIDER_LIB+'/spiderfw')
$:.push(Dir.pwd)
#p $:

require 'rubygems'
require 'find'
require 'spiderfw/autoload'
require 'spiderfw/requires'

require 'spiderfw/version'

$SPIDER_VERSION = Spider.version

module Spider
    
    class << self
        # Everything here must be thread safe!!!
        attr_reader :logger, :controller, :apps, :server, :configuration
        alias :config :configuration
        
        
        def init
            @paths = {}
            @apps ||= {}
            @root = Dir.pwd
            @logger = Spider::Logger
            @logger.open(STDERR, :DEBUG)
#            @controller = Controller
            @server = {}
            @configuration = Configuration.new
            setup_paths(@root)
            load_configuration($SPIDER_PATH+'/config')
            load_configuration(@root+'/config')


            if (Spider.config['debugger.start'])

            end
            init_apps
            routes_file = "#{@paths[:config]}/routes.rb"
            if (File.exist?(routes_file))
                load(routes_file)
            end
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
            @paths[:apps] = root+'/apps'
            @paths[:config] = root+'/config'
            @paths[:layouts] = root+'/layouts'
        end
        
        def init_apps
            Find.find(@paths[:apps]) do |path|
                if (File.basename(path) == '_init.rb')
                    require(path)
                    Find.prune
                elsif (File.exist?("#{path}/_init.rb"))
                    require("#{path}/_init.rb")
                    Find.prune
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


# TMP

def _(string, *arguments)
    if arguments && arguments.length > 0
        string.%(arguments) 
    else
        string
    end
end