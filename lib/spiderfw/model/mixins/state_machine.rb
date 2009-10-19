module Spider; module Model

    module StateMachine

        def self.included(model)
            model.extend(ClassMethods)
        end

        module ClassMethods

            class StateEvent
                
                def initialize
                    @transitions = []
                    @action = nil
                end
                
                def transitions(params=nil)
                    @transitions << params if params
                    @transitions
                end
                
                def action(&proc)
                    @action = proc if proc
                    @action
                end
                
            end

            def element_association?(name, ass)
                el_ass = elements[name].association
                if (el_ass == :state)
                    return true if ass == :choice
                end
                return super
            end

            def state(name, type, attributes={}, &proc)
                attributes[:association] = :state
                element(name, type, attributes, &proc)
            end

            def state_event(name)
                ev = StateEvent.new
                yield ev
                @state_events ||= []
                @state_events << ev
            end


        end
        
        module MapperMethods
            
            def before_save(obj, mode)
                obj.model.elements_array.select{ |el| el.association == :state }.each do |el|
                    if (obj.model.state_events[el.name] && obj.modified?(el))
                        old = obj.get_new
                        old_state = old.get(el.name)
                        new_state = obj.get(el.name)
                        obj.model.state_events[el.name].each do |event|
                            call_ev = false
                            event.transitions.each do |tr|
                                if (!tr[:from] || tr[:from] == old_state) && (!tr[:to] || tr[:to] == new_state)
                                    call_ev = true
                                    break
                                end
                            end
                            if (call_ev)
                                event.run(obj)
                            end
                        end
                    end
                end
            end
            
        end

    end

end; end