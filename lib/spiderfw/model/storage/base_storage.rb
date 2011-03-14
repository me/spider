require 'spiderfw/model/storage/connection_pool'

module Spider; module Model; module Storage
    
    class BaseStorage
        include Spider::Logger
        attr_reader :url
        attr_accessor :instance_name
        
        @capabilities = {
            
        }
        
        class << self
            # An Hash of storage capabilities. The default for db storages is 
            # {:autoincrement => false, :sequences => true, :transactions => true}
            # (The BaseStorage class provides file sequences in case the subclass does not support them.)
            attr_reader :capabilities
            
            def storage_type
                :none
            end
            
            def sequence_sync
                @sequence_sync ||= ::Sync.new
            end

            def base_types
                Model.base_types
            end
            
            # True if given named capability is supported by the Storage.
            def supports?(capability)
                @capabilities[capability]
            end
            
            # Returns a new connection. Must be implemented by the subclasses; args are implementation specific.
            def new_connection(*args)
                raise "Unimplemented"
            end

            def max_connections
                nil
            end

            def connection_pools
                @pools ||= {}
            end

            def get_connection(*args)
                @pools ||= {}
                @pools[args] ||= ConnectionPool.new(args, self)
                @pools[args].get_connection
            end

            # Frees a connection, relasing it to the pool
            def release_connection(conn, conn_params)
                return unless conn
                return unless @pools && @pools[conn_params]
                @pools[conn_params].release(conn)
            end

            # Removes a connection from the pool.
            def remove_connection(conn, conn_params)
                return unless conn
                return unless @pools && @pools[conn_params]
                @pools[conn_params].remove(conn)
            end

            def disconnect(conn)
                raise "Virtual"
            end

            # Checks whether a connection is still alive. Must be implemented by subclasses.
            def connection_alive?(conn)
                raise "Virtual"
            end

            def inherited(subclass)
                subclass.instance_variable_set("@capabilities", @capabilities)
            end
            
        end
        
        
        def initialize(url)
            @url = url
            @configuration = {}
            parse_url(url)
        end
        
        def configure(conf)
            @configuration.merge!(conf.to_hash)
        end
        
        def parse_url(url)
            raise StorageException, "Unimplemented"
        end
        
        def get_mapper(model)
            raise StorageException, "Unimplemented"
        end
        
        def supports?(capability)
            self.class.supports?(capability)
        end
        
        def curr
            var = nil
            if Spider.conf.get('storage.shared_connection')
                $STORAGES ||= {}
                var = $STORAGES
            else
                var = Thread.current
            end
            var[:storages] ||= {}
            var[:storages][self.class.storage_type] ||= {}
            var[:storages][self.class.storage_type][@connection_params] ||= {
                :transaction_nesting => 0, :savepoints => []
            }
        end
        
        def connection_pool
            self.class.connection_pools[@connection_params]
        end
        
        # Instantiates a new connection with current connection params.
        def connect
            return self.class.get_connection(*@connection_params)
            #Spider::Logger.debug("#{self.class.name} in thread #{Thread.current} acquired connection #{@conn}")
        end
        
        # True if currently connected.
        def connected?
            curr[:conn] != nil
        end

        
        # Returns the current connection, or creates a new one.
        # If a block is given, will release the connection after yielding.
        def connection
            curr[:conn] = connect
            if block_given?
                yield curr[:conn]
                release # unless is_connected
                return true
            else
                return curr[:conn]
            end
        end
        
        def self.connection_attributes
            @connection_attributes ||= {}
        end
        
        def connection_attributes
            self.class.connection_attributes[connection] ||= {}
        end
        
        # Releases the current connection to the pool.
        def release
            # The subclass should check if the connection is alive, and if it is not call remove_connection instead
            c = curr[:conn]
            #Spider.logger.debug("#{self} in thread #{Thread.current} releasing #{curr[:conn]}")
            curr[:conn] = nil
            self.class.release_connection(c, @connection_params)
            #Spider.logger.debug("#{self} in thread #{Thread.current} released #{curr[:conn]}")
            return nil
            #@conn = nil
        end
        
        # Prepares a value for saving.
        def value_for_save(type, value, save_mode)
            return prepare_value(type, value)
        end
        
        # Prepares a value that will be used in a condition.
        def value_for_condition(type, value)
            return prepare_value(type, value)
        end
        
        
        def prepare_value(type, value)
            return value
        end
        
        def ==(storage)
            return false unless self.class == storage.class
            return false unless self.url == storage.url
            return true
        end
        
        
        def supports_transactions?
            return self.class.supports?(:transactions)
        end
        
        def transactions_enabled?
            @configuration['enable_transactions'] && supports_transactions?
        end
        
        def start_transaction
            return unless transactions_enabled?
            curr[:transaction_nesting] += 1
            return savepoint("point#{curr[:savepoints].length}") if in_transaction?
        
            Spider.logger.debug("#{self.class.name} starting transaction for connection #{connection.object_id}")
            do_start_transaction
            return true
        end
        
        # May be implemented by subclasses.
        def do_start_transaction
           raise StorageException, "The current storage does not support transactions" 
        end
        
        def in_transaction
            if in_transaction?
                curr[:transaction_nesting] += 1
                return true
            else
                start_transaction
                return false
            end
        end
        
        def in_transaction?
            return false
        end
        
        
        def commit
            return false unless transactions_enabled?
            raise StorageException, "Commit without a transaction" unless in_transaction?
            return curr[:savepoints].pop unless curr[:savepoints].empty?
            commit!
        end
        
        def commit_or_continue
            return false unless transactions_enabled?
            raise StorageException, "Commit without a transaction" unless in_transaction?
            if curr[:transaction_nesting] == 1
                commit
                curr[:transaction_nesting] = 0
                return true
            else
                curr[:transaction_nesting] -= 1
            end
        end
        
        def commit!
            Spider.logger.debug("#{self.class.name} commit connection #{curr[:conn].object_id}")
            curr[:transaction_nesting] = 0
            do_commit
            release
        end
        
        def do_commit
            raise StorageException, "The current storage does not support transactions" 
        end
        
        def rollback
            raise "Can't rollback in a nested transaction" if curr[:transaction_nesting] > 1
            return rollback_savepoint(curr[:savepoints].last) unless curr[:savepoints].empty?
            rollback!
        end
        
        def rollback!
            curr[:transaction_nesting] = 0
            Spider.logger.debug("#{self.class.name} rollback")
            do_rollback
            curr[:savepoints] = []
            release
        end
        
        def do_rollback
            raise StorageException, "The current storage does not support transactions" 
        end
        
        def savepoint(name)
            curr[:savepoints] << name
        end
        
        def rollback_savepoint(name=nil)
            if name
                curr[:savepoints] = curr[:savepoints][0,(curr[:savepoints].index(name))]
                name
            else
                curr[:savepoints].pop
            end
        end
        
        # Utility methods
        
        def sequence_file_path(name)
            path = 'var/sequences/'+name
            return path
        end
        
        def sequence_exists?(name)
            File.exist?(sequence_file_path(name))
        end
        
        def create_sequence(name, start=1, increment=1)
            sequence_next(name, start-1, increment)
        end
        
        def generate_uuid
            Spider::DataTypes::UUID.generate
        end
            
        
        def update_sequence(name, val)
            # not an alias because the set value behaviour of next_sequence isn't expected in subclasses
            sequence_next(name, val)
        end
        
        # Increments a named sequence and returns the new value
        def sequence_next(name, newval=nil, increment=1)
            path = sequence_file_path(name)
            FileUtils.mkpath(File.dirname(path))
            self.class.sequence_sync.lock(::Sync::EX)
            if newval
                seq = newval
            else
                seq = 0
                File.open(path, 'a+') do |f|
                    f.rewind
                    f.flock File::LOCK_EX
                    cur = f.gets
                    if (cur)
                        seq, increment_str = cur.split('|')
                    else
                        seq, increment_str = 0, 1
                    end
                    seq = seq.to_i
                    increment = increment_str.to_i if increment_str
                    f.close
                end
                seq += increment
            end
            File.open(path, 'w+') do |f|
                f.print(seq)
                f.print("|#{increment}") if (increment != 1)
                f.flock File::LOCK_UN
                f.close
            end
            self.class.sequence_sync.lock(::Sync::UN)
            return seq
        end
        
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class StorageException < RuntimeError
    end
    
    
    
end; end; end
