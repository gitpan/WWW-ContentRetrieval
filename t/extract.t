use Test;
BEGIN { plan tests => 3 };
use WWW::ContentRetrieval;

ok(1);

$desc = {
    romance =>
    {
        NAME => "romance",
        NEXT => [ ],
        POLICY =>[
		  'romance\.language'
		  =>
		  [
		   [
		    "LINGUA" => "0.1.0.0.0",
		    [ 3 ], [ 1 ], [ 5 ],
		    sub{ local $_=shift; s/\s//g; $_ }
		   ],
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

ok( 'title', WWW::ContentRetrieval::Extract::lookup( WWW::ContentRetrieval::bldTree($s) , '0.0.0')->{tag} );

$e = WWW::ContentRetrieval::Extract->new({
             TEXT    => $s,
             DESC    => $desc->{romance},
             THISURL => 'http://romance.language.com/',
         });

print Dumper $e->extract;
ok('spanish', $e->extract->[3]->{LINGUA});


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
