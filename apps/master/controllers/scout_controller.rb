require 'json'

module Spider; module Master
    
    class ScoutController < Spider::PageController
        
        route /([\w\d]{8}-[\w\d]{4}-[\w\d]{4}-[\w\d]{4}-[\w\d]{12})/, self, :do => lambda{ |uuid|
            @server = Server.load(:uuid => uuid)
            @uuid = uuid
            raise NotFound.new("Server #{uuid}") unless @server
        }
        

        __.json
        def plan
            last_modified = (@server.scout_plan_changed || @server.obj_modified).to_local_time
            @server.scout_plugins.each do |instance|
                stat = File.lstat(instance.plugin.rb_path)
                mtime = stat.mtime
                last_modified = mtime if mtime > last_modified
            end 
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
            $out << @server.scout_plan.to_json
        end
        
        
        __.json
        def checkin
            res = Zlib::GzipReader.new(@request.body).read
            #Spider.logger.debug("RECEIVED REPORT FOR #{@uuid}:")
            #Spider.logger.debug(res)
            res = JSON.parse(res)
            statuses = {}
            reports = {}
            res["reports"].each do |rep|
                statuses[rep["plugin_id"]] = :ok
                reports[rep["plugin_id"]] ||= ScoutReport.create(
                    :plugin_instance => rep["plugin_id"], 
                    :created_at => DateTime.parse(rep["created_at"])
                )
                report = reports[rep["plugin_id"]]
                rep["fields"].each do |name, val|
                    field = ScoutReportField.create(:name => name, :value => val, :report => report)
                end
            end
            res["alerts"].each do |alert|
                subject = alert["fields"]["subject"]
                body = alert["fields"]["body"]
                last = ScoutAlert.where(
                    :plugin_instance => alert["plugin_id"],
                    :active => true
                ).order_by(:obj_created, :desc)
                statuses[alert["plugin_id"]] = :alert
                had_previous = false
                last.each do |l|
                    if l && l.subject == subject && l.body == body
                        l.repeated ||= 0
                        l.repeated += 1
                        l.save
                        had_previous = true
                        break
                    end
                end
                next if had_previous
                subject = alert["fields"]["subject"]
                instance = ScoutPluginInstance.new(alert["plugin_id"])
                subject = "#{instance.server} - #{subject}"
                alert = ScoutAlert.create(
                    :plugin_instance => alert["plugin_id"],
                    :subject => alert["fields"]["subject"],
                    :body => alert["fields"]["body"]
                )
            end
            res["errors"].each do |err|
                subject = err["fields"]["subject"]
                body = err["fields"]["body"]
                last = ScoutError.where(:plugin_instance => err["plugin_id"]).order_by(:obj_created, :desc)
                last.limit = 1
                statuses[err["plugin_id"]] = :error
                if last[0] && last[0].subject == subject && last[0].body == body
                    last[0].repeated ||= 0
                    last[0].repeated += 1
                    last[0].save
                    next
                end
                subject = err["fields"]["subject"]
                instance = ScoutPluginInstance.new(err["plugin_id"])
                subject = "#{instance.server} - #{subject}"
                error = ScoutError.create(
                    :plugin_instance => err["plugin_id"],
                    :subject => err["fields"]["subject"],
                    :body => err["fields"]["body"]
                )
            end
            today = Date.today
            statuses.each do |id, val|
                i = ScoutPluginInstance.new(id)
                averages_computed_at = i.averages_computed_at
                i.obj_modified = DateTime.now
                i.status = val
                i.compute_averages if !averages_computed_at || averages_computed_at < today
                i.averages_computed_at = Date.today
                i.save
                i.check_triggers
                i.save
            end

        end
        
    end
    
end; end
