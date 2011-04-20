module Spider; module Test
    
    class PageObject
        attr_reader :browser
        
        def initialize(browser=nil)
            unless browser
                if Object.const_defined?(:Capybara) && Capybara.current_session
                    browser = Capybara.current_session
                end
            end
            @browser = browser
        end
        
        def go(url)
            if url =~ /^https?:\/\/([^\/])(\/.+)$/
                url = $1
            end
            @browser.visit(url)
        end
        
        def method_missing(method, *args)
            @browser.send(method, *args)
        end
        
        
    end
    
end; end