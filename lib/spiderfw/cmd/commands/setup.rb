require 'spiderfw/utils/setup_task'

class SetupCommand < CmdParse::Command


    def initialize
        super( 'setup', false, true )
        @short_desc = _("Setup an application")
#        @description = _("")
        @apps = []
        @version = nil
        
        options = CmdParse::OptionParserWrapper.new do |opt|
            # TODO
            opt.on("--version", _("Setup to a specific version"), "-v"){ |version|
                @version = version
            }
        end
        

        set_execution_block do |apps|
            apps = Spider.apps.keys if (!apps || apps.length < 1)
            apps.each do |name|
                path = Spider.apps[name].setup_path
                next unless File.exist?(path)
                Dir.entries(path).sort.each do |entry|
                    next if (entry[0].chr == '.')
                    Spider.logger.info("Running setup task #{path+'/'+entry}")
                    load(path+'/'+entry)
                    task = Spider::SetupTask.current_task.new
                    task.run
                end
            end 
        end


    end

end