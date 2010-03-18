package Resmon::Updater;
use strict;
use File::Find;
use IO::Socket;

my $assess;
my $newfiles;
my $changedfiles;
my %times;
my $debug;
my $resmondir;

sub update {
    # Ignore a HUP, otherwise we will kill ourselves when we try to reload
    # because we are called as 'resmon'
    $SIG{'HUP'} = 'IGNORE';

    # Debug mode (currently specified with the -d option to resmon). WARNING:
    # turning this on will reload resmon on every invocation regardless of
    # whether there were any files updated or not.
    $debug = shift;

    $resmondir = shift;

    # Check for subversion
    my $svn;
    foreach my $i (qw(svn /usr/bin/svn /usr/local/bin/svn /opt/omni/bin/svn)) {
        if (-x "$i") {
            print "Found subversion at $i\n" if $debug;
            $svn = $i;
            last;
        }
    }
    if (!$svn) {
        print STDERR "Cannot find subversion. Exiting.\n";
        return 2;
    }

    # Find the last revision, in case we need to revert
    my $last_rev=`$svn info $resmondir | awk '/^Revision/ {print \$2;}'`;
    chomp $last_rev;
    print "Last rev: $last_rev\n" if $debug;

    # Run the update
    chdir $resmondir || die "Cannot chdir to $resmondir: $!\n";

    $assess = 0;
    $newfiles = 0;
    $changedfiles = 0;
    %times = ();
    my @dirs = ("$resmondir/lib/Resmon/Module");

    find( { wanted => \&track_mod_times, no_chdir => 1 }, @dirs);
    `$svn update -q`;
    $assess = 1;
    find( { wanted => \&track_mod_times, no_chdir => 1 }, @dirs);

    print "Newfiles: $newfiles   ChangedFiles: $changedfiles\n" if $debug;

    if ($newfiles + $changedfiles || $debug) {
        print "We have changed files, reloading resmon...\n" if $debug;

        reload_resmon();
        ## Check to see if everything went OK
        sleep(3);
        if (!get_resmon_status()) {
            print STDERR "There is a problem with the update, reverting to ";
            print STDERR "revision $last_rev\n";
            my $output = `$svn update -r $last_rev $resmondir`;
            print $output if $debug;
            reload_resmon();
            return 3;
        }
        return 1;
    }
    return 0;
}

sub get_resmon_status {
    # Load resmon config file and find what port we need to connect to to
    # check if everything went OK
    my $port = 0;
    my $state, my $modstatus, my $configstatus, my $message, my $revision;

    if (!open(CONF, "<$resmondir/resmon.conf")) {
        print STDERR "Unable to open config file";
        return 0;
    }

    while(<CONF>) {
        if (/PORT\W*(.+);/) {
            $port = $1;
        }
    }
    close(CONF);
    if (!$port) {
        print STDERR "Unable to determine port";
        return 0;
    }
    print "Port is: $port\n" if $debug;

    my $host = "127.0.0.1";
    my $handle = IO::Socket::INET->new(Proto     => "tcp",
        PeerAddr  => $host,
        PeerPort  => $port);
    if (!$handle) {
        print STDERR "can't connect to port $port on $host: $!";
        return 0;
    }

    print $handle "GET /RESMON/resmon HTTP/1.0\n\n";
    while(<$handle>) {
        if (/<state>(\w+)<\/state>/) {
            $state=$1;
        } elsif (/<modstatus>(\w+)<\/modstatus>/) {
            $modstatus=$1;
        } elsif (/<configstatus>(\w+)<\/configstatus>/) {
            $configstatus=$1;
        } elsif (/<message>(.+)<\/message>/) {
            $message=$1;
        } elsif (/<revision>r(\d+)<\/revision>/) {
            $revision=$1;
        }
    }

    print "State: $state\nModules: $modstatus\n" if $debug;
    print "Config: $configstatus\nRevision: $revision\n" if $debug;
    print "Message: $message\n" if $debug;

    if ("$state" eq "OK") {
        print "Status is OK\n" if $debug;
        return 1;
    } elsif ("$state" eq "BAD") {
        print "Status is BAD\n" if $debug;
        return 0;
    } else {
        print STDERR "Unable to determine resmon status\n";
        return 0;
    }
}

sub reload_resmon {
    ## Get a process listing
    my $pscmd;
    if ($^O eq 'linux' || $^O eq 'openbsd') {
        $pscmd = 'ps ax -o pid,args';
    } elsif ($^O eq 'solaris') {
        $pscmd = 'ps -ef -o pid,args';
    }
    my $psout = `$pscmd`;

    my @procs=grep(/perl (\/opt\/resmon\/|.\/)resmon/, split(/\n/, $psout));
    foreach my $proc (@procs) {
        $proc =~ s/^\s//;
        print "$proc\n" if $debug;
        my ($pid, $args) = split(/\W/, $proc, 2);
        print "Killing PID:$pid\n" if $debug;
        kill('HUP', $pid);
    }
}

sub track_mod_times {
    my $mtime = (stat $_)[9];
    return unless -f $_;
    return if /\/\.svn$/ || /\/\.svn\//;
    if($assess == 0) {
        $times{$_} = $mtime;
    } else {
        $newfiles++ unless(exists($times{$_}));
        $changedfiles++ if(exists($times{$_}) and ($times{$_} != $mtime));
    }
}

1;
