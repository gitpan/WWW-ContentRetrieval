use Test;
BEGIN { plan tests => 2 };
use WWW::ContentRetrieval;
ok(1);

for(qw/google.com/){
    $s = new WWW::ContentRetrieval::Spider({
	URL         => "http://$_",
	METHOD      => 'PLAIN',
	TIMEOUT     => 30,
    });
    $text = $s->content;
}

ok( ($text ? 1 : 0), 1);
