require 'apps/messenger/lib/sms_backend'

module Spider; module Messenger; module Backends; module SMS
    
    module Test
        include Messenger::SMSBackend

        def self.sent_sms
            @sent_sms ||= []
        end

        def self.after_test
            @sent_sms = []
        end
        
        def self.send_message(msg)
            Spider.logger.debug("Sending SMS #{msg.ticket}")
            self.sent_sms << msg
        end
        

        
    end
    
end; end; end; end
