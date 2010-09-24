require 'json'
require 'json/add/rails'

module Spider; module Master
    
    class ScoutController < Spider::PageController
        
        route /([\w\d]{8}-[\w\d]{4}-[\w\d]{4}-[\w\d]{4}-[\w\d]{12})/, self, :do => lambda{ |uuid|
            @servant = Servant.load(:uuid => uuid)
            raise NotFound.new("Servant #{uuid}") unless @servant
        }
        

        __.json
        def plan
            last_modified = (@servant.scout_plan_changed || @servant.obj_modified).to_local_time
            if @request.env['HTTP_IF_MODIFIED_SINCE']
                if_modified = nil
                begin
                    if_modified = Time.httpdate(@request.env['HTTP_IF_MODIFIED_SINCE'])
                rescue ArgumentError
                    if_modified = 0
                end
                raise HTTPStatus.new(Spider::HTTP::NOT_MODIFIED) if last_modified <= if_modified
            end
            @response.headers['Last-Modified'] = last_modified.httpdate
            $out << @servant.scout_plan.to_json
        end
        
        
        __.json
        def checkin
            res = Zlib::GzipReader.new(@request.body).read
            res = JSON.parse(res)
            debugger
            res["reports"].each do |rep|
                report = ScoutReport.create(
                    :plugin_instance => rep["plugin_id"], 
                    :created_at => DateTime.parse(rep["created_at"])
                )
                rep["fields"].each do |name, val|
                    field = ScoutReportField.create(:name => name, :value => val, :report => report)
                end
            end
            res["errors"].each do |err|
                error = ScoutError.create(
                    :plugin_instance => err["plugin_id"],
                    :subject => err["fields"]["subject"],
                    :body => err["fields"]["body"]
                )
            end
        end
        
    end
    
end; end