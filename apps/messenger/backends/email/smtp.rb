require 'apps/messenger/lib/email_backend'

module Spider; module Messenger; module Backends; module Email
    
    module SMTP
        include Messenger::EmailBackend
        
        def self.send_message(msg)
            Spider.logger.debug("Sending e-mail #{msg.ticket}")
            mail = prepare_mail(msg)
            mail.delivery_method :smtp, {
                :address => Spider.conf.get('messenger.smtp.address'),
                :port => Spider.conf.get('messenger.smpt.port'),
                :domain => Spider.conf.get('messenger.smtp.domain'),
                :user_name => Spider.conf.get('messenger.smtp.username'),
                :password => Spider.conf.get('messenger.smtp.password'),
                :authentication => Spider.conf.get('messenger.smtp.auth_scheme')
            }
            mail.deliver
            return true
        end
        
        def self.update_statuses
            log_path = nil
            return unless log_path = Spider.conf.get('messenger.smtp.log_path')
            previous_position  = nil
            memory_file = File.join(Spider.paths[:var], 'messenger_smtp_log_position')
            begin; previous_position = IO.read(memory_file).to_i; rescue; end
            current_position = `wc -c #{log_path}`.split(' ')[0].to_i
            if previous_position and current_position < previous_position
                # log file rotated - set position to zero
                previous_position = 0
            elsif previous_position.nil?
                # first run
                previous_position = 0
            end
            File.open(memory_file, 'w'){ |f| f << current_position }
            found = {}
            File.open(log_path, 'rb') do |f|
                f.seek(previous_position, IO::SEEK_SET)
                f.each_line do |line|
                    if line =~ /\: ([A-F\d]+)\: to(.+)status=(\w+)/
                        found[$1] = line
                    end
                end
            end
            Messenger::Email.where{ |e| e.status == :backend }.each do |msg|
                if msg.backend_id || (msg.backend_response && msg.backend_response =~ /queued as ([A-F\d]+)/)
                    msg_id = msg.backend_id || msg.backend_response
                    msg.backend_id ||= msg_id
                    next unless msg_id
                    if line = found[msg_id]
                        msg.backend_response = line
                        if line =~ /\: ([A-F\d]+)\: to(.+)status=(\w+)/
                            status = $2
                        end
                        if status == 'bounced'
                            msg.status = :failed
                        elsif status == 'sent'
                            msg.status = :sent
                        end
                        msg.save
                    end
                end
            end
            
            
        end
        
        
    end
    
end; end; end; end
