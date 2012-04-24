require 'net/http'
require 'uri'
require 'json'
require 'open-uri'
require 'spiderfw/app'

module Spider

    class AppServerClient
        
        def initialize(url)
            @url = url
        end
        
        def specs(branch=nil)
            load_specs unless @specs
            @specs
        end
        
        def http_get(url)
            uri = URI.parse(url)
            proxy = uri.find_proxy
            klass = nil
            if proxy
                proxy_user, proxy_pass = nil
                proxy_user, proxy_pass = proxy.userinfo.split(/:/) if proxy.userinfo
                klass = Net::HTTP::Proxy(proxy.host, proxy.port, proxy_user, proxy_pass)
            else
                klass = Net::HTTP
            end
            result = klass.get_response(uri)
            raise "#{result.code} #{result.message} #{uri}" if result.is_a?(Net::HTTPClientError)
            result.body
        end
        
        def load_specs
            url = @url+'/list.json'
            result = http_get(url)
            list = JSON.parse(result)
            @specs = list.map{ |app| Spider::App::AppSpec.parse_hash(app) }
        end
        
        def get_specs(app_ids)
            app_ids = [app_ids] unless app_ids.is_a?(Array)
            url = @url+"/list/#{app_ids.join('+')}.json"
            result = http_get(url)
            JSON.parse(result).map{ |app| Spider::App::AppSpec.parse_hash(app) }
        end
        
        def get_deps(app_ids, options={})
            app_ids = [app_ids] unless app_ids.is_a?(Array)
            url = "#{@url}/deps/#{app_ids.join('+')}.json"
            params = []
            params << 'no_optional=true' if options[:no_optional]
            url += '?'+params.join('&') unless params.empty?
            result = http_get(url)
            JSON.parse(result).map{ |app| Spider::App::AppSpec.parse_hash(app) }
        end
        
        def fetch_app(app_id, branch=nil)
            tmp = Tempfile.new("spider-app-archive")
            tmp.binmode
            url = @url+"/pack/#{app_id}"
            url += "?branch=#{branch}" if branch
            res = http_get(url)
            tmp << res
            tmp.flush
            tmp.path
        end
        

    end 

end