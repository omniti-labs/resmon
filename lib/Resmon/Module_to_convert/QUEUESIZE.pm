package Resmon::Module::QUEUESIZE;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# Checks ecelerity queue sizes and alerts on large queues

# Path to ec_console
my $ecc = '/opt/ecelerity/bin/ec_console';
# Domains to exclude from the 'common' check
my $exclude_domains = 'aol\.com|yahoo\.com|msn\.com|hotmail\.com|verizon\.net|comcast\.net|bellsouth\.net|earthlink\.net|mindspring\.com|pacbell\.net|sbcglobal\.net|cox\.net';

sub handler {
    my $arg = shift;

    my $domain = $arg->{'object'};
    my $queue = $arg->{'queue'};
    my $threshold = $arg->{'count'};
    if( $domain !~ /common/i ) {
        if ( $queue =~ /delayed/i ) {
            $queue = "Delayed";
        } else {
            $queue = "Active";
        }
        my $rawOutput = cache_command(
            "echo \"domain $domain\" | $ecc | grep \"$queue Queue:\"", 300);
        @lines = split(/\n/,$rawOutput);
        $numLines = $#lines;
        $total = $lines[$numLines];
        if( $total =~ /\s*$queue Queue:\s*(\d+).*/ ) {
            if( $1 > $threshold ) {
                return "BAD", "$1 messages";
            } else {
                return "OK", "$1 messages";
            }
        } else {
            return "OK", "0";
        }
    } else {
        my $rawOutput = cache_command(
            "echo \"$queue $threshold\" | $ecc | grep Domain:",300);
        $badDomains = 0;
        my @bad;
        foreach my $line (split /\n/, $rawOutput) {
            chomp($line);
            if( $line =~ /^Domain:\s*([\w\.]*)\s*.*A:\s*(\d+)\s*D:\s*(\d+)/ ) {
                my $domain = $1;
                my $aQueue = $2;
                my $dQueue = $3;
                if($domain !~ /$exclude_domains/) {
                    $badDomains++;
                    if( $queue =~ /active/i ) {
                        $queueCount = $aQueue;
                    } elsif( $queue =~ /delayed/i ) {
                        $queueCount = $dQueue;
                    }
                    push @bad, "$domain:$queueCount";
                }
            }
        }
        $output = join(',', @bad);
        if( $badDomains > 0 ) {
            return "BAD", $output;
        } else {
            return "OK", "no domains over $threshold";
        }
    }
}

1;
