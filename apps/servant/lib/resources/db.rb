require 'spiderfw'

module Spider; module Servant; module Resources
    
    class Db < Resource
        
        def self.get_resource(url)
            matches = url.match(/^(.+?):\/\/(.+)/)
            adapter = matches[1]
            rest = matches[2]
            if (adapter =~ /(.+):(.+)/)
                connector = $1
                adapter = $2
                url = "#{adapter}://#{rest}"
            end
            case adapter
            when 'sqlite'
                class_name = :SQLite
            when 'oci8'
                class_name = :OCI8
            when 'mysql'
                class_name = :Mysql
            when 'mssql'
                class_name = :MSSQL
            end
            return Resources.const_get(class_name).new(url)
        end
        
        def initialize(url)
            @storage = Spider::Model::Storage.get_storage('db', url)
        end
        
        # __.command :name => _('Create Db'), :params => [:name => String]
        def create_db(name)
            raise "Unimplemented"
        end
        
        def db_exists?(name)
            raise "Unimplemented"
        end
        
        def add_user(name, password)
            raise "Unimplemented"
        end
        
        def grant_db_to_user(db_name, user)
            raise "Unimplemented"
        end
        
        def resource_type
            :db
        end
    end
    
end; end; end