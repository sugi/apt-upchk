package AptUpchk::Report::Mail;
use strict;
use warnings;
use POSIX;
use Sys::Hostname;
use AptUpchk::Report::Common;
use AptUpchk::Report::SingleHost;
our @ISA = qw(AptUpchk::Report::SingleHost);

sub report {
    my $self = shift;
    my $old_loc = POSIX::setlocale(&POSIX::LC_ALL, "C");
    my $timefmt = "%a, %d %b %Y %T %z";
    my $d = $self->{doc};
    my $sbj = "Subject: [" . $d->{hostname} . "] UpdatePkg;";

    foreach my $p ($self->_get_security_pkg,
		   $self->_get_update_pkg,
		   $self->_get_hold_pkg) {
	my $pname = " " . $p->{name};
	if (length($sbj)+length($pname) > 75){
	    $sbj .= "...";
	    last;
	}
	$sbj .= $pname;
    }

    $self->_msg("$sbj\n");
    $self->_msg("Date: " . strftime($timefmt, localtime()) . "\n");
    $self->_msg("X-Check-Date: " .
		strftime($timefmt,
			 localtime($d->{unixtime})) . "\n");
    $self->_msg("X-Sender: apt-upchk v.$AptUpchk::VERSION (".hostname().")\n");
    $self->_msg("Content-Type: text/plain; charset=us-ascii\n");
    $self->_msg("\n");
    POSIX::setlocale( &POSIX::LC_ALL, $old_loc );

    $self->SUPER::report;
}

1;

