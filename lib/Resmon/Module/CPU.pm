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

    $fieldcount = @headers;
    for (my $i=0; $i < $fieldcount; $i++) {
        if ($headers[$i] eq 'us') {
            $cpuuser = $vals[$i];
        }
        if ($headers[$i] eq 'sy') {
            $cpusys = $vals[$i];
        }
        if ($headers[$i] eq 'wa') {
            $cpuwait = $vals[$i];
        }
    }

    #print "$cpuuser, $cpusys, $cpuwait\n";
    $total = $cpuuser + $cpusys + $cpuwait;

    if ($total > $limit) {
        return "BAD", "$total > $limit";
    } else {
        return "OK", "$total <= $limit";
    }

    return "BAD", "Unable to determine cpu info";
};
1;
