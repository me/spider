require 'apps/messenger/models/email'

module Spider; module Messenger
   
   module EmailBackend 
      
      def self.included(mod) 
          Messenger.add_backend(:email, self)
      end
     
       
   end
    
end; end