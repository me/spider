require 'spiderfw/controller/app_controller'

module Spider
    
    module App
        
        def self.included(mod)
            mod.module_eval do
                
                include Spider::DataTypes
                
                #@controller ||= :"Spider::AppController"
                class << self
                    attr_reader :path, :pub_path, :test_path, :setup_path, :widgets_path, :views_path, :tags_path
                    attr_reader :short_name, :route_url, :label, :version
                    attr_reader :short_prefix
                    attr_reader :command
                    
                    def init
                        @short_name ||= Inflector.underscore(self.name).gsub('/', '_')
                        @pub_path ||= @path+'/public'
                        @test_path ||= @path+'/test'
                        @setup_path ||= @path+'/setup'
                        @widgets_path ||= @path+'/widgets'
                        @views_path ||= @path+'/views'
                        @tags_path ||= @path+'/tags'
                        @route_url ||= Inflector.underscore(self.name)
                        @label ||= @short_name.split('_').each{ |p| p[0] = p[0].chr.upcase }.join(' ')
                        find_tags
                    end
                    
                    def request_url
                        Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping('/'+@route_url)
                    end
                    
                    def pub_url
                        request_url+'/public'
                    end
                    
                    def controller
                        #controllers = self.const_get(:Controllers)
                        if (!@controller || !const_defined?(@controller))
                            @controller = :AppController
                            return const_set(@controller, Spider::AppController.clone)
                            
                        end
                        return const_get(@controller)
                    end
                    
                    def models(container=nil)
                        container ||= self
                        mods = []
                        container.constants.each do |c|
                            mods += get_models(container.const_get(c))
                        end
                        return mods
                    end
                    
                    def get_models(m)
                        ms = []
                        if m.respond_to?(:subclass_of?) && m.subclass_of?(Spider::Model::BaseModel)
                             ms << m
                             m.constants.each do |c|
                                 sub_mod = m.const_get(c)
                                 next if !sub_mod.subclass_of?(Spider::Model::BaseModel) || sub_mod.app != self
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
                            klass = Spider::Tag.new_class(@tags_path+'/'+entry)
                            const_set(Spider::Inflector.camelize(name).to_sym, klass)
                            Spider::Logger.debug("REGISTERED TAG #{name}, #{klass}")
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
                    
                    
                end
                
                # controllers = Spider::App::Controllers.clone
                # controllers.app = mod
                # Spider.logger.debug("Controllers.app")
                # Spider.logger.debug(controllers.to_s)
                # Spider.logger.debug(controllers.app)
                #     
                # mod.const_set(:Controllers, controllers) unless mod.const_defined?(:Controllers)
                # Spider.logger.debug(Controllers)
            end
            mod.init()
            # routes_file = "#{mod.path}/routes.rb"
            # if (File.exist?(routes_file))
            #     load(routes_file)
            # else
            #     mod.controller.route('/', mod.name+'::MainController')
            # end
            Spider::add_app(mod)
        end
        
        # module Controllers
        #     def self.app=(app)
        #         @app = app
        #     end
        #     def self.app
        #         @app
        #     end
        # 
        # end
        
    end
    
end
