module Spider; module Migrations

    module PreviousModel

        def self.included(klass)
            klass.extend(ClassMethods)
            klass.with_mapper do
                def schema_table_name
                    if @model.previous_model_of
                        model.previous_model_of.mapper.schema.table.name
                    else
                        super.gsub('previousmodels__', '')
                    end
                end
            end
        end

        def to_new_model
            nm = self.class.previous_model_of
            obj = nm.new
            vals = self.to_hash
            vals.each do |k, v|
                obj.set(k, v) if nm.elements[k]
            end
            obj
        end

        module ClassMethods


            def previous_model_of(model=nil)
                @replacement_model = model if model
                @replacement_model
            end


            def class_table_inheritance(params={})
                unless params[:name]
                    spm = nil
                    mpm = nil
                    if @replacement_model
                        spm = @replacement_model.parent_module
                    else
                        spm = self.parent_module.parent_module
                    end
                    if superclass.respond_to?(:previous_model_of)
                        if superclass.previous_model_of
                            mpm = superclass.previous_model_of
                        else
                            mpm = superclass.parent_module.parent_module
                        end
                    else
                        mpm = superclass.parent_module
                    end
                    integrated_name = (spm == mpm) ? superclass.short_name : superclass.name
                    integrated_name = Spider::Inflector.underscore(integrated_name).gsub('/', '_')
                    params[:name] = integrated_name
                end
                super(params)
            end

            def element(name, type, attributes={}, &proc)
                super
                if @elements[name].junction?
                    @elements[name].model.send(:include, PreviousModel)
                end
            end

        end

    end

end; end