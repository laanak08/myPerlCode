#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Data::Dumper;

=head2 Author:

Marcelle Bonterre

=head2 Purpose:
=cut

sub gen_outname;
sub read_file;
sub print_report;
sub parse_line;
sub check_contains;
sub check_ends_with;
sub check_begins_with;
sub get_server_env;
sub check_physical_virtual;
sub main;

my %contains;
my %startsWith;

# decide physical/virtual
# decide env for servers and env tab
# ... calculate/lookup other new fields to be created ..
# write split line to data struct + newly expanded/split/added fields

sub main {
  read_file;

  print_report;
}

sub read_file {
  my $heading_regex = qr/.+?vcBSLPath.+?/;
  my $filePath = $ARGV[0] or die "No CSV file supplied in command.";
  open(my $import, qw(<), $filePath) or die "Could not load \'$filePath\' $!\n";

  LINE: while ( my $line = <$import> ) {
    chomp $line;
    next LINE if($line =~ $heading_regex);
    my @lineFields = split( ",", $line );
    parse_line( \@lineFields );
  }
  close($import);
}

sub parse_line {
	my @line = @{ $_[0] };
	
	my ( $server, $numCPUs, $numCores, $billingCode,
	$baseOStype, $size, $physVirt, $resourceCnt,
	$vcBSLPath, $bslAppPercent, $appServerPercent,
	$appName, $product, $serverModel, $env,
	$vcsnSiteName ) = @line;
	
	my @splitBSLPath = split( '|', $vcBSLPath );
	my ( $bu, $division, $solutionLine, $bsl ) = @splitBSLPath;
	
	$env = get_server_env($server, $env);	
	$physVirt = check_physical_virtual($server,$baseOStype,$physVirt,$resourceCnt,$serverModel,$env,$vcsnSiteName);
	
	my @writeLine = ( $server, $numCPUs, $numCores, $billingCode,
	$baseOStype, $size, $physVirt, $resourceCnt,
	$bu, $division, $solutionLine, $bsl, 
	$bslAppPercent, $appServerPercent,
	$appName, $product, $serverModel, $env,
	$vcsnSiteName );
	
	# FIXME: write $writeLine to file;
	print "@writeLine\n";
}

sub print_report {
    
}
    
sub check_physical_virtual {
    # potentially need to remove unsed subroutine arguments
    my ( $server, $baseOStype, $pv, $resourceCnt, $serverModel, $env, $vcsnSiteName ) = @_;
    
    if( ($serverModel =~ /virtual/i) && ($pv =~ /virtual/i) ) {
        $pv = 'virtual';
    } else {
        $pv = 'physical';
    }

    return $pv;
}

sub check_begins_with {
    my ($server) = @_;
    
    my $cert = qr/^C\d/i;
    my $dev = qr/^D\d/i;
    my $prod = qr/^P\d/i;
    my $test = qr/^T\d/i;

    my %regexes = (
        'cert' => $cert,
        'dev' => $dev,
        'prod' => $prod,
        'test' => $test
    );
    
    foreach my $key ( keys %startsWith ) {
        if( $server =~ /^$key/i) {
            return $startsWith{$key};
        }
    }
    
    foreach my $regex ( keys %regexes ) {
        if( $server =~ $regexes{$regex} ){
            return $regex;
        }
    }
     
    return "none";
}

sub check_contains {
    my ($server) = @_;
    
    foreach my $key ( keys %contains ) {
        if( $server =~ /$key/i) {
            return $contains{$key};
        }
    }
    
    if( ($server =~ /...red.+?/i) || ($server =~ /...wkg.+?/i) ) {
        return "DR";
    }
    
    return "none";
}

sub check_ends_with {
    my ($server) = @_;
    
    my $prod = qr/P\d{3}$/i;
    my $cert = qr/C\d{3}$/i;
    my $dev = qr/D\d{3}$/i;
    my $test = qr/T\d{3}$/i;
    my $cert2 = qr/A\d{3}$/i;

    my %regexes = (
        'prod' => $prod,
        'cert' => $cert,
        'dev' => $dev,
        'test' => $test,
        'cert2' => $cert2
    );

    foreach my $regex ( keys %regexes ) {
        if( $server =~ $regexes{$regex} ){
            return $regex;
        }
    }
    return "none";
}

sub get_server_env {
    my ($server, $env) = @_;
    
    my $doesBeginWith = check_begins_with($server);
    my $doesContian = check_contains($server);
    my $doesEndWith = check_ends_with($server);

    # FIXME: add logic to decide env based on results
    return $env;
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

%contains = (
'dev' => 'Dev',
'int' => 'Int',
'prod' => 'Prod',
'prd' => 'Prod',
'cert' => 'Cert',
'crt' => 'Cert',
'test' => 'Test',
'uat' => 'UAT',
'Clup' => 'Prod',
'Clud' => 'Dev',
'Cluc' => 'Cert',
'Clua' => 'Cert',
'clut' => 'Test'
);

%startsWith = (
'Drp' => 'DR',
'Drlp' => 'DR',
'pnt' => 'Prod',
'Psc' => 'Prod',
'Psdb' => 'Prod',
'Psml' => 'Prod',
'P1ml' => 'Prod',
'P1se' => 'Prod',
'Dvd' => 'Dev',
'dvc' => 'Dev',
'Lab' => 'Lab',
'Tpdb' => 'Test',
'Tpc' => 'Test',
'Tpw' => 'Test',
'tpn' => 'Test',
'Oxp' => 'Prod',
'oxlp' => 'prod',
'Oxc' => 'Cert',
'Oxlc' => 'Cert',
'Oxd' => 'Dev',
'Oxld' => 'Dev',
'Oxt' => 'Test',
'Oxlt' => 'Test',
'Cnt' => 'Cert',
'Cpweb' => 'Cert',
'Cpml' => 'Cert',
'Cpn' => 'Cert',
'Cpdb' => 'Cert',
'Cpc' => 'Cert',
'Cltukp' => 'Prod',
'Clleb' => 'DR',
'Cl' => 'Cert',
'Cp' => 'Cert',
'Dv' => 'Dev',
'Dco' => 'Dev',
'Ps' => 'Prod'
);