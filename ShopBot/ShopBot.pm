package WWW::ShopBot;
use 5.006;
use strict;
our $VERSION = '0.01';
use WWW::ContentRetrieval;

sub new {
    my $pkg = shift;
    my $arg = ref($_[0]) ? shift : {@_};
    bless {
	merchants => $arg->{merchants},
	pick      => $arg->{pick} || [ 'product', 'price' ],
	sortby    => $arg->{sortby} || 'price',
	proxy     => $arg->{proxy},
    }, $pkg;
}

sub sift {
    caller eq __PACKAGE__ or die "\n";
    my($result, $criteria, $merchant) = @_;

    foreach my $r (@{$result}){
	unless( $r->{product} && $r->{price} ){
	    $r = {};
	    next;
	}

	# lower bound
	if(defined $criteria->{price}->[0]){
	    if($r->{price} < $criteria->{price}->[0]){
		$r = {};
		next;
	    }
	}

	# upper bound
	if(defined $criteria->{price}->[0]){
	    if($r->{price} > $criteria->{price}->[1]){
		$r = {};
		next;
	    }
	}

	# other filters
	foreach my $f (keys %{$criteria}){
	    next if $f =~ /product/io;
	    next if $f =~ /price/io;
	    unless( $criteria->{$f}->($r->{$f}) ){
		$r = {};
		next;
	    }
	}
    }
}

sub query {
    my $pkg = shift;
    my $criteria = ref($_[0]) ? $_[0] : {@_};
    my @pool;
    foreach my $merchant (@{$pkg->{merchants}}){
	my $bot = new WWW::ContentRetrieval(DESC => $merchant,HTTP_PROXY => $pkg->{proxy});
	my $result = $bot->query($criteria->{product});
	sift($result, $criteria, $merchant);
	push @pool, grep { scalar %$_ } @$result;
    }
    return sort { $a->{$pkg->{sortby}} <=> $b->{$pkg->{sortby}} } @pool;
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

WWW::ShopBot - Price comparison agent

=head1 SYNOPSIS

  use WWW::ShopBot;
  $bot = new WWW::ShopBot( merchants => \@merchants );
  $bot->query($product);

=head1 DESCRIPTION

This module is a shopping agent which can fetch products' data and sort them by the price.

=head2 Set up a bot

  $bot = new WWW::ShopBot(
    # Specify merchants' descriptions
    # See also WWW::ContentRetrieval
    merchants => \@merchants,
    
    # Or give it a glob reference
    merchants => [ glob("foo/merchant.*>") ],
    
    # Recognized entries in an item's data
    # 'product' and 'price' are the default.
    pick      => [ 'product', 'price', 'desc' ],
    
    # You can use your own sorting function instead of the default one.
    # Sorting by 'price' is the default.
    sortfunc    => \&sort_by_product,

    proxy => 'http://foo.bar:1234/,
    );


=head2 Look for product

Query will be sent to the given hosts.

  $result = $bot->query('some product');

Or more specifically, you can do this.

  $result = $bot->query(
			product => 'some product',

			# Choose items whose prices are between
			# an interval
			price => [ $lower_bound, $upper_bound ],

			# You can use a self-defined filter to
			# decide whether to take this item or not.
			desc => \&my_desc_filter,
			);



=head1 SEE ALSO

L<WWW::ContenetRetrieval>

=head1 COPYRIGHT

xern E<lt>xern@cpan.orgE<gt>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.

=cut
