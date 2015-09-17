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

require_ok( "Nokia::Model::ReleaseNote" );

my $obj;

ok( $obj = Nokia::Model::ReleaseNote->new(), "create release note object" );
isa_ok( $obj, "Nokia::Model::ReleaseNote" );
isa_ok( $obj, "Nokia::Model" );
isa_ok( $obj, "Nokia::Object" );

can_ok( $obj, qw( new 
                  init 
                  releaseName 
                  commentForRevision 
                  addImportantNoteMessage 
                  mustHaveFileData
                  importantNote
                ) );

# releaseNote method
is( $obj->releaseName(), "", "got empty release name" );

ok( $obj = Nokia::Model::ReleaseNote->new( releaseName => "foobar" ), 
        "create release note object with parameter" );
is( $obj->releaseName(), "foobar", "got correct release name" );


# addImportantNoteMessage method
lives_ok { $obj->addImportantNoteMessage( "foo" ) }, 'adding in';
is( $obj->{importantNote}->[0], "foo", "adding important note was ok" );
lives_ok { $obj->addImportantNoteMessage( "bar" ) }, 'adding in';
is( $obj->{importantNote}->[1], "bar", "adding important note was ok" );

# mustHaveFileData method
# create mock first:
$ENV{WORKSPACE} = "foobar";
my $module = Test::MockModule->new('File::Slurp');
$module->mock('read_file', sub { return qw( line_1 line_2 line_3 } ) } );

# create a new empty object 
ok( $obj = Nokia::Model::ReleaseNote->new( releaseName => "foobar" ), 
        "create release note object with parameter" );

# lives_ok { $obj->mustHaveFileData( "importantNote" ) }, 'reading in';

done_testing();





