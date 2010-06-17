module Spider; module Model; module Storage
    
    module Db
        module Connectors
        end
        
    end
    
    Db.autoload(:DbSchema, 'spiderfw/model/storage/db/db_schema')
    Db.autoload(:SQLite, 'spiderfw/model/storage/db/adapters/sqlite')
    Db.autoload(:Oracle, 'spiderfw/model/storage/db/adapters/oracle')
    Db.autoload(:Mysql, 'spiderfw/model/storage/db/adapters/mysql')
    Db.autoload(:MSSQL, 'spiderfw/model/storage/db/adapters/mssql')
    Db::Connectors.autoload(:ODBC, 'spiderfw/model/storage/db/connectors/odbc')
    Db::Connectors.autoload(:OCI8, 'spiderfw/model/storage/db/connectors/oci8')
    Db::Connectors.autoload(:JDBCOracle, 'spiderfw/model/storage/db/connectors/jdbc_oracle')
    
end; end; end