use Test;
BEGIN { plan tests => 2 };
use WWW::ContentRetrieval;

ok(1);

$desc = {
    romance =>
    {
        NAME => "romance",
        NEXT => [ ],
        POLICY =>[
		  'romance\.language' =>
		  [
		   [ "TABLE" => '0.1.0!', ],
		   ],
		  ],
        METHOD => 'PLAIN',
    },

};

{
    local $/;
    $s = <DATA>;
}

use Data::Dumper;

$e = WWW::ContentRetrieval::Extract->new({
             TEXT    => $s,
             DESC    => $desc->{romance},
             THISURL => 'http://romance.language.com/',
         });

print Dumper $e->extract;
ok($e->extract->[0]->{TABLE}, ' latin  italian  french  spanish  romanian  portuguese ');


__DATA__
<html>
<head>
<title> Romance Languages </title>
</head>
<body>
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
