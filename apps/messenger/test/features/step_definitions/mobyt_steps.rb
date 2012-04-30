require 'apps/messenger/lib/backends/mobyt'


Dato /^che lo username è "([^\"]*)"$/ do |username|
    @username = username
    Spider.conf.set('messenger.mobyt.username',username)
end

Dato /^che la password è "([^\"]*)"$/ do |password|
    @password = password
    Spider.conf.set('messenger.mobyt.password',password)
end

Quando /^invio un sms con i seguenti dati$/ do |table|
    to = table.hashes.first["to"] 
    from = table.hashes.first["from"]
    testo = table.hashes.first["testo"]
    @risultato = Spider::Messenger::Mobyt.parametri(@username,@password,to,from,testo)  
end

Allora /^il backend deve restituire i seguenti dati$/ do |table|
    table.rows_hash.each do |key, value|
        @risultato[key.to_sym].should eq value
    end
end  

Dato /^che il backend è solo di tipo "([^\"]*)"$/ do |backend|
    require "apps/messenger/backends/sms/#{backend}"
    Spider.conf.set('messenger.sms.backends', [backend])
end


Dato /^che il from è "([^\"]*)"$/ do |from|
    Spider.conf.set('messenger.mobyt.from',from)
end

Quando /^invio un messaggio con messenger$/ do
    Spider::Messenger.sms("+39123456789", "Ciao")   
end

Quando /^faccio girare la coda dei messaggi$/ do
    require "net/http"

    module Net
        class HTTP 
            def self.post_form(uri, data)
                $uri_http = uri
                $data_http = data
            end

        end

    end
    Spider::Messenger.process_queue(:sms)
end

Allora /^deve essere fatta una chiamata in "([^\"]*)" all.url "([^\"]*)"$/ do |post, url|
    $uri_http.to_s.should eq url
end
