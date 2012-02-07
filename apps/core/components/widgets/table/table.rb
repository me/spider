module Spider; module Components
    
    class Table < Spider::Widget
        tag 'table'
 
        is_attribute :elements, :process => lambda{ |v|
            return v.split(',').map{ |v| v.include?('.') ? v : v.strip.to_sym } if v.is_a?(String)
            v
        }
        attribute :labels, :process => lambda{ |v| 
            return v.split(',') if v.is_a?(String)
            v
        }
        i_attribute :num_elements, :default => 7, :type => Fixnum
        attribute :row_limit, :type => Fixnum, :default => 15
        attribute :paginate, :type => TrueClass, :default => true
        attribute :max_element_length, :type => Fixnum, :default => 80
        attribute :link_el, :type => Symbol
        attribute :link_id, :type => Symbol
        attribute :link
        attribute :sort
        i_attr_accessor :queryset
        i_attr_accessor :model
        attr_accessor :queryset, :condition, :page
        
        def condition
            @condition ||= Spider::Model::Condition.new
        end
        
        def add_condition(c)
            @condition = self.condition.and(c)
        end
        
        def prepare(action='')
            @model ||= @queryset.model
            @model = const_get_full(@model) if @model.is_a?(String)
            if params['sort'] && params['sort'].is_a?(Hash)
                @sort_el = params['sort'].keys.first.to_sym 
                @sort_dir = params['sort'].values.first.to_sym
                @page = 1
            elsif session[:sort]
                @sort_el, @sort_dir = session[:sort]
            elsif @attributes[:sort]
                el, dir = @attributes[:sort].split(',')
                @sort_el = el.to_sym
                @sort_dir = dir ? dir.to_sym : :asc
            end
            if @attributes[:paginate]
                @page = params['page'] if params['page']
                @page ||= 1
                @page = @page.to_i
                @offset = ((@page - 1) * @attributes[:row_limit])
            end
            session[:sort] = [@sort_el, @sort_dir] if @sort_el
            @scene.sorted = {}
            @scene.sorted[@sort_el] = @sort_dir if @sort_el
            if @sort_el
                el = @model.elements[@sort_el]
                if el && el.model? && el.storage == @model.storage
                    s = []
                    element = @model.elements[@sort_el]
                    @model.elements[@sort_el].model.each_element do |el|                         
                        s << "#{@sort_el}.#{el.name}" if (el.type == String && !el.primary_key? && element.model.mapper.mapped?(el) )
                    end
                    @sort_el = s
                end
            end
            @sort_el = [@sort_el] if @sort_el && !@sort_el.is_a?(Array)
            @scene.link_el = @attributes[:link_el]
            @scene.link = @attributes[:link]
            @scene.link_id = @attributes[:link_id] || @attributes[:link_el]
            super
        end
        
        def choose_elements
            els = []
            cnt = 1
            @model.elements_array.each do |el|
                break if cnt > @num_elements
                unless el.name == @link_el
                    next if el.attributes[:integrated_model]
                    next if el.multiple? && el.association != :multiple_choice
                    next if el.type == Spider::DataTypes::Password
                    next if el.hidden?
                end
                cnt += 1
                els << el.name
            end
            return els
        end
        
        def run
            @elements ||= choose_elements
            @model.elements_array.each{ |el|  }
            @scene.labels = {}
            @scene.sortable = {}
            attr_labels = attributes[:labels] || []
            @elements.each_index do |i|
                el = @elements[i]
                full = el
                if el.is_a?(String)
                    first, rest = el.split('.', 2)
                    el = first.to_sym
                end
                raise "No element #{el} in #{@model} for table #{@id}" unless @model.elements[el]
                @scene.labels[full] = attr_labels[i].blank? ? @model.elements[el].label : attr_labels[i]
                @scene.sortable[full] = sortable?(full)
            end
            @rows = prepare_queryset(@queryset ? @queryset : @model.list)
            @rows.condition.and(self.condition) if self.condition && !self.condition.empty?
            if @attributes[:paginate]
                @rows.limit = @attributes[:row_limit]
                @rows.offset = @offset
                @scene.page = @page
                @scene.paginate_first = [@page-5, 1].max
                @scene.paginate = true
            end
            if @sort_el
                @sort_el.each do |el|
                    @rows.order_by(el, @sort_dir)
                end
            end
            @rows.load
            @scene.rows = prepare_rows(@rows)
            @scene.data = @rows
            @scene.has_more = @rows.has_more?
            if @attributes[:paginate]
                @scene.pages = (@rows.total_rows.to_f / @attributes[:row_limit]).ceil
                @scene.paginate_last = [@scene.paginate_first + 9, @scene.pages].min
            end
            @scene.columns = @elements.size
            super
        end
        
        def sortable?(el)
            @model.mapper.sortable?(el) ? true : false
        end
       
        def prepare_queryset(qs)
            return qs
        end
        
        def prepare_rows(rows)
            res = []
            rows.each do |row|
                res_row = {}
                @elements.each do |el|
                    res_row[el] = prepare_value(el, row)
                end
                res << res_row
            end
            return res
        end

        def prepare_value(el, row)
            full = el; rest = nil
            if el.is_a?(String)
                first, rest = el.split('.', 2)
                el = first
            end
            element = @model.elements[el.to_sym]
            if !row[el] && [String, Spider::DataTypes::Text].include?(element.type)
                return ''
            end
            if element.multiple?
                list = "<ul>"
                if row[el]
                    row[el][0..2].each{ |sub|
                        if sub && element.junction? && element.model.attributes[:sub_model] != @model
                            sub = sub.get(element.attributes[:junction_their_element]) 
                        end
                        sub_desc = sub.nil? ? '' : sub.to_s
                        sub_desc ||= ''
                        sub_desc = sub_desc[0..@attributes[:max_element_length]] if sub_desc.length > @attributes[:max_element_length]
                        list += "<li>"+sub_desc+"</li>" unless sub_desc.empty?
                    }
                    list += "<li>...</li>" if (row[el].length > 3)
                    list += "</ul>"
                    return list
                end
            else
                format_value(element.type, row[el], element.attributes)
            end
        end

        def format_value(type, value, attributes={})
            if type <= Spider::Bool
                return value ? _('Yes') : _('No')
            elsif !value
                return ''
            elsif type <= Date || type <= Time
                return Spider::I18n.localize_date_time(@request.locale, value, :short)
            elsif type <= Float || type <= BigDecimal
                str = Spider::I18n.localize_number(@request.locale, value)
                if attributes[:currency]
                    str = "&#{attributes[:currency]}; #{str}"
                end
                return str
            elsif value.respond_to?(:format)
                return value.format(:short)
            else
                str = value.to_s || ''
                str = str.split("\n").map{ |str_row|
                    if str_row.length > @attributes[:max_element_length]
                        str_row[0..@attributes[:max_element_length]]+'...' 
                    else
                        str_row
                    end
                }.join("\n")
                return str
            end
        end
        
        
    end
    
end; end
