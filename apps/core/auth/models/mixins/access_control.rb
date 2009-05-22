module Spider; module Auth

    module AccessControl
        
        def self.included(model)
            model.extend(ClassMethods)
            model.element(:creation_user, Spider::Auth::User)
            model.element(:modification_user, Spider::Auth::User)
            model.element(:creation_date, DateTime)
            model.element(:modification_date, DateTime)
            model.mapper_include MapperMethods
        end
        
        module MapperMethods
            def insert(obj)
                obj.creation_user = Spider::Auth.current_user
                obj.modification_user = Spider::Auth.current_user
                obj.creation_date = DateTime.now
                obj.modification_date = DateTime.now
                super(obj)
            end
            
            def update(obj)
                if (@model.elements_array.select{ |el| obj.element_modified?(el) }.length > 0)
                    obj.modification_user = Spider::Auth.current_user
                    obj.modification_date = DateTime.now
                end
                super(obj)
            end
        end
        
        module ClassMethods

            def check_user(op, &proc)

                with_mapper do
                    def check_auth(op, proc, obj, mode)
                        if (op == :all || op == mode)
                            if (!proc && !Spider::Auth.current_user) || (proc && !proc.call(obj, mode))
                                raise UnauthorizedAction, "You are not allowed to #{mode} #{@model}"
                            end
                        end
                    end
                    
                    def before_save(obj, mode)
                        check_auth(op, proc, obj, mode)
                        super
                    end
                    
                    def delete(obj)
                        check_auth(op, proc, obj, :delete)
                        super
                    end
                    
                    def delete_all!(obj)
                        check_auth(op, proc, obj, :delete_all)
                        super
                    end
                    
                end
                
            end 

        end
        
    end
    
end; end
        
        
        