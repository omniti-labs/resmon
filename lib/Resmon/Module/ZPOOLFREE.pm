package Resmon::Module::ZPOOLFREE;

use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;

use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# Version of the free space module that uses zfs list instead of df
#
# Note: this check used to use zpool list, but this doesn't report accurate
# values due to a space reservation. See
# http://cuddletech.com/blog/pivot/entry.php?id=1013 for an explanation of
# this.
#
# Sample config:
#
# ZPOOLFREE {
#   intmirror           : limit => 90%
#   storage1            : limit => 90%
# }

sub handler {
  my $self = shift;
  my $object = $self->{object};
  my %units = (
      'B' => 1,
      'K' => 1024,
      'M' => 1048576,
      'G' => 1073741824,
      'T' => 1099511627776,
      'P' => 1125899906842624,
      'E' => 1152921504606846976,
      'Z' => 1180591620717411303424
  );
  if ($object =~ /\//) {
      return "BAD", "Dataset name $object is not the root of a zpool"
  }
  # -H prints script friendly output
  my $output = cache_command("zfs list -H $object", 120);
  my ($used, $uunit, $free, $funit) =
    $output =~ /$object\t([0-9.]+)([BKMGTPEZ]?)\t([0-9.]+)([BKMGTPEZ]?)/;
  if (!$used) {
      return "BAD", "no data";
  }
  my $hused = "${used}${uunit}";
  my $hfree = "${free}${funit}";
  # Convert from human readable units
  $used = $used * $units{$uunit} if $uunit;
  $free = $free * $units{$funit} if $funit;
  my $total = $used + $free;
  my $percent = ($used / $total) * 100;
  my $status;
  if($percent > $self->{'limit'}) {
    $status = "BAD";
  } elsif(exists $self->{'warnat'} && $1 > $self->{'warnat'}) {
    $status = "WARNING";
  } else {
    $status = "OK";
  }
  return $status, sprintf("%.0f%% full, %s used, %s free",
    $percent, $hused, $hfree);
}

1;
