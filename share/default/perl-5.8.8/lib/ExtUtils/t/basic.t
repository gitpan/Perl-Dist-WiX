#!/usr/bin/perl -w

# This test puts MakeMaker through the paces of a basic perl module
# build, test and installation of the Big::Fat::Dummy module.

# **** NOTE - This is a stripped down version of EU::MM's t/basic.t ****
# **** Do NOT copy this file into the Perl source tree! ****


BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use Config;

use Test::More tests => 55;
use MakeMaker::Test::Utils;
use MakeMaker::Test::Setup::BFD;
use File::Find;
use File::Spec;
use File::Path;

# 'make disttest' sets a bunch of environment variables which interfere
# with our testing.
delete @ENV{qw(PREFIX LIB MAKEFLAGS)};

my $perl = which_perl();
my $Is_VMS = $^O eq 'VMS';

# GNV logical interferes with testing
$ENV{'bin'} = '[.bin]' if $Is_VMS;

chdir 't';

perl_lib;

my $Touch_Time = calibrate_mtime();

$| = 1;

ok( setup_recurs(), 'setup' );
END {
    ok( chdir File::Spec->updir );
    ok( teardown_recurs(), 'teardown' );
}

ok( chdir('Big-Dummy'), "chdir'd to Big-Dummy" ) ||
  diag("chdir failed: $!");

my @mpl_out = run(qq{$perl Makefile.PL "PREFIX=../dummy-install"});
END { rmtree '../dummy-install'; }

cmp_ok( $?, '==', 0, 'Makefile.PL exited with zero' ) ||
  diag(@mpl_out);

my $makefile = makefile_name();
ok( grep(/^Writing $makefile for Big::Dummy/, 
         @mpl_out) == 1,
                                           'Makefile.PL output looks right');

ok( grep(/^Current package is: main$/,
         @mpl_out) == 1,
                                           'Makefile.PL run in package main');

ok( -e $makefile,       'Makefile exists' );

# -M is flakey on VMS
my $mtime = (stat($makefile))[9];
cmp_ok( $Touch_Time, '<=', $mtime,  '  its been touched' );

END { unlink makefile_name(), makefile_backup() }

my $make = make_run();

{
    # Supress 'make manifest' noise
    local $ENV{PERL_MM_MANIFEST_VERBOSE} = 0;
    my $manifest_out = run("$make manifest");
    ok( -e 'MANIFEST',      'make manifest created a MANIFEST' );
    ok( -s 'MANIFEST',      '  its not empty' );
}

END { unlink 'MANIFEST'; }

my $test_out = run("$make test");
like( $test_out, qr/All tests successful/, 'make test' );
is( $?, 0,                                 '  exited normally' ) || 
    diag $test_out;

# Test 'make test TEST_VERBOSE=1'
my $make_test_verbose = make_macro($make, 'test', TEST_VERBOSE => 1);
$test_out = run("$make_test_verbose");
like( $test_out, qr/ok \d+ - TEST_VERBOSE/, 'TEST_VERBOSE' );
like( $test_out, qr/All tests successful/,  '  successful' );
is( $?, 0,                                  '  exited normally' ) ||
    diag $test_out;


my $install_out = run("$make install");
is( $?, 0, 'install' ) || diag $install_out;
like( $install_out, qr/^Installing /m );
like( $install_out, qr/^Writing /m );

ok( -r '../dummy-install',     '  install dir created' );
my %files = ();
find( sub { 
    # do it case-insensitive for non-case preserving OSs
    my $file = lc $_;

    # VMS likes to put dots on the end of things that don't have them.
    $file =~ s/\.$// if $Is_VMS;

    $files{$file} = $File::Find::name; 
}, '../dummy-install' );
ok( $files{'dummy.pm'},     '  Dummy.pm installed' );
ok( $files{'liar.pm'},      '  Liar.pm installed'  );
ok( $files{'program'},      '  program installed'  );
ok( $files{'.packlist'},    '  packlist created'   );
ok( $files{'perllocal.pod'},'  perllocal.pod created' );


SKIP: {
    skip 'VMS install targets do not preserve $(PREFIX)', 9 if $Is_VMS;

    $install_out = run("$make install PREFIX=elsewhere");
    is( $?, 0, 'install with PREFIX override' ) || diag $install_out;
    like( $install_out, qr/^Installing /m );
    like( $install_out, qr/^Writing /m );

    ok( -r 'elsewhere',     '  install dir created' );
    %files = ();
    find( sub { $files{$_} = $File::Find::name; }, 'elsewhere' );
    ok( $files{'Dummy.pm'},     '  Dummy.pm installed' );
    ok( $files{'Liar.pm'},      '  Liar.pm installed'  );
    ok( $files{'program'},      '  program installed'  );
    ok( $files{'.packlist'},    '  packlist created'   );
    ok( $files{'perllocal.pod'},'  perllocal.pod created' );
    rmtree('elsewhere');
}


SKIP: {
    skip 'VMS install targets do not preserve $(DESTDIR)', 11 if $Is_VMS;

    $install_out = run("$make install PREFIX= DESTDIR=other");
    is( $?, 0, 'install with DESTDIR' ) || 
        diag $install_out;
    like( $install_out, qr/^Installing /m );
    like( $install_out, qr/^Writing /m );

    ok( -d 'other',  '  destdir created' );
    %files = ();
    my $perllocal;
    find( sub { 
        $files{$_} = $File::Find::name;
    }, 'other' );
    ok( $files{'Dummy.pm'},     '  Dummy.pm installed' );
    ok( $files{'Liar.pm'},      '  Liar.pm installed'  );
    ok( $files{'program'},      '  program installed'  );
    ok( $files{'.packlist'},    '  packlist created'   );
    ok( $files{'perllocal.pod'},'  perllocal.pod created' );

    ok( open(PERLLOCAL, $files{'perllocal.pod'} ) ) || 
        diag("Can't open $files{'perllocal.pod'}: $!");
    { local $/;
      unlike(<PERLLOCAL>, qr/other/, 'DESTDIR should not appear in perllocal');
    }
    close PERLLOCAL;

# TODO not available in the min version of Test::Harness we require
#    ok( open(PACKLIST, $files{'.packlist'} ) ) || 
#        diag("Can't open $files{'.packlist'}: $!");
#    { local $/;
#      local $TODO = 'DESTDIR still in .packlist';
#      unlike(<PACKLIST>, qr/other/, 'DESTDIR should not appear in .packlist');
#    }
#    close PACKLIST;

    rmtree('other');
}


SKIP: {
    skip 'VMS install targets do not preserve $(PREFIX)', 10 if $Is_VMS;

    $install_out = run("$make install PREFIX=elsewhere DESTDIR=other/");
    is( $?, 0, 'install with PREFIX override and DESTDIR' ) || 
        diag $install_out;
    like( $install_out, qr/^Installing /m );
    like( $install_out, qr/^Writing /m );

    ok( !-d 'elsewhere',       '  install dir not created' );
    ok( -d 'other/elsewhere',  '  destdir created' );
    %files = ();
    find( sub { $files{$_} = $File::Find::name; }, 'other/elsewhere' );
    ok( $files{'Dummy.pm'},     '  Dummy.pm installed' );
    ok( $files{'Liar.pm'},      '  Liar.pm installed'  );
    ok( $files{'program'},      '  program installed'  );
    ok( $files{'.packlist'},    '  packlist created'   );
    ok( $files{'perllocal.pod'},'  perllocal.pod created' );
    rmtree('other');
}
