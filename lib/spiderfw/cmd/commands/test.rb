class TestCommand < CmdParse::Command


    def initialize
        super( 'test', true, true )
        @short_desc = _("Manage tests")
#        @description = _("")
        @apps = []

        run_cmd = CmdParse::Command.new( 'run', false )
        run_cmd.short_desc = _("Run tests")
        # run.options = CmdParse::OptionParserWrapper.new do |opt|
        #     opt.on("--app", 
        #            _("Run tests only for an app"),
        #            "-a"){ |app|
        #         @apps << app
        #     }
        # end
        run_cmd.set_execution_block do |apps|
            require 'test/unit/collector/dir'
            require 'test/unit'
            apps = Spider.apps.keys if (!apps || apps.length < 1)
            collector = Test::Unit::Collector::Dir.new()
            apps.each do |name|
                next unless File.exist?(Spider.apps[name].test_path)
                collector.collect(Spider.apps[name].test_path)
            end
        end
        self.add_command(run_cmd)


    end

end