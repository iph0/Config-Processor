use 5.008000;
use strict;
use warnings;

use Test::More tests => 9;
use Config::Loader;

my $CONFIG_LOADER = Config::Loader->new(
  dirs => [ qw( t/etc ) ],
);

can_ok( $CONFIG_LOADER, 'load' );

t_merging_yaml($CONFIG_LOADER);
t_merging_json($CONFIG_LOADER);
t_merging_mixed($CONFIG_LOADER);

t_variable_interpolation_on($CONFIG_LOADER);
t_variable_interpolation_off();

t_directive_processing_on($CONFIG_LOADER);
t_directive_processing_off();

t_complete_processing($CONFIG_LOADER);


sub t_merging_yaml {
  my $config_loader = shift;

  my $t_config = $config_loader->load( qw( foo_A.yaml foo_B.yml ) );

  my $e_config = {
    foo => {
      param_A => 'foo_B:val_A',
      param_B => 'foo_A:val_B',

      param_C => {
        param_C_1 => 'foo_B:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
      },

      param_D => [
        'foo_B:val_D_1',
        'foo_B:val_D_2',
      ],

      param_E => [
        'foo_B:val_E_1',
        { param_E_2_1 => 'foo_B:val_E_2_1',
          param_E_2_2 => 'foo_B:val_E_2_2',
        },
      ],

      param_F => {
        param_F_1 => 'foo_B:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'foo_B:val_F_4',
      },
    },
  };

  is_deeply( $t_config, $e_config, 'merging; YAML' );
}

sub t_merging_json {
  my $config_loader = shift;

  my $t_config = $config_loader->load( qw( bar_A.json bar_B.jsn ) );

  my $e_config = {
    bar => {
      param_A => 'bar_B:val_A',
      param_B => 'bar_A:val_B',

      param_C => {
        param_C_1 => 'bar_B:val_C_1',
        param_C_2 => 'bar_A:val_C_2',
        param_C_3 => 'bar_B:val_C_3',
      },

      param_D => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_E => [
        'bar_B:val_E_1',
        { param_E_2_1 => 'bar_B:val_E_2_1',
          param_E_2_2 => 'bar_B:val_E_2_2',
        },
      ],

      param_F => {
        param_F_1 => 'bar_B:val_F_1',
        param_F_2 => [
          'bar_B:val_F_2_1',
          'bar_B:val_F_2_2',
        ],
        param_F_3 => 'bar_A:val_F_3',
        param_F_4 => 'bar_B:val_F_4',
      },
    },
  };

  is_deeply( $t_config, $e_config, 'merging; JSON' );

  return;
}

sub t_merging_mixed {
  my $config_loader = shift;

  my $t_config = $config_loader->load( qw( foo_A.yaml bar_A.json zoo.yml ),
    { foo => {
        param_A => 'hard:val_A',

        param_C => {
          param_C_3 => "hard:val_C_3",
          param_C_5 => "hard:val_C_5",
        },
      },

      bar => {
        param_A => 'hard:val_A',

        param_C => {
          param_C_3 => "hard:val_C_3",
          param_C_5 => "hard:val_C_5",
        },
      },
    }
  );

  my $e_config = {
    foo => {
      param_A => 'hard:val_A',
      param_B => 'foo_A:val_B',

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'hard:val_C_3',
        param_C_4 => 'zoo:val_C_4',
        param_C_5 => 'hard:val_C_5',
      },

      param_D => [
        'foo_A:val_D_1',
        'foo_A:val_D_2',
      ],

      param_E => [
        'foo_A:val_E_1',
        { param_E_2_1 => 'foo_A:val_E_2_1',
          param_E_2_2 => 'foo_A:val_E_2_2',
        },
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'foo_A:val_F_2_1',
          'foo_A:val_F_2_2'
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2'
        ],
      },
    },

    bar => {
      param_A => 'hard:val_A',
      param_B => 'bar_A:val_B',

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'bar_A:val_C_2',
        param_C_3 => 'hard:val_C_3',
        param_C_4 => 'zoo:val_C_4',
        param_C_5 => 'hard:val_C_5',
      },

      param_D => [
        'bar_A:val_D_1',
        'bar_A:val_D_2',
      ],

      param_E => [
        'bar_A:val_E_1',
        { param_E_2_1 => 'bar_A:val_E_2_1',
          param_E_2_2 => 'bar_A:val_E_2_2',
        },
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'bar_A:val_F_2_1',
          'bar_A:val_F_2_2',
        ],
        param_F_3 => 'bar_A:val_F_3',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ]
      },
    },
  };

  is_deeply( $t_config, $e_config, 'merging; mixed' );

  return;
}

sub t_variable_interpolation_on {
  my $config_loader = shift;

  my $t_config = $config_loader->load(
      qw( foo_A.yaml foo_B.yml bar_A.json bar_B.jsn zoo.yml jar.json ) );

  my $e_config = {
    foo => {
      param_A => 'foo_B:val_A',
      param_B => 'foo_A:val_B',

      param_D => [
        'foo_B:val_D_1',
        'foo_B:val_D_2',
      ],

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_E => [
        'foo_B:val_E_1',
        { param_E_2_1 => 'foo_B:val_E_2_1',
          param_E_2_2 => 'foo_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'foo_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    bar => {
      param_A => 'bar_B:val_A',
      param_B => 'bar_A:val_B',

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'bar_A:val_C_2',
        param_C_3 => 'bar_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_D => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_E => [
        'bar_B:val_E_1',
        { param_E_2_1 => 'bar_B:val_E_2_1',
          param_E_2_2 => 'bar_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'bar_B:val_F_2_1',
          'bar_B:val_F_2_2',
        ],
        param_F_3 => 'bar_A:val_F_3',
        param_F_4 => 'bar_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    jar => {
      param_A => 'jar:foo_B:val_A',
      param_B => 'jar:foo_A:val_B; jar:bar_A:val_B',

      param_C => {
        param_C_1 => 'jar:zoo:val_C_1; jar:bar_B:val_C_3',
        param_C_2 => 'jar:foo_B:val_C_3; jar:zoo:val_C_1',
      },

      param_D => [
        'jar:foo_B:val_D_1; jar:bar_B:val_D_2',
        'jar:bar_B:val_D_2; jar:foo_B:val_D_1',
        'jar:foo_B:val_F_2_1; jar:bar_B:val_F_2_2',
        'jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',
        'jar:zoo:val_F_5_1; jar:zoo:val_F_5_2',
      ],

      param_E => [
        'jar:jar:foo_B:val_A; jar:jar:foo_A:val_B; jar:bar_A:val_B',
        { param_E_2_2 => 'jar:jar:foo_B:val_D_1; jar:bar_B:val_D_2;'
              . ' jar:jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',
          param_E_2_1 => 'jar:jar:zoo:val_C_1; jar:bar_B:val_C_3;'
              . ' jar:jar:foo_B:val_C_3; jar:zoo:val_C_1',
        },
        'jar:jar:bar_B:val_D_2; jar:foo_B:val_D_1; jar:jar:zoo:val_F_5_1;'
            . ' jar:zoo:val_F_5_2',
      ],

      param_F => {
        param_F_1 =>
            'jar:jar:jar:foo_B:val_A; jar:jar:foo_A:val_B; jar:bar_A:val_B;'
                .' jar:jar:jar:zoo:val_C_1; jar:bar_B:val_C_3;'
                .' jar:jar:foo_B:val_C_3; jar:zoo:val_C_1',
        param_F_2 => [
          'jar:jar:jar:foo_B:val_D_1; jar:bar_B:val_D_2; jar:jar:bar_B:val_F_2_2;'
              . ' jar:foo_B:val_F_2_1',
          'jar:jar:jar:bar_B:val_D_2; jar:foo_B:val_D_1; jar:jar:zoo:val_F_5_1;'
              . ' jar:zoo:val_F_5_2',
        ],
        param_F_3 => 'jar:jar:jar:jar:foo_B:val_D_1; jar:bar_B:val_D_2;'
            . ' jar:jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',

        param_F_4 => 'jar:${foo.param_A}',

        param_F_5 => 'jar:',
        param_F_6 => 'jar:',
        param_F_7 => 'jar:',
        param_F_8 => 'jar:',
      },
    },
  };

  is_deeply( $t_config, $e_config, 'variable interpolation: on' );

  return;
}

sub t_variable_interpolation_off {
  my $config_loader = Config::Loader->new(
    dirs                  => [ qw( t/etc ) ],
    interpolate_variables => 0,
  );

  my $t_config = $config_loader->load(
      qw( foo_A.yaml foo_B.yml bar_A.json bar_B.jsn zoo.yml jar.json ) );

  my $e_config = {
    foo => {
      param_A => 'foo_B:val_A',
      param_B => 'foo_A:val_B',

      param_D => [
        'foo_B:val_D_1',
        'foo_B:val_D_2',
      ],

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_E => [
        'foo_B:val_E_1',
        { param_E_2_1 => 'foo_B:val_E_2_1',
          param_E_2_2 => 'foo_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'foo_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    bar => {
      param_A => 'bar_B:val_A',
      param_B => 'bar_A:val_B',

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'bar_A:val_C_2',
        param_C_3 => 'bar_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_D => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_E => [
        'bar_B:val_E_1',
        { param_E_2_1 => 'bar_B:val_E_2_1',
          param_E_2_2 => 'bar_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'bar_B:val_F_2_1',
          'bar_B:val_F_2_2',
        ],
        param_F_3 => 'bar_A:val_F_3',
        param_F_4 => 'bar_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    jar => {
      param_A => 'jar:${foo.param_A}',
      param_B => 'jar:${foo.param_B}; jar:${bar.param_B}',

      param_C => {
        param_C_1 => 'jar:${foo.param_C.param_C_1};'
            . ' jar:${bar.param_C.param_C_3}',
        param_C_2 => 'jar:${foo.param_C.param_C_3};'
            . ' jar:${bar.param_C.param_C_1}',
      },

      param_D => [
        'jar:${foo.param_D.0}; jar:${bar.param_D.1}',
        'jar:${bar.param_D.1}; jar:${foo.param_D.0}',
        'jar:${foo.param_F.param_F_2.0}; jar:${bar.param_F.param_F_2.1}',
        'jar:${bar.param_F.param_F_2.1}; jar:${foo.param_F.param_F_2.0}',
        'jar:${foo.param_F.param_F_5.0}; jar:${bar.param_F.param_F_5.1}',
      ],

      param_E => [
        'jar:${jar.param_A}; jar:${jar.param_B}',
        { param_E_2_1 => 'jar:${jar.param_C.param_C_1};'
            . ' jar:${jar.param_C.param_C_2}',
          param_E_2_2 => 'jar:${jar.param_D.0}; jar:${jar.param_D.3}',
        },
        'jar:${jar.param_D.1}; jar:${jar.param_D.4}',
      ],

      param_F => {
        param_F_1 => 'jar:${jar.param_E.0}; jar:${jar.param_E.1.param_E_2_1}',
        param_F_2 => [
          'jar:${jar.param_E.1.param_E_2_2}',
          'jar:${jar.param_E.2}',
        ],
        param_F_3 => 'jar:${jar.param_F.param_F_2.0}',

        param_F_4 => 'jar:$${foo.param_A}',

        param_F_5 => 'jar:${foox.param_C.param_C_1}',
        param_F_6 => 'jar:${foo.param_CX.param_C_1}',
        param_F_7 => 'jar:${foo.param_C.param_CX}',
        param_F_8 => 'jar:${jar.param_E.3}',
      }
    }
  };

  is_deeply( $t_config, $e_config, 'variable interpolation: off' );

  return;
}

sub t_directive_processing_on {
  my $config_loader = shift;

  my $t_config = $config_loader->load(
      qw( foo_A.yaml foo_B.yml bar_A.json bar_B.jsn zoo.yml moo.yml ) );

  my $e_config = {
    foo => {
      param_A => 'foo_B:val_A',
      param_B => 'foo_A:val_B',

      param_D => [
        'foo_B:val_D_1',
        'foo_B:val_D_2',
      ],

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_E => [
        'foo_B:val_E_1',
        { param_E_2_1 => 'foo_B:val_E_2_1',
          param_E_2_2 => 'foo_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'foo_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    bar => {
      param_A => 'bar_B:val_A',
      param_B => 'bar_A:val_B',

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'bar_A:val_C_2',
        param_C_3 => 'bar_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_D => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_E => [
        'bar_B:val_E_1',
        { param_E_2_1 => 'bar_B:val_E_2_1',
          param_E_2_2 => 'bar_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'bar_B:val_F_2_1',
          'bar_B:val_F_2_2',
        ],
        param_F_3 => 'bar_A:val_F_3',
        param_F_4 => 'bar_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    moo => {
      param_A => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_B => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_C => [
        { param_C_1 => 'zoo:val_C_1',
          param_C_2 => 'foo_A:val_C_2',
          param_C_3 => 'foo_B:val_C_3',
          param_C_4 => 'zoo:val_C_4',
        },
        [ 'bar_B:val_D_1',
          'bar_B:val_D_2',
        ],
      ],

      param_D => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
      },

      param_D_A => {
        param_D_1 => 'moo:val_D_A_1',
        param_D_2 => 'moo:val_D_A_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_A_5',
      },

      param_D_B => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_B_3',
        param_D_4 => 'moo:val_D_B_4',
        param_D_5 => 'moo:val_D_B_5',
      },

      param_D_C => {
        param_D_1 => 'moo:val_D_C_1',
        param_D_2 => 'moo:val_D_A_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_A_5',
        param_D_6 => 'moo:val_D_C_6',
      },

      param_D_D => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_D_3',
        param_D_4 => 'moo:val_D_B_4',
        param_D_5 => 'moo:val_D_B_5',
        param_D_6 => 'moo:val_D_D_6',
      },

      param_D_E => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_E_5',
      },

      param_D_F => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_F_5',
      },

      param_D_G => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_E_5',
        param_D_6 => 'moo:val_D_G_6',
      },

      param_D_H => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_F_5',
        param_D_6 => 'moo:val_D_H_6',
      },

      param_E => {
        param_E_1 => {
          param_E_1_2 => 'moo_A:val_E_1_2',
          param_E_1_1 => 'moo_A:val_E_1_1'
        },

        param_E_2 => {
          param_E_2_1 => 'moo_B:val_E_2_1',
          param_E_2_2 => 'moo_B:val_E_2_2'
        },

        param_E_3 => {
          param_E_1_1 => 'moo_A:val_E_1_1',
          param_E_1_2 => 'moo_A:val_E_1_2',
          param_E_2_1 => 'moo_B:val_E_2_1',
          param_E_2_2 => 'moo_B:val_E_2_2',
          param_F_6   => 'moo_C:val_F_6',
          param_F_7   => 'moo_C:val_F_7',
        },
      },

      param_F_A => {
        param_F_1 => 'moo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'moo:val_F_4',
        param_F_5 => 'moo:val_F_5',
        param_F_6 => 'moo:val_F_6',
        param_F_7 => 'moo_C:val_F_7',
      },

      param_F_B => {
        param_F_1 => 'moo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2'
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'moo:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
        param_F_6 => 'moo_C:val_F_6',
        param_F_7 => 'moo_C:val_F_7',
      },

      param_F_C => {
        param_F_1 => 'moo:val_F_C_1',
        param_F_2 => 'moo:val_F_C_2',
      },

      param_F_D => 'moo:val_F_D_2',

      param_F_E => {
        param_F_1 => 'moo:val_F_E_1',
        param_F_2 => 'moo:val_F_E_2',
      },

      param_F_F => 'moo:val_F_F_3',
    },
  };

  is_deeply( $t_config, $e_config, 'directive processing: on' );

  return;
}

sub t_directive_processing_off {
  my $config_loader = Config::Loader->new(
    dirs               => [ qw( t/etc ) ],
    process_directives => 0,
  );

  my $t_config = $config_loader->load(
      qw( foo_A.yaml foo_B.yml bar_A.json bar_B.jsn zoo.yml moo.yml ) );

  my $e_config = {
    foo => {
      param_A => 'foo_B:val_A',
      param_B => 'foo_A:val_B',

      param_D => [
        'foo_B:val_D_1',
        'foo_B:val_D_2',
      ],

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_E => [
        'foo_B:val_E_1',
        { param_E_2_1 => 'foo_B:val_E_2_1',
          param_E_2_2 => 'foo_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'foo_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    bar => {
      param_A => 'bar_B:val_A',
      param_B => 'bar_A:val_B',

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'bar_A:val_C_2',
        param_C_3 => 'bar_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_D => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_E => [
        'bar_B:val_E_1',
        { param_E_2_1 => 'bar_B:val_E_2_1',
          param_E_2_2 => 'bar_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'bar_B:val_F_2_1',
          'bar_B:val_F_2_2',
        ],
        param_F_3 => 'bar_A:val_F_3',
        param_F_4 => 'bar_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    moo => {
      param_A => { var => 'foo.param_C' },
      param_B => { var => 'bar.param_D' },

      param_C => [
        { var => 'foo.param_C' },
        { var => 'bar.param_D' },
      ],

      param_D => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
      },

      param_D_A => {
        underlay  => { var => 'moo.param_D' },
        param_D_1 => 'moo:val_D_A_1',
        param_D_2 => 'moo:val_D_A_2',
        param_D_5 => 'moo:val_D_A_5',
      },

      param_D_B => {
        underlay  => { var => 'moo.param_D' },
        param_D_3 => 'moo:val_D_B_3',
        param_D_4 => 'moo:val_D_B_4',
        param_D_5 => 'moo:val_D_B_5',
      },

      param_D_C => {
        underlay  => { var => 'moo.param_D_A' },
        param_D_1 => 'moo:val_D_C_1',
        param_D_6 => 'moo:val_D_C_6',
      },

      param_D_D => {
        underlay  => { var => 'moo.param_D_B' },
        param_D_3 => 'moo:val_D_D_3',
        param_D_6 => 'moo:val_D_D_6',
      },

      param_D_E => {
        param_D_1 => 'moo:val_D_E_1',
        param_D_2 => 'moo:val_D_E_2',
        param_D_5 => 'moo:val_D_E_5',
        overlay   => { var => 'moo.param_D' },
      },

      param_D_F => {
        param_D_3 => 'moo:val_D_F_3',
        param_D_4 => 'moo:val_D_F_4',
        param_D_5 => 'moo:val_D_F_5',
        overlay   => { var => 'moo.param_D' },
      },

      param_D_G => {
        param_D_1 => 'moo:val_D_G_1',
        param_D_6 => 'moo:val_D_G_6',
        overlay   => { var => 'moo.param_D_E' },
      },

      param_D_H => {
        param_D_3 => 'moo:val_D_H_3',
        param_D_6 => 'moo:val_D_H_6',
        overlay   => { var => 'moo.param_D_F' },
      },

      param_E => {
        param_E_1 => { include => 'includes/moo_A.yml' },
        param_E_2 => { include => 'includes/moo_B.json' },
        param_E_3 => { include => 'includes/*' },
      },

      param_F_A => {
        underlay => [
          { var     => 'foo.param_F' },
          { include => 'includes/moo_C.yml' },
          { param_F_1 => 'moo:val_F_1',
            param_F_4 => 'moo:val_F_4',
          },
        ],
        param_F_5 => 'moo:val_F_5',
        param_F_6 => 'moo:val_F_6',
      },

      param_F_B => {
        param_F_5 => 'moo:val_F_5',
        param_F_6 => 'moo:val_F_6',
        overlay => [
          { var     => 'foo.param_F' },
          { include => 'includes/moo_C.yml' },
          { param_F_1 => 'moo:val_F_1',
            param_F_4 => 'moo:val_F_4',
          }
        ],
      },

      param_F_C => {
        underlay  => [
          'moo:val_F_C_1',
          'moo:val_F_C_2',
        ],
        param_F_2 => 'moo:val_F_C_2',
        param_F_1 => 'moo:val_F_C_1',
      },

       param_F_D => {
        param_F_1 => 'moo:val_F_D_1',
        param_F_2 => 'moo:val_F_D_2',
        overlay   => [
          'moo:val_F_D_1',
          'moo:val_F_D_2',
        ],
      },

      param_F_E => {
        underlay  => 'moo:val_F_E_3',
        param_F_1 => 'moo:val_F_E_1',
        param_F_2 => 'moo:val_F_E_2',
      },

      param_F_F => {
        param_F_1 => 'moo:val_F_F_1',
        param_F_2 => 'moo:val_F_F_2',
        overlay   => 'moo:val_F_F_3',
      },
    },
  };

  is_deeply( $t_config, $e_config, 'directive processing: off' );

  return;
}

sub t_complete_processing {
  my $config_loader = shift;

  my $t_config = $config_loader->load(
      qw( foo_A.yaml foo_B.yml bar_A.json bar_B.jsn zoo.yml jar.json moo.yml
      yar.yml ) );

  my $e_config = {
    foo => {
      param_A => 'foo_B:val_A',
      param_B => 'foo_A:val_B',

      param_D => [
        'foo_B:val_D_1',
        'foo_B:val_D_2',
      ],

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_E => [
        'foo_B:val_E_1',
        { param_E_2_1 => 'foo_B:val_E_2_1',
          param_E_2_2 => 'foo_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'foo_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    bar => {
      param_A => 'bar_B:val_A',
      param_B => 'bar_A:val_B',

      param_C => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'bar_A:val_C_2',
        param_C_3 => 'bar_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_D => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_E => [
        'bar_B:val_E_1',
        { param_E_2_1 => 'bar_B:val_E_2_1',
          param_E_2_2 => 'bar_B:val_E_2_2',
        }
      ],

      param_F => {
        param_F_1 => 'zoo:val_F_1',
        param_F_2 => [
          'bar_B:val_F_2_1',
          'bar_B:val_F_2_2',
        ],
        param_F_3 => 'bar_A:val_F_3',
        param_F_4 => 'bar_B:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
      },
    },

    jar => {
      param_A => 'jar:foo_B:val_A',
      param_B => 'jar:foo_A:val_B; jar:bar_A:val_B',

      param_C => {
        param_C_1 => 'jar:zoo:val_C_1; jar:bar_B:val_C_3',
        param_C_2 => 'jar:foo_B:val_C_3; jar:zoo:val_C_1',
      },

      param_D => [
        'jar:foo_B:val_D_1; jar:bar_B:val_D_2',
        'jar:bar_B:val_D_2; jar:foo_B:val_D_1',
        'jar:foo_B:val_F_2_1; jar:bar_B:val_F_2_2',
        'jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',
        'jar:zoo:val_F_5_1; jar:zoo:val_F_5_2',
      ],

      param_E => [
        'jar:jar:foo_B:val_A; jar:jar:foo_A:val_B; jar:bar_A:val_B',
        { param_E_2_2 => 'jar:jar:foo_B:val_D_1; jar:bar_B:val_D_2;'
              . ' jar:jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',
          param_E_2_1 => 'jar:jar:zoo:val_C_1; jar:bar_B:val_C_3;'
              . ' jar:jar:foo_B:val_C_3; jar:zoo:val_C_1',
        },
        'jar:jar:bar_B:val_D_2; jar:foo_B:val_D_1; jar:jar:zoo:val_F_5_1;'
            . ' jar:zoo:val_F_5_2',
      ],

      param_F => {
        param_F_1 =>
            'jar:jar:jar:foo_B:val_A; jar:jar:foo_A:val_B; jar:bar_A:val_B;'
                .' jar:jar:jar:zoo:val_C_1; jar:bar_B:val_C_3;'
                .' jar:jar:foo_B:val_C_3; jar:zoo:val_C_1',
        param_F_2 => [
          'jar:jar:jar:foo_B:val_D_1; jar:bar_B:val_D_2;'
              . ' jar:jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',
          'jar:jar:jar:bar_B:val_D_2; jar:foo_B:val_D_1;'
              . ' jar:jar:zoo:val_F_5_1; jar:zoo:val_F_5_2',
        ],
        param_F_3 => 'jar:jar:jar:jar:foo_B:val_D_1; jar:bar_B:val_D_2;'
            . ' jar:jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',

        param_F_4 => 'jar:${foo.param_A}',

        param_F_5 => 'jar:',
        param_F_6 => 'jar:',
        param_F_7 => 'jar:',
        param_F_8 => 'jar:',
      },
    },

    moo => {
      param_A => {
        param_C_1 => 'zoo:val_C_1',
        param_C_2 => 'foo_A:val_C_2',
        param_C_3 => 'foo_B:val_C_3',
        param_C_4 => 'zoo:val_C_4',
      },

      param_B => [
        'bar_B:val_D_1',
        'bar_B:val_D_2',
      ],

      param_C => [
        { param_C_1 => 'zoo:val_C_1',
          param_C_2 => 'foo_A:val_C_2',
          param_C_3 => 'foo_B:val_C_3',
          param_C_4 => 'zoo:val_C_4',
        },
        [ 'bar_B:val_D_1',
          'bar_B:val_D_2',
        ],
      ],

      param_D => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
      },

      param_D_A => {
        param_D_1 => 'moo:val_D_A_1',
        param_D_2 => 'moo:val_D_A_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_A_5',
      },

      param_D_B => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_B_3',
        param_D_4 => 'moo:val_D_B_4',
        param_D_5 => 'moo:val_D_B_5',
      },

      param_D_C => {
        param_D_1 => 'moo:val_D_C_1',
        param_D_2 => 'moo:val_D_A_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_A_5',
        param_D_6 => 'moo:val_D_C_6',
      },

      param_D_D => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_D_3',
        param_D_4 => 'moo:val_D_B_4',
        param_D_5 => 'moo:val_D_B_5',
        param_D_6 => 'moo:val_D_D_6',
      },

      param_D_E => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_E_5',
      },

      param_D_F => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_F_5',
      },

      param_D_G => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_E_5',
        param_D_6 => 'moo:val_D_G_6',
      },

      param_D_H => {
        param_D_1 => 'moo:val_D_1',
        param_D_2 => 'moo:val_D_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_F_5',
        param_D_6 => 'moo:val_D_H_6',
      },

      param_E => {
        param_E_1 => {
          param_E_1_2 => 'moo_A:val_E_1_2',
          param_E_1_1 => 'moo_A:val_E_1_1'
        },

        param_E_2 => {
          param_E_2_1 => 'moo_B:val_E_2_1',
          param_E_2_2 => 'moo_B:val_E_2_2'
        },

        param_E_3 => {
          param_E_1_1 => 'moo_A:val_E_1_1',
          param_E_1_2 => 'moo_A:val_E_1_2',
          param_E_2_1 => 'moo_B:val_E_2_1',
          param_E_2_2 => 'moo_B:val_E_2_2',
          param_F_6   => 'moo_C:val_F_6',
          param_F_7   => 'moo_C:val_F_7',
        },
      },

      param_F_A => {
        param_F_1 => 'moo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'moo:val_F_4',
        param_F_5 => 'moo:val_F_5',
        param_F_6 => 'moo:val_F_6',
        param_F_7 => 'moo_C:val_F_7',
      },

      param_F_B => {
        param_F_1 => 'moo:val_F_1',
        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2'
        ],
        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'moo:val_F_4',
        param_F_5 => [
          'zoo:val_F_5_1',
          'zoo:val_F_5_2',
        ],
        param_F_6 => 'moo_C:val_F_6',
        param_F_7 => 'moo_C:val_F_7',
      },

      param_F_C => {
        param_F_1 => 'moo:val_F_C_1',
        param_F_2 => 'moo:val_F_C_2',
      },

      param_F_D => 'moo:val_F_D_2',

      param_F_E => {
        param_F_1 => 'moo:val_F_E_1',
        param_F_2 => 'moo:val_F_E_2',
      },

      param_F_F => 'moo:val_F_F_3',
    },

    yar => {
      param_A => {
        param_A_1 => 'yar_A:jar:jar:zoo:val_C_1; jar:bar_B:val_C_3;'
            . ' jar:jar:foo_B:val_C_3; jar:zoo:val_C_1',

        param_A_2 => [
          { param_C_1 => 'zoo:val_C_1',
            param_C_2 => 'foo_A:val_C_2',
            param_C_3 => 'foo_B:val_C_3',
            param_C_4 => 'zoo:val_C_4',
          },
          [ 'bar_B:val_D_1',
            'bar_B:val_D_2',
          ]
        ],

        param_A_3 => {
          param_E_1_2 => 'moo_A:val_E_1_2',
          param_E_1_1 => 'moo_A:val_E_1_1'
        },

        param_A_4 => 'yar:jar:jar:jar:foo_B:val_D_1; jar:bar_B:val_D_2;'
            . ' jar:jar:bar_B:val_F_2_2; jar:foo_B:val_F_2_1',

        param_A_5 => 'yar:val_A_5',
        param_A_6 => 'yar:jar:foo_B:val_A',
        param_A_7 => 'yar:val_A_7',
        param_A_8 => 'yar:jar:foo_A:val_B; jar:bar_A:val_B',
        param_A_9 => 'yar:val_A_9',

        param_D_1 => 'moo:val_D_A_1',
        param_D_2 => 'moo:val_D_A_2',
        param_D_3 => 'moo:val_D_3',
        param_D_4 => 'moo:val_D_4',
        param_D_5 => 'moo:val_D_A_5',

        param_E_1 => {
          param_E_1_1 => 'moo_A:val_E_1_1',
          param_E_1_2 => 'moo_A:val_E_1_2',
        },

        param_E_2 => {
          param_E_2_1 => 'moo_B:val_E_2_1',
          param_E_2_2 => 'moo_B:val_E_2_2',
        },

        param_E_3 => {
          param_E_1_1 => 'moo_A:val_E_1_1',
          param_E_1_2 => 'moo_A:val_E_1_2',
          param_E_2_2 => 'moo_B:val_E_2_2',
          param_E_2_1 => 'moo_B:val_E_2_1',
          param_F_6   => 'moo_C:val_F_6',
          param_F_7   => 'moo_C:val_F_7',
        },

        param_F_1 => 'moo:val_F_1',

        param_F_2 => [
          'foo_B:val_F_2_1',
          'foo_B:val_F_2_2',
        ],

        param_F_3 => 'foo_A:val_F_3',
        param_F_4 => 'moo:val_F_4',
        param_F_5 => 'moo:val_F_5',
        param_F_6 => 'moo:val_F_6',
        param_F_7 => 'moo_C:val_F_7',
      },
    },
  };

  is_deeply( $t_config, $e_config, 'complete processing' );

  return;
}
