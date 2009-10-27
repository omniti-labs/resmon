package Resmon::Module::DHCPLEASES;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $net = $arg->{'object'};
  my $file = "/var/db/dhcpd.leases";
  my %ips;
  open (IN, '<', $file);
  my $date = `date -u +'%Y/%m/%d %H:%M:%S;'`;
  my ($actives,$mynet,$ip,$starts,$ends)=(0,'','','','');
  while (<IN>) {
    if (/^lease/) {
      my $lease=$_;
      $mynet = ($lease =~ m/($net.\d+)/);
      $ip = $1;
      ($starts,$ends)=('','');
      ## print STDERR "mynet:($mynet,$net)\n";
    }
    if ($mynet) {
      ## print STDERR "in mynet:";
      if(/starts/) {
        s/\s+starts\s+\d\s+//;
        $starts = $_;
        ## print STDERR "starts:($starts)\n";
      }elsif (/ends/) {
        s/\s+ends\s+\d\s+//;
        $ends = $_;
        ## print STDERR "ends:($ends)\n";
      }elsif (/^}/) {
        if (($starts le $date ) && ($ends ge $date)){
          if (!$ips{$ip}) {
            $actives +=1;
            $ips{$ip} = 1;
          }
          ## print STDERR "ACTIVE!}", $_;
        }else{
          ## print STDERR "not active}", $_;
          ## print STDERR "because today:($date)\n";
        }
      }
    }elsif (/^}/) {
      ## print STDERR "not in mynet}", $_;
    }
  }
  my ($warn,$crit)=($arg->{'warn'},$arg->{'crit'});
  if ($actives < $warn) {
    return("OK($actives leases)");
  }elsif ($actives < $crit) {
    return("WARNING($actives leases)");
  }else {
    return("BAD($actives leases)");
  }
};
1;
