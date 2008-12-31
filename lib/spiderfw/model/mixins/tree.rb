module Spider; module Model
    
    module Tree
        
        def self.included(model)
            model.extend(ClassMethods)
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
            q.order_by(left_el)
            res = element.model.find(q)
            right_stack = []
            res.each do |obj|
                if (right_stack.length > 0)
                    right_stack.pop while (right_stack[right_stack.length-1] < obj.get(right_el))
                    obj.set(element.attributes[:tree_depth], right_stack.length)
                end
                right_stack << obj.get(right_el)
            end
            return res
        end
        
        module ClassMethods
            
           def tree(name, attributes={})
               attributes[:association] = :tree
               attributes[:multiple] = true
               attributes[:reverse] ||= :"#{name}_parent"
               attributes[:tree_left] ||= :"#{name}_left"
               attributes[:tree_right] ||= :"#{name}_right"
               attributes[:tree_depth] ||= :"#{name}_depth"
               element(attributes[:reverse], self, :association => :tree_parent, :read_only => true)
               element(name, self, attributes)
               element(attributes[:tree_left], Fixnum)
               element(attributes[:tree_right], Fixnum)
               element(attributes[:tree_depth], Fixnum, :unmapped => true)
               sequence(name)
               
               (class << self; self; end).instance_eval do
                   
                   define_method("#{name}_roots") do
                       element = self.elements[name]
                       c = Condition.and
                       c[element.reverse] = nil
                       return find(c)
                   end
                   
                   define_method("#{name}_leafs") do
                       if mapper.type != :db
                           raise MapperException, "The #{name}_leafs method is supported only for db storage"
                       end
                       element = self.elements[name]
                       left_el = element.attributes[:tree_left]; right_el = element.attributes[:tree_right]
                       left_field = mapper.schema.field(left_el); right_field = mapper.schema.field(right_el)
                       sql = "SELECT * FROM #{mapper.schema.table} WHERE #{left_field} = #{right_field} - 1"
                       return mapper.find_by_sql(sql)
                   end
                   
                   define_method("#{name}_all") do
                       qs = QuerySet.new(self)
                       self.send("#{name}_roots").each do |root|
                           qs += root.tree_all(name)
                       end
                       return qs
                   end
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

               with_mapper do

                   def after_save(obj)
                       super
                       @model.elements_array.select{ |el| el.attributes[:association] == :tree }.each do |el|
                           left_el = el.attributes[:tree_left]
                           left = obj.get(left_el)
                           if (!left)
                               left = sequence_next(el.name)
                               obj.set(left_el, left)
                           end
                           parent = obj_get(el.attributes[:reverse])
                           rebuild_from = parent ? parent : obj
                           tree_rebuild(el, rebuild_from, left)
                       end
                   end
                   
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

                   
               end

           end
            
        end
        
    end
    
    
end; end
