package Core::Linux::Processes;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Linux::Processes - a procesess state module

=head1 SYNOPSIS

 Core::Linux::Processes {
     local : noop
 }

=head1 DESCRIPTION

This module returns information on the state of the proceses on a running system.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=back

=head1 METRICS

=over

=item blocked

Processes in an uninterruptible sleep.

=item zombies

Defunct processes, terminated but not reaped by their parent.

=item running

Running or runnable processes.

=item sleeping

Processes in an interruptible sleep.

=item stopped

Stopped processes.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $check_name = $self->{check_name}; # The check name is in here


    my $ps_cmd = 'ps ax -o state';

    my $processes = run_command($ps_cmd);
    my @processes = split(/\n/, $processes);

    my $sleeping = grep(/S/, @processes);
    my $blocked = grep(/D/, @processes);
    my $zombies = grep(/Z/, @processes);
    my $running = grep(/R/, @processes);
    my $stopped = grep(/T/, @processes);

    return {
        "blocked" => [$blocked, "i"],
        "zombies" => [$zombies, "i"],
        "running" => [$running, "i"],
        "stopped" => [$stopped, "i"],
        "sleeping" => [$sleeping, "i"]
    };
};

1;
