require 'fileutils'

module Spider
    
    module Messenger

        def self.app_init
            available_backends = {}
            base = File.join(Spider::Messenger.path, 'backends')
            Dir.new(base).each do |type|
                next if type[0].chr == '.'
                type_dir = File.join(base, type)
                next unless File.directory?(type_dir)
                available_backends[type.to_sym] = []
                Dir.new(type_dir).each do |bcknd|
                    next if bcknd[0].chr == '.'
                    name = File.basename(bcknd, '.rb')
                    available_backends[type.to_sym] << name
                end
            end
            available_backends.each do |type, backends|
                Spider.config_option("messenger.#{type}.backends")[:params][:choices] = backends
                Spider.config_option("messenger.#{type}.backend")[:params][:choices] = backends
            end

        end
        
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
                self.process_queue(queue) unless Spider.conf.get("messenger.#{queue}.backends").empty?
            end
        end
        
        def self.lock_file
            File.join(Spider.paths[:var], 'messenger_lock')
        end
                
        def self.process_queue(queue, tickets=nil)
            raise ArgumentError, "Queue #{name} not found" unless self.queues[queue]
            @mutexes ||= {}
            mutex = @mutexes[queue] ||= Mutex.new
            return false if mutex.locked?
            model = Spider::Messenger.const_get(self.queues[queue][:model])
            lock_file = "#{self.lock_file}_#{queue}"
            now = DateTime.now
            mutex.synchronize do
                FileUtils.touch(lock_file)
                File.open(lock_file, 'r'){ |f| return false unless f.flock File::LOCK_EX | File::LOCK_NB }
                begin
                    list = nil
                    if tickets
                        list = model.where(:ticket => tickets)
                    else
                        list = model.where{ (sent == nil) & (next_try <= now) }
                    end
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
                            msg.attempts ||= 0
                            msg.attempts += 1
                            msg.last_try = now
                            if (exc)
                                msg.backend_response = exc.to_s
                            else
                                msg.backend_response = res
                            end
                            if (msg.attempts >= Spider.conf.get("messenger.#{queue}.retries"))
                                msg.next_try = nil
                            else
                                msg.next_try = msg.last_try.to_local_time + (msg.attempts * Spider.conf.get("messenger.#{queue}.retry_time") * 60)
                            end
                            msg.save
                        end
                            
                    end
                ensure
                    File.open(lock_file, 'r'){ |f| f.flock File::LOCK_UN }
                    File.unlink(lock_file)
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


        def self.after_test
            self.backends.each do |queue, mods|
                mods.each do |mod|
                    mod.after_test if mod.respond_to?(:after_test)
                end
            end
        end

        def self.before_test
            self.backends.each do |queue, mods|
                mods.each do |mod|
                    mod.after_test if mod.respond_to?(:after_test)
                end
            end
        end
        
        
    end
    
end
