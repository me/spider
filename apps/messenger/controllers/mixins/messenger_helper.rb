require 'erb'
require 'mail'

Spider.register_resource_type(:email, :extensions => ['erb'], :path => 'templates/email')

module Spider; module Messenger
    
    module MessengerHelper
        
        # Compiles an e-mail from given template and scene, and sends it using
        # #Messenger::email
        # template is the template name (found in templates/email), without the extension
        # will use template.html.erb and template.txt.erb if they exist, template.erb otherwise.
        # attachments must be an array, which items can be strings (the path to the file)
        # or Hashes:
        # {:filename => 'filename.png', :content => File.read('/path/to/file.jpg'),
        #   :mime_type => 'mime/type'}
        # Attachments will be passed to the Mail gem (https://github.com/mikel/mail), so any syntax allowed by Mail
        # can be used
        def send_email(template, scene, from, to, headers={}, attachments=[], params={})
            klass = self.class if self.class.respond_to?(:find_resouce_path)
            klass ||= self.class.app if self.class.respond_to?(:app)
            klass ||= Spider.home
            msg = Spider::Messenger::MessengerHelper.send_email(klass, template, scene, from, to, headers, attachments, params)
            @messenger_sent ||= {}
            @messenger_sent[:email] ||= []
            @messenger_sent[:email] << msg.ticket
            msg.ticket
        end
        
        def self.send_email(klass, template, scene, from, to, headers={}, attachments=[], params={})
            path_txt = klass.find_resource_path(:email, template+'.txt')
            path_txt = nil unless path_txt && File.exist?(path_txt)
            path_html = klass.find_resource_path(:email, template+'.html')
            path_html = nil unless path_html && File.exist?(path_html)
            scene_binding = scene.instance_eval{ binding }
            if (path_txt || path_html)
                text = ERB.new(IO.read(path_txt)).result(scene_binding) if path_txt
                html = ERB.new(IO.read(path_html)).result(scene_binding) if path_html
            else
                path = klass.find_resource_path(:email, template)
                text = ERB.new(IO.read(path)).result(scene_binding)
            end
            mail = Mail.new
            mail[:to] = to
            mail[:from] = from
            mail.charset = "UTF-8"
            headers.each do |key, value|
                mail[key] = value
            end

            if html
                mail.text_part do
                    body text
                end
                mail.html_part do
                    content_type 'text/html; charset=UTF-8'
                    body html
                end
            else
                mail.body = text
            end

            if attachments && !attachments.empty?
                attachments.each do |att|
                    if att.is_a?(Hash)
                        filename = att.delete(:filename)
                        mail.attachments[filename] = att
                    else
                        mail.add_file(att)
                    end
                end
            end
            mail_headers, mail_body = mail.to_s.split("\r\n\r\n", 2)
            mail_headers += "\r\n"
            Messenger.email(from, to, mail_headers, mail_body, params)
        end
        
        def sent_email(ticket)
            return unless ticket
            @messenger_sent ||= {}
            @messenger_sent[:email] ||= []
            @messenger_sent[:email] << ticket
        end
        
        def after(action='', *params)
            return super unless Spider.conf.get('messenger.send_immediate') && @messenger_sent
            Spider::Messenger.process_queue(:email, @messenger_sent[:email]) if @messenger_sent[:email]
            Spider::Messenger.process_queue(:sms, @messenger_sent[:sms]) if @messenger_sent[:sms]
        end
        
    end
    
end; end
