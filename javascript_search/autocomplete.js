
    function lookupLocal(){
	    var oSuggest = $("#vallex_search")[0].autocompleter;
	    oSuggest.findValue();
	    return false;
    }

    function findValue(li) {
    	if( li == null ) return alert("bohužel!");
    	// if coming from an AJAX call, let's use the CityId as the value
    	if( !!li.extra ) var sValue = li.extra[0];
    	// otherwise, let's just display the value in the text box
    	else var sValue = li.selectValue;
    	parent.frames[3].location.href="../lexeme-entries/"+sValue+".html";
    }

    function selectItem(li) {
    	findValue(li);
    }


    $(document).ready(function() {
	    $("#vallex_search").autocompleteArray(
		vallex_lexeme_entries_index,
		{
			delay:10,
			minChars:1,
			matchSubset:1,
			onItemSelect:selectItem,
			onFindValue:findValue,
			autoFill:true,
			maxItemsToShow:10,
      selectFirst:1
		}
	);
  $("#vallex_search").focus();
});
