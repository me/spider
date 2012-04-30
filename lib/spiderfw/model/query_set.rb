module Spider; module Model
    
    # The QuerySet expresses represents a Query applied on a Model.
    # It includes Enumerable, and can be accessed as an Array; but, the QuerySet is lazy, and the actual data will be
    # fetched only when actually requested, or when a {#load} is issued.
    # How much data is fetched and kept in memory can be controlled by setting the {#fetch_window}
    # and the {#keep_window}.
    class QuerySet
        include Enumerable
        # BaseModel instance pointing to this QuerySet
        # @return [BaseModel]
        attr_accessor :_parent
        # Element inside the _parent pointing to this QuerySet.
        # @return [Element]
        attr_accessor :_parent_element
        # Disables parent setting for this QuerySet
        # @return [bool]
        attr_accessor :_no_parent
        # Raw data returned by the mapper, if requested.
        # @return [Hash]
        attr_reader :raw_data
        # An Hash of autoloaded elements.
        # @return [Hash]
        attr_reader :loaded_elements
        # The actual fetched objects.
        # @return [Array]
        attr_reader :objects
        # The Query
        # @return [Model::Query]
        attr_accessor :query
        # Set by mapper
        # @return [Model::Query]
        attr_accessor :last_query # :nodoc: TODO: remove?
        # The BaseModel subclass
        # @return [Class<BaseModel]
        attr_accessor :model
        # Total number of objects present in the Storage for the Query
        # @return [Fixnum]
        attr_accessor :total_rows
        # Whether the QuerySet has been loaded
        # @return [bool]
        attr_reader :loaded
        # How many objects to load at a time. If nil, all the objects returned by the Query 
        # will be loaded.
        # @return [Fixnum]
        attr_accessor :fetch_window
        #  How many objects to keep in memory when advancing the window. If nil, all objects will be kept.
        # @return [Fixnum]
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
        # @return [Element]
        attr_accessor :append_element
        # If false, prevents the QuerySet from loading.
        # @return [bool]
        attr_accessor :loadable
        # If bool, on't put this queryset's objects into the IdentityMapper
        # @return [bool]
        attr_accessor :_no_identity_mapper
        # @return [bool] True when the QuerySet has been modified after loading
        attr_accessor :modified
        
        # Instantiates a non-autoloading queryset
        # @param [Class<BaseModel] model
        # @param [Query|Object] query_or_val see {QuerySet.new}
        # @return [QuerySet]
        def self.static(model, query_or_val=nil)
            qs = self.new(model, query_or_val)
            qs.autoload = false
            return qs
        end
        
        # Instantiates an autoloading queryset
        # @param [Class<BaseModel] model
        # @param [Query|Object] query_or_val see {QuerySet.new}
        # @return [QuerySet]
        def self.autoloading(model, query_or_val=nil)
            qs = self.new(model, query_or_val)
            qs.autoload = true
            return qs
        end

        # @param [Class<BaseModel] model The BaseModel subclass
        # @param [Query|Array|BaseModel] query_or_val Can be a Query, or data.
        #                                             * If a Query is given, the QuerySet will autoload using Query.
        #                                             * If data is given, the QuerySet will be static (not autoloading), 
        #                                               and the data will be passed to {#set_data}.
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
        
        
        # @return [Model::Mapper] The model's mapper
        def mapper
            @model.mapper
        end
        
        # Sets a fixed value: it will be applied to every object.
        # @param [Symbol] name
        # @param [Object] value
        # @return [void]
        def fixed(name, value)
            @fixed[name] = value
        end
        
        # Enables or disables autoload; if the second argument is true, will traverse
        # contained objects.
        # @param [bool] value Enable or disable autoload
        # @param [bool] traverse If true, set autoload to value on contained objects as well
        # @return [void]
        def autoload(value, traverse=true)
            @autoload = value
            @objects.each{ |obj| obj.autoload = value } if traverse
        end
        
        # See #{#autoload}
        # @param [bool] value
        # @return [void]
        def autoload=(bool)
            autoload(bool)
        end
        
        # @return [bool] True if autoload is enabled, False otherwise
        def autoload?
            @autoload ? true : false
        end
        
        # Sets containing model and element.
        # @param [BaseModel] obj
        # @param [Symbol] element Name of the element inside the parent which points to this QuerySet
        # @return [void]
        def set_parent(obj, element)
            @_parent = obj
            @_parent_element = element
        end
        
        # Disables autoload. If a block is given, the current autoload value will be restored after yielding.
        # @param [bool] traverse If true, apply to children as well
        # @return [void]
        def no_autoload(traverse=true)
            prev_autoload = autoload?
            self.autoload(false, traverse)
            yield
            self.autoload(prev_autoload, traverse)
        end
        
        # Adds objects to the QuerySet
        # @param [Enumerable|Object] data If the argument is an Enumerable, its contents will be appendend to the QuerySet;
        #                                 otherwise, the object will be appended.
        # @return [void]
        def set_data(data)
            if (data.is_a?(Enumerable))
                data.each do |val|
                    self << val
                end
            else
                self << data
            end
            
        end
        
        # Changes the model of the QuerySet; will call {BaseModel#become} on children.
        # @param [Class<BaseModel] model The model to change to
        # @return [self]
        def change_model(model)
            @model = model
            @objects.each_index do |i|
                @objects[i] = @objects[i].become(model)
            end
            return self
        end

        # Adds an object to the set. Also stores the raw data if it is passed as the second parameter. 
        # @param [BaseModel] obj The object to add
        # @param [Hash] raw Optional raw data associated to the object
        # @return [void]
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
            @modified = true
        end

            
        # Accesses an object. Data will be loaded according to fetch_window.
        # @param [Fixnum] index
        # @return [BaseModel]
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
            val.set_parent(self, nil) if val && !@_no_parent
            return val
        end
        
        # Sets an object
        # @param [Fixnum] index
        # @param [BaseModel] val
        # @return [void]
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
        
        # Ensures children's loaded_elments match the QuerySet's ones.
        # @return [void]
        def update_loaded_elements

            return if currently_empty?
            f_loaded = {}
            @loaded_elements = {}
            @loaded_elements.merge!(@objects[0].loaded_elements)
            self.each_current do |obj|
                @loaded_elements.each do |el, val|
                    f_loaded[el] = false unless obj.loaded_elements[el]
                end
            end
            @loaded_elements.merge!(f_loaded)
        end
        
        # @return [true] True if the QuerySet, or any of its children, has been modified since loading
        def modified?
            return true if @modified
            @objects.each do |obj|
                return true if obj.modified?
            end
            return false
        end
        
        # @return [BaseModel] The last object in the QuerySet
        def last
            load unless (@loaded || !autoload?) && loaded?(total_rows-1)
            @objects.last
        end
        
        # Removes the object at the given index from the QuerySet
        # @param [Fixnum] index
        # @return [BaseModel|nil] The removed object
        def delete_at(index)
            @objects.delete_at(index)
        end

        # Deletes every element for which block evaluates to true
        # @return [nil]
        def delete_if(&proc)
            @objects.delete_if(&proc)
        end
        
        # Removes the given object from the QuerySet
        # @param [BaseModel] obj
        # @return [BaseModel|nil] The removed object
        def delete(obj)
            @objects.delete(obj)
        end
        
        # Returns a new QuerySet containing objects from both this and the other.
        # @param [QuerySet] other
        # @return [QuerySet]
        def +(other)
            qs = self.clone
            other.each do |obj|
                qs << obj
            end
            return qs
        end
        
        # Number of objects fetched. Will call load if not loaded yet.
        # Note: this is not the total number of objects responding to the Query; 
        # it may be equal to the fetch_window, or to the @query.limit.
        # @return [Fixnum] length
        def length
            load unless @loaded || !autoload?
            @objects.length
        end
        
        # Like {#select}, but returns an array
        # @return [Array]
        alias :select_array :select
        
        # Returns a (static) QuerySet of the objects for which the block evaluates to true.
        # @param [Proc] proc The block to evaluate
        # @return [QuerySet]
        def select(&proc)
            return QuerySet.new(@model, select_array(&proc))
        end
        
        # True if the query had a limit, and more results can be fetched.
        # @return [bool] True if there are more objects to fetch from the storage.
        def has_more?
            return true if autoload? && !@loaded
            return false unless query.limit
            pos = query.offset.to_i + length
            return pos < total_rows
        end
        
        # Total number of objects that would be returned had the Query no limit.
        # @return [Fixnum] The total number of rows corresponding to the Query (without limit).
        def total_rows
            return @total_rows ? @total_rows : (@total_rows = @model.mapper.count(@query.condition))
        end
        
        # Current number of objects fetched.
        # @return [Fixnum]
        def current_length
            @objects.length
        end
        
        # Returns true if the QuerySet has no elements. Will load if the QuerySet is autoloading.
        # @return [bool] True if QuerySet is empty
        def empty?
            load unless @loaded || !autoload?
            @objects.empty?
        end
        
        # @return [bool] True if no object has been fetched yet.
        def currently_empty?
            @objects.empty?
        end
        
        # Index objects by some elements.
        # @param [*Element] elements Elements to index on
        # @return [self]
        def index_by(*elements)
            names = elements.map{ |el| (el.is_a?(Spider::Model::Element)) ? el.name.to_s : el.to_s }
            index_name = names.sort.join(',')
            @index_lookup[index_name] = {}
            reindex
            return self
        end
        

        # Rebuild object index.
        # @return [self]
        def reindex
            @index_lookup.each_key do |index|
                @index_lookup[index] = {}
            end
            each_current do |obj|
                index_object(obj)
            end
            return self
        end
        
        # Adds object to the index
        # @param [BaseModel] obj
        # @return [void]
        def index_object(obj) # :nodoc:
            @index_lookup.keys.each do |index_by|
                names = index_by.split(',')
                search_key = names.map{ |name| 
                    search_key(obj, name)
                }.join(',')
                (@index_lookup[index_by][search_key] ||= []) << obj
            end
        end
        
        # @param [BaseModel] obj
        # @param [Symbol|String] name Element name
        # @return [String] The index key for an object's element
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
        # @return [void]
        def clear
            @objects = []
            @index_lookup.each_key{ |k| @index_lookup[k] = {} }
        end
                
        # Iterates on currently loaded objects
        # @yield [BaseModel]
        # @return [void]
        def each_current
            @objects.each { |obj| yield obj }
        end

        # Iterates on objects, loading when needed.
        # @yield [BaseModel]
        # @return [void]
        def each
            self.each_rolling_index do |i|
                obj = @objects[i]
                prev_parent = obj._parent
                prev_parent_element = obj._parent_element
                obj.set_parent(self, nil)
                yield obj
                obj.set_parent(prev_parent, prev_parent_element)
            end
        end

        # Iterates yielding the internal objects index. Will load when needed. If a window is
        # used, the index will roll back to 0 on every window.
        # @yield [BaseModel]
        # @return [void]
        def each_rolling_index
            @window_current_start = nil if (@fetch_window)
            while (!@fetch_window || has_more?)
                load_next unless !autoload? || (!@fetch_window && @loaded)
                @objects.each_index do |i|
                    yield i
                end
                break unless autoload? && @fetch_window
            end
        end
        
        # Iterates yielding the queryset index. Will load when needed.
        # @yield [Fixnum]
        # @return [void]
        def each_index
            self.each_rolling_index do |i|
                i += @window_current_start-1 if @window_current_start
                yield i
            end
        end

        # Iterates on indexes without loading.
        # @yield [Fixnum]
        # @return [void]
        def each_current_index
            @objects.each_index do |i|
                i += @window_current_start-1 if @window_current_start
                yield i
            end
        end
        
        # Merges the content of another QuerySet.
        # @param [QuerySet] query_set
        # @return [void]
        def merge(query_set)
            @objects += query_set.instance_variable_get(:"@objects")
            reindex
        end
        
        # Returns true if the QuerySet includes the given value.
        # 
        # The value can be a BaseModel, which will be searched as it is;
        # 
        # a Hash, in which case an Object with all the given values will be searched;
        # 
        # or an Object, which will be searched as the (only) primary key of a contained model
        # @param [BaseModel|Hash|Object] val The value to be checked
        # @return [bool]
        def include?(val)
            self.each do |obj|
                if val.is_a?(BaseModel)
                    return true if obj == val
                elsif val.is_a?(Hash)
                    has_all = true
                    val.each do |k, v|
                        unless obj.get(k) == v
                            has_all = false
                            break
                        end
                        return true if has_all
                    end
                elsif @model.primary_keys.length == 1
                    return true if obj.primary_keys[0] == val
                end
            end
            return false
        end
        
        # Searchs the index for objects matching the given params.
        # @param [Hash] params A set of conditions. Keys must match already created indexes.
        # @return [QuerySet] A new QuerySet with objects matching params
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

        # Calls {Query#order_by} on the QuerySet's query
        # @param [*Element]
        # @return [self]
        def order_by(*elements)
            @query.order_by(*elements)
            return self
        end
        
        # Calls {Query#with_polymorphs} on the QuerySet's query
        # @return [self]
        def with_polymorphs
            @model.polymorphic_models.each do |model, attributes|
                @query.with_polymorph(model)
            end
            self
        end
        
        # Sets the value of an element on all currently loaded objects.
        # @param [Element|Symbol] element
        # @param [Object] value
        # @return [void]
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
        # @return [self]
        def load
            return self unless loadable?
            clear
            @loaded = false
            @loaded_elements = {}
            return load_next if @fetch_window && !@query.offset
            mapper.find(@query.clone, self)
            @loaded = true
            @modified = false
            return self
        end
        
        # @param [Fixnum] i 
        # @return [Fixnum] The index to start with to get the page containing the i-th element
        def start_for_index(i) # :nodoc:
            return 1 unless @fetch_window
            page = i / @fetch_window + 1
            return (page - 1) * @fetch_window + 1
        end
        
        # Loads objects up to index i
        # @param [Fixnum] i Index
        # @return [void]
        def load_to_index(i)
            return load unless @fetch_window
            page = i / @fetch_window + 1
            load_next(page)
        end
        
        # Loads the next batch of objects.
        # @param [Fixnum] Page to load (defaults to next page)
        # @return [self]
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
        # With no argument, will tell if the QuerySet is fully loaded
        # @param [Fixnum] index
        # @return [bool]
        def loaded?(index=nil)
            return @loaded if !@loaded || !index || !@fetch_window
            return false unless @window_current_start
            return true if index >= @window_current_start-1 && index < @window_current_start+@fetch_window-1
            return false
        end
        
        # Sets that the QuerySet is or is not loaded
        # @param [bool] val
        # @return [void]
        def loaded=(val)
            @loaded = val
            @modified = false if @loaded
        end
        
        # @return [bool] True if the QuerySet can be loaded
        def loadable?
            @loadable
        end
        
        # Saves each object in the QuerySet.
        # @return [void]
        def save
            no_autoload(false){ each{ |obj| obj.save } }
        end
        
        # Calls {BaseModel.save!} on each object in the QuerySet.
        # @return [void]
        def save!
            no_autoload(false){ each{ |obj| obj.save! } }
        end

        # Calls {BaseModel.insert} on each object in the QuerySet.        
        # @return [void]
        def insert
            no_autoload(false){ each{ |obj| obj.insert } }
        end

        # Calls {BaseModel.update} on each object in the QuerySet.        
        # @return [void]
        def update
            no_autoload(false){ each{ |obj| obj.update } }
        end
        
        # Calls {BaseModel.save_all} on each object in the QuerySet.
        # @return [void]
        def save_all(params={})
            @objects.each do |obj| 
#                next if (unit_of_work && !unit_of_work.save?(obj))
                obj.save_all(params)
            end
        end
        
        # Returns a new instance of @model from val.
        # @param [Object] val
        # @return [BaseModel] The created object
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
        
        # @return [String] A textual description of the QuerySet
        def inspect
            return "#{self.class.name}:\n@model=#{@model}, @query=#{query.inspect}, @objects=#{@objects.inspect}"
        end
        
        # @return [String] The JSON representation of the QuerySet
        def to_json(state=nil, &proc)
            load unless loaded? || !autoload?
            res =  "[" +
                self.map{ |obj| obj.to_json(&proc) }.join(',') +
                "]"
            return res
        end

        
        # @param [*Object] (see {BaseModel.cut})
        # @return [Array] An array with the results of calling {BaseModel.cut} on each object.
        def cut(*params)
            load unless loaded? || !autoload?
            return self.map{ |obj| obj.cut(*params) }
        end
        
        # @return [Array] An array with the results of calling #BaseModel.to_hash_array on each object.
        def to_hash_array
            return self.map{ |obj| obj.to_hash }
        end
        
        # @param [String|Symbol] Element name (or dotted element path) to index by
        # @return [Hash] A Hash, indexed by the value of element on the object
        def to_indexed_hash(element)
            hash = {}
            self.each do |row|
                hash[row.get(element)] = row
            end
            hash
        end
        
        # Prints an ASCII table of the QuerySet
        # @return [void]
        def table
            
            # Functions for determining terminal size:
            # Copyright (c) 2010 Gabriel Horner, MIT LICENSE
            # http://github.com/cldwalker/hirb.git
            
            # Determines if a shell command exists by searching for it in ENV['PATH'].
            def command_exists?(command)
              ENV['PATH'].split(File::PATH_SEPARATOR).any? {|d| File.exists? File.join(d, command) }
            end

            # Returns [width, height] of terminal when detected, nil if not detected.
            # Think of this as a simpler version of Highline's Highline::SystemExtensions.terminal_size()
            def detect_terminal_size
              if (ENV['COLUMNS'] =~ /^\d+$/) && (ENV['LINES'] =~ /^\d+$/)
                [ENV['COLUMNS'].to_i, ENV['LINES'].to_i]
              elsif (RUBY_PLATFORM =~ /java/ || !STDIN.tty?) && command_exists?('tput')
                [`tput cols`.to_i, `tput lines`.to_i]
              else
                command_exists?('stty') ? `stty size`.scan(/\d+/).map { |s| s.to_i }.reverse : nil
              end
            rescue
              nil
            end
            
            
            return print("Empty\n") if length < 1
            columns = detect_terminal_size[0]
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
            sizes.each do |k, v|
                sizes[k] = v.floor
            end
            print "\n"
            1.upto(columns) { print "-" }
            print "\n"
            elements.each do |el|
                print "|"
                print el.label[0..sizes[el.name]-1].ljust(sizes[el.name])
            end
            print "\n"
            1.upto(columns) { print "-" }
            print "\n"
            a.each do |row|
                elements.each do |el|
                    print "|"
                    print row[el.name][0..sizes[el.name]-1].ljust(sizes[el.name])
                end
                print "\n"
            end
            1.upto(columns) { print "-" }
            print "\n"
            
        end
        
        # @return [Array] The Array corresponding to the QuerySet
        def to_a
            self.map{ |row| row }
        end
        
        # @return [Array] A reversed Array
        def reverse
            self.to_a.reverse
        end
        
        # @return [Array] Calls map on currently loaded objects
        def map_current
            a = []
            each_current{ |row| a << yield(row) }
            a
        end
        
        # Returns an array of Hashes, with each value of the object is converted to string.
        # @return [Array]
        def to_flat_array
            map do |obj|
                h = {}
                obj.class.each_element do |el|
                    h[el.name] = obj.element_has_value?(el) ? obj.get(el).to_s : ''
                end
                h
            end
        end

        # Removes the objects for which the block returns true from the QuerySet
        # @yield [BaseModel]
        # @return [void]
        def reject!(&proc)
            @objects.reject!(&proc)
        end
        
        # Removes all objects from the QuerySet
        # @return [void]
        def empty!
            @objects = []
        end
        
        # @return [String] All the objects, to_s, joined by ', '
        def to_s
            self.map{ |o| o.to_s }.join(', ')
        end
        
        # Missing methods will be sent to the query
        def method_missing(method, *args, &proc)
            el = @model.elements[method]
            if (el && el.model? && el.reverse)
                return element_queryset(el)
            end
            return @query.send(method, *args, &proc) if @query.respond_to?(method)
            return super
        end
        
        # @param [Element|Symbol] element
        # @return [QuerySet] The QuerySet corresponding to an element in the current QuerySet
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
        # @param [String] path
        # @return [Array] An array of all found objects
        def all_children(path)
            if (path.length > 0)
                children = @objects.map{ |obj| obj.all_children(path.clone) }.flatten
            else
                return @objects
            end
        end
        
        # Registers that the element has been loaded.
        # @param [Element|Symbol]
        # @return [void]
        def element_loaded(element)
            element = element.name if element.is_a?(Element)
            @loaded_elements[element] = true
        end
        
        # @param [Element|Symbol]
        # @return [bool] True if the element has been loaded from the Storage.
        def element_loaded?(element)
            element = element.name if element.is_a?(Element)
            @loaded_elements[element]
        end
        
        # Returns the current QuerySet IdentityMapper instance, or instantiates a new one
        # @return [IdentityMapper] The IdentityMapper
        def identity_mapper
            return Spider::Model.identity_mapper if Spider::Model.identity_mapper
            @identity_mapper ||= IdentityMapper.new
        end
        
        # Assigns an IdentityMapper to the QuerySet
        # @param [IdentityMapper] im
        # @return [void]
        def identity_mapper=(im)
            @identity_mapper = im
        end
        
        # Calls {Query#with_superclass} on the query.
        # @return [self]
        def with_superclass
            @query.with_superclass
            return self
        end
        
        ########################################
        # Condition, request and query methods #
        ########################################
        
        # Calls {Query#where} on the query.
        # @return {self}
        def where(*params, &proc)
            @query.where(*params, &proc)
            return self
        end
        
        # Calls {Query.limit} on the query
        # @return {self}
        def limit(n)
            @query.limit = n
            return self
        end
        
        # Calls {Query.offset}
        # @return {self}
        def offset(n)
            @query.offset = n
            return self
        end
        
        # Calls {Query.page} on the Query
        # @return {self}
        def page(page, rows)
            @query.page(page, rows)
            self
        end
        
        # @return [Fixnum|nil] Total number of available pages for current query (or nil if no limit is set)
        def pages
            return nil unless @query.limit
            (self.total_rows.to_f / @query.limit).ceil
        end
        
        # def unit_of_work
        #     return Spider::Model.unit_of_work
        # end
        
        # Performs a deep copy
        # @return [QuerySet]
        def clone
            c = self.class.new(self.model, self.query.clone)
            c.autoload = self.autoload?
            c_objects = c.instance_variable_get(:@objects)
            @objects.each do |o|
                c_objects << o.clone
            end
            return c
        end

    end

end; end
