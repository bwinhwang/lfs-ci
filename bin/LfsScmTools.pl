#!/usr/bin/env perl
# vim:foldmethod=marker 

package Object; # {{{
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

# }}} ------------------------------------------------------------------------------------------------------------------
package Store::Config::Date; # {{{

use warnings;
use strict;
use parent qw( -norequire Object );
use Data::Dumper;

sub readConfig {
    my $self  = shift;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time() );
    $year += 1900;
    $mon  += 1;

    my $data = [];

    push @{ $data }, { name => "date_%Y", value => sprintf( "%04d", $year ), tags => "" };
    push @{ $data }, { name => "date_%y", value => sprintf( "%02d", ( $year - 2000 )), tags => "" };
    push @{ $data }, { name => "date_%m", value => sprintf( "%02d", $mon  ), tags => "" };

    return $data;
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Store::Config::File; # {{{

use warnings;
use strict;
use parent qw( -norequire Object );

sub readConfig {
    my $self  = shift;
    my $param = { @_ };
    my $file  = $self->{file};

    return if not -e $file;

    my $tagsRE  = qr/ \s*
                       < (?<tags>[^>]*) >
                       \s*
                    /x;
    my $nameRE  = qr/ \s* 
                      (?<name>[\w_]+) 
                      \s* 
                    /x;
    my $valueRE = qr/ \s* 
                      (?<value>.*)
                      \s* 
                    /x;

    my $data = [];
    open FILE, $file or die "can not open file";
    while ( my $line = <FILE> ) {
        chomp( $line );
        next if $line =~ m/^#/;
        next if $line =~ m/^\s*$/;

        if( $line =~ /^ $nameRE (?: $tagsRE | ) = $valueRE $/x ) {
            push @{ $data }, {
                                name  => $+{name}  || "",
                                value => $+{value} || "",
                                tags  => $+{tags}  || "",
                             }
        }
    }
    close FILE;

    return $data;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Store::Config::Cache; # {{{

use warnings;
use strict;
use parent qw( -norequire Object );

sub init {
    my $self = shift;
    $self->{data} = {};
    return;
}

sub readConfig {
    my $self = shift;
    my $data = [];

    foreach my $key ( keys %{ $self->{data} || {} } ) {
        push @{ $data }, {
                            name  => $key,
                            value => $self->{data}{$key} || "",
                            tags  => "",
                            }
    }
    return $data;
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Store::Config::Environment; # {{{

use warnings;
use strict;
use parent qw( -norequire Object );

sub readConfig {
    my $self = shift;
    my $data;

    foreach my $key ( keys %ENV ) {
        push @{ $data }, {
                            name  => $key,
                            value => $ENV{$key} || "",
                            tags  => "",
                            }
    }
    return $data;
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Model; # {{{
## @fn     Model
#  @brief  base class for all model classes. a model contains data from some sources.

use strict;
use warnings;
use parent qw( -norequire Object );

# }}} ------------------------------------------------------------------------------------------------------------------
package Model::Config; # {{{
use warnings;
use strict;
use parent qw( -norequire Model );

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or die "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    # strip fully-qualified portion

    if( not exists $self->{$name} ) {
        die "Can't access `$name' field in class $type";
    }

    if( @_ ) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub DESTROY {
    return;
}

sub matches {
    my $self    = shift;
    my $matches = 1;

    # printf STDERR "CHECK START - %s %s\n", $self->name(), $self->value();
    foreach my $tag ( @{ $self->{tags} } ) {
        my $value = $tag->value();
        # printf STDERR "check %s -- %s %s\n", $tag->name(), $value, $tag->operator();
        if( $tag->operator() eq "eq" 
            and $value eq $self->{handler}->getConfig( name => $tag->name() ) ) {
            # printf STDERR "matching tag %s / %s found...\n", $tag->name(), $value;
            $matches ++;
        } elsif ( $tag->operator() eq "regex" and $self->{handler}->getConfig( name => $tag->name()) =~ m/$value/ ) {
            # printf STDERR "matching tag %s / %s via regex found...\n", $tag->name(), $value;
            $matches ++;
        } else {
            # printf STDERR "NOT matching tag %s / %s found...\n", $tag->name(), $tag->value();
            return 0;
        }
    }
    $self->{matches} = $matches;

    # printf STDERR "CHECK END   - %s %s %s\n", $self->name(), $self->value(), $matches;

    return $matches;
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Model::ReleaseNote; # {{{
use warnings;
use strict;
use parent qw( -norequire Model );

use File::Slurp;

sub releaseName {
    my $self = shift;
    return $self->{releaseName};
}

sub commentForRevision {
    my $self     = shift;
    my $revision = shift;

    $self->mustHaveFileData( "revisions" );

    foreach my $line ( @{ $self->{revisions} } ) {
        next if $line =~ m/^\s*#/;
        next if $line =~ m/^\s*$/;
        if( $line =~ m/^(\d+)\s+(.*)/ ) {
            if( $1 == $revision ) {
                return $2;
            }
        }
    }
    return;
}

sub importantNote {
    my $self = shift;
    $self->mustHaveFileData( "importantNote" );
    return join( "\n", @{ $self->{importantNote} || [] } );
}

sub mustHaveFileData {
    my $self     = shift;
    my $fileType = shift;
    if( not exists $self->{ $fileType } ) {
        my $file = sprintf( "%s/releaseNotes/%s/%s.txt", $ENV{HOME}, $self->releaseName(), $fileType );
        if ( -e $file ) {
            $self->{ $fileType } = [ read_file( $file ) ];
        }
    }
    return
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Model::Subdirectory; # {{{
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

sub getHeadRevision {
    my $self = shift;
    if( $self->isSubversion() ) {
        my $svn = Singelton::svn();
        $self->{revision} = $svn->info( url => $self->{repos} )->{entry}->{commit}->{revision};
    }
    return $self->{revision};
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
    $self->{tag} =\ "";

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

    # parse the depdendency file
    $dependencyParser->parse();

    my $locationParser = Usecase::GetLocation->new();

    foreach my $hint ( @{ $dependencyParser->{data}->{hint} } ) {
            push @{ $self->{hints} }, $hint;
            Singelton::hint()->addHint( $hint->{src} => $hint->{dst}[0] );
    }

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

sub targets {
    my $self = shift;
    return @{ $self->{targets} || [] };
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
# }}} ------------------------------------------------------------------------------------------------------------------
package Svn; # {{{
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

    my $url      = replaceMasterByUlmServer( $param->{url} );
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

sub propget {
    my $self = shift;
    my $param= { @_ };
    my $url      = replaceMasterByUlmServer( $param->{url} );
    my $property = $param->{property};

    my $cmd = sprintf( "%s pg %s %s|",
                        $self->{svnCli},
                        $property,
                        $url );
    open SVN_CAT, $cmd || die "can not execute $cmd";
    my $ret = join( "", <SVN_CAT> );
    close SVN_CAT;

    return $ret;
}

## @fn     info( %param )
#  @brief  runs the svn info command on a specified url (or the current directory)
#  @param  {url} a svn url (optional)
#  @return hash ref with the data from svn info. see svn info --xml for details about the struction
sub info {
    my $self  = shift;
    my $param = { @_ } ;
    my $url   = replaceMasterByUlmServer( $param->{url} || "" );
    my $xml   = "";
    my $count = 0;

    while ( $xml eq "" || $count < 4 ) {
        open SVN_INFO, sprintf( "%s --xml info %s|", $self->{svnCli}, $url ) || die "can not open svn info: %!";
        $xml = join( "", <SVN_INFO> );
        close SVN_INFO;
        $count++;
    }
    if( $xml eq "" ) {
        die "svn info --xml failed";
    }

    return XMLin( $xml );
}

sub ls {
    my $self  = shift;
    my $param = { @_ };
    my $url   = replaceMasterByUlmServer( $param->{url} || "" );

    open SVN_LS, sprintf( "%s --xml ls %s|", $self->{svnCli}, $url ) || die "can not open svn info: %!";
    my $xml = join( "", <SVN_LS> );
    close SVN_LS;

    return XMLin( $xml, ForceArray => 1 );
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
    my $url      = replaceMasterByUlmServer( $param->{url} || "");
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

sub replaceMasterByUlmServer {
    my $url = shift;
    $url =~ s/svne1.access.nokiasiemensnetworks.com/ulscmi.inside.nsn.com/g;
    $url =~ s/svne1.access.nsn.com/ulscmi.inside.nsn.com/g;
    return $url;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Replacer; # {{{

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


# }}} ------------------------------------------------------------------------------------------------------------------
package Parser; # {{{
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

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Model; # {{{

# @brief generic class to store information from the parser

use strict;
use warnings;
use parent qw( -norequire Object );

use Data::Dumper;
use File::Basename;

## @fn      match( $string )
#  @brief   checks, if the given strings matches to the src regex
#  @param   {string}    string to match
#  @return  1 if string matches to regex, 0 otherwise
sub match {
    my $self   = shift;
    my $string = shift;
    my $regex  = $self->{src};
    $regex =~ s/\*/\.\*/g;

    return $string =~ m/$regex/ ? 1 : 0
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


# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Locations::Models::SearchTag; # {{{
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Locations::Models::SearchTrunk; # {{{
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Locations::Models::PhysicalLocations; # {{{
use strict;
use warnings;
use parent qw( -norequire Parser::Model );

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Dependencies::Models::Target; # {{{
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

sub platform {
    my $self   = shift;
    my $target = $self->{target};
    $target =~ s:bld/bld-\w+-(\w+):$1:;
    return $target;
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

    return if scalar( @{ $self->{params} } ) != 1;

    if(  $self->{params}->[0] =~ m/^--cfgs=(.*)/ ) {
        return split( ",", $1 );
    }
    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Dependencies::Models::UseReadonly; # {{{
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
    # TODO: demx2fk3 2014-06-24 fixme
    if( $self->{src} =~ m:bld/bld-([a-z0-9]*)-.*: ) {
        if( -d sprintf( "src-%s", $1 ) ) {
            return sprintf( "src-%s", $1 );
        }
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

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Locations; # {{{
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
                    $tag ? @{ $self->{data}->{searchTag}    } : (),
                           @{ $self->{data}->{searchTrunk}  }
                      ) {
        if( $model->match( $subDir ) ) {
            return $model;
        }

    }
    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Parser::Dependencies; # {{{
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

sub use {
    my $self = shift;
    push @{ $self->{data}->{use} }, { src => shift, dst => \@_ };
    return;
}

sub hint {
    my $self = shift;
    push @{ $self->{data}->{hint} }, { src => shift, dst => \@_ };
    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::SortBuildsFromDependencies; # {{{
use strict;
use warnings;

use parent qw( -norequire Object );
use Data::Dumper;

sub prepare {
    my $self = shift;
    my @args = @_;

    $self->{goal}  = shift @args || die "no src dir";
    $self->{style} = shift @args || "makefile";
    $self->{label} = shift @args;

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

        my @deps = map  { $_->{directory} }
                   # grep { $_->{sourceExistsInFileSystem} }
                   $source->getDependencies();

        foreach my $dep ( sort @deps ) {
            next if not $dep =~ /src-/;
            if( not $seen{ $dep } ) {
                push @sources, $source;
                next SOURCES;
            }
        }

        my %duplicate;

        # t: t-1 t-2
        # t-1:
        #     build -C t 1

        my @filteredDeps = sort 
                           grep { /src-/ } 
                           grep { not $duplicate{$_}++; } 
                           @deps;

        if( $self->{style} eq "makefile" ) {

            # print label information for different components
            my $label = $self->{label};
            if( grep { $_ eq $source->{directory} } qw ( src-bos src-fsmbos src-fsmbos35 src-mbrm src-fsmbrm src-fsmbrm35 ) ) {
                $label =~ s/PS_LFS_OS/LFS/g;
                $label =~ s/PS_LFS_BT/LBT/g;
                $label =~ s/_20(\d\d)_/$1/g;
                $label =~ s/_//g;
            }

            printf "%s: LABEL := %s\n\n", $source->{directory}, $label;

            if( grep { $_ eq $goal } $source->platforms() ) {
                printf ".PHONY: %s\n\n", $source->{directory};
                printf "%s: ", $source->{directory};
                foreach my $platform ( sort grep { $_ eq $goal } $source->platforms() ) {
                    printf "%s-%s ", $source->{directory}, $platform;
                }
                printf "\n";
            }

            foreach my $target ( sort $source->targets() ) {
                my $platform = $target->platform();
                foreach my $p ( $target->targetsParameter() ) {
                    if( $p ne $platform ) {
                        printf "%s-%s: %s-%s\n\n", $source->{directory}, $p, $source->{directory}, $platform;
                    }

                }
                printf "%s-%s: %s\n", $source->{directory}, $platform, join( " ", @filteredDeps );
                printf "\t/usr/bin/time -v build -L \$@.log -C %s %s --label=\$(LABEL)\n\n", $source->{directory}, $platform;
            }
        } elsif( $self->{style} eq "legacy" ) {
            printf "%s %s - %s\n",
                    $source->{directory},
                    join( ",", sort $source->platforms() ),
                    join( ",", sort 
                               grep { /src-/ } 
                               grep { not $duplicate{ $_ }++; } 
                               @filteredDeps 
                    );
        } else {
            die "style is unknown";
        }

        $seen{ $source->{directory} } ++;
    }

    return 0;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetDependencies; # {{{
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

    # use YAML;
    # print STDERR Dump($dir);

    printf( "%s %s", join( " ", $dir->getSourceDirectoriesFromDependencies() ),
                     $subDir,
          );
    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetUpStreamProject; # {{{
use strict;
use warnings;

use parent qw( -norequire Object );
use XML::Simple;
use Getopt::Std;
use Data::Dumper;

sub readBuildXml {
    my $self  = shift;
    my $param = { @_ };
    my $file  = $param->{file};

#         <hudson.model.Cause_-UpstreamCause>
#           <upstreamProject>LFS_CI_-_trunk_-_Package_-_package</upstreamProject>
#           <upstreamUrl>job/LFS_CI_-_trunk_-_Package_-_package/</upstreamUrl>
#           <upstreamBuild>159</upstreamBuild>
#           <upstreamCauses>
#             <hudson.model.Cause_-UpstreamCause>
#               <upstreamProject>LFS_CI_-_trunk_-_Build</upstreamProject>
#               <upstreamUrl>job/LFS_CI_-_trunk_-_Build/</upstreamUrl>
#               <upstreamBuild>473</upstreamBuild>
#               <upstreamCauses>
#                 <hudson.triggers.SCMTrigger_-SCMTriggerCause/>
#               </upstreamCauses>
#             </hudson.model.Cause_-UpstreamCause>
#           </upstreamCauses>
#         </hudson.model.Cause_-UpstreamCause>
#       </causes>

#   <hudson.model.CauseAction>
#       <causes>
#         <hudson.model.Cause_-UpstreamCause>
#           <upstreamProject>LFS_CI_-_trunk_-_Test</upstreamProject>
#           <upstreamUrl>job/LFS_CI_-_trunk_-_Test/</upstreamUrl>
#           <upstreamBuild>858</upstreamBuild>
#           <upstreamCauses>
#             <hudson.model.Cause_-UpstreamCause>
#               <upstreamProject>LFS_CI_-_trunk_-_Package_-_package</upstreamProject>
#               <upstreamUrl>job/LFS_CI_-_trunk_-_Package_-_package/</upstreamUrl>
#               <upstreamBuild>1070</upstreamBuild>
#               <upstreamCauses>
#                 <hudson.model.Cause_-UpstreamCause>
#                   <upstreamProject>LFS_CI_-_trunk_-_Build</upstreamProject>
#                   <upstreamUrl>job/LFS_CI_-_trunk_-_Build/</upstreamUrl>
#                   <upstreamBuild>1881</upstreamBuild>
#                   <upstreamCauses>
#                     <hudson.triggers.SCMTrigger_-SCMTriggerCause/>
#                   </upstreamCauses>
#                 </hudson.model.Cause_-UpstreamCause>
#                 <hudson.model.Cause_-UpstreamCause>
#                   <upstreamProject>LFS_CI_-_trunk_-_Build</upstreamProject>
#                   <upstreamUrl>job/LFS_CI_-_trunk_-_Build/</upstreamUrl>
#                   <upstreamBuild>1882</upstreamBuild>
#                   <upstreamCauses>
#                     <hudson.triggers.SCMTrigger_-SCMTriggerCause/>
#                   </upstreamCauses>
#                 </hudson.model.Cause_-UpstreamCause>
#               </upstreamCauses>
#             </hudson.model.Cause_-UpstreamCause>
#           </upstreamCauses>
#         </hudson.model.Cause_-UpstreamCause>
#       </causes>
#     </hudson.model.CauseAction>


    my @results;
    my $xml = XMLin( $file, ForceArray => 1 );
    my $upstream = $xml->{actions}->[0]->{'hudson.model.CauseAction'}->[0]->{causes}->[0]->{'hudson.model.Cause_-UpstreamCause'};

    # print STDERR Dumper( $xml->{actions}->[0]->{'hudson.model.CauseAction'}->[0] );
    foreach my $up ( @{ $upstream } ) {
        push @results, _getUpstream( $up );

    }

    return @results;
}

sub _getUpstream {
    my $upstream = shift;
    my @result;

    if( exists $upstream->{upstreamCauses} and
        ref $upstream->{upstreamCauses} eq "ARRAY" ) {
        my @array = @{ $upstream->{upstreamCauses}->[0]->{'hudson.model.Cause_-UpstreamCause'} || [] };
        foreach my $up ( @array ) {
            push @result, _getUpstream( $up );
        }
    }
    push @result, sprintf( "%s:%s", $upstream->{upstreamProject}->[0], $upstream->{upstreamBuild}->[0], );

    return @result;
}

sub prepare {
    my $self = shift;
    my @args = @_;

    getopts( "j:b:h:", \my %opts );
    $self->{jobName} = $opts{j} || die "no job name";
    $self->{build}   = $opts{b} || die "no build number";
    $self->{home}    = $opts{h} || die "no home";

    return;
}

sub execute {
    my $self = shift;

    my $file = sprintf( "%s/jobs/%s/builds/%s/build.xml",
                        $self->{home},
                        $self->{jobName},
                        $self->{build},
                      );

    my @results = $self->readBuildXml( file => $file );

    foreach my $line ( @results ) {
        printf( "%s\n", $line );
    }

    return;
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetDownStreamProjects; # {{{
use strict;
use warnings;

use parent qw( -norequire Object );
use XML::Simple;
use Getopt::Std;

sub readBuildXml {
    my $self  = shift;
    my $param = { @_ };
    my $file  = $param->{file};

    my $xml  = XMLin( $file, ForceArray => 1 );
    my @builds = @{ $xml->{actions}->[0]->{'hudson.plugins.parameterizedtrigger.BuildInfoExporterAction'}->[0]->{builds}->[0]->{'hudson.plugins.parameterizedtrigger.BuildInfoExporterAction_-BuildReference'} || [] };

    my @results;

    foreach my $build ( @builds ) {

        my $newFile = sprintf( "%s/jobs/%s/builds/%s/build.xml",
                                $self->{home},
                                $build->{projectName}->[0],
                                $build->{buildNumber}->[0] );

        push @results, sprintf( "%s:%s:%s", $build->{buildNumber}->[0],
                                            $build->{buildResult}->[0],
                                            $build->{projectName}->[0] );
        if ( -f $newFile ) {
            push @results, $self->readBuildXml( file => $newFile );
        }
    }

    return @results;
}

sub prepare {
    my $self = shift;
    my @args = @_;

    getopts( "j:b:h:", \my %opts );
    $self->{jobName} = $opts{j} || die "no job name";
    $self->{build}   = $opts{b} || die "no build number";
    $self->{home}    = $opts{h} || die "no home";

    return;
}

sub execute {
    my $self = shift;

    my $file = sprintf( "%s/jobs/%s/builds/%s/build.xml",
                        $self->{home},
                        $self->{jobName},
                        $self->{build},
                      );

    my @results = $self->readBuildXml( file => $file );

    foreach my $line ( @results ) {
        printf( "%s\n", $line );
    }

    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetRevisionTxtFromDependencies; # {{{
## @brief this command creates a file with svn revisions and svn urls
use strict;
use warnings;

use parent qw( -norequire Object );
use Getopt::Std;
use Data::Dumper;

sub prepare {
    my $self = shift;
    getopts( "f:u:", \my %opts );
    $self->{fileName} = $opts{f} || die "no file name";
    $self->{url}      = $opts{u} || die "no svn url";

    return;
}

sub execute {
    my $self = shift;

    my $svn = Singelton::svn();

    my $dependencies = $svn->cat(  url => $self->{url} );
    my $rev          = $svn->info( url => $self->{url} )->{entry}->{commit}->{revision};
    # NOTE: demx2fk3 2014-07-16 this will cause problems and triggeres unnessesary builds
    # my $rev          = $svn->info( url => $self->{url} )->{entry}->{revision};

    open FILE, sprintf( ">%s", $self->{fileName} ) or die "can not open temp file";
    print FILE $dependencies;
    close FILE;

    printf( "location %s %s\n", $self->{url}, $rev );

    my $loc = Usecase::GetLocation->new( fileName => $self->{fileName} );

    foreach my $subDir ( $loc->getDirEntries() ) {
        my $dir = $loc->getLocation( subDir   => $subDir,
                                     tag      => "",
                                     revision => "", );
        $dir->getHeadRevision();
        printf( "%s %s %s\n", $subDir, $dir->{repos}, $dir->{revision});

    }

    return;
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetReleaseNoteContent; # {{{
## @brief generate release note content
use strict;
use warnings;

use parent qw( -norequire Object );

use XML::Simple;
use Data::Dumper;
use Getopt::Std;

sub prepare {
    my $self = shift;

    getopts( "t:", \my %opts );
    $self->{tagName} = $opts{t} || die "no t";

    my $xml  = XMLin( "changelog.xml", ForceArray => 1 ) or die "can not open changelog.xml";

    $self->{releaseNote} = Model::ReleaseNote->new( releaseName => $self->{tagName} );

    my $subsysHash;
    foreach my $entry ( @{ $xml->{logentry} } ) {

        my $overrideMessage= $self->{releaseNote}->commentForRevision( $entry->{revision} );

        my $msg = $overrideMessage 
                    ?  $overrideMessage
                    :  ref( $entry->{msg}->[0] ) eq "HASH" 
                        ? sprintf( "empty commit message (r%s) from %s at %s", $entry->{revision}, $entry->{author}->[0], $entry->{date}->[0] ) 
                        : $entry->{msg}->[0] ;

        
        if( $msg =~ m/set Dependencies, Revisions for Release/i or
            $msg =~ m/set Dependencies for Release/i or
            $msg =~ m/new Version files for Release/i or
            $msg =~ m/empty commit message/i or
            $msg =~ m/INTERNAL COMMENT/ )
        {
            # skip this type of comments.
            next;
        }
        my @newMessage;
        foreach my $line ( split( /[\n\r]+/, $msg ) ) {

            # cleanup the message a little bit
            $line =~ s/[\%\#]FIN  *[\%\#](\w+)=(\S+)\s*(.*)/$1 $2 $3 (completed)/g;
            $line =~ s/[\%\#]TBC  *[\%\#](\w+)=(\S+)\s*(.*)/$1 $2 $3 (to be continued)/g;
            $line =~ s/[\%\#]TPC  *[\%\#](\w+)=(\S+)\s*(.*)/$1 $2 $3 (work in progress)/g;
            $line =~ s/[\%\#]REM /Remark: /g;
            $line =~ s/[\%[#]RB=\d+//g;
            $line =~ s/\s*commit [0-9a-f]+\s*//g;
            $line =~ s/\s*Author: .*[@].+//g;
            $line =~ s/\s*Date: .* [0-9]+:[0-9]+:[0-9]+ .*//g;
            $line =~ s/\n/\\n/g;
            $line =~ s/\s+/ /g;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            $line =~ s/\(ros\)/ /;
            $line =~ s/\s*NOJCHK\s*//;
            $line =~ s/\bDESCRIPTION:\s*/ /;
            $line =~ s/\bREADINESS\s*:\s*COMPLETED\s*/ /;
            $line =~ s/^BTSPS-\d+\s+IN[^:]+:\s*//;
            $line =~ s/^BTSPS-\d+\s+IN\s*//;
            $line =~ s/  */ /g;
            $line =~ s/^fk\s*:\s*//;
            $line =~ s/\\n/\n/g;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            next if $line =~ m/^\s*$/;

            push @newMessage, $line;
        }

        $msg = join( "\n", @newMessage );

        my @pathes = map { $_->{content} }
                    @{ $entry->{paths}->[0]->{path} };

        foreach my $p ( @pathes ) {
            $p =~ s:.*/(src-.*?)/.*:$1:;
            $subsysHash->{ $p }->{ $msg } = undef;
        }
    }

    # map the comments to the component names
    my $changeLogAsTextHash;
    my $duplicates;
    foreach my $key ( keys %{ $subsysHash } ) {
        # my @components = split( "/", $key );
        my $componentName = $key; # $components[1];
        
        push @{ $changeLogAsTextHash->{ $componentName } }, grep { $_ }
                                                            grep { not $duplicates->{ $componentName }{$_}++ }
                                                            map  { $self->filterComments( $_ ); } 
                                                            keys %{ $subsysHash->{$key} };
    }

    $self->{changeLog} = $changeLogAsTextHash;
    return;
}

sub execute {
    my $self = shift;

    my $importantNote = $self->{releaseNote}->importantNote();
    if( $importantNote ) {
        printf "--- Important Note ---\n\n";
        printf "%s\n", $importantNote;
        printf "--- Important Note ---\n\n";
    }

    foreach my $component ( keys %{ $self->{changeLog} } ) {
        my @list = $self->{changeLog}->{$component};
        @list = map { @{ $_ } } @list;
        
        if( @list ) {
            print "\n";
            printf "=== %s ===\n", $self->mapComponentName( $component );
            print         "   * ";
            print join( "\n   * ", map { s/\n/\n     /g; $_ } @list );
            print "\n";
        }
    }

    return;
}

sub mapComponentName {
    my $self = shift;
    my $name = shift;

    # TODO: demx2fk3 2014-07-14 move this into a config file
    # LFS_PROD_uc_release_component_title < componentName:src:bos > = Linux Kernel Config
    my $componentName = { 
                            'src-bos'            => "Linux Kernel Config",
                            'src-cvmxsources'    => "CVMX Sources",
                            'src-cvmxsources3'   => "CVMX Sources 3.x",
                            'src-ddal'           => "FSMr2 DDAL",
                            'src-ddg'            => "Kernel Drivers",
                            'src-ifddg'          => "Intreface Kernel Drivers",
                            'src-firmware'       => "Firmware",
                            'src-fsmbos'         => "Linux Kernel Config",
                            'src-fsmbrm'         => "FSMr3 U-Boot",
                            'src-fsmbrm35'       => "FSMr4 U-Boot",
                            'src-fsmddal'        => "DDAL Library",
                            'src-fsmddg'         => "Kernel Drivers",
                            'src-fsmdtg'         => "Transport Drivers",
                            'src-fsmfirmware'    => "Firmware",
                            'src-fsmfmon'        => "FMON",
                            'src-fsmifdd'        => "DDAL Library API",
                            'src-fsmpsl'         => "Software Load",
                            'src-fsmrfs'         => "Root Filesystem",
                            'src-ifddal'         => "FSMr2 DDAL Library API",
                            'src-kernelsources'  => "Linux Kernel",
                            'src-kernelsources3' => "Linux Kernel 3.x",
                            'src-lrcbrm'         => "LRC U-Boot",
                            'src-lrcddal'        => "LRC specific DDAL",
                            'src-lrcddg'         => "LRC Kernel Drivers",
                            'src-lrcifddg'       => "LRC Kernel Drivers Interface",
                            'src-lrcpsl'         => "LRC Software Load",
                            'src-mddg'           => "FSMr2 Kernel Drivers",
                            'src-mrfs'           => "FSMr2 Root Filesystem",
                            'src-psl'            => "FSMr2 Software Load",
                            'src-rfs'            => "Common Root Filesystem",
                            'src-test'           => "Testing",
                            'src-tools'          => "Tools (LRC)",
    };

    return $componentName->{$name} ? $componentName->{$name} : $name;
}

sub filterComments {
    my $self        = shift;
    my $commentLine = shift;

    # remove new lines at the end
    $commentLine =~ s/\n$//g;

    return if $commentLine =~ m/BTSPS-1657 IN psulm: DESCRIPTION: set Dependencies, Revisions for Release .* r\d+ NOJCHK/;

    return $commentLine;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetReleaseNoteXML; # {{{
## @brief generate release note content
use strict;
use warnings;

use parent qw( -norequire Object );

use XML::Simple;
use Data::Dumper;
use POSIX qw(strftime);
use Getopt::Std;

sub prepare {
    my $self = shift;
    my %duplicates;

    # t: := tag name
    # r: := release note template file
    getopts( "r:t:f:o:", \my %opts );
    $self->{tagName}         = $opts{t} || die "no t";
    $self->{basedOn}         = $opts{o} || die "no o";
    $self->{configFileName}  = $opts{f} || die "no f";

    my $config = Singelton::config();
    $config->loadData( configFileName => $self->{configFileName} );

    $self->{releaseNote} = Model::ReleaseNote->new( releaseName => $self->{tagName} );

    my $svn = Singelton::svn();

    my $xml  = XMLin( "changelog.xml", ForceArray => 1 ) or die "can not open changelog.xml";

    my $subsysHash;
    foreach my $entry ( @{ $xml->{logentry} } ) {

        my $overrideMessage= $self->{releaseNote}->commentForRevision( $entry->{revision} );

        my $msg = $overrideMessage 
                    ?  $overrideMessage
                    :  ref( $entry->{msg}->[0] ) eq "HASH" 
                        ? sprintf( "empty commit message (r%s) from %s at %s", $entry->{revision}, $entry->{author}->[0], $entry->{date}->[0] ) 
                        : $entry->{msg}->[0] ;

        # jira stuff
        if( $msg =~ m/^.*(BTS[A-Z]*-[0-9]*)\s*PR\s*([^:]*)(.*$)/  ) {
            push @{ $self->{PR} }, { jira => $1,
                                     nr   => $2,
                                     text => $3, };
        }
        # change note
        if( $msg =~ m/^.*(BTS[A-Z]-[0-9]*)\s*CN\s*([^ :]*)(.*$)/ ) {
            push @{ $self->{CN}}, { jira => $1,
                                    nr   => $2,
                                    text => $3, };
        }
        # new feature
        if( $msg =~ m/^.*(BTS[A-Z]-[0-9]*)\s*NF\s*([^ t:]*)(.*$)/ ) {
            push @{ $self->{NF}}, { jira => $1,
                                    nr   => $2,
                                    text => $3, };
        }
        # notes
        if( $msg =~ m/Transport Drivers/ ) {
            push @{ $self->{notes} }, { notes => "Change in Transport Drivers. Please update transport software also when testing this release." };
        }

        # %FIN PR=PR123456 foobar
        if( $msg =~ m/\s*[#%]FIN\s+[%@](PR|NF|CN)=(\w+)(.*)/ ) {
            push @{ $self->{ $1 } }, { nr   => $2,
                                       text => $2 . $3, };
        }
    }

    $self->{templateFileName} = $config->getConfig( name => "LFS_PROD_ReleaseNote_TemplateFileXml" );
    if( not -e $self->{templateFileName} ) {
        die sprintf( "template file %s does not exist", $self->{templateFileName} );
    }
    open TEMPLATE, $self->{templateFileName} or die "can not open template file xml";
    $self->{template} = join( "", <TEMPLATE> );
    close TEMPLATE;

    # collect data
    # __TAGNAME__
    $self->{data}{TAGNAME} = $self->{tagName};
    # __DATE__
    $self->{data}{DATE} = strftime( "%Y-%m-%d", gmtime());
    # __TIME__
    $self->{data}{TIME} = strftime( "%H:%M:%SZ", gmtime());
    # __BASED_ON__
    $self->{data}{BASED_ON} = $self->{basedOn};
    # __BRANCH__
    $self->{data}{BRANCH} = "Branch";
    # __IMPORTANT_NOTE__
    $self->{data}{IMPORTANT_NOTE} = $self->{releaseNote}->importantNote();
    # __SVN_REPOS_URL__
    $self->{data}{SVN_REPOS_URL} = $config->getConfig( name => "LFS_PROD_svn_delivery_os_repos_url" );
    # __SVN_REVISION__
    my $svnUrl = sprintf( "%s/os/tags/%s", 
                            $self->{data}{SVN_REPOS_URL},
                            $self->{data}{TAGNAME},
                        );
    $self->{data}{SVN_REVISION} = $svn->info( url => $svnUrl )->{entry}->{commit}->{revision};

    # __SVN_TAGS_URL_WITH_REVISION__
    $self->{data}{SVN_TAGS_URL_WITH_REVISION} = sprintf( "%s/tags/%s@%d",
                                                            $self->{data}{SVN_REPOS_URL},
                                                            $self->{data}{TAGNAME},
                                                            $self->{data}{SVN_REVISION},
                                                       );
    # __CORRECTED_FAULTS__
    $self->{data}{CORRECTED_FAULTS} = join( "\n        ", 
                                            map { sprintf( "<fault %sid=\"%s\">%sPR %s</fault>",
                                                            $_->{jira} ? sprintf( "info=\"jira issue number: \" ", $_->{jira} ) : "",
                                                            $_->{nr},
                                                            $_->{jira} ? sprintf( "%s: ", $_->{jira} ) : "",
                                                            $_->{text},
                                                        ) }
                                            grep { not $duplicates{ $_->{nr} } ++ }
                                            @{ $self->{PR} || [] }
                                        );
    # __FEATURES__
    $self->{data}{FEATURES} = join( "\n        ", 
                                    map { sprintf( "<feature id=\"%s\">%sNF %s</feature>",
                                                    $_->{nr},
                                                    $_->{jira} ? sprintf( "%s: ", $_->{jira} ) : "",
                                                    $_->{text},
                                                ) }
                                     grep { not $duplicates{ $_->{nr} } ++ }
                                    @{ $self->{NF} || [] }
                                  );
    # __BASELINES__
    my @baselineFiles = qw ( bld/bld-externalComponents-summary/externalComponents );
    push @baselineFiles, glob( "bld/bld-fsmpsl-*/results/doc/versions/fpga_baselines.txt" );

    foreach my $file ( @baselineFiles ) {
        open FILE, $file or die "can not open file $file";
        while( my $line = <FILE> ) {
            chomp( $line );
            if( $line =~ m/^([\w-]+).*\s*=\s*(.*)$/ ) {
                push @{ $self->{baselines} }, { baseline => uc $1,
                                                tag      => $2 };
            }
            if( $line =~ m/^((PS_LFS_FW)_.*)$/ ) {
                push @{ $self->{baselines} }, { baseline => $2,
                                                tag      => $1 };
            }
        }
    }
    foreach my $hash ( @{ $self->{baselines} } ) {
        if( $hash->{baseline} =~ m/brm35/i ) {
            $hash->{baseline} =  "PS_LFS_BT";
            # FSMR4LBT140601
            $hash->{tag}      =~ s/^(.*)LBT(\d\d)(\d\d)(\d*).*$/PS_LFS_BT_FSMR4_20${2}_${3}_${4}/;
        }
        elsif( $hash->{baseline} =~ m/brm/i ) {
            $hash->{baseline} =  "PS_LFS_BT";
            # LBT140602-ci1
            # FSMR4LBT140601
            $hash->{tag}      =~ s/^(.*)LBT(\d\d)(\d\d)(\d*).*$/PS_LFS_BT_20${2}_${3}_${4}/;
        }
        if( $hash->{baseline} eq "PKGPOOL" ) {
            $hash->{baseline} = "PS_LFS_PKG";
        }
        if( $hash->{baseline} =~ m/sdk/i ) {
            $hash->{baseline} = "PS_LFS_SDK";
        }
    }

    $self->{data}{BASELINES} = join( "\n    ", 
                                        map { sprintf( '<baseline name="%s" auto_create="true">%s</baseline>',
                                                         $_->{baseline},
                                                         $_->{tag},
                                                     ) }
                                        grep { not $duplicates{ $self->{baselines} . $_->{tag} } ++ }
                                        grep { $_->{tag} !~ m/SDK_2/ } 
                                         @{ $self->{baselines} || [] }
                                     );

    # __CHANGENOTES__
    $self->{data}{CHANGENOTES} = join( "\n        ", 
                                        map { sprintf( "<changenote id=\"CN %s\">CN %s%s</changenote>",
                                                         $_->{nr},
                                                         $_->{text},
                                                     ) }
                                         @{ $self->{CN} || [] }
                                     );

    $self->{template} =~ s/__([A-Z_]*)__/ $self->{data}{$1} || "" /ge;

    return;
}

sub execute {
    my $self = shift;
    print $self->{template};
    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::Template; # {{{
use strict;
use warnings;

use parent qw( -norequire Object );

use XML::Simple;
use Data::Dumper;

sub prepare {
    my $self = shift;
    return;
}

sub execute {
    my $self = shift;
    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::SendReleaseNote; # {{{
use strict;
use warnings;

use parent qw( -norequire Object );
use lib sprintf( "%s/lib/perl5/", $ENV{LFS_CI_ROOT} || "." );


use XML::Simple;
use Data::Dumper;
use Getopt::Std;
use Mail::Sender;

sub prepare {
    my $self = shift;
    
    # t: := tag name
    # r: := release note template file
    getopts( "r:t:f:", \my %opts );
    $self->{releaseNoteFile} = $opts{r} || die "no r";
    $self->{tagName}         = $opts{t} || die "no t";
#     $self->{oldTagName}      = $opts{o} || die "no o";
    $self->{configFileName}  = $opts{f} || die "no f";

    my $config = Singelton::config();
    $config->loadData( configFileName => $self->{configFileName} );

    $self->{fromAddress}     = $config->getConfig( name => "LFS_PROD_ReleaseNote_FromAddress" );
    $self->{fakeFromAddress} = $config->getConfig( name => "LFS_PROD_ReleaseNote_FakeFromAddress" );
    $self->{fakeToAddress}   = $config->getConfig( name => "LFS_PROD_ReleaseNote_FakeToAddress" );
    $self->{toAddress}       = $config->getConfig( name => "LFS_PROD_ReleaseNote_ToAddress" );
    $self->{subject}         = $config->getConfig( name => "LFS_PROD_ReleaseNote_Subject" );
    $self->{smtpServer}      = $config->getConfig( name => "LFS_PROD_ReleaseNote_SmtpServer" );
    $self->{templateFile}    = $config->getConfig( name => "LFS_PROD_ReleaseNote_TemplateFile" );
    $self->{reposName}       = $config->getConfig( name => "LFS_PROD_svn_delivery_release_repos_url" );


    if( not -f $self->{releaseNoteFile} ) {
        die "no release note file";
    }
    if( not -f $self->{templateFile} ) {
        die "no template  file";
    }

    open( TEMPLATE, $self->{templateFile} ) 
        or die sprintf( "can not open template file %s", $self->{releaseNoteFile} );
    $self->{releaseNote} = join( "", <TEMPLATE> );
    close TEMPLATE;

    open( RELEASENOTE, $self->{releaseNoteFile} ) 
        or die sprintf( "can not open release note content file %s", $self->{releaseNoteFile} );
    $self->{data}{RELEASE_NOTE_CONTENT} = join( "", <RELEASENOTE> );
    close RELEASENOTE;

    $self->{data}{DELIVERY_REPOS}       = $config->getConfig( name => "LFS_PROD_svn_delivery_release_repos_url" );
    $self->{data}{SOURCE_REPOS}         = $config->getConfig( name => "LFS_PROD_svn_delivery_os_repos_url" );
    $self->{data}{TAGNAME}              = $self->{tagName};
    $self->{data}{SVN_EXTERNALS}        = Singelton::svn()->propget( property => "svn:externals",
                                                                   url      => sprintf( "%s/tags/%s",
                                                                                  $self->{data}{DELIVERY_REPOS},
                                                                                  $self->{data}{TAGNAME} ) );


    $self->{subject}     =~ s:__([A-Z_]*)__:  $self->{data}{$1} // $config->getConfig( name => $1 ) :eg; 
    $self->{releaseNote} =~ s:__([A-Z_]*)__:  $self->{data}{$1} // $config->getConfig( name => $1 ) :eg;  

    return;
}

sub execute {
    my $self = shift;

    my $mua = Mail::Sender->new(
                                { smtp      => $self->{smtpServer},
                                  from      => $self->{fromAddress}, 
                                  to        => $self->{toAddress},
                                  fake_from => $self->{fakeFromAddress},
                                  fake_to   => $self->{fakeToAddress},
                                  subject   => $self->{subject},
                                  replyto   => "",
                                }
                               );

    my $rv = $mua->MailMsg( { from => $self->{fromAddress}, 
                              to   => $self->{toAddress}, 
                              msg  => $self->{releaseNote},
                            }
                          ); 
    if( ! $rv ) {
        die "error in sending release note: rc $rv";
    }

    return;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetConfig; # {{{
## @brief 
use strict;
use warnings;

use parent qw( -norequire Object );
use Getopt::Long;
use Data::Dumper;

sub prepare {
    my $self = shift;
    my $opt_f = $ENV{LFS_CI_CONFIG_FILE};
    my $opt_k = undef;
    my $opt_t = [];
    GetOptions( 'k=s',  \$opt_k,
                'f=s',  \$opt_f,
                't=s@', \$opt_t,
                );

    $self->{configFileName} = $opt_f;
    $self->{configKeyName}  = $opt_k || die "no key";


    foreach my $value ( @{ $opt_t } ) {
        if( $value =~ m/([\w_]+):(.*)/ ) {
            Singelton::configStore( "cache" )->{data}->{ $1 } = $2;
        }
    }
    return;
}

sub execute {
    my $self = shift;

    Singelton::config()->loadData( configFileName => $self->{configFileName} );
    print Singelton::config()->getConfig( name => $self->{configKeyName} );

    return;
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Command::GetNewTagName; # {{{
## @brief generate new tag
use strict;
use warnings;

use parent qw( -norequire Object );
use Getopt::Std;
use Data::Dumper;

sub prepare {
    my $self = shift;
    getopts( "r:i:o:", \my %opts );
    $self->{regex}  = $opts{r} || die "no regex";
    $self->{incr}   = $opts{i} // 1;
    $self->{oldTag} = $opts{o} || die "no old tag";

    return;
}

sub execute {
    my $self = shift;

    my $regex = $self->{regex};
    my $oldTag = $self->{oldTag};

    my $newTag         = $regex;
    my $newTagLastByte = "0001";

    if( $oldTag =~ m/^$regex$/ ) {
        $newTagLastByte = sprintf( "%04d", $1 + $self->{incr} );
    }
    $newTag =~ s/\(.*\)/$newTagLastByte/g;

    printf $newTag;
    return;
}


# }}} ------------------------------------------------------------------------------------------------------------------
package Usecase::GetLocation; # {{{
use strict;
use warnings;

use parent qw( -norequire Object );
use Data::Dumper;
use Storable qw( dclone );

sub init {
    my $self = shift;

    my $locations = Parser::Locations->new();

    if( not $self->{fileName} ) {
        my @tmp = glob("locations/*/Dependencies");
        $self->{fileName} = shift @tmp;
    }

    $locations->{fileName} = $self->{fileName};
    $locations->parse();
    $self->{locations} = $locations;

    return;
}

sub getDirEntries {
    my $self = shift;
    return @{ $self->{locations}->{data}->{dir} || []};
}

sub getLocation {
    my $self  = shift;
    my $param = { @_ };

    my $subDir   = $param->{subDir};
    my $tag      = $param->{tag};
    my $revision = $param->{revision};

    if( Singelton::hint()->hint( $subDir ) ) {
        $tag = Singelton::hint()->hint( $subDir );
    }

    # printf STDERR "LOCATION HINT %s %s -- %s\n", $subDir, $tag // "undef tag", Singelton::hint()->hint( $subDir ) // "undef";
    
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

# }}} ------------------------------------------------------------------------------------------------------------------
package Hints; # {{{
## @fn    Hints
#  @brief 
use strict;
use warnings;
use Data::Dumper;

use parent qw( -norequire Object );

sub addHint {
    my $self = shift;
    my $param = { @_ };
    foreach my $key ( keys %{ $param } ) {
        $self->{$key} = $param->{$key};
    }
    return;
}

sub hint { 
    my $self = shift;
    my $key  = shift;
    return exists $self->{$key} ? $self->{$key} : undef;
}

# }}} ------------------------------------------------------------------------------------------------------------------
package Config; # {{{

use warnings;
use strict;
use parent qw( -norequire Object );

use Data::Dumper;

sub init {
    my $self = shift;
    $self->{configObjects} = [];
    return;
}

sub getConfig {
    my $self  = shift;
    my $param = { @_ };
    my $name  = $param->{name};

    my @candidates = map  { $_->[0]               } # schwarzian transform
                     sort { $b->[1] <=> $a->[1]   } 
                     grep { $_->[1]               }
                     map  { [ $_, $_->matches() ] }
                     grep { $_->name() eq $name   }
                     @{ $self->{configObjects} };

    if( scalar( @candidates ) > 1 ) {
        # TODO: demx2fk3 2014-06-18 warning -- die "error: more than one canidate found...";
    } elsif ( scalar( @candidates ) == 0 ) {
        # we are only handling strings, no undefs!
        # print "empty $name\n";
        return "";
    } 
    my $value = $candidates[0]->value();
    $value =~ s:
                    \$\{
                        ( [^}]+ )
                      \}
                :
                        $self->getConfig( name => $1 ) || "\${$1}"
                :xgie;
    return $value;
}

sub loadData {
    my $self  = shift;
    my $param = { @_ };

    my $fileName = $param->{configFileName};

    my @dataList;
    foreach my $store ( Store::Config::File->new( file => $fileName ),
                        Store::Config::Environment->new(), 
                        Store::Config::Date->new(), 
                        Singelton::configStore( "cache" ),
                      ) {
        push @dataList, @{ $store->readConfig() };
    }


    foreach my $cfg ( @dataList ) {
        # handling tags in an extra section here
        my @tags = ();
        foreach my $tag (split( /\s*,\s*/, $cfg->{tags} ) ) {
            if( $tag =~ m/(\w+):([^:\s]+)/ ) {
                push @tags, Model::Config->new( handler  => $self,
                                                name     => $1, 
                                                value    => $2, 
                                                operator => "eq"
                                              );
            } elsif( $tag =~ m/(\w+)~([^:\s]+)/ ) {
                push @tags, Model::Config->new( handler  => $self,
                                                name     => $1, 
                                                value    => $2, 
                                                operator => "regex"
                                              );
            } elsif( $tag =~ m/^\s*$/ ) {
                # skip empty string
            } else {
                die "tag $tag does not match to syntax";
            }
        }
        
        push @{ $self->{configObjects} }, Model::Config->new(
                                                             handler => $self,
                                                             value   => $cfg->{value},
                                                             name    => $cfg->{name},
                                                             tags    => \@tags,
                                                            );
    }
    return
}
# }}} ------------------------------------------------------------------------------------------------------------------
package Singelton; # {{{
## @fn    Singelton
#  @brief class which just provide a singelton - just one instance of this class
use strict;
use warnings;

my $obj = bless {}, __PACKAGE__;

sub svn {
    if( not $obj->{svn} ) {
        $obj->{svn} = Svn->new();
    }
    return $obj->{svn};
}

sub hint {
    if( not $obj->{hint} ) {
        $obj->{hint} = Hints->new();
    }
    return $obj->{hint};
}

sub configStore {
    my $storeName = shift;
    if( not $obj->{config}{ $storeName } ) {
        if( $storeName eq "cache" ) {
            $obj->{config}{ $storeName } = Store::Config::Cache->new();
        }
    }
    return $obj->{config}{ $storeName };
}

sub config {
    if( not $obj->{config}{handler} ) {
        $obj->{config}{handler} = Config->new();
    }
    return $obj->{config}{handler};
}

# }}} ------------------------------------------------------------------------------------------------------------------
package main; # {{{
## @fn    main
#  @brief the main programm and dispatcher to the command objects.
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
} elsif ( $program eq "getUpStreamProject" ) {
    $command = Command::GetUpStreamProject->new();
} elsif ( $program eq "getDownStreamProjects" ) {
    $command = Command::GetDownStreamProjects->new();
} elsif ( $program eq "getRevisionTxtFromDependencies" ) {
    $command = Command::GetRevisionTxtFromDependencies->new();
} elsif ( $program eq "getNewTagName" ) {
    $command = Command::GetNewTagName->new();
} elsif ( $program eq "getReleaseNoteContent" ) {
    $command = Command::GetReleaseNoteContent->new();
} elsif ( $program eq "getReleaseNoteXML" ) {
    $command = Command::GetReleaseNoteXML->new();
} elsif ( $program eq "sendReleaseNote" ) {
    $command = Command::SendReleaseNote->new();
} elsif ( $program eq "getConfig" ) {
    $command = Command::GetConfig->new();
} else {
    die "command not defined";
}

$command->prepare( @ARGV );
$command->execute() and die "can not execute $program";

exit 0;
