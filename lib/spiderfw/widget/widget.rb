require 'spiderfw/controller/page_controller'
require 'spiderfw/templates/template'
require 'spiderfw/controller/mixins/visual'
require 'spiderfw/widget/widget_attributes'
require 'spiderfw/controller/mixins/http_mixin'
require 'spiderfw/widget/widget_plugin'

module Spider
    
    class Widget < PageController
        include HTTPMixin
        
        attr_accessor :parent
        attr_accessor :request, :scene, :widgets, :template, :id, :id_path, :containing_template, :is_target_ancestor, :is_target_descendant
        attr_reader :attributes, :widget_attributes, :css_classes, :widgets_runtime_content
        attr_accessor :active
        
        @@common_attributes = {
            :id => {}
        }
        
        class << self
            attr_reader :attributes, :scene_attributes
            cattr_reader :tag_name, :plugins
            
            def inherited(subclass)
                subclass.instance_variable_set(:@attributes, attributes.clone)
                subclass.instance_variable_set(:@scene_attributes, @scene_attributes.clone) if @scene_attributes
                subclass.instance_variable_set(:@plugins, @plugins.clone) if @plugins
                subclass.instance_variable_set(:@default_assets, @default_assets.clone) if @default_assets
                @subclasses ||= []
                @subclasses << subclass
                super
                # Do some magic to try and infer the widget's path, considering intermediate superclass callers
                cnt = 0
                s = subclass.superclass
                while s != Spider::Widget
                    if caller[cnt].split(':')[-1] =~ /inherited/
                        cnt += 1
                    end
                    s = s.superclass

                end
                raise "Unable to determine widget file" unless caller[cnt] =~ /(.+):(\d+)$/
                file = $1
                subclass.instance_variable_set("@widget_path", File.dirname(file))
            end

            
            def attribute(name, params={})
                # TODO: implement, this is just a placeholder
                @attributes ||= @@common_attributes.clone
                @attributes[name] = params
            end
            
            def attributes
                @attributes ||= @@common_attributes.clone
            end
            
            def attribute?(name)
                @attributes[name.to_sym]
            end
            
            def i_attribute(name, params={})
                params[:instance_attr] = true
                params[:ruby_name] = name.to_s.gsub('-', '_').to_sym
                params[:set_var] = true
                attribute(name, params)
                attr_reader(params[:ruby_name])
            end
            
            def is_attribute(name, params={})
                params[:instance_attr] = true
                params[:ruby_name] = name.to_s.gsub('-', '_').to_sym
                i_attribute(name, params)
                attr_to_scene(params[:ruby_name])
                attr_reader(params[:ruby_name])
            end
            
            def s_attribute(name, params={})
                attribute(name, params)
                attr_to_scene(name)
            end
            
            def i_attr_accessor(name, params={})
                params[:instance_attr] = true
                params[:ruby_name] = name.to_s.gsub('-', '_').to_sym
                i_attribute(name, params)
                attr_accessor(params[:ruby_name])
            end
            
            def is_attr_accessor(name, params={})
                params[:instance_attr] = true
                params[:ruby_name] = name.to_s.gsub('-', '_').to_sym
                is_attribute(name, params)
                attr_accessor(params[:ruby_name])
            end
            
            def attr_to_scene(*names)
                @scene_attributes ||= []
                names.each{ |name| @scene_attributes << name }
            end
            
            def tag(name)
                self.app.register_tag(name, self)
                @tag_name ||= name
            end
            
            def register_tag(name)
                Spider::Template.register(name, self)
            end
            
            def scene_elements(*list)
                @scene_elements ||= []
                @scene_elements += list
            end
            
            def get_scene_elements
                @scene_elements
            end
            
            def template_path
                return @template_path if @template_path
                @template_path = @widget_path
                @template_path += '/templates' if @template_path && ::File.directory?(@template_path+'/templates')
                @template_path
            end
            
            def default_template(val=nil)
                @default_template = val if val
                @default_template ||= Spider::Inflector.underscore(self.name).split('/')[-1]
                @default_template
            end
            
            def relative_url
                ::File.dirname(@widget_path)
            end
            
            def route_url
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping('/'+self.app.route_url+'/w/'+relative_url)
            end
            
            def pub_url
                return self.app.pub_url
                w = self
                # FIXME! this is a quick hack to make extended templates work
                # but what we need is a better method to handle asset ownership
                #
                # Is it needed anymore?
                # w = w.superclass while w.superclass != Spider::Widget && w.superclass.subclass_of?(Spider::Widget)
                w.route_url+'/pub'
            end
            
            def pub_path
                self.app.pub_path
            end
            
            def runtime_content_tags
                ['sp:attribute']
            end
            
            def parse_content_xml(xml)
                return ["", []] if !xml || xml.strip.empty?
                return parse_content(Hpricot(xml))
            end
            
            # Parses widget content at compile time.
            # Must return a pair consisting of:
            # - runtime content XML
            # - an array of overrides (as Hpricot nodes)
            def parse_content(doc)
                overrides = []
                plugins = []
                to_del = []
                doc.root.each_child do |child|
                    if child.respond_to?(:name)
                        namespace, short_name = child.name.split(':', 2)
                        if (namespace == 'tpl' && (Spider::Template.override_tags.include?(short_name) || self.override_tags.include?(child.name)))
                            overrides << child unless child.is_a?(Hpricot::BogusETag)
                        end
                        if (child.name == 'sp:plugin')
                            plugins << child
                        end
                    end
                end
                overrides.each do |ovr|
                    parse_override(ovr)
                end

                Hpricot::Elements[*overrides].remove
                return [doc.to_s, overrides]
            end
            
            # This method is called on each override node found. The widget must return the node,
            # modifying it if needed.
            def parse_override(el)
                return el
            end
            
            # An array of custom tags that will be processed at compile time by the widget.
            def override_tags
                return []
            end
            
            def add_plugin(name, mod)
                @plugins ||= {}
                @plugins[name] = mod
                @subclasses.each{ |sub| sub.add_plugin(name, mod) } if @subclasses
            end
            
            def plugin(name)
                return nil unless @plugins
                @plugins[name]
            end
            
            def default_asset(ass)
                @default_assets ||= []
                @default_assets << ass
            end
            
            def assets
                r = []
                if @default_assets
                    @default_assets.each do |ass|
                        if ass.is_a?(Hash)
                            ass[:app] ||= self.class.app
                            r << ass
                        else
                            r += Spider::Template.get_named_asset(ass)
                        end
                    end
                end
                if @plugins
                    @plugins.each do |name, mod|
                        r += mod.get_assets
                    end
                end
                r
            end
            
        end
        
        i_attribute :use_template
        attribute :"sp:target-only"
        attribute :class
        # shows the widget's local id in the html instead of the full id
        attribute :keep_id, :type => Spider::Bool, :default => false
        
        default_asset 'jquery'
        default_asset 'spider'
        
        
        def initialize(request, response, scene=nil)
            super
            @is_target = false
            @widgets = {}
            Spider::GetText.in_domain(self.class.app.short_name){
                @attributes = WidgetAttributes.new(self)
            }
            @id_path = []
            @widget_attributes = {}
            @assets = []
            @use_template ||= self.class.default_template
            @css_classes = []
            @widgets_runtime_content = {}
            @widget_procs = {}
            @runtime_overrides = []
            @_plugins = []
        end
        
        def full_id
            @id_path.join('-')
        end
        
        def local_id
            @id_path.last
        end
        
        def attributes=(hash)
            hash = {} unless hash
            hash.each do |k, v|
                @attributes[k] = v
            end
        end
        
        def route_widget
            return nil
        end
        
        def widget_target=(target)
            @widget_target = target
        end
        
        def widget_request_path
            p = @request.path
            i = p.index(@_action) if @_action && !@_action.empty?
            p = p[0..i-2] if i
            p = p.sub(/\/+$/, '')
            return p
        end
        
        def before(action='')
            #Spider.logger.debug("Widget #{self} before(#{action})")
            widget_init(action)
            @before_done = true
            super
        end
        
        def widget_before(action='')
            Spider::GetText.in_domain(self.class.app.short_name){
                widget_init(action)
                if active?
                    prepare_scene(@scene)
                    prepare
                    @before_done = true
                end
            }

        end
        
        
        # Active widgets get prepared. When calling a deep widget, the ancestors will be active.
        def active?
            return true if @active
            return true unless target_mode? || attributes[:"sp:target-only"]
            return true if @is_target || @is_target_ancestor
            return true if @is_target_descendant && !attributes[:"sp:target-only"]
            return false
        end
        
        # When in target mode, a widget will be run only if it is the target, or one of its subwidgets
        def run?
            return true unless target_mode? || attributes[:"sp:target-only"]
            return true if @is_target # || @is_target_ancestor
            return true if @is_target_descendant && !attributes[:"sp:target-only"]
            return false
        end
        
        def active=(val)
            @active = val
        end
        
        def before_done?
            @before_done
        end
        
        # Loads the template and sets the widget attributes
        def widget_init(action='')
            action ||= ''
            if (@request.params['_wa'] && @request.params['_wa'][full_id])
                action = @request.params['_wa'][full_id]
            end
            @_action = action
            @_action_local, @_action_rest = action.split('/', 2)
            unless @template
                @template = load_template(@use_template)
            end
            prepare_template(@template)
            @id ||= @attributes[:id]
            @template.id_path = @id_path
            @template.mode = :widget
            required_groups = {}
            self.class.attributes.each do |k, params|
                if (params[:required])
                    if (params[:required] == true && !@attributes[k])
                        raise ArgumentError, "Attribute #{k} is required by widget #{self}"
                    else
                        if (!@attributes[k] && required_groups[params[:required]] != false)
                            required_groups[params[:required]] ||= []
                            required_groups[params[:required]] << k
                        else
                            required_groups[params[:required]] = false
                        end
                    end 
                end
            end
            required_groups.each do |group_name, attributes|
                next if attributes == false
                raise ArgumentError, "Widget #{self} requires attribute #{attributes.join(' or ')} to be set"
            end
            if (@attributes[:class])
                @css_classes += @attributes[:class].split(/\s+/)
            end
        end

        
        # Recursively instantiates the subwidgets.
        def prepare(action='')
            init_widgets unless @init_widgets_done
            set_widget_attributes
            prepare_widgets
            @template.assets.each do |res|
                res = res.clone
                @assets << res
            end
        end
        
        def init_widgets(template=@template)
            load_widgets(template)
            @widgets.each do |id, w| 
                w.parent = self
                w.is_target_descendant = true if @is_target || @is_target_descendant
                w.active = true if run?
            end
            if !@is_target && @widget_target
                first, rest = @widget_target.split('/', 2)
                @_widget = find_widget(first)
                raise "#{self} couldn't find widget #{first} for target #{@widget_target}" unless @_widget
                @_widget.is_target_ancestor = true
                @_widget.widget_target = rest
                @_widget.is_target = true unless rest
                @_widget_rest = rest || ''
            end
            @init_widgets_done = true
            
        end
        
        # Instantiates this widget's own subwidgets.
        def load_widgets(template=@template)
            if self.class.scene_attributes
                self.class.scene_attributes.each do |name|
                    @scene[name] = instance_variable_get("@#{name}")
                end
            end
            template.request = @request
            template.response = @response
            template.runtime_overrides += @runtime_overrides
            template.init(@scene)
            template.widgets.each do |name, w|
                add_widget(w)
            end
        end
        
        def set_widget_attributes
            @widget_attributes.each do |w_id, a|
                w_id_parts = w_id.to_s.split('.', 2)
                if (w_id_parts[1])
                    w_id = w_id_parts[0]
                    sub_w = w_id_parts[1]
                end
                w_id = w_id.to_sym
                if (@widgets[w_id])
                    if (sub_w)
                        @widgets[w_id].widget_attributes[sub_w] = a
                    else
                        a.each{ |key, value| @widgets[w_id].attributes[key] = value}
                    end
                end
            end
        end
        
        # Runs widget_before on all subwidgets.
        def prepare_widgets
            r = route_widget
            @widgets.each do |id, w|
                if (r && r[0].to_sym == id)
                    act = r[1]
                end
                act ||= ''
                w.widget_before(act)
            end
        end
        
        
        def run(action='')
            @widgets.each do |wname, w|
                w.do_run if w.run?
            end
            if (@parent)
                @parent.after_widget(@id.to_sym)
            end
            @did_run = true
        end
        
        def did_run?
            @did_run
        end
        
        def init_widget_done?
            @init_widget_done
        end
        
        def index
            do_run
            render
        end
        
        def do_run
            Spider::GetText.in_domain(self.class.app.short_name){
                run
            }
        end
        
        def render
            Spider::GetText.in_domain(self.class.app.short_name){
                prepare_scene(@scene)
                set_scene_vars(@scene)
                @template.render(@scene) unless @is_target_ancestor && !@is_target 
            }
        end
        
        def execute(action='', *params)
            Spider.logger.debug("Widget #{self} executing #{action}")
            Spider::GetText.in_domain(self.class.app.short_name){
                widget_execute = @request.params['_we']
                if (@is_target)
                    if (widget_execute)
                        super(widget_execute, *params)
                    else
                        do_run
                        render
                    end
                elsif (@_widget)
                    @_widget.set_action(widget_execute)
                    @_widget.before(@_widget_rest, *params)
                    @_widget.execute(@_widget_rest, *params)
                else
                    super
                end
            }
        end
                        
        def try_rescue(exc)
            if (exc.is_a?(NotFound))
                error("Widget path not found: #{exc.path}")
            else
                raise exc
            end
        end
        
        def params
            p = @request.params['_w']
            return {} unless p
            @id_path.each do |id| 
                p = p[id.to_s]
                return {} unless p
            end
            return p
        end
        
        def has_params?
            !params.empty?
        end
        
        def session(container=@request.session, klass=Hash)
            s = (container['_w'] ||= klass.new)
            @id_path[0..-2].each{ |id| s = (s[id] ||= klass.new) }
            s = (s[@id_path[-1]] ||= klass.new)
            return s
        end
        
        def flash
            s = session(@request.session.flash, Spider::FlashHash)
            return s
        end
        
        def transient_session
            return session(@request.session.transient, Spider::TransientHash)
        end
        
        def create_widget(klass, id,  *params)
            klass = Spider::Template.get_registered_class(klass) unless klass.is_a?(Class)
            params.unshift(@response)
            params.unshift(@request)
            obj = klass.new(*params)
            obj.id = id
            add_widget(obj)
            return obj
        end
        
        def add_widget(widget)
            widget.id_path = @id_path + [widget.id]
            widget.parent = self
            # widget.active = true if @is_target || @active
            @widgets[widget.id.to_sym] = widget
            if (@widgets_runtime_content[widget.id.to_sym])
                @widgets_runtime_content[widget.id.to_sym].each do |content|
                    if (content[:widget])
                        first, rest = content[:widget].split('/', 2)
                        content[:widget] = rest
                        widget.widgets_runtime_content[first.to_sym] ||= [] 
                        widget.widgets_runtime_content[first.to_sym] << content
                    else
                        next if (content[:params] && !check_subwidget_conditions(widget, content[:params]))
                        widget.parse_runtime_content_xml(content[:xml])
                    end
                end
            end
            if (@widget_procs[widget.id.to_sym])
                @widget_procs[widget.id.to_sym].each do |wp|
                    if (wp[:target])
                        widget.with_widget(wp[:target], &wp[:proc])
                    else
                        widget.instance_eval(&wp[:proc])
                    end
                end
            end
            widget
        end
        
        def check_subwidget_conditions
            return false
        end
            
        
        def parse_runtime_content_xml(xml, src_path=nil)
            return if xml.empty?
            doc = Hpricot(xml)
            parse_runtime_content(doc, src_path) if doc.children && doc.root && doc.root.children
        end
        
        def replace_content_vars(str, scene=nil)
            scene ||= @parent && @parent.scene ? @parent.scene : @scene
            res = ""
            Spider::Template.scan_text(str) do |type, val, full|
                case type
                when :plain, :escaped_expr
                    res << full
                when :expr
                    Spider::Template.scan_scene_vars(val) do |vtype, vval|
                        case vtype
                        when :plain
                            res << vval
                        when :var
                            res << scene[vval.to_sym].to_s
                        end
                    end
                end
            end
        end
        
        def parse_runtime_content(doc, src_path=nil)
            doc.search('sp:plugin').each do |plugin|
                # we don't call add_plugin here because the overrides don't have to be added at runtime, since
                # they have already been processed when compiling the instance
                name = plugin['name'].to_sym
                mod = self.class.plugin(name)
                next unless mod
                self.extend(mod)
            end
            # doc.search('sp:plugin').each do |plugin|
            #     name = plugin['name']
            #     mod = self.class.plugin(name)
            #     next unless mod
            #     (class <<self; self; end).instance_eval do
            #         debugger
            #         include mod
            #     end
            #     shadow = (class <<self; self; end)
            #     
            #     debugger
            #     a = 3
            # end
            doc.search('sp:runtime-content').each do |cont|
                w = cont.get_attribute('widget')
                first, rest = w.split('/', 2)
                params = nil
                if (first =~ /(.+)\[(.+)\]/)
                    params = {}
                    parts = $2.split(',')
                    parts.each do |p|
                        key, val = p.split('=')
                        params[key] = val
                    end
                end
                if (w)
                    @widgets_runtime_content[first.to_sym] ||= []
                    @widgets_runtime_content[first.to_sym] << {
                        :widget => rest,
                        :xml => "<sp:widget-content>#{cont.innerHTML}</sp:widget-content>",
                        :params => params
                    }
                end
            end
            doc.search('sp:runtime-content').remove
            
            attributes = doc.search('sp:attribute')
            attributes.each do |a|
                name = a.get_attribute('name').to_sym
                kvs = a.children ? a.children_of_type('sp:value') : []
                if (kvs.length > 0)
                    value = {}
                    kvs.each do |kv|
                        key = kv.get_attribute('key')
                        val = kv.innerText
                        value[key] = val
                    end
                else
                    value = a.get_attribute('value')
                end
                if w = a.get_attribute('widget')
                    @widget_attributes[w] ||= {}
                    @widget_attributes[w][name] = value
                else
                    @attributes[name] = value
                end
            end
            attributes.remove
            doc.search('sp:use-template').each do |templ|
                if templ.has_attribute?('app')
                    owner = Spider.apps_by_path[templ.get_attribute('app')]
                else
                    owner = self
                end
                @template = load_template(templ.get_attribute('src'), nil, owner)
            end
            return doc
        end
        
        
        def assets
            res = @assets.clone + widget_assets
            return res
        end
        
        def widget_assets
            res = []
            @widgets.each do |id, w|
                res += w.assets
            end
            return res
        end

        
        def owner_controller
            w = self
            while (w.is_a?(Widget) && w.template && w.template.owner)
                return nil unless w.containing_template
                w = w.containing_template.owner
            end
            return w
        end
                
        def prepare_scene(scene)
            scene = super
            
            # FIXME: owner_controller should be (almost) always defined
            scene.controller[:request_path] = owner_controller.request_path if owner_controller
            scene.widget[:request_path] = widget_request_path
            scene.widget[:target_only] = attributes[:"sp:target-only"]
            scene.widget[:is_target] = @is_target
            scene.widget[:is_running] = run?
            if (@parent && @parent.respond_to?(:scene) && @parent.scene)
                scene._parent = @parent.scene
            end
            par = @parent
            while par && par.is_a?(Widget)
                par = par.parent
            end
            scene.controller_scene = par.scene if par
            scene.extend(WidgetScene)
            return scene
        end
        
        def set_scene_vars(scene)
            if self.class.scene_attributes # Repeat for new instance variables
                self.class.scene_attributes.each do |name|
                    @scene[name] = instance_variable_get("@#{name}")
                end
            end
        end
        
        def css_class
            return @css_class if @css_class
            supers = self.class.ancestors.select{ |c| c != Spider::Widget && c.subclass_of?(Spider::Widget)}
            @css_class = Inflector.underscore(supers.join('/')).gsub('_', '-').gsub('/', ' ').split(' ').uniq.join(' ')
        end
        
        def css_model_class(model)
            "model-#{model.name.gsub('::', '-')}"
        end
        
        def inspect
            super + ", id: #{@id}"
        end
        
        def to_s
            super + ", id: #{@id}"
        end
        
        def find_widget(name)
            @widgets[name.to_sym] || super
        end
        
        # FIXME: is the same in template. Refactor out.
        def with_widget(path, &proc)
            first, rest = path.split('/', 2)
            @widget_procs[first.to_sym] ||= []
            @widget_procs[first.to_sym] << {:target => rest, :proc => proc }
        end
        
        def add_plugin(name)
            mod = self.class.plugin(name)
            return unless mod
            self.extend(mod)
            @_plugins << mod
            @runtime_overrides << [name, mod.get_overrides, mod.overrides_path]
        end
        
        def controller_action?(method)
            r = super
            return r if r
            @_plugins.each do |pl|
                return r if r = pl.controller_action?(method)
            end
            return false
        end
        
    end
    
    module WidgetScene
        
        def _wt
            self[:widget][:id_path].join('/')
        end
        
        def widget_target
            "#{self[:request][:path]}?_wt=#{self[:widget][:id_path].join('/')}"
        end
        
        def widget_action(name, *params)
            "#{self.widget_target}&_we=#{name}"+(params.map{|p| "&_wp[]=#{p}"}).join('')
        end
        
        def widget_action_u(name, *params)
            "#{self.widget_target}&_we=#{name}"+(params.map{|p| "&_wp%5B%5D=#{p}"}).join('')
        end
        
        def widget_params(params)
            "#{self[:request][:path]}?"+params.map{ |k, v| "_w#{self[:widget][:param]}%5B#{k}%5D=#{v}"}.join('&')
        end
        
        def widget_param(name)
            "_w#{self[:widget][:param]}[#{name}]"
        end
        
        def widget_param_u(name)
            "_w#{self[:widget][:param]}%5B#{name}%5D"
        end
        
    end
    
end
