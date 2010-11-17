require 'cgi'

module Spider; module Forms
    
    class HTMLArea < Input
        tag 'htmlarea'
        
        is_attr_accessor :rows, :type => Fixnum, :default => 6
        is_attr_accessor :cols, :type => Fixnum, :default => 80
        attribute :"full-page", :type => Spider::Bool
        
        def prepare
            super
            @scene.initial_html = @initial_html ? CGI.escapeHTML(@initial_html) : ''
            @scene.css = @css
            options = {}
            options[:file_manager] = Spider::Files.http_url(:manager) if Spider.app?('spider_files')
            options[:image_manager] = Spider::Images.http_url(:manager) if Spider.app?('spider_images')
            options[:full_page] = attributes[:"full-page"]
            @scene.options = options.to_json
        end
        
        
        def parse_runtime_content(doc, src_path=nil)
            html = doc.search('wparam:html')
            html = html.first if html
            if html
                @initial_html = replace_content_vars(html.innerHTML)
            end
            doc.search('wparam:html').remove
            
            css = doc.search('wparam:css')
            css = css.first if css
            if css
                @css = replace_content_vars(css.innerHTML)
            end
            doc.search('wparam:css').remove
            
            val = doc.search('wparam:value')
            val = val.first if val
            if val
                @value = replace_content_vars(val.innerHTML)
            end
            doc.search('wparam:value').remove
            
        end
            

    end
    
end; end