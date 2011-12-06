package Core::SVM;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::SVM - Monitor status of Solaris Volume Manager metadevices

=head1 SYNOPSIS

 Core::SVM {
     metadevices : noop
 }

 Core::SVM {
     metadevices : metastat_path => /usr/sbin/metastat
 }

=head1 DESCRIPTION

This module monitors Solaris Volume Manager metadevice status with the metastat command.

=head1 CONFIGURATION

=over

=item check_name

The check name is used for descriptive purposes only.  It is not used for
anything functional.

=item metastat_path

Provide an alternate path to the metastat command (optional).

=back

=head1 METRICS

=over

=item count_bad

A count of how many metadevices are in a faulted or degraded state. This should
normally be zero.

=item devices_bad

Concatenated list of the metadevices not in a normal state.  Each
entry will be separated by commas.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $metastat_path = $config->{'metastat_path'} || '/usr/sbin/metastat';
    my $osname = $^O;
    my %results;

    die "Unsupported platform: $osname\n"  unless ($osname eq 'solaris');

    my $output = run_command("$metastat_path -c");
    chomp $output;

    # metastat is broken
    if ($? && ! $output) {
        return {};
    }

    foreach (split(/\n/, $output)) {
        if (/^\s*(\S+)\s+\S+\s+\S+\s+(\S+)\s+\(/) {
            $results{$1} = $2;
        }
    }

    return {
        "count_bad" => [scalar(keys %results), "i"],
        "devices_bad" => [join(",", keys %results), "s"]
    };
};

1;

