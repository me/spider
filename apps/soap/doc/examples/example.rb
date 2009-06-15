require 'apps/soap/_init.rb'

module SoapTest
    
    class SoapTestController < Spider::SoapController
        SumResponse = SoapStruct(:a => Finxum, :b => Fixnum, :res => Fixnum)
        FloatArray = SoapArray(Float)
        
        soap :sum, :in => [[:a, Fixnum], [:b, Fixnum]], :return => SumResponse
        soap :random, :return => FloatArray
        
        def sum(a, b)
            return {:a => a, :b => b, :res => a+b}
        end
        
        
        def random
            res = []
            0.upto(9) do
                res << rand
            end
            return res
        end
        
    end
    
    
end