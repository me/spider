Spider.defineWidget('Spider.Forms.DateTime', {
	
	autoInit: true,
	
	ready: function(){
	    var conf = {};
        this.input = this.el.find('input');
	    if (this.el.is('.change-month')) conf.changeMonth = true;
	    if (this.el.is('.change-year')) conf.changeYear = true;
        var classes = this.el.attr('class').split(' ');
        for (var i=0; i<classes.length; i++){
            var cl = classes[i];
            if (cl.substr(0, 10) == 'year-range'){
                var range = cl.substr(11).split('-');
                conf.yearRange = range[0].replace("m", "-")+":"+range[1].replace('p', '+');
                a = 3;
            }
        }
		if (this.el.is('.date')) this.input.datepicker(conf);
		else if (this.el.is('.date_time')){
			var el = this.input;
			el.hide();
			var val = el.val().split(' ');
			if (!val[1]) val[1] = '';
			var d = $('<input type="text" class="date" size="10" />').val(val[0]).insertAfter(el).datepicker(conf);
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