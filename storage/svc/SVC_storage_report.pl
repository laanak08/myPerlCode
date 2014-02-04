#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Data::Dumper;

#################################################################################################################################
# Author: Marcelle Bonterre -- 2/1/2013
#
# Run As: SVC_storage_report.pl inputFile outputFilename_WITHOUT_EXTENSION
#
# Result: After program run, outputFilename is generated in the current directory,
#	or if no outfile was indicated, one will be created as inputFile_out.txt, or inputFile{i}out.txt
#	in the case of files with duplicate names where "i" is some number
#	- If any vdisk exists in the second command's output but not in the first command's output,
#	that vdisk's name get appended to the exception list.
#	- ***The exception list follows the same naming convention as described above***
#
# Input:
#	- "*.txt" file containing the output from the "lshostvdiskmap" command
# 	  and the output from the "lsvdisk" command
# 	  concatenated onto the previous command's output.
# Output:
#	- Scans the entire document.
#	- gets host name, Svc name, and the size occupied on the indicated host.
#		- the size is calculated as the sum of the sizes of all the vdisks on a particular host.
#	- Server_Name (hostname)	Storage_Volume		Svc_Name
#		- output into a "*.tab" tab separated values file.
#
# DEBUG file (Optional):
#	- To cause a debug file to be generated, uncomment the #debug; call at the bottom of this script.
#		- This will generate a <SVCNAME>_debug.txt file for each SVC that is being reported.
#
################################################################################################################################
# ChangeLog:
#-----------------------------------------------------------------------------------------------------------------------------
# (xx/yy/2013)
# if reading second cmd output lists no tier info in 7th field (i.e. index 6), write host server name out to file
#
# (7/13/2013)
# line 95: refactored while loop that reads the input file
# line 110/121: pulled the code that reads file one and file two out of the while loop into separate subroutines
#		which then get called dynamically from the while loop
# lines 100-106: cleaned up logic in while loop to be more semantically straightforward.
# removed unused code that:
#		gets storage volume sum
#		gets tier-less vdisks
# line 163: added a closure that sums storage volume size within a host's vdisk list
# lines 189-190: addded code to print only unique storage devices per host in final output
# line 192-193: bumped the former line 192 down to 193, to insert a check for vDisks that are in migration transition.
#################################################################################################################################

################################################################################################################################
# Output filenames - Main scripts output, an exception list if it exists get named here.
################################################################################################################################
my $filePath = $ARGV[0] or die "No CSV file supplied in command.";
my $basename = fileparse( $filePath, qr/\.[^.]*/ );
my $out_name;

# if present, name the output file whatever the user specified
( $ARGV[1] ) && ( $basename = $ARGV[1] ) && ( $out_name = $ARGV[1] );

# prepare default exceptionList filename
my $exceptsList = $basename . "_exceptions.txt";

# prepare default output filename
$out_name = $basename . "_out.txt";

my $fileint = 0;    # int val to handle duplicate filename

# if current output filename is a duplicate, add int after filename
while ( -e $out_name ) {
    $out_name = $basename . "{" . $fileint . "}" . "out.txt";
    $fileint  = $fileint + 1;
}

# if current exceptionList filename is a duplicate, add int after filename
while ( -e $exceptsList ) {
    $exceptsList = $basename . "{" . $fileint . "}" . "exceptions.txt";
    $fileint     = $fileint + 1;
}
##################################################################################################################################

open( my $import, '<', $filePath ) or die "Could not load '$filePath' $!\n";
open( my $exceptions, qw(>>), "$exceptsList" );

my %excepts;
my %hosts;
my %hostStorage;
my %vdisks;
my %vdisknames;
my @hostlist;

my $svcName      = "No_Svc";
my $fileOneRegex = qr/SCSI_id/;
my $fileTwoRegex = qr/IO_group_id/;
my $parseFileType;

# bias: all 'next' commands skip to the next iteration of the while loop to avoid processing lines that shouldn't be processed
# example: 'next' skips processing the svcname, and the heading fields of each file as they dont contain data, just headings.
while ( my $line = <$import> ) {
    chomp $line;
    my @fields = split( ",", $line );

# if @fields has just svcName in it, grab the name and store it, then skip to next iteration of while loop
    ( scalar @fields < 6 ) && ( $line =~ /(\w+)/ ) && ( $svcName = $1 ) && next;

 # after deciding which file is being read, skip to next iteration of while loop
    if ( $line =~ $fileOneRegex ) { $parseFileType = \&fileOneParse; next; }
    if ( $line =~ $fileTwoRegex ) { $parseFileType = \&fileTwoParse; next; }

    &$parseFileType( \@fields );
}
close($import);

sub fileOneParse {
    my @fields = @{ $_[0] };

    (@fields) && ( $fields[1] =~ /.+_(.+)/ ) && ( my $hostName  = $1 ) && ( my $vDiskName = $fields[4] );

    # "$vDiskName" => @{[$hostName...]}
    push( @{ $vdisknames{$vDiskName}{'hosts'} }, $hostName );

    # "$hostName" => @{[$vDiskName...]}
    push( @{ $hosts{$hostName} }, $vDiskName );
}

sub fileTwoParse {
    my @fields = @{ $_[0] };

    my $vDiskName = $fields[1];

    ( $fields[6] =~ /(\w+)-(.+)/ ) && ( my $tier = $1 ) && ( my $storageDev = $2) && ( my $size =  &convertToGigs( $fields[7] ) );

    # assign each vdisk its own size and tier
    if ( defined( $vdisknames{$vDiskName} ) ) {
        $vdisks{$vDiskName} = {
	    'size' => $size,
	    'storageDev' => $storageDev,
	    'tier' => $tier
	};
    } else {
        unless (  $vDiskName =~ /\W/  ) {
            $excepts{$vDiskName} = $size;
        }
    }
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
	open my $debug,qw/>>/, $basename . "_debug.txt" || die " couldn't open debug for writing\n";
	print $debug "Host\tVdisk\tStorageDev\tNumHosts\tSizePerHost\tTier\n";
	foreach my $host (@hostlist) {
	    foreach my $vdisk ( @{$hosts{$host}} ) {
		my $storage = $vdisks{$vdisk}{'storageDev'};
		my $size = sprintf("%.3f", $vdisks{$vdisk}{'size'} );
		my $numHosts = $vdisknames{$vdisk}{'numhosts'};
		my $tier = $vdisks{$vdisk}{'tier'};

		if($host ){ print $debug "$host\t"; }else{ print $debug "undefined\t"; }
		if($vdisk){ print $debug "$vdisk\t"; }else{ print $debug "undefined\t"; }
		if($storage){ print $debug "$storage\t"; }else{ print $debug "undefined\t"; }
		if($numHosts){ print $debug "$numHosts\t"; }else{ print "undefined\t"; }
		if($size){ print $debug "$size\t"; }else{ print $debug "undefined\t"; }
		if($tier){ print $debug "$tier\t\n"; }else{ print $debug "undefined\t\n"; }
	    }
	}
}


{ # this block allows reuse of var names by limiting their scope to this enclosed block

	# find size of individual vdisk on host.
	foreach my $host (keys %hosts) {
	    foreach my $vdisk ( @{$hosts{$host}} ) {
		# get size of list of hosts on the current vdisk to be used in the following division
		$vdisknames{$vdisk}{'numhosts'} = scalar @{ $vdisknames{$vdisk}{'hosts'} };
	    }
	}

	foreach my $vdisk (keys %vdisknames) {
		# the size that particular vdisk occupies on each host that its on
		if( !defined($vdisks{$vdisk}{'size'}) or !defined($vdisknames{$vdisk}{'numhosts'}) ){ print $exceptions "$vdisk has error-producing size or number of hosts.\n\n"; }
		$vdisks{$vdisk}{'size'} = $vdisks{$vdisk}{'size'} / $vdisknames{$vdisk}{'numhosts'};
	}

	foreach my $host (keys %hosts) {
		foreach my $vdisk ( @{ $hosts{$host} } ) {
        		my $storage = $vdisks{$vdisk}{'storageDev'};
			( defined( $hostStorage{$host}{$storage} ) ) ? ( $hostStorage{$host}{$storage} += $vdisks{$vdisk}{'size'} ) :
			($hostStorage{$host}{$storage} = $vdisks{$vdisk}{'size'});
		}
	}

}

open( my $out, qw(>), "$out_name" );

my $printedStorage = "";
@hostlist = sort keys %hosts;
print $out "Server_Name\tStorage_Device\tStorage_Vol(GB)\tSource\tTier\n";
foreach my $host (@hostlist) {
    foreach my $vdisk ( @{$hosts{$host}} ) {
		my $storage = $vdisks{$vdisk}{'storageDev'};
		my $size = sprintf("%.3f",$hostStorage{$host}{$storage});
		my $tier = $vdisks{$vdisk}{'tier'};

		next if $printedStorage =~ /$storage/;
		$printedStorage = "$printedStorage $storage ";

		print $out "$host\t";
		print $out "$storage\t";
		print $out "$size\t";
		print $out "$svcName\t";
		print $out "$tier\t";
		print $out "\n";

    }
    # print $out "\n"; # uncomment to make CLI output more readable and separated by host
    $printedStorage = "";
}
close($out);

print $exceptions "################################\n";
print $exceptions "#  These vdisks have no hosts\n";
print $exceptions "#       vdisk => size\n";
print $exceptions "#################################\n";
print $exceptions Dumper( \%excepts );
print $exceptions "\n";

close($exceptions);

# debug;
