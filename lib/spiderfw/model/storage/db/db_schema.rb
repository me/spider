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
            @foreign_key_constraints = []
            @order = []
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
            f = foreign_key_field(element_name, key_name)
            return f.expression if f.is_a?(FieldExpression)
            raise "No foreign key field for #{element_name} #{key_name} in #{@table}" unless f
            return @table.name + '.' + f.name
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
            field = {:name => field} if field.is_a?(String)
            field = Field.new(@table, field[:name], field[:type], field[:attributes] || {}) if field.is_a?(Hash)
            had_column = @columns[element_name]
            @columns[element_name] = field
            @order << field unless had_column
        end
        
        # Sets a foreign key to the primary key of an element.
        def set_foreign_key(element_name, element_key, field)
            field = {:name => field} if field.is_a?(String)
            if field.is_a?(Hash)
                field[:attributes] ||= {}
                field[:attributes][:expression] ||= field[:expression]
                field[:attributes][:fixed] ||= field[:fixed]
                if field[:attributes][:expression] || field[:attributes][:fixed]
                    field[:name] = "#{@table}_#{element_name}_#{element_key}".upcase
                    if field[:attributes][:fixed]
                        field = FixedExpression.new(@table, field[:name], field[:type], field[:attributes][:fixed], field[:attributes])
                    else
                        field = FieldExpression.new(@table, field[:name], field[:type], field[:attributes] || {})
                    end
                else
                    field = Field.new(@table, field[:name], field[:type], field[:attributes] || {}) 
                end
            end
            @foreign_keys[element_name] ||= {}
            had_fk = @foreign_keys[element_name][element_key]
            @foreign_keys[element_name][element_key] = field
            @order << field unless had_fk
        end
        
        def set_foreign_key_constraint(name, table, keys, options={})
            @foreign_key_constraints << ForeignKeyConstraint.new(name, table, keys, options)
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
            schemas[@table.name] = {:columns => {}, :attributes => {}, :fields_order => @order}
            @columns.each do |element, column|
                schemas[@table.name][:columns][column.name] = {:type => column.type, :attributes => column.attributes}
            end
            @foreign_keys.each_key do |element|
                @foreign_keys[element].each do |key, column|
                    schemas[@table.name][:columns][column.name] = {:type => column.type, :attributes => column.attributes}
                end
            end
            schemas[@table.name][:attributes][:primary_keys] = primary_keys.map{ |k| k.name }
            schemas[@table.name][:attributes][:foreign_key_constraints] = @foreign_key_constraints
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
        
        def inspect
            "#<#{self.class.name}:#{self.object_id} @name=\"#{@name}\ >"
        end
        
    end
    
    class Field
        attr_reader :table
        attr_accessor :name, :type
        attr_accessor :attributes
        
        def initialize(table, name, type, attributes={})
            @table = table
            @name = name.to_s
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
        
        def inspect
            "#<#{self.class.name}:#{self.object_id} @name=\"#{@name}\", @table=#<Spider::Model::Storage::Db::Table:#{@table.object_id} #{@table.name}> >"
        end
        
        def ==(other)
            @table == other.table && @name == other.name
        end
        
        
        def eql?(other)
            self == other
        end
        
        def hash
            to_s.hash
        end
        
    end

    class FieldInAliasedTable < Field

        def initialize(field, table_alias)
            @table = field.table
            @name = field.name
            @type = field.type
            @table_alias = table_alias
        end

        def to_s
            "#{@table_alias}.#{@name}"
        end

        def inspect
            "#<#{self.class.name}:#{self.object_id} @name=\"#{@name}\", @table=#<Spider::Model::Storage::Db::Table:#{@table.object_id} #{@table.name} AS #{@table_alias}> >"
        end

    end
    
    class FieldExpression < Field
        attr_reader :expression
        
        def initialize(table, name, type, attributes={})
            @table = table
            @name = name.to_s
            @type = type
            @attributes = attributes
            @expression = attributes[:expression]
        end
        
        
        def to_s
            "#{@expression} AS #{@name}"
        end
        
    end

    class FixedExpression < FieldExpression
        def initialize(table, name, type, fixed_value, attributes={})
            attributes[:expression] = fixed_value
            super(table, name, type, attributes)
        end
    end
    
    class FieldFunction
        attr_reader :expression, :table, :joins
        attr_accessor :as
        def initialize(expression, table, joins)
            @expression = expression
            @table = table
            @joins = joins
        end

        def aggregate=(val)
            @aggregate = val
        end

        def aggregate?
            !!@aggregate
        end
        
        def to_s
            if @as
                "#{@expression} AS #{@as}"
            else
                @expression
            end
        end
    end
    
    class ForeignKeyConstraint
        attr_reader :name, :table, :fields, :options
        
        def initialize(name, table, fields, options={})
            @name = name.to_s
            @table = table
            @fields = fields
            @options = options
        end
        
        def ==(other)
            other.table == @table && other.fields == @fields && other.options == @options
        end
        
        def eq?(other)
            self ==  other
        end
        
    end
    

    
end; end; end; end
