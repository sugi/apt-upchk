package AptUpchk::Report::MultiHost;
use XML::DOM;
use XML::XQL;
use XML::XQL::DOM;
use AptUpchk::Report::Common;
use AptUpchk::Report::SingleHost;
our @ISA = qw(AptUpchk::Report::SingleHost);

sub report {
    my $self = shift;

    my @time = localtime([__get_first_data($self->{doc}->xql("/apt-upchk-report/unixtime"))]->[0]);
    $time[5] += 1900;

    $self->_msg("======== Package update report for ",
		__get_first_data($self->{doc}->xql("/apt-upchk-report/hostname")),
		" (",
		sprintf("%04d/%02d/%02d %02d:%02d", @time[5,4,3,2,1]),
	        ") ========\n");

    $self->report_security_pkg and $self->_msg("\n");
    $self->report_update_pkg   and $self->_msg("\n");
    $self->report_hold_pkg     and $self->_msg("\n");
}

sub report_update_err {
    my $self = shift;
    my $err;
    if ( ($err = $self->_get_update_exitcode) != 0 ) {
	$self->_msg("Warning: apt-get update exited with error($err)\n");
	#$self->_msg($self->_get_update_output);
	1;
    } else {
	0;
    }
}


sub __secpkg_banner {
    "  * SECURITY UPDATES\n"
}
sub __uppkg_banner {
    "  * Update Packages\n"
}
sub __holdpkg_banner {
    "  * holds ageinst update\n"
}

sub __secpkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("    - %-25s (%s => %s)\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version"),
			     $p->xql("./new-version")));
}

sub __uppkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("    - %-25s (%s => %s)\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version"),
			     $p->xql("./new-version")));
}

sub __holdpkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("    - %-25s (%s)\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version")));
}

1;
