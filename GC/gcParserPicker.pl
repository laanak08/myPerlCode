: # Use perl
eval 'if [ -x /home/cpm/bin/findperl.sh ] ; then exec `/home/cpm/bin/findperl.sh` -S $0 ${1+"$@"}; fi'
  if $running_under_some_shell;

#############################################################################
# Program Name: gcParserPicker.pl
# Purpose:      To choose the right script to read any GC log.
# Author:       Marcelle Bonterre
# Date Created: 10May2013
#
# Input Files:  gcParserPicker.pl [options] gclog.log # Output Files: none. return ouput to STDOUT #
# Usage:		If gc log being read is like:
#					2013-03-24T22:39:17.490-0400: 301715.078: [GC [PSYoungGen: 43168K->288K(43264K)] 130524K->87676K(130688K), 0.0068750 secs] [Times: user=0.03 sys=0.00, real=0.01 secs]
#				Then 
#					use as if fgc_newhsDS.pl
#				Else
#					use as if parseTomcatGCLog.pl
#############################################################################

$file = $ARGV[$#ARGV];
$fileType = "";

foreach (@ARGV){
	unless(-r $file){
		if(/-usage/){
			die "Must supply gc log in order to see usage.\n";
		}
	}
}

open(my $log,"<","$file") or die "could not open $file for reading.";

while(<$log>){
	chomp;
	if( 
	        (/Total\stime\sfor\swhich\sapplication\sthreads\swere\sstopped:\s\d+\.\d+\sseconds/) || 
	        (/Heap\sbefore\sGC\sinvocations/) ||
	        (/Heap\safter\sGC\sinvocations/) 
	 ){
		$fileType = "parseTomcatGCLog";
		print "Running as parseTomcatGCLog.pl\n";
		system("/nfs/apphome02/u1escpm/public/scripts/parseTomcatGCLog.pl",@ARGV);
		last;
	}
}
close($log);
unless($fileType eq "parseTomcatGCLog"){
		print "Running as fgc_newhsDS.pl\n";
		system("/home/cpm/public/fgc_newhsDS.pl",@ARGV);
}
