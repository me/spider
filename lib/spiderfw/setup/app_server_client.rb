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
        
        def specs
            load_specs unless @specs
            @specs
        end
        
        def http_get(url)
            uri = URI.parse(url)
            proxy = uri.find_proxy
            klass = proxy ? Net::HTTP::Proxy(proxy.host, proxy.port) : Net::HTTP
            result = klass.get_response(uri)
            raise "#{result.code} #{result.message} #{uri}" if result.is_a?(Net::HTTPClientError)
            result.body
        end
        
        def load_specs
            result = http_get(@url+'/list.json')
            list = JSON.parse(result)
            @specs = list.map{ |app| Spider::App::AppSpec.parse_hash(app) }
        end
        
        def get_specs(app_ids)
            app_ids = [app_ids] unless app_ids.is_a?(Array)
            result = http_get(@url+"/list/#{app_ids.join('+')}.json")
            JSON.parse(result).map{ |app| Spider::App::AppSpec.parse_hash(app) }
        end
        
        def get_deps(app_ids, options={})
            app_ids = [app_ids] unless app_ids.is_a?(Array)
            url = "#{@url}/deps/#{app_ids.join('+')}.json"
            url += "?no_optional=true" if options[:no_optional]
            result = http_get(url)
            JSON.parse(result).map{ |app| Spider::App::AppSpec.parse_hash(app) }
        end
        
        def fetch_app(app_id)
            tmp = Tempfile.open("spider-app-archive")
            res = http_get(@url+"/pack/#{app_id}")
            tmp << res
            tmp.path
        end
        

    end 

end