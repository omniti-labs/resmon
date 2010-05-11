package Resmon::Status;

use strict;
use warnings;
use POSIX qw/:sys_wait_h/;
use IO::Handle;
use IO::File;
use IO::Socket;
use Socket;
use Fcntl qw/:flock/;
use IPC::SysV qw /IPC_PRIVATE IPC_CREAT IPC_RMID S_IRWXU S_IRWXG S_IRWXO/;
use Data::Dumper;

my $SEGSIZE = 1024*256;
my $KEEPALIVE_TIMEOUT = 5;
my $REQUEST_TIMEOUT = 60;
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
    return unless(defined($self->{shared_state}));
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
    return unless(defined($self->{shared_state}));
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
        if(ref $value eq 'HASH') {
            while (my ($k, $v) = each %$value) {
                $rv .= " " x $indent;
                $rv .= "<$key name=\"$k\"";
                if (ref($v) eq 'ARRAY') {
                    # A value/type pair
                    my $type = $v->[1];
                    if ($type !~ /^[0iIlLns]$/) {
                        $type = "0";
                    }
                    $rv .= " type=\"$type\"";
                    $v = $v->[0];
                }
                $v = xml_escape($v);
                $rv .= ">$v</$key>\n";
            }
        } else {
            $rv .= " " x $indent;
            $value = xml_escape($value);
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

sub xml_escape {
    my $v = shift;
    $v =~ s/&/&amp;/g;
    $v =~ s/</&lt;/g;
    $v =~ s/>/&gt;/g;
    $v =~ s/'/&apos;/g;
    return $v;
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

sub dump_generic_module {
    # Dumps a single module rather than all checks
    my $self = shift;
    my $dumper = shift;
    my $module = shift;
    my $rv = '';
    my $services = $self->{store}->{$module};
    while(my ($service, $info) = each %$services) {
        $rv .= $dumper->($module,$service,$info);
    }
    return $rv;
}
sub dump_xml {
    my $self = shift;
    my $response = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="/resmon.xsl"?>
<ResmonResults>
EOF
    ; 
    $response .= $self->dump_generic(\&xml_info);
    $response .= "</ResmonResults>\n";
    return $response;
}
sub get_xsl() {
    my $response = <<EOF
<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="ResmonResults">
<html>
<head>
    <title>Resmon Results</title>
    <link rel="stylesheet" type="text/css" href="/resmon.css" />
</head>
<body>
    <p>
    Total checks:
    <xsl:value-of select="count(ResmonResult)" />
    </p>
    <xsl:for-each select="ResmonResult">
        <xsl:sort select="\@module" />
        <xsl:sort select="\@service" />
        <div class="item">
            <div class="info">
                Last check: <xsl:value-of select="last_runtime_seconds" />
                /
                Last updated: <xsl:value-of select="last_update" />
            </div>
            <h1>
                <a>
                    <xsl:attribute name="href">
                        /<xsl:value-of select="\@module" />
                    </xsl:attribute>
                    <xsl:value-of select="\@module" />
                </a>`<a>
                    <xsl:attribute name="href">
                        /<xsl:value-of select="\@module"
                            />/<xsl:value-of select="\@service" />
                    </xsl:attribute>
                    <xsl:value-of select="\@service" />
                </a>
            </h1>
            <ul>
                <xsl:for-each select="metric">
                    <xsl:sort select="\@name" />
                    <li><xsl:value-of select="\@name" /> = 
                    <xsl:value-of select="." /></li>
                </xsl:for-each>
            </ul>
        </div>
    </xsl:for-each>
</body>
</html>
</xsl:template>
</xsl:stylesheet>
EOF
    ;
    return $response;
}
sub get_css() {
    my $response=<<EOF
body {
    font-family: Verdana, Arial, helvetica, sans-serif;
}

h1 {
    margin: 0;
    font-size: 120%;
}

h2 {
    margin: 0;
    font-size: 110%;
}

.item {
    border: 1px solid black;
    border-left: 10px solid #999;
    padding: 1em;
    margin: 2em;
    background-color: #eeeeee;
}

.info {
    float: right;
    font-size: 80%;
    padding: 0;
    margin: 0;
}

table {
    border: 1px solid black;
    background-color: #eeeeee;
    border-collapse: collapse;
    margin: 1em;
    font-size: 80%;
}

th {
    font-size: 100%;
    font-weight: bold;
    background-color: black;
    color: white;
}

td {
    padding-left: 1em;
    padding-right: 1em;
}

a {
    text-decoration: none;
}

a.metrics, a.metrics:visited {
    color: black;
}

a.metrics table {
    display: none;
}

a.metrics:hover table {
    display: block;
    position: relative;
    top: 1em;
    right: 1em;
    max-width: 95%;
    overflow: hidden;
}
EOF
    ;
    return $response;
}

sub service {
    my $self = shift;
    my ($client, $req, $proto, $snip, $authuser, $authpass) = @_;
    my $state = $self->get_shared_state();
    if (defined($self->{authuser}) && $self->{authuser} ne "" &&
        ($authuser ne $self->{authuser} || $authpass ne $self->{authpass})) {
        my $response = "<html><head><title>Password required</title></head>" .
        "<body><h1>Password required</h1></body></html>";
        $client->print(http_header(401, length($response), 'text/html', $snip,
                "WWW-Authenticate: Basic realm=\"Resmon\"\n"));
        $client->print($response . "\r\n");
        return;
    } elsif($req eq '/') {
        my $response .= $self->dump_xml();
        $client->print(http_header(200, length($response), 'text/xml', $snip));
        $client->print($response . "\r\n");
        return;
    } elsif($req eq '/resmon.xsl') {
        my $response = $self->get_xsl();
        $client->print(http_header(200, length($response), 'text/xml', $snip));
        $client->print($response . "\r\n");
        return;
    } elsif($req eq '/resmon.css') {
        my $response = $self->get_css();
        $client->print(http_header(200, length($response), 'text/css', $snip));
        $client->print($response . "\r\n");
        return;
    } elsif($req =~ /^\/([^\/]+)\/(.+)$/) {
        if(exists($self->{store}->{$1}) &&
            exists($self->{store}->{$1}->{$2})) {
            my $info = $self->{store}->{$1}->{$2};
            my $response = qq^<?xml version="1.0" encoding="UTF-8"?>\n^;
            $response .= qq^<?xml-stylesheet type="text/xsl" href="/resmon.xsl"?>^;
            $response .= "<ResmonResults>\n".
            xml_info($1,$2,$info).
            "</ResmonResults>\n";
            $client->print(http_header(200, length($response), 'text/xml', $snip));
            $client->print( $response . "\r\n");
            return;
        }
    } elsif($req =~ /^\/([^\/]+)$/) {
        if(exists($self->{store}->{$1})) {
            my $response = qq^<?xml version="1.0" encoding="UTF-8"?>\n^;
            $response .= qq^<?xml-stylesheet type="text/xsl" href="/resmon.xsl"?>^;
            $response .= "<ResmonResults>\n".
            $self->dump_generic_module(\&xml_info,$1) .
            "</ResmonResults>\n";
            $client->print(http_header(200, length($response), 'text/xml', $snip));
            $client->print( $response . "\r\n");
            return;
        }
    }
    die "Request not understood\n";
}

sub http_header {
    my $code = shift;
    my $len = shift;
    my $type = shift || 'text/xml';
    my $close_connection = shift || 1;
    my $extra_headers = shift || "";
    return "HTTP/1.0 $code OK\nServer: resmon\n" .
        (defined($len) ? "Content-length: $len\n" : "") .
    (($close_connection || !$len) ? "Connection: close\n" : "") .
    "Content-Type: $type; charset=utf-8\n" . $extra_headers . "\n";
}

sub base64_decode($) {
    # Base64 decoding for basic auth
    # We cheat when doing the decoding - perl can do uudecoding using unpack -
    # so we just convert to uuencoded text and decode that.
    my $enc = shift;
    if (length($enc) % 4 != 0) { return "" } # Length should be multiple of 4
    $enc =~ tr#A-Za-z0-9+/=##cd; # Ignore any invalid characters
    $enc =~ tr#A-Za-z0-9+/=# -_#d; # Convert base64 to uuencode alphabet and
    # strip padding
    if (length($enc) > 63) { return "" }; # Only support up to 63 chars
    # (one uuencoded line)
    my $len = chr(32 + length($enc)*3/4); # uuencode has a length byte at the
    # beginning
    return unpack("u", $len.$enc);
}

sub serve_http_on {
    my $self = shift;
    my $ip = shift;
    my $port = shift;
    $self->{authuser} = shift;
    $self->{authpass} = shift;
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

    $self->{parent_pid} = $$;
    $self->{child} = fork();
    if($self->{child} == 0) {
        eval {
            $SIG{'HUP'} = 'IGNORE';
            $SIG{'PIPE'} = 'IGNORE';
            while(my $client = $handle->accept) {
                my $req;
                my $proto;
                my $close_connection;
                my $authuser;
                my $authpass;
                local $SIG{ALRM} = sub { die "timeout\n" };
                eval {
                    alarm($KEEPALIVE_TIMEOUT);
                    while(<$client>) {
                        alarm($REQUEST_TIMEOUT);
                        eval {
                            s/\r\n/\n/g;
                            chomp;
                            if(!$req) {
                                if(/^GET \s*(\S+)\s*?(?: HTTP\/(0\.9|1\.0|1\.1)\s*)?$/) {
                                    $req = $1;
                                    $proto = $2;
                                    # Protocol 1.1 and high are keep-alive by
                                    # default
                                    $close_connection = ($proto <= 1.0)?1:0;
                                }
                                elsif(/./) {
                                    die "protocol deviations.\n";
                                }
                            }
                            else {
                                if(/^$/) {
                                    $self->service($client, $req, $proto, $close_connection,
                                        $authuser, $authpass);
                                    last if ($close_connection);
                                    alarm($KEEPALIVE_TIMEOUT);
                                    $req = undef;
                                    $proto = undef;
                                }
                                elsif(/^\S+\s*:\s*.{1,4096}$/) {
                                    # Valid request header... noop
                                    if(/^Connection: (\S+)/) {
                                        if(($proto <= 1.0 && lc($2) eq 'keep-alive') ||
                                            ($proto == 1.1 && lc($2) ne 'close')) {
                                            $close_connection = 0;
                                        }
                                    }
                                    if(/^Authorization: Basic (\S+)/) {
                                        my $dec = base64_decode($1);
                                        ($authuser, $authpass) = split /:/, $dec, 2
                                    }
                                }
                                else {
                                    die "protocol deviations.\n";
                                }
                            }
                        };
                        if($@) {
                            print $client http_header(500, 0, 'text/plain', 1);
                            print $client "$@\r\n";
                            last;
                        }
                    }
                    alarm(0);
                };
                alarm(0) if($@);
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
    return 1 if($self->{handle});  # Already open
    if($self->{file} eq '-' || !defined($self->{file})) {
        # We'll use stdout instead - no file handle needed
        return 1;
    }
    $self->{handle} = IO::File->new("> $self->{file}.swap");
    die "open $self->{file}.swap failed: $!\n" unless($self->{handle});
    $self->{swap_on_close} = 1; # move this to a non .swap version on close
    chmod 0644, "$self->{file}.swap";

    unless(defined($self->{shared_state})) {
        $self->{shared_state} = shmget(IPC_PRIVATE, $SEGSIZE,
            IPC_CREAT|S_IRWXU|S_IRWXG|S_IRWXO);
        die "$0: $!" unless (defined $self->{shared_state});
    }
    return 1;
}

sub store {
    my ($self, $type, $name, $info) = @_;
    %{$self->{store}->{$type}->{$name}} = %$info;
    $self->{store}->{$type}->{$name}->{last_update} = time;
    $self->store_shared_state();
}

sub clear {
    # Clear all state after a reload
    my $self = shift;
    $self->{store} = {};
    $self->store_shared_state;
}

sub write {
    # Writes the metrics output for a single check to stdout and/or a file
    my ($self, $module_name, $check_name, $metrics, $debug) = @_;
    my $metrics_output = "$module_name`$check_name\n";
    while (my ($k, $v) = each (%$metrics)) {
        if (ref($v) eq "ARRAY") {
            $v = $v->[0];
        }
        $metrics_output .= "    $k = $v\n";
    }
    if($self->{handle}) {
        $self->{handle}->print($metrics_output);
    }
    if (!$self->{handle} || $debug) {
        print $metrics_output;
    }
}

sub close {
    my $self = shift;
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
    # Make sure we're really the parent process
    return if ($self->{parent_pid} != $$);
    my $child = $self->{child};
    if ($child) {
        kill 15, $child;
        sleep 1;
        kill 9, $child if(kill 0, $child);
        waitpid(-1,WNOHANG);
    }
    if(defined($self->{shared_state})) {
        shmctl($self->{shared_state}, IPC_RMID, 0);
    }
}
1;
