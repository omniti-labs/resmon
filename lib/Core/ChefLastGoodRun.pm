package Core::ChefLastGoodRun;

use strict;
use warnings;

use base 'Resmon::Module';


=pod

=head1 NAME

Core::ChefLastGoodRun

=head1 SYNOPSIS

 Core::ChefLastGoodRun {
    local : report_path => /var/chef/reports/last_good_run.json
 }

=head1 DESCRIPTION

This module reads a JSON file deposited whenever chef-solo runs to successful completion.

=head1 CONFIGURATION

=over

=item check_name

Arbitrary name of the check.

=item report_path

Optional path to the report JSON file.

=back

=head1 METRICS

=over

=item age (integer, seconds since last run)

=back

=head1 METRICS AVAILABLE WITH REPORT PARSING

If you have the JSON and File::Slurp perl modules installed, the following are also provided:

=over

=item elapsed (float, time last run took)

=item change_count (integer, number of changes)

=back

=cut

my $MODS_LOADED;

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $report_path = $config->{'report_path'} || '/var/chef/reports/last_good_run.json';

    unless (-e $report_path) { return {} }

    # Age metric
    my %metrics;
    $metrics{age} = [ time() - (stat($report_path))[9], 'I' ];

    # Try to load JSON module
    unless ($MODS_LOADED) {
        eval "use JSON; use File::Slurp;";
        if ($@) {
            return \%metrics;
        } else {
            $MODS_LOADED = 1;
        }
    }

    my $report = File::Slurp::readfile($report_path);
    $report = decode_json($report);

    $metrics{elapsed} = [ $report->{elapsed_time}, 'F' ];
    $metrics{change_count} = [ scalar(@{$report->{updated_resources}}), 'I' ];

    return \%metrics;
};

1;
