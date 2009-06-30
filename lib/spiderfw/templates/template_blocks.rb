module Spider
    
    module TemplateBlocks
        
        def self.parse_element(el, allowed_blocks=nil, template=nil)
            return nil if (el.class == ::Hpricot::BogusETag)
            if (el.class == ::Hpricot::Text)
                block = :Text
            elsif (el.class == ::Hpricot::Comment)
                block = :Comment
            elsif (el.attributes['sp:if'])
                block = :If
            elsif (el.attributes['sp:tag-if'])
                block = :TagIf
            elsif (el.attributes['sp:attr-if'])
                block = :AttrIf
            elsif (el.attributes['sp:each'] || el.attributes['sp:each_index'])
                block = :Each
            elsif (el.name == 'sp:render')
                block = :Render
            elsif (el.name == 'sp:run')
                block = :Run
            elsif (el.name == 'sp:yield')
                block = :Yield
            elsif (el.name == 'sp:pass' || el.name == 'sp:template')
                block = :Pass
            elsif (el.name == 'sp:debugger')
                block = :Debugger
            elsif (Spider::Template.registered?(el.name))
                klass = Spider::Template.get_registered_class(el.name)
                if (klass.subclass_of?(::Spider::Widget))
                    block = :Widget
                else
                    Spider.logger.error("Could not parse #{el.name} tag")
                end
            else
                block = :HTML
            end
            return nil unless (!allowed_blocks || allowed_blocks.include?(block))
            return const_get(block).new(el, template, allowed_blocks)
        end
        
        class Block
            
            def initialize(el, template=nil, allowed_blocks=nil)
                @el = el
                @template = template
                @allowed_blocks = allowed_blocks
                @content_blocks = []
            end
            
            def parse_content(el)
                content_blocks = []
                last_block = nil
                el.each_child do |ch|
                    #Spider.logger.debug "TRAVERSING CHILD #{ch}"
                    # Gives the preceding block the chance to "eat" the next elements
                    next if (last_block && last_block.get_following(ch))
                    last_block = TemplateBlocks.parse_element(ch, @allowed_blocks, @template)
                    content_blocks << last_block if (last_block)
                end
                return content_blocks
            end
            
            def compile_content(c='', init='')
                c ||= ""
                init ||= ""
                blocks = parse_content(@el)
                blocks.each do |block|
                    compiled = block.compile
                    next unless compiled
                    # if (compiled.run_code =~ /nil/)
                    #     Spider::Logger.debug("NIL BLOCK")
                    #     Spider::Logger.debug(block)
                    #     Spider::Logger.debug(compiled.run_code)
                    # end
                    c += compiled.run_code if (compiled.run_code)
                    init += compiled.init_code if (compiled.init_code)
                end
                return [c, init]
            end
            
            def get_following(el)
                return false
            end
            
            def escape_text(text)
                res = text.gsub("'", "\\'") \
                    .gsub(/_(\\*)\\\((.+?)\)/, '_\1\1(\2)') \
                    .gsub('\\', '\\\\')
                return res
            end
            
            def vars_to_scene(str, container='self')
                res = ""
                scanner = ::StringScanner.new(str)
                pos = 0
                while scanner.scan_until(/@(\w[\w\d_]+)/)
                    text = scanner.pre_match[pos..-1]
                    pos = scanner.pos
                    res += text
                    res += "#{container}[:#{scanner.matched[1..-1]}]"
                end
                res += scanner.rest
                return res
            end
            
            def scan_vars(str, &block)
                res = ""
                scanner = ::StringScanner.new(str)
                pos = 0
                while scanner.scan_until(/\{ ([^}]+) \}/)
                    text = scanner.pre_match[pos..-1]
                    pos = scanner.pos
                    yield text, scanner.matched[2..-3]
                end
                return scanner.rest
            end
            
            
            def inspect
                @el
            end
            
            def var_to_scene(var, container='self')
                first, rest = var.split('.', 2)
                if (first =~ /([^\[]+)(\[.+)/)
                    var_name = $1
                    array_rest = $2
                else
                    var_name = first
                end
                if (var[0].chr == '@')
                    scene_var = "#{container}[:#{var_name[1..-1]}]"
                else
                    scene_var = var_name
                end
                scene_var += array_rest if (array_rest)
                scene_var += '.'+rest if (rest)
                return scene_var
            end
            
        end
        
        class CompiledBlock
            attr_accessor :init_code, :run_code
            
            def initialize(init_code, run_code)
                @init_code = init_code
                @run_code = run_code
            end
            
        end
        
    end
    
end
require 'spiderfw/templates/blocks/html'
require 'spiderfw/templates/blocks/comment'
require 'spiderfw/templates/blocks/text'
require 'spiderfw/templates/blocks/each'
require 'spiderfw/templates/blocks/if'
require 'spiderfw/templates/blocks/tag_if'
require 'spiderfw/templates/blocks/attr_if'
require 'spiderfw/templates/blocks/render'
require 'spiderfw/templates/blocks/yield'
require 'spiderfw/templates/blocks/pass'
require 'spiderfw/templates/blocks/widget'
require 'spiderfw/templates/blocks/run'
require 'spiderfw/templates/blocks/debugger'
