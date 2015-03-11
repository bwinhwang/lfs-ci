package Nokia::Store::Database::SubversionCommits;
use strict;
use warnings;

use DBI;
use Log::Log4perl qw( :easy );

use parent qw( Nokia::Store::Database );

sub newSubversionCommit {
    my $self  = shift;
    my $param = { @_ };

    my $baselineName  = $param->{baselineName};
    my $revision      = $param->{revision};
    my $author        = $param->{author};
    my $date          = $param->{date};
    my $msg           = $param->{msg};

    my $sth = $self->prepare(
        'CALL add_new_subversion_commit( ?, ?, ?, ?, ? )'
    );

    DEBUG "$baselineName $revision $author $date\n";

    $sth->execute( $baselineName, $revision, $author, $date, $msg )
        or LOGDIE sprintf( "can not insert test execution: %s, %s, %s, %s", $baselineName, $revision, $author, $author);

    return;
}

1;
