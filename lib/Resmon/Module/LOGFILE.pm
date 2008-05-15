package Resmon::Module::LOGFILE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

my %logfile_stats;
sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $file = $arg->{'object'};
  my $match = $arg->{'match'};
  my $max = $arg->{'max'} || 8;
  my @statinfo = stat($file);
  if(exists($arg->{file_dev})) { 
    if(($arg->{file_dev} == $statinfo[0]) &&
       ($arg->{file_ino} == $statinfo[1])) {
      if($arg->{lastsize} == $statinfo[7]) {
        if($arg->{errors}) {
          return $arg->set_status("BAD($arg->{nerrs}: $arg->{errors})");
        }
        return $arg->set_status("OK(0)");
      }
    } else {
      # File is a different file now
      $arg->{lastsize} = 0;
      $arg->{nerrs} = 0;
      $arg->{errors} = '';
    }
  }
  if(!open(LOG, "<$file")) {
    return $arg->set_status("BAD(ENOFILE)");
  }
  seek(LOG, $arg->{lastsize}, 0);

  while(<LOG>) {
    chomp;
    if(/$match/) {
      if($arg->{nerrs} < $max) {
        $arg->{errors} .= " " if(length($arg->{errors}));
        $arg->{errors} .= $_;
      }
      $arg->{nerrs}++;
    }
  }

  # Remember where we were
  $arg->{file_dev} = $statinfo[0];
  $arg->{file_ino} = $statinfo[1];
  $arg->{lastsize} = $statinfo[7];

  if($arg->{nerrs}) {
    return $arg->set_status("BAD($arg->{nerrs}: $arg->{errors})");
  }
  return $arg->set_status("OK(0)");
}
1;
