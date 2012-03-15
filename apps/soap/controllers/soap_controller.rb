require 'soap/rpc/router'
require 'soap/streamHandler'
require 'builder'
begin
    require 'stringio'
    require 'zlib'
rescue LoadError
    warn("Loading stringio or zlib failed.  No gzipped response supported.") if $DEBUG
end

module Spider

    class SoapController < Controller
        include Soap
        include HTTPMixin
        

        class <<self
            attr_accessor :soap_methods, :soap_types

            def soap_options
                @options ||= {:allow_content_encoding_gzip => true}
            end
            
            # Returns the currently used soap registry
            def soap_registry
                @registry ||= SOAP::Mapping::Registry.new
            end

            # Defines a soap method
            def soap(name, params)
                @soap_methods ||= {}
                params[:in] ||= []
                raise ArgumentError, "No return value" unless params[:return]
                [params[:in], params[:out]].each do |ps|
                    next unless ps
                    if (ps.is_a?(Array)) # ruby 1.8
                        ps.each_index do |i|
                            p_name, p = ps[i]
                            ps[i] = [p_name, {:type => p}] unless p.is_a?(Hash)
                            ps[i][1][:type] = ps[i][1][:type]
                        end
                    elsif (ps.is_a?(Hash)) # ordered Hash
                        ps.each do |p_name, p|
                            ps[p_name] = {:type => p} unless p.is_a?(Hash)
                            ps[p_name][:type] = ps[p_name][:type]
                        end
                    end
                end
                params[:return] = {:type => params[:return]} unless params[:return].is_a?(Hash)
                params[:return][:type] = params[:return][:type]
                @soap_methods[name] = params

            end
            
            def soap_type(name, type)
                @soap_types ||= {}
                @soap_types[name] = type
            end

            def soap_namespace(ns=nil)
                @soap_namespace = ns if ns
                @soap_namespace || 'urn:'+self.name.gsub('::', '_')
            end

            def soap_service_name(sn=nil)
                @soap_service_name = sn if sn
                @soap_service_name || self.name.gsub('::', '_')
            end

            def soap_port_name(pn=nil)
                @soap_port_name = pn if pn
                @soap_port_name || self.soap_service_name+'Port'
            end

            def soap_binding_name(bn=nil)
                @soap_binding_name = bn if bn
                @soap_binding_name || self.soap_service_name+'Binding' 
            end

            def params_to_def(params)
                p_def = []
                params.each do |dir, vars|
                    cnt = 0
                    vars = [[:return, vars]] if dir == :return
                    dir = :retval if dir == :return
                    vars.each do |name, p|
                        p_def << [dir.to_s, name.to_s, p[:type].to_s]
                    end
                end
                return p_def

            end

            def type_to_qname(type)
                # the class2soap method is monkey-added in lib/soap, since the stupid SOAP registry does not provide it
                return XSD::QName.new(soap_namespace, type.to_s.split('::')[-1]) if (type < Spider::Soap::SoapType)
                soap_def = soap_registry.class2soap(type)
                return nil unless soap_def
                return soap_def[0].const_get(:Type) if soap_def[0] && soap_def[0].const_get(:Type) # native types
            end
            
            def type_to_soap_name(type)
                qname = type_to_qname(type)
                return qname ? qname.name : nil
            end
            
            def methods_soap_types
                ct = []
                soap_methods.each do |name, params|
                    [:in, :out].each do |dir|
                        next unless params[dir]
                        params[dir].each do |p_name, p_hash|
                            ct += p_hash[:type].collect_soap_types if (p_hash[:type] < Soap::SoapType)
                        end
                    end
                    if (params[:return])
                        ct += params[:return][:type].collect_soap_types if (params[:return][:type] < Soap::SoapType)
                    end
                end
                return ct.uniq
            end


        end

        def before(action='', *params)
            begin
                # Debugger post mortem interferes with the mapping of exceptions
                Debugger.post_mortem = false 
            rescue NameError, RuntimeError
            end
            method = @request.env['REQUEST_METHOD']
            @soap_proxy = SoapProxy.new(self, self.class.soap_methods)
            @soap_registry = SOAP::Mapping::Registry.new
            self.class.methods_soap_types.each do |t|
                t.soap_controller = self.class
                @soap_registry.add(t, t.soap_class, t.soap_factory, t.soap_info)
            end
            unless Spider.runmode == 'devel'
                @soap_registry.add(RuntimeError, SOAP::Mapping::SOAPException, CustomExceptionFactory.new, nil)
            end
            if method == 'POST'
                @router = ::SOAP::RPC::Router.new(self.class.name)
                @router.mapping_registry = @soap_registry
                self.class.soap_methods.each do |name, params|
                    qname = ::XSD::QName.new(self.class.soap_namespace, name.to_s)
                    opt = {}
                    opt[:request_style] = opt[:response_style] = :rpc
                    opt[:request_use] = opt[:response_use] = :encoded
                    @router.add_rpc_operation(@soap_proxy, qname, nil, name.to_s, self.class.params_to_def(params), opt)
                end
            elsif (method == 'GET' && action == 'wsdl')
            else
                raise HTTPStatus.METHOD_NOT_ALLOWED 
                done
            end
            super
            @response.headers['Content-Type'] = "text/xml"
        end

        def execute(action='', *params)
            return super if action == 'wsdl'
            begin
                conn_data = ::SOAP::StreamHandler::ConnectionData.new
                conn_data.receive_string = @request.read_body
                conn_data.receive_contenttype = @request.env['HTTP_CONTENT_TYPE']
                conn_data.soapaction = parse_soapaction(@request.env['HTTP_SOAPACTION'])
                conn_data = @router.route(conn_data)
                setup_res(conn_data)
            rescue Exception => e
                conn_data = @router.create_fault_response(e)
                @response.status = Spider::HTTP::INTERNAL_SERVER_ERROR
                @response.headers['Content-Type'] = conn_data.send_contenttype || "text/xml"
                @response.headers['Transfer-Encoding'] = 'chunked' if conn_data.send_string.is_a?(IO)
                @response.body = conn_data.send_string
            end
        end

        def wsdl
            to_wsdl
        end

        # private

        def parse_soapaction(soapaction)
            if !soapaction.nil? and !soapaction.empty?
                if /^"(.+)"$/ =~ soapaction
                    return $1
                end
            end
            nil
        end

        def setup_res(conn_data)
            @response.headers['Content-Type'] = conn_data.send_contenttype
            if conn_data.is_fault
                @response.status = Spider::HTTP::INTERNAL_SERVER_ERROR
            end
            if outstring = encode_gzip(conn_data.send_string)
                @response.headers['Content-Encoding'] = 'gzip'
                @response.headers['Content-Length'] = outstring.size
                @response.body = outstring
            else
                @response.headers['Transfer-Encoding'] = 'chunked' if conn_data.send_string.is_a?(IO)
                @response.body = conn_data.send_string
            end
        end

        def encode_gzip(outstring)
            unless encode_gzip?
                return nil
            end
            begin
                ostream = StringIO.new
                gz = Zlib::GzipWriter.new(ostream)
                gz.write(outstring)
                ostream.string
            ensure
                gz.close
            end
        end

        def encode_gzip?
            self.class.soap_options[:allow_content_encoding_gzip] and defined?(::Zlib) and
            @request.env['HTTP_ACCEPT_ENCODING'] and
            @request.env['HTTP_ACCEPT_ENCODING'].split(/,\s*/).include?('gzip')
        end

        def to_wsdl
            
            def qtype(type)
                qname = self.class.type_to_qname(type)
                qname.namespace == XsdNs ? 'xsd:'+qname.name : 'typens:'+qname.name
            end

            xm = Builder::XmlMarkup.new(:target => $out, :indent => 2)
            xm.instruct!
            xm.definitions('name' => self.class.soap_service_name,
            'targetNamespace' => self.class.soap_namespace,
            'xmlns:typens'    => self.class.soap_namespace,
            'xmlns:xsd'       => XsdNs,
            'xmlns:soap'      => SoapNs,
            'xmlns:soapenc'   => SoapEncodingNs,
            'xmlns:wsdl'      => WsdlNs,
            'xmlns'           => WsdlNs) do
                
                # Types
                
                xm.types do
                    xm.xsd(:schema, 'targetNamespace' => self.class.soap_namespace) do
                        self.class.methods_soap_types.each do |st|
                            xm.complexType('name' => self.class.type_to_soap_name(st)) do
                                if (st <= SoapArray)                                
                                    xm.complexContent do
                                        xm.restriction('base' => 'soapenc:Array') do
                                            arytype = qtype(st.array_type)
                                            xm.attribute('ref' => 'soapenc:arrayType', 'wsdl:arrayType' => arytype+'[]')
                                        end
                                    end
                                elsif (st <= SoapStruct)
                                   xm.xsd(:all) do
                                       st.elements.each do |el_name, el_type|
                                           elqtype = qtype(el_type)
                                           xm.xsd(:element, 'name'=> el_name.to_s, 'type' => elqtype)
                                       end
                                   end
                                end
                            end
                        end
                    end
                end
                

                # Service
                
                soap_address = request_url
                soap_address += '/' unless soap_address[-1].chr == '/'
                xm.service('name' => self.class.soap_service_name) do
                    xm.port('name' => self.class.soap_port_name, 'binding' => 'typens:'+self.class.soap_binding_name) do
                        xm.soap(:address, 
                        'location' => soap_address)
                    end
                end

                # PortType
                xm.portType('name' => self.class.soap_port_name) do
                    self.class.soap_methods.each do |name, params|
                        name = name.to_s
                        xm.operation('name' => name) do
                            xm.input('message' => 'typens:'+name)
                            xm.output('message' => 'typens:'+name+'Response')
                        end
                    end
                end

                # Messages

                self.class.soap_methods.each do |name, params|
                    xm.message('name' => name) do
                        params[:in].each do |p_name, p|
                            xm.part('name' => p_name, 'type' => qtype(p[:type]))
                        end
                    end
                    xm.message('name' => name.to_s+'Response') do
                        xm.part('name' => 'return', 'type' => qtype(params[:return][:type]).to_s)
                    end
                end

                # Binding

                xm.binding(
                'name' => self.class.soap_binding_name,
                'type' => 'typens:'+self.class.soap_port_name
                ) do
                    xm.soap(:binding, 'style' => 'rpc', 'transport' => SoapHttpTransport)
                    self.class.soap_methods.each do |name, params|
                        xm.operation('name' => name) do
                            xm.soap(:operation, 
                            'soapAction' => self.class.soap_namespace+'/'+name.to_s
                            ) do
                                xm.input do
                                    xm.soap(:body,
                                    'use' => 'encoded',
                                    'namespace' => self.class.soap_namespace,
                                    'encodingStyle' => SoapEncodingNs)
                                end
                                xm.output do
                                    xm.soap(:body,
                                    'use' => 'encoded',
                                    'namespace' => self.class.soap_namespace,
                                    'encodingStyle' => SoapEncodingNs)
                                end
                            end
                        end

                    end
                end
            end

        end

    end



end
