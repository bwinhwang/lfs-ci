#!/usr/bin/perl
use strict;
use warnings;
use Test::MockModule;
use Test::Exception;
use Test::More;
use Nokia::Singleton;

$ENV{LFS_CI_ROOT} = "."; 
Nokia::Singleton::config()->loadData( configFile => "etc/global.cfg" );

my $obj;
require_ok( "Nokia::Svn" );

ok( $obj=Nokia::Svn->new(), "create an svn object" );

if( $ENV{USER} ne "lfscidev") {
    my $url = "svne1.access.nsn.com/dies/ist/ein/test";
    is( $obj->replaceMasterByUlmServer( $url ), "ulscmi.inside.nsn.com/dies/ist/ein/test", "replaceMasterByUlmServer");
    is( $obj->replaceMasterByUlmServer( "dies/ist/ein/test" ), "dies/ist/ein/test", "replaceMasterByUlmServer with no valid data");

    $url = "ulscmi.inside.nsn.com/dies/ist/ein/test";
    is( $obj->replaceUlmByMasterServer( $url ), "svne1.access.nsn.com/dies/ist/ein/test", "replaceUlmByMasterServer");
    is( $obj->replaceUlmByMasterServer( "dies/ist/ein/test" ), "dies/ist/ein/test", "replaceUlmByMasterServer with no valid data");
} else {
    my $url = "lfs-sandbox-svn.dynamic.nsn-net.net/dies/ist/ein/test";
    is( $obj->replaceMasterByUlmServer( $url ), "lfs-sandbox-svn.dynamic.nsn-net.net/dies/ist/ein/test", "replaceMasterByUlmServer");
    is( $obj->replaceUlmByMasterServer( $url ), "lfs-sandbox-svn.dynamic.nsn-net.net/dies/ist/ein/test", "replaceUlmByMasterServer");
}

done_testing();

