use Test;
BEGIN { plan tests => 2 };
use WWW::ContentRetrieval;
use Data::Dumper;
ok(1);

sub callback {
    my ($textref, $thisurl) = @_;
    my @retarr;
    while( $$textref =~ m,<a href=(.+?)>(.+?)</a>,sgi){
	push @retarr, { URL => $1, NAME => $2 };
    }
    return \@retarr;
}


$robot = new WWW::ContentRetrieval(
<<'SETTING'

NAME: test

FETCH:
 METHOD: PLAIN
 QHANDL: http://www.google.com/
 POLICY:
  - m/./ => &callback

SETTING
);

#print Dumper $robot;

print STDERR "\n\nIt's trying to fetch web pages. Are you connected to the internet [Y]";
$_=<>;
$content = $robot->retrieve();
print Dumper $content;
/n/i ? ok(1) : ok( $content ? 1 : 0 , 1 );
