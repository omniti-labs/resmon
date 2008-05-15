package Resmon::Module::REMOTEFILESIZE;
use vars qw/@ISA/;
use Resmon::ExtComm qw/cache_command/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $host = $arg->{'host'};
  my $file = $arg->{'object'};
  my $output = cache_command("ssh -i /root/.ssh/id_dsa $host du -b $file", 600);
  $output =~ /^(\d+)\s/; 
  my $size = $1;
  my $minsize = $arg->{minimum};
  my $maxsize = $arg->{maximum};
  return $arg->set_status("BAD(too big, $size > $maxsize)")
        if($maxsize && ($size > $maxsize));
  return $arg->set_status("BAD(too small, $size < $minsize)")
        if($minsize && ($size > $minsize));
  return $arg->set_status("OK($size)");
}
1;
