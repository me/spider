module Spider; module Components
    
    class Table < Spider::Widget
        tag 'table'
        i_attribute :model, :required => true
        attribute :elements, :process => lambda{ |v| v.split(',').map{ |v| v.strip.to_sym } }
        attribute :row_limit, :type => Fixnum, :default => 15
        attribute :paginate, :type => TrueClass, :default => true
        
        def prepare
            if (@attributes[:paginate])
                @page = params['page']
                @page ||= session[:page]
                @page ||= 1
                @page = @page.to_i
                @offset = ((@page - 1) * @attributes[:row_limit])
            end
            if params['sort']
                @sort = params['sort'].to_sym 
                @page = 1
            end
            if (@sort)
                if (@model.elements[@sort].model?)
                    s = []
                    @model.elements[@sort].model.each_element{ |el| s << "#{@sort}.#{el.name}" if el.type == String && !el.primary_key? }
                    @sort = s
                end
            end
            @sort = session[:sort] if !@sort && session[:sort]
            session[:sort] = @sort if @sort
            @sort = [@sort] if @sort && !@sort.is_a?(Array)
        end
        
        def execute
            @scene.elements = @attributes[:elements] || @attributes[:model].elements_array.map{ |el| el.name }
            @scene.sortable = {}
            @model.elements_array.each{ |el| @scene.sortable[el.name] = @model.mapper.mapped?(el) ? true : false }
            @scene.labels = {}
            @scene.elements.each do |el|
                @scene.labels[el] = @model.elements[el].label
            end
            @scene.rows = @model.all
            if (@attributes[:paginate])
                @scene.rows.limit = @attributes[:row_limit]
                @scene.rows.offset = @offset
                @scene.page = @page
                @scene.paginate = true
            end
            @scene.rows.order_by(*@sort) if @sort
            @scene.rows.load
            @scene.has_more = @scene.rows.has_more?
            @scene.pages = (@scene.rows.total_rows.to_f / @attributes[:row_limit]).ceil
        end
        
        
    end
    
end; end