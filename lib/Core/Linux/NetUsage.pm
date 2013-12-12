package Core::Linux::NetUsage;

use strict;
use warnings;

use base 'Resmon::Module';

use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday usleep);

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Linux::NetUsage - Linux network interface throughput stats

=head1 SYNOPSIS

 Core::Sample {
     check_name : interface => arg1
 }

=head1 DESCRIPTION

This module obtains network usage statistics on a Linux machine
by reading the /proc filesystem (like netstat and ifconfig do). 

=head1 CONFIGURATION

=over

=item check_name

Description only, non-normative.

=item interface

The interface to obtain statistics for, like C<eth0>. Defaults to
C<eth0> if not specified.

=back

=head1 METRICS

=over

=item rx_bytes

Count, in bytes, of packets received on the interface.

=item tx_bytes

Count, in bytes, of packets sent on the interface.

=back

=cut

sub new {
    my ($class, $check_name, $config) = @_;
    my $self = $class->SUPER::new($check_name, $config);

    bless($self, $class);
    return $self;
}

sub handler {
    my $self = shift;
    my $config = $self->{config};
    my $interface = $config->{interface};
    print "I have ${interface}\n";

    my $stats = get_network_statistics_for($interface);
    return $stats;
};


sub get_network_statistics_for {
  my ($interface) = @_;

  my $dir = "/sys/class/net/$interface/statistics";

  my $stats = {};
  my @stats = qw/rx_bytes tx_bytes/;
  for my $stat (@stats) {
    $stats->{$stat} = do {
      open my $fh, '<', "${dir}/${stat}" or die "${dir}/${stat}: $!";
      local $/;
      <$fh>;
    };
    chomp $stats->{$stat};
  }

  return $stats;
}

1;
