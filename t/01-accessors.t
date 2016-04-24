use 5.008000;
use strict;
use warnings;

use Test::More tests => 8;
use Config::Loader;

my $CONFIG_LOADER = Config::Loader->new();

can_ok( $CONFIG_LOADER, 'interpolate_variables' );
can_ok( $CONFIG_LOADER, 'process_directives' );

t_interpolate_variables($CONFIG_LOADER);
t_process_directives($CONFIG_LOADER);


sub t_interpolate_variables {
  my $config_loader = shift;

  my $interpolate_variables = $config_loader->interpolate_variables;
  is( $interpolate_variables, 1, 'get variable interpolation switch value' );

  $config_loader->interpolate_variables(undef);
  is( $config_loader->interpolate_variables,
      undef, 'disable variable interpolation' );

  $config_loader->interpolate_variables(1);
  is( $config_loader->interpolate_variables, 1,
      "enable variable interpolation" );

  return;
}

sub t_process_directives {
  my $config_loader = shift;

  my $process_directives = $config_loader->process_directives;
  is( $process_directives, 1, 'get directive processing switch value' );

  $config_loader->process_directives(undef);
  is( $config_loader->process_directives,
      undef, 'disable directive processing' );

  $config_loader->process_directives(1);
  is( $config_loader->process_directives, 1, "enable directive processing" );

  return;
}
