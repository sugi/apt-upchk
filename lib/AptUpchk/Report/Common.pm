package AptUpchk::Report::Common;
use strict;
use warnings;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(__get_first_data);

sub __get_first_data {
    map { $_->getFirstChild->getData } @_;
}

1;
