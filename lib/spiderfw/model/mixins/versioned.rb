require 'digest/sha1'
require 'yaml'

module Spider; module Model
    
    module Versioned
        
        
        def self.included(model)
            return if model.is_a?(ClassMethods) && model.version_model
            model.extend(ClassMethods)
            model.mapper_include(Mapper)
            model.remove_element(:v_sha1) if model.elements[:v_sha1] && model.elements[:v_sha1].integrated?
            unless model.elements[:v_sha1] #|| model.attributes[:sub_model]
                model.element(:v_sha1, String, :length => 40, :hidden => true) 
            end
            
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
            vmod.element(:v_sha1, String, :primary_key => true, :length => 40, :version_pk => true, :hidden => true) 
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
              if self.attributes[:sub_model] && self.attributes[:sub_model].respond_to?(:version_model)
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
              vmod.element(:v_original, self, :add_multiple_reverse => {:name => :history, :version_history => true, :hidden => true}, :hidden => true)
              vmod.element(:version_date, DateTime)
              vmod.element(:version_comment, String)
              vmod.remove_element(:history)
              self.elements_array.each do |el|
                  next if el.name == :v_sha1
                  elh = dump_element(el)
                  if el.integrated?
                      if el.integrated_from.type < Versioned && vmod.elements[el.name] && vmod.elements[el.name].model? && \
                          !vmod.elements[el.name].integrated_from.type.attributes[:version_model]
                          vmod.remove_element(el) 
                      end
                      next
                  end
                  next unless elh
                  # elh[:attributes][:primary_key] = false
                  # debugger if elh[:attributes][:junction]
                  # vmod.send(elh[:method], elh[:name], elh[:type], elh[:attributes])
                  if (el.model?)
                      is_version_content = el.type < Spider::Model::Versioned && el.attributes[:version_content] != false
                      if elh[:attributes][:integrated_model]
                          elh[:type].elements.each do |ielname, iel|
                              i = vmod.elements[ielname]
                              vmod.remove_element(ielname) if i && i.integrated? && i.integrated_from.name == el.name
                          end
                          elh[:attributes][:integrate] = true
                          elh[:attributes].delete(:extended_model)
                          elh[:attributes].delete(:embedded)
                      end
                      if el.attributes[:add_reverse] || el.attributes[:add_multiple_reverse]
                          rev = el.attributes[:add_reverse] || el.attributes[:add_multiple_reverse]
                          el.type.version_model.remove_element(rev[:name]) if el.type.respond_to?(:version_model)
                      end
                      if vmod.elements[el.name] && elh[:attributes][:reverse] && !is_version_content
                          vmod.elements[el.name].attributes.delete(:reverse)
                          vmod.elements[el.name].attributes.delete(:condition)
                      end
                      if el.multiple? && !el.attributes[:junction] && !is_version_content
                          # Note: this creates a junction
                          # When the object is deleted, the junction will be deleted too since the object
                          # is not versioned
                          elh[:attributes].delete(:reverse)
                          elh[:attributes].delete(:add_reverse)
                          elh[:attributes].delete(:add_multiple_reverse)
                          vmod.remove_element(el.name)
                          vmod.send(elh[:method], el.name, el.type, elh[:attributes])
                      elsif !el.attributes[:added_reverse] && el.model < Spider::Model::Versioned
                          vmod.remove_element(el.name)
                          if elh[:method] == :tree
                              vmod.remove_element(elh[:attributes][:reverse])
                              vmod.remove_element(elh[:attributes][:tree_left])
                              vmod.remove_element(elh[:attributes][:tree_right])
                              vmod.remove_element(elh[:attributes][:tree_depth])
                              vmod.remove_element(elh[:attributes][:tree_position])
                              vmod.tree(el.name, elh[:attributes])
                          else
                              vmod.send(elh[:method], el.name, el.type.version_model, elh[:attributes])
                          end
                          @version_elements[el.name] = el.name
                      elsif el.attributes[:junction] && el.attributes[:owned]
                          # elh[:attributes][:has_single_reverse] = (el.attributes[:reverse] && !el.type.elements[el.attributes[:reverse]].multiple?)
                          junction = vmod.elements[el.name].attributes[:association_type]
                          unless junction < Spider::Model::Versioned || (el.attributes[:embedded] && self.storage.supports?(:embedding))
                              junction.module_eval{ include Spider::Model::Versioned } 
                              junction.versioning(branch)
                          end
                          unless vmod.elements[el.name].model.attributes[:version_model]
                              elh[:attributes][:through] = junction.version_model
                              elh[:attributes][:junction_our_element] = "#{elh[:attributes][:reverse]}".to_sym
                              elh[:attributes][:junction_their_element] = "#{elh[:attributes][:junction_their_element]}".to_sym
                              vmod.remove_element(el.name)
                              junction_type = nil
                              if is_version_content
                                  junction_type = el.type.version_model
                              else
                                  junction_type = el.type
                                  elh[:attributes].delete(:reverse)
                                  elh[:attributes].delete(:add_reverse)
                                  elh[:attributes].delete(:add_multiple_reverse)
                                  v_junction = junction.version_model
                                  v_junction.remove_element(elh[:attributes][:junction_their_element])
                                  v_junction.element(elh[:attributes][:junction_their_element], el.type, :association => :choice, :junction_reference => true)
                                  v_junction.integrate(elh[:attributes][:junction_their_element], :hidden => true, :no_pks => true)
                                  
                              end
                              vmod.send(elh[:method], el.name, junction_type, elh[:attributes])
                              
                              junction.version_model.integrate(elh[:attributes][:junction_their_element]) if junction.attributes[:sub_model] == self
                          end
                          @version_elements[el.name] = el.name
                      end
                  end
              end
              vmod.elements_array.each{ |el| el.attributes[:unique] = false if el.attributes[:unique] }            
              doc_storage = Spider.conf.get('storage.versioning.use_document')
              if doc_storage && Spider.conf.get("storages.#{doc_storage}")
                  vmod.use_storage(doc_storage)
                  vmod.elements_array.select{ |el| el.junction? }.each do |el|
                      el.model.use_storage(doc_storage)
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
           
           # Returns the elements that concur to define the objects version
           def version_contents
               #no_content_assocs = [:choice, :multiple_choice]
               no_content_assocs = []
               supports_embed = self.storage.supports?(:embedding)

               self.elements_array.select{ |el|
                   el.attributes[:version_content] || mapper.have_references?(el.name) || (!el.attributes[:added_reverse] && !no_content_assocs.include?(el.association))
               }.reject{ |el| el.attributes[:version_content] == false || (el.model? && !(el.model < Spider::Model::Versioned)) }
           end
           
           def version_ignored_elements
               [:v_sha1, :history, :obj_created, :obj_modified]
           end
           
           def version?
               false
           end
            
        end
        
        module Mapper
            
            def get_dependencies(task)
                return super unless @model.respond_to?(:version_model)
                deps = []
                obj = task.object
                action = task.action
                version_contents = obj.class.version_contents
                vmod = @model.version_model
                case action
                when :save_version
                    version_contents.each do |vc|
                        next unless vc.model?
                        next if vc.integrated?
                        v_el = vmod.elements[vc.name]
                        next unless v_el
                        is_embedded = v_el.attributes[:embedded] && vmod.storage.supports?(:embedding)
                        next if is_embedded && !vc.junction?
                        Spider.logger.debug("VC #{vc.name}")
                        set = obj.send(vc.name)
                        next unless set
                        set = obj.prepare_version_object(vc.name, set) if obj.respond_to?(:prepare_version_object)
                        next if set.eql?(obj)
                        set = obj.instance_variable_get("@#{vc.name}_junction") if vc.junction? && !vc.attributes[:keep_junction]
                        next unless set
                        set = [set] unless vc.multiple?
                        set.each do |set_obj|
                            s_obj = set_obj
                            if have_references?(vc)
                                #Spider.logger.debug("Version on #{obj} (#{obj.class}) depends on #{set_obj} (#{set_obj.class})")
                                deps << [task, MapperTask.new(set_obj, :save_version)]
                            elsif vc.junction?
                                dejunct = set_obj.get(vc.attributes[:junction_their_element])
                                dejunct = obj.class.prepare_junction_version_object(vc.name, dejunct) if obj.class.respond_to?(:prepare_junction_version_object)
                                dejunct_task = MapperTask.new(dejunct, :save_version)
                                junction_task = MapperTask.new(set_obj, :save_version)
                                if is_embedded
                                    deps << [task, dejunct_task] if dejunct.class < Spider::Model::Versioned
                                else
                                    deps << [junction_task, dejunct_task] if dejunct.class < Spider::Model::Versioned
                                    deps << [junction_task, task]
                                end
                            else
                                #Spider.logger.debug("Version on #{set_obj} (#{set_obj.class}) depends on #{obj} (#{obj.class})")
                                deps << [MapperTask.new(set_obj, :save_version), task]
                            end
                        end
                    end
                else
                    return super
                end
                deps
            end
            
            def execute_action(action, object, params) # :nodoc:
                return super unless [:save_version, :save_junction_version].include?(action)
                case action
                when :save_version
                    save_version(object)
                when :save_junction_version
                    save_junction_version(object)
                end
            end
            
            def save_version(object)
                mod = @model
                vmod = mod.version_model
                vobj = vmod.static()
                ve = mod.version_element
                current_sha1 = object.get(ve)
                new_sha1 = object.version_sha1
                # debugger
                # debugger
                return if current_sha1 == new_sha1
                # debugger
                object.v_sha1 = new_sha1
                vobj = Spider::Model.get(vmod, :v_sha1 => new_sha1)
                vobj.autoload(false)
                object.populate_version_object(vobj)
                vobj.autoload(false)
                
                vobj.set(mod.elements[:history].reverse, object)
                vobj.set(:version_date, DateTime.now)
                # vobj.set(:version_comment, comment)
                object.mapper.do_update(object)
                dup = false
                begin
                    vobj.mapper.insert(vobj)
                    #vobj.insert
                rescue Spider::Model::Storage::DuplicateKey
                    dup = true
                    Spider.logger.error("Duplicate version for #{self}")
                end
                object.autoload(true)
                object.trigger(:version_saved) unless dup
            end
            
            def save_junction_version(object)
                vmod = @model.version_model
                vobj = vmod.static
                object.class.elements_array.select{ |el| el.attributes[:junction_reference] }.each do |el|
                    val = object.get(el)
                    vobj.set(el, val.get(:v_sha1))
                end
                vobj.mapper.do_insert(vobj)
            end

        end
        
        def version_sha1
            yaml = YAML::dump(self.version_flatout)
            sha1 = Digest::SHA1.hexdigest(yaml)
        end
        
        def version_sha1_getnew
            yaml = YAML::dump(self.get_new.version_flatout)
            sha1 = Digest::SHA1.hexdigest(yaml)
        end
        
        def version_flatout(params={})
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
                        obj = self.prepare_version_object(el.name, obj)
                    end
                    if is_version_content && self.class.mapper.have_references?(el)
                        if (el.multiple?)
                            h[el.name] = obj.map{ |o| o.v_sha1 }
                        else
                            h[el.name] = obj.v_sha1
                        end
                    elsif is_version_content && el.type < Spider::Model::Versioned
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
                        obj = self.prepare_version_object(el.name, obj)
                    end
                    next if params[:except_objects].include?(obj)
                    
                    if !obj
                       h[el.name] = nil
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
        
        def populate_version_object(vobj)
            mod = self.class
            vmod = mod.version_model
            version_contents = self.class.version_contents
            
            self.class.elements_array.each do |el|
                v_el = vmod.elements[el.name]
                next unless v_el
                next if el.model? && el.type.attributes[:version_model]
                next if el.integrated? && !(el.integrated_from.embedded? && vmod.storage.supports?(:embedding))
                is_embedded = el.attributes[:embedded] && vmod.storage.supports?(:embedding)
                next if el.multiple? && el.model.respond_to?(:version_element) && !is_embedded
                is_version_content = version_contents.include?(el)
                #debugger if el.name == :news_list
                el_val = self.get(el)
                if self.respond_to?(:prepare_version_object)
                    el_val = self.prepare_version_object(el.name, el_val) 
                end
                #next unless mod.mapper.have_references?(el)
                if el_val && el.multiple?
                    if !(v_el.model < Spider::Model::VersionModel)
                        el_val.each do |v|
                            vobj.get(el.name) << v
                        end
                    elsif is_embedded && el.junction?
                        el_val = instance_variable_get("@#{el.name}_junction") if !el.attributes[:keep_junction]
                        el_val.each do |v|
                            jv = v_el.model.new
                            jv_sha1 = v.version_sha1
                            v.populate_version_object(jv)
                            jv.v_sha1 = jv_sha1
                            vobj.get(el.name) << jv
                        end
                    end
                elsif el.model? && el_val && v_el.type < Spider::Model::VersionModel # && is_version_content 
                    
                    vobj.set(el.name, el_val.get(el.type.version_element))
                            # if self.class.attributes[:sub_model] && self.class.attributes[:sub_model].respond_to?(:prepare_junction_version_object)
                            #     prep_val = self.class.attributes[:sub_model].prepare_junction_version_object(self.class.attributes[:sub_model_element], el_val)
                            #     prep_val.save_version
                            # end
                else
                    vobj.set(el.name, el_val)
                end
            end
        end
        
        def save_version(comment=nil)
            obj = nil
            Spider::Model.in_unit do |uow|
                obj = Spider::Model.identity_mapper.put(self)
                uow.add(obj, :save_version)
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
        
        def previous_version(back=1)
            self.class.version_model.where{ |s| 
                (s.v_original == self) & (s.v_sha1 .not self.v_sha1) 
            }.order_by(:version_date, :desc).limit(1).offset(back-1)[0]
        end
        
        def last_version
            self.class.version_model.where{ |s| 
                (s.v_original == self)
            }.order_by(:version_date, :desc).limit(1)[0]
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
