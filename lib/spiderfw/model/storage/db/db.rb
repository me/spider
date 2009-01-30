module Spider; module Model; module Storage
    
    module Db
        
    end
    
    Db.autoload(:DbSchema, 'spiderfw/model/storage/db/db_schema')
    Db.autoload(:SQLite, 'spiderfw/model/storage/db/adapters/sqlite')
    Db.autoload(:OCI8, 'spiderfw/model/storage/db/adapters/oci8')
    Db.autoload(:Mysql, 'spiderfw/model/storage/db/adapters/mysql')
    
end; end; end