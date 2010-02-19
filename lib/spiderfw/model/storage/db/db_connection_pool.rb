require 'monitor'

module Spider; module Model; module Storage; module Db

    class DbConnectionPool
        attr_reader :max_size
        attr_accessor :timeout, :retry

        def initialize(connection_params, provider)
            @connection_params = connection_params
            @provider = provider
            @connection_mutex = Monitor.new
            @queue = @connection_mutex.new_cond
            @max_size = Spider.conf.get('storage.db.pool.size')
            @max_size = provider.max_connections if provider.max_connections && provider.max_connections < @max_size
            @timeout = Spider.conf.get('storage.db.pool.timeout')
            @retry = Spider.conf.get('storage.db.pool.retry')
            @connections = []
            @free_connections = []
            # if Spider.runmode == 'devel'
            #     Thread.new do
            #         loop do
            #             Spider.logger.debug("DB Pool: #{@connections.length} connections, #{@free_connections.length} free")
            #             sleep(10)
            #         end
            #     end
            # end
        end
        
        def size
            @connections.length
        end
        
        def free_size
            @free_connections.length
        end

        def get_connection
            Thread.current[:db_connections] ||= {}
            @connection_mutex.synchronize do
                if conn = Thread.current[:db_connections][@connection_params]
                    # Spider.logger.debug("DB Pool (#{Thread.current}): returning thread connection #{conn}")
                    @free_connections.delete(conn)
                    conn
                else
                    Thread.current[:db_connections][@connection_params] = _checkout
                end
            end
        end
        
        def checkout
            @connection_mutex.synchronize do
                _checkout
            end
        end
        
        def release(conn)
            @connection_mutex.synchronize do
                # Spider.logger.debug("DB Pool (#{Thread.current}): releasing #{conn}")
                @free_connections << conn
                @queue.signal
                Thread.current[:db_connections].delete(@connection_params)
            end
        end
        
        def remove(conn)
            @connection_mutex.synchronize do
                remove_connection(conn)
            end
        end
        
        def clear
            @connections.each do |c|
                @provider.disconnect(c)
            end
            @connections = []
            @free_connections = []
        end
        
        private
        
        def _checkout
            # Spider.logger.debug("DB Pool (#{Thread.current}): checkout (max: #{@max_size})")
            1.upto(@retry) do
                if @free_connections.empty?
                    # Spider.logger.debug("DB Pool (#{Thread.current}): no free connection")
                    if @connections.length < @max_size
                        create_new_connection
                    else
                        Spider.logger.debug "#{Thread.current} WAITING FOR CONNECTION, #{@queue.count_waiters} IN QUEUE"
                        unless @queue.wait(@timeout)
                            raise StorageException, "Unable to get a db connection in #{@timeout} seconds" if @timeout
                        end
                    end
                else
                    # Spider.logger.debug("DB Pool (#{Thread.current}): had free connection")
                end
                conn = @free_connections.pop
                if @provider.connection_alive?(conn)
                    # Spider.logger.debug("DB Pool (#{Thread.current}): returning #{conn} (#{@free_connections.length} free)")
                    return conn
                else
                    remove(conn)
                end
            end
        end
        
        def remove_connection(conn)
            @free_connections.delete(conn)
            @connections.delete(conn)
        end
        
        
        def create_new_connection
            conn = @provider.new_connection(*@connection_params)
            Spider.logger.debug("DB Pool (#{Thread.current}): creating new connection #{conn} (#{@connections.length} already in pool)")
            @connections << conn
            @free_connections << conn
        end



    end


end; end; end; end