Spider.defineWidget('Spider.Forms.DateTime', {
	
	autoInit: true,
	
	ready: function(){
		if (this.el.is('.date')) this.el.datepicker();
		else if (this.el.is('.date_time')){
			var el = this.el;
			el.hide();
			var val = el.val().split(' ');
			if (!val[1]) val[1] = '';
			var d = $('<input type="text" class="date" size="10" />').val(val[0]).insertAfter(el).datepicker();
			var span = $('<span> </span>').insertAfter(d);
			var t = $('<input type="text" class="time" size="8" />').val(val[1]).insertAfter(span);
			var updateDt = function(){
				el.val(d.val()+' '+t.val());
			};
			d.change(updateDt);
			t.change(updateDt);
		}
	}
    
});