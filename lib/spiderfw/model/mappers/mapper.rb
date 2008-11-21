module Spider; module Model
    
    class Mapper
        
        def initialize(model, storage)
            @model = model
            @storage = storage
            @raw_data = {}
            @options = {}
            @no_map_elements = {}
        end
        
        
        # Configuration methods
        
        def no_map(*els)
            els.each{ |el| @no_map_elements[el] = true }
        end
        
        def mapped?(element)
            element = element.name if (element.is_a? Element)
            return false if @no_map_elements[element]
            return true
        end
        
        # Utility methods
        
        def map_elements
            @model.elements_array.select{ |el| !@no_map_elements[el.name] }
        end
        
        def execute_action(action, object)
            case action
            when :save
                save(object)
            when :keys
                # do nothing; keys will be set by save
            else
                raise MapperException, "#{action} action not implemented"
            end
        end
        
        def normalize(obj)
            @model.elements.select{ |n, el| 
                    mapped?(el) &&  el.model? && obj.element_has_value?(el) 
            }.each do |name, element|
                val = obj.get(name)
                next if (val.is_a?(BaseModel) || val.is_a?(QuerySet))
                if (val.is_a? Array)
                    val.each_index { |i| val[i] = @model.new(val[i]) }
                    obj.set(name, val)
                else
                    val = element.model.new(val)
                    obj.set(name, val)
                end
            end
        end
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        def save(obj)
            normalize(obj)
            if (obj.primary_keys_set?)
                update(obj)
            else
                insert(obj)
            end
        end
        
        def insert
            raise MapperException, "Unimplemented"
        end
        
        def update
            raise MapperException, "Unimplemented"
        end
        
        ##############################################################
        #   Load (and find)                                          #
        ##############################################################        
        
        def load(obj, query)
            query = prepare_query(query)
            result = fetch(query)
            if (result && result[0])
                @raw_data[obj.object_id] ||= {}; @raw_data[obj.object_id].merge!(result[0])
                map(query.request, result[0], obj)
            end
            get_external(obj, query)
            return obj
        end
        
        
        def find(query, query_set=nil)
            # if (query.class == String)
            #     q = Query.new
            #     q.parse_xsql(query)
            #     query = q
            # end
            query = prepare_query(query)
            query.request.total_rows = true unless query.request.total_rows = false
            result = fetch(query)
            set = query_set || QuerySet.new(@model)
            set.index_by(*@model.primary_keys)
            set.query = query
            return set unless result
            set.total_rows = result.total_rows
            result.each do |row|
                obj = set.model.new
                @raw_data[obj.object_id] = row
                set << map(query.request, row, obj)
            end
            set = get_external(set, query)
            return set
        end
        
        def count(condition)
            query = Query.new(condition)
            result = fetch(query)
            return result.length
        end
        
        def fetch(query)
            raise MapperException, "Unimplemented"
        end
        
        def map(request, result, obj)
            raise MapperException, "Unimplemented"
        end
        
        # Load external elements, according to query, 
        # and merge them into an object or an QuerySet
        def get_external(objects, query)
            # Make "objects" an array if it is not an QuerySet; the methods used are common to the two classes
            objects = [objects] unless objects.kind_of?(Spider::Model::QuerySet)
            get_integrated = {}
            query.request.each_key do |element_name|
                element = @model.elements[element_name]
                next unless element && mapped?(element)
                if element.integrated?
                   get_integrated[element.integrated_from] ||= Request.new
                   get_integrated[element.integrated_from][element_name] = query.request[element_name]
                elsif element.model?
                    sub_query = Query.new
                    sub_query.request = ( query.request[element_name].class == Request ) ? query.request[element_name] : nil
                    sub_query.condition = element.attributes[:condition] if element.attributes[:condition]
                    objects = get_external_element(element, sub_query, objects)
                end
            end
            get_integrated.each do |integrated, request|
                sub_query = Query.new(nil, request)
                objects = get_external_element(integrated, sub_query, objects)
            end
                
            return objects
        end
        
        
        def load_element(obj, element)
            query = Query.new
            if (element.model?)
                query.request[element] = Request.new
                element.model.elements.each do |name, el|
                    query.request[element.name][name] = true unless (el.model?)
                end
            else
                query.request[element] = true
            end
            @model.primary_keys.each do |key|
                val = obj.instance_variable_get("@#{key.name}")
                raise MapperException, "Object's primary keys don't have a value. Can't load object." unless val
                query.condition[key.name] = val
            end
            load(obj, query)
        end
        
        
        def prepare_map_value(type, value)
            raise MapperException, "Unimplemented"
        end
        
        
        ##############################################################
        #   Strategy                                                 #
        ##############################################################

        def prepare_query(query)
            @model.primary_keys.each do |key|
                query.request[key] = true
            end
            prepare_query_condition(query.condition)
            return query
        end
        
        # FIXME: better name, move somewhere else
        def prepare_query_condition(condition)
            condition.each_with_comparison do |k, v, c|
                if (@model.elements[k].integrated?)
                    condition.delete(k)
                    integrated_from = @model.elements[k].integrated_from
                    condition.set("#{integrated_from}.name", v, c)
                end 
            end
            condition.subconditions.each do |sub|
                prepare_query_condition(sub)
            end
        end
        
        
        ##############################################################
        #   Helper methods                                           #
        ##############################################################
        
        
        # Increments a named sequence and returns the new value
        def next_sequence(name)
            dir = @model.name.sub('::Models', '').gsub('::', '/')
            FileUtils.mkpath('var/sequences/'+dir)
            path = 'var/sequences/'+dir+'/'+name
            seq = 0
            File.open(path, 'a+') do |f|
                f.rewind
                f.flock File::LOCK_EX
                seq = f.gets.to_i
                f.close
            end
            seq += 1
            File.open(path, 'w+') do |f|
                f.print(seq)
                f.flock File::LOCK_UN
                f.close
            end
            return seq
        end
        
        
        
        
    end
    
    ##############################################################
    #   MapperTask                                               #
    ##############################################################
    
    class MapperTask
        attr_reader :dependencies, :object, :action
       
        def initialize(object, action)
            @object = object
            @action = action
            @dependencies = []
        end
        
        def <<(task)
            @dependencies << task
        end
        
        def execute()
            p "Executing #{@action} on #{@object}"
            @object.mapper.execute_action(@action, @object)
        end
        
        def eql?(task)
            return false unless task.class == self.class
            return false unless (task.object == self.object && task.action == self.action)
            return true
        end
        
        def hash
            return @object.hash + @action.hash
        end
        
        def ===(task)
            return eql?(task)
        end
        
        
        def inspect
            if (@action && @object)
                str = "#{@action} on #{@object}\n"
                str += "-dependencies:\n"
                @dependencies.each do |dep|
                    str += "---#{dep.action} on #{dep.object}\n"
                end
            else
                str = "Root Task"
            end
            return str
        end
        
    end
    
    
    ##############################################################
    #   Exceptions                                               #
    ##############################################################
    
    class MapperException < RuntimeError
    end
    
end; end