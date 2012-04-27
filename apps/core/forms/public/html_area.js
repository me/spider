Spider.defineWidget('Spider.Forms.HTMLArea', 'Spider.Forms.Input', {
	
	autoInit: true,
	
	ready: function(){
        var options = {};
        var initialHtmlEl = $('.initial_html', this.el);
        var initialHtml;
        this.textarea = $('textarea', this.el);
        if (initialHtmlEl.length > 0){
            initialHtml = $.trim(initialHtmlEl.text());
        }
        if (initialHtml){
            initialHtml = initialHtml.replace(/INITIAL_CONTENT/, this.textarea.val());
            var h = $(initialHtml);
            this.textarea.val(initialHtml);
        }
        var cssEl = $('.css', this.el);
        var css;
        if (cssEl.length > 0){
            css = cssEl.text();
        }
        options = $.parseJSON($('.options', this.el).text());
        var config = {
            // extraPlugins : 'autogrow'
        };
        config.toolbar_simple =
        [
            ['Source','-','Preview','-'],
            ['PasteFromWord','-','Print', 'SpellChecker'],
            ['RemoveFormat'],
            ['Format'],
            ['TextColor','BGColor'],
            ['Maximize', 'ShowBlocks'],
            '/',
            ['Bold','Italic','Underline','Strike','-','Subscript','Superscript'],
            ['NumberedList','BulletedList','-','Outdent','Indent','Blockquote','CreateDiv'],
            ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
            ['Link','Unlink','Anchor'],
            ['Image','Table','HorizontalRule','SpecialChar']
        ];
        config.toolbar = 'simple';
        config.skin = 'BootstrapCK-Skin';
        config.filebrowserBrowseUrl = options.link_manager;
        config.filebrowserImageBrowseUrl = options.image_manager;
        config.filebrowserWindowFeatures = 'modal=yes,alwaysRaised=yes';
        config.fullPage = options.full_page;
        
        var self = this;
        this.textarea.ckeditor(function(){
            self.ckeditor = this;
            if (css){ this.ckeditor.addCss(css); }
        }, config);
        
	}
});
