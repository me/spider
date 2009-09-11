Spider.defineWidget('Spider.Core.Forms.Form', {

    clear: function(){
        $Form.clearForm(this.el);
    }

});

$Form = {
    clearForm: function(form){
        $(':input', form).each(function() {
            var type = this.type;
            var tag = this.tagName.toLowerCase(); // normalize case
            if (type == 'text' || type == 'password' || tag == 'textarea' || type == 'hidden') this.value = "";
            else if (type == 'checkbox' || type == 'radio') this.checked = false;
            else if (tag == 'select') this.selectedIndex = -1;
        });
    }
};