#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Data::Dumper;

# type perldoc codeName.pl to see the following documentation where "codeName.pl" is the name of this code.
=head1 Author:
Marcelle Bonterre

=head2 Date Created:
8/28/2013

=head2 Usage:

xivRept.pl inputFile [outputFilename]

=head3 Debug:

Comment/Uncomment debug in sub print_report.

=head2 Result:

After program run, outputFilename is generated in the current directory,
or if no outfile was indicated, one will be created as inputFile_out.txt, or inputFile{i}out.txt
in the case of files with duplicate names where "i" is some number
=cut
###################################################################################################

# -------begin gvars -----------
my ($tier, $source, $host, $size, $volumeName);
my (%hosts,%volNameServer, %serverVolName);
my @hostlist;

#------sub list----------
sub get_vol_calc_size;
sub gen_outname;
sub parseFile;
sub convertToGigs;
sub debug;
sub print_report;
sub calc_server_capacity;
sub read_file;
sub main;

# run all code
main;

sub main {
  read_file;
  calc_server_capacity;
  print_report;
}

sub read_file {
  my $heading_regex = qr/.+?Host\s+Name.+?/;
  my $filePath = $ARGV[0] or die "No CSV file supplied in command.";
  open(my $import, qw(<), $filePath) or die "Could not load \'$filePath\' $!\n";

  LINE: while ( my $line = <$import> ) {
    chomp $line;
    my @fields = split( ",", $line );
    next LINE if($line =~ $heading_regex);
    parseFile( \@fields );
  }
  close($import);
}

sub gen_outname {

  my $filePath = $ARGV[0];

  my $basename = fileparse($filePath,qr/\.[^.]*/);

  # prepare default output filename
  my $out_name =  $basename . "_out.txt";

  # if present, name the output file whatever the user specified
  if($ARGV[1]) {
    $basename = $ARGV[1];
    $out_name = $ARGV[1];
  }

  # if current output filename is a duplicate, add int after filename
  my $fileint = 0; # int val to handle duplicate filename
  while(-e $out_name) {
    $out_name = $basename . "{" . $fileint . "}" . "out.txt";
    $fileint = $fileint + 1;
  }

  return $out_name;
}

sub parseFile  {
  my @fields = @{ $_[0] };

  ( $fields[0] =~ /(\w+)-(.+)-\w+/ ) && ( $tier = $1 ) && ( $source = $2 );
  $host = uc( $fields[1] );
  $size =  convertToGigs( $fields[2].'GB' );
  $volumeName = $fields[3];

  # all volumes have a list of servers who all have the same size
  push @{ $volNameServer{$volumeName}{'serverList'} }, $host;
  $volNameServer{$volumeName}{'size'} = $size;

  # all servers have a list of volumes that they belong to
  push @{ $serverVolName{$host} }, $volumeName;

  $hosts{$host} = {
    'size' => 0, # initialize the calculated size at zero; key to be used later.
    'source' => $source,
    'tier' => $tier
  };

  undef $tier; undef $source; undef $host; undef $size; undef $volumeName;

}

# Accepts size with Units (ie. GB, TB...) as a string
# Converts to GB without Units attached.
sub convertToGigs {
  my $rawSizeStr = $_[0];
  my $sizeInGigsNoUnits;
  ( $rawSizeStr =~ /(.+)TB/ ) && ($sizeInGigsNoUnits = $1 * 1024) ||
  ( $rawSizeStr =~ /(.+)MB/ ) && ($sizeInGigsNoUnits = $1 / 1024) ||
  ( $rawSizeStr =~ /(.+)GB/ ) && ($sizeInGigsNoUnits = $1);
  return $sizeInGigsNoUnits;
}

sub debug {

  my @hostlist = @{ $_[0] };

  my $basename = gen_outname;
  open my $debug,qw/>>/, $basename . "_debug.txt" || die " couldn't open debug for writing\n";
=head2
  print $debug "host\tnumVolsForHost\tcalc'dSizeO\tsource\ttier\n";
  foreach my $host (@hostlist) {
    $source = $hosts{$host}{'source'};
    $tier = $hosts{$host}{'tier'};
    my $volSize = $volNameServer{$volume}{'size'};

    foreach my $volname ( @{ $serverVolName{$host} } ) {
      print $debug "$host\t$source\t$tier\t$volname\n";
    }
  }
=cut
  close $debug;
}


sub calc_server_capacity {
  my $sum = 0;
  foreach my $host (keys %serverVolName) {
    foreach my $volume ( @{ $serverVolName{$host} } ) {
      my $hostSizeOnVolume = get_vol_calc_size($volume);
      $sum += $hostSizeOnVolume;
    }
    $hosts{$host}{'size'} = $sum;
    $sum = 0;
  }

}


sub get_vol_calc_size {
  my $volume = shift @_;
  return $volNameServer{$volume}{'size'} / ( scalar @{ $volNameServer{$volume}{'serverList'} } ) ;
}

sub print_report {
  my $out_name = gen_outname;
  open(my $out,qw(>),"$out_name");

  @hostlist = sort keys %hosts;
  #debug(\@hostlist);
  print $out "Server_Name\tStorage_Vol(GB)\tSource\tTier\n";
  foreach my $host (@hostlist) {
    $tier = $hosts{$host}{'tier'};
    $source = $hosts{$host}{'source'};
    $size = sprintf "%.3f",$hosts{$host}{'size'};

    print $out "$host\t$size\t$source\t$tier\n";

    undef $tier; undef $source; undef $host; undef $size;
  }
  close($out);

}
