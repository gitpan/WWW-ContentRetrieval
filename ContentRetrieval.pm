package WWW::ContentRetrieval;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.05a';

require WWW::ContentRetrieval::Spider;
require WWW::ContentRetrieval::Extract;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(genDescTmpl);

use Data::Dumper;
use URI;
use Digest::MD5 qw/md5/;

# ----------------------------------------------------------------------
# Generating description template
# ----------------------------------------------------------------------
sub genDescTmpl(){
    <<TMPL;
{
  HANDL 
   =>
  {
        NAME => "",
        NEXT => [
            'http://foo/' => 'http://bar',
        ],
        POLICY =>[
		  'http://blah' => \&my_callback,
		  'http://bar'  => [
				    ["NODE1" => "0.0.0" ],
				    ],
        ],
        METHOD => 'POST',
        QHANDL => 'http://foo/query',
        PARAM => [
                  ['param1', ''],
                  ],
        KEY => 'query',
  },
};
TMPL
}


#                                                               << OO >>
# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------

sub new($$;$){
    my($pkg, $desc, $settings)= @_;
    my($justhaveit);
    bless{
	DESC       => $desc,
	SPOOL      => undef,       # URL queue
	BEEF       => undef,       # desired info
	JUSTHAVEIT => $justhaveit, # stores checksums of urls that are retrieved
	HTTP_PROXY => $settings->{HTTP_PROXY},
	TIMEOUT    => $settings->{TIMEOUT},
	DEBUG      => $settings->{DEBUG},
    },$pkg
}

# ----------------------------------------------------------------------
# Feeding urls
# ----------------------------------------------------------------------

sub feed{
    caller eq __PACKAGE__ or die qq/It's too private!\n/;
    my($pkg, $arg, $level)=@_;
    my($method, $url)= map { $arg->{$_} } qw/METHOD URL/;
    push @{$pkg->{SPOOL}}, [ $method, $url ];
}

# ----------------------------------------------------------------------
# Frontend
# ----------------------------------------------------------------------

sub retrieve{
    my($pkg) = shift;
    $pkg->{QUERY} = shift;
    $pkg->feed({
	       URL         => $pkg->{DESC}->{QHANDL},
	       METHOD      => $pkg->{DESC}->{METHOD},
	       PARAM       => $pkg->{DESC}->{PARAM},
	       QUERY       => [ $pkg->{DESC}->{KEY} , $pkg->{QUERY} ],
	       });

    do{	$pkg->_retrieve() } while @{$pkg->{SPOOL}};

    $pkg->{BEEF};
}

# ----------------------------------------------------------------------
# Backend
# ----------------------------------------------------------------------

sub _retrieve{
    caller eq __PACKAGE__ or die qq/It's too private!\n/;
    my($pkg)=shift;
    my($food) = shift @{$pkg->{SPOOL}};
    my($method, $url) = @$food;

    return unless $url;

    my $thisurl =
      WWW::ContentRetrieval::Spider::queryURL(
				      {
					  URL         => $url,
					  METHOD      => $method,
					  PARAM       => $pkg->{DESC}->{PARAM},
					  QUERY       => [
							  $pkg->{DESC}->{KEY},
							  $pkg->{QUERY}
							  ],
				      });
    my $cud = md5($thisurl);  # current url's digest ; using md5 trying to avoid duplication
    return if $pkg->{JUSTHAVEIT}->{$cud};
    $pkg->{JUSTHAVEIT}->{$cud} = 1;

    $url = URI->new_abs($url, $thisurl)->as_string unless $url =~ /^http:/;

    my ($content) = WWW::ContentRetrieval::Spider->new({
	URL         => $url,
	METHOD      => $method,
	PARAM       => $pkg->{DESC}->{PARAM},
	QUERY       => [ $pkg->{DESC}->{KEY} , $pkg->{QUERY} ],
	HTTP_PROXY  => $pkg->{HTTP_PROXY},
	TIMEOUT     => $pkg->{TIMEOUT},
    })->content;

    return unless $content;

    my $k = WWW::ContentRetrieval::Extract->new({
	TEXT    => $content,
	DESC    => $pkg->{DESC},
	THISURL => $thisurl,
    })->extract;

    return unless ref $k;
    foreach (@$k){
	print Dumper $_ if $pkg->{DEBUG};
	if(exists $_->{_DTLURL}){
	    if($_->{_DTLURL} !~ /^http:/){
		$_->{_DTLURL} = URI->new_abs($_->{_DTLURL}, $thisurl)->as_string;
	    }
	    push @{$pkg->{SPOOL}},['PLAIN', $_->{_DTLURL} ];
	}
        elsif(!exists $_->{_DTLURL} || (scalar keys %$_) > 1){
	    push @{$pkg->{BEEF}}, $_;
        }
    }
}


1;
__END__

=head1 NAME

WWW::ContentRetrieval - WWW robot plus text analyzer

=head1 SYNOPSIS

  use WWW::ContentRetrieval;
  use Data::Dumper;
  $robot = WWW::ContentRetrieval->new($desc,
				 {
				     TIMEOUT    => 3,
				     HTTP_PROXY => 'http://fooproxy:2345/',
				 });
  print Dumper $robot->retrieve( $query );


=head1 DESCRIPTION

L<WWW::ContentRetrieval> combines the power of a www robot and a text analyzer. It can fetch a series of web pages with some attributes in common, for example, a product catalogue. Users write down a description file and L<WWW::ContentRetrieval> can do fetching and extract desired data. This can be applied to do price comparison or meta search, for instance.

=head1 METHODS

=head2 new

  $s =
    new WWW::ContentRetrieval(
			      $desc,
			      {
				  TIMEOUT    => 3,
				  # default is 10 seconds.

				  HTTP_PROXY => 'http://fooproxy:2345/',

				  DEBUG      => 1,
				  # non-zero to print out debugging msgs
			      });

=head2 retrieve

  $s->retrieve($query) returns an anonymous array of retrieved data.

You may use Data::Dumper to see it. 

=head1 EXPORT

=head2 genDescTmpl

generates a description template.

Users can do it in a command line,

  perl -MWWW::ContentRetrieval -e'print genDescTmpl'

=head1 DESC FILE TUTORIAL

=head2 OVERVIEW

Currently, this module uses Perl's native anonymous array and hash for users to write down site descriptions. Let's see an example.

Suppose the product's query url of "foobar technology" be B<http://foo.bar/query.pl?encoding=UTF8&product=blahblahblah>, then the description is like the following: 
 $desc ={
    NAME => "foobar tech.",
    NEXT => [
     'query.pl' => 'detail.pl',
    ],
    POLICY => [
      'http://foo.bar/foobarproduct.pl'
        => \&extraction_callback,
    ],
    METHOD => 'GET',
    QHANDL => 'http://foo.bar/query.pl',
    PARAM => [
     ['encoding', 'UTF8'],
    ],
    KEY => 'product',
 };

=head2 NAME

The name of the site.

=head2 NEXT

NEXT is an anonymous array containing pairs of (this pattern => next pattern). If the current url matches /this pattern/, then text is searched for urls that match /next pattern/ and these urls will be queued for next retrieval.

=head2 POLICY

POLICY is an anonymous array containing pairs of (this pattern => callback). If the current url matches /this pattern/, then the corresponding callback will be invoked.

L<WWW::ContentRetrieval> passes two parameters to a callback function: a reference to page's content and page's url.

E.g.

  sub my_callback{
      my ($textref, $thisurl) = @_;
      while( $$textref =~ /blahblah/g ){
           do some blahblahs here.
      }
      return an array of hashes, with keys and extracted information.
  }

N.B.
Callback's return value should be like the following

 [
  {
   PRODUCT => "foobar",
   PRICE => 256,
  },
  {
   ...
   }
 ];

If users need WWW::ContentRetrieval to retrieve next page, e.g. dealing with several pages of search results, push an anonymous hash with only one entry: C<_DTLURL>

 {
  _DTLURL => next url,
 }

See also I<t/extract.t>, I<t/robot.t>

=head2 METHOD

Request method: GET, POST, or PLAIN.

=head2 QHANDL

C<Query Handler>, Url of the query script.

=head2 PARAM

Constant script parameters, excluding user's queries.

=head2 KEY

Key to user's query strings, e.g. product names

=head1 TO DO

=over 1

=item * A small language for site description

=back

=head1 SEE ALSO

L<WWW::ContentRetrieval::Spider>, L<WWW::ContentRetrieval::Extract>

=head1 COPYRIGHT

xern E<lt>xern@cpan.orgE<gt>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.


=cut
