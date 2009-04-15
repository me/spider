module Spider; module Model

    class QuerySet
        include Enumerable
        attr_accessor :_parent, :_parent_element
        attr_reader :raw_data, :loaded_elements
        attr_accessor :query, :model, :owner, :total_rows
        attr_accessor :loaded, :fetch_window
        attr_accessor :append_element
        
        def self.static(model, query_or_val=nil)
            qs = self.new(model, query_or_val)
            qs.autoload = false
            return qs
        end

        def initialize(model, query_or_val=nil)
            if (query_or_val.is_a?(Query))
                 query = query_or_val 
            else
                data = query_or_val
            end
            @query = query || Query.new
            @model = model
            @objects = []
            @raw_data = []
            @owner = nil
            @_parent = nil
            @_parent_element = nil
            @index_lookup = {}
            @total_rows = nil
            @fetch_window = nil
            @autoload = query_or_val.is_a?(Query) ? true : false
            @identity_mapper = nil
            @loaded = false
            @loaded_elements = {}
            @fixed = {}
            @append_element = nil
            set_data(data) if data
            self
        end
        
        def mapper
            @model.mapper
        end
        
        def fixed(name, value)
            @fixed[name] = value
        end
        
        def autoload(bool, traverse=true)
            @autoload = bool
            @objects.each{ |obj| obj.autoload = bool } if traverse
        end
        
        def autoload=(bool)
            autoload(bool)
        end
        
        def autoload?
            @autoload ? true : false
        end
        
        def set_parent(obj, element)
            @_parent = obj
            @_parent_element = element
        end
                
        def no_autoload(traverse=true)
            prev_autoload = autoload?
            self.autoload(false, traverse)
            yield
            self.autoload(prev_autoload, traverse)
        end
            
        def set_data(data)
            if (data.is_a?(Enumerable))
                data.each do |val|
                    self << val
                end
            else
                self << data
            end
        end

        # Adds an object to the set. Also stores the raw data if it is passed as the second parameter. 
        def <<(obj, raw=nil)
            return merge(obj) if (obj.class == QuerySet)
            unless (obj.is_a?(@model))
                obj = instantiate_object(obj)
            end
            @objects << obj
            @loaded_elements.merge!(obj.loaded_elements)
            @fixed.each do |key, val|
                obj.set(key, val)
            end
            index_object(obj)
            @raw_data[@objects.length-1] = raw if raw
        end

            

        def [](index)
            if (index.is_a?(Range))
                return index.map{ |i| self[i] }
            end
            load unless @objects[index] || @loaded || !autoload?
            val = @objects[index]
            val.set_parent(self, nil) if val
            return val
        end
        
        def []=(index, val)
            load unless @loaded || !autoload?
            val = instantiate_object(val) unless val.is_a?(@model)
            @loaded_elements.merge!(val.loaded_elements)
            @fixed.each do |fkey, fval|
                val.set(fkey, fval)
            end
            @objects[index] = val
        end
        
        def last
            load unless @loaded || !autoload?
            @objects.last
        end
        
        def delete_at(index)
            @objects.delete_at(index)
        end
        
        def +(other)
            qs = self.clone
            other.each do |obj|
                qs << obj
            end
            return qs
        end
        
        def length
            load unless @loaded || !autoload?
            @objects.length
        end
        
        def has_more?
            return false unless query.limit
            pos = query.offset.to_i + length
            return pos < total_rows
        end
        
        def total_rows
            return @total_rows ? @total_rows : @model.mapper.count(@query.condition)
        end
        
        def current_length
            @objects.length
        end
        
        def empty?
            @objects.empty?
        end
        
        def index_by(*elements)
            names = elements.map{ |el| (el.class == Spider::Model::Element) ? el.name.to_s : el.to_s }
            index_name = names.sort.join(',')
            @index_lookup[index_name] = {}
            reindex
            return self
        end
        
        def reindex
            @index_lookup.each_key do |index|
                @index_lookup[index] = {}
            end
            no_autoload(false) do
                each do |obj|
                    index_object(obj)
                end
            end
            return self
        end
        
        def index_object(obj)
            @index_lookup.keys.each do |index_by|
                names = index_by.split(',')
                search_key = names.map{ |name| 
                    search_key(obj, name)
                }.join(',')
                (@index_lookup[index_by][search_key] ||= []) << obj
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
            load unless @loaded || !autoload?
            @objects.each do |obj| 
                obj.set_parent(self, nil)
                yield obj
            end
        end

        def each_index
            load unless @loaded || !autoload?
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
            #@objects = result
            return QuerySet.new(@model, result)
        end

        def order_by(*elements)
            @query.order_by *elements
            return self
        end
        
        def set(element, value)
            element_name = element.is_a?(Element) ? element.name : element
            fixed(element_name, value)
#            @query.condition.set(element, '=', value)
            no_autoload(false) do
                each do |obj|
                    obj.set(element_name, value)
                end
            end
        end
        
        def load
            mapper.find(@query, self)
            @loaded = true
        end
        
        def save
            no_autoload(false){ each{ |obj| obj.save } }
        end
        
        def insert
            no_autoload(false){ each{ |obj| obj.insert } }
        end
        
        def update
            no_autoload(false){ each{ |obj| obj.update } }
        end
        

        def save_all(params={})
            @objects.each do |obj| 
#                next if (unit_of_work && !unit_of_work.save?(obj))
                obj.save_all(params)
            end
        end
        
        def instantiate_object(val=nil)
            if (@append_element && !val.is_a?(@model))
                val = @model.elements[@append_element].type.new(val) unless (val.is_a?(BaseModel))
                val = {@append_element => val}
            end
                
            obj = @model.new(val)
            obj.identity_mapper = @identity_mapper
            obj.autoload = autoload?
            @fixed.each do |key, fval|
                obj.set(key, fval)
            end
            return obj
        end
        
        def inspect
            return "#{self.class.name}:\n@model=#{@model}, @query=#{query.inspect}, @objects=#{@objects.inspect}"
        end
        
        def to_json(state=nil, &proc)
            load unless @loaded || !autoload?
            res =  "[" +
                self.map{ |obj| obj.to_json(&proc) }.join(',') +
                "]"
            return res
        end

        
        def cut(*params)
            load unless @loaded || !autoload?
            return self.map{ |obj| obj.cut(*params) }
        end
        
        def to_hash_array
            return self.map{ |obj| obj.to_hash }
        end
        
        def table
            return print("Empty\n") if length < 1
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
        
        def method_missing(method, *args, &proc)     
            return @query.send(method, *args, &proc)
        end
        
        def all_children(path)
            if (path.length > 0)
                children = @objects.map{ |obj| obj.all_children(path.clone) }.flatten
            else
                return @objects
            end
        end
        
        def element_loaded(element)
            element = element.name if (element.class == Element)
            @loaded_elements[element] = true
        end
        
        def element_loaded?(element)
            element = element.name if (element.class == Element)
            @loaded_elements[element]
        end
        
        def identity_mapper
            return Spider::Model.identity_mapper if Spider::Model.identity_mapper
            @identity_mapper ||= IdentityMapper.new
        end
        
        def identity_mapper=(im)
            @identity_mapper = im
        end
        
        ########################################
        # Condition, request and query methods #
        ########################################
        
        def where(*params, &proc)
            @query.where(*params, &proc)
            return self
        end
        
        def limit(n)
            @query.limit = n
            return self
        end
        
        def offset(n)
            @query.offset = n
            return self
        end
            
        
                    
        
        # def unit_of_work
        #     return Spider::Model.unit_of_work
        # end
        
        def clone
            self.class.new(self.model, self.query.clone)
        end

    end

end; end
