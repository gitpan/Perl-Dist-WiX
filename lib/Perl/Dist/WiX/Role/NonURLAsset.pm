package Perl::Dist::WiX::Role::NonURLAsset;

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

our $VERSION = '1.100';
$VERSION = eval $VERSION; ## no critic (ProhibitStringyEval)

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
		'_get_dist_dir'     => 'dist_dir',
		'_get_cpan'         => 'cpan',
		'_get_bin_perl'     => 'bin_perl',
		'_get_wix_dist_dir' => 'wix_dist_dir',
		'_get_icons'        => 'icons',
		'_get_pv_human'     => 'perl_version_human',
		'_module_fix'       => '_module_fix',
		'_trace_line'       => 'trace_line',
		'_mirror'           => '_mirror',
		'_run3'             => '_run3',
		'_filters'          => 'filters',
		'_add_icon'         => 'add_icon',
		'_dll_to_a'         => '_dll_to_a',
		'_copy'             => '_copy',
		'_extract'          => '_extract',
		'_extract_filemap'  => '_extract_filemap',
		'_insert_fragment'  => 'insert_fragment',
		'_pushd'            => '_pushd',
		'_perl'             => '_perl',
		'_patch_file'       => 'patch_file',
		'_build'            => '_build',
		'_make'             => '_make',
		'_add_to_distributions_installed' =>
		  '_add_to_distributions_installed',
	},
	required => 1,
);

# An asset knows how to install itself.
requires 'install';

sub cpan {

	# Throw error.
}

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

	my $image_dir   = $self->_get_image_dir();
	my @module_dirs = split /::/ms, $module;
	my @dirs        = (
		catdir( $image_dir, qw{perl vendor lib auto}, @module_dirs ),
		catdir( $image_dir, qw{perl site   lib auto}, @module_dirs ),
		catdir( $image_dir, qw{perl        lib auto}, @module_dirs ),
	);

	my $packlist;
  DIR:
	foreach my $dir (@dirs) {
		$packlist = catfile( $dir, '.packlist' );
		last DIR if -r $packlist;
	}

	my $filelist;
	if ( -r $packlist ) {
		$filelist =
		  File::List::Object->new()->load_file($packlist)
		  ->add_file($packlist);
	} else {

		my $output = catfile( $self->_get_output_dir, 'debug.out' );

		# Trying to use the output to make an array.
		$self->_trace_line( 3,
			"Attempting to use debug.out file to make filelist\n" );

		my $fh = IO::File->new( $output, 'r' );
		if ( not defined $fh ) {
			PDWiX->throw("Error reading output file $output: $OS_ERROR");
		}
		my @output_list = <$fh>;
		$fh->close();

		my @files_list =
		  map { ## no critic 'ProhibitComplexMappings'
			my $t = $_;
			chomp $t;
			( $t =~ / \A Installing [ ] (.*) \z /msx ) ? ($1) : ();
		  } @output_list;

		if ( $#files_list == 0 ) {
			PDWiX->throw($error);
		} else {
			$self->_trace_line( 4, "Adding files:\n" );
			$self->_trace_line( 4, q{  } . join "\n  ", @files_list );
			$filelist = File::List::Object->new()->load_array(@files_list);
		}
	} ## end else [ if ( -r $packlist ) ]

	return $filelist->filter( $self->_filters );
} ## end sub _search_packlist

1;
