package WWW::ContentRetrieval;

use 5.006;
use strict;
our $VERSION = '0.09';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(gentmpl);


use WWW::ContentRetrieval::Spider;
use WWW::ContentRetrieval::Extract;
use WWW::ContentRetrieval::Utils;
use WWW::ContentRetrieval::CRL;

use Data::Dumper;
use URI;
use Digest::MD5 qw/md5/;

# ----------------------------------------------------------------------
# Generating description template
# ----------------------------------------------------------------------
sub gentmpl(){
    my $tmpl = <<'TMPL';
 =crl foobar

 =fetch

 =url http://foo.bar/

 =method PLAIN

 =case m/./

product

 =policy product

mainmatch=m,<a href=(["'])(.+?)\1>(.+?)</a>,sg
link=$2
name=$3
export=link name

 =policy nexturls

mainmatch=m,<a href=(.+?)>.+</a>
_DTLURL="http://foo.bar/".$1
export _DTLURL

 =callback c_a_llback

sub {
    my ($textref, $thisurl) = @_;
}

 =lrc

TMPL

    $tmpl =~ s/^ =(.+)/=$1/mog;
$tmpl;
}


# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------

sub new {
    my($pkg) = shift;
    my($arg);
    if(@_==1){	$arg->{DESC} = shift;    }
    else {	$arg = ref($_[0]) ? shift : {@_};    }
    my($callpkg) = caller(0);
    my($justhaveit, $desc);

    $desc = transform_desc($callpkg, parse $arg->{DESC});

    bless{
	CALLPKG    => $callpkg,
	DESC       => $desc,
	EXTR       => $desc,
	SPOOL      => undef,       # URL queue
	BEEF       => undef,       # desired info
	JUSTHAVEIT => $justhaveit, # stores checksums of urls that are retrieved
	HTTP_PROXY => $arg->{HTTP_PROXY},
	TIMEOUT    => $arg->{TIMEOUT},
	DEBUG      => $arg->{DEBUG},
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
    my $desc = $pkg->{DESC};
    my $fetch = $pkg->{DESC}->{fetch};
    $pkg->feed({
	       URL         => $fetch->{url},
	       METHOD      => $fetch->{method},
	       PARAM       => $fetch->{param},
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
    my($fetch) = $pkg->{DESC}->{fetch};

    return unless $url;


    if(ref($fetch->{param}) eq 'HASH'){
	foreach (keys %{$fetch->{param}}){
	    if($_ eq $fetch->{key}){
		$fetch->{param}->{$_} = $pkg->{QUERY};
	    }
	}
    }
    elsif(ref($fetch->{param}) eq 'ARRAY'){
      $fetch->{param}->[$fetch->{key}]->[1] = $pkg->{QUERY};
    }

    my $thisurl =
      WWW::ContentRetrieval::Spider::queryURL(
				      {
					  URL         => $url,
					  METHOD      => $method,
					  PARAM       => $fetch->{param},
				      });
    # current url's digest ; using md5 trying to avoid duplication
    my $cud = md5($thisurl);
    return if $pkg->{JUSTHAVEIT}->{$cud};
    $pkg->{JUSTHAVEIT}->{$cud} = 1;

    $url = URI->new_abs($url, $thisurl)->as_string unless $url =~ /^http:/;

    my ($content) = WWW::ContentRetrieval::Spider->new({
	URL         => $url,
	METHOD      => $method,
	PARAM       => $fetch->{PARAM},
	HTTP_PROXY  => $pkg->{HTTP_PROXY},
	TIMEOUT     => $pkg->{TIMEOUT},
    })->content;

    return unless $content;

    my $k = WWW::ContentRetrieval::Extract->new({
	CALLPKG      => $pkg->{CALLPKG},
	TEXT         => $content,
	PARSED_DESC  => $pkg->{EXTR},
	THISURL      => $thisurl,
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
  $robot = WWW::ContentRetrieval->new($desc);
  print Dumper $robot->retrieve( $query );


=head1 DESCRIPTION

L<WWW::ContentRetrieval> combines the power of a www robot and a text analyzer. It can fetch a series of web pages with some attributes in common. Users write down a description file and L<WWW::ContentRetrieval> can do fetching and extract desired data.

=head1 METHODS

=head2 new

  # with site's description only
  $s = new WWW::ContentRetrieval($desc);

  # or
  $s = new WWW::ContentRetrieval($desc_filename);


  # or with full argument list
  $s =
    new WWW::ContentRetrieval(
			      DESC       => $desc,
			      # site's description

			      TIMEOUT    => 3,
			      # default is 10 secs.

			      HTTP_PROXY => 'http://fooproxy:2345/',

			      );

=head2 retrieve

  $s->retrieve($query) returns an anonymous array of retrieved data.

You may use Data::Dumper to see it. 

=head1 EXPORT

=head2 gentmpl

generates a description template.

Users can do it in a command line,

  perl -MWWW::ContentRetrieval -e'print gentmpl'

=head1 DESC FILE TUTORIAL

=head2 OVERVIEW

L<WWW::ContentRetrieval> uses a pod-like language call B<CRL>, I<content retrieval language>, for users to define a site's description. See L<WWW::ContentRetrieval::CRL> for detail.

Now, suppose the product's query url of "foobar technology" be I<http://foo.bar/query.pl?encoding=UTF8&product=blahblahblah>, then the description is like the following.

  $desc = <<'...';

  =crl foobar tech.

  =fetch

  =url http://foo.bar/

  =method PLAIN

  =param encoding

  utf-8

  =key product

  =case m/./

  product

  =policy product

  mainmatch=m,<a href=(["'])(.+?)\1>(.+?)</a>,sg
  link="http://foo.bar/".$2
  name=$3
  export=link name

  =policy nexturls

  blah blah looking for urls

  =callback

  sub {
      my ($textref, $thisurl) = @_;
      blah blah ...
      write your filter code here
  }

  =LRC

  ...

=head2 crl

Beginning of site's description. It is followed by the site's name.

=head2 fetch

Beginning of fetching block.

=head2 url

The web page you are dealing with.

=head2 method

PLAIN | GET | POST

=head2 param

Web script's parameters. It is followed by key and value.

=head2 key

Variable part of paramters. Parameter passed to method C<retrieve> will be joined with the key.

Both param and key are I<order-sensitive>, that is, the order they appears in description file will determine the order in the request url.

=head2 case

It takes two arguments; one is a regular expression, another is the name of a page filter.

If page's url matches the pattern, the corresponding filter will be invoked.

See I<policy> and I<callback> parts for detail.


=head2 policy and callback

B<Policy> and B<callback> are the guts of this module and they help to extract data from pages.

=over 2

=item * policy

Policy takes two parameters: a regular expression and a lines of data manipulation sublanguage. Here is an example.

  mainmatch=m,<a href=(["'])(.+?)\1>(.+?)</a>,sg
  link="http://foobar:/$2"
  name=$3
  match(link)=m,^http://(.+?),
  site=$1
  replace(link)=s/http/ptth/
  reject(name)=m/^bb/
  export=link name site

In the first place, use C<mainmatch> to look for desired pattern. Then, users can assign value to self-defined variables and go deeper to capture values using C<match(variable)>. C<Replace> can modify extracted text, and C<reject> discards values matching some pattern. Finally, users have to specify which variables to export using C<export>.


=item * callback

If users have to write callback functions for more complex cases, here is the guideline:

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

If users need to retrieve next page, e.g. dealing with several pages of search results, push an anonymous hash with only one entry: C<_DTLURL>

 {
  _DTLURL => next url,
 }

See also I<t/extract.t>, I<t/robot.t>


=head1 SEE ALSO

L<WWW::ContentRetrieval::Spider>, L<WWW::ContentRetrieval::Extract>, L<WWW::ContentRetrieval::CRL>

=head1 CAVEATS

It is still alpha, and the interface is subject to change. Source code is distributed without warranty.

B<Use it with your own cautions.>

=head1 TO DO

Login and logout simulation

=head1 COPYRIGHT

xern E<lt>xern@cpan.orgE<gt>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.


=cut
