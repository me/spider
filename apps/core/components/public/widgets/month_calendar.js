Spider.defineWidget('Spider.Components.MonthCalendar', {
	
	autoInit: true,
	
	ready: function(){
		this.ajaxify($('thead a', this.el));
	}

});
