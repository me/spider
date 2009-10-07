require 'spiderfw/model/mappers/mapper'
require 'fileutils'

module Spider; module Model; module Mappers

    # Simple mapper for an array of hash data. Used by the InlineModel.
    class HashMapper < Spider::Model::Mapper
        
        def initialize(model, storage)
            super
            @type = :hash
        end
        
        # False. This mapper is read-only.
        def self.write?
            false
        end
        
        def have_references?(key)
            true
        end
        
        # Fetch implementation.
        #--
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
            raise MapperError, "Model has no primary key or no description element" unless primary_key && desc
            res =  @model.data.map{ |id, val| {primary_key => id, desc => val} }.select do |row|
                check_condition(query.condition, row)
            end
            res.extend(Spider::Model::Storage::StorageResult)
            return res
        end
        
        # Checks if a row (hash) matches a Condition.
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
        
        def prepare_query(query, obj=nil) #:nodoc:
            query = super
            @model.elements.select{ |name, element| !element.model? }.each do |name, element|
                query.request[element] = true
            end
            return query
        end
        
        def map(request, result, obj_or_model) #:nodoc:
            obj = obj_or_model.is_a?(Class) ? obj_or_model.new : obj_or_model
            request.keys.each do |element_name|
                element = @model.elements[element_name]
                next if element.model?
                result_value = result[element_name]
                obj.set_loaded_value(element, prepare_map_value(element.type, result_value))
            end
            return obj
        end
        
        def prepare_map_value(type, value) #:nodoc:
            return value
        end
        
    end
    
    
end; end; end