#!/usr/bin/perl
################################################################################
# TCP Connection Sharing Daemon
#
# Functional Description (full solution):
# - maintains a number of listening sockets, identified by a unique name/string
# - upon at least one client connected, opens TCP conn to (console) server
#   each local listening socket has a different remote console server
# - inbound  connections (from clients) are called DL connections
# - outbound connections (to servers)   are called UL connections
# - if UL connection can not be established or breaks, kill all DL connections
# - once no DL connections exist for any UL connection, kill UL connection
# - data forwarding rules:
#   - each data chunk(byte) received from UL shall be forwarded to all DL
#   - each data chunk(byte) received from any DL shall be forwarded to UL only
# - status page: open point
# - configuration rereading: open point
#
#
# Functional Description (simplified solution):
# - one daemon instance is only for one UL connection (one listening socket)
# - getopt parameters are: id/name, Local (ip:port), Remote (ip:port), logfile
# - if UL connection breaks or can not be established, close UL+DL connections
# - if no more DL connections exist, close UL connection but continue running
# - later extension for "bigger" operation: One master daemon who only reads
#   config file and forks/kills worker daemons, each worker daemon for one UL.
#
################################################################################

################################################################################
# Declarations
################################################################################
use strict;
use warnings;
use FindBin;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Level;
use Getopt::Long;
use Time::HiRes qw(time sleep);
use IO::Select;
use IO::Socket::INET;
use Data::Dumper;

################################################################################
# Configuration / State variables
################################################################################
my $CONFIG_name    = "unknown_name";
my $CONFIG_local   = "";
my $CONFIG_remote  = "";
my $CONFIG_logfile = "/var/log/" . $FindBin::Script . ".log";

my %g_lsn2name;       #(1:1) key: listening socket (lsn), value: name
my %g_name2lsn;       #(1:1) key: name, value: listening socket (lsn)
my %g_name2ul;        #(1:1) key: name, value: UL sock
my %g_name2ulpeer;    #(1:1) key: name, value: UL host:port (configuration)
my %g_ul2name;        #(1:1) key: UL sock, value: name
my %g_ul2dl;          #(1:n) key: UL sock, value: {key: DL sock(string), value:DL sock}
my %g_dl2ul;          #(n:1) key: DL sock, value: UL sock
my $g_selector;       #instance of IO::Select

# States and contents of hashes (always think per instance/"name"):
# startup:
#     lsn socket(s) ready, g_lsn2name and g_name2lsn are alive, others "empty"
# single DL (with UL):
#     all hashes filled, g_ul2dl{$ul}->{} has a single entry
# multiple DLs:
#     all hashes filled, g_ul2dl{$ul}->{} has multiple entries
#

################################################################################
# Helper functions
################################################################################

## @fn     helper_getpeer
#  @brief  given a socket, return peer name or "UNKNOWN"
#  @param  peer socket
#  @return ip:port of peer
sub helper_getpeer {
    my $sock = shift;
    defined $sock or return "UNKNOWN";

    if( not $sock->can( "peerhost" ) ) {
        print Dumper( $sock ), "\n";
        LOGCONFESS "wtf? aborting...";
    }

    my $host = $sock->peerhost() // "UNKNOWN";
    my $port = $sock->peerport() // "";

    my $result = $host;
    $result .= ":$port" if length $port;

    return $result;
}

sub helper_mydebug {
    my ( $name, $hashref ) = @_;
    my $result = "";

    foreach my $i ( keys %{$hashref} ) {
        if( ref $hashref->{$i} eq "HASH" ) {
            foreach my $j ( keys %{ $hashref->{$i} } ) {
                $result .= join( " ", $name, $i, $j, $hashref->{$i}->{$j} ) . "\n";
            }
        }
        else {
            $result .= join( " ", $name, $i, $hashref->{$i} ) . "\n";
        }
    }

    $result =~ s/IO::Socket::INET=GLOB//gs;
    print $result;
}

################################################################################
# Event Handler functions
################################################################################

## @fn     handle_selectable
#  @brief  Handle Data from Selector socket
#  @param  list of sockets to be read from
#  @return none
sub handle_selectable {
    my @sockets = @_;

    foreach my $fh ( @sockets ) {
        if( defined $g_lsn2name{$fh} ) {

            #listening socket --> new connection
            my $name = $g_lsn2name{$fh};
            TRACE "$name: new incoming connection";
            my $new_dl = $fh->accept();
            my $peer   = helper_getpeer( $new_dl );
            my $ul;
            INFO "$name: new DL connection from $peer";

            if( defined $g_name2ul{$name} ) {

                #existing socket, just an additional DL
                $ul = $g_name2ul{$name};
            }
            else {

                #UL was not yet open
                $ul = handle_new_ul( name => $name, new_dl => $new_dl );
                if( not defined $ul ) {

                    #error in creating UL, has been handled (and error printed)
                    next;    #skip further processing (new_dl was already closed)
                }
            }

            #finally, register the new DL connection
            handle_new_dl( new_dl => $new_dl, name => $name, ul => $ul, peer => $peer );
        }
        elsif( defined $g_ul2name{$fh} ) {

            #data (or conn.close) from alive UL socket
            my $name = $g_ul2name{$fh};
            my $dl_list = $g_ul2dl{$fh} // die "internal error, missing DL list for $name";
            TRACE "$name: UL event";
            handle_data_ul( sock => $fh, name => $name, dl_list => $dl_list );
        }
        elsif( defined $g_dl2ul{$fh} ) {

            #data (or conn.close) from alive DL socket
            my $peer = helper_getpeer( $fh );
            my $ul   = $g_dl2ul{$fh} // die "internal error, missing UL entry for DL from $peer";
            my $name = $g_ul2name{$ul} // die "internal error, missing name for UL to DL from $peer";
            TRACE "$name: DL event from $peer";
            handle_data_dl( sock => $fh, name => $name, peer => $peer, ul => $ul );
        }
        else {
            my $peer = helper_getpeer( $fh );
            LOGDIE "Aborting, received event for unknown socket $fh ($peer)";
        }
    }
}

## @fn     handle_new_dl
#  @brief  Register new DL connection (already accepted)
#  @param  {new_dl} New DL socket
#  @param  {name}   Name of Instance (listening socket)
#  @param  {ul}     corresponding UL socket
#  @return none
sub handle_new_dl {
    my $param  = {@_};
    my $new_dl = $param->{new_dl} // die "internal error, missing parameter new_dl";
    my $name   = $param->{name} // die "internal error, missing parameter name";
    my $ul     = $param->{ul} // die "internal error, missing parameter ul";
    my $peer   = $param->{peer} // die "internal error, missing parameter peer";

    #INFO "$name: new DL connection from $peer";
    $g_selector->add( $new_dl );
    $g_ul2dl{$ul}->{$new_dl} = $new_dl;
    $g_dl2ul{$new_dl} = $ul;
}

## @fn     handle_new_ul
#  @brief  Create+Register new UL connection
#  @param  {new_dl} New DL socket
#  @param  {name}   Name of Instance (listening socket)
#  @return new UL socket
sub handle_new_ul {
    my $param  = {@_};
    my $new_dl = $param->{new_dl} // die "internal error, missing parameter new_dl";
    my $name   = $param->{name} // die "internal error, missing parameter name";
    my $peer   = $g_name2ulpeer{$name} // die "internal error, missing entry in g_name2ulpeer for $name";

    INFO "$name: create new UL connection to $peer";
    my ( $host, $port ) = split /:/, $peer
      or die "internal error, bad UL peer config for $name: \"$peer\"";

    my $ul = new IO::Socket::INET(
                                   PeerHost => $host,
                                   PeerPort => $port,
                                   Proto    => 'tcp',
                                   Timeout  => 1,       #wait at most 1s for connection timeout
    );

    if( not defined $ul ) {
        ERROR "$name: UL connect failure: $!";
        TRACE $new_dl;
        handle_error( name => $name, ul => undef, dl => $new_dl );

        #effectively a full shutdown, since we have no other DL

        return undef;
    }

    $g_selector->add( $ul );
    $g_ul2name{$ul}   = $name;
    $g_name2ul{$name} = $ul;
    $g_ul2dl{$ul}     = {};      #an empty hashref

    return $ul;
}

## @fn     handle_new_lsn
#  @brief  Create+Register new Listening socket
#  @param  {local}    New spec of local  [<ip>:]<port>
#  @param  {remote}   New spec of remote <ip>:<port> (for UL)
#  @param  {name}     Name of Instance
#  @param  {selector} Instance of IO::Select to register lsn at
#  @return new lsn socket
sub handle_new_lsn {
    my $param    = {@_};
    my $local    = $param->{local} // die "internal error, missing parameter local";
    my $remote   = $param->{remote} // die "internal error, missing parameter remote";
    my $name     = $param->{name} // die "internal error, missing parameter name";
    my $selector = $param->{selector} // die "internal error, missing parameter selector";

    DEBUG "$name: Prepare new listening socket at $local";

    if( defined $g_name2lsn{$name} ) {
        my $oldremote = $g_name2ulpeer{$name} // "unknown";
        ERROR "$name: name already exists, remote at \"$oldremote\"";
        return undef;
    }

    my ( $host, $port ) =
        ( $local =~ m/^([\w\.]+):(\d+)$/ )
      ? ( $1, $2 )
      : ( "", $local );
    my $lsn = new IO::Socket::INET(
                                    LocalHost => $host,
                                    LocalPort => $port,
                                    Proto     => 'tcp',
                                    Listen    => 5,
                                    Reuse     => 1
    );

    if( not $lsn ) {
        ERROR "$name: failed to create listening socket for $local: $!";
        return undef;
    }

    $selector->add( $lsn );
    $g_lsn2name{$lsn}     = $name;
    $g_name2lsn{$name}    = $lsn;
    $g_name2ulpeer{$name} = $remote;

    INFO "$name: listening at $local";

    return $lsn;
}

## @fn     handle_data_ul
#  @brief  Handle incoming data for UL socket
#  @param  {sock}   readable UL socket
#  @param  {name}   Name of Instance (listening socket)
#  @return none
sub handle_data_ul {
    my $param   = {@_};
    my $sock    = $param->{sock} // die "internal error, missing parameter sock";
    my $name    = $param->{name} // die "internal error, missing parameter name";
    my $dl_list = $param->{dl_list} // die "internal error, missing parameter dl_list";

    #step 1: read UL data
    my $data = "";
    my $rcvd_len = sysread( $sock, $data, 1024 );

    #my $result   = $sock->recv($data, 1024);
    #my $rcvd_len = length $data;
    my $result = $!;
    TRACE "$name: received $rcvd_len bytes from UL";

    #step 2: upon error in reading, close all UL+DL sockets, return
    if( not $rcvd_len ) {
        INFO "$name: UL closed connection, closing all connections for this stream";
        DEBUG "$name: full shutdown due to UL read failure ($rcvd_len): $result";
        handle_error( name => $name, ul => $sock, dl => undef );
        return;
    }

    #step 3: forward data to DL sockets
    foreach my $dl ( values %{$dl_list} ) {
        my $peer     = helper_getpeer( $dl );
        my $sent_len = $dl->send( $data );
        $sent_len //= 0;    #0 instead of undef
        next if $sent_len;
        my $errmsg = $!;

        #error occurred: close this DL socket, remove it from hashes
        ERROR "$name: DL send failure to $peer, closing this connection";
        DEBUG "$name: partial shutdown due to DL send failure (sent $sent_len/$rcvd_len) for $peer: $errmsg";
        handle_error( name => $name, ul => $sock, dl => $dl );
    }
}

## @fn     handle_data_dl
#  @brief  Handle incoming data for DL socket
#  @param  {sock}   readable DL socket
#  @param  {ul}     related UL socket
#  @param  {name}   Name of Instance (listening socket)
#  @param  {peer}   ip:port of peer
#  @return none
sub handle_data_dl {
    my $param = {@_};
    my $sock  = $param->{sock} // die "internal error, missing parameter sock";
    my $name  = $param->{name} // die "internal error, missing parameter name";
    my $ul    = $param->{ul} // die "internal error, missing parameter ul";
    my $peer  = $param->{peer} // die "internal error, missing parameter peer";

    #step 1: read DL data
    my $data = "";
    my $rcvd_len = sysread( $sock, $data, 1024 );

    #my $result   = $sock->recv($data, 1024);
    #my $rcvd_len = length $data;
    my $result = $!;
    TRACE "$name: received $rcvd_len bytes from DL";

    #step 2: upon error in reading, close this DL socket, return
    if( not $rcvd_len ) {

        #probably OK, due to connection closed
        INFO "$name: DL connection closed from $peer";
        DEBUG "$name: partial shutdown due to DL read failure ($peer, $rcvd_len): $result";
        handle_error( name => $name, ul => $ul, dl => $sock );
        return;
    }

    #step 3: forward data to UL socket
    my $sent_len = $ul->send( $data );
    $sent_len //= 0;    #0 for undef
    if( ( $sent_len == 0 ) or ( $sent_len != $rcvd_len ) ) {
        my $errmsg = $!;

        #error occurred: close all DL+UL sockets, remove it from hashes
        ERROR "$name: UL send failure, closing all connections for this stream";
        DEBUG "$name: full shutdown due to UL send failure (sent $sent_len/$rcvd_len): $errmsg";
        handle_error( name => $name, ul => $ul, dl => undef );
    }
}

## @fn     handle_error
#  @brief  handle RX or TX error for DL or UL, closing channels as needed
#  @param  {name}   Name of Instance (listening socket)
#  @param  {ul}     UL socket in error (optional)
#  @param  {dl}     DL socket in error (optional)
#  @return none
#  If UL and DL are given, close only this DL connection.
#  If UL is given, but DL not, then close all related DL connections
#  If DL is given, but UL not, then no UL connection exists (setup failure)
#  If UL is given, and no DL connection remains after completion, also close UL
sub handle_error {
    my $param = {@_};
    my $name  = $param->{name} // die "internal error, missing parameter name";
    my $ul    = $param->{ul};                                                     #may be undef
    my $dl    = $param->{dl};                                                     #may be undef

    TRACE $g_selector->count();

    #Step 1: Close DL connection(s)
    if( defined $dl )                                                             #close a single DL
    {
        my $peer = helper_getpeer( $dl );
        DEBUG "$name: handle_error for DL $peer";
        delete $g_dl2ul{$dl};
        delete $g_ul2dl{$ul}->{$dl} if defined $ul;
        $g_selector->remove( $dl );
        $dl->close();
    }
    elsif( defined $ul )                                                          #UL but not DL --> close all DL now, later close UL
    {
        my @list_dl = values %{ $g_ul2dl{$ul} };
        DEBUG "$name: handle_error \"UL but not DL\", keycount " . scalar( @list_dl );

        foreach $dl ( @list_dl ) {
            my $peer = helper_getpeer( $dl );
            DEBUG "$name: handle_error UL, processing DL $peer";
            delete $g_dl2ul{$dl};
            delete $g_ul2dl{$ul}->{$dl};
            $g_selector->remove( $dl );
            $dl->close();
        }
    }

    TRACE $g_selector->count();

    #Step 2: Close UL connection, if it has no more DL
    if( defined $ul and ( 0 == scalar( values %{ $g_ul2dl{$ul} } ) ) ) {
        DEBUG "$name: handle_error closing orphaned UL";
        delete $g_name2ul{$name};
        delete $g_ul2name{$ul};
        delete $g_ul2dl{$ul};
        $g_selector->remove( $ul );
        $ul->close();
    }
    TRACE $g_selector->count();
}

## @fn     init_log4perl
#  @brief  Log4Perl initialization
#  @param  {logfile} Name of Logfile
#  @return none
sub init_log4perl {
    my $param = {@_};
    my $logfile = $param->{logfile} // die "internal error, missing parameter logfile";

    my $l4p_config = qq(
        log4perl.category                   = TRACE, SCREEN, LOGFILE

        log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
        log4perl.appender.SCREEN.stderr    = 0
        log4perl.appender.SCREEN.Threshold = INFO
        log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.SCREEN.layout.ConversionPattern = %d{HH:mm:ss.SSS} %-6p %m{chomp}%n
    
        log4perl.appender.LOGFILE           = Log::Log4perl::Appender::File
        log4perl.appender.LOGFILE.filename  = $logfile
        log4perl.appender.LOGFILE.layout    = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.LOGFILE.Threshold = TRACE
        log4perl.appender.LOGFILE.layout.ConversionPattern = %H %-5P %d{ISO8601} [%9r %5R] %-6p [%M %L] %m{chomp}%n
    );

    Log::Log4perl::init( \$l4p_config );
    $Log::Log4perl::Logger::INITIALIZED
      or die "ERROR: Log::Log4perl init failed\n";
}

## @fn     usage
#  @brief  print usage information and exit
#  @param  optional error message
#  @return none
sub usage {
    my $info = join( "\n", @_ );

    length $info and print STDERR "$info\n\n";

    print STDERR <<END_OF_USAGE;
Usage: $FindBin::Script [<options>]
    --name    <InstanceName> Name of this Instance
    --logfile <filename>     Where to log information
    --local   [<ip>:]<port>  for listening socket
    --remote  <ip>:<port>    for target socket, e.g. at wiznet module
    --help                   this information

END_OF_USAGE
    exit 1;
}

## @fn     init_config
#  @brief  handle Configuration by GetOpt
#  @param  none
#  @return none
sub init_config {

    #getopt handling
    my $flag_help = 0;
    GetOptions(
                'logfile=s' => \$CONFIG_logfile,
                'local=s'   => \$CONFIG_local,
                'remote=s'  => \$CONFIG_remote,
                'name=s'    => \$CONFIG_name,
                'help|h|?'  => \$flag_help,
    ) or usage "unknown/bad argument";
    $flag_help and usage;

    #verify configured options
    length $CONFIG_local
      or length $CONFIG_remote
      or usage;    #no parameters at all --> skip further checks

    $CONFIG_local =~ m/^(\d+|[\w\.]+:\d+)$/
      or usage "bad argument --local=$CONFIG_local";
    $CONFIG_remote =~ m/^[\w\.]+:\d+$/
      or usage "bad argument --remote=$CONFIG_remote";
    length $CONFIG_logfile
      or usage "missing argument --logfile=<filename>";
    length $CONFIG_name
      or usage "missing argument --name=<Instance_Name>";
    return;
}

## @fn     main()
#  @brief  core code, to be replaced when implementing "bigger" solution
#  @param  none
#  @return none
sub main {
    init_config();

    init_log4perl( logfile => $CONFIG_logfile, );

    $g_selector = IO::Select->new()
      or LOGDIE "IO::Select $!";

    handle_new_lsn(
                    local    => $CONFIG_local,
                    remote   => $CONFIG_remote,
                    name     => $CONFIG_name,
                    selector => $g_selector,
    );

    while( my @sockets = $g_selector->can_read() ) {
        TRACE "can_read: " . scalar( @sockets ) . "/" . $g_selector->count();
        handle_selectable( @sockets );
        TRACE "after handle_selectable: " . $g_selector->count();
    }

    LOGDIE "we should never reach here, Aborting";
}
main;

#TODO plan+implement complex solution (multiple lsn, runtime re-read of config file)
