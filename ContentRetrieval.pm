package WWW::ContentRetrieval;

use 5.006;
use strict;
our $VERSION = '0.08';

use WWW::ContentRetrieval::Spider;
use WWW::ContentRetrieval::Extract;
use WWW::ContentRetrieval::Utils;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(genDescTmpl);

use Data::Dumper;
use URI;
use Digest::MD5 qw/md5/;
use YAML;

# ----------------------------------------------------------------------
# Generating description template
# ----------------------------------------------------------------------
sub genDescTmpl(){
    <<'TMPL';

NAME: site's name

FETCH:
 URL : 'http://foo.bar/query.pl'
 METHOD: GET
 PARAM:
   encoding : UTF8
 KEY: product
 POLICY:
  - m/foo\.bar/ => $items
  - m/foo\.bar/ => &callback
 NEXT:
  - m/./ => m/<a href="(.+?)">.+<\/a>/
  - m/./ => $next

TMPL
}


#                                                               << OO >>
# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------

sub new($$;$){
    my($pkg, $desc, $settings)= @_;
    my($callpkg) = caller(0);
    my($justhaveit);
    $desc = Load($desc);
    transform_desc($callpkg, $desc);
    print Dumper $desc;
    bless{
	CALLPKG    => $callpkg,
	DESC       => $desc->{FETCH},
	EXTR       => $desc,
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

L<WWW::ContentRetrieval> uses L<YAML> for users to define a site's description. L<YAML> is a portable, editable, readable, and extensible language. It can be an alternative for L<Data::Dumper>, and it is designed to define a data structure in a friendly way. Thus, L<YAML> is adopted.

Now, suppose the product's query url of "foobar technology" be B<http://foo.bar/query.pl?encoding=UTF8&product=blahblahblah>, then the description is like the following: 

 # callback function
 sub callback {
     my ($textref, $thisurl) = @_;
     blah blah
 }

 # a small processing language
 $items = <<'ITEMS';
  match=<a href="(.+?)">(.+)</a>
  site=$1
  url=$2
  replace(url)=s/http/ptth/

  match=<img src="(.+?)">
  photo="http://foo.bar/".$1
 ITEMS

 # site's description
 $desc = <<'...';
 NAME: site's name

 FETCH:
   URL : 'http://foo.bar/query.pl'
   METHOD: GET
   PARAM:
    encoding : UTF8
   KEY: product
   POLICY:
    - m/foo\.bar/ => $items
    - m/foo\.bar/ => &callback
   NEXT:
    - m/./ => m/<a href="(.+?)">.+<\/a>/
    - m/./ => $next
 ...

=head2 NAME

Name of the site.

=head2 POLICY

POLICY stores information for a certain page's extraction. It is composed of pairs of (this url's pattern => callback function) or (this url's pattern => retrieval settings). If the current url matches /this pattern/, then this modules will invoke the corresponding callback or extract data according to the retrieval settings given by users.

In simple cases, users only need to write down the retrieval settings instead of a callback function. Retrieval settings contains lines of instructions in a /key=value/ format. Here's an example.

 # use a leading # for comment
 $setting=<<'SETTING';
 match=<a href="(.+?)">(.+?)</a>
 url=$1
 desc="<".$2.">"
 replace(url)=s/http/ptth/;
 SETTING

Then the module will try to match the pattern in the retrieved page, and assigns the keys with matched values. And, B<replace> follows a substitution matcher, which can transform the specified extracted data.

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

If users need WWW::ContentRetrieval to retrieve next page, e.g. dealing with several pages of search results, push an anonymous hash with only one entry: C<_DTLURL>

 {
  _DTLURL => next url,
 }

See also I<t/extract.t>, I<t/robot.t>


=head2 NEXT

Represents URLs to be retrieved in next cycle.

Likewise, this module tries to match the lefthand side with the current url. If they match, the code on the right side will be invoked.

Additional to callback functions and retrieval settings, users can use regular expressions on the right side. Text will be searched for patterns matching the given one, and don't forget to capture desired urls with parentheses.

N.B. Different righthand sides can be attached to the same lefthand side, which means users can process one webpage with multiple strategies.

=head2 METHOD

Request method: GET, POST, or PLAIN.

=head2 QHANDL

C<Query Handler>, Url of the query script.

=head2 PARAM

Constant script parameters, excluding user's queries.

=head2 KEY

Key to user's query strings, e.g. product names

=head1 SEE ALSO

L<WWW::ContentRetrieval::Spider>, L<WWW::ContentRetrieval::Extract>

=head1 COPYRIGHT

xern E<lt>xern@cpan.orgE<gt>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.


=cut
