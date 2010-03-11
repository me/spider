Spider.defineWidget('Spider.Forms.Select', 'Spider.Forms.Input', {
	
	autoInit: true,
	
	ready: function(){
		if (this.el.is('select[multiple]')) this.el.asmSelect({
			removeLabel: 'togli',
			highlightAddedLabel: 'Aggiunto: ',
			highlightRemovedLabel: 'Tolto: '
		});
	},
	
	onConnectedChange: function(connected, val){
		var params = {};
		params[connected] = val;
		this.reload({connected: params});
	}
    
});