package Core::Rails;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Rails - gather Rails production.log statistics

=head1 SYNOPSIS

 Core::Rails {
    site1 : logfile => /var/www/rails/site1/production.log
    site2 : logfile => /var/www/rails/site2/production.log
 }

=head1 DESCRIPTION

This module retrieves statistics from Rails applications using
the native production.log.

=head1 CONFIGURATION

=over

=item check_name

Name of the check, typically named after the application or
website.  This is an arbitrary name used only to differentiate
it from other Core::Rails checks.

=item logfile

Path to the production.log file.  This setting is mandatory.

=back

=head1 METRICS

All of the metrics returned by this check are counter values.

=over

=item count

Number of times the controller method has been called.

=item time

Aggregate time spent in the controller method, in milliseconds.

=item views

Aggregate number of views called by the controller method.

=item queries

Aggregate number of database queries  called by the controller method.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $logfile = $config->{'logfile'};
    $/="\n\n\n";
    my $metrics;

    open(IN, $logfile) || die "Unable to open: $!\n";
    while (<IN>) {
        chomp;
        if (/\s*Processing\s(\S+)\s(to\s\w+\s)?\(for\s\S+\sat\s\S+\s\S+\)\s\[(\w+)\].*Completed\sin\s(\d+)ms\s\((View\:\s)?(\d+)?(\,\s)?(DB\:\s)?(\d+)?\)\s\|\s(\d+)\s(.*)\s\[(.*)\]/s) {
            my $controller = $1;
            my $action = $3;
            my $time = $4;
            my $views = $6;
            my $queries = $9;
            my $response = $10;
            $metrics->{"${controller}_count"}++;
            $metrics->{"${controller}_time"} += $time;
            $metrics->{"${controller}_views"} += $views if ($views);
            $metrics->{"${controller}_queries"} += $queries if ($queries);
        } elsif (/\s*Processing\s(\S+)\s(to\s\w+\s)?\(for\s\S+\sat\s\S+\s\S+\)\s\[(\w+)\].*Rendering\s(\S+)\s\((\d+).*\)/s) {
            my $controller = $1;
            my $action = $3;
            my $response = $5;
            next if ($response eq '404');
            $metrics->{"${controller}_count"}++;
        }
    }
    close(IN);

    foreach (keys %$metrics) {
        $metrics->{$_} = [$metrics->{$_}, 'L'];
    }

    die "No data found" unless ($metrics);

    return $metrics;
};

1;

