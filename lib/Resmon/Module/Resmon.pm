package Resmon::Module::Resmon;

use strict;
use warnings;

use Resmon::Module;
use vars ('@ISA');
@ISA = ("Resmon::Module");

use Sys::Hostname;

sub handler {
    my $self = shift;

    # Get the global config object
    my $config = $main::config;
    my $configstatus = $config->{'configstatus'};
    my $modstatus = $config->{'modstatus'};

    ## Current revision
    my $revision = '$Revision$';
    my ($numeric_revision) = $revision =~ /([0-9]+)/;
    if (!defined($numeric_revision)) {
        $numeric_revision = "unknown";
    }

    # The hostname command croaks (dies) if it fails, hence the eval
    my $hostname = eval { hostname } || "Unknown";

    return {
        "revision" => [$numeric_revision, "s"],
        "hostname" => [$hostname, "s"],
        "configstatus" => [$configstatus ? "BAD" : "OK", "s"],
        "modstatus" => [$modstatus ? "BAD" : "OK", "s"]
    };
};

1;
