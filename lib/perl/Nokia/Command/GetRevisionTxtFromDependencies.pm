package Nokia::Command::GetRevisionTxtFromDependencies; 
## @brief this command creates a file with svn revisions and svn urls
use strict;
use warnings;

use Getopt::Std;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Singleton;
use Nokia::Usecase::GetLocation;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    getopts( "f:u:", \my %opts );
    $self->{fileName} = $opts{f} || die "no file name";
    $self->{url}      = $opts{u} || die "no svn url";

    return;
}

sub execute {
    my $self = shift;

    my $svn = Nokia::Singleton::svn();

    my $dependencies = $svn->cat(  url => $self->{url} );
    my $rev          = $svn->info( url => $self->{url} )->{entry}->{commit}->{revision};
    # NOTE: demx2fk3 2014-07-16 this will cause problems and triggeres unnessesary builds
    # my $rev          = $svn->info( url => $self->{url} )->{entry}->{revision};

    open FILE, sprintf( ">%s", $self->{fileName} ) or die "can not open temp file";
    print FILE $dependencies;
    close FILE;

    printf( "location %s %s\n", $self->{url}, $rev );

    my $loc = Nokia::Usecase::GetLocation->new( fileName => $self->{fileName} );

    foreach my $subDir ( $loc->getDirEntries() ) {
        my $dir = $loc->getLocation( subDir   => $subDir,
                                     tag      => "",
                                     revision => "", );
        $dir->getHeadRevision();
        printf( "%s %s %s\n", $subDir, $dir->{repos}, $dir->{revision});
    }

    return;
}

1;
