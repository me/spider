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
                text.strip.split.each { |str|
                    #str = Spider::Messenger::Mobyt.transforma_accentate(stringa)
                    cnt += str.size + 1
                    if cnt > 153
                        testi["#{index}"] = mes
                        mes = ""
                        cnt = str.size + 1
                        index += 1
                    end
                    mes << str.strip + " "                     
                }
                testi["#{index}"] = mes
                tot_testi = testi.size
                #invio sms con testi in hash testi
                testi.each_pair{ |key,testo|
                    #p key.to_i
                    #p testo
                    # udh=aabbcc: aa=id sequenza, bb=tot messaggi, cc=id del messaggio nella sequenza
                    udh = "010"+tot_testi.to_s+"0"+key
                    #p udh   
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