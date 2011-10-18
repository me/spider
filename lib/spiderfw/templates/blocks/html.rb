require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class HTML < Block
        HTML_NO_CLOSE = ['br', 'img', 'input', 'meta']
        
        def compile(options={})
            c = ""
            init = ""
            if @doctype
                c = "$out << '#{@doctype.raw_string}'\n" 
                c += "$out << 10.chr\n" #newline
            end
            start = get_start(options)
            c += start
            is_root = options[:root]
            options.delete(:root)
            c += "unless self[:widget][:target_only] && !self[:widget][:is_target]\n" if (options[:mode] == :widget && is_root)
            c, init = compile_content(c, init, options)
            c += "end\n"  if (options[:mode] == :widget && is_root)
            end_tag = get_end(options)
            c += "$out << '#{end_tag}'\n" if end_tag
            return CompiledBlock.new(init, c)
        end
        
        def get_start(options)
            if options[:mode] == :widget
                cl = @el.get_attribute('class') || ''
                if @el.has_attribute?('id')
                    cl += ' ' unless cl.empty?
                    cl += "id-#{@el.get_attribute('id')}"
                    our_id = @el.get_attribute('id')
                    @el.remove_attribute('id')
                    @el.set_attribute('id', "{ @widget[:full_id] }-#{our_id}")
                end
                if (options[:root])
                    cl += " widget"
                    if options[:owner_class]
                        cl += " wdgt-#{options[:owner_class].name.gsub('::', '-')}"
                    end
                    @el.set_attribute('id', "{ @widget[:shown_id] }")
                    cl += ' ' unless cl.empty?
                    cl += '{ @widget[:css_classes] }'
                end
                @el.set_attribute('class', cl) unless cl.blank?
            end
            start = "$out << '<"+@el.name
            @el.attributes.to_hash.each do |key, val|
                if key =~ /sp::(.+)/
                    key = "sp:#{$1}"
                end
                start += " #{key}=\""
                start += compile_text(val)
                start += "\""
            end
            start += ">'\n"
            return start
        end
        
        def get_end(options)
            return nil if options[:doctype].html? && HTML_NO_CLOSE.include?(@el.name.downcase)
            str = escape_text(@el.etag.inspect) if @el.etag
            str = str[1..-2] if str && str[0].chr == '"' # FIXME:  This is a workaround Hpricot 0.6 and 0.8 differences
            return str
        end
        
    end
    
    
end; end