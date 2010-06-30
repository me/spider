require 'rake'
require 'rake/testtask'
require 'pathname'

def check_app_path(full, partial)
    p = Pathname.new(full)
    rel = p.relative_path_from(Pathname.new(Spider.paths[:core_apps]))
    return true if rel.to_s == partial
    rel = p.relative_path_from(Pathname.new(Spider.paths[:apps]))
    return true if rel.to_s == partial
    return false
end

desc "Update pot/po files. To update a single app, call rake updatepo[app_relative_path], where app_relative_path is the path relative to the apps folder (or 'spider')."
task :updatepo, [:app] do |t, args|
    require 'spiderfw'
    require 'spiderfw/i18n/shtml_parser'
    require 'gettext/tools'
    require 'ruby-debug'
    GetText.update_pofiles("spider", Dir.glob("{lib,bin,views}/**/*.{rb,rhtml,shtml}"), "Spider #{Spider::VERSION}") if !args[:app] || args[:app] == 'spider'
    apps = Spider.find_all_apps
    apps.each do |path|
        next if args[:app] && !check_app_path(path, args[:app])
        require path+'/_init.rb' if File.directory?(path+'/po')
    end
    Spider.apps.each do |name, mod|
        next unless File.directory?(mod.path+'/po')
        next if args[:app] && !check_app_path(mod.path, args[:app])
        Dir.chdir(mod.path)
        GetText.update_pofiles(mod.short_name, Dir.glob("{lib,bin,controllers,models,views,widgets}/**/*.{rb,rhtml,shtml}"), "#{mod.name} #{mod.version}")
        print "\n"
    end

end

desc "Create mo-files. To create for a single app, call rake makemo[app_relative_path], where app_relative_path is the path relative to the apps folder (or 'spider')."
task :makemo, [:app] do |t, args|
    require 'gettext/tools'
    GetText.create_mofiles(:verbose => true) if !args[:app] || args[:app] == 'spider'
    require 'spiderfw'
    apps = Spider.find_all_apps
    apps.each do |path|
        next if args[:app] && !check_app_path(path, args[:app])
        if File.directory?(path+'/po')
            Dir.chdir(path)
            GetText.create_mofiles(:verbose => true, :po_root => './po', :mo_root => "#{path}/data/locale")
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

begin
    require 'hanna/rdoctask'
    Rake::RDocTask.new(:rdoc) do |rdoc|
      rdoc.rdoc_files.include('README', 'LICENSE', 'CHANGELOG').
        include('lib/**/*.rb')
    #    .exclude('lib/will_paginate/version.rb')

      rdoc.main = "README" # page to start on
      rdoc.title = "Spider documentation"

      rdoc.rdoc_dir = 'doc' # rdoc output folder
      rdoc.options << '--webcvs=http://github.com/me/spider/tree/master/'
    end
rescue LoadError
end
    

