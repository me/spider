

module Spider; module Model
    
    module ActiveRecordModel
        
        def self.included(mod)
            mod.extend(ClassMethods)
            mod.mapper_include(MapperMethods)
        end
        
        module ClassMethods
            
            def ar=(val)
                @ar = val
            end
            
            def ar
                @ar
            end
            
            def ar_schema
                @ar_schema
            end
            
            def ar_defined=(val)
                @ar_defined = val
            end
            
            def ar_defined
                @ar_defined
            end
            
            def ar_through_models
                ar = @ar
                m = []
                ar.reflections.each do |name, reflection|
                     if (reflection.through_reflection)
                        m << reflection.through_reflection.klass.spider_model
                    end
                end
                return m
            end
            
            def rails_app_name=(val)
                @rails_app_name = val
            end
            
            def rails_app_name
                @rails_app_name
            end
            
            def prepare_to_code
                c = super
                schema = "@ar_schema = #{@ar_schema.inspect}\n"
                c[:additional_code] << schema
                return c
            end
            
            def define_from_ar
                ar = @ar
                type_conversion = {
                    :integer       => Fixnum,
                    :float         => Float,
                    :decimal       => BigDecimal,
                    :datetime      => DateTime,
                    :date          => Date,
                    :timestamp     => DateTime,
                    :time          => DateTime,
                    :string        => String,
                    :text          => Spider::DataTypes::Text,
                    :binary        => Spider::DataTypes::Binary,
                    :boolean       => Spider::DataTypes::Bool
                }
                skip_columns = {}
                ar.reflections.each do |name, refl|
                    begin
                        skip_columns[refl.association_foreign_key.to_sym] = true
                        skip_columns[refl.primary_key_name.to_sym] = true
                    rescue NoMethodError
                    end
                end
                tree_options = nil
                if (ar.respond_to?(:acts_as_nested_set_options))
                    tree_options = ar.acts_as_nested_set_options
                    skip_columns[tree_options[:parent_column].to_sym] = true
                    skip_columns[tree_options[:left_column].to_sym] = true
                    skip_columns[tree_options[:right_column].to_sym] = true
                end
                @ar_schema = {:table => ar.table_name, :columns => {}}
                ar.columns.each do |col|
                    options = {}
                    name = col.name.to_sym
                    name = :obj_created if name == :created_on
                    name = :obj_modified if name == :updated_on
                    column = col.name
                    type = type_conversion[col.type]
                    skip = skip_columns[name]
                    if ar.primary_key == column
                        options[:primary_key] = true 
                        options[:autoincrement] = true
                    end
                    
                    hidden = [:obj_created, :obj_modified]
                    options[:hidden] = true if hidden.include?(name)
                    next if skip
#                    debugger if name == :parent_id
                    @ar_schema[:columns][name] = col.name
                    next unless type
                    self.element(name, type, options)
                end
                ar.reflections.each do |name, reflection|
                    options = {}
                    association = nil
                    if (reflection.macro == :belongs_to)
                        association = nil
                    else
                        association = :many
                        options[:multiple] = true
                            
                        # unless options[:reverse]
                        #     options[:add_reverse] = ar.send(:undecorated_table_name, ar.name)
                        # end
                        options[:has_single_reverse] = true
                    end
                    options[:association] = association
                    if (reflection.options[:polymorphic])
                        self.element(name, Fixnum, options)
                        @ar_schema[:columns][name] = reflection.primary_key_name.to_s
                        next
                    end
                    begin
                        if (reflection.through_reflection)
                            klass = reflection.through_reflection.klass

                            options[:junction] = true
                            klass.reflections.each do |r_name, r_refl|
                                if (r_refl.klass == ar && r_refl.primary_key_name == reflection.primary_key_name)
                                    options[:junction_their_element] = r_name
                                elsif(r_refl.klass == reflection.klass && r_refl.primary_key_name == reflection.association_foreign_key)
                                    options[:junction_our_element] = r_name
                                end
                            end
                            assoc_type = klass.spider_model
#                            assoc_type.integrate(options[:junction_their_element])
                            options[:association_type] = assoc_type
                            type = reflection.klass.spider_model
                            options[:junction_id] = :id
                            options.delete(:has_single_reverse)
                        elsif (reflection.options[:join_table])
                            klass = reflection.klass
                            type = klass.spider_model
                            junction_model_name = Spider::Inflector.camelize([ar.name.to_s, klass.name.to_s].sort.join('_')).to_sym
                            pm = self.parent_module
                            self_name = ar.name.downcase.to_sym
                            other_name = klass.name.downcase.to_sym
                            options[:junction_their_element] = other_name
                            options[:junction_our_element] = self_name
                            options[:junction] = true
                            options[:reverse] = self_name
                            if (pm.const_defined?(junction_model_name))
                                junction_mod = pm.const_get(junction_model_name)
                            else
                                junction_mod = Class.new(Spider::Model::BaseModel)
                                pm.const_set(junction_model_name, junction_mod)
                                
                                junction_mod.attributes[:sub_model] = ar.spider_model
                                junction_mod.element(self_name, ar.spider_model, :hidden => true, :reverse => name, :primary_key => true) 
                                junction_mod.element(other_name, type, :primary_key => true)
                                junction_mod.ar_defined = true
                            end
                            unless junction_mod.is_a?(ActiveRecordModel)
                                junction_mod.instance_eval do
                                    include ActiveRecordModel
                                end
                            end
                            junction_mod.instance_variable_set("@ar_schema", {
                                :table => reflection.options[:join_table],
                                :columns => {
                                    self_name => "#{ar.name.downcase}_id",
                                    other_name => "#{klass.name.downcase}_id"
                                }
                            })
                            options[:through] = junction_mod
                            options[:association_type] = junction_mod
                            options[:junction_id] = :id
                            options.delete(:has_single_reverse)
                            #junction_mod.integrate(other_name, :hidden => true, :no_pks => true)
                        else
                            klass = reflection.klass
                            type = klass.spider_model
                        end
                        klass.reflections.each do |r_name, r_refl|
                            begin
                                if (r_refl.klass == ar && r_refl.primary_key_name == reflection.primary_key_name)
                                    options[:reverse] = r_name
                                end
                            rescue => exc
                            end
                        end                            
                        type ||= klass.spider_model
                    rescue NameError => exc
                        #$stderr << exc.inspect+"\n"
                        next
                    end

                    next unless type
                    next if options[:junction]  && (!options[:junction_their_element] || !options[:junction_our_element])
                    self.element(name, type, options)
                    unless reflection.options[:join_table]
                        if (reflection.table_name == ar.table_name)
                            @ar_schema[:columns][name] = reflection.association_foreign_key
                        elsif (!(reflection.macro == :has_many || reflection.through_reflection))
                            @ar_schema[:columns][name] = reflection.primary_key_name.to_s
                        end
                    end
                end
                if (tree_options)
                    include Spider::Model::Tree
                    self.tree :children, :tree_left => :lft, :tree_right => :rgt, :reverse => :parent, :tree_depth => :depth
                    @ar_schema[:columns].merge!({
                        :lft => tree_options[:left_column],
                        :rgt => tree_options[:right_column],
                        :parent => tree_options[:parent_column]
                    })
                end

                
                def get_connection_url(conf)
                    url = case conf['adapter']
                    when 'mysql'
                        str = "db:mysql://#{conf['username']}:#{conf['password']}@#{conf['host']}"
                        str += conf['port'] if conf['port']
                        str += "/#{conf['database']}"
                        str
                    end
                    return url
                end
                
                if (@rails_app_name)
                    rails_app_name = @rails_app_name
                elsif (const_defined?("SETTINGS") && SETTINGS.is_a?(Hash))
                    rails_app_name = SETTINGS[:app_name]
                elsif const_defined?("APP_NAME")
                    rails_app_name = APP_NAME
                else
                    rails_app_name = 'rails'
                end
                Spider.conf.set("storages.#{rails_app_name}.url", get_connection_url(ar.configurations['production']))
                self.use_storage(rails_app_name)
                
                
            end
            
        end
        
        module MapperMethods
                
            def before_save(obj, mode)
                obj.obj_created = DateTime.now if obj.respond_to?(:obj_created=) && mode == :insert
                obj.obj_modified = DateTime.now if obj.respond_to?(:obj_modified=) && obj.modified?
                super
            end
            
            def generate_schema(schema=nil)
                return super unless @model.ar_schema
                schema = Spider::Model::Storage::Db::DbSchema.new
                schema.table = @model.ar_schema[:table]
                @model.ar_schema[:columns].each do |name, field|
                    element = @model.elements[name]
                    if (element.model?)
                        storage_type = Spider::Model.base_type(element.type.primary_keys[0].type)
                    else
                        storage_type = Spider::Model.base_type(element.type)
                    end
                    column_type = @storage.column_type(storage_type, element.attributes)
                    db_attributes = @storage.column_attributes(storage_type, element.attributes)
                    if (element.model?)
                        schema.set_foreign_key(element.name, element.type.primary_keys[0].name, 
                        :name => field,
                        :type => column_type,
                        :attributes => db_attributes
                        )
                    else
                        schema.set_column(name,
                        :name => field,
                        :type => column_type,
                        :attributes => db_attributes
                        )
                    end
                end
                return schema
            end
            
        end
        
    end
    
    def self.ar_models
        @ar_models
    end
    
    def self.create_ar_classes(ar, container)
        @ar_models ||= []
        return if ar.spider_model
        name = ar.name.split(':')[-1]
        if (container.const_defined?(name))
            current = container.const_get(name)
        end
        unless current
            mod = Class.new(Spider::Model::BaseModel)
            container.const_set(name, mod)
        else
            mod = current
        end
        unless mod.is_a?(ActiveRecordModel)
            mod.instance_eval do
                include ActiveRecordModel
            end
        end
        mod.ar_defined = true unless current
        mod.ar = ar
        ar.spider_model = mod
        ar.reflections.each do |name, reflection|
            begin 
                create_ar_classes(reflection.klass, container) unless reflection.klass.spider_model
                through = reflection.through_reflection.klass
                create_ar_classes(through, container) if through && !through.spider_model
            rescue NameError
            end
        end
        @ar_models << mod
    end
    
end; end