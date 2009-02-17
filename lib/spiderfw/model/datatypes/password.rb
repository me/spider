require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'

module Spider; module DataTypes
    
    Spider.config_option('password.salt', 'Salt to use for passwords')
    Spider.config_option('password.hash', 'Hash function to use for passwords', :default => :sha2,
        :type => Symbol, :choices => [:md5, :sha1, :sha2]
    )

    class Password < DataType
        maps_to String
        take_attributes :hash, :salt
        
        def map(mapper_type)
            @val ||= ''
            salt = attributes[:salt] || Spider.conf.get('password.salt')
            salt ||= ''
            hash_type = attributes[:hash] || Spider.conf.get('password.hash')
            case hash_type
            when :md5
                hash_obj = Digest::MD5.new
            when :sha1
                hash_obj = Digest::SHA1.new
            when :sha2
                hash_obj = Digest::SHA2.new
            else
                raise ArgumentError, "Hash function #{hash_type} is not supported"
            end
            hash_obj.update(@val+salt)
            return hash_obj.hexdigest
        end
        

    end
    
    
end; end