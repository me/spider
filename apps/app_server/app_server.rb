require 'find'
require 'apps/app_server/lib/app'
require 'apps/app_server/lib/git_app'

module Spider
    
    module AppServer
        
        def self.apps
            @apps ||= scan
        end
        
        def self.rescan
            @apps = scan
        end
    
        def self.scan
            apps = []
            self.paths.each do |path|
                apps += scan_path(path)
            end
            @apps_by_id = {}
            apps.each do |app|
                @apps_by_id[app.spec.id] = app
                app.app_server(Spider.conf.get('app_server.url'))
            end
            apps
        end
        
        def self.apps_by_id
            self.apps
            @apps_by_id
        end
        
        def self.scan_path(path)
            apps = []
            git_repos = search_git(path)
            git_repos.each do |p|
                app = GitApp.new(p)
                apps << app if app.spec
            end
            apps
        end
        
        def self.search_git(path)
            found = []
            Find.find(path) do |p|
                if File.directory?(p)
                    if File.directory?("#{p}/objects") && File.directory?("#{p}/info") && File.file?("#{p}/HEAD")
                        found << p
                        Find.prune
                    end
                end
            end
            found
        end
        
        def self.search_dirs(path)
            Dir.glob("#{path}/**/_init.rb").each do |f|
                found << File.dirname(f)
            end
        end
        
        def self.paths
            Spider.conf.get('app_server.search_paths') || []
        end
        
    end
    
end