package Resmon::Module::RESMON;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

use Sys::Hostname;

# A resmon 'health check' module
# Currently just prints the hostname in the output, always
# returning OK. In future it will check for a broken config and broken
# modules, reporting that it is running with old modules/an old config.

my $resmon_dir = $0;
$resmon_dir =~ s/\/?[^\/]+$//;

sub handler {
    my $arg = shift;

    # Get the global config object
    my $config = $main::config;
    my $configstatus = $config->{'configstatus'} || "";
    my $modstatus = $config->{'modstatus'} || "";

    # The hostname command croaks (dies) if it fails, hence the eval
    my $hostname = eval { hostname } || "Unknown";

    my $status = "OK";
    my $statusmsg = "running";
    if ($configstatus) {
        $statusmsg = "BAD config file, running on old configuration";
        $status = "BAD";
    }
    if ($modstatus) {
        $statusmsg .= " with failed modules: $modstatus";
        $status = "BAD";
    }

    # Set 'config' variables so it shows up in the xml output
    $arg->{'hostname'} = $hostname;
    $arg->{'configstatus'} = $configstatus || "OK";
    $arg->{'modstatus'} = $modstatus || "OK";

    return $status, {
        "message" => ["$hostname $statusmsg", "s"]
    };
}

1;
