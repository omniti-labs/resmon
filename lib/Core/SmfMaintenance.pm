package Core::SmfMaintenance;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::SmfMaintenance - Monitor services in maintenance mode

=head1 SYNOPSIS

 Core::SmfMaintenance {
     services: noop
 }

 Core::SmfMaintenance {
     services: svcs_path => /bin/svcs
 }

=head1 DESCRIPTION

This module monitors Solaris SMF services and reports on any that are in
maintenance mode.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item svcs_path

Provide an alternate path to the svcs command. Optional.

=back

=head1 METRICS

=over

=item count

A count of how many services are in maintenance mode. This should normally be
zero.

=item services

A list of the services in maintenance mode. If no services are in maintenance
mode, then this will be blank. The service names will be separated by
whitespace.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here

    my $svcs_path = $config->{svcs_path} || 'svcs';

    my $output = run_command("$svcs_path");
    my @maintenance_services = map((split(/\s+/, $_))[2],
        grep(/^maintenance/, split(/\n/, $output)));


    return {
        "count" => [scalar(@maintenance_services), "i"],
        "services" => [join(" ", @maintenance_services), "s"]
    };
};

1;
