package Resmon::Module::ADAPTEC;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
use strict;
@ISA = qw/Resmon::Module/;

# Adaptec RAID status
# requires the arcconf program to be installed (defaults to /usr/StorEdge, but
# you can specify this in the config variable arcconf.
#
# Example config:
# ADAPTEC {
#   1 : noop
# }
#
# ADAPTEC {
#   1 : arcconf => /usr/StorMan/arcconf
# }

sub handler {
    my $arg = shift;
    # Unit number
    my $unit = $arg->{'object'};
    # Path to arcconf program
    my $arcconf = $arg->{'arcconf'} || '/usr/StorMan/arcconf';

    my $status = "BAD";
    my $message = "No output";

    my $output = cache_command("$arcconf getconfig $unit AD", 500);
    foreach (split(/\n/, $output)) {
        if (/Logical devices\/Failed\/Degraded\s+:\s+\d+\/(\d+)\/(\d+)/) {
            my $failed = $1;
            my $degraded = $2;
            if ($failed == 0 || $degraded == 0) {
                $status = "OK";
            }
            $message = "$failed Failed, $degraded Degraded";
            last;
        }
    }
    return $status, $message;
};
1;
