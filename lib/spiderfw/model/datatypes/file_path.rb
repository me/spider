require 'pathname'

module Spider; module DataTypes
    
    class FilePath < ::Pathname
        include DataType
        maps_to String
        
        take_attributes :base_path, :uploadable
        
        def self.from_value(value)
            return nil if value.to_s.empty?
            super
        end
        
        def map(mapper_type)
            val = nil
            if attributes[:base_path]
                begin
                    val = self.relative_path_from(Pathname.new(attributes[:base_path]))
                rescue ArgumentError
                    val = self
                end
            else
                val = self
            end
            val.to_s
        end
        
        def prepare
            if attributes[:base_path]
                self.new(Pathname.new(attributes[:base_path]) + self)
            else
                self
            end
        end
        
        def format(format_type = :normal)
            return super unless attributes[:base_path]
            if format_type == :long || format_type == :full
                self.to_s
            else
                self.relative_path_from(Pathname.new(attributes[:base_path])).to_s
            end
        end
        
        
    end
    
end; end