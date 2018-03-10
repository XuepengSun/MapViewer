#!/usr/bin/perl -w 

my $mapFile = '8K_SNP.txt';
my $output = 'valid_map.txt';

open OUT,">$output";
open IN,$mapFile;
while(<IN>){
	@s=split;
	my ($d) = $s[0] =~/(\d+)/;
	my ($k) = $s[3] =~/(\d+)/;
	next if $d > 20;
	print OUT $_ if $d == $k;
}
close IN;
close OUT;
