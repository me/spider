module Spider; module Model

    class QuerySet
        include Enumerable
        attr_reader :raw_data
        attr_accessor :query, :owner

        def initialize(source=nil)
            @query = Query.new
            if (source.class == Array)
                @objects = source
            else
                @objects = []
            end
            @raw_data = []
            @owner = nil
            @index_lookup = {}
        end

        # Adds an object to the set. Also stores the raw data if it is passed as the second parameter. 
        def <<(obj, raw=nil)
            return merge(obj) if (obj.class == QuerySet)
            @objects << obj
            index_object(obj)
            @raw_data[@objects.length-1] = raw if raw
        end

        def [](key)
            @objects[key]
        end
        
        def length
            @objects.length
        end
        
        def index_by(*elements)
            names = elements.map{ |el| (el.class == Spider::Model::Element) ? el.name.to_s : el.to_s }
            index_name = names.sort.join(',')
            @index_lookup[index_name] = {}
            reindex
        end
        
        def reindex
            @index_lookup.each_key do |index|
                @index_lookup[index] = {}
            end
            each do |obj|
                index_object(obj)
            end
        end
        
        def index_object(obj)
            @index_lookup.keys.each do |index_by|
                names = index_by.split(',')
                search_key = names.map{ |name| obj.get(name).to_s }.join(',')
                @index_lookup[index_by][search_key] ||= [] << obj
            end
        end

        def each
            @objects.each{ |obj| yield obj }
        end

        def each_index
            @objects.each_index{ |index| yield index }
        end
        
        def merge(query_set)
            @objects += query_set.instance_variable_get(:"@objects")
            reindex
        end
        
        def find(params)
            sorted_keys = params.keys.sort
            index = sorted_keys.map{ |key| key.to_s }.join(',')
            search_key = sorted_keys.map{ |key| params[key].to_s }.join(',')
            # TODO: implement find without index
            raise UnimplementedError, "find without an index is not yet implemented" unless @index_lookup[index]
            result = @index_lookup[index][search_key]
            result = QuerySet.new(result) if (result)
            return result
        end

        def order_by(*elements)
            @query.order_by *elements
        end

        def save_all(params={})
            @objects.each do |obj| 
#                next if (unit_of_work && !unit_of_work.save?(obj))
                obj.save_all(params)
            end
        end
        
        def inspect
            return "Query:#{query.inspect}\nObjects:#{@objects.inspect}"
        end
        
        # def unit_of_work
        #     return Spider::Model.unit_of_work
        # end

    end

end; end