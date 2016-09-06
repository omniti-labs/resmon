package Core::BEcount;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::BEcount - Monitor number of BEs on a Solarish Global Zone

=head1 SYNOPSIS

 Core::BEcount {
     count: noop
 }

 Core::BEcount {
     count: beadm_path => /usr/sbin/beadm , cache => 3600
 }

=head1 DESCRIPTION

This module countes Solarish BEs in a Global Zone.
Operators of illumos/OmniOS may find it useful to alert when this number
grows too large to avoid tripping over https://www.illumos.org/issues/5943

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item beadm_path

Provide an alternate path to the beadm command. Optional.

=item count

Provide an alternate number of seconds to cache beadm output. Optional.

=back

=head1 METRICS

=over

=item count

A count of how many BEs are on this machine

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here

    my $beadm_path = $config->{beadm_path} || '/usr/sbin/beadm';
    my $cache = $config->{cache} // 3600;

    my $output = cache_command("$beadm_path list -H", $cache);
    my @boot_environments = split(/\n/, $output);

    return {
        "count" => [scalar(@boot_environments), "i"],
    };
}

1;
