package WWW::ContentRetrieval::CRL;

use 5.006;
use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(parse);
our $VERSION = '0.02';
use File::Slurp;
use POSIX qw/tmpnam/;

my %dirset = map{$_=>1} qw(crl lrc name login logout fetch url jar param key method case policy callback merge);

my %arg2eat = qw(crl 1 lrc 0 name 1 login 0 logout 0 fetch 0 url 1 jar 1 param 2 key 1 method 1 case 2 policy 2 callback 2 merge 1);

sub refine($) {
    unless( exists $_[0]->{jar} ){
	foreach ( qw(login logout fetch) ){
	    $_[0]->{jar} = $_[0]->{$_}->{jar} if $_[0]->{$_}->{jar};
	}
    }
    # default method
    unless( exists $_[0]->{fetch}->{method} ){
	$_[0]->{fetch}->{method} = 'PLAIN';
    }
    warn "Site's name missing\n" unless $_[0]->{crl};
}

sub parse($) {
    my @lines = split /\n/, -f $_[0] ? read_file $_[0] : $_[0];
    my $ref;
    my $context;
    my $linenum = 0;

    foreach my $idx (0..$#lines){
	last if $context eq 'lrc';
	$linenum++;
	next unless $lines[$idx];
	if( $lines[$idx] =~ /^=(.+?)(?:[\s\t]+?(.+))?$/o ){
	    die "Null directive at line $linenum\n" unless $1;
	    die "Unknown directive at line $linenum\n" unless exists $dirset{lc $1};
	    my ($dir, $p1) = map{lc}($1, $2);
	    if( $dir eq 'crl'){
		$ref->{name} = $ref->{$dir} = $2;
	    }
	    elsif( $dir eq 'lrc' ){
		$ref->{$dir} = undef;
	    }
	    elsif( $dir eq 'key' ){
		push @{$ref->{$context}->{param}}, [ $p1, '' ];
		$ref->{$context}->{$dir} = $#{$ref->{$context}->{param}};
	    }
	    elsif( $dir eq 'merge' ){
		push @{$ref->{$context}->{$dir}}, 1;
	    }
	    elsif( $arg2eat{$dir} == 2 ){
		my ($text, $j);
		for $j ($idx+1..$#lines){
		    next unless $lines[$j];
		    last if $lines[$j] =~ /^=/o;
		    $text.=$lines[$j].$/;
		}
		chomp $text;
		$idx = $j;
		push @{$ref->{$context}->{$dir}}, [ $2 , $text ];
	    }
	    elsif($arg2eat{$dir} == 1){
		$ref->{$context}->{$dir} = $2;
	    }
	    else{
		$ref->{$dir} = {};
		$context = $dir;
	    }
	}
    }
    refine($ref);
    $ref;
}




1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WWW::ContentRetrieval::CRL - Content Retrieval Language

=head1 SYNOPSIS

  use WWW::ContentRetrieval::CRL;
  $desc = parse($text);

=head1 DESCRIPTION

This module exports C<parse> to process content retrieval language which is designed for users to write down site's description. 

=head2 parse

 $desc = parse($text);
 $desc = parse($filename);

A parser for retrieval language. It parses text in place or from a file.

=head1 SEE ALSO

L<WWW::ContentRetrieval>

=head1 COPYRIGHT

xern <xern@cpan.org>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.

=cut
