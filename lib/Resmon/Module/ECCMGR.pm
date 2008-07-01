package Resmon::Module::ECCMGR;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# Note: This requires you have access to the ecelerity control lib. The
# easiest way to do this is to start resmon using ecelerity's perl install.
use Ecelerity::Control;

# Sample config for resmon.conf
# (The module doesn't actually use anything other than 'services' to use as
#  a label)
# ECCMGR {
#   eccmgr : socket => /tmp/2026
# }

sub handler {
  my $arg = shift;
  my $proc = $arg->{'object'};
  my $socket = $arg->{'socket'} || '/tmp/2026';
  # Connect to ecelerity
  my $ec = Ecelerity::Control->new({"Control" => $socket});
  eval {
    # Check the version
    $version = $ec->command('version');
  };
  if ($@) {
      # Catch any could not connect error
      $@ =~ /^(.*) at/; # Fetch just the error message and no file/line no.
      return "BAD($1)";
  }
  if ($version =~ /(eccmgr version: .*)\n/) {
      return "OK($1)";
  } else {
      # Something other than eccmgr responded, print out a version string
      $version =~ s/\n/ /g;
      $version =~ s/#//g;
      return "BAD(eccmgr not running: $version)";
  }
};
1;
