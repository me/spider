module Spider
    
    class Environment < Hash
        attr_accessor :protocol
        attr_reader :request, :session, :cookies

        
        def initialize
        end
        
        def request=(req)
            @request = req
            parse_request
        end
        
        def parse_request
        end
        
        # ==== Parameters
        # s<String>:: String to URL escape.
        #
        # ==== returns
        # String:: The escaped string.
        #--
        # Note: Stolen from Merb
        def escape(s)
          s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
            '%'+$1.unpack('H2'*$1.size).join('%').upcase
          }.tr(' ', '+')
        end

        # ==== Parameter
        # s<String>:: String to URL unescape.
        #
        # ==== returns
        # String:: The unescaped string.
        #--
        # Note: Stolen from Merb        
        def unescape(s)
          s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
            [$1.delete('%')].pack('H*')
          }
        end

        # ==== Parameters
        # qs<String>:: The query string.
        # d<String>:: The query string divider. Defaults to "&".
        #
        # ==== Returns
        # Mash:: The parsed query string.
        #
        # ==== Examples
        #   query_parse("bar=nik&post[body]=heya")
        #     # => { :bar => "nik", :post => { :body => "heya" } }
        #--
        # Note: Stolen from Merb        
        def query_parse(qs, d = '&;')
          (qs||'').split(/[#{d}] */n).inject({}) { |h,p| 
            key, value = unescape(p).split('=',2)
            normalize_params(h, key, value)
          }.to_mash
        end
        
    end
    
end