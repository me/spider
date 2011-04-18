$SPIDER_RUNMODE = 'test'
require 'spiderfw/test'
require "test/unit"

module Spider
    
    class TestCase < ::Test::Unit::TestCase
        
        def setup
            Spider::Test.before
        end
        
        def teardown
            Spider::Test.after
        end
        
        def default_test
            return super unless self.class == Spider::TestCase
        end
        
    end
    
end