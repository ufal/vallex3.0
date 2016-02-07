var AppView = Backbone.View.extend({
	events: {
		"click .fixed_bottom .expander" : "toggleHeader"
	},

	// mohl bych implementovat promises, ale kvůli jednomu eventu...?
	filtersReady: false,

	initialize: function() {
		this.filters = new FilterMenu({
			selected: true,
			id: "all",
			name: "all",
			url: "all.json",
			filtersURL: "filters.json"
		});
		this.listenTo(this.filters, "filtersReady", this.addFilters);

		this.lexemes = new Lexemes();
		this.lexemesView = new LexemesView({
			model: this.lexemes,
			el: "#framelist"
		});

		this.alphabetView = new AlphabetView({
			model: this.lexemes,
			el: "#alphabet"
		});

		this.router = new AppRouter;
		this.router.on("route:getLexeme", function (lexeme, unit) {
			console.log("getLexeme route")
			this.lexemes.setSelectedLexeme(lexeme, unit);
		}, this);
		this.router.on("route:getFilter", function (path) {
			console.log("getFilter route");

			if(this.filtersReady){
				this.getFilter(path);
			}
			else {
				var _this = this;
				this.listenToOnce(this.filters, "filtersReady", function () {
					_this.getFilter(path);
				})
			}
			
		}, this);
		this.router.on("route:defaultRoute", function (path) {
			console.log("defaultRoute route");

			// zobrazení hlavního filtru
			this.lexemes.showFiltered(this.filters);
		}, this);
		Backbone.history.start();

		var scrollbarSettings = {
			theme: "rounded-dark",
			scrollInertia: 0,
			mouseWheel:{ scrollAmount: 53 }
		};

		$(".alphabet, .wordentry").mCustomScrollbar(scrollbarSettings);

		var _this = this;
		$(".framelist .result").mCustomScrollbar(_.extend(scrollbarSettings, {
			callbacks: {
				whileScrolling: function () {
					_this.alphabetView.framelistScroll();
				}
			}
		}));
	},

	getFilter: function (path) {
		var pathArray = [];
		if(path !== null)
			var pathArray = path.split("/");

		var selectedFilter = this.filters.setSelectedFilter([], pathArray);

		this.lexemes.showFiltered(selectedFilter);

		resize();
	},

	addFilters: function () {
		this.filtersReady = true;
		var filtersDOM = this.filters.filterView.render();

		resize();
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
