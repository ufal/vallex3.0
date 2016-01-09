var path_to_generated = "./generated/";

// nástavba kolekce filtrů
var Filters = Backbone.Model.extend({

	defaults: {
		visible: false
	},

	filters: null,

	initialize: function (filters) {
		this.filters = new FilterCollection(filters);
		this.listenTo(this.filters, "change:selected", this.selected);
	},

	selected: function (selectedFilter) {
		if(!selectedFilter.get("selected"))
			return;
		this.filters.each(function (filter) {
			if(filter != selectedFilter){
				filter.unselect();
			}
		});
	},

	show: function () {
		this.set("visible", true);
	},

	hide: function () {
		this.set("visible", false);
		this.filters.invoke("unselect");
	}

});

var Filter = Backbone.Model.extend({
	defaults: {
		name: null,
		url: null,
		selected: false,
	},

	subfilters: null,

	initialize: function (settings) {
		if(settings !== undefined){
			this.set(settings);
			if(settings.subfilters.length > 0){
				this.subfilters = new Filters(settings.subfilters);
			}
		}
	},

	toggle: function () {
		this.set("selected", !this.get("selected"));
		if(this.subfilters !== null){
			if(this.get("selected"))
				this.subfilters.show();
			else
				this.subfilters.hide();
		}
	},

	unselect: function () {
		if(this.get("selected"))
			this.toggle();
	},

	getSelectedFilter: function () {
		if(this.subfilters == null)
			return this;

		var selectedChild = this.subfilters.filters.where({
			"selected":true
		});
		if(selectedChild.length > 0)
			return selectedChild[0].getSelectedFilter();
		else
			return this;
	}
});

var FilterCollection = Backbone.Collection.extend({
  model: Filter
});

var FilterMenu = Filter.extend({
	initialize: function (settings) {
		this.set(settings);
		this.fetchFilters(function (subfilters) {
			subfilters = subfilters;
			this.subfilters = new Filters(subfilters);
			this.subfilters.set("visible", true);

			this.filterView = new FilterView({
				model: this
			});

			this.trigger("filtersReady");
		});
	},

	fetchFilters: function (success) {
		$.ajax({
			dataType: "json",
			url: path_to_generated + this.get("filtersURL"),
			success: success,
			context: this
		});
	},
});

// view ---

var FilterView = Backbone.View.extend({
	tagName: "li",

	events: {
		"click .togglable": "toggle",
	},

	initialize: function() {
		this.listenTo(this.model, "change:selected", this.render);

		if(this.model.subfilters !== null){
			this.subfilters = new FiltersView({
				model: this.model.subfilters
			});
			var filtersDOM = this.subfilters.render();
		}
	},

	toggle: function () {
		this.model.toggle();

		appView.filters.trigger("filtersChange", this.model);
	},

	render: function() {
		this.$el.html("");

		var a = document.createElement("a");
		var $a = $(a);
		$a.addClass("togglable");
		if(this.model.get("selected"))
			$a.addClass("selected");
		// $a.attr("href", "#");
		$a.html(this.model.get("name"));

		this.$el.append($a);

		return this.$el;
	}
});

var FiltersView = Backbone.View.extend({
	tagName: "li",

	initialize: function() {
		this.listenTo(this.model, "change:visible", this.update);
	},

	update: function () {
		this.$el.toggleClass("hidden", !this.model.get("visible"));
		// if(this.model.get("visible"))
		// 	this.$el.slideDown();
		// else
		// 	this.$el.slideUp();
	},

	render: function() {
		this.$el.html("");
		var ul = document.createElement("ul");
		var $ul = $(ul);
		$ul.addClass("inline").addClass("separators");

		$(".header .filters .filter_list").append(this.$el);

		this.model.filters.each(function (filter) {
			var filterView = new FilterView({
				model: filter
			});

			$ul.append(filterView.render());
		});

		this.$el.append($ul);

		this.update();

		return this.$el;
	}
});
