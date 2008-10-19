require 'spiderfw/controller/http_controller'
require 'drb'

module Spider
    
    #MAH?
    class ServerController < Controller
        route /([\w]+):\/\/([^:\/]+)(:\d+)?/, Spider::HTTPController, 
            :spawn => 1, :remove_params => true
    
        def initialize(env, response, scene=nil)
            super
            @children = {}
        end
        
        def get_route(path)
            r = super
            r.action = $1 if (r && r.action =~ /^:\d+\/(.+)/) # strip port
            return r
        end
        
        def dispatched_object(route)
            Spider.logger.debug("ROUTE:")
            Spider.logger.debug(route)
            Spider.server[:forks] ||= {}
            if (route.options[:fork])
                if (!Spider.server[:forks][route.path])
                    obj = super
                    Spider.logger.debug("FORKING!")
                    pid = fork
                    if (pid)
                        Signal.trap(0) do
                              # tell the child process to die
                              Process.kill("TERM", pid)
                        end
                        Spider.server[:forks][route.path] = [pid, 7777]
                        DRb.start_service
                        begin
                            obj = DRbObject.new(nil, 'druby://localhost:77777')
                        rescue DRb::DRbConnError
                            sleep(100)
                            retry
                        end
                        return obj
                    else
                        Spider.logger.debug("IN FORKED")
                        DRb.start_service("druby://localhost:77777", obj)
                    end
                else
                    DRb.start_service
                    obj = DRbObject.new(nil, 'druby://localhost:77777')
                    return obj
                end
            end 
                
        end
        
        # def choose_action(protocol, server, port)
        #     
        # end
        
        # def dispatch(method, action='', *params)
        #      path.slice!(0) if path.length > 0 && path[0].chr == "/"
        #      
        #      return [Spider::HTTPController, path, []]
        # end
        # 
        # def fork?(path)
        # end
        
    end
    
    
end