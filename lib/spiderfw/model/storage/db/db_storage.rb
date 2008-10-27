require 'spider/model/storage/base_storage'

module Spider; module Model; module Storage; module Db
    
    class DbStorage < Spider::Model::Storage::BaseStorage
        @reserved_keywords = ['from', 'order', 'where']
        def self.reserved_keywords
            @reserved_keywords
        end
        
        def initialize(url)
            
            super
        end
        
        def get_default_mapper(model)
            require 'spider/model/mappers/db_mapper'
            mapper = Spider::Model::Mappers::DbMapper.new(model, self)
            return mapper
        end
        
        ##############################################################
        #   Methods used to generate a schema                        #
        ##############################################################
        
        # Fixes a string to be used as a table name
        def table_name(name)
            return name.to_s.gsub(':', '_')
        end
        
        # Fixes a string to be used as a column name
        def column_name(name)
            name = name.to_s
            name += '_field' if (self.class.reserved_keywords.include?(name.downcase)) 
            return name
        end
        
        # Returns the db type corresponding to an element type
        def column_type(type)
            case type
            when 'text'
                'TEXT'
            when 'longText'
                'LONGTEXT'
            when 'int'
                'INT'
            when 'real'
                'REAL'
            when 'dateTime'
                'DATE'
            when 'binary'
                'BLOB'
            end
        end
        
        # Returns the attributes corresponding to element type and attributes
        def column_attributes(type, attributes)
            db_attributes = {}
            case type
            when 'text', 'longText'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            when 'real'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
                db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
            when 'binary'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            end
            return db_attributes
        end
            
            
        
    end
    
end; end; end; end