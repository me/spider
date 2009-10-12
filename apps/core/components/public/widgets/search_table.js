Spider.defineWidget('Spider.Components.SearchTable', 'Spider.Components.Table', {
	
	autoInit: true,
	
	ready: function(){
		this._super();
		this.ajaxify($('form', this.el));
	}
	
});