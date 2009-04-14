package Resmon::Module::MDSTAT;
use strict;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

my $statfile = '/proc/mdstat';

sub handler {
    my $arg = shift;
    open FH, "<$statfile";
    my $getnext = 0;
    my $status = "BAD";
    while (<FH>) {
        chomp;
        if ($getnext == 1) {
            print STDERR $_;
            $getnext = 0;
        } elsif (/^md[0-9]+\s*:\s+/) {
            foreach my $part (split(/ /,$')) {
                if ($part =~ /active/) {
                    $status = "OK";
                }
                # TODO - degraded etc.
                elsif ($part =~ /^([a-z0-9]+)\[(\d+)\](?:\((\S+)\))?$/) {
                    # We have a drive status
                    print STDERR "status: $1 $2 $3\n";
                }
            }
            $getnext = 1;
        }
    }
};
1;
