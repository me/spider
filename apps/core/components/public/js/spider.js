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
    
    init: function(container, path, config){
        this.el = container;
        this.path = path;
        this.backend = new Spider.WidgetBackend(this);
		this.readyFunctions = [];
		config = $.extend({}, config);
		this.config = config;
		this.model = config.model;
        Spider.widgets[path] = this;
		this.startup();
		this.ready();
		this.applyReady();
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
	
	applyReady: function(){
		for (var i=0; i<this.readyFunctions.length; i++){
			this.readyFunctions[i].apply(this);
		}
		Spider.newHTML(this.el);
	},
	
	reload: function(params, callback){
		$C.loadWidget(this.path, params, callback);
	},
	
	startup: function(){},
	ready: function(){},
	update: function(){},
	
	replaceHTML: function(html){
		var el = $(html);
		this.el.html(el.html());
		this.update();
		this.ready();
		this.applyReady();
	},
	
	paramName: function(key){
		var pathParts = this.path.split('/');
		var param = "_w";
		for (var i=0; i<pathParts.length; i++){
			param += "["+pathParts[i]+"]";
		}
		param += "["+key+"]";
		return param;
	},
	
	
	ajaxify: function(el, options){
		var w = this;
		if (!options) options = {};
		el.each(function(){
			var $this = $(this);
			if (this.tagName == 'FORM'){
				$('input[type=submit]', $this).click(function(e){
					e.preventDefault();
					w.setLoading();
					var submitName = $(this).attr('name');
					var submitValue = $(this).val();
					$this.ajaxSubmit({
						dataType: 'html',
						beforeSubmit: function(data, form, options){
							data.push({name: submitName, value: submitValue});
							data.push({name: '_wt', value: w.path});
						},
						success: function(res){
							w.replaceHTML(res);
							w.removeLoading();
						}
					});
				});
			}
			else if (this.tagName == 'A'){
				$this.click(function(e){
					if (options.before){
						var res = options.before.apply(this);
						if (res === false) return false ;
					}
					e.preventDefault();
					var a = $(e.target);
					var url = $(this).attr('href');
					var parts = url.split('?');
					url = parts[0]; //+'.json';
					url += '?';
					if (parts[1]) url += parts[1]+'&';
					url += '_wt='+w.path;
					w.setLoading();
					$.ajax({
						url: url,
						type: 'GET',
						dataType: 'html',
						success: function(res){
							w.replaceHTML(res);
							w.removeLoading();
						}
					});
				});
			}
		});

	},
	
	setLoading: function(){
		if (this.el.is(':empty')){
			this.el.addClass('loading-empty');
		}
		else{
			this.el.addClass('loading');
		}
	},
	
	removeLoading: function(){
		this.el.removeClass('loading').removeClass('loading-empty');
	},
	
	acceptDataObject: function(model, acceptOptions, droppableOptions){
		var cls = '.model-'+Spider.modelToCSS(model);
		droppableOptions = $.extend({
			accept: cls+' .dataobject',
			hoverClass: 'drophover'
		}, droppableOptions);
		acceptOptions = $.extend({
			el: this.el
		}, acceptOptions);
		if (acceptOptions.el != this.el){
			this.onReady(function(){ 
				$(acceptOptions.el, this.el).droppable(droppableOptions); 
			});
		}
		else this.el.droppable(droppableOptions);
	}
	
	
    
});

Spider.Widget.initFromEl = function(el){
	if (!el || !el.attr('id')) return;
    var path = Spider.Widget.pathFromId(el.attr('id'));
    var cl = el.attr('class');
    var cl_parts = cl.split(' ');
    var w_cl = null;
	var config = {};
    for (var i=0; i < cl_parts.length; i++){
        if (cl_parts[i].substr(0, 5) == 'wdgt-'){
            w_cl = cl_parts[i].substr(5);
            break;
        }
		else if (cl_parts[i].substr(0, 6) == 'model-'){
			config.model = cl_parts[i].substr(6);
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
    var obj = new func(el, path, config);
    return obj;
};

Spider.Widget.pathFromId = function(id){
	return id.replace(/-/, '/');
};



Spider.WidgetBackend = Class.extend({
   
	init: function(widget){
		this.widget = widget;
		this.url = document.location.href;
		this.urlParts = this.url.split('?');
		this.urlParts[0] = this.urlParts[0].split('#')[0];
	},
   
   send: function(method, args, options){
       var url = this.urlParts[0]+'?';
	   if (this.urlParts[1]) url += this.urlParts[1]+'&';
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
	if (w.autoInit){
		var initSelector = null;
		if (w.autoInit === true){
			initSelector = '.wdgt-'+parts.join('-');
		}
		else{
			initSelector = w.autoInit;
		}
		Spider.onHTML(function(){
			$(initSelector, this).each(function(){
				Spider.Widget.initFromEl($(this));
			});
		});
	}
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
	
	loadWidget: function(path, params, callback){
		var widget = $W(path);
		var href = document.location.href;
		var urlParts = this.url.split('?');
		var docParts = urlParts[0].split('#');
		var url = docParts[0]+'?_wt='+path;
		if (urlParts[1]) url += "&"+urlParts[1];
		if (params){
			for (var key in params){
				url += '&'+widget.paramName(key)+'='+params[key];
			}
		}
		widget.setLoading();
		$.ajax({
			url: url,
			type: 'GET',
			dataType: 'html',
			success: function(res){
				widget.replaceHTML(res);
				widget.removeLoading();
				widget.el.effect('highlight', {}, 700);
				if (callback) callback.apply(widget);
			}
		});
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
				a.trigger('autoAjaxSuccess', res);
			}
		});
		return false;
	});
});

$.fn.spiderWidget = function(){
	if (!this.attr('id')) return;
	return $W(Spider.Widget.pathFromId(this.attr('id')));
};

$.fn.parentWidget = function(){
	var par = this;
	while (par && !par.is('.widget')){
		par = par.parent();
	}
	if (!par) return null;
	return par.spiderWidget();
};

$.fn.getDataObjectKey = function(){
	var doParent = null;
	var par = this;
	while (par && !par.is('.dataobject')){
		par = par.parent();
	}
	if (!par) return null;
	return $('.dataobject-key', par).text();
};

$.fn.getDataModel = function(){
	var par = this;
	while (par && !par.is('.model')){
		par = par.parent();
	}
	if (!par) return null;
	var cl = this.attr('class');
    var cl_parts = cl.split(' ');
    for (var i=0; i < cl_parts.length; i++){
		if (cl_parts[i].substr(0, 6) == 'model-'){
			return cl_parts[i].substr(6);
		}
    }
};

Spider.htmlFunctions = [];
Spider.onHTML = function(callback){
	Spider.htmlFunctions.push(callback);
	if ($.isReady) callback.call($(document.body));
};

Spider.newHTML = function(el){
	for (var i=0; i<Spider.htmlFunctions.length; i++){
		Spider.htmlFunctions[i].call(el);
	}
};

Spider.modelToCSS = function(name){
	return name.split('::').join('-');
};
