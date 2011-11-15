require 'spiderfw/model/storage/base_storage'
require 'spiderfw/model/mappers/db_mapper'
require 'iconv'

module Spider; module Model; module Storage; module Db
    
    # Represents a DB connection, and provides methods to execute structured queries on it.
    # This is the class that generates the actual SQL; vendor specific extensions may override the 
    # generic SQL methods.
    
    class DbStorage < Storage::BaseStorage
        @reserved_keywords = ['from', 'order', 'where', 'to']
        @type_synonyms = {}
        @safe_conversions = {
            'TEXT' => ['LONGTEXT'],
            'INT' => ['TEXT', 'LONGTEXT', 'REAL'],
            'REAL' => ['TEXT'],
            'DATETIME' => ['DATE', 'TIME']
        }
        @capabilities = {
            :autoincrement => false,
            :sequences => true,
            :transactions => true
        }

        class << self
            # An Array of keywords that can not be used in schema names.
            attr_reader :reserved_keywords
            # An Hash of DB type equivalents.
            attr_reader :type_synonyms
            # Type conversions which do not lose data. See also #safe_schema_conversion?
            attr_reader :safe_conversions


            def storage_type
                :db
            end
            
            def inherited(subclass)
                subclass.instance_variable_set("@reserved_keywords", @reserved_keywords)
                subclass.instance_variable_set("@type_synonyms", @type_synonyms)
                subclass.instance_variable_set("@safe_conversions", @safe_conversions)
                super
            end

        end
        
        def query_start
            curr[:query_start] = Time.now
        end
        
        def query_finished
            return unless curr[:query_start] # happens if there was no db connection
            now = Time.now
            diff = now - curr[:query_start]
            diff = 0 if diff < 0 # ??? 
            diff = diff*1000
            Spider.logger.info("Db query (#{@instance_name}) done in #{diff}ms")
        end
        
        # The constructor takes the connection URL, which will be parsed into connection params.
        def initialize(url)
            super
        end
        
        
        # Returns the default mapper for the storage.
        # If the storage subclass contains a MapperExtension module, it will be mixed-in with the mapper.
        def get_mapper(model)
            mapper = Spider::Model::Mappers::DbMapper.new(model, self)
            if (self.class.const_defined?(:MapperExtension))
                mapper.extend(self.class.const_get(:MapperExtension))
            end
            return mapper
        end
        
        
        def lock(table, mode=:exclusive)
            lockmode = case(mode)
            when :shared
                'SHARE'
            when :row_exclusive
                'ROW EXCLUSIVE'
            else
                'EXCLUSIVE'
            end
            execute("LOCK TABLE #{table} IN #{lockmode} MODE")
        end
                
        ##############################################################
        #   Methods used to generate a schema                        #
        ##############################################################
        
        # Fixes a string to be used as a table name.
        def table_name(name)
            return name.to_s.gsub(':', '_')
        end
        
        # Fixes a string to be used as a sequence name.
        def sequence_name(name)
            return name.to_s.gsub(':', '_')
        end
        
        # Fixes a string to be used as a column name.
        def column_name(name)
            name = name.to_s
            name += '_field' if (self.class.reserved_keywords.include?(name.downcase)) 
            return name
        end
        
        def foreign_key_name(name)
            name
        end
        
        
        # Returns the db type corresponding to an element type.
        def column_type(type, attributes)
            case type.name
            when 'String'
                'TEXT'
            when 'Text'
                'LONGTEXT'
            when 'Fixnum'
                'INT'
            when 'Float'
                'REAL'
            when 'BigDecimal', 'Spider::DataTypes::Decimal'
                'DECIMAL'
            when 'Date', 'DateTime', 'Time'
                'DATE'
            when 'Spider::DataTypes::Binary'
                'BLOB'
            when 'Spider::DataTypes::Bool'
                'INT'
            end
        end
        
        # Returns the attributes corresponding to element type and attributes
        def column_attributes(type, attributes)
            db_attributes = {}
            case type.name
            when 'Spider::DataTypes::PK'
                db_attributes[:autoincrement] = true if supports?(:autoincrement)
                db_attributes[:length] = 11
            when 'String', 'Spider::DataTypes::Text'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            when 'Float'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
                db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
            when 'BigDecimal'
                db_attributes[:precision] = attributes[:precision] || 65
                db_attributes[:scale] = attributes[:scale] || 2
            when 'Spider::DataTypes::Binary'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            when 'Spider::DataTypes::Bool'
                db_attributes[:length] = 1
            end
            db_attributes[:autoincrement] = attributes[:autoincrement] if supports?(:autoincrement)
            return db_attributes
        end
        
        # Returns the SQL for a QueryFuncs::Function
        def function(func)
            fields = func.elements.map{ |func_el|
                if (func_el.is_a?(Spider::QueryFuncs::Function))
                    function(func_el)
                else
                    func.mapper_fields[func_el.to_s]
                end
            }
            case func.func_name
            when :length
                return "LENGTH(#{fields.join(', ')})"
            when :trim
                return "TRIM(#{fields.join(', ')})"
            when :concat
                return "CONCAT(#{fields.join(', ')})"
            when :substr
                arguments = "#{func.start}"
                arguments += ", #{func.length}" if func.length
                return "SUBSTR(#{fields.join(', ')}, #{arguments})"
            when :subtract
                return "(#{fields[0]} - #{fields[1]})"
            when :rownum
                return "ROWNUM()"
            when :sum, :avg, :count, :first, :last, :max, :min
                return "#{func.func_name.to_s.upcase}(#{fields[0]})"
            end
            raise NotImplementedError, "#{self.class} does not support function #{func.func_name}"
        end
        
        ##################################################################
        #   Preparing values                                             #
        ##################################################################
        
        
        # Converts a value loaded from the DB to return it to the mapper.
        def value_to_mapper(type, value)
            if (type.name == 'String' || type.name == 'Spider::DataTypes::Text')
                enc = @configuration['encoding']
                if (enc && enc.downcase != 'utf-8')
                    begin
                        value = Iconv.conv('utf-8//IGNORE', enc, value.to_s+' ')[0..-2] if value
                    rescue Iconv::InvalidCharacter
                        value = ''
                    end
                end
            end
            return value
        end
        
        # Prepares a value that will be used on the DB.
        def prepare_value(type, value)
            case type.name
            when 'String', 'Spider::DataTypes::Text'
                enc = @configuration['encoding']
                if (enc && enc.downcase != 'utf-8')
                    begin
                        value = Iconv.conv(enc+'//IGNORE', 'utf-8', value.to_s+' ')[0..-2]
                    rescue Iconv::InvalidCharacter
                        value = ''
                    end
                end
            when 'BigDecimal'
                value = value.to_f if value
            end
            return value
        end
        
        # Executes a select query (given in struct form).
        def query(query)
            curr[:last_query] = query
            case query[:query_type]
            when :select
                sql, bind_vars = sql_select(query)
                execute(sql, *bind_vars)
            when :count
                query[:keys] = ['COUNT(*) AS N']
                sql, bind_vars = sql_select(query)
                return execute(sql, *bind_vars)[0]['N'].to_i
            end
        end
        
        # Returns a two element array, containing the SQL for given select query, and the variables to bind.
        def sql_select(query)
            curr[:last_query_type] = :select
            bind_vars = query[:bind_vars] || []
            tables_sql, tables_values = sql_tables(query)
            sql = "SELECT #{sql_keys(query)} FROM #{tables_sql} "
            bind_vars += tables_values
            where, vals = sql_condition(query)
            bind_vars += vals if vals
            sql += "WHERE #{where} " if where && !where.empty?
            having, having_vals = sql_condition(query, true)
            unless having.blank?
                group_fields = (
                    query[:keys].select{ |k| !k.is_a?(FieldExpression)
                } + collect_having_fields(query[:condition])).flatten.uniq
                group_keys = sql_keys(group_fields)
                sql += "GROUP BY #{group_keys} "
                sql += "HAVING #{having} "
                bind_vars += having_vals
            end
            order = sql_order(query)
            sql += "ORDER BY #{order} " if order && !order.empty?
            limit = sql_limit(query)
            sql += limit if limit
            return sql, bind_vars
        end
        
        def total_rows
            curr[:total_rows]
        end
        
        # Returns the SQL for select keys.
        def sql_keys(query)
            query = {:keys => query} unless query.is_a?(Hash)
            query[:keys].join(',')
        end
        
        # Returns an array containing the 'FROM' part of an SQL query (including joins),
        # and the bound variables, if any.
        def sql_tables(query)
            values = []
            sql = query[:tables].map{ |table|
                str = table.name
                if (query[:joins] && query[:joins][table])
                    join_str, join_values = sql_tables_join(query, table)
                    str += " "+join_str
                    values += join_values
                end
                str
            }.join(', ')
            return [sql, values]
        end
        
        # Returns SQL and bound variables for joins.
        def sql_tables_join(query, table)
            str = ""
            values = []
            query[:joins][table].each_key do |to_table|
                join, join_values = sql_joins(query[:joins][table][to_table])
                str += " "+join
                values += join_values
                if (query[:joins][to_table])
                    query[:joins][to_table].delete(table) # avoid endless loop
                    sub_str, sub_values = sql_tables_join(query, to_table)
                    str += " "+sub_str
                    values += sub_values
                end
            end
            return str, values
        end
        
        # Returns SQL and bound variables for a condition.
        def sql_condition(query, having=false)
            condition = query[:condition]
            return ['', []] unless (condition && condition[:values])
            bind_vars = []
            condition[:values].reject!{ |v| (v.is_a?(Hash) && v[:values].empty?)}
            vals = condition[:values]

            return nil if !having && condition[:is_having]
            mapped = vals.map do |v|
                if v.is_a? Hash # subconditions
                    # FIXME: optimize removing recursion
                    sql, vals = sql_condition({:condition => v}, having)
                    next unless sql
                    bind_vars += vals
                    sql = nil if sql.empty?
                    sql = "(#{sql})" if sql && v[:values].length > 1
                    sql
                elsif !having || condition[:is_having]
                    if v[2].is_a? Spider::QueryFuncs::Expression
                        sql_condition_value(v[0], v[1], v[2].to_s, false)
                    else
                        v[1] = 'between' if (v[2].is_a?(Range))
                        v[2].upcase! if (v[1].to_s.downcase == 'ilike')
                        if (v[1].to_s.downcase == 'between')
                            bind_vars << v[2].first
                            bind_vars << v[2].last
                        else
                            bind_vars << v[2] unless v[2].nil?
                        end
                        sql_condition_value(v[0], v[1], v[2])
                    end
                end
            end
            return mapped.reject{ |p| p.nil? }.join(' '+(condition[:conj] || 'and')+' '), bind_vars
        end
        
        # Returns the SQL for a condition comparison.
        def sql_condition_value(key, comp, value, bound_vars=true)
            key = key.expression if key.is_a?(FieldExpression)
            if (comp.to_s.downcase == 'ilike')
                comp = 'like'
                key = "UPPER(#{key})"
            end
            if (value.nil?)
                comp = comp == '=' ? "IS" : "IS NOT"
                sql = "#{key} #{comp} NULL"
            else
                if comp.to_s.downcase == 'between'
                    if bound_vars
                        val0 = val1 = '?' 
                    else
                        val0, val1 = value
                    end
                    sql = "#{key} #{comp} #{val0} AND #{val1}"
                else
                    val = bound_vars ? '?' : value
                    sql = "#{key} #{comp} #{val}"
                    if comp == '<>'
                        sql = "(#{sql} or #{key} IS NULL)"
                    end
                end
            end
            return sql
        end
        
        # def sql_join(joins)
        #     sql = ""
        #     joins.each_key do |from_table|
        #         joins[from_table].each do |to_table, conditions|
        #             conditions.each do |from_key, to_key|
        #                 sql += " AND " unless sql.empty?
        #                 sql += "#{from_table}.#{from_key} = #{to_table}.#{to_key}"
        #             end
        #         end
        #     end
        #     return sql
        # end
        
        # Returns SQL and values for DB joins.
        def sql_joins(joins)
            types = {
                :inner => 'INNER', :outer => 'OUTER', :left => 'LEFT OUTER', :right => 'RIGHT OUTER'
            }
            values = []
            sql = joins.map{ |join|
                to_t = join[:as] || join[:to]
                sql_on = join[:keys].map{ |from_f, to_f|
                    to_field = to_f.is_a?(FieldExpression) ? to_f.expression : "#{to_t}.#{to_f.name}"
                    if from_f.is_a?(FieldExpression)
                        "#{to_field} = #{from_f.expression}"
                    else
                        "#{from_f} = #{to_field}"
                    end
                }.join(' AND ')
                if (join[:condition])
                    condition_sql, condition_values = sql_condition({:condition => join[:condition]})
                    sql_on += " and #{condition_sql}"
                    values += condition_values
                end
                j = "#{types[join[:type]]} JOIN #{join[:to]}"
                j += " #{join[:as]}" if join[:as]
                j += " ON (#{sql_on})"
                j
            }.join(" ")
            return [sql, values]
        end
        
        # Returns SQL for the ORDER part.
        def sql_order(query, replacements={})
            return '' unless query[:order]
            replacements ||= {}
            return query[:order].map{|o| 
                repl = replacements[o[0].to_s]
                ofield = repl ? repl : o[0]
                "#{ofield} #{o[1]}"
            }.join(' ,')
        end
        
        # Returns the LIMIT and OFFSET SQL.
        def sql_limit(query)
            sql = ""
            sql += "LIMIT #{query[:limit]} " if query[:limit]
            sql += "OFFSET #{query[:offset]} " if query[:offset]
            return sql
        end
        
        # Returns SQL and values for an insert statement.
        def sql_insert(insert)
            curr[:last_query_type] = :insert
            sql = "INSERT INTO #{insert[:table]} (#{insert[:values].keys.map{ |k| k.name }.join(', ')}) " +
                  "VALUES (#{insert[:values].values.map{'?'}.join(', ')})"
            return [sql, insert[:values].values]
        end
        
        # Returns SQL and values for an update statement.
        def sql_update(update)
            curr[:last_query_type] = :update
            values = []
            tables = update[:table].to_s
            if (update[:joins] && update[:joins][update[:table]])
                join_str, join_values = sql_tables_join(update, update[:table])
                tables += " "+join_str
                values += join_values
            end
            values += update[:values].values.reject{ |v| v.is_a?(Spider::QueryFuncs::Expression) }
            sql = "UPDATE #{tables} SET "
            sql += sql_update_values(update)
            where, bind_vars = sql_condition(update)
            values += bind_vars
            sql += " WHERE #{where}"
            return [sql, values]
        end
        
        # Returns the COLUMN = val, ... part of an update statement.
        def sql_update_values(update)
            update[:values].map{ |k, v| 
                v.is_a?(Spider::QueryFuncs::Expression) ? "#{k.name} = #{v}" : "#{k.name} = ?"
            }.join(', ')
        end
        
        # Returns SQL and bound values for a DELETE statement.
        def sql_delete(delete, force=false)
            curr[:last_query_type] = :delete
            where, bind_vars = sql_condition(delete)
            where = "1=0" if !force && (!where || where.empty?)
            sql = "DELETE FROM #{delete[:table]}"
            sql += " WHERE #{where}" if where && !where.empty?
            return [sql, bind_vars]
        end
        
        def sql_truncate(table)
            "TRUNCATE #{table}"
        end
        
        # Returns an array of SQL statements for a create structured description.
        def sql_create_table(create)
            name = create[:table]
            fields = create[:fields]
            sql_fields = ''
            fields.each do |field|
                attributes = field[:attributes]
                attributes ||= {}
                length = attributes[:length]
                sql_fields += ', ' unless sql_fields.empty?
                sql_fields += sql_table_field(field[:name], field[:type], attributes)
            end
            if (create[:attributes][:primary_keys] && !create[:attributes][:primary_keys].empty?)
                primary_key_fields = create[:attributes][:primary_keys].join(', ')
                sql_fields += ", PRIMARY KEY (#{primary_key_fields})"
            end
            ["CREATE TABLE #{name} (#{sql_fields})"]
        end
        
        # Returns an array of SQL statements for an alter structured description.
        def sql_alter_table(alter)
            current = alter[:current]
            table_name = alter[:table]
            add_fields = alter[:add_fields]
            alter_fields = alter[:alter_fields]
            alter_attributes = alter[:attributes]
            sqls = []
            
            add_fields.each do |field|
                name, type, attributes = field
                sqls += sql_add_field(table_name, field[:name], field[:type], field[:attributes])
            end
            alter_fields.each do |field|
                name, type, attributes = field
                sqls += sql_alter_field(table_name, field[:name], field[:type], field[:attributes])
            end
            if (alter_attributes[:primary_keys] && !alter_attributes[:primary_keys].empty?)
                sqls << sql_drop_primary_key(table_name) if (current[:primary_keys] && !current[:primary_keys].empty? && current[:primary_keys] != alter_attributes[:primary_keys])
                sqls << sql_create_primary_key(table_name, alter_attributes[:primary_keys])
            end
            if (alter_attributes[:foreign_key_constraints])
                cur_fkc = current && current[:foreign_key_constraints] ? current[:foreign_key_constraints] : []
                cur_fkc.each do |fkc|
                    next if alter_attributes[:foreign_key_constraints].include?(fkc)
                    sqls << sql_drop_foreign_key(table_name, foreign_key_name(fkc.name))
                end
                if (alter_attributes[:foreign_key_constraints])
                    alter_attributes[:foreign_key_constraints].each do |fkc|
                        next if cur_fkc.include?(fkc)
                        sql = "ALTER TABLE #{table_name} ADD CONSTRAINT #{foreign_key_name(fkc.name)} FOREIGN KEY (#{fkc.fields.keys.join(',')}) "
                        sql += "REFERENCES #{fkc.table} (#{fkc.fields.values.join(',')})"
                        sqls << sql
                    end
                end
            end
            return sqls
        end
        
        
        # Executes a create table structured description.
        def create_table(create)
            sqls = sql_create_table(create)
            sqls.each do |sql|
                execute(sql)
            end
        end
        
        # Executes an alter table structured description.
        def alter_table(alter)
            sqls = sql_alter_table(alter)
            sqls.each do |sql|
                execute(sql)
            end
        end
        
        # Drops a field from the DB.
        def drop_field(table_name, field_name)
            sqls = sql_drop_field(table_name, field_name)
            sqls.each{ |sql| execute(sql) }
        end
        
        # Drops a table from the DB.
        def drop_table(table_name)
            sqls = sql_drop_table(table_name)
            sqls.each{ |sql| execute(sql) }
        end
        
        def sql_drop_primary_key(table_name)
            "ALTER TABLE #{table_name} DROP PRIMARY KEY"
        end
        
        def sql_drop_foreign_key(table_name, key_name)
            "ALTER TABLE #{table_name} DROP FOREIGN KEY #{key_name}"
        end
        
        def sql_create_primary_key(table_name, fields)
            "ALTER TABLE #{table_name} ADD PRIMARY KEY ("+fields.join(', ')+")"
        end
        
        # Returns the SQL for a field definition (used in create and alter table)
        def sql_table_field(name, type, attributes)
            f = "#{name} #{type}"
            if (type == 'DECIMAL')
                f += "(#{attributes[:precision]}, #{attributes[:scale]})"
            else
                if attributes[:length] && attributes[:length] != 0
                    f += "(#{attributes[:length]})"
                elsif attributes[:precision]
                    f += "(#{attributes[:precision]}"
                    f += "#{attributes[:scale]}" if attributes[:scale]
                    f += ")"
                end
            end
            return f
        end
        
        # Returns an array of SQL statements to add a field.
        def sql_add_field(table_name, name, type, attributes)
            ["ALTER TABLE #{table_name} ADD #{sql_table_field(name, type, attributes)}"]
        end
        
        # Returns an array of SQL statements to alter a field.
        def sql_alter_field(table_name, name, type, attributes)
            ["ALTER TABLE #{table_name} MODIFY #{sql_table_field(name, type, attributes)}"]
        end
        
        # Returns an array of SQL statements to drop a field.
        def sql_drop_field(table_name, field_name)
            ["ALTER TABLE #{table_name} DROP COLUMN #{field_name}"]
        end
        
        # Returns an array of SQL statements needed to drop a table.
        def sql_drop_table(table_name)
            ["DROP TABLE #{table_name}"]
        end
        
        # Checks if a DB field is equal to a schema field.
        def schema_field_equal?(current, field)
            attributes = field[:attributes]
            return false unless current[:type] == field[:type] || 
                (self.class.type_synonyms && self.class.type_synonyms[current[:type]] && self.class.type_synonyms[current[:type]].include?(field[:type]))
            try_method = :"schema_field_#{field[:type].downcase}_equal?"
            return send(try_method, current, field) if (respond_to?(try_method))
            current[:length] ||= 0; attributes[:length] ||= 0; current[:precision] ||= 0; attributes[:precision] ||= 0
            return false unless current[:length] == attributes[:length]
            return false unless current[:precision] == attributes[:precision]
            return true
        end

        
        # Checks if the conversion from a current DB field to a schema field is safe, i.e. can 
        # be done without loss of data.
        def safe_schema_conversion?(current, field)
            attributes = field[:attributes]
            safe = self.class.safe_conversions
            if (current[:type] != field[:type])
                if safe[current[:type]] && safe[current[:type]].include?(field[:type])
                    return true 
                else
                    return false
                end
            end
            return true if ((!current[:length] || current[:length] == 0) \
                            || (attributes[:length] && current[:length] <= attributes[:length])) && \
                           ((!current[:precision] || current[:precision] == 0) \
                           || (attributes[:precision] && current[:precision] <= attributes[:precision]))
            return false
        end
        
        # Shortens a DB name up to length.
        def shorten_identifier(name, length)
            while (name.length > length)
                parts = name.split('_')
                max = 0
                max_i = nil
                parts.each_index do |i|
                    if (parts[i].length > max)
                        max = parts[i].length
                        max_i = i
                    end
                end
                parts[max_i] = parts[max_i][0..-2]
                name = parts.join('_')
                name.gsub!('_+', '_')
            end
            return name
        end
        
        # Returns an array of the table names currently in the DB.
        def list_tables
            raise "Unimplemented"
        end
        
        # Returns a description of the table as currently present in the DB.
        def describe_table(table)
            raise "Unimplemented"
        end
        
        # Post processes column information retrieved from current DB.
        def parse_db_column(col)
            col
        end
        
        def dump(stream, tables=nil, options={})
            tables ||= list_tables
            options = ({
                :include_create => true
            }).merge(options)
            tables.each do |t|
                 Spider.logger.info("Dumping table #{t}")
                 begin
                     if options[:include_create]
                         create = get_table_create_sql(t)
                         stream << create
                         stream << "\n\n"
                     end
                     dump_table_data(t, stream)
                     stream << "\n\n"
                 rescue => exc
                     Spider.logger.error("Failed to dump table #{t}")
                     Spider.logger.error(exc.message)
                 end
             end
         end
        
        ##############################################################
        #   Aggregates                                               #
        ##############################################################
        
        def sql_max(max)
            values = []
            from_sql, from_values = sql_tables(max)
            values += from_values
            sql = "SELECT MAX(#{max[:field]}) AS M FROM #{from_sql}"
            if (max[:condition])
                condition_sql, condition_values = sql_condition(max)
                sql += " WHERE #{condition_sql}"
                values += condition_values
            end
            return sql, values
        end

        def collect_having_fields(condition)
            c = condition
            c.is_a?(Hash) ? 
                ((c[:group_by_fields] || []) + (c[:values] || []).map{ |v| collect_having_fields(v) }) : []
        end
        
        ##############################################################
        #   Reflection                                               #
        ##############################################################
            
            
        def reflect_column(table, column_name, column_attributes)
            column_type = column_attributes[:type]
            el_type = nil
            el_attributes = {}
            case column_type
            when 'TEXT'
                el_type = String
            when 'LONGTEXT'
                el_type = Text
            when 'INT'
                if (column_attributes[:length] == 1)
                    el_type = Spider::DataTypes::Bool
                else
                    el_type = Fixnum
                end
            when 'REAL'
                el_type = Float
            when 'DECIMAL'
                el_type = BigDecimal
            when 'DATE'
                el_type = DateTime
            when 'BLOB'
                el_type = Spider::DataTypes::Binary
            end
            return el_type, el_attributes
            
        end
            
        
    end
    
end; end; end; end
