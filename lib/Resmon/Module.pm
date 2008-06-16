package Resmon::Module;

use strict;
use Data::Dumper;
use FileHandle;
use UNIVERSAL qw/isa/;
my %coderefs;

my $rmloading = "Registering";

sub fetch_monitor {
  my $type = shift;
  my $coderef = $coderefs{$type};
  return $coderef if ($coderef);

  # First if the monitor name is raw and looks right:
  #   is a subclass of Resmon::Module and can 'handler'
  # then we will promote it into the Resmon::Module namespace
  # and use this one.
  eval "use $type;";
  if($type->isa(__PACKAGE__) && $type->can('handler')) {
    eval " 
      package Resmon::Module::$type;
      use vars qw/\@ISA/;
      \@ISA = qw($type);
      1;
    ";
    if($@) {
      die "Could not repackage $type as Resmon::Module::$type\n";
    }
    return undef;
  }
  eval "use Resmon::Module::$type;";
  return undef;
}

sub register_monitor {
  my ($type, $ref) = @_;
  if(ref $ref eq 'CODE') {
    $coderefs{$type} = $ref;
  }
  print STDERR "$rmloading $type monitor\n";
}
sub fresh_status {
  my $arg = shift;
  return undef unless $arg->{interval};
  my $now = time;
  if(($arg->{lastupdate} + $arg->{interval}) >= $now) {
    return $arg->{laststatus};
  }
  return undef;
}
sub set_status {
  my $arg = shift;
  $arg->{laststatus} = shift;
  $arg->{lastmessage} = shift;
  $arg->{lastupdate} = time;
  if($arg->{laststatus} =~ /^([A-Z]+)\((.*)\)$/s) {
    # This handles old-style modules that return just set status as
    #     STATE(message)
    $arg->{laststatus} = $1;
    $arg->{lastmessage} = $2;
  }
  return ($arg->{laststatus}, $arg->{lastmessage});
}
sub config_as_hash {
  my $self = shift;
  my $conf = {};
  while(my ($key, $value) = each %$self) {
    if(! ref $value) {
      # only stash scalars here.
      $conf->{$key} = $value;
    }
  }
  return $conf;
}

sub reload_module {
    my $self = shift;
    my $class = ref($self) || $self;
    $class =~ s/::/\//g;
    my $file = $INC{"$class.pm"};
    # Deal with modules loaded from a LIB directory and not in
    # lib/Resmon/Module: try MODNAME.pm instead of Resmon/Module/MODNAME.pm
    unless ($file) {
        $class =~ s/^.*\/([^\/]+)$/\1/;
        $file = $INC{"$class.pm"};
    }
    print STDERR "Reloading module: $class\n";
#    my $fh = FileHandle->new($file);
#    local($/);
    my $redef = 0;
    local($SIG{__WARN__}) = sub {
        if($_[0] =~ /[Ss]ubroutine ([\w:]+) redefined/ ) {
            $redef++;
            return;
        }
        warn @_;
    };
#    eval <$fh>;
    eval {do($file); die $@ if $@};
    return $@ if $@;
    return $redef;
}

$rmloading = "Demand loading";
1;
