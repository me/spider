module Spider; module Model
    
end; end

module Spider; module QueryFuncs
    
    def self.included(mod)
        mod.extend(self)
        super
    end
    
    def self.add_query_func(name, klass)
        (class << self; self; end).module_eval do
            define_method(name) do |*args|
                return klass.new(*args)
            end
        end
        define_method(name) do |*args|
            return klass.new(*args)
        end
    end

    class Expression
        
        def initialize(string)
            @string = string
            @replacements = {}
        end
        
        def each_element
            @string.scan(/:\w[\w\d\.]+/).each{ |el| yield el[1..-1].to_sym }
        end
        
        def []=(el, replacement)
            @replacements[el] = replacement
        end
        
        def to_s
            str = @string
            @replacements.each do |el, rep|
                str = str.gsub(":#{el}", rep)
            end
            return str
        end
        
    end

    class Function
        attr_accessor :mapper_fields
        
        def self.inherited(subclass)
            cl_name = subclass.name.split('::')[-1].to_sym
            Spider::QueryFuncs.add_query_func(cl_name, subclass)
        end

        def self.func_name
            self.name =~ /::([^:]+)$/
            return Inflector.underscore($1).to_sym
        end

        def func_name
            self.class.func_name
        end

        def elements
            []
        end

        def inner_elements
            els = []
            elements.each do |el|
                if (el.is_a?(Function))
                    els += el.inner_elements
                else
                    els << [el, self]
                end
            end
            return els
        end

        def aggregate?
            false
        end

        def has_aggregates?
            return true if aggregate?
            elements.each do |el|
                return true if el.is_a?(Function) && el.has_aggregates?
            end
            return false
        end

        def inspect
            "#{self.func_name.to_s.upcase}(#{elements.map{ |el| el.inspect }.join(', ')})"
        end

        def as(name)
            SelectFunction.new(self, name)
        end

    end

    class SelectFunction
        attr_reader :function, :as


        def initialize(function, as)
            @function = function
            @as = as
        end

        def inspect
            "#{@function.inspect} AS #{@as}"
        end

        def method_missing(method, *args)
            @function.send(method, *args)
        end

    end

    class ZeroArityFunction < Function
    end

    class UnaryFunction < Function

        def initialize(el)
            @el = el
        end

        def elements
            [@el]
        end

    end

    class BinaryFunction < Function

        def initialize(el1, el2)
            @el1 = el1
            @el2 = el2
        end

        def elements
            [@el1, @el2]
        end
    end
    
    class NAryFunction < Function
        
        def initialize(*elements)
            @elements = elements
        end
        
        def elements
            @elements
        end
        
    end


    class CurrentDate < ZeroArityFunction
    end
    
    class RowNum < ZeroArityFunction
    end

    class Length < UnaryFunction
    end

    class Trim < UnaryFunction
    end

    class Subtract < BinaryFunction

        def inspect
            "#{@el1.inspect} - #{@el2.inspect}"
        end

    end
    
    class Concat < NAryFunction
    end
    
    class Substr < UnaryFunction
        attr_reader :start, :length
        
        def initialize(el, start, length=nil)
            @el = el
            @start = start
            @length = length
        end
        
    end

    class AggregateFunction < UnaryFunction

        def aggregate?
            true
        end

    end


    class Avg < AggregateFunction
    end

    class Count < AggregateFunction
    end

    class First < AggregateFunction
    end

    class Last < AggregateFunction
    end

    class Max < AggregateFunction
    end

    class Min < AggregateFunction
    end

    class Sum < AggregateFunction
    end


end; end