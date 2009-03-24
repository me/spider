require 'rexml/document'
require 'webrick/httputils'
require 'iconv'

module Spider; module WebDAV
    
    class WebDAVController < Spider::Controller
        include HTTPMixin
        CRLF = "\r\l"
        PUT_READ_BUFFER = 16384
        
        def self.default_action
            ''
        end
        
        def init
            @options = {
                :FileSystemCoding			=> "UTF-8",
    			:DefaultClientCoding		=> "UTF-8",
    			:DefaultClientCodingWin		=> "CP932",
    			:DefaultClientCodingMacx 	=> "UTF-8",
    			:DefaultClientCodingUnix 	=> "EUC-JP",
    			:NotInListName				=> %w(.*),
    			:NondisclosureName			=> %w(.ht*)
            }
            super
        end
        
        def request_uri
            normalize_path(@request.env['PATH_INFO'])
		end
		
		def normalize_path(path)
		    path.sub!(/http:\/\/[^\/]+\/#{dispatch_prefix}/, '')
		    path = '/'+path unless !path.empty? && path[0].chr == '/'
		    path.gsub!(/\/+$/, '') unless path == '/'
		    path = Spider::HTTP.urldecode(path)
	    end
	    
	    def map_path_to_request(path)
	        path.sub!(/^\/+/, '')
	        '/'+dispatch_prefix+'/'+path
        end
        
        def vfs
            @vfs ||= init_vfs
        end
        
        def init_vfs
            raise NotImplementedError, "The controller must implement its own vfs method, returning a Spider::WebDAV::VFS::Abstract subclass instance"
        end
        
        def execute(action='', *arguments)
            path = normalize_path(action)
            case @request.env['REQUEST_METHOD']
            when 'OPTIONS'
                do_OPTIONS
            when 'GET'
                do_GET(path)
            when 'PUT'
                do_PUT(path)
            when 'PROPFIND'
                do_PROPFIND(path)
            when 'LOCK'
                do_LOCK(path)
            when 'UNLOCK'
                do_UNLOCK(path)
            when 'MKCOL'
                do_MKCOL(path)
            when 'DELETE'
                do_DELETE(path)
            when 'COPY'
                do_COPY(path)
            when 'MOVE'
                do_MOVE(path)
            when 'HEAD'
                do_GET(path, true)
            end
        end
        
        def do_OPTIONS
    		@response.headers["DAV"] = vfs.locking? ? "2" : "1"
    		@response.headers["MS-Author-Via"] = "DAV"
    	end
    	        
        
        def do_GET(path, just_head=false)
            begin
                properties = vfs.properties(path)
            rescue Errno::ENOENT => e
                raise NotFound.new(path)
            end
            @response.headers['ETag'] = properties.etag
            if (not_modified?(properties.mtime, properties.etag))
                @response.status = Spider::HTTP::NOT_MODIFIED
            elsif (@request.env['RANGE'])
                make_partial_content
            else
                @response.headers['Content-Type'] = properties.content_type
                @response.headers['Content-Length'] = properties.size
                @response.headers['Last-Modified'] = properties.mtime.httpdate
                unless just_head
                    vfs.stream(path, "rb") do |f|
                        $out << f.read
                    end
                end
            end
        end
        
        def do_PUT(path)

    		check_lock(path)

    		if @request.env['RANGE']
    			ranges = WEBrick::HTTPUtils::parse_range_header(@request.env['RANGE']) or
    				raise HTTPStatus.BAD_REQUEST,
    					"Unrecognized range-spec: \"#{@request.env['RANGE']}\""
    		end

    		if !ranges.nil? && ranges.length != 1
    			raise HTTPStatus.NOT_IMPLEMENTED
    		end

    		begin						
    			vfs.iostream(path) do |f|
    				if ranges
    					# TODO: supports multiple range
    					#ranges.each do |range|
    					#	first, last = prepare_range(range, filesize)
    					#	first + req.content_length != last and
    					#		raise HTTPStatus.BadRequest
    					#	f.pos = first
    					#	req.body {|buf| f << buf }
    					#end
    				else
    					begin
    					    # body_str = @request.body.read
    					    #                          debug("PUT BODY_STR: #{body_str}")
    					    #                          f << body_str
    					    @request.body do |buf|
    					        f << buf
					        end
						end
    				end
    			end
    		rescue Errno::ENOENT
    			raise HTTPStatus.CONFLICT
    		rescue Errno::ENOSPC
    		    raise HTTPStatus.WEBDAV_INSUFFICIENT_STORAGE
    		end
    	end
        
        def do_PROPFIND(path)
            depth = @request.env['HTTP_DEPTH']
    		debug "propfind requeset for path #{path}, depth=#{depth}"
    		depth = (depth.nil? || depth == "infinity") ? nil : depth.to_i
    		#raise Forbidden unless depth # deny inifinite propfind

    		begin
    		    b = @request.read_body
    			req_doc = REXML::Document.new b
    		rescue REXML::ParseException
    			raise HTTPStatus.BAD_REQUEST
    		end
            # debug("REQ_DOC:")
            # debug(req_doc)

    		ns = {""=>"DAV:"}
    		req_props = []
    		all_props = %w(creationdate getlastmodified getetag resourcetype getcontenttype getcontentlength displayname)

    		if vfs.locking?
    			all_props += %w(supportedlock lockdiscovery)
    		end	 

    		if @request.read_body.empty? || !REXML::XPath.match(req_doc, "/propfind/allprop", ns).empty?
    			req_props = all_props
    		elsif !REXML::XPath.match(req_doc, "/propfind/propname", ns).empty?
    			# TODO: support propname
    			raise HTTPStatus.NOT_IMPLEMENTED
    		elsif !REXML::XPath.match(req_doc, "/propfind/prop", ns).empty?
    			REXML::XPath.each(req_doc, "/propfind/prop/*", ns){|e|
    				req_props << [e.name, e.namespace]
    			}
    		else
    			raise BadRequest
    		end

    		propfind_response(path, req_props, depth)		
    	end
    	
    	def do_PROPPATCH(path)

    		if not vfs.exist?(path)
    			raise NotFound.new(path)
    		end

    		ret = []
    		ns = {""=>"DAV:"}
    		begin
    			req_doc = REXML::Document.new @request.read_body
    		rescue REXML::ParseException
    			raise BadRequest
    		end
    		REXML::XPath.each(req_doc, "/propertyupdate/remove/prop/*", ns){|e|
    			ps = REXML::Element.new "D:propstat"
    			ps.add_element("D:prop").add_element "D:" + e.name
    			ps << elem_status(Spider::HTTP::FORBIDDEN)
    			ret << ps
    		}
    		REXML::XPath.each(req_doc, "/propertyupdate/set/prop/*", ns){|e|
    			ps = REXML::Element.new "D:propstat"
    			ps.add_element("D:prop").add_element "D:" + e.name
    			begin
    				e.namespace.nil? || e.namespace == "DAV:" or raise Unsupported
    				case e.name
    				when "getlastmodified"
    				    vfs.set_lastmodified(Time.httpdate(e.text), res.filename)
    				else
    					raise Unsupported
    				end
    				ps << elem_status(Spider::HTTP::OK)
    			rescue Errno::EACCES, ArgumentError
    				ps << elem_status(Spider::HTTP::CONFLICT)
    			rescue Unsupported
    				ps << elem_status(Spider::HTTP::FORBIDDEN)
    			rescue
    				ps << elem_status(Spider::HTTP::INTERNAL_SERVER_ERROR)
    			end
    			ret << ps
    		}
    		@response.headers["Content-Type"] = 'text/xml; charset="utf-8"'
    		@response.status = Spider::HTTP::WEBDAV_MULTI_STATUS
    		$out << build_multistat([[request_uri, *ret]]).to_s
    		
    	end
    	
    	def do_LOCK(path)
    		raise HTTPStatus.NOT_IMPLEMENTED unless vfs.locking?
            
            body_str = @request.read_body
    		begin
    			req_doc = REXML::Document.new body_str
    		rescue REXML::ParseException
    			raise BadRequest
    		end

    		if body_str.empty?
    			# Could be a lock refresh
    			matches = parse_if_header

    			matches.each do |match|
    				res = match[0].empty? ? path : match[0]

                    locks = vfs.locked?(res)
                    if (locks)                        
        				locks.each do |lock|
        					vfs.refresh(lock) if if_match(lock, [res, match[1]])
        				end
    				end
    			end

    			raise HTTPStatus.NO_CONTENT
    		else
    			ns = {""=>"DAV:"}
    			item = REXML::XPath.first(req_doc, "/lockinfo", ns)

    			raise BadRequest unless item
    			depth = @request.env['HTTP_DEPTH'] =~ /^infinite$/i ? 'infinite' : 0
    			scope = (v = REXML::XPath.first(item, 'lockscope/*', ns)) && v.name
    			type = (v = REXML::XPath.first(item, 'locktype/*', ns)) && v.name
    			#owner = REXML::XPath.first(item, 'owner/*', ns)
    			owner = REXML::XPath.first(item, 'owner')
    			owner = owner.elements.size > 0 ? owner.elements[1] : owner.text
                if (request_timeout = @request.env['HTTP_TIMEOUT'])
                    timeout_parts = request_timeout.split(/,\s+/)
                    timeout = timeout_parts[0]
                end
                    
                
    			# Try to lock the resource
    			lock = vfs.lock(path, :depth => depth, :scope => scope, :type => type, :owner => owner, :uid => @request.user_id)
    			lock.timeout = timeout if (timeout)
                if not lock
    			    @response.headers["Content-Type"] = 'text/xml; charset="utf-8"'	
    			    @response.status = Spider::HTTP::WEBDAV_MULTI_STATUS	
    				$out << build_multistat([[request_uri, elem_status(Spider::HTTP::WEBDAV_LOCKED)]]).to_s
    				done
    			end
    			
                @response.headers['Lock-Token'] = "<opaquelocktoken:#{lock.token}>" if lock

    			# Respond with propfinding the lockdiscovery property
    			# FIXME: cleanup, the code is repeated from propfind_response
    			propstat = get_propstat(path, ['lockdiscovery'])
    			prop = REXML::XPath.first(propstat, 'D:prop')
    			prop.attributes['xmlns:D'] = 'DAV:'
    			resp = REXML::Document.new << prop
    			@response.headers["Content-Type"] = 'text/xml; charset="utf-8"'
                @response.status = Spider::HTTP::OK
                $stdout << resp.to_s
    			
    		end
    	end

    	def do_UNLOCK(path)
    		raise HTTPStatus.NOT_IMPLEMENTED unless vfs.locking?

    		if not @request.env['HTTP_LOCK_TOKEN'] =~ /<opaquelocktoken:(.*)>/
    			raise BadRequest
    		end

    		if vfs.unlock(path, $1, @request.user_id)
    			raise HTTPStatus.NO_CONTENT
    		else
    			raise Forbidden
    		end
    	end
    	
    	def do_MKCOL(path)

    		check_lock(path)

    		begin
    			vfs.mkdir(path)
    		rescue Errno::ENOENT, Errno::EACCES
    			raise Forbidden
    		rescue Errno::ENOSPC
    			raise HTTPStatus.WEBDAV_INSUFFICIENT_STORAGE
    		rescue Errno::EEXIST
    			raise HTTPStatus.CONFLICT
    		end
    		raise HTTPStatus.CREATED
    	end
    	
    	def do_DELETE(path)
    		lock = check_lock(path)
    		begin
    			vfs.rm(path)

    			vfs.unlock_all(lock.resource) if vfs.locking? and lock
    		rescue Errno::EPERM
    			raise Forbidden
    		end
    		raise HTTPStatus.NO_CONTENT
    	end

    	def do_COPY(path)
    		src, dest, depth, exists_p = cp_mv_precheck(path)
    		debug "copy #{src} -> #{dest}"
    		begin
    			if depth.nil? # infinity
    				vfs.cp(src, dest, true)
    			elsif depth == 0
    				vfs.cp(src, dest, false)
    			end
    		rescue Errno::ENOENT
    			raise HTTPStatus.CONFLICT
    			# FIXME: use multi status(?) and check error URL.
    		rescue Errno::ENOSPC
    			raise HTTPStatus.WEBDAV_INSUFFICIENT_STORAGE
    		end

    		raise exists_p ? HTTPStatus.NO_CONTENT : HTTPStatus.CREATED
    	end

    	def do_MOVE(path)
    		src, dest, depth, exists_p = cp_mv_precheck(path)

    		begin
    			vfs.mv(src, dest)

    			lock = check_lock(src)
    			vfs.unlock_all(lock.resource) if vfs.locking? and lock
    		rescue Errno::ENOENT
    			raise HTTPStatus.CONFLICT
    			# FIXME: use multi status(?) and check error URL.
    		rescue Errno::ENOSPC
    			raise HTTPStatus.WEBDAV_INSUFFICIENT_STORAGE
    		end

    		raise exists_p ? HTTPStatus.NO_CONTENT : HTTPStatus.CREATED
    	end
    	
    	def propfind_response(path, props, depth)

    		if not vfs.exists?(path)
    			raise NotFound.new(vfs.map_path(path))
    		end

    		ret = get_rec_prop(path, ::WEBrick::HTTPUtils.escape(codeconv_str_fscode2utf(request_uri)), props, *[depth].compact)
            @response.headers["Content-Type"] = 'text/xml; charset="utf-8"'
            @response.status = Spider::HTTP::WEBDAV_MULTI_STATUS
    		res =  build_multistat(ret).to_s
    		$stdout << res
    		
    	end
    	
    	def get_rec_prop(path, r_uri, props, depth = 5000)
    	    debug "get prop file='#{path}' depth=#{depth}"
    		ret_set = []
    		depth -= 1
    		ret_set << [r_uri, get_propstat(path, props)]

    		return ret_set if !(vfs.directory?(path) && depth >= 0)

    		vfs.ls(path) {|d|
    			if vfs.directory?("#{path}/#{d}")
    				ret_set += get_rec_prop("#{path}/#{d}",
											::WEBrick::HTTPUtils.normalize_path(
												r_uri+::WEBrick::HTTPUtils.escape(
													codeconv_str_fscode2utf("/#{d}/"))),
											props, depth)
    			else 
    				ret_set << [::WEBrick::HTTPUtils.normalize_path(
    											r_uri+::WEBrick::HTTPUtils.escape(
    												codeconv_str_fscode2utf("/#{d}"))),
    					get_propstat("#{path}/#{d}", props)]
    			end
    		}
    		ret_set
    	end
    	
    	def get_propstat(file, props)
    		propstats = []
    		propstat = REXML::Element.new "D:propstat"
    		propstats << propstat

    		errstat = {}
    		begin
    			st = vfs.properties(file)
    			pe = REXML::Element.new "D:prop"
    			props.each {|pname, pnamespace|
    			    namespace_method_prefix = ''
    			    if (!pnamespace || pnamespace.empty? || pnamespace == 'DAV:')
    			        namespace_method_prefix = 'dav_'
			        elsif (pnamespace =~ /http:\/\/([^\/]+)(\/)?/)
			            namespace_method_prefix = $1.gsub('.', '_')+'_'
		            end
    				begin 
    				    begin
        					if respond_to?("get_prop_#{namespace_method_prefix}#{pname}", true)
        						prop_el = __send__("get_prop_#{namespace_method_prefix}#{pname}", file, st)
        					elsif (st.respond_to?("#{namespace_method_prefix}#{pname}"))
        					    prop_el = gen_element(["#{pname}", pnamespace], st.send("#{namespace_method_prefix}#{pname}"))
    					    else
        						raise Spider::Controller::NotFound.new(file)
        					end
    					rescue VFS::PropertyNotFound => e
    					    raise Spider::Controller::NotFound.new(e.file)
					    end
    					pe << prop_el if prop_el
    				rescue Spider::ControllerMixins::HTTP::HTTPStatus, Spider::ControllerMixins::NotFound => e
    					# FIXME: add to errstat
    					ps = REXML::Element.new("D:propstat")
    					ps << gen_element('D:prop', gen_element("D:#{pname}"))
    					if (e.is_a?(Spider::Controller::NotFound))
    					    ps << elem_status(Spider::HTTP::NOT_FOUND)
					    else
    					    ps << elem_status(e.code, e.status_message)
					    end

    					propstats << ps
    				end
    			}
    			propstat.elements << pe
    			propstat.elements << elem_status(Spider::HTTP::OK)
    		rescue Exception => e
    		    debug("EXCEPTION! #{e}")
    			propstat.elements << elem_status(Spider::HTTP::INTERNAL_SERVER_ERROR)
    		end

    		propstats
    	end
    	
    	def gen_element(elem, child = nil, attrib = {})
    	    if (elem.is_a?(Array))
    	        namespace = elem[1]
    	        elem = elem[0]
	        end
    		e = REXML::Element.new(elem)
            e.add_namespace(namespace) if namespace
    		if child.is_a?(REXML::Element)
    			e << child
    		elsif child
    			e.text = child.to_s
    		end

    		attrib.each {|k, v| e.attributes[k] = v }
    		e
    	end
    	
    	def elem_status(code, message=nil)
    	    message ||= Spider::HTTP.status_messages[code]
    		gen_element("D:status", "#{@request.env['SERVER_PROTOCOL']} #{code} #{message}")
    	end
    	
    	def elem_multistat
    		gen_element "D:multistatus", nil, {"xmlns:D" => "DAV:"}
    	end
    	
    	def build_multistat(rs)
    		m = elem_multistat
    		rs.each {|href, *cont|
    			res = m.add_element "D:response"
    			res.add_element("D:href").text = href
    			cont.flatten.each {|c| res.elements << c}
    		}
    		REXML::Document.new << m
    	end

    	
    	def get_prop_dav_displayname(file, props)
    		gen_element "D:displayname", props.displayname
    	end

    	def get_prop_dav_creationdate(file, props)
    		gen_element "D:creationdate", props.ctime.xmlschema
    	end

    	def get_prop_dav_getlastmodified(file, props)
    		if @request.env['HTTP_USER_AGENT'] and @request.env['HTTP_USER_AGENT'] =~ /gvfs/
    			d = props.mtime.xmlschema
    		else
    			d = props.mtime.httpdate
    		end

    		gen_element "D:getlastmodified", d
    	end
    	def get_prop_dav_getetag(file, props)
    		gen_element "D:getetag", props.etag
    	end

    	def get_prop_dav_resourcetype(file, props)
    		t = gen_element "D:resourcetype"
    		vfs.directory?(file) and t.add_element("D:collection")
    		t
    	end

    	def get_prop_dav_getcontenttype(file, props)
    		gen_element("D:getcontenttype", props.content_type)
    	end

    	def get_prop_dav_getcontentlength(file, props)
    		gen_element "D:getcontentlength", props.size
    	end

    	def get_prop_dav_lockdiscovery(file, props)
    		raise NotFound.new(file) unless vfs.locking?

    		locks = vfs.locked?(file)
    		return nil unless locks

    		discovery = REXML::Element.new('D:lockdiscovery')

    		locks.each do |lock|
    			e = lock_entry('activelock', lock.scope, lock.type)
    			e << gen_element('D:depth', lock.depth)

    			if lock.owner
    				owner = REXML::Element.new('D:owner')
    				if (lock.owner.is_a?(String))
    				    owner.text = lock.owner
				    else
    				    owner << lock.owner
				    end

    				e << owner
    			end

    			if lock.timeout
    				e << gen_element('D:timeout', lock.timeout)
    			end

    			token = REXML::Element.new('D:locktoken') 
    			token << gen_element('D:href', "opaquelocktoken:#{lock.token}")

    			e << token

    			discovery << e
    		end

    		discovery
    	end
    	
    	def get_prop_dav_supportedlock(file, props)
    		e = REXML::Element.new('D:supportedlock')
    		e << lock_entry('lockentry', 'exclusive', 'write')
    		e << lock_entry('lockentry', 'shared', 'write')

    		e
    	end

    	def lock_entry(name, scope, type)
    		entry = REXML::Element.new("D:#{name}")

    		entry << gen_element('D:lockscope', scope ? gen_element("D:#{scope}") : nil)
    		entry << gen_element('D:locktype', type ? gen_element("D:#{type}") : nil)
            
    		entry
    	end
        
        def not_modified?(mtime, etag)
            if ir = @request.env['IF_RANGE']
    			begin
    				if Time.httpdate(ir) >= mtime
    					return true
    				end
    			rescue
    				if ::WEBrick::HTTPUtils::split_header_value(ir).member?(etag)
    					return true
    				end
    			end
    		end

    		if (ims = @request.env['IF_MODIFIED_SINCE']) && Time.parse(ims) >= mtime
    			return true
    		end

    		if (inm = @request.env['IF_NONE_MATCH']) &&
    			 ::WEBrick::HTTPUtils::split_header_value(inm).member?(etag)
    			return true
    		end

    		return false
        end
        
        def make_partial_content(path, properties)
            unless ranges = ::WEBrick::HTTPUtils::parse_range_header(@request.env['RANGE'])
    			@response.status = Spider::HTTP::BAD_REQUEST
    			done
    		end
    		vfs.stream(path, "rb") do |io|
    			if ranges.size > 1
    			    have_range = false
    				time = Time.now
    				boundary = "#{time.sec}_#{time.usec}_#{Process::pid}"
    				@response.headers['Content-Type'] = "multipart/byteranges; boundary=#{boundary}"
    				ranges.each do |range|
    					first, last = prepare_range(range, properties.size)
    					next if first < 0

    					io.pos = first
    					content = io.read(last - first + 1)
    					have_range = true

    					$stdout << "--" << boundary << CRLF
    					$stdout << "Content-Type: #{mtype}" << CRLF
    					$stdout << "Content-Range: #{first}-#{last}/#{filesize}" << CRLF
    					$stdout << CRLF
    					$stdout << content
    					$stdout << CRLF
    				end

                    unless have_range
                        @response.headers.delete('Content-Type')
                        @response.status = Spider::HTTP::REQUESTED_RANGE_NOT_SATISFIABLE
                        done
                    end
    				$stdout << "--" << boundary << "--" << CRLF
    				
    			elsif range = ranges[0]
    				if filesize == 0 and range.first == 0 and range.last == -1 then
    					first, last = 0, 0
    				else
    					first, last = prepare_range(range, properties.size)				
    				end

                    if first < 0
                        @response.status = Spider::HTTP::REQUESTED_RANGE_NOT_SATISFIABLE
                        done
                    end

    				if filesize != 0
    					if last == properties.size - 1
    						d = io.dup
    						d.pos = first

    						content = d.read
    					else
    						io.pos = first
    						content = io.read(last - first + 1)
    					end
    				end

    				@response.headers['Content-Type'] = properties.content_type
    				@response.headers['Content-Range'] = "#{first}-#{last}/#{filesize}"
    				@response.headers['Content-Length'] = properties.size == 0 ? 0 : last - first + 1
    				$out << content
    			else
    			    @response.status = Spider::HTTP::BAD_REQUEST
    			    done
    			end
    		end
        end
        
        def prepare_range(range, filesize)
    		first = range.first < 0 ? filesize + range.first : range.first

    		return -1, -1 if first < 0 || first >= filesize

    		last = range.last < 0 ? filesize + range.last : range.last
    		last = filesize - 1 if last >= filesize

    		return first, last
    	end
    	
    	def check_lock(path)
    		return nil unless vfs.locking?

    		# Get locks on this resource
    		locks = vfs.locked?(path)
    		
    		return nil unless locks && !locks.empty?

    		# Check if the current user is the owner of one of the locks
    		matches = parse_if_header

    		locks.each do |lock|
    			matches.each do |match|
    				return lock if if_match(lock, match)
    			end
    		end

    		raise HTTPStatus.WEBDAV_LOCKED
    	end
    	
    	def parse_if_header
    		return [] unless @request.env['HTTP_IF']

    		matches = []
    		token = '<[^>]*>'
    		@request.env['HTTP_IF'].scan(/(#{token})?(\s*\(((#{token})|\[([^\]]*)\]\s*)+\))+/) do |resource, lst, token|
    			if resource
    				resource = normalize_path(resource.gsub(/(<|>)/, ''))
    			else
    				resource = request_uri
    			end

    			matches << [resource, token.gsub(/(<|>)/, '').gsub(/^opaquelocktoken:/, '')]
    		end

    		matches
    	end
    	
    	def if_match(lock, match)
            # debug("IF MATCH:")
            # debug(lock)
            # debug(match)
            # debug("CONFRONTO #{lock.resource}, #{match[0]}")
            # debug("TOKEN NON CORRISPONDENTE #{lock.token}, #{match[1]}") unless lock.token == match[1]
    		return false unless lock.token == match[1]
    		# debug("UID NON CORRISPONDENTE #{lock.uid}, #{@request.user_id}") unless lock.uid == @request.user_id
    		return false unless lock.uid == @request.user_id
    		# debug("#resource non corrispondente #{lock.resource}, #{match[0]}")  if not match[0].empty? and lock.resource != match[0]
    		return false if not match[0].empty? and lock.resource != match[0]
    		true
    	end
        
        def codeconv_str_fscode2utf(str)
    		return str if @options[:FileSystemCoding] == "UTF-8"
            debug "codeconv str fscode2utf: orig='#{str}'"
    		begin
    			ret = Iconv.iconv("UTF-8", @options[:FileSystemCoding], str).first
    		rescue Iconv::IllegalSequence
    			warn "code conversion fail! #{@options[:FileSystemCoding]}->UTF-8 str=#{str.dump}"
    			ret = str
    		end
    		debug "codeconv str fscode2utf: ret='#{ret}'"
    		ret
    	end
    	
    	def cp_mv_precheck(path)
    	    depth = @request.env['HTTP_DEPTH']
    		depth = (depth.nil? || depth == "infinity") ? nil : depth.to_i
    		depth.nil? || depth == 0 or raise BadRequest
    		debug "copy/move requested. Destination=#{@request.env['HTTP_DESTINATION']}"
    		dest_uri = URI.parse(@request.env['HTTP_DESTINATION'])
            # unless "#{@request.env['HTTP_HOST']}" == "#{dest_uri.host}:#{dest_uri.port}"
            #   raise HTTPStatus.BAD_GATEWAY
            #   # TODO: anyone needs to copy other server?
            # end
    		src	= path
    		dest = normalize_path(@request.env['HTTP_DESTINATION'])

    		src == dest and raise Forbidden

    		if @request.env['REQUEST_METHOD'] == 'MOVE'
    			# MOVE - check lock on source
    			check_lock(src)
    		end

    		check_lock(dest)

    		exists_p = false
    		if vfs.exists?(dest)
    			exists_p = true
    			if @request.env["HTTP_OVERWRITE"] == "T"
    				debug "copy/move precheck: Overwrite flag=T, deleting #{dest}"
    				vfs.rm(dest)
    			else
    				raise HTTPStatus.PRECONDITION_FAILED
    			end
    		end

    		return *[src, dest, depth, exists_p]
    	end
        
        
    end
    
    
end; end