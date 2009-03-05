require 'base64'
require 'uuid'
require 'digest/md5'
require 'macaddr'

module Spider; module Helpers
    
    module HTTP
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        def redirect(url, code=Spider::HTTP::MOVED_PERMANENTLY)
            debug "REDIRECTING TO #{url}"
            @response.status = code
            @response.headers["Location"] = url
            @response.headers.delete("Content-Type")
            @response.headers.delete("Set-Cookie")
            done
        end
        
        def before(action='', *arguments)
            # Redirect to url + slash if controller is called without action
            if (action == '' && @request.env['PATH_INFO'][-1].chr != '/')
                dest = @request.env['PATH_INFO']+'/'
                if (@request.env['QUERY_STRING'] && !@request.env['QUERY_STRING'].empty?)
                    dest += '?'+@request.env['QUERY_STRING']
                end
                redirect(dest)
            end
            super
        end
        
        def try_rescue(exc)
            if (exc.is_a?(HTTPStatus))
                @response.status = exc.code
                done
                #raise
            else
                super
            end
        end
        
        def challenge_basic_auth()
            realm ||= http_auth_realm
            realm ||= 'Secure Area'
            @response.headers["WWW-Authenticate"] = "Basic realm=\"#{realm}\""
            @response.status = Spider::HTTP::UNAUTHORIZED
            render('errors/unauthorized') if self.is_a?(Visual)
            done
        end
        
        def check_basic_auth(authenticator)
            if (@request.env['HTTP_AUTHORIZATION'] =~ /Basic (.+)/)
                pair = Base64.decode64($1)
                user, pass = pair.split(':')
                return authenticator.authenticate(user, pass)
            end
        end
        
        def challenge_digest_auth(realm=nil)
            realm ||= http_auth_realm
            realm ||= 'Secure Area'
            
            # nonce
            now = "%012d" % @request.request_time
            pk  = Digest::MD5.hexdigest("#{now}:#{digest_instance_key}")[0,32]
            nonce = [now + ":" + pk].pack("m*").chop # it has 60 length of chars.
            
            opaque = [UUID.new.generate].pack("m*").chop
            header = "Digest realm=\"#{realm}\", qop=\"auth\", nonce=\"#{nonce}\", opaque=\"#{opaque}\""
            @response.headers['WWW-Authenticate'] = header
            @response.status = Spider::HTTP::UNAUTHORIZED
            done
        end
        
        def check_digest_auth(authenticator)
            # TODO: implement opaque, auth-int
            if (@request.env['HTTP_AUTHORIZATION'] =~ /Digest (.+)/)
                parts = $1.split(',')
                params = {}
                parts.each do |p|
                    k, v = p.strip.split('=')
                    v = v.sub(/^"+/, '').sub(/"+$/, '')
                    params[k.downcase] = v
                end
                ['username', 'realm', 'nonce', 'uri', 'cnonce', 'qop', 'nc', 'response', 'opaque'].each{ |k| return unless params[k] }
                pub_time, pk = params['nonce'].unpack("m*")[0].split(":", 2)
                return unless pub_time && pk
                return unless Digest::MD5.hexdigest("#{pub_time}:#{digest_instance_key}")[0,32] == pk
                diff_time = @request.request_time.to_i - pub_time.to_i
                return if diff_time < 0
                return if diff_time > Spider.conf.get('http.nonce_life')
                user = authenticator.find(params['username'], params['realm'])
                return unless user
                ha1 = user.ha1
                return unless ha1
                ha2 = Digest::MD5.hexdigest("#{@request.env['REQUEST_METHOD']}:#{params['uri']}")
                if (params['qop'] == "auth" || params['qop'] == "auth-int")
                    param2 = ['nonce', 'nc', 'cnonce', 'qop'].map{|key| params[key] }.join(':')
                    response = Digest::MD5.hexdigest([ha1, param2, ha2].join(':'))
                else
                    response = Digest::MD5.hexdigest([ha1, params['nonce'], ha2].join(':'))
                end
                return unless response == params['response']
                return user.uid
            end
        end
        
        def digest_instance_key
            Digest::MD5.hexdigest("#{Mac.addr}:plaw15x857m4p671")
        end
        
        
        
        def http_auth_realm=(val)
            @http_auth_realm = val
        end
        
        def http_auth_realm
            @http_auth_realm || self.class.http_auth_realm
        end
        
        module ClassMethods

            def http_auth_realm(val=nil)
                @http_auth_realm = val if val
                @http_auth_realm
            end
        end
        
        class HTTPStatus < RuntimeError
            
            class << self
                
                def method_missing(meth, *args)
                    if (Spider::HTTP::StatusCodes.const_defined?(meth))
                        return self.new(Spider::HTTP::StatusCodes.const_get(meth))
                    end
                    super
                end
                
            end
            
            attr_reader :code
            
            def initialize(code)
                @code = code
            end
            
            def status_message
                Spider::HTTP.status_messages[@code]
            end
        end
        
        class HTTPRequest
            
            
            
        end
        
        
    end
    
    
    
end; end