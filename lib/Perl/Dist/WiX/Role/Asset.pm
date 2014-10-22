package Perl::Dist::WiX::Role::Asset;

=pod

=head1 NAME

Perl::Dist::WiX::Role::Asset - Role for assets.

=head1 VERSION

This document describes Perl::Dist::WiX::Role::Asset version 1.200.

=head1 SYNOPSIS

	# Since this is a role, it is composed into classes that use it.
	# It is not used independently.
	
=head1 DESCRIPTION

B<Perl::Dist::WiX::Role::Asset> is a role that provides methods,
attributes, and error checking for assets to be installed in a 
L<Perl::Dist::WiX|Perl::Dist::WiX>-based Perl distribution.

=cut

# Convenience role for Perl::Dist::WiX assets

use 5.008001;
use Moose::Role;
use File::Spec::Functions qw( rel2abs catdir catfile );
use MooseX::Types::Moose qw( Str );
use Params::Util qw( _INSTANCE );
use English qw( -no_match_vars );
require File::List::Object;
require File::ShareDir;
require File::Spec::Unix;
require Perl::Dist::WiX::Exceptions;
require URI;
require URI::file;

our $VERSION = '1.200';
$VERSION =~ s/_//ms;

=head1 ATTRIBUTES

Attributes of this role also become parameters to the new() constructor for 
classes that use this role.

=head2 parent

This is the L<Perl::Dist::WiX|Perl::Dist::WiX> object that uses an asset 
object that uses this role. The Perl::Dist::WiX object handles a number 
of private methods for the asset object.

It is required, and has no default, so an error will be thrown if it is not 
given.

=cut



has parent => (
	is       => 'ro',
	isa      => 'Perl::Dist::WiX',
	reader   => '_get_parent',
	weak_ref => 1,
	handles  => {
		'_get_image_dir',   => 'image_dir',
		'_get_download_dir' => 'download_dir',
		'_get_output_dir'   => 'output_dir',
		'_get_modules_dir'  => 'modules_dir',
		'_get_license_dir'  => 'license_dir',
		'_get_build_dir'    => 'build_dir',
		'_get_cpan'         => 'cpan',
		'_get_bin_perl'     => 'bin_perl',
		'_get_wix_dist_dir' => 'wix_dist_dir',
		'_get_icons'        => '_icons',
		'_get_pv_human'     => 'perl_version_human',
		'_module_fix'       => '_module_fix',
		'_trace_line'       => 'trace_line',
		'_mirror'           => 'mirror_url',
		'_mirror_url'       => 'mirror_url',
		'_run3'             => 'execute_any',
		'_filters'          => '_filters',
		'_add_icon'         => 'add_icon',
		'_add_file'         => 'add_file',
		'_copy'             => 'copy_file',
		'_extract'          => 'extract_archive',
		'_extract_filemap'  => '_extract_filemap',
		'_insert_fragment'  => 'insert_fragment',
		'_patch_file'       => 'patch_file',
		'_pushd'            => 'push_dir',
		'_perl'             => 'execute_perl',
		'_build'            => 'execute_build',
		'_make'             => 'execute_make',
		'_gcc_version'      => 'gcc_version',
		'_relocatable'      => 'relocatable',
		'_force'            => 'force',
		'_forceperl'        => 'forceperl',
		'_add_to_distributions_installed' =>
		  '_add_to_distributions_installed',
	},
	required => 1,
);



=head2 url

This attribute is the location on the Internet of the thing the asset 
installs.

Either the 'url' or 'file' parameters are required.

=cut

has url => (
	is       => 'bare',
	isa      => Str,
	reader   => '_get_url',
	writer   => '_set_url',
	required => 1,
);



=head2 file

This attribute is the location of the file the asset installs. This could be 
an archive containing multiple files to install.

Either the 'url' or 'file' parameters are required.

=cut



has file => (
	is       => 'bare',
	isa      => Str,
	reader   => '_get_file',
	required => 1,
);



=head1 METHODS

=head2 install

This role requires that classes that use it implement an C<install> method
that installs the asset.

It does not provide the method itself, but makes classes that use the role
implement the method based on their needs.

=cut



# An asset knows how to install itself.
requires 'install';



sub BUILDARGS {
	my $class = shift;
	my %args;

	# get the argument hash set up.
	if ( @_ == 1 && 'HASH' eq ref $_[0] ) {
		%args = %{ $_[0] };
	} elsif ( 0 == @_ % 2 ) {
		%args = (@_);
	} else {
		PDWiX->throw(
			'Parameters incorrect (not a hashref or hash) for ::Asset::*');
	}

	# Validate 'parent' parameter early.
	my $parent = $args{parent};
	unless ( defined _INSTANCE( $args{parent}, 'Perl::Dist::WiX' ) ) {
		PDWiX::Parameter->throw(
			parameter =>
			  'parent: missing or not a Perl::Dist::WiX instance',
			where => '::Role::Asset->new',
		);
	}

	unless ( defined $args{url} ) {
		if ( defined $args{share} ) {

			# Map share to url vis File::ShareDir
			my ( $dist, $name ) = split /\s+/ms, $args{share};
			$parent->trace_line( 2, "Finding $name in $dist... " );
			my $file = rel2abs( File::ShareDir::dist_file( $dist, $name ) );
			unless ( -f $file ) {
				PDWiX->throw("Failed to find $file");
			}
			$args{url} = URI::file->new($file)->as_string();
			$parent->trace_line( 2, " found\n" );

		} elsif ( defined $args{name} ) {

			PDWiX->throw(q{'name' without 'url' is deprecated});

			# Map name to URL via the default package path
			$args{url} = $parent->binary_url( $args{name} );
		}
	} ## end unless ( defined $args{url...})

	if ( $class ne 'Perl::Dist::WiX::Asset::DistFile' ) {

		# Create the filename from the url
		$args{file} = $args{url};
		$args{file} =~ s{.+/}{}ms;
		unless ( defined $args{file} and length $args{file} ) {
			if ( $class ne 'Perl::Dist::WiX::Asset::Website' ) {
				PDWiX::Parameter->throw(
					parameter => 'file',
					where     => '::Role::Asset->new'
				);
			} else {

				# file is not used in Websites.
				$args{file} = q{ };
			}
		} ## end unless ( defined $args{file...})
	} else {
		$args{url} = q{ };
	}

	my %default_args = (
		url    => $args{url},
		file   => $args{file},
		parent => $args{parent},
	);
	delete @args{ 'url', 'file', 'parent' };

	# Miscaught by Perl::Critic.
	## no critic (ProhibitCommaSeparatedStatements)
	return { (%default_args), (%args) };
} ## end sub BUILDARGS



sub _search_packlist {
	my ( $self, $module ) = @_;

	# We don't use the error until later, if needed.
	my $error = <<"EOF";
No .packlist found for $module.

Please set packlist => 0 when calling install_distribution or 
install_module for this module.  If this is in an install_modules 
list, please take it out of the list, creating two lists if need 
be, and create an install_module call for this module with 
packlist => 0.
EOF
	chomp $error;

	# Get all the filenames and directory names required.
	my $image_dir   = $self->_get_image_dir();
	my @module_dirs = split /::/ms, $module;
	my @dirs        = (
		catdir( $image_dir, qw{perl vendor lib auto}, @module_dirs ),
		catdir( $image_dir, qw{perl site   lib auto}, @module_dirs ),
		catdir( $image_dir, qw{perl        lib auto}, @module_dirs ),
	);

	# What file exists, if any?
	my $packlist;
  DIR:
	foreach my $dir (@dirs) {
		$packlist = catfile( $dir, '.packlist' );
		last DIR if -r $packlist;
	}

	my $filelist;
	if ( -r $packlist ) {

		# Load a filelist object from the packlist if one exists.
		$filelist =
		  File::List::Object->new()->load_file($packlist)
		  ->add_file($packlist);
	} else {

		# Read the output from installing the module.
		my $output = catfile( $self->_get_output_dir(), 'debug.out' );
		$self->_trace_line( 3,
			"Attempting to use debug.out file to make filelist\n" );
		my $fh = IO::File->new( $output, 'r' );

		if ( not defined $fh ) {
			PDWiX->throw("Error reading output file $output: $OS_ERROR");
		}
		my @output_list = <$fh>;
		$fh->close();

		# Parse the output read in for filenames.
		my @files_list =
		  map { ## no critic 'ProhibitComplexMappings'
			my $t = $_;
			chomp $t;
			( $t =~ / \A Installing [ ] (.*) \z /msx ) ? ($1) : ();
		  } @output_list;

		# Load the filenames into the filelist object.
		if ( $#files_list == 0 ) {

			# Throw an error if no files were found.
			PDWiX->throw($error);
		} else {
			$self->_trace_line( 4, "Adding files:\n" );
			$self->_trace_line( 4, q{  } . join "\n  ", @files_list );
			$filelist = File::List::Object->new()->load_array(@files_list);
		}
	} ## end else [ if ( -r $packlist ) ]

	# Return the filelist processed therough the filters.
	return $filelist->filter( $self->_filters() );
} ## end sub _search_packlist


1;

__END__

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Perl-Dist-WiX>

For other issues, contact the author.

=head1 AUTHOR

Curtis Jewell E<lt>csjewell@cpan.orgE<gt>

=head1 SEE ALSO

L<Perl::Dist::WiX|Perl::Dist::WiX>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 - 2010 Curtis Jewell.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
