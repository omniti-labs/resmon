package Core::Cpu;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Cpu - check CPU usage

=head1 SYNOPSIS

 Core::Cpu {
    local : path_to_vmstat => /usr/bin/vmstat
 }

=head1 DESCRIPTION

This module retrieves CPU statistics.

=head1 CONFIGURATION

=over

=item check_name

Arbitrary name of the check.

=item path_to_vmstat

Optional path to the vmstat executable.

=item path_to_tail

Optional path to the tail executable.

=back

=head1 METRICS

=over

=item user (time)

=item system (time)

=item idle (time)

=item error_msg

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $path_to_vmstat = $config->{'path_to_vmstat'} || 'vmstat';
    my $path_to_tail = $config->{'path_to_tail'} || 'tail';
    my $output = run_command("$path_to_vmstat 1 2 | $path_to_tail -1");
    my $osname = $^O;
    my %metrics;
    my @keys = qw( user system idle );
    my @values;

    $output =~ s/^\s+//;
    $output =~ s/\s+/ /g;
    if ($osname eq 'solaris') {
        @values = (split($output))[19..21];
    } elsif ($osname eq 'linux') {
        @values = (split($output))[12..14];
    } elsif ($osname eq 'openbsd') {
        @values = (split(/\s+/, $output))[16..18];
    } elsif ($osname eq 'freebsd') {
        @values = (split($output))[16..18];
    } else {
        return { 'error_msg' => 'unknown operating system' };
    }

    %metrics = map { $_ => shift(@values) } @keys;

    return { %metrics };
};

1;
