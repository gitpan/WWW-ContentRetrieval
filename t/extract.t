use Test;
BEGIN { plan tests => 3 };
use WWW::ContentRetrieval;

ok(1);

sub callback {
    my ($textref, $thisurl) = @_;
    my $ret;
    push @$ret, { 'LINGUA' => $1 } while( $$textref =~ /<tr> <td> (.+)/mg);
    $ret;
}

$items = <<'ITEMS';

match=(<tr>) (<td>) (.+?)\n
tr=$1
td=$2
language="romance language => ".$3

ITEMS

$desc = {
    romance =>
    {
        NAME => "romance",
        NEXT => [ ],
        POLICY =>[
		  'romance\.language' => \&callback,
		  'romance\.language' => \$items,
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
             THISURL => 'http://romance.language.moc/',
         });

print Dumper $e->extract;
ok('spanish', $e->extract->[3]->{LINGUA});
ok('romance language => latin', $e->extract->[6]->{language});

__DATA__
<html>
<head>
<title> Some Romance Languages </title>
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
