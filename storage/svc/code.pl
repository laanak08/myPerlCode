#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Data::Dumper;

# type perldoc codeName.pl to see the following documentation where "codeName.pl" is the name of this code.
=pod

=head1 Author:
Marcelle Bonterre

=head2 Date Created:
2/1/2013

=head2 Usage:

Run As: SVC_storage_report.pl inputFile outputFilename_WITHOUT_EXTENSION

=head2 Result:

After program run, outputFilename is generated in the current directory,
or if no outfile was indicated, one will be created as inputFile_out.txt, or inputFile{i}out.txt
in the case of files with duplicate names where "i" is some number
- If any vdisk exists in the second command's output but not in the first command's output,
that vdisk's name get appended to the exception list.
- ***The exception list follows the same naming convention as described above***

Input:
- "*.txt" file containing the output from the "lshostvdiskmap" command
and the output from the "lsvdisk" command
concatenated onto the previous command's output.
Output:
- Scans the entire document.
- gets host name, Svc name, and the size occupied on the indicated host.
- the size is calculated as the sum of the sizes of all the vdisks on a particular host.
- Server_Name (hostname)	Storage_Volume		Svc_Name
- output into a "*.tab" tab separated values file.

DEBUG file (Optional):
- To cause a debug file to be generated, uncomment the #debug; call at the bottom of this script.
- This will generate a <SVCNAME>_debug.txt file for each SVC that is being reported.

=head2 Functions:
=cut

my (%excepts, %hosts, %hostStorage, %vdisks, %vdisknames, @hostlist,@problemDisks);
my $svcName = "No_Svc";


sub main;
sub read_file;
sub convert_to_gigs;
sub parse_file_type_one;
sub parse_file_type_two;
sub clean_input_data;
sub debug;
sub gen_outname;
sub get_single_vdisk_size;
sub calc_total_storage;
sub print_exceptions;
sub print_report;

main;

=over

=item main()

Processes inputfile and generates output file

=back
=cut
sub main {
	read_file;
	clean_input_data;
	get_single_vdisk_size;
	calc_total_storage;
	print_report;
	#debug;
	print_exceptions;
}

=over

=item read_file()

Parses input file, and converts it to internal data structures

=back
=cut
sub read_file {
	my $fileOneIndicator = 'SCSI_id';
	my $fileTwoIndicator = 'IO_group_id';
	my $parseFileType;

	my $filePath = $ARGV[0] or die "No CSV file supplied in command.";
	open( my $import, '<', $filePath ) or die "Could not load '$filePath' $!\n";

	while ( my $line = <$import> ) {
		chomp $line;
		my @fields = split( ",", $line );

		# if current line contains the svcName
		( scalar @fields < 6 ) && ( $line =~ /(\S+)/ ) && ( $svcName = $1 ) && next;

		# after deciding which file is being read, skip to next iteration of while loop
		if ( $fields[2] eq $fileOneIndicator ) { $parseFileType = \&parse_file_type_one; next; }
		if ( $fields[2] eq $fileTwoIndicator ) { $parseFileType = \&parse_file_type_two; next; }
		&$parseFileType( \@fields )
	}
	close($import);
}

sub parse_file_type_one {
	my @fields = @{$_[0]};

	my ($hostName, $vDiskName) = ($fields[1], $fields[4]);
	# print $hostName."\n" if( index($hostName,'_') == -1);
	unless($svcName eq 'SVCOXFC01V'){
		unless( index($hostName,'_') == -1 ) { 
			my @containsHostname = split('_',$hostName);
			$hostName = pop @containsHostname;
		}
	}

	unless($hostName and $vDiskName){
		push( @{ $excepts{'problemLines'} }, \@fields);
		return 'invalid_line';
	}
	
	push( @{ $vdisknames{$vDiskName}{'hosts'} }, $hostName );
	push( @{ $hosts{$hostName} }, $vDiskName );
}

sub parse_file_type_two {
	my @fields = @{$_[0]};

	my $vDiskName = $fields[1];
	my ($tier, $storageDev) = ('MissingValue', $fields[6]);

	if( $fields[6] =~ /(\w+)-(\S+)/ ) { 
		($tier, $storageDev) = ($1, $2);
	}
	
	my $exit = sub {
		push (@problemDisks, $vDiskName);
		push( @{ $excepts{'problemLines'} }, \@fields);
		return 'invalid_line';
	};
	my $size = $fields[7] || &$exit;

	if( $vdisknames{$vDiskName} ) {
		$vdisks{$vDiskName} = {
			'size' => convert_to_gigs($size),
			'storageDev' => $storageDev,
			'tier' => $tier
		};
	} else {
		unless (  $vDiskName =~ /\W/  ) {
			$excepts{$vDiskName} = $size;
		}
	}
}

sub clean_input_data {
	foreach my $host ( keys %hosts ){

		my $numDisks = scalar @{ $hosts{$host} };
		for(my $i = 0; $i < $numDisks; $i++){

			my $hostDisk = ${ $hosts{$host} }[$i];

			foreach my $disk ( @problemDisks ) {

				if( $hostDisk eq $disk ){
					print "HostDisk Match: $hostDisk\n";
					delete ${ $hosts{$host} }[$i];
				}
			}
		}
	}

	foreach my $vdiskname ( keys %vdisknames ){
		foreach my $disk ( @problemDisks ){
			if( $vdiskname eq $disk ){
				 print "Vdisk Match: $vdiskname\n";
				delete $vdisknames{$vdiskname};
			}
		}
	}
}

sub get_single_vdisk_size {
	# find size of individual vdisk on host.
	foreach my $host (keys %hosts) {
		foreach my $vdisk ( @{$hosts{$host}} ) {
			# get size of list of hosts on the current vdisk to be used in the following division
			$vdisknames{$vdisk}{'numhosts'} = scalar @{ $vdisknames{$vdisk}{'hosts'} };
		}
	}

	foreach my $vdisk (keys %vdisknames) {
		$vdisks{$vdisk}{'size'} /= $vdisknames{$vdisk}{'numhosts'};
	}
}

sub calc_total_storage {
	foreach my $host (keys %hosts) {
		foreach my $vdisk ( @{ $hosts{$host} } ) {
			my $storage = $vdisks{$vdisk}{'storageDev'};

			if( defined( $hostStorage{$host}{$storage} ) ) {
				$hostStorage{$host}{$storage} += $vdisks{$vdisk}{'size'};
			} else {
				$hostStorage{$host}{$storage} = $vdisks{$vdisk}{'size'};
			}
		}
	}
}

sub print_report {
	my $outName = gen_outname();
	open( my $out, qw(>), $outName );

	my %printedStorage;
	@hostlist = sort keys %hosts;

	print $out "Server_Name\tStorage_Device\tStorage_Vol(GB)\tSource\tTier\n";
	foreach my $host (@hostlist) {
		foreach my $vdisk ( @{$hosts{$host}} ) {
			my $storage = $vdisks{$vdisk}{'storageDev'};
			my $size = sprintf("%.3f",$hostStorage{$host}{$storage});
			my $tier = $vdisks{$vdisk}{'tier'};

			next if $printedStorage{$storage};
			$printedStorage{$storage} = 1;

			print $out "$host\t$storage\t$size\t$svcName\t$tier\n";
		}
		# print $out "\n"; # uncomment to make output more readable and separated by host
		undef %printedStorage;
	}
	close($out);
}

sub print_exceptions {
	my $exceptsList = gen_outname( 'exceptions' );
	open( my $exceptions, qw(>>), $exceptsList );
	print $exceptions 
		"################################\n" .
		"#  These vdisks have no hosts\n" .
		"#       vdisk => size\n" .
		"#################################\n";
	print $exceptions Dumper( \%excepts );
	print $exceptions "\n";
	close($exceptions);
}


sub debug {
	# my $filename = gen_outname( 'debug' );
	# open my $debug,qw/>>/, $filename || die " couldn't open debug for writing\n";

	# print $debug "Host\tVdisk\tStorageDev\tNumHosts\tSizePerHost\tTier\n";
	# foreach my $host (@hostlist) {
	# 	foreach my $vdisk ( @{$hosts{$host}} ) {
	# 		my $storage = $vdisks{$vdisk}{'storageDev'};
	# 		my $size = sprintf("%.3f", $vdisks{$vdisk}{'size'} );
	# 		my $numHosts = $vdisknames{$vdisk}{'numhosts'};
	# 		my $tier = $vdisks{$vdisk}{'tier'};

	# 		if($host ){ print $debug "$host\t"; }else{ print $debug "undefined\t"; }
	# 		if($vdisk){ print $debug "$vdisk\t"; }else{ print $debug "undefined\t"; }
	# 		if($storage){ print $debug "$storage\t"; }else{ print $debug "undefined\t"; }
	# 		if($numHosts){ print $debug "$numHosts\t"; }else{ print "undefined\t"; }
	# 		if($size){ print $debug "$size\t"; }else{ print $debug "undefined\t"; }
	# 		if($tier){ print $debug "$tier\t\n"; }else{ print $debug "undefined\t\n"; }
	# 	}
	# }
	# close($debug);
}

=over

=item gen_outname(type_of_outname)

 no argument: Returns unused filename based on input data name.

 'exception': Returns unused filename based on input data name, that identifies the
  output file for exceptions report.

 'debug': Returns unused filename based on input data name, that identifies the
  output file for debugging.

=back
=cut
sub gen_outname {
	my ($arg) = @_;
	$arg = "" unless $arg;

	my ($name,$path,$ext) = fileparse($ARGV[0],('.csv','.txt'));
	if($arg eq 'exceptions'){
		$name .= '_exceptions';
	} elsif( $arg eq 'debug'){
		$name .= '_debug';
	} else {
		$name .= '_out';
	}

	my $testname = $name . '.txt';
	for(my $i = 0; -e $testname; ++$i ) {
		$testname = $name . $i . '.txt';
	}
	$name = $testname;
	return $name;
}

=over

=item convert_to_gigs(sizeWithUnits)

Converts string representing size to gigabytes and strips units from the size.

=back
=cut
sub convert_to_gigs {
	my ($sizeInGigsNoUnits, $units);
	($sizeInGigsNoUnits, $units) = ($_[0] =~ /(\S+)(..)/);
	( $units eq 'MB' ) && ($sizeInGigsNoUnits /= 1024) ||
	( $units eq 'TB' ) && ($sizeInGigsNoUnits *= 1024);
	return $sizeInGigsNoUnits;
}