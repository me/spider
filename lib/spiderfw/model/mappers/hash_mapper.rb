require 'spiderfw/model/mappers/mapper'
require 'FileUtils'

module Spider; module Model; module Mappers

    class HashMapper < Spider::Model::Mapper
        
        # TODO: This is only for one-element hashes; make this a subclass of
        # a generic hashmapper
        def fetch(query)
            return [] unless @model.data && @model.data.length > 0
            primary_key = nil
            desc = nil
            @model.elements.each do |name, el|
                if el.primary_key?
                    primary_key = el.name
                else
                    desc = el.name
                end
            end
            raise MapperException, "Model has no primary key or no description element" unless primary_key && desc
            res =  @model.data.map{ |id, val| {primary_key => id, desc => val} }.select do |row|
                check_condition(query.condition, row)
            end
            return res
        end
        
        def check_condition(condition, row)
            return true if condition.empty?
            condition.each_with_comparison do |key, value, comp|
                has_check = true
                test = case comp
                when '='
                    row[key] == value
                when '>'
                    row[key] > value
                when '<'
                    row[key] < value
                when '<>'
                    row[key] != value
                when 'like'
                    test_re = Regexp.new(Regexp.quote(value).gsub('%', '.+'))
                    row[key] =~ test_re
                end
                if (test) 
                    return true if (condition.conjunction == :or)
                else
                    return false if (condition.conjunction == :and)
                end
            end
            condition.subconditions.each do |sub|
                has_check = true
                test = check_condition(sub, row)
                if (test) 
                    return true if (condition.conjunction == :or)
                else
                    return false if (condition.conjunction == :and)
                end
            end
            return false if (condition.conjunction == :or)
            return true
        end
        
        def prepare_query(query)
            query = super
            @model.elements.select{ |name, element| !element.model? }.each do |name, element|
                query.request[element] = true
            end
            return query
        end
        
        def integrate(request, result, obj)
            request.keys.each do |element_name|
                element = @model.elements[element_name]
                next if element.model?
                result_value = result[element_name]
                obj.set_loaded_value(element, prepare_integrate_value(element.type, result_value))
            end
            return obj
        end
        
        def prepare_integrate_value(type, value)
            return value
        end
        
    end
    
    
end; end; end