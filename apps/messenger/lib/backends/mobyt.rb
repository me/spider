require 'digest/md5'
require 'net/http'
require 'iconv'

module Spider::Messenger

      module Mobyt

            def self.parametri(username,password,to,from,testo,operation="TEXT",udh="")
                  #cambio la codifica per gli accenti e caratteri particolari
                  testo_codificato = Iconv.conv('ISO-8859-15', 'UTF-8', testo)
                  string_digest = [username, operation, to, from, testo_codificato, password].map{ |val|
                      val.to_s 
                  }.join("")
                  ticket = Digest::MD5.hexdigest(string_digest).downcase
                  hash_parametri = {
                      'rcpt'       => to, 
                      'operation'  => operation,
                      'from'       => from,
                      'data'       => testo_codificato,
                      'id'         => username,
                      'qty'        => "h",
                      'ticket'     => ticket,
                      'udh'        => udh         
                  }

            end

            def self.do_post_request(uri,data)
                  response = Net::HTTP.post_form(uri,data) 
            end


            def self.check_response_http(response)
                  case response
                  when Net::HTTPSuccess
                      if response.body !~ /^OK/
                          raise response.body
                      else
                          return true 
                      end
                  else
                      #solleva un eccezione
                      raise response.class.to_s
                  end         
            end

      end      

end