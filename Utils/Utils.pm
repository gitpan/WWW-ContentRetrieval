package WWW::ContentRetrieval::Utils;

use 5.006;
use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(transform_desc);
our $VERSION = '0.01';
use Data::Dumper;

sub transform_desc {
    my ($callpkg, $desc) = @_;
    foreach my $entry (qw/POLICY NEXT/){
	foreach my $p (0..$#{$desc->{FETCH}->{$entry}}){
	    print $desc->{FETCH}->{$entry}->[$p];
	    if( $desc->{FETCH}->{$entry}->[$p] =~ /^(.+?)[\t\s]+=>[\t\s]+(.+)$/o ){
		my ( $patt, $strat ) = ($1, $2);
		die "Pattern error:($patt)\n" unless $patt =~/^[m\/]/o;
		if( $strat =~ /^\$(.+)/o ){
		    $strat = eval "\\\$${callpkg}::$1";
		}
		elsif( $strat =~ /^&(.+)/o ){
		    $strat = eval "\\&${callpkg}::$1";
		}
		die "Description error: $@\n" if $@;
		
		$desc->{FETCH}->{"_$entry"}->[2*$p] = $patt;
		$desc->{FETCH}->{"_$entry"}->[2*$p + 1] = $strat;
	    }
	    else{ die "Description error...\n" }
	}
	$desc->{FETCH}->{$entry} = $desc->{FETCH}->{"_$entry"};
    }
    print Dumper $desc;

}


1;
__END__
