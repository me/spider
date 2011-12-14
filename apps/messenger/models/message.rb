require 'uuidtools'

module Spider; module Messenger
    
    class Message < Spider::Model::Managed
        element :ticket, UUID, :label => _("Ticket")
        element :last_try, DateTime, :label => _("Last try")
        element :next_try, DateTime, :label => _("Next try")
        element :attempts, Fixnum, :label => _("Attempts")
        element :backend, String, :label => _("Backend")
        element :backend_id, String, :label => _("Backend id")
        element :backend_response, String, :label => _("Last status")
        element :sent, DateTime, :label => _("Sent at")
        element :status, {
            :retry => _('Retry'),
            :queued => _('Queued'),
            :failed => _('Failed'),
            :backend => _('Handed to backend'),
            :sent => _('Sent'),
            :delivered => _('Delivered')
        }
        
        def self.sent_messages
            self.where{ q.sent .not nil }
        end
        
        def self.queued_messages
            self.where{ (q.sent == nil) & (q.next_try .not nil) }
        end
        
        def self.failed_messages
            self.where{ (q.sent == nil) & (q.next_try == nil) }
        end
        
        def self.queue(val=nil)
            @queue = val if val
            @queue
        end
            
        
        def add_failure(backend_response=nil)
            msg = self
            msg.last_try = DateTime.now
            msg.attempts ||= 0
            msg.attempts += 1
            queue = self.class.queue
            if (msg.attempts >= Spider.conf.get("messenger.#{queue}.retries"))
                msg.next_try = nil
                msg.status = :failed
            else
	        msg.last_try ||= DateTime.now
                msg.next_try = msg.last_try + (msg.attempts * Spider.conf.get("messenger.#{queue}.retry_time") * 60)
                msg.status = :retry
            end
        end
        
        # with_mapper do
        #     def before_save(obj, mode)
        #         obj.ticket = UUIDTools::UUID.random_create.to_s if mode == :insert
        #         super
        #     end
        # end
        
    end
    
end; end
