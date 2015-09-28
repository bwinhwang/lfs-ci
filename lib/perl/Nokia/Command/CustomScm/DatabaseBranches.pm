package Nokia::Command::CustomScm::DatabaseBranches;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );
use File::Slurp;

use Nokia::Handler::Database;

use parent qw( Nokia::Command::CustomScm );

sub compare {
    my $self = shift;
    my $newString = Nokia::Store::Database::Branches->new()->md5sumOfAllEntries();
    my $oldString = read_file( $ENV{"OLD_REVISION_STATE_FILE"} );

    if( $newString ne $oldString ) {
        INFO "trigger build";
        write_file( $ENV{"REVISION_STATE_FILE"}, $newString );
        exit 1
    }
    INFO "no build";

    return;
}

1;
