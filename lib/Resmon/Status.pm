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
sub new {
  my $class = shift;
  my $file = shift;
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
  my $VAR1;
  eval $blob;
  die $@ if ($@);
  $self->{store} = $VAR1;
  return $self->{store};
}
sub store_shared_state {
  my $self = shift;
  return unless($self->{shared_state});
  my $blob = Dumper($self->{store});

  # Lock shared segment
  # Write state and flush
  shmwrite($self->{shared_state}, pack('i', length($blob)),
           0, length(pack('i', 0))) || die "$!";
  shmwrite($self->{shared_state}, $blob, length(pack('i', 0)),
           length($blob)) || die "$!";
  # unlock
}
sub xml_kv_dump {
  my $info = shift;
  my $indent = shift || 0;
  my $rv = '';
  while(my ($key, $value) = each %$info) {
    $rv .= " " x $indent;
    if(ref $value eq 'HASH') {
      $rv .= "<$key>\n";
      $rv .= xml_kv_dump($value, $indent + 2);
      $rv .= " " x $indent;
      $rv .= "</$key>\n";
    }
    else {
      $rv .= "<$key>$value</$key>\n";
    }
  }
  return $rv;
}
sub xml_info {
  my ($module, $service, $info) = @_;
  my $rv = '';
  $rv .= "  <ResmonResult module=\"$module\" service=\"$service\">\n";
  $rv .= xml_kv_dump($info, 4);
  $rv .= "  </ResmonResult>\n";
  return $rv;
}
sub dump_generic {
  my $self = shift;
  my $dumper = shift;
  my $rv = '';
  while(my ($module, $services) = each %{$self->{store}}) {
    while(my ($service, $info) = each %$services) {
      $rv .= $dumper->($module,$service,$info);
    }
  }
  return $rv;
}
sub dump_oldstyle {
  my $self = shift;
  my $response = $self->dump_generic(sub {
    my($module,$service,$info) = @_;
    return "$service($module) :: $info->{state}($info->{message})\n";
  });
  return $response;
}
sub dump_xml {
  my $self = shift;
  my $response = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<ResmonResults>
EOF
  ; 
  $response .= $self->dump_generic(\&xml_info);
  $response .= "</ResmonResults>\n";
  return $response;
}
sub service {
  my $self = shift;
  my ($client, $req, $proto) = @_;
  my $state = $self->get_shared_state();
  if($req eq '/' or $req eq '/status') {
    my $response .= $self->dump_xml();
    $client->print(http_header(200, $proto?length($response):0));
    $client->print($response . "\r\n");
    return;
  } elsif($req eq '/status.txt') {
    my $response = $self->dump_oldstyle();
    $client->print(http_header(200, $proto?length($response):0, 'text/plain'));
    $client->print($response . "\r\n");
    return;
  } else {
    if($req =~ /^\/([^\/]+)\/(.+)$/) {
      if(exists($self->{store}->{$1}) &&
         exists($self->{store}->{$1}->{$2})) {
        my $info = $self->{store}->{$1}->{$2};
        my $response = qq^<?xml version="1.0" encoding="UTF-8"?>\n^;
        $response .= "<ResmonResults>\n".
                     xml_info($1,$2,$info).
                     "</ResmonRestults>\n";
        $client->print(http_header(200, $proto?length($response):0));
        $client->print( $response . "\r\n");
        return;
      }
    }
  }
  die "Request not understood\n";
}
sub http_header {
  my $code = shift;
  my $len = shift;
  my $type = shift || 'text/xml';
  return qq^HTTP/1.0 $code OK
Server: resmon
^ . (defined($len) ? "Content-length: $len" : "Connection: close") . q^
Content-Type: text/plain; charset=utf-8

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

  $self->{zindex} = 0;
  if (-x "/usr/sbin/zoneadm") {
    open(Z, "/usr/sbin/zoneadm list -p |");
    my $firstline = <Z>;
    close(Z);
    ($self->{zindex}) = split /:/, $firstline, 2;
  }
  $self->{http_port} = $port;
  $self->{http_ip} = $ip;
  $self->{ftok_number} = $port * (1 + $self->{zindex});

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
            if(!$req) {
              if(/^GET \s*(\S+)\s*?(?: HTTP\/(0\.9|1\.0|1\.1)\s*)?$/) {
                $req = $1;
                $proto = $2;
              }
              else {
                die "protocol deviations.\n";
              }
            }
            elsif(/^$/) {
              $self->service($client, $req, $proto);
              last unless ($proto);
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
            print $client http_header(500, 0, 'text/plain');
            print $client "$@\r\n";
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
    $self->{handle_is_stdout} = 1;
    $self->{handle} = IO::File->new_from_fd(fileno(STDOUT), "w");
    return 1;
  }
  $self->{handle} = IO::File->new("> $self->{file}.swap");
  die "open $self->{file}.swap failed: $!\n" unless($self->{handle});
  $self->{swap_on_close} = 1; # move this to a non .swap version on close
  chmod 0644, "$self->{file}.swap";

  unless($self->{shared_state}) {
    my $id = ftok(__FILE__,$self->{ftok_number});
    $self->{shared_state} = shmget($id, $SEGSIZE,
                                   IPC_CREAT|S_IRWXU|S_IRWXG|S_IRWXO)
      || die "$0: $!";
  }
  return 1;
}
sub store {
  my ($self, $type, $name, $info) = @_;
  %{$self->{store}->{$type}->{$name}} = %$info;
  $self->{store}->{$type}->{$name}->{last_update} = time;
  $self->store_shared_state();
  if($self->{handle}) {
    $self->{handle}->print("$name($type) :: $info->{state}($info->{message})\n");
  } else {
    print "$name($type) :: $info->{state}($info->{message})\n";
  }
}
sub close {
  my $self = shift;
  return if($self->{handle_is_stdout});
  $self->{handle}->close() if($self->{handle});
  $self->{handle} = undef;
  if($self->{swap_on_close}) {
    unlink("$self->{file}");
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
