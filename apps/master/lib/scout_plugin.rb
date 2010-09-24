require 'yaml'
require 'scout'

module Spider; module Master
    
    class ScoutPlugin
        attr_reader :id
        
        def initialize(id)
            @id = id
            @class_name = Spider::Inflector.camelize(@id)
            @info = ScoutPluginInfo.load(:id => id)
            @path = nil
            @rb_path = nil
            @plugin_class = nil
        end
        
        def name
            return @info.name if @info
            Spider::Inflector.upcasefirst(@id.gsub(/_+/, ' '))
        end
        
        
        def find
            base = Spider.conf.get('master.scout_plugins_path')
            full_path = File.join(base, @id)
            raise "Scout Plugin #{id} not found" unless File.directory?(full_path)
            @path = full_path
            @rb_path = File.join(@path, @id)+".rb"
            raise "Scout Plugin #{id} not found" unless File.file?(@rb_path)
        end
        
        def load
            return @plugin_class if @plugin_class
            find unless @path
            require @rb_path
            @plugin_class = Object.const_get(@class_name)
        end
        
        def options
            return @options if @options
            load
            return {} unless @plugin_class.const_defined?("OPTIONS")
            @options = YAML.load(@plugin_class.const_get("OPTIONS"))
            @options.each do |id, opt|
                opt["name"] ||= id
            end
            @options
        end
        
        def yaml_data
            return @yaml if @yaml
            find unless @path
            yaml_path = File.join(@path, "#{@id}.yml")
            return @yaml = {} unless File.file?(yaml_path)
            @yaml = YAML::load_file(yaml_path)
        end
        
        def read_code
            find unless @path
            File.read(@rb_path)
        end
        
        alias :data :yaml_data
        
        def metadata
            self.yaml_data["metadata"] || {}
        end
        
        def triggers
            self.yaml_data["triggers"] || []
        end
        
        
    end
    
    
end; end