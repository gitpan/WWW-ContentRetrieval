use Test;
BEGIN { plan tests => 2 };
use WWW::ContentRetrieval;
ok(1);

sub callback {
    my ($textref, $thisurl) = @_;
    my @retarr;
    while( $$textref =~ m,<a href=(.+?)>(.+?)</a>,sgi){
	push @retarr, { URL => $1, NAME => $2 };
    }
    return \@retarr;
}


$robot = new WWW::ContentRetrieval({
    NAME => "test",
    NEXT => [ ],
    POLICY =>
	[
	 '.' => \&callback,
	 ],
    METHOD => 'PLAIN',
    QHANDL => 'http://google.com/',
   },
);


print STDERR "\rIt's trying to fetch web pages. Are you connected to the internet [Y]";
$_=<>;
/n/i ? ok(0) : ok( $robot->retrieve() ? 1 : 0 , 1 );
