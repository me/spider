$SPIDER_RUNMODE = 'test'
require 'spiderfw/test/cucumber'
require 'spiderfw/test/capybara'
Spider.init

TEST_EMAIL = {
    :from => 'from@example.com',
    :to => 'to@example.com',
    :subject => 'Test e-mail',
    :body => 'This is a test'
}
