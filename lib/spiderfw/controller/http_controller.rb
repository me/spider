require 'spiderfw/controller/spider_controller'
require 'spiderfw/controller/session/memory_session'
require 'spiderfw/controller/session/file_session'

module Spider
    
    class HTTPController < Controller
        include HTTPMixin
        
        
        def initialize(request, response, scene=nil)
            response.status = Spider::HTTP::OK
            response.headers = {
                'Content-Type' => 'text/plain'
            }
            @previous_stdout = $stdout
            Thread.current[:stdout] = response.server_output
            $out = ThreadOut
            $stdout = ThreadOut if Spider.conf.get('http.seize_stdout')
            request.extend(HTTPRequest)
            super(request, response, scene)
        end

        def call_before(action, *arguments)
            if action =~ /(.+)\.(\w+)$/ # strip extension, set format
                action = $1
                @request.format = $2.to_sym
            end
            super(action, *arguments)
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
                @request.get = @request.params
            end
            if ['POST', 'PUT', 'DELETE'].include?(@request.env['REQUEST_METHOD']) && @request.env['HTTP_CONTENT_TYPE']
                if @request.env['HTTP_CONTENT_TYPE'].include?('application/x-www-form-urlencoded')
                    data = Spider::HTTP.parse_query(@request.read_body)
                    req_meth = @request.env['REQUEST_METHOD'].downcase
                    @request.send(:"#{req_meth}=", data)
                    @request.params.merge!(@request.send(:"#{req_meth}"))
                elsif @request.env['HTTP_CONTENT_TYPE'] =~ Spider::HTTP::MULTIPART_REGEXP
                    multipart_params, multipart_files = Spider::HTTP.parse_multipart(@request.body, $1, @request.env['CONTENT_LENGTH'].to_i)
                    @request.params.merge!(multipart_params)
                    @uploaded_files = multipart_files
                end
            end

            @request.http_method = @request.env['REQUEST_METHOD'].upcase.to_sym
            @request.http_host = @request.env['HTTP_HOST']
            @request.ssl = true if @request.env['HTTPS'] == 'on'
            if @request.http_host =~ /(.+)\:(\d+)/
                @request.domain = $1
                @request.port = $2.to_i
            else
                @request.domain = @request.http_host
                @request.port = @request.ssl? ? 443 : 80
            end
            
            unless Spider.site
                port = @request.ssl? ? nil : @request.port
                Spider.site = Spider::Site.new(@request.domain, port)
                Spider.site._auto = true
                Spider.site.save_cache
            end
            if @request.ssl? && Spider.site.auto? && !Spider.site.ssl_port
                Spider.site.ssl_port = @request.port
                Spider.site.save_cache
            end
            if !@request.ssl? && Spider.site.auto? && !Spider.site.port
                Spider.site.port = @request.port
                Spider.site.save_cache
            end
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
            l = @request.locale.to_s
            l = $1 if l =~ /(\w\w)_+/
            FastGettext.locale = l
            FastGettext.text_domain = 'spider'
#            Spider.reload_sources if Spider.conf.get('webserver.reload_sources')
            static_level = Spider.conf.get('log.static_extensions')
            if @request.format && @request.get? && static_level != true
                allowed = Spider.conf.get('log.non_static_extensions_list')
                unless allowed.include?(@request.format.to_s)
                    Spider.logger.info("GET #{@request.path}")
                    @logger_static_prev = Spider.logger.set_request_level(static_level)
                end
            end
            Spider::Logger.debug("REQUEST:")
            Spider::Logger.debug(@request.env)
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
            @request.session.persist if @request.session && @request.session.respond_to?(:persist)
            super(action, *arguments)
            @Spider.logger.set_thread_level(@logger_static_prev) if @logger_static_prev
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
            self.done = true
            if exc.is_a?(Spider::Controller::NotFound)
                Spider.logger.error("Not found: #{exc.path}")
            elsif exc.is_a?(Spider::Controller::Forbidden)
                Spider.logger.warn("Forbidden: #{exc.message}")
            elsif exc.is_a?(Errno::EPIPE)
                Spider.logger.warn("Broken pipe")
            else
                super
            end
        end
        
        module HTTPRequest
            attr_accessor :http_method, :http_host, :domain, :port, :post, :get, :put, :delete
            
            # Returns PATH_INFO reversing any proxy mappings if needed.
            def path
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping(self.env['PATH_INFO'])
            end
            
            def http_path
                'http://'+self.env['HTTP_HOST']+path
            end
            
            def full_path
                Spider.logger.warn("Request#full_path is deprecated. Use Request#http_path instead")
                http_path
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
            
            def ssl=(bool)
                @ssl = bool
            end
            
            def ssl?
                @ssl
            end
            
            def post
                @post ||= {}
            end
            
            def get
                @get ||= {}
            end

            def put
                @put ||= {}
            end
            
            def post?
                self.http_method == :POST
            end
            
            def get?
                self.http_method == :GET
            end

            def put?
                self.http_method == :PUT
            end

            def delete?
                self.http_method == :DELETE
            end
            
        end
    
        
        
    end
    
end
