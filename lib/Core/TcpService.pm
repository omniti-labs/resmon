package Core::TcpService;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);
use Socket;
use Fcntl;
use IO::Select;
use IO::Handle;

=pod

=head1 NAME

Core::TcpService - Test connections to a TCP service.

=head1 SYNOPSIS

 Core::TcpService {
     connect : noop
 }

 Core::TcpService {
     connect : host => 127.0.0.1, port => 22, timeout => 10
 }

=head1 DESCRIPTION

This module connects to TCP services and tests for a response.

=head1 CONFIGURATION

=over

=item check_name

The check name is used for descriptive purposes only.  It is not used for
anything functional.

=item host

The host to connect to (required).

=item port

The port to connect to (required).

=item timeout

Override the default timeout value (optional).  Default value is 5.

=item prepost

A string to send on connection (optional).  Useful if the service requires
something to be entered before showing a banner.

=item post

A string to send after the initial banner (optional).

=back

=head1 METRICS

=over

=item status

Status of the connection attempt.

=item banner

Banner string returned by the target service, if available.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $host = $config->{'host'} || die "Host is required";
    my $port = $config->{'port'} || die "Port is required";
    my $timeout = $config->{'timeout'} || 5;
    my $banner;
    my $proto = getprotobyname('tcp');
    my $c = IO::Select->new();
    my $h = IO::Handle->new();

    socket($h, Socket::PF_INET, Socket::SOCK_STREAM, $proto) || return { 'status' => ['socket error', 's'] };
    $h->autoflush(1);

    fcntl($h, Fcntl::F_SETFL, Fcntl::O_NONBLOCK) || (close($h) && return { 'status' => ['fcntl error', 's'] } );

    my $s = Socket::sockaddr_in($port, Socket::inet_aton($host));
    connect($h, $s);
    $c->add($h);
    my ($fd) = $c->can_write($timeout);
    if ($fd == $h) {
        my $error = unpack("s", getsockopt($h, Socket::SOL_SOCKET, Socket::SO_ERROR));
        if ($error != 0) {
            close($h);
            return { 'status' => ['connection failed', 's'] };
        }
        print $h $config->{'prepost'}."\r\n" if ($config->{'prepost'});
        ($fd) = $c->can_read($timeout);
        if ($fd == $h) {
            chomp($banner = <$h>);
            print $h $config->{'post'} if ($config->{'post'});
            close($h);
            $banner =~ s/([^\s\d\w.,;\/\\])/sprintf "\\%o", $1/eg;
        }
    }
    close($h);

    return {
        'banner' => [$banner, 's'],
        'status' => ['connection successful', 's']
    };
};

1;

