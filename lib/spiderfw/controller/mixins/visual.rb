require 'spiderfw/templates/template'
require 'spiderfw/templates/layout'

module Spider; module ControllerMixins
    
    # Mixin for objects using templates
    module Visual
        attr_reader :template
        attr_accessor :layout, :dispatcher_layout
        
        def self.included(klass)
           klass.extend(ClassMethods)
           klass.extend(OutputFormatMethods)
           define_format_annotations(klass)
        end
        
        def self.define_format_annotations(klass)
            klass.define_annotation(:html) { |k, m, params| k.output_format(m, :html, params) }
            klass.define_annotation(:xml) { |k, m, params| k.output_format(m, :xml, params) }
            klass.define_annotation(:json) { |k, m, params| k.output_format(m, :json, params) }
            klass.define_annotation(:text) { |k, m, params| k.output_format(m, :text, params) }
        end
        
        def before(action='', *params)
            @layout ||= self.class.get_layout(action)
            @layout ||= @dispatcher_layout
            format = nil
            req_format = self.is_a?(Widget) && @is_target && @request.params['_wf'] ? @request.params['_wf'].to_sym : @request.format
            if (req_format && self.class.output_formats[@executed_method])
                format = req_format if self.class.output_format?(@executed_method, req_format)
                if (format)
                    format_params = self.class.output_format_params(@executed_method, format)
                end
                if @executed_method && !format || (format_params && format_params[:widgets] && !target_mode?)
                    #raise Spider::Controller::NotFound.new("#{action}.#{@request.format}") 
                end
            end
            format ||= self.class.output_format(@executed_method)
            format_params ||= self.class.output_format_params(@executed_method, format)
            output_format_headers(format)
            @executed_format = format
            @executed_format_params = format_params
            super
        end
        
        def output_format_headers(format)
            case format
            when :text
                content_type('text/plain')
            when :json
                if (Spider.runmode == 'devel' && @request.params['_text'])
                    content_type('text/plain')
                else
                    content_type('application/json')
                end
            when :js
                content_type('application/x-javascript')
            when :html
                content_type('text/html')
            when :xml
                content_type('text/xml')
            end
        end
        
        def visual_params
            @visual_params ||= {}
        end
        
        def target_mode?
            !@request.params['_wt'].nil? && !@request.params['_wt'].empty?
        end
        
        def init_widgets(template, layout=nil)
            widget_target = @request.params['_wt']
            widget_execute = @request.params['_we']
            if (widget_target && !@rendering_error)
                first, rest = widget_target.split('/', 2)
                @_widget = template.find_widget(first)
                @_widget = layout.find_widget(first) if !@_widget && layout
                raise Spider::Controller::NotFound.new("Widget #{widget_target}") unless @_widget
                @_widget.is_target = true unless rest
                @_widget.set_action(widget_execute) if widget_execute
                @_widget.is_target_ancestor = true
                @_widget.widget_target = rest
            end
            template.do_widgets_before
            layout.do_widgets_before if layout
            if @_widget
                @_widget.before(widget_execute) if @_widget.is_target
                @_widget.execute
                done
            end
        end
        
        def execute(action='', *params)
            @visual_params = @executed_format_params
            @is_target = false if target_mode? && !self.is_a?(Spider::Widget)
            if (self.is_a?(Widget) && @is_target && @request.params['_wp'])
                params = @request.params['_wp']
            elsif (@visual_params.is_a?(Hash) && @visual_params[:params])
                p_first, p_rest = action.split('/')
                params = format_params[:params].call(p_rest) if p_rest
            end
            super(action, *params)
            return unless @visual_params.is_a?(Hash)
            @template = get_template if !@template && @visual_params[:template]
            init_widgets(@template) if @template
            if @visual_params[:call]
                meth = self.method(@visual_params[:call])
                args = params + @executed_method_arguments
                arity = meth.arity
                arity = (-arity + 1) if arity < 0
                args = arity == 0 ? [] : args[0..(arity-1)]
                args = [nil] if meth.arity == 1 && args.empty?
                send(@visual_params[:call], *args)
            end
            if @visual_params[:template] && !@_widget && !done?
                if (@template)
                    render(@template, @visual_params)  # has been init'ed in before method
                else
                    render(@visual_params[:template], @visual_params)
                end
            end
            if @visual_params[:redirect]
                redirect(@visual_params[:redirect])
            end
            if @executed_format == :json && (@visual_params[:scene] || @visual_params[:return]) # FIXME: move in JSON mixin?
                if (@visual_params[:return])
                    $out << @visual_params[:return].to_json
                elsif (@visual_params[:scene].is_a?(Array))
                    h = @scene.to_hash
                    res = {}
                    @visual_params[:scene].each{ |k| res[k] = h[k] }
                    $out << res.to_json
                else
                    $out << @scene.to_json
                end
            end
        end
        
        def load_template(path, cur_path=nil, owner=nil, search_paths=nil)
            template = self.class.load_template(path, cur_path, owner, search_paths)
            prepare_template(template)
            @template = template
            return template
        end
        
        def prepare_template(template)
            template.owner = self
            template.request = request
            template.response = response
        end
        
        def template_exists?(name)
            self.class.template_exists?(name)
        end
        
        
        def get_template(path=nil, scene=nil, options={})
            return @template if @template && @loaded_template_path == path
            scene ||= @scene
            scene ||= get_scene
            if (!path)
                format_params = @visual_params || self.class.output_format_params(@executed_method, @executed_format)
                return unless format_params && format_params[:template]
                path = format_params[:template]
                options = format_params.merge(options)
            end
            template = load_template(path)
            init_template(template, options)            
            @template = template
            @loaded_template_path = path

            return template
        end
        
        def init_template(template=nil, options={})
            return get_template(template, nil, options) unless template.is_a?(Spider::Template)
            prepare_template(template) unless template.owner # if called directly
            template.init(scene)
            if (@request.params['_action'])
                template._widget_action = @request.params['_action']
            else
                template._action_to = options[:action_to]
                template._action = @controller_action
            end
            return template
        end
                
        def init_layout(layout)
            l = layout.is_a?(Layout) ? layout : self.class.load_layout(layout)
            prepare_template(l)
            return l
        end
        
        def render(path=nil, options={})
            scene = options[:scene] || @scene
            scene ||= get_scene
            scene = prepare_scene(scene)
            request = options[:request] || @request
            response = options[:response] || @response
            if (path.is_a?(Spider::Template))
                template = path
            else
                template = get_template(path, scene, options)
            end
            layout = nil
            chosen_layouts = options[:layout] || @layout
            chosen_layouts = [chosen_layouts] if chosen_layouts && !chosen_layouts.is_a?(Array)
            if (chosen_layouts)
                t = template
                layout = nil
                (chosen_layouts.length-1).downto(0) do |i|
                    layout = init_layout(chosen_layouts[i])
                    layout.template = t
                    t = layout
                end
            end
            layout.init(scene) if layout
            init_widgets(template, layout)
            return template if done?
            if layout
                layout.render(scene)
            else
                template.render(scene)
            end
            return template
        end
        
        def find_widget(name)
            @template.find_widget(name)
        end
        
        # Callback executed after child widgets are run. Useful to postprocess widgets data.
        # id is the child widget id, as a symbol.
        def after_widget(id)
        end
        
        
        
        def dispatched_object(route)
            obj = super
            if (obj.is_a?(Visual))
                set_layout = @layout || @dispatcher_layout
                if set_layout
                    set_layout = [set_layout] unless set_layout.is_a?(Array)
                    set_layout.map{ |l| self.class.load_layout(l) }
                    obj.dispatcher_layout = set_layout
                end
            end
            return obj
        end
        
        def try_rescue(exc)            
            exc.uuid = UUIDTools::UUID.random_create.to_s if exc.respond_to?(:uuid=)
            format = self.class.output_format(:error) || :html
            return super unless @executed_format == :html
            return super unless action_target?
            return super if target_mode?
            output_format_headers(format)
            if (exc.is_a?(Spider::Controller::NotFound))
                error_page = '404'
                @scene.error_msg = _("Page not found")
                @scene.email_subject = @scene.error_msg
            else
                error_page = 'error_generic'
                if (exc.is_a?(HTTPMixin::HTTPStatus))
                    @scene.error_msg = exc.status_message
                end
                @scene.error_msg = _("An error occurred")
                @scene.email_subject = @scene.error_msg
            end
            
            if (exc.respond_to?(:uuid))
                exc.extend(UUIDExceptionMessage)
                @scene.exception_uuid = exc.uuid
                @scene.email_subject += " (#{exc.uuid})"
            end
            @scene.admin_email = Spider.conf.get('site.tech_admin.email')
            if (Spider.runmode == 'devel')
                begin
                    @scene.devel = true
                    @scene.backtrace = build_backtrace(exc)
                    client_editor = Spider.conf.get('client.text_editor')
                    prefix = 'txmt://open?url=' if client_editor == 'textmate'
                    @scene.exception = "#{exc.class.name}: #{CGI.escapeHTML(exc.message)}"
                    cnt = 0
                    @scene.backtrace.each do |tr|
                        tr[:index] = cnt
                        cnt += 1
                        suffix = ''
                        suffix = "&line=#{tr[:line]}" if (client_editor == 'textmate')
                        tr[:link] = "#{prefix}file://#{tr[:path]}#{suffix}"
                    end
                    @scene.request_params = @request.params.inspect
                    @scene.session = @request.session.inspect
                rescue => exc2
                    super(exc)
                end
            end
            @rendering_error = true
            @scene.__is_error_page = true
            if Spider.const_defined?(:Messenger) && Spider.conf.get('errors.send_email') && Spider.conf.get('site.tech_admin.email')
                begin
                    send_error_email(exc)
                rescue => exc2
                end
            end
            render "errors/#{error_page}", :layout => "errors/error"
            super
        end
        
        def send_error_email(exc)
            scene = Spider::Scene.new
            scene.request = @request.env
            scene.exception = exc
            subject = _("Site error")
            if Spider.conf.get('orgs.default.name')
                subject = "#{Spider.conf.get('orgs.default.name')} - #{subject}"
            elsif @request.env.key?('HTTP_HOST')
                subject = "#{@request.env['HTTP_HOST']} - #{subject}" 
            end
            headers = {'Subject' => subject}
            from = Spider.conf.get('orgs.default.auto_from_email') || Spider.conf.get('site.tech_admin.email')
            Spider::Messenger::MessengerHelper.send_email(
                self.class, 'error', scene, from, Spider.conf.get('site.tech_admin.email'), headers
            )
        end
        
        def build_backtrace(exc)
            bt = []
            if Object.const_defined?(:Debugger) && Debugger.started? && Debugger.post_mortem?
                use_debugger = true
                context = exc.__debug_context
                ct_first_file = context.frame_file(0)
                ct_first_line = context.frame_line(0)
                e_file, e_line, e_method = exc.backtrace[0].split(':')
                if (e_file != ct_first_file || e_line.to_i != ct_first_line)
                    use_debugger = false
                end
            end
            if (!use_debugger)
                exc.backtrace.each do |trace_line|
                    str = trace_line
                    file_path, line, method = trace_line.split(':')
                    bt << {:text => str, :path => file_path, :line => line, :method => method}
                end
                return bt
            end
            context = exc.__debug_context
            0.upto(Debugger.current_context.stack_size - 2) do |i|
                begin
                    file = context.frame_file(i)
                    line = context.frame_line(i)
                    klass = context.frame_class(i)
                    method = context.frame_method(i)
                    args = context.frame_args(i)
                    locals = context.frame_locals(i)
                    frame_self = context.frame_self(i)
                    dest = context.frame_self(i-1) unless i == 0
                    ex_method = context.frame_method(i-1) unless i == 0
                    in_method = context.frame_method(i)
    #s                ex_args = context.frame_args(i+1)
                    str = "#{file}:#{line}: in #{in_method}"
                    #str = exc.backtrace[i]
                
                    self_str = frame_self
    #                self_str = "#<#{frame_self.class}:#{frame_self.object_id}>"
                    if (dest)
                        dest_str = dest.is_a?(Class) ? dest.inspect : "#<#{dest.class}:#{dest.object_id}>"
                    else
                        dest_str = ""
                    end
                    self_str = frame_self.is_a?(Class) ? frame_self.inspect : "#<#{frame_self.class}:#{frame_self.object_id}>"
                    if (i == -1)
                        info = ""
                    else
                        # if (frame_self == dest)
                        #                        info = "#{dest_str}"
                        #                    else
                        #                        info = "#{self_str}: #{dest_str}"
                        #                    end
                        info = "#{self_str}: #{dest_str}"
                        info += ".#{ex_method}("
                        info += args.map{ |arg|
                            val = locals[arg]
                            arg_str = "#{arg}##{val.class}"
                            val_str = nil
                            if (val.is_a?(String))
                                if (val.length > 20)
                                    val_str = (val[0..20]+'...').inspect
                                else
                                    val_str = val.inspect
                                end
                            elsif (val.is_a?(Symbol) || val.is_a?(Fixnum) || val.is_a?(Float) || val.is_a?(BigDecimal) || val.is_a?(Date) || val.is_a?(Time))
                                val_str = val.inspect
                            end
                            arg_str += "=#{val_str}" if val_str
                            arg_str
                        }.join(', ')
                        info += ")"
                    end
                    if (Spider.conf.get('devel.trace.show_instance_variables'))
                        iv = {}
                        frame_self.instance_variables.each{ |var| iv[var] = frame_self.instance_variable_get(var) }
                        iv.reject{ |k, v| v.nil? }
                    end
                    locals = nil unless Spider.conf.get('devel.trace.show_locals')
                    bt << {
                        :text => str, :info => info, 
                        :path => File.expand_path(file), :line => line, :method => method, :klass => klass, :locals => locals,
                        :instance_variables => iv
                    }
                rescue => exc2
                end
            end
            return bt
        end
        
        module OutputFormatMethods
           
            def output_format(method=nil, format=nil, params={})
                return @default_output_format unless method
                @output_formats ||= {}
                @output_format_params ||= {}
                if format
                    @output_formats[method] ||= []
                    @output_formats[method] << format
                    @output_format_params[method] ||= {}
                    @output_format_params[method][format] = params
                    controller_actions(method)
                    return format
                end
                return @default_output_format unless @output_formats[method] && @output_formats[method][0]
                return @output_formats[method][0]
            end
            
            def output_formats
                @output_formats || {}
            end
            
            def output_format?(method, format)
                return false unless @output_formats
                @output_formats[method] && @output_formats[method].include?(format)
            end
            
            def output_format_params(method, format)
                return nil unless @output_format_params && @output_format_params[method]
                fp = @output_format_params[method][format]
                return nil if fp == true
                return fp
            end
            
            def default_output_format(format)
                @default_output_format = format if format
                @default_output_format
            end 
            
        end
        
        module ClassMethods

            
            def layouts
                @layouts ||= []
            end
            
            def layout_params
                @layout_params ||= {}
            end
            
            def layout(name, params={})
                self.layouts << name
                self.layout_params[name] = params
            end
            
            
            def no_layout(check)
                @no_layout ||= []
                @no_layout << check
            end
            
            def get_layout(action)
                if (@no_layout)
                    @no_layout.each do |check|
                        return nil if check_action(action, check)
                    end
                end
                action = (action && !action.empty?) ? action.to_sym : self.default_action
                layouts.each do |name|
                    params = @layout_params[name]
                    if (params[:for])
                        next unless check_action(action, params[:for])
                    end
                    if (params[:except])
                        next if check_action(action, params[:except])
                    end
                    return name
                end
                return nil
            end
            
            def template_paths
                unless respond_to?(:template_path)
                    raise NotImplementedError, "The template_path class method must be implemented by object using the Visual mixin, but #{self} does not"
                end
                paths = [template_path]
                s = self.superclass
                while (s && s.subclass_of?(Visual) && s.app && s.respond_to?(:template_path))
                    paths << s.template_path
                    s = s.superclass
                end
                return paths
            end
                
            
            def load_template(name, cur_path=nil, owner=nil, search_paths=nil)
                owner ||= self
                search_paths ||= template_paths
                resource = Spider::Template.find_resource(name, cur_path, owner, search_paths)
                raise "Template #{name} not found" unless resource && resource.path
                t = Spider::Template.new(resource.path)
                t.owner_class = self
                t.definer_class = resource.definer
                return t

            end
                        
            def template_exists?(name, paths=nil)
                if (name[0..5] == 'SPIDER' || name[0..3] == 'ROOT')
                    name.sub!('SPIDER', $SPIDER_PATH).sub!('ROOT', Spider.paths[:root])
                    return true if File.exist?(name)
                end
                paths ||= template_paths
                paths.each do |path|
                    full = path+'/'+name+'.shtml'
                    return true if File.exist?(full)
                end
                return false
            end
            
            def load_layout(path)
                unless respond_to?(:layout_path)
                    raise NotImplementedError, "The layout_path class method must be implemented by object using the Visual mixin, but #{self} does not"
                end
                params = self.layout_params[path] || {}
                if (path.is_a?(Symbol))
                    path = Spider::Layout.named_layouts[path]
                end
                resource = Spider::Template.find_resource(path+'.layout', layout_path, self)
                layout = Spider::Layout.new(resource.path)
                layout.definer_class = resource.definer
                layout.asset_set = params[:assets] if params[:assets]
                layout
            end
            
            
            def current_default_template
                Spider::Inflector.underscore(self.to_s.split('::')[-1])
            end
            
            def assets
                []
            end
            
        end
        
    end
    
    
end; end
