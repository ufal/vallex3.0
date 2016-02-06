var AppRouter = Backbone.Router.extend({
	routes: {
		"filter/*path": "getFilter",
		"lexeme/:lexeme": "getLexeme",
		"lexeme/:lexeme/:unit": "getLexeme",
		// "*actions": "defaultRoute"
	}
});
