function $W(path){
    // var path_parts = path.split('/');
    // var wdgt;
    // for (var i=0; i < path_parts.length; i++){
    //     wdgt = $('.widget.id-'+path_parts[i]);
    // }
    if (Spider.widgets[path]) return Spider.widgets[path];
    var wdgt_id = path.replace(/\//, '-');
    var wdgt = $('#'+wdgt_id);
    if (!wdgt) return null;
    var cl = wdgt.attr('class');
    var cl_parts = cl.split(' ');
    var w_cl = null;
    for (var i=0; i < cl_parts.length; i++){
        if (cl_parts[i].substr(0, 5) == 'wdgt-'){
            w_cl = cl_parts[i].substr(5);
            break;
        }
    }
    if (w_cl){
        var w_cl_parts = w_cl.split('-');
        var target = Widgets;
        for (var i=0; i < w_cl_parts.length; i++){
            target = target[w_cl_parts[i]];
            if (!target) break;
        }
    }
    var func = null;
    if (target) func = target;
    else func = Spider.Widget;
    var obj = new func(wdgt, path);
    Spider.widgets[path] = obj;
    return obj;
}


Spider = function(){};

Spider.widgets = {};

Widgets = function(){};

Spider.Widget = Class.extend({
    
    init: function(container, path){
        this.el = container;
        this.path = path;
    }
    
});

Spider.defineWidget = function(name, w){
    var parts = name.split('.');
    var curr = Widgets;
    for (var i=0; i<parts.length-1; i++){
        if (!curr[parts[i]]) curr[parts[i]] = function(){};
        curr = curr[parts[i]];
    }
    curr[parts[parts.length-1]] = Spider.Widget.extend(w);
};

