package WWW::ContentRetrieval::Spider;

use 5.006;
use strict;
our $VERSION = '0.05';

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(queryURL);


# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------
sub new {
    my($pkg) = shift;
    my($arg) = ref($_[0]) ? shift : {@_};
    
    die "NO URL\n" unless $arg->{URL};
    my($h) =    {
        URL         => $arg->{URL},
	METHOD      => $arg->{METHOD} || "GET",
	COOKIE_JAR  => $arg->{COOKIE_JAR},
	USERAGENT   => $arg->{USERAGENT} || "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:0.9.2.1) Gecko/20010901",
	PARAM       => $arg->{PARAM},
	QUERY       => $arg->{QUERY},
	HTTP_PROXY  => $arg->{HTTP_PROXY},
	TIMEOUT     => $arg->{TIMEOUT} || 10,
	DEBUG       => $arg->{DEBUG},
    };
bless $h, $pkg
}

# ----------------------------------------------------------------------
# Returns content of a given URL
# request method : ( PLAIN | GET | POST )
# ----------------------------------------------------------------------
sub content {
    my($pkg) = shift;
    my($content, $request, $response, $url);
    my $ua = LWP::UserAgent->new;

    print STDERR "METHOD: $pkg->{METHOD}\n" if $pkg->{DEBUG};
    $ua->agent  ($pkg->{USERAGENT});
    $ua->proxy  (http => $pkg->{HTTP_PROXY}) if $pkg->{HTTP_PROXY};
    $ua->timeout($pkg->{TIMEOUT});
    $ua->cookie_jar({ file => $pkg->{COOKIE_JAR} });

    if($pkg->{METHOD} eq "PLAIN"){
	print STDERR "$pkg->{URL}\n" if $pkg->{DEBUG};
	$request = GET ($pkg->{URL});
	$response = $ua->request($request);
	$response->is_success or return;
    }
    elsif($pkg->{METHOD} eq "GET"){
	my $paramstr
	    = join(q/&/, 
		   ref($pkg->{PARAM} eq 'HASH') ?
		   map { qq/$_=${$pkg->{PARAM}}{$_}/ } keys %{$pkg->{PARAM}} :
		       map{ qq/${$_}[0]=${$_}[1]/ } @{$pkg->{PARAM}});

	$url=join( q//, "$pkg->{URL}?",
                   join q/&/,
                   grep{$_}
                   ( $pkg->{QUERY}->[0] ?
                     qq/$pkg->{QUERY}->[0]=$pkg->{QUERY}->[1]/ : undef),
                   $paramstr);
	print STDERR "$url\n" if($pkg->{DEBUG});
	$request = GET ($url);
	$response = $ua->request($request);
	$response->is_success or return;
    }
    elsif($pkg->{METHOD} eq "POST"){
	$request = POST ($pkg->{URL} =>
			 [
			  $pkg->{QUERY}->[0] => $pkg->{QUERY}->[1],
			  map { $_ => $pkg->{PARAM}->{$_} } keys %{$pkg->{PARAM}}
			  ],
			 );
           my $paramstr=join(q/&/,  map { qq/$_=${$pkg->{PARAM}}{$_}/ } keys %{$pkg->{PARAM}});
	if($pkg->{DEBUG}){
	    $url=join( q//, "$pkg->{URL}?",
                        join q/&/,
                        grep{$_}
                        ( $pkg->{QUERY}->[0] ?
                          qq/$pkg->{QUERY}->[0]=$pkg->{QUERY}->[1]/ : undef),
	                 $paramstr);
	    print STDERR "$url\n";
	}
	$response = $ua->request($request);
	$response->is_success or return;
    }
$response->content
}

# ----------------------------------------------------------------------
# Dump content directly to a file
# ----------------------------------------------------------------------
sub content_to_file{
    my($pkg) = shift;
    my($fn) = shift;
    die "FILENAME?\n" unless $fn;
    open F, ">$fn" or die;
    print F $pkg->content();
    close F;
}


# ----------------------------------------------------------------------
# Returns a well-formed query url
# ----------------------------------------------------------------------
sub queryURL {
    my($arg) = ref($_[0]) ? shift : {@_};
    my($content, $request, $response);
    if($arg->{METHOD} eq "PLAIN"){
	print STDERR "$arg->{URL}\n" if $arg->{DEBUG};
	return $arg->{URL};
    }
    elsif($arg->{METHOD} eq "GET" || $arg->{METHOD} eq "POST"){
	my $paramstr
	    = join(q/&/,
		  ref($arg->{PARAM} eq 'HASH') ?
		  map { qq/$_=${$arg->{PARAM}}{$_}/ } keys %{$arg->{PARAM}} :
		      ref($arg->{PARAM} eq 'ARRAY')?
			  map{ qq/${$_}[0]=${$_}[1]/ } @{$arg->{PARAM}} : '');

	my $url = join( q//, $arg->{URL}, q/?/,
                        join q/&/,
                        grep{$_}
                        ( $arg->{QUERY}->[0] ?
                          qq/$arg->{QUERY}->[0]=$arg->{QUERY}->[1]/ : undef),
	                 $paramstr);
	print STDERR "$url\n" if $arg->{DEBUG};
	return $url;
    }
}



1;
__END__

=head1 NAME

WWW::ContentRetrieval::Spider - Simplified WWW User Agent

=head1 SYNOPSIS

  use WWW::ContentRetrieval::Spider;
  $s = new WWW::ContentRetrieval::Spider(
    URL         => 'http://foo.bar/',
    METHOD      => 'PLAIN',
    PARAM       => { 'paramA', 'valueA' },
    QUERY       => [ querykey, queryvalue ],
    HTTP_PROXY  => 'http://foo.bar:2345/',
    COOKIE_JAR  => "$ENV{HOME}/cookies.txt",
    TIMEOUT     => 10,
  );

  print $s->content;

=head1 DESCRIPTION

WWW::ContentRetrieval::Spider is a simplified www useragnet for web page retrieval, and is designed mainly for WWW::ContentRetrieval. Many features of LWP are excluded from here.

=head1 METHODS

=head2 new

  $s = WWW::ContentRetrieval::Spider->new(
    URL         => 'http://foo.bar/',
    METHOD      => 'PLAIN',                     # default is 'GET'
    QUERY       => [ querykey, queryvalue ],    # user's query
    PARAM       => { 'paramA' => 'valueA' }     # other parameters
    TIMEOUT     => 5,                           # 10 if undef
    USERAGENT   => 'WWW::ContentRetrieval::Spider'      # becomes Mozilla if undef
    COOKIE_JAR  => "$ENV{HOME}/cookies.txt"     # default is undef
    HTTP_PROXY  => 'http://foo.bar:2345/',
  );

And, it is better not to mix URL and its parameters together.

=head2 content

$s->content() returns url's content if success. Or it returns undef

=head2 content_to_file

$s->content_to_file(FILENAME) dumps content to a file

=head1 EXPORT

  queryURL(
      URL         => $url,
      METHOD      => 'POST',
      PARAM       => { 'paramA', 'valueA' },
      QUERY       => [ querykey, queryvalue],
  );

returns a GET-like URL for debugging or other uses, even though request method is POST.

=head1 SEE ALSO

L<WWW::ContentRetrieval>, L<WWW::ContentRetrieval::Extract>, L<LWP>

=head1 COPYRIGHT

xern <xern@cpan.org>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.

=cut

