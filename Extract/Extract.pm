package WWW::ContentRetrieval::Extract;

use 5.006;
use strict;
our $VERSION = '0.082';

use WWW::ContentRetrieval::Utils;
use Data::Dumper;
use URI;
use YAML;

# ----------------------------------------------------------------------
# Constructor
# ----------------------------------------------------------------------
sub new {
    my($pkg, $arg) = @_;
    my $desc;
    my $callpkg = $arg->{CALLPKG} ? $arg->{CALLPKG} : caller(0);
    if($arg->{DESC}){
	$desc = Load($arg->{DESC});
	transform_desc($callpkg, $desc);
    }
    else {
	$desc = $arg->{PARSED_DESC};
    }

    my($obj) = {
	DESC        => $desc,             # configuraion
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
    my ($policy)   = $desc->{FETCH}->{POLICY};
    my ($next)     = $desc->{FETCH}->{NEXT};
    my (@retarr)   = qw//;
    my ($output, $c, $corrupt);
    my (%output);
    my ($type, $urlpatt, $nextpatt);
    my $top;


    ### parse the item settings ###
    foreach my $entry (qw/POLICY NEXT/){
	$top = -1;
	next if $desc->{$entry."_PARSED"};
	my $p = $desc->{FETCH}->{$entry};
	next unless $p;
	for(my $i=0; $i<@{$p}; $i+=2){
	    if( ref $p->[$i+1] eq 'SCALAR' ){
		my $itemref = $p->[$i+1];
		foreach my $line (
				  grep{$_}
				  grep{$_!~/^#/o} 
				  map{ s/^[\s\t]+//o; s/[\s\t]+$//o; $_ }
				  split( /\n+/o, $$itemref )
				  ){
		    if( $line =~ /(.+?)=(.+)/o ){
			my ($head, $patt) = ($1, $2);
			if( $head =~ /^replace\((.+?)\)/o ){
			    $desc->{ITEMS}->{$entry."_FILTER"}->[$top]->{$1} = $patt;
			}
			elsif( $head =~ /^reject\((.+?)\)/o ){
			    $desc->{ITEMS}->{$entry."_REJECT"}->[$top]->{$1} = $patt;
			}
			elsif( $head eq 'match' ){
			    $desc->{ITEMS}->{$entry."_MATCH"}->[++$top] = $patt;
			}
			else {
			    $desc->{ITEMS}->{$entry."_ASSIGN"}->[$top]->{$1} = $2 if $top >= 0;
			}
		    }
		    else {
			die "Your item setting might be wrong\n";
		    }
		}

	    }
	}
	$desc->{$entry."_PARSED"} = 1;
    }

    ### extract *next* links ###
    for(my $i=0; $next && $i<@{$next}; $i+=2){
	my $trigger = $next->[$i];
	if($trigger &&
	   (
	    ( $trigger =~ /^m/o && eval "\$thisurl =~ $trigger" ) ||
	    ( $thisurl eq eval $trigger )
	   )){
	    die "Url's pattern error: $trigger $@\n" if $@;
	    my $p = $next->[$i+1];
	    if( ref($p) eq 'CODE' ){
		my $r = $p->(\$pagetext, $thisurl);
		push @retarr, @$r;
	    }
	    elsif( ref($p) eq 'SCALAR' ){
		my $r = $pkg->match_get( 'NEXT', \$pagetext, $thisurl );
		push @retarr, @$r;
	    }
	    else{
		my $subtext = $pagetext;
		while($p){
		    my $c;
		    eval "\$subtext =~ $p;".'$c = $1; $subtext = $\'; ';
		    die "Url's pattern error: $p $@\n" if $@;
		    last unless $c;
		    undef $output;
		    $c = URI->new_abs($c, $thisurl)->as_string if($c !~ /^http:/o);
		    $output->{_DTLURL} = $c;
		    push @retarr, $output if $c;
		}
	    }
	}
    }

    my ($nodes, @linevect, $filter, $getmethod);

    for(my $i=0; $policy && $i<@{$policy}; $i+=2){
	my $trigger = $policy->[$i];
	if( $trigger &&
	   (
	    ( $trigger =~ /^m/o && eval "\$thisurl =~ $trigger" ) ||
	    ( $thisurl eq eval $trigger )
	   )){
	    die "Url's pattern error: $trigger $@\n" if $@;
	    if( ref($policy->[$i+1]) eq 'CODE' ){
		my $r = $policy->[$i+1]->(\$pagetext, $thisurl);
		push @retarr, @$r;
	    }
	    elsif( ref($policy->[$i+1]) eq 'SCALAR' ){
		my $r = $pkg->match_get( 'POLICY', \$pagetext, $thisurl );
		push @retarr, @$r;
	    }
	}
    }
return \@retarr;
}


sub match_get {
    my ( $pkg, $type, $textref, $pageurl ) = @_;
    my ( @ret, $item, $i );
    my $reject;
    my $desc = $pkg->{DESC};
    no strict;

    foreach my $patt ( @{$desc->{ITEMS}->{$type."_MATCH"}} ){
	$i = 0;
	my @item;
	my $subtext = $$textref;
	while( $subtext ){
	    eval '$subtext =~ '.$patt.';
                  $item[$_] = ${$_} for(1..9);
                  $subtext = $\'; ';
	    die "Matching error : $patt\n" if $@;
           L:
	    foreach my $idx (0..$#{$desc->{ITEMS}->{$type."_ASSIGN"}}){
		my $ass = $desc->{ITEMS}->{$type."_ASSIGN"}->[$idx];
		$item = undef;
                $reject = 0;
		foreach my $asskey ( keys %$ass ){
		    $item->{$asskey} = eval $ass->{$asskey};
                    next L unless $item->{$asskey};
		    if( $desc->{ITEMS}->{$type."_FILTER"}->[$idx]->{$asskey} ){
			eval '$item->{$asskey} =~ '.
			    $desc->{ITEMS}->{$type."_FILTER"}->[$idx]->{$asskey};
		    }
		    if( $desc->{ITEMS}->{$type."_REJECT"}->[$idx]->{$asskey} ){
                        $reject = 1 if( eval '$item->{$asskey} =~ '.
			    $desc->{ITEMS}->{$type."_REJECT"}->[$idx]->{$asskey} );
		    }
                    last if $reject == 1;
		}
                next if $reject;
		$ret[$i++] = $item;
	    }
	    $patt =~ /^m(.)(?:.+?)\1(.+)/o;
	    last if( $2 !~ /g/o );
	}
    }
    \@ret;
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

