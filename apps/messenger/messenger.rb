module Spider
    
    module Messenger
        
        def self.queues
            {
                :email => { :label => _("Email"), :model => :Email },
                :sms => { :label => _("SMS"), :model => :SMS }
            }
        end
        
        def self.backends
            @backends ||= {}
        end
        
        def self.add_backend(queue, mod)
            @backends ||= {}
            @backends[queue] ||= []
            @backends[queue] << mod
        end
        
        def self.process_queues
            self.queues.each_key do |queue|
                self.process_queue(queue)
            end
        end
                
        def self.process_queue(queue)
            raise ArgumentError, "Queue #{name} not found" unless self.queues[queue]
            @mutexes ||= {}
            mutex = @mutexes[queue] ||= Mutex.new
            return if mutex.locked?
            model = Spider::Messenger.const_get(self.queues[queue][:model])
            mutex.synchronize do
                now = DateTime.now
                list = model.where{ (sent == nil) & (next_try <= now) }
                list.each do |msg|
                    res = false
                    exc = nil
                    self.backends[queue].each do |backend|
                        begin
                            res = backend.send_message(msg)
                        rescue => exc
                            Spider.logger.error(exc)
                        end
                        break if res
                    end
                    if (res)
                        msg.sent = now
                        msg.status = :backend
                        msg.next_try = nil
                        msg.backend_response = res
                        msg.save
                    else
                        backend_response = exc ? exc.to_s : res
                        msg.add_failure(backend_response)
                        msg.save
                    end
                            
                end
            end
        end
        
        def self.email(from, to, headers, body, params={})
            if (headers.is_a?(Hash))
                headers = headers.inject(""){ |h, p| h += "#{p[0]}: #{p[1]}\n"}
            elsif(headers.is_a?(Array))
                headers = headers.join("\n")
            end
            headers = "To: #{to}\r\n"+headers unless headers =~ /^To/
            headers = "From: #{from}\r\n"+headers unless headers =~ /^From/
            msg = Email.new(
                :from => from, :to => to, :headers => headers, :body => body
            )
            msg.next_try = params[:send_from] || DateTime.now
            msg.save
            return msg
        end
        
        def self.sms(to, text, params={})
            msg = SMS.new(
                :to => to, :text => text
            )
            msg.next_try = params[:send_from] || DateTime.now
            msg.save
            return msg
        end
        
        
    end
    
end
