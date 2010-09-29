require 'spiderfw/controller/spider_controller'
require 'spiderfw/controller/session/memory_session'
require 'spiderfw/controller/session/file_session'

module Spider
    
    class HTTPController < Controller
        include HTTPMixin
        
        
        def initialize(request, response, scene=nil)
            response.status = Spider::HTTP::OK
            response.headers = {
                'Content-Type' => 'text/plain',
                'Connection' => 'close'
            }
            @previous_stdout = $stdout
            Thread.current[:stdout] = response.server_output
            $out = ThreadOut
            $stdout = ThreadOut if Spider.conf.get('http.seize_stdout')
            request.extend(HTTPRequest)
            super(request, response, scene)
        end
        
        def before(action='', *arguments)
            if (@request.env['HTTP_TRANSFER_ENCODING'] == 'Chunked' && !@request.server.supports?(:chunked_request))
                raise HTTPStatus.NOT_IMPLEMENTED
            end
            @request.cookies = Spider::HTTP.parse_query(@request.env['HTTP_COOKIE'], ';')
            @request.session = Session.get(@request.cookies['sid'])
            @response.cookies['sid'] = @request.session.sid
            @response.cookies['sid'].path = '/'
            @request.params = {}
            @uploaded_files = []
            if (@request.env['QUERY_STRING'])
                @request.params = Spider::HTTP.parse_query(@request.env['QUERY_STRING'])
            end
            if @request.env['REQUEST_METHOD'] == 'POST' && @request.env['HTTP_CONTENT_TYPE']
                if @request.env['HTTP_CONTENT_TYPE'].include?('application/x-www-form-urlencoded')
                    @request.params.merge!(Spider::HTTP.parse_query(@request.read_body))
                elsif @request.env['HTTP_CONTENT_TYPE'] =~ Spider::HTTP::MULTIPART_REGEXP
                    multipart_params, multipart_files = Spider::HTTP.parse_multipart(@request.body, $1, @request.env['CONTENT_LENGTH'].to_i)
                    @request.params.merge!(multipart_params)
                    @uploaded_files = multipart_files
                end
            end

            @request.http_method = @request.env['REQUEST_METHOD'].upcase.to_sym
            @request.http_host = @request.env['HTTP_HOST']
            if @request.env['HTTP_CACHE_CONTROL']
                parts = @request.env['HTTP_CACHE_CONTROL'].split(';')
                parts.each do |part|
                    if part == 'no-cache'
                        @request.cache_control[:no_cache] = true
                    else
                        key, val = part.split('=')
                        @request.cache_control[key] = val
                    end
                end
            end
            if @request.env['HTTP_PRAGMA'] == 'no-cache'
                @request.cache_control[:no_cache] = true
            end
            Locale.clear
            Locale.init(:driver => :cgi)
            Locale.set_request(@request.params['lang'], @request.cookies['lang'], @request.env['HTTP_ACCEPT_LANGUAGE'], @request.env['HTTP_ACCEPT_CHARSET'])
            @request.locale = Locale.current[0]
            if (action =~ /(.+)\.(\w+)$/) # strip extension, set format
                action = $1
                @request.format = $2.to_sym
            end
#            Spider.reload_sources if Spider.conf.get('webserver.reload_sources')
            Spider.logger.info("Request: #{@request.http_method} #{@request.http_host} #{@request.path}")
            super(action, *arguments)
        end
        
        def execute(action='', *arguments)
            # FIXME: cache stripped action?
            action = $1 if (action =~ /(.+)\.(\w+)$/) # strip extension, set format
            super(action, *arguments)
            log_done
            #@response.headers['Date'] ||= Time.now.httpdate
        end
        
        def after(action='', *arguments)
            # FIXME: cache stripped action?
            action = $1 if (action =~ /(.+)\.(\w+)$/) # strip extension, set format
            @request.session.persist if @request.session
            super(action, *arguments)
        end
        
        def ensure(action='', *arguments)
            dispatch(:ensure, action, *arguments)
            $stdout = @previous_stdout
            if @uploaded_files
                @uploaded_files.each do |f|
                    f.close
                end
            end
        end
        
        def log_done
            Spider::Request.current[:_http_logged_done] = true
            str = "Done: #{@response.status} #{Spider::HTTP.status_messages[@response.status]}"
            str += " (static)" if @request.misc[:is_static]
            str += " in #{(Time.now - Spider::Request.current[:_start])*1000}ms" if Spider::Request.current[:_start]
            if @request.respond_to?(:user) && @request.user
                str += " for user #{@request.user.class}(#{@request.user.primary_keys})"
            end
            if Spider.conf.get('log.memory')
                str += " - Memory usage: #{Spider::Memory.get_memory_usage}"
            end
            Spider.logger.info(str)
        end
        
        
        def get_route(path)
            path = path.clone
            path.slice!(0) if path.length > 0 && path[0].chr == "/"
            return Route.new(:path => path, :dest => Spider.home.controller, :action => path)
        end
        
        def try_rescue(exc)
            log_done unless Spider::Request.current[:_http_logged_done]
            if exc.is_a?(Spider::Controller::NotFound)
                Spider.logger.error("Not found: #{exc.path}")
            elsif exc.is_a?(Spider::Controller::Forbidden)
                Spider.logger.warn("Forbidden: #{exc.message}")
            else
                super
            end
        end
        
        module HTTPRequest
            attr_accessor :http_method, :http_host
            
            # Returns PATH_INFO reversing any proxy mappings if needed.
            def path
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping(self.env['PATH_INFO'])
            end
            
            def full_path
                'http://'+self.env['HTTP_HOST']+path
            end
            
            # Returns the REQUEST_URI reversing any proxy mappings if needed
            def uri
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping(self.env['REQUEST_URI'])
            end
            
            # Returns #uri prefixed with http:// and the HTTP_HOST
            def full_uri
                'http://'+self.env['HTTP_HOST']+uri
            end
            
            def client_cert
                return @client_certificate if @client_cert
                unless self.env['SSL_CLIENT_CERT'].blank?
                    @client_cert = OpenSSL::X509::Certificate.new(self.env['SSL_CLIENT_CERT'])
                end
            end
            
            def cache_control
                @cache_control ||= {}
            end
            
        end
    
        
        
    end
    
end
