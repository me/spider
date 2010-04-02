require 'spiderfw/model/model_hash'

module Spider; module Model
    
    # The Condition behaves like a ModelHash, and as such contains key-value pairs:
    # a simple equality condition can be set with
    #   condition[:element_name] = value
    # The Condition object also holds comparisons: a comparison different from equality can be set with
    #   condition.set(:element_name, '>', value)
    # Finally, it contains subconditions, which can be added with
    #   conditions << subcondition
    # Subconditions will be created automatically when using #set twice on the same element.
    # If you want to change the condition, use #delete and set it again.
    # 
    # The Condition object, like the Request, doesn't hold a reference to a model; so no check will be made
    # that the conditions elements are meaningful.
    
    class Condition < Hash
        # The top level conjunction for the Condition (:or or :and; new Conditions are initialized with :or)
        attr_accessor :conjunction
        # Polymorph model: used to tell the mapper the condition is on a subclass of the queried model.
        attr_accessor :polymorph
        # An hash of comparisons for each element name
        attr_reader :comparisons
        # An Array of subconditions
        attr_reader :subconditions
        attr_accessor :conjunct # :nodoc: a hack to keep track of which is the last condition in blocks
        alias :hash_set :[]= # :nodoc:
        
        # See #ModelHash.get_deep_obj
        def get_deep_obj # :nodoc:
            c = self.class.new
            c.conjunction = @conjunction
            return c
        end
        
        @comparison_operators = %w{= > < >= <= <> != like}
        @comparison_operators_regexp = @comparison_operators.inject('') do |str, op|
            str += '|' unless str.empty? 
            str += Regexp.quote(op)
        end
        
        # Regexp to parse comparison operators
        def self.comparison_operators_regexp # :nodoc:
            @comparison_operators_regexp
        end
        
        # Used by and and or methods
        def self.conj(conjunction, a, b) # :nodoc:
            c = Condition.new
            c.conjunction = conjunction
            c << a
            c << b
        end
        
        # Instantiates a Condition with :and conjunction.
        # See #new for arguments.
        def self.and(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = :and
            return c
        end
        
        # Instantiates a Condition with :or conjunction. 
        # See #new for arguments.
        def self.or(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = :or
            return c
        end
        
        # Instantiates a Condition with no conjunction.
        def self.no_conjunction(*params, &proc) # :nodoc:
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
        # All comparisons must be parenthesized; and/or conjunctions are expressed with a single &/|.
        #
        # Available comparisions are: ==, >, <, >=, <=, .not, .like, .ilike (case insensitive like).
        #
        # _Note:_ for .like and .ilike comparisons, the SQL '%' syntax must be used.
        #
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
        
        # Yields each key, value and comparison.
        def each_with_comparison
            self.each do |k, v|
                yield k, v, @comparisons[k.to_sym] || '='
            end
        end
        
        # Returns the result of merging the condition with another one (does not modify the original condition).
        def +(condition)
            res = self.clone
            @subconditions += condition.subconditions
            condition.each_with_comparison do |k, v, c|
                res.set(k, v, c)
            end
            return res
        end
        
        # Adds a subcondtion.
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
        
        # Sets a comparison.
        def set(field, comparison, value)
            if (value.is_a?(QuerySet))
                value = value.to_a
            end
            if (value.is_a?(Array))
                or_cond = self.class.or
                value.uniq.each do |v|
                    or_cond.set(field, comparison, v)
                end
                @subconditions << or_cond
                return self
            end
            field = field.to_s
            parts = field.split('.', 2)
            parts[0] = parts[0].to_sym
            field = field.to_sym unless parts[1]
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
        def []=(key, value)
            set(key, '=', value)
        end
        
        def [](key)
            # TODO: deep
            key = key.name if key.class == Element
            super(key.to_sym)
        end
        
        # Adds a range condition. This creates a subcondition with >= and <= conditions.
        def range(field, lower, upper)
            c = self.class.and
            c.set(field, '>=', lower)
            c.set(field, '<=', upper)
            self << c
        end
        
        # Deletes a field from the Condition.
        def delete(field)
            super
            @comparisons.delete(field.to_sym)
        end    
        
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
        
        def inspect
            str = ""
            cnt = 0
            each do |key, value|
                str += " #{@conjunction} " if cnt > 0
                cnt += 1
                comparison = @comparisons[key] || '='
                cond = "#{comparison} #{value.inspect}"
                str += "#{key} #{cond}"
            end
            str = '(' + str + ')' if str.length > 0
            #str += ' [raw:'+raw.inspect+']' unless raw.empty?
            first = true
            if @subconditions.length > 0
                str += ' '+@conjunction.to_s+' ' if str.length > 0
                str += @subconditions.map{ |sub| sub.inspect }.join(' '+@conjunction.to_s+' ')
            end
            return str
        end
        
        # Returns the conjunction with another condition.
        # If this condition already has the required conjunction, the other will be added as a subcondition;
        # otherwise, a new condition will be created and both will be added to it.
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
        
        
        # Joins the condition to another with an "or" conjunction. See #conj.
        def or(other=nil, &proc)
            return conj(:or, other, &proc)
        end
        alias :| :or
        alias :OR :or
        
        # Joins the condition to another with an "and" conjunction. See #conj.
        def and(other=nil, &proc)
            return conj(:and, other, &proc)
        end
        alias :& :and
        alias :AND :and
    
        alias :hash_empty? :empty? # :nodoc:
        
        # True if there are no comparisons and no subconditions.
        def empty?
            return super && @subconditions.empty?
        end
        
        alias :hash_replace :replace  # :nodoc:
        
        # Replace the content of this Condition with another one.
        def replace(other)
            hash_replace(other)
            @subconditions = other.subconditions
            @conjunction = other.conjunction
            @polymorph = other.polymorph
            @comparisons = other.comparisons
        end
        
        def ==(other)
            return false unless other.class == self.class
            return false unless super
            return false unless @subconditions == other.subconditions
            return false unless @comparisons == other.comparisons
            return false unless @polymorph == other.polymorph
            return false unless @conjunction == other.conjunction
            return true
        end
        
        def eql?(other)
            self == other
        end
        
        def hash
            ([self.keys, self.values, @comparisons.values, @polymorph] + @subconditions.map{ |s| s.hash}).hash
        end
        
        # Removes duplicate subcondtions.
        def uniq!
            @subconditions.uniq!
        end
        
        # Returns a deep copy.
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
        def simplify
            @subconditions.each{ |sub| sub.simplify }
            if (hash_empty? && @subconditions.length == 1)
                self.replace(@subconditions[0])
            end
            @subconditions.uniq!
            return self
        end
        
        def polymorphs
            pol = []
            pol << @polymorph if @polymorph
            return pol + @subconditions.inject([]){ |arr, s| arr += s.polymorphs }
        end
    
    end
    
    module ConditionMixin # :nodoc:
        
        
        def method_missing(meth, *arguments)
            if (meth == :q)
                return ConditionElementCreator.new
            end
            if (meth.to_s =~ /element_(.+)/) # alternative syntax to avoid clashes
                meth = $1.to_sym
            end
            name = @condition_element_name ? "#{@condition_element_name}.#{meth}" : meth.to_s
            return ConditionElement.new(name, @condition_context)
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
                    if (replace[op])
                        op = replace[op]
                    end
                    op = op.to_s
                    c = Condition.no_conjunction.set(@condition_element_name, op, val)
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
