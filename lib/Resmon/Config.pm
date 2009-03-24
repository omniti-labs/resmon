package Resmon::Config;

use strict;

sub new {
  my $class = shift;
  my $filename = shift;
  my $self = bless {
    configfile => $filename,
    modstatus => '',
    # Defaults
    timeout => 10
  }, $class;
  open(CONF, "<$filename") || return undef;

  my $current;
  my $line = 0;
  while(<CONF>) {
    $line++;
    next if /^\s*#/;
    next if /^\s*$/;
    if($current) {
      if(/^\s*([^:\s](?:[^:]*[^:\s])?)\s*:\s*(.+)\s*$/) {
	my %kvs;
	$kvs{'type'} = $current;
        $kvs{'object'} = $1;
	my @params = split(/,/, $2);
	grep { $kvs{$1} = $2 if /^\s*(\S+)\s*=>\s*(\S(?:.*\S))\s*$/ } @params;
        my $object = bless \%kvs, "Resmon::Module::$current";
        push(@{$self->{Module}->{$current}}, $object);

        # Test to make sure the module actually works
        my $coderef;
        eval { $coderef = Resmon::Module::fetch_monitor($current); };
        if (!$coderef) {
            # Try to execute the config_as_hash method. If it fails, then
            # the module didn't load properly (e.g. syntax error).
            eval { $object->config_as_hash; };
            if ($@) {
                # Module failed to load, print error and add to failed
                # modules list.
                print STDERR "Problem loading module $current\n";
                print STDERR "This module will not be available\n";
                $self->{'modstatus'} .= "$current ";
            }
        }

      } elsif (/^\s*\}\s*$/) {
	$current = undef;
      } else {
        die "Syntax Error on line $line\n";
      }
    } else {
      if(/\s*(\S+)\s*\{/) {
	$current = $1;
        $self->{Module}->{$current} = [];
	next;
      }
      elsif(/\S*LIB\s+(\S+)\s*;\s*/) {
        eval "use lib '$1';";
        next;
      }
      elsif(/\S*PORT\s+(\d+)\s*;\s*/) {
        $self->{port} = $1;
        next;
      }
      elsif(/\S*INTERFACE\s+(\S+)\s*;\s*/) {
        $self->{interface} = $1;
        next;
      }
      elsif(/\s*INTERVAL\s+(\d+)\s*;\s*/) {
        $self->{interval} = $1;
        next;
      }
      elsif(/\s*STATUSFILE\s+(\S+)\s*;\s*/) {
        $self->{statusfile} = $1;
        next;
      }
      elsif(/\s*TIMEOUT\s+(\d+)\s*;\s*/) {
        $self->{timeout} = $1;
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
