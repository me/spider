Spider.defineWidget('Spider.Forms.FileInput', 'Spider.Forms.Input', {
	
	autoInit: true,
	
	ready: function(){
		var self = this;
		var fileLink = $('.file-link', this.el);
		if (fileLink.size() == 1){
			var changeLabel = $('.change-label', this.el).text();
			var changeDiv = $('.change', this.el);
			changeDiv.hide();
			$('.clear', this.el).hide();
			var clearCheckBox = $('.clear input:checkbox', this.el);
			var fileInput = $('.change input', this.el);
			
			var link = $('<a href="#" class="js-change-link"/>');
			link.text(changeLabel+'...')
				.insertAfter(fileLink)
				.click(function(e){
					e.preventDefault();
					if (clearCheckBox.is(':checked')){
						link.removeClass('open');
						fileLink.removeClass('deleted');
						clearCheckBox.attr('checked', false);
						changeDiv.hide();
					}
					else{
						fileLink.addClass('deleted');
						clearCheckBox.attr('checked', true);
						link.addClass('open');
						changeDiv.show();
					}
				});
		}
		
	}    
});