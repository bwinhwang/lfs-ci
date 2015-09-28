package Nokia::Command::CustomScm;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    GetOptions( 'action=s', \$self->{action} ) or LOGDIE "invalid option";
    return;
}

sub execute {
    my $self = shift;
    if( $self->{action} eq "compare" ) {
        $self->compare();
    } elsif( $self->{action} eq "checkout" ) {
        $self->checkout();
    } elsif( $self->{action} eq "calculate" ) {
        $self->calculate();
    }
    return;
}

sub compare {
    my $self = shift;
    return;
}

sub calculate {
    my $self = shift;
    return;
}

sub checkout {
    my $self = shift;
    return;
}

1;
