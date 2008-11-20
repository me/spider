class ConsoleCommand < CmdParse::Command


    def initialize
        super( 'console', false )
        @short_desc = _("Open a console")
#        @description = _("")
        @opts = {:irb => 'irb'}
        
        options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--irb", 
                   _("Irb executable to use"),
                   "-i"){ |irb|
                @opts[:irb] = irb
            }
        end
        
        set_execution_block do
            exec("#{@opts[:irb]} -I #{$SPIDER_LIB} -r spiderfw")
        end


    end

end