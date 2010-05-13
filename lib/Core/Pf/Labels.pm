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
the pfctl command.  Each metric returned is prefixed with the
name of the associated label.

=head1 CONFIGURATION

=over

=item check_name

Arbitrary name of the check.

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

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $pfctl_path = $config->{'pfctl_path'} || 'pfctl';
    my $output = run_command("$pfctl_path -sl") || die "Unable to execute: $pfctl_path";
    my $osname = $^O;
    my %metrics;

    if ($osname eq 'openbsd') {
        foreach (split(/\n/, $output)) {
            if (/(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
                $metrics{"${1}_evals"} += $2;
                $metrics{"${1}_pkts"} += $3;
                $metrics{"${1}_bytes"} += $4;
                $metrics{"${1}_pkts_in"} += $5;
                $metrics{"${1}_bytes_in"} += $6;
                $metrics{"${1}_pkts_out"} += $7;
                $metrics{"${1}_bytes_out"} += $8;
                $metrics{"${1}_states"} += $9;
            } else {
                die "No queues found";
            }
        }
    } else {
        die "Unknown platform: $osname";
    }

    return \%metrics;
};

1;
