package Core::Linux::Cpu;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Sample - a sample/template resmon module

=head1 SYNOPSIS

 Core::Linux::Cpu {
    cpu: noop
 }

 Core::Linux::Cpu {
     cpu: multi => 1
 }

=head1 DESCRIPTION

This module monitors CPU usage for Linux. It supports per-CPU statistics, as
well as showing a combined total. The combined total will never go above 100%.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item multi

Show statistics for all CPUs/Cores as well as a combined total. If set to 0,
then only show a combined total.

=back

=head1 METRICS

=over

=item cpu_* (user, nice, system, idle, iowait, irq, softirq)

The CPU usage for all CPUs combined. E.g. cpu_user == normal user processes
for all cpus combined. The usage is a percentage of all cpu usage combined.


=item cpu1_* (user, nice, system, idle, iowait, irq, softirq)

Individual CPU stats. The stats are a percentage of total cpu usage for that
CPU.

=back

=cut

sub get_new_values {
    my $config = shift;
    open (my $fh, "<" , "/proc/stat");
    my @cols = ("user", "nice", "system", "idle", "iowait", "irq", "softirq",
        "steal", "guest");
    my $values = {};
    while (<$fh>) {
        if (/^cpu/) {
            my @parts = split;

            my $cpu = shift @parts;

            if ((defined($config->{multi}) && $config->{multi} == 1) ||
                $cpu eq 'cpu') {
                $values->{$cpu} = {};
                for (my $i=0; $i<@cols && $i<@parts; $i++) {
                    $values->{$cpu}->{$cols[$i]} = $parts[$i];
                }
            }

        }
    }
    return $values;
}

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here

    my $values = get_new_values($config);
    if (!defined($self->{cached_values})) {
        # It's the first run, we need to wait a second and get some new cpu
        # values os we can compare the two. For subsequent runs, we can just
        # use the values from the previous run and take the difference between
        # the two.
        $self->{cached_values} = $values;
        sleep(1);
        $values = get_new_values($config);
    }

    my $total_delta = {}; # Total ticks for calculating percentage
    for my $cpu (keys %$values) {
        $total_delta->{$cpu} = 0;
        for my $i (keys %{$values->{$cpu}}) {
            $total_delta->{$cpu} += (
                $values->{$cpu}->{$i} - $self->{cached_values}->{$cpu}->{$i});
        }
    };

    my $metrics = {};
    while (my ($cpu, $percpu_values) = each %$values) {
        while (my ($name, $value) = each %$percpu_values) {
            my $delta = $value - $self->{cached_values}->{$cpu}->{$name};
            $metrics->{"${cpu}_$name"} = [
                sprintf("%.2f", (100 * $delta / $total_delta->{$cpu})), "n"];
        }
    }
    return $metrics;
};

1;
