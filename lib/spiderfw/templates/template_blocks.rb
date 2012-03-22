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
            elsif !skip_attributes && el.has_attribute?('sp:lambda')
                block = :Lambda
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
            elsif el.name == 'tpl:output-assets'
                block = :LayoutAssets
            elsif el.name == 'tpl:output-meta'
                block = :LayoutMeta
            elsif el.name == 'sp:render'
                block = :Render
            elsif el.name == 'sp:run'
                block = :Run
            elsif el.name == 'sp:yield'
                block = :Yield
            elsif !skip_attributes && el.has_attribute?('tpl:text-domain')
                block = :TextDomain    
            elsif el.name == 'sp:pass' || el.name == 'tpl:pass' || el.name == 'sp:template'
                block = :Pass
            elsif el.name == 'sp:debugger'
                block = :Debugger
            elsif el.name == 'sp:parent-context'
                block = :ParentContext
            elsif el.name == 'sp:recurse'
                block = :Recurse
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
                Spider::Template.scan_scene_vars(str) do |type, val|
                    case type
                    when :plain
                        res += val
                    when :var
                        res += "#{container}[:#{val}]"
                    end
                end
                res
            end
            
            def vars_to_scene(str, container='self')
                self.class.vars_to_scene(str, container)
            end
            
            def compile_text(str)
                res = ""
                Spider::Template.scan_text(str) do |type, val, full|
                    case type
                    when :plain
                        res += escape_text(val)
                    when :escaped_expr
                        res += "{ #{escape_text(val)} }"
                    when :expr
                        res += "'+("+vars_to_scene(val)+").to_s+'"
                    when :gettext
                        res += "'\n$out << _('#{escape_text(val[:val])}')"
                        if val[:vars]
                            res += " #{vars_to_scene(val[:vars])}" 
                        end
                        res += "\n$out << '"
                    end
                end
                res
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
require 'spiderfw/templates/blocks/layout_assets'
require 'spiderfw/templates/blocks/layout_meta'
require 'spiderfw/templates/blocks/lambda'
require 'spiderfw/templates/blocks/recurse'
require 'spiderfw/templates/blocks/text_domain'


