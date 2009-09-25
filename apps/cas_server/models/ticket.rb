module Spider; module CASServer; module Models

    class Ticket < Spider::Model::Managed
        #element :extra_attributes, String

        def to_s
            ticket
        end


        def self.cleanup_expired(expiry_time)
            condition = Spider::Model::Condition.where{ created_on < (Time.now - expiry_time) }
            mapper.delete(condition)
        end



    end

end; end; end