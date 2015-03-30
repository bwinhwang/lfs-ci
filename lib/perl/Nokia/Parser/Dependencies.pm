package Nokia::Parser::Dependencies; 
use strict;
use warnings;

use Nokia::Parser::Dependencies::Models::Target;
use Nokia::Parser::Dependencies::Models::UseReadonly;

use parent qw( Nokia::Parser );


sub target {
    my $self = shift;
    push @{ $self->{data}->{target} }, Nokia::Parser::Dependencies::Models::Target->new( target => shift, params => \@_ );
    return;
}

sub use_readonly {
    my $self = shift;
    push @{ $self->{data}->{useReadonly} }, Nokia::Parser::Dependencies::Models::UseReadonly->new( src => shift, dst => \@_ );
    return;
}

sub use {
    my $self = shift;
    push @{ $self->{data}->{use} }, { src => shift, dst => \@_ };
    return;
}

sub hint {
    my $self = shift;
    push @{ $self->{data}->{hint} }, { src => shift, dst => \@_ };
    return;
}


1;
