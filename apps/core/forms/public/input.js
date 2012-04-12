Spider.defineWidget('Spider.Forms.Input', {
    
    autoInit: false,
    
    startup: function(){
        var connect = this.getClassInfo('connect');
        var w = this;
        for (var i=0; i<connect.length; i++){
            var currConn = connect[i];
            $('.el-'+currConn, w.el.parents('form').eq(0)).parentWidget().change(function(val){
                w.onConnectedChange(currConn, val);
            });
        }
    },
    
    onConnectedChange: function(connected, val){
        this.reload();
    },
    
    change: function(callback){
        this.bind('change', callback);
    },
    
    val: function(){
        return this.el.val();
    }
    
    
    
});