package Resmon::Module::TWRAID;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
use strict;
@ISA = qw/Resmon::Module/;

# 3ware RAID status
# requires the tw_cli program to be installed (defaults to /usr/local/bin, but
# you can specify this in the config variable tw_cli.
#
# Example config:
# TWRAID {
#   /c0/u1 : noop
# }
#
# TWRAID {
#   /co/u1 : tw_cli => /opt/3ware/bin/tw_cli
# }

sub handler {
    my $arg = shift;
    # Unit in the form /cx/ux - /c0/u1 is the first unit
    my $unit = $arg->{'object'};
    # Path to tw_cli program
    my $tw_cli = $arg->{'tw_cli'} || '/usr/local/bin/tw_cli';

    my $status = "OK";
    my @messages;

    my $output = cache_command("$tw_cli $unit show", 500);
    for (split(/\n/, $output)) {
        my @parts = split(/ +/);
        next if ($parts[0] !~ /^u[0-9]/);
        if ($parts[2] ne "OK") {
            $status = "BAD";
            my $type;
            if ($parts[1] eq "DISK") {
                my $port = $parts[5];
                if ($port eq "-") {
                    $port = "not present";
                }
                $type = "(disk $port)";
            } else {
                $type = "($parts[1])";
            }
            push @messages, "$parts[0] $type $parts[2]";
        }
    }
    return $status, join(", ", @messages);
};
1;

