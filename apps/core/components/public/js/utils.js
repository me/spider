$.fn.makeConfirmable = function(){
    return this.each(function(){
        var a = $(this);
    	var cloned = a.clone();
    	cloned.insertAfter(a);
    	a.remove();
    	cloned.click(function(e){
    		e.preventDefault();
    		var div = $('<span class="confirm_box">'+_('Are you sure?')+'</span>');
    		div.css('margin-left', a.css('margin-left'));
            div.css('padding-left', a.css('padding-left'));
    		cloned.hide();
    		div.insertAfter(cloned);
    		a.text(_('Yes')).click(function(e){
    			div.remove();
    			cloned.show();
    		}).appendTo(div);
    		$('<span />').text(' ').appendTo(div);
    		$('<a href="#">'+_('No')+'</a>').click(function(e){
    			e.preventDefault();
    			cloned.show();
    			div.remove();
    			return false;
    		}).appendTo(div);
    	});
    });
};