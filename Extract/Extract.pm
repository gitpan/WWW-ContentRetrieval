package WWW::ContentRetrieval::Extract;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.05';

use Data::Dumper;
use URI;

# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------
sub new {
    my($pkg, $arg) = @_;
    my($obj) = {
	DESC        => $arg->{DESC},      # configuraion
	TEXT        => $arg->{TEXT},      # page's content
	THISURL     => $arg->{THISURL},
    };
bless $obj, $pkg
}

# ----------------------------------------------------------------------
# Extraction
# ----------------------------------------------------------------------
sub extract($) {
    my ($pkg)      = shift;
    my ($pagetext) = $pkg->{TEXT};       # page's text
    my ($thisurl)  = $pkg->{THISURL};    # this url
    my ($desc)     = $pkg->{DESC};
    my (@retarr)   = qw//;
    my ($output, $c, $corrupt);
    my (%output);
    my ($type, $urlpatt, $nextpatt);

    ### extract links ###
    for(my $i=0; $i<@{$desc->{NEXT}}; $i+=2){
	my $trigger = $desc->{NEXT}->[$i];
	if($trigger && $thisurl =~ /$trigger/){
	    my $p = $desc->{NEXT}->[$i+1];
	    while($pagetext =~ /$p/g){
		next unless $1;
		undef $output;
		$c = $1;
		$c = URI->new_abs($c, $thisurl)->as_string if($c !~ /^http:/o);
		$output->{_DTLURL} = $c;
		push @retarr, $output if $c;
	    }
	}
    }

    my ($nodes, @linevect, $filter, $getmethod);

    for(my $i=0; $i<@{$desc->{POLICY}}; $i+=2){
	my $pageurl = $desc->{POLICY}->[$i];
	if( $pageurl && $thisurl =~ /$pageurl/ && ref($desc->{POLICY}->[$i+1]) eq 'CODE' ){
	    my $r = $desc->{POLICY}->[$i+1]->(\$pagetext, $pageurl);
	    push @retarr, @$r;
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
 
  $e = WWW::ContentRetrieval::Extract->new({
      TEXT    => $t,                      # webpage text
      DESC    => $desc->{foo},            # site foo
      THISURL => 'http://bazz.buzz.org/', # url of TEXT
  });

  print Dumper $e->extract;

=head1 DESCRIPTION

L<WWW::ContentRetrieval::Extract> extracts data according to a given description file.

=head1 METHODS

=head2 new

  $e = new ({
     TEXT    => page's content,
     THISURL => URL of the text,
     DESC    => data description
  });

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

