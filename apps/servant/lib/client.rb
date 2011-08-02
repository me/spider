require 'rubygems'
require 'httpclient'

module Spider
    
    module Servant
        
        class Client
        
            def initialize(url)
                @url = url
            end
            
            def http_client
                HTTPClient.new
            end
        
            def ping_server(url=nil)
                url ||= @url
                clnt = self.http_client
                status = Servant.status
                status[:apps] = status[:apps].to_json
                last_check_file = File.join(Spider.paths[:var], 'memory', 'servant_last_check')
                if File.exists?(last_check_file)
                    last_check = Time.parse(File.read(last_check_file))
                    status[:interval] = Time.now - last_check
                end
                status[:log] = Servant.gather_log.to_json
                status[:configuration] = compress_string(Servant.gather_configuration)
                res = clnt.post("#{url}/ping", Spider::HTTP.params_to_hash(status))
                unless res.status == 200
                    puts _("The server responded with: %s - %s") % [res.status, res.reason]
                    exit
                end
                File.open(last_check_file, 'w'){ |f| f << Time.now.to_s }
                res = JSON.parse(res.content)
                if res['commands']
                    processor = Servant.command_processor.new(url)
                    processor.run_commands(res['commands'])
                end
            end
            
            def process_commands(commands)
            end
            
            def send_event(name, details)
                self.http_client.post("#{@url}/servant_event", {
                    :event => name, :install_id => Servant.install_id, :details => details.to_json
                })
            end

            
            private

            
            def compress_string(str)
                compr = ""
                gz = Zlib::GzipWriter.new(StringIO.new(compr))
                gz.write str
                gz.close
                compr
            end
        
            
        end
        
    end
    
end