package Guiguts::MultiLingual;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw()
}

=head1 NAME

Guiguts::MultiLingual - spellcheck in multiple languages

=head1 PLAN

Variables: base_lang eg 'en'
       additional_lang eg 'fr', 'la'
array wordlist => word, (distinct words in book)
  => frequency, (count of words in book)
  => language, (language spelt in, eg en, or user, or undef)

A: set languages
B: Process  file as per word frequency into array wordlist
	filling frequency and word
C: Aspell wordlist where language undef using base_lang
D: Diff Aspell output with wordlist and
	set language = base_lang for all words not in output
	ie correctly spelt
E: Repeat (C) where language undef using additional_lang[1]
F: Repeat (D) setting language = additional_lang[1] where spelt
G: Repeat E/F for all additional_lang
H: consider saving wordlist to file
I: option to add non-base_lang spelt words to project.dic
J: option to update wordlist language = user for all words in project.dic
K: display outputs (wordlist) in word frequency window with (frequency)
	and ability to switch between - undef / user / base / spelt
	and ability to alter language values

=cut

1;