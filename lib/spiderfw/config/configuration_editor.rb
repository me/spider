require 'fileutils'

module Spider
    
    class ConfigurationEditor
        
        def initialize
            @values = {}
            @changed = {}
            @added = {}
            @first_file = nil
        end
        
        def load(file)
            @first_file ||= file
            @values[file] = YAML::load_file(file)
        end
        
        def set(*args)
            value = args.pop
            key = args.pop
            context = args
            found_val = false
            first_file = nil
            @values.each do |file, data|
                cdata = get_context(file, context)
                if cdata && cdata[key]
                    cdata[key] = value
                    @changed[file] ||= {}
                    curr_changed = @changed[file]
                    context.each do |c|
                        curr_changed[c] ||= {}
                        curr_changed = curr_changed[c]
                    end
                    curr_changed[key] = value
                    found_val = true
                    break
                end
            end
            unless found_val
                best_file = nil
                best_found = nil
                @values.each do |file, data|
                    cdata = data
                    found = []
                    ccontext = context.clone
                    while !ccontext.empty? && cdata
                        c = ccontext.shift
                        cdata = cdata[c]
                        found << c if cdata
                    end
                    if !best_file || found.length > best_found.length
                        best_file = file
                        best_found = found
                    end
                end
                file = best_file
                found = best_found
                @changed[file] ||= {}
                @changed[file][:_add] ||= {}
                @changed[file][:_add][found] ||= {}
                ch = @changed[file][:_add][found]
                context = context-found
                context.each do |c|
                    ch = (ch[c] ||= {})
                end
                ch[key] = value
            end
        end
        
        def get_context(file, context)
            data = @values[file]
            return nil unless data
            context.each do |c|
                data = data[c]
                return nil unless data
            end
            return data
        end
        
        def save
                        
            def commit_ml(res, key, val, curr)
                if curr
                    curr.instance_eval("def to_yaml_style; :multiline; end")
                    res << {key => curr}.to_yaml.split("\n")[2..-1].join("\n") + "\n"
                else
                    res << val
                end
                
            end
            @changed.each do |file, data|
                dirname = File.dirname(file)
                basename = File.basename(file)
                tmp_file = File.join(dirname, ".#{basename}.editor")
                File.open(file) do |f|
                    res = File.open(tmp_file, 'w')
                    context = []
                    indents = {}
                    prev_indent = ""
                    curr = data
                    curr_val = ""
                    last_key = nil
                    level = 0
                    indent_size = 2
                    add_next = nil
                    f.each_line do |line|
                        if add_next
                            line =~ /(\s*)\S/
                            indent = $1
                            add_next.each do |l|
                                res << indent + l + "\n"
                            end
                            add_next = nil
                        end
                        if line =~ /^(\s*)(\w[^:]+):\s*(.+)?$/
                            indent = $1
                            key = $2
                            value = $3
                            unless curr_val.empty?
                                commit_ml(res, last_key, curr_val, curr[last_key])
                                curr_val = ""
                            end
                            if value
                                value = value[1..-2] if value[0].chr == "'" || value[0].chr == '"'
                            end
                            if indent.empty?
                                level = 0
                                context = []
                                curr = data
                            elsif indent.length <= prev_indent.length
                                level = indents[indent.length]
                                context = context[0..level-1]
                                curr = data
                                context.each do |c|
                                    curr = curr[c]
                                    break unless curr
                                end
                            else
                                level += 1
                            end
                            last_key = key
                            indents[indent.length] = level
                            if indent.length > prev_indent.length
                                indent_size = indent.length - prev_indent.length
                            end
                            prev_indent = indent
                            
                            curr = curr[key] if curr
                            
                            if value
                                if curr
                                    res << indent
                                    if curr.is_a?(Hash) || curr.is_a?(Array)
                                        curr.instance_eval("def to_yaml_style; :inline; end")
                                    end
                                    res << {key => curr}.to_yaml.split("\n")[1..-1].join("\n") + "\n"
                                else
                                    res << line
                                end
                            else
                                context << key
                                res << line
                            end
                            if !context.empty? && data[:_add] && data[:_add][context]
                                lines = data[:_add][context].to_yaml.split("\n")[1..-1]
                                add_next = lines
                            end
                            

                        elsif line =~ /^\s*$/
                            unless curr_val.empty?
                                commit_ml(res, last_key, curr_val, curr)
                                curr_val = ""
                            end
                            curr = data
                            res << line
                        elsif line =~ /^\s*#/
                            res << line
                        else # value line
                            curr_val << line
                        end
                    end
                    unless curr_val.empty?
                        commit_ml(res, last_key, curr_val, curr)
                    end
                    
                    if data[:_add] && data[:_add][[]]
                        res << "\n\n\n"
                        data[:_add][[]].to_yaml.split("\n")[1..-1].each do |l|
                            res << l + "\n"
                        end
                    end
                    
                    res.close
                end
                bak_file = File.join(dirname, ".#{basename}.previous")
                FileUtils.mv(file, bak_file)
                FileUtils.mv(tmp_file, file)
            end
        end
        
    end
    
end
