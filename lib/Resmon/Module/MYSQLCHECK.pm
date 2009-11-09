package Resmon::Module::MYSQLCHECK;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
	my $arg = shift;
	my $db = $arg->{'object'};
	my $output = cache_command("/opt/mysql5/bin/mysqlcheck -s $db", 500);
	if($output) {
		chomp($output);
		return "BAD($output)";
	}
	return "OK($db is healthy)";
};
1;

