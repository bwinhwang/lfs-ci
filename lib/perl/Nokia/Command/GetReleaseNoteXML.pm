package Nokia::Command::GetReleaseNoteXML; # {{{
## @brief generate release note content
use strict;
use warnings;

use XML::Simple;
use Data::Dumper;
use POSIX qw(strftime);
use Getopt::Std;

use Nokia::Singleton;
use Nokia::Model::ReleaseNote;

use parent qw( Nokia::Object );

sub quote {
    my $self = shift;
    my $data = shift;
    $data =~ s/&/&amp;/g;
    $data =~ s/</&lt;/g;
    $data =~ s/>/&gt;/g;
    return $data;
}

sub prepare {
    my $self = shift;
    my %duplicates;

    # t: := tag name
    # r: := release note template file
    getopts( "r:t:f:o:", \my %opts );
    $self->{tagName}         = $opts{t} || die "no t";
    $self->{basedOn}         = $opts{o} || die "no o";
    $self->{configFileName}  = $opts{f} || die "no f";

    my $config = Nokia::Singleton::config();
    $config->loadData( configFileName => $self->{configFileName} );

    $self->{releaseNote} = Nokia::Model::ReleaseNote->new( releaseName => $self->{tagName} );

    my $svn = Nokia::Singleton::svn();

    my $xml = XMLin( "changelog.xml", ForceArray => 1 ) or die "can not open changelog.xml";

    my $subsysHash;
    foreach my $entry ( @{ $xml->{logentry} } ) {

        my $overrideMessage= $self->{releaseNote}->commentForRevision( $entry->{revision} );



        my $completeMessage = $overrideMessage 
                    ?  $overrideMessage
                    :  ref( $entry->{msg}->[0] ) eq "HASH" 
                        ? sprintf( "empty commit message (r%s) from %s at %s", $entry->{revision}, $entry->{author}->[0], $entry->{date}->[0] ) 
                        : $entry->{msg}->[0] ;

        foreach my $msg ( split( /\n/, $completeMessage ) ) {
            if( $msg =~ m/^\%RB=(\d+)(.*)$/) {
                $self->{releaseNote}->addImportantNoteMessage( $self->quote( sprintf( "RB=%d ", $1 )http://link/to/rbt/$1 ) );
            }
            if( $msg =~ m/[\%\#]REM (.*)/) {
                $self->{releaseNote}->addImportantNoteMessage( $self->quote( $1 ) );
            }
            # jira stuff
            if( $msg =~ m/^.*(BTS[A-Z]*-[0-9]*)\s*PR\s*([^ :]*)(.*$)/  ) {
                push @{ $self->{PR} }, { jira => $1,
                                         nr   => $2,
                                         text => $self->quote( $3 ), };
            }
            # change note
            elsif( $msg =~ m/^.*(BTS[A-Z]-[0-9]*)\s*CN\s*([^ :]*)(.*$)/ ) {
                push @{ $self->{CN}}, { jira => $1,
                                        nr   => $2,
                                        text => $self->quote( $3 ), };
            }
            # new feature
            if( $msg =~ m/^.*(BTS[A-Z]-[0-9]*)\s*NF\s*([^ :]*)(.*$)/ ) {
                push @{ $self->{NF}}, { jira => $1,
                                        nr   => $2,
                                        text => $self->quote( $3 ), };
            }
            # %FIN PR=PR123456 foobar
            elsif( $msg =~ m/\s*[#%]FIN\s+[%@](PR|NF|CN)=(\w+)(.*)/ ) {
                push @{ $self->{ $1 } }, { nr   => $2,
                                           text => $self->quote( $2 . $3 ) , };
            }
            # notes
            if( $msg =~ m/Transport Drivers/ ) {
                push @{ $self->{notes} }, { notes => "Change in Transport Drivers. Please update transport software also when testing this release." };
            }
        }
    }

    $self->{templateFileName} = $config->getConfig( name => "LFS_PROD_ReleaseNote_TemplateFileXml" );
    if( not -e $self->{templateFileName} ) {
        die sprintf( "template file %s does not exist", $self->{templateFileName} );
    }
    open TEMPLATE, $self->{templateFileName} or die "can not open template file xml";
    $self->{template} = join( "", <TEMPLATE> );
    close TEMPLATE;

    # collect data
    # __TAGNAME__
    $self->{data}{TAGNAME} = $self->{tagName};
    # __BRANCH__
    $self->{data}{BRANCH}  = $config->getConfig( name => "LFS_PROD_ps_scm_branch_name" );

    # __LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL__
    $self->{data}{LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL} = $ENV{"LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL"};
    # __DATE__
    $self->{data}{DATE} = strftime( "%Y-%m-%d", gmtime());
    # __TIME__
    $self->{data}{TIME} = strftime( "%H:%M:%SZ", gmtime());
    # __BASED_ON__
    $self->{data}{BASED_ON} = $self->{basedOn};
    # __IMPORTANT_NOTE__
    $self->{data}{IMPORTANT_NOTE} = $self->{releaseNote}->importantNote();

    # __SVN_OS_REPOS_URL__
    $self->{data}{SVN_OS_REPOS_URL} = $config->getConfig( name => "LFS_PROD_svn_delivery_os_repos_url" );

    # __SVN_OS_REPOS_REVISION__
    my $svnUrl = sprintf( "%s/tags/%s", 
                            $self->{data}{SVN_OS_REPOS_URL},
                            $self->{data}{TAGNAME},
                        );
    $self->{data}{SVN_OS_REPOS_REVISION} = ""; # $svn->info( url => $svnUrl )->{entry}->{commit}->{revision};
    # __SVN_OS_TAGS_URL_WITH_REVISION__
    $self->{data}{SVN_OS_TAGS_URL_WITH_REVISION} = $svnUrl;

    # __SVN_REL_REPOS_URL__
    $self->{data}{SVN_REL_REPOS_URL}  = $config->getConfig( name => "LFS_PROD_svn_delivery_release_repos_url" );
    # __SVN_REL_REPOS_NAME__
    $self->{data}{SVN_REL_REPOS_NAME} = $config->getConfig( name => "LFS_PROD_svn_delivery_repos_name" );
    # __SVN_REL_REPOS_REVISION__
    $svnUrl = sprintf( "%s/tags/%s", 
                         $self->{data}{SVN_REL_REPOS_URL} || "",
                         $self->{data}{LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL} || "",
                     );
    $self->{data}{SVN_REL_REPOS_REVISION} = ""; # $svn->info( url => $svnUrl )->{entry}->{commit}->{revision};
    # __SVN_REL_TAGS_URL_WITH_REVISION__
    $self->{data}{SVN_REL_TAGS_URL_WITH_REVISION} = $svnUrl;

    # __SVN_SOURCE_TAGS_URL_WITH_REVISION__
    $self->{data}{SVN_SOURCE_REPOS_URL} = $config->getConfig( name => "lfsSourceRepos" );

    $svnUrl = sprintf( "%s/os/tags/%s", 
                         $self->{data}{SVN_SOURCE_REPOS_URL},
                         $self->{data}{TAGNAME},
                     );

    $self->{data}{SVN_SOURCE_TAGS_REVISION}          = ""; # $svn->info( url => $svnUrl )->{entry}->{commit}->{revision};
    $self->{data}{SVN_SOURCE_TAGS_URL_WITH_REVISION} = $svnUrl;

    # __CORRECTED_FAULTS__
    $self->{data}{CORRECTED_FAULTS} = join( "\n        ", 
                                            map { sprintf( "<fault %sid=\"%s\">%sPR %s</fault>",
                                                            $_->{jira} ? sprintf( "info=\"jira issue number: \" ", $_->{jira} ) : "",
                                                            $_->{nr},
                                                            $_->{jira} ? sprintf( "%s: ", $_->{jira} ) : "",
                                                            $_->{text},
                                                        ) }
                                            grep { not $duplicates{ $_->{nr} } ++ }
                                            @{ $self->{PR} || [] }
                                        );
    # __FEATURES__
    $self->{data}{FEATURES} = join( "\n        ", 
                                    map { sprintf( "<feature id=\"%s\">%sNF %s</feature>",
                                                    $_->{nr},
                                                    $_->{jira} ? sprintf( "%s: ", $_->{jira} ) : "",
                                                    $_->{text},
                                                ) }
                                     grep { not $duplicates{ $_->{nr} } ++ }
                                    @{ $self->{NF} || [] }
                                  );
    # __BASELINES__
    my @baselineFiles =  glob( "bld/bld-externalComponents-summary/externalComponents*" );
    push @baselineFiles, glob( "bld/bld-*psl-*/results/doc/versions/fpga_baselines.txt" );
    push @baselineFiles, glob( "bld/bld-pkgpool-release/forRe*.txt" );

    foreach my $file ( @baselineFiles ) {
        open FILE, $file or die "can not open file $file";
        while( my $line = <FILE> ) {
            chomp( $line );
            if( $line =~ m/^([\w-]+).*\s*=\s*(.*)$/ ) {
                push @{ $self->{baselines} }, { baseline => uc $1,
                                                tag      => $2 };
            }
            if( $line =~ m/^((PS_LFS_FW)_.*)$/ ) {
                push @{ $self->{baselines} }, { baseline => $2,
                                                tag      => $1 };
            }
        }
    }
    foreach my $hash ( @{ $self->{baselines} } ) {
        if( $hash->{baseline} =~ m/brm35/i ) {
            $hash->{baseline} =  "PS_LFS_BT";
            # FSMR4LBT140601
            $hash->{tag}      =~ s/^(.*)LBT(\d\d)(\d\d)(\d*).*$/PS_LFS_BT_FSMR4_20${2}_${3}_${4}/;
        }
        elsif( $hash->{baseline} =~ m/brm/i ) {
            $hash->{baseline} =  "PS_LFS_BT";
            # LBT140602-ci1
            # FSMR4LBT140601
            $hash->{tag}      =~ s/^(.*)LBT(\d\d)(\d\d)(\d*).*$/PS_LFS_BT_20${2}_${3}_${4}/;
        }
        if( $hash->{baseline} eq "PKGPOOL" ) {
            $hash->{baseline} = "PS_LFS_PKG";
        }
        if( $hash->{baseline} =~ m/sdk/i ) {
            $hash->{baseline} = "PS_LFS_SDK";
        }
    }

    $self->{data}{BASELINES} = join( "\n    ", 
                                        map { sprintf( '<baseline name="%s" auto_create="true">%s</baseline>',
                                                         $_->{baseline},
                                                         $_->{tag},
                                                     ) }
                                        grep { not $duplicates{ $self->{baselines} . $_->{tag} } ++ }
                                        grep { $_->{tag} !~ m/SDK_2/ } 
                                         @{ $self->{baselines} || [] }
                                     );

    # __CHANGENOTES__
    $self->{data}{CHANGENOTES} = join( "\n        ", 
                                        map { sprintf( "<changenote id=\"CN %s\">CN %s%s</changenote>",
                                                         $_->{nr},
                                                         $_->{nr},
                                                         $_->{text},
                                                     ) }
                                         @{ $self->{CN} || [] }
                                     );

    $self->{template} =~ s/__([A-Z_]*)__/ $self->{data}{$1} || "" /ge;

    return;
}

sub execute {
    my $self = shift;
    print $self->{template};
    return;
}

1;
