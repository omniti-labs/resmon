package Resmon::Module::RESMON;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

use Sys::Hostname;

# A resmon 'health check' module
# Currently just prints the hostname and svn revision in the output, always
# returning OK. In future it will check for a broken config and broken
# modules, reporting that it is running with old modules/an old config.

(my $resmon_dir = $0) =~ s/\/?[^\/]+$//;

sub handler {
    my $arg = shift;
    my $os = $arg->fresh_status();

    ## Current revision
    # Find location of subversion binary
    my $svn = 'svn';
    for my $path (qw(/usr/local/bin /opt/omni/bin)) {
        if (-x "$path/svn") {
            $svn = "$path/svn";
            last;
        }
    }
    my $output = cache_command("$svn info $resmon_path 2>&1", 600);
    $revision = 0;
    for (split(/\n/, $output)) {
        if (/^Revision:\s*(\d*)$/) { $revision = "r$1"; }
        if (/^svn: (.*) is not a working copy$/) {
            $revision = "not a working copy";
        }
    }


    # The hostname command croaks (dies) if it fails, hence the eval
    my $hostname = eval { hostname } || "Unknown";

    # Set 'config' variables so it shows up in the xml output
    $arg->{'revision'} = $revision;
    $arg->{'hostname'} = $hostname;

    return $arg->set_status("OK", "$hostname running ($revision)");
}

1;
