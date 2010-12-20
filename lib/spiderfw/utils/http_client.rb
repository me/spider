require 'open-uri'

module Spider

    def self.http_client
        uri = URI.parse('http://www.test.com')
        proxy = uri.find_proxy
        klass = nil
        if proxy
            proxy_user, proxy_pass = nil
            proxy_user, proxy_pass = proxy.userinfo.split(/:/) if proxy.userinfo
            Net::HTTP::Proxy(proxy.host, proxy.port, proxy_user, proxy_pass)
        else
            Net::HTTP
        end
    end

end