function resize () {
	$("body").css("overflow", "hidden");
	// vertikála
	if($(".header").hasClass("expanded")){
		var documentHeight = window.innerHeight;
		var headerHeight = $(".header").outerHeight();
		var bottomMargin = 20;
		$(".dictionary").css("height", (documentHeight - headerHeight - bottomMargin)+"px");

		$(".scrollhack").css("height", $(".framelist").height() + "px");
	}

	// horizontála
	var documentWidth = $(".dictionary").innerWidth();
	var alphabetWidth = $(".alphabet").outerWidth();
	var framelistWidth = $(".framelist").outerWidth();
	$(".wordentry").css("width", (documentWidth - alphabetWidth - framelistWidth - 1)+"px");
}
function layout_init(){
	$(window).resize(resize);
	resize();
}