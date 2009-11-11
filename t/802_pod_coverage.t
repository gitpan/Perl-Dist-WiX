#!perl

# Test that modules are documented by their pod.

use strict;

sub filter {
	my $module = shift;
	
	return 0 if $module =~ m/auto::share::dist/;
	return 0 if $module =~ m/::Fragment::/;	# For now.
	return 1;
}

BEGIN {
	use English qw(-no_match_vars);
	$OUTPUT_AUTOFLUSH = 1;
	$WARNING = 1;
}

my @MODULES = (
	'Pod::Coverage::Moose 0.01',
	'Pod::Coverage 0.20',
	'Test::Pod::Coverage 1.08',
);

# Don't run tests for installs
use Test::More;
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan( skip_all => "Author tests not required for installation" );
}

# Load the testing modules
foreach my $MODULE ( @MODULES ) {
	eval "use $MODULE";
	if ( $EVAL_ERROR ) {
		$ENV{RELEASE_TESTING}
		? BAIL_OUT( "Failed to load required release-testing module $MODULE" )
		: plan( skip_all => "$MODULE not available for testing" );
	}
}

plan( skip_all => "It's worked so far, but we're not out yet." );

my @modules = all_modules();
my @modules_to_test = grep { filter($_) } @modules;
my $test_count = scalar @modules_to_test;
plan( tests => $test_count );

foreach my $module (@modules_to_test) {
	pod_coverage_ok($module, { 
	  coverage_class => 'Pod::Coverage::Moose', 
	  also_private => [ qr/^[A-Z_]+$/ ],
	  trustme => [ qw(prepare delegate) ]
	});
}