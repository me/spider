module Spider
    
    class Request
        attr_accessor :params, :env, :protocol, :format, :extension
        
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
        # from Merb
        def parse_query(qs, d = '&;')
          @params = (qs||'').split(/[#{d}] */n).inject({}) { |h,p| 
            key, value = unescape(p).split('=',2)
            normalize_params(h, key, value)
          }
        end
        
        # ==== Parameters
        # s<String>:: String to URL escape.
        #
        # ==== returns
        # String:: The escaped string.
        #--
        # from Merb        
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
        # from Merb
        def unescape(s)
          s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
            [$1.delete('%')].pack('H*')
          }
        end
        
        # Converts a query string snippet to a hash and adds it to existing
        # parameters.
        #
        # ==== Parameters
        # parms<Hash>:: Parameters to add the normalized parameters to.
        # name<String>:: The key of the parameter to normalize.
        # val<String>:: The value of the parameter.
        #
        # ==== Returns
        # Hash:: Normalized parameters
        #--
        # from Merb
        def normalize_params(parms, name, val=nil)
          name =~ %r([\[\]]*([^\[\]]+)\]*)
          key = $1 || ''
          after = $' || ''

          if after == ""
            parms[key] = val
          elsif after == "[]"
            (parms[key] ||= []) << val
          elsif after =~ %r(^\[\])
            parms[key] ||= []
            parms[key] << normalize_params({}, after, val)
          else
            parms[key] ||= {}
            parms[key] = normalize_params(parms[key], after, val)
          end
          parms
        end        
        
    end
    
end