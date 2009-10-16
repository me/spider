Spider.defineWidget('Spider.Components.List', {
	
	autoInit: '.wdgt-Spider-Components-List:not(.sublist)',
    
    startup: function(){
        var options = {};
		
    },

	ready: function(){
		this.listEl = $('>ul, >ol', this.el);
		var options = {};
		if (this.listEl.length > 0){
			this.listTagName = this.listEl.get(0).tagName;
			if (this.el.hasClass('collapsed')) options.collapsed = true;
	        if (this.el.hasClass('tree')) $(this.listTagName, this.el).treeview(options);
	        if (this.el.hasClass('sortable')) this.makeSortable();
	        
		};
		this.ajaxify($('form, .paginator a', this.el));
		this.ajaxify($('.delete_link:not(.unmanaged)', this.el));
	},
	
	update: function(){
	},
    
    
    makeSortable: function(){
        var options = {
			items: 'li',
            helper: function(e,item) {
				return $("<div class='treeview-helper'>"+item.find("span.desc").html()+"</div>");
			},
			update: this.handleSort.bind(this)
		};
        if (this.el.hasClass('tree')){
            options = $.extend(options, {
    			//revert: true,
    			sortIndication: {
    				down: function(item) {
    					item.css("border-top", "1px dotted black");
    				},
    				up: function(item) {
    					item.css("border-bottom", "1px dotted black");
    				},
    				remove: function(item) {
    					item.css("border-bottom", "0px").css("border-top", "0px");
    				}
    			},
    			start: function(e, ui) {
                    console.log("Tree start:");
                    console.log(e);
                    console.log(ui);
//					ui.instance.element.treeview({update: ui.item});
				},
				update: this.handleTreeUpdate.bind(this)
            });
            this.listEl.sortableTree(options);
            // handles drops on non-subtrees nodes
//            debugger;
            $('.desc', this.el).droppable({
                accept: "li",
                hoverClass: "drop",
                tolerance: "pointer",
                greedy: true,
                drop: this.handleTreeDrop.bind(this),
                over: function(e,ui) {
                    ui.helper.css("outline", "1px dotted green");
                },
                out: function(e,ui) {
                    ui.helper.css("outline", "1px dotted red");
                }
            });
        }
        else{
            this.listEl.sortable(options);
        }
    },
    
    handleSort: function(e, ui){
        var item = ui.item;
        var cnt = 0;
        $('> li', this.listEl).each(function(){
            cnt++;
            if (this == item.get(0)) return false;
        });
        this.remote('sort', this.getSortItemId(item), cnt);
    },
    
    handleTreeUpdate: function(e, ui){
        var parentId = this.getItemId(ui.item.parents('li.tree').eq(0));
        var prevId = this.getItemId(ui.item.prev('li.tree'));
        this.remote('tree_sort', this.getItemId(ui.item), parentId, prevId);
    },
    
    handleTreeDrop: function(e, ui){
        if (e.target.parentNode == ui.draggable[0]) return false; //dropped over itself
        console.log('dropped inside');
        var dropLi = $(e.target.parentNode);
        var subUl = $("> "+this.listTagName, dropLi);
        if (subUl.length == 0){
            subUl = $("<"+this.listTagName+" />").appendTo(dropLi);
            this.el.treeview({add: e.target.parentNode});
        }
        subUl.append(ui.draggable);
		var parentId = this.getItemId($(e.target).parents('li.tree').eq(0));
		var prevId = null;
		//this.remote('tree_sort', this.getItemId(ui.draggable), parentId, prevId);
		return false;
    },
    
    getItemId: function(li){
        return $('> .dataobject-key', li).text();
    },

	getSortItemId: function(li){
		var k = $('> .sort-key', li);
		if (k.length > 0) return k.text();
		return getItemId(li);
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

$(document).ready(function(){
    $('.wdgt-Spider-Components-List:not(.sublist)').each(function(){
        var widget = Spider.Widget.initFromEl($(this));
    });
});