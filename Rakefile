require 'rake'
require 'rake/testtask'

desc "Update pot/po files."
task :updatepo do
    require 'spiderfw'
    require 'spiderfw/i18n/shtml_parser'
    require 'gettext/utils'
    GetText.update_pofiles("spider", Dir.glob("{lib,bin}/**/*.{rb,rhtml}"), "Spider #{Spider::VERSION}")
    apps = Spider.find_all_apps
    apps.each do |path|
        require path+'/_init.rb' if File.directory?(path+'/po')
    end
    Spider.apps.each do |name, mod|
        next unless File.directory?(mod.path+'/po')
        Dir.chdir(mod.path)
        GetText.update_pofiles(mod.short_name, Dir.glob("{lib,bin,controllers,models,views,widgets}/**/*.{rb,rhtml,shtml}"), "#{mod.name} #{mod.version}")
        print "\n"
    end

end

desc "Create mo-files"
task :makemo do
    require 'gettext/utils'
    GetText.create_mofiles(true)
    require 'spiderfw'
    apps = Spider.find_all_apps
    apps.each do |path|
        if File.directory?(path+'/po')
            Dir.chdir(path)
            GetText.create_mofiles(true, './po', $SPIDER_PATH+'/data/locale')
        end
    end
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
    

