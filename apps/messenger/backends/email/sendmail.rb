require 'apps/messenger/lib/email_backend'

module Spider; module Messenger; module Backends; module Email
    
    module Sendmail
        include Messenger::EmailBackend
        
        def self.send_message(msg)
            Spider.logger.debug("Sending e-mail #{msg.ticket}")
            res = false
            mail = prepare_mail(msg)
            mail.delivery_method :sendmail
            mail.deliver
        end
        

        
    end
    
end; end; end; end
