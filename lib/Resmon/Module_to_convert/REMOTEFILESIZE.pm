package Resmon::Module::REMOTEFILESIZE;
use vars qw/@ISA/;
use Resmon::ExtComm qw/cache_command/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $host;
  my $file;
  # Specify the host in hostname/path/to/file format, this method allows
  # you to monitor the same file on multiple hosts
  ($host, $file) = $arg->{'object'} =~ /^([^\/]+)?(\/.*)$/;
  # Specify host as a paramater. This method doesn't allow you to monitor
  # the same file on multiple hosts
  $host ||= $arg->{'host'};
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
