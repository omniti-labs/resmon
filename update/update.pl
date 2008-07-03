#!/usr/bin/perl
# Copyright (c) 2006-2007, OmniTI Computer Consulting, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials provided
#      with the distribution.
#    * Neither the name OmniTI Computer Consulting, Inc. nor the names
#      of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written
#      permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use File::Find;
use IO::Socket;

my $resmondir='/opt/resmon';
# Debug mode. WARNING: turning this on will reload resmon on every invocation
# regardless of whether there were any files updated or not. This is
# incompatible with the UPDATE resmon module which will constantly reload as
# soon as an update is found.
my $debug = 0;

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
    exit 2;
}

# Find the last revision, in case we need to revert
my $last_rev=`$svn info $resmondir | awk '/^Revision/ {print \$2;}'`;
chomp $last_rev;
print "Last rev: $last_rev\n" if $debug;

# Run the update
chdir $resmondir || die "Cannot chdir to $resmondir: $!\n";

my $assess = 0;
my $newfiles = 0;
my $changedfiles = 0;
my %times = ();
my @dirs = ("$resmondir/lib/Resmon/Module");

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

find( { wanted => \&track_mod_times, no_chdir => 1 }, @dirs);
`$svn update -q`;
$assess = 1;
find( { wanted => \&track_mod_times, no_chdir => 1 }, @dirs);

print "Newfiles: $newfiles   ChangedFiles: $changedfiles\n" if $debug;

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
        exit 3;
    }
    exit 1;
}
