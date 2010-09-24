module Spider; module Servant; module Resources
    
    class Mysql < Db
       
        
        
        def create_db(name)
            return if db_exists?(name)
            sql = "create database #{name}"
            @storage.execute(sql)
        end
        
        def db_exists?(name)
            sql = "select schema_name from information_schema.schemata where schema_name = '#{name}'"
            res = @storage.execute(sql)
            return res[0] ? true : false
        end
        
        def add_user(name, password)
            sql = "create user '#{name}'@'localhost' identified by '#{password}'"
            @storage.execute(sql)
        end
        
        def grant_db_to_user(db_name, user)
            sql = "grant all on #{db_name}.* to '#{user}'@'localhost'"
            @storage.execute(sql)
        end
        
        def self.discovery(ip)
            
        end
        
    end
    
end; end; end