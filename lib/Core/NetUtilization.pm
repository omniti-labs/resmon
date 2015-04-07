package Core::NetUtilization;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::NetUtilization - get interface in/out byte counts

=head1 SYNOPSIS

 Core::NetUtilization {
     local: noop
 }

=head1 DESCRIPTION

Each instance is the name of a network interface (vnic under solaris).  

On linux, uses ifconfig to list interfaces and obtain byte in/out counts.

On solaris, uses kstat.

=head1 CONFIGURATION

None.

=head1 METRICS

=over

=item in_bytes

64-bit Integer, number of inbound bytes

=item out_bytes

64-bit Integer, number of outbound bytes

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $check_name = $self->{check_name}; # The check name is in here

    my $results;

    if ($^O eq 'solaris') {
        my $output = run_command('kstat -p ::mac_[tr]x_swlane0:[or]bytes');
        chomp $output;

        # global0:0:mac_rx_swlane0:rbytes 5858602050
        # global0:0:mac_tx_swlane0:obytes 275810267256
        # omnibuildil10:0:mac_rx_swlane0:rbytes   340562
        # omnibuildil10:0:mac_tx_swlane0:obytes   0
        foreach my $line (split("\n", $output)) {
            next unless $line;
            my ($key, $val) = split(/\s+/, $line);
            next unless $key;
            my ($vnic, $dum1, $direction, $dum2) = split(':', $key);
            next unless $vnic;
            $results->{$vnic . '_' . ($direction eq 'mac_rx_swlane0' ? 'in' : 'out' 
                                     ) . '_bytes64'} = [ $val, 'l'];
        }
    } else {
        # Everything else is obviously linux, right?
        my $output = run_command('/sbin/ifconfig -a');
        chomp $output;

        my $iface;
        foreach my $line (split("\n", $output)) {
            next unless $line;
            my ($name, $rest) = $line =~ /^(\S+)\s+Link encap:(\S+)/;
            if ($name) {
                $iface = $name;
                next;
            }

            #     RX bytes:114925052 (109.6 MiB)  TX bytes:5398728 (5.1 MiB)
            my ($in_bytes, $out_bytes) = $line =~ /^\s+RX bytes:(\d+).+TX bytes:(\d+).+/;
            next unless defined $in_bytes;
            $results->{$iface . '_in_bytes64'} = [$in_bytes, 'l'];
            $results->{$iface . '_out_bytes64'} = [$out_bytes, 'l'];
        }
    }
    return $results;
};

1;
