package Core::ZpoolFree;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::ZpoolFree - monitor free space available on ZFS pools

=head1 SYNOPSIS

 Core::ZpoolFree {
     zpools: noop
 }

 Core::ZpoolFree {
     zpools: zfs_path = '/sbin/zfs'
 }

=head1 DESCRIPTION

This module monitors the free space on ZFS pools. Free space is reported for
all pools on the system. Multiple checks are not required for individual
pools.

Implementation Note: The 'zfs list' command is used rather than 'zpool list'
in order to get a more accurate view of the available space in certain cases
where zpool list does not report the true usable free space (e.g. raidz
pools). See http://www.cuddletech.com/blog/pivot/entry.php?id=1013 for another
case where zpool list does not report the correct values for monitoring.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item zfs_path

Specify an alternative location for the zfs command. Default: /sbin/zfs.

=back

=head1 METRICS

A set of metrics is returned for each pool on the system, with the name of the
pool being used as a prefix. For example, if you have rpool and data pools,
then you will end up with both rpool_free_KB and data_free_KB (as well as the
rest of the metrics for each pool).

=over

=item poolname_free_MB

The amount of free space in the pool, measured in megabytes.

=item poolname_used_MB

The amount of used space in the pool, measured in megabytes.

=item poolname_percent_full

The amount of used space in the pool, expressed as a percentage of the total
space.

=back

=cut

our %units = (
    'B' => 1,
    'K' => 1024,
    'M' => 1048576,
    'G' => 1073741824,
    'T' => 1099511627776,
    'P' => 1125899906842624,
    'E' => 1152921504606846976,
    'Z' => 1180591620717411303424
);

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $zfs_command = $config->{zfs_command} || "/sbin/zfs";
    my $status = {};
    my $output = run_command("$zfs_command list -H -o name,used,avail");
    foreach my $line (split /\n/, $output) {
        my ($name, $used, $uunit, $free, $funit) = $line =~
            /(\S+)\s+([0-9.]+)([BKMGTPEZ]?)\s+([0-9.]+)([BKMGTPEZ]?)/;
        # Make sure we were able to match the regex
        die "Unable to parse zfs command output: $line\n" unless defined($name);
        next if ($name =~ /\//); # We're only interested in the root of a pool

        # Convert human readable units to bytes
        $used = $used * $units{$uunit} if $uunit;
        $free = $free * $units{$funit} if $funit;

        my $percent_full = sprintf("%.2f", ($used / ($used + $free)) * 100);
        $status->{"${name}_used_MB"} = [int($used/1048576), "i"];
        $status->{"${name}_free_MB"} = [int($free/1048576), "i"];
        $status->{"${name}_percent_full"} = [$percent_full, "n"];
    }

    return $status;
};

1;
