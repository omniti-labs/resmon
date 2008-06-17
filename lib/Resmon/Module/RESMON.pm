package Resmon::Module::RESMON;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

use Sys::Hostname;

# A resmon 'health check' module
# Currently just prints the hostname and svn revision in the output, always
# returning OK. In future it will check for a broken config and broken
# modules, reporting that it is running with old modules/an old config.

my $resmon_dir = $0;
$resmon_dir =~ s/\/?[^\/]+$//;

sub handler {
    my $arg = shift;
    my $os = $arg->fresh_status();

    # Get the global config object
    my $config = $main::config;
    my $configstatus = $config->{'configstatus'} || "";
    my $modstatus = $config->{'modstatus'} || "";

    ## Current revision
    # Find location of subversion binary
    my $svn = 'svn';
    for my $path (qw(/usr/local/bin /opt/omni/bin /opt/csw/bin)) {
        if (-x "$path/svn") {
            $svn = "$path/svn";
            last;
        }
    }
    my $output = cache_command("$svn info $resmon_dir 2>&1", 120);
    my $revision = "svn revision unknown";
    for (split(/\n/, $output)) {
        if (/^Revision:\s*(\d*)$/) { $revision = "r$1"; }
        if (/^svn: (.*) is not a working copy$/) {
            $revision = "not a working copy";
        }
    }


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
    $arg->{'revision'} = $revision;
    $arg->{'hostname'} = $hostname;
    $arg->{'configstatus'} = $configstatus || "OK";
    $arg->{'modstatus'} = $modstatus || "OK";

    return $arg->set_status($status, "$hostname $statusmsg ($revision)");
}

1;
