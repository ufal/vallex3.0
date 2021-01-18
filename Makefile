SHELL = /bin/bash

ver = 4.0-work
XML_newest = XMLverbs.xml
XML_NOUNS = XMLlvc-nouns.xml
dir_html_in = xml2html30
dir_out     = vallex-$(ver)
dir_xml_out = $(dir_out)/data/xml
dir_doc_out = $(dir_out)/doc
dir_valeval = extern/cnk
XML = $(dir_xml_out)/vallex-$(ver).xml#	 name of -> XML file itself
date = $(shell date +%F_%H:%M)

all: html nounhtml www



$(XML): $(XML_newest)
	@echo Copying the newest version of XML
	mkdir -p $(dir_xml_out)
	cp $(XML_newest) $(XML)

html: $(XML)
	#@echo Copying VALEVAL annotation
	#@mkdir -p $(dir_out)/data/html/generated/cnk
	#cp $(dir_valeval)/*html $(dir_out)/data/html/generated/cnk
	@echo Creating HTML files from verb XML file
	# perlbrew exec --with perl-5.20.1 $(dir_html_in)/xml2html.pl $(XML) $(dir_html_in) $(ver)
	# perlbrew exec --with perl-5.18.2 $(dir_html_in)/xml2html.pl $(XML) $(dir_html_in) $(ver)
	$(dir_html_in)/xml2html.pl $(XML) $(dir_html_in) $(ver)
	#cp $(dir_valeval)/valeval.xml $(dir_valeval)/valeval.dtd $(dir_xml_out)

nounhtml: $(XML_NOUNS)
	@echo Creating HTML files from noun XML file
	# perlbrew exec --with perl-5.20.1 $(dir_html_in)/xml2html.pl $(XML_NOUNS) $(dir_html_in) $(ver)
	# VERB_MODE=0 $(dir_html_in)/xml2html.pl $(XML_NOUNS) $(dir_html_in) $(ver) $(XML)
	NOUN_MODE=1 $(dir_html_in)/xml2html.pl $(XML_NOUNS) $(dir_html_in) $(ver)
	@echo Done.




www:
#	scp -r $(dir_out)/data/html/ vernerova@ufal:public_html/vallex31/
#	scp vallex-$(ver)/data/html/generated/lexeme-entries/* vernerova@ufal:public_html/vallex31/html/generated/lexeme-entries
#	ssh vernerova@ufal ' \
#		cp -r  public_html/vallex31/html public_html/vallex31/test_`date +%F_%T`; \
#		rm -rf public_html/vallex31/test-Nov; \
#		mv     public_html/vallex31/html public_html/vallex31/test-Nov'
	# or
	echo $(date)
	rsync -av --copy-unsafe-links --delete --checksum $(dir_out)/data/html/ --link-dest ../$(ver)-test vernerova@ufal:vallex_web/$(ver)_${date}
	ssh vernerova@ufal 'unlink vallex_web/$(ver)-test; ln -s $(ver)_$(date) vallex_web/$(ver)-test'
	#### cp 3.0 3.0_backup_<datum>
	#### cd     3.0_backup_<datum>
	#### cp about.html grammar.html guide.html theory.html obr-* ../3.0/
	


cleanrelease:
	rm -rf $(dir_out)/*

