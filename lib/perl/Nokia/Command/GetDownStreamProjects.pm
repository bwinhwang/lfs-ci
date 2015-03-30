package Nokia::Command::GetDownStreamProjects; # {{{
use strict;
use warnings;

use XML::Simple;
use Getopt::Std;

use Nokia::Command;

use parent qw( Nokia::Command );

sub readBuildXml {
    my $self  = shift;
    my $param = { @_ };
    my $file  = $param->{file};

    my $xml  = XMLin( $file, ForceArray => 1 );
    my @builds = @{ $xml->{actions}->[0]->{'hudson.plugins.parameterizedtrigger.BuildInfoExporterAction'}->[0]->{builds}->[0]->{'hudson.plugins.parameterizedtrigger.BuildInfoExporterAction_-BuildReference'} || [] };

    my @results;

    foreach my $build ( @builds ) {

        my $newFile = sprintf( "%s/jobs/%s/builds/%s/build.xml",
                                $self->{home},
                                $build->{projectName}->[0],
                                $build->{buildNumber}->[0] );

        push @results, sprintf( "%s:%s:%s", $build->{buildNumber}->[0],
                                            $build->{buildResult}->[0],
                                            $build->{projectName}->[0] );
        if ( -f $newFile ) {
            push @results, $self->readBuildXml( file => $newFile );
        }
    }

    return @results;
}

sub prepare {
    my $self = shift;
    my @args = @_;

    getopts( "j:b:h:", \my %opts );
    $self->{jobName} = $opts{j} || die "no job name";
    $self->{build}   = $opts{b} || die "no build number";
    $self->{home}    = $opts{h} || die "no home";

    return;
}

sub execute {
    my $self = shift;

    my $file = sprintf( "%s/jobs/%s/builds/%s/build.xml",
                        $self->{home},
                        $self->{jobName},
                        $self->{build},
                      );

    my @results = $self->readBuildXml( file => $file );

    foreach my $line ( @results ) {
        printf( "%s\n", $line );
    }

    return;
}

1;
