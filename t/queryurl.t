use Test;
BEGIN { plan tests => 2 };
use WWW::ContentRetrieval::Spider;
ok(1);

$url = queryURL
    (
     URL      => 'http://foobar.tech/',
     METHOD   => 'POST',
     PARAM    => { 'bee', 'buzz' },
     QUERY    => [ 'eez', 'zzub'],
     );

ok($url, "http://foobar.tech/?eez=zzub&bee=buzz");
