$SPIDER_RUNMODE = 'test'
require 'rspec'
require 'rr'
require 'spiderfw/spider'
require 'spiderfw/test'
$:.unshift($SPIDER_PATH) unless $:.include?($SPIDER_PATH)
$:.unshift(File.join($SPIDER_PATH, 'test'))
Spider::Controller # autoload
Spider.start_loggers
require 'ruby-debug' rescue LoadError

RSpec.configure do |config|
    config.mock_with :rr
    config.before(:each) do
        Spider::Test.before
    end
    config.after(:each) do
        Spider::Test.after
    end
end