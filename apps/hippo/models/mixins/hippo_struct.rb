module Hippo
    
    class SecurityUser < Spider::Model::BaseModel; end
    class SecurityGroup < Spider::Model::BaseModel; end
    
    module HippoStruct
    
        def self.included(mod)
            mod.extend(ClassMethods)
            mod.mapper_include(Mapper)
            mod.element :id, Fixnum, :primary_key => true
            mod.element :cr_date, DateTime
            mod.element :mod_date, DateTime
            mod.element :cr_user, Hippo::SecurityUser
            mod.element :mod_user, Hippo::SecurityUser
        end
        
        def self.base_elements
            [:id, :cr_date, :mod_date, :cr_user, :mod_user]
        end
    
        module ClassMethods
            
            def element(name, type, attributes={}, &proc)
                el = super
                if (el.attributes[:junction])
                    el.model.elements[:id].attributes[:primary_key] = false
                    el.model.elements[el.attributes[:reverse]].attributes[:primary_key] = true
                    el.model.elements[el.attributes[:junction_their_element]].attributes[:primary_key] = true
                end
                return el
            end

        
            def binding(val=nil)
                if val
                    @binding = val
                    elements_array.select{ |el| el.attributes[:added_reverse] }.each do |el|
                        reverse = el.attributes[:reverse]
                        if (el.type.binding && el.type.binding[:elements][reverse.to_s])
                            el_b = el.type.binding[:elements][reverse.to_s]
                            if (el_b[:type] == "mmbind")
                                @binding[:elements][el.name.to_s] = {
                                    :type => "mmbind",
                                    :table => el_b[:table],
                                    :local_id => el_b[:remote_id],
                                    :remote_id => el_b[:local_id]
                                }
                            end
                        end
                    end
                    self.mapper.schema # generates the schema
                end
                return @binding
            end
        
            def convert_type(type)
                return type.inspect if (type.is_a?(Hash))
                convert = {
                    'text' => String,
                    'longText' => Spider::DataTypes::Text,
                    'dateTime' => DateTime,
                    'int' => Fixnum,
                    'order' => Fixnum,
                    'bool' => Spider::DataTypes::Bool,
                    'real' => Float,
                    'password' => Spider::DataTypes::Password,
                    'html' => Spider::DataTypes::Text,
                    'richText' => Spider::DataTypes::Text
                }
                return convert[type] if (convert[type])
                return convert_struct_name(type)
            end

            def convert_struct_name(struct_name)
                ns, local = struct_name.split('::')
                unless local
                    local = ns
                    ns = 'hippo'
                end
                local = local[1..-1] if local[0].chr == '_'
                if @ns_mappings[ns]
                    app = @ns_mappings[ns]
                else
                    app = Spider::Inflector.camelize(ns)
                end
                model_name = Spider::Inflector.camelize(local)
                return "#{app}::#{model_name}"
            end
        
            def extend_model(model, params={})
                integrated_name = (self.parent_module == model.parent_module) ? model.short_name : model.name
                integrated_name = Spider::Inflector.underscore(integrated_name).gsub('/', '_')
                integrated_name = integrated_name.to_sym
                @extended_models ||= {}
                @extended_models[model] = integrated_name
                attributes = {}
                attributes[:hidden] = true
                attributes[:delete_cascade] = params[:delete_cascade]
            
                # create junction            
                orig_type = model
                assoc_type_name = Spider::Inflector.camelize(model.name).split('::')[1]
                
                attributes[:junction] = true
                attributes[:junction_id] ||= :id
                self_name = self.short_name.gsub('/', '_').downcase.to_sym
                attributes[:reverse] = self_name
                other_name = Spider::Inflector.underscore(orig_type.short_name == self.short_name ? orig_type.name : orig_type.short_name).gsub('/', '_').downcase.to_sym
                other_name = :"#{other_name}_ref" if (orig_type.elements[other_name])
                attributes[:junction_their_element] = other_name
                assoc_type = const_set(assoc_type_name, Class.new(Spider::Model::BaseModel)) # FIXME: maybe should extend self, not the type
                assoc_type.attributes[:sub_model] = self
                #assoc_type.element(attributes[:junction_id], Fixnum, :primary_key => true, :autoincrement => true, :hidden => true)
                assoc_type.element(self_name, self, :hidden => true, :reverse => name, :primary_key => true) # FIXME: must check if reverse exists?
                # FIXME! fix in case of clashes with existent elements
                assoc_type.element(other_name, orig_type, :primary_key => true)
                assoc_type.integrate(other_name, :hidden => true, :no_pks => true)
                attributes[:association_type] = assoc_type
                integrated = element(integrated_name, model, attributes)
                integrate(integrated_name, :no_pks => true) # scazza perché prende le pks da sopra
            end
            
            def get_storage(storage_string='default')
                storage = super
                storage.extend(HippoStorage)
                return storage
            end
        
        end
    
        module Mapper
        
            def generate_schema(schema=nil)
                return super unless @model.binding
                schema = Spider::Model::Storage::Db::DbSchema.new
                schema.table = @model.binding[:table]
                @model.binding[:elements].each do |el, binding|
                    element = @model.elements[el.to_sym]
                    next unless element
                    if (binding[:type] == 'mmbind')
                        junction = element.model.mapper.schema
                        junction.table = binding[:table]
                        junction.foreign_keys[element.attributes[:reverse]] ||= {}
                        junction.foreign_keys[element.attributes[:reverse]][@model.primary_keys[0].name] ||= {}
                        junction.foreign_keys[element.attributes[:reverse]][@model.primary_keys[0].name][:name] = binding[:local_id]
                        junction.foreign_keys[element.attributes[:junction_their_element]] ||= {}
                        junction.foreign_keys[element.attributes[:junction_their_element]][element.type.primary_keys[0].name] ||= {}
                        junction.foreign_keys[element.attributes[:junction_their_element]][element.type.primary_keys[0].name][:name] = binding[:remote_id]
                    elsif (element.model? && !element.multiple?)
                        schema.foreign_keys[element.name] ||= {}
                        schema.foreign_keys[element.name][element.model.primary_keys[0].name] ||= {}
                        schema.foreign_keys[element.name][element.model.primary_keys[0].name][:name] = binding[:field]
                    else
                        schema.columns[element.name] ||= {}
                        schema.columns[element.name][:name] = binding[:field]
                    end
                end
                if (@model.binding[:parent_ref])
                    pr = @model.binding[:parent_ref]
                    extended = nil
                    @model.extended_models.each { |k, v| extended = k; break }
                    element = @model.elements[@model.extended_models[extended]]
                    schema.foreign_keys.delete(@model.extended_models[extended])
                    junction = element.model.mapper.schema
                    junction.table = pr[:table]
                    junction.foreign_keys[element.attributes[:reverse]] ||= {}
                    junction.foreign_keys[element.attributes[:reverse]][@model.primary_keys[0].name] ||= {}
                    junction.foreign_keys[element.attributes[:reverse]][@model.primary_keys[0].name][:name] = pr[:child_id]
                    junction.foreign_keys[element.attributes[:junction_their_element]] ||= {}
                    junction.foreign_keys[element.attributes[:junction_their_element]][element.type.primary_keys[0].name] ||= {}
                    junction.foreign_keys[element.attributes[:junction_their_element]][element.type.primary_keys[0].name][:name] = pr[:parent_id]
                end
                @model.elements_array.each do |el|
                    unless @model.binding[:elements][el.name.to_s] || HippoStruct.base_elements.include?(el.name)
                        schema.pass[el.name] = true 
                    end
                end
#                debugger if @model.name.to_s == "AgendaHippo::Ordine"
                return super(schema)
            end
        
        end
        
        module HippoStorage
            
            def column_type(type, attributes)
                return super(String, attributes) if (type == DateTime)
                return super
            end
            
             def value_to_mapper(type, value)
                 return value unless value
                 case type.name
                 when 'DateTime'
                     begin
                         return DateTime.parse(value)
                     rescue ArgumentError
                         return nil
                     end
                 end
                 return super
             end
            
        end
    
    
    end
    
end
