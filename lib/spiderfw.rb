require 'rubygems'
require 'find'
require 'spiderfw/autoload'

require 'spiderfw/version'
$SPIDER_VERSION = Spider.version

$SPIDER_PATH = File.expand_path(File.dirname(__FILE__)+'/..')
$SPIDER_LIB = $SPIDER_PATH+'/lib'
$:.push(Dir.pwd)

module Spider
    
    class << self
        # Everything here must be thread safe!!!
        attr_reader :logger, :controller, :apps
        
        
        def init
            @paths = {}
            @apps = {}
            @root = Dir.pwd
            @logger = Spider::Logger.new
            @logger.open(STDERR, :DEBUG)
            @controller = Controller
            setup_paths(@root)
            init_apps
            routes_file = "#{@paths[:config]}/routes.rb"
            if (File.exist?(routes_file))
                load(routes_file)
            else
                @apps.each do |name, app|
                    @controller.route('/'+app.name.gsub('::', '/'), app.controller_class)
                end
            end
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
        
    end
    
end

Spider::init()

# TMP

def _(string, *arguments)
    if arguments && arguments.length > 0
        string.%(arguments) 
    else
        string
    end
end