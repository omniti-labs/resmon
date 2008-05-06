package Resmon::Module::DHCPLEASES;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $net = $arg->{'object'};
  my $file = "/var/db/dhcpd.leases";
  open (IN, '<', $file);
  my $date = `date +'%Y/%m/%e %H:%M:%S;'`;
  my ($actives,$mynet,$starts,$ends)=(0,'','');
  while (<IN>) {
    if (/^lease/) {
      my $lease=$_;
      $mynet = ($lease =~ m/$net/);
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
          $actives =+1;
          print STDERR "ACTIVE!}", $_;
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
    return($arg->set_status("OK($actives leases)"));
  }elsif ($actives < $crit) {
    return($arg->set_status("WARN($actives leases > $warn)"));
  }else {
    return($arg->set_status("BAD($actives leases > $crit!)"));
  }
};
