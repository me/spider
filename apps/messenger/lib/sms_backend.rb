require 'apps/messenger/models/sms'

module Spider; module Messenger
   
   module SMSBackend 
      
      def self.included(mod) 
          Messenger.add_backend(:sms, mod)
      end
      
       
   end
    
end; end
