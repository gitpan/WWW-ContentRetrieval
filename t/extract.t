use Test;
BEGIN{ plan tests => 4 }
use WWW::ContentRetrieval::Extract;
use Data::Dumper;
ok(1);

$desc =<<'DESC';
=crl several romance languages

=fetch

=case m/./

rl

=policy rl

mainmatch=m/<tr> <td> (.+)/mg
language="is $1"
match(language)=/.+(.)/
lastchar=$1
replace(language)=s/sp/ps/
reject(language)=m/latin/
export=language lastchar

=lrc

DESC

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

$e =
  WWW::ContentRetrieval::Extract->new(DESC => $desc, TEXT => $text,
				      THISURL => 'http://romance.language');

$r = $e->extract;
#print Dumper $r;
ok($r->[0]->{language}, 'is italian');
ok($r->[2]->{language}, 'is psanish');
ok($r->[4]->{lastchar}, 'e');
