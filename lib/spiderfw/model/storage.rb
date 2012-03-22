#require 'spiderfw/model/storage/db/connectors/odbc'

module Spider; module Model

    # The namespace for classes related to storage.
    # 
    # See {BaseStorage}.
    module Storage
        
        
        # Returns an instance of a BaseStorage subclass, according to type and type-specific url
        # @param [String] type The type of storage. Can be 'db' (for DataBase storages),
        #                      'doc' (for Document storages), or 'stub' (for a Test stub).
        # @param [String] url  A connection url, specific to the storage.
        def self.get_storage(type, url)
            Thread.current[:storages] ||= {}
            Thread.current[:storages][type] ||= {}
            return Thread.current[:storages][type][url] if Thread.current[:storages][type][url]
            klass = nil
            begin
                matches = url.match(/^(.+?):\/\/(.+)/)
                adapter = matches[1]
                rest = matches[2]
            rescue => exc
                Spider.output _("The connection string %s is not correct") % url, :error
            end
            if adapter =~ /(.+):(.+)/
                connector = $1
                adapter = $2
                url = "#{adapter}://#{rest}"
            end
            case type
            when 'db' 
                class_name = case adapter
                when 'sqlite'
                    :SQLite
                when 'oci8', 'oracle'
                    :Oracle
                when 'mysql'
                    :Mysql
                when 'mssql'
                    :MSSQL
                end
                klass = Db.const_get(class_name)
                unless connector
                    connector = case adapter
                    when 'oci8', 'oracle'
                        RUBY_PLATFORM =~ /java/ ? 'jdbc' : 'oci8'
                    end
                end
                if connector
                    conn_mod_name = case connector
                    when 'odbc'
                        :ODBC
                    when 'jdbc'
                        :JDBC
                    when 'oci8'
                        :OCI8
                    end
                    full_name = "#{conn_mod_name}#{class_name}"
                    if Db.const_defined?(full_name)
                        klass = Db.const_get(full_name)
                    else
                        conn_mod = Db::Connectors.const_defined?(full_name) ? Db::Connectors.const_get(full_name) : Db::Connectors.const_get(conn_mod_name)
                        klass = Db.const_set(full_name, Class.new(klass))
                        klass.instance_eval{ include conn_mod }
                    end
                end
            when 'doc'
                class_name = case adapter
                when 'mongodb'
                    :Mongodb
                end
                klass = Spider::Model::Storage::Document.const_get(class_name)
            when 'stub'
                require 'spiderfw/test/stubs/storage_stub'
                klass = Spider::Test::StorageStub
            end
            return nil unless klass
            Thread.current[:storages][type][url] = klass.new(url)
            return Thread.current[:storages][type][url]
        end
        
        module StorageResult
            attr_accessor :total_rows
            
        end
        
        class StorageException < RuntimeError
        end
        
        class DuplicateKey < StorageException
        end
        
        ###############################
        #   Autoload                  #
        ###############################
        
        Storage.autoload(:Db, 'spiderfw/model/storage/db/db')
                
    end
    
end; end

require 'spiderfw/model/storage/db/db'
require 'spiderfw/model/storage/document/document'
