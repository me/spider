module Spider; module Model
    
    # The ModelHash is a specialized hash for models. It is subclassed by Condition and Request.
    # It provides two functions: 
    # * when given a BaseModel instance as a value, it will unwrap it setting its element-value pairs
    # * if the key is a dotted string, will split it and create sub-hashes.
    # Example:
    #   cat = Cat.new(:name => 'Kitty', :color => 'black')
    #   mh[:test] = cat
    #     => {:test => {:name => 'Kitty', :color => 'black}}
    #   mh['test.name'] = 'Devilish Kitty'
    #     => {:test => {:name => 'Devilish Kitty', :color => 'black'}}
    class ModelHash < Hash
        # Original hash value assignment
        alias :modelhash_orig_set :[]=
        
        # @param [Hash] hash A Hash to get data from
        def initialize(hash=nil)
            super()
            merge!(hash) if (hash && hash.is_a?(Hash))
        end
        
        # Returns a new instance when needed by an assignement. May be overridden by subclasses.
        # @return [ModelHash]
        def get_deep_obj
            return self.class.new
        end
        
        # Value assignment
        # @param [String|Symbol|Element] key
        # @param [Object] value
        def []=(key, val)
            if (val.is_a?(BaseModel))
                n = self.class.new
                val.each_val do |el, v|
                    n[el] = v
                end
                val = n
            end
            key = key.name if key.is_a?(Element)
            if key.is_a?(String)
                parts = key.split('.', 2)
                return super(key.to_sym, val) unless parts[1]
                parts[0] = parts[0].to_sym
                self[parts[0]] = get_deep_obj unless self[parts[0]].is_a?(self.class)
                self[parts[0]][parts[1]] = val
            else
                super(key, val)
            end
        end
        
        # Value retrieval
        # @param [String|Symbol|Element] key
        def [](key)
            # TODO: deep
            key = key.name if key.is_a?(Element)
            super(key.to_sym)
        end
        
    end
    
end; end;