use Test;
BEGIN { plan tests => 2 };
ok(1);

print STDERR "\n\nIt's going to fetch 'google.com'. OK? [Y/n] ";
$a = <>;

if($a =~ /n/io){
    ok(1);
}
else{
    use WWW::ContentRetrieval;
    $e = WWW::ContentRetrieval->new(DESC => 't/robot.desc');
    use Data::Dumper;
    print Dumper $e->retrieve();
    ok($e->retrieve()?1:0, 1);
}
