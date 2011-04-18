require 'spiderfw/model/mappers/mapper'
require 'fileutils'


module Spider; module Model; module Mappers

    class DocumentMapper < Spider::Model::Mapper
        include Spider::Model::Storage::Document
                
        def embedding(obj)
            embedder_el = obj.embedder
            return nil unless embedder_el
            first_embedder = obj.get(embedder_el)
            while first_embedder._subclass_object
                first_embedder = first_embedder._subclass_object
            end
            reverse_el = embedder_el.type.elements[embedder_el.reverse]
            path = "#{reverse_el.name}.#{obj.get(reverse_el.attributes[:embed_key])}"
            parent_obj = obj.get(embedder_el)
            # while parent_obj._subclass_object
            #     parent_obj = parent_obj._subclass_object
            # end
            parent_embedding = parent_obj.mapper.embedding(parent_obj)
            if parent_embedding
                first_embedder = parent_embedding[0]            
                path = "#{parent_embedding[0]}.#{path}"
            end
            [first_embedder, path]
        end

        def do_update(obj)
            search_obj = obj
            emb = embedding(obj)
            path = nil
            search_obj, path = emb if emb
            condition = {}
            # search_obj.class.primary_keys.each do |pk|
            #     name = pk.name == :id ? '_id' : pk.name
            #     condition[name] = map_condition_value(pk.type, search_obj.get(pk))
            # end
            condition["_id"] = obj.keys_string
            set = {}
            document_elements(obj).select{ |el| obj.element_modified?(el) }.each do |el|
                name = el.name
                name = "#{path}.#{name}" if path
                if el.model?
                    if el.attributes[:embedded]
                        set[name] = obj_to_hash(obj.get(el), :embed_key => el.attributes[:embed_key])
                    else
                        set[name] = obj.get(el).keys_string
                    end
                else
                    set[name] = map_save_value(el.type, obj.get(el), :update)
                end
            end
            storage.update(search_obj.class.name, condition, set)
        end

        def do_insert(obj)
            storage.insert(obj.class.name, obj_to_hash(obj)) 
        end
        
        def assign_pk(obj)
            if obj.is_a?(QuerySet)
                obj.each{ |o| assign_pk(o) }
                return
            end
            obj.class.elements_array.select{ |el| el.type <= Spider::DataTypes::PK }.each do |el|
                obj.set(el, storage.generate_pk) unless obj.element_has_value?(el)
            end
        end

        def do_delete(condition, force)
            query = Spider::Model::Query.new(condition)
            objs = self.find(query)
            return unless objs
            objs.each do |obj|
                storage.delete(obj.class.name, obj_to_hash(obj)) 
            end
        end
        
        def before_save(obj, mode)
            super
            obj.class.elements_array.select{ |el| 
                el.attributes[:embedded] && !el.attributes[:extended_model] && obj.element_has_value?(el)
            }.each do |el|
                if el.multiple?
                    obj.get(el).each do |o|
                        o.mapper.before_save(o, mode)
                    end
                else
                    o = obj.get(el)
                    next unless o
                    o.mapper.before_save(o, mode)
                end
            end
        end
        
        def document_elements(obj)
            obj.class.elements_array.select{ |el| document_element?(el, obj.class) }
        end
        
        def document_element?(el, model=@model)
            return true if el.attributes[:document_element]
            return false if el.multiple? && !el.attributes[:embedded]
            return false if el.attributes[:extended_model]
            return false if el.attributes[:added_reverse]
            return false if el.attributes[:computed_from]
            return false if el.integrated? && !el.integrated_from.attributes[:extended_model]
            return true

        end
        
        def embed?(element, val=nil)
            return false unless element.attributes[:embedded] && element.model.embeddable?
            return false if element.integrated?
            model = nil
            if val
                model = val.is_a?(QuerySet) ? val.model : val.class
            else
                model = element.model
            end
            return false unless model.embeddable?
            
            return true
        end


        def obj_to_hash(obj, options={})
            h = {}
            if obj.class == QuerySet
                res = obj.map{ |obj| obj_to_hash(obj) } 
                if options[:embed_key]
                    h = {}
                    res.each do |val|
                        h[val[options[:embed_key].to_s]] = val
                    end
                    return h
                end
                return res
            end
            
            document_elements(obj).each do |el|
                next if el.primary_key?
                name = el.name
                next if options[:skip] && options[:skip].include?(el.name)
                val = obj.get(el)
                sub_options = {}
                hval = if el.model? && val
                    if embed?(el, val)
                        if el.multiple?
                            # if el.junction?
                            #     sub_options[:skip] = [el.reverse]
                            # end
                            if el.attributes[:embed_key]
                                el_h = {}
                                val.each do |row|
                                    el_h[row.get(el.attributes[:embed_key])] = row.mapper.obj_to_hash(row, sub_options)
                                end
                                el_h
                            else
                                h_mapper = val[0] && val[0].mapper.respond_to?(:obj_to_hash) ? val[0].mapper : self
                                val.map{ |row| h_mapper.obj_to_hash(row, sub_options) }
                            end
                        else
                            sub_mapper = val.mapper.respond_to?(:obj_to_hash) ? val.mapper : self
                            sub_mapper.obj_to_hash(val, sub_options)
                        end
                    else
                        val.keys_string
                    end
                else
                    map_save_value(el.type, val)
                end
                h[name] = hval
            end
            
            assign_pk(obj)
            h["_id"] = obj.keys_string
            
            h
        end

        def have_references?(element)
            element = @model.elements[element] unless element.is_a?(Element)
            document_element?(element)
        end
        
        def someone_have_references?(element)
            element = @model.elements[element] unless element.is_a?(Element)
            if (element.integrated?)
                return element.model.someone_have_references?(element.attributes[:integrated_from_element])
            end
            return have_references?(element)
        end
        
        
        def map(request, result, obj_or_model)
            # FIXME: ignores request for now
            model = obj_or_model.is_a?(Class) ? obj_or_model : obj_or_model.model
            if (!request || request == true)
                request = Request.new
                model.elements_array.each{ |el| request.request(el.name) }
            end
            subclass_type_el = model.elements_array.select{ |cel| cel.attributes[:subclass_type] }.first
            if subclass_type_el && subclass_type = result[subclass_type_el.name]
                model = const_get_full(subclass_type)
            end
            embedded = {}
            embedded_keys = model.elements_array.select{ |el| embed?(el) && !el.attributes[:extended_model] }.map{ |el| el.name }
            # debugger
            # embed?(:civilia_open_persona) if $DO_DEBUG
            embedded_keys.each do |k|
                embedded[k] = result.delete(k)
            end
            data = {}
            request.keys.each do |element_name|
                element = model.elements[element_name]
                result_value = nil
                next if !element || (element.integrated? && !element.integrated_from.embedded?) || !have_references?(element)
                next if embedded[element_name]
                if element.model?
                    pks = {}
                    keys_str = result[element_name]
                    next if keys_str.blank?
                    pks_array = element.model.split_keys_string(keys_str)
                    element.model.primary_keys.each_with_index do |key, i|
                        key_val = pks_array[i]
                        pks[key.name] = map_back_value(key.type, key_val)
                    end
#                    begin
                    data[element_name] = Spider::Model.get(element.model, pks, true)
#                    rescue IdentityMapperException
                        # null keys, nothing to set
#                    end
                elsif !element.model?
                    data[element_name] = map_back_value(element.type, result[element_name])
                end
            end
            obj = Spider::Model.get(model, data, true)
            embedded.each do |k, v|
                if !v
                    obj.set_loaded_value(k, nil) if request[k]
                    next
                end
                next if v.is_a?(Array) && v.empty?
                el = obj.class.elements[k]
                if el.multiple?
                    vals = []
                    if el.attributes[:embed_key]
                        vals = v.values
                    else
                        vals = v
                    end
                    qs = QuerySet.static(el.model)
                    el_model = el.model
                    el_mapper = el.model.mapper
                    if el.junction? && !el.attributes[:keep_junction]
                        el_model = el.type
                        el_mapper = el.model.mapper
                    end
                    vals.each do |val|
                        # FIXME: pass sub request
                        sub_obj = el_mapper.map(true, val, el_model)#Spider::Model.get(el_model, val, true)
                        qs << sub_obj
                    end
                    obj.set_loaded_value(k, qs)
                else
                    # FIXME: pass sub request request[el.name]
                    sub_obj = el.model.mapper.map(true, v, el.model)
                    obj.set_loaded_value(k, sub_obj)
                end
                
            end
            obj
        end
        
        
        def save_extended_models(obj, mode)
            return
        end
        
        def children_for_unit_of_work(obj, action)
            obj.class.elements_array.select{ |el| 
                el.model? && obj.element_has_value?(el) && !el.attributes[:embedded]  && !el.attributes[:added_reverse]
            }.map do |el|
                obj.get(el)
            end
        end
        
        def get_external_element(element, query, objects)
            return objects if element.attributes[:embedded] || element.attributes[:extended_model]
            super
        end

        def determine_save_mode(obj)
            if @model.extended_models && !@model.extended_models.empty?
                has_pks = true
                @model.primary_keys.each do |pk|
                    if pk.integrated? && pk.integrated_from.attributes[:extended_model]
                        return super unless pk.integrated_from.attributes[:embedded]
                        unless obj.element_has_value?(pk)
                            has_pks = false
                            break
                        end
                    end
                end
                return has_pks ? :update : :insert
            end
        end


    end

end; end; end