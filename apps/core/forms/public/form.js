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
            // it's ok to reset the value attr of text inputs,
            // password inputs, and textareas
            if (type == 'text' || type == 'password' || tag == 'textarea' || type == 'hidden') this.value = "";
            // checkboxes and radios need to have their checked state cleared
            // but should *not* have their 'value' changed
            else if (type == 'checkbox' || type == 'radio') this.checked = false;
            // select elements need to have their 'selectedIndex' property set to -1
            // (this works for both single and multiple select elements)
            else if (tag == 'select') this.selectedIndex = -1;
        });
    }
};