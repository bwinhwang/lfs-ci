package Nokia::Hints; 
## @fn    Hints
#  @brief Hints is a singleton object, which contains the informations
#         about the hints entries from the dependency files.
#         this must be a singelton, because it is required in many 
#         different locations in the program.
use strict;
use warnings;

use Data::Dumper;

use Nokia::Object;

use parent qw( Nokia::Object );

## @fn      addHint( %param )
#  @brief   add a hint to the singleton object
#  @param   {keyName}    name of the baseline type e.g. bld-rfs-arm
#  @param   {valueName}  value of the baseline e.g. PS_LFS_OS_2014_01_01
#  @return  <none>
sub addHint {
    my $self = shift;
    my $param = { @_ };
    foreach my $key ( keys %{ $param } ) {
        $self->{$key} = $param->{$key};
    }
    return;
}

## @fn      hint( $key )
#  @brief   get the hint information 
#  @param   {keyName}    name of the baseline tye e.g. bld-rfs-arm
#  @return  value of the hint entry
sub hint { 
    my $self = shift;
    my $key  = shift;
    return exists $self->{$key} ? $self->{$key} : undef;
}


1;
