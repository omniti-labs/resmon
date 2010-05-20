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
    * : pfctl_path => /sbin/pfctl
 }

=head1 DESCRIPTION

This module retrieves queue statistics from PF firewalls using
the pfctl command. Metrics for each queue are returned as a separate check.

=head1 CONFIGURATION

=over

=item check_name

This is a wildcard module and will return metrics for all queues. As such, the
check name should be an asterisk (*).

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

sub wildcard_handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $pfctl_path = $config->{'pfctl_path'} || 'pfctl';
    my $output = run_command("$pfctl_path -vsq") ||
        die "Unable to execute: $pfctl_path";
    my $osname = $^O;
    my $metrics;

    if ($osname eq 'openbsd') {
        foreach (split(/queue\s+/, $output)) {
            next unless /\w+/;
            if (/(\S+)\s+.*\n\s+\[\s+pkts\:\s+(\d+)\s+bytes\:\s+(\d+)\s+dropped\s+pkts\:\s+(\d+)\s+bytes\:\s+(\d+).*/) {
                $metrics->{$1}->{"pkts"} = [$2, 'L'];
                $metrics->{$1}->{"bytes"} = [$3, 'L'];
                $metrics->{$1}->{"drop_pkts"} = [$4, 'L'];
                $metrics->{$1}->{"drop_bytes"} = [$5, 'L'];
                $metrics->{$1}->{"mbits"} =
                    ($3 > 0) ? [($3 * 8 / 1000000), 'n'] : [0, 'n'];
                $metrics->{$1}->{"drop_mbits"} =
                    ($5 > 0) ? [($5 * 8 / 1000000), 'n'] : [0, 'n'];
            }
        }
    } else {
        die "Unknown platform: $osname";
    }

    die "No queues found" unless (%$metrics);

    return $metrics;
};

1;
