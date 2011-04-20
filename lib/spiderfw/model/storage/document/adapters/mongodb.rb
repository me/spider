require 'spiderfw/model/storage/document/document_storage'
require 'mongo'

module Spider; module Model; module Storage; module Document
    
    class Mongodb < DocumentStorage
        CONDITION_OPS = {
            '>' => '$gt', '<' => '$lt', '>=' => '$gte', '<=' => '$lte', 'not' => '$e', '<>' => '$ne'
        }
        
        def self.parse_url(url)
            # doc:mongodb://<username:password>@<host>:<port>/<database>
            if (url =~ /.+:\/\/(?:(.+):(.+)@)?(.+)?\/(.+)/)
                user = $1
                pass = $2
                location = $3
                db_name = $4
            else
                raise ArgumentError, "Mongodb url '#{url}' is invalid"
            end
            location =~ /(.+)(?::(\d+))/
            host = $1
            port = $2
            return [host, user, pass, db_name, port]
        end
        
        def parse_url(url)
            @host, @user, @pass, @db_name, @port = self.class.parse_url(url)
            @connection_params = [@host, @user, @pass, @db_name, @port]
        end
        
        def self.new_connection(host=nil, user=nil, passwd=nil, db=nil, port=nil)
            conn = ::Mongo::Connection.new(host, port)
            conn.authenticate(user, passwd) if user
            return conn
        end
        
        def self.disconnect(conn)
            conn.close
        end
        
        def self.connection_alive?(conn)
            conn.connected?
        end
        
        def connect
            conn = super
            curr[:db] = conn.db(@connection_params[3])
            conn
        end
        
        def release
            curr[:db] = nil
            super
        end
                
        def db
            connection
            curr[:db]
        end
        
        def collection(coll)
            db.collection(coll)
        end
        
        def insert(collection, doc)
            Spider.logger.debug("Mongodb insert #{collection}:")
            Spider.logger.debug(doc)
            begin
                collection(collection).insert(doc)
            ensure
                release
            end
        end
        
        def update(collection, selector, vals)
            Spider.logger.debug("Mongodb update #{collection}, #{selector.inspect}:")
            Spider.logger.debug(vals)
            begin
                collection(collection).update(selector, {'$set' => vals})
            ensure
                release
            end
        end
        
        def delete(collection, doc)
            begin
                collection(collection).remove({"_id" => doc["_id"]}, doc)
            ensure
                release
            end
        end
        
        def prepare_value(type, value)
            return value if value.nil?
            case type.name
            when 'Time'
                value = value.utc
            when 'DateTime'
                value = value.to_local_time.utc.to_time
            when 'Date'
                value = value.to_gm_time.utc
            when 'BigDecimal'
                # FIXME: should multiply on value.attributes[:scale] and store an integer, converting it back on load
                value = value.to_f
            end
            value 
        end
        
        def value_to_mapper(type, value)
            if value.class == Time
                if type.name == 'Date'
                    value = value.to_date
                elsif type.name == 'DateTime'
                    value = value.to_datetime
                end
                return value
            elsif type.name == 'Fixnum'
                return value.to_i
            end
            return super
        end
        
        def find(collection, condition, request, options)
            options[:fields] = request
            Spider.logger.debug("Mongodb find #{collection}, #{condition.inspect}")
            begin
                res = collection(collection).find(condition, options).to_a
            ensure
                release
            end
            res = res.map{ |row| keys_to_symbols(row) }
            res.extend(StorageResult)
            res.total_rows = res.length # FIXME
            res
        end
                
        def keys_to_symbols(h)
            sh = {}
            h.each do |k, v|
                v = if v.is_a?(Hash)
                    keys_to_symbols(v)
                elsif v.is_a?(Array)
                    v.map{ |row| keys_to_symbols(row) }
                else
                    v
                end
                #name = k == "_id" ? :id : k.to_sym
                name = k.to_sym
                sh[name] = v
            end
            sh
        end
        
        def drop_db!
            conn = connection
            begin
                conn.drop_database(@db_name)
            ensure
                release
            end
        end
        
        def generate_pk
            ::BSON::ObjectId.new
        end
        
        # Mapper extension
         
         module MapperExtension
        
             def prepare_condition(condition)
                 cond_hash = {}
                 pks = []
                 condition.each_with_comparison do |k, v, comp|
                     element = model.elements[k.to_sym]
                     name = nil
                     if element.primary_key?
                         if @model.primary_keys.length == 1
                             name = '_id'
                         else
                             raise "Mongo conditions for multiple primary keys are not supported yet"
                         end
                     else
                         name = element.name.to_s
                     end
                     #next unless model.mapper.mapped?(element)
                     if element.model?
                         if element.attributes[:embedded]
                             # TODO
                         else
                             pks = []
                             element.model.primary_keys.each do |ek|
                                 kv = v[ek.name]
                                 raise "Document mapper can't join #{element.name}: condition #{condition}" unless kv
                                 pks << element.mapper.map_condition_value(ek.type, kv)
                             end
                             hash_v = element.model.keys_string(pks)
                             hash_v = {Mongodb::CONDITION_OPS[comp] => hash_v} unless comp == '='
                             cond_hash[name] = hash_v
                         end
                     else
                         hash_v = map_condition_value(element.type, v)
                         comp ||= '='
                         if comp != '='
                             if comp == 'like' || comp == 'ilike'
                                 options = comp == 'ilike' ? Regexp::IGNORECASE : nil
                                 parts = hash_v.split('%')
                                 parts << "" if hash_v[-1].chr == '%'
                                 re_str = parts.map{ |p| p.blank? ? '' : Regexp.quote(p)}.join('.+') 
                                 hash_v = Regexp.new(re_str, options)
                             else
                                 hash_v = {Mongodb::CONDITION_OPS[comp] => hash_v}
                             end
                         end
                         cond_hash[name] = hash_v
                     end
                 end
                 or_conds = []
                 or_conds << cond_hash if condition.conjunction == :or && condition.subconditions.length > 0
                 condition.subconditions.each do |sub|
                     sub_res = self.prepare_condition(sub)
                     if condition.conjunction == :and
                         cond_hash.merge!(sub_res)
                     elsif condition.conjunction == :or
                         or_conds << sub_res
                     end
                 end
                 unless or_conds.empty?
                     cond_hash = { '$or' => or_conds }
                 end
                 cond_hash
             end
             
             def prepare_request(request)
                 h = {}
                 request.each do |k, v|
                     element = @model.elements[k.to_sym]
                     next unless element
                     name = element.primary_key? ? '_id' : element.name.to_s
                     if v.is_a?(Spider::Model::Request)
                         sub = prepare_request(v)
                         sub.each do |sk, sv|
                             h["#{name}.#{sk}"] = sv
                         end
                     else
                         h[name] = 1
                     end
                 end
                 h
             end
             
             def fetch(query)
                 condition = prepare_condition(query.condition)
                 request = prepare_request(query.request)
                 options = {}
                 options[:limit] = query.limit if query.limit
                 options[:skip] = query.offset if query.offset
                 if query.order
                     order_array = []
                     query.order.each do |order|
                         order_element, direction = order
                         dir_str = direction == :desc ? 'descending' : 'ascending'
                         order_array << [order_element.to_s, dir_str]
                     end
                     options[:sort] = order_array unless order_array.empty?
                 end
                 res = storage.find(@model.name, condition, request, options)
                 r = res.map{ |row| postprocess_result(row) }
                 r.extend(Storage::StorageResult) # FIXME: avoid doing this twice
                 r.total_rows = res.total_rows
                 r
             end
             
             def postprocess_result(h, model=nil)
                 model ||= @model
                 sh = {}
                 h.each do |k, v|
                     if k == :_id
                         pks = model.split_keys_string(v)
                         model.primary_keys.each_with_index do |pk, i|
                             pkval = pks[i]
                             pkval = storage_value_to_mapper(pk.type, pkval)
                             sh[pk.name] = pks[i]
                         end
                     else
                         el = model.elements[k]
                         v = if v.is_a?(Hash)
                             postprocess_result(v, el.model)
                         elsif v.is_a?(Array)
                             v.map{ |row| postprocess_result(row, el.model) }
                         else
                             v
                         end
                         sh[k] = v
                     end
                 end
                 sh
             end
             

             
         end
        
    end
    
end; end; end; end
