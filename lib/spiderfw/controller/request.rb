module Spider
    
    class Request
        attr_accessor :params, :cookies, :env, :protocol, :format, :extension, :session, :user_id
        @@multipart_regexp = /\Amultipart\/form-data.*boundary=\"?([^\";,]+)/n.freeze
        
        
        def initialize(protocol, env, body)
            Spider::Logger.debug("REQUEST:")
            Spider::Logger.debug(env)
#            Spider::Logger.debug(b)
            @env = env
            if (env['REQUEST_METHOD'] == 'POST')
                @params = parse_query(body.read)
            else
                @params = parse_query(env['QUERY_STRING'])
            end
            @cookies = parse_query(env['HTTP_COOKIE'], ';')
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
        def parse_query(qs, d = '&;')
          return (qs||'').split(/[#{d}] */n).inject({}) { |h,p| 
            key, value = unescape(p).split('=',2)
            normalize_params(h, key, value)
          }
        end
        
        # ==== Parameters
        # s<String>:: String to URL escape.
        #
        # ==== returns
        # String:: The escaped string.
        #--
        # from Merb        
        def escape(s)
           s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
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
        def unescape(s)
          s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
            [$1.delete('%')].pack('H*')
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
        def normalize_params(parms, name, val=nil)
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
        def parse_multipart(request, boundary, content_length)
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