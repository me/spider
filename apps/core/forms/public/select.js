Spider.defineWidget('Spider.Forms.Select', 'Spider.Forms.Input', {
	
	autoInit: true,
	
	ready: function(){
		if (this.el.is('select[multiple]')){
            this.el.attr('title', 'Aggiungi...');
		    this.el.bsmSelect({
    			removeLabel: 'togli',
    			highlightAddedLabel: 'Aggiunto: ',
    			highlightRemovedLabel: 'Tolto: ',
    			addItemTarget: 'top'
    		});
            $('.bsmSelect option:first', this.el.parent()).addClass('bsmSelectTitle')
                .attr("selected", false)
				.attr("disabled", true);
		} 
	},
	
	onConnectedChange: function(connected, val){
		var params = {};
		params[connected] = val;
		this.reload({connected: params});
	}
    
});