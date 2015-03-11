package Nokia::Command::GetBranchInformationFile;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Handler::Database::Branches;

use parent qw( Nokia::Command; );

sub prepare {
    my $self = shift;
    return;
}

sub execute {
    my $self = shift;
    Nokia::Handler::Database::Branches->new()->branchInformation();
    return;
}

1;
