module Spider; module Model

    class QuerySet
        include Enumerable
        attr_reader :raw_data
        attr_accessor :query, :model, :owner, :total_rows

        def initialize(model, query=nil)
            @query = query || Query.new
            @model = model
            @objects = []
            @raw_data = []
            @owner = nil
            @index_lookup = {}
            @total_rows = nil
        end
        
        def mapper
            @model.mapper
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
        
        def []=(key, val)
            @objects[key] = @model.new(val)
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
                search_key = names.map{ |name| 
                    search_key(obj, name)
                }.join(',')
                @index_lookup[index_by][search_key] ||= [] << obj
            end
        end
        
        def search_key(obj, name)
            sub = obj.is_a?(Hash) ? obj[name] : obj.get(name.to_sym)
            if (sub.is_a?(Spider::Model::BaseModel))
                @model.elements[name.to_sym].type.primary_keys.map{ |k| sub.get(k).to_s }.join(',')
            else
                sub.to_s
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
            sorted_keys = params.keys.map{|k| k.to_s}.sort.map{|k| k.to_sym}
            index = sorted_keys.map{ |key| key.to_s }.join(',')
            search_key = sorted_keys.map{ |key| search_key(params, key) }.join(',')
            # TODO: implement find without index
            raise UnimplementedError, "find without an index is not yet implemented" unless @index_lookup[index]
            result = @index_lookup[index][search_key]
            #result = QuerySet.new(result) if (result)
            @objects = result
            return result
        end

        def order_by(*elements)
            @query.order_by *elements
        end
        
        def load
            mapper.find(@query, self)
        end
        

        def save_all(params={})
            @objects.each do |obj| 
#                next if (unit_of_work && !unit_of_work.save?(obj))
                obj.save_all(params)
            end
        end
        
        def inspect
            return "#{self.class.name}:\n@model=#{@model}, @query=#{query.inspect}, @objects=#{@objects.inspect}"
        end
        
        def to_json
            return "[" +
                @objects.map{ |obj| obj.to_json }.join(',') +
                "]"
        end
        
        def table
            return print "Empty\n" if length < 1
            columns = ENV['COLUMNS'].to_i || 80
            a = to_flat_array
            m_sizes = Hash.new(0) # one separator column
            a.each do |row|
                row.each do |key, val|
                    m_sizes[key] = val.length if val.length > m_sizes[key]
                end
            end
            elements = @model.elements_array.select{ |el| m_sizes[el.name] > 0}
            elements.each do |el|
                m_sizes[el.name] = el.label.length if el.label.length > m_sizes[el.name] + 1
            end
            reduce = columns.to_f/(m_sizes.values.inject{ |sum, s| sum + s })
            sizes = {}
            m_sizes.each_key { |k| sizes[k] = m_sizes[k] * reduce }
            avail = columns - sizes.values.inject{ |sum, s| sum + s }
            while avail > 0 && (truncated = sizes.reject{ |k, v| v < m_sizes[k] }).length > 0
                truncated.each_key do |k|
                    break if avail < 1
                    sizes[k] += 1; avail -= 1
                end
            end
            print "\n"
            1.upto(columns) { print "-" }
            print "\n"
            elements.each do |el|
                print "|"
                print el.label[0..sizes[el.name]].ljust(sizes[el.name])
            end
            print "\n"
            1.upto(columns) { print "-" }
            print "\n"
            a.each do |row|
                elements.each do |el|
                    print "|"
                    print row[el.name][0..sizes[el.name]].ljust(sizes[el.name])
                end
                print "\n"
            end
            1.upto(columns) { print "-" }
            print "\n"
            
        end
        
        def to_flat_array
            map do |obj|
                h = {}
                obj.class.each_element do |el|
                    h[el.name] = obj.element_has_value?(el) ? obj.get(el).to_s : ''
                end
                h
            end
        end                    
                    
        
        # def unit_of_work
        #     return Spider::Model.unit_of_work
        # end

    end

end; end