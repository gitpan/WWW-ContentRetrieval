use Test;
BEGIN { plan tests => 2 };
use WWW::ContentRetrieval;

ok(1);

sub callback {
    my ($textref, $thisurl) = @_;
    my $ret;
    push @$ret, { 'LINGUA' => $1 } while( $$textref =~ /<tr> <td> (.+)/mg);
    $ret;
}

$desc = {
    romance =>
    {
        NAME => "romance",
        NEXT => [ ],
        POLICY =>[ 'romance\.language' => \&callback ],
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
