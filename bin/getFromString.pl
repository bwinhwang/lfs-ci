#!/usr/bin/perl

# parses the string and return the requested substring.
# string: e.g. LFS_CI_-_asdf_v3.x_-_build_-_FSM-r3_-_fct
# wanted: location | subTaskName | subTaskName | platform

# usage: $0 <JOB_NAME> <wanted>

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
                           [^-_]+
                         )
                       /x;
my $platformRE    = qr / (?<platform>
                           .*)
                       /x;
my $splitRE       = qr / _-_ /x;

my $productRE     = qr / (?<productName>(Admin | LFS | UBOOT | PKGPOOL)) /x;

my $regex1 = qr /
                    ^
                    $productRE
                    _
                    ( CI | Prod )
                    $splitRE
                    $locationRE           # location aka branch 
                    $splitRE
                    $taskNameRE           # task name (Build)
                    $splitRE?             # sub task name is 
                    $subTaskNameRE?       # optional string, like FSM-r3
                    $splitRE
                    $platformRE           # platfrom, like fcmd, fspc, fct, ...
                    $
                /x;

my $regex2 = qr /
                    ^
                    $productRE
                    _
                    ( CI | Prod )
                    $splitRE
                    $locationRE           # location aka branch 
                    $splitRE
                    $taskNameRE           # task name (Build | Package | Testing )
                    $
                /x;

my $regex3 = qr /
                    ^
                    (Admin)
                    $splitRE
                    $taskNameRE           # task name (Build)
                    $splitRE?             # sub task name is 
                    $subTaskNameRE?       # optional string, like FSM-r3
                    $
                /x;


if( $string =~ m/$regex1/x or
    $string =~ m/$regex2/x or
    $string =~ m/$regex3/x
  ) {
    printf "%s\n", $+{ $wanted };
}

exit 0;
