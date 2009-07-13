require 'spiderfw/model/storage/schema'

module Spider; module Model; module Storage; module Db
    
    # The class describind the DB table(s) associated to a model.
    
    class DbSchema < Spider::Model::Storage::Schema
        # An Hash of db names for each named sequence.
        attr_reader :sequences
        # An Hash of column definitions for each element:
        # {:element_name => {:name => 'COLUMN_NAME', :attributes => {...}}}
        attr_reader :columns
        # An Hash of column definitions for foreign keys:
        # {:element_name => {:primary_key_name => {:name => 'FOREGIN_COLUMN', :attributes => {...}}}}
        attr_reader :foreign_keys
        # Primary key column(s)
        attr_reader :primary_key
        # An Hash of elements without primary columns.
        attr_reader :pass
        
        def initialize()
            super
            @columns = {}
            @foreign_keys = {}
            @junction_tables = {}
            @sequences = {}
            @pass = {}
        end
        
        # Returns the main table name.
        def table
            return @table
        end
        
        # Sets the main table name.
        def table=(name)
            @table = name
        end
        alias :set_table :table=
        
        # Returns the db column defined for the element.
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
        
        # Returns column attributes for given element name.
        def attributes(element_name)
            return nil if (!@columns[element_name])
            return @columns[element_name][:attributes]
        end

        # Returns the column for element_name, prefixed with the table name.
        def qualified_field(element_name)
            raise SchemaException, "No DB field defined for element #{element_name}" unless f = field(element_name)
            return @table + '.' + f
        end

        # Returns the defined foreign key column for given element and primary key
        def foreign_key_field(element_name, key_name)
            return nil unless @foreign_keys[element_name]
            return @foreign_keys[element_name][key_name][:name]
        end
        
        # Returns table_name + '.' + #foreign_key_field
        def qualified_foreign_key_field(element_name, key_name)
            return @table + '.' + foreign_key_field(element_name, key_name)
        end
        
        # True if element_name has a defined column or foreign key.
        def has_fields?(element_name)
            return (@columns[element_name] || @foreign_keys[element_name]) ? true : false
        end

        def has_foreign_fields?(element_name)
            return @foreign_keys[element_name] ? true : false
        end
        
        # Returns the column name for an element.
        def column(element_name)
            return @columns[element_name]
        end 
        
        # Sets the column name for an element.
        def set_column(element_name, column_description)
            column_description[:attributes] ||= {}
            @columns[element_name] = column_description
        end
        
        # Sets a foreign key to the primary key of an element.
        def set_foreign_key(element_name, element_key, column_description)
            @foreign_keys[element_name] ||= {}
            @foreign_keys[element_name][element_key] = column_description
        end
        
        # Sets the db name for a named sequence.
        def set_sequence(name, db_name)
            @sequences[name] = db_name
        end
        
        # Sets that given element has no associated db field.
        def set_nil(name)
            @pass[name] = true
        end
        
        # Returns the db name of a named sequence.
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
        
        # Returns a description of all the tables used by the model.
        # Returns a struct in the form
        #   {table_name => :columns => {
        #     'column_name' => {:type => 'column_type', :attributes => {:attr => true, :attr2 => 'some_val, ...}}
        #   }, :attributes => {
        #     :primary_key => 'primary_key_column', ...
        #   }}
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
        
        # Sets the primary key (a comma separated list of column names).
        def set_primary_key(columns)
            @primary_key = columns
        end
        
    end
    

    
end; end; end; end
