#!/usr/bin/perl

use strict;
use warnings;
BEGIN {
	$|  = 1;
}

use Test::Perl::Dist 0.203;

#####################################################################
# Complete Generation Run

# Create the dist object
my $dist = Test::Perl::Dist->new_test_class_long(
	999, '5101', 'Perl::Dist::WiX', 
	portable => 1,
	user_agent_cache  => 0,
);

test_run_dist( $dist );

test_verify_files_long(999, '510');

test_verify_portability(999, $dist->output_base_filename());

test_cleanup(999);

done_testing();

