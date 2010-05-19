Spider.defineWidget('Spider.Components.List', {
	
	autoInit: '.wdgt-Spider-Components-List',
	
	includePlugins: [Spider.Sortable],
    
    startup: function(){
    },

	ready: function(){
		this.listEl = $('>ul, >ol', this.el);
		var options = {};
		if (this.listEl.length > 0){
			this.listTagName = this.listEl.get(0).tagName;
			if (this.el.hasClass('collapsed')) options.collapsed = true;
	        if (this.el.hasClass('tree')) $(this.listTagName, this.el).treeview(options);
	        if (this.el.hasClass('sortable')){
				this.plugin(Spider.Sortable);
				this.makeSortable({
					listEl: this.listEl,
					handle: '> span.desc',
					helper: function(e,item) {
						return $("<div class='treeview-helper'>"+item.find("span.desc").html()+"</div>");
					}			        
				});
			} 
	        
		};
		this.ajaxify($('form, .paginator a', this.el));
		this.ajaxify($('.delete_link:not(.unmanaged)', this.el));
	},
	
	update: function(){
	},
    
	getItemById: function(id){
		var found = null;
		var self = this;
		$('>li', this.listEl).each(function(){
			$this = $(this);
			if ($this.dataObjectKey == id){
				found = $(this);
				return false;
			}
		});
		return found;
	},
    
    sortResult: function(res){
        console.log(res);
    },

	scrollable: function(options){
		options = $.extend({
			num: 5,
			scroll: 1
		}, options);
		this.scrollOptions = options;
		this.scrollPos = 0;
		this.scrollBackButton = $('<a href="#">&lt;</a>').click(
			function(){ this.scroll(-options.scroll); return false; }.bind(this)
		);
		this.scrollForwarButton = $('<a href="#">&gt;</a>').click(
			function(){ this.scroll(options.scroll); return false; }.bind(this)
		);
		this.el
			.append(this.scrollBackButton)
			.append($('<span> </span>'))
			.append(this.scrollForwarButton);
		this.scroll(1);
	},
	
	scroll: function(num){
		var newPos = null;
		newPos = this.scrollPos + num;
		if (newPos < 1) newPos = 1;
		var size = $('>li', this.listEl).length;
		var max = size - this.scrollOptions.num + 1;
		if (max < 1) max = 1;
		if (newPos > max) newPos = max;
		$('>li', this.listEl).show();
		$('>li:lt('+(newPos-1)+')', this.listEl).hide();
		$('>li:gt('+(newPos+this.scrollOptions.num-2)+')', this.listEl).hide();
		this.listEl.attr('start', newPos);
		this.scrollPos = newPos;
		if (this.scrollPos == 1) this.scrollBackButton.hide();
		else this.scrollBackButton.show();
		if (this.scrollPos == max) this.scrollForwarButton.hide();
		else this.scrollForwarButton.show();
	},
	
	makeEditable: function(button, form_path){
		$(button, this.el).click(function(e){
			e.preventDefault();
			var form = $W(form_path);
			form.el.appendTo($(this).parents('.listItem').eq(0));
			form.el.show();
			form.reload({pk: $(this).getDataObjectKey()}, function(){
				var widget = this;
				$('.buttons', this.el).append(
					$('<input type="submit" value="Annulla" />').click(function(e){
						e.preventDefault();
						widget.el.html('');
						widget.el.hide();
					})
				);
			});
		});
			
	},
	
	keys: function(){
		var keys = [];
		$('>li >.dataobject-key').each(function(){
			keys.push($(this).text());
		});
		return keys;
	}
    
    
    
});