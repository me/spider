module Spider
   
   module Master
       
       def self.scout_plugins
           path = Spider.conf.get('master.scout_plugins_path')
           return [] unless path
           res = []
           Dir.new(path).each do |dir|
               next if dir[0].chr == '.'
               next unless File.directory?(File.join(path, dir))
               res << dir
           end
           res
       end
       
   end
    
end