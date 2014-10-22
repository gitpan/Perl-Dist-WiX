#!/usr/bin/perl

# Test that the syntax of our POD documentation is valid

use strict;

BEGIN {
	use English qw(-no_match_vars);
	$OUTPUT_AUTOFLUSH = 1;
	$WARNING = 1;
}

my @MODULES = (
	'Pod::Simple 3.07',
	'Test::Pod 1.41',
);

# Load the testing modules
use Test::More;
foreach my $MODULE ( @MODULES ) {
	eval "use $MODULE";
	if ( $EVAL_ERROR ) {
		BAIL_OUT( "Failed to load required release-testing module $MODULE" )
	}
}

%Test::Pod::ignore_dirs = %Test::Pod::ignore_dirs = (
    '.bzr'  => 'Bazaar',
    '.git'  => 'Git',
    '.hg'   => 'Mercurial',
    '.pc'   => 'quilt',
    '.svn'  => 'Subversion',
    CVS     => 'CVS',
    RCS     => 'RCS',
    SCCS    => 'SCCS',
    _darcs  => 'darcs',
    _sgbak  => 'Vault/Fortress',
	default => 'Perl::Dist::WiX default patch files directory'	
);

my @files = sort { $a cmp $b } all_pod_files();

all_pod_files_ok( @files );
