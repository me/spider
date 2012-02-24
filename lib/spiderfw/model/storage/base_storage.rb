require 'spiderfw/model/storage/connection_pool'

module Spider; module Model; module Storage
    
    # @abstract
    # This class is subclassed by classes that interact with different storage backends.
    # See also {Db::DbStorage}, {Document::DocumentStorage}.
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
            # @return [Hash]
            attr_reader :capabilities
            
            # @return [Symbol] A label for the storage's class.            
            def storage_type
                :none
            end
            
            # @return [Sync] A Sync object to use for sequences
            def sequence_sync
                @sequence_sync ||= ::Sync.new
            end

            # @return [Array] Base types supported by the backend.
            def base_types
                Model.base_types
            end
            
            # @return [bool] True if given named capability is supported by the backend.
            def supports?(capability)
                @capabilities[capability]
            end
            
            # @abstract
            # @return [Object] Returns a new connection. Must be implemented by the subclasses; args are implementation specific.
            def new_connection(*args)
                raise "Unimplemented"
            end

            # @abstract
            # @return [Fixnum|nil] Maximum number of connections possible for this backend (or nil if unlimited)
            def max_connections
                nil
            end

            # @return [Hash] An Hash of connection pools for each backend.
            def connection_pools
                @pools ||= {}
            end

            # @param [*args] Storage specific arguments
            # @return [Object] Retrieves a native connection to the backend from the {ConnectionPool}.
            def get_connection(*args)
                @pools ||= {}
                @pools[args] ||= ConnectionPool.new(args, self)
                @pools[args].get_connection
            end

            # Frees a connection, relasing it to the pool
            # @param [Object] conn The connection
            # @param [Array] conn_params An array of connection params that were used to create the connection.
            # @return [void]
            def release_connection(conn, conn_params)
                return unless conn
                return unless @pools && @pools[conn_params]
                @pools[conn_params].release(conn)
            end

            # Removes a connection from the pool.
            # @param [Object] conn The connection
            # @param [Array] conn_params An array of connection params that were used to create the connection.
            # @return [void]
            def remove_connection(conn, conn_params)
                return unless conn
                return unless @pools && @pools[conn_params]
                @pools[conn_params].remove(conn)
            end

            # @abstract
            # Closes the native connection to the backend.
            # @param [Object] conn The native connection
            # @return [void]
            def disconnect(conn)
                raise "Virtual"
            end

            # @abstract
            # Checks whether a connection is still alive. Must be implemented by subclasses.
            # @param [Object] conn The native connection
            # @return [void]
            def connection_alive?(conn)
                raise "Virtual"
            end

            # Copies capabilities on subclasses
            # @param [Class<BaseStorage] subclass
            # @return [void]
            def inherited(subclass)
                subclass.instance_variable_set("@capabilities", @capabilities)
            end
            
        end
        
        # Creates a new storage instance.
        # @param [String] url The backend-specific url for the connection
        def initialize(url)
            @url = url
            @configuration = {}
            parse_url(url)
        end
        
        # Sets configuration for the Storage
        # @param [Hash] conf The configuration
        # @return [void]
        def configure(conf)
            @configuration.merge!(conf.to_hash)
        end
        
        # @abstract
        # Splits a backend-specific connection url into parts
        # @param [String] url
        # @return [Array]
        def parse_url(url)
            raise StorageException, "Unimplemented"
        end
        
        # @abstact
        # @param [Class<BaseModel]
        # @return [Mapper] Returns the instance of a mapper for the storage and the given model
        def get_mapper(model)
            raise StorageException, "Unimplemented"
        end
        
        # @param [Symbol] capability
        # @return [bool] True if the backend supports the given capability
        def supports?(capability)
            self.class.supports?(capability)
        end
        
        # @return [Hash] An hash of thread-local values for this connection
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
        
        # @return [ConnectionPool|nil] The ConnectionPool managing the current connection params
        def connection_pool
            self.class.connection_pools[@connection_params]
        end
        
        # Instantiates a new connection with current connection params.
        # @return [void]
        def connect
            return self.class.get_connection(*@connection_params)
            #Spider::Logger.debug("#{self.class.name} in thread #{Thread.current} acquired connection #{@conn}")
        end
        
        # @return [bool] True if currently connected.
        def connected?
            curr[:conn] != nil
        end

        
        # Returns the current connection, or creates a new one.
        # If a block is given, will release the connection after yielding.
        # @yield [Object] If a block is given, it is passed the connection, which is released after the block ends.
        # @return [Object] The connection
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
        
        # @return [Hash] current connection attributes
        def self.connection_attributes
            @connection_attributes ||= {}
        end
        
        # @return [Hash] current connection attributes
        def connection_attributes
            self.class.connection_attributes[connection] ||= {}
        end
        
        # Releases the current connection to the pool.
        # @return [void]
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
        
        # Prepares a value which will be saved into the backend.
        # @param [Class] type
        # @param [Object] value 
        # @param [Symbol] save_mode :insert or :update or generic :save
        # @return [Object] The prepared value
        def value_for_save(type, value, save_mode)
            return prepare_value(type, value)
        end
        
        # Prepares a value that will be used in a condition on the backend.
        # @param [Class] type
        # @param [Object] value
        # @return [Object] The prepared value
        def value_for_condition(type, value)
            return prepare_value(type, value)
        end
        
        # Prepares a value coming from the backend for the mapper
        # @param [Class] type
        # @param [Object] value
        # @return [Object] The prepared value
        def value_to_mapper(type, value)
            value
        end
        
        # Prepares a value that will be used by the backend (see also {#value_for_save} and {#value_for_condition},
        # which by default call this method, but can be override to do more specific processiong).
        # @param [Class] type
        # @param [Object] value
        # @return [Object] The prepared value
        def prepare_value(type, value)
            return value
        end
        
        # @return [bool] True if the other storage is of the same class, and has the same connection url
        def ==(storage)
            return false unless self.class == storage.class
            return false unless self.url == storage.url
            return true
        end
        
        # @return [bool] True if the backend support stransaction
        def supports_transactions?
            return self.class.supports?(:transactions)
        end
        
        # @return [bool] True if transactions are supported by the backend and enabled in the storage's configuration.
        def transactions_enabled?
            @configuration['enable_transactions'] && supports_transactions?
        end
        
        # Starts a new transaction on the backend
        # @return [bool] True if a new transaction was started, false otherwise
        def start_transaction
            return unless transactions_enabled?
            curr[:transaction_nesting] += 1
            return savepoint("point#{curr[:savepoints].length}") if in_transaction?
        
            Spider.logger.debug("#{self.class.name} starting transaction for connection #{connection.object_id}")
            do_start_transaction
            return true
        end
        
        # @abstract
        # Implemented by subclasses to interact with the backend
        def do_start_transaction
           raise StorageException, "The current storage does not support transactions" 
        end
        
        # Starts a transaction, or increases transaction nesting.
        # @return [bool] True if a transaction was already active, false otherwise
        def in_transaction
            if in_transaction?
                curr[:transaction_nesting] += 1
                return true
            else
                start_transaction
                return false
            end
        end
        
        # @return [bool] True if a transaction is currently active
        def in_transaction?
            return false
        end
        
        
        # Commits the current transaction
        # @return [bool] True if the transaction was successfully committed, false if transactions are not enabled
        #                (Raises a StorageException if transactions are supported but were not started)
        def commit
            return false unless transactions_enabled?
            raise StorageException, "Commit without a transaction" unless in_transaction?
            return curr[:savepoints].pop unless curr[:savepoints].empty?
            commit!
        end
        
        # Commits the current transaction, or decreases transaction nesting.
        # @return [bool] True if the transaction was successfully committed, false if transactions are not enabled
        #                (Raises a StorageException if transactions are supported but were not started)
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
        
        # Commits current transaction, resets transaction nesting, and releases the connection.
        # @return [void]
        def commit!
            Spider.logger.debug("#{self.class.name} commit connection #{curr[:conn].object_id}")
            curr[:transaction_nesting] = 0
            do_commit
            release
        end
        
        # @abstract
        # Implemented by subclasses to interact with the backend
        # @return [void]
        def do_commit
            raise StorageException, "The current storage does not support transactions" 
        end
        
        # Rolls back the current transaction. Raises an error if in a nested transaction.
        # @return [void]
        def rollback
            raise "Can't rollback in a nested transaction" if curr[:transaction_nesting] > 1
            return rollback_savepoint(curr[:savepoints].last) unless curr[:savepoints].empty?
            rollback!
        end
        
        # Rolls back the current transaction, regardless of transaction nesting, and releases the connection
        # @return [void]
        def rollback!
            curr[:transaction_nesting] = 0
            Spider.logger.debug("#{self.class.name} rollback")
            do_rollback
            curr[:savepoints] = []
            release
        end
        
        # @abstract
        # Implemented by subclasses to interact with the backend
        # @return [void]
        def do_rollback
            raise StorageException, "The current storage does not support transactions" 
        end
        
        # Creates a new savepoint
        # @param [String] name
        # @return [void]
        def savepoint(name)
            curr[:savepoints] << name
        end
        
        # Rolls back a savepoint
        # @param [String] name
        # @return [void]
        def rollback_savepoint(name=nil)
            if name
                curr[:savepoints] = curr[:savepoints][0,(curr[:savepoints].index(name))]
                name
            else
                curr[:savepoints].pop
            end
        end
        
        # Utility methods
        
        # @param [String] name Sequence name
        # @return [String] Path to the sequence file
        def sequence_file_path(name)
            path = File.join(Spider.paths[:var], 'sequences', name)
            return path
        end
        
        # @param [String] name Sequence name
        # @return [bool] True if the sequence file exists
        def sequence_exists?(name)
            File.exist?(sequence_file_path(name))
        end
        
        # Creates a new sequence
        # @param [String] name Sequence name
        # @param [Fixnum] start
        # @param [Fixnum] increment
        # @return [void]
        def create_sequence(name, start=1, increment=1)
            sequence_next(name, start-1, increment)
        end
        
        # @return [String] A new UUID
        def generate_uuid
            Spider::DataTypes::UUID.generate
        end
            
        # Updates a sequence
        # @param [String] name Sequence name
        # @param [Fixnum] val New value for the sequence
        # @return [Fixnum] New value for the sequence
        def update_sequence(name, val)
            # not an alias because the set value behaviour of next_sequence isn't expected in subclasses
            sequence_next(name, val)
        end
        
        # Increments a named sequence and returns the new value
        # @param [String] name Sequence name
        # @param [Fixnum] newval New value for the sequence
        # @param [Fixnum] increment
        # @return [Fixnum] New value for the sequence
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
    
    # Exception for Storage related errors
    class StorageException < RuntimeError
    end
    
    
    
end; end; end
