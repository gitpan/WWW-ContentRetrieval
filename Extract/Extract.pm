package WWW::ContentRetrieval::Extract;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.02';

use HTML::Tree;
use Data::Dumper;
use URI;

# ----------------------------------------------------------------------
# WWW::ContentRetrieval::Extract::lookup(parsed_text, nodeID)
# ----------------------------------------------------------------------
sub lookup($$) {
    my ($t, $nid) = @_;
    my $r;
    $r->{tag}='';
    $r->{text}='';
    return $r unless $t && $nid;
    $r->{tag} = $1 if $t =~ /<(.+?)>\s+\@$nid\n/;
    $r->{text} = $1 if $t =~ /\@$nid\n\s+"(.+?)"\n/;
$r
}

# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------
sub new {
    my($pkg, $arg) = @_;
    my($obj) = {
	DESC        => $arg->{DESC},      # configuraion
	TEXT        => $arg->{TEXT},      # page's content
	THISURL     => $arg->{THISURL},
	DEBUG       => $arg->{DEBUG},
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
		$output->{DTLURL} = $c;
		push @retarr, $output;
	    }
	}
    }
    my ($nodes, @linevect, $filter);
    @linevect = split /\n/o, WWW::ContentRetrieval::bldTree($pagetext);

    for(my $i=0; $i<@{$desc->{POLICY}}; $i+=2){
	my $pageurl = $desc->{POLICY}->[$i];
	print "$thisurl, $pageurl\n";
	if( $pageurl && $thisurl =~ /$pageurl/ ){
	    ## if there is a callback function, ..
	    if( ref($desc->{POLICY}->[$i+1]) eq 'CODE' ){
		my $r = $desc->{POLICY}->[$i+1]->(\$pagetext, $pageurl);
		push @retarr, @$r;
	    }
	    else {
                ### Node expansion ###
		($nodes, $filter) = loadDESC($desc->{POLICY}->[$i+1]);
		foreach my $n (@$nodes){
		    undef $output;
		    foreach my $k (keys %$n){
			next unless $k;
			$c = undef;
			$c = get(\@linevect, $n->{$k});
			$output->{$k} = $c;
			if( ref $filter->{$k} eq 'CODE' ){
			    $output->{$k} = $filter->{$k}->( $output->{$k} );
			}
		    }
		    push @retarr, $output;
		}
	    }
	}
    }
return \@retarr;
}

# ----------------------------------------------------------------------
# Cartesian Expansion
# ----------------------------------------------------------------------
sub cart($$$$){
    caller eq __PACKAGE__ or die "It's too private!\n";
    my ($s, $i, $p, $e) = @_; # (starting, changing index, stepsize, ending)
    return unless @$i == @$p;
    my $c = 0;
    my (@r);
    push @r, join q/./, @$s;
  EXPANSION:
    while(1){
	last unless @$e;
        $s->[$i->[-1]] += $p->[-1];
        for(my $j = $#$i; $j>0; $j--){
            if($s->[$i->[$j]] == $e->[$j]){
                $s->[$i->[$j]] = 0;
                $s->[$i->[$j-1]] += $p->[$i->[$j-1]];
            }
        }
        push @r, join q/./, @$s;
	my $escape = 1;
	for(my $k = 0; $k<@$i; $k++){
	    undef $escape if($s->[$i->[$k]] != $e->[$k]);
	}
	last if $escape;
    }
\@r
}

# ----------------------------------------------------------------------
# Loading desc
# ----------------------------------------------------------------------
sub loadDESC($) {
    caller eq __PACKAGE__ or die "It's too private!\n";
    my($h) = shift;
    my($sidx, $sdif, $LBD, $UBD, $th, $ft);
    for my$C (@$h){
	unless( defined $C->[2] && defined $C->[3] && defined $C->[4] ){
	    $th->[0]->{$C->[0]} = $C->[1];
	    next;
	}
	$sidx = $C->[2], $sdif = $C->[3], $UBD = $C->[4];
	$LBD=[ split /\./o, $C->[1] ];

	my($IV)=cart($LBD, $sidx, $sdif, $UBD);
	my $cnt = 0;
	for( @$IV){
	    $th->[$cnt++]->{$C->[0]} = $_;
	    if( defined $C->[5]){
		$ft->{$C->[0]} = $C->[5];
	    }
	}
    }
($th, $ft)
}


# ----------------------------------------------------------------------
# Retrieving text at some node
# ----------------------------------------------------------------------
sub get($$;$){
    caller eq __PACKAGE__ or die "It's too private!\n";
    my $linevect = shift;
    my $node     = shift;
    my $cont;

    for my $i (0..$#$linevect){
        if($linevect->[$i] =~ /$node$/){
            my($j) = $i+1;
	    if($linevect->[$j] && 
		   $linevect->[$j++]=~/^[\s\t]+"(.*)"$/ ){
                $cont .= $1;
            }
	    last;
        }
    }

$cont
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

=head2 extract

  $e->extract returns an array of hashes. You may use Data::Dumper to see it

=head1 STANDALONES

=head2 WWW::ContentRetrieval::Extract::lookup( text, node_identifier )

WWW::ContentRetrieval::Extract::lookup( WWW::ContentRetrieval::bldTree($t), "0.0.0");

It looks up the given text for the some node identifier, and returns an anonymous hash with entries "tag" and "text".

=head1 SEE ALSO

L<WWW::ContentRetrieval>, L<WWW::ContentRetrieval::Spider>, L<HTML::TreeBuilder>

=head1 COPYRIGHT

xern <xern@cpan.org>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.

=cut

