module Spider
    module HTTP
        autoload :Server,   'spiderfw/http/server'
        #autoload :Thin,     'spiderfw/http/servers/thin'
        autoload :WEBrick,  'spiderfw/http/adapters/webrick'
        autoload :Mongrel,  'spiderfw/http/adapters/mongrel'
        autoload :Thin,     'spiderfw/http/adapters/thin'
        #autoload :Rack,     'spiderfw/http/adapters/rack/rack'
        
        @multipart_regexp = /\Amultipart\/form-data.*boundary=\"?([^\";,]+)/n.freeze
        
        module StatusCodes
        
            CONTINUE = 100
            SWITCHING_PROTOCOLS = 101
            WEBDAV_PROCESSING = 102
            OK = 200
            CREATED = 201
            ACCEPTED = 202
            NON_AUTHORITATIVE = 203
            NO_CONTENT = 204
            RESET_CONTENT = 205
            PARTIAL_CONTENT = 206
            WEBDAV_MULTI_STATUS = 207
            MULTIPLE_CHOICES = 300
            MOVED_PERMANENTLY = 301
            FOUND = 302
            SEE_OTHER = 303
            NOT_MODIFIED = 304
            USE_PROXY = 305
            TEMPORARY_REDIRECT = 307
            BAD_REQUEST = 400
            UNAUTHORIZED = 401
            FORBIDDEN = 403
            NOT_FOUND = 404
            METHOD_NOT_ALLOWED = 405
            NOT_ACCEPTABLE = 406
            PROXY_AUTHENTICATION_REQUIRED = 407
            REQUEST_TIMEOUT = 408
            CONFLICT = 409
            GONE = 410
            LENGTH_REQUIRED = 411
            PRECONDITION_FAILED = 412
            REQUEST_ENTITY_TOO_LARGE = 413
            REQUEST_URI_TOO_LONG = 414
            UNSUPPORTED_MEDIA_TYPE = 415
            REQUESTED_RANGE_NOT_SATISFIABLE = 416
            EXPECTATION_FAILED = 417
            WEBDAV_UNPROCESSABLE_ENTITY = 422
            WEBDAV_LOCKED = 423
            WEBDAV_FAILED_DEPENDENCY = 424
            UPGRADE_REQUIRED = 426
            INTERNAL_SERVER_ERROR = 500
            NOT_IMPLEMENTED = 501
            BAD_GATEWAY = 502
            SERVICE_UNAVAILABLE = 503
            GATEWAY_TIMEOUT = 504
            HTTP_VERSION_NOT_SUPPORTED = 505
            VARIANT_ALSO_NEGOTIATES = 506
            WEBDAV_INSUFFICIENT_STORAGE = 507
            BANDWIDTH_LIMIT_EXCEEDED = 509
            NOT_EXTENDED = 510

            @status_messages = {
                CONTINUE => 'Continue',
                SWITCHING_PROTOCOLS => 'Switching Protocols',
                WEBDAV_PROCESSING => 'Processing',
                OK => 'OK',
                CREATED => 'Created',
                ACCEPTED => 'Accepted',
                NON_AUTHORITATIVE => 'Non Authoritative',
                NO_CONTENT => 'No Content',
                RESET_CONTENT => 'Reset Content',
                PARTIAL_CONTENT => 'Partial Content',
                WEBDAV_MULTI_STATUS => 'Multi-Status',
                MULTIPLE_CHOICES => 'Multiple Choices',
                MOVED_PERMANENTLY => 'Moved Permanently',
                FOUND => 'Found',
                SEE_OTHER => 'See Other',
                NOT_MODIFIED => 'Not Modified',
                USE_PROXY => 'Use Proxy',
                TEMPORARY_REDIRECT => 'Temporary Redirect',
                BAD_REQUEST => 'Bad Request',
                UNAUTHORIZED => 'Unauthorized',
                FORBIDDEN => 'Forbidden',
                NOT_FOUND => 'Not Found',
                METHOD_NOT_ALLOWED => 'Method Not Allowed',
                NOT_ACCEPTABLE => 'Not Acceptable',
                PROXY_AUTHENTICATION_REQUIRED => 'Proxy Authentication Required',
                REQUEST_TIMEOUT => 'Request Timeout',
                CONFLICT => 'Conflict',
                GONE => 'Gone',
                LENGTH_REQUIRED => 'Length Required',
                PRECONDITION_FAILED => 'Precondition Failed',
                REQUEST_ENTITY_TOO_LARGE => 'Request Entity Too Large',
                REQUEST_URI_TOO_LONG => 'Request-URI Too Long',
                UNSUPPORTED_MEDIA_TYPE => 'Unsupported Media Type',
                REQUESTED_RANGE_NOT_SATISFIABLE => 'Requested Range Not Satisfiable',
                EXPECTATION_FAILED => 'Expectation Failed',
                WEBDAV_UNPROCESSABLE_ENTITY => 'Unprocessable Entity',
                WEBDAV_LOCKED => 'Locked',
                WEBDAV_FAILED_DEPENDENCY => 'Failed Dependency',
                UPGRADE_REQUIRED => 'Upgrade Required',
                INTERNAL_SERVER_ERROR => 'Internal Server Error',
                NOT_IMPLEMENTED => 'Not Implemented',
                BAD_GATEWAY => 'Bad Gateway',
                SERVICE_UNAVAILABLE => 'Service Unavailable',
                GATEWAY_TIMEOUT => 'Gateway Timeout',
                HTTP_VERSION_NOT_SUPPORTED => 'HTTP Version Not Supported',
                VARIANT_ALSO_NEGOTIATES => 'Variant Also Negotiates',
                WEBDAV_INSUFFICIENT_STORAGE => 'Insufficient Storage',
                BANDWIDTH_LIMIT_EXCEEDED => 'Bandwidth Limit Exceeded',
                NOT_EXTENDED => 'Not Extended'
            }
        
            def self.status_messages
                @status_messages
            end
            
        end
        
        include StatusCodes
        
        def self.status_messages
            StatusCodes.status_messages
        end
        
        # ==== Parameters
        # s<String>:: String to URL escape.
        #
        # ==== returns
        # String:: The escaped string.
        #--
        # from Merb        
        def self.urlencode(s)
           s.to_s.gsub(/([^a-zA-Z0-9_.-]+)/n) {
             '%'+$1.unpack('H2'*$1.size).join('%').upcase
           }.tr(' ', '+')
        end

        # ==== Parameter
        # s<String>:: String to URL unescape.
        #
        # ==== returns
        # String:: The unescaped string.
        #--
        # from Merb
        def self.urldecode(s)
          s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
            [$1.delete('%')].pack('H*')
          }
        end
        
        # ==== Parameters
        # qs<String>:: The query string.
        # d<String>:: The query string divider. Defaults to "&".
        #
        # ==== Returns
        # Mash:: The parsed query string.
        #
        # ==== Examples
        #   query_parse("bar=nik&post[body]=heya")
        #     # => { :bar => "nik", :post => { :body => "heya" } }
        #--
        # from Merb
        def self.parse_query(qs, d = '&')
          return (qs||'').split(/[#{d}] */n).inject({}) { |h,p| 
            key, value = urldecode(p).split('=',2)
            normalize_params(h, key, value)
          }
        end
        
        
        # Converts a query string snippet to a hash and adds it to existing
        # parameters.
        #
        # ==== Parameters
        # parms<Hash>:: Parameters to add the normalized parameters to.
        # name<String>:: The key of the parameter to normalize.
        # val<String>:: The value of the parameter.
        #
        # ==== Returns
        # Hash:: Normalized parameters
        #--
        # from Merb
        def self.normalize_params(parms, name, val=nil)
          name =~ %r([\[\]]*([^\[\]]+)\]*)
          key = $1 || ''
          after = $' || ''

          if after == ""
            parms[key] = val
          elsif after == "[]"
            (parms[key] ||= []) << val
          elsif after =~ %r(^\[\])
            parms[key] ||= []
            parms[key] << normalize_params({}, after, val)
          else
            parms[key] ||= {}
            parms[key] = normalize_params(parms[key], after, val)
          end
          parms
        end
        
        # ==== Parameters
        # request<IO>:: The raw request.
        # boundary<String>:: The boundary string.
        # content_length<Fixnum>:: The length of the content.
        #
        # ==== Raises
        # ControllerExceptions::MultiPartParseError:: Failed to parse request.
        #
        # ==== Returns
        # Hash:: The parsed request.
        #--
        # from Merb
        # da utilizzare
        def self.parse_multipart(request, boundary, content_length)
          boundary = "--#{boundary}"
          paramhsh = {}
          buf = ""
          input = request
          input.binmode if defined? input.binmode
          boundary_size = boundary.size + EOL.size
          bufsize = 16384
          content_length -= boundary_size
          status = input.read(boundary_size)
          raise ControllerExceptions::MultiPartParseError, "bad content body:\n'#{status}' should == '#{boundary + EOL}'"  unless status == boundary + EOL
          rx = /(?:#{EOL})?#{Regexp.quote(boundary,'n')}(#{EOL}|--)/
          loop {
            head = nil
            body = ''
            filename = content_type = name = nil
            read_size = 0
            until head && buf =~ rx
              i = buf.index("\r\n\r\n")
              if( i == nil && read_size == 0 && content_length == 0 )
                content_length = -1
                break
              end
              if !head && i
                head = buf.slice!(0, i+2) # First \r\n
                buf.slice!(0, 2)          # Second \r\n
                filename = head[FILENAME_REGEX, 1]
                content_type = head[CONTENT_TYPE_REGEX, 1]
                name = head[NAME_REGEX, 1]

                if filename && !filename.empty?
                  body = Tempfile.new(:Merb)
                  body.binmode if defined? body.binmode
                end
                next
              end

              # Save the read body part.
              if head && (boundary_size+4 < buf.size)
                body << buf.slice!(0, buf.size - (boundary_size+4))
              end

              read_size = bufsize < content_length ? bufsize : content_length
              if( read_size > 0 )
                c = input.read(read_size)
                raise ControllerExceptions::MultiPartParseError, "bad content body"  if c.nil? || c.empty?
                buf << c
                content_length -= c.size
              end
            end

            # Save the rest.
            if i = buf.index(rx)
              body << buf.slice!(0, i)
              buf.slice!(0, boundary_size+2)

              content_length = -1  if $1 == "--"
            end

            if filename && !filename.empty?   
              body.rewind
              data = { 
                :filename => File.basename(filename),  
                :content_type => content_type,  
                :tempfile => body, 
                :size => File.size(body.path) 
              }
            else
              data = body
            end
            paramhsh = normalize_params(paramhsh,name,data)
            break  if buf.empty? || content_length == -1
          }
          paramhsh
        end
        
        
    end
    
end