package Nokia::Command::GetBranchInformation;
use strict;
use warnings;

use Nokia::Handler::Database;

use parent qw( Nokia::Command );

sub execute {
    my $self = shift;
    Nokia::Handler::Database->new()->branchInformation();
    return;
}

1;
