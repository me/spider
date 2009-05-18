require 'rake'
require 'rake/testtask'

desc "Update pot/po files."
task :updatepo do
  require 'spiderfw'
  require 'gettext/utils'
  GetText.update_pofiles("spider", Dir.glob("{apps,lib,bin}/**/*.{rb,rhtml}"), "Spider #{Spider::VERSION}")
end

desc "Create mo-files"
task :makemo do
  require 'gettext/utils'
  GetText.create_mofiles(true)
  # GetText.create_mofiles(true, "po", "locale")  # This is for "Ruby on Rails".
end

task :test do
    Dir.chdir("test")
    require 'spiderfw'
    require 'test/unit/collector/dir'
    require 'test/unit'
    
    begin
        Spider.test_setup
        Spider._test_setup
        collector = Test::Unit::Collector::Dir.new()
        suite = collector.collect('tests')
        Test::Unit::AutoRunner.run
    rescue => exc
        Spider::Logger.error(exc)
    ensure
        Spider._test_teardown
        Spider.test_teardown
    end
    
end
    

