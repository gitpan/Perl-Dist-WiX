package Perl::Dist::WiX::StartMenu;

#####################################################################
# Perl::Dist::WiX::StartMenu - A <Fragment> and <DirectoryRef> tag that
# contains start menu <Shortcut>.
#
# Copyright 2009 Curtis Jewell
#
# License is the same as perl. See Wix.pm for details.
#
#<<<
use 5.006;
use strict;
use warnings;
use Object::InsideOut qw( 
    Perl::Dist::WiX::Base::Fragment
    Storable
);
use Params::Util      qw( _IDENTIFIER _STRING             );
use vars              qw( $VERSION                        );

use version; $VERSION = qv('0.14');

#>>>
#####################################################################
# Accessors:
#   none.

#####################################################################
# Constructor for StartMenu
#
# Parameters: [pairs]
#   id, directory: See Base::Filename.
#   sitename: The name of the site that is hosting the download.

sub _pre_init : PreInit {
	my ( $self, $args ) = @_;

	# Apply required defaults.
	$args->{id}        ||= 'Icons';
	$args->{directory} ||= 'ApplicationProgramsFolder';

	return;
}

#####################################################################
# Main Methods

########################################
# get_component_array
# Parameters:
#   None.
# Returns:
#   Array of the Id attributes of the components within this object.

sub get_component_array {
	my $self = shift;

	my $count = scalar @{ $self->get_components };
	my @answer;
	my $id;

	# Added in this module.
	push @answer, 'RemoveShortcutFolder';

	# Get the array for each descendant.
	foreach my $i ( 0 .. $count - 1 ) {
		$id = $self->get_components->[$i]->get_component_id;
		push @answer, "S_$id";
	}

	return @answer;
} ## end sub get_component_array

sub search_file {
	return undef;
}

sub check_duplicates {
	return undef;
}

########################################
# as_string
# Parameters:
#   None.
# Returns:
#   String representation of the <Fragment> and other tags represented
#   by this object.

sub as_string {
	my ($self) = shift;

# getting the number of items in the array referred to by $self->{components}
	my $count = scalar @{ $self->get_components };
	my $string;
	my $s;
	my $id        = $self->get_fragment_id();
	my $directory = $self->get_directory_id();

	# Short-circuit.
	return q{} if ( 0 == $count );

	# Start printing.
	$string = <<"EOF";
<?xml version='1.0' encoding='windows-1252'?>
<Wix xmlns='http://schemas.microsoft.com/wix/2006/wi'>
  <Fragment Id='Fr_$id'>
    <DirectoryRef Id='$directory'>
EOF

	# Get component strings.
	foreach my $i ( 0 .. $count - 1 ) {
		$s = $self->get_components->[$i]->as_string;
		$string .= $self->indent( 6, $s );
		$string .= "\n";
	}

	# Create a GUID out of the ID for the last component.
	my $guid_rsf = $self->generate_guid('RemoveShortcutFolder');

	# Finish printing.
	$string .= <<"EOF";
      <Component Id='C_RemoveShortcutFolder' Guid='$guid_rsf'>
        <RemoveFolder Id="$directory" On="uninstall" />
      </Component>
    </DirectoryRef>
  </Fragment>
</Wix>
EOF

	return $string;

} ## end sub as_string

1;
