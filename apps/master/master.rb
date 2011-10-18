module Spider
   
   module Master
      
       def self.app_init
          Spider.home.controller.route 'clients', Spider::Master::ScoutController
       end
       
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
       
       def self.url_for_server(id)
           id = id.id if id.is_a?(Spider::Model::BaseModel)
           server = Server.new(id)
           "#{self.url}/servers/#{server.id}"
       end
       
       def self.url_for_plugin(id)
           id = id.id if id.is_a?(Spider::Model::BaseModel)
           instance = ScoutPluginInstance.new(id)
           "#{self.url}/servers/#{instance.server.id}/plugins/#{id}"
       end
       
       def self.add_site_type(type)
           @site_types ||= []
           @site_types << type
       end
       
       def self.site_types
           @site_types ||= []
       end
       
   end
    
end