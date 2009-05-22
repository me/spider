require 'digest/md5'

module Spider; module Auth
    
    class DigestUser < LoginUser
        include DigestAuthenticator
        extend_model superclass, :add_polymorphic => true
        element :realm, String, :hidden => true
        element :ha1, String, :hidden => true
        
        module MapperMethods
            def before_save(obj, mode)
                if (mode == :insert) || (mode == :update && (obj.elements_modified?(:username, :password, :realm)))
                    unless (obj.element_modified?(:password))
                        cur = obj.get_new
                        if (cur.username != obj.username || cur.realm != obj.realm)
                            raise RuntimeError, _("You must always supply the password to a DigestUser when updating username or realm")
                        end
                    end
                    pass_obj = obj.get(:password)
                    pass = pass_obj.is_a?(String) ? pass_obj : pass_obj.get
                    obj.set(:ha1, Digest::MD5::hexdigest("#{obj.get(:username)}:#{obj.get(:realm)}:#{pass}"))
                    super
                else
                    super
                end
            end
        end
        mapper_include MapperMethods
            
        
    end
    
end; end