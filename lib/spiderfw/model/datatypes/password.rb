require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'

module Spider; module DataTypes
    
    Spider.config_option('password.salt', 'Salt to use for passwords')
    Spider.config_option('password.hash', 'Hash function to use for passwords', :default => :sha2,
        :type => Symbol, :choices => [:md5, :sha1, :sha2]
    )
    
    # A hashed password.
    # Takes :hash attribute (defaults to 'password.hash' configuration value, which in turn defaults to :sha2) and
    # :salt attribute; the default is to generate a random salt when mapping (unless 'password.salt' configuration is provided).
    # Maps to a "#{hash_type}$#{salt}$#{hash}" string
    #--
    # TODO: remove salt configuration

    class Password < String
        include DataType
        
        take_attributes :hash, :salt
        
        def map(mapper_type)
            salt = attributes[:salt] || Spider.conf.get('password.salt')
            # TODO: better salts
            salt ||= (0..10).inject('') { |r, i| r << rand(89) + 37 }
            hash_type = attributes[:hash] || Spider.conf.get('password.hash')
            return "#{hash_type}$#{salt}$#{self.class.do_hash(hash_type, self.to_s, salt)}"
        end
        
        # Checks if a password matches with a stored representation.
        # Expects a stored string in the form "#{hash_type}$#{salt}$#{hash}": otherwise,
        # it will assume the string is a hash using the Spider.conf 'password.hash' and 'password.salt'
        def self.check_match(stored, pwd)
            hash_type, salt, hash = stored.split('$')
            if (!salt)
                return stored == do_hash(Spider.conf.get('password.hash'), pwd,  Spider.conf.get('password.salt'))
            end
            return (hash == do_hash(hash_type, pwd, salt))
        end
        
        # Returns a hash of given type, using given salt
        def self.do_hash(type, str, salt='')
            salt ||= ''
            case type.to_sym
            when :md5
                hash_obj = Digest::MD5.new
            when :sha1
                hash_obj = Digest::SHA1.new
            when :sha2
                hash_obj = Digest::SHA2.new
            else
                raise ArgumentError, "Hash function #{type} is not supported"
            end
            hash_obj.update(str+salt)
            return hash_obj.hexdigest
        end

    end
    
    
end; end