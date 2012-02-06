$(document).ready(function(){
	$('.local-name, .iv-name').click(function(){
		$('pre', $(this).parent()).toggle();
	});
});