use Test;
BEGIN{ plan tests => 4 }

use WWW::ContentRetrieval::Extract;
ok(1);
sub callback{
    my ($textref, $thisurl) = @_;
    my $ret;
    push @$ret, { 'LINGUA' => $1 } while( $$textref =~ /<tr> <td> (.+)/mg);
    $ret;
};


$items = <<'ITEMS';
match=m/(<tr>) (<td>) (.+?)\n/mg
tr=$item[1]
td=$item[2]
language="romance language => ".$item[3]
replace(language)=s/l/a/
ITEMS

    $next =<<'NEXT';
match=m,<a href="(.+?)">.+?</a>,m
_DTLURL="http://romance.language/".$1
NEXT

my $hashref = <<'SETTING';
NAME: romance languages
FETCH:
  URL : 'http://foo.bar/query.pl'
  METHOD: GET
  PARAM:
     encoding : UTF8
  KEY: product
  POLICY:
   - m/romance\.language/ => $items
   - m/romance\.language/ => &callback
  NEXT:
   - m/./ => m/<a href="(.+?)">.+<\/a>/
   - m/./ => $next
SETTING

use Data::Dumper;

$text =<<'TEXT';
<html>
<head>
<title> Some Romance Languages </title>
</head>
<body>
<a href="next.pl?asdf"> asdf </a>
<table>
<tr> <td> latin
<tr> <td> italian
<tr> <td> french
<tr> <td> spanish
<tr> <td> romanian
<tr> <td> portuguese
</table>
</body>
</html>
TEXT

$e = WWW::ContentRetrieval::Extract->new(
					 {
					     DESC => $hashref,
					     TEXT => $text,
					     THISURL => 'http://romance.language'
					 }
					 );

$r = $e->extract;
print Dumper $r;
ok(1) if $r->[0]->{_DTLURL} =~ /http/;
ok(1) if $r->[2]->{language} =~ /romance aanguage/;
ok(1) if $r->[13]->{LINGUA} eq 'portuguese';
