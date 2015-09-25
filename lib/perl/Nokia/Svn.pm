package Nokia::Svn; 
## @fn    Svn
#  @brief class for subversion command line client
use strict;
use warnings;

use XML::Simple;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use parent qw( Nokia::Object );

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

    my $url      = $self->replaceMasterByUlmServer( $param->{url} );
    my $revision = $param->{revision};

    TRACE sprintf( "running svn cat for %s - rev %s", $url, $revision || "undef" );

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

## @fn      propget( $param )
#  @brief   get the svn properties for a svn URL
#  @param   {url}         svn url
#  @param   {property}    name of the svn property
#  @return  value of the svn property
sub propget {
    my $self = shift;
    my $param= { @_ };
    my $url      = $self->replaceMasterByUlmServer( $param->{url} );
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
    my $url   = $self->replaceMasterByUlmServer( $param->{url} || "" );
    my $xml   = "";
    my $count = 0;

    while ( $xml eq "" and $count < 8 ) {
        TRACE "running ($count) svn info --xml ${url}";
        open SVN_INFO, sprintf( "%s --xml info %s|", $self->{svnCli}, $url ) or next;
        TRACE "svn info --xml ${url} command was ok";
        $xml = join( "", <SVN_INFO> );
        TRACE "xml is $xml";
        close SVN_INFO;
        $count++;
    }
    if( $xml eq "" ) {
        die "svn info --xml failed";
    }

    my $xmlDataHash = XMLin( $xml );
    TRACE "got data from svn info " . Dumper( $xmlDataHash );

    return $xmlDataHash;
}

## @fn      ls( $param )
#  @brief   get the svn list output of a svn url as xml
#  @param   {url}    a svn url
#  @return  output of svn list command
sub ls {
    my $self  = shift;
    my $param = { @_ };
    my $url   = $self->replaceMasterByUlmServer( $param->{url} || "" );

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
    my $url      = $self->replaceMasterByUlmServer( $param->{url} || "");
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

## @fn      replaceMasterByUlmServer( $url )
#  @brief   replace the svnMasterServerUrl by the svn url of the local Ulm server
#  @param   {url}    svn url
#  @return  changed svn url
sub replaceMasterByUlmServer {
    my $self = shift;
    my $url  = shift;
    my $masterServer = Nokia::Singleton::config->getConfig( name => "svnMasterServerHostName" );
    my $slaveServer = Nokia::Singleton::config->getConfig( name => "svnSlaveServerUlmHostName" );
    $url =~ s/$masterServer/$slaveServer/g;
    return $url;
}

## @fn      replaceUlmByMasterServer( $url )
#  @brief   replace the svn url of the local Ulm server by the svnMasterServerUrl
#  @param   {url}    svn url
#  @return  changed svn url
sub replaceUlmByMasterServer {
    my $self = shift;
    my $url  = shift;
    my $masterServer = Nokia::Singleton::config->getConfig( name => "svnMasterServerHostName" );
    my $slaveServer = Nokia::Singleton::config->getConfig( name => "svnSlaveServerUlmHostName" );
    $url =~ s/$slaveServer/$masterServer/g;
    return $url;
}

1;
