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

		this.set("selectedLexeme", null);
	},

	findBest: function (str) {
		if(!str){
			return [0, this.filtered[0]];
		}

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
			if(found){
				return [i, lu];
			}
		}

		// pokud nenajde nic jednoduché vyhledávání, přepne se na složitější
		if(!found){
			for (var i = 0; i < this.filtered.length; i++) {
				var lu = this.filtered[i];
				var namesString = lu.parent.get("name").toLowerCase();
				var names = namesString.split(", ");
				for (var n = 0; n < names.length; n++) {
					var name = names[n];
					var found = true;
					for (var j = 0; j < str.length; j++) {
						if(str[j] != name[j]){
							found = false;
							break;
						}
					}
					if(found){
						return [i, lu];
					}
				}
			}
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
					_this.filtered.push(unit);

					// alphabet statistics
					var letter = _this.getLetter(lexeme);

					_this.alphabet[letter]++;
				}
			});
		});
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

		console.log("parsed length", list.length);

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
		}
		var id = lexemes[imin].getAttribute("data-id");
		var lexeme = appView.lexemes.getLexeme(id);
		var letter = appView.lexemes.getLetter(lexeme);

		$(".alphabet_row").toggleClass("selected", false);
		$(".alphabet_row."+letter).toggleClass("selected", true);
	},

	render: function () {
		var alphabetTable = _.map(this.model.alphabet, function (letterStats, letter) {
			if(letterStats != 0){
				return "<tr onClick='appView.lexemesView.scrollToLetter(\""+letter+"\")' class='alphabet_row "+letter+"'><td class='letter'>"+letter+"</td><td class='count'>"+letterStats+"</td></tr>"
			}
			return "";
		});

		this.$el.find("table").html(alphabetTable);
	},
});

var LexemesView = Backbone.View.extend({
	// events: {
	// 	"keyup .search_input": "search",
	// },
	initialize: function () {
		this.listenTo(this.model, "filtersChange", this.render);
		this.listenTo(this.model, "change:selectedLexeme", this.showLexeme);

		// autocomplete
		var _this = this;
		$('.search_input').autocomplete({
			preserveInput: true, // kvůli homographs, které dělají neplechu s html tagy
			autoSelectFirst: true,
			lookup: function (query, done) {
				var result = {
					suggestions: []
				};

				if(query){
					var unique = {};
					for (var i = 0; i < _this.model.filtered.length; i++) {
						var lu = _this.model.filtered[i];
						var namesString = lu.parent.get("name").toLowerCase();
						var names = namesString.split(", ");
						for (var n = 0; n < names.length; n++) {
							var name = names[n];
							var found = true;
							for (var j = 0; j < query.length; j++) {
								if(name[j] != query[j]){
									found = false;
									break;
								}
							}
							if(found && !unique[lu.parent.id]){
								result.suggestions.push({
									"value": namesString,
									"data": lu
								});
								unique[lu.parent.id] = true;
								break;
							}
						}
					}
				}


				done(result);
			},
			formatResult: function (suggestion, currentValue) {
				// vybarví matchnuté začátky lemmat
				return _(suggestion.value.split(", ")).map(function (lemma) {
					for (var i = 0; i < currentValue.length; i++) {
						if(lemma[i] != currentValue[i])
							break;
					}
					if(currentValue.length == i)
						return "<strong>" + lemma.substr(0, i) + "</strong>" + lemma.substr(i);
					else
						return false;
				}).filter(function (lemma) {
					return lemma !== false;
				}).join(", ");
			},

			onSelect: function (suggestion) {
				var lu = suggestion.data;
				// select
				appView.router.navigate("#/lexeme/"+lu.parent.id+"/"+lu.id, {trigger:true});
				// scroll
				_this.$el.find(".result").mCustomScrollbar("scrollTo", "."+lu.parent.id);
			}
		});
	},

	search: function (e) {
		if(e.keyCode == 13){
			this.select(e.target.value);
		}

		this.scrollTo(e.target.value);
	},

	clearSearch: function (e) {
		this.$el.find(".search_input").val("");
		// odstraní šedou
		// this.grayFiltered();
	},

	scrollToLetter: function (letter) {
		this.clearSearch();
		this.scrollTo(letter);
	},

	// scroll k prvnímu odpovídajícímu výsledku podle str
	scrollTo: function (str) {
		console.time("findBest");
		var first = this.model.findBest(str);
		console.timeEnd("findBest");

		// var _this = this;
		// _.defer(function () {
		// 	_this.grayFiltered(str);
		// });

		if(first !== undefined){
			this.$el.find(".result").mCustomScrollbar("scrollTo", "."+first[1].parent.id);
		}
	},

	grayFiltered: function (str) {
		console.time("gray");
		var results = $(".result li a");
		if(str){
			$(".result .found").removeClass("found");
			$(".result").addClass("search_active");
			for (var i = 0; i < this.model.filtered.length; i++) {
				var lu = this.model.filtered[i];
				var namesString = lu.parent.get("name").toLowerCase();
				var names = namesString.split(", ");
				for (var n = 0; n < names.length; n++) {
					var name = names[n];
					var found = true;
					for (var j = 0; j < str.length; j++) {
						if(name[j] != str[j]){
							found = false;
							break;
						}
					}
					if(found){
						$(results[i]).addClass("found");
						break;
					}
				}
			}
		}
		else {
			$(".result").removeClass("search_active");
		}

		console.timeEnd("gray");
	},

	select: function (str) {
		var first = this.model.findBest(str);
		console.log(first)
		this.model.setSelectedLexeme(first[1].parent.id, first[1].id);
	},

	render: function () {
		console.time('lexemesRender');

		this.clearSearch();

		// popisek do placeholderu hledacího políčka
		// trochu zneužívá to, že ve filtru jsou buď jen lexémy a nebo LU
		// ale to snad nevadí
		var search_description = this.model.filtered[0].id > 0 ? "LU" : "lexeme";
		if(this.model.filtered.length > 1)
			search_description += "s";

		this.$el.find(".search_input").attr("placeholder", "search ("+this.model.filtered.length+" "+search_description+")");
		var $ul = this.$el.find(".result ul").html("");
		var ul = $ul[0];
		var _this = this;
		var selectedLexeme = this.model.get("selectedLexeme");
		var asyncWrite = function (filtered, pos) {
			var output = [];
			var maxPos = Math.min(50, filtered.length);
			if(pos > 0)
				maxPos = filtered.length;
			for (var i = pos; i < maxPos; i++) {
				var lu = filtered[i];
				var parent = lu.parent;
				var selected = "";
				if(lu == selectedLexeme)
					selected = " selected";

				var luId = "";
				if(lu.id > 0)
					luId = "&nbsp;" + lu.id;

				var str = "<li data-id='"+parent.id+"'><a href='#/lexeme/"+parent.id+"/"+lu.id+"' class='"+parent.id+" u"+lu.id+selected+"'>" + parent.get("name") + luId + "</a></li>";
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
		this.clearSearch();

		var lu = this.model.get("selectedLexeme");
		if(lu === null)
			return;
		var prevlu = this.model.previous("selectedLexeme");
		var lexeme = lu.parent;
		var LUIndex = lu.id;

		// označení ve vyhledávání
		if(prevlu)
			this.$el.find(".result ul li ."+prevlu.parent.id).removeClass("selected").off("click");
		this.$el.find(".result ul li ."+lexeme.id+".u"+lu.id)
			.addClass("selected")
			.one("click", function (e) {
				e.preventDefault();
				appView.router.navigate("#/lexeme/"+lexeme.id+"/0", {trigger:true});
			});

		// pokud je stránka již načtená
		if(prevlu !== null && prevlu.parent.id == lu.parent.id){
			// označí aktivní LU
			this.toggleLUSelection(lu.id);
			// otevře aktivní LU
			this.toggleLUExpansion(lu.id, true);
		}
		else {
			this.showPage(lexeme, lu);
		}

	},

	showPage: function (lexeme, lu) {
		var _this = this;
		lexeme.getPage(function (data) {
			data = "<div>" + data + "</div>";
			var $data = $(data);
			var header = $data.find(".wordentry_header");
			var content = $data.find(".wordentry_content");
			$(".wordentry .wordentry_header .matrjoska").html(header.html());
			$(".wordentry .wordentry_content .matrjoska").html(content.html());
			var lu = _this.model.get("selectedLexeme");
			$(".lexical_unit .more").hide();

			// funkce rozbalovače
			$(".lexical_unit .expander").click(function (e) {
				var id = $(e.target).parents(".lexical_unit").data("id");
				_this.toggleLUExpansion(id);
			});

			// funkce kliknutí na číslo pro aktivní lexém
			// (aktivní lexém nespouští event změny adresy webu)
			$(".lexical_unit .frame_index_link").click(function (e) {
				var lu = _this.model.get("selectedLexeme");
				var id = $(e.target).parents(".lexical_unit").data("id");
				if(lu.id == id){
					_this.toggleLUSelection(id);
					_this.toggleLUExpansion(id, true);
				}
			});

			// označování kliknutím do prázdna
			// $(".lexical_unit").click(function (e) {
			// 	console.log($(e.target).data("events"))
			// 	if(!$(e.target).is("a")){
			// 		var id = $(e.target).parents(".lexical_unit").data("id");
			// 		var selected = _this.toggleLUSelection(id);
			// 		_this.toggleLUExpansion(id, selected);
			// 	}
			// });

			// otevření, pokud je < 3 LU
			if($(".lexical_unit").length <= 3){
				for (var i = 0; i < $(".lexical_unit").length; i++) {
					_this.toggleLUExpansion(i+1, true);
				};
			}
			else {
				// otevře aktivní LU
				if(lu.id > 0)
					_this.toggleLUExpansion(lu.id, true);
			}

			// označí aktivní LU
			if(lu.id > 0){
				_this.toggleLUSelection(lu.id);
			}
		});
	},

	clearPage: function () {
		$(".wordentry .matrjoska").html("");
		this.model.set("selectedLexeme", null);
	},

	toggleLUSelection: function (id, select) {
		var $selecting = $(".wordentry .matrjoska .lexical_unit.u"+id);
		var selected = $selecting.hasClass("selected");
		$(".wordentry .matrjoska .lexical_unit").toggleClass("selected", false);
		if(!selected || select !== undefined){
			$(".wordentry .matrjoska .lexical_unit.u"+id).toggleClass("selected", select);
		}

		$(".wordentry_content").mCustomScrollbar("scrollTo", ".lexical_unit.u"+id, {
			scrollInertia: 250
		});

		return select === undefined ? !selected : select;
	},

	toggleLUExpansion: function (id, expand) {
		// var parent = $(e.target).parents(".lexical_unit");
		var $parent = $(".wordentry .matrjoska .lexical_unit.u"+id);
		var $expander = $parent.find(".expander");
		if($expander.hasClass("disabled"))
			return false;

		if(($expander.hasClass("expanded") && expand === undefined) || expand === false){
			$expander.find("span").html("more");
			$expander.removeClass("expanded");

			$parent.find(".more").hide(200);

			return false;
		}
		else {
			$expander.find("span").html("less");
			$expander.addClass("expanded");

			$parent.find(".more").show(200);

			return true;
		}
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