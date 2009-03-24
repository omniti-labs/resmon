package Resmon::Module::REMOTEFILESIZE;
use vars qw/@ISA/;
use Resmon::ExtComm qw/cache_command/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $host = $arg->{'host'};
  my $file = $arg->{'object'};
  my $output = cache_command("ssh -i /root/.ssh/id_dsa $host du -k $file", 600);
  $output =~ /^(\d+)\s/; 
  my $size = $1 * 1024;
  my $minsize = $arg->{minimum};
  my $maxsize = $arg->{maximum};
  return "BAD($size, too big)"
        if($maxsize && ($size > $maxsize));
  return "BAD($size, too small)"
        if($minsize && ($size > $minsize));
  return "OK($size)";
}
1;
