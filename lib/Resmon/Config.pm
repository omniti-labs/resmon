package Resmon::Config;

use strict;

sub new {
  my $class = shift;
  my $filename = shift;
  my $self = bless {
    configfile => $filename,
  }, $class;
  open(CONF, "<$filename") || return undef;

  my $current;
  my $line = 0;
  while(<CONF>) {
    $line++;
    next if /^\s*#/;
    next if /^\s*$/;
    if($current) {
      if(/^\s*(\S+)\s*:\s*(.+)\s*$/) {
	my %kvs;
	$kvs{'type'} = $current;
        $kvs{'object'} = $1;
	my @params = split(/,/, $2);
	grep { $kvs{$1} = $2 if /^\s*(\S+)\s*=>\s*(\S+)\s*$/ } @params;
        my $object = bless \%kvs, "Resmon::Modules::$current";
        push(@{$self->{Modules}->{$current}}, $object);
      } elsif (/^\s*\}\s*$/) {
	$current = undef;
      } else {
        die "Syntax Error on line $line\n";
      }
    } else {
      if(/\s*(\S+)\s*\{/) {
	$current = $1;
        $self->{Modules}->{$current} = [];
	next;
      }
      elsif(/\S*LIB\s+(\S+)\s*;?\s*/) {
        eval "use lib '$1';";
        next;
      }
      elsif(/\s*INTERVAL\s+(\d+)\s*;?\s*/) {
        $self->{interval} = $1;
        next;
      }
      elsif(/\s*STATUSFILE\s+(\S+)\s*;?\s*/) {
        $self->{statusfile} = $1;
        next;
      }
      else {
        die "Syntax Error on line $line\n";
      }
    }
  }
  if($current) {
    die "unclosed stanza\n";
  }
  return $self;
}

1;
