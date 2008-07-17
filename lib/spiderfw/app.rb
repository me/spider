module Spider
    
    module App
        
        def self.included(mod)
            mod.module_eval do
                @controller_class ||= :ApplicationController
                class << self
                    attr_reader :path
                    
                    def init
                    end
                    
                    def controller_class
                        p "Controller class: #{@controller_class}"
                        p "Defined: "
                        controllers = self.const_get(:Controllers)
                        p controllers.const_defined?(@controller_class)
                        p controllers
                        p controllers.constants
                        controllers.const_defined?(@controller_class) ? controllers.const_get(@controller_class) : Spider::Controller
                    end
                end
                
                mod.const_set(:Controllers, Spider::App::Controllers.clone) unless mod.const_defined?(:Controllers)
            end
            mod.init()
            routes_file = "#{mod.path}/routes.rb"
            if (File.exist?(routes_file))
                load(routes_file)
            else
                mod.controller_class.route('/', mod.name+'::MainController')
            end
            Spider::add_app(mod)
        end
        
        module Controllers
        end
        
    end
    
end