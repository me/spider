module Spider; module Model
    
    module List
        
        def self.included(model)
            model.extend(ClassMethods)
            model.mapper_include(MapperMethods)
        end
        
        def list_mixin_modified_elements
            @list_mixin_modified_elements ||= {}
        end
        
        module MapperMethods
            
            def before_save(obj, mode)
                obj.class.lists.each do |l|
                    next if (!check_list_condition(l, obj))
                    cond = get_list_condition(l, obj)
                    cur = obj.get(l.name)
                    obj.set(l.name, max(l.name, cond) + 1) unless cur
                end
                if (obj.list_mixin_modified_elements)
                    obj.list_mixin_modified_elements.each do |name, old|
                        if (!check_list_condition(name, obj))
                            obj.set(name, nil)
                            next
                        end
                        cond = get_list_condition(name, obj)
                        new_val = nil
                        obj.save_mode do
                            new_val = obj.get(name)
                        end
                        new_val ||= max(name, cond) + 1
                        if (!old)
                            move_up_list(name, new_val, nil, cond)
                        else
                            if (new_val < old)
                                move_up_list(name, new_val, old-1, cond)
                            else
                                move_down_list(name, old+1, new_val, cond)
                            end
                        end
                    end
                end
                super(obj, mode)
            end
            
            def before_delete(objects)
                @model.lists.each do |list_el|
                    objects.each do |obj|
                        cond = get_list_condition(list_el, obj)
                        val = obj.get(list_el)
                        move_down_list(list_el.name, val, nil, cond) if val
                    end
                end
                super(objects)
            end
            
            def move_up_list(element_name, from, to=nil, condition=nil)
                expr = ":#{element_name} + 1"
                cond = condition || Condition.and
                cond.set(element_name, '>=', from)
                cond.set(element_name, '<=', to) if to
                bulk_update({element_name => Spider::QueryFuncs::Expression.new(expr)}, cond)
            end
            
            def move_down_list(element_name, from, to=nil, condition=nil)
                expr = ":#{element_name} - 1"
                cond = condition || Condition.and
                cond.set(element_name, '>=', from)
                cond.set(element_name, '<=', to) if to
                bulk_update({element_name => Spider::QueryFuncs::Expression.new(expr)}, cond)
            end
            
            def get_list_condition(element, obj)
                element = @model.elements[element] unless element.is_a?(Element)
                l_cond = element.attributes[:list_condition]
                return nil unless l_cond
                cond = l_cond.call(obj)
                cond = Condition.new(cond) unless cond.is_a?(Condition)
                preprocess_condition(cond)
                return cond
            end
            
            def check_list_condition(element, obj)
                element = @model.elements[element] unless element.is_a?(Element)
                l_check = element.attributes[:check_list_condition]
                return true unless l_check
                return l_check.call(obj)

            end
            
        end
        
        
        module ClassMethods
            
            def lists
                elements_array.select{ |el| el.attributes[:list] }
            end
            
            def list(name, attributes={})
                attributes[:list] = true
                attributes[:order] ||= true
                element(name, Fixnum, attributes)
                observe_element(name) do |obj, el, new_val|
                    obj.save_mode do
                        obj.list_mixin_modified_elements[name] = obj.get(el)
                    end
                end
                
                (class << self; self; end).instance_eval do
                    
                    define_method("#{name}_last") do
                        qs = self.all.order_by(name).limit(1)
                        return qs[0]
                    end
                    
                end
                
                define_method("insert_last_#{name}") do
                    # FIXME: locking!
                    last = self.class.send("#{name}_last")
                    max = last ? last.get(name) : 0
                    set(name, max + 1)
                end
            end
            
            

            
        end
        
    end
    
end; end