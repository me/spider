require 'fileutils'
require 'tsort'

module Spider
    
    # The Spider::App module must be included in each apps' main module inside the
    # apps's _init.rb file.
    # 
    # Example: apps/my_app/_init.rb
    #
    #   module MyApp
    #       include Spider::App
    #   end
    #
    # It extends the including module, defining several variables and Class methods.
    # All variables are pre-set to defaults, but can be overridden by the including Module
    # (see {ClassMethods}).
    # 
    # The app's module can implement several lifecycle hooks (as Module methods):
    # * app_init: called during the framework's init phase
    # * app_startup: called when a server is started
    # * app_shutdown: called when a server is shut down
    module App
        
        # Methods set on the App main module.
        # All instance attributes will be set to default values, but can be overridden
        # by the module by setting the corresponding instance variable.
        # Example:
        # 
        #   module MyApp
        #       include Spider::App
        #       @controller = :MyController
        #       @label = 'My Application'
        #   end
        # 
        module ClassMethods
            
            # @return [String] filesystem path of the app
            attr_reader :path
            # @return [String] path of the 'public' folder
            attr_reader :pub_path
            # @return [String] path of the 'test' folder
            attr_reader :test_path
            # @return [String] path of the 'setup' folder
            attr_reader :setup_path
            # @return [String] path of the 'widgets' folder
            attr_reader :widgets_path
            # @return [String] path of the 'views' folder
            attr_reader :views_path
            # @return [String] path of the 'tags' folder
            attr_reader :tags_path
            # @return [String] path of the 'models' folder
            attr_reader :models_path
            # @return [String] name, without spaces
            attr_reader :short_name
            # @return [String] url from which the app will be routed
            attr_reader :route_url
            # @return [String] app
            attr_reader :label
            # @return [Gem::Version] app's version
            attr_reader :version
            # @return [String] prefix used to distinguish Database table
            attr_accessor :short_prefix
            # @return [AppSpec] the app's AppSpec
            attr_reader :spec
            # @return [Array] A list of directories to look for translations
            attr_reader :gettext_dirs
            # @return [Array] File extensions to parse for translations
            attr_reader :gettext_extensions
            # @return [Array] Additional GetText parasers to use
            attr_reader :gettext_parsers
            # @return [String] Gettext domain of the app. Defaults to the app short name
            attr_reader :gettext_domain
            

            # Initializes missing variables to default variables.
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
                @gettext_domain ||= @short_name
                
                find_tags
            end

            # @return [String] The apps' full_name or spec.name
            def full_name
                @full_name || self.spec.name
            end

            # @return [String] description or spec.description or name
            def description
                desc = @description || self.spec.description
                desc.blank? ? self.name : desc
            end
            
            # @return [String] The path used to access the application from the browser
            def request_url
                if u = Spider.conf.get("#{@dotted_name}.url") 
                    return u
                end
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping('/'+@route_url)
            end
            alias :url :request_url
            
            # @return [String] The full url used to access the application from the browser
            def http_url(action=nil)
                if u = Spider.conf.get("#{@dotted_name}.http_url") 
                    if action
                        u += '/' if u[-1].chr != '/'
                        u += action.to_s
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
            
            # The full url used to access the application from the browser, prefixed
            # with https
            # @return [String] 
            def https_url
                return nil unless Spider.site && Spider.site.ssl?
                u = "https://#{Spider.site.domain}"
                u += ":#{Spider.site.ssl_port}" unless Spider.site.ssl_port == 443
                u += url
                u
            end
            
            # @return [String] If the site supports SSL, returns the #https_url; otherwise, the #http_url
            def http_s_url
                return https_url if Spider.site && Spider.site.ssl?
                return http_url
            end
            
            # @return [String] The url to the app's public content. If the static_content.mode configuration
            # option is set to 'publish', the app's url inside the home is returned.
            def pub_url
                if Spider.conf.get('static_content.mode') == 'publish'
                    Spider::HomeController.pub_url+'/apps/'+self.short_name
                else
                    request_url+'/public'
                end
            end
            
            # @return [String] The url to the app's public content, inside the app's folder (ignoring publishing mode)
            def pub_url!
                request_url+'/public'
            end
            
            # @return [Spider::Controller] The apps' main Controller. 
            # If setting the instance variable, use a Symbol
            def controller
                if (!@controller || !const_defined?(@controller))
                    @controller = :AppController
                    return const_set(@controller, Spider::PageController.clone)
                    
                end
                return const_get(@controller)
            end
            
            # @return [Array] An array of all the {BaseModel} subclasses defined inside the module
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
            
            # @return [Array] An array of all the {Controller} subclasses defined inside the module
            def controllers
                self.constants.map{ |m| const_get(m) }.select{ |m| m.subclass_of? Spider::Controller }
            end
            
            # Finds a resource (see {Spider.find_resource})
            # @return [Spider::Resource]
            def find_resource(type, name, cur_path=nil)
                Spider.find_resource(type, name, cur_path, self)
            end

            # Finds the path of the resource (see {Spider#find_resource})
            # @return [String]
            def find_resource_path(type, name, cur_path=nil)
                res = Spider.find_resource(type, name, cur_path, self)
                return res ? res.path : nil
            end
            
            # Calls route on the app's controller (see {Dispatcher.route}).
            # @return [nil]
            def route(path, dest=nil, options=nil)
                self.controller.route(path, dest, options)
            end
            
            # @return [String] The app's path, relative to its container (the home or the Spider lib)
            def relative_path
                if Spider.paths[:apps] && @path.index(Spider.paths[:apps]) == 0
                    return @path[Spider.paths[:apps].length+1..-1]
                else
                    return @path[$SPIDER_PATHS[:core_apps].length+1..-1]
                end
            end

            # @return [String] The path to the apps' container (the home or the Spider lib)
            def base_path
                if Spider.paths[:apps] && @path.index(Spider.paths[:apps])
                    Spider.paths[:apps]
                else
                    $SPIDER_PATH
                end
            end


            def route_path(action='')
                path = Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping('/'+@route_url)
                action = action[1..-1] if action[0].chr == '/'
                [path, action].reject{ |p| p.blank? }.join('/')
            end


            # Convenience method: since all classes inside the app have an #app method,
            # the App itself has it too
            # @return [self] 
            def app
                self
            end
            
            # Require files inside the App's path
            #
            # Can accept either a list of files to require, relative to the app's path; or, a Hash
            # containing arrays for keys corresponding to folders inside app (e.g. :models, :controllers)
            #
            # If an Hash is provided, will load files in the order :lib, :models, :widgets, :controllers, followed
            # by any additional keys, in the order they are defined in the Hash (under Ruby 1.9.x), or in random order (Ruby 1.8.x)
            # @param [Hash|file1,file2,...] files to require
            # @return [nil]
            def req(*list)
                do_require = lambda{ |f| 
                    Kernel.require File.join(@path, f) 
                }
                if list.first.is_a?(Hash)
                    hash = list.first
                    load_keys = ([:lib, :models, :widgets, :controllers] + hash.keys).uniq
                    load_keys.each do |k|
                        if hash[k].is_a?(Array)
                            hash[k].each{ |file| 
                                if k == :widgets
                                    file = File.join(file, file)
                                end
                                file = File.join(k.to_s, file)
                                do_require.call(file) 
                            }
                        end
                    end
                else
                    list.each do |file|
                        do_require.call(file)
                    end
                end
            end

            alias :app_require :req            

            
            # Returns the currently installed version of an app
            # @return [Gem::Version]
            def installed_version
                FileUtils.mkpath(File.dirname(installed_version_path))
                return unless File.exist?(installed_version_path)
                return Gem::Version.new(IO.read(installed_version_path))
            end

            # Sets the currently installed version of an app
            # @param [String|Gem::Version] version
            # @return [nil]
            def installed_version=(version)
                FileUtils.mkpath(File.dirname(installed_version_path))
                version = Gem::Version.new(version) unless version.is_a?(Gem::Version)
                File.open(installed_version_path, 'w') do |f|
                    f << version.to_s
                end
            end
            
            # Loads the app's .spec file
            # @param [String] spec_path 
            # @return [AppSpec]
            def load_spec(spec_path=nil)
                @spec = AppSpec.load(spec_path)
                @spec.app_id = File.basename(spec_path, 'appsec') unless @spec.app_id
                @version = @spec.version if @spec.version
                @spec
            end
            
            # A list of tettext parsers to use for the app
            # @return [Array]
            def gettext_parsers
                @gettext_parsers || []
            end

            # Register the pointer from a widget tag to the an object
            # @param [String] tag
            # @param [String] object
            # @return [void]
            def register_tag(tag, obj)
                @tags ||= {}
                @tags[tag] = obj
            end

            # @param [String] tag
            # @return [Object] The object corresponding to a registered tag
            def get_tag(tag)
                @tags[tag]
            end
            
            # @param [String] tag
            # @return [bool] Whether the given tag is registered
            def has_tag?(tag)
                return false unless @tags
                @tags[tag] ? true : false
            end


            private

            # @private
            # Path to the file with the currently installed version            
            # @return [String]
            def installed_version_path
                File.join(Spider.paths[:var], 'apps', self.name, 'installed_version')
            end

            # Looks for erb files in the tags_path
            # @return [nil]
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

            # Collects models ({BaseModel} subclasses) from inside the module m
            # @param [Module] m
            # @return [Array] the models
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
            
        end

        def self.included(mod)
            mod.module_eval do
                
                include Spider::DataTypes
                
                extend ClassMethods
            end

            mod.init()
            Spider::add_app(mod)
        end
        
        # The AppSpec class represents an app's .spec file
        # The AppSpec attributes are:
        #
        # * :app_id [String]            sunique identifier for the app
        # * :name [String]              descriptive name
        # * :description [String]
        # * :git_repo [String]          URL of git repository for the app
        # * :git_repo_rw [String]       URL of read/write git repository for the app
        # * :authors [Array]
        # * :depends [Array]            Apps this app depends on
        # * :depends_optional [Array]   Optional dependencies
        # * :load_after [Array]         Apps that must be loaded before this one (if present)
        # * :gems [Array]               Gems this app depends on
        # * :gems_optional [Array]      Optional gem dependencies
        # * :version [Gem::Version]     Current app version
        # * :app_server [String]        URL for the app server of this app
        # * :auto_update [TrueClass|FalseClass] true by default; set to false if this version can't be auto-updated

        class AppSpec
            # @private
            @@attributes = []
            
            # @private
            # Helper method to define an attribute on the AppSpec class
            # @return [nil]
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
                if options[:default].is_a?(TrueClass) || options[:default].is_a?(FalseClass)
                    str += "\nalias :#{name}? :#{name}\n"
                end
                class_eval(str)
                nil
            end
            
            # @private
            # Helper method to define an Array attribute on the AppSpec class
            # @return [nil]
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
                nil
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
            array_attribute :gems
            array_attribute :gems_optional
            attribute :version
            attribute :app_server
            attribute :auto_update, :default => true

            # The git branch used for the app
            attr_accessor :branch
            
            # Sets or retrieves the AppSpec id
            # @return [String]
            def id(val=nil)
                self.app_id(val)
            end
                        
            # Sets or retrieves the AppSpec version
            # @param [String] val
            # @return [Gem::Version]
            def version(val=nil)
                @version = Gem::Version.new(val) if val
                @version
            end

            # Sets or retrieves the first AppSpec author
            # @return [String]
            def author(val = nil)
                @authors = [val] if val
                @authors ||= []
                @authors[0]
            end
            
            # Loads attributes from a .spec file
            # @param [String] spec_path
            # @return [self]
            def load(spec_path)
                self.eval(File.read(spec_path), spec_path)
                self
            end
            
            # Returns a new AppSpec instance, loading from a .spec file
            # @param [String] spec_path
            # @return [AppSpec]
            def self.load(spec_path)
                self.new.load(spec_path)
            end
            

            # Evals the given code in the AppSpec's context
            # @return [AppSpec]
            def eval(text, path=nil)
                self.instance_eval(text)
                self
            end
            
            # Returns a new AppSpec instance, evaluating the given code
            # @param [String] text code to evaluate
            # @param [String] path path to the code
            # @return [AppSpec]
            def self.eval(text, path=nil)
                self.new.eval(text, path)
            end
            
            # Returns all attributes as an Hash
            # @return [Hash]
            def to_h
                h = {}
                @@attributes.each do |a|
                    h[a] = send(a)
                end
                h[:branch] = @branch unless @branch.blank?
                h
            end
            
            # Returns the Hash (as in #to_hash) as JSON
            # @param [Hash] opts JSON options
            # @return [String]
            def to_json(opts=nil)
                to_h.to_json
            end
            
            # Constructs a new AppSpec instance from an Hash of attributes
            # @param [Hash] h
            # @return [AppSpec]
            def self.parse_hash(h)
                spec = self.new
                h.each do |key, value|
                    unless spec.respond_to?(:"#{key}")
                        Spider.output("Bad spec key #{key} in:", :ERROR)
                        Spider.output(h.inspect, :ERROR)
                        next
                    end
                    if value.is_a?(Array)
                        spec.send(:"#{key}", *value)
                    else
                        spec.send(:"#{key}", value)
                    end
                end
                spec
            end

            # Returns an array of apps needed at runtime
            # @return [Array]
            def get_runtime_dependencies
                return self.load_after unless @load_after.blank?
                return self.depends + self.depends_optional
            end

            # Returns an Array of gem names for gems this AppSpec depends on
            # @return [Array]
            def gems_list
                self.gems.map{ |g| g.is_a?(Array) ? g.first : g }
            end

            # Returns an Array of optional gem names
            # @return [Array]
            def gems_optional_list
                self.gems_optional.map{ |g| g.is_a?(Array) ? g.first : g }
            end

            def branch(val=nil)
                @branch = val if val
                @branch
            end

        end
        
        # Helper class to sort the runtime dependencies of an app using TSort.
        class RuntimeSort
            
            def initialize
                @apps = []
                @apps_hash = {}
            end
            

            # Adds an app to be sorted
            # @param [AppSpec|String] app the app to add
            def add(app)
                @apps << app
                if app.is_a?(AppSpec)
                    @apps_hash[app.app_id] = app
                else
                    @apps_hash[app] = app
                end
            end
            
            # Runs block on each dependency
            # @param [Proc] block
            def tsort_each_node(&block)
                @apps.each(&block)
            end
            
            # Runs the given block for each dependency of node
            # @param [AppSpec] node the app to get dependecies for
            # @param [Proc] block 
            def tsort_each_child(node, &block)
                return unless node.is_a?(AppSpec)
                node.get_runtime_dependencies.map{ |a| @apps_hash[a] }.each(&block)
            end
            
            # Runs tsort
            # @return [Array] an array of sorted App ids
            def tsort
                sorted = super
                sorted.map{ |a| a.is_a?(AppSpec) ? a.app_id : a }
            end
            
            include TSort
            
        end

        # This module is included Controller and BaseModel, and provides the
        # app method, returning the class' app.
        module AppClass

            def self.included(klass)
                klass.extend(ClassMethods)
            end

            # @return [App] The app to which the object's class belongs
            def app
                return self.class.app
            end

            module ClassMethods

                # @return [App] The app to which the class belongs
                def app
                    return @app if @app
                    @app ||= self.parent_module
                    while @app && !@app.include?(Spider::App) && @app != Object
                        @app = @app.parent_module
                    end
                    @app = nil if @app && !@app.include?(Spider::App)
                    return @app
                end
            end
        end
        
    end
    
end
