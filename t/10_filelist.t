#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More;
use File::Spec::Functions qw(catfile curdir catdir rel2abs);

my @file = (
    catfile( rel2abs(curdir()), qw(t test10 file1.txt)),
    catfile( rel2abs(curdir()), qw(t test10 file2.txt)),
    catfile( rel2abs(curdir()), qw(t test10 file3.txt)),
    catfile( rel2abs(curdir()), qw(t test10 excluded file1.txt)),
    catfile( rel2abs(curdir()), qw(t test10 excluded file2.txt)),    
    catfile( rel2abs(curdir()), qw(t test10 dir2 file1.txt)),    # dir2 deliberately does not exist.
    catfile( rel2abs(curdir()), qw(t test10 dir2 file2.txt)),    
    catfile( rel2abs(curdir()), qw(t test10 dir3 file3.txt)),    
);

BEGIN {
	if ( $^O eq 'MSWin32' ) {
		plan tests => 13;
	} else {
		plan skip_all => 'Not on Win32';
	}
}

use_ok( 'Perl::Dist::WiX::Filelist' );

is( Perl::Dist::WiX::Filelist->new->add_file($file[0])->as_string, 
    $file[0],
    'adding single file' );

is( Perl::Dist::WiX::Filelist->new->load_array(@file[1, 2])->as_string, 
    "$file[1]\n$file[2]",
    'adding array' );

is( Perl::Dist::WiX::Filelist->new->load_array(@file[1, 2, 5])->as_string, 
    "$file[1]\n$file[2]",
    'adding array with missing files' );
    
my $add1 = Perl::Dist::WiX::Filelist->new->add_file($file[0]);
my $add2 = Perl::Dist::WiX::Filelist->new->add_file($file[1]);

is( $add1->add($add2)->as_string,
    "$file[0]\n$file[1]",
    'addition' );
    
my $sub1 = Perl::Dist::WiX::Filelist->new->add_file($file[0])->add_file($file[1])
    ->add_file($file[2]);
my $sub2 = Perl::Dist::WiX::Filelist->new->add_file($file[1]);

is( $sub1->subtract($sub2)->as_string,
    "$file[0]\n$file[2]",
    'subtraction' );

my $filter = Perl::Dist::WiX::Filelist->new->load_array(@file);
my $re_1 = catdir( rel2abs(curdir()), qw(t test10 excluded));
my $re_2 = catdir( rel2abs(curdir()), qw(t test10 dir3));

is( $filter->filter([$re_1, $re_2])->as_string,
    "$file[0]\n$file[1]\n$file[2]",
    'filtering'); 

is( $filter->count, 3, 'counting');

is( $filter->clear->count, 0, 'clearing');
    
is (Perl::Dist::WiX::Filelist->new->add_file($file[0])->move($file[0], $file[6])->as_string,
    $file[6],
    'move a file' );

is (Perl::Dist::WiX::Filelist->new->load_array(@file[0, 1])
    ->move_dir(
        catdir( rel2abs(curdir()), qw(t test10)),
        catdir( rel2abs(curdir()), qw(t test10 dir2)))
    ->as_string,
    "$file[5]\n$file[6]",
    'move a directory' );
    
# Need to create a packlist
my $packlist_file = catfile(rel2abs(curdir()), qw(t test10 filelist.txt));
my $fh;
my $answer = open $fh, '>', $packlist_file;
if ($answer) {
    print $fh "$file[0]\n$file[2]\n$file[1]\n";
    close $fh;

    is (Perl::Dist::WiX::Filelist->new->load_file($packlist_file)->as_string,
        "$file[0]\n$file[1]\n$file[2]",
        'reading from packlist file' );

} else {
    fail('reading from packlist file'); 
    diag('Could not create packlist in test directory.');
}

is( Perl::Dist::WiX::Filelist->new->load_array(@file[1, 2, 3, 7])->as_string, 
    "$file[7]\n$file[3]\n$file[1]\n$file[2]",
    'as_string with mixed directories' );


