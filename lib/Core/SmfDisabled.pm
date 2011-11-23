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
        sshd_disabled: pattern => ssh
        apache_disabled: pattern => httpd
    }

    Core::SmfDisabled {
        sshd_disabled: svcs_path => /bin/svcs, pattern => ssh
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

=item pattern

A perl regular expression of the services to report on.  Optional.  Defaults to all services.

=back

=head1 METRICS

=over

=item count

A count of how many services are in disabled mode. This should normally be
zero.

=item <service name>

For each service that matches the pattern, the a result will be
added with the service name as a metric.  The value will be 1 for
disabled, and 0 otherwise.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here

    my $svcs_path = $config->{svcs_path} || 'svcs';
    my $pattern = $config->{pattern} || '.*';
    $pattern = qr/$pattern/;

    my $output = {
        count => 0,
    };
    my $svcs_output = run_command("$svcs_path -a");
    my @lines = grep { $_ ne '' } split /\n/, $svcs_output;
    for my $line (@lines) {
        my ($state, $start, $name) = split /\s+/, $line, 3;
        if ($name =~ $pattern) {
            if ($state eq 'disabled') {
                $output->{count}++;
                $output->{$name} = 1;
            }
            else {
                $output->{$name} = 0;
            }
        }
    }
    return $output;
}

1;
