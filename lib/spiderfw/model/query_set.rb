module Spider; module Model
    
    # The QuerySet expresses represents a Query applied on a Model.
    # It includes Enumerable, and can be accessed as an Array; but, the QuerySet is lazy, and the actual data will be
    # fetched only when actually requested, or when a #load is issued.
    # How much data is fetched and kept in memory can be controlled by setting the #fetch_window
    # and the #keep_window.
    class QuerySet
        include Enumerable
        # BaseModel instance pointing to this QuerySet
        attr_accessor :_parent
        # Element inside the _parent pointing to this QuerySet.
        attr_accessor :_parent_element
        # Raw data returned by the mapper, if requested.
        attr_reader :raw_data
        # An Hash of autoloaded elements.
        attr_reader :loaded_elements
        # The actual fetched objects.
        attr_reader :objects
        # The Query
        attr_accessor :query
        # Set by mapper
        attr_accessor :last_query # :nodoc: TODO: remove?
        # The BaseModel
        attr_accessor :model
        # Total number of objects present in the Storage for the Query
        attr_accessor :total_rows
        # (bool) Wether the QuerySet has been loaded
        attr_accessor :loaded
        # (Fixnum) How many objects to load at a time. If nil, all the objects returned by the Query 
        # will be loaded.
        attr_accessor :fetch_window
        # (Fixnum) How many objects to keep in memory when advancing the window. If nil, all objects will be kept.
        attr_accessor :keep_window
        # If something that can't be converted to a @model instance is appended to the QuerySet,
        # and append_element is set, the appended value will be set on the element named append_element
        # of a new instance of @model, which will be appended instead. This is useful for junction models,
        # which function as both types.
        # Example:
        #    cat = Animal.new; tiger = Animal.new;
        #    # Instead of doing
        #    friend = Animal::Friend.new(:animal => cat, :other_animal => tiger)
        #    cat.friends << friend
        #    # since the junction was created setting append_element = :other_animal, one can do
        #    cat.friends << lion
        attr_accessor :append_element
        # (bool) If false, prevents the QuerySet from loading.
        attr_accessor :loadable # :nodoc: TODO: remove?
        
        # Instantiates a non-autoloading queryset
        def self.static(model, query_or_val=nil)
            qs = self.new(model, query_or_val)
            qs.autoload = false
            return qs
        end
        
        def self.autoloading(model, query_or_val=nil)
            qs = self.new(model, query_or_val)
            qs.autoload = true
            return qs
        end

        # The first argument must be a BaseModel subclass.
        # The second argument may be a Query, or data that will be passed to #set_data. If data is passed,
        # the QuerySet will be instantiated with autoload set to false.
        def initialize(model, query_or_val=nil)
            @model = model
            model.extend_queryset(self)
            if (model.attributes[:integrated_models])
                model.attributes[:integrated_models].each{ |m, el| m.extend_queryset(self) }
            end
            if (query_or_val.is_a?(Query))
                 query = query_or_val 
            else
                data = query_or_val
            end
            @query = query || Query.new
            @objects = []
            @raw_data = []
            @_parent = nil
            @_parent_element = nil
            @index_lookup = {}
            @total_rows = nil
            @fetch_window = nil
            @window_current_start = nil
            @keep_window = 100
            @autoload = query_or_val.is_a?(Query) ? true : false
            @identity_mapper = nil
            @loaded = false
            @loaded_elements = {}
            @fixed = {}
            @append_element = nil
            @loadable = true
            set_data(data) if data
            self
        end
        
        
        # Model mapper.
        def mapper
            @model.mapper
        end
        
        # Sets a fixed value: it will be applied to every object.
        def fixed(name, value)
            @fixed[name] = value
        end
        
        # Enables or disables autoload; if the second argument is true, will traverse
        # contained objects.
        def autoload(bool, traverse=true)
            @autoload = bool
            @objects.each{ |obj| obj.autoload = bool } if traverse
        end
        
        # Enables or disables autoload.
        def autoload=(bool)
            autoload(bool)
        end
        
        def autoload?
            @autoload ? true : false
        end
        
        # Sets containing model and element.
        def set_parent(obj, element)
            @_parent = obj
            @_parent_element = element
        end
        
        # Disables autoload. If a block is given, the current autoload value will be restored after yielding.
        def no_autoload(traverse=true)
            prev_autoload = autoload?
            self.autoload(false, traverse)
            yield
            self.autoload(prev_autoload, traverse)
        end
        
        # Adds objects to the QuerySet. The argument must be an Enumerable (and should contain BaseModel instances).
        def set_data(data)
            if (data.is_a?(Enumerable))
                data.each do |val|
                    self << val
                end
            else
                self << data
            end
            
        end
        
        def change_model(model)
            @model = model
            @objects.each_index do |i|
                @objects[i] = @objects[i].become(model)
            end
            return self
        end

        # Adds an object to the set. Also stores the raw data if it is passed as the second parameter. 
        def <<(obj, raw=nil)
            return merge(obj) if (obj.class == QuerySet)
            unless (obj.is_a?(@model))
                obj = instantiate_object(obj)
            end
            @objects << obj
            @fixed.each do |key, val|
                obj.set(key, val)
            end
            index_object(obj)
            @raw_data[@objects.length-1] = raw if raw
        end

            
        # Accesses an object. Data will be loaded according to fetch_window.
        def [](index)
            if (index.is_a?(Range))
                return index.map{ |i| self[i] }
            elsif (index.is_a?(String))
                i, rest = index.split('.', 2)
                i = i.to_i
                val = self[i]
                return '' unless val
                return val[rest]
            end
            start = start_for_index(index)
            array_index = (index - start) + 1
            load_to_index(index) unless (@objects[array_index] && (!@fetch_window || @window_current_start == start)) || loaded?(index) || !autoload?
            val = @objects[array_index]
            val.set_parent(self, nil) if val
            return val
        end
        
        # Sets an object.
        def []=(index, val)
            #load_to_index(index) unless loaded?(index) || !autoload?
            val = instantiate_object(val) unless val.is_a?(@model)
            @fixed.each do |fkey, fval|
                val.set(fkey, fval)
            end
            array_index = index
            array_index -= @window_current_start-1 if @window_current_start
            @objects[array_index] = val
        end
        
        # Checks contained objects' loaded elements.
        def update_loaded_elements
            return if currently_empty?
            f_loaded = {}
            self.each_current do |obj|
                @loaded_elements.each do |el|
                    f_loaded[el] = false unless obj.loaded_elements[el]
                end
            end
            @loaded_elements = {}
            @loaded_elements.merge!(@objects[0].loaded_elements)
            @loaded_elements.merge!(f_loaded)
        end
        
        # Returns the last object.
        def last
            load unless (@loaded || !autoload?) && loaded?(total_rows-1)
            @objects.last
        end
        
        # Deletes object at the given index.
        def delete_at(index)
            @objects.delete_at(index)
        end
        
        # Returns a new QuerySet containing objects from both this and the other.
        def +(other)
            qs = self.clone
            other.each do |obj|
                qs << obj
            end
            return qs
        end
        
        # Number of objects fetched. Will call load if not loaded yet.
        # Note: this is not the total number of objects corresponding to the Query; 
        # it may be equal to the fetch_window, or to the @query.limit.
        def length
            load unless @loaded || !autoload?
            @objects.length
        end
        
        # Like #select, but returns an array
        alias :select_array :select
        
        # Returns a (static) QuerySet of the objects for which the block evaluates to true.
        def select(&proc)
            return QuerySet.new(@model, select_array(&proc))
        end
        
        # True if the query had a limit, and more results can be fetched.
        def has_more?
            return true if autoload? && !@loaded
            return false unless query.limit
            pos = query.offset.to_i + length
            return pos < total_rows
        end
        
        # Total number of objects that would be returned had the Query no limit.
        def total_rows
            return @total_rows ? @total_rows : @model.mapper.count(@query.condition)
        end
        
        # Current number of objects fetched.
        def current_length
            @objects.length
        end
        
        # True if no objects were fetched (yet).
        def empty?
            load unless @loaded || !autoload?
            @objects.empty?
        end
        
        def currently_empty?
            @objects.empty?
        end
        
        # Index objects by some elements.
        def index_by(*elements)
            names = elements.map{ |el| (el.class == Spider::Model::Element) ? el.name.to_s : el.to_s }
            index_name = names.sort.join(',')
            @index_lookup[index_name] = {}
            reindex
            return self
        end
        
        # Rebuild object index.
        def reindex # :nodoc:
            @index_lookup.each_key do |index|
                @index_lookup[index] = {}
            end
            each_current do |obj|
                index_object(obj)
            end
            return self
        end
        
        # Adds object to the index
        def index_object(obj) # :nodoc:
            @index_lookup.keys.each do |index_by|
                names = index_by.split(',')
                search_key = names.map{ |name| 
                    search_key(obj, name)
                }.join(',')
                (@index_lookup[index_by][search_key] ||= []) << obj
            end
        end
        
        # FIXME: ???
        def search_key(obj, name) # :nodoc:
            sub = obj.is_a?(Hash) ? obj[name] : obj.get(name.to_sym)
            if (sub.is_a?(Spider::Model::BaseModel))
                name_parts = name.to_s.split('.')
                model = @model
                name_parts.each do |part|
                    model = model.elements[part.to_sym].type
                end
                model.primary_keys.map{ |k| sub.get(k).to_s }.join(',')
            else
                sub.to_s
            end
        end
        
        # Remove all elements from self
        def clear
            @objects = []
            @index_lookup.each_key{ |k| @index_lookup[k] = {} }
        end
        
        # Remove when merging
        alias :map_array :map
        
        # Iterates on currently loaded objects
        def each_current
            @objects.each { |obj| yield obj }
        end

        # Iterates on objects, loading when needed.
        def each
            tmp = []
            prev_parents = []
            self.each_index do |i|
                obj = @objects[i]
                prev_parent = obj._parent
                prev_parent_element = obj._parent_element
                obj.set_parent(self, nil)
                tmp << obj
                prev_parents << [prev_parent, prev_parent_element]
            end
            tmp.each do |obj|
                yield obj
            end
            tmp.each_index do |i|
                prev_parent, prev_parent_element = prev_parents[i]
                tmp[i].set_parent(prev_parent, prev_parent_element)
            end
        end

        # Iterates yielding objects index. Will load when needed.
        def each_index
            @window_current_start = nil if (@fetch_window)
            while (!@fetch_window || has_more?)
                load_next unless !autoload? || (!@fetch_window && @loaded)
                @objects.each_index do |i|
                    yield i
                end
                break unless autoload? && @fetch_window
            end
        end
        
        # Iterates on indexes without loading.
        def each_current_index
            @objects.each_index do |i|
                i += @window_current_start-1 if @window_current_start
                yield i
            end
        end
        
        # Merges the content of another QuerySet.
        def merge(query_set)
            @objects += query_set.instance_variable_get(:"@objects")
            reindex
        end
        
        # Searchs the index for objects matching the given params.
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

        # Calls Query.order_by
        def order_by(*elements)
            @query.order_by *elements
            return self
        end
        
        def with_polymorphs
            @model.polymorphic_models.each do |model, attributes|
                @query.with_polymorph(model)
            end
            self
        end
        
        # Sets the value of an element on all currently loaded objects.
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
        
        # Executes the query and fetches the objects; (the next batch if a fetch_window is set).
        def load
            return self unless loadable?
            clear
            @loaded = false
            @loaded_elements = {}
            return load_next if @fetch_window && !@query.offset
            mapper.find(@query.clone, self)
            @loaded = true
            return self
        end
        
        # Start for the query to get index i
        def start_for_index(i) # :nodoc:
            return 1 unless @fetch_window
            page = i / @fetch_window + 1
            return (page - 1) * @fetch_window + 1
        end
        
        # Loads objects up to index i
        def load_to_index(i)
            return load unless @fetch_window
            page = i / @fetch_window + 1
            load_next(page)
        end
        
        # Loads the next batch of objects.
        def load_next(page=nil)
            if (@fetch_window)
                @query.limit = @fetch_window
                if (page)
                    @window_current_start = (page - 1) * @fetch_window + 1
                else
                    if (!@window_current_start)
                        @window_current_start = 1
                    else
                        @window_current_start += @fetch_window
                    end
                end
                @query.offset = @window_current_start-1
            end
            return load
        end
        
        # If a Fixnum is passed, will tell if the given index is loaded.
        # With no argument, will tell if the QuerySet is loaded
        def loaded?(index=nil)
            return @loaded if !@loaded || !index || !@fetch_window
            return false unless @window_current_start
            return true if index >= @window_current_start-1 && index < @window_current_start+@fetch_window-1
            return false
        end
        
        def loadable?
            @loadable
        end
        
        # Saves each object in the QuerySet.
        def save
            no_autoload(false){ each{ |obj| obj.save } }
        end

        # Calls #BaseModel.insert on each object in the QuerySet.        
        def insert
            no_autoload(false){ each{ |obj| obj.insert } }
        end

        # Calls #BaseModel.update on each object in the QuerySet.        
        def update
            no_autoload(false){ each{ |obj| obj.update } }
        end
        
        # Calls #BaseModel.save_all on each object in the QuerySet.
        def save_all(params={})
            @objects.each do |obj| 
#                next if (unit_of_work && !unit_of_work.save?(obj))
                obj.save_all(params)
            end
        end
        
        # Returns a new instance of @model from val.
        def instantiate_object(val=nil)
            if (@append_element && !val.is_a?(@model) && !(val.is_a?(Hash) && val[@append_element]))
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
            load unless loaded? || !autoload?
            res =  "[" +
                self.map{ |obj| obj.to_json(&proc) }.join(',') +
                "]"
            return res
        end

        
        # Returns an array with the results of calling #BaseModel.cut on each object.
        def cut(*params)
            load unless loaded? || !autoload?
            return self.map{ |obj| obj.cut(*params) }
        end
        
        # Returns an array with the results of calling #BaseModel.to_hash_array on each object.
        def to_hash_array
            return self.map{ |obj| obj.to_hash }
        end
        
        def to_indexed_hash(element)
            hash = {}
            self.each do |row|
                hash[row.get(element)] = row
            end
            hash
        end
        
        # Prints an ASCII table
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
        
        def to_a
            self.map{ |row| row }
        end
        
        def map_current
            a = []
            each_current{ |row| a << yield(row) }
            a
        end
        
        # Returns an array of Hashes, with each value of the object is converted to string.
        def to_flat_array
            map do |obj|
                h = {}
                obj.class.each_element do |el|
                    h[el.name] = obj.element_has_value?(el) ? obj.get(el).to_s : ''
                end
                h
            end
        end

        def reject!(&proc)
            @objects.reject!(&proc)
        end
        
        def to_s
            self.map{ |o| o.to_s }.join(', ')
        end
        
        def method_missing(method, *args, &proc)
            el = @model.elements[method]
            if (el && el.model? && el.reverse)
                return element_queryset(el)
            end
            return @query.send(method, *args, &proc) if @query.respond_to?(method)
            return super
        end
        
        def element_queryset(el)
            el = @model.elements[el] if el.is_a?(Symbol)
            condition = el.condition
            if (el.attributes[:element_query])
                el = @model.elements[el.attributes[:element_query]]
            end
            cond = Spider::Model::Condition.new
            cond[el.reverse] = self.map_current{ |row| row }
            cond = cond.and(condition) if (condition)
            return self.class.new(el.model, Query.new(cond))
        end
        
        # Given a dotted path, will return an array of all objects reachable by that path
        # Example
        #   objectset.all_children('friends.collegues.addresses.street_name')
        def all_children(path)
            if (path.length > 0)
                children = @objects.map{ |obj| obj.all_children(path.clone) }.flatten
            else
                return @objects
            end
        end
        
        # Registers that the element has been loaded.
        def element_loaded(element)
            element = element.name if (element.class == Element)
            @loaded_elements[element] = true
        end
        
        # Returns whether the element has been loaded from the Storage.
        def element_loaded?(element)
            element = element.name if (element.class == Element)
            @loaded_elements[element]
        end
        
        # Returns the QuerySet IdentityMapper instance
        def identity_mapper
            return Spider::Model.identity_mapper if Spider::Model.identity_mapper
            @identity_mapper ||= IdentityMapper.new
        end
        
        # Assigns an IdentityMapper
        def identity_mapper=(im)
            @identity_mapper = im
        end
        
        def with_superclass
            @query.with_superclass
            return self
        end
        
        ########################################
        # Condition, request and query methods #
        ########################################
        
        # Calls #Query.where
        def where(*params, &proc)
            @query.where(*params, &proc)
            return self
        end
        
        # Calls #Query.limit
        def limit(n)
            @query.limit = n
            return self
        end
        
        # Calls #Query.offset
        def offset(n)
            @query.offset = n
            return self
        end
        
        # def unit_of_work
        #     return Spider::Model.unit_of_work
        # end
        
        # Performs a deep copy
        def clone
            c = self.class.new(self.model, self.query.clone)
            c_objects = c.instance_variable_get(:@objects)
            @objects.each do |o|
                c_objects << o.clone
            end
            return c
        end

    end

end; end
