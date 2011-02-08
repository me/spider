require 'apps/messenger/lib/email_backend'

module Spider; module Messenger; module Backends; module Email
    
    module Sendmail
        include Messenger::EmailBackend
        
        def self.send_message(msg)
            Spider.logger.debug("Sending e-mail #{msg.ticket}")
            mail = prepare_mail(msg)
            mail.delivery_method :sendmail
            mail.deliver
            return true
        end
        

        
    end
    
end; end; end; end
