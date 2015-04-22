package Nokia::Command::DiffToChangelog; 
# @brief creates a svn style xml changelog file from the output of diff <a> <b>
use strict;
use warnings;

use Nokia::Object;

use parent        qw( Nokia::Object );

use POSIX         qw( strftime );
use Log::Log4perl qw( :easy );
use Getopt::Std;

sub init {
    my $self = shift;
    $self->{msg}     = "";
    $self->{pathes}  = [];
    $self->{changes} = {};

    return;
}

sub prepare {
    my $self = shift;
    getopts( "a:b:d", \my %opts );

    open CMD, sprintf( "diff %s %s|", $opts{a}, $opts{b} ) 
        or LOGDIE "can not execute diff";

    while( <CMD> ) {
        chomp;
        next if not m/[<>]/;
        my ( $op, $time, $path ) = split( /\s+/, $_ );

        if( $op eq "<" ) {
            INFO "$path was deleted";
            $self->{changes}{ $path } = "D";
        } elsif( $op eq ">"  and exists $self->{changes}{ $path } and $self->{changes}{ $path } eq "D" ) {
            # TODO: demx2fk3 2014-08-12 fix me - make this configureable
            # $changes{ $path } = "M";
            INFO "$path was modified";
            delete $self->{changes}{ $path };
        } else {
            # noop
            # INFO "$path was added";
            # $changes{ $path } = "A";
        }
    }
    close CMD;
    return;
}

sub execute {
    my $self = shift;

    my %types = ( "A" => "added", "M" => "modified", "D" => "deleted" );

    printf( "<?xml version=\"1.0\"?>
<log>
    <logentry revsion=\"%d\">
        <author>%s</author>
        <date>%s</date>
        <paths>
            %s
        </paths>
        <msg>%s</msg>
    </logentry>
</log>
",
        time(),
        $ENV{ "USER" },
        strftime( "%Y-%m-%dT%H:%M:%S.000000Z", gmtime( time() ) ),
        join( "            \n", 
            map { sprintf( '<path kind="" action="%s">%s</path>', $self->{changes}{ $_ }, $_, ) } 
            keys %{ $self->{changes} } ),
        join( "\n", 
            map { sprintf( "%s %s ", $types{ $self->{changes}{ $_ } }, $_, ) } 
            sort 
            keys %{ $self->{changes} } ),
);

    return;
}

1;
