package AptUpchk::Report::SingleHost;

use strict;
use warnings;
use IO::File;
use AptUpchk::Report::Common;

sub new {
    my $class = shift;
    my $self;
    my @opt = @_;
    @opt = (doc => shift) if (@_ == 1);
    $self = {"exclude-hold"     => 0,
	     "exclude-normal"   => 0,
	     "exclude-security" => 0,
	     "exclude-update-error"=> 1,
	     "exclude-byname"   => [],
	     @opt};
    unless (exists $self->{output}) {
	$self->{output} = IO::File->new(">-");
    }
    bless $self, $class;
}

sub _scan_updates {
    # pickup non-excluded packages
    my $self = shift;
    my (@security, @update, @hold);
    my ($pkg);

  PKG:
    foreach $pkg ( @{$self->{doc}->{updatepkg}} ) {
	foreach my $i ( @{$self->{"exclude-byname"}} ) {
	    $pkg->{name} =~ /^${i}$/i and next PKG;
	}

	if ( $pkg->{release} =~ /-security:/i ) {
	    next if $self->{"exclude-security"};
	    push @security, $pkg;
	} else {
	    next if $self->{"exclude-normal"};
	    push @update, $pkg;
	}
    }
  HLD:
    foreach $pkg ( @{$self->{doc}->{keptbackpkg}} ) {
	foreach my $i ( @{$self->{"exclude-byname"}} ) {
	    $pkg->{name} =~ /^${i}$/i and next HLD;
	}
	push @hold, $pkg;
    }
    $self->{pkgcache} = {} unless exists $self->{pkgcache};
    $self->{pkgcache}->{security} = [@security];
    $self->{pkgcache}->{update}   = [@update];
    $self->{pkgcache}->{hold}     = [@hold];
    $self;
}

sub _get_hold_pkg {
    my $self = shift;
    $self->_scan_updates unless exists $self->{pkgcache}->{hold};
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
    $self->{doc}->{"update-command"}->{exitcode};
}

sub _get_update_output {
    my $self = shift;
    $self->{doc}->{"update-command"}->{output};
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
    return 0 if $self->{"exclude-update-error"};

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

sub __generic_fmt($) {
    my $self = shift;
    my $p = shift;
    sprintf("%-20s %12s => %12s (%s)\n",
	    $p->{name}, $p->{"current-version"},
	    $p->{"new-version"}, $p->{release});
}

sub __secpkg_fmt($) {
    shift->__generic_fmt(@_);
}

sub __uppkg_fmt($) {
    shift->__generic_fmt(@_);
}

sub __holdpkg_fmt($) {
    shift->__generic_fmt(@_);
}

1;
