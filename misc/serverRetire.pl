#!/usr/bin/env perl

open my $fh,qw/</,shift @ARGV or die "couldn't open $_ ";

my @servers;
while(<$fh>) {
  push @servers, $1 if (/(.+?)\s+is\s+being\s+retired/);
}
close $fh;

open my $out,qw/>>/,qw/out.txt/;

local $" = "\n";
print $out "@servers";

close $out;
