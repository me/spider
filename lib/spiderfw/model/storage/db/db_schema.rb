require 'spiderfw/model/storage/schema'

module Spider; module Model; module Storage; module Db
    
    class DbSchema < Spider::Model::Storage::Schema
        attr_reader :sequences, :columns, :foreign_keys, :primary_key, :partial
        
        def initialize()
            super
            @columns = {}
            @foreign_keys = {}
            @junction_tables = {}
            @sequences = {}
            @partial = false
        end
        
        def table
            return @table
        end
        
        def table=(name)
            @table = name
        end
        alias :set_table :table=
        
        def field(element_name)
            if (@columns[element_name])
                return @columns[element_name][:name]
            elsif (@foreign_keys[element_name])
                unless @foreign_keys[element_name].length == 1 # FIXME!!
                    raise SchemaException, "No single field for element #{element_name}" 
                end
                @foreign_keys[element_name].each do |key, val|
                    return val[:name]
                end
            end
            return nil
        end
        
        def attributes(element_name)
            return nil if (!@columns[element_name])
            return @columns[element_name][:attributes]
        end

        
        def qualified_field(element_name)
            raise SchemaException, "No DB field defined for element #{element_name}" unless f = field(element_name)
            return @table + '.' + f
        end

        def foreign_key_field(element_name, key_name)
            return nil unless @foreign_keys[element_name]
            return @foreign_keys[element_name][key_name][:name]
        end
        
        def qualified_foreign_key_field(element_name, key_name)
            return @table + '.' + foreign_key_field(element_name, key_name)
        end
        
        def has_fields?(element_name)
            return (@columns[element_name] || @foreign_keys[element_name]) ? true : false
        end

        def has_foreign_fields?(element_name)
            return @foreign_keys[element_name] ? true : false
        end
        
        def column(element_name)
            return @columns[element_name]
        end 
        
        def set_column(element_name, column_description)
            @columns[element_name] = column_description
        end
        
        def set_foreign_key(element_name, element_key, column_description)
            @foreign_keys[element_name] ||= {}
            @foreign_keys[element_name][element_key] = column_description
        end
        
        def set_sequence(name, db_name)
            @sequences[name] = db_name
        end
        
        def sequence(name)
            @sequences[name]
        end
        
        # def set_junction_table(element_name, description)
        #     @junction_tables[element_name] = description
        # end
        # 
        # def junction_table_name(element_name)
        #     return @junction_tables[element_name][:name]
        # end
        # 
        # def junction_table_our_field(element_name, key)
        #     return @junction_tables[element_name][:ours][key][:name]
        # end
        # 
        # def junction_table_their_field(element_name, key)
        #     return @junction_tables[element_name][:theirs][key][:name]
        # end
        # 
        # def junction_table_added_field(element_name, added_element)
        #     return @junction_tables[element_name][:added][added_element][:name]
        # end
        
        def get_schemas
            schemas = {}
            schemas[@table] = {:columns => {}, :attributes => {}}
            @columns.each do |element, column|
                schemas[@table][:columns][column[:name]] = {:type => column[:type], :attributes => column[:attributes]}
            end
            @foreign_keys.each_key do |element|
                @foreign_keys[element].each do |key, column|
                    schemas[@table][:columns][column[:name]] = {:type => column[:type], :attributes => column[:attributes]}
                end
            end
            schemas[@table][:attributes][:primary_key] = @primary_key
            # @junction_tables.each do |element, junction_table|
            #     table_name = junction_table[:name]
            #     schemas[table_name] = {}
            #     [junction_table[:ours], junction_table[:theirs], junction_table[:added]].each do |fields|
            #         continue unless fields
            #         fields.each do |key, column|
            #             schemas[table_name][column[:name]] = { :type => column[:type], :attributes => column[:attributes] }
            #         end
            #     end
            # end
            return schemas
        end
        
        def set_primary_key(columns)
            @primary_key = columns
        end
        
    end
    

    
end; end; end; end
