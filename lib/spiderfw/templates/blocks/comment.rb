require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Comment < Block
        
        def compile(options={})
            init = nil
            c = ""
            str = nil
            mode = nil
            if (@el.content[0].chr == '-')
                mode = :internal
            elsif (@el.content[0].chr == '+')
                mode = :parse
            else
                mode = :verbatim
            end
            if (mode == :parse)
                str = ""
                rest = Spider::Template.scan_scene_vars(@el.to_s) do |type, val|
                    case type
                    when :plain
                        str += escape_text(val)
                    when :var
                        str += "'+("+vars_to_scene(val)+").to_s+'"
                    end
                end
                str += escape_text(rest)
            elsif (mode == :verbatim)
                str = escape_text(@el.to_s)
            else
                str = nil
            end
            c += "$out << '#{str}'\n" if str
            #c += "$out << '#{@el.to_s}'\n"
            return CompiledBlock.new(init, c)
        end

    end
    
    
end; end