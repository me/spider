module Spider; module QueryFuncs
            
        class Function
            attr_accessor :mapper_fields
            
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
            
        
        class CurrentDate < ZeroArityFunction
        end
                    
        class Length < UnaryFunction
        end
        
        class Trim < UnaryFunction
        end
        
        class Subtract < BinaryFunction
        end
        
    
end; end