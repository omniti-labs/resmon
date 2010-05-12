package Core::Zoneinfo;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Zoneinfo - report zone information

=head1 SYNOPSIS

 Core::Zoneinfo {
     zoneinfo : noop
 }

 Core::Zoneinfo {
     zoneinfo : zonecfg_path => /usr/sbin/zonecfg
 }

=head1 DESCRIPTION

Reports zone info, such as name, root filesystem path, creation date.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item zonecfg_path

Optional.  Specifies the path to the zonecfg command.

=item zoneadm_path

Optional.  Specifies the path to the zoneadm command.

=item zfs_path

Optional.  Specifies the path to the zfs command.

=back

=head1 METRICS

=over

=item path

The path to the root of the zone.  This corresponds to the 'zonepath' config
option to zonecfg(1M).

=item dataset

The ZFS dataset that provides the zone root, if the zone is on its own ZFS
filesystem.  If the zone is not on its own ZFS filesystem, this will return
'Not a mountpoint'.

=item creation

The creation date of the zone's ZFS filesystem.  If the zone is not on its own
ZFS filesystem, this metric is not returned.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $zonecfg = $config->{zonecfg_path} || '/usr/sbin/zonecfg';
    my $zoneadm = $config->{zoneadm_path} || '/usr/sbin/zoneadm';
    my $zfs = $config->{zfs_path} || '/usr/sbin/zfs';

    # Build the list of non-global zones
    my $zonelist = run_command("$zoneadm list");
    my @zones = grep {!/^global$/} split(/\n/, $zonelist);

    # Get stuff.  Start with the current list of mounts and test each zonepath
    # to see if it is a mountpoint.
    my $mounts = {};
    my $output = run_command("/sbin/mount");
    foreach my $line (split(/\n/, $output)) {
	my @parts = split(/\s+/, $line);
	next unless $parts[2] =~ /\//;
	$mounts->{$parts[0]} = $parts[2];
    };
    my $status = {};
    foreach my $zone (@zones) {
	my $output = run_command("$zonecfg -z $zone info zonepath");
	chomp $output;
	my @result = split(/:\s*/, $output);
	my $path = $result[1];
	my $dataset = $mounts->{$path};
	if ($dataset) {
	    my $creation = run_command("$zfs get -H -o value -p creation $dataset");
	    chomp $creation;
	    $status->{"${zone}_creation"}   = [$creation, "i"];
	} else {
	    $dataset = "Not a mountpoint";
	}
	# Store the values
	$status->{"${zone}_path"}       = [$path, "s"];
	$status->{"${zone}_dataset"}    = [$dataset, "s"];
    };

    return $status;
};

1;
