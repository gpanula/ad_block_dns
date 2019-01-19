#! /usr/bin/perl

## This script was found at
## http://stackoverflow.com/questions/1782033/convert-perl-script-to-python-dedupe-2-files-based-on-hash-keys
## Compare file1 and file2 and output only the unique lines from file2.

## Opening file1.txt and store the data in a hash.
open my $file1, '<', "/tmp/ad.domains" or die $!;
while ( <$file1> ) {
    my $name = $_;
    $file1hash{$name}=$_;
}
## Opening file2.txt and store the data in a hash.
open my $file2, '<', "/tmp/malware.domains" or die $!;

while  ( <$file2> ) {
    $name = $_;
    $file2hash{$name}=$_;
}

open my $dfh, '>', "/tmp/ad-domain-dupes.txt";

## Compare the keys and remove the duplicate one in the file2 hash
foreach ( keys %file1hash ) {
    if ( exists ( $file2hash{$_} ))
    {
    print $dfh $file2hash{$_};
    delete $file2hash{$_};
    }
}

# for our purposes we don't care about the cleaned file
open my $ofh, '>', "/tmp/ad_domains_removed_from_malware.txt";
print  $ofh values(%file2hash) ;

