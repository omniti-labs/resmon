package Resmon::Module::ZPOOLERRS;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# Checks for zpool read write errors by using zpool status -x
# Will also notify if a zpool is degraded or not, similar to the basic zpool
# check.

# Sample configuration:
# ZPOOLERRS {
#   zpools : noop
# }

sub handler {
    my $arg = shift;
    my $os = $arg->fresh_status();
    return $os if $os;
    my $unit = $arg->{'object'};
    my $output = cache_command(
        "zpool status -x", 600);
    if($output) {
            my $errstring = "";
            my $currpool = "";
            foreach my $line (split(/\n/, $output)) {
                if ($line =~ /(all pools are healthy)/) {
                    return "OK", $1;
                }
                if ($line =~ /pool: (.+)$/) {
                    # Pool name
                    $currpool = $1;
                } elsif ($line =~ /state: (.+)$/) {
                    # Pool state
                    $errstring .= "$currpool:$1 ";
                } elsif ($line =~
                    /([a-z0-9]+)\s+([A-Z]+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
                    # Pool errors
                    if ($3 != 0 || $4 != 0 || $5 != 0) {
                        $errstring .= "- $1:$2 w/Errs: R:$3 W:$4 Chk:$5 ";
                    }
                }
            }
            chop($errstring);
            return "BAD", $errstring;
    }
    return "BAD", "no data"
};
1;
