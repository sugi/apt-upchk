package AptUpchk::Notify::Daemon;
use strict;
use warnings;
use Carp;
use IO::File;
use IO::Seekable;
use IO::Socket::UNIX;
use XML::DOM;
use XML::XQL;
use XML::XQL::DOM;
use AptUpchk::Notify::Common;
use AptUpchk::Report::MultiHost;

$Conf{timeout} = 10;

sub new {
    my $class = shift;
    my $self  = { debug => 0, need_send => 0, temp => undef, @_ };
    &parseconfig;
    bless $self, $class;
}

sub _cleanup {
    unlink($SOCK_PATH);
}

sub DESTROY {
    my $self = shift;
    $self->{temp}->close if $self->{temp};
    _cleanup;
}

sub set_timer {
    my $self = shift;
    $self->_log("timer reset\n");
    $SIG{ALRM} = sub { $self->send_report; _cleanup; exit(0); };
    alarm 0;
    alarm $Conf{timeout};
}

sub fork {
    my $self = shift;
    my $pid = fork;
    return(1) if $pid;
    close(STDIN);
    close(STDOUT);
    close(STDERR);
    $self->_log("forked. pid=$$\n");
    $self->run;
}

sub run {
    my $self = shift;
    $self->acceptloop;
}

sub listen {
    my $self = shift;
    $self->_log("opeing socket...");
    my $s = IO::Socket::UNIX->new(Local => $SOCK_PATH);
    $self->_log("done\n");
    unless ($s) {
	croak "can't open socket: $!\n";
    }
    $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub { _cleanup; };
    $self->{sock} = $s;
    $self->{sock}->listen;
    $self;
}

sub acceptloop {
    my $self = shift;
    $self->listen;
    $self->_log("waiting client...\n");
    $self->set_timer;
    my $peer;
    while ( $peer = $self->{sock}->accept ) {
	$self->set_timer;
	$self->_log("connected. reading data\n");
	local($/);
	undef $/;
	my $doc;
	eval {
	    $doc = XML::DOM::Parser->new->parse(<$peer>);
	};
	if ($@) {
	    $self->_log("XML parse failed: $@\n");
	} else {
	    $self->write_report($doc);
	}
    }
}

sub gettemp {
    my $self = shift;
    unless ($self->{temp}) {
	$self->{temp} = IO::File->new_tmpfile;
    }
    $self->{temp}
}

sub write_report($) {
    my $self = shift;
    my $doc  = shift;

    return 1 unless $doc->xql("//updatepkg") || $doc->xql("//keptbackpkg");

    $self->_log("write donw report...\n");
    my $temp = $self->gettemp;

    my $rep = AptUpchk::Report::MultiHost->new(doc => $doc, output => $temp);
    $rep->report;
    $self->{need_send} = 1;
}

sub send_report {
    my $self = shift;
    return(1) unless $self->{need_send};
    $self->_log("sending report...");

    my $temp = $self->gettemp;
    my $mail = IO::File->new("| /usr/sbin/sendmail ". join(" ",  @{$Conf{mailto}}));
    print $mail "Subject: Updated Package Report\n",
	"X-Sender: apt-upchk-summary\n",
	"To: ", join(", ", @{$Conf{mailto}}), "\n", "\n";
    $temp->sync;
    $temp->seek(0, 0);
    my $line;
    while ( $line = <$temp> ){
	print $mail $line;
    }
    $self->_log("done\n");
}

sub _log {
    my $self = shift;
    $self->{debug} or return;
    print @_;
}


1;
