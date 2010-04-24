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
     sd0 : noop
     sd1 : noop
 }

 Core::Iostat {
     hda : iostat_path => /usr/sbin/iostat
 }

=head1 DESCRIPTION

This module monitors I/O statistics for a given disk.  It uses the running
total values reported by iostat.  The type and number of metrics returned
depend on the type returned by each platform's respective iostat command.

=head1 CONFIGURATION

=over

=item check_name

The name of the check refers to the disk to query status for.

=item iostat_path

Provide an alternate path to the iostat command (optional).

=back

=head1 METRICS

=over

=item read_sec

Reads per second.

=item write_sec

Writes per second.

=item kb_read_sec

Kilobytes read per second.

=item kb_write_sec

Kilobytes written per second.

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

=item kb_xfrd

Kilobytes transferred.

=item disk_xfrs

Disk transfers.

=item busy_sec

Seconds spent in disk activity.

=back

=cut

sub handler {
    my $self = shift;
    my $disk = $self->{'check_name'};
    my $config = $self->{'config'};
    my $iostat_path = $config->{'iostat_path'} || 'iostat';
    my $osname = $^O;

    if ($osname eq 'solaris') {
        my $output = run_command("$iostat_path -xe $disk");
        my ($line) = grep(/$disk\s*/, split(/\n/, $output));
        if ($line =~ /$disk\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+).*/) {
            return {
                'read_sec' => [$1, 'i'],
                'write_sec' => [$2, 'i'],
                'kb_read_sec' => [$3, 'i'],
                'kb_write_sec' => [$4, 'i'],
                'wait_txn' => [$5, 'i'],
                'actv_txn' => [$6, 'i'],
                'rspt_txn' => [$7, 'i'],
                'wait_pct' => [$8, 'i'],
                'busy_pct' => [$9, 'i'],
                'soft_errors' => [$10, 'i'],
                'hard_errors' => [$11, 'i'],
                'txport_errors' => [$12, 'i'],
                'total_errors' => [$13, 'i']
            };
        } else {
            die "Unable to find disk: $disk\n";
        }
    } elsif ($osname eq 'openbsd') {
        my $output = run_command("$iostat_path -D -I $disk");
        if ($output =~ /\s+$disk\s+\n\s+KB xfr time\s+\n\s+(\d+)\s+(\d+)\s+(\S+).*/) {
            return {
                'kb_xfrd' => [$1, 'i'],
                'disk_xfrs' => [$2, 'i'],
                'busy_sec' => [$3, 'i']
            };
        } else {
            die "Unable to find disk: $disk\n";
        }
    } else {
        die "Unsupported platform: $osname\n";
    }
};

1;
