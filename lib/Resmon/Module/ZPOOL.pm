package Resmon::Module::ZPOOL;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
	my $arg = shift;
	my $os = $arg->fresh_status();
	return $os if $os;
	my $unit = $arg->{'object'};
	my $output = cache_command("zpool list -H | grep -v ONLINE", 500);
	if($output) {
		my $errstring = "";
		foreach my $line (split(/\n/, $output)) {
			my @cols = split(/\t/, $line);
			$errstring .= $cols[0] . ":" . $cols[5] . " ";
		}
		chop($errstring);
		return $arg->set_status("BAD($errstring)");
	}
	return $arg->set_status("OK(all pools are healthy)");
};
