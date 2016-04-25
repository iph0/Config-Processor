#!/usr/bin/env perl

use strict;
use warnings;

use Config::Processor;
use Data::Dumper;

my $config_processor = Config::Processor->new(
  dirs => [ qw( examples/etc ) ],
);

# Load all configuration sections
my $config = $config_processor->load(
  qw( users.yml db.json passwords/* pathes.yml ),

  { db => {
      frontend_master => {
        host => 'localhost',
        port => '5000',
      },

      frontend_slave => {
        host => 'localhost',
        port => '5000',
      }
    },
  }
);

# Print full config tree
print Dumper( $config );
