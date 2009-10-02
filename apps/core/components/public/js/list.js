Spider.defineWidget('Spider.Components.List', {
    
    startup: function(){
        var options = {};
        if (this.el.hasClass('collapsed')) options.collapsed = true;
        if (this.el.hasClass('tree')) this.el.treeview(options);
        if (this.el.hasClass('sortable')) this.makeSortable();
    },
    
    
    makeSortable: function(){
        var options = {update: this.handleSort.bind(this)};
        if (this.el.hasClass('tree')){
            options = $.extend(options, {
                items: 'li',
                helper: function(e,item) {
    				return $("<div class='treeview-helper'>"+item.find("span").html()+"</div>");
    			},
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
            this.el.sortableTree(options);
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
            this.el.sortable(options);
        }
    },
    
    handleSort: function(e, ui){
        var item = ui.item;
        var cnt = 0;
        $('> li', this.el).each(function(){
            cnt++;
            if (this == item.get(0)) return false;
        });
        this.remote('sort', this.getItemId(item), cnt);
    },
    
    handleTreeUpdate: function(e, ui){
        var parentId = this.getItemId(ui.item.parents('li.tree').eq(0));
        var prevId = this.getItemId(ui.item.prev('li.tree'));
        this.remote('tree_sort', this.getItemId(ui.item), parentId, prevId);
    },
    
    handleTreeDrop: function(e, ui){
        debugger;
        var a = 3;
        if (e.target.parentNode == ui.draggable[0]) return false; //dropped over itself
        console.log('dropped inside');
        var dropLi = $(e.target.parentNode);
        var subUl = $("> ul", dropLi);
        if (subUl.length == 0){
            subUl = $("<ul />").appendTo(dropLi);
            self.list.treeview({add: e.target.parentNode});
        }
        subUl.append(ui.draggable);
    },
    
    getItemId: function(li){
        return $('> .key', li).text();
    },
    
    sortResult: function(res){
        console.log(res);
    }
    
    
    
});

$(document).ready(function(){
    $('.wdgt-Spider-Components-List:not(.sublist)').each(function(){
        var widget = Spider.Widget.initFromEl($(this));
    });
});