require 'spiderfw/templates/template'
require 'spiderfw/templates/layout'

module Spider; module ControllerMixins
    
    # Mixin for objects using templates
    module Visual
        
        attr_accessor :layout, :dispatcher_layout
        
        def self.included(klass)
           klass.extend(ClassMethods)
           klass.define_annotation(:html) { |k, m, params| k.output_format(m, :html, params) }
           klass.define_annotation(:xml) { |k, m, params| k.output_format(m, :xml, params) }
           klass.define_annotation(:json) { |k, m, params| k.output_format(m, :json, params) }
        end
        
        def before(action='', *params)
            @layout ||= self.class.get_layout(action)
            @layout ||= @dispatcher_layout
            format = nil
            req_format = self.is_a?(Widget) && @is_target && @request.params['_wf'] ? @request.params['_wf'].to_sym : @request.format
            if (req_format)
                format = req_format if self.class.output_format?(@executed_method, req_format)
                if (format)
                    format_params = self.class.output_format_params(@executed_method, format)
                end
                if @executed_method && !format || (format_params && format_params[:widgets] && !@request.params['_wt'])
                    raise Spider::Controller::NotFound.new("#{action}.#{@request.format}") 
                end
            end
            format ||= self.class.output_format(@executed_method)
            format_params ||= self.class.output_format_params(@executed_method, format)
            case format
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
            @executed_format = format
            @executed_format_params = format_params
            super
        end
        
        def execute(action='', *params)
            format_params = @executed_format_params
            if (self.is_a?(Widget) && @is_target && @request.params['_wp'])
                params = @request.params['_wp']
            elsif (format_params && format_params[:params])
                p_first, p_rest = action.split('/')
                params = format_params[:params].call(p_rest) if p_rest
            end
            super(action, *params)
            return unless format_params
            if format_params[:template]
                widget_target = @request.params['_wt']
                widget_execute = @request.params['_we']
                if (widget_target)
                    first, rest = widget_target.split('/', 2)
                    @template ||= init_template(format_params[:template])
                    @_widget = @template.find_widget(first)
                    @_widget.widget_target = rest
                    @_widget_target = @_widget if !rest
                    @_widget.is_target = true if @_widget_target
                    if !rest && widget_execute
                        set_dispatched_object_attributes(@_widget, widget_execute)
                    else
                        set_dispatched_object_attributes(@_widget, 'index')
                        @_widget.widget_before() 
                    end
                end
            end
            if (format_params[:template])
                if (@_widget)
                    if (@_widget_target && widget_execute)
                        @_widget.before(widget_execute)
                        @_widget.execute(widget_execute)
                    else
                        @_widget.run
                        @_widget.render
                    end
                else
                    if (@template)
                        render(@template)  # has been init'ed in before method
                    else
                        render(format_params[:template])
                    end
                end
            end
            if (format_params[:redirect])
                redirect(format_params[:redirect])
            end
            if (@executed_format == :json && format_params[:scene]) # FIXME: move in JSON mixin?
                if (format_params[:scene].is_a?(Array))
                    h = @scene.to_hash
                    res = {}
                    format_params[:scene].each{ |k| res[k] = h[k] }
                    $out << res.to_json
                else
                    $out << @scene.to_json
                end
            end
        end
        
        def load_template(path)
            template = self.class.load_template(path)
            template.owner = self
            template.request = request
            template.response = response
            @template = template
            return template
        end
        
        def template_exists?(name)
            self.class.template_exists?(name)
        end
        
        
        def init_template(path=nil, scene=nil, options={})
            return @template if @template
            scene ||= @scene
            scene ||= get_scene
            if (!path)
                format_params = self.class.output_format_params(@executed_method, @executed_format)
                return unless format_params && format_params[:template]
                path = format_params[:template]
            end
            template = load_template(path)
            template.init(scene)
            @template = template
            return template
        end
        
        def render_layout(path, content={})
            layout = self.class.load_layout(path)
            layout.request = @request
            layout.render(content)
        end
        
        def init_layout(layout)
            l = layout.is_a?(Layout) ? layout : self.class.load_layout(layout)
            l.owner = self
            l.request = request
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
                template = init_template(path, scene, options)
            end
            if (@request.params['_action'])
                template._widget_action = @request.params['_action']
            else
                template._action_to = options[:action_to]
                template._action = @controller_action
            end
            template.exec
            unless (@_partial_render) # TODO: implement or remove
                chosen_layouts = options[:layout] || @layout
                chosen_layouts = [chosen_layouts] if chosen_layouts && !chosen_layouts.is_a?(Array)
                if (chosen_layouts)
                    t = template
                    l = nil
                    (chosen_layouts.length-1).downto(0) do |i|
                        l = init_layout(chosen_layouts[i])
                        l.template = t
                        t = l
                    end
                    l.render(scene)
                else
                    template.render(scene)
                end
            end
            return template
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
        
        
        module ClassMethods
            
            def output_format(method, format=nil, params={})
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
            
            def output_format?(method, format)
                return false unless @output_formats
                @output_formats[method] && @output_formats[method].include?(format)
            end
            
            def output_format_params(method, format)
                return nil unless @output_format_params && @output_format_params[method]
                return @output_format_params[method][format]
            end
            
            def default_output_format(format)
                @default_output_format = format if format
                @default_output_format
            end

            
            def layouts
                @layouts ||= []
            end
            
            def layout(name, params={})
                @layouts ||= []
                @layouts << [name, params]
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
                layouts.each do |try|
                    name, params = try
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
                
            
            def load_template(name)
                # FIXME: use Template's real_path
                if (name[0..5] == 'SPIDER' || name[0..3] == 'ROOT')
                    name.sub!('SPIDER', $SPIDER_PATH).sub!('ROOT', Spider.paths[:root])
                    t = Spider::Template.new(name+'.shtml')
                else
                    template_paths.each do |path|
                        full = path+'/'+name+'.shtml'
                        next unless File.exist?(full)
                        t = Spider::Template.new(full)
                        break
                    end
                end
                if (t)
                    t.request = @request
                    t.response = @response
                    return t
                end
                raise "Template #{name} not found"
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
                if (path.is_a?(Symbol))
                    path = Spider::Layout.named_layouts[path]
                end
                path = Spider::Template.real_path(path+'.layout', layout_path, self)
                return Spider::Layout.new(path)
            end
            
            
            def current_default_template
                Spider::Inflector.underscore(self.to_s.split('::')[-1])
            end
            
        end
        
    end
    
    
end; end