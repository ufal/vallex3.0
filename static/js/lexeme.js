var Lexemes = Backbone.Model.extend({
	lexemes: null,
	cached: null,
	filtered: null,
	alphabet: null,
	alphabetDefault: ["a","b","c","č","d","e","f","g","h","ch","i","j","k","l","m","n","o","p","r","ř","s","š","t","u","v","z","ž"],

	initialize: function () {
		this.lexemes = new LexemeCollection();
		this.filtered = [];
		this.alphabet = {};
		this.cached = {};
	},

	findFirst: function (str) {
		str = str.toLowerCase();
		for (var i = 0; i < this.filtered.length; i++) {
			var lu = this.filtered[i];
			var name = lu.parent.get("name").toLowerCase();
			var found = true;
			for (var j = 0; j < str.length; j++) {
				if(str[j] != name[j]){
					found = false;
					break;
				}
			}
			if(found)
				return [i, lu];
		}
	},

	getLexeme: function (id) {
		var lexeme = this.lexemes.get(id);
		if(lexeme === undefined){
			lexeme = new Lexeme({
				id: id,
			});
		}
		return lexeme;
	},

	setSelectedLexeme: function (lexemeId, LUIndex) {
		this.set("selectedLexeme", this.getLexeme(lexemeId).getUnit(LUIndex));
	},

	showFiltered: function (filter) {
		console.log("filter", filter.id)
		if(this.cached[filter.id] === undefined){
			this.downloadList(filter, this.showFiltered);
			return;
		}

		this.alphabet = {};
		// init alphabet stats
		_.each(this.alphabetDefault, function (letter) {
			this.alphabet[letter] = 0;
		}, this);

		console.time('lexemesFilter');
		this.filtered = [];
		var _this = this;
		this.lexemes.each(function (lexeme) {
			lexeme.units.each(function (unit) {
				if(unit.tags[filter.id]){
					// add to filtered
					_this.filtered.push(unit); // TODO!!

					// alphabet statistics
					var letter = _this.getLetter(lexeme);

					_this.alphabet[letter]++;
				}
			});
		});

		// console.log(this.filtered.length);
		// console.log(this.alphabet);
		console.timeEnd('lexemesFilter');
		this.trigger("filtersChange");
	},

	getLetter: function (lexeme) {
		var name = lexeme.get("name").toLowerCase();
		var letter = name[0];
		if(name[0] == "c" && name[1] == "h")
			letter = "ch";
		if(this.alphabet[letter] == undefined)
			letter = lexeme.id.toLowerCase()[0];

		return letter;
	},

	downloadList: function (filter, callback) {
		var _this = this;
		console.log("down", path_to_generated+filter.get("url"))
		$.getJSON(path_to_generated + filter.get("url"), {}, function (data) {
			_.defer(function () {
				_this.parseList(data, filter);
				callback.call(_this, filter);
			});
		});
	},

	parseList: function (list, filter) {
		console.time("parseList");
		_.each(list, function (link) {
			var lexeme = this.lexemes.get(link[0]); // get podle id
			if(lexeme === undefined){
				lexeme = this.lexemes.add({
					id: link[0],
					name: link[2],
				});
			}

			var LUIndex = link[1];
			var lexicalUnit = lexeme.getUnit(LUIndex);
			lexicalUnit.tags[filter.id] = true;
		}, this);

		console.log(list.length);
		console.log(this.lexemes.length);

		this.cached[filter.id] = true;
		console.timeEnd("parseList");
	}
});

var Lexeme = Backbone.Model.extend({
	defaults: {
		name: null,
	},
	units: null,
	html: null,
	initialize: function (settings) {
		this.units = new LexicalUnitCollection();
	},
	getUnit: function (id) {
		var lu = this.units.get(id);
		if(lu === undefined){
			lu = this.units.add({
				id: id
			});
			lu.parent = this;
		}
		return lu;
	},
	getPage: function (callback) {
		if(this.html === null){
			var path = path_to_generated + "lexeme-entries/" + this.id + ".html";
			_this = this;
			$.get(path, {}, function (data) {
				_this.html = data;
				callback.call(_this, data);
			});
		}
		else {
			callback.call(this, this.html);
		}
	},
});

var LexemeCollection = Backbone.Collection.extend({
	model: Lexeme
});

var AlphabetView = Backbone.View.extend({
	initialize: function () {
		this.listenTo(this.model, "filtersChange", this.render);
	},

	framelistScroll: function () {
		var parentOffset = $(".framelist .result").offset().top;
		var lexemes = $(".framelist .result li");
		// binary search
		var imin = 0, imax = lexemes.length-1;
		var cnt = 0;
		while (imin <= imax) {
			var imid = Math.floor((imin+imax)/2);
			var offset = lexemes[imid].getBoundingClientRect().top;
			if (offset < parentOffset)
				imin = imid + 1;
			else
				imax = imid - 1;

			cnt++;
		}1 / 32
		var id = lexemes[imin].getAttribute("data-id");
		var lexeme = appView.lexemes.getLexeme(id);
		var letter = appView.lexemes.getLetter(lexeme);

		$(".alphabet_row").toggleClass("selected", false);
		$(".alphabet_row."+letter).toggleClass("selected", true);
	},

	render: function () {
		var alphabetTable = _.map(this.model.alphabet, function (letterStats, letter) {
			if(letterStats != 0){
				return "<tr onClick='appView.lexemesView.scrollTo(\""+letter+"\")' class='alphabet_row "+letter+"'><td class='letter'>"+letter+"</td><td class='count'>"+letterStats+"</td></tr>"
			}
			return "";
		});

		this.$el.find("table").html(alphabetTable);
	},
});

var LexemesView = Backbone.View.extend({
	events: {
		"keyup .search_input": "search"
	},
	initialize: function () {
		this.listenTo(this.model, "filtersChange", this.render);
		this.listenTo(this.model, "change:selectedLexeme", this.showLexeme);
	},

	search: function (e) {
		this.scrollTo(e.target.value);
	},

	// scroll k prvnímu odpovídajícímu výsledku podle str
	scrollTo: function (str) {
		var first = this.model.findFirst(str);
		if(first !== undefined){
			this.$el.find(".result").mCustomScrollbar("scrollTo", "."+first[1].parent.id, {
				scrollInertia: 250
			});
		}
	},

	render: function () {
		console.time('lexemesRender');
		this.$el.find(".search_input").attr("placeholder", "search ("+this.model.filtered.length+")");
		var $ul = this.$el.find(".result ul").html("");
		var ul = $ul[0];
		var _this = this;
		var selectedLexeme = this.model.get("selectedLexeme");
		var asyncWrite = function (filtered, pos) {
			var output = [];
			var maxPos = 50;
			if(pos > 0)
				maxPos = filtered.length;
			for (var i = pos; i < maxPos; i++) {
				var lu = filtered[i];
				var parent = lu.parent;
				var selected = "";
				if(lu == selectedLexeme)
					selected = " selected";
				var str = "<li data-id='"+parent.id+"'><a href='#/lexeme/"+parent.id+"/"+lu.id+"' class='"+parent.id+" u"+lu.id+selected+"'>" + parent.get("name") + "&nbsp;" + lu.id + "</a></li>";
				output.push(str);
			}
			ul.innerHTML += output.join("");
			if(i < filtered.length)
				_.defer(asyncWrite, filtered, i);
			else
				console.timeEnd('lexemesRender');
		}
		_.defer(asyncWrite, this.model.filtered, 0);
		// this.$el.html(html);
	},

	showLexeme: function () {
		var lu = this.model.get("selectedLexeme");
		var prevlu = this.model.previous("selectedLexeme");
		var lexeme = lu.parent;
		var LUIndex = lu.id;

		console.time("select");
		if(prevlu)
			this.$el.find(".result ul li ."+prevlu.parent.id).removeClass("selected");
		this.$el.find(".result ul li ."+lexeme.id+".u"+lu.id).addClass("selected");
		console.timeEnd("select");

		var _this = this;
		lexeme.getPage(function (data) {
			$(".wordentry .matrjoska").html(data);
			var lu = _this.model.get("selectedLexeme");
			$(".lexical_unit .more").hide();
			$(".lexical_unit .expander").click(function (e) {
				var parent = $(e.target).parents(".lexical_unit");
				var $expander = $(this);
				if($expander.hasClass("expanded")){
					$expander.find("span").html("more");
					$expander.removeClass("expanded");

					parent.find(".more").hide(200);
				}
				else {
					$expander.find("span").html("hide");
					$expander.addClass("expanded");

					parent.find(".more").show(200);
				}
			})
			if(lu.id > 0){
				$(".wordentry .matrjoska .lexical_unit.u"+lu.id).addClass("selected");
				$(".wordentry").mCustomScrollbar("scrollTo", ".lexical_unit.u"+lu.id, {
					scrollInertia: 250
				});
			}
			// _this.expand(lu.id);
		});
	}
});


var LexemeView = Backbone.View.extend({

});

var LexicalUnit = Backbone.Model.extend({
	tags: null,
	initialize: function () {
		this.tags = {};
	}
});

var LexicalUnitCollection = Backbone.Collection.extend({
	model: LexicalUnit
});