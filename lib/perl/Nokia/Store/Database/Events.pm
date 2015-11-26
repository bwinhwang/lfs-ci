package Nokia::Store::Database::Events;
use strict;
use warnings;

use DBI;
use Log::Log4perl qw( :easy);
use Data::Dumper;
use Sys::hostname;

use parent qw( Nokia::Store::Database );

sub newTestCaseResult {
    my $self  = shift;
    my $param = { @_ };

    my $testCaseName        = $param->{testCaseName};
    my $testExecutionId     = $param->{testExecutionId};
    my $testCaseDuration    = $param->{testCaseDuration};
    my $testCaseFailedSince = $param->{testCaseFailedSince};
    my $testCaseSkipped     = $param->{testCaseSkipped} eq "true" ? 1 : 0;
    my $testCaseResult      = $param->{testCaseResult};

    my $sth = $self->prepare(
        'CALL add_new_test_case_result( ?, ?, ?, ?, ?, ? )'
    );
    DEBUG sprintf( "can not insert test case result: %s, %s, %s, %s, %s, %s", 
                   $testExecutionId, 
                   $testCaseName, 
                   $testCaseDuration, 
                   $testCaseFailedSince, 
                   $testCaseSkipped, 
                   $testCaseResult, );

    $sth->execute( $testExecutionId, 
                   $testCaseName, 
                   $testCaseDuration, 
                   $testCaseFailedSince, 
                   $testCaseSkipped, 
                   $testCaseResult, )
        or LOGDIE sprintf( "can not insert test case result: %s, %s, %s, %s, %s, %s", 
                   $testExecutionId, 
                   $testCaseName, 
                   $testCaseDuration, 
                   $testCaseFailedSince, 
                   $testCaseSkipped, 
                   $testCaseResult, );
    return;
}

sub newTestExecution {
    my $self  = shift;
    my $param = { @_ };

    my $buildName     = $param->{buildName};
    my $testSuiteName = $param->{testSuiteName};
    my $targetName    = $param->{targetName};
    my $targetType    = $param->{targetType};
    my $jobName       = $param->{jobName};
    my $buildNumber   = $param->{buildNumber};

    my $sth = $self->prepare(
        'CALL add_new_test_execution( ?, ?, ?, ?, ?, ?, @id )'
    );
    DEBUG sprintf( "insert test execution: %s, %s, %s, %s, %s %s", $buildName, $testSuiteName, $targetName, $targetType, $jobName, $buildNumber );
    $sth->execute( $buildName, $testSuiteName, $targetName, $targetType, $jobName, $buildNumber )
        or LOGDIE sprintf( "can not insert test execution: %s, %s, %s, %s, %s, %s", $buildName, $testSuiteName, $targetName, $targetType, $jobName, $buildNumber );
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
    DEBUG sprintf( "insert subversion commit: %s, %s, %s, %s, %s", $baselineName, $revision, $author, $date, $msg);

    $sth->execute( $baselineName, $revision, $author, $date, $msg )
        or LOGDIE sprintf( "can not insert subversion commit: %s, %s, %s, %s, %s", $baselineName, $revision, $author, $date, $msg);

    return;
}

sub newTestResult {
    my $self  = shift;
    my $param = { @_ };

    my $testExecutionId = $param->{testExecutionId};
    my $testResultName  = $param->{testResultName};
    my $testResultValue = $param->{testResultValue} eq "false" ? 0 : $param->{testResultValue};

    my $sth = $self->prepare(
        'CALL add_new_test_result( ?, ?, ? )'
    );
    DEBUG sprintf( "insert test result: %s, %s, %s", $testExecutionId, $testResultName, $testResultValue );
    $sth->execute( $testExecutionId, $testResultName, $testResultValue )
        or LOGDIE sprintf( "can not insert test result: %s, %s, %s", 
                                $testExecutionId, $testResultName, $testResultValue );

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
    my $productName  = $param->{productName}  || "";
    my $taskName     = $param->{taskName}     || "";
    my $action       = $param->{action};
    my $hostname     = hostname();
    my $method       = "";
    my $data         = [];

    my $dataListShort = [ $baselineName, $comment,                         $jobName, $buildNumber, $productName, $taskName, $hostname ];
    my $dataListLong  = [ $baselineName, $comment, $branchName, $revision, $jobName, $buildNumber, $productName, $taskName, $hostname ];
    my $dataHash      = { 
            build_started       => $dataListLong,
            build_failed        => $dataListShort,
            build_finished      => $dataListShort,
            other_failed        => $dataListShort,
            other_finished      => $dataListShort,
            other_started       => $dataListShort,
            other_unstable      => $dataListShort,
            package_failed      => $dataListShort,
            package_finished    => $dataListShort,
            package_started     => $dataListShort,
            release_finished    => $dataListShort,
            release_started     => $dataListShort,
            release_failed      => $dataListShort,
            subrelease_finished => $dataListShort,
            subrelease_started  => $dataListShort,
            subrelease_failed   => $dataListShort,
            subbuild_failed     => $dataListShort,
            subbuild_finished   => $dataListShort,
            subbuild_started    => $dataListShort,
            subtest_failed      => $dataListShort,
            subtest_finished    => $dataListShort,
            subtest_started     => $dataListShort,
            subtest_unstable    => $dataListShort,
            test_failed         => $dataListShort,
            test_finished       => $dataListShort,
            test_started        => $dataListShort,
    };


    $data   = $dataHash->{$action};
    $method = sprintf( "$action( %s )", join( ", ", map { "?" } @{ $data } ) );

    DEBUG "executing $action with $method and data (" . join( ", ", @{ $data } ) . ")";

    my $sth = $self->prepare(
        "CALL $method"
    );

    $sth->execute( @{ $data } )
        or LOGDIE sprintf( "can not insert data\n%s\n", $sth->errstr() );

    return;
}

sub branchInformation {
    my $self  = shift;
    my $param = { @_ };

    my $sth = $self->prepare( 
        "SELECT * FROM branches"
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
