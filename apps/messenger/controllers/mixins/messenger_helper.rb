require 'erb'
require 'mailfactory'

Spider.register_resource_type(:email, :extensions => ['erb'], :path => 'templates/email')

module Spider; module Messenger
    
    module MessengerHelper
        
        # Compiles an e-mail from given template and scene, and sends it using
        # #Messenger::email
        # template is the template name (found in templates/email), without the extension
        # will use template.html.erb and template.txt.erb if they exist, template.erb otherwise.
        # attachments must be an array of hashes like 
        # {:file => '/full/file/path', :type => 'mime type', :file_name => 'optional email file name', 
        # :headers => 'optional string or array of additional headers'}
        def send_email(template, scene, from, to, headers={}, attachments=[], params={})
            klass = self.class if self.class.respond_to?(:find_resouce_path)
            klass ||= self.class.app if self.class.respond_to?(:app)
            klass ||= Spider.home
            Spider::Messenger::MessengerHelper.send_email(klass, template, scene, from, to, headers, attachments, params)
        end
        
        def self.send_email(klass, template, scene, from, to, headers={}, attachments=[], params={})
            path_txt = klass.find_resource_path(:email, template+'.txt')
            path_txt = nil unless File.exist?(path_txt)
            path_html = klass.find_resource_path(:email, template+'.html')
            path_html = nil unless File.exist?(path_html)
            scene_binding = scene.instance_eval{ binding }
            if (path_txt || path_html)
                text = ERB.new(IO.read(path_txt)).result(scene_binding) if path_txt
                html = ERB.new(IO.read(path_html)).result(scene_binding) if path_html
            else
                path = klass.find_resource_path(:email, template)
                text = ERB.new(IO.read(path)).result(scene_binding)
            end
            mail = MailFactory.new
            mail.To = to
            mail.From = from
            headers.each do |key, value|
                mail.add_header(key, value)
            end
            mail.html = html if html
            mail.text = text if text
            if (attachments && !attachments.empty?)
                attachments.each do |att|
                    if (att[:file_name])
                        mail.add_attachment_as(att[:file], att[:file_name], att[:type], att[:headers])
                    else
                        mail.add_attachment(att[:file], att[:type], att[:headers])
                    end
                end
            end
            mail_headers, mail_body = mail.to_s.split("\r\n\r\n", 2)
            mail_headers += "\r\n"
            Messenger.email(from, to, mail_headers, mail_body, params)
        end
    end
    
end; end