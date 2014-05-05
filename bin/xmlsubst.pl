#!/usr/bin/perl

######################################################################
## xmlsubst.pl <args>
##
## change XML attributes in an existing XML file, retaining
## syntactical format as far as possible.
##
## converts stdin to stdout. changes are performed according to
## command line arguments, each of which must have the format
##
##   <attributePath>:=fix(<text>)
##   (will change attributes to a fixed <text>)
##
## or
##
##   <attributePath>:=re(<search>,<replace>)
##   (will apply the standard "m" search/replace Perl operator on
##   the input attribute value; use '\,' for literal commas in the
##   arguments)
##   mutiple such arguments can be specied and will be applied in
##   the given order
##
## or
##
##   <sectionPath>:=condre(<condChildName>,<condChildValue>,<changeChildName>,
##                         <search>,<replace>)
##   Checks the XML section in <sectionPath> for <condChildName>
##   childs which have a value of <condChildValue>. If existing, then
##   the search/replace pattern will be applied to the value of the
##   'sister' child <changeChildName>.
##
## or
##
##   <sectionPath>:=delete()
##
##   Delete the corresponding section.
##
## or
##
##   <attributePath[#attribute]>:=print(<prefix>)
##   (will print the selected attribute's value (prefixed by
##   <prefix>); this will disable the normal 'filter' behaviour, and
##   output is no longer in XML format!  It does not make sense to mix
##   this with the fix() and re() commands.
##
## or
##
##   <sectionPath>:=condprint(<condChildName>,<condChildValue>,<printChildName>,<prefix>)
##   Checks the XML section in <sectionPath> for <condChildName>
##   childs which have a value of <condChildValue>. If existing, then
##   the valueof the <printChildName> attribute will be printed, prefixed by <prefix>.
##
## Example:
##   xmlsubst.pl 'foo/bar/attribute:=fix(mytext)' \
##               'foo/test/anotherone:=re(prefix\S*,newprefix)'
##   xmlsubst.pl 'foo/test/anotherone:=print()'
##
##
## demxxqg1 / 2010-Oct-25
##
######################################################################

use strict;
use XML::Twig;

# function generator for fixed text replacements
sub mkFixedSub {
    my $newText = shift;

    return sub {
        my ( $t, $section ) = @_;

        $section->set_text( $newText );
        $section->print;
      }
}

# function generator for conditional regexp replacements
my $sectionHandlers;

sub mkCondRegexSub {
    my ( $sectionPath, $condChildName, $condChildValue, $changeChildName, $search, $replace ) = @_;

    use Data::Dumper;

    my $rule = {
                 condChildName   => $condChildName,
                 condChildValue  => $condChildValue,
                 changeChildName => $changeChildName,
                 search          => $search,
                 replace         => $replace,
    };

    if( !defined( $sectionHandlers->{$sectionPath} ) ) {
        $sectionHandlers->{$sectionPath}->{rules} = [$rule];
        $sectionHandlers->{$sectionPath}->{func}  = sub {
            my ( $t, $section ) = @_;

            # check all rules for this section:
            foreach my $rule ( @{ $sectionHandlers->{$sectionPath}->{rules} } ) {

                # does child for this rule exist?
                if( my $condChild = $section->first_child( $rule->{condChildName} ) ) {

                    # has it the proper value?
                    if( $condChild->text() eq $rule->{condChildValue} ) {

                        # does the change child exist?
                        if( my $changeChild = $section->first_child( $rule->{changeChildName} ) ) {

                            # yes. search and replace!
                            my $currentValue = $changeChild->text();
                            $currentValue =~ s/$rule->{search}/$rule->{replace}/g;
                            $changeChild->set_text( $currentValue );
                        }
                    }
                }
            }
            $section->print;
          }
    }
    else {
        push @{ $sectionHandlers->{$sectionPath}->{rules} }, $rule;
    }
    return $sectionHandlers->{$sectionPath}->{func};
}

# function generator for section deletion
sub mkDeleteSub {
    return sub { $_->delete(); };
}

# function generator for regexp replacements
sub mkRegexSub {
    my ( $search, $replace, $oldsub ) = @_;

    return sub {
        my ( $t, $section ) = @_;

        my $text;
        if( !defined( $section ) ) {

            # special handling for single argument: we've been called by
            # another 'regexSub', and we're supposed to just apply the
            # regex to the text that is provided directly:
            $text = $t;
        }
        else {

            # get text
            $text = $section->text();
        }

        # was there any prior sub? if so, apply its regexp
        if( defined( $oldsub ) ) {
            $text = $oldsub->( $text, undef );
        }

        # apply our "own" regexp
        $text =~ s/$search/$replace/g;

        if( defined( $section ) ) {

            # normal handling: replace xml value
            $section->set_text( $text );

            # ...then print
            $section->print;
        }
        else {

            # 'special handling' (see above)
            return $text;
        }
      }
}

# plain dump of tag value (with prefix)
sub mkPrintSub {
    my ( $prefix, $attribute ) = @_;

    return sub {
        my ( $t, $section ) = @_;

        if( defined( $attribute ) ) {
            print $prefix . $section->att( $attribute ) . "\n";
        }
        else {
            print $prefix . $section->text() . "\n";
        }
      }
}

sub mkCondPrintSub {
    my ( $sectionPath, $condChildName, $condChildValue, $printChildName, $prefix ) = @_;

    use Data::Dumper;

    my $rule = {
                 condChildName  => $condChildName,
                 condChildValue => $condChildValue,
                 printChildName => $printChildName,
                 prefix         => $prefix,
    };

    if( !defined( $sectionHandlers->{$sectionPath} ) ) {
        $sectionHandlers->{$sectionPath}->{rules} = [$rule];
        $sectionHandlers->{$sectionPath}->{func}  = sub {
            my ( $t, $section ) = @_;

            # check all rules for this section:
            foreach my $rule ( @{ $sectionHandlers->{$sectionPath}->{rules} } ) {

                # does child for this rule exist?
                if( my $condChild = $section->first_child( $rule->{condChildName} ) ) {

                    # has it the proper value?
                    if( $condChild->text() eq $rule->{condChildValue} ) {

                        # does the print child exist?
                        if( my $printChild = $section->first_child( $rule->{printChildName} ) ) {

                            # yes. print it!
                            print $rule->{prefix} . $printChild->text() . "\n";
                        }
                    }
                }
            }
          }
    }
    else {
        push @{ $sectionHandlers->{$sectionPath}->{rules} }, $rule;
    }
    return $sectionHandlers->{$sectionPath}->{func};
}

# "help"
@ARGV or die "error: need arguments -- read $0 for usage";

# read arguments and create twig roots
my $twigRoots = {};
my $printAll  = 1;

while( my $arg = shift ) {
    if( $arg =~ /^(.*?)(#(.*?))?\s*:=\s*(fix|re|condre|delete|print|condprint)\s*\((.*)\)\s*$/s ) {
        my ( $path, $attribute, $op, $arg ) = ( $1, $3, $4, $5 );
        my $sub;
        if( $op eq 'fix' ) {
            $sub = mkFixedSub( $arg );
        }
        elsif( $op eq 're' ) {
            $arg =~ /^(.*[^\\]),(.*)$/;
            $sub = mkRegexSub( $1, $2, $twigRoots->{$path} );
        }
        elsif( $op eq 'condre' ) {
            $arg =~ /^(.*),(.*),(.*),(.*),(.*)$/;
            $sub = mkCondRegexSub( $path, $1, $2, $3, $4, $5 );
        }
        elsif( $op eq 'delete' ) {
            $sub = mkDeleteSub();
        }
        elsif( $op eq 'print' ) {
            $sub = mkPrintSub( $arg, $attribute );
            $printAll = 0;
        }
        elsif( $op eq 'condprint' ) {
            $arg =~ /^(.*),(.*),(.*),(.*)$/;
            $sub = mkCondPrintSub( $path, $1, $2, $3, $4 );
            $printAll = 0;
        }
        else {
            die "internal error";
        }
        $twigRoots->{$path} = $sub;
    }
    else {
        die "illegal argument \"$arg\"";
    }
}

# create twig
my $t = XML::Twig->new(
                        keep_spaces              => 1,
                        keep_encoding            => 1,
                        twig_roots               => $twigRoots,
                        twig_print_outside_roots => $printAll,    # print the rest
);

# go
$t->parse( *STDIN );
