package Resmon::Module::FILECOUNT;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
        my $arg = shift;
        my $dir = $arg->{'object'};
        my $hlimit = $arg->{'hard_limit'};
        my $slimit = $arg->{'soft_limit'};
        my $output = cache_command("ls $dir | wc -l",30);
        chomp($output);
        if ($output > $hlimit) {
                return "BAD", "$output files";
        } elsif ($output > $slimit) {
                return "WARNING", "$output files";
        } else {
                return "OK", "$output files";
        }
}

1;
