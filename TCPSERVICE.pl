#!/usr/bin/perl

use Socket;
use Fcntl;
use IO::Select;
use IO::Handle;

register_monitor('TCPSERVICE',
sub {
  my $arg = shift;
  my $os = fresh_status($arg);
  return $os if $os;
  my $host = $arg->{host};
  my $port = $arg->{port};
  my $timeout = $arg->{timeout} || 5;
  my $proto = getprotobyname('tcp');
  my $con = new IO::Select();
  my $handle = new IO::Handle;
  socket($handle, Socket::PF_INET, Socket::SOCK_STREAM, $proto) ||
    return "BAD(socket error)";
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
    ($fd) = $con->can_read($timeout);
    if($fd == $handle) {
      my $banner;
      chomp($banner = <$handle>);
      print $handle $arg->{post} if ($arg->{post});
      close($handle);
      return "BAD($banner)"
        if($arg->{match} && ($banner =! /$arg->{match}/));
      return "OK($banner)";
    }
  }
  close($handle);
  return "BAD(timeout)";
});

1;
