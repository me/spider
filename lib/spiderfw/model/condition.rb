require 'spiderfw/model/model_hash'

module Spider; module Model
    
    class Condition < ModelHash
        attr_accessor :conjunction
        attr_reader :subconditions, :comparisons, :polymorphs#, :raw
        
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
        
        def self.new_and(hash=nil)
            c = self.new(hash)
            c.conjunction = :and
            return c
        end
        
        def initialize(hash_or_array=nil)
            @conjunction = :or
            @comparisons = {}
            @subconditions = []
            @polymorphs = []
            if (hash_or_array.is_a?(Array))
                hash_or_array.each{ |item| self << self.class.new(item) }
            else
                super
            end
            #@raw = {}
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
            if (self.conjunction == conjunction)
                c = self
            else
                c = Condition.new
                c.conjunction = conjunction
                c << self
            end
            c << other
            return c
        end
        
                    
        def or(other)
            return conj(:or, other)
        end
        alias :| :or
        
        def and(other)
            return conj(:and, other)
        end
        alias :& :and
    
        def empty?
            return super && @subconditions.empty?
        end
    
    end
    
    
end; end
