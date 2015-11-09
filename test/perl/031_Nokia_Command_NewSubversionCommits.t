#!/usr/bin/perl
use strict;
use warnings;

# BEGIN {
#     no strict 'refs';
#     *{'CORE::GLOBAL::-f'} = sub { print "-e ok\n";
#                                   return 0 };
# }

use Test::MockModule;
use Test::Exception;
use Test::More;

require_ok( "Nokia::Command::NewSubversionCommits" );

my $obj;

ok( $obj = Nokia::Command::NewSubversionCommits->new(), "create new object" );
isa_ok( $obj, "Nokia::Command::NewSubversionCommits" );
# isa_ok( $obj, "Nokia::Model" );
isa_ok( $obj, "Nokia::Object" );

can_ok( $obj, qw( new 
                ) );

done_testing();





