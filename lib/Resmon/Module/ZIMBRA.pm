package Resmon::Module::ZIMBRA;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
	my $arg = shift;
	my $unit = $arg->{'object'};
	my $output = cache_command("su - zimbra -c 'zmcontrol status' | grep 'not running'", 500);
	if($output) {
		$output =~s /\n/:/gs;
		return "BAD($output)";
	}
	return "OK(All services running)";
};
1;
