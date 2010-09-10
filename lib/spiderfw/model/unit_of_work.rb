require 'tsort'

module Spider; module Model
    
    class UnitOfWork
        include TSort
        
        def initialize(&proc)
            @objects = {}
            @to_delete = {}
            @new_objects = []
            if (proc)
                start
                yield self
                stop
            end
        end
        
        def start
            Spider.current[:unit_of_work] = self
        end
        
        def stop
            Spider.current[:unit_of_work] = nil
        end
        
        def run #(&proc)
            #proc.call
            @tasks = {}
            @processed_tasks = {}
            while objs = new_objects
                objs.each do |obj|
                    action = @objects[obj.object_id][:action]
                    if action == :save
                        next unless obj.mapper && obj.mapper.class.write?
                        next unless obj.modified?
                        obj.save_mode do
                            obj.before_save
                        end
                    elsif action == :delete
                        obj.before_delete
                    end
                end
            end
            @objects.each do |obj_id, o|
                obj = o[:obj]
                action = o[:action]
                next unless action == :save
                next unless obj.mapper && obj.mapper.class.write?
                next unless obj.modified?
                task = Spider::Model::MapperTask.new(obj, :save)
                @tasks[task] ||= task
                find_dependencies(task)
            end
            tasks = tsort()
            Spider.logger.debug("Tasks:")
            tasks.each do |task| 
                Spider.logger.debug "-- #{task.action} on #{task.object.class} #{task.object.primary_keys}"
            end
            
            tasks.each do |task|
                #Spider::Logger.debug("Executing task #{task.inspect}")
                task.execute()
            end
            @objects.each do |obj_id, o|
                next unless o[:action] == :delete
                obj = o[:obj]
                obj.mapper.delete(obj)
            end
            @objects = {}
            @new_objects = []
        end
        
        alias :commit :run
        
        def find_dependencies(model_task)
            return if (@processed_tasks[model_task])
            @processed_tasks[model_task] = true
            dependencies = model_task.object.mapper.get_dependencies(model_task.object, model_task.action)
            dependencies.each do |dep|
                @tasks[dep[0]] ||= dep[0]
                @tasks[dep[1]] ||= dep[1]
                @tasks[dep[0]] << @tasks[dep[1]]
                find_dependencies(dep[1])
            end
        end
                
        
        def add(obj, action = :save)
            if (obj.class == QuerySet)
                obj.each do |item|
                    add(item)
                end
            else
                if curr = @objects[obj.object_id]
                    curr[:action] = :delete if action == :delete
                else
                    has_other = false
                    @new_objects.each do |cur|
                        if cur.class == obj.class && cur.primary_keys == obj.primary_keys
                            has_other = cur
                            break
                        end
                    end
                    @new_objects << obj
                    @objects[obj.object_id] = {:action => action, :obj => obj }
                    traverse(obj, action)
                end
                
            end
        end
        
        def traverse(obj, action)
            obj.class.elements_array.each do |el|
                next unless obj.element_has_value?(el)
                next unless el.model?
                add(obj.get(el), action)
            end
            
        end
        
        def to_delete(obj)
            
        end
        
        def new_objects
            objects = @new_objects.clone
            @new_objects = []
            objects.length > 0 ? objects : nil
        end
        
        
        def tsort_each_node(&block)
            @tasks.values.each(&block)
        end
        
        def tsort_each_child(node, &block)
            node.dependencies.each(&block)
        end
        
        
        
    end

    

    
    
end; end