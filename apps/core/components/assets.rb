Spider::Template.define_named_asset 'jquery', [
     [:js, 'js/jquery/jquery-1.4.2.js', Spider::Components]
 ]
 Spider::Template.define_named_asset 'spider', [
     [:js, 'js/inheritance.js', Spider::Components],
     [:js, 'js/spider.js', Spider::Components],
     [:js, 'js/jquery/plugins/jquery.query-2.1.6.js', Spider::Components],
     [:js, 'js/jquery/plugins/jquery.form.js', Spider::Components],
     [:js, 'js/plugins/plugin.js', Spider::Components],
     [:css, 'css/spider.css', Spider::Components]
 ], :depends => ['jquery']
 
 Spider::Template.define_runtime_asset 'jquery-ui-datepicker-locale' do |request, response, scene|
     Spider::Components.pub_url+"/js/jquery/jquery-ui-1.8.2/development-bundle/ui/i18n/jquery.ui.datepicker-#{request.locale.language}.js"
 end
 
 Spider::Template.define_named_asset 'jquery-ui', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.1.8.2.custom.js', Spider::Components],
     [:css, 'js/jquery/jquery-ui-1.8.2/css/smoothness/jquery-ui-1.8.2.custom.css', Spider::Components],
     [:js, 'jquery-ui-datepicker-locale', :runtime]
 ], :depends => ['jquery']
 

 
 Spider::Template.define_named_asset 'jquery-ui-core', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.core.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.widget.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.mouse.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.position.js', Spider::Components],
     [:css, 'js/jquery/jquery-ui-1.8.2/css/smoothness/jquery-ui-1.8.2.custom.css', Spider::Components]
 ]
 
 Spider::Template.define_named_asset 'jquery-ui-draggable', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.draggable.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-droppable', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.droppable.js', Spider::Components]
 ], :depends => ['jquery-ui-draggable']
 
 Spider::Template.define_named_asset 'jquery-ui-resizable', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.resizable.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-selectable', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.selectable.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-sortable', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.sortable.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-accordion', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.accordion.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-autocomplete', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.autocomplete.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-button', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.button.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-dialog', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.dialog.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-slider', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.slider.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-tabs', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.tabs.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-datepicker', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.datepicker.js', Spider::Components],
     [:js, 'jquery-ui-datepicker-locale', :runtime]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-ui-progressbar', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.ui.progressbar.js', Spider::Components]
 ], :depends => ['jquery-ui-core']
 
 Spider::Template.define_named_asset 'jquery-effects', [
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.core.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.blind.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.bounce.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.clip.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.drop.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.explode.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.fold.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.highlight.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.pulsate.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.scale.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.shake.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.slide.js', Spider::Components],
     [:js, 'js/jquery/jquery-ui-1.8.2/development-bundle/ui/jquery.effects.transfer.js', Spider::Components]
 ], :depends => ['jquery-ui-core']