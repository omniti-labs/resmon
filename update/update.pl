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

my $resmondir='/opt/resmon';
my $debug = 1;

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
    exit -1;
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
        print "$proc\n" if $debug;
        my ($pid, $args) = split(/\W/, $proc, 2);
        kill('HUP', $pid);
    }
}

sub get_resmon_status {
    # Load resmon config file and find what port we need to connect to to
    # check if everything went OK
    my $statusfile = 0;
    if (!open(CONF, "<$resmondir/resmon.conf")) {
        print STDERR "Unable to open config file";
        return 0;
    }

    while(<CONF>) {
        if (/STATUSFILE\W*(.+);/) {
            $statusfile = $1;
        }
    }
    close(CONF);
    if (!$statusfile) {
        print STDERR "Unable to determine the status file";
        return 0;
    }
    print "Status file is: $statusfile\n" if $debug;

    if (!open(STAT, "<$statusfile")) {
        print STDERR "Unable to open status file\n";
        return 0;
    }
    while(<STAT>) {
        if (/resmon\(RESMON\) :: ([A-Z]+)/) {
            if ("$1" eq "OK") {
                print "Status is OK\n" if $debug;
                return 1;
            } else {
                print "Status is BAD\n" if $debug;
                return 0;
            }
        }
    }
    print STDERR "Unable to determine resmon status\n";
    return 0;
}

if ($newfiles + $changedfiles || $debug) {
    print "We have changed files, reloading resmon...\n" if $debug;

    reload_resmon();
    ## Check to see if everything went OK
    sleep(3);
    if (!get_resmon_status()) {
        print STDERR "There is a problem with the update, reverting\n";
        `$svn update -r $last_rev $resmondir`;
        reload_resmon();
    }
}
