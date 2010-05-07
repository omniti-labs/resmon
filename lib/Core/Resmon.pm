package Core::Resmon;

use strict;
use warnings;

use base 'Resmon::Module';

use Sys::Hostname;

sub new {
    my ($class, $check_name, $config) = @_;
    my $self = $class->SUPER::new($check_name, $config);

    # Get the svn revision
    my $svnversion = 'svnversion';
    if (defined($self->{config}->{svnversion_path})) {
        $svnversion = $self->{config}->{svnversion_path};
    }
    $self->{svn_revision} = `$svnversion`;
    if ($self->{svn_revision} eq "") {
        $self->{svn_revision} = "unknown";
    }
    chomp $self->{svn_revision};

    bless($self, $class);
    return $self;
}

sub handler {
    my $self = shift;

    # Get the global config object
    my $config = $main::config;
    my $configstatus = $config->{'configstatus'};
    my $modstatus = $config->{'modstatus'};

    # The hostname command croaks (dies) if it fails, hence the eval
    my $hostname = eval { hostname } || "Unknown";

    return {
        "revision" => [$self->{svn_revision}, "s"],
        "hostname" => [$hostname, "s"],
        "configstatus" => [$configstatus ? "BAD" : "OK", "s"],
        "modstatus" => [scalar @$modstatus ? "BAD" : "OK", "s"],
        "failed_modules" => [join(", ", @$modstatus), "s"]
    };
};

1;
