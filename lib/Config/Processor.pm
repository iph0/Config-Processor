package Config::Processor;

use 5.008000;
use strict;
use warnings;

our $VERSION = '0.15_01';

use File::Spec;
use YAML::XS qw( LoadFile );
use Cpanel::JSON::XS;
use Hash::Merge;
use Scalar::Util qw( refaddr );
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
  my $class  = shift;
  my %params = @_;

  my $self = bless {}, $class;

  $self->{dirs} = $params{dirs} || [];
  unless ( @{ $self->{dirs} } ) {
    push( @{ $self->{dirs} }, '.' );
  }

  $self->{interpolate_variables} = exists $params{interpolate_variables}
      ? $params{interpolate_variables} : 1;
  $self->{process_directives} = exists $params{process_directives}
      ? $params{process_directives} : 1;
  $self->{export_env} = $params{export_env};

  $self->{_merger} = Hash::Merge->new('CONFIG_PRECEDENT');
  $self->{_config}     = undef;
  $self->{_vars}       = {};
  $self->{_seen_nodes} = {};

  return $self;
}

{
  no strict 'refs';

  foreach my $name (
      qw( interpolate_variables process_directives export_env ) )
  {
    *{$name} = sub {
      my $self = shift;

      if (@_) {
        $self->{$name} = shift;
      }

      return $self->{$name};
    }
  }
}

sub load {
  my $self = shift;
  my @config_sections = @_;

  $self->{_config} = $self->_build_tree(@config_sections);
  if ( $self->{export_env} ) {
    $self->{_config} = $self->{_merger}->merge( $self->{_config},
        { ENV => {%ENV} } );
  }
  $self->_process_tree( $self->{_config} );

  $self->{_vars}       = {};
  $self->{_seen_nodes} = {};

  return $self->{_config};
}

sub _build_tree {
  my $self = shift;
  my @config_sections = @_;

  my $config = {};

  foreach my $config_section (@config_sections) {
    next unless defined $config_section;

    if ( ref($config_section) eq 'HASH' ) {
      $config = $self->{_merger}->merge( $config, $config_section );
    }
    else {
      my %not_found_idx;
      my @file_patterns = split( /\s+/, $config_section );

      foreach my $dir ( @{ $self->{dirs} } ) {
        foreach my $file_pattern ( @file_patterns ) {
          my @file_pathes = glob( File::Spec->catfile( $dir, $file_pattern ) );

          foreach my $file_path (@file_pathes) {
            next if -d $file_path;

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

            my @data = eval {
              my $method = "_load_$file_type";
              return $self->$method($file_path);
            };
            if ($@) {
              croak "Can't parse $file_path\n$@";
            }

            foreach my $data_chunk (@data) {
              $config = $self->{_merger}->merge( $config, $data_chunk );
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

sub _load_yaml {
  my $self      = shift;
  my $file_path = shift;

  return LoadFile($file_path);
}

sub _load_json {
  my $self      = shift;
  my $file_path = shift;

  open( my $fh, '<', $file_path ) || die "Can't open $file_path: $!";
  my @data = ( decode_json( join( '', <$fh> ) ) );
  close($fh);

  return @data;
}

sub _process_tree {
  my $self = shift;

  $_[0] = $self->_process_node( $_[0] );

  if ( my $node_addr = refaddr( $_[0] ) ) {
    return if $self->{_seen_nodes}{$node_addr};

    $self->{_seen_nodes}{$node_addr} = 1;
  }

  if ( ref( $_[0] ) eq 'HASH' ) {
    foreach ( values %{ $_[0] } ) {
      $self->_process_tree($_);
    }
  }
  elsif ( ref( $_[0] ) eq 'ARRAY' ) {
    foreach ( @{ $_[0] } ) {
      $self->_process_tree($_);
    }
  }

  return;
}

sub _process_node {
  my $self = shift;
  my $node = shift;

  return unless defined $node;

  if ( !ref($node) && $self->{interpolate_variables} ) {
    $node =~ s/\$((\$?)\{([^\}]*)\})/
        $2 ? $1 : ( $self->_resolve_var( $3 ) || '' )/ge;
  }
  elsif ( ref($node) eq 'HASH' && $self->{process_directives} ) {
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
        $node = $self->{_merger}->merge( $layer, $node );
      }

      if ( defined $node->{overlay} ) {
        my $layer = delete $node->{overlay};
        $layer = $self->_process_layer($layer);
        $node = $self->{_merger}->merge( $node, $layer );
      }
    }
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
      $new_layer = $self->{_merger}->merge( $new_layer, $node );
    }

    $layer = $new_layer;
  }

  return $layer;
}

sub _resolve_var {
  my $self     = shift;
  my $var_name = shift;

  my $vars = $self->{_vars};

  unless ( defined $vars->{$var_name} ) {
    my @tokens = split( /\./, $var_name );
    my $pointer = $self->{_config};

    my $value;

    while (1) {
      my $token = shift @tokens;

      if ( ref($pointer) eq 'HASH' ) {
        last unless defined $pointer->{$token};

        if ( !@tokens ) {
          $value = $self->_process_node( $pointer->{$token} );
          $pointer->{$token} = $value;

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
          $value = $self->_process_node( $pointer->[$token] );
          $pointer->[$token] = $value;

          last;
        }

        last unless ref( $pointer->[$token] );

        $pointer = $pointer->[$token];
      }
    }

    if ( defined $value ) {
      $vars->{$var_name} = $value;
    }
  }

  return $vars->{$var_name};
}

1;
__END__

=head1 NAME

Config::Processor - Cascading configuration files processor with additional
features

=head1 SYNOPSIS

  use Config::Processor;

  my $config_processor = Config::Processor->new(
    dirs => [ qw( /etc/myapp /home/username/etc/myapp ) ],
  );

  my $config = $config_processor->load( qw( dirs.yml db.json metrics/* ) );

  $config = $config_processor->load(
    qw( dirs.yml db.json redis.yml mongodb.json metrics/* ),

    { myapp => {
        db => {
          connectors => {
            stat_master => {
              host => 'localhost',
              port => '4321',
            },
          },
        },
      },
    },
  );

=head1 DESCRIPTION

Config::Processor is the cascading configuration files processor, which
supports file inclusions, variables interpolation and other manipulations with
configuration tree. Works with YAML and JSON file formats. File format is
determined by the extension. Supports following file extensions: F<.yml>,
F<.yaml>, F<.jsn>, F<.json>.

=head1 CONSTRUCTOR

=head2 new( %params )

  my $config_processor = Config::Processor->new(
    dirs => [ qw( /etc/myapp /home/username/etc/myapp ) ],
  );

  $config_processor = Config::Processor->new();

  $config_processor = Config::Processor->new(
    dirs                  => [ qw( /etc/myapp /home/username/etc/myapp ) ],
    interpolate_variables => 0,
    process_directives    => 0,
  );

=over

=item dirs => \@dirs

List of directories, in which configuration processor will search files. If
the parameter not specified, current directory will be used.

=item interpolate_variables => $boolean

Enables or disables variable interpolation in configurations files.
Enabled by default.

=item process_directives => $boolean

Enables or disables directive processing in configurations files.
Enabled by default.

=item export_env

Enables or disables environment variables exporting to configuration tree.
If enabled, environment variables can be accessed by the key C<ENV> from the
tree and can be interpolated in other configuration parameters.

Disabled by default.

=back

=head1 METHODS

=head2 load( @config_sections )

Attempts to load all configuration sections and returns reference to resulting
configuration tree.

Configuration section can be a relative filename, a filename with wildcard
characters or a hash reference. Filenames with wildcard characters is processed
by C<CORE::glob> function and supports the same syntax.

  my $config = $config_processor->load( qw( myapp.yml extras/* ), \%hard_config );

=head2 interpolate_variables( [ $boolean ] )

Enables or disables variable interpolation in configurations files.

=head2 process_directives( [ $boolean ] )

Enables or disables directive processing in configuration files.

=head2 export_env( [ $boolean ] )

Enables or disables environment variables exporting to configuration tree.

=head1 MERGING RULES

Config::Processor merges all configuration sections in one resulting configuration tree by following rules:

  Left value  Right value  Result value

  SCALAR $a   SCALAR $b    SCALAR $b
  SCALAR $a   ARRAY  \@b   ARRAY  \@b
  SCALAR $a   HASH   \%b   HASH   \%b

  ARRAY \@a   SCALAR $b    SCALAR $b
  ARRAY \@a   ARRAY  \@b   ARRAY  \@b
  ARRAY \@a   HASH   \%b   HASH   \%b

  HASH \%a    SCALAR $b    SCALAR $b
  HASH \%a    ARRAY  \@b   ARRAY  \@b
  HASH \%a    HASH   \%b   HASH   recursive_merge( \%a, \%b )

For example, we have two configuration files. F<db.yml> at the left side:

  db:
    connectors:
      stat_writer:
        host:     "stat.mydb.com"
        port:     "1234"
        dbname:   "stat"
        username: "stat_writer"
        password: "stat_writer_pass"

And F<db_test.yml> at the right side:

  db:
    connectors:
      stat_writer:
        host:     "localhost"
        username: "test"
        password: "test_pass"

After merging of two files we will get:

  db => {
    connectors => {
      stat_writer => {
        host      => "localhost",
        port:     => "1234",
        dbname:   => "stat",
        username: => "test",
        password: => "test_pass",
      },
    },
  },

=head1 INTERPOLATION

Config::Processor can interpolate variables in string values (if you need alias
for complex structures see C<var> directive). For example, we have
F<myapp.yml> file:

  myapp:
    media_formats: [ "images", "audio", "video" ]

    dirs:
      root_dir: "/myapp"
      templates_dir: "${myapp.dirs.root_dir}/templates"
      sessions_dir: "${myapp.dirs.root_dir}/sessions"
      media_dirs:
        - "${myapp.dirs.root_dir}/media/${myapp.media_formats.0}"
        - "${myapp.dirs.root_dir}/media/${myapp.media_formats.1}"
        - "${myapp.dirs.root_dir}/media/${myapp.media_formats.2}"

After processing of the file we will get:

  myapp => {
    media_formats => [ "images", "audio", "video" ],

    dirs => {
      root_dir      => "/myapp",
      templates_dir => "/myapp/templates",
      sessions_dir  => "/myapp/sessions",
      media_dirs    => [
        "/myapp/media/images",
        "/myapp/media/audio",
        "/myapp/media/video",
      ],
    },
  },

To escape variable interpolation add one more "$" symbol before variable.

  templates_dir: "$${myapp.dirs.root_dir}/templates"

After processing we will get:

  templates_dir => ${myapp.dirs.root_dir}/templates,

=head1 DIRECTIVES

=over

=item var: varname

Assigns configuration parameter value to another configuration parameter.

  myapp:
    db:
      generic_options:
        PrintWarn:  0
        PrintError: 0
        RaiseError: 1

      connectors:
        stat_master:
          host:     "stat-master.mydb.com"
          port:     "1234"
          dbname:   "stat"
          username: "stat_writer"
          password: "stat_writer_pass"
          options: { var: myapp.db.generic_options }

        stat_slave:
          host:     "stat-slave.mydb.com"
          port:     "1234"
          dbname:   "stat"
          username: "stat_reader"
          password: "stat_reader_pass"
          options: { var: myapp.db.generic_options }

=item include: filename

Loads configuration parameters from file or multiple files and assigns it to
specified configuration parameter. Argument of C<include> directive can be
relative filename or a filename with wildcard characters. If loading multiple
files, configuration parameters from them will be merged before assignment.

  myapp:
    db:
      generic_options:
        PrintWarn:  0
        PrintError: 0
        RaiseError: 1

      connectors: { include: db_connectors.yml }

    metrics: { include: metrics/* }

=item underlay

Merges specified configuration parameters with parameters located at the same
context. Configuration parameters from the context overrides parameters from
the directive. C<underlay> directive most usefull in combination with C<var>
and C<include> directives.

For example, you can use this directive to set default values of parameters.

  myapp:
    db:
      connectors:
        default:
          port:   "1234"
          dbname: "stat"
          options:
            PrintWarn:  0
            PrintError: 0
            RaiseError: 1

        stat_master:
          underlay: { var: myapp.db.connectors.default }
          host:     "stat-master.mydb.com"
          username: "stat_writer"
          password: "stat_writer_pass"

        stat_slave:
          underlay: { var: myapp.db.connectors.default }
          host:     "stat-slave.mydb.com"
          username: "stat_reader"
          password: "stat_reader_pass"

You can move default parameters in separate files.

  myapp:
    db:
      connectors:
        underlay:
          - { include: db_connectors/default.yml }
          - { include: db_connectors/default_test.yml }

        stat_master:
          underlay: { var: myapp.db.connectors.default }
          host:     "stat-master.mydb.com"
          username: "stat_writer"
          password: "stat_writer_pass"

        stat_slave:
          underlay: { var: myapp.db.connectors.default }
          host:     "stat-slave.mydb.com"
          username: "stat_reader"
          password: "stat_reader_pass"

        test:
          underlay: { var: myapp.db.connectors.default_test }
          username: "test"
          password: "test_pass"

=item overlay

Merges specified configuration parameters with parameters located at the same
context. Configuration parameters from the directive overrides parameters from
the context. C<overlay> directive most usefull in combination with C<var> and
C<include> directives.

For example, you can use C<overlay> directive to temporaly overriding regular
configuration parameters.

  myapp:
    db:
      connectors:
        default:
          port:   "1234"
          dbname: "stat"
          options:
            PrintWarn:  0
            PrintError: 0
            RaiseError: 1

        test:
          host: "localhost"
          port: "4321"

        stat_master:
          underlay: { var: myapp.db.connectors.default }
          host:     "stat-master.mydb.com"
          username: "stat_writer"
          password: "stat_writer_pass"
          overlay:  { var: myapp.db.connectors.test }

        stat_slave:
          underlay: { var: myapp.db.connectors.default }
          host:     "stat-slave.mydb.com"
          username: "stat_reader"
          password: "stat_reader_pass"
          overlay:  { var: myapp.db.connectors.test }

To disable overriding just assign to C<test> connector empty hash.

  test: {}

=back

=head1 AUTHOR

Eugene Ponizovsky, E<lt>ponizovsky@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2016, Eugene Ponizovsky, E<lt>ponizovsky@gmail.comE<gt>.
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
