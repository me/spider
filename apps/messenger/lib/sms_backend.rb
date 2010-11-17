require 'apps/messenger/models/sms'

module Spider; module Messenger
   
   module SMSBackend 
      
      def self.included(mod) 
          Messenger.add_backend(:sms, self)
      end
      
       
   end
    
end; end