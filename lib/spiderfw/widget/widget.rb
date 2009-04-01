require 'spiderfw/controller/controller'
require 'spiderfw/templates/template'
require 'spiderfw/controller/mixins/visual'
require 'spiderfw/widget/widget_attributes'
require 'spiderfw/controller/mixins/http_mixin'

module Spider
    
    class Widget < PageController
        include HTTPMixin
        
        attr_accessor :request, :scene, :template_name, :widgets, :template, :id, :id_path
        attr_reader :attributes, :widget_attributes, :css_class
        
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
                # FIXME: look for app in parent modules, might not be the first
                self.parent_module.register_tag(name, self)
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
            
            def default_action
                'run'
            end
            
            def app
                @app ||= self.parent_module
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
            
            def relative_url
                template_path[template_path_parent.length+1..-1]
            end
            
            def route_url
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping('/'+self.app.route_url+'/w/'+relative_url)
            end
            
            def pub_url
                route_url+'/pub'
            end
                
            
            def find_template(name=nil)
                path = template_path
                return 'default' if (File.exist?(path+'/default.shtml'))
                Dir.entries(path).each do |entry|
                    next if entry[0].chr == '.' || !File.file?(path+'/'+entry)
                    # TODO: other extensions
                    next unless entry =~ /(.+)\.(shtml)$/
                    return $1
                end
                return nil 
            end
            
        end
        
        def initialize(request, response, scene=nil)
            super
            @widgets = {}
            @attributes = WidgetAttributes.new(self.class)
            @id_path = []
            @widget_attributes = {}
            @resources = []
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
        
        
        def prepare
        end
        
        def start
        end
        
        def execute
        end
        
        def after_execute
        end
        
        def init_widget
            @id ||= @attributes[:id]
            unless @template
                template_name = self.class.find_template
                @template = load_template(template_name)
            end
            @template.id_path = @id_path
            self.class.attributes.each do |k, params|
                @attributes[k] = params[:default] if (params[:default] && !@attributes[k])
                if (params[:required] && !@attributes[k] && !(params[:instance_attr] && instance_variable_defined?("@#{k}")))
                    raise ArgumentError, "Attribute #{k} is required by widget #{self}" 
                end
            end
            @attributes.each do |k, v|
                if (self.class.attributes[k][:set_var])
                    instance_variable_set("@#{k}", v) unless instance_variable_get("@#{k}")
                end
            end
            prepare
            if (self.class.scene_attributes)
                self.class.scene_attributes.each do |name|
                    @scene[name] = instance_variable_get("@#{name}")
                end
            end
#            debug("WIDGET #{full_id} INIT TEMPLATE WITH SCENE #{@scene}")
            template.request = @request
            template.response = @response
            @template.init(@scene)
            @widgets.merge!(@template.widgets)
            start
            @widget_attributes.each do |w_id, a|
                w_id_parts = w_id.to_s.split('.', 2)
                if (w_id_parts[1])
                    w_id = w_id_parts[0]
                    sub_w = w_id_parts[1]
                end
                w_id = w_id.to_sym
                Spider::Logger.debug("WIDGET ATTRIBUTE:")
                Spider::Logger.debug(a)
                if (@widgets[w_id])
                    if (sub_w)
                        @widgets[w_id].widget_attributes[sub_w] = a
                    else
                        if (!a[:name])
                            Spider::Logger.error("No name for attribute #{a.to_s}")
                            next
                        end
                        @widgets[w_id].attributes[a[:name].to_sym] = a[:value]
                    end
                end
            end
            @init_widget_done = true
            @widgets.each do |wname, w|
                w.init_widget
            end
            @template.resources.each do |res|
                res = res.clone
                res[:src] = self.class.pub_url+'/'+res[:src]
                @resources << res
            end
            #@resources += @template.resources
            @template.init_sub_done = true
        end
        
        def run_execute
            execute
            @widgets.each do |wname, w|
                w.run_execute
            end
            after_execute
            @widgets.each do |wname, w|
                w.after_execute
            end
        end
        
        def init_widget_done?
            @init_widget_done
        end
        
        def run
            init_widget unless init_widget_done?
            if (self.class.scene_attributes) # Repeat for new instance variables
                self.class.scene_attributes.each do |name|
                    @scene[name] = instance_variable_get("@#{name}")
                end
            end
            render
        end
        
        def render
            prepare_scene(@scene) # FIXME
            @template.render(@scene)
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
            
        
        def parse_content_xml(xml)
            parse_content(Hpricot(xml))
        end
        
        def parse_content(doc)
            attributes = doc.search('sp:attribute')
            attributes.each do |a|
                name = a.attributes['name']
                value = a.attributes['value']
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
        
        def request_path
            HTTPMixin.reverse_proxy_mapping(@request.env['REQUEST_PATH'])
        end
        
    end
    
end