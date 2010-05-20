package Core::Pf::Labels;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Pf::Labels - gather label statistics from PF firewalls

=head1 SYNOPSIS

 Core::Pf::Labels {
    local : pfctl_path => /sbin/pfctl
 }

=head1 DESCRIPTION

This module retrieves label statistics from PF firewalls using
the pfctl command. Metrics for each label are returned as a separate check.

=head1 CONFIGURATION

=over

=item check_name

This is a wildcard module and will return metrics for all labels. As such, the
check name should be an asterisk (*).

=item pfctl_path

Optional path to the pfctl executable.

=back

=head1 METRICS

=over

=item evals

=item pkts

=item bytes

=item pkts_in

=item bytes_in

=item pkts_out

=item bytes_out

=item states

=back

=cut

sub wilcard_handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $pfctl_path = $config->{'pfctl_path'} || 'pfctl';
    my $output = run_command("$pfctl_path -sl") ||
        die "Unable to execute: $pfctl_path";
    my $osname = $^O;
    my $metrics;

    if ($osname eq 'openbsd') {
        foreach (split(/\n/, $output)) {
            if (/(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
                $metrics->{$1}->{"evals"} += $2;
                $metrics->{$1}->{"pkts"} += $3;
                $metrics->{$1}->{"bytes"} += $4;
                $metrics->{$1}->{"pkts_in"} += $5;
                $metrics->{$1}->{"bytes_in"} += $6;
                $metrics->{$1}->{"pkts_out"} += $7;
                $metrics->{$1}->{"bytes_out"} += $8;
                $metrics->{$1}->{"states"} += $9;
            }
        }
    } else {
        die "Unknown platform: $osname\n";
    }

    die "No labels found\n" unless (%$metrics);

    return $metrics;
};

1;
