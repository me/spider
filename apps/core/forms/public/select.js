Spider.defineWidget('Spider.Forms.Select', 'Spider.Forms.Input', {
	
	autoInit: true,
	
	onConnectedChange: function(connected, val){
		var params = {};
		params[connected] = val;
		this.reload({connected: params});
	}
    
});