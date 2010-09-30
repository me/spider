module Spider; module ConfigEditor
    
    class ConfigEditorController < Spider::PageController
        
        layout 'config_editor'
        
        def conf
            Spider.conf
        end
        
        def index
            redirect 'options'
        end
        
        def before(action='', *arguments)
            super
            @scene.required = []
            self.conf.each do |key, val|
                if !val && self.conf.option(key)[:params][:required]
                    @scene.required << key
                end
            end
        end
        
        __.html :template => 'index'
        def options(action='')
            @scene.prefix = action
            @scene.prefix += '/' unless @scene.prefix.empty?
            @scene.parts = []
            conf = self.conf.options
            unless action.empty?
                parts = action.split('/')
                tmp_cur_part = ''
                @scene.parts = parts.map{ |p| tmp_cur_part = "#{tmp_cur_part}/#{p}"}
                @scene.parts.pop
                parts.each do |part|
                    conf = conf[part]
                end
            end
            @scene.subconfs = []
            @scene.options = {}
            @scene.edit_widgets = {}
            if conf[:params] && conf[:params][:type] == :conf
                @scene.multiple = true
                conf = conf['x']
            end
            
            conf.each do |key, val|
                if val.key?(:description) && val.key?(:params) && val[:params][:type] != :conf
                    next if val[:description] == "__auto__"
                    @scene.options[key] = val
                    w = create_edit_widget(key, val)
                    @scene.edit_widgets[key] = w
                else
                    @scene.subconfs << key
                end
            end

        end
        
        __.html :template => 'index'
        def required
            @scene.parts = []
            @scene.subconfs = []
            @scene.options = {}
            @scene.edit_widgets = {}
            self.conf.each do |key, val|
                next unless self.conf.option(key)
                if self.conf.option(key)[:params][:required]
                    @scene.options[req] = self.conf.option(key)
                    w = create_edit_widget(req, self.conf.option(key))
                    @scene.edit_widgets[key] = w
                end
            end
        end
        
        def create_edit_widget(key, option)
            w = Edit.new(@request, @response, @scene)
            w.attributes[:name] = key
            w.attributes[:option] = option
            w.widget_init
            w.prepare
            w
        end
        
    end
    
end; end