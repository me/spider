$SPIDER_RUN_PATH=File.dirname(__FILE__)+'/..'
require 'spiderfw'
require 'spiderfw/utils/test_case'


class TestDb < Spider::TestCase
    @single = (__FILE__ == $0)
    
    def test_connection_pool
        pool = Zoo::Animal.storage.connection_pool
        threads = []
        1.upto(pool.max_size) do |i|
            t = Thread.new do
                pool.get_connection
            end
            t.join
        end
        assert_equal(pool.max_size, pool.size)
        pool.clear
        assert_equal(0, pool.size)
        
        threads = []
        1.upto(pool.max_size*2) do |i|
            threads[i] = Thread.new do
                1.upto(100) do |j|
                    Zoo::Animal.all.load
                end
            end
        end
        pool = Zoo::Animal.storage.connection_pool
        sleep(1)

        assert_equal(pool.max_size, pool.size)

        threads.each{ |t| t.kill if t }
        pool.clear

    end
    
end