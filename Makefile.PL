use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'WWW::ContentRetrieval',
    'VERSION_FROM'	=> 'ContentRetrieval.pm', # finds $VERSION
    'PREREQ_PM'		=> {
	'Digest::MD5' => '2.02',
	'URI'         => '1.22',
	'YAML'        => '0.35',
	'LWP'         => '5.69',
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'ContentRetrieval.pm', # retrieve abstract from module
       AUTHOR     => 'xern <xern@cpan.org>') : ()),
);