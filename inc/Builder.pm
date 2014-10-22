package Builder;

use strict;
use warnings;
use parent qw(Module::Build);

sub ACTION_authortest {
    my ($self) = @_;

    $self->depends_on('build');

    $self->test_files( qw< t xt/author > );
    $self->depends_on('test');

    return;
}


sub ACTION_releasetest {
    my ($self) = @_;

    $self->depends_on('build');

    $self->test_files( qw< t xt/author xt/release > );
    $self->depends_on('test');

    return;
}


sub ACTION_manifest {
    my ($self, @arguments) = @_;

    if (-e 'MANIFEST') {
        unlink 'MANIFEST' or die "Can't unlink MANIFEST: $!";
    }

    return $self->SUPER::ACTION_manifest(@arguments);
}


sub ACTION_distmeta {
    my ($self) = @_;
	
    $self->depends_on('manifest');
	
    return $self->SUPER::ACTION_distmeta();
}


sub ACTION_dist {
	my ($self) = @_;
	
	# Check and see if we've bundled a plugin.
	my $buildperl_dh;
	opendir $buildperl_dh, 'lib/Perl/Dist/WiX/BuildPerl';
	my $packaged_plugin = scalar grep { $_ =~ m{\A\d+ [.] pm\z}msx }
		readdir $buildperl_dh;
	closedir $buildperl_dh;

	die 'Need to wrap a plugin with "Build pluginwrap --version <version>"'
		if not $packaged_plugin;
	
	return $self->SUPER::ACTION_dist();
}


sub ACTION_pluginwrap {
	my ($self) = @_;
	
	my $version = $self->args('version');
	die 'Option --version <version> required' if not $version;
	
	require LWP::UserAgent;
	
	my $ua = LWP::UserAgent->new();
	$ua->env_proxy();
	
	my @files = (
		"lib/Perl/Dist/WiX/BuildPerl/$version.pm",
		"t/500_new.t",
		"t/501_short_version_$version.t",
		$self->get_all_files_in($ua, $version, "share-$version"),
	);
	
	foreach my $file (@files) {
		my $url = "http://hg.curtisjewell.name/Perl-Dist-WiX-BuildPerl-$version/raw-file/tip/$file";
		print "Getting $file\n";
		my $response = $ua->mirror($url, $file);
		die "Could not get $file" if $response->is_error;
	}
	
	return 1;
}


sub get_all_files_in {
	my ($self, $ua, $version, $url) = @_;
    my @answer; 
	
	my $full_url = "http://hg.curtisjewell.name/Perl-Dist-WiX-BuildPerl-$version/raw-file/tip/$url";
    my $response = $ua->get($full_url);
	return () if not $response->is_success();
	my @content = grep { $_ =~ m{r} } split "\n", $response->decoded_content();
	my @line;
	foreach my $line (@content) {
		@line = split q{ }, $line;
		if ($line[0] =~ m{\Ad}) { # Directory to descend into.
			push @answer, $self->get_all_files_in($ua, $version, "$url/" . $line[-1]);
		} else { # File to get.
		    push @answer, "$url/" . $line[-1];
		}
	}
	
	return @answer;
}


1;