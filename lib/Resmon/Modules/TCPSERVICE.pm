package Resmon::Modules::TCPSERVICE;

use Socket;
use Fcntl;
use IO::Select;
use IO::Handle;
use Resmon::Modules;

use vars qw/@ISA/;
@ISA = qw/Resmon::Modules/;

sub handler {
  my $self = shift;
  my $os = $self->fresh_status();
  return $os if $os;
  my $host = $self->{host};
  my $port = $self->{port};
  my $timeout = $self->{timeout} || 5;
  my $proto = getprotobyname('tcp');
  my $con = new IO::Select();
  my $handle = new IO::Handle;
  socket($handle, Socket::PF_INET, Socket::SOCK_STREAM, $proto) ||
    return "BAD(socket error)";
  $handle->autoflush(1);
  fcntl($handle, Fcntl::F_SETFL, Fcntl::O_NONBLOCK) ||
    (close($handle) && return "BAD(fcntl error)");
  my $sin = Socket::sockaddr_in($port, Socket::inet_aton($host));
  connect($handle, $sin);
  $con->add($handle);
  my ($fd) = $con->can_write($timeout);
  if($fd == $handle) {
    my $error = unpack("s", getsockopt($handle, Socket::SOL_SOCKET,
					Socket::SO_ERROR));
    if($error != 0) {
      close($handle);
      return "BAD(connect failed)";
    }
    print $handle $self->{prepost}."\r\n" if ($self->{prepost});
    ($fd) = $con->can_read($timeout);
    if($fd == $handle) {
      my $banner;
      chomp($banner = <$handle>);
      print $handle $self->{post} if ($self->{post});
      close($handle);
      $banner =~ s/([^\s\d\w.,;\/\\])/sprintf "\\%o", $1/eg;
      return "BAD($banner)"
        if($self->{match} && ($banner =! /$self->{match}/));
      return "OK($banner)";
    }
  }
  close($handle);
  return "BAD(timeout)";
}

1;
