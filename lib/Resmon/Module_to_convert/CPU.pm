package Resmon::Module::CPU;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
    my $arg = shift;
    my $timeperiod = 1;
    my $limit = $arg->{'limit'} || "90";
    my $output = cache_command("vmstat $timeperiod 2", 60);
    my @lines = split(/\n/, $output);
    for (@lines) {
        if($_ =~ /us sy/) {
            # we have a header line
            @headers = split(/ +/, $_);
            break;
        }
    }

    @vals = split(/ +/, $lines[-1]);

    $cpuuser = 0;
    $cpusys  = 0;
    $cpuwait = 0;
    $havewait = 0;

    $fieldcount = @headers;
    # Look at the field header names to determine which values to use
    for (my $i=0; $i < $fieldcount; $i++) {
        # Need to compare previous/next header because solaris has two 'sy'
        # values - one for cpu and one for interrupts
        if ($headers[$i] eq 'us' && $headers[$i+1] eq 'sy') {
            $cpuuser = $vals[$i];
        }
        if ($headers[$i] eq 'sy' && $headers[$i-1] eq 'us') {
            $cpusys = $vals[$i];
        }
        # Wait appears to be a linux thing, so on other platforms it will just
        # be 0
        if ($headers[$i] eq 'wa') {
            $cpuwait = $vals[$i];
            $havewait = 1;
        }
    }

    #print "$cpuuser, $cpusys, $cpuwait\n";
    $total = $cpuuser + $cpusys + $cpuwait;

    $summary = "- us:$cpuuser sy:$cpusys";
    if ($havewait) {
        $summary = "$summary wa:$cpuwait";
    }

    if ($total > $limit) {
        return "BAD", "$total > $limit $summary";
    } else {
        return "OK", "$total <= $limit $summary";
    }

    return "BAD", "Unable to determine cpu info";
};
1;
