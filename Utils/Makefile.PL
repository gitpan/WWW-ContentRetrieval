use ExtUtils::MakeMaker;


WriteMakefile(
    'NAME'		=> 'WWW::ContentRetrieval::Utils',
    'VERSION_FROM'	=> 'Utils.pm', 
    'PREREQ_PM'		=> {}, 
    ($] >= 5.005 ?    
      (AUTHOR     => 'xern <xern@cpan.org>') : ()),
);
