package Nokia::Parser::Replacer; 

## @fn     Parser::Replacer
#  @brief  replace some template
#  @detail in there are some variables in the dependencies files, which should be replaced with the real
#          values. The syntax of this variables are ${FOOBAR} or ${FOOBAR:mod1:mod2}.
use strict;
use warnings;

use Data::Dumper;
use File::Basename;

use parent qw( Nokia::Parser );

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

1;
