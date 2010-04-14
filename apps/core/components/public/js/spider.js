function $W(path){
    // var path_parts = path.split('/');
    // var wdgt;
    // for (var i=0; i < path_parts.length; i++){
    //     wdgt = $('.widget.id-'+path_parts[i]);
    // }
    if (Spider.widgets[path]) return Spider.widgets[path];
    var wdgt_id = path.replace(/\//g, '-');
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
		this.events = [];
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
		Spider.newHTML(this.el);
		this.applyReady();
		
	},
	
	replaceEl: function(el){
		this.el = el;
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
		if (matches = key.match(/(.+)(\[.*\])/)){
			param += "["+matches[1]+"]"+matches[2];
		}
		else param += "["+key+"]";
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
        if (!model.push) model = [model];
        var cls = "";
        for (var i=0; i<model.length; i++){
            if (cls) cls += ', ';
            cls += '.model-'+Spider.modelToCSS(model[i])+' .dataobject';
        }
		droppableOptions = $.extend({
			accept: cls,
			hoverClass: 'drophover',
			tolerance: 'pointer'
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
	},
	
	getClassInfo: function(prefix){
		var info = [];
		var cl = this.el.attr('class');
		var cl_parts = cl.split(' ');
		for (var i=0; i < cl_parts.length; i++){
			if (cl_parts[i].substr(0, prefix.length) == prefix){
				info.push(cl_parts[i].substr(prefix.length+1));
			}
		}
		return info;
	},
	
	bind: function(eventName, callback){
		if (!this.events[eventName]){
			this.events[eventName] = [];
		}
		this.events[eventName].push(callback);
	},
	
	trigger: function(eventName){
		if (!this.events[eventName]) return;
		var args = Array.prototype.slice.call(arguments, 1); 
		for (var i=0; i < this.events[eventName].length; i++){
			this.events[eventName][i].apply(this, args);
		}
	}
	
	
    
});

Spider.Widget.initFromEl = function(el){
	if (!el || !el.attr('id')) return;
    var path = Spider.Widget.pathFromId(el.attr('id'));
	if (Spider.widgets[path]){
		var widget = Spider.widgets[path];
		if (el.get(0) != widget.el.get(0)) widget.replaceEl(el);
		return widget;
	} 
    var cl = el.attr('class');
    var cl_parts = cl.split(' ');
    var w_cl = null;
	var config = {};
    for (var i=0; i < cl_parts.length; i++){
        if (cl_parts[i].substr(0, 5) == 'wdgt-'){
            w_cl = cl_parts[i].substr(5);
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
	return id.replace(/-/g, '/');
};



Spider.WidgetBackend = Class.extend({

	init: function(widget){
		this.widget = widget;
		this.baseUrl = document.location.href.split('#')[0];
		this.urlParts = this.baseUrl.split('?');
		this.wUrl = this.urlParts[0]+'?';
		if (this.urlParts[1]) this.wUrl += this.urlParts[1]+'&';
		this.wUrl += '_wt='+this.widget.path;
	},

	urlForMethod: function(method){
		return this.wUrl + '&_we='+method;
	},

	send: function(method, args, options){
		var url = this.urlForMethod(method);
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

Spider.widgetClasses = {};

Spider.defineWidget = function(name, parent, w){
	if (!w){
		w = parent;
		parent = null;
	}
    var parts = name.split('.');
    var curr = Widgets;
    for (var i=0; i<parts.length-1; i++){
        if (!curr[parts[i]]) curr[parts[i]] = function(){};
        curr = curr[parts[i]];
    }
	if (parent) parent = Spider.widgetClasses[parent];
	else parent = Spider.Widget;
    var widget = parent.extend(w);
	curr[parts[parts.length-1]] = widget;
	Spider.widgetClasses[name] = widget;
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
		var urlParts = href.split('?');
		var docParts = urlParts[0].split('#');
		var url = docParts[0]+'?_wt='+path;
		if (urlParts[1]) url += "&"+urlParts[1];
		if (params){
			for (var key in params){
				url += '&'+this.paramToQuery(params[key], widget.paramName(key));
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
				//widget.el.effect('highlight', {}, 700);
				if (callback) callback.apply(widget);
			}
		});
	},
	
	paramToQuery: function(value, prefix){
		var res = null;
		if (!prefix) prefix = '';
		if (!value){
			return '=null';
		}
		else if (value.push){ // array
			for (var i=0; i < value.length; i++){
				if (!res) res = "";
				else res += '&';
				res += this.paramToQuery(value[i], prefix+'[]');
			}
			return res;
		}
		else if (typeof (value) == 'object'){
			for (var name in value){
				if (!res) res = "";
				else res += '&';
				res += this.paramToQuery(value[name], prefix+'['+name+']');
			}
			return res;
		}
		else{
			return prefix+"="+value;
		}
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
	while (par && par.length > 0 && !par.is('.widget')){
		par = par.parent();
	}
	if (!par) return null;
	return par.spiderWidget();
};

$.fn.getDataObjectKey = function(){
	var doParent = null;
	var par = this;
	while (par && par.length > 0 && !par.is('.dataobject')){
		par = par.parent();
	}
	if (!par) return null;
	return $('>.dataobject-key', par).text();
};

$.fn.getDataModel = function(){
	var par = this;
	while (par && par.length > 0 && !par.is('.model')){
		par = par.parent();
	}
	if (!par) return null;
	var cl = par.attr('class');
	if (!cl) return null;
    var cl_parts = cl.split(' ');
    for (var i=0; i < cl_parts.length; i++){
		if (cl_parts[i].substr(0, 6) == 'model-'){
			return cl_parts[i].substr(6).replace(/-/g, '::');;
		}
    }
};

Spider.htmlFunctions = [];
Spider.onHTML = function(callback){
	Spider.htmlFunctions.push(callback);
	$(document).ready(function(){
		callback.call($(this.body));
	});
};

Spider.newHTML = function(el){
	for (var i=0; i<Spider.htmlFunctions.length; i++){
		Spider.htmlFunctions[i].call(el);
	}
};

Spider.modelToCSS = function(name){
	return name.split('::').join('-');
};


