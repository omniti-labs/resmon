package Core::Uptime;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Uptime - track system boot time and uptime 

=head1 SYNOPSIS

 Core::Uptime {
     uptime: noop
 }

=head1 DESCRIPTION

This module monitors system uptime and boot time

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=back

=head1 METRICS

=over

=item boottime 

The time when the system booted

=item uptime 

The number of seconds between when the system last booted and when the check ran

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $kstat_path = $self->{kstat_path} || 'kstat';

    my $current_time = time(); 
    my $uptime;
    my $boottime;

    if ( $^O eq "solaris" ) {
       my $check_006;
       open my $release_fh,'<',"/etc/release" or die "Could not find /etc/release";
       while (my $line = <$release_fh>) {
          if ($line =~ /r151006/) {
             $check_006 = $line;
             chomp($check_006);
          }
       }
       close $release_fh;

       my $zonename = run_command("/usr/bin/zonename");
       chomp $zonename;

       #Zones on r151006 do not report boot time from kstat correctly
       if (($check_006 ne "") && ($zonename ne "global")) {
          $uptime = run_command('ptime -Fp `pgrep init` 2>&1 | grep real | awk \'{print $2}\' | awk -F: \'{print ($1*3600) + ($2*60) + $3}\'');
          chomp $uptime;
          $boottime = $current_time - $uptime;
       } else {  
          my $output = run_command("$kstat_path -p unix:0:system_misc:boot_time");
          chomp $output;

          ($boottime) =
             $output =~ /^unix:0:system_misc:boot_time\s+(\d+)$/;
          $uptime = $current_time - $boottime;
      }
    } else {
       open my $uptime_fh,'<',"/proc/uptime" or die "Could not find /proc/uptime";
       while (my $line = <$uptime_fh>) {
           if ($line =~ /^(\d+)\.\d+\s+\d+\.\d+$/) {
              $uptime = $1;
           }
       }
       close $uptime_fh;
       chomp $uptime;
       $boottime = $current_time - $uptime; 
    } 

    return {
        "boottime" =>  [$boottime,  "n"],
        "uptime" => [$uptime, "n"]
    };
};

1;
