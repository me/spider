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
    return Spider.Widget.initFromEl(wdgt);
}


Spider = function(){};

Spider.widgets = {};

Widgets = function(){};

Spider.Widget = Class.extend({
    
    init: function(container, path){
        this.el = container;
        this.path = path;
        this.backend = new Spider.WidgetBackend(this);
		this.readyFunctions = [];
        Spider.widgets[path] = this;
		this.startup();
		this.ready();
    },
    
    remote: function(){
        var args = Array.prototype.slice.call(arguments); 
        var method = args.shift();
        return this.backend.send(method, args);
    },

	onReady: function(callback){
		this.readyFunctions.push(callback);
		callback.apply(this);
	},
	
	ready: function(){
		for (var i=0; i<this.readyFunctions.length; i++){
			this.readyFunctions[i].apply(this);
		}
	},
	
	reload: function(){
		$C.loadWidget(this.path);
	},
	
	startup: function(){},
	update: function(){},
	
	replaceHTML: function(html){
		var el = $(html)
		this.el.html(el.html());
		this.update();
		this.ready();
	}
	
	
    
});

Spider.Widget.initFromEl = function(el){
    var path = el.attr('id').replace(/-/, '/');
    var cl = el.attr('class');
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
    var obj = new func(el, path);
    return obj;
};



Spider.WidgetBackend = Class.extend({
   
   init: function(widget){
       this.widget = widget;
       this.url = document.location;
   },
   
   send: function(method, args, options){
       var url = this.url+'?';
       url += '_wt='+this.widget.path;
       url += '&_we='+method;
       for (var i=0; i<args.length; i++){
           url += '&_wp[]='+args[i];
       }
       var data = {};
       var callback = this.widget[method+'_response'];
       if (!callback) callback = function(){};
       var defaults = {
          url: url,
          type: 'POST',
          success: callback,
          data: data
       };
       options = $.extend(defaults, options);
       $.ajax(options);
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

Spider.Controller = Class.extend({
    
    init: function(){
		var url = ''+document.location;
		var slashPos = url.lastIndexOf('/');
		url = url.substr(0, slashPos);
		this.url = url;
    },
    
	remote: function(method, params, callback, options){
		var args = Array.prototype.slice.call(arguments); 
		if (!callback) callback = function(){};
		var url = this.url+'/'+method+'.json';
		var defaults = {
			url: url,
			type: 'POST',
			complete: callback,
			data: params
		};
		options = $.extend(defaults, options);
		$.ajax(options);
	},
	
	loadWidget: function(path){
		var url = document.location+'?_wt='+path;
		$.ajax({
			url: url,
			type: 'GET',
			dataType: 'html',
			success: function(res){
				$W(path).replaceHTML(res);
				$W(path).el.effect('highlight', {}, 500);
			}
		})
	}
    
});

$C = new Spider.Controller();

$(document).ready(function(){
	$('a.ajax').click(function(e){
		e.preventDefault();
		var a = $(e.target);
		var url = $(this).attr('href');
		var parts = url.split('?');
		url = parts[0]+'.json';
		if (parts[1]) url += '?'+parts[1];
		$.ajax({
			url: url,
			type: 'GET',
			dataType: 'json',
			success: function(res){
				a.trigger('ajaxSuccess', res);
			}
		})
		return false;
	})
})
