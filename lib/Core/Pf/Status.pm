package Core::Pf::Status;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);
use Data::Dumper;

=pod

=head1 NAME

Core::Pf::Status - gather statistics from PF firewalls

=head1 SYNOPSIS

 Core::Pf::Status {
    local : pfctl_path => /sbin/pfctl
 }

=head1 DESCRIPTION

This module retrieves statistics from PF firewalls using
the pfctl command.

=head1 CONFIGURATION

=over

=item check_name

Arbitrary name of the check.

=item pfctl_path

Optional path to the pfctl executable.

=back

=head1 METRICS

=over

=item state_entries

=item state_searches

=item state_inserts

=item state_removals

=item counters_match

=item counters_bad-offset

=item counters_fragment

=item counters_short

=item counters_normalize

=item counters_memory

=item counters_bad-timestamp

=item counters_congestion

=item counters_ip-option

=item counters_proto-cksum

=item counters_state-mismatch

=item counters_state-insert

=item counters_state-limit

=item counters_src-limit

=item counters_synproxy

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $pfctl_path = $config->{'pfctl_path'} || 'pfctl';
    my $output = run_command("$pfctl_path -si") || die "Unable to execute: $pfctl_path";
    my $osname = $^O;
    my %metrics;
    my %keys = (
        'current entries' => 'state_entries',
        'searches'        => 'state_searches',
        'inserts'         => 'state_inserts',
        'removals'        => 'state_removals',
        'match'           => 'counters_match',
        'bad-offset'      => 'counters_bad-offset',
        'fragment'        => 'counters_fragment',
        'short'           => 'counters_short',
        'normalize'       => 'counters_normalize',
        'memory'          => 'counters_memory',
        'bad-timestamp'   => 'counters_bad-timestamp',
        'congestion'      => 'counters_congestion',
        'ip-option'       => 'counters_ip-option',
        'proto-cksum'     => 'counters_proto-cksum',
        'state-mismatch'  => 'counters_state-mismatch',
        'state-insert'    => 'counters_state-insert',
        'state-limit'     => 'counters_state-limit',
        'src-limit'       => 'counters_src-limit',
        'synproxy'        => 'counters_synproxy'
    );

    if ($osname eq 'openbsd') {
        foreach (split(/\n/, $output)) {
            if (/^\s+\w+.*/) {
                if (/^\s+current\sentries\s+(\d+)\s+/) {
                    $metrics{'state_entries'} = [$1, 'L'];
                } else {
                    /^\s+(\S+)\s+(\d+).*/;
                    $metrics{$keys{$1}} = [$2, 'L'];
                }
            }
        }
    } else {
        die "Unknown platform: $osname";
    }

    return { %metrics };
};

1;
