use Test;
BEGIN { plan tests => 2 };
ok(1);

$a = 'n';
eval{
    local $SIG{ALRM} = sub { die "\n" };
    alarm 5;
    print STDERR "\n\nIt's going to fetch 'google.com'. OK? [Y/n] ";
    $a = <>;
    alarm 0;
};

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
