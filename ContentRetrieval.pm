package WWW::ContentRetrieval;

use 5.006;
use strict;
our $VERSION = '0.087';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(genDescTmpl);


use WWW::ContentRetrieval::Spider;
use WWW::ContentRetrieval::Extract;
use WWW::ContentRetrieval::Utils;

use Data::Dumper;
use URI;
use Digest::MD5 qw/md5/;
use YAML;

# ----------------------------------------------------------------------
# Generating description template
# ----------------------------------------------------------------------
sub genDescTmpl(){
    <<'TMPL';

sub callback {
    my ($textref, $thisurl) = @_;
}

$items = <<'...';
match=m//sg
item1=$item[1]
item2=$item[2]
replace(url)=s///
reject(url)=m//
...

$desc = <<'...';
NAME: site's name

FETCH:
 QHANDL : 'http://foo.bar/query.pl'
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

TMPL
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
    $desc = Load($arg->{DESC});
    transform_desc($callpkg, $desc);
    bless{
	CALLPKG    => $callpkg,
	DESC       => $desc->{FETCH},
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
  $robot = WWW::ContentRetrieval->new($desc);
  print Dumper $robot->retrieve( $query );


=head1 DESCRIPTION

L<WWW::ContentRetrieval> combines the power of a www robot and a text analyzer. It can fetch a series of web pages with some attributes in common, for example, a product catalogue. Users write down a description file and L<WWW::ContentRetrieval> can do fetching and extract desired data. This can be applied to do price comparison or meta search, for instance.

=head1 METHODS

=head2 new

  # with site's description only
  $s = new WWW::ContentRetrieval($desc);


  # with full argument list
  $s =
    new WWW::ContentRetrieval(
			      DESC       => $desc,
			      # site's description

			      TIMEOUT    => 3,
			      # default is 10 secs.

			      HTTP_PROXY => 'http://fooproxy:2345/',

			      DEBUG      => 1,
			      # non-zero to print out debugging msgs
			      );

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
 $links = <<'LINKS';

    # look up texts for this pattern
  match=m,<a href="(.+?)">(.+?)</a>,sg

    # give an identifier to the captured value
  site=$item[1]

    # ditto
  url=$item[2]

    # replace *url* using substitution
  replace(url)=s/http/ptth/

    # reject data with *asp* at url's end
  reject(url)=m/\.asp$/
 LINKS

 # site's description
 $desc = <<'...';
 NAME: site's name

 FETCH:
   QHANDL : 'http://foo.bar/query.pl'
   METHOD: GET
   PARAM:
    encoding : UTF8
   KEY: product
   POLICY:
    - m/foo\.bar/ => $links
    - m/foo\.bar/ => &callback
   NEXT:
    - m/./ => m/<a href="(.+?)">.+<\/a>/
    - q'http://foo.bar/query.pl' => $next
 ...

=head2 NAME

Name of the site.

=head2 POLICY

POLICY stores information for a certain page's extraction. It is composed of pairs of (this url's pattern => callback function) or (this url's pattern => retrieval settings). If the current url matches /this pattern/, then this modules will invoke the corresponding callback or extract data according to the retrieval settings given by users. And remember that regular expressions must be initialed with C<m>, or it will produce an error.

In simple cases, users only need to write down the retrieval settings instead of a callback function. Retrieval settings contains lines of instructions in a /key=value/ format. Here's an example.

 # use a leading # for comment
 $setting=<<'SETTING';
 match=m,<a href="(.+?)">(.+?)</a>,sg
 url=$item[1]
 desc="<".$item[2].">"
 replace(url)=s/http/ptth/;
 reject(url)=m/\.asp$/
 SETTING

Then the module will try to match the pattern in the retrieved page, and assigns the keys with matched values. Captured variables will be stored in an array called C<@item>, whose index counts from 1 to 9. Then, B<replace> follows a substitution matcher, which can refine extracted data. And, B<reject> allows users to discard values matching some pattern after substitution.

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

=head1 CAVEATS

It is still alpha, and the interface is subject to change. Source code is distributed without warranty.

B<Use it with your own cautions.>

=head1 COPYRIGHT

xern E<lt>xern@cpan.orgE<gt>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.


=cut
