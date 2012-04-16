Spider.defineWidget('Spider.Forms.Select', 'Spider.Forms.Input', {
    
    autoInit: true,
    
    ready: function(){
        var sel = this.el;
        if (sel.is('select[multiple]')){
            sel.attr('title', 'Aggiungi...');
            sel.bsmSelect({
                removeLabel: 'togli',
                highlightAddedLabel: 'Aggiunto: ',
                highlightRemovedLabel: 'Tolto: ',
                addItemTarget: 'bottom'
            });
            $('.bsmSelect option:first', sel.parent()).addClass('bsmSelectTitle')
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
