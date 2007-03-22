package Resmon::Status;

use strict;
use POSIX qw/:sys_wait_h/;
use IO::Handle;
use IO::File;
use IO::Socket;
use Socket;
use Fcntl qw/:flock/;
use IPC::SysV qw /IPC_CREAT IPC_RMID ftok S_IRWXU S_IRWXG S_IRWXO/;
use Data::Dumper;

my $SEGSIZE = 1024*256;
my $statusfile;
sub new {
  my $class = shift;
  my $file = shift;
  return $statusfile if($statusfile);
  return bless {
    file => $file
  }, $class;
}
sub get_shared_state {
  my $self = shift;
  my $blob;
  my $len;
  return unless($self->{shared_state});
  # Lock shared segment
  # Read in
  shmread($self->{shared_state}, $len, 0, length(pack('i', 0)));
  $len = unpack('i', $len);
  shmread($self->{shared_state}, $blob, length(pack('i', 0)), $len);
  # unlock
  die "LEN: $len [$blob]\n";
  $self->{store} = eval $blob;
  return $self->{store};
}
sub store_shared_state {
  my $self = shift;
  return unless($self->{shared_state});
  my $blob = Dumper($self->{store});

  # Lock shared segment
  # Write state and flush
  shmwrite($self->{shared_state}, pack("l", length($blob)),
           0, length(pack('i', 0))) || die "$!";
  shmwrite($self->{shared_state}, $blob, length(pack('i', 0)),
           length($blob) - length(pack('i', 0))) || die "$!";
  # unlock
}
sub service {
  my $self = shift;
  my ($client, $req, $proto) = @_;
  my $state = $self->get_shared_state();
  if($req eq '/' or $req eq '/status' or $req eq '/status.txt') {
    my $response = Dumper($self->{store});
    print $client http_header(200, length($response)) if($proto);
    print $client $response . "\r\n";
  }
}
sub http_header {
  my $code = shift;
  my $len = shift;
  return qq^HTTP/1.0 $code OK
Server: resmon
^ . (defined($len) ? "Content-length: $len" : "Connection: close") . q^
Content-Type: text/plain

^;
}
sub serve_http_on {
  my $self = shift;
  my $ip = shift;
  my $port = shift;
  $ip = INADDR_ANY if(!defined($ip) || $ip eq '' || $ip eq '*');
  $port ||= 81;

  my $handle = IO::Socket->new();
  socket($handle, PF_INET, SOCK_STREAM, getprotobyname('tcp'))
    || die "socket: $!";
  setsockopt($handle, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
    || die "setsockopt: $!";
  bind($handle, sockaddr_in($port, $ip))
    || die "bind: $!";
  listen($handle,SOMAXCONN);

  $self->{http_port} = $port;
  $self->{http_ip} = $ip;

  $self->{child} = fork();
  if($self->{child} == 0) {
    eval {
      while(my $client = $handle->accept) {
        my $req;
        my $proto;
        while(<$client>) {
          eval {
            s/\r\n/\n/g;
            chomp;
print "CLIENT <= $_\n";
            if(!$req) {
              if(/^GET \s*(\S+) \s*HTTP\/(0\.9|1\.0|1\.1)\s*$/) {
                $req = $1;
                $proto = $2;
              }
              elsif(/^GET \s*(\S+)\s*$/) {
                $req = $1;
                $proto = undef;
              }
              else {
                die "protocol deviations.\n";
              }
            }
            elsif(/^$/) {
              $self->service($client, $req, $proto);
              $req = undef;
              $proto = undef;
            }
            elsif(/^\S+\s*:\s*.{1,4096}$/) {
              # Valid request header... noop
            }
            else {
              die "protocol deviations.\n";
            }
          };
          if($@) {
            print $client http_header(500);
            print $client "$@";
            last;
          }
        }
        $client->close();
      }
    };
    if($@) {
      print STDERR "Error in listener: $@\n";
    }
    exit(0);
  }
  close($handle);
  return;
}
sub open {
  my $self = shift;
  return 0 unless(ref $self);
  return 1 if($self->{handle});  # Alread open
  if($self->{file} eq '-' || !defined($self->{file})) {
    $self->{handle} = IO::File->new_from_fd(fileno(STDOUT), "w");
    return 1;
  }
  $self->{handle} = IO::File->new("> $self->{file}.swap");
  die "open $self->{file}.swap failed: $!\n" unless($self->{handle});
  $self->{swap_on_close} = 1; # move this to a non .swap version on close
  chmod 0644, "$statusfile.swap";

  unless($self->{shared_state}) {
    my $id = ftok(__FILE__,$self->{http_port});
    $self->{shared_state} = shmget($id, $SEGSIZE,
                                   IPC_CREAT|S_IRWXU|S_IRWXG|S_IRWXO)
      || die "$0: $!";
  }
  return 1;
}
sub store {
  my ($self, $type, $name, $state, $mess) = @_;
  $self->{store}->{$type}->{$name} = {
    last_update => time,
    state => $state,
    message => $mess
  };
  $self->store_shared_state();
  if($self->{handle}) {
    $self->{handle}->print("$name($type) :: $state($mess)\n");
  } else {
    print "$name($type) :: $state($mess)\n";
  }
}
sub close {
  my $self = shift;
  $self->{handle}->close() if($self->{handle});
  $self->{handle} = undef;
  if($self->{swap_on_close}) {
    link("$self->{file}.swap", $self->{file});
    unlink("$self->{file}.swap");
    delete($self->{swap_on_close});
  }
}
sub DESTROY {
  my $self = shift;
  my $child = $self->{child};
  if($child) {
    kill 15, $child;
    sleep 1;
    kill 9, $child if(kill 0, $child);
    waitpid(-1,WNOHANG);
  }
  if($self->{shared_state}) {
    shmctl($self->{shared_state}, IPC_RMID, 0);
  }
}
1;
