module Spider; module Model

    module Synchronized

        def self.extended(model)
            model.extend(ClassMethods)
        end
        
        def self.included(model)
            model.extend(ClassMethods)
        end

        module ClassMethods

            def synchronizing(name) 
                @synchronizing = name

                with_mapper do
                    def before_save(obj)
                        return super unless @synchronizing
                        @model.elements.select{ |el| 
                            el.model? && el.model.include?(Synchronized) && el.model.synchronizing == @model.synchronizing
                        }.each do |el|
                            cond = Condition.new
                            el.model.primary_keys.each{ |k| cond[el.model.syncronization_key(@model.synchronizing, k)] = obj.get(k) }
                            res = el.model.find(cond)
                            raise SynchronizationException, "The synchronized object was not unique" unless res.length == 1
                            el.model.primary_keys.each{ |k| obj.get(el).set(k, res.get(k))}
                        end
                        super(obj)
                    end  
                end
                
            end

            def synchronization(name)
                @synchronizations ||= []
                @synchronizations << name
                self.primary_keys.each do |k|
                    element(:"sync_#{name}_{k}", k.type)
                end
            end


        end

        class SynchronizationException < RuntimeError
        end

    end

end; end
