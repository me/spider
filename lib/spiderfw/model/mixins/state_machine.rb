module Spider; module Model

    module StateMachine

        def self.included(model)
            model.extend(ClassMethods)
            model.mapper_include(MapperMethods)
        end

        module ClassMethods
            attr_reader :state_events
            
            def inherited(sub)
                super
                sub.extend(Spider::Model::StateMachine::ClassMethods)
                sub.instance_variable_set("@state_events", @state_events.clone) if @state_events
            end

            class StateEvent
                attr_reader :transitions
                
                def initialize
                    @transitions = []
                    @action = nil
                end
                
                def transition(params=nil)
                    @transitions << params if params
                end
                
                def action(&proc)
                    @action = proc if proc
                    @action
                end
                
                def run(obj, old_state, new_state)
                    @action.call(obj, old_state, new_state)
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
                raise "States must be models with one primary key" unless type.is_a?(Hash) || !type.is_a?(Spider::Model::BaseModel) || type.primary_keys.length == 1
                element(name, type, attributes, &proc)
            end

            def state_event(element_name)
                ev = StateEvent.new
                yield ev
                @state_events ||= {}
                @state_events[element_name] ||= []
                @state_events[element_name] << ev
            end


        end
        
        def _pending_state_events
            @_pending_state_events ||= []
        end
        
        module MapperMethods
            
            def before_save(obj, mode)
                obj.model.elements_array.select{ |el| el.association == :state }.each do |el|
                    if (obj.model.state_events[el.name] && obj.element_modified?(el))
                        old = obj.get_new
                        old_state = old.get(el.name)
                        new_state = obj.get(el.name)
                        old_state = old_state.primary_keys.first if old_state && el.model?
                        new_state = new_state.primary_keys.first if new_state && el.model?
                        obj.model.state_events[el.name].each do |event|
                            call_ev = false
                            event.transitions.each do |tr|
                                from_ok = false
                                to_ok = false
                                if tr[:from]
                                    tr[:from] = [tr[:from]] unless tr[:from].is_a?(Array)
                                    from_ok = true if tr[:from].include?(old_state)
                                else
                                    from_ok = true
                                end
                                if tr[:to]
                                    tr[:to] = [tr[:to]] unless tr[:to].is_a?(Array)
                                    to_ok = true if tr[:to].include?(new_state)
                                else
                                    to_ok = true
                                end
                                if from_ok && to_ok
                                    call_ev = true
                                    break
                                end
                            end
                            if (call_ev)
                                obj._pending_state_events << [event, old_state, new_state]
                            end
                        end
                    end
                end
                super
            end
            
            def after_save(obj, mode)
                super
                obj._pending_state_events.each do |event, old_state, new_state|
                    event.run(obj.get_new, old_state, new_state)
                end
            end
            
        end

    end

end; end
