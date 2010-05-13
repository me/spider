require 'fileutils'
require 'find'

module Spider
    
    module StaticContent
        
        def self.publish
            Spider.apps.each do |name, app|
                next unless File.directory?(app.pub_path)
                dest = Spider::HomeController.app_pub_path(app)
                FileUtils.mkdir_p(dest)
                Dir.new(app.pub_path).each do |file|
                    next if file[0].chr == '.'
                    FileUtils.cp_r("#{app.pub_path}/#{file}", "#{dest}/#{file}")
                end
            end
        end
        
        def self.compress(*apps)
            require 'yui/compressor'
            apps = Spider.apps.keys if apps.empty?
            apps.each do |app_name|
                app = Spider.apps[app_name]
                raise "Can't find app #{app_name}" unless app
                next unless File.directory?(app.pub_path)
                pub_path = nil
                if Spider.conf.get('static_content.mode') == 'publish'
                    pub_path = Spider::HomeController.app_pub_path(app)
                else
                    pub_path = app.pub_path
                end
                tmp_combined = Spider.paths[:tmp]+'/_combined.js'
                combined = pub_path+'/.'+app.short_name+'.js'
                combine_js(pub_path, tmp_combined)
                recompress = true
                recompress = false if File.exists?(combined) && md5sum(combined) == md5sum(tmp_combined)
                File.cp(tmp_combined, combined)
                File.rm(tmp_combined)
                next unless recompress
                version = 0
                curr = Dir.glob(pub_path+'/'+app.short_name+'.*.js')
                unless curr.empty?
                    curr.each do |f|
                        name = File.basename(f)
                        if name =~ /(\d+)\.js$/
                            version = $1 if $1 > version
                            File.unlink(f)
                        end
                    end
                end
                version += 1
                dest = "#{pub_path}/#{app.short_name}.#{version}.js"
                compressor = YUI::JavaScriptCompressor.new("charset" => "UTF-8")
                io = open(combined, 'r')
                res = compressor.compress(io)
                open(dest, 'w') do |f|
                    f << res
                end
            end
        end
        
        def self.combine_js(path, combined_file)
            combined = open(combined_file, 'w')
            Find.find(path) do |path|
                next if File.directory?(path)
                next if File.basename(path)[0].chr == '.'
                if File.extname(path) == '.js'
                    p "ADDING #{path}"
                    js = IO.read(path)
                    combined.write(js+"\n")                    
                end
            end
            combined.close
        end
        
        def self.md5sum(file)
            Digest::MD5.hexdigest(File.read(file))
        end
        
    end
    
    
end