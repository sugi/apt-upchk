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
    $self = {need_report => {security => 0, normal => 0, hold => 0},
	     suppress => [],
	     ignore   => [],
	     force    => 0,
	     @opt};
    unless (exists $self->{output}) {
	$self->{output} = IO::File->new(">-");
    }
    bless $self, $class;
}

sub _scan_updates {
    # pickup non-excluded packages
    my $self = shift;
    return $self->{pkgcache} if exists $self->{pkgcache};
    my (@security, @update, @hold);
    my ($pkg);

  PKG:
    foreach $pkg ( @{$self->{doc}->{updatepkg}} ) {
	$pkg->{mark} = {};
	my $suppress = 0;
	foreach my $act ( qw(ignore suppress) ) {
	    foreach my $i ( @{$self->{$act}} ) {
	        my $f = undef;
	        foreach my $k ( qw(name current-version new-version release uptype) ) {
		    next unless exists($i->{$k});
		    defined($f) or $f = 1;
		    $pkg->{$k} !~ /^$i->{$k}$/i and $f = 0;
	        }
	        if ($f and $act eq "ignore") {
	            $pkg->{mark}->{I}++;
		    next PKG unless $self->{force};
		} elsif ($f and $act eq "suppress") {
	            $pkg->{mark}->{S}++;
		    $suppress = 1 unless $self->{force};
		}
	    }
	}

	if ( $pkg->{uptype} eq "security" ) {
	    push @security, $pkg;
	    $suppress or $self->{need_report}->{security} = 1;
	} elsif ( $pkg->{uptype} eq "hold" ) {
	    push @hold, $pkg;
	    $suppress or $self->{need_report}->{hold} = 1;
	} else {
	    push @update, $pkg;
	    $suppress or $self->{need_report}->{normal} = 1;
	}
    }
    $self->{pkgcache} = {};
    $self->{pkgcache}->{security} = [@security];
    $self->{pkgcache}->{normal}   = [@update];
    $self->{pkgcache}->{hold}     = [@hold];
    $self;
}

sub _get_packages($) {
    my $self = shift;
    my $cat  = shift;
    $self->_scan_updates unless exists $self->{pkgcache};
    @{$self->{pkgcache}->{$cat}};
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
    $self->report_update_err;
    $self->report_category("security");
    $self->report_category("normal");
    $self->report_category("hold");

    return $self->need_report;
}

sub report_update_err {
    my $self = shift;
    return 0 unless $self->need_report;

    my $err;
    if ( ($err = $self->_get_update_exitcode) != 0 ) {
	$self->_msg("Warning: apt-get update exited with error($err);\n");
	$self->_msg($self->_get_update_output);
	$self->_msg("\n");
	1;
    } else {
	0;
    }
}

sub report_category($) {
    my $self = shift;
    my $cat  = shift;

    $self->need_report or return 0;
    my @pkgs = $self->_get_packages($cat) or return 0;
    $self->_msg($self->__banner($cat));
    foreach my $pkg ( @pkgs ) {
	$self->_msg($self->__fmt($cat, $pkg));
    }
    $self->_msg("\n");
    return 1;
}


sub _msg {
    my $self = shift;
    my $fh = $self->{output};
    print $fh @_;
}

###

sub need_report {
    my $self = shift;
    my $cat  = shift;
    my $set  = shift;
    $self->_scan_updates;

    if ($cat) {
	return $self->{need_report}->{$cat};
    } else {
	my $k;
	foreach $k ( keys %{$self->{need_report}} ) {
	    return 1 if $self->{need_report}->{$k};
	}
	return 0;
    }
}

sub __banner($) {
    my $self = shift;
    my $meth = "_banner_".shift;
    $self->$meth;
}

sub _banner_security {
    "== SECURITY UPDATES ==\n"
}
sub _banner_normal {
    "== Update Packages ==\n"
}
sub _banner_hold {
    "== holds against update ==\n"
}

sub __fmt($$) {
    my $self = shift;
    my $meth = "_fmt_".shift;
    $self->$meth(shift);
}

sub _fmt_generic($) {
    my $self = shift;
    my $p = shift;
    my $ret = "";
    $ret .= sprintf("%-20s %12s => %12s (%s)",
		    $p->{name}, $p->{"current-version"},
		    $p->{"new-version"}, $p->{release});
    #$ret .= " " . join("", map{"[$_$p->{mark}->{$_}]"} keys %{$p->{mark}}) if $p->{mark};
    $ret .= " " . join("", map{"[$_]"} keys %{$p->{mark}}) if $p->{mark};
    $ret .= "\n";
    $ret;
}

sub _fmt_security($) {
    shift->_fmt_generic(@_);
}

sub _fmt_normal($) {
    shift->_fmt_generic(@_);
}

sub _fmt_hold($) {
    shift->_fmt_generic(@_);
}

1;
