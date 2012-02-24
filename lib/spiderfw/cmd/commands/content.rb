require 'fileutils'

module Spider::CommandLine

    class ContentCommand < CmdParse::Command


        def initialize
            super( 'content', true, true )
            @short_desc = _("Manage static content")
            
            publish = CmdParse::Command.new( 'publish', false )
            publish.short_desc = _("Publish apps static content to home public folder")
            publish.options = CmdParse::OptionParserWrapper.new do |opt|
            end
            
            publish.set_execution_block do |args|
                require 'spiderfw/init'
                Spider::StaticContent.publish
            end
            
            self.add_command(publish)
            
            compress = CmdParse::Command.new('compress', false)
            compress.short_desc = _("Compress Javascript files")
            compress.set_execution_block do |args|
                require 'spiderfw/init'
                Spider::ContentUtils.compress(*args)
            end
            
            self.add_command(compress)
            
        end
        
    end

end