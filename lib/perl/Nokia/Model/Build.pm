package Nokia::Model::Build;

use strict;
use warnings;

use parent qw( Nokia::Object );

sub baselineName { my $self = shift; return $self->{baselineName}; }
sub branchName   { my $self = shift; return $self->{branchName};   }
sub revision     { my $self = shift; return $self->{revision};     }
sub comment      { my $self = shift; return $self->{comment};      }
sub jobName      { my $self = shift; return $self->{jobName};      }
sub buildNumber  { my $self = shift; return $self->{buildNumber};  }
sub productName  { my $self = shift; return $self->{productName};  }
sub taskName     { my $self = shift; return $self->{taskName};     }


1;
