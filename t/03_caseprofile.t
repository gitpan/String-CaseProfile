#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 22;

use String::CaseProfile qw(get_profile set_profile);
use Encode;

my @strings = (
                'Entorno de tiempo de ejecuci�n',
                '� un linguaggio veloce',
                'langages d�riv�s du C',
                'sil�labaris, l�altre sistema d�escriptura japon�s',
                'dir-se-ia que era bom',
                'Cadena de prueba KT31',
                'identificador some_ID',
              );

# encode strings as utf-8
my @samples = map { decode('iso-8859-1', $_) } @strings;

my $new_string;


# EXAMPLE 1: Get the profile of a string
my %profile = get_profile($samples[0]);

is($profile{string_type}, '1st_uc', 'First letter of first word is uppercase');
is(@{$profile{words}}, 5, 'String contains 5 words');
is($profile{words}[2]->{word}, 'tiempo', 'Third word is tiempo');
is($profile{words}[2]->{type}, 'all_lc', 'The type of the 2nd word is all_lc');

# Test the token recognition regex
%profile = get_profile($samples[3]);
is(@{$profile{words}}, 5, 'String contains 5 words');
is($profile{words}[0]->{word}, 'sil�labaris', 'First word is sil�labaris');

%profile = get_profile($samples[4]);
is(@{$profile{words}}, 4, 'String contains 4 words');
is($profile{words}[0]->{word}, 'dir-se-ia', 'First word is dir-se-ia');

%profile = get_profile($samples[5]);
is($profile{words}[3]->{word}, 'KT31', 'Fourth word is KT31');
is($profile{words}[3]->{type}, 'other', 'Type of KT31 is other');

%profile = get_profile($samples[6]);
is(@{$profile{words}}, 2, 'String contains 2 words');
is($profile{words}[1]->{word}, 'some_ID', 'Second word is some_ID');
is($profile{words}[1]->{type}, 'other', 'Type of some_ID is other');

# EXAMPLE 2: Get the profile of a string and apply it to another string
my $ref_string1 = 'REFERENCE STRING';
my $ref_string2 = 'Another reference string';

$new_string = set_profile($samples[1], get_profile($ref_string1));
is($new_string, '� UN LINGUAGGIO VELOCE', '� UN LINGUAGGIO VELOCE');

$new_string = set_profile($samples[1], get_profile($ref_string2));
is($new_string, '� un linguaggio veloce', '� un linguaggio veloce');


# EXAMPLE 3: Change a string using several custom profiles
my %profile1 = ( string_type  => 'all_uc');
my %profile2 = ( string_type => 'all_lc', force_change => 1);
my %profile3 = (
                custom  => {
                            default => 'all_lc',
                            index   => { '1'  => 'all_uc' }, # 2nd word
                           }
                );
my %profile4 = ( custom => { 'all_lc' => '1st_uc' } );

$new_string = set_profile($samples[2], %profile1);
is($new_string, 'LANGAGES D�RIV�S DU C', 'LANGAGES D�RIV�S DU C');
    
$new_string = set_profile($samples[2], %profile2);
is($new_string, 'langages d�riv�s du c', 'langages d�riv�s du c');
    
$new_string = set_profile($samples[2], %profile3);
is($new_string, 'langages D�RIV�S du C', 'langages D�RIV�S du C');

$new_string = set_profile($samples[2], %profile4);
is($new_string, 'Langages D�riv�s Du C', 'Langages D�riv�s Du C');

# Validation tests
my %bad_profile1 = get_profile(1);
$new_string = set_profile($samples[0], %bad_profile1);
is($new_string, $samples[0], 'Unchanged string');

my %bad_profile2 = ( string_type => 'bad' );
$new_string = set_profile( $samples[0], %bad_profile2);
is($new_string, $samples[0], 'Unchanged string');

my %bad_profile3 = ( custom => {
                                index => { '7' => 'all_uc' },
                                default => 'bogus',
                           }
               );
$new_string = set_profile($samples[0], %bad_profile3);
is($new_string, $samples[0], 'Unchanged string');




