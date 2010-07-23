module Spider; module Model; module VFS
    
    module FlatFile
        
        
        
        def insert(obj)
        end
        
        def update(obj)
        end
        
        def s_insert(stream)
            
        end
        
        def s_update(stream)
        end
        
        def obj_file_name(obj)
            pk_string = obj.pk_string
            desc = obj.short_desc(self.class.file_name_max - pk_str.length - 4) # minus one just so.
            "#{pk_string)} - #{desc}"
        end
        
        def self.ls
            @model.all.map{ |obj| obj_file_name(obj) }
        end
        
        
    end