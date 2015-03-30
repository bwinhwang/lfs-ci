package Nokia::Command::GetFromString; # {{{
## @brief    get a specified information from a string
#   @details parses the string and return the requested substring.
#            string: e.g. LFS_CI_-_asdf_v3.x_-_build_-_FSM-r3_-_fct
#            wanted: location | subTaskName | subTaskName | platform
#
# usage: $0 <JOB_NAME> <wanted>
#

# refactor this command, make it much simplier:
# my $string = $ARGV[0]; # string, which should be parsed
# my $wanted = $ARGV[1]; # wanted substring from regex


use strict;
use warnings;

use Log::Log4perl qw( :easy );
use Data::Dumper;

use Nokia::Object;

use parent qw( Nokia::Object );

sub prepare {
    my $self = shift;
    $self->{string} = shift; # string, which should be parsed
    $self->{wanted} = shift; # wanted substring from regex
    return;
}

sub execute {
    my $self = shift;

    my $string = $self->{string};
    my $wanted = $self->{wanted};

    my $wantMap = {
                    productName => 0,
                    location    => 1,
                    branch      => 1,
                    taskName    => 2,
                    subTaskName => 3,
                    platform    => 4,
                  };

    # if the user gave a number instead of a string
    if( not $wantMap->{$wanted} and $wanted =~ m/^\d+$/ ) {
        $wantMap->{ $wanted } = $wanted;
    }
    elsif( $string =~ m/^Admin/ ) {
        $wantMap = {
                        productName => 0,
                        taskName    => 1,
                        subTaskName => 2,
                        platform    => 3,
                    };
    }
    if( not exists $wantMap->{$wanted} ) {
        # if we don't know the key, we set it to something empty
        # hopefully nobody will ever use 999x_-_ :)
        $wantMap->{$wanted} = 999;
    }

    my @resultArray = split( "_-_", $string );

    # some special cases...
    if( $wanted eq "productName" or
        $wanted eq "0" ) {
        @resultArray = split( "_", $resultArray[ $wantMap->{$wanted} ] );
    }
    
    my $result = $resultArray[ $wantMap->{$wanted} ];

    DEBUG sprintf( "wanted %s from \"%s\" ==> %s", $wanted, $string, $result || "not defined" );
    # required for real debugging in unit tests or something like this...
    # printf STDERR "%s\n", sprintf( "wanted %s from \"%s\" ==> %s", $wanted, $string, $result || "not defined" );
    # print STDERR Dumper( \@resultArray );
    # print STDERR Dumper( $wantMap );
    # print STDERR "\n";
    printf "%s\n", $result || "";

    return;
}

1;
