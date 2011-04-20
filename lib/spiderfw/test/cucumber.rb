require 'cucumber/rspec/doubles'
require 'spiderfw/spider'
require 'spiderfw/test'
require 'fileutils'

Before do
    Spider::Test.before
end

After do
    Spider::Test.after
end