var AppView = Backbone.View.extend({
	events: {
		"click .fixed_bottom .expander" : "toggleHeader"
	},

	initialize: function() {
		// this.listenTo(this.model, "change", this.render);
		this.filters = new FilterMenu({
			selected: true,
			id: "all",
			name: "all",
			url: "all.json",
			filtersURL: "filters.json"
		});
		this.listenTo(this.filters, "filtersReady", this.addFilters);
		this.listenTo(this.filters, "filtersChange", this.changeFilters);

		this.lexemes = new Lexemes();
		this.lexemesView = new LexemesView({
			model: this.lexemes,
			el: "#framelist"
		});

		this.changeFilters();

		this.alphabetView = new AlphabetView({
			model: this.lexemes,
			el: "#alphabet"
		});

		var _this = this;

		this.router = new AppRouter;
		this.router.on("route:getLexeme", function (lexeme, unit) {
			console.log("getLexeme route")
			this.lexemes.setSelectedLexeme(lexeme, unit);
		}, this);
		Backbone.history.start();

		$(".alphabet, .wordentry").mCustomScrollbar({
			theme: "rounded-dark",
			scrollInertia: 0,
			mouseWheel:{ scrollAmount: 53 }
		});

		$(".framelist .result").mCustomScrollbar({
			theme: "rounded-dark",
			scrollInertia: 0,
			mouseWheel:{ scrollAmount: 53 }, // naměřeno v linuxu ve chrome jako defaultní scrollamount u nativního scrollbaru
			callbacks: {
				whileScrolling: function () {
				// onScroll: function () {
					_this.alphabetView.framelistScroll();
				}
			}
		});
	},

	addFilters: function () {
		var filtersDOM = this.filters.filterView.render();
	},

	changeFilters: function () {
		// console.log(arguments)
		var selectedFilter = this.filters.getSelectedFilter();
		this.lexemes.showFiltered(selectedFilter);

		resize();
	},

	toggle: function () {
		this.model.toggle();
	},

	render: function() {

	},

	toggleHeader: function (e) {
		console.log(e)
		var $expander = $(e.currentTarget);
		console.log("msg")
		$(".header .filters").slideToggle({
			progress: resize
		});
		$expander.toggleClass("expanded");
		if($expander.hasClass("expanded")){
			$expander.find("span").html("hide filters");
		}
		else {
			$expander.find("span").html("show filters");
		}
	}

});

$(function () {
	layout_init();
	window.appView = new AppView({
		el: $("body")[0]
	});
});
