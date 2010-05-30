package Core::Iostat;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Iostat - Monitor disk I/O statistics using iostat

=head1 SYNOPSIS

 Core::Iostat {
     local : noop
 }

 Core::Iostat {
     local : iostat_path => /usr/sbin/iostat
 }

=head1 DESCRIPTION

This module monitors I/O statistics for a given disk.  It uses the running
total values reported by iostat.  The type and number of metrics returned
depend on the type returned by each platform's respective iostat command.
Each metric returned is prefixed with the name of the associated disk.

=head1 CONFIGURATION

=over

=item check_name

The check name is used for descriptive purposes only.
It is not used for anything functional.

=item iostat_path

Provide an alternate path to the iostat command (optional).

=back

=head1 METRICS

=over

=item reads_sec

Reads per second.

=item writes_sec

Writes per second.

=item kb_read_sec

Kilobytes read per second.

=item kb_write_sec

Kilobytes written per second.

=item lqueue_txn

Transaction queue length.

=item wait_txn

Average number of transactions waiting for service.

=item actv_txn

Average number of transactions actively being serviced.

=item rspt_txn

Average response time of transactions, in milliseconds.

=item wait_pct

Percent of time there are transactions waiting for service.

=item busy_pct

Percent of time the disk is busy.

=item soft_errors

Number of soft errors.

=item hard_errors

Number of hard errors.

=item txport_errors

Number of transport errors.

=item rrqm_sec

The number of read requests merged per second that were queued to the device.

=item wrqm_sec

The number of write requests merged per second that were queued to the device.

=item rsec_sec

The number of sectors read from the device per second.

=item wsec_sec

The number of sectors written to the device per second.

=item avgrq_size

The average size (in sectors) of the requests that were issued to the device.

=item avgqu_size

The average queue length of the requests that were issued to the device.

=item await_msec

The average time (in milliseconds) for I/O requests issued to the device to be served.

=item svctm_msec

The average service time (in milliseconds) for I/O requests that were issued to the device.

=item util_pct

Percentage of CPU time during which I/O requests were issued to the device.

=item kb_xfrd

Kilobytes transferred (counter).

=item disk_xfrs

Disk transfers (counter).

=item busy_sec

Seconds spent in disk activity (counter).

=item xfrs_sec

Disk transfers per second.

=back

=cut

sub handler {
    my $self = shift;
    my $disk = $self->{'check_name'};
    my $config = $self->{'config'};
    my $iostat_path = $config->{'iostat_path'} || 'iostat';
    my $osname = $^O;
    my %metrics;

    if ($osname eq 'solaris') {
        my $interval = 5;
        my $count = 2;
        my $output = run_command("$iostat_path -xe $interval $count");
        foreach (split(/\n/, $output)) {
            next unless (/(\w+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+).*/);
            $metrics{"${1}_reads_sec"} = [$2, 'n'];
            $metrics{"${1}_writes_sec"} = [$3, 'n'];
            $metrics{"${1}_kb_read_sec"} = [$4, 'n'];
            $metrics{"${1}_kb_write_sec"} = [$5, 'n'];
            $metrics{"${1}_wait_txn"} = [$6, 'n'];
            $metrics{"${1}_actv_txn"} = [$7, 'n'];
            $metrics{"${1}_rspt_txn"} = [$8, 'n'];
            $metrics{"${1}_wait_pct"} = [$9, 'I'];
            $metrics{"${1}_busy_pct"} = [$10, 'I'];
            $metrics{"${1}_soft_errors"} = [$11, 'I'];
            $metrics{"${1}_hard_errors"} = [$12, 'I'];
            $metrics{"${1}_txport_errors"} = [$13, 'I'];
            $metrics{"${1}_total_errors"} = [$14, 'I'];
        }
        if (keys %metrics) {
            return \%metrics;
        } else {
            die "No disks found\n";
        }
    } elsif ($osname eq 'linux') {
        my $interval = 5;
        my $count = 2;
        my $output = run_command("$iostat_path -x $disk $interval $count");
        my ($line) = (grep(/$disk\s*/, split(/\n/, $output)))[1];
        if ($line =~ /^$disk\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+).*/) {
            return {
                "${disk}_rrqm_sec" => [$1, 'n'],
                "${disk}_wrqm_sec" => [$2, 'n'],
                "${disk}_reads_sec" => [$3, 'n'],
                "${disk}_writes_sec" => [$4, 'n'],
                "${disk}_rsec_sec" => [$5, 'n'],
                "${disk}_wsec_sec" => [$6, 'n'],
                "${disk}_avgrq_size" => [$7, 'n'],
                "${disk}_avgqu_size" => [$8, 'n'],
                "${disk}_await_msec" => [$9, 'n'],
                "${disk}_svctm_msec" => [$10, 'n'],
                "${disk}_util_pct" => [$11, 'n']
            };
        } else {
            die "Unable to find disk: $disk\n";
        }
    } elsif ($osname eq 'freebsd') {
        my $output = run_command("$iostat_path -x $disk");
        my ($line) = grep(/$disk\s*/, split(/\n/, $output));
        if ($line =~ /^$disk\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+).*/) {
            return {
                'reads_sec' => [$1, 'i'],
                'writes_sec' => [$2, 'i'],
                'kb_read_sec' => [$3, 'i'],
                'kb_write_sec' => [$4, 'i'],
                'lqueue_txn' => [$5, 'i'],
                'rspt_txn' => [$6, 'i']
            };
        } else {
            die "Unable to find disk: $disk\n";
        }
    } elsif ($osname eq 'openbsd') {
        my $output = run_command("$iostat_path -D -I $disk");
        if ($output =~ /\s+$disk\s+\n\s+KB xfr time\s+\n\s+(\d+)\s+(\d+)\s+(\S+).*/) {
            return {
                'kb_xfrd' => [$1, 'I'],
                'disk_xfrs' => [$2, 'I'],
                'busy_sec' => [$3, 'n']
            };
        } else {
            die "Unable to find disk: $disk\n";
        }
    } else {
        die "Unsupported platform: $osname\n";
    }
};

1;
