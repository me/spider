require 'apps/cas_server/models/proxy_granting_ticket'

module Spider; module CASServer; module Models
    
    class ProxyTicket < Ticket
        element :ticket, String
        element :client_hostname, String
        element :iou, String
        element :proxy_granting_ticket, Models::ProxyGrantingTicket, :add_multiple_reverse => :proxy_tickets, :delete_cascade => true
    end
    
end; end; end