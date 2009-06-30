module Spider; module DataTypes
    
    class Email < DataType
        maps_to 'text'
        
        def self.check(val)
            raise FormatError, _("%s is not a valid e-mail address") % val unless /\A[\w\._%-]+@[\w\.-]+\.[a-zA-Z]{2,4}\z/
        end
        
        
    end
    
end; end