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
    my @opt = @_;
    @opt = (doc => shift) if (@_ == 1);
    $self = {"ignore-type" => [], "ignore-name" =>[],
	     @opt};
    unless (exists $self->{output}) {
	$self->{output} = IO::File->new(">-");
    }
    bless $self, $class;
}

sub _scan_updates {
    my $self = shift;
    my (@security, @update);
    my ($pkg);
    my %ignore_t;
    @ignore_t{@{$self->{"ignore-type"}}}=();

  PKG:
    foreach $pkg ( $self->{doc}->xql("/apt-upchk-report/updatepkg") ) {
	foreach my $i ( @{$self->{"ignore-name"}} ) {
	    [__get_first_data($pkg->xql("./name"))]->[0] =~ /^${i}$/i and next PKG;
	}

	if ( [__get_first_data($pkg->xql("./release"))]->[0] =~ /-security:/i ) {
	    next if exists $ignore_t{"security"};
	    push @security, $pkg;
	} else {
	    next if exists $ignore_t{"normal"};
	    push @update, $pkg;
	}
    }
    $self->{pkgcache} = {} unless exists $self->{pkgcache};
    $self->{pkgcache}->{security} = [@security];
    $self->{pkgcache}->{update}   = [@update];
    $self;
}

sub _get_hold_pkg {
    my $self = shift;
    my @pkg;
    my %ignore_t;
    @ignore_t{@{$self->{"ignore-type"}}}=();
    return @pkg if exists $ignore_t{"hold"};

    unless (exists $self->{pkgcache}->{hold}) {
      PKG:
	foreach my $pkg ( $self->{doc}->xql("/apt-upchk-report/keptbackpkg") ){
	    foreach my $i ( @{$self->{"ignore-name"}} ) {
		[__get_first_data($pkg->xql("./name"))]->[0] =~ /^${i}$/i and next PKG;

	     }
	     push @pkg, $pkg;
	}
	$self->{pkgcache}->{hold} = [@pkg];
    }
    @{$self->{pkgcache}->{hold}};
}

sub _get_update_pkg {
    my $self = shift;
    $self->_scan_updates unless exists $self->{pkgcache}->{update};
    @{$self->{pkgcache}->{update}};
}

sub _get_security_pkg {
    my $self = shift;
    $self->_scan_updates unless exists $self->{pkgcache}->{security};
    @{$self->{pkgcache}->{security}};
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
    my $ret  = 0;
    $self->report_update_err   and $ret = 1 and $self->_msg("\n");
    $self->report_security_pkg and $ret = 1 and $self->_msg("\n");
    $self->report_update_pkg   and $ret = 1 and $self->_msg("\n");
    $self->report_hold_pkg     and $ret = 1 and $self->_msg("\n");
    $ret;
}

sub report_update_err {
    my $self = shift;
    my %ignore_t;
    @ignore_t{@{$self->{"ignore-type"}}}=();
    return 0 if exists $ignore_t{"update-error"};

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
    sprintf("%-20s %12s => %12s (%s)\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version"),
			     $p->xql("./new-version"),
			     $p->xql("./release")));
}

sub __uppkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("%-20s %12s => %12s (%s)\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version"),
			     $p->xql("./new-version"),
			     $p->xql("./release")));

}

sub __holdpkg_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("%s (%s)\n",
	    __get_first_data($p->xql("./name"),
			     $p->xql("./current-version")));
}


1;
