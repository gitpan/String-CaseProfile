package String::CaseProfile;

use 5.008;
use strict;
use warnings;
use Carp qw(carp);

use Exporter;
use base 'Exporter';
our @EXPORT_OK = qw(
                    get_profile
                    set_profile
                    copy_profile
                   );

our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );

our $VERSION = '0.07';


our $word_re =  qr{
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


our %types = (
                '1st_uc' => 1,
                'all_uc' => 2,
                'all_lc' => 3,
                'other'  => 4,
             );


sub get_profile {
    my $string = shift;

    # read excluded words, if any
    my %excluded;
    if ($_[0]) {
        $excluded{$_}++ foreach (@{$_[0]});
    }
    
    my @words = $string =~ /($word_re)/g;
    my @word_types = map {
                            _exclude($_, \%excluded)
                            ?
                            'excluded'
                            :
                            _word_type($_)
                            
                         } @words;
    
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


sub _exclude {
    my ($word, $excluded_href) = @_;
    
    return 1 if $excluded_href->{$word}; 

    if ($word =~ /[-']/) {
        my @pieces = split /[-']/, $word;
        my @excluded = grep { $excluded_href->{$_} } @pieces;
        if (@excluded) { return 1 } else { return 0 };
    } else {
        return 0;
    }
}


sub set_profile {
    my ($string, %ref_profile) = @_;

    my %string_profile = get_profile($string, $ref_profile{exclude});
    
    my @words = map { $_->{word} } @{$string_profile{words}};
    my @word_types = map { $_->{type} } @{$string_profile{words}};
    
    my $force = $ref_profile{'force_change'};
    
    # validate string_type
    my ($legal, $ref_string_type);
    if ($ref_profile{string_type}) {
        $ref_string_type = $ref_profile{string_type};
        if ($types{$ref_string_type} && $ref_string_type ne 'other') {
            $legal = 1;
        } elsif ($ref_string_type eq 'other') {
            return $string;
        } else {
            carp "\nIllegal value of string_type";
        }
    }
    
    my @transformed;
    
    if ($legal) {
        if ($ref_string_type eq '1st_uc') {
            if ($word_types[0] eq 'excluded') {
                $transformed[0] = $words[0];
            } else {
                $transformed[0] = _transform(
                                              '1st_uc',
                                              $words[0],
                                              $word_types[0],
                                              $force
                                            );
            }
            for (my $i = 1; $i <= $#words; $i++) {
                if ($word_types[$i] eq 'excluded') {
                    push @transformed, $words[$i];
                } else {
                    push @transformed, _transform(
                                                  'all_lc',
                                                  $words[$i],
                                                  $word_types[$i],
                                                  $force
                                                 );
                }
            }
        } else {
            for (my $i = 0; $i <= $#words; $i++) {
                if (
                    $word_types[$i] eq 'excluded' 
                    && $ref_string_type ne 'all_uc'
                    ) {
                        push @transformed, $words[$i];
                } else {
                    push @transformed, _transform(
                                                  $ref_string_type,
                                                  $words[$i],
                                                  $word_types[$i],
                                                  $force
                                                 );
                }
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
                carp "\nIllegal default value in custom profile";
            }
        }
        
        for (my $i = 0; $i <= $#word_types; $i++) {
            
            my $in_index = $ref_profile{custom}->{index}->{$i};
            my $trigger_type = $ref_profile{custom}->{$word_types[$i]};
            
            if ($in_index) {
                if (
                    $word_types[$i] eq 'excluded' 
                    && $in_index ne 'all_uc'
                    ) {
                        push @transformed, $words[$i];
                } elsif ($in_index ne $word_types[$i]) {
                    push @transformed, _transform(
                                                  $in_index,
                                                  $words[$i],
                                                  $word_types[$i],
                                                  $force
                                                 );
                } else {
                    push @transformed, $words[$i];
                }
            } elsif ($trigger_type) {
                if (
                    $word_types[$i] eq 'excluded' 
                    && $ref_string_type ne 'all_uc'
                    ) {
                        push @transformed, $words[$i];
                } else {
                    push @transformed, _transform(
                                                  $trigger_type,
                                                  $words[$i],
                                                  $word_types[$i],
                                                  $force
                                                 );
                }

            } elsif ($default_type) { # use default type
                if (
                    $word_types[$i] eq 'excluded' 
                    && $ref_string_type ne 'all_uc'
                    ) {
                        push @transformed, $words[$i];
                } else {
                    push @transformed, _transform(
                                                  $default_type,
                                                  $words[$i],
                                                  $word_types[$i],
                                                  $force
                                                 );
                }
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


sub copy_profile {
    my %options = @_;
    
    if ( $options{from} && $options{to} ) {
        if ( $options{exclude} ) {
            my %ref_profile = get_profile(
                                          $options{from},
                                          $options{exclude},
                                         );
            
            $ref_profile{exclude} = $options{exclude};
            foreach (keys %ref_profile) {
                print "$_\t$ref_profile{$_}\n";
            }
            return set_profile(
                                $options{to},
                                %ref_profile,
                              );
        } else {
            return set_profile($options{to}, get_profile($options{from}));
        }
    } elsif ( !$options{from} && !$options{to} ) {
        carp "Missing parameters\n";
        return '';
    } elsif ( !$options{from} ) {
        carp "Missing reference string\n";
        return $options{to};
    } else {
        carp "Missing target string\n";
        return '';
    }
}


sub _word_type {
    my ($word) = @_;
    
    if ($word =~ /^[bcdfghjklmnpqrstvwxyz]$/i) {
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
    
    my $types_str = join "", map { $types{$_} } grep { $_ ne 'excluded' } @types;
    
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


sub _transform {
    my ($type, $word, $word_type, $force) = @_;
    
    return $word if ($word_type eq 'other' && !$force);
    
    my %dispatch = (
                    '1st_uc' => ucfirst(lc($word)),
                    'all_uc' => uc($word),
                    'all_lc' => lc($word),
                    'other'  => $word,
                   );
    
    $dispatch{$type};
}


1;
__END__

=head1 NAME

String::CaseProfile - Get/Set the letter case profile of a string

=head1 VERSION

Version 0.07 - June 17, 2008

=head1 SYNOPSIS

    use String::CaseProfile qw(get_profile set_profile copy_profile);
    
    my $reference_string = 'Some reference string';
    my $string = 'sample string';
    
    
    # Typical, single-line usage
    my $target_string = set_profile($string, get_profile($reference_string));
    
    # Alternatively, you can use the 'copy_profile' convenience function:
    my $target_string = copy_profile(
                                        from => $reference_string,
                                        to   => $string,
                                    );
    
    
    # Get the profile of a string, access the details, 
    # and apply it to another string
    my %ref_profile = get_profile($reference_string);
    
    my $string_type = $ref_profile{string_type};
    my $word        = $ref_profile{words}[2]->{word}; # third word
    my $word_type   = $ref_profile{words}[2]->{type};
    
    my $new_string  = set_profile($string, %ref_profile);
    
    
    # Use custom profiles
    my %profile1 = ( string_type => '1st_uc' );
    $new_string  = set_profile($string, %profile1);
    
    my %profile2 = ( string_type => 'all_lc', force_change => 1 );
    $new_string  = set_profile($string, %profile2);
    
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
    $new_string  = set_profile($string, %profile3);



=head1 DESCRIPTION

This module provides a convenient way of handling the letter case conversion of
sentences/phrases/chunks in machine translation, case-sensitive search and replace,
and other text processing applications.

String::CaseProfile includes three functions:

B<get_profile> determines the letter case profile of a string.

B<set_profile> applies a letter case profile to a string; you can apply a
profile determined by get_profile, or you can create your own custom profile.

B<copy_profile> gets the profile of a string and applies it to another string
in a single step.

These functions are Unicode-aware and support text in most European languages.
You must feed them utf8-encoded strings.

B<get_profile> and B<set_profile> use the following identifiers to classify
word and string types according to their case:

=over 4

=item * C<all_lc>

In word context, it means that all the letters are lowercase.
In string context, it means that every word is of C<all_lc> type.

=item * C<all_uc>

In word context, it means that all the letters are uppercase.
In string context, it means that every word is of C<all_uc> type.

=item * C<1st_uc>

In word context, it means that the first letter is uppercase,
and the other letters are lowercase.
In string context, it means that the type of the first word is C<1st_uc>,
and the type of the other words is C<all_lc>.

=item * C<other>

Undefined type (e.g. a CamelCase code identifier in word context, or a
string containing several alternate types in string context.)

=back


=head1 FUNCTIONS

=over 4

=item C<get_profile($string, [ $excluded ])>

Returns a hash containing the profile details for $string. The string provided
must be encoded as B<utf8>.

$excluded is an optional parameter containing a reference to a list of terms that
should not be considered when determining the profile of $string (e.g., the word
"Internet" in some cases, or the first person personal pronoun in English, "I").

The keys of the returned hash are the following:

=over 4

=item * C<string_type>

Scalar containing the string type, if it can be determined; otherwise,
its value is 'other'.

=item * C<words>

Reference to an array containing a hash for every word in the string.
Each hash has two keys: B<word> and B<type>.

=back

=back

=over 4

=item C<set_profile($string, %profile)>

Applies %profile to $string and returns a new string. $string must be encoded
as B<utf8>. The profile configuration parameters (hash keys) are the following:

=over 4

=item * C<string_type>

You can specify one of the string types mentioned above (except 'other') as the
type that should be applied to the string.

=item * C<custom>

As an alternative, you can define a custom profile as a reference to a hash in
which you can specify types for specific word (zero-based) positions, conversions
for the types mentioned above, and you can define a 'default' type for the words
for which none of the preceding rules apply. The order of evaluation is 1) index,
2) type conversion, 3) default type. For more information, see the examples below.

=item * C<exclude>

Optionally, you can specify a list of words that should not be affected by the
B<get_profile> function. The value of the C<exclude> key should be an array
reference. The case profile of these words won't change unless the target
string type is 'all_uc'.

=item * C<force_change>

By default, set_profile will ignore words with type 'other' when applying
the profile. You can use this boolean parameter to enable changing this
kind of words.

=back

=back

=over 4

=item C<copy_profile(from =E<gt> $source, to =E<gt> $target), [ exclude =E<gt> $array_ref ])>

Gets the profile of C<$source>, applies it to C<$target>, and returns
the resulting string.

You can also specify words that should be excluded both in the input string
and the target string:

    copy_profile(
                    from    => $source,
                    to      => $target,
                    exclude => $array_ref,
                );

=back

B<NOTES:>

When these functions process the excluded words list, they also
consider compound words that include them, like "Internet-based" or "I've".

The list of excluded words is case-sensitive (i.e., if you exclude the word 'MP3',
its lowercase version, 'mp3', won't be excluded unless you add it to the list).



=head1 EXAMPLES

    use String::CaseProfile qw(
                                get_profile
                                set_profile
                                copy_profile
                               );
    use Encode;
    
    my @strings = (
                    'Entorno de tiempo de ejecuci�n',
                    '� un linguaggio veloce',
                    'langages d�riv�s du C',
                  );


    # Encode strings as utf-8
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

    $new_string = set_profile( $samples[1], get_profile($ref_string1) );
    # The current value of $new_string is '� UN LINGUAGGIO VELOCE'

    $new_string = set_profile( $samples[1], get_profile($ref_string2) );
    # Now it's '� un linguaggio veloce'
    
    # Alternative, using copy_profile
    $new_string = copy_profile( from => $ref_string1, to => $samples[1] );
    $new_string = copy_profile( from => $ref_string2, to => $samples[1] );



    # EXAMPLE 3: Change a string using several custom profiles

    my %profile1 = ( string_type  => 'all_uc' );
    $new_string = set_profile( $samples[2], %profile1 );
    # $new_string is 'LANGAGES D�RIV�S DU C'
    
    my %profile2 = ( string_type => 'all_lc', force_change => 1 );
    $new_string = set_profile( $samples[2], %profile2 );
    # $new_string is 'langages d�riv�s du c'
    
    my %profile3 = (
                    custom  => {
                                default => 'all_lc',
                                index   => { '1'  => 'all_uc' }, # 2nd word
                               }
                   );
    $new_string = set_profile( $samples[2], %profile3 );
    # $new_string is 'langages D�RIV�S du C'

    my %profile4 = ( custom => { all_lc => '1st_uc' } );
    $new_string = set_profile( $samples[2], %profile4 );
    # $new_string is 'Langages D�riv�s Du C'



    # MORE EXAMPLES EXCLUDING WORDS
    
    # A second batch of sample strings
    @strings = (
                'conexi�n a Internet',
                'An Internet-based application',
                'THE ABS MODULE',
                'Yes, I think so',
                "this is what I'm used to",
               );
               
    # Encode strings as utf-8
    my @samples = map { decode('iso-8859-1', $_) } @strings;



    # EXAMPLE 4: Get the profile of a string excluding the word 'Internet'
    #            and apply it to another string

    my %profile = get_profile($samples[0], ['Internet']);

    print "$profile{string_type}\n";      # prints  'all_lc'
    print "$profile{words}[2]->{word}\n"; # prints 'Internet'
    print "$profile{words}[2]->{type}\n"; # prints 'excluded'

    # Set this profile to $samples[1], excluding the word 'Internet'
    $profile{exclude} = ['Internet'];
    $new_string = set_profile($samples[1], %profile);

    print "$new_string\n"; # prints "an Internet-based application", preserving
                           # the case of the 'Internet-based' compound word



    # EXAMPLE 5: Set the profile of a string containing a '1st_uc' excluded word
    #            to 'all_uc'

    %profile = ( string_type => 'all_uc', exclude => ['Internet'] );
    $new_string = set_profile($samples[0], %profile);
    
    print "$new_string\n";   # prints 'CONEXI�N A INTERNET'



    # EXAMPLE 6: Set the profile of a string containing an 'all_uc'
    #            excluded word to 'all_lc'
    
    %profile = ( string_type => 'all_lc', exclude => ['ABS'] );
    $new_string = set_profile($samples[2], %profile);

    print "$new_string\n";   # prints 'the ABS module'



    # EXAMPLE 7: Get the profile of a string containing the word 'I' and
    #            apply it to a string containing the compound word 'I'm'
    #            using the copy_profile function

    $new_string = copy_profile(
                                from => $samples[3],
                                to   => $samples[4],
                                exclude => ['I'],
                              );

    print "$new_string\n";   # prints "This is what I'm used to"



    # EXAMPLE 8: Change a string using a custom profile
    
    %profile = (
                    custom  => {
                                default => '1st_uc',
                                index   => { '1'  => 'all_lc' }, # 2nd word
                               },
                    exclude => ['ABS'],
               );

    $new_string = set_profile($samples[2], %profile);
    print "$new_string\n";  # prints 'The ABS Module'



=head1 EXPORT

None by default.

=head1 LIMITATIONS

Since String::CaseProfile is a multilanguage module and title case is a
language-dependent feature, the functions provided don't handle title
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

Copyright (C) 2007-2008 by Enrique Nell.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut