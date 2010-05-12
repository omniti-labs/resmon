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
     zoneinfo : zonecfg_path = '/usr/sbin/zonecfg'
 }

 Core::Zoneinfo {
     zoneinfo : zoneadm_path = '/usr/sbin/zoneadm'
 }

 Core::Zoneinfo {
     zoneinfo : zfs_path = '/usr/sbin/zfs'
 }

=head1 DESCRIPTION

Reports zone info, such as name, root filesystem path, creation date.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=back

=head1 METRICS

=over

=item check_name

The name of the current check. You wouldn't normally return this, but it is
here to show how to access the check name, and for testing purposes.

=item arg1

The contents of what you put in the arg1 configuration variable.

=item arg2

The contents of what you put in the arg2 configuration variable.

=item date

Todays date. It only shows the actual date of the month as an example of an
integer (type "i") metric.

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
