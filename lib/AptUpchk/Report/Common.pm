package AptUpchk::Report::Common;
use strict;
use warnings;
use Exporter;
use AptUpchk;
our @ISA = qw(Exporter);
our @EXPORT = qw(__get_first_data);

sub __get_first_data(@) {
    my @a = map { $_->getFirstChild->getData } @_;
    wantarray ? @a : join($", @a);
}

1;
