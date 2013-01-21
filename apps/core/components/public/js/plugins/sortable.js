Spider.Sortable = Spider.Plugin.extend({
    makeSortable: function(options){
        options = $.extend({
            listSelector: '>ul',
            items: '>li',
            update: this.handleSort.bind(this),
            receive: this.handleReceive.bind(this),
            onSort: function(){},
            // if true, an element with class sort-pos inside the li is used to determine the li position in the storage.
            // This is useful if the displayed items are a subset (with holes) of the sorted items in the storage
            useSortPos: false
        }, options);
        this.listEl = options.listEl;
        if (!this.listEl) this.listEl = $(options.listSelector, this.el);
        this.prevMinHeight = this.listEl.css('min-height');
        this.listEl.css('min-height', '20px');
        if (this.el.hasClass('tree')){
            options = $.extend(options, {
                //revert: true,
                sortIndication: {
                    down: function(item) {
                        item.before($('<li id="list-sort-indicator" />'));
                    },
                    up: function(item) {
                        item.after($('<li id="list-sort-indicator" />'));
                    },
                    remove: function(item) {
                        $('#list-sort-indicator').remove();
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
                //                greedy: true,
                drop: this.handleTreeDrop.bind(this)
                // over: function(e,ui) {
                    //     ui.helper.css("outline", "1px dotted green");
                    // },
                    // out: function(e,ui) {
                        //     ui.helper.css("outline", "1px dotted red");
                        // }
            });
        }
        else{
            this.listEl.sortable(options);
        }
        this.sortableOptions = options;
    },
    
    disableSortable: function(){
        if (this.listEl){
            this.listEl.css('min-height', this.prevMinHeight);
            if (this.listEl.data('sortable') || this.listEl.data('uiSortable')) this.listEl.sortable('destroy');
        }
    },
	
    
    handleSort: function(e, ui){
        if (ui.sender) return; // handled by handleReceive
        if (!$.contains(this.listEl.get(0), ui.item.get(0))) return; // handled by handleReceive
        var mySortable = this.listEl.data('sortable') || this.listEl.data('uiSortable');
        var realTarget = null;
        ui.item.parents().each(function(){
            var $this = $(this);
            var s = $this.data('sortable') || $this.data('uiSortable');
            if (s){
                if (s != mySortable) realTarget = $this;
                return false;
            }
        });
        if (realTarget){
            ui.sender = this.listEl;
            return realTarget.parentWidget().handleReceive(e, ui);
        }
        var pos = this.findLiPosition(ui.item);
        if (pos == -1) return;
        if (mySortable.fromOutside){ // hack to work around strange jquery ui behaviour...
            return this.acceptFromSender(null, ui.item, pos);
        }
        this.remote('sort', this.getSortItemId(ui.item), pos, this.sortableOptions.onSort.bind(this));
    },


    handleReceive: function(e, ui){
        if (ui.sender == ui.item){
            // the item is received from a draggable, not from a list. For some reason the receiver is not
            // yet ready to find the position; will call acceptFromSender from handleSort.
            return;
        }
        var pos = this.findLiPosition(ui.item);
        if (pos == -1) return;
        return this.acceptFromSender(ui.sender, ui.item, pos);
    },

    handleTreeUpdate: function(e, ui){
        var parentId = ui.item.parents('li.tree').eq(0).dataObjectKey();
        var prevId = ui.item.prev('li.tree').dataObjectKey();
        this.remote('tree_sort', this.getItemId(ui.item), parentId, prevId, this.sortableOptions.onSort.bind(this));
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
        var parentId = $(e.target).parents('li.tree').eq(0).dataObjectKey();
        var prevId = null;
        this.remote('tree_sort', ui.draggable.dataObjectKey(), parentId, prevId);
        return false;
    },

    acceptFromSender: function(sender, item, pos){
        console.error("Accept from sender must be implemented by the widget instance");
    },

    findLiPosition: function(item){
        var cnt = 1;
        var lis = $(this.sortableOptions.items, this.listEl);
        lis.each(function(){
            if (this == item.get(0)) return false;
            cnt++;
        });
        if (cnt > lis.length) return -1; // the row was dropped outside
        if (this.sortableOptions.useSortPos && lis.length > 1){
            var realPos = -1;
            if (cnt == 1){
                realPos = parseInt(item.next().find('> .sort-pos').text(), 10) - 1;
            }
            else realPos = parseInt(item.prev().find('> .sort-pos').text(), 10) + 1;
            return realPos;
        }
        return cnt;
    },

    getSortItemId: function(li){
        var k = $('> .sort-key', li);
        if (k.length > 0) return k.text();
        return li.getDataObjectKey();
    }
	
});
