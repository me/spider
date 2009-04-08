require 'tsort'

module Spider; module Model
    
    class UnitOfWork
        include TSort
        
        def initialize(&proc)
            @objects = {}
            if (proc)
                Thread.current[:unit_of_work] = self
                yield self
                Thread.current[:unit_of_work] = nil
            end
        end
        
        def run() #(&proc)
            #proc.call
            @tasks = {}
            @processed_tasks = {}
            @objects.each do |obj_id, obj|
                next unless obj.mapper && obj.mapper.class.write?
                task = Spider::Model::MapperTask.new(obj, :save)
                @tasks[task] ||= task
                find_dependencies(task)
            end
            tasks = tsort()
            tasks.each{ |task| p task}
            tasks.each do |task|
                Spider::Logger.debug("Executing task #{task.inspect}")
                task.execute()
            end
        end
        
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
                
        
        def add(obj)
            if (obj.class == QuerySet)
                obj.each do |item|
                    @objects[item.object_id] = item
                end
            else
                @objects[obj.object_id] = obj
            end
        end
        
        
        def tsort_each_node(&block)
            @tasks.values.each(&block)
        end
        
        def tsort_each_child(node, &block)
            node.dependencies.each(&block)
        end
        
        
        
    end

    

    
    
end; end