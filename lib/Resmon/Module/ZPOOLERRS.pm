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
#   zpools : warn_on_upgrade => yes
# }

# Another sample configuration, which ignores zpool upgrade requests
# ZPOOLERRS {
#   zpools : noop
# }

sub handler {
    my $arg = shift;
    my $unit = $arg->{'object'};
    # Do we warn on 'zpool needs an upgrade', or just leave it OK?
    my $warn_on_upgrade = $arg->{'warn_on_upgrade'} || "no";
    my $output = cache_command(
        "zpool status -x", 600);
    if($output) {
            my %errs = ();
            my $currpool = "";
            my $status = "OK";
            foreach my $line (split(/\n/, $output)) {
                if ($line =~ /(all pools are healthy)/) {
                    # If everything is OK, we don't need to go any further
                    return "OK", $1;
                }
                if ($line =~ /pool: (.+)$/) {
                    # Pool name
                    $currpool = $1;
                } elsif ($line =~ /state: (.+)$/) {
                    # Pool state
                    $errs->{$currpool} .= "$1 ";
                    if ($1 ne 'ONLINE') {
                        $status = "BAD";
                    }
                } elsif ($line =~
                    /The pool is formatted using an older on-disk format/) {
                    # Detect if the error is just that a pool needs upgrading.
                    $errs->{$currpool} .= "- needs upgrade ";
                    if ($warn_on_upgrade eq "yes" && $status != "BAD") {
                        $status = "WARNING";
                    }
                } elsif ($line =~
                    /([a-z0-9]+)\s+([A-Z]+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
                    # Pool errors
                    if ($3 != 0 || $4 != 0 || $5 != 0) {
                        $errs->{$currpool} .=
                            "- $1:$2 w/Errs: R:$3 W:$4 Chk:$5 ";
                        $status = "BAD";
                    }
                }
            }
            # Generate the status
            my $errstring = "";
            while (my ($k, $v) = each %$errs) {
                # $v should always contain a trailing space
                chop($v);
                $errstring .= "$k: $v";
                $errstring .= ", ";
            }
            # Remove the trailing comma and space
            chop($errstring);
            chop($errstring);
            return $status, $errstring;
    }
    return "BAD", "no data"
};
1;
