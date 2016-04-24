package Config::Loader;

use 5.008000;
use strict;
use warnings;

our $VERSION = '0.01_01';

use File::Spec;
use YAML::XS qw( LoadFile );
use Cpanel::JSON::XS;
use Hash::Merge;
use Data::Rmap qw( rmap_to :types );
use Carp qw( croak );

my %FILE_EXTENSIONS_MAP = (
  yml  => 'yaml',
  yaml => 'yaml',
  json => 'json',
  jsn  => 'json',
);

Hash::Merge::specify_behavior(
  {
    SCALAR => {
      SCALAR => sub { $_[1] },
      ARRAY  => sub { $_[1] },
      HASH   => sub { $_[1] },
    },
    ARRAY => {
      SCALAR => sub { $_[1] },
      ARRAY  => sub { $_[1] },
      HASH   => sub { $_[1] },
    },
    HASH => {
      SCALAR => sub { $_[1] },
      ARRAY  => sub { $_[1] },
      HASH   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) },
    },
  },
  'CONFIG_PRECEDENT',
);


sub new {
  my $self_class = shift;
  my %params     = @_;

  my $self = bless {}, $self_class;

  $self->{dirs} = $params{dirs} || ['.'];
  $self->{interpolate_variables} = exists $params{interpolate_variables}
      ? $params{interpolate_variables} : 1;
  $self->{process_directives} = exists $params{process_directives}
      ? $params{process_directives} : 1;

  $self->{_hash_merge} = Hash::Merge->new( 'CONFIG_PRECEDENT' );
  $self->{_config}     = undef;
  $self->{_vars}       = {};

  return $self;
}

{
  no strict 'refs';

  foreach my $name ( qw( interpolate_variables process_directives ) ) {
    *{$name} = sub {
      my $self = shift;

      if ( @_ ) {
        $self->{$name} = shift;
      }

      return $self->{$name};
    }
  }
}

sub load {
  my $self            = shift;
  my @config_sections = @_;

  $self->{_config} = $self->_build_tree( @config_sections );

  rmap_to {
    $_ = $self->_process_node( $_ );
  } HASH|VALUE, $self->{_config};

  $self->{_vars} = {};

  return $self->{_config};
}

sub _build_tree {
  my $self            = shift;
  my @config_sections = @_;

  my $config = {};

  foreach my $config_section (@config_sections) {
    next unless defined $config_section;

    if ( ref($config_section) eq 'HASH' ) {
      $config = $self->{_hash_merge}->merge( $config, $config_section );
    }
    else {
      my %not_found_idx;
      my @file_patterns = split( /\s+/, $config_section );

      foreach my $dir ( @{ $self->{dirs} } ) {
        foreach my $file_pattern ( @file_patterns ) {
          my @file_pathes = glob( File::Spec->catfile( $dir, $file_pattern ) );

          foreach my $file_path (@file_pathes) {
            unless ( $file_path =~ m/\.([^.]+)$/ ) {
              croak "File extension not specified."
                  . " Don't known how parse $file_path";
            }

            my $file_ext  = $1;
            my $file_type = $FILE_EXTENSIONS_MAP{$file_ext};

            unless ( defined $file_type ) {
              croak "Unknown file extension \".$file_ext\" encountered."
                  . " Don't known how parse $file_path";
            }

            unless ( -e $file_path ) {
              $not_found_idx{$file_pattern} ||= 0;
              $not_found_idx{$file_pattern}++;

              next;
            }

            my $method = "_load_${file_type}_file";
            my @data = eval {
              return $self->$method($file_path);
            };
            if ($@) {
              croak "Can't parse $file_path\n$@";
            }

            foreach my $data_chunk (@data) {
              $config = $self->{_hash_merge}->merge( $config, $data_chunk );
            }
          }
        }
      }

      my @not_found = grep {
        $not_found_idx{$_} == scalar @{ $self->{dirs} }
      } keys %not_found_idx;

      if ( @not_found ) {
        croak "Can't locate " . join( ', ', @not_found )
            . " in " . join( ', ', @{ $self->{dirs} } );
      }
    }
  }

  return $config;
}

sub _load_yaml_file {
  my $self      = shift;
  my $file_path = shift;

  return LoadFile($file_path);
}

sub _load_json_file {
  my $self      = shift;
  my $file_path = shift;

  open( my $fh, '<', $file_path ) || die "Can't open $file_path: $!";
  my @data = ( decode_json( join( '', <$fh> ) ) );
  close($fh);

  return @data;
}

sub _process_node {
  my $self = shift;
  my $node = shift;

  return unless defined $node;

  if ( ref($node) eq 'HASH' && $self->{process_directives} ) {
    if ( defined $node->{var} ) {
      $node = $self->_resolve_var( $node->{var} );
    }
    elsif ( defined $node->{include} ) {
      $node = $self->_build_tree( $node->{include} );
    }
    else {
      if ( defined $node->{underlay} ) {
        my $layer = delete $node->{underlay};
        $layer = $self->_process_layer($layer);
        $node = $self->{_hash_merge}->merge( $layer, $node );
      }

      if ( defined $node->{overlay} ) {
        my $layer = delete $node->{overlay};
        $layer = $self->_process_layer($layer);
        $node = $self->{_hash_merge}->merge( $node, $layer );
      }
    }
  }
  elsif ( $self->{interpolate_variables} ) { # SCALAR
    $node =~ s/\$((\$?)\{([^\}]*)\})/
        $2 ? $1 : $self->_resolve_var( $3 )/ge;
  }

  return $node;
}

sub _process_layer {
  my $self  = shift;
  my $layer = shift;

  if ( ref($layer) eq 'HASH' ) {
    $layer = $self->_process_node( $layer );
  }
  elsif ( ref($layer) eq 'ARRAY' ) {
    my $new_layer = {};

    foreach my $node ( @{$layer} ) {
      $node = $self->_process_node( $node );
      $new_layer = $self->{_hash_merge}->merge( $new_layer, $node );
    }

    $layer = $new_layer;
  }

  return $layer;
}

sub _resolve_var {
  my $self     = shift;
  my $var_name = shift;

  my $vars = $self->{_vars};

  unless ( defined $vars->{$var_name}  ) {
    my @tokens = split( /\./, $var_name );
    my $pointer = $self->{_config};

    while ( 1 ) {
      my $token = shift @tokens;

      if ( ref($pointer) eq 'HASH' ) {
        last unless defined $pointer->{$token};

        if ( !@tokens ) {
          $vars->{$var_name}
              = $self->_process_node( $pointer->{$token} );
          $pointer->{$token} = $vars->{$var_name};

          last;
        }

        last unless ref( $pointer->{$token} );

        $pointer = $pointer->{$token};
      }
      else { # ARRAY
        if ( $token =~ m/\D/ ) {
          die "Argument \"$token\" isn't numeric in array element:"
              . " $var_name\n";
        }

        last unless defined $pointer->[$token];

        if ( !@tokens ) {
          $vars->{$var_name}
              = $self->_process_node( $pointer->[$token] );
          $pointer->[$token] = $vars->{$var_name};

          last;
        }

        last unless ref( $pointer->[$token] );

        $pointer = $pointer->[$token];
      }
    }
  }

  unless ( defined $vars->{$var_name} ) {
    $vars->{$var_name} = '';
  }

  return $vars->{$var_name};
}

1;
__END__

=head1 NAME

Config::Loader - Cascading configuration files parser with file inclusions
and variables interpolation support

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 new()

=head2 load()

=head2 interpolate_variables

=head2 process_directives

=head1 AUTHOR

Eugene Ponizovsky, E<lt>ponizovsky@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2016, Eugene Ponizovsky, E<lt>ponizovsky@gmail.comE<gt>.
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

