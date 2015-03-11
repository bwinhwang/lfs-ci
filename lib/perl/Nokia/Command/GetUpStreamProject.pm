package Nokia::Command::GetUpStreamProject; 
use strict;
use warnings;

use XML::Simple;
use Getopt::Std;
use Data::Dumper;

use parent qw( Nokia::Command );

sub readBuildXml {
    my $self  = shift;
    my $param = { @_ };
    my $file  = $param->{file};

#         <hudson.model.Cause_-UpstreamCause>
#           <upstreamProject>LFS_CI_-_trunk_-_Package_-_package</upstreamProject>
#           <upstreamUrl>job/LFS_CI_-_trunk_-_Package_-_package/</upstreamUrl>
#           <upstreamBuild>159</upstreamBuild>
#           <upstreamCauses>
#             <hudson.model.Cause_-UpstreamCause>
#               <upstreamProject>LFS_CI_-_trunk_-_Build</upstreamProject>
#               <upstreamUrl>job/LFS_CI_-_trunk_-_Build/</upstreamUrl>
#               <upstreamBuild>473</upstreamBuild>
#               <upstreamCauses>
#                 <hudson.triggers.SCMTrigger_-SCMTriggerCause/>
#               </upstreamCauses>
#             </hudson.model.Cause_-UpstreamCause>
#           </upstreamCauses>
#         </hudson.model.Cause_-UpstreamCause>
#       </causes>

#   <hudson.model.CauseAction>
#       <causes>
#         <hudson.model.Cause_-UpstreamCause>
#           <upstreamProject>LFS_CI_-_trunk_-_Test</upstreamProject>
#           <upstreamUrl>job/LFS_CI_-_trunk_-_Test/</upstreamUrl>
#           <upstreamBuild>858</upstreamBuild>
#           <upstreamCauses>
#             <hudson.model.Cause_-UpstreamCause>
#               <upstreamProject>LFS_CI_-_trunk_-_Package_-_package</upstreamProject>
#               <upstreamUrl>job/LFS_CI_-_trunk_-_Package_-_package/</upstreamUrl>
#               <upstreamBuild>1070</upstreamBuild>
#               <upstreamCauses>
#                 <hudson.model.Cause_-UpstreamCause>
#                   <upstreamProject>LFS_CI_-_trunk_-_Build</upstreamProject>
#                   <upstreamUrl>job/LFS_CI_-_trunk_-_Build/</upstreamUrl>
#                   <upstreamBuild>1881</upstreamBuild>
#                   <upstreamCauses>
#                     <hudson.triggers.SCMTrigger_-SCMTriggerCause/>
#                   </upstreamCauses>
#                 </hudson.model.Cause_-UpstreamCause>
#                 <hudson.model.Cause_-UpstreamCause>
#                   <upstreamProject>LFS_CI_-_trunk_-_Build</upstreamProject>
#                   <upstreamUrl>job/LFS_CI_-_trunk_-_Build/</upstreamUrl>
#                   <upstreamBuild>1882</upstreamBuild>
#                   <upstreamCauses>
#                     <hudson.triggers.SCMTrigger_-SCMTriggerCause/>
#                   </upstreamCauses>
#                 </hudson.model.Cause_-UpstreamCause>
#               </upstreamCauses>
#             </hudson.model.Cause_-UpstreamCause>
#           </upstreamCauses>
#         </hudson.model.Cause_-UpstreamCause>
#       </causes>
#     </hudson.model.CauseAction>

    my @results;
    my $xml = XMLin( $file, ForceArray => 1 );
    my $upstream = $xml->{actions}->[0]->{'hudson.model.CauseAction'}->[0]->{causes}->[0]->{'hudson.model.Cause_-UpstreamCause'};

    # print STDERR Dumper( $xml->{actions}->[0]->{'hudson.model.CauseAction'}->[0] );
    foreach my $up ( @{ $upstream } ) {
        push @results, _getUpstream( $up );

    }

    return @results;
}

sub _getUpstream {
    my $upstream = shift;
    my @result;

    if( exists $upstream->{upstreamCauses} and
        ref $upstream->{upstreamCauses} eq "ARRAY" ) {
        my @array = @{ $upstream->{upstreamCauses}->[0]->{'hudson.model.Cause_-UpstreamCause'} || [] };
        foreach my $up ( @array ) {
            push @result, _getUpstream( $up );
        }
    }
    push @result, sprintf( "%s:%s", $upstream->{upstreamProject}->[0], $upstream->{upstreamBuild}->[0], );

    return @result;
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
