package Core::Zpool;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Zpool - monitor zfs zpool health

=head1 SYNOPSIS

 Core::Zpool {
     zpools: noop
 }

 Core::Zpool {
     zpools: zpool_path = '/sbin/zpool'
 }

=head1 DESCRIPTION

This module checks the status of ZFS pools, reporting any read/write/checksum
errors, as well as the status of the pools as a whole.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item zpool_path

Specify an alternative location for the zpool command. Default: /sbin/zpool.

=back

=head1 METRICS

A set of metrics is returned for each pool on the system, with the name of the
pool being used as a prefix. For example, if you have rpool and data pools,
then you will end up with both rpool_state and data_state (as well as the
rest of the metrics for each pool).

=over

=item poolname_state

The state of the pool as a string. Examples: ONLINE, FAULTED, DEGRADED.

=item poolname_errors_read

A count of read errors in the pool as a whole. This is the sum of the errors
for all devices in the pool

=item poolname_errors_write

A count of write errors in the pool as a whole. This is the sum of the errors
for all devices in the pool

=item poolname_errors_cksum

A count of checksum errors in the pool as a whole. This is the sum of the
errors for all devices in the pool

=item poolname_device_errors

A list of devices that have errors, along with the error count. For example:

 c0t0d0 3R 2W 1C, c1t0d0 100W

=back

=cut

sub convert_units {
    my ($self, $count, $unit) = @_;
    my %units = (
        'G' => 1000000000,
        'M' => 1000000,
        'K' => 1000
    );
    if ($unit) {
        $count = $count * $units{$unit};
    }
    return $count;
}

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $zpool_command = $config->{zpool_command} || '/sbin/zpool';

    my $pool = "";
    my $pool_status = {};
    my $status = {};
    my $output = run_command("$zpool_command status");
    foreach my $line (split(/\n/, $output)) {
        if ($line =~ /pool: (.+)$/) {
            # Start of a new pool
            $pool = $1;
            $pool_status = {
                'state' => '',
                'r' => 0,
                'w' => 0,
                'c' => 0,
                'deverrs' => []
            }
        }
        elsif ($line =~ /errors: (.+)$/) {
            # This line marks the end of a pool in zpool status. Store the
            # status for a pool.
            $status->{"${pool}_state"}        = [$pool_status->{state}, "s"];
            $status->{"${pool}_errors_read"}  = [$pool_status->{r}, "i"];
            $status->{"${pool}_errors_write"} = [$pool_status->{w}, "i"];
            $status->{"${pool}_errors_cksum"} = [$pool_status->{c}, "i"];
            $status->{"${pool}_device_errors"} =
                [join(', ', @{$pool_status->{deverrs}}), "s"];
        }
        elsif ($line =~ /state: (.+)$/) {
            # Pool state
            $pool_status->{state} = $1;
        }
        elsif ($line =~ /([a-z0-9]+)\s+([A-Z]+)\s+([\d.]+)([KMG])?\s+([\d.]+)([KMG])?\s+([\d.]+)([KMG])?/) {
            # A device status line
            my $device = $1;
            my @errs;
            if ($3 != 0) {
                my $count = $self->convert_units($3, $4);
                $pool_status->{r} += $count;
                push(@errs, "${count}R");
            }
            if ($5 != 0) {
                my $count = $self->convert_units($5, $6);
                $pool_status->{w} += $count;
                push(@errs, "${count}W");
            }
            if ($7 != 0) {
                my $count = $self->convert_units($7, $8);
                $pool_status->{c} += $count;
                push(@errs, "${count}C");
            }
            if (scalar(@errs)) {
                push(@{$pool_status->{deverrs}}, join(" ", $device, @errs));
            }
        }
    }

    return $status;
};

1;
