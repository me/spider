module Spider; module Model
    
    module Tree
        
        def self.included(model)
            model.extend(ClassMethods)
            model.mapper_include(MapperMethods)
        end
        
        def tree_all(element)
            element = self.class.elements[element] unless element.is_a?(Element)
            left_el = element.attributes[:tree_left]
            right_el = element.attributes[:tree_right]
            left = get(left_el)
            right = get(right_el)
            return nil unless (left && right)
            c = Condition.and
            c[left_el] = (left..right)
            q = Query.new(c)
            q.order_by(left_el) unless element.attributes[:order] == false
            res = element.model.find(q)
            return [] unless res
            right_stack = []
            parents = []
            first = nil
            res.each do |obj|
                first ||= obj
                if right_stack.length > 0
                    while right_stack.length > 0 && right_stack.last < obj.get(right_el)
                        right_stack.pop
                        p, sub = parents.pop
                        p.set_loaded_value(element.name, sub)
                        parents.last[1] << p if parents.last
                    end
                    obj.set(element.attributes[:tree_depth], right_stack.length)
                end
                right_stack << obj.get(right_el)
                parents << [obj, QuerySet.static(self.class)]
            end
            
            while pair = parents.pop
                p, sub = pair
                p.set_loaded_value(element.name, sub)
                parents.last[1] << p if parents.last
            end
            
            return res
        end

        def before_save
            self.class.elements_array.select{ |el| el.attributes[:association] == :tree }.each do |el|
                if element_modified?(el)
                    cnt = 1
                    self.get(el).each do |obj|
                        obj.set(el.attributes[:tree_position], cnt)
                        cnt += 1
                    end
                end
            end
            super
        end
        
        module ClassMethods
            
           def tree(name, attributes={})
               attributes[:association] = :tree
               attributes[:multiple] = true
               attributes[:reverse] ||= :"#{name}_parent"
               attributes[:reverse_attributes] = {
                   :association => :tree_parent,
                   :tree_element => name
               }.merge(attributes[:reverse_attributes] || {})
               attributes[:tree_left] ||= :"#{name}_left"
               attributes[:tree_right] ||= :"#{name}_right"
               attributes[:tree_depth] ||= :"#{name}_depth"
               attributes[:tree_position] ||= :"#{name}_position"
               choice(attributes[:reverse], self, attributes[:reverse_attributes])
               element(name, self, attributes)
               order = attributes[:order] == false ? false : true
               element(attributes[:tree_left], Fixnum, :hidden => true, :tree_element => name, :order => order)
               element(attributes[:tree_right], Fixnum, :hidden => true, :tree_element => name)
               element(attributes[:tree_depth], Fixnum, :unmapped => true, :hidden => true, :tree_element => name)
               element(attributes[:tree_position], Fixnum, :unmapped => true, :hidden => true, :tree_element => name)
#               sequence(name)
               qs_module ||= Module.new
               
               qs_module.module_eval do
                   
                   define_method("#{name}_roots") do
                       qs = self.clone
                       qs.condition[attributes[:reverse]] = nil
                       qs
                   end

                   define_method("#{name}_leafs") do
                       qs = self.clone
                       qs.condition[attributes[:tree_left]] = QueryFuncs::Expression.new(":#{attributes[:tree_right]} - 1")
                       qs
                   end
                   
                   
               end
               @elements[name].attributes[:queryset_module] = qs_module
               
               def extend_queryset(qs)
		   super
                   @elements.each do |name, el|
                       qs_module = el.attributes[:queryset_module]
                       qs.extend(qs_module) if qs_module
                   end
               end
               
               (class << self; self; end).instance_eval do
                   define_method("#{name}_roots") do
                       QuerySet.autoloading(self).send("#{name}_roots")
                   end
                   
                   define_method("#{name}_leafs") do
                       QuerySet.autoloading(self).send("#{name}_leafs")
                      
                   end
                   #TODO:la condizione non viene gestita
                   define_method("#{name}_all") do |condition|
		       qs = QuerySet.static(self)
                       self.send("#{name}_roots").each do |root|
                           ta = root.tree_all(name)
                           qs += ta if ta
                       end
                       return qs
                   end
                   
               end
               
               define_method("#{name}_leaf?") do
                   element = self.class.elements[name]
                   left_el = element.attributes[:tree_left]
                   right_el = element.attributes[:tree_right]
                   left = get(left_el)
                   right = get(right_el)
                   return left == (right - 1)
               end

               
               define_method("#{name}_all") do
                   tree_all(name)
               end
               
               define_method(attributes[:tree_depth]) do
                   ivar = :"@#{ attributes[:tree_depth] }"
                   return instance_variable_get(ivar)
               end
               
               define_method("#{name}_path") do
                   element = self.class.elements[name]
                   left_el = element.attributes[:tree_left]
                   right_el = element.attributes[:tree_right]
                   left = get(left_el)
                   right = get(right_el)
                   return nil unless (left && right)
                   c = Condition.and
                   c.set(tree_left, '<', left)
                   c.set(tree_right, '>', right)
                   q = Query.new(c)
                   q.order_by(left_el)
                   return element.model.find(q)
               end
               
               define_method("#{name}_append_first") do |new_child|
                   
               end
               
               define_method("#{name}_append_after") do |new_child, child|
                   element = self.class.elements[name]
                   left_el = element.attributes[:tree_left]
                   right_el = element.attributes[:tree_right]
                   parent_el = element.attributes[:reverse]
                   if (child.get(left_el))
                       
                   end
               end
               
               define_method(attributes[:tree_position]) do
                   i = instance_variable_get("@#{attributes[:tree_position]}")
                   return i if i
                   element = self.class.elements[name]
                   left_el = element.attributes[:tree_left]
                   right_el = element.attributes[:tree_right]
                   parent_el = element.attributes[:reverse]
                   parent = self.get(parent_el)
                   return nil unless parent
                   cnt = 0
                   parent.get(name).each do |sub|
                       cnt += 1
                       break if sub == self
                   end
                   cnt = nil if cnt == 0
                   cnt
               end

           end
           
            
            def remove_element(el)
                el = el.name if el.is_a?(Spider::Model::Element)
                element = @elements[el] if @elements
                return super if !element || element.attributes[:association] != :tree
                remove_element(element.attributes[:reverse])
                remove_element(element.attributes[:tree_left])
                remove_element(element.attributes[:tree_right])
                remove_element(element.attributes[:tree_depth])
                return super
            end
            
        end

        module MapperMethods

            def before_save(obj, mode)
                @model.elements_array.select{ |el| el.attributes[:association] == :tree }.each do |el|
                    unless mode == :insert || obj.element_modified?(el.attributes[:reverse]) || obj.element_modified?(el.attributes[:tree_position])
                        next 
                    end
                    # already set by parent
                    unless obj.element_modified?(el.attributes[:tree_left])
                        if mode == :update
                            tree_remove(el, obj)
                        end
                        parent = obj.get(el.attributes[:reverse])
                        if parent
                            sub = parent.get(el.name)
                            if obj.element_modified?(el.attributes[:tree_position]) && sub.length > 0
                                pos = obj.get(el.attributes[:tree_position]) 
                                if pos == 1
                                    tree_insert_node_first(el, obj, parent)
                                else
                                    sibling_i = pos-2
                                    sub.each_index do |i|
                                        if sub[i] == obj
                                            sibling_i += 1 if i <= sibling_i
                                            break
                                        end
                                    end
                                    tree_insert_node_right(el, obj, sub[sibling_i])
                                end
                            else
                                tree_insert_node_under(el, obj, parent)
                            end
                        else
                            tree_insert_node(el, obj)
                        end
                    end
                end
                super
            end
            
            def before_delete(objects)
                @model.elements_array.select{ |el| el.attributes[:association] == :tree }.each do |el|
                    objects.each{ |obj| tree_remove(el, obj) }
                end
            end
            
            # def after_save(obj, mode)
            #     super
            #     debugger
            #     @model.elements_array.select{ |el| el.attributes[:association] == :tree }.each do |el|
            #         debugger
            #         left_el = el.attributes[:tree_left]
            #         left = obj.get(left_el)
            #         if (!left)
            #             left = sequence_next(el.name)
            #             obj.set(left_el, left)
            #         end
            #         parent = obj.get(el.attributes[:reverse])
            #         rebuild_from = parent ? parent : obj
            #         tree_rebuild(el, rebuild_from, left)
            #     end
            # end
            
            def tree_rebuild(tree_el, obj, left)
                left_el = tree_el.attributes[:tree_left]; right_el = tree_el.attributes[:tree_right]
                right = left + 1
                children = obj.get(tree_el)
                if (children)
                    children.each do |child|
                        right = child.mapper.tree_rebuild(tree_el, child, right)
                    end
                end
                obj.set(left_el, left)
                obj.set(right_el, right)
                do_update(obj)
                return right + 1
            end
            
            def tree_insert_node(tree_el, obj, left=nil)
                left_el = tree_el.attributes[:tree_left]; right_el = tree_el.attributes[:tree_right]
                left = max(right_el) + 1 unless left
                right = tree_assign_values(tree_el, obj, left)
                diff = right-left+1
                condition = Condition.new.set(right_el, '>=', left)
                bulk_update({right_el => QueryFuncs::Expression.new(":#{right_el}+#{diff}")}, condition)
                condition = Condition.new.set(left_el, '>=', left)
                bulk_update({left_el => QueryFuncs::Expression.new(":#{left_el}+#{diff}")}, condition)
                obj.get(tree_el).each do |child|
                    child.save
                end
            end
            
            def tree_assign_values(tree_el, obj, left)
                left_el = tree_el.attributes[:tree_left]; right_el = tree_el.attributes[:tree_right]
                cur = left+1
                obj.get(tree_el).each do |child|
                    cur = tree_assign_values(tree_el, child, cur) + 1
                end
                obj.set(left_el, left)
                obj.set(right_el, cur)
                cur
            end
            
            def tree_insert_node_under(tree_el, obj, parent)
                obj.set(tree_el.attributes[:reverse], parent)
                tree_insert_node(tree_el, obj, parent.get(tree_el.attributes[:tree_right]))
            end
            
            def tree_insert_node_first(tree_el, obj, parent)
                obj.set(tree_el.attributes[:reverse], parent)
                tree_insert_node(tree_el, obj, parent.get(tree_el.attributes[:tree_left])+1)
            end
            
            def tree_insert_node_left(tree_el, obj, sibling)
                obj.set(tree_el.attributes[:reverse], sibling.get(tree_el.attributes[:reverse]))
                tree_insert_node(tree_el, obj, sibling.get(tree_el.attributes[:tree_left]))
            end
            
            def tree_insert_node_right(tree_el, obj, sibling)
                obj.set(tree_el.attributes[:reverse], sibling.get(tree_el.attributes[:reverse]))
                tree_insert_node(tree_el, obj, sibling.get(tree_el.attributes[:tree_right])+1)
            end
            
            def tree_remove(tree_el, obj)
                left_el = tree_el.attributes[:tree_left]; right_el = tree_el.attributes[:tree_right]
                left = obj.get(left_el); right = obj.get(right_el)
                return unless left && right
                diff = right-left+1
                condition = Condition.new.set(left_el, '>', right)
                bulk_update({left_el => QueryFuncs::Expression.new(":#{left_el} - #{diff}")}, condition)
                condition = Condition.new.set(right_el, '>', right)
                bulk_update({right_el => QueryFuncs::Expression.new(":#{right_el} - #{diff}")}, condition)
                def unset_tree_vals(obj, tree_el)
                    left_el = tree_el.attributes[:tree_left]; right_el = tree_el.attributes[:tree_right]
                    obj.set(left_el, nil); obj.set(right_el, nil)
                    obj.get(tree_el).each do |sub|
                        unset_tree_vals(sub, tree_el)
                    end
                end
                unset_tree_vals(obj, tree_el)
            end
            
            def tree_delete(tree_el, obj)
                tree_remove(tree_el, obj)
                def delete_children(obj, tree_el)
                    obj.get(tree_el).each do |child| 
                        delete_children(child, tree_el)
                    end
                    obj.delete
                end
                delete_children(obj, tree_el)
            end
            
            def tree_move_up_children(tree_el, obj)
                left_el = tree_el.attributes[:tree_left]; right_el = tree_el.attributes[:tree_right]
                left = obj.get(left_el); right = obj.get(right_el)
                bulk_update({
                    :left_el => QueryFuncs::Expression.new(":#{left_el} - 1"),
                    :right_el => QueryFuncs::Expression.new(":#{right_el} - 1")
                }, Condition.new.set(left_el, 'between', [left, right]))
                condition = Condition.new.set(right_el, '>', right)
                bulk_update({:right_el => QueryFuncs::Expression.new(":#{right_el} - 2")}, condition)
                condition = Condition.new.set(left_el, '>', right)
                bulk_update({:left_el => QueryFuncs::Expression.new(":#{left_el} - 2")}, condition)
            end

            # Ensure that in Unit of Work parents are saved before children
            def get_dependencies(task)
                deps = super
                if task.action == :save
                    @model.elements_array.select{ |el| el.attributes[:association] == :tree }.each do |el|
                        if task.object.element_modified?(el.attributes[:reverse])
                            parent = task.object.get(el.attributes[:reverse])
                            deps << [task, MapperTask.new(parent, :save)] if parent
                        end
                    end
                end
                deps
            end
            
            
            
            
        end
        
    end
    
    
end; end
