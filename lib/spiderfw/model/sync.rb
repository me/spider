require 'tsort'

module Spider; module Model
    
    class Sync
        include TSort
        
        def initialize
            @model_tasks = {}
            @processed_deps = {}
            @processed = {}
        end
        
        def add(models)
            models = [models] unless models.is_a?(Array)
            models.each do |model|
                collect_dependencies(model)
            end
        end
        
        def sorted
            tasks = tsort
            tasks.map{ |t| t.model }
        end
        
        def each
            sorted.each do |model|
                yield model
            end
        end
        
        def length
          @model_tasks.keys.length
        end
        
        # def dump(model, model_server)
        #     collect_dependencies(model)
        #     tasks = tsort
        # end
        # 
        # def fetch!(model, model_server)
        #     model.mapper.delete_all!
        #     collect_dependencies(model)
        #     tasks = tsort
        #     tasks.each do |task|
        #         res = model_server.all(model.name)
        #         res.each do |obj|
        #             debugger
        #             model.mapper.insert(obj)
        #         end
        #     end
        # end
        
        def tsort_each_node(&block)
            @model_tasks.each_value(&block)
        end
        
        def tsort_each_child(node, &block)
            node.dependencies.each(&block)
        end
        
        def collect_dependencies(model)
            return collect_dependencies(model.superclass) if model.attributes[:inherit_storage]
            return if model.subclass_of?(Spider::Model::InlineModel)
            @processed_deps[model] = true
            @model_tasks[model] ||= SyncTask.new(model)
            model.elements_array.select{ |el| el.model? && model.mapper.have_references?(el) }.each do |el|
                @model_tasks[el.model] ||= SyncTask.new(el.model)
                @model_tasks[model] << @model_tasks[el.model]
            end
            model.elements_array.select{ |el| el.model? }.each do |el|
                collect_dependencies(el.model) unless @processed_deps[el.model]
            end
        end
        
        class SyncTask
            attr_reader :model, :dependencies
            
            def initialize(model)
                @model = model
                @dependencies = []
            end
            
            def <<(model)
                @dependencies << model
            end
            
            def eql?(other)
                @model == other.model
            end
            
            def inspect
                "#{@model.name} -> (#{dependencies.map{|d| d.model.name }.join(', ')})"
            end
                
        end
        
    end
    
end; end
