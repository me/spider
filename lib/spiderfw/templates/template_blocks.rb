module Spider
    
    module TemplateBlocks
        
        def self.parse_element(el, allowed_blocks=nil)
            if (el.class == ::Hpricot::Text)
                block = :Text
            elsif (el.attributes['sp:if'])
                block = :If    
            elsif (el.attributes['sp:each'])
                block = :Each
            elsif (el.name == 'sp:render')
                block = :Render
            elsif (el.name == 'sp:yield')
                block = :Yield
            elsif (el.name == 'sp:pass')
                block = :Pass
            elsif (Spider::Template.registered?(el.name))
                klass = Spider::Template.get_registered_class(el.name)
                if (klass.subclass_of?(::Spider::Widget))
                    block = :Widget
                else
                    Spider.logger.debug("IS NOT A WIDGET!") # FIXME
                end
            else
                block = :HTML
            end
            return nil unless (!allowed_blocks || allowed_blocks.include?(block))
            return const_get(block).new(el, allowed_blocks)
        end
        
        class Block
            
            def initialize(el, template, allowed_blocks=nil)
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
                    # Gives the preceding block the change to "eat" the next elements
                    next if (last_block && last_block.get_following(ch))
                    last_block = TemplateBlocks.parse_element(ch, @allowed_blocks)
                    content_blocks << last_block
                end
                return content_blocks
            end
            
            def compile_content(c='', init='')
                c ||= ""
                init ||= ""
                blocks = parse_content(@el)
                blocks.each do |block|
                    compiled = block.compile
                    if (compiled.run_code =~ /nil/)
                        Spider::Logger.debug("NIL BLOCK")
                        Spider::Logger.debug(block)
                        Spider::Logger.debug(compiled.run_code)
                    end
                    c += compiled.run_code if (compiled.run_code)
                    init += compiled.init_code if (compiled.init_code)
                end
                return [c, init]
            end
            
            def get_following(el)
                return false
            end
            
            def escape_text(text)
                res = text.gsub("'", "\\\\'")
                return res
            end
            
            def vars_to_scene(str)
                res = ""
                scanner = ::StringScanner.new(str)
                pos = 0
                while scanner.scan_until(/@(\w[\w\d_]+)/)
                    text = scanner.pre_match[pos..-1]
                    pos = scanner.pos
                    res += text
                    res += "scene[:#{scanner.matched[1..-1]}]"
                end
                res += scanner.rest
                return res
            end
            
            
            def inspect
                @el
            end
            
            def var_to_scene(var)
                first, rest = var.split('.', 2)
                if (var[0].chr == '@')
                    scene_var = "self[:#{first[1..-1]}]"
                else
                    scene_var = first
                end
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
require 'spiderfw/templates/blocks/text'
require 'spiderfw/templates/blocks/each'
require 'spiderfw/templates/blocks/if'
require 'spiderfw/templates/blocks/render'
require 'spiderfw/templates/blocks/yield'
require 'spiderfw/templates/blocks/pass'
require 'spiderfw/templates/blocks/widget'