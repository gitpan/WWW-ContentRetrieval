use ExtUtils::MakeMaker;


WriteMakefile(
    'NAME'		=> 'WWW::ShopBot',
    'VERSION_FROM'	=> 'ShopBot.pm', 
    'PREREQ_PM'		=> {}, 
    ($] >= 5.005 ?    
      (ABSTRACT_FROM => 'ShopBot.pm', 
       AUTHOR     => 'xern <xern@cpan.org>') : ()),
);
