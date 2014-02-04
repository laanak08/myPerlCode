#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use File::Basename;

# type perldoc codeName.pl to see the following documentation where "codeName.pl" is the name of this code.
=head1 Author:
Marcelle Bonterre

=head2 Date Created:
3/22/2013

=head2 Usage:

vmaxRept.pl inputFile [outputFilename]

=head3 Debug:

Search for "`rm *debug*`;"
Comment it out.
This generates a file *debug* which contains debug log of all "  print $debug ..." lines


=head2 Result:

After program run, outputFilename is generated in the current directory,
or if no outfile was indicated, one will be created as inputFile_out.txt, or inputFile{i}out.txt
in the case of files with duplicate names where "i" is some number
=cut
###################################################################################################

#-----sub list---------------
sub main;
sub gen_outname;
sub read_infile;
sub write_to_dataStructs;
sub get_server_name;
sub get_symDev_size;
sub convert_to_gigs;
sub calc_server_capacity;
sub write_outfile;
sub write_debug;
sub isCluster;

#-----gvars------------------
my (%servers, %symDevs);

# run all code
main;

sub main {
  read_infile;
  calc_server_capacity;
  write_outfile;
  #write_debug;
  #`del *debug*`;
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

sub read_infile {

  my $filePath = $ARGV[0] or die "No CSV file supplied in command.";
  open(my $import, qw(<), $filePath) or die "Could not load \'$filePath\' $!\n";

  my ($server, $source, $symDev, $size);

  while (<$import>){
    # skip blank lines
    if( /\w+/ ){
      chomp $_;
      my ($value, $type) = parse_line($_);

      next if ($type eq 'skip');

      ($type eq 'source') && ($source = $value);
      ($type eq 'server') && ($server = $value);

      if($type eq 'symDevSize') {
		$symDev = $value->[0];
		$size = $value->[1];
		write_to_dataStructs($source,$server,$symDev,$size);
      }
    }

  }
  close($import);

}

sub write_to_dataStructs {
  my ($source,$server,$symDev,$size) = (@_);

  push( @{ $symDevs{$symDev}{'serverList'} },$server );
  $symDevs{$symDev}{'size'} = $size;

  push( @{ $servers{$server}{'symDevList'} },$symDev );
  $servers{$server}{'source'} = $source;

}

sub parse_line {
  ($_) = (@_);

  my $sourceRegex = qr/Symmetrix\s+ID\s+:\s+(\d+)/;
  my ($source,$value,$type);

  # get source
  ( /$sourceRegex/ ) &&
  ( $source = $1 ) &&
  ( return ($source,qw/source/) );

  ( ($value,$type) = get_server_name($_) ) &&
  ($value ne 'cluster') &&
  ( return ($value,$type) );

  ( ($value,$type) = get_symDev_size($_) ) &&
  ($value ne 'noSize') &&
  ( return ($value,$type) );

  return ('skip','skip');
}

sub get_server_name {
  ($_) = (@_);

  my $server;
  my $serverRegex = qr/Initiator\s+Group\s+Name\s+:\s+([\w|-]+)/;

  if( /$serverRegex/ ){
    $server = $1;

    return ('false','cluster') if( isCluster($server) eq 'cluster');

    if($server =~ /-\d\d$/){
      chop($server);
      chop($server);
      chop($server);
    }

    return ($server,'server');
  }

  return ('false','cluster');
}

sub isCluster {
  my ($server) = (@_);

  if( $server =~ /Cluster/ ){
    return 'cluster';
  } elsif( $server =~ /[-]+/ ){
    # detect cases where the server name is like:
    # eCaaS-cert-cpdb1a996-997-998-999
    # when true, we're reading a cluster, so don't write its info

    my @lineWithDashes = split("-",$server);
    my $numItemsInlineWithDashes = scalar @lineWithDashes;

    if($numItemsInlineWithDashes > 2){
      return 'cluster';
    }else{
      return 'server';
    }
  }else{
    return 'server';
  }

  return 'server';
}

sub get_symDev_size {
  ($_) = (@_);

  my ($symDev,$size);
  my $symDevRegex = qr/([\w]{4})\s+[\w]{3}:/;

  if( /$symDevRegex/ ){
    $symDev = $1;

    #get size(GB) and mask-name field
    if( /(\d+)\s+(\w|-|\*)+$/ || /\s(\d+)\s[A-Z|a-z]{3,4}/){
      $size = convert_to_gigs($1);

    }
    return ([$symDev,$size],qw/symDevSize/);
  }

  return ('false','noSize');
}

sub convert_to_gigs {
  my ($size) = (@_);
  my $sizeInGigs = $size/1024;
  return $sizeInGigs;
}

sub calc_server_capacity {

  my $servCap;
  foreach my $server (keys %servers){
    foreach my $symDev ( @{$servers{$server}{'symDevList'}} ){

      # get $numServersSharing current symDev
      my $numServersSharing = scalar @{$symDevs{$symDev}{'serverList'}};
      # get symDev Size
      my $size = $symDevs{$symDev}{'size'};
      #if(!defined($size)){ print $debug "$symDev has error-producing size.\n\n"};

      # compute symDev contrib to total server size
      my $contrib = $size / $numServersSharing;
      $servCap += $contrib;

    }
    $servers{$server}{'capacity'} = $servCap;

    undef $servCap;
  }
}

sub write_outfile {
  my $out_name = gen_outname;

  open(my $out,qw(>),"$out_name");

  my @sortedServers = sort keys %servers;

  print $out "Server_Name\tStorage_Vol(GB)\tSource\n";
  foreach my $oneServerName (@sortedServers){
    my $source = $servers{$oneServerName}{'source'};
    my $size = sprintf("%.3f", $servers{$oneServerName}{'capacity'} );
    print $out "$oneServerName\t$size\t$source\n";
  }

  close($out);
}

=head2
sub write_debug {
  my %servers = %{shift @_};
  $out_name = gen_outname;
  #print $debug Dumper(\%debugInfo);

  open(my $debug,qw(>),"$out_name.debug");

  my @debugServerList = sort keys %debugInfo;

  print $debug "Server\tSymDev\tNumServersThatShare\tSize(GB)\n";
  foreach my $serv (@debugServerList){
    print $debug "$serv";
    foreach my $symDev (keys %{$debugInfo{$serv}}){
      print $debug "\t$symDev";
      print $debug "\t$debugInfo{$serv}{$symDev}[0]";
      print $debug "\t$debugInfo{$serv}{$symDev}[1]\n";
    }
  }
  close($debug);
}
=cut
