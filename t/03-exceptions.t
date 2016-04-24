use 5.008000;
use strict;
use warnings;

use Test::More tests => 6;
use Test::Fatal;
use Config::Loader;

my $CONFIG_LOADER = Config::Loader->new(
  dirs => [ qw( t/etc ) ],
);

t_missing_extension($CONFIG_LOADER);
t_unknown_extension($CONFIG_LOADER);
t_cant_locate_file();
t_cant_parse_file($CONFIG_LOADER);
t_invalid_array_element_index($CONFIG_LOADER);


sub t_missing_extension {
  my $config_loader = shift;

  like(
    exception { $config_loader->load( qw( foo ) ) },
    qr/^File extension not specified\. Don't known how parse t\/etc\/foo/,
    'missing extension'
  );

  return;
}

sub t_unknown_extension {
  my $config_loader = shift;

  like(
    exception { $config_loader->load( qw( foo.xml ) ) },
    qr/^Unknown file extension "\.xml" encountered\. Don't known how parse t\/etc\/foo\.xml/,
    'unknown extension'
  );

  return;
}

sub t_cant_locate_file {
  my $config_loader = Config::Loader->new(
    dirs => [ qw( t/etc my/etc ) ],
  );

  like(
    exception { $config_loader->load( 'foo.json bar.yml' ) },
    qr/^Can't locate foo\.json, bar\.yml in t\/etc, my\/etc/,
    'unknown extension'
  );

  return;
}

sub t_cant_parse_file {
  my $config_loader = shift;

  like(
    exception { my $c = $config_loader->load( qw( invalid.yml ) ) },
    qr/^Can't parse t\/etc\/invalid\.yml/,
    "can't parse file; YAML"
  );

  like(
    exception { my $c = $config_loader->load( qw( invalid.json ) ) },
    qr/^Can't parse t\/etc\/invalid\.json/,
    "can't parse file; JSON"
  );

  return;
}

sub t_invalid_array_element_index {
  my $config_loader = shift;

  like(
    exception {
      $config_loader->load( qw( foo_A.yaml ),
        { foo => {
            param_G => { var => 'foo.param_D.param_D_1' },
          },
        }
      );
    },
    qr/^Argument \"param_D_1\" isn't numeric in array element: foo\.param_D\.param_D_1/,
    'invalid array element index'
  );

  return;
}
