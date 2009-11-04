require 'digest/sha1'

module Spider; module Model
    
    module Versioned
        
        def self.included(model)
            
            model.extend(ClassMethods)
            model.mapper_include(Mapper)
            vmod = Class.new(model)
            vmod.primary_keys.each do |pk|
                vmod.element_attributes(pk.name, :primary_key => false)
            end
            model.const_set("Versioned", vmod)
            model.set_version_model(nil, vmod)
            model.element(:sha1, String, :length => 40)
        end
        
        module ClassMethods
           
           def versioning(branch=nil)
              @version_models ||= {} 
              @version_elements ||= {}
              unless @version_models[branch]
                  vmod = Class.new(self)
                  vmod_name = "Versioned"
                  vmod_name += Spider::Inflector.camelize(branch) if branch
                  const_set(vmod_name.to_sym, vmod)
                  @version_models[branch] = vmod
              end
              vmod = @version_models[branch]
              vmod.primary_keys.each do |pk|
                  vmod.delete_element(pk.name)
              end
              vmod.elements_array.each do |el|
                  el.attributes[:autoincrement] = false
              end
              vmod.element(:sha1, String, :primary_key => true, :length => 40)
              vmod.element(self.short_name.to_sym, self, :add_multiple_reverse => :history)
              vmod.element(:version_date, DateTime)
              self.elements_array.each do |el|
                  elh = dump_element(el)
                  next if el.integrated?
                  next unless elh
                  # elh[:attributes][:primary_key] = false
                  # debugger if elh[:attributes][:junction]
                  # vmod.send(elh[:method], elh[:name], elh[:type], elh[:attributes])
                  if (el.model?)
                      if (self.mapper.have_references?(el) && el.model < Spider::Model::Versioned)
                          vname = "#{el.name}_versioned".to_sym
                          @version_elements[el.name] = vname
                          vmod.send(elh[:method], vname, el.model.version_model)
                      elsif (el.attributes[:junction] && el.type < Spider::Model::Versioned)
                          # el.attributes[:association_type].module_eval{ include Spider::Model::Versioned }
                          # el.attributes[:association_type].versioning(branch)
                          # elh[:attributes].
                          # debugger
                          # elh[:attributes][:has_single_reverse] = (el.attributes[:reverse] && !el.type.elements[el.attributes[:reverse]].multiple?)
                          junction = el.attributes[:association_type]
                          unless junction < Spider::Model::Versioned && junction.version_model
                              junction.module_eval{ include Spider::Model::Versioned }
                              junction.versioning(branch)
                          end
                          elh[:attributes][:through] = junction.version_model
                          elh[:attributes][:junction_our_name] = "#{elh[:attributes][:reverse]}_versioned".to_sym
                          elh[:attributes][:junction_their_element] = "#{elh[:attributes][:junction_their_element]}_versioned".to_sym
                          vname = "#{elh[:name]}_versioned".to_sym
                          vmod.send(elh[:method], vname, el.type.version_model, elh[:attributes])
                          @version_elements[el.name] = vname
                      end
                  end
              end
           end
           
           def version_element(el=nil)
               return :sha1 unless el
               el = el.name if el.respond_to?(:name)
               @version_elements[el]
           end
           
           def version_model(branch=nil)
               @version_models ||= {}
               @version_models[branch]
           end
           
           def set_version_model(branch, model)
               @version_models ||= {}
               @version_models[branch] = model
           end
            
        end
        
        module Mapper
           
           def save_done(obj, mode)
               obj.set(obj.class.version_element, obj.version_sha1)
               obj.reset_modified_elements
               obj.set_modified(:sha1 => true)
               obj.mapper.do_update(obj)
               super
           end
            
        end
        
        def version_sha1
            yaml = self.to_yaml(:except => [:sha1])
            sha1 = Digest::SHA1.hexdigest(yaml)
        end
        
        def save_version
            mod = self.class
            vmod = mod.version_model
            vobj = vmod.new()
            vobj.set(mod.elements[:history].reverse, self)
            ve = mod.version_element
            unless self.get(ve)
                self.set(ve, self.version_sha1)
                self.mapper.do_update(self)
            end
            mod.elements_array.each do |el|
                vobj.set(el.name, self.get(el))
                vel = mod.version_element(el)
                if (vel)
                    if (mod.mapper.have_references?(el))
                        el_sha1 = self.get(el).get(el.model.version_element)
                        vobj.set(vel, el_sha1)
                    else
                        cond = Spider::Model::Condition.and
                        cond[el.reverse] = self
                        ass = el.model.find(cond)
                        ass.each do |row|
                            row.save_version
                        end
                    end
                end
            end
            vobj.set(:version_date, DateTime.now)
            begin
                vobj.mapper.do_insert(vobj)
            rescue Spider::Model::Storage::DuplicateKey
            end
        end
        
    end
    
end; end