require 'yaml'


module Spider
    
    class Configuration
        attr_accessor :options, :current_set, :hash_key
        @@options = {}
        @@lang_aliases = {}
        
        def initialize(prefix='')
            prefix = prefix[1..prefix.length-1] if (prefix[0..0] == '.')
            @prefix = prefix
            @options = @@options
            if prefix != ''
                cur = ''
                @options = prefix.split('.').inject(@options) do |o, part|
                    cur += '.' unless cur.empty?; cur += part
                    config_option(cur, '__auto__') unless o[part]
                    #raise ConfigurationException.new(:invalid_option), _("%s is not a configuration option") % cur unless o[part]
                    o[part]
                end
            end
            @sets = {}
            @current_set = 'default'
            @sets['default'] = self
            @values = {}
            @hash_key = nil
        end
        
        def global_options
            @@options
        end
        
        def conf_alias(name, aliases=nil)
            if (aliases)
                aliases.each do |locale, translated|
                    @@lang_aliases[locale] ||= {}
                    @@lang_aliases[locale][translated] = name
                end
            elsif (name.is_a?(Hash))
                name.each do |locale, aliases|
                    @@lang_aliases[locale] ||= {}
                    aliases.each do |name, translated|
                        @@lang_aliases[locale][translated] = name
                    end
                end
            end
        end

        
        def []=(key, val)
            key = translate_key(key)
            config_option(key, "__auto__") unless @options[key]
            #raise ConfigurationException.new(:invalid_option), _("%s is not a configuration option") % key unless @options && @options[key]
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
        
        def translate_key(key)
            if (!@options[key])
                locale = Spider.locale
                locale = $1 if locale =~ /^([^@\.]+)[@\.].+/
                a = @@lang_aliases[locale][key] if @@lang_aliases[locale]
                return a.to_s if a
            end
            return key.to_s
        end
        
        def set(key, val)
            first, rest = key.split('.', 2)
            if rest
                first = translate_key(first)
                begin
                    sub_conf(first).configure(rest, val)
                rescue ConfigurationException # raise only top level exception
                    raise ConfigurationException.new(:invalid_option), _("%s is not a configuration option") % key
                end
            else
                key = translate_key(key)
                config_option(key, '__auto__') unless @options[key]
                if val.is_a?(Hash)
                    if (@options[key][:params] && @options[key][:params][:type] == :conf)
                        @values[key] ||= Configuration.new(@prefix+".#{key}") # FIXME: needed?
                        val.each do |h_key, h_val|
                            self[key][h_key] = Configuration.new(@prefix+".#{key}.x")
                            self[key][h_key].hash_key = h_key
                            h_val.each { |k, v| self[key][h_key].set(k, v) }
                        end
                    elsif (!@options[key][:params] || @options[key][:params][:type] != Hash) # sub conf
                        @values[key] ||= Configuration.new(@prefix+".#{key}")
                        val.each { |k, v| self[key][k.to_s] = v }
                    else
                        self[key] = val
                    end
                else
                    val = convert_val(@options[key][:params][:type], val) if (@options[key][:params][:type])
                    self[key] = val
                end
            end
        end
        alias :configure :set
        
        def convert_val(type, val)
            case type.name
            when 'String'
                val = val.to_s
            when 'Symbol'
                val = val.to_sym
            when 'Fixnum'
                val = val.to_i
            when 'Float'
                val = val.to_f
            end
            return val
        end
        
        
        def [](key)
            key = translate_key(key)
            val = @values[key]
            
            if (val.nil? && @options[key] && @options[key][:params][:default])
                default = @options[key][:params][:default]
                val = default
                if (default.class == Proc)
                    val = @hash_key ? default.call(@hash_key) : default.call
                end
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
        def config_option(name, description, params={}, &proc)
            name = name.to_s
            if (params.empty? && description.is_a?(Hash))
                params = description
                description = ''
            end
            o = @options
            params[:action] ||= proc if proc
            first, rest = name.split('.', 2)
            while (rest)
                o = (o[first] ||= {})
                first, rest = rest.split('.', 2)
            end
            o[first] = {:description => description, :params => params}
        end
        

        
        def get(key)
            key = key.to_s
            first, rest = key.split('.', 2)
            if rest
                first = translate_key(first)
                v = sub_conf(first)
                if (@values[first].is_a?(Configuration))
                    return @values[first].config(rest)
                elsif (@values[first].is_a?(Hash) || @values[first].is_a?(Array))
                    return @values[first][rest]
                end
            else
                key = translate_key(key)
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
            values.each do |k, v|
                s.configure(k, v)
            end
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
        
        def to_hash
            return @values.clone
        end
        
    end
    
    class ConfigurationException < Exception
        attr_reader :type
        
        def initialize(type)
            @type = type
            super
        end
        
    end    
    
    # Spider
    @configuration = Configuration.new
    class <<self
        attr_reader :configuration
        alias :config :configuration
        alias :conf :configuration
    end
    def self.config_option(*params)
        @configuration.config_option(*params)
    end
    def self.conf_alias(name, al=nil)
        @configuration.conf_alias(name, al)
    end
    
    
end