use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'WWW::ContentRetrieval::Extract',
    'VERSION_FROM'	=> 'Extract.pm', # finds $VERSION
    'PREREQ_PM'		=> {
	'HTML::Tree' => 3.17,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Extract.pm', # retrieve abstract from module
       AUTHOR     => 'xern <xern@cpan.org>') : ()),
);
