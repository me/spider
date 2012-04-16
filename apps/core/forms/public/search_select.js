Spider.defineWidget('Spider.Forms.SearchSelect', 'Spider.Forms.Input', {
    
    autoInit: true,
    
    startup: function(){
        this.removed = [];
        this.added = [];
        this._super();
    },
    
    ready: function(){
        var w = this;
        this.multiple = this.el.is('.multiple');
        for (var i=0; i<this.removed.length; i++){
            this.removeValue(this.removed[i]);
        }
        // Convert delete checkboxses
        $('.delete_action', this.el).each(function(){
            var $this = $(this);
            $('input[type=checkbox]', $this).remove();
            var key = $this.getDataObjectKey();
            var textSpan = $('.action_text', $this);
            var a = $('<a href="#" />').text(textSpan.text());
            a.attr('class', $this.attr('class'));
            a.click(function(e){
                w.removed.push(key);
                e.preventDefault();
                w.removeValue(key);
            });
            textSpan.replaceWith(a);
            
        });
        // Convert change checkboxes
        $('.change_action', this.el).each(function(){
            var $this = $(this);
            $('input[type=checkbox]', $this).remove();
            var textSpan = $('.action_text', $this);
            var a = $('<a href="#" />').text(textSpan.text());
            a.attr('class', $this.attr('class'));
            a.click(function(e){
                e.preventDefault();
                w.reload({clear: true});
            });
            textSpan.replaceWith(a);
        });
        // var showTable = $('<a href="#" class="show_table"><span class="action_text">Tabella</span></a>').appendTo($('.add_box', this.el));
        //      showTable.click(function(e){
        //          e.preventDefault();
        //          var table = $('.search_table', w.el).spiderWidget();
        //          if (table.el.is(':hidden')){
        //              table.el.show();
        //              $(this).addClass('open');
        //              table.reload({}, function(e){
        //                  $('tr.row', this.el).click(function(e){
        //
        //                  });
        //              });
        //          }
        //          else{
        //              $(this).removeClass('open');
        //              table.el.hide();
        //          }
        //      });
        $('.add_box input[type=text]', this.el).attr('name', 'autocomplete-box').autocomplete({
            source: function(request, response){
                var url = w.backend.urlForMethod('jquery_autocomplete');
                var current = [];
                var vl = $('.values_list', w.el).spiderWidget();
                if (vl) current = vl.keys();
                var params = {};
                for (var i=0; i<current.length; i++){
                    params['not['+i+']'] = current[i];
                }
                var data = {};
                $.extend(data, params, {
                    q: request.term
                });
                $.ajax({
                    // try to leverage ajaxQueue plugin to abort previous requests
                    mode: "abort",
                    // limit abortion to this input
                    port: "autocomplete" + w.fullId,
                    dataType: 'json',
                    url: url,
                    data: data,
                    success: function(data) {
                        response(data);
                    }
                });
            },
            select: function(e, ui){
                var w = $(this).parentWidget();
                var data = ui.item;
                if (!data) return;
                if (w.multiple){
                    w.added.push(data.value);
                    for (var i=0; i<this.removed; i++){
                        if (this.removed[i] == data.value) this.removed.splice(i, 1);
                    }
                    w.reload({add: w.added});
                }
                else{
                    $('input[type=hidden].hidden-val', w.el).val(data.value);
                }
                w.trigger('change', w.val());
                $(e.target).val(data.label);
                return false;
            },
            focus: function(e, ui){
                if (ui.item) $(e.target).val(ui.item.label);
                else $(e.target).val('');
                return false;
            }
            
        });
    },
    
    addValue: function(keys, desc){
        // var h = $('input[type=hidden]:last', this.el);
        // h.clone.val(keys).insertAfter(h);
        // $('.values_list', this.el).spiderWidget().reload({add})
    },
    
    removeValue: function(key){
        for (var i=0; i<this.added; i++){
            if (this.added[i] == key) this.added.splice(i, 1);
        }
        $('input[type=hidden][value='+key+']', this.el).remove();
        $('.values_list li', this.el).each(function(){
            var $this = $(this);
            if ($this.getDataObjectKey() == key) $this.remove();
        });
    },
    
    changed: function(){
        
    },
    
    val: function(){
        if (this.multiple){
            var v = [];
            $('input[type=hidden].hidden-val', this.el).each(function(){
                v.push($(this).val());
            });
            return v;
        }
        else return $('input[type=hidden].hidden-val', this.el).val();
    }
    
});