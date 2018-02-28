#!/usr/bin/env perl

use strict;
use warnings;
use locale;
use POSIX qw(locale_h);
setlocale(LC_ALL,"cs_CZ.utf8");
# setlocale('LANG',"czech");
use utf8;
use JSON qw(encode_json);
# use encoding "utf-8";
binmode STDERR,":encoding(utf-8)";
binmode STDOUT,":encoding(utf-8)";


use XML::DOM;
use List::Util 1.33 'none';
# use Data::Dumper;

my $VERB_MODE = 1;

# ------------------ initializing hint hashes ----------------------

my $xmlfile = shift;
my $xml2html_dir = shift;
my $version = shift;


my $outputdir = "$xml2html_dir/../vallex-$version/data/html/";


my %functor_comments = (
  "ACT" => "actor",
  "ADDR" => "addressee",
  "PAT" => "patient",
  "EFF" => "effect",
  "ORIG" => "origin",
  "DIFF" => "difference",
  "OBST" => "obstacle",
  "ACMP" => "accompaniement",
  "AIM" => "aim",
  "BEN" => "benefactive",
  "CAUS" => "cause",
  "COMPL" => "complement",
  "CPHR" => "compound phraseme",
  "CRIT" => "criterion/measure/standard",
  "DIR" => "shortcut for DIR1 DIR2 DIR3",
  "DIR1" => "direction-from",
  "DIR2" => "direction-through",
  "DIR3" => "direction-to",
  "DPHR" => "dependent part of a phraseme",
  "EXT" => "extent",
  "HER" => "heritage",
  "INTT" => "intent",
  "LOC" => "locative",
  "MANN" => "manner",
  "MEANS" => "means",
  "NORM" => "norm",
  "RCMP" => "recompense",
  "REG" => "regard",
  "RESL" => "result",
  "SUBS" => "substitution",
  "TFHL" => "temporal-for-how-long",
  "TFRWH" => "temporal-from-when",
  "THL" => "temporal-how-long ",
  "TOWH" => "temporal-to when",
  "TSIN" => "temporal-since-when",
  "TTILL" => "temporal-until-when",
  "TWHEN" => "temporal-when"
);

my %type_of_compl = (
  'opt' => 'type of complementation: optional',
  'typ' => 'type of complementation: typical',
  'obl' => 'type of complementation: obligatory'
);

my $border = 0;

my %long_attr_names = (
  'class' => 'sem. class',
  'frame' => 'val. frame',
);
 
my %long_form_types = (
  'direct_case' => 'Direct cases',
  'prepos_case' => 'Prepositional cases',
  'subord_conj' => 'Subordinating conjunctions',
  'cont' => 'Content clauses',
  'infinitive' => 'Infinitive',
  'adjective' => 'Constructions with adjectives',
  'byt' => 'Constructions with "být" (to be)',
  'phraseme_part' => 'Parts of phrasemes',
  'possessive' => 'Possessive',
);

my %long_form_type = (
  'direct_case' => 'direct case',
  'prepos_case' => 'prepositional case',
  'subord_conj' => 'subordinating conjunction',
  'cont' => 'content clause',
  'infinitive' => 'infinitive',
  'adjective' => 'construction with an adjective',
  'byt' => 'construction with "být" (to be)',
  'phraseme_part' => 'part of a phraseme',
  'possessive' => 'possessive',
);
my %case_names = (
  '1' => 'nominative',
  '2' => 'genitive',
  '3' => 'dative',
  '4' => 'accusative',
  '5' => 'vocative',
  '6' => 'locative',
  '7' => 'instrumental',
);


my $bullet = "<img src='../../static/redbullet.gif'>";

use Readonly;
Readonly my $PDTVALLEX_URL => "http://lindat.mff.cuni.cz/services/PDT-Vallex/?verb=";
my ($multiframe,$template);

my %irrefl_mlemma;

# ----------------- pomocne funkce ----------------


# prevod arabskych cislic na rimske (zatim napraseno)
sub ara2roman ($) {
  my ($cnt)=@_;
  return join "",map {'I'} (1..$cnt);
}

# odstraní whitespace z obou stran stringu
sub trim {
  my $s = shift;
  $s =~ s/^\s+|\s+$//g;
  return $s;
};

# nahradi znaky s diakritikou a prida za ne suffix (zatim jednosmerne!)
my %substitution;
my %subst_prefs;
sub string_to_html_filename {
  my $orig=shift;
  if (not $substitution{$orig}) {
    my $subst_prefix;
    my $subst_suffix = "";
    if ($orig =~ /^lxm-v-/) {
      $subst_prefix = $1 if $orig =~ /^lxm-v-(.{1,5}).*?$/;
      $subst_prefix =~ tr/áéíóúůýěžščřďťň/aeiouuyezscrdtn/;
      $subst_prefix =~ s/[^a-zA-Z0-9-]/_/g;
      $subst_suffix = ++$subst_prefs{$subst_prefix};
    } else {
      $subst_prefix = $orig =~ /^([^:]*).*$/s ? $1 : "";
      $subst_prefix =~ tr/áéíóúůýěžščřďťňŽŠČŘĎŤŇ/aeiouuyezscrdtnZSCRDTN/;
      $subst_prefix =~ s/^\s+//;
      $subst_prefix =~ s/\s+$//;
      $subst_prefix =~ s/, /-/; # control: ACT, PAT
      $subst_prefix =~ tr/+ /-_/; # forms:   mezi+4     do bot
      $subst_prefix =~ s/[^a-zA-Z0-9_-]/./g;
      $subst_prefix = "_" if !$subst_prefix;
      if ($subst_prefs{$subst_prefix}) {
        $subst_suffix = ++$subst_prefs{$subst_prefix};
      } else {
        $subst_prefs{$subst_prefix} = 1;
      }
    }
    $substitution{$orig} = "$subst_prefix$subst_suffix";
  }
  return $substitution{$orig};
}



sub create_directory ($) {
  my $directory_name = shift;
  my $fullpath = $outputdir.$directory_name;
  print STDERR "Creating directory $fullpath ...\n";
  system "mkdir $fullpath -p";
}

my $javascript_head = '<script type="text/javascript" src="jquery.js"></script>
  <script type="text/javascript" src="jquery.autocomplete.js"></script>
  <link rel="stylesheet" type="text/css" href="jquery.autocomplete.css"/>
  <script type="text/javascript" src="../lexeme-entries/index.js"></script>
  <script type="text/javascript" src="autocomplete.js"></script>';

my $HTML_noun_header = '<!DOCTYPE html>
<html>
<head>
        <title>vallex 3.0</title>
        <meta charset="utf-8">
        <link rel="stylesheet/less" type="text/css" href="../../css/styles.less">
        <script src="../../libs/less.min.js"></script>
        <script src="../../libs/underscore-min.js"></script>
        <script src="../../libs/jquery-2.1.4.min.js"></script>
        <script src="../../libs/jquery.autocomplete.min.js"></script>
        <script src="../../libs/jquery.mCustomScrollbar.concat.min.js"></script>
        <script src="../../libs/backbone-min.js"></script>

        <script src="../../js/layout.js"></script>
        <script src="../../js/filters.js"></script>
        <script src="../../js/lexeme.js"></script>
        <script src="../../js/router.js"></script>
        <script src="../../js/app.js"></script>
</head>
<body>';
my $HTML_noun_footer = "</body>\n</html>";


sub create_html_file ($$) {
  my ($filename, $content)=@_;
  $filename = $outputdir.$filename;
  # print STDERR "Storing $filename ...\n";
  open F,">:encoding(utf-8)",$filename or print STDERR  "!!!! Nelze otevrit $filename pro zapis\n"; # should be die!
  print F $HTML_noun_header if !$VERB_MODE;
  print F $content;
  print F $HTML_noun_footer if !$VERB_MODE;
  close F;
}

sub create_multiframe ($$$) {
  my ($filename,$firstframelist,$firstentryfilename)=@_;
  my $m=$multiframe;
  $filename = $outputdir.$filename;
  $m=~s/#framelist#/$firstframelist/;
  $m=~s/#wordentry#/$firstentryfilename/;
  # open F,">:encoding(utf-8)",$filename;
  # open F,">:$filename";
  # $filename=~s/^(..............................).+/$1/;  #hack!!!! tady by mel byt poradny test
  # print STDERR "Storing $filename ...\n";
  open F,">:encoding(utf-8)",$filename or print STDERR  "!!!! Nelze otevrit $filename pro zapis\n"; #die "Nelze otevrit $filename pro zapis";
  print F $m;
  close F;
}

sub create_json_file ($$) {
  my ($filename, $hash)=@_;
  $filename = $outputdir.$filename;
  my $json = encode_json($hash);
  open F,">",$filename or print STDERR  "!!!! Nelze otevrit $filename pro zapis\n"; #die "Nelze otevrit $filename pro zapis";
  print F $json;
  close F;
}

sub questionmark ($) {
  my ($label)=@_;
  if ($label) {
    return "<a href='../../../../doc/structure_en.html#sec:$label' target='_parent'><img border='0' src='../../static/questionmark.gif'></a>";
  }
  else {
    return "<img border='0' src='../../static/questionmark.gif'>";
  }
}

sub formnode2formtxt {
  my ($formnode)=@_;
  my $to_be = "";
  if ($formnode->getAttribute('to_be')) { $to_be="být+" }
  my $prep=$formnode->getAttribute('prepos_lemma');
  $prep=~s/\_/ /g;
  my $type=$formnode->getAttribute('type');
  if ($type eq "direct_case") {
    return [$to_be.$formnode->getAttribute('case')];
  }
  elsif ($type eq "prepos_case") {
    return [$prep."+".$formnode->getAttribute('case')]
  }
  elsif ($type eq "subord_conj") {
    return [$formnode->getAttribute('subord_conj_lemma')];
  }
  elsif ($type eq "adjective") {
    my $prepos = $formnode->getAttribute('prepos_lemma');
    $prepos = $prepos ? $prepos."+" : "";
    return [$to_be.$prepos."adj-".$formnode->getAttribute('case')]
  }
  elsif ($type eq "infinitive") {
    if ($prep) {$prep="$prep+";};
    return [$prep.'inf'];
  }
  elsif ($type eq "cont") {
    return ["cont"];
  }
  elsif ($type eq "phraseme_part") {
    return [$formnode->getAttribute('phraseme_part')];
  }
  elsif ($type eq "possessive") {
    return ["poss"];
  }
  else { print STDERR "Nerozeznana forma ($type)!\n"; return ['']  }
}




my %framelist;
my %framecnt;
my %firstframefilename;
my %filtertree;

sub add_to_list ($$$) {
  my ($crit,$value,$link)=@_;
  return unless $value;
  $framelist{$crit}{$value}.=$link;
  $framecnt{$crit}{$value}++;
  $link=~/href=\'([^']+)/;
  $firstframefilename{$crit}{$value}=$1 unless  $firstframefilename{$crit}{$value};
}

# přidá LU do filtrovacího stromu
# parametry:
# - index LU (v našem případě od 1 do n - pořadí v XML)
# - lexém (nejlépe unikátní id)
# - html string lexému - takový, jaký se bude zobrazovat na stránkách v seznamech
# - volitelný počet parametrů cesty ve stromu kritérií
sub unit_to_criteria {
  my $lu_index = shift;
  my $lexeme = shift;
  my $headword_lemmas = shift;

  my $tree = \%filtertree;
  foreach my $node (@_) {
    if(!exists ${${$tree}{"subfilters"}}{$node}){
      ${${$tree}{"subfilters"}}{$node} = {
        "lexemes" => {},
        "subfilters" => {}
      };
    }
    $tree = ${${$tree}{"subfilters"}}{$node};

    ${%{$tree}{"lexemes"}}{$lexeme . "-" . $lu_index} = [$lexeme, $lu_index, $headword_lemmas];
    # push @{%{$tree}{"lexemes"}}, [$lexeme, $lu_index, $headword_lemmas]
      # if none { $_[0] eq $lexeme } @{%{$tree}{"lexemes"}};
  }
}

# přidá lexém do filtrovacího stromu
# parametry:
# - id lexému
# - html string lexému
# - cesta ve stromu
sub lexeme_to_criteria {
  unit_to_criteria (0, @_);
}

sub mlemma_2_string {
  my ($mlemma, $homo_index) = @_;
  my $mlemma_string = $mlemma;
  if ($homo_index) {
    $mlemma_string .= "<sub class='scriptsize'>".ara2roman($homo_index)."</sub>"
  }
  return $mlemma_string;
}





sub lexeme_or_blu_to_lemmas {
  my ($higher_node,$with_aspect) = @_;
  my %asp2lemma;
  my $globreflex = "";

  foreach my $node (
      grep {$_->getNodeType == ELEMENT_NODE}
      map {$_->getChildNodes}
      grep {$_->getNodeType == ELEMENT_NODE and $_->getTagName eq "lexical_forms"} $higher_node->getChildNodes) {
    if ($node->getTagName eq "mlemma") {
      my $refl = $node->getAttribute("optrefl") ? " (".$node->getAttribute("optrefl").")" : "##GLOBREFL##";
      $asp2lemma{$node->getAttribute("coindex")}
        = [[$node->getFirstChild->getNodeValue . $refl, $node->getAttribute('homograph')]]; # TODO o dva radky niz je temer kopie
    } elsif ($node->getTagName eq "mlemma_variants") {
      $asp2lemma{$node->getAttribute("coindex")}
        = [map {
                my $refl = $_->getAttribute("optrefl") ? " (".$_->getAttribute("optrefl").")" : "##GLOBREFL##";
                [$_->getFirstChild->getNodeValue . $refl, $_->getAttribute('homograph')]
            } $node->getElementsByTagName('mlemma')];
    } elsif ($node->getTagName eq "commonrefl") {
      $globreflex = " ".$node->getFirstChild->getNodeValue;
    } else {
      print STDERR "Necekany tagname: ".$node->getTagName()."\n";
    }
  }

  foreach my $coindex (keys %asp2lemma) {
    foreach my $lemma (@{$asp2lemma{$coindex}}) {
      $lemma->[0] =~ s/##GLOBREFL##/$globreflex/g; # replace placeholder by (possibly empty) $globreflex
    }
  }

  return %asp2lemma;
}

sub coindex_sort { # (temer) kopie z txt2xml_b.pl
    local $_ = shift;
    my $n = $1 if s/(\d*)$//;
    s/^biasp$/b$n/;
    s/^pf/c$n/;
    s/^impf/a$n/;
    s/^iter/d$n/;
    return $_;
}

sub lexeme_node_2_headwords {
  my ($aspect2lemma_ref, $with_aspect) = @_;

  my @headwords;

  foreach my $coindex (sort {coindex_sort($a) cmp coindex_sort($b)} keys %$aspect2lemma_ref) {
    my @lemmas = @{$aspect2lemma_ref->{$coindex}};
    push(@headwords,
        join("/", map {mlemma_2_string(@{$_})} @lemmas)
        . ($with_aspect ? "<sup class='scriptsize'>$coindex</sup>" : "")
    );
  }

  return [@headwords];
}

# Returns HTML string with links from lemmas (in this lexeme) to PDT-Vallex
sub pdtvallex_word_links {
  my $lexeme_node = shift;
  my %coindexed_lemmas = @_;
  my $wlink_string;

  # Go through all aspects
  foreach my $wlink ($lexeme_node->getElementsByTagName('wlink')) {
    my @lemmas = @{$coindexed_lemmas{$wlink->getAttribute('coindex')}};
    my $lemma;
    if (@lemmas > 1) { # if there are more variants
      $lemma = $wlink->getAttribute('variant'); # the proper one is specified
    } else {
      $lemma = $lemmas[0]->[0]; # the only one -> 'lemma' from (lemma, homo)
    }
    my $url_lemma = $lemma;
    $lemma =~ s/\ /&nbsp;/x; # keep reflexive verbs on one line together
    $url_lemma =~ s/\ /+/x;
    $wlink_string .=
      "<li><a href='$PDTVALLEX_URL$url_lemma' target='_blank' class='external'>"
      . "<span>$lemma</span>"
      . "<div class='arrow'>&gt;</div></a></li>";
  }
  if($wlink_string){
    return "<div class='pdtvallex-box'>"
           . "<a class='expander'>"
           . "<span>PDT-Vallex</span>"
           . "<div class='arrow'>&gt;</div>"
           . "</a>"
           . "<ul class='pdt-links' style='display: none;'>$wlink_string</ul>"
           . "</div>";
  }
  else {
    return "";
  }
}

# INPUT: HTML string like aktualizovat<sup class='scriptsize'>biasp</sup>
#                         moci/moct<sup class='scriptsize'>impf</sup>
#                         patřit<sub class='scriptsize'>II</sub><sup class='scriptsize'>impf</sup>
#                         dožít<sub class='scriptsize'>II</sub>/dožnout<sup class='scriptsize'>pf</sup>
# OUTPUT: hash biasp => ( (aktualizovat,'')          )
#              impf  => ( (moci,''), (moct,'')       )
#              impf  => ( (patřit,'II')              )
#              pf    => ( (dožít,'II'), (dožnout,'') )
sub get_coindexed_hash {
  my @headwords_html = @{shift()};
  my %coindexed;

  foreach my $headword_html (@headwords_html) {
    # $coindexed{$2} = $1 if $headword_html =~ /^ ([^<>]+)  <sup\ class='scriptsize'>  ([^<>]+)  <\/sup>  $/x;
    my $asp = $1 if $headword_html =~ s/<sup\ class='scriptsize'>  ([^<>]+)  <\/sup>  $//x;
    $headword_html =~ s/([^<])\//$1|/g;   # HTML slashes remain -- variant slashes changed into pipes
    my @lemma_variants = map { /^ ([^<>]+)  (?:<sub\ class='scriptsize'>([IV]+)<\/sub>)? $/x; [$1,$2]} split(/\|/, $headword_html);
    $coindexed{$asp} = \@lemma_variants;
  }

  return %coindexed;
}

# Returns HTML string with examples from VALEVAL: one line for each aspect, <br/> between lines
my %valeval_frames;
sub create_links_to_valeval {
  my $frame_num = shift;
  my $filename = shift;
  my $lexeme_id = shift;
  my $only_one_aspect = shift;
  my %coindexed_lemmas = @_;
  my @return;

  my %sortasp = (impf=>1, impf1=>2, impf2=>3, pf=>4, pf1=>5, pf2=>6, biasp=>7, iter=>8, iter1=>9, iter2=>10);
  my @aspects = sort {$sortasp{$a}<=>$sortasp{$b}} keys(%coindexed_lemmas);
  foreach my $asp (@aspects) {
    my @variants = @{$coindexed_lemmas{$asp}};
    my $var = (@variants > 1) ? 0 : undef();
    foreach my $lemma (@variants) {
      my $lemma_stem = $lemma->[0];
      my $homo       = $lemma->[1];
      $var++ if defined($var);
      my $lemma_full = $lemma_stem . ($homo ? "-$homo" : "");
      $lemma_full =~ s/ /_/g;
      my $excerpt = get_valeval_excerpt(\$lemma_full, $frame_num);
      next if $excerpt eq "0" or $excerpt eq "-1"; # no occurence of a frame or of a verb at all

      # The frame is used in VALEVAL
      my $line = (@aspects > 1 and !$only_one_aspect ? "&nbsp;<span class='scriptsize'>$asp:</span> " : "" ) .
        "<a href=\"generated/cnk/$lemma_full.html#$frame_num\" target=\"_blank\">" . $excerpt . "</a>";
      push(@return, $line);

      my $headword = $lemma_stem . ($homo ? "<sub class='scriptsize'>$homo</sub>" : "");
      push(@{$valeval_frames{$headword}}, "<a target='wordentry' href='../lexeme-entries/$filename#$frame_num'>$bullet $headword <span class='scriptsize'>$frame_num</span></a><br>");

      # Output lexeme's ID (it will be used to prune VALLEX XML and get smaller one only with those lexemes used in VALEVAL
      print(Pruned_IDs "$lexeme_id-$asp",
            $var ? "-".("", "A","B","C","D")[$var] : "",
            "\n");
    }
  }
  return join("<br/>", @return);
}

sub get_valeval_excerpt {
  my $lemma = shift;
  my $filename = create_correct_filename($lemma);
  return -1 if !$filename;             # "no occurence of this verb in CNK"
  my $frame_num = shift;
  open(CNK, "<encoding(utf-8)", $filename)
    or die("Can't open HTML $filename with VALEVAL examples.\n");
  my $nalezen_ramec = 0;
  my $nalezena_veta = 0;
  my $sentence = "empty";
  while (<CNK>) {
    if ($nalezena_veta) {
      # $sentence = <CNK>;
      $sentence = $_;
      last;
    }
    $nalezena_veta = 1 if $nalezen_ramec and /<td class="sentences" title="example sentence">/;
    $nalezen_ramec = 1 if /<a name="$frame_num"/;
  }
  return 0 if $sentence eq "empty"; # no occurence of this frame

  $sentence =~ s/<a href=["'][^"']+["']>//g; # ged rid of href start tag
  $sentence =~ s/^.*?( .{1,40}:\d+<\/a>)/&hellip;$1/ # trim beginning
    if $sentence =~ /^.*(.{60}:\d+<\/a>)/; # if too long
  $sentence =~ s/:\d+<\/a>(.{1,50} ).*/$1&hellip;/ # trim end
    if $sentence =~ /:\d+<\/a>(.{70}).*/; # if too long
  $sentence =~ s/:\d+<\/a>//g; # ged rid of href closing tag
  $sentence =~ s/<\/a>//g; # href of reflexive particles
  $sentence =~ s/^\s+//; # leading spaces
  $sentence =~ s/\s+$//; # trailing newline

  my $more = ""; # is there more than one example for this frame?
  while (<CNK>) {
    last if /<table class="examples">/; # next frame
    if (/<td class="sentences"/) { # next sentences for the same frame
      $more = "&nbsp;&nbsp;&nbsp;<span style=\"font-size:6pt\">(more&hellip;)</span>";
      last;
    }
  }
  close(CNK);

  return $sentence . $more;
}

sub create_correct_filename {
  my $lemma = shift;
  $$lemma =~ s/-III/-3/;
  $$lemma =~ s/-II/-2/;
  $$lemma =~ s/-I/-1/;
  if (!-f cnk_filename($$lemma)) {
    if (-f cnk_filename($$lemma."-1")) {
      $$lemma .= "-1";
      return cnk_filename($$lemma);
    } elsif ($$lemma =~ /-1/ or $$lemma =~ /_se-[23]/) {
      my $lemma_without = $$lemma;
      $lemma_without =~ s/-[123]//;
      if (-f cnk_filename($lemma_without)) {
        $$lemma = $lemma_without;
        return cnk_filename($$lemma);
      }
      return 0; # "no occurence of this verb in CNK"
    } elsif ($$lemma =~ /zachy/ and cnk_filename($$lemma."-2")) {
      $$lemma .= "-2";
      return cnk_filename($$lemma);
    } else {
      return 0; # "no occurence of this verb in CNK"
    }
  }
  return cnk_filename($$lemma);
}

sub cnk_filename {
  return "vallex-$version/data/html/generated/cnk/$_[0].html";
}

# -------------------------------- MAIN ----------------------

print STDERR "Copying non-generated (static) files ...\n";

system "mkdir -p $outputdir/";
# open IIN,"$xml2html_dir/index.html" or die "Can't open html index\n";
# open IOUT,">:encoding(utf-8)","$outputdir/index.html";
# s/#version#/$version/g, print IOUT while <IIN>;    # copy s jednou substituci
# close IIN;
# close IOUT;
system "cp -r $xml2html_dir/static/* $outputdir/"; # je potreba vyhnout se kopirovan .svn

print STDERR "Loading $xmlfile...\n";
my $parser = XML::DOM::Parser->new();
my $doc = $parser->parsefile($xmlfile);
my ($version_xml) = map {$_->getFirstChild->toString}
                        $doc->getElementsByTagName('version');
if ( $version ne $version_xml ) {
  if ( $version."test" ne $version_xml) {
    die "The given XML has different version ($version_xml) than requested VALLEX $version\n";
  } else {
    warn "The given XML has different version ($version_xml) than requested VALLEX $version\n";
  }
}

my %type_of_form;
my %htmlized_lexeme_entry;

print STDERR "Transforming lexemes into HTML and their classification according to sorting criteria ...\n";



foreach my $lexeme_node ($doc->getElementsByTagName('lexeme')) {
  my @refl = $lexeme_node->getElementsByTagName('commonrefl');
  # print "REFL: @refl\n";
  # exit;
  if (@refl == 0) {
    # print "Nonrefl\n";
    foreach my $mlemma_node ($lexeme_node->getElementsByTagName('mlemma')) {
      my $mlemma = $mlemma_node->getFirstChild->getNodeValue;
      my $homo_index = $mlemma_node->getAttribute('homograph');
      $irrefl_mlemma{$mlemma.$homo_index} = 1;
      # print "IRREFL: $mlemma.$homo_index\n";
    }
  }
}

my %autocomplete_lemma2filename;
my $pruned_IDs_file = $xmlfile;
$pruned_IDs_file =~ s/\/[^\/]+$/\/pruned_IDs.txt/;
$pruned_IDs_file =~ s/(?:\.xml)?$/_pruned_IDs.txt/ if $pruned_IDs_file eq $xmlfile;
open(Pruned_IDs, ">:encoding(utf-8)", $pruned_IDs_file)
  or die("Cannot open $pruned_IDs_file for writing.\n");

foreach my $lexeme_node ($doc->getElementsByTagName('lexeme')){
  my $filename = string_to_html_filename($lexeme_node->getAttribute('id'));
  my %global_aspect = lexeme_or_blu_to_lemmas($lexeme_node, 0); # global == for lexeme
  my $headwords_rf = lexeme_node_2_headwords(\%global_aspect, 0);

  foreach my $headword_string (map {split(/\//, $_)} map {$_ =~ s/<.+?>//g; $_} map {$_} @$headwords_rf) {
    $autocomplete_lemma2filename{$headword_string} = $filename;
  }

  my $headword_lemmas = join ", ",@$headwords_rf;

  my $headwords_rf_with_aspect = lexeme_node_2_headwords(\%global_aspect, 1);

  my $headword_lemmas_table= join ", ",@$headwords_rf_with_aspect; # doplnit vyrobeni tabulek

  my $link_to_word = "<a target='wordentry' href='../lexeme-entries/$filename'>$bullet $headword_lemmas</a><br>";

  my %coindexed_lemmas = get_coindexed_hash($headwords_rf_with_aspect);
  my $pdtvallex_word_links = pdtvallex_word_links($lexeme_node, %coindexed_lemmas);

  if ($headword_lemmas =~ /s[ie]/) {
    my $tantum = 1;
    mlemma: foreach my $mlemma_node ($lexeme_node->getElementsByTagName('mlemma')) {
      my $mlemma = $mlemma_node->getFirstChild->getNodeValue;
      my $homo_index = $mlemma_node->getAttribute('homograph');
      if ($irrefl_mlemma{$mlemma.$homo_index}) {
        $tantum = 0;
        last mlemma;
      }
    }
    if ($tantum) {
      lexeme_to_criteria($filename, $headword_lemmas, "others", "reflexive lexemes", "reflexive tantum verbs");
    }
    else {
      lexeme_to_criteria($filename, $headword_lemmas, "others", "reflexive lexemes", "derived reflexive lexemes");
    }

    # my $lexeme_cluster = $lexeme_node->getParentNode;
    # if (grep {$_ ne $lexeme_node} $lexeme_cluster->getElementsByTagName('lexeme')) {
    #  add_to_list('rfl','derived',$link_to_word);
    # }
    # else {
    #  add_to_list('rfl','tantum',$link_to_word);
    # }
  }

  lexeme_to_criteria($filename, $headword_lemmas, "all");

  my ($lexical_forms) = $lexeme_node->getElementsByTagName('lexical_forms');

  my $aspect_combination = join "+",sort grep {!/iter/} grep {$_} keys %global_aspect;
  lexeme_to_criteria($filename, $headword_lemmas, "others", "aspect", $aspect_combination);

  my @variants = $lexeme_node->getElementsByTagName('mlemma_variants');
  if (@variants > 0) {
    lexeme_to_criteria($filename, $headword_lemmas, "others", "variants");
  }



  $htmlized_lexeme_entry{$filename} .= "<div class='wordentry_header'>$pdtvallex_word_links<div class='headword'>$headword_lemmas_table</div></div>\n";
  # "<td>&nbsp;&nbsp;&nbsp;
  # <span class='headword_aspect'>   <a title='aspect' href='../aspect/index-$aspect.html' target='_parent'>$aspect.</a></span></table><br>\n";

  my $homographs = grep {$_->getAttribute('homograph') } $lexeme_node->getElementsByTagName('mlemma');
  if ($homographs) {
    lexeme_to_criteria($filename, $headword_lemmas, "others", "homographs");
  }

  my $complexity = $#{[$lexeme_node->getElementsByTagName('lu_cluster')]}+1;
  $complexity .= $complexity > 1 ? " LUs" : " LU"; # přidá jednotné/množné číslo LU
  lexeme_to_criteria($filename, $headword_lemmas, "others", 'complexity', $complexity);

  my $frame_index;
  my $htmlized_frame_entries;
  foreach my $blu_node (
      $lexeme_node->getElementsByTagName('blu'),
      $lexeme_node->getElementsByTagName('llu')) {
    $frame_index ++;

    # ------ html link na ramec do vyhledavacich tabulek

    my $link_to_frame = "<a target='wordentry' href='../lexeme-entries/$filename\#$frame_index'>$bullet $headword_lemmas <span class='scriptsize'>$frame_index</span></a><br>";


    my $limited_lex_forms = "";
    my @blu_coindexes;
    my %local_aspect;
    if (@{[$blu_node->getElementsByTagName('lexical_forms')]}>0) {  # omezeni forem, pro nez LU plati
      %local_aspect = lexeme_or_blu_to_lemmas($blu_node, 0);    # local == for LU
      my $blu_headwords_rf = lexeme_node_2_headwords(\%local_aspect, 1);
      $limited_lex_forms = "limit <span class='gloss'>".(join ", ",@$blu_headwords_rf)."</span><br>";
      @blu_coindexes = keys %local_aspect;
      # print(STDERR @blu_coindexes ? "lokalni: @blu_coindexes\n" : "lokalni prazdno\n");
    } else {
      %local_aspect = %global_aspect;
      @blu_coindexes = (keys %coindexed_lemmas);
      # print(STDERR @blu_coindexes ? "globalni: @blu_coindexes\n" : "globalni prazdno\n");
    }


    # ---------- load the frame attributes
    my %frame_attrs;
    # tady se musi pridat rozdeleni na dok: %???% /ned: %...%
    foreach my $attrname ('example','gloss','control','class','reflex','diat','alter','recipr','links','nouns', "instigator", "functor_mapping") {
      if ($blu_node->getElementsByTagName($attrname)->item(0)) {
        eval {
          foreach my $attr_node ($blu_node->getElementsByTagName($attrname)) {
            if ($attrname=~/^(control|class)$/) {
              unit_to_criteria($frame_index, $filename, $headword_lemmas, $attrname, trim($attr_node->getFirstChild->getNodeValue));
            }
            elsif ($attrname eq "alter") {
              my $type       = $attr_node->getAttribute('type');
              my $subtype    = $attr_node->getAttribute('subtype');
              my $primary    = $attr_node->getAttribute('primary');
              my $locatum    = $attr_node->getAttribute('locatumtype');
              $locatum = $locatum ? " ($locatum)" : "";
              my $primary_mark = "<span class='primary-mark'>" # FIXME moc velke, odstrkuje radku
                . ($primary ? "Ⅰ." : "Ⅱ.") . "</span>";
              my $LU_ref     = $attr_node->getElementsByTagName("flink")->[0]->getAttribute("frame_id");
              my $LU_ref_index = $1 if $LU_ref =~ /^blu-v-.+-(\d+)$/;
              if (!$LU_ref_index) {
                warn("*** Unrecognized ID of a counterpart of lexical alternation: $LU_ref\n");
                $LU_ref_index = "N";
              }

              unit_to_criteria($frame_index, $filename, $headword_lemmas, "alternation", "lexicalized", $type, $subtype.$locatum);
              my $url_type = string_to_html_filename($type);
              my $url_subtype = string_to_html_filename($subtype.$locatum);
              $frame_attrs{$type} .= "<table cellspacing='0' cellpadding='0'>"
                . "<tr><td><a href='#/filter/alternation/lexicalized/$url_type/$url_subtype'>$subtype$locatum</a>: $primary_mark&nbsp;"
                . "<td><a href='#/lexeme/$filename/$LU_ref_index' class='circle small'>$LU_ref_index</a> <a href='grammar.html#sec:sect:$type' class='rule-link'>rule</a>"
                . "</table>";
            }
            elsif ($attrname eq "diat") {
              my $type = $attr_node->getAttribute('type');
              if ($attr_node->getAttribute('value') eq "no") {
              # add_to_list("diat","$type NO",$link_to_frame);
              } elsif ($attr_node->getAttribute('value') eq "yes") {
                unit_to_criteria($frame_index, $filename, $headword_lemmas, "alternation", "grammaticalized", "diathesis", "$type");
                if ($frame_attrs{"diat"}) {$frame_attrs{"diat"} .="<br>"}
                my %subtypes;
                if ( my @coindexed = $attr_node->getElementsByTagName('coindexeddiat') ) {
                  foreach my $coindexed (@coindexed) {
                    if ( $coindexed->getAttribute('coindex') ) {
                      foreach my $example ( $coindexed->getElementsByTagName('diatexample') ) {
                        $subtypes{$example->getAttribute('subtype')} .= " &nbsp;<span class='scriptsize'>".$coindexed->getAttribute('coindex').":</span> ".$example->getFirstChild->getNodeValue;
                      }
                    } else {
                      foreach my $example ( $coindexed->getElementsByTagName('diatexample') ) {
                        $subtypes{$example->getAttribute('subtype')} .= $example->getFirstChild->getNodeValue;
                      }
                    }
                  }
                } elsif ( my @examples = $attr_node->getElementsByTagName('diatexample') ) {
                  foreach my $example (@examples) {
                    $subtypes{$example->getAttribute('subtype')} .= $example->getFirstChild->getNodeValue;
                  }
                }
                foreach my $subtype (sort keys %subtypes) {
                  $subtypes{$subtype} =~ s@(&nbsp;<span class='scriptsize'>(impf|pf|iter|biasp)[12]?:</span>)(.*)\g1@$1$3@gs;
                  $subtypes{$subtype} =~ s/\s+$//; # trailing whitespace removed -> semicolon can be appended
                }

                #   $type     -->    $subtype
                # poss-result --> (poss-result-conv poss-result-nconv poss-result-both)
                # deagent     --> (deagent deagent0)
                # passive     --> passive / or YES
                # recipient   --> recipient / or YES
                warn("ERROR: Possessive resultative without a subtype: $headword_lemmas LU$frame_index\n") if $type eq "poss-result" and !%subtypes;
                warn("ERROR: Deagentisation without a subtype: $headword_lemmas LU$frame_index\n") if $type eq "deagent" and !%subtypes;
                warn("ERROR: Subtype not allowed for $type diathesis: $headword_lemmas LU$frame_index\n") if $type ne "poss-result" and $type ne "deagent" and %subtypes and (keys(%subtypes) > 1 or !$subtypes{$type});
                # TODO predchozi chyby kontrolovat hlavne v prevodu do XML ci v testech dat
                if ($type eq "poss-result") {
                  foreach my $subtype (sort keys %subtypes) {
                    # my $adjusted_subtype = $subtype;
                    # $adjusted_subtype =~ s@-(n?conv|both)@<sub>\1</sub>@;  #TODO: chceme to jako spodní index, ale takhle to nemá správnou barvu
                    # $frame_attrs{"diat"} .= "<span class='attrname'>$adjusted_subtype:</span>".$subtypes{$subtype};
                    # add_to_list("diat","$adjusted_subtype",$link_to_frame); # FIXME postaru -> asi smazat a napsat znovu poradne
                    $frame_attrs{"diat"} .= "<a href='#/filter/alternation/grammaticalized/diathesis/$type/$subtype'>$subtype:</a>".$subtypes{$subtype};
                    unit_to_criteria($frame_index, $filename, $headword_lemmas, "alternation", "grammaticalized", "diathesis", $type, $subtype);
                  }
                } elsif (%subtypes) {
                  $frame_attrs{"diat"} .= "<a href='#/filter/alternation/grammaticalized/diathesis/$type'>$type:</a>";
                  # Only one possible subtype for "passive" and "recipient"
                  # and both possible subtypes for "deagent" should be merged
                  # TODO aspects are not merged properly (original "deagent impf pf deagent0 impf pf" -> "deagent impf pf impf pf")
                  $frame_attrs{"diat"} .= join("; ", map {$subtypes{$_}} sort keys(%subtypes));
                } else {
                  $frame_attrs{"diat"} .= "<a href='#/filter/alternation/grammaticalized/diathesis/$type'>$type</a> YES";
                }
              } else {
                print STDERR "Unexpected value of 'value' in a diathesis node.";
              }
            }
            elsif (my $type = $attr_node->getAttribute('type')) {
              if ($frame_attrs{$attrname}) {
                $frame_attrs{$attrname} .="<br>"
              }

              my $url_type = string_to_html_filename($type);
              if ( ($attrname=~/^(control|class|reflex|recipr)$/) ) {
                if ($attrname eq "reflex") {
                  unit_to_criteria($frame_index, $filename, $headword_lemmas, "alternation", "grammaticalized", "reflexivity", $type);
                  $frame_attrs{$attrname} .= "<a href='#/filter/alternation/grammaticalized/reflexivity/$url_type'>$type</a>: ";
                }
                elsif ($attrname eq "recipr") {
                  unit_to_criteria($frame_index, $filename, $headword_lemmas, "alternation", "grammaticalized", "reciprocity", $type);
                  $frame_attrs{$attrname} .= "<a href='#/filter/alternation/grammaticalized/reciprocity/$url_type'>$type</a>: ";
                }
                else { # control a class
                  # tohle else nikdy nenastane, nejspíš přežitek ze starších verzí, radši to tu ale nechávám
                  unit_to_criteria($frame_index, $filename, $headword_lemmas, $attrname, trim($type));
                  $frame_attrs{$attrname} .= "$type: ";
                }
              }
              else {
                $frame_attrs{$attrname} .= "$type: ";
              }
            }
            elsif ($attrname eq "links") {
              my $last_limit = "";
              foreach my $flink_node ($attr_node->getElementsByTagName("flink")) {
                my $coindex      = $flink_node->getAttribute('coindex');
                my $pdtvallex_id = $flink_node->getAttribute("frame_id");
                my $variant      = $flink_node->getAttribute("variant");
                my $weight       = $flink_node->getAttribute("weight");
                my $lemma        = $variant ? $variant : join("/", map {$_->[0]} @{$local_aspect{$coindex}}); # TODO kdyby se fakt pouzilo /, je to chyba
                $lemma =~ s/\ /+/xg;
                # Rounding (2 decimal places)
                $weight += 0.005; # plus half
                $weight =~ s/,(..).*$/.$1/; # trunk
                $weight += 0; # remove trailing zeros
                $weight =~ s/,/./; # point instead of comma

                my $limit = "";
                # kdyz je nutne rozlisovat, ktery z vidu platnych pro danou LU to je,
                # protoze neiterativnich je vic -- a nebo je toto dokonce iterativum
                if ((grep {$_ !~ /^iter/} @blu_coindexes) > 1 or $coindex =~ /^iter/) {
                  $limit = $coindex;
                }
                $limit = $limit ? "$limit, $variant" : $variant if $variant;
                if ($limit eq $last_limit) {
                  $limit = "";
                } else {
                  $last_limit = $limit;
                }
                $frame_attrs{'PDT-Vallex'} .=
                  ($limit ? " &nbsp;<span class='scriptsize'>$limit:</span> " : "")
                  . "<a href='$PDTVALLEX_URL$lemma#$pdtvallex_id' target='_blank'>$pdtvallex_id</a> "
                  . "<span style='font-size:xx-small'>($weight)</span>\n";
              }
            }

            my $lvc_index = $blu_node->getTagName eq "llu" ?
              ($attr_node->getAttribute('lvc_coindex') or 0) : undef();
            my @coindexed = $attr_node->getElementsByTagName('coindexed');
            if (@coindexed) {
              my $sep = "";
              foreach my $node (@coindexed) {
                my $node_value = "$sep<span class='scriptsize'>".$node->getAttribute('coindex').":</span> ".$node->getFirstChild->getNodeValue;
                if (defined($lvc_index)) {
                  $frame_attrs{$attrname}->[$lvc_index] .= $node_value;
                } else {
                  $frame_attrs{$attrname} .= $node_value;
                }
                $sep = "&nbsp";
              }
            }
            else {
              if (my $the_only_child = $attr_node->getFirstChild) {
                my $trimmed_value = trim($the_only_child->getNodeValue);
                if($attrname=~/^(control|class)$/){
                  my $url_value = string_to_html_filename($trimmed_value);
                  $frame_attrs{$attrname} .= "<a href='#/filter/$attrname/$url_value'>$trimmed_value</a>";
                }
                else {
                  my $node_value = $the_only_child->getNodeValue;
                  $node_value =~ s/^\s+//;
                  $node_value =~ s/\s+$//;
                  if ($attrname eq "nouns") {
                    $node_value = join(", ",
                      map {
                        if (/^blu-n-(.*-\d+)$/) {
                          my $noun = $1;
                          my $noun_lexeme = $noun;
                          $noun_lexeme =~ s/-\d+//;
                          "<a href='generated/lexeme-entries/lxm-n-"
                          . string_to_html_filename($noun_lexeme)
                          . ".html' target='_blank'>$noun</a>";
                        } elsif (/\|/) {
                          ";";
                        } else {
                          "<span class='one-verb-noun'>$_</span>";  # TODO no specification for this class, yet
                        }
                      }
                      grep { $_ }
                      split(/\s+/, $node_value));
                    $node_value =~ s/^;,//;     # lvc:  | noun noun       -> ;, noun, noun
                    $node_value =~ s/, ;,/;/;   # lvc: noun1 noun1 | noun -> noun1, noun1, ;, noun
                  } elsif ($attrname eq "functor_mapping") {
                    $node_value =~ s/-/&mdash;/g;
                    $node_value =~ s/([A-Z])v/$1<span style='vertical-align: sub; font-size: smaller'>verb<\/span>/g;
                    $node_value =~ s/([A-Z])n/$1<span style='vertical-align: sub; font-size: smaller'>noun<\/span>/g;
                  }
                  if (defined($lvc_index)) {
                    $frame_attrs{$attrname}->[$lvc_index] = $node_value;
                  } else {
                    $frame_attrs{$attrname} .= $node_value;
                  }
                }
              } else {
                $frame_attrs{$attrname} =~ s{:  $}{} if $frame_attrs{$attrname};
              }
            }
          }

          # $frame_attrs{$attrname}=$blu_node->getElementsByTagName($attrname)->item(0)->getFirstChild->getNodeValue
        };
        warn("nonfatal: ", $@) if $@;
      }
      elsif ($attrname eq "gloss" and $blu_node->getTagName eq "llu") {
        $frame_attrs{$attrname} .= "complex predicates";
      }
    }

    # VALEVAL info isn't in XML, so it has to be treated in different way
    # First, test whether this BLU is limited on one aspect only
    my @lexforms = $blu_node->getElementsByTagName('lexical_forms');
    my $only_one_apect = (@lexforms and (@{$lexforms[0]->getElementsByTagName('mlemma')})) == 1 ? "1" : "";
    my $lexeme_id = $lexeme_node->getAttribute('id');
    $frame_attrs{'usage in ČNK'} = create_links_to_valeval($frame_index, $filename, $lexeme_id, $only_one_apect, %coindexed_lemmas);


    my $special_LU_type = "";
    if ($blu_node->getParentNode->getAttribute('idiom') eq "1") {
      $special_LU_type = " (idiom) ";
    } elsif ($blu_node->getTagName eq "llu") {
      $special_LU_type = " (light verb) ";
    }

    my $id = $blu_node->getAttribute('id');

    # číslo rámce
    my $first_frameentry_row = "<a href='#/lexeme/$filename/$frame_index' title='$id' class='frame_index_link circle'>$frame_index</a>";
    my $lexical_unit_gloss = "$limited_lex_forms<span class='gloss'>$frame_attrs{gloss}</span>$special_LU_type";

    # ---------- vytvoreni tabulky s valencnim ramcem
    my ($frame_table_row1,$frame_table_row2);

    foreach my $frame_slot ($blu_node->getElementsByTagName('slot')) {
      my $functor=$frame_slot->getAttribute('functor');

      my $functor_class = "free";
      if ($functor =~ /^(ACT|ADDR|ORIG|PAT|EFF)$/) {
        $functor_class = "actants";
      }
      elsif ($functor =~ /^(DIFF|OBST|INTT)$/) {
        $functor_class = "quasi-valency";
      }
      unit_to_criteria($frame_index, $filename, $headword_lemmas, "functors", $functor_class, $functor);

      my $type=$frame_slot->getAttribute('type');

      # ------------ formy slotu
      my $forms=join ",",map {
        my $result;
        my $type=$_->getAttribute('type');
        $result=${formnode2formtxt($_)}[0];

        my $efftype=$type;
        if ($result=~/být\+/) {$efftype='byt'}
        $type_of_form{$result}=$efftype;

        my $filter_url;
        my $url_result = string_to_html_filename($result);
        if($type ne "phraseme_part"){ # filtrování phraseme_part, jinak ostatní forms ano
          if($type eq "cont"){ # cont nemá podkategorie
            unit_to_criteria($frame_index, $filename, $headword_lemmas, "forms", $result);
            $filter_url = "forms/$url_result";
          }
          else {
            unit_to_criteria($frame_index, $filename, $headword_lemmas, "forms", $type, $result);
            $filter_url = "forms/".string_to_html_filename($type)."/$url_result";
          }
        }
        else {
          $filter_url = "functors/free/DPHR";
        }
        my $form_comment = $long_form_type{$type};
        $form_comment .= " ($case_names{$result})"
          if ($type eq 'direct_case' and $efftype ne "byt");

        "<a class='forms' target='_top' title='morphemic form: $form_comment'
        href='#/filter/$filter_url'>$result</a>";
      } $frame_slot->getElementsByTagName('form');

      my $classtype = "";
      if ($type eq 'typ') {$classtype=' typ'}

      $frame_table_row1 .= "<td class='functor$classtype' rowspan='2'><a title='functor: $functor_comments{$functor}' href='#/filter/functors/$functor_class/".string_to_html_filename($functor)."'>$functor</a><td class='type' title='$type_of_compl{$type}'>$type";
      $frame_table_row2 .= "<td class='forms'>$forms";
    } # konec for frame slot
    my $frame_table_html="<table class='frame'><tr>$frame_table_row1<tr>$frame_table_row2</table>";

    # ---------- radek s prikladem, tridou a kontrolou, rcp, refl
    # my $example_line=  "<span class='attrname'>-example: </span>$frame_attrs{example}<br>\n\n";

    #### tato cast kodu se nikde nepouziva, promenn %attribute_line je mrtva
    # my %attribute_line;
    # foreach my $attr ('example','control','rfl','rcp','class','PDT-Vallex') {
    #   $attribute_line{$attr} = "<span class='attrname'>-$attr: </span> <a target='_top' href='../$attr/index-".string_to_html_filename($frame_attrs{$attr})."'>$frame_attrs{control}</a><br>\n\n"
    #     unless (!$frame_attrs{control});
    # }

    my %attrname_links = (
      'control' => 'guide.html#sec:sect:control',
      'reflex' => 'guide.html#sec:sect:reflexivity',
      'conv' => 'guide.html#sec:sect:alter',
      'split' => 'guide.html#sec:sect:alter',
      'multiple' => 'guide.html#sec:sect:alter',
      'recipr' => 'guide.html#sec:sect:reciprocity',
      'class' => 'guide.html#sec:sect:class',
      'diat' => 'guide.html#sec:sect:diat',
      'PDT-Vallex' => 'http://ufal.mff.cuni.cz/PDT-Vallex/',
      'cnk_usage' => '',  # TODO
      #'noun' => 'https://ufal.mff.cuni.cz/node/1124', #TODO
      #'map' => 'https://ufal.mff.cuni.cz/node/1124', #TODO
      #'instigator' => 'https://ufal.mff.cuni.cz/node/1124', #TODO
    );

    my $LVC = ($VERB_MODE and $frame_attrs{'nouns'}) ? 1 : 0;
    my @frame_attrs_filtered = grep {$frame_attrs{$_}} ('usage in ČNK','control','reflex','conv','split','multiple','recipr','class','diat','PDT-Vallex');
    my $visible_attributes =
      "<tr><td><td class='attrname frame'>frame<td colspan='2' class='attr frame'>".$frame_table_html. # frame má podobu tabulky
      ($LVC ?
        sort_LVC_attributes(%frame_attrs)
        :
        "<tr><td><td class='attrname example'>example<td class='attr example'>".$frame_attrs{example}
      );
    # ---------- vysledny htmlizovany zaznam ramce
    $htmlized_frame_entries .=
      "<table class='lexical_unit u$frame_index' data-id='".$frame_index."'>".
      "<td class='lexical_unit_index'>".$first_frameentry_row.
      "<td colspan='3' class='gloss_header'>".$lexical_unit_gloss. # hlavička se slovesy
      $visible_attributes;
    if ($VERB_MODE) {
      $htmlized_frame_entries .=
        "<td class='expander_cell'><a class='expander". (@frame_attrs_filtered or $LVC ? "" : " disabled") ."'><span>more</span><div class='arrow'>&gt;</div></a>". # more tlačítko
        # ostatní má class more: #diat je na konci kvuli prehlednosti vystupu
        # (join "", map ({"<tr class='more'><td><td class='attrname $_'>$_<td>$frame_attrs{$_} "}, @frame_attrs_filtered) ).
        (join "", map {
          my $attrname =
            $_ eq "usage in ČNK"     ? "cnk_usage" : $_;
          "<tr class='more'><td><td class='attrname $attrname'><a href='".$attrname_links{$attrname}."'>$_</a><td colspan='2' class='attr $attrname'>$frame_attrs{$_} "
          } (@frame_attrs_filtered) );
    }
    if ($LVC) {
      foreach my $lvc_index (0..$#{$frame_attrs{example}}) {
        my $suffix = $lvc_index > 0 ? $lvc_index : "";
        $htmlized_frame_entries .=
          LVC_line("example", $suffix, $frame_attrs{example}->[$lvc_index], "hidden");
      }
    }
    $htmlized_frame_entries .= "</table>";
  } # end of foreach blu

  $htmlized_lexeme_entry{$filename} .= "<div class='wordentry_content'>".$htmlized_frame_entries."</div>";

  # print "Lexeme:  ";
  # print join " , ",map {"$_ $reflex"} @{$headwords_rf};
  # print "($complexity)";

  # print "\n";
}
close(Pruned_IDs);

# ---------------------- storing word entries ----------------------------
print STDERR "Storing the html-ized lexeme entries...\n";

create_directory("generated/lexeme-entries/");

foreach my $filename (sort keys %htmlized_lexeme_entry) {
  my $longname="generated/lexeme-entries/$filename.html";
  # print STDERR "   $longname\n";
  my $x=$htmlized_lexeme_entry{$filename};
  create_html_file($longname, $x);
}


print STDERR "Generating JSON files for filtering\n";
# celkový strom filtrů = rozklikávací menu
# + vytvoření adresářové struktury

# print "\n", Dumper(\%filtertree), "\n";

# jména filtrů - nahradí id v menu
my %names = (
  "recipr" => "reciprocity",
  "reflex" => "reflexivity",
);

sub numberSort {
  return sort {
    my $numa = (split(" ", $a))[0];
    my $numb = (split(" ", $b))[0];

    return $numa <=> $numb;
  } @_;
}

sub fixedSort {
  my $fixedSubfilters_ref = shift;
  my %fixedSubfilters = %$fixedSubfilters_ref;
  my $subfilters_ref = shift;
  my @subfilters = @$subfilters_ref;
  my @fixed = ();
  my @sorted = ();
  foreach my $subfilter (@subfilters) {
    if(exists $fixedSubfilters{$subfilter}){
      @fixed[$fixedSubfilters{$subfilter}] = $subfilter;
    }
    else {
      push @sorted, $subfilter;
    }
  }
  @sorted = sort @sorted;
  return (@fixed, @sorted);
}

my %sortings = (
  "all" => sub {
    my $ref = shift;
    return fixedSort({
      "functors" => 0,
      "forms" => 1,
      "control" => 2,
      "alternation" => 3,
      "class" => 4,
      "others" => 5
    }, $ref);
  },
  "lexicalized" => sub {
    my $ref = shift;
    return fixedSort({
      "conv" => 0,
      "split" => 1,
      "multiple" => 2,
    }, $ref);
  },
  "actants" => sub {
    my $ref = shift;
    return fixedSort({
      "ACT" => 0,
      "ADDR" => 1,
      "PAT" => 2,
      "ORIG" => 3,
      "EFF" => 4,
    }, $ref);
  },
  "direct_case" => sub {
    my $ref = shift;
    return fixedSort({
      "1" => 0,
      "2" => 1,
      "3" => 2,
      "4" => 3,
      "5" => 4,
      "7" => 5,
    }, $ref);
  },
  "complexity" => sub {
    my $ref = shift;
    return numberSort(@$ref);
  },
  "forms" => sub {
    my $ref = shift;
    return fixedSort({
      "direct_case" => 0,
      "prepos_case" => 1,
      "infinitive" => 2,
      "subord_conj" => 3,
      "cont" => 4,
      "adjective" => 5,
    }, $ref);
  },
  "functors" => sub {
    my $ref = shift;
    return fixedSort({
      "actants" => 0,
      "free" => 1,
      "quasi-valency" => 2,
    }, $ref);
  },
  "aspect" => sub {
    my $ref = shift;
    return fixedSort({
      "impf" => 0,
      "pf" => 1,
      "impf+pf" => 2,
      "biasp" => 3,
      "impf1+impf2+pf" => 4,
      "impf1+impf2+pf1+pf2" => 5,
      "impf+pf1+pf2" => 6,
      "pf1+pf2" => 7,
    }, $ref);
  },
  "control" => sub {
    my $ref = shift;
    return fixedSort({
      "ACT" => 0,
      "ADDR" => 1,
      "ACT, ADDR" => 2,
      "PAT" => 3,
      "ACT, PAT" => 4,
      "ORIG" => 5,
      "ex" => 6,
      "ACT, ex" => 7,
      "ADDR, ex" => 8,
      "PAT, ex" => 9,
      "BEN, ex" => 10,
      "ORIG, ex" => 11,
    }, $ref);
  },
);

sub parseFiltertree {
  my $pathPrefix = shift;
  my $path = shift;
  my $tree = shift;
  my $subfilterId = shift;
  my @converted;

  if(keys %{${$tree}{"subfilters"}}){
    create_directory($pathPrefix.$path);
  }

  my @sortedSubfilters;
  if(exists $sortings{ $subfilterId }){
    my @subfilters = keys %{${$tree}{"subfilters"}};
    @sortedSubfilters = $sortings{ $subfilterId }(\@subfilters);
  }
  else {
    @sortedSubfilters = (sort keys %{${$tree}{"subfilters"}});
  }

  foreach my $key (@sortedSubfilters) {
    $key = "" if !$key;  # FIXME: nechapu, jak se tam JB dostane undef, ale takhle aspon nekrici
    my $filter_path = $path . string_to_html_filename($key);
    my $filter_filename = $filter_path . ".json";
    my %filter = (
      "id" => $filter_path,
      "name" => exists $names{$key} ? $names{$key} : $key,
      "url" => $filter_filename,
      "subfilters" => parseFiltertree($pathPrefix, $filter_path . "/", ${${$tree}{"subfilters"}}{$key}, $key)
    );
    # humus - v hlavním menu nechceme ALL záložku
    if($path . $key ne "all"){
      push @converted, \%filter;
    }

    my @lexemes_array = values %{${${${$tree}{"subfilters"}}{$key}}{"lexemes"}}; # proč perl :-(
    my @sorted = sort {
      if(${$a}[0] eq ${$b}[0]) {
        return ${$a}[1] <=> ${$b}[1];
      }
      return ${$a}[2] cmp ${$b}[2];
      } @lexemes_array;
    create_json_file($pathPrefix.$filter_filename, \@sorted);
  }

  return \@converted;
}

sub sort_LVC_attributes {
  my %attrs = @_;

  my $LVC_lines;
  foreach my $lvc_index (0..$#{$attrs{nouns}}) {
    next if !$attrs{nouns}->[$lvc_index];
    my $suffix = $lvc_index > 0 ? $lvc_index : "";
    $LVC_lines .=
      LVC_line("noun",       $suffix, $attrs{nouns}->[$lvc_index]) .
      LVC_line("map",        $suffix, $attrs{functor_mapping}->[$lvc_index]) .
      LVC_line("instigator", $suffix, $attrs{instigator}->[$lvc_index]);
  }
  return $LVC_lines;
}

sub LVC_line {
  my $labelname = shift;
  my $suffix    = shift;
  my $value     = shift;
  my $hidden    = shift;

  return "" if !$value;
  my $tr_attr = my $td_attr = "";
  if ($hidden) {
    $tr_attr = " class='more'";
    $td_attr = " colspan='2'";
  }
  return "<tr$tr_attr><td>"
    . "<td class='attrname $labelname'>$labelname$suffix"
    . "<td$td_attr class='attr $labelname'>$value";
}

my @parsedFiltertree = @{parseFiltertree("generated/", "",\%filtertree, "all")};

create_json_file("generated/filters.json", \@parsedFiltertree);



my $javascript_index_filename = "$outputdir/generated/lexeme-entries/index.js";
print STDERR "Generating autocomplete javascript file $javascript_index_filename\n";

# was: ["absolvovat",1],["brát",100]
# now: ["absolvovat","absol1"],[brát","brat-1"]
my $pairs = join ",", map {"[\"$_\",\"$autocomplete_lemma2filename{$_}\"\]"} sort keys %autocomplete_lemma2filename;
$pairs =~ s/\.html//g;



open O, ">:encoding(utf-8)", $javascript_index_filename;
print O "var vallex_lexeme_entries_index =\n\t[\n\t\t$pairs\n\t];\n";
close O;



print STDERR "Done.\n";
