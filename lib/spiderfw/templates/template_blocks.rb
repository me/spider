module Spider
    
    module TemplateBlocks
        
        def self.parse_element(el, allowed_blocks=nil, template=nil)
            return nil if (el.class == ::Hpricot::BogusETag)
            block = get_block_type(el)
            return nil unless (!allowed_blocks || allowed_blocks.include?(block))
            return const_get(block).new(el, template, allowed_blocks)
        end
        
        def self.get_block_type(el, skip_attributes=false)
            if el.class == ::Hpricot::Text
                block = :Text
            elsif el.class == ::Hpricot::Comment
                block = :Comment
            elsif !skip_attributes && (el.has_attribute?('sp:if') || el.has_attribute?('sp:run-if'))
                block = :If
            elsif !skip_attributes && el.has_attribute?('sp:tag-if')
                block = :TagIf
            elsif !skip_attributes && el.has_attribute?('sp:attr-if')
                block = :AttrIf
            elsif !skip_attributes && (el.has_attribute?('sp:each') || el.has_attribute?('sp:each_index') \
                                    || el.has_attribute?('sp:each_pair') || el.has_attribute?('sp:each_with_index'))
                block = :Each
            elsif el.name == 'tpl:output'
                block = :Output
            elsif el.name == 'sp:render'
                block = :Render
            elsif el.name == 'sp:run'
                block = :Run
            elsif el.name == 'sp:yield'
                block = :Yield
            elsif el.name == 'sp:pass' || el.name == 'tpl:pass' || el.name == 'sp:template'
                block = :Pass
            elsif el.name == 'sp:debugger'
                block = :Debugger
            elsif el.name == 'sp:parent-context'
                block = :ParentContext
            elsif Spider::Template.registered?(el.name)
                klass = Spider::Template.get_registered_class(el.name)
                if klass < ::Spider::Widget
                    block = :Widget
                elsif klass < Spider::Tag
                    block = :Tag
                else
                    Spider.logger.error("Could not parse #{el.name} tag")
                end
            else
                block = :HTML
            end
            return block
        end
        
        def self.parse_content(el, allowed_blocks=nil, template=nil)
            content_blocks = []
            last_block = nil
            el.each_child do |ch|
                #Spider.logger.debug "TRAVERSING CHILD #{ch}"
                # Gives the preceding block the chance to "eat" the next elements
                next if (last_block && last_block.get_following(ch))
                last_block = TemplateBlocks.parse_element(ch, allowed_blocks, template)
                content_blocks << last_block if (last_block)
            end
            return content_blocks
        end
        
        def self.compile_content(el, c='', init='', options={})
            c ||= ""
            init ||= ""
            blocks = self.parse_content(el, options[:allowed_blocks], options[:template])
            blocks.each do |block|
                compiled = block.compile(options)
                next unless compiled
                c += compiled.run_code if (compiled.run_code)
                init += compiled.init_code if (compiled.init_code)
            end
            return [c, init]
        end
        
        class Block
            attr_reader :el, :template, :allowed_blocks
            attr_accessor :doctype
            
            def initialize(el, template=nil, allowed_blocks=nil)
                @el = el
                @template = template
                @allowed_blocks = allowed_blocks
                @content_blocks = []
            end
            
            def parse_content(el)
                TemplateBlocks.parse_content(el, @allowed_blocks, @template)
            end
            
            def compile_content(c='', init='', options={})
                options[:allowed_blocks] ||= @allowed_blocks
                options[:template] ||= @template
                TemplateBlocks.compile_content(@el, c, init, options)
            end
            
            def get_following(el)
                return false
            end
            
            def escape_text(text)
                res = text.gsub(/_(\\*)\\\((.+?)\)/, '_\1(\2)') \
                    .gsub('\\', '\\\\\\').gsub("'", "\\\\'")
                return res
            end
            
            def self.vars_to_scene(str, container='self')
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
            
            def vars_to_scene(str, container='self')
                self.class.vars_to_scene(str, container)
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
            
            def compile_text(str)
                res = ""
                str = str.gsub(/\302\240/, ' ') # remove annoying fake space
                scanner = ::StringScanner.new(str)
                pos = 0
                var_regexp = /\{ ([^}]+) \}/
                while scanner.scan_until(Regexp.union(var_regexp, GettextRegexp))
                    text = scanner.pre_match[pos..-1]
                    pos = scanner.pos
                    case scanner.matched
                    when var_regexp
                         res += text+"'+("+vars_to_scene(scanner.matched[2..-3])+").to_s+'"
                    when GettextRegexp
                        res += "'\n$out << _('#{escape_text($1)}')"
                        if $2
                            res += " #{vars_to_scene($2)}" 
                        end
                        res += "\n$out << '"
                    end
                end
                res += escape_text(scanner.rest)
                return res
            end
            
            
            def inspect
                @el
            end
            
            def self.var_to_scene(var, container='self')
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
            
            def var_to_scene(var, container='self')
                self.class.var_to_scene(var, container)
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
require 'spiderfw/templates/blocks/tag'
require 'spiderfw/templates/blocks/widget'
require 'spiderfw/templates/blocks/run'
require 'spiderfw/templates/blocks/debugger'
require 'spiderfw/templates/blocks/parent_context'
require 'spiderfw/templates/blocks/output'


