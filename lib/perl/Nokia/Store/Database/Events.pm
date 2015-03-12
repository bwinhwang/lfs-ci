package Nokia::Store::Database::Events;
use strict;
use warnings;

use DBI;
use Log::Log4perl qw( :easy);
use Data::Dumper;

use parent qw( Nokia::Store::Database );

sub newTestExecution {
    my $self  = shift;
    my $param = { @_ };

    my $buildName     = $param->{buildName};
    my $testSuiteName = $param->{testSuiteName};
    my $targetName    = $param->{targetName};
    my $targetType    = $param->{targetType};

    my $sth = $self->prepare(
        'CALL add_new_test_execution( ?, ?, ?, ?, @id )'
    );
    $sth->execute( $buildName, $testSuiteName, $targetName, $targetType )
        or LOGDIE sprintf( "can not insert test execution: %s, %s, %s, %s", $buildName, $testSuiteName, $targetName, $targetType);
    my $id = $self->{dbi}->selectrow_array('SELECT @id');

    return $id;
}

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
    print "$baselineName $revision $author $date\n";
    $sth->execute( $baselineName, $revision, $author, $date, $msg )
        or LOGDIE sprintf( "can not insert test execution: %s, %s, %s, %s", $baselineName, $revision, $author, $author);

    return;
}

sub newTestResult {
    my $self  = shift;
    my $param = { @_ };

    my $testExecutionId = $param->{testExecutionId};
    my $testResultName  = $param->{testResultName};
    my $testResultValue = $param->{testResultValue};

    my $sth = $self->prepare(
        'CALL add_new_test_result( ?, ?, ? )'
    );
    $sth->execute( $testExecutionId, $testResultName, $testResultValue )
        or LOGDIE sprintf( "can not insert test result: %s, %s, %s", $testExecutionId, $testResultName, $testResultValue );

    return;
}

sub newBuildEvent {
    my $self         = shift;
    my $param        = { @_ };
    my $baselineName = $param->{baselineName} || "";
    my $branchName   = $param->{branchName}   || "";
    my $revision     = $param->{revision}     || "";
    my $comment      = $param->{comment}      || "";
    my $jobName      = $param->{jobName}      || "";
    my $buildNumber  = $param->{buildNumber}  || "";
    my $target       = $param->{target}       || "";
    my $subTarget    = $param->{subTarget}    || "";
    my $action       = $param->{action};
    my $method       = "";
    my $data         = [];

    DEBUG "parameter" . Dumper( $param );

    if( $action eq "build_started" ) {
        $method = "build_started( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $branchName, $revision, $jobName, $buildNumber ];
    } elsif ( $action eq "build_failed"  ) {
        $method = "build_failed( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $jobName, $buildNumber ];
    } elsif ( $action eq "build_finished"  ) {
        $method = "build_finished( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $jobName, $buildNumber ];
    } elsif ( $action eq "subbuild_started"  ) {
        $method = "subbuild_started( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "subbuild_finished" ) {
        $method = "subbuild_finished( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "subbuild_failed"   ) {
        $method = "subbuild_failed( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "test_started"      ) {
        $method = "test_started( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "test_failed"      ) {
        $method = "test_failed( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "test_finished"      ) {
        $method = "test_finished( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "subtest_started"   ) {
        $method = "subtest_started( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "subtest_finished"  ) {
        $method = "subtest_finished( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "subtest_unstable"  ) {
        $method = "subtest_unstable( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "subtest_failed"    ) {
        $method = "subtest_failed( ?, ?, ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $target, $subTarget, $jobName, $buildNumber ];
    } elsif ( $action eq "package_started"   ) {
        $method = "package_started( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $jobName, $buildNumber ];
    } elsif ( $action eq "package_finished"  ) {
        $method = "package_finished( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $jobName, $buildNumber ];
    } elsif ( $action eq "package_failed"   ) {
        $method = "package_failed( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $jobName, $buildNumber ];
    } elsif ( $action eq "release_started"   ) {
        $method = "release_started( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $jobName, $buildNumber ];
    } elsif ( $action eq "release_finished"  ) {
        $method = "release_finished( ?, ?, ?, ? )";
        $data   = [ $baselineName, $comment, $jobName, $buildNumber ];
    }

    DEBUG "executing $action with $method and data (" . join( ", ", @{ $data } ) . ")";

    my $sth = $self->prepare(
        "call $method"
    );

    $sth->execute( @{ $data } )
        or LOGDIE sprintf( "can not insert data\n%s\n", $sth->errstr() );

    return;
}

sub branchInformation {
    my $self  = shift;
    my $param = { @_ };

    my $sth = $self->prepare( 
        "select * from branches"
    );
    $sth->execute()
        or LOGDIE sprintf( "can not get branch information" );
    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
         push @results, $row;
    }
    return @results;

}

1;
