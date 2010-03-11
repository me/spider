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
            @thread_connections = {}
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
                #Spider.logger.debug("DB Pool (#{Thread.current}): trying to get connection")
                if conn = Thread.current[:db_connections][@connection_params]
                    #Spider.logger.debug("DB Pool (#{Thread.current}): returning thread connection #{conn}")
                    @free_connections.delete(conn)
                    conn
                else
                    conn = _checkout
                    Thread.current[:db_connections][@connection_params] = conn
                    @thread_connections[Thread.current.object_id] = [conn, Time.now]
                    conn
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
                #Spider.logger.debug("DB Pool (#{Thread.current}): releasing #{conn}")
                @free_connections << conn
                Thread.current[:db_connections].delete(@connection_params)
                @thread_connections.delete(Thread.current.object_id)
                @queue.signal
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
        
        def _release
        end
        
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
                            clear_stale_connections
                            create_new_connection if @free_connections.empty? && @connections.length < @max_size
                            if @free_connections.empty?
                                Spider.logger.error "#{Thread.current} GOT TIRED WAITING, #{@queue.count_waiters} IN QUEUE"
                                raise StorageException, "Unable to get a db connection in #{@timeout} seconds" if @timeout
                            end
                        end
                    end
                else
                    # Spider.logger.debug("DB Pool (#{Thread.current}): had free connection")
                end
                conn = @free_connections.pop
                while conn && !@provider.connection_alive?(conn)
                    Spider.logger.warn("DB Pool (#{Thread.current}): connection #{conn} dead")
                    remove_connection(conn)
                    conn = nil
                    conn = @free_connections.pop unless @free_connections.empty?
                end
                if conn
                    #Spider.logger.debug("DB Pool (#{Thread.current}): returning #{conn} (#{@free_connections.length} free)")
                    return conn
                end
            end
            raise StorageException, "#{Thread.current} unable to get a connection after #{@retry} retries."
        end
        
        def clear_stale_connections
            @connection_mutex.synchronize do
                keys = Set.new(@thread_connections.keys)
                Thread.list.each do |thread|
                    keys.delete(thread.object_id) if thread.alive?
                end
                keys.each do |thread_id|
                    conn, time = @thread_connections[thread_id]
                    Spider.logger.error("Thread #{thread_id} died without releasing connection #{conn} (acquired at #{time})")
                    if @provider.connection_alive?(conn)
                        @free_connections << conn
                    else
                        remove_connection(conn)
                    end
                    @thread_connections.delete(thread_id)
                end
                @thread_connections.each do |thread_id, conn_data|
                    conn, time = conn_data
                    diff = Time.now - time
                    if diff > 60
                        Spider.logger.warn("Thread #{thread_id} has been holding connection #{conn} for #{diff} seconds.")
                    end
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