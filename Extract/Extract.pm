package WWW::ContentRetrieval::Extract;

use 5.006;
use strict;
our $VERSION = '0.09';

use WWW::ContentRetrieval::CRL;
use WWW::ContentRetrieval::Utils;
use Data::Dumper;
use URI;

# ----------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------
sub new {
    my($pkg) = shift;
    my($arg) = ref($_[0]) ? shift : {@_};
    my $callpkg = $arg->{CALLPKG} ? $arg->{CALLPKG} : caller(0);
    my $desc;
    if($arg->{DESC}){
	$desc = transform_desc($callpkg, parse $arg->{DESC});
    }
    elsif($arg->{PARSED_DESC}){
	$desc = $arg->{PARSED_DESC};
    }

    my($obj) = {
	DESC        => $desc,
	TEXT        => $arg->{TEXT},
	THISURL     => $arg->{THISURL},
    };

bless $obj, $pkg
}

# ----------------------------------------------------------------------
# Extraction
# ----------------------------------------------------------------------
sub extract($) {
    my ($pkg)         = shift;
    my ($pagetextref) = \$pkg->{TEXT};
    my ($thisurl)     = $pkg->{THISURL};
    my ($desc)        = $pkg->{DESC};
    my ($case)        = $desc->{fetch}->{case};
    my ($next)        = $desc->{fetch}->{next};
    my (@retarr)      = qw//;

    foreach my $n (@{$case}){
	my $trigger = $n->[0];
	if($trigger &&
	   (
	    ( $trigger =~ /^m/o && eval "\$thisurl =~ $trigger" ) ||
	    ( $thisurl eq eval $trigger )
	   )){
	    die "Url's pattern error: $trigger $@\n" if $@;
	    if( ref($n->[1]) eq 'CODE' ){
		my $r = $n->[1]->($pagetextref, $thisurl);
		push @retarr, @$r;
	    }
	}
    }

return \@retarr;
}


1;
__END__

=head1 NAME

WWW::ContentRetrieval::Extract - Content Extractor

=head1 SYNOPSIS

  use WWW::ContentRetrieval::Extract;
 
  $e = WWW::ContentRetrieval::Extract->new(
      TEXT    => $t,                      # webpage text
      DESC    => $desc->{foo},            # site foo
      THISURL => 'http://bazz.buzz.org/', # url of TEXT
  );

  print Dumper $e->extract;

=head1 DESCRIPTION

L<WWW::ContentRetrieval::Extract> extracts data according to a given description file.

=head1 METHODS

=head2 new

  $e = new (
     TEXT    => page's content,
     THISURL => URL of the text,
     DESC    => data description
  );

See also L<WWW::ContentRetrieval> for how to write down description.

=head2 extract

  $e->extract() returns an array of hashes.

You may use L<Data::Dumper> to see it

=head1 SEE ALSO

L<WWW::ContentRetrieval>, L<WWW::ContentRetrieval::Spider>

=head1 COPYRIGHT

xern <xern@cpan.org>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.

=cut

