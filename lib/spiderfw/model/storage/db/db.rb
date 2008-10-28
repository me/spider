module Spider; module Model; module Storage
    
    module Db
        
    end
    
    Db.autoload(:DbSchema, 'spiderfw/model/storage/db/db_schema')
    Db.autoload(:SQLite, 'spiderfw/model/storage/db/adapters/sqlite')
    
end; end; end