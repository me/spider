require 'apps/messenger/lib/sms_backend'
require 'apps/messenger/lib/backends/mobyt'




module Spider; module Messenger; module Backends; module SMS

    module Mobyt
        include Messenger::SMSBackend

        def self.send_message(msg)
            Spider.logger.debug("**Sending SMS with mobyt**")
            username = Spider.conf.get('messenger.mobyt.username')
            password = Spider.conf.get('messenger.mobyt.password')
            from = Spider.conf.get('messenger.mobyt.from')    
            to = msg.to
            text = msg.text
            #trasformo gli accenti 
            text = Spider::Messenger::Mobyt.trasforma_accenti(text)
            uri = URI('http://smsweb.mobyt.it/sms-gw/sendsmart')
            
            testi = Hash.new
            #se mando messaggio lungo spezzo in più messaggi
            if text.size > 160
                tot_response = true
                operation="MULTI"
                
                cnt = 0
                index = 1
                mes = ""
                (text + " ").scan(/.{1,153}\s/).map{ |s|
                    testi[index] = s
                    index += 1 
                }
                tot_testi = testi.size
                #tolgo lo spazio che era stato aggiunto al testo nell'ultimo messaggio
                testi[tot_testi] = testi[tot_testi].strip
                #invio sms con testi in hash testi
                testi.each{ |key,testo|
                    # udh=aabbcc: aa=id sequenza, bb=tot messaggi, cc=id del messaggio nella sequenza
                    udh = "010"+tot_testi.to_s+"0"+key.to_s  
                    uri_params = Spider::Messenger::Mobyt.parametri(username,password,to,from,testo,operation,udh)
                    response = Spider::Messenger::Mobyt.do_post_request(uri, uri_params)
                    Spider::Messenger::Mobyt.check_response_http(response)
                }

            else
                uri_params = Spider::Messenger::Mobyt.parametri(username,password,to,from,text)
                response = Spider::Messenger::Mobyt.do_post_request(uri, uri_params)
                Spider::Messenger::Mobyt.check_response_http(response)
            end

            true            
        end

    end



end; end; end; end    