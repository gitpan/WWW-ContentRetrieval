package WWW::ContentRetrieval;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.03';

require WWW::ContentRetrieval::Spider;
require WWW::ContentRetrieval::Extract;

use Data::Dumper;
use HTML::TreeBuilder;
use IO::Scalar;
use URI;
use Digest::MD5 qw/md5/;

# ----------------------------------------------------------------------
# Building an html-tree
# ----------------------------------------------------------------------
use IO::String;
sub bldTree($){
    $_[0] || return;
    my $t;
    my $sh = new IO::Scalar \$t;
    my $h = HTML::TreeBuilder->new_from_content($_[0]);
    $h->ignore_unknown(0);
    $h->dump($sh);
    $h = $h->delete(); # nuke it!
$t;
}

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
    my $cud = md5($thisurl);  # current url digest ; md5 used to avoid duplication
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
	if(exists $_->{DTLURL}){
	    if($_->{DTLURL} !~ /^http:/){
		$_->{DTLURL} = URI->new_abs($_->{DTLURL}, $thisurl)->as_string;
	    }
	    push @{$pkg->{SPOOL}},['PLAIN', $_->{DTLURL} ];
	}
        elsif(!exists $_->{DTLURL} || (scalar keys %$_) > 1){
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
                                     DEBUG      => 1,
				 });
  print Dumper $robot->retrieve( $query );


=head1 DESCRIPTION

L<WWW::ContentRetrieval> combines the power of a www robot and a text analyzer. It can fetch a series of web pages with some attributes in common, for example, a product catalogue. Users write down a description file and L<WWW::ContentRetrieval> can do fetching and extract desired data. This can be applied to do price comparison or meta search, for instance.

=head1 METHODS

=head2 new

  $s = WWW::ContentRetrieval->new($desc,
			 {
			     TIMEOUT    => 3,  # default is 10 seconds.
			     HTTP_PROXY => 'http://fooproxy:2345/',
                             DEBUG      => 1,  # non-zero to print out debugging msgs
			 });

=head2 retrieve

  $s->retrieve($query) returns an anonymous array of retrieved data.

You may use Data::Dumper to see it. 

=head1 OTHER TOOLS

=head2 WWW::ContentRetrieval::bldTree(htmltext)

tree-ifies text. See also L<HTML::TreeBuilder>

=head2 WWW::ContentRetrieval::genDescTmpl

automatically generates a description template.

=head1 DESC FILE TUTORIAL

=head2 OVERVIEW

Currently, this module uses native Perl's anonymous array and hash for users to write down site descriptions. Let's see an example.

Suppose the product query url of "foobar technology" be B<http://foo.bar/query.pl?encoding=UTF8&product=blahblahblah>.

 {
   SITE  =>
   {
    NAME => "foobar tech.",
    NEXT => [
     'query.pl' => 'detail.pl',
    ],
    POLICY => [
      'http://foo.bar/detail.pl' => [
				     ["PRODUCT" => "0.1.1.0.0.5.1" ],
				     ["PRICE"   => "0.1.1.0.0.5.1.0" ],
				     ],
      'http://foo.bar/foobarproduct.pl' => \&extraction_callback,
    ],
    METHOD => 'GET',
    QHANDL => 'http://foo.bar/query.pl',
    PARAM => [
     ['encoding', 'UTF8'],
    ],
    KEY => 'product',
   }
 };


=head2 SITE

Hash key to the settings.

=head2 NAME

The name of the site.

=head2 NEXT

NEXT is an anonymous array containing pairs of (this pattern => next pattern). If the current url matches /this pattern/, then text is searched for urls that match /next pattern/ and these urls are queued for next retrieval.

=head2 POLICY

POLICY is an anonymous array containing pairs of (this pattern => node settings). If the current url matches /this pattern/, then data at the given node will be retrieved.
Format of a slice is like this:

  [ NODE_NAME =>
    STARTING_NODE,
    [ VARIABLE INDEX ],
    [ STEPSIZE ],
    [ ENDING ],
    [ sub{FILTER here} ]
   ]

NODE_NAME is the output key to the node data. VARIABLE INDEX is an array of integers, denoting the index numbers of individual digits in starting node at which STARTING_NODE evolves. Using Cartesian product, nodes expand one STEPSIZE one time until digits at VARIABLE INDEX are all identical to those given in ENDING.

FILTER is left to users to write callback functions handling retrieved data, such as whitespace stripping.

Except NODE_NAME and STARTING_NODE, all of them are optional.

If users append ! to the tail of STARTING_NODE, L<WWW::ContentRetrieval::Extract> will extract the subtree hanging on the STARTING_NODE.

=over 1

=item * POLICY example

[ "PRODUCT" =>
  "0.0.0.0",
  [ 1, 3 ],
  [ 1, 2 ],
  [ 3, 4 ],
  sub { local $_ = shift; s/\s//g; $_ }
]

Data at 0.0.0.0, 0.0.0.2, 0.0.0.4, 0.1.0.0, 0.1.0.2, 0.1.0.4, 0.2.0.0, 0.2.0.2, 0.2.0.4, 0.3.0.0, 0.3.0.2, and 0.3.0.4 will be extracted with spaces eliminated.

=back


Also,

users may write I<ad hoc> callback functions for I<extraction> instead of writing down the above clumsie. L<WWW::ContentRetrieval> passes two parameters to a callback function: a reference to page's content and page's url.

E.g.

  sub my_callback{
      my ($textref, $thisurl) = @_;
      while( $$textref =~ /blahblah/g ){
           do some blahblahs here.
      }
      return an array of hashes, with keys and extracted information.
  }

See also L<t/extract.t>, L<t/robot.t>, L<t/recget.t>


=head2 METHOD

Request method: GET, POST, or PLAIN.

=head2 QHANDL

C<Query Handler>, Url of the query script.

=head2 PARAM

Constant script parameters, without user's queries.

=head2 KEY

Key to user's query strings, e.g. product names

=head1 SEE ALSO

L<WWW::ContentRetrieval::Spider>, L<WWW::ContentRetrieval::Extract>

=head1 COPYRIGHT

xern E<lt>xern@cpan.orgE<gt>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.


=cut
