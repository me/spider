module Spider; module Model; module Storage
    
    module Db
        
    end
    
    Db.autoload(:DbSchema, 'spider/model/storage/db/db_schema')
    Db.autoload(:SQLite, 'spider/model/storage/db/adapters/sqlite')
    
end; end; end