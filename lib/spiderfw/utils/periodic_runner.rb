module Spider

    # TODO: remove
    class PeriodicRunner #:nodoc:
        attr_reader :runner_thread
        
        def initialize(sleep_time=nil)
            @entries = []
            @sleep_time = sleep_time
            @mutex = Mutex.new
            if (sleep_time)
                @runner_thread = Thread.new{
                    while (true)
                        sleep(sleep_time)
                        run
                    end
                }
            end
        end
        
        def add(secs, &proc)
            proc.call
            @mutex.synchronize {
                @entries << {
                    :secs => secs,
                    :proc => proc,
                    :last => Time.now.to_i
                }
            }
        end
        
        def run
            Spider::Logger.debug("Periodic_runner")
            @mutex.synchronize {
                Spider::Logger.debug("In synchro")
                @entries.each do |entry|
                    if (!entry[:last] || (entry[:last] + secs) < Time.now.to_i )
                        proc.call
                        entry[:last] = Time.now.to_i
                    end
                end
            }
        end
        
    end
    

    
    
end