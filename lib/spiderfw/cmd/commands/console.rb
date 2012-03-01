module Spider::CommandLine

    class ConsoleCommand < CmdParse::Command


        def initialize
            super( 'console', false )
            @short_desc = _("Open a console")
    #        @description = _("")
            @opts = {}
            
            self.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--irb [IRB]",  _("Use irb (you can specify the executable to use)"), "-i"){ |irb|
                    @opts[:irb] = irb ? irb : 'irb'
                }
                opt.on('--ripl' ,_("User ripl"), "-r"){ |ripl| @opts[:ripl] = true }
                opt.on('--pry', _("Use Pry if available (the default)"))
            end
            
            set_execution_block do
                if @opts[:ripl]
                    begin
                        require 'rubygems'
                        require 'ripl'
                    rescue LoadError
                        @opts[:irb] = 'irb'
                    end
                end
                unless @opts[:irb]
                    begin
                        require 'rubygems'
                        require 'pry'
                    rescue LoadError
                        @opts[:irb] = 'irb'
                    end
                end
                if @opts[:irb]
                    ENV['SPIDER_RUNMODE'] = $SPIDER_RUNMODE if ($SPIDER_RUNMODE)
                    ENV['SPIDER_CONFIG_SETS'] = $SPIDER_CONFIG_SETS.join(',') if ($SPIDER_CONFIG_SETS)
                    exec("#{@opts[:irb]} -I #{$SPIDER_LIB} -r spiderfw/init")
                elsif @opts[:ripl]
                    require 'ripl/irb'
                    require 'ripl/multi_line' 
                    
                    Ripl.config[:irb_verbose] = false
                    Ripl::Runner.load_rc(Ripl.config[:riplrc])
                    
                    require 'spiderfw/init'
                    Object.send(:remove_const, :IRB) if Object.const_defined?(:IRB)
                    Ripl.shell.loop
                else
                    try_require 'pry-nav'
                    try_require 'pry-stack_explorer'
                    require 'spiderfw/init'
                    Pry.start
                end
            end


        end

        def try_require(lib)
            begin
               require lib 
            rescue LoadError => e
            end
        end

    end

end
