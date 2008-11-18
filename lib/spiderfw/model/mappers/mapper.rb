module Spider; module Model
    
    class Mapper
        
        def initialize(model, storage)
            @model = model
            @storage = storage
            @raw_data = {}
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
            @model.elements.select{ |n, el| el.model? && obj.element_has_value?(el) }.each do |name, element|
                val = obj.get(name)
                if (val.is_a? Array)
                    val.each_index { |i| val[i] = @model.new(val[i]) }
                    obj.set(name, val)
                else
                    val = @model.new(val)
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
                integrate(query.request, result[0], obj)
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
            result = fetch(query)
            set = query_set || QuerySet.new(@model)
            set.index_by(*@model.primary_keys)
            set.query = query
            return set unless result
            result.each do |row|
                obj = @model.new
                @raw_data[obj.object_id] = row
                set << integrate(query.request, row, obj)
            end
            set = get_external(set, query)
            return set
        end
        
        def fetch(query)
            raise MapperException, "Unimplemented"
        end
        
        def integrate(request, result, obj)
            raise MapperException, "Unimplemented"
        end
        
        # Load external elements, according to query, 
        # and merge them into an object or an QuerySet
        def get_external(objects, query)
            # Make "objects" an array if it is not an QuerySet; the methods used are common to the two classes
            objects = [objects] unless objects.kind_of?(Spider::Model::QuerySet)
            query.request.each_key do |element_name|
                element = @model.elements[element_name]
                if element.model?
                    sub_query = Query.new
                    sub_query.request = ( query.request[element_name].class == Request ) ? query.request[element_name] : nil
                    sub_query.condition = element.attributes[:condition] if element.attributes[:condition]
                    objects = get_external_element(element, sub_query, objects)
                end
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
        
        def prepare_integrate_value(type, value)
            raise MapperException, "Unimplemented"
        end
        
        
        ##############################################################
        #   Strategy                                                 #
        ##############################################################

        def prepare_query(query)
            @model.primary_keys.each do |key|
                query.request[key] = true
            end
            return query
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