require 'spiderfw/controller/page_controller'
require 'spiderfw/templates/template'
require 'spiderfw/controller/mixins/visual'
require 'spiderfw/widget/widget_attributes'
require 'spiderfw/controller/mixins/http_mixin'

module Spider
    
    class Widget < PageController
        include HTTPMixin
        
        attr_accessor :parent
        attr_accessor :request, :scene, :widgets, :template, :id, :id_path, :containing_template, :is_target
        attr_reader :attributes, :widget_attributes, :css_classes
        
        @@common_attributes = {
            :id => {}
        }
        
        class << self
            attr_reader :attributes, :scene_attributes
            
            def inherited(subclass)
                subclass.instance_variable_set(:@attributes, attributes.clone)
                subclass.instance_variable_set(:@scene_attributes, @scene_attributes.clone) if @scene_attributes
            end
            
            def attribute(name, params={})
                # TODO: implement, this is just a placeholder
                @attributes ||= @@common_attributes.clone
                @attributes[name] = params
            end
            
            def attributes
                @attributes ||= @@common_attributes.clone
            end
            
            def i_attribute(name, params={})
                params[:instance_attr] = true
                params[:set_var] = true
                attribute(name, params)
            end
            
            def is_attribute(name, params={})
                params[:instance_attr] = true
                i_attribute(name, params)
                attr_to_scene(name)
            end
            
            def i_attr_accessor(name, params={})
                params[:instance_attr] = true
                i_attribute(name, params)
                attr_accessor(name)
            end
            
            def is_attr_accessor(name, params={})
                params[:instance_attr] = true
                is_attribute(name, params)
                attr_accessor(name)
            end
            
            def attr_to_scene(*names)
                @scene_attributes ||= []
                names.each{ |name| @scene_attributes << name }
            end
            
            def tag(name)
                self.app.register_tag(name, self)
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
            
            def template_path_parent(val=nil)
                # FIXME: damn! find a better way!
                @template_path_parent = val if val
                return @template_path_parent || app.path+'/widgets'
            end
            
            def template_path
                p = template_path_parent+'/'+Inflector.underscore(self.to_s.split('::')[-1])
                return p+'/templates' if (File.exist?(p+'/templates'))
                return p
            end
            
            def default_template
                Spider::Inflector.underscore(self.name).split('/')[-1]
            end
            
            def relative_url
                template_path[template_path_parent.length+1..-1]
            end
            
            def route_url
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping('/'+self.app.route_url+'/w/'+relative_url)
            end
            
            def pub_url
                return self.app.pub_url
                w = self
                # FIXME! this is a quick hack to make extended templates work
                # but what we need is a better method to handle resource ownership
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
                to_del = []
                doc.root.each_child do |child|
                    if child.respond_to?(:name)
                        namespace, short_name = child.name.split(':', 2)
                        next unless namespace == 'tpl'
                        next unless Spider::Template.override_tags.include?(short_name) || self.override_tags.include?(child.name)
                        overrides << child
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
            
        end
        
        i_attribute :use_template
        
        def initialize(request, response, scene=nil)
            super
            @widgets = {}
            @attributes = WidgetAttributes.new(self)
            @id_path = []
            @widget_attributes = {}
            @resources = [{
                :type => :js, :src => Spider::Components.pub_url+'/js/jquery/jquery-1.3.2.js', :path => Spider::Components.pub_path+'/js/jquery-1.3.2.js',
            },{
                :type => :js, :src => Spider::Components.pub_url+'/js/inheritance.js', :path => Spider::Components.pub_path+'/js/inheritance.js',
            },{
                :type => :js, :src => Spider::Components.pub_url+'/js/spider.js', :path => Spider::Components.pub_path+'/js/spider.js'
            },{
                :type => :js, :src => Spider::Components.pub_url+'/js/jquery/plugins/jquery.query-2.1.6.js', 
                :path => Spider::Components.pub_path+'/js/jquery.query-2.1.6.js'
            },# ,{
            #                 :type => :js, :src => Spider::Components.pub_url+'/js/jquery/jquery-ui/js/jquery-ui-1.7.2.custom.min.js', 
            #                 :path => Spider::Components.pub_path+'/js/jquery/jquery-ui/js/jquery-ui-1.7.2.custom.min.js'
            #             },
            {
                :type => :js, :src => Spider::Components.pub_url+'/js/jquery/jquery-ui/development-bundle/ui/jquery-ui-1.7.2.custom.js', 
                :path => Spider::Components.pub_path+'/js/jquery/jquery-ui/development-bundle/ui/jquery-ui-1.7.2.custom.min.js'
            },
            {
                :type => :css, :src => Spider::Components.pub_url+'/js/jquery/jquery-ui/css/ui-lightness/jquery-ui-1.7.2.custom.css', 
                :path => Spider::Components.pub_path+'/js/jquery/jquery-ui/css/ui-lightness/jquery-ui-1.7.2.custom.css'
            }]
            locale = @request.locale[0..1]
            @resources << {
                 :type => :js, :src => Spider::Components.pub_url+"/js/jquery/jquery-ui/development-bundle/ui/i18n/ui.datepicker-#{locale}.js",
                 :path => Spider::Components.pub_path+"/js/jquery/jquery-ui/development-bundle/ui/i18n/ui.datepicker-#{locale}.js"
            }
            
            @use_template ||= self.class.default_template
            @css_classes = []
        end
        
        def full_id
            @id_path.join('-')
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
            widget_init(action)
            super
        end
        
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
        end

        def widget_before(action='')
            widget_init(action)
            prepare
            @before_done = true
        end
        
        def before_done?
            @before_done
        end
        
        def prepare(action='')
            init_widgets unless @init_widgets_done
            set_widget_attributes
            prepare_widgets
            @template.resources.each do |res|
                res = res.clone
                @resources << res
            end
        end
        
        def init_widgets
            if (self.class.scene_attributes)
                self.class.scene_attributes.each do |name|
                    @scene[name] = instance_variable_get("@#{name}")
                end
            end
            template.request = @request
            template.response = @response
            @template.init(@scene)
            @widgets.merge!(@template.widgets)
            @widgets.each{ |id, w| w.parent = self }
            @init_widgets_done = true
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
                        # FIXME: what if there are a 'name' and a 'value' attributes?
                        if (a[:name] && a[:value])
                            @widgets[w_id].attributes[a[:name].to_sym] = a[:value]
                        else
                            a.each{ |key, value| @widgets[w_id].attributes[key] = value}
                        end
                    end
                end
            end
        end
        
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
                w.run
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
            run
            render
        end
        
        def render
            prepare_scene(@scene)
            if (@widget_target)
                first, rest = @widget_target.split('/', 2)
                target_widget = @template.find_widget(first)
                target_widget.widget_target = rest
                target_widget.render
            else
                @template.render(@scene)
            end
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
            obj = klass.new(*params)
            obj.id = id
            obj.id_path = @id_path + [id]
            @widgets[id.to_sym] = obj
        end
        
        def add_widget(widget)
            widget.id_path = @id_path + [widget.id]
            @widgets[widget.id.to_sym] = widget
        end
            
        
        def parse_runtime_content_xml(xml, src_path=nil)
            parse_runtime_content(Hpricot(xml), src_path)
        end
        
        def parse_runtime_content(doc, src_path=nil)
            attributes = doc.search('sp:attribute')
            attributes.each do |a|
                name = a.attributes['name'].to_sym
                kvs = a.children_of_type('sp:value')
                if (kvs.length > 0)
                    value = {}
                    kvs.each do |kv|
                        key = kv.attributes['key']
                        val = kv.innerText
                        value[key] = val
                    end
                else
                    value = a.attributes['value']
                end
                if (w = a.attributes['widget'])
                    @widget_attributes[w] = {:name => name, :value => value}
                else
                    @attributes[name] = value
                end
            end
            attributes.remove
            return doc
        end
        
        
        def resources
            res = @resources.clone + widget_resources
            return res
        end
        
        def widget_resources
            res = []
            @widgets.each do |id, w|
                res += w.resources
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
            if (self.class.scene_attributes) # Repeat for new instance variables
                self.class.scene_attributes.each do |name|
                    @scene[name] = instance_variable_get("@#{name}")
                end
            end
            # FIXME: owner_controller should be (almost) always defined
            scene.controller[:request_path] = owner_controller.request_path if owner_controller
            scene.widget[:request_path] = widget_request_path
            if (@parent && @parent.respond_to?(:scene) && @parent.scene)
                scene._parent = @parent.scene
            end
            return scene
        end
        
        def css_class
            return @css_class if @css_class
            supers = self.class.ancestors.select{ |c| c != Spider::Widget && c.subclass_of?(Spider::Widget)}
            @css_class = Inflector.underscore(supers.join('/')).gsub('_', '-').gsub('/', ' ').split(' ').uniq.join(' ')
        end
        
        def inspect
            super + ", id: #{@id}"
        end
            
        
    end
    
end
