require 'apps/messenger/models/email'

module Spider; module Messenger
   
   module EmailBackend 
      
      def self.included(mod) 
          Messenger.add_backend(:email, mod)
          mod.extend(ClassMethods)
      end
      
      module ClassMethods
          
          def prepare_mail(msg)
              msg_str = msg.headers+"\r\n\r\n"+msg.body
              mail = Mail.new(msg_str)
          end
          
      end
     
       
   end
    
end; end
