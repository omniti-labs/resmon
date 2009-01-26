package Resmon::Module::ZFSYNCHECK;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
use Time::Local;
use Time::Local;($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time-84600); print "$mon/$mday/$year";
@ISA = qw/Resmon::Module/;
my $arg=shift;
my $zfs=$arg->{'object'};
my $age=$arg->{'age'}*86400+43200;
sub handler {
  my $output = cache_command("zfs list -t snapshot -s creation | grep $zfs | tail -1", 300);
  if ($output =~ m!$zfs.%?([0-9]{4,4})([0-9]{2,2})([0-9]{2,2})!){
    my ($sy,$sm,$sd)=($1,$2,$3);
    my $snaptime=timelocal(0,15,23,$sd,$sm-1,$sy-1900);
    my $yesterday=time-$age;
    if($yesterday < $snaptime) {
      return "OK(snapshot $sm/$sd $sy)";
    }else{
      return "BAD(snapshot $sm/$sd $sy)";
    }
  }
  return "BAD(output $output)";
};
1;

