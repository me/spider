require 'apps/cas_server/models/service_ticket'

module Spider; module CASServer; module Models
    
    class ProxyGrantingTicket < Spider::Model::Managed
        element :ticket, String
        element :client_hostname, String
        element :service_ticket, ServiceTicket
        element :iou, String
    end
    
end; end; end