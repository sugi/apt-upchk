package AptUpchk::Notify::Common;
use strict;
use warnings;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($SOCK_PATH %Conf &parseconfig);

our $SOCK_PATH = "/tmp/apt-upchk-summary";
our %Conf = (config  => "/etc/apt-upchk/summary.conf",
	     timeout => 600,
	     mailto  => ["root"],
	    );

sub parseconfig {
    if ( -r $Conf{config} ) {
	do $Conf{config};
	die "Error in config file: $@\n" if $@;
    }
}

1;
