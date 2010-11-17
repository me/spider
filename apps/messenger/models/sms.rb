require 'apps/messenger/models/message'

module Spider; module Messenger
    
    class SMS < Message
        class_table_inheritance :add_polymorphic => true
        element :to, String, :label => _("To")
        element :text, Text, :label => _("Text")
        
        queue :sms
        
                
    end
    
end; end