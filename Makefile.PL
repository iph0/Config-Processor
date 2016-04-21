use 5.008000;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME               => 'Config::Loader',
  VERSION_FROM       => 'lib/Config/Loader.pm',
  PREREQ_PM          => {},
  CONFIGURE_REQUIRES => {
    'ExtUtils::MakeMaker' => 6.64,
  },
  BUILD_REQUIRES => {
    'Test::More' => 0.98,
  },
  META_MERGE => {
    resources => {
      homepage   => 'https://github.com/iph0/Config-Loader',
      bugtracker => 'https://github.com/iph0/Config-Loader/issues',
      repository => 'https://github.com/iph0/Config-Loader',
      license    => 'http://dev.perl.org/licenses/',
    },
  },  
  ABSTRACT_FROM => 'lib/App/Environ.pm',
  AUTHOR        => 'Eugene Ponizovsky <ponizovsky@gmail.com>',
  LICENSE       => 'perl',
);
