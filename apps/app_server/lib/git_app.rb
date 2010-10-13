require 'grit'

module Spider; module AppServer
    
    class GitApp < App
        attr_reader :repo
        
        def initialize(path)
            super
            repo = Grit::Repo.new(path)
            spec = nil
            repo.tree.blobs.each do |blob|
                next unless blob.basename =~ /\.appspec$/
                spec = blob.data
                @spec = Spider::App::AppSpec.eval(spec)
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
                break
            end
            @repo = repo
        end
        
        def package
            
        end
        
    end
    
end; end