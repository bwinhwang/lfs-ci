package Nokia::Command::SendReleaseNote; # {{{
use strict;
use warnings;

use lib sprintf( "%s/lib/perl5/", $ENV{LFS_CI_ROOT} || "." );

use XML::Simple;
use Data::Dumper;
use Getopt::Std;
use Log::Log4perl qw( :easy );

use Nokia::Singleton;

use parent qw( Nokia::Object );

sub prepare {
    my $self = shift;
    
    # t: := tag name
    # r: := release note template file
    getopts( "r:t:f:nT:P:", \my %opts );
    $self->{releaseNoteFile} = $opts{r} || die "no r";
    $self->{tagName}         = $opts{t} || die "no t";
    $self->{configFileName}  = $opts{f} || die "no f";
    $self->{noSvnActions}    = $opts{n};
    $self->{type}            = $opts{T} || die "no T"; # type of rel: REL or OS
    $self->{productName}     = $opts{P} || die "no P"; # type of the product: LFS, PKGPOOL, UBOOT, ...
    $self->{locationName}    = $opts{L} || die "no L"; # name of the location

    my $config = Nokia::Singleton::config();
    $config->loadData( configFileName => $self->{configFileName} );
    $config->addConfig( name  => "type",        value => $self->{type} );
    $config->addConfig( name  => "productName", value => $self->{productName} );
    $config->addConfig( name  => "location",    value => $self->{locationName} );

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
        die "no template file";
    }

    open( TEMPLATE, $self->{templateFile} ) 
        or die sprintf( "can not open template file %s", $self->{releaseNoteFile} );
    $self->{releaseNote} = join( "", <TEMPLATE> );
    close TEMPLATE;

    open( RELEASENOTE, $self->{releaseNoteFile} ) 
        or die sprintf( "can not open release note content file %s", $self->{releaseNoteFile} );
    $self->{data}{RELEASE_NOTE_CONTENT} = join( "", <RELEASENOTE> );
    close RELEASENOTE;

    $self->{data}{TAGNAME}              = $self->{tagName};
    if( not $self->{noSvnActions} ) {
        $self->{data}{DELIVERY_REPOS}       = $config->getConfig( name => "LFS_PROD_svn_delivery_release_repos_url" );
        $self->{data}{SVN_REL_REPOS_NAME}   = $config->getConfig( name => "LFS_PROD_svn_delivery_repos_name" );
        $self->{data}{SOURCE_REPOS}         = $config->getConfig( name => "LFS_PROD_svn_delivery_os_repos_url" );
        $self->{data}{SVN_EXTERNALS}        = Nokia::Singleton::svn()->propget( property => "svn:externals",
                                                                         url      => sprintf( "%s/tags/%s",
                                                                                     $self->{data}{DELIVERY_REPOS},
                                                                                     $self->{data}{TAGNAME} ) );
    }

    $self->{subject}     =~ s:__([A-Z_]*)__:  $self->{data}{$1} // $config->getConfig( name => $1 ) :eg; 
    $self->{releaseNote} =~ s:__([A-Z_]*)__:  $self->{data}{$1} // $config->getConfig( name => $1 ) :eg;  

    return;
}

sub execute {
    my $self = shift;

    # no use here, we only want to load the module, if we need the module
    require Mail::Sender;

    DEBUG Dumper( $self );
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
    DEBUG "return code from mua was $rv";

    if( ! $rv ) {
        die "error in sending release note: rc $rv";
    }

    return;
}

1;
