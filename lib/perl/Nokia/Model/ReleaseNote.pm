package Nokia::Model::ReleaseNote; 
use warnings;
use strict;

use parent qw( Nokia::Model );

use File::Slurp;

## @fn      releaseName()
#  @brief   get the name of the release
#  @param   <none>
#  @return  release name
sub releaseName {
    my $self = shift;
    return $self->{releaseName};
}

## @fn      commentForRevision( $param )
#  @brief   get the replacement comment of a given revision
#  @details idea: you can replace a comment from svn with a comment from a text file.
#           So you can change something in the release note without any change in svn.
#  @param   {revision}    revision number
#  @return  new comment
sub commentForRevision {
    my $self     = shift;
    my $revision = shift;

    $self->mustHaveFileData( "revisions" );

    foreach my $line ( @{ $self->{revisions} } ) {
        next if $line =~ m/^\s*#/;
        next if $line =~ m/^\s*$/;
        if( $line =~ m/^(\d+)\s+(.*)/ ) {
            if( $1 == $revision ) {
                return $2;
            }
        }
    }
    return;
}

## @fn      importantNote()
#  @brief   get the important note for the release from a text file
#  @param   <none>
#  @return  important note
sub importantNote {
    my $self = shift;
    $self->mustHaveFileData( "importantNote" );
    my %duplicates;
    return join( "\n", grep { not $duplicates{$_}++ } 
                       @{ $self->{importantNote} || [] } );
}

sub addImportantNoteMessage {
    my $self    = shift;
    my $message = shift;
    push @{ $self->{importantNote} }, $message;
    return;
}

## @fn      mustHaveFileData( $fileType )
#  @brief   ensure, that the data of the file were read.
#  @param   {fileType}    type of the file which should be read. valid values: importantNotes, revisions
#  @return  <none>
sub mustHaveFileData {
    my $self     = shift;
    my $fileType = shift;
    if( not exists $self->{ $fileType } ) {
        foreach my $file ( ( sprintf( "%s/releaseNotes/%s/%s.txt", $ENV{HOME}, $self->releaseName(), $fileType ),
                             sprintf( "%s/svn/%s.txt", $ENV{WORKSPACE}, $fileType ) ) ) {
            if ( -e $file ) {
                $self->{ $fileType } = [ read_file( $file ) ];
            }
        }
    }
    return
}


1;
