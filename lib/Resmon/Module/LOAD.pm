package Resmon::Module::LOAD;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
    my $arg = shift;
    my $limit1 = $arg->{'1m'} || "5.00";
    my $limit5 = $arg->{'5m'} || "5.00";
    my $limit15 = $arg->{'15m'} || "5.00";
    my $output = cache_command("uptime", 60);
    if($output =~ /load average: ([0-9.]+), ([0-9.]+), ([0-9.]+)/) {
        $status = "OK";
        $sign1 = "<=";
        $sign5 = "<=";
        $sign15 = "<=";
        if ($1 > $limit1) {
            $status = "BAD";
            $sign1 = ">";
        }
        if ($2 > $limit5) {
            $status = "BAD";
            $sign1 = ">";
        }
        if ($3 > $limit15) {
            $status = "BAD";
            $sign1 = ">";
        }
        return $status, "1m: $1 $sign1 $limit1, 5m: $2 $sign5 $limit5, " .
            "15m: $3 $sign15 $limit15";
    }
    return "BAD", "Unable to determine load average";
};
1;
