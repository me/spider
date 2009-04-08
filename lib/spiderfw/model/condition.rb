require 'spiderfw/model/model_hash'

module Spider; module Model
    
    class Condition < ModelHash
        attr_accessor :conjunction
        attr_reader :subconditions, :comparisons, :polymorphs#, :raw
        attr_accessor :conjunct # a hack to keep track of which is the last condition in blocks
        
        def get_deep_obj
            c = self.class.new
            c.conjunction = @conjunction
            return c
        end
        
        @comparison_operators = %w{= > < >= <= <> != like}
        @comparison_operators_regexp = @comparison_operators.inject('') do |str, op|
            str += '|' unless str.empty? 
            str += Regexp.quote(op)
        end
        
        def self.comparison_operators_regexp
            @comparison_operators_regexp
        end
        
        
        def self.conj(conjunction, a, b)
            c = Condition.new
            c.conjunction = conjunction
            c << a
            c << b
        end
        
        def self.and(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = :and
            return c
        end
        
        def self.or(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = :or
            return c
        end
        
        def self.no_conjunction(*params, &proc)
            c = self.new(*params, &proc)
            c.conjunction = nil
            return c
        end
        
        def initialize(*params, &proc)
            @conjunction = :or
            @comparisons = {}
            @subconditions = []
            @polymorphs = []
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
        
        def parse_block(&proc)
            context = eval "self", proc.binding
            res = context.dup.extend(ConditionMixin).instance_eval(&proc)
            self.replace(res)
            @conjunction = res.conjunction
            @comparisons = res.comparisons
            @subconditions = res.subconditions
            @polymorphs = res.polymorphs
        end
        
        def each_with_comparison
            self.each do |k, v|
                yield k, v, @comparisons[k.to_sym] || '='
            end
        end
        
        def +(condition)
            @subconditions += condition.subconditions
            condition.each_with_comparison do |k, v, c|
                set(k, v, c)
            end
        end
        
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
        
        def set(field, comparison, value)
            if (value.is_a?(Array))
                or_cond = self.class.or
                value.each do |v|
                    or_cond.set(field, comparison, v)
                end
                @subconditions << or_cond
                return self
            end
            field = field.to_s
            parts = field.split('.', 2)
            if (parts[1])
                self[parts[0]] = get_deep_obj() unless self[parts[0]]
                self[parts[0]].set(parts[1], comparison, value)
            elsif (self[field])
                c = Condition.new
                c.set(field, comparison, value)
                @subconditions << c
            else
                self[field] = value
                @comparisons[field.to_sym] = comparison
            end
            return self
        end
        
        def delete(field)
            super
            @comparisons.delete(field.to_sym)
        end
        
        
        
        def parse_comparison(comparison)
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
            @subconditions.each do |sub|
                str += " "+@conjunction.to_s if (str.length > 0)
                str += " ("+sub.inspect+')'
            end
            return str
        end
        
        def conj(conjunction, other)
            self.conjunction = conjunction if (!self.conjunction)
            if (self.conjunction == conjunction)
                c = self
            else
                c = Condition.new
                c.conjunction = conjunction
                c << self
            end
            c << other
            other.conjunct = true
            return c
        end
        
                    
        def or(other)
            return conj(:or, other)
        end
        alias :| :or
        alias :OR :or
        
        def and(other)
            return conj(:and, other)
        end
        alias :& :and
        alias :AND :and
    
        def empty?
            return super && @subconditions.empty?
        end
        
        def ==(other)
            return false unless other.class == self.class
            return false unless super
            return false unless @subconditions == other.subconditions
        end
        
        def uniq!
            @subconditions.uniq!
        end
    
    end
    
    module ConditionMixin
        
        
        def method_missing(meth, *arguments)
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
        
        class ConditionElement
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
    
    
end; end
