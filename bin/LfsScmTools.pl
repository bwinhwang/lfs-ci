#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use Log::Log4perl qw( :easy );

use lib sprintf( "%s/lib/perl/", $ENV{LFS_CI_ROOT} || "." );

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
                 getConfig                      => "Nokia::Command::GetConfig",
                 getDependencies                => "Nokia::Command::GetDependencies",
                 getDownStreamProjects          => "Nokia::Command::GetDownStreamProjects",
                 getFromString                  => "Nokia::Command::GetFromString",
                 getNewTagName                  => "Nokia::Command::GetNewTagName",
                 getReleaseNoteContent          => "Nokia::Command::GetReleaseNoteContent",
                 getReleaseNoteXML              => "Nokia::Command::GetReleaseNoteXML",
                 getRevisionTxtFromDependencies => "Nokia::Command::GetRevisionTxtFromDependencies",
                 getUpStreamProject             => "Nokia::Command::GetUpStreamProject",
                 removalCandidates              => "Nokia::Command::RemovalCandidates",
                 sendReleaseNote                => "Nokia::Command::SendReleaseNote",
                 sortBuildsFromDependencies     => "Nokia::Command::SortBuildsFromDependencies",
                 getBranchInformation           => "Nokia::Command::GetBranchInformation",
                 newEvent                       => "Nokia::Command::NewEvent",
                 newSubversionCommits           => "Nokia::Command::NewSubversionCommits",
                 newTestResults                 => "Nokia::Command::NewTestResults",
                 reserveTarget                  => "Nokia::Command::ReserveTarget",
                 unreserveTarget                => "Nokia::Command::UnreserveTarget",
                 searchTarget                   => "Nokia::Command::SearchTarget",
               );

if( not exists $commands{$program} ) {
    die "command $program not defined";
}

eval "use $commands{$program};";
if( @_ ) {
    die "@_";
}

Nokia::Singleton::config()->loadData( configFile => $ENV{"LFS_CI_CONFIG_FILE"} );

my $command = $commands{$program}->new();
$command->prepare( @ARGV );
$command->execute() and die "can not execute $program";

INFO "}}} Thank you for making a little program very happy";
exit 0;
