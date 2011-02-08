module Spider; module Messenger
    class MailTestController < Spider::PageController
       include Spider::Messenger::MessengerHelper
       
       attr_accessor :attachments
   
   
       __.action
       def test_send_email(template)
           att = nil
           if @attachments
               att = @attachments.map{ |a|
                   if a.is_a?(Hash)
                       h = {}
                       a.each do |k, v|
                           if k == "path"
                               path = File.join(Spider::Messenger.path, 'test/files', v)
                               h[:content] = File.read(path)
                           else
                               h[k.to_sym] = v
                           end
                       end
                       h
                   else
                       File.join(Spider::Messenger.path, 'test/files', a)
                   end
               }
           end
           send_email(template, @scene, TEST_EMAIL[:from], TEST_EMAIL[:to], {:Subject => "Test - #{template} template"}, att)
       end
    
    end
    
end; end