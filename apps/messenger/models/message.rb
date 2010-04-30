require 'uuidtools'

module Spider; module Messenger
    
    class Message < Spider::Model::Managed
        element :ticket, UUID, :label => _("Ticket")
        element :last_try, DateTime, :label => _("Last try")
        element :next_try, DateTime, :label => _("Next try")
        element :attempts, Fixnum, :label => _("Attempts")
        element :backend_response, String, :label => _("Last status")
        element :sent, DateTime, :label => _("Sent at")
        
        def status
            if self.sent
                :sent
            elsif (self.next_try)
                :queue
            else
                :failed
            end
        end
        
        def self.sent_messages
            self.where{ q.sent .not nil }
        end
        
        def self.queued_messages
            self.where{ (q.sent == nil) & (q.next_try .not nil) }
        end
        
        def self.failed_messages
            self.where{ (q.sent == nil) & (q.next_try .not nil) }
        end
        
        with_mapper do
            def before_save(obj, mode)
                obj.ticket = UUIDTools::UUID.random_create.to_s if mode == :insert
                super
            end
        end
        
    end
    
end; end