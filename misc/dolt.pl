: # Use perl
eval 'if [ -x $HOME/bin/findperl.sh ] ; then exec `$HOME/bin/findperl.sh` -S $0 ${1+"$@"};
      elif [ -x /cpm/bin/findperl.sh ] ; then exec `/cpm/bin/findperl.sh` -S $0 ${1+"$@"};
      elif [ -x ./findperl.sh ] ; then exec `./findperl.sh` -S $0 ${1+"$@"};
      fi'
  if $running_under_some_shell;

# require "sys/wait.ph";
#
# Created 03/09/95
# Written by Eric Martin
# rewritten by Jerod Tufte Apr96
# revised by Herry Setiadi Apr98

# dolt will read and parse a command input file and retrieve the data
# specified by the input file.

# Main();
#    sub parseDoltFile (dolt_file, logfile)
#    sub printJobQueue ()
#    sub Launch (job_num, logfile, number_of_iterations, jobs);
#    sub catch_sig ();
#    sub now ()
#    sub CheckTime ()
#    sub CheckStatus (StatusLog)
#    sub switch_eid (effective_uid, effective_gid)
#    sub switch_euid (effective_uid)
#    sub switch_egrpid (effective_grpid)
#    sub switch_rid (real_uid, real_gid)
#    sub switch_ruid (real_uid)
#    sub switch_rgid (real_gid)
#    sub Execute (command <, real_uid, real_gid>)
#    2001-0910 Added support for no restart for days older than yesterday
#    2008-0416 Added dir cammandline option to run all dolts in that dir
#

# Main ();
use POSIX; import POSIX;
# Default values below - Variable intializations
######################################################################
# 25May2004, MNatale
#  chamge default permissions on created files to allow other users
#  to run dolt jobs and modify the dolt status files
#    from: rwxrwxr-x
#    to: rwxrwxrwx
######################################################################
# 10Jan2007, MNatale
#  modified queued job handling test - changed:
#   @queued=grep(/\S+_$$_PID\S+_is_queued$/, readdir(MPLDIR));
#  to:
#   @queued=grep(/\S+_($$)_PID\S+_is_queued$/, readdir(MPLDIR));
######################################################################
# 18Jan2007, MNatale
#  replaced queued job handling:
#    opendir(MPLDIR,"$mpldir"); 
#    @queued=grep(/\S+_($$)_PID\S+_is_queued$/, readdir(MPLDIR));
#    $diffmpl=$diffmpl>scalar(@queued)? scalar(@queued): $diffmpl;
#    closedir(MPLDIR);
#  with:
#    $qpid='*_'.$$.'_PID*_is_queued' ;
#    @queued=`/bin/ls -lrt $mpldir/$qpid | awk '{print \$NF}'`;
#  so that the oldest queued jobs would be thawed first.
######################################################################
# 21Jan2007, MNatale
#  added the following line back into the queued job handling:
#    $diffmpl=$diffmpl>scalar(@queued)? scalar(@queued): $diffmpl;
#  also added test to make sure diffmpl was >= 0
######################################################################
# 18Jul2007, PGossard
#  added a No Queued Jobs feature, those jobs listed in 
#  $batchdir/.pasqjobs don't queue, just run;
#  added $mpldir/.MPL.lock file to synchronize listing of the MPL dir 
#  during job ExecOrQueue, it adds files named *is_pending to the dir
#  though briefly;
######################################################################
# 20Jul2007, PGossard
#  .MPL.lock file is working w/ pending files being created, but
#  still had 13 jobs running at once when mpl=5 so reopened the code.
#  found errors in mv'ing MPL files too.
#   - write 2>/dev/null in parent's is_queued ls, chomp @queued,
#   and fix path names of mv'd MPL files.
#  - moved the rm $remove_thaw_entry to ExecOrQueue from thaw_job closing
#  a small hole.   
#  - And, undef'd $been_to_thaw in so subsequent steps of a thawed 
#  job might queue.
######################################################################
# 26Jul2007, PGossard
#  - .MPL.lock.$ENV{'MAMA'} - a lock file per dolt parent
#  - mpldir's open and close placed in MPL.lock code block
#  - Quitting jobs exit 2 which is interpretted to be 512 so when
#  child is reaped with status=512 we don't THAW any jobs.
#  - more logging changes
######################################################################
# 07Apr2008, PGossard
# - added this comment for another $|=1 addition for dtree to work
#   without which dtree doesn't report all jobs completely.
######################################################################
# 16Apr2008, MathewHK
# - added -dir option to include all dolt files in that dir to run
#   instead of specifying all the dolts in cammandline.
######################################################################
# In the input block of .dolt job files, we can use logical express-
# ions within the same line. Each line is considered as a pre-codition 
# for that dolt job. 
# MathewHK-30Apr2008: backslash(\) can be used in input block as line 
# continuation symbol.
######################################################################
# 16Feb2010, MNatale
#  added new date variable at request of Dave Heald: $yyyy_mm_dd
#  which resolves to something like 2010_02_15 (based on dayback)
######################################################################
# 19Feb2010, MNatale
#  fixed handling of the new date variable added on 16Feb2010
######################################################################
# 23Jul2010, MNatale
#  - coverted all occurences of 'chop' to 'chomp'
#  - added new date variables at request of Carmen Spohn:
#	$yyyy	resolves to 4 digit year based on $dayback
#	$m1yyyy	resolves to 4 digit year based on $daybm1
######################################################################

#umask 002;
umask 000;

$argcnt = $#ARGV + 1;
if ($argcnt < 1) { 
  die ("\nno args try dolt -usage\n");
}

######################################################################
# figure out the level (cert/prod/case)
######################################################################
$level=&getlvl;

$Kludge = "false";
$cpmgid = 211;      #cpm's Group ID for rcp'd files.
$dayback = 1;                   # =yesterday
$iterations = 18;
$time = 600;

######################################################################
# Added 02/15/99 - MN
######################################################################
open STDIN, "< /dev/null";

$path = "/bin:/usr/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/ucb:.:/opt/ssh/bin";

if ( $level eq "cert" || $level eq "prod" ) {
 $outbase = "/cpm/$level";
 $codebase = "/cpm/$level/sas";
 $doltdir = "/cpm/dolt";
 $doltjob = "jobs";
 $doltlog = "log";
 $doltstat = "stat";
 $doltMPL = "MPL";
 $path = $path.":.:/cpm/bin:/home/cpm/public:/home/cpm/bin";
}
else {
 $outbase = "/tpf106/cpm";
 $codebase = "/project/tpf49/data3/cpm/sas/prod";
 $doltdir = "/cgti/bin";
 $doltjob = "doltfiles";
 $doltlog = "doltlog";
 $doltstat = "doltstat";
 $doltMPL = "doltMPL";
 $path = $path.":.:/tpf106/cpm/bin:/cgti/bin:/serve/bin:/nfs/sup01/cpm/bin:/nfs/sup01/cpm/public";
}

$inbase = "/server/data";

$TerminateDate = ""; $terminate = "";
$TDay = ""; $TMo = ""; $TYr = "";
$THour = ""; $TMin = ""; $TSec = ""; $TPrd = "";
$FileName = " ";

$restart = 0;
$TotalJob = 0;
@inputfiles;
@inputfiles1;
@InputDolt;
@StatFiles;

$NoSwitch = 1;                  # Do NOT Switch the euid during process

@id;
@gid;
@rootgid = split (' ', $));
@dirlist;
$dlist = "";
######################################################################
# Added 02/16/99 - MN
######################################################################
# Get the real uid and parent process id
$parent = getppid;
$real = $$;
# If the process's parent is init and the real uid is root force restart flag
($parent == 1) && ($real == 0) && ($restart = 1);

# Initialize the effective uid and effective gid
$root = $>;                       # Capture the euid of the user
$rootgrpid = $rootgid[0];         # Capture the grpid of the user

$euid = $root;
$grpid = $rootgrpid;

$SIG{INT} = 'catch_sig';          # Catch interupt, then kill all processes
$SIG{HUP} = 'catch_sig';
$SIG{THAW} = 'thaw_job';
$| = 1;                           # Flush buffer so that children do not reprint    

# All the possible options
 while ($_ = shift) {
	/^-v$/ && die("Version 5.2, multi-dolt, 7 days of logs");
	print STDOUT "arg:$_\n";
	/^-usage/ && die("Usage:  dolt <command input file>\n",
					 "             [-doltdir <base dolt directory>] \n",
                                         "             [-dir <list of dolt directory under basedolt dir - comma seperated list>] \n",
					 "             [-logdir <log_directory>] \n",
					 "             [-nokludge]\n",
					 "             [-d <dayback>]\n",
					 "             [-i <iterations>]\n",
					 "             [-t <time>]\n",
					 "             [-statdir <Status_log_dir>]\n",
					 "             [-MPLdir <MPL_dir>]\n",
					 "             [-code <code_base_dir>]\n",
					 "             [-ob <out_base_dir>]\n",
					 "             [-ib <in_base_dir>]\n",
					 "             [-path <path>]\n",
					 "             [-terminate <MM/DD/YYYY (HH:MM:SS | HH:MM | HH)[AM | PM]>]\n",
					 "             [-acl <aclscript>\n",
					 "             [-restart]\n",
					 "             [-switch]\n\n",
					 "   eg:  dolt /usr/test.dolt -logdir /usr/doltlog -nokludge -d 2\n",
					 "        -statdir /usr/doltstatdir -i 100 -t 300 -terminate 05/04/98 09:00:00PM\n\n");
	
	/^-logdir/ && ($logdir = shift) && next;
	/^-doltdir/ && ($doltdir = shift) && next;
        /^-dir/ && ($dlist = shift) && next; 
	/^-terminate/ && ($TerminateDate = shift) && ($terminate = shift) && next;
	/^-statdir/ && ($StatusDir = shift) && next;
	/^-code/ && ($codebase = shift) && next;
        /^-acl/ && ($aclscript = shift) && next;
	/^-path/ && ($path = shift) && next;
	/^-d$/ && ((($dayback = shift) && next) || (($dayback==0) && next)) ;
	/^-i/ && ($iterations = shift) && next;
	/^-t/ && ($time = shift) && next;
	/^-nokludge/ && ($Kludge = "false") && next;
	/^-kludge/ && ($Kludge = "true") && next;
	/^-ob/ && ($outbase = shift) && next;
	/^-ib/ && ($inbase = shift) && next;
	/^-restart/ && ($restart = 1) && next;
	/^-switch/ && ($NoSwitch = 0) && next;
	push (@inputfiles, $_);
}
@dirlist = split(',', $dlist);
$ENV{'PATH'} = "$path:$codebase/sas/autoexec";
$dayofweek = `dateback $dayback %a`;
$batchdir = "/cpm/utils/batch";
chomp($dayofweek);
$ENV{'DAYBACK'}=$dayback;
$ENV{'MAMA'} = $$;                      #MAMA will be used by children to identify her.
$ENV{'DOLTDIR'} = $doltdir;             #needed for checkjob command run by children.
$logdir = "$doltdir/$doltlog/$dayofweek";
$mpldir = "$doltdir/$doltMPL";
$StatusDir = "$doltdir/$doltstat/$dayofweek";
($_=`ls -d $mpldir/.MPL=*`) && /^\S+=(\d+)/ && ($mpl=$1);

# define the date variables for substitutions
$yyyymmdd = `dateback $dayback %Y%m%d`; 	chomp($yyyymmdd);
$yymmdd = `dateback $dayback %y%m%d`;		chomp($yymmdd);
$monthofyear = `dateback $dayback %h`;		chomp($monthofyear);
$mm_dd = `dateback $dayback %m/%d`;		chomp($mm_dd);
$mmddyyyy = `dateback $dayback`;		chomp($mmddyyyy);
$mmddyy = `dateback $dayback %m%d%y`;		chomp($mmddyy);
$yyyy_mm_dd = `dateback $dayback %Y_%m_%d`;	chomp($yyyy_mm_dd);
$yyyy = `dateback $dayback %Y`;			chomp($yyyy);

($Kludge eq "true") && ($dayback++) && print STDOUT " ** Kludging **\n";
$daybm1 = $dayback-1;     #for use in doltfiles and modtime
$daybp1 = $dayback+1;     #for use in doltfiles and modtime
$daybp6 = $dayback+5;     #for use in doltfiles and modtime

$m1dayofweek = `dateback $daybm1 %a`;	chomp($m1dayofweek);
$m1mmddyy = `dateback $daybm1 %m%d%y`;	chomp($m1mmddyy);
$m1mmddyyyy = `dateback $daybm1`;	chomp($m1mmddyyyy);
$m1yyyy = `dateback $daybm1 %Y`;	chomp($m1yyyy);


# Initialize the directories
($_ = $logdir) && (!(/^(\S+)\/$/)) && ($logdir .= "/");
($_ = $StatusDir) && (!(/^(\S+)\/$/)) && ($StatusDir .= "/") || ((!$StatusDir) && ($StatusDir = $logdir));

## Read DoltJobs from $doltdir/@dirlist directory if specified.
if(scalar @dirlist > 0) {
   foreach $djob (@dirlist) {
      opendir(DOLTJOBS,"$doltdir/$djob");
      @inputfiles1 = grep(/dolt$/,readdir(DOLTJOBS));
      closedir(DOLTJOBS);
      for ($i = 0; $i <= $#inputfiles1; $i++) {
         $inputfiles1[$i] = "$doltdir/$djob/" . $inputfiles1[$i];  #must make reference absolute.
      }
      push(@inputfiles, @inputfiles1);
   }
}
else {
## Read DoltJobs from $doltdir/$doltjob directory unless otherwise specified.
   if (!@inputfiles) {
      opendir(DOLTJOBS,"$doltdir/$doltjob");
      @inputfiles = grep(/dolt$/,readdir(DOLTJOBS));
      closedir(DOLTJOBS);
      for ($i = 0; $i <= $#inputfiles; $i++) {
         $inputfiles[$i] = "$doltdir/$doltjob/" . $inputfiles[$i];  #must make reference absolute.
      }
   }
}
###No Queue Jobs read in next
open (NFILE, "$batchdir/.pasqjobs")||print ("can't open file $batchdir/.pasqjobs\n") && (return 0);
@noqueuejobs = <NFILE>;
chomp(@noqueuejobs);
close(NFILE);


# Time initialization, if using -terminate options
if ($_ = $TerminateDate) {
	if (/^\s*(\d+)\/(\d+)\/(\d+)\s*$/) {
		($TMo, $TDay, $TYr) = ($1, $2, $3);
		if ( $TYr < 100 ) {
			$TYr += 2000 ;
		}
		$_ = $terminate;
		if (/^\s*(\d+)\:?(\d*)\:?(\d*)\s*(\w*)\s*$/) {
			tr/a-z/A-Z/;
			($THour, $TMin, $TSec, $TPrd) = ($1, $2, $3, $4);
		}
		if (!$THour) {
			$terminate = "";
			print STDOUT "Invalid termination setting. Ignoring\n";
		}
		else {
			($TMin) || ($TMin = "00");              # Initialize minutes to 00
			($TSec) ||	($TSec = "00");		        # Initialize seconds to 0
			($TPrd) || ($TPrd = "AM");              # Initialize to AM
			($TPrd eq "PM") && ($THour <= 12) && 
			($THour += 12);                         # Make military time to compare
			$terminate = 1;
		}
		(&CheckTime) || (die "Has passed termination point - $TMo/$TDay/$TYr $THour:$TMin:$TSec. Dolt is quitting.\n\n");
	}
	else {
		print STDOUT "Invalid termination date. Ignoring\n";
		$terminate = "";
	}
}

@inputfiles || die ("No command input file specified:  fatal error\n");
$QueueLog = "$logdir" . "jobQueue_$ENV{'MAMA'}.log";
open ($QueueLog, "> $QueueLog");
close ($QueueLog);

if (!$restart) {
	opendir (STATUS, "$StatusDir");
	@StatFiles = readdir (STATUS);
	closedir (STATUS);
}

# Parse each dolt file and record all the information and jobs listed
foreach $file (@inputfiles) {

	$_ = $file;
	if ((/^.*\/(\S+)\.dolt\s*$/) || (/^(\S+)\.dolt\s*/)) {
		$filename = $1;
		$logfile = "$logdir" . "$1" . "_" . $ENV{'MAMA'} . ".log";
		$StatusLog = "$1";
	}
	else {
		#print STDOUT "Invalid input file. Must be file.dolt\n";
		next;
	}

	# Check status file (Is it more than 1 day old)
	if ($restart || &CheckStatus ($StatusLog)) {
		$StatusLog = "$StatusDir" . "$StatusLog" . "_*.status=";
		#unless (fork ()) {
			$command = "rm $StatusLog" . "*";
			# Switch back to root before executing command
			($NoSwitch || &switch_eid ($root, $rootgrpid));
			$| = 1;
			system ($command);
		#}
		$PreviousQueue = scalar (@jobqueue);
		&parseDoltFile ($file, $logfile);
		$JobEntered = scalar (@jobqueue) - $PreviousQueue;
		open ($logfile, ">> $logfile");
		print $logfile &now, "Entering ", $JobEntered, " jobs in queue\n";
		print $logfile "*************************\n";
		print $logfile "     ", scalar (@jobqueue), "job(s) is now in queue\n\n";
		close ($logfile);
		local ($i) = 0;
		for ($i = 0; $i < $JobEntered; $i++) {
			$InputDolt[$TotalJob] = $filename;
			$id[$TotalJob] = $euid;
			$gid[$TotalJob] = $grpid;
			$TotalJob++;
		}
	}
	else {           # This dolt file has been processed at today
		open ($QueueLog, ">> $QueueLog");
		print $QueueLog &now, "$file has run since $daybm1 days ago. Ignoring. Use -restart to override.\n";
		print STDOUT &now, "$file has run since $daybm1 days ago. Ignoring. Use -restart to override.\n";
		close ($QueueLog);
		next;
	}
}

(scalar (@jobqueue) == 0) || (&printJobQueue);

# Switch back to root to gain all access
($NoSwitch || &switch_eid ($root, $rootgrpid));

local ($k) = 0;
local ($NumActivePids) = 0;
for ($k = 0; $k < scalar (@jobqueue); $k++) {
		unless ($pid = fork) {  # Make sure parent can quit without having to wait children
			#sleep 1 until getppid == 1;
                        print "forked $$ for $InputDolt[$k].\n";
			&Launch ($k, $InputDolt[$k], $iterations, $jobqueue[$k]);
		}
$NumActivePids++;
  print &now, "$NumActivePids after increment for $InputDolt[$k] with pid $pid\n";
	      }
open ($QueueLog, ">> $QueueLog");
select $QueueLog;
$|=1;
until ($NumActivePids < 1) {
# Parent has finished. Quit parent without killing children
 if ($pid = POSIX::waitpid(-1, &POSIX::WEXITSTATUS)) {
  $childstatus=$?;
  $NumActivePids--;
  print  $QueueLog &now, "$NumActivePids Pids still active after decrement for $pid which exited $childstatus.\n";
 if ($childstatus != 512) {
  $prmpl=$mpl;
  ($_=`ls -d $mpldir/.MPL=*`) && /^\S+=(\d+)/ && ($mpl=$1);
  $diffmpl=$mpl-$prmpl > 0 ? $mpl-$prmpl+1 : $prmpl-$mpl+1;
  $qpid='*_'.$$.'_PID*_is_queued' ;
  @queued=`/bin/ls -lrt $mpldir/$qpid 2>/dev/null|awk '{print \$NF}'`;
  chomp(@queued);
  $diffmpl=$diffmpl>scalar(@queued)? scalar(@queued): $diffmpl;
  ( $diffmpl < 0 ) && ( $diffmpl = 0 ) ;
#  opendir(MPLDIR,"$mpldir"); 
#  @queued=grep(/\S+_($$)_PID\S+_is_queued$/, readdir(MPLDIR));
#  $diffmpl=$diffmpl>scalar(@queued)? scalar(@queued): $diffmpl;
#  closedir(MPLDIR);
  for ($k = 0; $k < $diffmpl; $k++) {
      ($NoSwitch || &switch_eid ($root, $rootgrpid));
      print $QueueLog &now, "que{$k} is $queued[$k]\n";
      ($pid) = $queued[$k] =~ /^.*_PID=(\d+)\..*/;
      ($thawname = $queued[$k]) =~ s/queued/thawed/;
      print $QueueLog &now, "que{$k} is $queued[$k]\n";
      $command="mv $queued[$k] $thawname";
      print $QueueLog &now, "moving $command\n";
      system("$command");
      $status = kill 'THAW', $pid;
      print $QueueLog &now, "kill 'THAW' $pid status= $status, $_.\n";
  }
 }
 } # childstatus==512 implies we Quitt the jobs w/o ever running;
}
close($QueueLog);

# ******************************************************************************
sub parseDoltFile {	 #$filename

	local ($file, $logfile) = @_;
	local ($inputs , $output , $events , $flags, $euid, $grpid);
	local (@sts);
	local ($state);

	(@sts = stat ($file)) || (print "parseDoltFile can't stat dolt file $file\n") && (return 0);
	$euid = $sts[4];
	$grpid = $sts[5];

	($NoSwitch || &switch_eid ($euid, $grpid));

 	open ($logfile, "> $logfile");
	open (DFILE, $file) || open (DFILE, $doltdir . $file) || print ("parseDoltFile can't open file $file\n") && (return 0);
	local (@line) = <DFILE>;
	close DFILE;
	chomp @line;
	
	print $logfile &now, "parsing $file (",scalar (@line), " lines)\n";
	local ($l) = 0;
	for ($l = 0; $l <= $#line; $l++){
		$_ = $line[$l];
       	s /(.*)\s*\#.*/\1/;		# getting rid of comments
		s /^\s+//;				# strip leading space
		s /\s+$//;				# strip trailing space
		/^\s*\n?$/ && next;     # skip blank lines
		s /\$yymmdd/$yymmdd/g;	# variable substitutions
		s /\$yyyymmdd/$yyyymmdd/g;
		s /\$yyyy_mm_dd/$yyyy_mm_dd/g;
		s /\$mmddyyyy/$mmddyyyy/g;
		s /\$mmddyy/$mmddyy/g;
		s /\$yyyy/$yyyy/g;
		s /\$m1mmddyyyy/$m1mmddyyyy/g;
		s /\$m1mmddyy/$m1mmddyy/g;
		s /\$m1yyyy/$m1yyyy/g;
		s /\$dayofweek/$dayofweek/g;
		s /\$daybm1/$daybm1/g;
		s /\$dayback/$dayback/g;
		s /\$daybp1/$daybp1/g;
		s /\$daybp6/$daybp6/g;
		s /\$monthofyear/$monthofyear/g;
		s /\$mm_dd/$mm_dd/g;
		s /\$inbase/$inbase/g;
		s /\$outbase/$outbase/g;
		s /\$codebase/$codebase/g;
		if (/^\s*job(\d+)?:\s*\{(.*)/) {
			$state = "job";
			$output = "undef";
			$flags = "";
			$inputs = [];
			$events = [];
			if ($2 ne ""){
				print $logfile &now, "job $1 parms = $2\n";
				if ($2 =~ /runeachtime/){
					$flags .= "r";
				}
			}
		}
		elsif (/^\s*input:\s*\{/) {
			$state = "input";
		}
		elsif (/^\s*output:\s*\{/) {
			$state = "output";
		}
		elsif (/^\s*\}/){
			if ($state eq "output") {
				$state = "event";
			}
			elsif ($state eq "event") {
			       $state = "";
			       $file =~ s /\.dolt//;
	                #push (@$inputs, "modtime -cd $dayback $StatusDirp1/$file" . "_" . scalar(@$events) . "_of_" . scalar(@$events) . ".status=*");
				$rval = [$inputs , $output , $events , $flags, $euid, $grpid];
				if ((scalar (@$inputs) > 0) && 
					(scalar (@$events) > 0)) {
					push (@jobqueue, $rval);
				}
				else {
					print ("error parsing $file\n");
					return 0;
				}
			}
			elsif ($state eq "") {
		#		$state = "job";   #commented for error block May4/2001
			        print ("error parsing $file.  Extra }.\n");
			        return 0;
			}
		}
		else {
			if ($state eq "input") {
				s/\[/\\\[/g;
				s/\]/\\\]/g;
                                if (scalar (@$inputs) > 0) { 
                                    my $new_input = pop(@$inputs);
                                    if($new_input =~ m/\\$/) {
                                       chomp($new_input); 
                                       my $concat_in = $new_input . ' ' . $_;
                                       push (@$inputs, $concat_in); 
                                    }
                                    else { 
                                      push (@$inputs, $new_input);
                                      push (@$inputs, $_);
                                    }
                                } 
                                else { push (@$inputs, $_); }
			}
			elsif ($state eq "output") {
				$output = $_;
			}
			elsif ($state eq "event") {
				push (@$events, $_);
			}
			else {
				print $logfile &now, "disregarding line $_\n";
			}
		}
	}
	if ((scalar (@$inputs) == 0) || 
		(scalar (@$events) == 0) || 
		($output eq "")) {
		print $logfile &now,"ERROR parsing file $_[0]\n";
	}
	else {
		print $logfile &now ,"done parsing\n";
	}
	close ($logfile);
}

# **************************************************************************
sub printJobQueue {

	local ($j) = 0;

	open ($QueueLog, ">> $QueueLog");
	print $QueueLog &now, "***************************\n                  ", scalar(@jobqueue)," job(s) remaining in queue\n\n";

	for ($j = 0; $j <= $#jobqueue; $j++){
		$logfile = "$logdir" . "$InputDolt[$j]" . "_" . $ENV{'MAMA'} . ".log";
		local ($jobref) = $jobqueue[$j];
		local ($inref, $output, $evref, $flags, $euid, $grpid) = @$jobref;
		open ($logfile, ">> $logfile");
		print $QueueLog &now, "job ",1+$j,":\n";
		print $logfile &now, "job ", 1+$j,":\n";

		foreach $_ (@$inref){
			print $QueueLog &now, "input:$_\n";
			print $logfile &now, "input:$_\n";
		}
		print $QueueLog &now, "output:$output\n";
		print $logfile &now, "output:$output\n";

		foreach $_ (@$evref){
			print $QueueLog &now, "event:$_\n";
			print $logfile &now, "event:$_\n";
		}
		print $QueueLog &now, "flags:$flags\n\n";
		print $logfile &now, "flags:$flags\n\n";
		close $logfile;
	}
	print $QueueLog &now, "*****************************\n\n";
	close ($QueueLog);
}


# *********************************************************************
sub Launch {

	local ($ref, $filename, $iteration, $jobref) = @_;
	local ($inref, $output, $evref, $flags, $uid, $gid) = @$jobref;
	$| = 1;

	($NoSwitch || &switch_rid ($uid, $gid));
	while ((scalar (@$inref) > 0) && ($iteration-- > 0)) {

		local ($runjobs, $numtests, $runeachtime, $itworked, $j) = (0,0,0,1,0);
		local ($test, $job);
		local ($starttime) = time;

		if ((!$terminate) || (&CheckTime)) {
			$logfile = "$logdir" . "$filename" . "_" . $ENV{'MAMA'} . ".log";
			$StatusLog = "$StatusDir" . "${filename}_" .  $ENV{'MAMA'} ;
			open ($logfile, ">> $logfile");
                        select $logfile; $| = 1;
			print $logfile "\n", &now, "Pulling job ", $ref+1, " off queue\n";
			($flags =~ /r/) && ($runeachtime = 1) || ($runeachtime = 0);
			print $logfile &now, $ref+1, ": ", $numtests = scalar (@$inref), " test(s) remaining\n";
			for ($runjobs = 0, $j = 0; $j < $numtests; $j++) {
				($test = shift (@$inref)) || next;
				print $logfile &now, "\ttrying: $test\n";
				$itworked = 1;
				system ("$test") && ($itworked = 0);
		if (($test =~ /^chkdate/) && ($itworked == 0)) {
			print $logfile &now, "chkdate says we don't run today. Quitting.\n";
			exit 2
			}
		######################################################################
		# Added 02/15/99 - MN
		######################################################################
		if (($test =~ /dychk/) && ($itworked == 0)) {
			print $logfile &now, "dychk says we don't run today. Quitting.\n";
			exit 2
			}
		######################################################################
		# Added 07/30/01 - MN
		######################################################################
		if (($test =~ /day_check/) && ($itworked == 0)) {
			print $logfile &now, "day_check says we don't run today. Quitting.\n";
			exit 2
			}
		######################################################################
		# Added 12/17/01 - MN
		######################################################################
		if (($test =~ /dow_check/) && ($itworked == 0)) {
			print $logfile &now, "dow_check says we don't run today. Quitting.\n";
			exit 2
			}


		if ($test =~ /^rcp (\S+)\s+(\S+)/){
		  $file1=$1;$file2=$2;
		  print $logfile &now, "rcp:: $file1 -> $file2\n";
		  if (-e "$file2"){
		    print $logfile &now, "and it's really there.\n";
		    print $logfile &now, "chowning to group cpm.\n";
		    chown $>,$cpmgid, "$file2";
                    if (defined($aclscript)){
                     print $logfile &now, "setting ACL's according to script $acls cript.\n";
                           system("$aclscript $file2");
                    }

		  } else {
 		    print $logfile &now, "doesn't seem to be really there. Pushing back on jobs list.\n";
                    print $logfile &now, "And it failed.\n";
		    $itworked=0;
 		  }
		}

				if ($itworked) {
					$runjobs++;
					print $logfile &now, "\tit worked.\n";
				}
				else {
					print $logfile &now, "\tit failed.\n";
					push (@$inref, $test);
				}
			      }
		      }
		else {
			print $logfile "Time has expired before pulling job ", $ref+1, "\n";
			close ($logfile);
			die ("Time has expired\n");
		}

		if (($runjobs && $runeachtime) || (scalar (@$inref) == 0)) {
			print $logfile &now, "Queueing jobs\n";
			local ($k) = 0;
			foreach $job (@$evref) {
				print $logfile &now, "\t$job\n";
				#close ($logfile);
				#unless (fork ()) {
				#	unless (fork ()) {
				#		sleep 1 until getppid == 1;
				$k++;
				$events=scalar(@$evref);
				$StatusLogOut = "$StatusLog"."_${k}_of_${events}.status=";
				$command = "$job" . "; touch $StatusLogOut" . '$?';
			   	&ExecOrQueue ($filename,$command,$k,scalar(@$evref));
				#	}
				#	exit (0);
				#}
				#wait;
			      }
		}
		if (scalar (@$inref)) {
			print $logfile &now, "job ", $ref+1, ": ", scalar (@$inref), " test(s) failed. Putting job ", $ref+1, " back on queue\n";
			local ($delay) = $time - (time - $starttime);
			($delay < 0) && ($delay = 10);  # Min 10 sec delay
			open ($QueueLog, ">> $QueueLog");

			print $QueueLog &now, "job ", $ref+1, ": ", scalar (@$inref), " test(s) failed. Putting job ", $ref+1, " back on queue\n";

			foreach $_ (@$inref){
				print $QueueLog &now, "input:$_\n";
				print $logfile &now, "input:$_\n";
			}
			print $QueueLog &now, "output:$output\n";
			print $logfile &now, "output:$output\n";
			
			foreach $_ (@$evref){
				print $QueueLog &now, "event:$_\n";
				print $logfile &now, "event:$_\n";
			}
			print $QueueLog &now, "flags:$flags\n";
			
			print $QueueLog &now, "sleeping for $delay sec\n\n";
			print $logfile &now, "sleeping for $delay sec\n\n";
			close ($QueueLog);
			sleep ($delay);
		      }
		# For a job that is run each time, need to repeat the loop. Do not terminate
		# a job that is run each time, until all inputs has worked or time has expired
		elsif (scalar (@$inref) == 0) {
			close ($logfile);
			exit (0);
		}
	      }
	if ((scalar (@$inref)) && (!$runeachtime) && ($iteration > 0)) {
	  print $logfile &now, "Queueing jobs\n";
	  local ($k) = 0;
		foreach $job (@$evref) {
		  $k++;
		  $events=scalar(@$evref);
		  $StatusLogOut = "$StatusLog"."_${k}_of_${events}.status=";
		  $command = "$job" . "; touch $StatusLogOut" . '$?';
		  &ExecOrQueue ($filename,$command,$k,scalar(@$evref));
		}
		exit (0);
	}
	exit (0);
      }

# ********************************************************************
sub ExecOrQueue {
        local ($running);
	local ($mpl);
	local ($notqueueing) = 0;
	local ($runfile);
	local ($pendfile);
	local ($filename,$command,$event,$events) = @_;
        
	($_=`ls -d $mpldir/.MPL=*`) && /^\S+=(\d+)/ && ($mpl=$1);
        ##check if the job will not be made to queue
        foreach $noqj (@noqueuejobs) { ($noqj eq $filename) && ($notqueueing = 1) && (last);}
         ###Get MPL lockfile before listing MPL dir, retry in 2secs, block forever
          system("lockfile -1 $mpldir/.MPL.lock.$ENV{'MAMA'}");
	   opendir(MPLDIR,"$mpldir");
             $running=grep(/\S+_$ENV{'MAMA'}_PID\S+_is_running$/, readdir(MPLDIR));
	     $running+=grep(/\S+_$ENV{'MAMA'}_PID\S+_is_thawed$/, readdir(MPLDIR));
	     $running+=grep(/\S+_$ENV{'MAMA'}_PID\S+_is_pending$/, readdir(MPLDIR));
	     $pendfile=$filename . "_" . $ENV{'MAMA'} . "_PID=" .$$. ".${event}_of_${events}_is_pending";
	     system("touch $mpldir/$pendfile");
	   closedir(MPLDIR);
          system("rm -f $mpldir/.MPL.lock.$ENV{'MAMA'}");
         ###MPL lockfile now cleared
	select $logfile;
	$|=1;
	if ($running<$mpl | defined($been_to_thaw_job) | $notqueueing) { 
	  $runfile=$filename . "_" . $ENV{'MAMA'} . "_PID=" .$$. ".${event}_of_${events}_is_running";	
                if (defined($been_to_thaw_job)) {
                     !undef($been_to_thaw_job); 
                     system("rm $remove_thaw_entry");
                }
		system("touch $mpldir/$runfile");
                system("rm $mpldir/$pendfile");
          
		print $logfile &now,"$running jobs running,  running job - $runfile.\n";
                ($running>=$mpl) && ($notqueueing) && 
        (print $logfile &now, "This job wasn't queued because it is listed in $batchdir/.pasqjobs.\n");
		&Execute($command);
	} 
	else {
          $queuefile=$filename . "_" . $ENV{'MAMA'} ."_PID=".$$. ".${event}_of_${events}_is_queued";
		system("touch $mpldir/$queuefile");
                system("rm $mpldir/$pendfile");
		print $logfile &now, "$running jobs running\>=mpl=$mpl, queueing - $queuefile.\n";
		sleep;
	      }
      }
# **************************************************************************
sub Execute {
	
	local ($command, $uid, $gid) = @_;
        local $user = $system = $cuser = $csystem = 0;

	($NoSwitch || ($uid && &switch_rid ($uid, $gid)));
	$| = 1;
	system ($command);
	print $logfile &now, "Removing ${filename}_$ENV{'MAMA'}_PID=${$}.${event}_of_${events}_is_running\n";
        system("rm $mpldir/*_$ENV{'MAMA'}_PID=${$}*_is_running");
	($user,$system,$cuser,$csystem) = times;
	print $logfile &now, "user cpu = $user\tsystem cpu = $system\tchild user cpu = $cuser\tchild system cpu = $csystem\n\n" ;
	if ($event == $events) {close ($logfile)};
     }
# ********************************************************************
sub catch_sig {
    $pgrp=getpgrp $$;
    kill 9, $pgrp;
}

# ********************************************************************

sub thaw_job {
  $been_to_thaw_job=1;
  $remove_thaw_entry="$mpldir/${filename}_$ENV{'MAMA'}_PID=${$}*_is_*";
  $remove_thaw_entry=`ls $remove_thaw_entry`;
  chomp($remove_thaw_entry);
  print $logfile &now, "We're in thaw_job with $remove_thaw_entry.\n";
  if (grep(/is_running/,$remove_thaw_entry)) {return;}
  $_ = $remove_thaw_entry;
  ($event,$events) =~ /.*_PID=\d+\.(\d+)_of_(\d+)_\S+$/;
  #system("rm $remove_thaw_entry");
  #print $logfile &now, "Removing Thaw Entry $remove_thaw_entry, rc=$?.\n";
  &ExecOrQueue($filename,$command,$event,$events);
}

# *************************************************************************
sub now {

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	$mon += 1;
	$year += 1900;
	(length($sec) == 1) && ($sec = "0".$sec);
	(length($min) == 1) && ($min = "0".$min);
	(length($hour) == 1) && ($hour = "0".$hour);
	(length($mday) == 1) && ($mday = "0".$mday);
	(length($mon) == 1) && ($mon = "0".$mon);
	$now ="$year/$mon/$mday $hour:$min:$sec ";
}

# *************************************************************************
sub CheckTime {

	local ($retval) = 0;

#	print STDOUT "Checking Time !!\n";
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	$mon += 1;
	$year += 1900;

	if (($TYr > $year) || 
		(($TYr == $year) && ($TMo > $mon)) || 
		(($TYr == $year) && ($TMo == $mon) && ($TDay > $mday)) || 
		(($TYr == $year) && ($TMo == $mon) && ($TDay == $mday) && ($THour > $hour)) || 
		(($TYr == $year) && ($TMo == $mon) && ($TDay == $mday) && ($THour == $hour) && ($TMin > $min)) || 
		(($TYr == $year) && ($TMo == $mon) && ($TDay == $mday) && ($THour == $hour) && ($TMin == $min) && ($TSec > $sec))) {
		$retval = 1;
	}

	$retval;
}

# **************************************************************************
sub CheckStatus {

	local ($StatusLog) = $_[0];
	# 14400 = seconds difference between GMT and EDT
	local ($current_time) = $^T - 14400;
	local ($True) = 1;

	if (scalar (@StatFiles)) {

		local ($i = 0);
                #Added support for no restart for days older than yesterday 09/10/01
                local ($TimeCheck) = $daybm1*(24*60*60) + ($current_time % (24*60*60));

		while (($_ = $StatFiles[$i]) && $True) {
			if ((/(.*)_\d+_(\d+)_of_(\d+)\.status=\d+$/) && 
				($1 eq $StatusLog) && ($2 == $3)) {
				local ($StatusFile) = "$StatusDir" . "$StatFiles[$i]";
				@filetime = stat ($StatusFile);
				(($current_time - ($filetime[9] - 14400)) > $TimeCheck) || ($True = 0);
			}
			$i++;
		}
	}
	$True;
}

# ************************************************************************
sub switch_eid {  # Switch the effective uid and effective gid

	local ($uid, $gid) = @_;
	local ($success) = 1;

	&switch_egrpid ($gid);
	(&switch_euid ($uid)) || ($success = 0);
	$success;
}

# *********************************************************************
sub switch_euid {   # Switch the effective user id

	local ($euid) = $_[0];
	local ($ret_val) = 1;

	$> = $euid;
	($> == $euid) || ($ret_val = 0);
	$ret_val;
}

# **********************************************************************
sub switch_egrpid {  # Switch the effective group id

	local ($egid) = $_[0];

	($_ = $)) && (s /^\s*\d+\s+(.+)$/$1/);
	$) = "$egid $_";
}

# ************************************************************************
sub switch_rid {  # Switch the real uid and effective gid

	local ($ruid, $rgid) = @_;

	&switch_eid ($root, $rootgrpid);
	&switch_rgrpid ($rgid);
	&switch_ruid ($ruid);
}
# *********************************************************************
sub switch_ruid {   # Switch the real user id

	local ($ruid) = $_[0];

	# Note this is a specific SOLARIS syscall
	syscall (202, $ruid, $ruid);

      }
# **********************************************************************
sub switch_rgrpid {  # Switch the real group id

	local ($rgid) = $_[0];
	local ($Staff_ID) = 10;     # Staff group ID = 10

	# Note this is a specific SOLARIS syscall
	syscall (203, $rgid, $rgid);
	$) = "$rgid $rgid $Staff_ID";
}

##########################################################################
# getlvl - Tries to determin the "LEVEL" (cert/prod/dev) of the server
#    we're running on. First it looks for "/mdc/etc/runLevel", if it
#    doesn't find that it looks for "/usr/tmp/mdc/etc/runLevel", failing
#    that throws it into an attempt to parse the NIS Domain Name and
#    use that.
##########################################################################
sub getlvl
{
  my $LEVEL="";

  ### Check the two locations that the runlevel file should be...
  if ( -f "/mdc/etc/runLevel" ) {
    $LEVEL=`cat /mdc/etc/runLevel`;
  }
  elsif ( -f "/usr/tmp/mdc/etc/runLevel" ) {
   $LEVEL=`cat /usr/tmp/mdc/etc/runLevel`;
  }

  #print "Runlevel is $LEVEL\n";
  ### If its still not set get the domainname and parse that
  if (( -x "/bin/domainname" ) && ( $LEVEL eq "" )) {
    $LEVEL="UNKNOWN";
    $_=`/bin/domainname`;
    #print "NIS Domain is $_\n";
    if ( /cert/ ) { $LEVEL = "cert"; }
    elsif ( /prod/ ) { $LEVEL = "prod"; }
    #print "Extraction results were $LEVEL\n";
  }

  chomp $LEVEL;

  return $LEVEL;
}
