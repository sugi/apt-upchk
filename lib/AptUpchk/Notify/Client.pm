package AptUpchk::Notify::Client;

use strict;
use warnings;
use Carp;
use IO::Socket::UNIX;
use AptUpchk::Notify::Common;

sub new {
    my $class = shift;
    my $self  = {daemon => "summary-sender" @_ };
    bless $self, $class;
}

sub _start_daemon {
    system($self->{daemon});
    sleep(5);
}

sub connect {
    my $self = shift;
    {
	alarm 30;
	local $SIG{ALRM} = sub { croak "timeout. can't find daemon socket.\n" };
	while (! (-e $SOCK_PATH) ) {
	    &_start_daemon();
	}
	alarm 0;
    }
    my $sock;

    foreach (1..3) {
	$sock = IO::Socket::UNIX->new($SOCK_PATH);
	$sock ? last : carp("can't connect to daemon socket. retrying...\n");
	unlink($SOCK_PATH);
	&_start_daemon();
    }
    croak "gave up to connect daemon\n" unless $sock;
    $self->{sock} = $sock;
}

sub get_sock {
    my $self = shift;
    $self->connect unless exists($self->{sock}) && $self->{sock};
    $self->{sock};
}

sub senddoc {
    my $self = shift;
    my $doc  = shift;
    my $sock = $self->get_sock;
    if ( ref($doc) eq "IO::File" ) {
	my $line;
	while ( $line = <$doc> ) {
	    print $sock $line;
	}
    } else {
	print $sock $doc;
    }
}

1;
