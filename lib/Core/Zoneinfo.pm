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

=item disable_fsstat

Optional. Set to 1 if you do not wish to gather per-zone fsstat metrics.

=item disable_resource_collection

Optional. Set to 1 if you do not wish to gather per-zone resource metrics (CPU,
memory, etc.

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
    my $zones = join(':', @zones);

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
    my $zoneroots = "";

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
      }
	    else {
	      $dataset = "Not a mountpoint";
	    }

	    # Store the values
	    $status->{"${zone}_path"}       = [$path, "s"];
	    $status->{"${zone}_dataset"}    = [$dataset, "s"];

      $zoneroots .= "$path ";
    };

    our %units = (
      'B' => 1,
      'K' => 1024,
      'M' => 1048576,
      'G' => 1073741824,
      'T' => 1099511627776,
      'P' => 1125899906842624,
      'E' => 1152921504606846976,
      'Z' => 1180591620717411303424
    );

    unless ( $config->{disable_fsstat} ) {
	    my $fsstat = run_command("/bin/fsstat $zoneroots 5 2 ");
	    foreach (split(/\n/, $fsstat)) {
	      next unless (/^\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/);
	      my $fs = $12;

        my $fs_read_bytes;
	      my $fs_read = $9;

        my $fs_write_bytes;
        my $fs_write = $11;

        foreach my $unit ( keys %units ) {
          if ( $fs_read =~ m/$unit$/ ) {
            $fs_read =~ s/$unit$//;
            $fs_read_bytes = $fs_read * $units{$unit};
          }

          if ( $fs_write =~ m/$unit$/ ) {
            $fs_write =~ s/$unit$//;
            $fs_write_bytes = $fs_write * $units{$unit};
          }
        }

        # The fsstat output does not specify B for bytes.
        # Assume bytes if value is empty.
        unless ( $fs_read_bytes ) { $fs_read_bytes = $fs_read }
        unless ( $fs_write_bytes ) { $fs_write_bytes = $fs_write }

        # There is almost certainly a less stupid way of doing this.
        my $zone = `/usr/sbin/zoneadm list -p | /bin/grep $fs | /bin/awk -F: '{print \$2}'`;
        chomp $zone;

        $status->{"${zone}_read_bytes"} =  [ $fs_read_bytes,  "i" ];
        $status->{"${zone}_write_bytes"} = [ $fs_write_bytes, "i" ];

        $status->{"${zone}_read_kbytes"} =  [ int($fs_read_bytes/1024),  "i" ];
        $status->{"${zone}_write_kbytes"} = [ int($fs_write_bytes/1024), "i" ];

        $status->{"${zone}_read_mbytes"} =  [ int($fs_read_bytes/1048576),  "i" ];
        $status->{"${zone}_write_mbytes"} = [ int($fs_write_bytes/1048576), "i" ];
      }
    }

    unless ( $config->{disable_resource_collection} ) {
      my $prstat = run_command("prstat -Z -n 1,500 -c 1 1 | tail +4 | grep -v Total");
      foreach ( split(/\n/, $prstat) ) {
        next unless /^\s+(\d+)/;
        my ( $s, $zid, $nproc, $swap, $rss, $mem_pct, $time, $cpu_pct, $zone ) = split(/\s+/, $_);
  
        my $swap_bytes;
        my $rss_bytes;
  
        $mem_pct =~ s/%//;
        $cpu_pct =~ s/%//;
  
        foreach my $unit ( keys %units ) {
          if ( $swap =~ m/$unit$/ ) {
            $swap =~ s/$unit$//;
            $swap_bytes = $swap * $units{$unit};
          }
  
          if ( $rss =~ m/$unit$/ ) {
            $rss =~ s/$unit$//;
            $rss_bytes = $rss * $units{$unit};
          }
        }
  
        $status->{"${zone}_id"}         = [ $zid,         "i" ];
        $status->{"${zone}_nproc"}      = [ $nproc,       "i" ];
        $status->{"${zone}_swap_bytes"} = [ $swap_bytes,  "n" ];
        $status->{"${zone}_rss_bytes"}  = [ $rss_bytes,   "n" ];
        $status->{"${zone}_mem_pct"}    = [ $mem_pct,     "n" ];
        $status->{"${zone}_cpu_pct"}    = [ $cpu_pct,     "n" ];
        $status->{"${zone}_uptime"}     = [ $time,        "s" ];
      }
    }

  $status->{"zones"} = $zones;

  return $status;
};

1;
