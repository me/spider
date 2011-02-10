require 'tsort'

module Spider; module Model
    
    class UnitOfWork
        include TSort
        
        def initialize(&proc)
            @objects = {}
            @actions = {}
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
                    @actions[obj.object_id].each do |action, params|
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
            end
            @running = true
            @objects.each do |obj_id, obj|
                @actions[obj_id].each do |action, params|
                    if action == :save
                        next unless obj.mapper && obj.mapper.class.write?
                        next unless obj.modified?
                    end
                    task = Spider::Model::MapperTask.new(obj, action, params)
                    @tasks[task] = task
                end
            end
            @tasks.clone.each do |k, task|
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
            @objects = {}
            @new_objects = []
            @running = false
        end
        
        def running?
            @running
        end
        
        alias :commit :run
        
        def find_dependencies(model_task)
            return if (@processed_tasks[model_task])
            @processed_tasks[model_task] = true
            dependencies = model_task.object.mapper.get_dependencies(model_task.object, model_task.action).uniq
            dependencies.each do |dep|
                had0 = @tasks[dep[0]]
                @tasks[dep[0]] ||= dep[0]
                had1 = @tasks[dep[1]]
                @tasks[dep[1]] ||= dep[1]
                @tasks[dep[0]] << @tasks[dep[1]]
                find_dependencies(dep[0]) unless had0
                find_dependencies(dep[1]) unless had1
            end
        end
                
        
        def add(obj, action = :save, params = {})
            raise "Objects can't be added to the UnitOfWork while it is running" if @running
            if (obj.class == QuerySet)
                obj.each do |item|
                    add(item, action, params)
                end
                return
            end
            curr = @actions[obj.object_id]
            if curr && (curr_act = curr.select{ |c| c[0] == action }).length > 0
                curr_act.each{ |c| c[1] = params}
                return
            end
            if action == :delete # FIXME: abstract
                @actions[obj.object_id] = []
            end
            @actions[obj.object_id] ||= []
            @actions[obj.object_id] << [action, params]
            @objects[obj.object_id] = obj
            @new_objects << obj unless curr
            traverse(obj, action, params) if action == :save
        end
        
        def traverse(obj, action, params)
            obj.class.elements_array.each do |el|
                next unless obj.element_has_value?(el)
                next unless el.model?
                add(obj.get(el), action, params)
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