module Spider; module Master
    
    class ScoutError < Spider::Model::Managed
       element :plugin_instance, ScoutPluginInstance, :add_multiple_reverse => :errors
       element :subject, Text
       element :body, Text
       
       
       with_mapper do
           
           def before_save(obj, mode)
               return super unless mode == :insert && obj.plugin_instance
               debugger
               obj.plugin_instance.report_admins.each do |adm|
                   next unless adm.email
                   Spider::Messenger.email(
                        Spider.conf.get('master.from_email'), adm.email, {
                            'Subject' => "Spider alert: #{obj.subject}"
                        }, obj.body
                   )
               end

           end
           
       end
        
    end
    
end; end