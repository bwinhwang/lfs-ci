#!/usr/bin/perl

# parses the string and return the requested substring.
# string: e.g. LFS_CI_-_asdf_v3.x_-_build_-_FSM-r3_-_fct
# wanted: location | subTaskName | subTaskName | platform

my $string = $ARGV[0]; # string, which should be parsed
my $wanted = $ARGV[1]; # wanted substring from regex

my $locationRE    = qr / (?<location> 
                           [A-Za-z0-9.:_+-]+?
                         )
                       /x;
my $subTaskNameRE = qr / (?<subTaskName>
                           [A-Za-z0-9.:_+-]+
                         )
                       /x;
my $taskNameRE    = qr / (?<taskName>
                           [^_-_]+
                         )
                       /x;
my $platformRE    = qr / (?<platform>
                           .*)
                       /x;
my $splitRE       = qr / _-_ /x;

my $regex = qr /
                    ^
                    LFS
                    _
                    ( CI | Prod )
                    $splitRE
                    $locationRE
                    $splitRE
                    $taskNameRE 
                    $splitRE?             # sub task name is 
                    $subTaskNameRE?       # an optional string
                    $splitRE
                    $platformRE
                    $
               /x;

if( $string =~ m/$regex/x ) {
    printf "%s\n", $+{ $wanted };
}

exit 0;
