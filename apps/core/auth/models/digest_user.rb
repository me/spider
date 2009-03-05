require 'digest/md5'

module Spider; module Auth
    
    class DigestUser < LoginUser
        extend_model superclass
        element :realm, String
        element :ha1, String
        
        module MapperMethods
            def before_save(obj, mode)
                if (mode == :insert) || (mode == :update && (obj.elements_modified?(:username, :password, :realm)))
                    if (!obj.element_modified?(:password))
                        raise RuntimeError, "You must always supply the password to a DigestUser when updating username or realm"
                    end
                    pass_obj = obj.get(:password)
                    pass = pass_obj.get
                    obj.set(:ha1, Digest::MD5::hexdigest("#{obj.get(:username)}:#{obj.get(:realm)}:#{pass}"))
                    super
                end
            end
        end
        mapper_include MapperMethods
            
        
    end
    
end; end