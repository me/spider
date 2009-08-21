Spider.defineWidget('Spider.Core.List', {
    
    refresh: function(){
        var res = this.remote.call();
        this.update(res.data);
    },
    
    update: function(data){
        var ul = $(this.el, 'ul');
        ul.empty();
        res = this.remote.call();
        for (var i=0; i<this.keys.length; i++){
            var li = $('<li />').html(this.rows[i]).appendTo(ul);
            li.data('w_key', this.keys[i]);
        }
    },
    
    makeSortable: function(){
        var ul = $(this.el, 'ul');
        
    }
    
});