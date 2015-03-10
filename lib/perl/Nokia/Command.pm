package Nokia::Command; 
## @fn     Command
#  @brief  parent class for all commands

use strict;
use warnings;

use Nokia::Object;

use parent qw( Nokia::Object );

sub prepare {
    my $self = shift;
    return;
}

sub execute {
    my $self = shift;
    return;
}

1;
