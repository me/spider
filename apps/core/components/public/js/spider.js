function $W(path){
    // var path_parts = path.split('/');
    // var wdgt;
    // for (var i=0; i < path_parts.length; i++){
    //     wdgt = $('.widget.id-'+path_parts[i]);
    // }
    if (Spider.widgets[path]) return Spider.widgets[path];
    var wdgt_id = path.replace(/\//g, '-');
    var wdgt = $('#'+wdgt_id);
    if (wdgt.length == 0) return null;
    return Spider.Widget.initFromEl(wdgt);
}


Spider = function(){};

Spider.widgets = {};

Widgets = function(){};

Spider.Widget = Class.extend({
    
    init: function(container, path, config){
        this.el = container;
        this.path = path;
		var pathParts = path.split('/');
		this.widgetId = pathParts[pathParts.length - 1];
        this.backend = new Spider.WidgetBackend(this);
		this.readyFunctions = [];
		config = $.extend({}, config);
		this.config = config;
		this.model = config.model;
        Spider.widgets[path] = this;
		this.events = [];
		this.onWidgetCallbacks = {};
		this.widgets = {};
		this.findWidgets();		
		this.startup();
		this.ready();
		this.applyReady();
		this.plugins = [];
		if (this.includePlugins) for (var i=0; i<this.includePlugins.length; i++){
			this.plugin(this.includePlugins[i]);
		}
    },
    
    remote: function(){
        var args = Array.prototype.slice.call(arguments); 
        var method = args.shift();
		var options = {};
		if ($.isFunction(args[args.length-1])){
			options.callback = args.pop();
		}
        return this.backend.send(method, args, options);
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
		if (!callback && $.isFunction(params)){
			callback = params;
			params = {};
		}
		$C.loadWidget(this.path, params, callback);
	},
	
	isLoaded: function(){
		return !this.el.is(':empty');
	},
	
	startup: function(){},
	ready: function(){},
	update: function(){},
	
	replaceHTML: function(html){
		var el = $(html);
		this.el.html(el.html());
		this.findWidgets();
		this.update();
		this.ready();
		Spider.newHTML(this.el);
		this.applyReady();
		
	},
	
	replaceEl: function(el){
		this.el = el;
		this.findWidgets();		
		this.update();
		this.ready();
		this.applyReady();
	},
	
	findWidgets: function(){
		var self = this;
		$('.widget', this.el).filter(function(index){
			if ($(this).parents('.widget').get(0) == self.el.get(0)) return true;
			return false;
		}).each(function(){
			var $this = $(this);
			var w = $this.spiderWidget();
			if (!self.widgets[w.widgetId]) self.addWidget(w.widgetId, w);
			else self.widgets[w.widgetId].replaceEl($this);
		});
	},
	
	addWidget: function(id, w){
		this.widgets[id] = w;
		if (this.onWidgetCallbacks[id]){
			for (var i=0; i<this.onWidgetCallbacks[id].length; i++){
				this.onWidgetCallbacks[id][i].call(this, w);
			}
		}
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
	
	
	ajaxifyAll: function(options){
		var els = $('form:not(.ajaxified), a:not(.ajaxified)', this.el);
		if (!options) options = {};
		if (options.filter) els = els.filter(options.filter);
		if (options.not) els = els.not(options.not);
		this.ajaxify(els, options);
	},
	
	findWidgetsAjaxifiable: function(options){
		var selfEl = this.el.get(0);
		return $('form:not(.ajaxified), a:not(.ajaxified)', this.el).filter(function(index){
			var p = $(this).parent();
			while (p){
				if (p.is('.widget')){
					if (p.get(0) == selfEl) return true;
					return false;
				}
				p = p.parent();
			}
			return false;
		});
	},
	
	
	ajaxify: function(el, options){
		var w = this;
		if (!el || !el.eq){
			options = el;
			el = this.findWidgetsAjaxifiable();
		}
		if (!options) options = {};
		el.each(function(){
			var $this = $(this);
			if (this.tagName == 'FORM'){
				w.ajaxifyForm($(this), options);
			}
			else if (this.tagName == 'A'){
				w.ajaxifyLink($(this), options);
			}
		});

	},
	
	ajaxifyForm: function(form, options){
		var isForm = form.get(0).tagName == 'FORM';
		if (!options) options = {};
		$('input[type=submit]', form).addClass('ajaxified').bind('click.ajaxify', function(e){
			var $this = $(this);
			var w = $this.parentWidget();
			e.preventDefault();
			w.setLoading();
			var submitName = $this.attr('name');
			var submitValue = $this.val();
			form.ajaxSubmit({
				dataType: 'html',
				semantic: !isForm,
				beforeSubmit: function(data, form, options){
					data.push({name: submitName, value: submitValue});
					data.push({name: '_wt', value: w.path});
					if (options.before) options.before();
				},
				success: function(res){
					w.replaceHTML(res);
					w.removeLoading();
					if (options.onLoad) options.onLoad(form);
					w.trigger('ajaxifyLoad', form);
				}
			});
		});
	},
	
	ajaxifyLink: function(a, options){
		var w = this;
		if (!options) options = {};
		a.addClass('ajaxified').bind('click.ajaxify', function(e){
			if (options.before){
				var res = options.before.apply(w);
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
			if (options.before) options.before();
			w.setLoading();
			$.ajax({
				url: url,
				type: 'GET',
				dataType: 'html',
				success: function(res){
					w.replaceHTML(res);
					w.removeLoading();
					if (options.onLoad) options.onLoad(a);
					w.trigger('ajaxifyLoad', a);
				}
			});
		});
	},
	
	setLoading: function(){
		if (this.el.is(':empty') || this.el.children().hasClass('empty-placeholder')){
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
		var handleObj = {
			callback: callback
		};
		if ( eventName.indexOf(".") > -1 ) {
			var namespaces = eventName.split(".");
			eventName = namespaces.shift();
			handleObj.namespace = namespaces.slice(0).sort().join(".");
		}
		if (!this.events[eventName]) this.events[eventName] = [];
		this.events[eventName].push(handleObj);
	},
	
	on: function(eventName, callback){ return this.bind(eventName, callback); },
	
	trigger: function(eventName){
		if ( eventName.indexOf(".") > -1 ) {
			var namespaces = eventName.split(".");
			eventName = namespaces.shift();
			namespace = namespaces.slice(0).sort().join(".");
		}
		if (!this.events[eventName]) return;
		var args = Array.prototype.slice.call(arguments, 1); 
		for (var i=0; i < this.events[eventName].length; i++){
			this.events[eventName][i].callback.apply(this, args);
		}
	},
	
	unbind: function(eventName){
		var namespace = null;
		if ( eventName.indexOf(".") > -1 ) {
			var namespaces = eventName.split(".");
			eventName = namespaces.shift();
			namespace = namespaces.slice(0).sort().join(".");
		}
		if (namespace){
			for (var i=0; i<this.events[eventName].length; i++){
				if (this.events[eventName][i].namespace == namespace){
					this.events[eventName].splice(i);
				}
			}
		}
		else this.events[eventName] = [];
	},
	
	plugin: function(pClass, prop){
		if (prop) pClass = pClass.extend(prop);
		this.plugins[pClass] = new pClass(this);
		var plugin = this.plugins[pClass];
		for (var name in pClass.prototype){
			if (name.substring(0, 1) == '_') continue;
			if (typeof pClass.prototype[name] == "function" && !this[name]){
				this[name] = function(name){
					return function(){
						return plugin[name].apply(this, arguments);
					};
				}(name);
			}
		}
	},
	
	widget: function(id){
		return this.widgets[id];
	},
	
	onWidget: function(id, callback){
		if (!this.onWidgetCallbacks[id]) this.onWidgetCallbacks[id] = [];
		this.onWidgetCallbacks[id].push(callback);
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
		if (!options) options = {};
		var defaults = {
			url: url,
			type: 'POST',
			dataType: 'json'
		};
		options = $.extend(defaults, options);
		if (!options.format) options.format = options.dataType;
		var url = this.baseUrl;
		var data = {};
		if ($.isPlainObject(args[0])) data = args[0];
		else data = {'_wp': args};
		$.extend(data, {
			'_wt': this.widget.path,
			'_we': method,
			'_wf': options.format
		});
		var callback = this.widget[method+'_response'];
		if (!callback) callback = options.callback;
		if (!callback) callback = function(){};
		options.success = callback;
		options.data = data;
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
	return widget;
};

Spider.Controller = Class.extend({
    
    init: function(){
		var url = ''+document.location;
		var slashPos = url.lastIndexOf('/');
		url = url.substr(0, slashPos);
		this.setUrl(url);
    },

	setUrl: function(url){
		this.url = url;
		this.publicUrl = this.url+'/public'; // FIXME
		this.homeUrl = this.url+'/_h';
	},
    
	remote: function(method, params, callback, options){
		var args = Array.prototype.slice.call(arguments); 
		if (!callback) callback = function(){};
		var url = this.url+'/'+method+'.json';
		var defaults = {
			url: url,
			type: 'POST',
			success: callback,
			data: params,
			dataType: 'json'
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
	var path = Spider.Widget.pathFromId(this.attr('id'));
	if (Spider.widgets[path]) return Spider.widgets[path];
	return Spider.Widget.initFromEl(this);
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


