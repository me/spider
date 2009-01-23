require 'yaml'


module Spider
    
    class Configuration
        attr_accessor :options, :current_set
        @@options = {}
        
        def initialize(prefix='')
            prefix = prefix[1..prefix.length-1] if (prefix[0..0] == '.')
            @prefix = prefix
            @options = @@options
            # TODO: add exception if prefix not defined (i.e. if o[part] does not exist)
            @options = prefix.split('.').inject(@options){ |o, part| o[part] } if prefix != ''
            @sets = {}
            @current_set = 'default'
            @sets['default'] = self
            @values = {}
        end
        
        def global_options
            @@options
        end

        
        def []=(key, val)
            raise ConfigurationException.new(:invalid_option), _("%s is not a configuration option") % key unless @options && @options[key]
            process = @options[key][:params][:process]
            val = process.call(val) if (process)
            first, rest = key.split('.', 2)
            @values[key] = val
            action = @options[key][:params][:action]
            action.call(val) if (action)
        end
        
        def sub_conf(name)
            @values[name] ||= Configuration.new(@prefix+".#{name}")
        end
        
        def set(key, val)
            first, rest = key.split('.', 2)
            if rest
                begin
                    sub_conf(first).configure(rest, val)
                rescue ConfigurationException # raise only top level exception
                    raise ConfigurationException.new(:invalid_option), _("%s is not a configuration option") % key
                end
            else
                if (val.is_a?(Hash) && @options[key] && @options[key][:params][:type] != Hash)
                    @values[key] ||= Configuration.new(@prefix+".#{key}")
                    val.each { |k, v| self[key][k.to_s] = v }
                else
                    self[key] = val
                end
            end
        end
        alias :configure :set
        
        
        def [](key)
            Spider::Logger.debug("Getting CONF #{key}")
            val = @values[key]
            if (!val && @options[key] && @options[key][:params][:default])
                default = @options[key][:params][:default]
                Spider::Logger.debug("DEFAULT: #{default}")
                val = (default.class == Proc) ? default.call() : default
            end
            return val
        end
        
        def each
            @values.each do |key, val|
                if (val.class == Configuration)
                    val.each do |k, v|
                        yield key+'.'+k, v
                    end
                else
                    yield key, val
                end
            end
        end
        
        # Sets an allowed configuration option
        # Possible params are:
        # -:default     the default value for the option; if it is a proc, it will be called
        # -:choiches    an array of allowed values
        # -:type        parameter type; can be one of int, string, bool
        def config_option(name, description, params={})
            #debugger
            name = name.to_s
            o = @options
            first, rest = name.split('.', 2)
            while (rest)
                o = (o[first] ||= {})
                first, rest = rest.split('.', 2)
            end
            o[first] = {:description => description, :params => params}
        end
        

        
        def get(key)
#            debugger
            key = key.to_s
            first, rest = key.split('.', 2)
            if rest
                v = sub_conf(first)
                @values[first].config(rest)
            else
                self[key]
            end
        end
        
        # FIXME: temporarely allows old behaviour 
        def config(key=nil)
            return self unless key
            get(key)
        end
        
        def create_prefix(name)
            first, rest = name.split('.', 2)
            @options[first] ||= {}
            v = sub_conf(first)
            v.create_prefix(rest) if rest
        end
        
        def configure_set(name, values)
            s = (@sets[name] ||= Configuration.new(@prefix))
            s.options = @options
            values.each { |k, v| s.configure(k, v) }
        end
        
        def include_set(name)
            return if (self == @sets[name])
            ( @sets[name] ||= Configuration.new(@prefix) ).each do |key, val|
                configure(key, val)
            end
            @sets[name] = self
        end
        
        def set_included?(name)
            @sets[name] == self
        end

            
        def load_yaml(file)
            y = YAML::load_file(file)
            raise ConfigurationException(:yaml), "Can't parse configuration file #{file}" unless y
            y.each do |key, val|
                case key
                when /set (.+)/
                    configure_set($1, val)
                else
                    configure(key, val)
                end
            end
        end
        
    end
    
    
    class ConfigurationException < Exception
        attr_reader :type
        
        def initialize(type)
            @type = type
            super
        end
        
    
        
    end
    
end