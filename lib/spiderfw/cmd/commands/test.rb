module Spider::CommandLine

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
            
            self_cmd = CmdParse::Command.new('self', false)
            self_cmd.short_desc = _("Run framework tests")
            self_cmd.set_execution_block do
                require 'test/unit/collector/dir'
                require 'test/unit'
                $SPIDER_RUNMODE = 'test'
                require 'spiderfw/init'
                test_env = "#{$SPIDER_PATH}/test"
    #            Dir.cwd(test_env)
                $:.push(test_env)
                apps = Spider.find_apps_in_folder("#{test_env}/apps")
                Spider.apps.clear

                apps.each{ |app| Spider.load_app_at_path app }

                Spider._test_setup
                collector = Test::Unit::Collector::Dir.new()
                collector.collect("#{test_env}/tests")
                Spider._test_teardown
            end
            self.add_command(self_cmd)

            issue = CmdParse::Command.new('issue', false)
            issue.short_desc = _("Test for an issue")
            issue.set_execution_block do |args|
                id = args.first
                require 'spiderfw/spider'
                require 'spiderfw/test'
                
                test_path = File.join($SPIDER_PATH, 'test', 'issues')
                issue_no = id.rjust(5, "0")
                Dir.glob(File.join(test_path, "#{issue_no}-*")).each do |f|
                    require f
                end
                
            end
            self.add_command(issue)


        end

    end

end