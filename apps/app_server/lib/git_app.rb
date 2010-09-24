require 'grit'

module Spider; module AppServer
    
    class GitApp < App
        
        def initialize(path)
            repo = Grit::Repo.new(path)
            spec = nil
            repo.tree.blobs.each do |blob|
                next unless blob.basename =~ /\.appspec$/
                spec = blob.data
                @spec = Spider::App::AppSpec.eval(spec)
                @last_modified = repo.commits.first.authored_date # FIXME
                break
            end
            
        end
        
    end
    
end; end