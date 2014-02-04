#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use HTML::TreeBuilder;


# read list of links
my $linkFile = shift @ARGV;
open my $fh, qw/</, $linkFile or die "couldn't read $linkFile\n";

while ( <$fh> ) {
  chomp;
  (/href="(.+?)"/) and ( $_ = $1 );
  open my $file,qw/</,$_ or (print "skipping $_\n") and next;

# parse page for server name, and environment
  #my %rept = parsePage($file);
  parsePage($file);
# generate report
  #printRept(\%rept);
}

sub parsePage {
  my $file = shift @_;
  #my %rept;

  my $root = HTML::TreeBuilder->new;
  $root->parse_file($file);
  $root->eof;

  $root->dump;

  # find headings row
  # pick index of needed columns by analyzing headings row
  # grab every other row and store above index's data
  my @table = $root->find_by_tag_name('tr');
  foreach my $row ( @table ) {
    my @kids = $row->content_list;
    if( @kids and ref $kids[0] and $kids[0]->tag eq 'td' ){
      print $kids[0]->as_text,"\n";
    }
  }
  $root->delete;
  #return \%rept;

}

sub printRept {

}
