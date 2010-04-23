package Core::Fmadm;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Fmadm - Monitor hardware fault conditions in Solaris

=head1 SYNOPSIS

 Core::Fmadm {
     failures : noop
 }

 Core::Fmadm {
     failures : fmadm_path => /usr/sbin/fmadm
 }

=head1 DESCRIPTION

This module monitors hardware fault conditions using the Solaris fmadm utility.

=head1 CONFIGURATION

=over

=item check_name

The check name is used for descriptive purposes only.  It is not used for
anything functional.

=item svcs_path

Provide an alternate path to the fmadm command (optional).

=back

=head1 METRICS

=over

=item count

A count of how many services are in a faulted or degraded state. This should
normally be zero.

=item resources

Concatenated list of the resources (FMRI) and their respective state.  Each
entry will be separated by commas.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $fmadm_path = $config->{'fmadm_path'} || 'fmadm';
    my $osname = $^O;
    my %results;

    die "Unsupported platform: $osname\n"  unless ($osname eq 'solaris');

    my $output = run_command("$fmadm_path faulty -r");
    foreach (split(/\n/, $output)) {
        /(\S+)\s+(\w+)/;
        $results{$1} = $2;
    }

    return {
        "count" => [scalar(keys %results), "i"],
        "resources" => [join(", ", map { "$_ $results{$_}" } keys %results), "s"]
    };
};

1;

