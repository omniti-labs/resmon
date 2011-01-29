package Core::BSD::Sensor;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::BSD::Sensor - Check values of OpenBSD hardware sensors

=head1 SYNOPSIS

 Core::BSD::Sensor {
     cpu_temp: chip => admtm0, sensor => temp1
     sys_temp: chip => admtm0, sensor => temp2
     cpu_fan: chip => fins0, sensor => fan0
 }

=head1 DESCRIPTION

This module reads values from hardware sensors using sysctl on OpenBSD.

=head1 CONFIGURATION

=over

=item check_name

The check name is a short description of what the particular sensor monitors.

=item chip

Specifies the desired sensor chip.  This argument is mandatory.

=item sensor

The sensor on the specified chip whose value should be read.  This argument is mandatory.

=back

=head1 METRICS

=over

=item value

The value of the specified sensor.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $check_name = $self->{check_name}; # The check name is in here
    my $chip = $config->{chip};
    my $sensor = $config->{sensor};

    my $output = run_command("sysctl -n hw.sensors.$chip.$sensor");
    $output =~ m/(-?\d+\.?\d*)\s+\S+/;
    my $value = $1;

    return {
        "check_name" => [$self->{check_name}, "s"],
        "value" => [$value, "n"]
    };
};

1;
