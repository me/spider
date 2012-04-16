require 'grit'

module Spider; module AppServer
    
    class GitApp < App
        attr_reader :repo
        attr_reader :branches
        
        def initialize(path)
            super
            repo = Grit::Repo.new(path)
            spec = nil
            repo_branches = repo.heads.map{ |h| h.name }
            @branches = repo_branches
            @repo = repo
            read_spec
        end

        def read_spec(branch='master')
            @repo.tree(branch).blobs.each do |blob|
                next unless blob.basename =~ /\.appspec$/
                spec = blob.data
                @spec = Spider::App::AppSpec.eval(spec)
                @spec.branch = branch
                if repo_base = Spider.conf.get('app_server.git_repo_base')
                    unless @spec.git_repo
                        @spec.git_repo(repo_base+'/'+@spec.id)
                    end
                end
                if repo_base_rw = Spider.conf.get('app_server.git_repo_rw_base')
                    unless @spec.git_repo_rw
                        @spec.git_repo_rw(repo_base_rw+'/'+@spec.id)
                    end
                end
                @last_modified = repo.commits.first.authored_date # FIXME
                @spec.app_server ||= AppServer::AppServerController.http_url
                break
            end
            @repo = repo
            @spec
        end
        
        def package
            
        end
        
    end
    
end; end
