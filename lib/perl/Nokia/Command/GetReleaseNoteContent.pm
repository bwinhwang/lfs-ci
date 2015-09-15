package Nokia::Command::GetReleaseNoteContent; 
## @brief generate release note content
use strict;
use warnings;

use XML::Simple;
use Data::Dumper;
use Getopt::Std;
use Log::Log4perl qw( :easy );

use Nokia::Command;
use Nokia::Model::ReleaseNote;
use Nokia::Singleton;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;

    getopts( "t:", \my %opts );
    $self->{tagName} = $opts{t} || die "no t";

    my $xml  = XMLin( "changelog.xml", ForceArray => 1 ) or die "can not open changelog.xml";

    $self->{releaseNote} = Nokia::Model::ReleaseNote->new( releaseName => $self->{tagName} );

    my $subsysHash;
    foreach my $entry ( @{ $xml->{logentry} } ) {

        my $overrideMessage= $self->{releaseNote}->commentForRevision( $entry->{revision} );

        my $msg = $overrideMessage 
                    ?  $overrideMessage
                    :  ref( $entry->{msg}->[0] ) eq "HASH" 
                        ? sprintf( "empty commit message (r%s) from %s at %s", 
                                        $entry->{revision}, 
                                        $entry->{author}->[0], 
                                        $entry->{date}->[0],   ) 
                        : $entry->{msg}->[0];
        
        if( $msg =~ m/set Dependencies, Revisions for Release/i or
            $msg =~ m/set Dependencies for Release/i or
            $msg =~ m/new Version files for Release/i or
            $msg =~ m/empty commit message/i or
            $msg =~ m/INTERNAL COMMENT/ )
        {
            # skip this type of comments.
            next;
        }
        my @newMessage;
        foreach my $line ( split( /[\n\r]+/, $msg ) ) {

            if( $line =~ m/^\%RB=(\d+)(.*)$/) {
                DEBUG "found RB entry";
                DEBUG "line = $line";
                $self->{releaseNote}->addImportantNoteMessage( sprintf( "RB=%d: %s --> https://psreviewboard.emea.nsn-net.net/r/%d", $1, $2, $1 ) );
            }
            if( $line =~ m/[\%\#]REM (.*)/) {
                $self->{releaseNote}->addImportantNoteMessage( $1 );
            }

            # cleanup the message a little bit
            $line =~ s/[\%\#]FIN  *[\%\#](\w+)=(\S+)\s*(.*)/$1 $2 $3 (completed)/g;
            $line =~ s/[\%\#]TBC  *[\%\#](\w+)=(\S+)\s*(.*)/$1 $2 $3 (to be continued)/g;
            $line =~ s/[\%\#]TPC  *[\%\#](\w+)=(\S+)\s*(.*)/$1 $2 $3 (work in progress)/g;
            $line =~ s/[\%\#]REM /Remark: /g;
            $line =~ s/[\%[#]RB=\d+//g;
            $line =~ s/\s*commit [0-9a-f]+\s*//g;
            $line =~ s/\s*Author: .*[@].+//g;
            $line =~ s/\s*Date: .* [0-9]+:[0-9]+:[0-9]+ .*//g;
            $line =~ s/\n/\\n/g;
            $line =~ s/\s+/ /g;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            $line =~ s/\(ros\)/ /;
            $line =~ s/\s*NOJCHK\s*//;
            $line =~ s/\bDESCRIPTION:\s*/ /;
            $line =~ s/\bREADINESS\s*:\s*COMPLETED\s*/ /;
            $line =~ s/^BTSPS-\d+\s+IN[^:]+:\s*//;
            $line =~ s/^BTSPS-\d+\s+IN\s*//;
            $line =~ s/  */ /g;
            $line =~ s/^fk\s*:\s*//;
            $line =~ s/\\n/\n/g;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            next if $line =~ m/^\s*$/;

            push @newMessage, $line;
        }

        $msg = join( "\n", @newMessage );

        my @pathes = map { $_->{content} }
                    @{ $entry->{paths}->[0]->{path} };

        foreach my $p ( @pathes ) {
            my $component = "Subversion branch creation or merge";
            if( $p =~ m:/(src-\w*)/: or
                $p =~ m:/(src-\w*)$: ) {
                $component = $1;
            }
            $subsysHash->{ $component }->{ $msg } = undef;
            DEBUG "component = $component / $p / $msg";
        }
    }

    DEBUG "changelog entry parsing done";

    # map the comments to the component names
    my $changeLogAsTextHash;
    my $duplicates;

    foreach my $key ( keys %{ $subsysHash } ) {
        DEBUG "key = $key";
        my $componentName = $key; # $components[1];
        
        push @{ $changeLogAsTextHash->{ $componentName } }, grep { $_ }
                                                            grep { not $duplicates->{ $componentName }{$_}++ }
                                                            map  { $self->filterComments( $_ ); } 
                                                            keys %{ $subsysHash->{$key} };
    }

    $self->{changeLog} = $changeLogAsTextHash;
    return;
}

sub execute {
    my $self = shift;

    binmode STDOUT, ":utf8";

    my $importantNote = $self->{releaseNote}->importantNote();
    if( $importantNote ) {
        printf "--- Important Note ---\n\n";
        printf "%s\n\n", $importantNote;
    }

    foreach my $component ( keys %{ $self->{changeLog} } ) {

        my @list = $self->{changeLog}->{$component};
        @list = map { @{ $_ } } @list;
        
        if( @list ) {
            print "\n";
            printf "=== %s ===\n", $self->mapComponentName( $component );
            print         "   * ";
            print join( "\n   * ", map { s/\n/\n     /g; $_ } @list );
            print "\n";
        }
    }

    return;
}

sub mapComponentName {
    my $self = shift;
    my $name = shift;
    # TODO FIXME do this different!
    # DEBUG "mapping component name $name";
    # Singleton::configStore( "cache" )->{data}->{"src"} = { name => "src", value => $name };
    # DEBUG Dumper( Singleton::config() );
    # return Singleton::config()->getConfig( name => "LFS_PROD_uc_release_component_name" ) || $name;
    my $data = {
        'src-project'        => "Project Meta Information",
        'src-bos'            => "Linux Kernel Config",
        'src-cvmxsources'    => "CVMX Sources",
        'src-cvmxsources3'   => "CVMX Sources 3.x",
        'src-ddal'           => "FSMr2 DDAL",
        'src-ddg'            => "Kernel Drivers",
        'src-ifddg'          => "Intreface Kernel Drivers",
        'src-firmware'       => "Firmware",
        'src-fsmbos'         => "Linux Kernel Config",
        'src-fsmbrm'         => "FSMr3 U-Boot",
        'src-fsmbrm35'       => "FSMr4 U-Boot",
        'src-fsmddal'        => "DDAL Library",
        'src-fsmddg'         => "Kernel Drivers",
        'src-fsmdtg'         => "Transport Drivers",
        'src-fsmfirmware'    => "Firmware",
        'src-fsmfmon'        => "FMON",
        'src-fsmifdd'        => "DDAL Library API",
        'src-fsmpsl'         => "Software Load",
        'src-fsmrfs'         => "Root Filesystem",
        'src-ifddal'         => "FSMr2 DDAL Library API",
        'src-kernelsources'  => "Linux Kernel",
        'src-kernelsources3' => "Linux Kernel 3.x",
        'src-lrcbrm'         => "LRC U-Boot",
        'src-lrcddal'        => "LRC specific DDAL",
        'src-lrcddg'         => "LRC Kernel Drivers",
        'src-lrcifddg'       => "LRC Kernel Drivers Interface",
        'src-lrcpsl'         => "LRC Software Load",
        'src-mddg'           => "FSMr2 Kernel Drivers",
        'src-mrfs'           => "FSMr2 Root Filesystem",
        'src-psl'            => "FSMr2 Software Load",
        'src-rfs'            => "Common Root Filesystem",
        'src-test'           => "Testing",
        'src-tools'          => "Tools (LRC)",
    };

    return $data->{$name} || $name;
}

sub filterComments {
    my $self        = shift;
    my $commentLine = shift;

    DEBUG "filter component $commentLine";

    # remove new lines at the end
    $commentLine =~ s/\n$//g;

    Nokia::Singleton::config()->loadData( configFileName => $self->{configFileName} );
    my $jiraComment = Nokia::Singleton::config()->getConfig( name => "LFS_PROD_uc_release_svn_message_prefix" );
    return if $commentLine =~ m/$jiraComment/;

    # TODO: demx2fk3 2014-09-08 remove this line, if legacy CI is switched off
    return if $commentLine =~ m/BTSPS-1657 IN psulm: DESCRIPTION: set Dependencies, Revisions for Release .* r\d+ NOJCHK/;

    return $commentLine;
}

1;
