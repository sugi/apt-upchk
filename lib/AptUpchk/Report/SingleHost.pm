package AptUpchk::Report::SingleHost;

use strict;
use warnings;
use XML::DOM;
use XML::XQL;
use XML::XQL::DOM;
use IO::File;
use AptUpchk::Report::Common;

sub new {
    my $class = shift;
    my $self;
    if (@_ == 1) {
	$self = { doc => shift };
    } else {
	$self = { @_ };
    }
    unless (exists $self->{output}) {
	$self->{output} = IO::File->new(">-");
    }
    bless $self, $class;
}

sub _scan_updates {
    my $self = shift;
    my (@security, @update);
    my ($pkg);
    foreach $pkg ( $self->{doc}->xql("/apt-upchk-report/updatepkg") ) {
	if ( [__get_first_data($pkg->xql("./release"))]->[0] =~ /-security:/i ) {
	    push @security, $pkg;
	} else {
	    push @update, $pkg;
	}
    }
    $self->{pkg} = {} unless exists $self->{pkg};
    $self->{pkg}->{security} = [@security];
    $self->{pkg}->{update} = [@update];
    $self;
}

sub _get_hold_pkg {
    my $self = shift;
    unless (exists $self->{pkg}->{hold}) {
	$self->{pkg}->{hold} = [$self->{doc}->xql("/apt-upchk-report/keptbackpkg")];
    }
    @{$self->{pkg}->{hold}};
}

sub _get_update_pkg {
    my $self = shift;
    $self->_scan_updates unless exists $self->{pkg}->{update};
    @{$self->{pkg}->{update}};
}

sub _get_security_pkg {
    my $self = shift;
    $self->_scan_updates unless exists $self->{pkg}->{security};
    @{$self->{pkg}->{security}};
}

sub _get_update_exitcode {
    my $self = shift;
    [__get_first_data($self->{doc}->xql("/apt-upchk-report/update-command/exitcode"))]->[0];
}

sub _get_update_output {
    my $self = shift;
    [__get_first_data($self->{doc}->xql("/apt-upchk-report/update-command/output"))]->[0];
}

sub report {
    my $self = shift;
    $self->report_update_err   and $self->_msg("\n");
    $self->report_security_pkg and $self->_msg("\n");
    $self->report_update_pkg   and $self->_msg("\n");
    $self->report_hold_pkg     and $self->_msg("\n");
}

sub report_update_err {
    my $self = shift;
    my $err;
    if ( ($err = $self->_get_update_exitcode) != 0 ) {
	$self->_msg("Warning: apt-get update exited with error($err);\n");
	$self->_msg($self->_get_update_output);
	1;
    } else {
	0;
    }
}

sub report_security_pkg {
    my $self = shift;
    my @pkgs = $self->_get_security_pkg or return 0;
    $self->_msg($self->__secpkg_banner);
    foreach my $pkg ( @pkgs ) {
	$self->_msg($self->__uppkg_fmt($pkg));
    }
    return 1;
}

sub report_update_pkg {
    my $self = shift;
    my @pkgs = $self->_get_update_pkg or return 0;
    $self->_msg($self->__uppkg_banner);
    foreach my $pkg ( @pkgs ) {
	$self->_msg($self->__uppkg_fmt($pkg));
    }
    return 1;
}

sub report_hold_pkg {
    my $self = shift;
    my @pkgs = $self->_get_hold_pkg or return 0;
    $self->_msg($self->__holdpkg_banner);
    foreach my $pkg ( @pkgs ) {
	$self->_msg($self->__holdpkg_fmt($pkg));
    }
    return 1;
}

sub _msg {
    my $self = shift;
    my $fh = $self->{output};
    print $fh @_;
}

###

sub __secpkg_banner {
    "== SECURITY UPDATES ==\n"
}
sub __uppkg_banner {
    "== Update Packages ==\n"
}
sub __holdpkg_banner {
    "== holds ageinst update ==\n"
}

sub __secpkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("%-22s %15s => %15s\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version"),
			     $p->xql("./new-version")));
}

sub __uppkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("%-22s %15s => %15s\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version"),
			     $p->xql("./new-version")));

}

sub __holdpkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("%s (%s)\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version")));
}


1;
