module Spider
    
    module App
        
        def self.included(mod)
            mod.module_eval do
                @controller_class ||= :MainController
                class << self
                    attr_reader :path
                    
                    def init
                    end
                    
                    def controller_class
                        controllers = self.const_get(:Controllers)
                        controllers.const_defined?(@controller_class) ? controllers.const_get(@controller_class) : Spider::Controller
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
            #     mod.controller_class.route('/', mod.name+'::MainController')
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