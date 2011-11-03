class ConsoleCommand < CmdParse::Command


    def initialize
        super( 'console', false )
        @short_desc = _("Open a console")
#        @description = _("")
        @opts = {}
        
        self.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--irb [IRB]", 
                   _("Use irb instead of ripl (use given executable if supplied)"),
                   "-i"){ |irb|
                @opts[:irb] = irb ? irb : 'irb'
            }
        end
        
        set_execution_block do
            unless @opts[:irb]
                begin
                    require 'rubygems'
                    require 'ripl'
                rescue LoadError
                    @opts[:irb] = 'irb'
                end
            end
            if @opts[:irb]
                ENV['SPIDER_RUNMODE'] = $SPIDER_RUNMODE if ($SPIDER_RUNMODE)
                ENV['SPIDER_CONFIG_SETS'] = $SPIDER_CONFIG_SETS.join(',') if ($SPIDER_CONFIG_SETS)
                exec("#{@opts[:irb]} -I #{$SPIDER_LIB} -r spiderfw")
            else
                require 'ripl/irb'
                require 'ripl/multi_line' 
                
                Ripl.config[:irb_verbose] = false
                Ripl::Runner.load_rc(Ripl.config[:riplrc])
                
                require 'spiderfw/init'
                Object.send(:remove_const, :IRB) if Object.const_defined?(:IRB)
                Ripl.shell.loop
            end
        end


    end

end
