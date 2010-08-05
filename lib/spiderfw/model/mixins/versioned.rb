require 'digest/sha1'
require 'yaml'

module Spider; module Model
    
    module Versioned
        
        def self.included(model)
            model.extend(ClassMethods)
            model.mapper_include(Mapper)
            model.element(:v_sha1, String, :length => 40) unless model.elements[:v_sha1]
            
            #model.versioning
            par = model.containing_module
            local_name = model.name.sub(par.name+'::', '')
            unless par.const_defined?(:Versioned)
                par.const_set(:Versioned, Module.new)
            end
            versioned_module = par.const_get(:Versioned)
            vmod = Versioned.create_version_model(model)
            versioned_module.const_set_full(local_name, vmod)
            model.set_version_model(nil, vmod)
        end
        
        def self.create_version_model(model)
            vmod = Class.new(model)
            vmod.class_eval{ include VersionModel }
            vmod.remove_element(:v_sha1)
            vmod.primary_keys.each do |pk|
                 vmod.element_attributes(pk.name, :primary_key => false)
             end
            vmod.element(:v_sha1, String, :primary_key => true, :length => 40, :version_pk => true) 
            local_pk = "id_versioned_#{model.short_name.downcase}"
            vmod.element(local_pk, Fixnum, :autoincrement => true, :local_pk => true, :hidden => true)
            vmod
        end
        
        module ClassMethods
           
           def versioning(branch=nil)
              @version_models ||= {} 
              @version_elements ||= {}
              par = self.containing_module
              local_name = self.name.sub(par.name, '')
              versioned_module = par.const_get(:Versioned)
              unless @version_models[branch]
                  vmod = Versioned.create_version_model(self)
                  vmod_name = local_name.to_s
                  vmod_name += Spider::Inflector.camelize(branch) if branch
                  versioned_module.const_set_full(vmod_name, vmod)
                  @version_models[branch] = vmod
              end
              vmod = @version_models[branch]
              if self.attributes[:sub_model]
                  vmod.attributes[:sub_model] = self.attributes[:sub_model].version_model
              end
              if @polymorphic_models
                  @polymorphic_models.each do |pmod, options|
                      pmod = pmod.version_model if pmod.respond_to?(:version_model)
                      vmod.polymorphic(pmod, options)
                  end
              end
              vmod.attributes[:version_model] = true
              vmod.primary_keys.each do |pk|
                  vmod.remove_element(pk.name) unless pk.attributes[:version_pk] # FIXME
              end
              vmod.elements_array.each do |el|
                  el.attributes[:autoincrement] = false
              end
              # vmod.remove_element(:v_sha1)
              self.remove_element(:history) # may exist from superclass
              vmod.element(:v_original, self, :add_multiple_reverse => {:name => :history, :version_history => true})
              vmod.element(:version_date, DateTime)
              vmod.element(:version_comment, String)
              self.elements_array.each do |el|
                  next if el.name == :v_sha1
                  elh = dump_element(el)
                  next if el.integrated?
                  next unless elh
                  # elh[:attributes][:primary_key] = false
                  # debugger if elh[:attributes][:junction]
                  # vmod.send(elh[:method], elh[:name], elh[:type], elh[:attributes])
                  if (el.model?)
                      if elh[:attributes][:integrated_model]
                          elh[:type].elements.each do |ielname, iel|
                              vmod.remove_element(ielname) if vmod.elements[ielname] && vmod.elements[ielname].integrated?
                          end
                          elh[:attributes][:integrate] = true
                      end
                      if el.attributes[:add_reverse] || el.attributes[:add_multiple_reverse]
                          rev = el.attributes[:add_reverse] || el.attributes[:add_multiple_reverse]
                          el.type.version_model.remove_element(rev[:name]) if el.type.respond_to?(:version_model)
                      end
                      if (!el.attributes[:added_reverse] &&  el.model < Spider::Model::Versioned)
                          vmod.remove_element(el.name)
                          if elh[:method] == :tree
                              vmod.remove_element(elh[:attributes][:reverse])
                              vmod.remove_element(elh[:attributes][:tree_left])
                              vmod.remove_element(elh[:attributes][:tree_right])
                              vmod.remove_element(elh[:attributes][:tree_depth])
                              vmod.tree(el.name, elh[:attributes])
                          else
                              vmod.send(elh[:method], el.name, el.type.version_model, elh[:attributes])
                          end
                          @version_elements[el.name] = el.name
                      elsif (el.attributes[:junction] && el.type < Spider::Model::Versioned)
                          
                          # el.attributes[:association_type].module_eval{ include Spider::Model::Versioned }
                          # el.attributes[:association_type].versioning(branch)
                          # elh[:attributes].
                          # debugger
                          # elh[:attributes][:has_single_reverse] = (el.attributes[:reverse] && !el.type.elements[el.attributes[:reverse]].multiple?)
                          junction = el.attributes[:association_type]
                          unless junction < Spider::Model::Versioned 
                              junction.module_eval{ include Spider::Model::Versioned } 
                              junction.versioning(branch)
                          end
                          unless vmod.elements[el.name].model.attributes[:version_model]
                              elh[:attributes][:through] = junction.version_model
                              elh[:attributes][:junction_our_element] = "#{elh[:attributes][:reverse]}".to_sym
                              elh[:attributes][:junction_their_element] = "#{elh[:attributes][:junction_their_element]}".to_sym
                              vmod.remove_element(el.name)
                              vmod.send(elh[:method], el.name, el.type.version_model, elh[:attributes])
                          end
                          @version_elements[el.name] = el.name
                      end
                  end
              end              
           end
           
           def version_element(el=nil)
               return :v_sha1 unless el
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
           
           def version_contents
               no_content_assocs = [:choice, :multiple_choice]

               self.elements_array.select{ |el|
                   el.attributes[:version_content] || mapper.have_references?(el.name) || (!el.attributes[:added_reverse] && !no_content_assocs.include?(el.association))
               }
           end
           
           def version_ignored_elements
               [:v_sha1, :history, :obj_created, :obj_modified]
           end
           
           def version?
               false
           end
            
        end
        
        module Mapper
           
           # def save_done(obj, mode)
           #     obj.set(obj.class.version_element, obj.version_sha1)
           #     obj.reset_modified_elements
           #     obj.set_modified(:v_sha1 => true)
           #     obj.mapper.do_update(obj)
           #     super
           # end
           
           # def save_done(obj, mode)
           #     obj.save_version if mode == :insert
           #     super
           # end
            
        end
        
        def version_sha1
            yaml = YAML::dump(self.version_flatout)
            # Spider.logger.debug("YAML for #{self.class}, #{self}:")
            #  Spider.logger.debug(yaml)
            sha1 = Digest::SHA1.hexdigest(yaml)
        end
        
        def version_sha1_getnew
            yaml = YAML::dump(self.get_new.version_flatout)
            sha1 = Digest::SHA1.hexdigest(yaml)
        end
        
        def version_flatout(params={})
            #return YAML::dump(self)
            h = {}
            def v_obj_pks(obj, klass, use_sha)
                if use_sha && obj.respond_to?(:v_sha1)
                    return obj.v_sha1
                else
                    unless obj
                        return klass.primary_keys.length > 1 ? [] : nil
                    end
                    pks = obj.primary_keys
                    return pks[0] if pks.length == 1
                    return pks
                end
            end 

            version_contents = self.class.version_contents
            exclude_elements = self.class.version_ignored_elements
            self.class.elements_array.each do |el|
                next if exclude_elements.include?(el.name)
                next if el.name == :v_sha1
                next if el.name == :history
                next if params[:except] && params[:except].include?(el.name)
                next if el.integrated?
                if (el.model?)
                    is_version_content = version_contents.include?(el)
                    obj = get(el)
                    unless obj
                        h[el.name] = obj
                        next
                    end
                    if self.class.attributes[:sub_model] && self.class.attributes[:sub_model].respond_to?(:prepare_junction_version_object)
                        obj = self.class.attributes[:sub_model].prepare_junction_version_object(self.class.attributes[:sub_model_element], obj)
                    elsif self.respond_to?(:prepare_version_object)
                        obj = self.prepare_version_object(el, obj)
                    end
                    if is_version_content && self.class.mapper.have_references?(el)
                        if (el.multiple?)
                            h[el.name] = obj.map{ |o| o.v_sha1 }
                        else
                            h[el.name] = obj.v_sha1
                        end
                    elsif is_version_content # && !model.mapper.have_references?(el) && !el.attributes[:integrated_model]
                        # if (el.multiple?)
                        #     h[el.name] = obj.map{ |o| o.to_yaml_h(:except => exclude_elements) }
                        # else
                        #     h[el.name] = obj.to_yaml_h(:except => exclude_elements)
                        # end
                        if (el.multiple?)
                            h[el.name] = obj.map{ |o| o.version_content_hash(:except_objects => [self]) }
                        else
                            h[el.name] = obj.version_content_hash(:except_objects => [self])
                        end
                    elsif (el.multiple?)
                        h[el.name] = obj.map{ |o| v_obj_pks(o, el.model, false) }
                    else
                        h[el.name] = v_obj_pks(obj, el.model, false)
                    end
                else
                    h[el.name] = get(el)
                end
            end
            return h
        end
        
        def version_content_hash(params={})
            h = {:class => self.class.name}
            version_contents = self.class.version_contents
            exclude_elements = self.class.version_ignored_elements
            params[:except_objects] ||= []
            except_objects = params[:except_objects].clone
            except_objects << self
            self.class.elements_array.each do |el|
                next if exclude_elements.include?(el.name)
                next if el.name == :v_sha1
                next if el.name == :history
                next if params[:except] && params[:except].include?(el.name)
                next if el.integrated?
                if el.model?
                    obj = get(el)
                    next unless obj
                    if el.multiple?
                        obj.each{ |o| except_objects << o }
                    else
                        except_objects << obj
                    end 
                end
            end
            self.class.elements_array.each do |el|                
                next if exclude_elements.include?(el.name)
                next if el.name == :v_sha1
                next if el.name == :history
                next if params[:except] && params[:except].include?(el.name)
                next if el.integrated?
                
                if (el.model?)
                    obj = get(el)
                    next if params[:except_objects].include?(obj)
                    if self.class.attributes[:sub_model] && self.class.attributes[:sub_model].respond_to?(:prepare_junction_version_object)
                        obj =  self.class.attributes[:sub_model].prepare_junction_version_object(self.class.attributes[:sub_model_element], obj)
                    elsif self.respond_to?(:prepare_version_object)
                        obj = self.prepare_version_object(el, obj)
                    end
                    next if params[:except_objects].include?(obj)
                    
                    if !obj
                       h[el.name] = nil
                   # elsif self.class.mapper.have_references?(el)
                   #     if (el.multiple?)
                   #         h[el.name] = obj.map{ |o| o.v_sha1 }
                   #     else
                   #         h[el.name] = obj.v_sha1
                   #     end   
                    elsif el.type.method_defined?(:version_content_hash)
                        if (el.multiple?)
                            h[el.name] = obj.reject{ |o| 
                                params[:except_objects].include?(o) 
                            }.map{ |o| o.version_content_hash(:except_objects => except_objects) }
                        else
                            h[el.name] = obj.version_content_hash(:except_objects => except_objects)
                        end
                    else
                        if (el.multiple?)
                            h[el.name] = obj.reject{ |o| 
                                params[:except_objects].include?(o) 
                            }.map{ |o| params[:except_objects] << o; o.to_yaml_h(:except => exclude_elements + [el.reverse]) }
                        else
                            h[el.name] = obj.to_yaml_h(:except => exclude_elements + [el.reverse])
                        end
                    end
                else
                    h[el.name] = get(el)
                end
            end
            h
        end
        
        def save_version(comment=nil)
            return if @__version_saved
            Spider::Model.with_identity_mapper do |im|
                Spider.logger.debug("SAVING VERSION FOR #{self.class} #{self}")
                mod = self.class
                vmod = mod.version_model
                vobj = vmod.static()
                vobj.set(mod.elements[:history].reverse, self)
                ve = mod.version_element
                version_contents = self.class.version_contents
            
                self.class.elements_array.each do |el|
                    next unless vmod.elements[el.name]
                    next if el.model? && el.type.attributes[:version_model]
                    next if el.integrated?
                    # vobj.set(el.name, self.get(el))
                    # vel = mod.version_element(el)
                    if el.model?
                        is_version_content = version_contents.include?(el)
                        if mod.mapper.have_references?(el)
                            el_val = self.get(el)
                            if is_version_content && el_val && el.model.respond_to?(:version_element)
                                if self.respond_to?(:prepare_version_object)
                                    el_val = self.prepare_version_object(el, el_val) 
                                end
                                Spider.logger.debug("Doing save_version for referenced #{el}")
                                el_val.save_version
                                vobj.set(el.name, el_val.get(el.model.version_element))
                                if self.class.attributes[:sub_model] && self.class.attributes[:sub_model].respond_to?(:prepare_junction_version_object)
                                    prep_val = self.class.attributes[:sub_model].prepare_junction_version_object(self.class.attributes[:sub_model_element], el_val)
                                    prep_val.save_version
                                end
                            else
                                vobj.set(el.name, el_val)
                            end
                        end
                    else
                        el_val = self.get(el)
                        vobj.set(el.name, el_val)
                    end
                end

                current_sha1 = self.get(ve)
                new_sha1 = self.version_sha1
                return if current_sha1 == new_sha1
                # @@already_saved ||= {}
                # @@already_saved[self.class] ||= {}
                # debugger if @@already_saved[self.class][self.primary_keys]
                # @@already_saved[self.class][self.primary_keys] = self.version_flatout
                self.set(ve, new_sha1)
                self.set_modified(ve => true)
                im.put(self)
                self.mapper.do_update(self)
            
                vobj.set(:v_sha1, new_sha1)
            
                vobj.set(:version_date, DateTime.now)
                vobj.set(:version_comment, comment)
            
            
                begin
                    vobj.mapper.do_insert(vobj)
                rescue Spider::Model::Storage::DuplicateKey
                    Spider.logger.error("Duplicate version for #{self}")
                end
            
                update_version_contents(vobj)
                
                @__version_saved = true
            
            end

        end
        
        def update_version_contents(vobj)
            mod = self.class
            vmod = mod.version_model
            
            self.class.elements_array.each do |el|

                next unless vmod.elements[el.name]
                next if el.model? && el.type.attributes[:version_model]
                next if el.integrated?
                # vobj.set(el.name, self.get(el))
                # vel = mod.version_element(el)
                if el.model?
                    if mod.mapper.have_references?(el)

                    end
                    if !mod.mapper.have_references?(el) && el.reverse
                        # cond = Spider::Model::Condition.and
                        # cond[el.reverse] = self
                        # ass = el.model.where(cond)
                        # if self.respond_to?(:prepare_version_object)
                        #     ass = self.prepare_version_object(el, ass)
                        # end
                        # Spider.logger.debug("Doing save_version for related #{el}")
                        # 
                        # ass.each do |row|
                        #     row.save_version
                        # end
                        
                        ass = self.get(el)
                        if self.respond_to?(:prepare_version_object)
                            ass = self.prepare_version_object(el, ass)
                        end
                        ass = [ass] unless ass.is_a?(Enumerable)
                        ass.each do |row|
                            row.save_version
                        end
                        
                    end
                else
                    el_val = self.get(el)
                    vobj.set(el.name, el_val)
                end
            end
        end

        
        
        def version_modified?
            self.version_sha1 != self.get(self.class.version_element)
        end
        
        def version?
            false
        end
        
        def polymorphic_become(model)
            return super unless model < Spider::Model::VersionModel
            obj = super
            el = self.class.polymorphic_models[model][:through]
            super_obj = obj.get(el)
            return model.where(el => super_obj).order_by(:version_date, :desc).limit(1)[0]
        end
        
        
    end
    
    module VersionModel
        def self.included(model)
            model.extend(ClassMethods)
        end
        
        module ClassMethods
            def version?
                true
            end
        end
        
        def version?
            true
        end
    end
    
end; end