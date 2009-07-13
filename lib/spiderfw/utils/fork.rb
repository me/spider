module Spider
    
    # A safe fork keeping track of resources needing to be closed.
    module Fork
        
        # Adds a list of resources. Resources must respond to :close.
        def self.resources_to_close(*list)
            @resources ||= []
            @resources += list
        end
        
        # Closes all resources.
        def self.close_resources
            return unless @resources
            @mutex ||= Mutex.new
            @mutex.synchronize do
                @resources.each do |res|
                    @resource.close if resource && resource.respond_to?(:close) && !resource.closed?
                end
                @resources.clear
            end
        end
        
        # Closes resources, than forks.
        def self.fork(&proc)
            child = Kernel.fork do
                Spider::Fork.close_resources
                yield
            end
            return child
        end
        
    end
    
    # Calls Spider::Fork.fork
    def self.fork(&proc)
        Spider::Fork.fork(&proc)
    end
    
    
end

# Patches, taken from spawn Rails plugin (http://github.com/tra/spawn/)

if defined? Mongrel::HttpServer
  class Mongrel::HttpServer
    # redefine Montrel::HttpServer::process_client so that we can intercept
    # the socket that is being used so Spawn can close it upon forking
    alias_method :spider_orig_process_client, :process_client
    def process_client(client)
      Spider::Fork.resources_to_close(client, @socket)
      spider_orig_process_client(client)
    end
  end
end
 
need_passenger_patch = true
if defined? PhusionPassenger::VERSION_STRING
  # The VERSION_STRING variable was defined sometime after 2.1.0.
  # We don't need passenger patch for 2.2.2 or later.
  pv = PhusionPassenger::VERSION_STRING.split('.').collect{|s| s.to_i}
  need_passenger_patch = pv[0] < 2 || (pv[0] == 2 && (pv[1] < 2 || (pv[1] == 2 && pv[2] < 2)))
end
 
if need_passenger_patch
  if defined? PhusionPassenger::Rack::RequestHandler
    class PhusionPassenger::Rack::RequestHandler
      alias_method :spider_orig_process_request, :process_request
      def process_request(headers, input, output)
        Spider::Fork.resources_to_close(input, output)
        spider_orig_process_request(headers, input, output)
      end
    end
  end
end