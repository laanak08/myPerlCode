: # Use perl
eval 'if [ -x /nfs/apphome02/u1escpm/bin/findperl.sh ] ; then exec `/nfs/apphome02/u1escpm/bin/findperl.sh` -S $0 ${1+"$@"}; else if [ -x $HOME/bin/findperl.sh ] ; then exec `$HOME/bin/findperl.sh` -S $0 ${1+"$@"}; fi ; fi'
  if $running_under_some_shell;

#############################################################################
# Program Name: parseTomcatGCLog.pl
# Purpose:      To parse garbage collection logs.
# Author:       Nathaniel Ormbrek
# Date Created: 15NOV2011
# Input Files:  
# Output Files:
#
# Revision History:
#       firstName lastName - DDMMMYYYY - {OTRS Number | Webstar Number}
#               Revision Description
#       Nathaniel Ormbrek - 31JAN2012
#               Modified to pick up new GC format that does not use : to split
#               the gc type from the gc data.
#       Nathaniel Ormbrek - 16FEB2012
#               Updated to add \s* to some of the regular expressions.
#############################################################################

use Time::HiRes qw( time gettimeofday tv_interval ); use Time::Local;

my $GETFLAG = "";
my $Interval = 0;
my $SecondsBack = 0;
my $DirName = "";
my $DEBUG = "N";
#
######################################################################################
# Argument parsing
foreach $I (@ARGV) {
   switch:{
      $_ = "$I";
      if( ($GETFLAG ne "") && !(/^-.*/) ) {
         ($GETFLAG eq "Interval") && ($Interval = $I);
         ($GETFLAG eq "SecondsBack") && ($SecondsBack = $I);
         ($GETFLAG eq "DirName") && ($DirName = $I);
         $GETFLAG = "";
         last switch; }


      if( /^-[Nn][Oo][Hh][Ee][Aa][Dd][Ee][Rr]$/ ){
         $PRINTHEADER = 0;
         last switch; }

      if( /^-[Dd][Ii][Rr]$/ ){
         $GETFLAG = "DirName";
         last switch; }
      if( !(/^-.*/) && (/^(\S+)$/) ){
         $FileName = $1;
         last switch; }
      if( /^-[Ss]$/ ){
         $GETFLAG = "SecondsBack";
         last switch; }
      if( /^-[Ii]$/ ){
         $GETFLAG = "Interval";
         last switch; }
      if( /^-[Dd][Ee][Bb][Uu][Gg]$/ ){
         $DEBUG = "Y";
         last switch; }

      if( /^-[Uu][Ss][Aa][Gg][Ee]$/ ) {
         ### put usage statement in here
         &PRINTUSAGE;
         exit(1); }
   }
}
undef $GETFLAG;
#
######################################################################################
#
if( ($FileName !~ /\//) && ($DirName ne "") && (-e $DirName) ){
   $FileName = $DirName.'/'.$FileName;
}
   

($SecondsBack <= 0) && (print "Error: Seconds back must be greater than 0.\n") && (&PRINTUSAGE) && (exit(5)); ($Interval < 0) && (print "Error: Interval back must be greater than or equal to 0.\n") && (&PRINTUSAGE) && (exit(5)); (!(-e $DirName)) && ($FileName =~ /\//) && (print "Error: $DirName does not exist.\n") && (&PRINTUSAGE) && (exit(5)); (!(-e $FileName)) && (print "Error: $FileName does not exist.\n") && (&PRINTUSAGE) && (exit(5));


#Thoughts: Pull bytes in at a time. Trigger processing of GC event on the data between {}.

my $READCHAR = ""; # A set of characters.
my $OBJSTRING = "";
my $StartingInterval = time() - $SecondsBack; my $EndingInterval = time(); if( $Interval > 0 ){
   #print "1\t".time."\n";
   #print "2\t".$SecondsBack."\t".$Interval."\n";
   $StartingInterval = (int((time() - $SecondsBack) / $Interval )) * $Interval;
   #print "3\t".$ThisInterval."\n";
}
$EndingInterval = $StartingInterval + $Interval;

#print "Starting Interval: ".localtime($StartingInterval)."\n";

my $TimeCheck;  my $LastTimeCheck = 0; 
my @HeapStart;  my @HeapEnd;    my @HeapAlloc; my @GCTime;       my @GCType;
my @EdenAlloc;  my @FromAlloc;  my @ToAlloc;   my @NewGenAlloc;  my @GenAlloc;  my @PermAlloc;
my @EdenChange; my @FromChange; my @ToChange;  my @NewGenChange; my @GenChange; my @PermChange;

open(GCLOG,"<","$FileName") || die "Horrible death from $!\n";

printf "\n%5s %14s           %10s %11s %6s %6s  %8s %8s %8s %10s\n",
       "Dn/Tr","Time","Interval","GCTime","MaxGC","%GC","K Freed","MaxEnd","Perm","HeapSize";

while( read(GCLOG,$_,1) ){

   if(/\{/){
      #&PROCESSNON(\$OBJSTRING);
      $OBJSTRING = "";
   }elsif(/\}/){
      &PROCESSOBJ(\$OBJSTRING,  \@TimeStamp,   \@HeapStart,\@HeapEnd,   \@HeapAlloc,\@GCTime,\@GCType,
                  \@EdenAlloc,  \@EdenChange,  \@FromAlloc,\@FromChange,\@ToAlloc,  \@ToChange,
                  \@NewGenAlloc,\@NewGenChange,\@GenAlloc, \@GenChange, \@PermAlloc,\@PermChange );
      
      #($DEBUG eq "N") && ($OBJSTRING = "");


      if( $#TimeStamp >= 0 ) {

         $TimeCheck = pop(@TimeStamp);
         if( $StartingInterval <= $TimeCheck ){
            
            push(@TimeStamp,$TimeCheck);

            if( $EndingInterval < $TimeCheck ){
               #Cut all records except this one.
               if( $DEBUG eq "Y" ){
                  print "{".$OBJSTRING."}\n";
                  $OBJSTRING = "";
               }

               &PrintStats($EndingInterval,\$LastTimeCheck,($#TimeStamp),\@TimeStamp,
                           \@HeapStart,     \@HeapEnd,     \@HeapAlloc,  \@GCTime,    \@GCType,
                           \@EdenAlloc,     \@EdenChange,  \@FromAlloc,  \@FromChange,\@ToAlloc,  \@ToChange,
                           \@NewGenAlloc,   \@NewGenChange,\@GenAlloc,   \@GenChange, \@PermAlloc,\@PermChange);
               
               while( ($StartingInterval <= $TimeCheck) &&
                      ($TimeCheck > $EndingInterval) && 
                      ($Interval > 0) ){
                  $StartingInterval = $EndingInterval;
                  $EndingInterval = $EndingInterval + $Interval;
                  #print "New Interval: ".localtime($StartingInterval)." - ".localtime($EndingInterval)."\n";
               }
            }
         }else{
            #($DEBUG eq "Y") && (print "Clearing data. $#GCType\n");
            while($#HeapStart > -1){pop(@HeapStart);}
            while($#HeapEnd   > -1){pop(@HeapEnd);  }
            while($#HeapAlloc > -1){pop(@HeapAlloc);}
            while($#GCTime    > -1){pop(@GCTime);   }
            while($#GCType    > -1){pop(@GCType);   }
            #
            while($#EdenAlloc  > -1){pop(@EdenAlloc); }
            while($#EdenChange > -1){pop(@EdenChange);}
            #
            while($#FromAlloc  > -1){pop(@FromAlloc); }
            while($#FromChange > -1){pop(@FromChange);}
            #
            while($#ToAlloc  > -1){pop(@ToAlloc); }
            while($#ToChange > -1){pop(@ToChange);}
            #
            while($#NewGenAlloc  > -1){pop(@NewGenAlloc); }
            while($#NewGenChange > -1){pop(@NewGenChange);}
            #
            while($#GenAlloc  > -1){pop(@GenAlloc); }
            while($#GenChange > -1){pop(@GenChange);}
            #
            while($#PermAlloc  > -1){pop(@PermAlloc); }
            while($#PermChange > -1){pop(@PermChange);}
            $LastTimeCheck = $TimeCheck;
         }
      }

   }else{
      $OBJSTRING = $OBJSTRING.$_;
   }


}
if( $EndingInterval < time() ){
   &PrintStats($EndingInterval,\$LastTimeCheck,($#TimeStamp),\@TimeStamp,
               \@HeapStart,     \@HeapEnd,     \@HeapAlloc,  \@GCTime,    \@GCType,
               \@EdenAlloc,     \@EdenChange,  \@FromAlloc,  \@FromChange,\@ToAlloc,  \@ToChange,
               \@NewGenAlloc,   \@NewGenChange,\@GenAlloc,   \@GenChange, \@PermAlloc,\@PermChange);
}

&PROCESSOBJ(\$OBJSTRING,  \@TimeStamp,   \@HeapStart,\@HeapEnd,   \@HeapAlloc,\@GCTime,\@GCType,
            \@EdenAlloc,  \@EdenChange,  \@FromAlloc,\@FromChange,\@ToAlloc,  \@ToChange,
            \@NewGenAlloc,\@NewGenChange,\@GenAlloc, \@GenChange, \@PermAlloc,\@PermChange );

if( $#TimeStamp >= 0 ) {

   $TimeCheck = pop(@TimeStamp);
   push(@TimeStamp,$TimeCheck);

   while( ($StartingInterval <= $TimeCheck) &&
          ($TimeCheck > $EndingInterval) && 
          ($Interval > 0) ){
      $StartingInterval = $EndingInterval;
      $EndingInterval = $EndingInterval + $Interval;
      #print "New Interval: ".localtime($StartingInterval)." - ".localtime($EndingInterval)."\n";
   }
   &PrintStats($EndingInterval,\$LastTimeCheck,1,\@TimeStamp,
               \@HeapStart,     \@HeapEnd,     \@HeapAlloc,  \@GCTime,    \@GCType,
               \@EdenAlloc,     \@EdenChange,  \@FromAlloc,  \@FromChange,\@ToAlloc,  \@ToChange,
               \@NewGenAlloc,   \@NewGenChange,\@GenAlloc,   \@GenChange, \@PermAlloc,\@PermChange);
}

close(GCLOG);

######################################################################################

sub PrintStats{
   my $IntervalTimeStamp = $_[0];
   my $PriorEventTime    = $_[1];
   my $Number2Process    = $_[2];
   my $TIMESTAMP         = $_[3];

   my $HeapStart         = $_[4];
   my $HeapEnd           = $_[5];
   my $HeapAlloc         = $_[6];
   my $GCTime            = $_[7];
   my $GCType            = $_[8];
   
   my $EdenAlloc         = $_[9];
   my $EdenChange        = $_[10];
   my $FromAlloc         = $_[11];
   my $FromChange        = $_[12];
   my $ToAlloc           = $_[13];
   my $ToChange          = $_[14];
   my $NewGenAlloc       = $_[15];
   my $NewGenChange      = $_[16];
   my $GenAlloc          = $_[17];
   my $GenChange         = $_[18];
   my $PermAlloc         = $_[19];
   my $PermChange        = $_[20];

   my $ThisTime;
   my $ThisHeapStart;
   my $ThisHeapEnd;
   my $ThisHeapAlloc;
   my $ThisGCTime;
   my $ThisGCType;
  
   my $ThisEdenAlloc;
   my $ThisEdenChange;
   my $ThisFromAlloc;
   my $ThisFromChange;
   my $ThisToAlloc;
   my $ThisToChange;
   my $ThisNewGenAlloc;
   my $ThisNewGenChange;
   my $ThisGenAlloc;
   my $ThisGenChange;
   my $ThisPermAlloc;
   my $ThisPermChange;

   my $DNCount = 0;
   my $TRCount = 0;
   my $DNAmtTotal = 0;
   my $TRAmtTotal = 0;
   my $DNTimeTotal = 0;
   my $TRTimeTotal = 0;
   my $MaxGC = 0;
   my $KBFreed = 0;
   my $MaxEnd = 0;
   my $Perm = 0;
   my $HeapSize = 0;

   my $EdenChangeSum = 0;
   my $FromChangeSum = 0;
   my $ToChangeSum = 0;
   my $NewGenChangeSum = 0;
   my $GenChangeSum = 0;
   my $PermChangeSum = 0;

   my $LastEventTime = $PriorEventTime;
   
   for( my $X = 0; $X < $Number2Process; $X++ ){
      $ThisTime = shift(@$TIMESTAMP);
      $ThisHeapStart = shift(@$HeapStart);
      $ThisHeapEnd   = shift(@$HeapEnd);
      $ThisHeapAlloc = shift(@$HeapAlloc);
      $ThisGCTime    = shift(@$GCTime);
      $ThisGCType    = shift(@$GCType);
      
      $ThisEdenAlloc  = shift(@$EdenAlloc);
      $ThisEdenChange = shift(@$EdenChange);
#      if( $ThisEdenChange =~ /(\d+)\|(\d+)/ ){
#         $EdenChangeSum = $EdenChangeSum + ($1 - $2);
#      }
      $ThisFromAlloc  = shift(@$FromAlloc);
      $ThisFromChange = shift(@$FromChange);
#      if( $ThisFromChange =~ /(\d+)\|(\d+)/ ){
#         $FromChangeSum = $FromChangeSum + ($1 - $2);
#      }
      $ThisToAlloc    = shift(@$ToAlloc);
      $ThisToChange   = shift(@$ToChange);
#      if( $ThisToChange =~ /(\d+)\|(\d+)/ ){
#         $ToChangeSum = $ToChangeSum + ($1 - $2);
#      }
      $ThisNewGenAlloc  = shift(@$NewGenAlloc);
      $ThisNewGenChange = shift(@$NewGenChange);
#      if( $ThisNewGenChange =~ /(\d+)\|(\d+)/ ){
#         $NewGenChangeSum = $NewGenChangeSum + ($1 - $2);
#      }
      $ThisGenAlloc   = shift(@$GenAlloc);
      $ThisGenChange  = shift(@$GenChange);
#      if( $ThisGenChange =~ /(\d+)\|(\d+)/ ){
#         $GenChangeSum = $GenChangeSum + ($1 - $2);
#      }
      $ThisPermAlloc  = shift(@$PermAlloc);
      $ThisPermChange = shift(@$PermChange);
#      if( $ThisPermChange =~ /(\d+)\|(\d+)/ ){
#         $PermChangeSum = $PermChangeSum + ($1 - $2);
#      }

      $KBFreed = $KBFreed + ($ThisHeapStart - $ThisHeapEnd);

      if( ($DEBUG eq "Y") && ($Interval == 0) ){
         print "NewFormat: ".localtime($ThisTime)."|".$ThisNewGenChange."|".$ThisNewGenAlloc;
         print "|".$ThisEdenChange."|".$ThisEdenAlloc;
         print "|".$ThisFromChange."|".$ThisFromAlloc;
         print "|".$ThisToChange."|".$ThisToAlloc;
         print "|".$ThisGenChange."|".$ThisGenAlloc;
         print "|".$ThisPermChange."|".$ThisPermAlloc;
         print "\n";
      }

      #($DEBUG eq "Y") && (print "--->GC Type $ThisGCType\t$DNCount / $TRCount\n");
      if( $ThisGCType =~ /DN/ ){
         $DNCount++;
         $DNAmtTotal = $DNAmtTotal + ($ThisHeapStart - $ThisHeapEnd);
         $DNTimeTotal = $DNTimeTotal + $ThisGCTime;
      }elsif( $ThisGCType =~ /TR/ ){
         $TRCount++;
         $TRAmtTotal = $TRAmtTotal + ($ThisHeapStart - $ThisHeapEnd);
         $TRTimeTotal = $TRTimeTotal + $ThisGCTime;
      }
      $HeapSize = $ThisHeapAlloc;
      $Perm     = $ThisPermAlloc;
      ($MaxEnd < $ThisHeapEnd) && ($MaxEnd = $ThisHeapEnd);
      ($MaxGC < $ThisGCTime) && ($MaxGC = $ThisGCTime);

      $LastEventTime = $ThisTime;
   }

   if( $Number2Process > 0 ){

      printf("%2d/%2d ", $DNCount, $TRCount);

      # Variables for printing.
      my $PrintTimeStamp;
      my $Interval_Calculated = 0;
      my $PrintGCPercent = 0;

      # Switch between actual entries and the interval timestamp.
      if( $Interval > 0 ){
         $PrintTimeStamp = localtime($IntervalTimeStamp);
         $Interval_Calculated = $IntervalTimeStamp - $$PriorEventTime;
      }else{
         $PrintTimeStamp = localtime($ThisTime);
         $Interval_Calculated = $ThisTime - $$PriorEventTime;
      }
      printf("%15s ",$PrintTimeStamp);
      # The interval is calculated based on the event prior to the interval
      # and the last event of the interval.
      printf("%10.2f ",$Interval_Calculated);
      # Show the summarized Minor GC Time and Major GC Time.
      printf("%5.2f/%5.2f ",$DNTimeTotal,$TRTimeTotal);
      # Show the Maximum GC Time spent.
      printf("%6.2f ",$MaxGC);
      # Show the Percentage of the total time Spent in GC over the interval.
      if( $Interval_Calculated > 0 ){
         $PrintGCPercent = (($DNTimeTotal + $TRTimeTotal) / $Interval_Calculated) * 100;
         printf("%6.2f% ",$PrintGCPercent);
      }else{
         printf("%10s ",".");
      }
      # Print the total KB Freed.
      printf("%8d ",($DNAmtTotal + $TRAmtTotal));
      # Print the Maximum Ending Heap.
      printf("%8d ",$MaxEnd);
      # Print the Permanant Heap allocation.
      printf("%8d ",$Perm);
      # Print the Total Heap allocation.
      printf("%10d ",$HeapSize);

      # Extra variables
#      printf("%3d/%8d ",($EdenChangeSum / $Number2Process),$ThisEdenAlloc);
#      printf("%3d/%8d ",($FromChangeSum / $Number2Process),$ThisFromAlloc);
#      printf("%3d/%8d ",($ToChangeSum / $Number2Process),$ThisToAlloc);
#      printf("%3d/%8d ",($NewGenChangeSum / $Number2Process),$ThisNewGenAlloc);
#      printf("%3d/%8d ",($GenChangeSum / $Number2Process),$ThisGenAlloc);
#      printf("%3d/%8d ",($PermChangeSum / $Number2Process),$ThisPermAlloc);

      # Variables for printing removed.
      undef $PrintTimeStamp;
      undef $Interval_Calculated;
      undef $PrintGCPercent;
      print "\n";

      $$PriorEventTime = $LastEventTime;
   }

}

######################################################################################
sub PROCESSOBJ{
   my $OBJ = $_[0];
   my $TIMESTAMP  = $_[1]; # \d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d.\d+\+*-*\d+:
   my $HeapStart  = $_[2]; # \d+K->
   my $HeapEnd    = $_[3]; # \d+K->\d+K
   my $HeapAlloc  = $_[4]; # \d+K->\d+K(\d+K)
   my $GCTime     = $_[5]; # \d+K->\d+K(\d+K) \d+.\d+ secs
   my $GCType     = $_[6]; # Major=TR Minor=DN
   my $EdenAlloc  = $_[7]; # eden space 26240K
   my $EdenChange = $_[8]; # eden space 26240K, 100% used | eden space 26240K,   0% used
   my $FromAlloc  = $_[9]; # from space 3264K
   my $FromChange = $_[10]; # from space 3264K, 100% used | from space 3264K,  92% used
   my $ToAlloc    = $_[11]; # to   space 3264K
   my $ToChange   = $_[12]; # to   space 3264K,   0% used | to   space 3264K,   0% used
   my $NewGenAlloc= $_[13]; # new generation   total 29504K
   my $NewGenChange= $_[14]; # new generation   total 29504K, used 29504K
   my $GenAlloc   = $_[15]; # generation total 229376K
   my $GenChange  = $_[16]; # generation total 229376K, used 58664K
   my $PermAlloc  = $_[17]; # perm gen total 52928K
   my $PermChange = $_[18]; # perm gen total 52928K, used 52734K
   
   my $HeapB4Invoc;
   my $HeapAfInvoc;
   my $EVENT;

   
# ^Heap before GC invocations=30 (full 0):
# ^ par new generation   total 29504K, used 29504K [0x00002aaab4000000, 0x00002aaab6000000, 0x00002aaabc000000)
# ^  eden space 26240K, 100% used [0x00002aaab4000000, 0x00002aaab59a0000, 0x00002aaab59a0000) # ^  from space 3264K, 100% used [0x00002aaab59a0000, 0x00002aaab5cd0000, 0x00002aaab5cd0000)
# ^  to   space 3264K,   0% used [0x00002aaab5cd0000, 0x00002aaab5cd0000, 0x00002aaab6000000)
# ^ concurrent mark-sweep generation total 229376K, used 58664K [0x00002aaabc000000, 0x00002aaaca000000, 0x00002aaaf4000000) # ^ concurrent-mark-sweep perm gen total 52928K, used 52734K [0x00002aaaf4000000, 0x00002aaaf73b0000, 0x00002aaaf9400000)
   #print $$OBJ."\n";
   if( $$OBJ =~ /Heap\sbefore\sGC\sinvocations=(\d+)\s/ ){
      $HeapB4Invoc = $1;
   }
   if( $$OBJ =~ /(\d{4,4})-(\d{2,2})-(\d{2,2})T(\d{2,2}):(\d{2,2}):(\d{2,2}.\d+)(\+*-*\d+):(.*)Heap\safter\sGC/s ){
      #$1 Year
      #$2 Month
      #$3 Day
      #$4 Hour
      #$5 Minute
      #$6 Seconds
      #$7 Timezone
      push(@$TIMESTAMP, (timelocal($6,$5,$4,$3,($2 - 1),$1) + ($6 - int($6))) );
      $EVENT = $8;
   }elsif( $$OBJ =~ /(\d{4,4})-(\d{2,2})-(\d{2,2})T(\d{2,2}):(\d{2,2}):(\d{2,2}.\d+)(\+*-*\d+):(.*)/s ){
      push(@$TIMESTAMP, (timelocal($6,$5,$4,$3,($2 - 1),$1) + ($6 - int($6))) );
      $EVENT = $8;
   }else{
      #print STDERR $$OBJ."\n";
   }
   if( $$OBJ =~ /Heap\safter\sGC\sinvocations=(\d+)\s/ ){
      $HeapAfInvoc = $1;
   }elsif( $$OBJ =~ /Heap\sbefore\sGC\sinvocations=(\d+)\s/ ){
      $HeapAfInvoc = $1 + 1;
   }
   # ---------------------------------------------------------------- #
   my $Total = -1;
   my $Used = "";
   while( ($$OBJ =~ /new\sgeneration\s+total\s+(\d+)K\,\s+used\s+(\d+)K/g) ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$NewGenAlloc,$Total));
   ($Used ne "") && (push(@$NewGenChange,$Used));
   my $Total = -1;
   my $Used = "";
   while( ($$OBJ =~ /\sPSYoungGen\s+total\s+(\d+)K\,\s+used\s+(\d+)K/g) ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$NewGenAlloc,$Total));
   ($Used ne "") && (push(@$NewGenChange,$Used));

   # ---------------------------------------------------------------- #
   $Total = -1;
   $Used = "";
   while( ($$OBJ =~ /[^w]\sgeneration\s+total\s+(\d+)K\,\s+used\s+(\d+)K/g) ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$GenAlloc,$Total));
   ($Used ne "") && (push(@$GenChange,$Used));
   $Total = -1;
   $Used = "";
   while( ($$OBJ =~ /\sPSOldGen\s+total\s+(\d+)K\,\s+used\s+(\d+)K/g) ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$GenAlloc,$Total));
   ($Used ne "") && (push(@$GenChange,$Used));
   # ---------------------------------------------------------------- #
   $Total = -1;
   $Used = "";
   while( ($$OBJ =~ /\sperm\sgen\s+total\s+(\d+)K\,\s+used\s+(\d+)K/g) ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$PermAlloc,$Total));
   ($Used ne "") && (push(@$PermChange,$Used));
   $Total = -1;
   $Used = "";
   while( ($$OBJ =~ /\sPSPermGen\s+total\s+(\d+)K\,\s+used\s+(\d+)K/g) ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$PermAlloc,$Total));
   ($Used ne "") && (push(@$PermChange,$Used));
   # ---------------------------------------------------------------- #
   $Total = -1;
   $Used = "";
   while( $$OBJ =~ /eden\s+space\s+(\d+)K\,\s+(\d+)\%/g ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$EdenAlloc,$Total));
   ($Used ne "") && (push(@$EdenChange,$Used));
   # ---------------------------------------------------------------- #
   $Total = -1;
   $Used = "";
   while( $$OBJ =~ /from\s+space\s+(\d+)K\,\s+(\d+)\%/g ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$FromAlloc,$Total));
   ($Used ne "") && (push(@$FromChange,$Used));
   # ---------------------------------------------------------------- #
   $Total = -1;
   $Used = "";
   while( $$OBJ =~ /to\s+space\s+(\d+)K\,\s+(\d+)\%/g ){
      ($Total != $1) && ($Total = $1);
      if( $Used eq "" ){
         $Used = $2;
      }else{
         $Used = $Used."|".$2;
      }
   }
   ($Total > -1) && (push(@$ToAlloc,$Total));
   ($Used ne "") && (push(@$ToChange,$Used));
   # ---------------------------------------------------------------- #
   undef $Total;
   undef $Used;

   my $EVENTS = 0;
   # Recursively reduce the event string into the smallest recognizable part.
   # Smallest recognizable part is [<type>: <data> secs]
   while( $EVENT =~ /(.*)\[([^\[\]]+)\](.*)/gs ){
      my $SUBEVENT = $2;
      $EVENT = $1.$3;
      ($DEBUG eq "Y") && (print "\t-[".$EVENT."]-\n"); 
      $EVENTS++;
      # Data should appear to be '<type>: <data>'.
      if( $SUBEVENT =~ /([^:]+):\s+(.*)\ssecs/s ){
         $TYPE = $1;
         $DATA = $2;
         #($DEBUG eq "Y") && (print "\t\t[".$SUBEVENT."] WITH :\n");

         # ---------------------------------------------------------- #
         if( ($TYPE =~ /[Pp][Aa][Rr][Nn][Ee][Ww]/s) &&
             ($DATA =~ /(\d+)K->(\d+)K\((\d+)K\)\s*,\s+(\d+\.\d+)/s) ){
            # Need to keep track of Nursury and Tenured space.
         # ---------------------------------------------------------- #
         }elsif( ($TYPE =~ /[Tt][Ii][Mm][Ee][Ss]/s) &&
                 ($DATA =~/user=(\d+\.\d+)\s+sys=(\d+\.\d+)\s*,\s+real=(\d+\.\d+)/) ){
            #print "$1\t$2\t$3\n";
            # Not sure what to do with Times data.
         # ---------------------------------------------------------- #
         }elsif( ($TYPE =~ /[Cc][Mm][Ss]/s) &&
                 ($DATA =~ /(\d+)K->(\d+)K\((\d+)K\)\s*,\s+(\d+\.\d+)/s) ){
            # Another object.
         # ---------------------------------------------------------- #
         }elsif( ($TYPE =~ /[Ff][Uu][Ll][Ll]\s[Gg][Cc]/s ) &&
                 ($DATA =~ /(\d+)K->(\d+)K\((\d+)K\)\s*,[^0-9\.]*\s+(\d+\.\d+)/s) ){
            push(@$HeapStart,$1);
            push(@$HeapEnd,  $2);
            push(@$HeapAlloc, $3);
            push(@$GCTime, $4);
            push(@$GCType, "TR");
         # ---------------------------------------------------------- #
         }elsif( ($TYPE =~ /[Gg][Cc]/s ) &&
                 ($DATA =~ /(\d+)K->(\d+)K\((\d+)K\)\s*,[^0-9\.]*\s+(\d+\.\d+)/s) ){
            push(@$HeapStart,$1);
            push(@$HeapEnd,  $2);
            push(@$HeapAlloc, $3);
            push(@$GCTime, $4);
            push(@$GCType, "DN");
         }elsif( $DEBUG eq "Y" ){
            print "--->$TYPE\n";
            print "--->$DATA\n";
         }
         # ---------------------------------------------------------- #
      }elsif( $SUBEVENT =~ /^([^:]*GC)\s+([^:]+)\s+secs/s ){
         $TYPE = $1;
         $DATA = $2;
         #($DEBUG eq "Y") && (print "\t\t[".$SUBEVENT."] WITHOUT :\n");

         if( ($TYPE =~ /[Ff][Uu][Ll][Ll]\s[Gg][Cc]/s ) &&
             ($DATA =~ /(\d+)K->(\d+)K\((\d+)K\)\s*,[^0-9\.]*\s+(\d+\.\d+)/s) ){
            push(@$HeapStart,$1);
            push(@$HeapEnd,  $2);
            push(@$HeapAlloc, $3);
            push(@$GCTime, $4);
            push(@$GCType, "TR");
         # ---------------------------------------------------------- #
         }elsif( ($TYPE =~ /[Gg][Cc]/s ) &&
                 ($DATA =~ /(\d+)K->(\d+)K\((\d+)K\)\s*,[^0-9\.]*\s+(\d+\.\d+)/s) ){
            push(@$HeapStart,$1);
            push(@$HeapEnd,  $2);
            push(@$HeapAlloc, $3);
            push(@$GCTime, $4);
            push(@$GCType, "DN");
         }
      }elsif( $SUBEVENT =~ /^([^:]+):\s+(\d+)K->(\d+)K\((\d+)K\)$/ ){
         #PSPermGen: 131071K->87462K(131072K)
         #print STDERR "\t$1-$2-$3-$4\n";
      }
      #}else{ 
      #   print STDERR $SUBEVENT."\n";

   }
   undef $EVENTS;


# ^2011-11-15T16:13:50.908-0500: 6521.528: [GC 6521.528: [ParNew # ^Desired survivor size 1671168 bytes, new threshold 4 (max 4)
# ^- age   1:     931608 bytes,     931608 total
# ^: 29504K->3009K(29504K), 0.0200020 secs] 88168K->62295K(258880K), 0.0202560 secs] [Times: user=0.23 sys=0.01, real=0.02 secs] 
  
# ^Heap after GC invocations=31 (full 0):
# ^ par new generation   total 29504K, used 3009K [0x00002aaab4000000, 0x00002aaab6000000, 0x00002aaabc000000)
# ^  eden space 26240K,   0% used [0x00002aaab4000000, 0x00002aaab4000000, 0x00002aaab59a0000)
# ^  from space 3264K,  92% used [0x00002aaab5cd0000, 0x00002aaab5fc0788, 0x00002aaab6000000)
# ^  to   space 3264K,   0% used [0x00002aaab59a0000, 0x00002aaab59a0000, 0x00002aaab5cd0000)
# ^ concurrent mark-sweep generation total 229376K, used 59286K [0x00002aaabc000000, 0x00002aaaca000000, 0x00002aaaf4000000) # ^ concurrent-mark-sweep perm gen total 52928K, used 52734K [0x00002aaaf4000000, 0x00002aaaf73b0000, 0x00002aaaf9400000)

}
######################################################################################
sub PROCESSNON{
   $OBJ = $_[0];

# ^Total time for which application threads were stopped: 0.0262310 seconds # ^Application time: 0.0006890 seconds

}
######################################################################################
sub PRINTUSAGE{
   print "\nUsage: $0 [-i #][-s #][-dir dirname][Log File][-usage]\n";
   print "   Purpose: This program gathers a list of garbage collection logs.\n";

   print "   -NoHeader: Doesn't print the header on the output.\n";
   print "   -usage: Print this usage screen.\n";

}
######################################################################################
