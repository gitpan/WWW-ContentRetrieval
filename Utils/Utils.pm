package WWW::ContentRetrieval::Utils;

use 5.006;
use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(transform_desc);
our $VERSION = '0.01';
use Data::Dumper;
use IO::Scalar;
use Clone qw(clone);


sub collect {
    my($idx, $linesref) = @_;
    my @tmparr;
    foreach my $j ($idx+1..$idx+9){
	last unless $linesref->[$j];
	if($linesref->[$j] =~ /^(?:match|reject|replace|export)/o ){
	    last;
	}
	else{
	    $linesref->[$j] =~ /^(.+?)=(.+)$/;
	    push @tmparr, [ $1, $2 ];
	}
    }
    @tmparr;
}

sub translate {
    my $lines = clone(shift);
    my @lines = grep {$_!~/^#/o} map{ s/^[\s\t]+//o; s/[\s\t]+$//o; $_} split(/\n/o, $lines);
    my $subcontent;
    my $SH = new IO::Scalar \$subcontent;
    my $deftopic = '$$textref';
    my ($topic) = $deftopic;
    my $export_ok = 0;

    print $SH
	$/, 'sub {',$/,'my($textref, $thisurl) = @_;', $/, 'my (@pool, $reth);',$/;

    foreach my $idx (0..$#lines){
	my $line = $lines[$idx];
	$line =~ /^(.+?)(?:\((.+?)\))?[\s\t]*=[\s\t]*(.+)$/;
	my ($act, $obj, $plan) = ($1, $2, $3);
	if   ($act eq 'mainmatch' ){
	    $topic = $deftopic;
	    print $SH "\n##  mainmatch \n";
	    print $SH ($plan=~ m,^m(.).+\1(.*g.*)$,o?'while' : 'if'),
		'('.$topic.' =~ '.$plan.'){
                    undef $reth;', $/;
	    foreach (collect($idx, \@lines) ){
		print $SH '$reth->{'.$_->[0].'} = '.$_->[1].';',$/;
	    }
            print $SH
                 '   push @pool, $reth;
                 }', $/;
	}
	elsif($act eq 'match' ){
	    print $SH "\n##  match \n";

	    print $SH
		'for my $reth (@pool){ 
                   if($reth->{'.$obj.'} =~ '.$plan.'){', $/;
	    foreach (collect($idx, \@lines) ){
		print $SH '$reth->{'.$_->[0].'} = '.$_->[1].';',$/;
	    }

	    print $SH
		'
                   }
                 }', $/;
	}
	elsif($act eq 'replace' && $obj ){
	    print $SH "\n##  replace \n";

	    print $SH
		'for my $h (@pool){
                    $h->{'.$obj.'} =~ '.$plan.';', $/;

	    foreach (collect($idx, \@lines) ){
		print $SH '$reth->{'.$_->[0].'} = '.$_->[1].';',$/;
	    }
	    print $SH '
                 }', $/;
	}
	elsif($act eq 'reject' && $obj){
	    print $SH "\n##  reject \n";

	    print $SH
		'for my $h (@pool){
                    if($h->{'.$obj.'} =~ '.$plan.'){
                       $h={};
                    }
                 }', $/;
	}
	elsif($act eq 'export'){
	    print $SH "\n##  export \n";
	    print $SH
		'my %tmph = map{$_,1} qw(',
		map({"$_ "} grep {$_} split /\s+/, $plan),
		');
                 foreach my $reth (@pool){
                   foreach (keys %$reth){
                    delete $reth->{$_} unless $tmph{$_};
                   }
                 }',$/;
	    $export_ok = 1;
	}
	else{
	}
    }
    print $SH '@pool = ();',$/ unless $export_ok;
    print $SH 'return [ grep{ scalar %$_ } @pool ];', $/, '}', $/;
#    print $subcontent;
    my $sub =  eval $subcontent;
    die "POLICY ERROR: $@\n" if $@;
    return $sub;
}

sub transform_desc {
    my ($callpkg, $desc) = @_;
    my $assigned;

    foreach my $p (@{$desc->{fetch}->{policy}}){ translate(\$p->[1]) }

    foreach my $entry (qw/case/){
	foreach my $p (0..$#{$desc->{fetch}->{$entry}}){
	    my ($patt, $strat) = @{$desc->{fetch}->{$entry}->[$p]};

	    die "Pattern error:($patt)\n" unless $patt =~/^[qm]/o;
	    $assigned = 0;

	    if( $strat =~ /^\$(.+)/o ){
		$strat = translate "\\\$${callpkg}::$1";
		die "Description error: $@\n" if $@;
		$assigned = 1;
	    }
	    elsif( $strat =~ /^&(.+)/o ){
		$strat = eval "\\&${callpkg}::$1";
		die "Description error: $@\n" if $@;
		$assigned = 1;
	    }
	    elsif( $strat ){
		for my $type (qw(policy callback)){
		    for my $e (@{$desc->{fetch}->{$type}}){
			if($e->[0] eq $strat){
			    $strat = $type eq 'callback' ? eval $e->[1] : translate $e->[1];
			    die "$type error: ${$e}[0]\n" if $@;
			    $assigned = 1;
			}
		    }
		}
	    }
	    else {
		die "Where is your strategy?\n";
	    }

	    @{$desc->{fetch}->{"$entry"}->[$p]} = ($patt, $strat);
	}
    }
    $desc;
}


1;
__END__
