require 'apps/messenger/models/message'

module Spider; module Messenger
    
    class Email < Message
        class_table_inheritance :add_polymorphic => true
        element :from, String, :label => _("From")
        element :to, String, :label => _("To")
        element :headers, Text, :label => _("Headers")
        element :subject, String, :label => _("Subject"), :computed_from => [:headers]
        element :body, Text, :label => _("Body")
        
        queue :email
        
        def subject
            if (self.headers =~ /^Subject: (.+)$/)
                return $1
            end
            return ''
        end
                
    end
    
end; end