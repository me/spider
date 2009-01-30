require 'tsort'

module Spider; module Model
    
    class Sync
        include TSort
        
        def initialize
            @models = {}
            @processed = {}
        end
        
        def dump(model, remote)
            collect_dependencies(model)
            tasks = tsort
            
        end
        
        def tsort_each_node(&block)
            @models.each_value(&block)
        end
        
        def tsort_each_child(node, &block)
            node.dependencies.each(&block)
        end
        
        def collect_dependencies(model)
            @processed[model] = true
            @models[model] ||= SyncTask.new(model)
            model.elements_array.select{ |el| el.model? && model.mapper.have_references?(el) }.each do |el|
                @models[el.model] ||= SyncTask.new(el.model)
                @models[model] << @models[el.model]
            end
            model.elements_array.select{ |el| el.model? }.each do |el|
                collect_dependencies(el.model) unless @processed[el.model]
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