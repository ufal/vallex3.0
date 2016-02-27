var path_to_generated = "./generated/";

// nástavba kolekce filtrů
var Filters = Backbone.Model.extend({

	defaults: {
		visible: false
	},

	filters: null,

	initialize: function (filters) {
		this.filters = new FilterCollection(filters);
	},
});

var Filter = Backbone.Model.extend({
	defaults: {
		name: null,
		url: null,
		selected: false,
	},

	subfilters: null,

	initialize: function (settings) {
		this.on("change:selected", function () {
			if(this.subfilters){
				this.subfilters.set("visible", this.get("selected"));
				this.subfilters.filters.invoke("set", "selected", false);
			}
		}, this);

		if(settings !== undefined){
			this.set(settings);
			if(settings.subfilters.length > 0){
				this.subfilters = new Filters(settings.subfilters);
			}
		}
	},

	setSelectedFilter: function (path, rest) {
		var filterName = rest.shift();
		path.push(filterName);

		this.set("selected", true);
		if(this.subfilters){
			this.subfilters.filters.invoke("set", "selected", false);
			var selectedChild = this.subfilters.filters.where({
				"id" : path.join("/")
			});
			console.log(this.get("id"), selectedChild);

			if(selectedChild.length > 0)
				return selectedChild[0].setSelectedFilter(path, rest);
			else
				return this;
		}
		else {
			return this;
		}
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

			// modré vyhledávadlo
			var advancedSearch = _.template($("#advanced-search-template").html());
			this.filterView.subfilters.$el.find("ul").append(advancedSearch);

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

	initialize: function() {
		this.listenTo(this.model, "change:selected", this.render);

		if(this.model.subfilters !== null){
			this.subfilters = new FiltersView({
				model: this.model.subfilters
			});
			var filtersDOM = this.subfilters.render();
		}
	},

	render: function() {
		this.$el.html("");


		var a = document.createElement("a");
		var $a = $(a);
		$a.addClass("togglable");

		var path = this.model.id;

		if(this.model.get("selected")){
			$a.addClass("selected");
			path = path.split("/");
			path.pop();
			path = path.join("/");

			// filters_summary
			var li = document.createElement("li");
			li.innerHTML = this.model.get("name");
			$(".header .filters_summary ul").append(li);
		}

		$a.attr("href", "#/filter/" + path);
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
