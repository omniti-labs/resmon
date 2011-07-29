package Core::SmfDisabled;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::SmfDisabled - Monitor services in disabled mode

=head1 SYNOPSIS

 Core::SmfDisabled {
     services: noop
 }

 Core::SmfDisabled {
     services: svcs_path => /bin/svcs
 }

=head1 DESCRIPTION

This module monitors Solaris SMF services and reports on any that are in
disabled mode.

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

A count of how many services are in disabled mode. This should normally be
zero.

=item services

A list of the services in disabled mode. If no services are in disabled 
mode, then this will be blank. The service names will be separated by
whitespace.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here

    my $svcs_path = $config->{svcs_path} || 'svcs';

    my $output = run_command("$svcs_path");
    my @disabled_services = map((split(/\s+/, $_))[2],
        grep(/^disabled/, split(/\n/, $output)));


    return {
        "count" => [scalar(@disabled_services), "i"],
        "services" => [join(" ", @disabled_services), "s"]
    };
};

1;
