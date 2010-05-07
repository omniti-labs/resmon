package Core::Pf::Queues;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Pf::Queues - gather queue statistics from PF firewalls

=head1 SYNOPSIS

 Core::Pf::Queues {
    local : pfctl_path => /sbin/pfctl
 }

=head1 DESCRIPTION

This module retrieves queue statistics from PF firewalls using
the pfctl command.  Each metric returned is prefixed with the
name of the associated queue.

=head1 CONFIGURATION

=over

=item check_name

Arbitrary name of the check.

=item pfctl_path

Optional path to the pfctl executable.

=back

=head1 METRICS

=over

=item bytes

=item pkts

=item drop_bytes

=item drop_pkts

=item mbits

=item drop_mbits

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $pfctl_path = $config->{'pfctl_path'} || 'pfctl';
    my $output = run_command("$pfctl_path -vsq") || die "Unable to execute: $pfctl_path";
    my $osname = $^O;
    my %metrics;

    if ($osname eq 'openbsd') {
        foreach (split(/queue\s+/, $output)) {
            next unless /\w+/;
            if (/(\S+)\s+.*\n\s+\[\s+pkts\:\s+(\d+)\s+bytes\:\s+(\d+)\s+dropped\s+pkts\:\s+(\d+)\s+bytes\:\s+(\d+).*/) {
                $metrics{"${1}_pkts"} = [$2, 'L'];
                $metrics{"${1}_bytes"} = [$3, 'L'];
                $metrics{"${1}_drop_pkts"} = [$4, 'L'];
                $metrics{"${1}_drop_bytes"} = [$5, 'L'];
                $metrics{"${1}_mbits"} = ($3 > 0) ? [($3 * 8 / 1000000), 'n'] : [0, 'n'];
                $metrics{"${1}_drop_mbits"} = ($5 > 0) ? [($5 * 8 / 1000000), 'n'] : [0, 'n'];
            }
        }
        unless (keys %metrics) {
            die "No queues found";
        }

    } else {
        die "Unknown platform: $osname";
    }

    return { %metrics };
};

1;
