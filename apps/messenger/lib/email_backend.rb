require 'apps/messenger/models/email'

module Spider; module Messenger
   
   module EmailBackend 
      
      def self.included(mod) 
          Messenger.add_backend(:email, mod)
      end
     
       
   end
    
end; end
