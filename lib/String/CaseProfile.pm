package String::CaseProfile;

use 5.008;
use strict;
use warnings;
use Carp qw(carp);

use Exporter;
use base 'Exporter';
our @EXPORT_OK = qw(get_profile set_profile);

our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );

our $VERSION = '0.02';


my %types = (
                '1st_uc' => 1,
                'all_uc' => 2,
                'all_lc' => 3,
                'other'  => 4,
            );


sub get_profile {
    my ($string) = @_;

    my $word_re = qr{
                        (?:
                            \p{L}
                            |
                            (?<=\p{L})[-'\x92_](?=\p{L})
                            |
                            (?<=[lL])\xB7(?=[lL])
                            |
                            \d
                        )+
                    }x;
    
    my @words = $string =~ /($word_re)/g;
    my @word_types = map { _word_type($_) } @words;
    
    my %profile;
    $profile{string_type} = _string_type(@word_types);
    for (my $i = 0; $i <= $#words; $i++) {
        push @{$profile{words}}, {
                                    word => $words[$i],
                                    type => $word_types[$i],
                                 }
    }
    
    return %profile;
}


sub set_profile {
    my ($string, %ref_profile) = @_;

    my %string_profile = get_profile($string);
    my @words = map { $_->{word} } @{$string_profile{words}};
    my @word_types = map { $_->{type} } @{$string_profile{words}};
    
    my $force = $ref_profile{'force_change'};

    my %dispatch = (
                    '1st_uc' => sub {
                                        if ( $_[1] eq 'other' && !$force ) {
                                            return $_[0];
                                        } else {
                                            return ucfirst(lc($_[0]));
                                        }
                                    },
                    'all_uc' => sub {
                                        if ( $_[1] eq 'other' && !$force ) {
                                            return $_[0];
                                        } else {
                                            return uc($_[0]);
                                        }
                                    },
                    'all_lc' => sub {
                                        if ( $_[1] eq 'other' && !$force ) {
                                            return $_[0];
                                        } else {
                                            return lc($_[0]);
                                        }
                                    },
                    'other'  => sub { return $_[0] },
                   );
    
    my @transformed;
    
    # typical string types
    
    # validate string_type
    my ($legal, $ref_string_type);
    if ($ref_profile{string_type}) {
        $ref_string_type = $ref_profile{string_type};
        if ($types{$ref_string_type} && $ref_string_type ne 'other') {
            $legal = 1;
        } else {
            carp "Illegal value of string_type";
        }
    }
    
    if ($legal) {

        if ($ref_string_type eq '1st_uc') {
            $transformed[0] = $dispatch{'1st_uc'}->($words[0], $word_types[0]);
            for (my $i = 1; $i <= $#words; $i++) {
                push @transformed, $dispatch{'all_lc'}->(
                                                         $words[$i],
                                                         $word_types[$i]
                                                        );
            }
        } else {
            for (my $i = 0; $i <= $#words; $i++) {
                push @transformed, $dispatch{$ref_string_type}->(
                                                                 $words[$i],
                                                                 $word_types[$i]
                                                                );
            }
        }
        
    # custom profile
    } elsif ($ref_profile{custom}) {
        
        # validate default type
        my ($type, $default_type);
        if ($ref_profile{custom}->{default}) {
            $type = $ref_profile{custom}->{default};
            if ($types{$type} && $types{$type} ne 'other') {
                $default_type = $type;
            } else {
                carp "Illegal default value in custom profile";
            }
        }
        
        for (my $i = 0; $i <= $#word_types; $i++) {
            
            my $in_index = $ref_profile{custom}->{index}->{$i};
            my $trigger_type = $ref_profile{custom}->{$word_types[$i]};
            
            if ($in_index) {
                if ($in_index ne $word_types[$i]) {
                    push @transformed, $dispatch{$in_index}->(
                                                              $words[$i],
                                                              $word_types[$i]
                                                             );
                } else {
                    push @transformed, $words[$i];
                }
            } elsif ($trigger_type) {
                push @transformed, $dispatch{$trigger_type}->(
                                                              $words[$i],
                                                              $word_types[$i]
                                                              );

            } elsif ($default_type) { # use default type
                push @transformed, $dispatch{$default_type}->(
                                                              $words[$i],
                                                              $word_types[$i]
                                                              );
            } else {
                push @transformed, $words[$i];
            }
        }
    }
    
    # transform string
    if (@transformed) {
        for (my $i = 0; $i <= $#words; $i++) {
            $string =~ s/\b$words[$i]\b/$transformed[$i]/;
        }
    }

    return $string;
}


sub _word_type {
    my ($word) = @_;
    
    my $consonant_rx = qr{[bcdfghjklmnpqrstvwxyz]}i;
    
    if ($word =~ /^$consonant_rx$/) {
        return 'other';
    } elsif ($word =~ /^\p{Lu}(?:\p{Ll}|[-'\x92\xB7])*$/) {
        return '1st_uc';
    } elsif ($word =~ /^(?:\p{Ll}|[-'\x92\xB7])+$/) {
        return 'all_lc';
    } elsif ($word =~ /^(?:\p{Lu}|[-'\x92\xB7])+$/) {
        return 'all_uc';
    } else {
        return 'other';
    }
    
}

sub _string_type {
    my @types = @_;
    
    my $types_str = join "", map { $types{$_} } @types;
    
    # remove 'other' word types
    $types_str =~ s/4//g;
    
    if ($types_str =~ /^13*$/) {
        return '1st_uc';
    } elsif ($types_str =~ /^2+$/) {
        return 'all_uc';
    } elsif ($types_str =~ /^3+$/) {
        return 'all_lc';
    } else {
        return 'other';
    }
}


1;
__END__

=head1 NAME

String::CaseProfile - Get/Set the letter case profile of a string

=head1 VERSION

Version 0.02 - December 22, 2007

=head1 SYNOPSIS

    use String::CaseProfile qw(get_profile set_profile);
    
    # Get the profile of a string
    my $reference_string = 'Some reference string';
    my %ref_profile = get_profile($reference_string);
    
    my $string_type = $ref_profile{string_type};
    
    # Details of the third word
    my $word_type = $ref_profile{words}[2]->{type};
    my $word      = $ref_profile{words}[2]->{word};
    
    # Apply the profile to another string
    my $string = 'sample string';
    my $new_string = set_profile($string, %ref_profile);
    
    # Use custom profiles
    my %profile1 = ( string_type => 'all_uc' );
    $new_string = set_profile($string, %profile1);
    
    my %profile2 = ( string_type => 'all_lc', force_change => 1 );
    $new_string = set_profile($string, %profile2);
    
    my %profile3 = (
                    custom => {
                                default => 'all_lc',
                                all_uc  => '1st_uc',
                                index   => {
                                                3 => '1st_uc',
                                                5 => 'all_lc',
                                             },
                               }
                    );
    $new_string = set_profile($string, %profile3);



=head1 DESCRIPTION

This module provides a convenient way of handling the letter case conversion of
sentences/phrases/chunks in machine translation, case-sensitive search and replace,
and other text processing applications.

String::CaseProfile contains two functions:

B<get_profile> determines the letter case profile of a string.

B<set_profile> applies a letter case profile to a string; you can apply a
profile determined by get_profile, or you can create your own custom profile.

Both functions are Unicode-aware and support text in most European languages.
You must feed them utf8-encoded strings.

These functions use the following identifiers to classify word and string
types according to their case:

=over 4

=item * all_lc

In word context, it means that all the letters are lowercase.
In string context, it means that every word is of all_lc type.

=item * all_uc

In word context, it means that all the letters are uppercase.
In string context, it means that every word is of all_uc type.

=item * 1st_uc

In word context, it means that the first letter is uppercase,
and the other letters are lowercase.
In string context, it means that the type of the first word is 1st_uc,
and the type of the other words is all_lc.

=item * other

Undefined type (e.g. a CamelCase code identifier in word context, or a
string containing several words of type 'other').

=back


=head1 FUNCTIONS

=over 4

=item get_profile($string)

Returns a hash containing the profile details for $string. The string provided
must be encoded as B<utf8>. The hash keys are the following:

=over 4

=item * string_type

Scalar containing the string type, if it can be determined; otherwise,
its value is 'other'.

=item * words

Reference to an array containing a hash for every word in the string.
Each hash has two keys: B<word> and B<type>.

=back

=back

=over 4

=item set_profile($string, %profile)

Applies %profile to $string and returns a new string. $string must be encoded
as B<utf8>. The profile configuration parameters (hash keys) are the following:

=over 4

=item * string_type

You can specify one of the string types mentioned above (except 'other') as the
type that should be applied to the string.

=item * custom

As an alternative, you can define a custom profile as a reference to a hash in
which you can specify types for specific word (zero-based) positions, conversions
for the types mentioned above, and you can define a 'default' type for the words
for which none of the preceding rules apply. The order of evaluation is 1) index,
2) type conversion, 3) default type. For more information, see the examples below.

=item * force_change

By default, set_profile will ignore words with type 'other' when applying
the profile. You can use this boolean parameter to enable changing this
kind of words.

=back

=back

=head1 EXAMPLES

    use String::CaseProfile qw(get_profile set_profile);
    use Encode;
    
    my @strings = (
                    'Entorno de tiempo de ejecución',
                    'è un linguaggio veloce',
                    'langages dérivés du C',
                  );

    # encode strings as utf-8
    my @samples = map { decode('iso-8859-1', $_) } @strings;

    my $new_string;


    # EXAMPLE 1: Get the profile of a string
    
    my %profile = get_profile($samples[0]);

    print "$profile{string_type}\n";   # prints '1st_uc'
    my @types = $profile{string_type}; # 1st_uc all_lc all_lc all_lc all_lc
    my @words = $profile{words};       # returns an array of hashes



    # EXAMPLE 2: Get the profile of a string and apply it to another string
    
    my $ref_string1 = 'REFERENCE STRING';
    my $ref_string2 = 'Another reference string';

    $new_string = set_profile($samples[1], get_profile($ref_string1));
    # The current value of $new_string is 'È UN LINGUAGGIO VELOCE'

    $new_string = set_profile($samples[1], get_profile($ref_string2));
    # Now it's 'È un linguaggio veloce'



    # EXAMPLE 3: Change a string using several custom profiles

    my %profile1 = ( string_type  => 'all_uc');
    $new_string = set_profile($samples[2], %profile1);
    # $new_string is 'LANGAGES DÉRIVÉS DU C'
    
    my %profile2 = ( string_type => 'all_lc', force_change => 1);
    $new_string = set_profile($samples[2], %profile2);
    # $new_string is 'langages dérivés du c'
    
    my %profile3 = (
                    custom  => {
                                default => 'all_lc',
                                index   => { '1'  => 'all_uc' }, # 2nd word
                               }
                   );
    $new_string = set_profile($samples[2], %profile3);
    # $new_string is 'langages DÉRIVÉS du C'

    my %profile4 = ( custom => { all_lc => '1st_uc' } );
    $new_string = set_profile($samples[2], %profile4);
    # $new_string is 'Langages Dérivés Du C'



=head1 EXPORT

None by default.

=head1 LIMITATIONS

Since String::CaseProfile is a multilanguage module and title case is a
language-dependent feature, so the functions provided don't handle title
case capitalization (in the See Also section you will find further
information on modules you can use for this task). Anyway, you can use
the profile information provided by get_profile to implement a solution
for your particular case.

For the German language, which has a peculiar letter case rule consisting in
capitalizing every noun, these functions may have a limited utility, but you
can still use the profile information to create and apply customs profiles.


=head1 SEE ALSO

Lingua::EN::Titlecase

Text::Capitalize


=head1 ACKNOWLEDGEMENTS

Many thanks to Xavier Noria for wise suggestions.

=head1 AUTHOR

Enrique Nell, E<lt>perl_nell@telefonica.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Enrique Nell.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut
