require 'spiderfw/model/model_hash'

module Spider; module Model
    
    # The Condition behaves like a {ModelHash}, and as such contains key-value pairs:
    # a simple equality condition can be set with
    #   condition[:element_name] = value
    # The Condition object also holds comparisons: a comparison different from equality can be set with
    #   condition.set(:element_name, '>', value)
    # Finally, it contains subconditions, which can be added with
    #   conditions << subcondition
    # Subconditions will be created automatically when using {#set} twice on the same element.
    # If you want to change the condition, use {#delete} and set it again.
    #
    # Conditions also support an SQL-like block syntax for setting conditions:
    #   books_condition = Condition.new{ |book| 
    #    ((book.year < 1970) | (book.price > 1000)) & (book.author.name .like 'John')  
    #   }
    # 
    # The Condition object, like the Request, doesn't hold a reference to a model; so no check will be made
    # that the conditions elements are meaningful.
    
    class Condition < Hash
        # The top level conjunction for the Condition (:or or :and; new Conditions are initialized with :or)
        # @return [Symbol] :and | :or
        attr_accessor :conjunction
        # Polymorph model: used to tell the mapper the condition is on a subclass of the queried model.
        # @return [Class<BaseModel]
        attr_accessor :polymorph
        # An hash of comparisons for each element name
        # @return [Hash]
        attr_reader :comparisons
        # An Array of subconditions
        # @return [Array]
        attr_reader :subconditions
        # @private
        # A pointer to the last Condition used in condition blocks
        # @return [Condition]
        attr_accessor :conjunct 
        # Original hash value assignment
        alias :hash_set :[]= # :nodoc:
        
        # See #ModelHash.get_deep_obj
        # @return [Condition]
        def get_deep_obj # :nodoc:
            c = self.class.new
            c.conjunction = @conjunction
            return c
        end
        
        @comparison_operators = %w{= > < >= <= <> like}
        @comparison_operators_regexp = @comparison_operators.inject('') do |str, op|
            str += '|' unless str.empty? 
            str += Regexp.quote(op)
        end
        
        # @private
        # Regexp to parse comparison operators
        # @return [Regexp]
        def self.comparison_operators_regexp
            @comparison_operators_regexp
        end
        
        # @private
        # Used by {Condition.and} and {Condition.or} methods
        # @param [Symbol] conjunction
        # @param [Condition] a
        # @param [Condition] b
        def self.conj(conjunction, a, b) # :nodoc:
            c = Condition.new
            c.conjunction = conjunction
            c << a
            c << b
        end
        
        # Instantiates a Condition with :and conjunction.
        # See {Condition.new} for arguments.
        # @return [Condition]
        def self.and(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = :and
            return c
        end
        
        # Instantiates a Condition with :or conjunction. 
        # See {Condition.new} for arguments.
        # @return [Condition]
        def self.or(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = :or
            return c
        end
        
        # Instantiates a Condition with no conjunction.
        # See {Condition.new} for arguments.
        # @return [Condition]
        def self.no_conjunction(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = nil
            return c
        end
        
        # Instantiates a new Condition, with :and conjunction.
        # If given a Hash, will set all keys = values.
        # If given multiple params, will convert each to a Condition if needed, and append them
        # to the returned instance.
        # If a block is given, it will be processed by #parse_block
        def initialize(*params, &proc)
            @conjunction = :and
            @comparisons = {}
            @subconditions = []
            params.reject!{ |p| p.nil? }
            if (params.length == 1 && params[0].is_a?(Hash) && !params[0].is_a?(Condition))
                params[0].each do |k, v|
                    set(k, '=', v)
                end
            else
                # FIXME: must have an instantiate method
                params.each{ |item| self << (item.is_a?(self.class) ? item : self.class.new(item)) } 
            end
            parse_block(&proc) if (block_given?)
        end
        
        # Parses a condition block. Inside the block, an SQL-like language can be used.
        #
        # Example:
        #   condition.parse_block{ (element1 == val1) & ( (element2 > 'some string') | (element3 .not nil) ) }
        #
        # All comparisons must be parenthesized; and/or conjunctions are expressed with a single &/|.
        #
        # Available comparisions are: ==, >, <, >=, <=, .not, .like, .ilike (case insensitive like).
        #
        # _Note:_ for .like and .ilike comparisons, the SQL '%' syntax must be used.
        #
        # @param [Proc] proc The condition block
        def parse_block(&proc)
            res = nil
            if proc.arity == 1
                res = proc.call(ConditionContext.new)
            else
                context = eval "self", proc.binding
                res = context.dup.extend(ConditionMixin).instance_eval(&proc)
            end
            self.replace(res)
            @conjunction = res.conjunction
            @comparisons = res.comparisons
            @subconditions = res.subconditions
            @polymorph = res.polymorph
        end
        
        # @return [Array] An array of all conditions, expressed as [key, value, comparison]
        def conditions_array
            self.hash_clone.map do |k, v|
                k = k.to_sym if k.respond_to?(:to_sym)
                [k, v, (@comparisons[k] || '==')]
            end
        end
        
        # Yields each key, value and comparison.
        # @return void
        def each_with_comparison
            self.each do |k, v|
                k = k.to_sym if k.respond_to?(:to_sym)
                yield k, v, @comparisons[k] || '='
            end
        end
        
        # Yields each key, value and comparison, for this condition and its subconditions
        # @return [void]
        def all_each_with_comparison
            self.each_with_comparison{ |k, v, c| yield k, v, c }
            @subconditions.each do |sub|
                sub.all_each_with_comparison{ |k, v, c| yield k, v, c }
            end
        end

        # @param [Class<BaseModel] The model on which the Condition is based on.
        # @return [bool] True if the condition has only primary keys for the given model
        def primary_keys_only?(model)
            self.select{ |key, value| !model.elements[key] || !model.elements[key].primary_key? }.empty?
        end
        
        # Returns the result of merging the condition with another one (does not modify the original condition).
        # @param [Condition] Condition to merge with
        # @return [Condition] The resulting Condition
        def +(condition)
            res = self.clone
            @subconditions += condition.subconditions
            condition.each_with_comparison do |k, v, c|
                res.set(k, v, c)
            end
            return res
        end
        
        # Adds a subcondtion.
        # @param [Condition] condition
        # @return [void]
        def <<(condition)
            if (condition.class == self.class)
                @subconditions << condition
            elsif (condition.is_a?(Hash))
                @subconditions << self.class.new(condition)
            elsif (condition.class == String)
                key, val, comparison = parse_comparison(condition)
                set(key, val, comparison)
            end
        end
        
        # Adds a single condition for an element
        # @param [Symbol|String|QueryFuncs::Function] field to add the condition to
        # @param [String] comparison: can be =, <, >, <=, >=, 'between'
        # @param [QuerySet|Array|Range|Object] the value of the condition
        # @return [self]
        def set(field, comparison, value)
            if value.is_a?(QuerySet)
                value = value.to_a
            end
            if value.is_a?(Array) && comparison != 'between'
                multi_cond = comparison == '<>' ? self.class.and : self.class.or
                value.uniq.each do |v|
                    multi_cond.set(field, comparison, v)
                end
                @subconditions << multi_cond
                return self
            end
            parts = []
            unless field.is_a?(Spider::QueryFuncs::Function)
                field = field.to_s
                parts = field.split('.', 2)
                debugger if parts[0].blank?
                parts[0] = parts[0].to_sym
                field = field.to_sym unless parts[1]
            end
            if (parts[1])
                hash_set(parts[0], get_deep_obj()) unless self[parts[0]]
                self[parts[0]].set(parts[1], comparison, value)
            elsif (self[field])
                c = Condition.new
                c.set(field, comparison, value)
                @subconditions << c
            else
                hash_set(field, value)
                @comparisons[field] = comparison
            end
            return self
        end
        
        # Sets an equality comparison.
        # 
        # Equivalent to {#set}(key, '=', value)
        # @param [String|Symbol|QueryFuncs::Function] key
        # @param [Object] value
        # @return [self]
        def []=(key, value)
            set(key, '=', value)
        end
        
        # Gets the value of a condition
        # @param [String|Symbol|QueryFuncs::Function] key
        # @return [Object] value
        def [](key)
            # TODO: deep
            key = key.name if key.is_a?(Element)
            key = key.to_sym if key.respond_to?(:to_sym) # might be a QueryFunc
            super(key)
        end
        
        # Adds a range condition. This creates a subcondition with >= and <= conditions.
        # @param [String|Symbol|QueryFuncs::Function] key
        # @param [Object] lower
        # @param [Object] upper
        # @return [self]
        def range(field, lower, upper)
            c = self.class.and
            c.set(field, '>=', lower)
            c.set(field, '<=', upper)
            self << c
        end
        
        # Deletes a field from the Condition.
        # @param [String|Symbol|QueryFuncs::Function] key
        # @return [Array] A pair containing the deleted value and comparison
        def delete(field)
            field = field.to_sym
            return nil unless self[field] || @comparisons[field]
            cur = [self[field], @comparisons[field]]
            super
            @comparisons.delete(field)
            cur
        end    
        
        # @return [String] A String representation of the condition
        def inspect
            str = ""
            cnt = 0
            each do |key, value|
                str += " #{@conjunction} " if cnt > 0
                cnt += 1
                comparison = @comparisons[key] || '='
                cond = "#{comparison} #{value.inspect}"
                str += "#{key.inspect} #{cond}"
            end
            #str += ' [raw:'+raw.inspect+']' unless raw.empty?
            first = true
            if @subconditions.length > 0
                str += ' '+@conjunction.to_s+' ' if str.length > 0
                str += @subconditions.map{ |sub| sub.inspect }.reject{ |sub| sub.empty? }.join(' '+@conjunction.to_s+' ')
            end
            str = "(#{str})" if cnt + @subconditions.length > 1
            return str
        end
        
        # Returns the conjunction with another condition.
        # If this condition already has the required conjunction, the other will be added as a subcondition;
        # otherwise, a new condition will be created and both will be added to it.
        # @param [Symbol] conjunction :and | :or
        # @param [Condition] other Condition to conjuct to this
        # @param [Proc] proc Block to create the other condition
        # @return [Condition] The resulting Condition (self, or the new Condition created)
        def conj(conjunction, other=nil, &proc)
            self.conjunction = conjunction if (!self.conjunction)
            if (self.conjunction == conjunction)
                c = self
            else
                c = Condition.new
                c.conjunction = conjunction
                c << self
            end
            if (!other && proc)
                other = Condition.new(&proc)
            end
            c << other
            other.conjunct = true
            return c
        end
        
        
        # Joins the condition to another with an "or" conjunction. See {#conj}.
        # @param [Condition] other Condition to conjuct to this
        # @param [Proc] proc Block to create the other condition
        # @return [Condition] The resulting Condition (self, or the new Condition created)
        def or(other=nil, &proc)
            return conj(:or, other, &proc)
        end
        alias :| :or
        alias :OR :or
        
        # Joins the condition to another with an "and" conjunction. See {#conj}.
        # @param [Condition] other Condition to conjuct to this
        # @param [Proc] proc Block to create the other condition
        # @return [Condition] The resulting Condition (self, or the new Condition created)
        def and(other=nil, &proc)
            return conj(:and, other, &proc)
        end
        alias :& :and
        alias :AND :and
    
        alias :hash_empty? :empty? # :nodoc:
        
        # True if there are no comparisons and no subconditions.
        # @return [bool] True if the Condition is empty, false otherwise
        def empty?
            return false unless super
            @subconditions.each do |sub|
                return false unless sub.empty?
            end
            return true
        end
        
        # Alias to the original Hash#replace
        alias :hash_replace :replace
        
        # Replace all the content of this Condition with another one.
        # @param [Condition] other The other condition
        # @return [self]
        def replace(other)
            hash_replace(other)
            @subconditions = other.subconditions
            @conjunction = other.conjunction
            @polymorph = other.polymorph
            @comparisons = other.comparisons
            self
        end
        
        # @param [Condition] other
        # @return [bool] True if the two conditions have the same comparisions and conjunction
        def ==(other)
            return false unless other.class == self.class
            return false unless super
            return false unless @subconditions == other.subconditions
            return false unless @comparisons == other.comparisons
            return false unless @polymorph == other.polymorph
            return false unless @conjunction == other.conjunction
            return true
        end
        
        # @return [bool] See {#==}
        def eql?(other)
            self == other
        end
        
        # @return [String] Keying hash
        def hash
            ([self.keys, self.values, @comparisons.values, @polymorph] + @subconditions.map{ |s| s.hash}).hash
        end
        
        # Removes duplicate subcondtions.
        # @return self
        def uniq!
            @subconditions.uniq!
            self
        end
        
        # Alias for Hash#clone
        alias :hash_clone :clone
        
        # Returns a deep copy.
        # @return [Condition] A copy of this Condition
        def clone
            c = self.class.new
            c.conjunction = @conjunction
            c.polymorph = @polymorph
            self.each_with_comparison do |key, val, comparison|
                c.set(key, comparison, val)
            end
            @subconditions.each do |sub|
                c << sub.clone
            end
            return c
        end
        
        # Traverses the tree removing useless conditions.
        # @return [self]
        def simplify
            @subconditions.each{ |sub| sub.simplify }
            if (hash_empty? && @subconditions.length == 1)
                self.replace(@subconditions[0])
            end
            @subconditions.uniq!
            return self
        end
        
        # @return [Array] An array of polymorphic conditions
        def polymorphs
            pol = []
            pol << @polymorph if @polymorph
            return pol + @subconditions.inject([]){ |arr, s| arr += s.polymorphs }
        end
        
        # Returns, from self and subconditions, all those who define a condition for one of the given element names.
        # @param [*Symbol] element_names A list of element names
        # @return [Array] An array of matching conditions
        def conditions_for(*element_names)
            conds = []
            element_names.each do |el|
                if self.key?(el)
                    conds << self
                    break
                end
            end
            @subconditions.map{ |s| s.conditions_for(*element_names) }.each{ |c| conds += c }
            conds
        end

        private

        # Parses a string comparison.
        # TODO: remove?
        def parse_comparison(comparison) # :nodoc:
            if (comparison =~ Regexp.new("(.+)(#{self.class.comparison_operators_regexp})(.+)"))
                val = $3.strip
                # strip single and double quotes
                val = val[1..-2] if ((val[0] == ?' && val[-1] == ?') || (val[0] == ?" && val[-1] == ?") )
                return [$1.strip, $2.strip, val]
            end
        end
    
    end
    
    # Helper module used for Condition block syntax
    module ConditionMixin # :nodoc:
        
        def __el(meth)
            __create_condition_element(meth)
        end
        
        def method_missing(meth, *arguments)
            __create_condition_element(meth)
        end
        
        def __create_condition_element(meth)
            if (meth == :q)
                return ConditionElementCreator.new
            end
            if (meth.to_s =~ /element_(.+)/) # alternative syntax to avoid clashes
                meth = $1.to_sym
            end
            name = @condition_element_name ? "#{@condition_element_name}.#{meth}" : meth.to_s
            return ConditionElement.new(name, @condition_context)
        end
        
        def id
            return ConditionElement.new(:id, @condition_context)
        end
        
        def AND(&proc)
            @condition_context = []
            instance_eval(&proc)
            c = Condition.and
            @condition_context.each do |cond|
                c << cond unless (cond.conjunct)
            end
            @condition_context = nil
            return c
        end
        
        def OR(&proc)
            @condition_context = []
            instance_eval(&proc)
            c = Condition.and
            @condition_context.each do |cond|
                c << cond unless (cond.conjunct)
            end
            @condition_context = nil
            return c
        end
        
        class ConditionElementCreator #:nodoc:
            include ConditionMixin
        end
        
        class ConditionElement #:nodoc:
            include ConditionMixin
            
            def initialize(name, condition_context)
                @condition_element_name = name
                @condition_context = condition_context
            end
            
            [:==, :<, :>, :<=, :>=, :like, :ilike, :not].each do |op|
                define_method(op) do |val|
                    replace = {
                        :== => '=',
                        :not => '<>'
                    }
                    if replace[op]
                        op = replace[op]
                    end
                    op = op.to_s
                    c = Condition.and.set(@condition_element_name, op, val)
                    if (@condition_context)
                        @condition_context << c
                    end
                    return c
                end
            end
                    
        end

        
    end
    
    class ConditionContext
        include ConditionMixin
    end
    
    
end; end
