#!/usr/bin/env perl

package Object;
## @fn    Object
#  @brief base class of all other classes.

use strict;
use warnings;

## @fn     new( %param )
#  @brief  this class is the base of all objects
#  @detail in basic it's just the new method to avoid to write this method every time
sub new {
    my $class = shift;
    my $param = { @_ };
    my $self  = bless $param, $class;

    if( $self->can( "init" ) ) {
        $self->init();
    }
    return $self;
}

# ------------------------------------------------------------------------------------------------------------------
package Model;
## @fn     Model
#  @brief  base class for all model classes. a model contains data from some sources.

use strict;
use warnings;
use parent qw( -norequire Object );

# ------------------------------------------------------------------------------------------------------------------
package Model::Subdirectory;
## @fn    Model::Subdirectory
#  @brief this class represents a subdirectory of the build. It's a src- or a bld/bld- directory 

use strict;
use warnings;
use parent qw( -norequire Object );

use File::Basename;
use Data::Dumper;

## @fn     isSubversion()
#  @brief  checks, if the subdirectory is based / in subversion 
#  @param  <none>
#  @return 1 if subdirectory is from svn, otherwise 0
sub isSubversion {
    my $self = shift;
    return 0 if $self->{repos} =~ m|^/|;
    return 1 if $self->{repos} =~ m|^https://|;
    return 0;
}

## @fn     checkDependencies()
#  @brief  checks dependencies of a subdirectory and get the required dependencies
#  @param  <none>
#  @return <none>
sub checkDependencies {
    my $self = shift;

    my $dependencyParser = Parser::Dependencies->new( fileName => sprintf( "%s/Dependencies", $self->{directory} ) );
    $dependencyParser->parse();

    # check use
    my $locationParser = Usecase::GetLocation->new();
    foreach my $useLine ( @{ $dependencyParser->{data}->{use} } ) {

        my $childLocation = $locationParser->getLocation( subDir => $useLine->{src} );

        $childLocation->checkout();
        $childLocation->checkDependencies();

        push @{ $self->{dependencies} }, $childLocation;
    }

    # check use-readonly
    foreach my $use_readonly ( @{ $dependencyParser->{data}->{useReadonly} } ) {

        $use_readonly->cleanup() if -l $use_readonly->src();
        next                     if $use_readonly->hasSourceParameter();
        next                     if $use_readonly->existsDirectory();

        my $childLocation = $locationParser->getLocation( subDir => $use_readonly->src(), 
                                                          tag    => $use_readonly->tag() );
        $childLocation->createSymlink();
        push @{ $self->{dependencies} }, $childLocation;
    }

    foreach my $target ( @{ $dependencyParser->{data}->{target} } ) {
        $target->cleanup();
        push @{ $self->{targets} }, $target;
    }

    return;
}

## @fn     loadDependencyTree()
#  @brief  load the dependencies of a source directory
#  @param  <none>
#  @return <none>
sub loadDependencyTree {
    my $self = shift;

    my $dependencyParser;
    my $svn = Singelton::svn();

    # hack
    if( $self->{directory} eq "src-bos" and $self->{tag} eq "EMPTY" ) {
        warn "skipping src-bos with tag EMPTY";
        return;
    }

    if( -f sprintf( "%s/Dependencies", $self->{directory} ) ) {
        # Dependency file exists in the local workspace
        $dependencyParser = Parser::Dependencies->new( fileName => sprintf( "%s/Dependencies", $self->{directory} ) );
    } elsif ( $self->isSubversion() ) { 
        # load Dependency file from subversion
        $dependencyParser = Parser::Dependencies->new( 
            fileContent => $svn->cat( url      => sprintf( "%s/Dependencies", $self->{repos} ),
                                      revision => $self->{revision}                             ) );
    } elsif ( -f sprintf( "%s/Dependencies", $self->{repos} ) )  {
        # Dependency file exists on the share...
        $dependencyParser = Parser::Dependencies->new( fileName => sprintf( "%s/Dependencies", $self->{repos} ) );
    }
    else {
        return;
    }

    # parse the gotten depdendency file
    $dependencyParser->parse();

    my $locationParser = Usecase::GetLocation->new();
    foreach my $useLine ( @{ $dependencyParser->{data}->{use} } ) {
        my $childLocation = $locationParser->getLocation( subDir => $useLine->{src} );
        $childLocation->loadDependencyTree();
        push @{ $self->{dependencies} }, $childLocation;
    }

    foreach my $use_readonly ( @{ $dependencyParser->{data}->{useReadonly} } ) {
        my $src = $use_readonly->hasSourceParameter() 
            ? $use_readonly->sourceParameter() 
            : $use_readonly->{src};

        my $childLocation = $locationParser->getLocation( subDir => $src,
                                                          tag    => $use_readonly->tag() );

        if( $childLocation ) {
            $childLocation->{sourceExistsInFileSystem} = $use_readonly->hasSourceDirectory();
            $childLocation->loadDependencyTree();
            push @{ $self->{dependencies} }, $childLocation;
        }
    }

    foreach my $target ( @{ $dependencyParser->{data}->{target} } ) {
            push @{ $self->{targets} }, $target;
    }

    return;
}

## @fn     getSourceDirectoriesFromDependencies()
#  @brief  
#  @param  <none>
#  @return list of source directories
sub getSourceDirectoriesFromDependencies {
    my $self = shift;

    my @deps = ();

    foreach my $location ( @{ $self->{dependencies} } ) {
        push @deps, $location->getSourceDirectoriesFromDependencies();
        # we push ourself also on the list
        push @deps, $location->{directory};
    }

    my %tmp = map  { $_ => undef } 
              grep { /src-/ } 
              @deps;
    return sort keys %tmp;
}

sub getDependencies {
    my $self = shift;
    return @{ $self->{dependencies} || [] };
}

sub matchesPlatform {
    my $self     = shift;
    my $platform = shift;
    my @targets  = @{ $self->{targets} || [] };
    my @matches = grep { 1 }
                  map  { $_->matchesPlatform( $platform ) } 
                  @targets;
    return scalar( @matches ) > 0 ? 1 : 0;
}

sub platforms {
    my $self = shift;
    return map { $_->platforms() } @{ $self->{targets} };
}

## @fn     createSymlink
#  @brief  create a symlink for this directory from the share
#  @param  <none>
#  @return <none>
sub createSymlink {
    my $self = shift;

    return if $self->isSubversion();


    my $dirname = dirname( $self->{directory} );

    mkdir( $dirname );
    symlink( $self->{repos}, $self->{directory} );

    return;
}

## @fn     checkout
#  @brief  checkout the directory from subversion
#  @param  <none>
#  @return <none>
sub checkout {
    my $self = shift;

    return if not $self->isSubversion();

    my $basename = basename( $self->{repos} );  # src-fsmci
    my $dirname  = dirname( $self->{repos} );   # https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS/os/KERNEL_3.4_DEV/trunk/ci
    my $svnUrl;

    my $svn = Singelton::svn(); # the subversion client

    if( not -d ".svn" ) {
        $svn->checkout( url      => $self->{repos},
                        revision => $self->{revision},
                        args     => [ qw( -q --depth empty . ) ] );
    } else {

        my $svnInfo = $svn->info(); 
        # https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS/os/KERNEL_3.4_DEV/trunk/fsmr3
        $svnUrl     = $svnInfo->{entry}->{url};
    }

    if( $svnUrl eq $self->{repos} && $basename eq $self->{directory} ) {
        $svn->update( dir      => $self->{directory},
                      revision => $self->{revision} );
    } else {
        $svn->checkout( dir      => $self->{directory},
                        url      => $self->{repos},
                        revision => $self->{revision} );
    }

    # 014-03-03 demx2fk3 TODO add need branch handling here

    return;
}
# ------------------------------------------------------------------------------------------------------------------
package Svn;
## @fn    Svn
#  @brief class for subversion command line client

use strict;
use warnings;

use parent qw( -norequire Object );

use XML::Simple;
use Data::Dumper;

## @fn     init()
#  @brief  initialize the Svn Object with data
#  @param  <none>
#  @return <none>
sub init {
    my $self = shift;
    $self->{svnCli} = "svn";
    return;
}

## @fn     checkout( %param )
#  @brief  checkout a URL from subversion
#  @param  {url}       a svn url
#  @param  {vevision}  a svn revision
#  @return <none>
sub checkout {
    my $self = shift;
    $self->command( @_, action => "checkout" );
    return;
}

## @fn     cat( %param )
#  @brief  checkout a URL from subversion
#  @param  {url}       a svn url
#  @param  {vevision}  a svn revision
#  @return content of the url
sub cat {
    my $self  = shift;
    my $param = { @_ };

    my $url      = $param->{url};
    my $revision = $param->{revision};
    my $cmd = sprintf( "%s cat %s %s|",
                        $self->{svnCli},
                        $revision ? sprintf( "-r %d", $revision ) : "",
                        $url );

    if( not $self->{cached}{svnCat}{$cmd} ) {
        # print STDERR "$cmd\n";
        open SVN_CAT, $cmd || die "can not execute $cmd";
        $self->{cached}{svnCat}{$cmd} = join( "", <SVN_CAT> );
        close SVN_CAT;
    }

    return $self->{cached}{svnCat}{$cmd};
}

## @fn     info( %param )
#  @brief  runs the svn info command on a specified url (or the current directory)
#  @param  {url} a svn url (optional)
#  @return hash ref with the data from svn info. see svn info --xml for details about the struction
sub info {
    my $self  = shift;
    my $param = { @_ } ;
    my $url   = $param->{url} || "";

    open SVN_INFO, sprintf( "%s --xml info %s|", $self->{svnCli}, $url ) || die "can not open svn info: %!";
    my $xml = join( "", <SVN_INFO>);
    close SVN_INFO;
    return XMLin( $xml );
}

## @fn     command( %param )
#  @brief  generic method to run a svn command like checkout or export
#  @param  {action}    a svn command (checkout, export, ...)
#  @param  {url}       a svn url
#  @param  {revision}  a svn revision
sub command {
    my $self = shift;

    my $param = { @_ };

    my $revision = $param->{revision} || "";
    my $url      = $param->{url}      || "";
    my $action   = $param->{action}   || "";
    my $args     = join( " ", @{ $param->{args} || [] } );

    my $cmd = sprintf( "%s %s -q %s %s %s",
                        $self->{svnCli},
                        $action,
                        $revision ? sprintf( "-r%d", $revision ) : "",
                        $url,
                        $args );
    my $error = system ($cmd );
    if( $error >> 8 != 0 ) {
        exit 1;
    }

    return;
}

# ------------------------------------------------------------------------------------------------------------------
package Parser::Replacer;

## @fn     Parser::Replacer
#  @brief  replace some template
#  @detail in there are some variables in the dependencies files, which should be replaced with the real
#          values. The syntax of this variables are ${FOOBAR} or ${FOOBAR:mod1:mod2}.
use strict;
use warnings;

use parent qw( -norequire Parser );

use Data::Dumper;
use File::Basename;

# sub replace_lc       { return lc( shift ); }
# sub replace_uc       { return lc( shift ); }
# sub replace_basename { my $value = shift; $value =~ s#.*/##;     return $value; }
# sub replace_dirname  { my $value = shift; $value =~ s:/[^/]+$::; return $value; }
sub cfg  { my $value = shift; $value =~ s#.*/##; $value =~ s#[^-]*-##; $value =~ s#[^-]*-##; return $value; }
sub prd  { my $value = shift; $value =~ s#.*/##; $value =~ s#[^-]*-##; $value =~ s#-.*##;    return $value; }

## @fn     replace( %param )
#  @brief  replace the string in replace with the value in the string
#  @param  {replace} replace this string
#  @param  {value}   with the value
#  @param  {string}  in the string
#  @return replaced string
sub replace {
    my $self   = shift;
    my $param  = { @_ };
    my $replace = $param->{replace};
    my $value   = $param->{value} || "";
    my $string  = $param->{string};

    # get the modifieres and alter the value
    my $modifieres = $string;
    $modifieres =~ s/
                        .*
                        \$\{            # beginning of the string ${ TAG | BRANCH | DIR | ...  }
                        $replace  
                        (.*?)           # the optinal modifieres 
                        \}              # ending of the variable   }
                        .*
                    /$1/igx;

    if( $modifieres ne $string ) {
        foreach my $modifier ( split( ":", $modifieres ) ) {
            next if not $modifier;
            # eval "\$value = replace_$modifier( \$value ); ";
            no strict 'refs';
            $value = &$modifier( $value );
        }
    }

    # replace the final string...
    $string =~ s/
                        \$\{           # beginning of the string ${ TAG | BRANCH | DIR | ... }
                        $replace  
                        (.*?)          # the optinal modifieres 
                        \}             # ending of the variable   }
                    /$value/igx;

    return $string;
}


# ------------------------------------------------------------------------------------------------------------------
package Parser;
## @fn    parser
#  @brief parent class for the parser

use strict;
use warnings;

use parent qw( -norequire Object );

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

# ------------------------------------------------------------------------------------------------------------------
package Parser::Model;
use strict;
use warnings;
use parent qw( -norequire Object );

use Data::Dumper;
use File::Basename;

sub match {
    my $self  = shift;
    my $match = shift;
    my $regex = $self->{src};
    $regex =~ s/\*/\.\*/g;

    return $match =~ m/$regex/ ? 1 : 0  
}

sub replaceLocations {
    my $self = shift;
    my $param = { @_ };
    my @locations = @{ $param->{locations} || [] };

    foreach my $location ( 
                            map  { $_->[0]                     }
                            sort { $b->[1] cmp $a->[1]         }
                            map  { [ $_, length( $_->{src} ) ] }
                            @locations 
    ) {
        $self->{dst} =~ s/$location->{src}/$location->{dst}/ge;
    }

    my $replacer = Parser::Replacer->new();

    $self->{dst} = $replacer->replace( replace => "TAG",
                                       value   => $param->{tag},
                                       string  => $self->{dst} );

    $self->{dst} = $replacer->replace( replace => "BRANCH",
                                       value   => $param->{branch},
                                       string  => $self->{dst} );

    $self->{dst} = $replacer->replace( replace => "DIR",
                                       value   => $param->{dir},
                                       string  => $self->{dst} );

    $self->{dst} = $replacer->replace( replace => "BUILD_HOST",
                                       value   => $ENV{BUILD_HOST} || "",
                                       string  => $self->{dst} );
    
    return;
}


# ------------------------------------------------------------------------------------------------------------------
package Parser::Locations::Models::SearchTag;
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

# ------------------------------------------------------------------------------------------------------------------
package Parser::Locations::Models::SearchTrunk;
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

# ------------------------------------------------------------------------------------------------------------------
package Parser::Locations::Models::PhysicalLocations;
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

# ------------------------------------------------------------------------------------------------------------------
package Parser::Dependencies::Models::Target;
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

sub cleanup {
    my $self = shift;
    if( -l $self->{target} ) {
        unlink( $self->{target} );
    }
    return;
}

sub platforms {
    my $self   = shift;
    my $target = $self->{target};
    my @platforms;
    $target =~ s:bld/bld-\w+-(\w+):$1:;
    push @platforms, $target;
    push @platforms, $self->targetsParameter();

    return @platforms;
}

sub matchesPlatform {
    my $self     = shift;
    my $platform = shift;

    if( $self->hasTargetsParameter() ) {
        return scalar( grep { $platform eq $_ || $_ eq "all" } $self->targetsParameter() ) ? 1 : 0;
    } 
    return 1 if $self->{target} =~ m/-$platform$/;
    return 0;
}

sub hasTargetsParameter {
    my $self = shift;
    return 1 if( $self->targetsParameter() );
    return 0;
}

sub targetsParameter {
    my $self = shift;
    if( scalar( @{ $self->{params} } ) > 1 
        && $self->{params}->[1] =~ m/^-targets=(.*)/ )
    {
        return split( ",", $1 );
    }
    return;
}

# ------------------------------------------------------------------------------------------------------------------
package Parser::Dependencies::Models::UseReadonly;
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

sub hasSourceDirectory {
    my $self = shift;
    return 1 if( $self->hasSourceParameter() && -d $self->sourceParameter() );
    return 0;
}

sub sourceParameter {
    my $self = shift;

    # check for --source
    if( scalar( @{ $self->{dst} } ) > 1
        && $self->{dst}->[1] =~ m/^--source=(.*)/ 
      ) 
    { 
        return $1;
    }

    return; 
}

sub hasSourceParameter {
    my $self = shift;
    return $self->sourceParameter() ? 1 : 0;
}

sub existsDirectory {
    my $self = shift;
    if( -d $self->{src} ) {
        warn sprintf( "%s exists", $self->{src} );
        return 1;
    }

    return 0;
}

sub cleanup {
    my $self = shift;
    if( -l $self->{src} ) {
        # printf( "cleanup %s\n", $self->{src} );
        unlink( $self->{src} ) 
    }            
    return;
}

sub src { my $self = shift; return $self->{src}; }
sub tag { my $self = shift; return $self->{dst}->[0]; }

# ------------------------------------------------------------------------------------------------------------------
package Parser::Locations;
use strict;
use warnings;
use Data::Dumper;

use parent qw( -norequire Parser );

sub dir             { my $self = shift; push @{ $self->{data}->{dir} }, @_; return; }
sub local_directory {
    my $self = shift;
    push @{ $self->{data}->{physicalLocations} }, Parser::Locations::Models::PhysicalLocations->new( src => $_[0], dst => $_[1], type => "local" );
    return;
}

sub svn_repository {
    my $self = shift;
    push @{ $self->{data}->{physicalLocations} }, Parser::Locations::Models::PhysicalLocations->new( src => $_[0], dst => $_[1], type => "svn" );
    return;
}

sub search_tag      { 
    my $self = shift; 
    push @{ $self->{data}->{searchTag} }, Parser::Locations::Models::SearchTag->new( src => $_[0], dst => $_[1] );
    return;
}

sub search_trunk { 
    my $self = shift; 
    push @{ $self->{data}->{searchTrunk} }, Parser::Locations::Models::SearchTrunk->new( src => $_[0], dst => $_[1] );
    return;
}

# not supported any more
sub search_branch { 
    my $self = shift; 
    push @{ $self->{data}->{searchBranch} }, Parser::Locations::Models::SearchBranch->new( src => $_[0], dst => $_[1] ); 
    return; 
}

sub getReporitoryOrLocation {
    my $self   = shift;
    my $param  = { @_ };

    my $subDir = $param->{subDir};
    my $tag    = $param->{tag};

    # todo add support for hints here

    foreach my $model ( 
                           @{ $self->{data}->{searchBranch} },
                           $tag ? @{ $self->{data}->{searchTag} } : (), 
                           @{ $self->{data}->{searchTrunk} } 
                      ) {
        if( $model->match( $subDir ) ) {
            return $model;
        }
        
    }
    return;
}

# ------------------------------------------------------------------------------------------------------------------
package Parser::Dependencies;
use strict;
use warnings;
use parent qw( -norequire Parser );

sub target {
    my $self = shift;
    push @{ $self->{data}->{target} }, Parser::Dependencies::Models::Target->new( target => shift, params => \@_ );
    return;
}

sub use_readonly {
    my $self = shift;
    push @{ $self->{data}->{useReadonly} }, Parser::Dependencies::Models::UseReadonly->new( src => shift, dst => \@_ );
    return;
}
sub use { my $self = shift; push @{ $self->{data}->{use} }, { src => shift , dst => \@_ }; return; }

# ------------------------------------------------------------------------------------------------------------------
package Command::SortBuildsFromDependencies;
use strict;
use warnings;

use parent qw( -norequire Object );
use Data::Dumper;

sub prepare {
    my $self = shift;
    my @args = @_;

    $self->{goal}     = shift @args || die "no src dir";

    @{ $self->{sourcesDirectories} } = <src-*>;
    @{ $self->{sources} } = ();

    my $loc = Usecase::GetLocation->new();
    foreach my $subDir ( @{ $self->{sourcesDirectories} } ) {
        my $dir = $loc->getLocation( subDir   => $subDir );
        $dir->loadDependencyTree();
        push @{ $self->{sources} }, $dir;
    }

    return;
}

sub execute {
    my $self = shift;
    my $goal = $self->{goal};

    my @sources = sort { $a->{directory} cmp $b->{directory} } @{ $self->{sources} };
    my %seen;

SOURCES:
    while( scalar( @sources > 0 ) ) {
        my $source = shift @sources;
        next if not $source;

        my @deps = map { $_->{directory} } 
                   grep { $_->{sourceExistsInFileSystem} }
                   $source->getDependencies();

        foreach my $dep ( sort @deps ) {
            next if not $dep =~ /src-/;
            if( not $seen{ $dep } ) {
                push @sources, $source;
                next SOURCES;
            }
        }

        my %duplicate;
        printf "%s %s - %s\n", 
                $source->{directory}, 
                join( ",", sort $source->platforms() ),
                join( ",", sort grep { /src-/ } grep { not $duplicate{ $_ }++; } @deps );

        $seen{ $source->{directory} } ++;
    }

    return 0;
}

# ------------------------------------------------------------------------------------------------------------------
package Command::GetDependencies;
use strict;
use warnings;

use parent qw( -norequire Object );
use Data::Dumper;

sub prepare {
    my $self = shift;
    my @args = @_;

    $self->{dir}      = shift @args || die "no src dir";
    $self->{tag}      = shift @args || undef;
    $self->{revision} = shift @args || undef;

    return;
}

sub execute {
    my $self     = shift;
    my $subDir   = $self->{dir};
    my $tag      = $self->{tag};
    my $revision = $self->{revision};

    my $loc = Usecase::GetLocation->new();
    my $dir = $loc->getLocation( subDir   => $subDir,
                                 tag      => $tag,
                                 revision => $revision );
    $dir->loadDependencyTree();
    printf( "%s %s", join( " ", $dir->getSourceDirectoriesFromDependencies() ),
                     $subDir,
          );

    return;
}

# ------------------------------------------------------------------------------------------------------------------
package Usecase::GetLocation;
use strict;
use warnings;

use parent qw( -norequire Object );
use Data::Dumper;
use Storable qw( dclone );

sub init {
    my $self = shift;

    my $locations = Parser::Locations->new();
    my @tmp = glob("locations/*/Dependencies");
    $locations->{fileName} = shift @tmp;
    $locations->parse();

    $self->{locations} = $locations;

    return;
}

sub getLocation {
    my $self  = shift;
    my $param = { @_ };

    my $subDir   = $param->{subDir};
    my $tag      = $param->{tag};
    my $revision = $param->{revision};

    my $tmp = $self->{locations}->getReporitoryOrLocation( subDir => $subDir, 
                                                           tag    => $tag );
    if( $tmp ) {
        my $repos = dclone ( # create a deep clone copy of the object
                            $tmp 
                           );
 
        $repos->{subDir} = $subDir;
        $repos->replaceLocations( locations => $self->{locations}->{data}->{physicalLocations},
                                  dir       => $subDir,
                                  tag       => $tag );

        my $subDirectory = Model::Subdirectory->new( 
                                                    directory => $subDir,
                                                    tag       => $tag,
                                                    revision  => $revision, 
                                                    repos     => $repos->{dst},
                                                );
        return $subDirectory;
    }
    else {
        if( not $subDir eq "bldtools/bld-buildtools-common" ) {
            # we know the problem with bldtools/bld-buildtools-common
            warn "can not find location $subDir";
        }
    }

    return;
}

sub prepare {
    my $self  = shift;
    my $param = { @_ };

    return;
}

sub execute {
    my $self = shift;
    return;
}

# ------------------------------------------------------------------------------------------------------------------
package Singelton;
use strict;
use warnings;

my $obj = bless {}, __PACKAGE__;

sub svn {
    if( not $obj->{svn} ) {
        $obj->{svn} = Svn->new();
    }
    return $obj->{svn};
}

# ------------------------------------------------------------------------------------------------------------------
package main;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;

my $program = basename( $0 );
my $command;

if( $program eq "getDependencies" ) {
    $command = Command::GetDependencies->new();
} elsif ( $program eq "sortBuildsFromDependencies" ) {
    $command = Command::SortBuildsFromDependencies->new();
}

$command->prepare( @ARGV );
$command->execute() and die "can not execute $program";

exit 0;