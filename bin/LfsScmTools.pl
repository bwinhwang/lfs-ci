#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl qw( :easy );

our $lfs_ci_root;
BEGIN {
    use FindBin qw($Bin);
    use File::Basename;
    $lfs_ci_root = dirname($Bin);
}   

use lib sprintf( "%s/lib/perl/", $lfs_ci_root );

use Nokia::Singleton;

my %l4p_config = (
    'log4perl.category'                                  => 'TRACE, Logfile',
    'log4perl.category.Sysadm.Install'                   => 'OFF',
    'log4perl.appender.Logfile'                          => 'Log::Log4perl::Appender::File',
    'log4perl.appender.Logfile.filename'                 => $ENV{CI_LOGGING_LOGFILENAME}, 
    'log4perl.appender.Logfile.layout'                   => 'Log::Log4perl::Layout::PatternLayout',
    'log4perl.appender.Logfile.layout.ConversionPattern' => '%d{ISO8601}       UTC [%9r] [%-8p] %M:%L -- %m%n',
);

if( $ENV{CI_LOGGING_LOGFILENAME} ) {
    # we are only create a log, if the log already exists.
    # this is the case, if the perl script is called from the ci scripting (bash)
    Log::Log4perl::init( \%l4p_config );
}

my $program = basename( $0, qw( .pl ) );
INFO "{{{ welcome to $program";

my %commands = (
                 diffToChangelog                => "Nokia::Command::DiffToChangelog",
                 dumpConfig                     => "Nokia::Command::DumpConfig",
                 getBranchInformation           => "Nokia::Command::GetBranchInformation",
                 getConfig                      => "Nokia::Command::GetConfig",
                 getDependencies                => "Nokia::Command::GetDependencies",
                 getDownStreamProjects          => "Nokia::Command::GetDownStreamProjects",
                 getFingerprintData             => "Nokia::Command::GetFingerprintData",
                 getFromString                  => "Nokia::Command::GetFromString",
                 getLocationsText               => "Nokia::Command::GetLocationsText",
                 getNewTagName                  => "Nokia::Command::GetNewTagName",
                 getReleaseNoteContent          => "Nokia::Command::GetReleaseNoteContent",
                 getReleaseNoteXML              => "Nokia::Command::GetReleaseNoteXML",
                 getRevisionTxtFromDependencies => "Nokia::Command::GetRevisionTxtFromDependencies",
                 getUpStreamProject             => "Nokia::Command::GetUpStreamProject",
                 newEvent                       => "Nokia::Command::NewEvent",
                 newSubversionCommits           => "Nokia::Command::NewSubversionCommits",
                 newTestResults                 => "Nokia::Command::NewTestResults",
                 removalCandidates              => "Nokia::Command::RemovalCandidates",
                 reserveTarget                  => "Nokia::Command::ReserveTarget",
                 searchTarget                   => "Nokia::Command::SearchTarget",
                 sendReleaseNote                => "Nokia::Command::SendReleaseNote",
                 sortBuildsFromDependencies     => "Nokia::Command::SortBuildsFromDependencies",
                 unreserveTarget                => "Nokia::Command::UnreserveTarget",
                 customScmDatabaseBranches      => "Nokia::Command::CustomScm::DatabaseBranches",
               );

if( not exists $commands{$program} ) {
    die "command $program not defined";
}

eval "use $commands{$program};";
if( @_ ) {
    die "@_";
}

if( $program ne "getConfig" ) {
    Nokia::Singleton::config()->loadData( configFile => $ENV{"LFS_CI_CONFIG_FILE"} );
}

my $command = $commands{$program}->new();
$command->prepare( @ARGV );
$command->execute() and die "can not execute $program";

INFO "}}} Thank you for making a little program very happy";
exit 0;
