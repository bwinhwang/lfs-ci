package Nokia::Command::GetLocationsText;
use strict;
use warnings;

use Nokia::Handler::Database;

use parent qw( Nokia::Command );

sub execute {
    my $self = shift;
    Nokia::Handler::Database->new()->locationsText();
    return;
}

1;
