#!/usr/bin/perl
# creates a svn style xml changelog file from the output of diff <a> <b>
# author: bernhard minks <bernhard.minks.ext@nsn.com>
use strict;
use warnings;

use Data::Dumper;
use POSIX qw( strftime );
use Getopt::Std;

my $msg = "";
my @pathes;
my %changes;

my %types = ( "A" => "added", "M" => "modified", "D" => "deleted" );

getopts( "a:b:", \my %opts );

open CMD, sprintf( "diff %s %s|", $opts{a}, $opts{b} ) or die "can not execute diff";
while( <CMD> ) {
    chomp;
    next if not m/[<>]/;
    my ( $op, $time, $path ) = split( /\s+/, $_ );

    if( $op eq "<" ) {
        $changes{ $path } = "D";
    } elsif( $op eq ">"  and exists $changes{ $path } and $changes{ $path } eq "D" ) {
        $changes{ $path } = "M";
    } else {
        $changes{ $path } = "A";
    }
}
close CMD;

printf( "<?xml version=\"1.0\"?>
<log>
    <logentry revsion=\"%d\">
        <author>%s</author>
        <date>%s</date>
        <paths>
            %s
        </paths>
        <msg>update in %s</msg>
    </logentry>
</log>
",
    time(),
    $ENV{ "USER" },
    strftime( "%Y-%m-%dT%H:%M:%S.000000Z", gmtime( time() ) ),
    join( "            \n", 
        map { sprintf( '<path kind="" action="%s">%s</path>', $changes{ $_ }, $_, ) } 
        keys %changes ),
    join( "\n", map { sprintf( "change in %s (%s)", $_, $types{ $changes{ $_ } }, ) } keys %changes ),
);

exit 0;
