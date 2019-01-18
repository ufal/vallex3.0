SHELL = /bin/bash

ver = 3.1_jmena_0.0-work
ver_nouns = 0.1-jmena
#XML_newest = ../../XML_3.1_0.0
XML_newest = ../../vallex-3.1_jmena_0.0-work/data/xml/vallex-3.1_jmena_0.0-work-b.xml
XML_NOUNS = ../../XML-nouns_0.1
dir_html_in = xml2html
dir_out     = vallex-$(ver)
dir_xml_out = $(dir_out)/data/xml
dir_doc_out = $(dir_out)/doc
dir_valeval = ../../extern/cnk
XML = $(dir_xml_out)/vallex-$(ver).xml#	 name of -> XML file itself

all: html nounhtml www



$(XML): $(XML_newest)
	@echo Copying the newest version of XML
	mkdir -p $(dir_xml_out)
	cp $(XML_newest) $(XML)

html: $(XML)
	@echo Copying VALEVAL annotation
	@mkdir -p $(dir_out)/data/html/generated/cnk
	cp $(dir_valeval)/*html $(dir_out)/data/html/generated/cnk
	@echo Creating HTML files from verb XML file
	# perlbrew exec --with perl-5.20.1 $(dir_html_in)/xml-b-to-html.pl $(XML) $(dir_html_in) $(ver)
	# perlbrew exec --with perl-5.18.2 $(dir_html_in)/xml-b-to-html.pl $(XML) $(dir_html_in) $(ver)
	$(dir_html_in)/xml-b-to-html.pl $(XML) $(dir_html_in) $(ver)
	cp $(dir_valeval)/valeval.xml $(dir_valeval)/valeval.dtd $(dir_xml_out)

nounhtml: $(XML_NOUNS)
	@echo Creating HTML files from noun XML file
	# perlbrew exec --with perl-5.20.1 $(dir_html_in)/xml-b-to-html.pl $(XML_NOUNS) $(dir_html_in) $(ver_nouns)
	VERB_MODE=0 $(dir_html_in)/xml-b-to-html.pl $(XML_NOUNS) $(dir_html_in) $(ver_nouns) $(XML)
	@echo Done.




www:
	scp -r $(dir_out)/data/html/ bejcek@ufal:public_html/vallex31/
	ssh bejcek@ufal ' \
		cp -r  public_html/vallex31/html public_html/vallex31/test_`date +%F_%T`; \
		rm -rf public_html/vallex31/test-Nov; \
		mv     public_html/vallex31/html public_html/vallex31/test-Nov'
	scp vallex-$(ver_nouns)/data/html/generated/lexeme-entries/* bejcek@ufal:public_html/vallex31/test-Nov/generated/lexeme-entries
	# or
	# scp -r $(dir_out)/data/html/ bejcek@ufal:web_vallex/3.1-test/
	# ssh bejcek@ufal 'cp -r web_vallex/3.1-test/html web_vallex/3.1-test/3.1-test_`date +%F_%T`'
	#### cp 3.0 3.0_backup_<datum>
	#### cd     3.0_backup_<datum>
	#### cp about.html grammar.html guide.html theory.html obr-* ../3.0/
	


cleanrelease:
	rm -rf $(dir_out)/*

