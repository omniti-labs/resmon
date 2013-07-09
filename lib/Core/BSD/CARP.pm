package Core::BSD::CARP;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::BSD::CARP - Checks the status of OpenBSD CARP interfaces

=head1 SYNOPSIS

 Core::BSD::CARP {
     * : noop
 }

=head1 DESCRIPTION

This module reads values from ifconfig on OpenBSD to give the status of CARP
(Common Address Redundancy Protocol) interfaces.

=head1 CONFIGURATION

=over

=item check_name

This is a wildcard module and will return metrics for all CARP interfaces. 
As such, the check name should be an asterisk (*).

=back

=head1 METRICS

=over

=item role

The role of the interface (whether it is MASTER or BACKUP)

=item advbase

How often the interface is advertised

=item advskew

How skewed the advertisement interval is

=back

=cut

sub wildcard_handler {
    my $self = shift;
    my $interface = $self->{check_name}; # The check name is in here

    my $metrics;
    my $iface = '';
    my $line;

    my $output = run_command("ifconfig carp");
    my @lines = split("\n", $output);
    foreach $line (@lines) {
        if ($line =~ /^(carp\d+):/) {
            $iface = $1;
        }
        if ($iface ne '' && $line =~ /carp:/) {
            $line =~ /(BACKUP|MASTER)/;
            my $role = $&;
            $line =~ /carpdev (\w*)/;
            my $carpdev = $1;
            $line =~ /vhid (\d*)/;
            my $vhid = $1;
            $line =~ /advbase (\d*)/;
            my $advbase = $1;
            $line =~ /advskew (\d*)/;
            my $advskew = $1;

            $metrics->{$iface} = {
                "role" => [$role, "s"],
                "carpdev" => [$carpdev, "s"],
                "vhid" => [$vhid, "I"],
                "advbase" => [$advbase, "I"],
                "advskew" => [$advskew, "I"]
            };
        }
    }
    return $metrics;
};


1;
