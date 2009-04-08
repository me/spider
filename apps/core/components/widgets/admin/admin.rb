module Spider; module Components
    
    class Admin < Spider::Widget
        tag 'admin'
        
        i_attribute :models, :process => lambda{ |models| models.split(/,[\s\n]*/).map{|m| const_get_full(m) } }
        
        def init
            @items = []
        end
        
        def parse_content(doc)
            doc = super
            mods = []
            doc.search('admin:model').each do |mod|
                mods << const_get_full(mod.innerText)
            end
            doc.search('admin:app').each do |app_tag|
                app = const_get_full(app_tag.innerText)
                mods += app.models.select do |m|
                    !m.attributes[:sub_model] && m.mapper.class.write?
                end
            end
            @models ||= []
            @models += mods
            return doc
        end

        def start
            @models.each do |model|
                crud = Crud.new(@request, @response)
                crud.id = model.name.to_s.gsub('::', '_').downcase
                crud.model = model
                @widgets[:menu].add(model.label_plural, crud)
            end
        end
        
        def execute
            @scene.current = @widgets[:menu].current_label
        end

    end
    
end; end