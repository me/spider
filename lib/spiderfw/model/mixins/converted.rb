module Spider; module Model

    module Converted

        def self.extended(model)
            model.extend(ClassMethods)
        end
        
        def self.included(model)
            model.extend(ClassMethods)
        end

        module ClassMethods
            
            def convert(obj)
                custom_conv_method = "convert_from_#{self.converting}"
                if (self.respond_to?(custom_conv_method))
                    res = self.send(custom_conv_method, obj)
                else
                    res = self.new
                    obj.class.elements_array.each do |el|
                        our_element = self.elements[el.name]
                        next unless our_element
                        if (el.model?)
                            if (our_element.model.is_a?(InlineModel))
                                objects = el.multiple? ? obj.get(el) : [obj.get(el)]
                                objects.each do |sub_obj|
                                    next unless sub_obj # WTF?
                                    res.set(el.name, obj.get(el).get(el.model.primary_keys[0]))
                                end
                                next
                            end
                            next unless our_element.model.is_a?(Converted)
                            next if our_element.attributes[:added_reverse] || our_element.has_single_reverse?
                            objects = el.multiple? ? obj.get(el) : [obj.get(el)]
                            objects.each do |sub_obj|
                                next unless sub_obj # WTF?
                                convert_associated(self.elements[el.name], sub_obj, res)
                            end
                        else
                            res.set(el.name, obj.get(el))
                        end
                    end
                    self.conversion_model.primary_keys.each do |k|
                        res.set(conversion_key(self.converting, k), obj.get(k))
                    end
                end
                if (self.respond_to?("after_convert_from_#{self.converting}"))
                    return self.send("after_convert_from_#{self.converting}", obj, res)
                end
                return res
            end
            
            def convert_associated(element, src, dest)
                puts "Converting associated #{element.name}"
                converted_el_model = element.type.conversions[self.converting]
                cond = Condition.new
                converted_el_model.primary_keys.each do |k|
                    cond[element.type.conversion_key(self.converting, k)] = src.get(k)
                end
                res = element.type.find(cond)
                if res.length > 1
                    Spider::Logger.error("The converted object was not unique")
                    Spider::Logger.error(res)
                end
                if (element.multiple?)
                    dest.get(element) << res[0]
                else
                    dest.set(element, res[0])
                end
            end

            def converting(name=nil) 
                return @converting unless name
                @converting = name
            end
            
            def conversions
                @conversions
            end

            def conversion(name, app_or_model)
                model = app_or_model.subclass_of?(Spider::Model::BaseModel) ? app_or_model : app_or_model.const_get(self.short_name)
                @conversions ||= {}
                @conversions[name] = model
                #Spider::Logger.debug("Converting #{self} from #{model}")
                model.primary_keys.each do |k|
                    element(conversion_key(name, k), k.type, :hidden => true) unless k.attributes[:no_conv_map]
                end
            end
            
            def conversion_model
                return nil unless @conversions
                @conversions[@converting]
            end
            
            def conversion_key(conversion, key)
                return key.name if key.attributes[:no_conv_map]
                return :"conv_#{conversion}_#{key.name}"
            end


        end

        class ConversionException < RuntimeError
        end

    end

end; end
