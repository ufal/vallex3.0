var AppRouter = Backbone.Router.extend({
	routes: {
		"filter/:id": "getFilter",
		"lexeme/:lexeme": "getLexeme",
		"lexeme/:lexeme/:unit": "getLexeme",
		// "*actions": "defaultRoute"
	}
});
