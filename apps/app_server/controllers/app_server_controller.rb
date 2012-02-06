require 'tempfile'
require 'json'

module Spider; module AppServer

    class AppServerController < Spider::PageController

        layout 'app_server'

        __.html :template => 'app_list'
        __.json :call => :list_json
        def list(name=nil)
            # FIXME: names, branches
            @scene.apps = AppServer.apps
        end

        def list_json(names=nil)
            if names
                apps = names.split('+')
                $out << (apps.map{ |name| AppServer.apps_by_id[name] }).to_json
            else
                $out << AppServer.apps.to_json
            end
        end

        __.action
        def pack(name=nil)
            branch = @request.params['branch'] || 'master'
            app = AppServer.apps_by_id[name]
            raise NotFound.new("App #{name}") unless app
            tmp = Tempfile.new("spider-app-archive")
            if app.is_a?(GitApp)
                repo = app.repo
                repo.archive_to_file(branch, nil, tmp.path, nil, 'cat') 
            else
                # TODO
            end
            output_static(tmp.path)
            tmp.close
        end
        
        __.json
        def deps(names)
            AppServer.apps
            names = names.split('+')
            new_apps = names
            specs = {}
            while !new_apps.empty? && curr = new_apps.pop
                curr, branch = curr.split('@')
                raise NotFound.new("App #{curr}") unless AppServer.apps_by_id[curr]
                a = AppServer.apps_by_id[curr]
                spec = a.spec
                spec = a.read_spec(branch) if branch 
                specs[curr] = spec
                new_apps += spec.depends.reject{ |app| specs[app] }
                new_apps += spec.depends_optional.reject{ |app| specs[app] } unless @request.params['no_optional']
            end
            $out << specs.values.to_json
        end

    end


end; end
