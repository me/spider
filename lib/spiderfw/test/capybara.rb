require 'spiderfw/http/adapters/rack'
require 'capybara'
require 'capybara/cucumber'
require 'culerity'

Capybara.app = Spider::HTTP::RackApplication.new
Capybara.default_host = 'localhost'
Capybara.app_host = 'http://localhost'