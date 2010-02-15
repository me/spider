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
        limit = 100
        while (pool.size < pool.max_size && threads.length < limit)
            Spider.logger.debug "POOL SIZE: #{pool.size}"
            threads << Thread.new do
                1.upto(100) do |j|
                    Zoo::Animal.all.load
                end
            end
        end
        Spider.logger.debug "THREADS: #{threads.length}"
        
        assert(threads.length < limit)
        
      #  sleep(1)

     #   assert_equal(pool.max_size, pool.size)

        threads.each{ |t| t.join  }
        pool.clear

        #pool.timeout = pool.max_size
        
        threads = []
        1.upto(pool.max_size * 2) do |i|
            threads << Thread.new do
                conn = pool.get_connection
                sleep(1)
                pool.release(conn)
            end
        end
        
        threads.each{ |t| t.join  }
        pool.clear

        
        Zoo::Food.static(:id => 'test_food1', :name => 'Test1').insert
        Zoo::Food.static(:id => 'test_food2', :name => 'Test2').insert
        threads = []
        i = 0
        # This should build up some queue
        while threads.length < pool.max_size * 3
            i += 1
            threads << Thread.new do
                1.upto(50) do |j|
                    animal = Zoo::Animal.static(:id => "test_animal#{Thread.current}", :name => 'Test')
                    animal.foods << 'test_food1'; animal.foods << 'test_food2'
                    animal.insert
                    animal = Zoo::Animal.new("test_animal#{Thread.current}")
                    animal.delete
                end
            end
        end
        
        threads.each{ |t| t.join  }        
        
        assert_equal(pool.max_size, pool.size)
        assert_equal(0, Zoo::Animal.where(:name => 'Test').total_rows)
        assert_equal(0, Zoo::Animal::Foods.where('food.id' => 'test_food1').total_rows)
        


    end
    
end