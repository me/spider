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
        # {:element_name => {:primary_key_name => {:name => 'FOREIGN_COLUMN', :attributes => {...}}}}
        attr_reader :foreign_keys
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
        def table=(table)
            table = Table.new(table) unless table.is_a?(Table)
            @table = table
        end
        alias :set_table :table=
        
        # Returns the db column defined for the element.
        def field(element_name)
            if (@columns[element_name])
                return @columns[element_name]
            elsif (@foreign_keys[element_name])
                unless @foreign_keys[element_name].length == 1 # FIXME!!
                    raise SchemaException, "No single field for element #{element_name}" 
                end
                @foreign_keys[element_name].each do |key, val|
                    return val
                end
            end
            return nil
        end
        
        # Returns column attributes for given element name.
        def attributes(element_name)
            return nil if (!@columns[element_name])
            return @columns[element_name].attributes
        end

        # Returns the column for element_name, prefixed with the table name.
        def qualified_field(element_name, qualifier=nil)
            raise SchemaException, "No DB field defined in table #{@table} for element #{element_name}" unless f = field(element_name)
            qualifier ||= @table.name
            return qualifier + '.' + f.name
        end

        # Returns the defined foreign key column for given element and primary key
        def foreign_key_field(element_name, key_name)
            return nil unless @foreign_keys[element_name]
            return @foreign_keys[element_name][key_name]
        end
        
        # Returns table_name + '.' + #foreign_key_field
        def qualified_foreign_key_field(element_name, key_name)
            return @table.name + '.' + foreign_key_field(element_name, key_name).name
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
        def set_column(element_name, field)
            field = Field.new(@table, field[:name], field[:type]) if field.is_a?(Hash)
            @columns[element_name] = field
        end
        
        # Sets a foreign key to the primary key of an element.
        def set_foreign_key(element_name, element_key, field)
            field = Field.new(@table, field[:name], field[:type]) if field.is_a?(Hash)
            @foreign_keys[element_name] ||= {}
            @foreign_keys[element_name][element_key] = field
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
            return schemas
        end
        
        # Primary key column(s)
        def primary_keys
            @table.fields.select{ |f| f.primary_key? }
        end
        
        
    end
    
    class Table
        attr_reader :name, :fields, :attributes
        
        def initialize(name, attributes={})
            @name = name
            @attributes = attributes
            @fields = []
        end
        
        def add_field(field)
            @fields << field
        end
        
        def to_s
            @name
        end
        
    end
    
    class Field
        attr_reader :name, :table
        attr_accessor :type
        attr_accessor :attributes
        
        def initialize(table, name, type, attributes={})
            @table = table
            @name = name
            @type = type
            @attributes = attributes
            @table.add_field(self)
        end
        
        
        def primary_key
            @attributes[:primary_key]
        end
        alias :primary_key? :primary_key
        
        def primary_key=(val)
            @attributes[:primary_key] = true
        end
        
        
        def to_s
            "#{@table.name}.#{@name}"
        end
        
        
        
    end
    

    
end; end; end; end
