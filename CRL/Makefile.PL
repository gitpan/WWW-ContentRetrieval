use ExtUtils::MakeMaker;


WriteMakefile(
    'NAME'		=> 'WWW::ContentRetrieval::CRL',
    'VERSION_FROM'	=> 'CRL.pm', 
    'PREREQ_PM'		=> {}, 
    ($] >= 5.005 ?    
      (ABSTRACT_FROM => 'CRL.pm', 
       AUTHOR     => 'xern <xern@cpan.org>') : ()),
);
