require 'fileutils'
require 'tsort'

module Spider
    
    module App
        
        def self.included(mod)
            mod.module_eval do
                
                include Spider::DataTypes
                
                class << self
                    attr_reader :id, :path, :pub_path, :test_path, :setup_path, :widgets_path, :views_path, :tags_path, :models_path
                    attr_reader :short_name, :route_url, :label, :version
                    attr_accessor :short_prefix
                    attr_reader :command
                    attr_reader :spec
                    attr_reader :gettext_dirs, :gettext_extensions, :gettext_parsers
                    
                    def init
                        unless @path
                            file = caller[1].split(':')[0]
                            dir = File.dirname(file)
                            @path = dir
                        end
                        @path = File.expand_path(@path)
                        @short_name ||= Inflector.underscore(self.name).gsub(File::SEPARATOR, '_')
                        @dotted_name = Inflector.underscore(self.name).gsub(File::SEPARATOR, '.')
                        @pub_path ||= File.join(@path, 'public')
                        @test_path ||= File.join(@path, 'test')
                        @setup_path ||= File.join(@path, 'setup')
                        @models_path ||= File.join(@path, 'models')
                        @widgets_path ||= File.join(@path, 'widgets')
                        @views_path ||= File.join(@path, '/views')
                        @tags_path ||= File.join(@path, 'tags')
                        @version = Gem::Version.new(@version.to_s) if @version && !@version.is_a?(Gem::Version)
                        spec_path = File.join(@path, "#{@short_name}.appspec")
                        load_spec(spec_path) if File.exists?(spec_path)
                        @route_url ||= Inflector.underscore(self.name)
                        @label ||= @short_name.split('_').each{ |p| p[0] = p[0].chr.upcase }.join(' ')
                        @gettext_parsers ||= []
                        @gettext_dirs ||= ['lib','bin','controllers','models','views','widgets','public']
                        @gettext_extensions ||= ['rb','rhtml','shtml','js']
                        
                        find_tags
                    end
                    
                    def request_url
                        if u = Spider.conf.get("#{@dotted_name}.url") 
                            return u
                        end
                        Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping('/'+@route_url)
                    end
                    alias :url :request_url
                    
                    def http_url(action=nil)
                        if u = Spider.conf.get("#{@dotted_name}.http_url") 
                            if action
                                u += '/' if u[-1].chr != '/'
                                u += action
                            end
                            return u 
                        end
                        return nil unless Spider.site
                        u = "http://#{Spider.site.domain}"
                        u += ":#{Spider.site.port}" unless Spider.site.port == 80
                        u += url
                        u += "/"+action.to_s if action
                        u
                    end
                    
                    def https_url
                        return nil unless Spider.site && Spider.site.ssl?
                        u = "https://#{Spider.site.domain}"
                        u += ":#{Spider.site.ssl_port}" unless Spider.site.ssl_port == 443
                        u += url
                        u
                    end
                    
                    def http_s_url
                        return https_url if Spider.site && Spider.site.ssl?
                        return http_url
                    end
                    
                    def pub_url
                        if Spider.conf.get('static_content.mode') == 'publish'
                            Spider::HomeController.pub_url+'/apps/'+self.short_name
                        else
                            request_url+'/public'
                        end
                    end
                    
                    def pub_url!
                        request_url+'/public'
                    end
                    
                    def controller
                        #controllers = self.const_get(:Controllers)
                        if (!@controller || !const_defined?(@controller))
                            @controller = :AppController
                            return const_set(@controller, Spider::PageController.clone)
                            
                        end
                        return const_get(@controller)
                    end
                    
                    def models(container=nil)
                        container ||= self
                        mods = []
                        container.constants.each do |c|
                            begin
                                mods += get_models(container.const_get(c))
                            rescue LoadError
                            end
                        end
                        return mods
                    end
                    
                    def get_models(m)
                        ms = []
                        if m.respond_to?(:subclass_of?) && m.subclass_of?(Spider::Model::BaseModel)
                             ms << m
                             m.constants.each do |c|
                                 sub_mod = m.const_get(c)
                                 next unless sub_mod.is_a?(Module)
                                 next if !sub_mod.subclass_of?(Spider::Model::BaseModel) || sub_mod.app != self
                                 next if sub_mod == m
                                 ms += get_models(sub_mod)
                             end
                         elsif (m.is_a?(Module) && !m.is_a?(Class))
                             return models(m)
                         end
                         return ms
                    end
                    
                    def controllers
                        self.constants.map{ |m| const_get(m) }.select{ |m| m.subclass_of? Spider::Controller }
                    end
                    
                    def find_resource(type, name, cur_path=nil)
                        Spider.find_resource(type, name, cur_path, self)
                    end

                    def find_resource_path(type, name, cur_path=nil)
                        res = Spider.find_resource(type, name, cur_path, self)
                        return res ? res.path : nil
                    end
                    
                    
                    def register_tag(tag, obj)
                        @tags ||= {}
                        @tags[tag] = obj
                    end
                    
                    def get_tag(tag)
                        @tags[tag]
                    end
                    
                    def has_tag?(tag)
                        return false unless @tags
                        @tags[tag] ? true : false
                    end
                    
                    def route(path, dest=nil, options=nil)
                        self.controller.route(path, dest, options)
                    end
                    
                    def relative_path
                        if (@path.index(Spider.paths[:apps]) == 0)
                            return @path[Spider.paths[:apps].length+1..-1]
                        else
                            return @path[Spider.paths[:core_apps].length+1..-1]
                        end
                    end
                    
                    def find_tags
                        return unless File.directory?(@tags_path)
                        Dir.new(@tags_path).each do |entry|
                            next if entry[0].chr == '.'
                            next unless File.extname(entry) == '.erb'
                            name = File.basename(entry, '.erb')
                            klass = Spider::Tag.new_class(File.join(@tags_path, entry))
                            const_set(Spider::Inflector.camelize(name).to_sym, klass)
                            #Spider::Logger.debug("REGISTERED TAG #{name}, #{klass}")
                            register_tag(name, klass)
                        end
                    end

                    def app
                        self
                    end
                    
                    def req(*list)
                        list.each do |file|
                            require @path+'/'+file
                        end
                    end
                    
                    def installed_version_path
                        File.join(Spider.paths[:var], 'apps', self.name, 'installed_version')
                    end
                    
                    def installed_version
                        FileUtils.mkpath(File.dirname(installed_version_path))
                        return unless File.exist?(installed_version_path)
                        return Gem::Version.new(IO.read(installed_version_path))
                    end
                    
                    def installed_version=(version)
                        FileUtils.mkpath(File.dirname(installed_version_path))
                        version = Gem::Version.new(version) unless version.is_a?(Gem::Version)
                        File.open(installed_version_path, 'w') do |f|
                            f << version.to_s
                        end
                    end
                    
                    def load_spec(spec_path=nil)
                        @spec = AppSpec.load(spec_path)
                        @spec.app_id = File.basename(spec_path, 'appsec') unless @spec.app_id
                        @version = @spec.version if @spec.version
                    end
                    
                    def gettext_parsers
                        @gettext_parsers ||[]
                    end
                    
                    
                    
                end

            end
            mod.init()
            Spider::add_app(mod)
        end
        
        class AppSpec
            @@attributes = []
            
            def self.attribute(name, options={})
                @@attributes << name
                str = <<END_OF_EVAL
                def #{name}(val=nil)
                    @#{name} = val if val
                    @#{name} ||= #{options[:default].inspect}
                    @#{name}
                end
                alias :#{name}= :#{name}
END_OF_EVAL
                class_eval(str)
            end
            
            def self.array_attribute(name, options={})
                @@attributes << name
                str = <<END_OF_EVAL
                def #{name}(*vals)
                    @#{name} = vals unless vals.empty?
                    @#{name} ||= []
                    @#{name}
                end
END_OF_EVAL
                class_eval(str)
            end
            
            attribute :app_id
            attribute :name
            attribute :description
            attribute :git_repo
            attribute :git_repo_rw
            array_attribute :authors
            array_attribute :depends
            array_attribute :depends_optional
            array_attribute :load_after
            array_attribute :can_use
            array_attribute :gems
            array_attribute :gems_optional
            attribute :version
            attribute :app_server
            
            def id(val=nil)
                self.app_id(val)
            end
                        
            def version(val=nil)
                @version = Gem::Version.new(val) if val
                @version
            end

            def author(val = nil)
                @authors = [val] if val
                @authors ||= []
                @authors[0]
            end
            
            def load(spec_path)
                self.eval(File.read(spec_path), spec_path)
                self
            end
            
            def self.load(spec_path)
                self.new.load(spec_path)
            end
            
            def eval(text, path=nil)
                self.instance_eval(text)
                self
            end
            
            def self.eval(text, path=nil)
                self.new.eval(text, path)
            end
            
            def to_h
                h = {}
                @@attributes.each do |a|
                    h[a] = send(a)
                end
                h
            end
            
            def to_json(opts=nil)
                to_h.to_json
            end
            
            def self.parse_hash(h)
                spec = self.new
                h.each do |key, value|
                    if value.is_a?(Array)
                        spec.send(:"#{key}", *value)
                    else
                        spec.send(:"#{key}", value)
                    end
                end
                spec
            end

            def get_runtime_dependencies
                return self.load_after if @load_after
                return self.depends + self.depends_optional
            end

            def gems_list
                self.gems.map{ |g| g.is_a?(Array) ? g.first : g }
            end

            def gems_optional_list
                self.gems_optional.map{ |g| g.is_a?(Array) ? g.first : g }
            end

        end
        
        class RuntimeSort
            
            def initialize
                @apps = []
                @apps_hash = {}
            end
            
            def add(app)
                @apps << app
                if app.is_a?(AppSpec)
                    @apps_hash[app.app_id] = app
                else
                    @apps_hash[app] = app
                end
            end
            
            def tsort_each_node(&block)
                @apps.each(&block)
            end
            
            def tsort_each_child(node, &block)
                return unless node.is_a?(AppSpec)
                node.get_runtime_dependencies.map{ |a| @apps_hash[a] }.each(&block)
            end
            
            def tsort
                sorted = super
                sorted.map{ |a| a.is_a?(AppSpec) ? a.app_id : a }
            end
            
            include TSort
            
        end
        
    end
    
end
