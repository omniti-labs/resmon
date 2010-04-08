package Core::Load;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Load - monitor system load

=head1 SYNOPSIS

 Core::Load {
     load: noop
 }

 Core::Load {
     load: uptime_path => /bin/uptime
 }

=head1 DESCRIPTION

This module monitors system load using the uptime command.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item uptime_path

Specify an alternate path to the uptime command. Default: uptime

=back

=head1 METRICS

=over

=item 1m

The system load average over the past minute.

=item 5m

The system load average over the past five minutes.

=item 15m

The system load average over the past fifteen minutes.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $uptime_path = $self->{uptime_path} || 'uptime';

    my $output = run_command($uptime_path);
    chomp $output;

    my ($l1, $l5, $l15) =
        $output =~ /load averages?: ([0-9.]+), ([0-9.]+), ([0-9.]+)/;

    return {
        "1m" =>  [$l1,  "n"],
        "5m" =>  [$l5,  "n"],
        "15m" => [$l15, "n"],
    };
};

1;
