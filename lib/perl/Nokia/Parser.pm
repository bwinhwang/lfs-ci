package Nokia::Parser; 
## @fn    parser
#  @brief parent class for the parser

use strict;
use warnings;

use parent qw( Nokia::Object );

## @fn     fileName()
#  @brief  returns the fileName
#  @param  <none>
#  @return file name
sub fileName { my $self = shift; return $self->{fileName}; }

## @fn     fileContent()
#  @brief  returns the content of the file to parse
#  @param  <none>
#  @return content of the file to parse
sub fileContent {
    my $self     = shift;
    my $fileName = $self->fileName();

    if( not defined $self->{fileContent} ) {
        open( FILE, $fileName ) or die "can not open file $fileName: $!\n";
        $self->{fileContent} = join "", <FILE>;
        close FILE;
    }

    $self->joinMultiLines();

    return $self->{fileContent};
}

## @fn     joinMultiLines()
#  @brief  joins a multiline "line" to a single line
#  @detail example: a line
#             foo \
#             bar
#          will be joined to "foo bar"
#  @return join string
sub joinMultiLines {
    my $self = shift;

    $self->{fileContent} =~ s/\n/\\n/g;
    $self->{fileContent} =~ s/\\\\n//g;
    $self->{fileContent} =~ s/\\n/\n/g;

    return;
}

## @fn     parse()
#  @brief  parse a location or dependencies file
#  @param  <none>
#  @return <none>
sub parse {
    my $self = shift;

    # printf( STDERR "parsing %s\n", $self->fileName() || "string from svn" );

    foreach my $line ( split( /\n/, $self->fileContent() ) ) {
        next if $line =~ m/^\s*$/; # remove empty lines
        next if $line =~ m/^\s*#/; # remove comments

        my ( $command, @args ) = split( /\s+/, $line );

        $command =~ s/_/++/g;
        $command =~ s/-/_/g;

        if( $self->can( $command ) ) {
            $self->$command( @args );
        } else {
            die "command $command is not defined in parser\n";
        }
    }

    return;
}

1;
