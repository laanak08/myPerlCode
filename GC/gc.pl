: # Use perl
eval 'if [ -x /home/cpm/bin/findperl.sh ] ; then exec `/home/cpm/bin/findperl.sh` -S $0 ${1+"$@"}; fi'
  if $running_under_some_shell;

#######################################################################################
# 21Mar2007, MNatale
#  - modify perl startup, requires findperl.sh in bin directory in CPM home #######################################################################################

##############################################################
# old command was /usr2/public/bin/perl5 ##############################################################
#
# Parse stdout.log data
#
##############################################################
#  modified by hazy mathew on jan 2007
##############################################################
$min_time=0;		#min time per interval
$max_time=0;		#max time per interval
$count=0;		#total count per interval
$major_count=0;		#count of Full GC's per interval
$dncount=0;		#count of DefNew GC's per interval
$trcount=0;		#count of Tenured GC's per interval
$minor_count=0;		#count of GC's per interval
$time=9999999999;       #time stamp per record
$e_time=0;		#elapsed time per record
$elapsed_sum=0;		#sum of elapsed time per interval
$elapsed_max=0;		#max elapsed time per interval
$start=0;		#start size in bytes
$end=0;			#end size in bytes
$heap=0;		#size of heap per record
$interval=600;		#size of interval in seconds (set by user at command line) default = 300
$start_sum=0;		#sum of the start size per interval
$end_sum=0;		#sum of the end size per interval
$heap_max=0;		#max heap size per interval
$lb=9999999999;		#number of lines to read from file

$stopped_sum=0;

$threshold=0;		#max gc percent(-t option) modified on 01/09/2007
$print_hddr = 0;	#Headder to be print or not - modified on 1/9/07

$timeback = 0;		#time back so many seconds (-s option) max value 8640000		

$flag1 = 0;             # added for -s option
$tenured =0;
$diff = 0;              # added for -s option 
$t0 = 0;                # added for -s option 
$ts = 0;                # added for -s option
$bsize = 0;             # added for -s option
$buf = " ";             # added for -s option
$dir =".";
$file = "***";
$fileMtime = time;
$fileOld = 0;
$CurrTime = time;
$prevtime = 0;
$LCtime = time;
$aptime = 0;
$diffappTime = 0;
$firstdataflag = 1;
$bouncecount = 0;
$bCount = 0;
$pts = 0;
$bounceInterval = 600;
$java1dot5flag = 0;
$loopflag = 0;
$perm_heap = 0;
###-----------------------------------------------
## initializing $file with current OS
#_________________________________________________
$operating_sys = $^O;
if ($operating_sys eq "solaris") { $file = "stdout.log";  } #else { die "\nUnknown OS $operating_sys\n"; }
#--------------------------------------------------


while ($_ = shift) {
       (((/^-usage/) || (/-\?/) || (/-help/)) && (die("Usage: $argv[0] [-i #] [-l #] [-t #] [-s #  [-at] ] [-b] [-dir dirname] [Log File]
       \t -i # - Interval Size (default = 0)\n\t -l # - Number of lines (default = 9999999999) 
       \t -s # - Seconds Back (if -at not selected timeStamp is printed in local time format othervise in Appserver time format) 
       \t -b   - BounceTime Iterval inseconds (default assumption 600s)
       \t -t # - Threshold(above %GC)\n\t -usage or -help - usage\n",)));
                 
  #parse command line
    if(/-dir/) {
       $_ = shift;
       /\D+/ && ($dir = $_);
       $_ = shift;
    }
     if( /^-l/ ){
          $_ = shift;
          /^\d+/ && ($lb=$_);
     }

     if( /^-i/ ){
          $_ =shift;
          /^\d+/ && ($interval=$_);
     }

     if(/-t/) {
        $_ = shift;
         /^(\d*\.?\d+)/ && ($threshold = $_);
     }
     
     if(/-b/) {
        $_ = shift;
         /^(\d*\.?\d+)/ && ($bounceInterval= $_);
     }

    if(/-s/) {
       $_ = shift;
       /^\d+/ && ($timeback = $_);
       if($timeback <0) { $timeback = 0;  }
    }

    if(/^-at/)  {  $aptime = 1;   }

    if($interval <0) { $interval = 0;  }
   #if($timeback > 8640000) { $timeback = 8640000 }
    if($lb <0) { die "invalid line number... should be > 0\n";  }

   if(/^[A-Z, a-z, \., \/]\w+/)    { $file = $_;   }
}
   if($dir ne ".")  { $file = "${dir}/${file}";  }
   open ($fh, $file ) || die "Can't open $file\n";

   $fileMtime = (stat $fh)[9];
   $fileOld = time - $fileMtime;
   
  # print "\n filemodi time"; print $fileMtime;
  # print "\n fileold by (sec)";  print $fileOld;
  # print "\n time back (sec)"; print  $timeback;

   if($timeback > 0) {  # =========================================
       if($fileOld > $timeback)  { die "\n old file\n";   } 
       $timeback -= $fileOld;
       
       $lb=10;
       if(seek($fh, -$lb,2) == 0) { die "\n No Records to Show\n"; }
       while ($t0==0) {
        if($lb >$timeback*10000)  { die "\n TimeStamp Not Found\n"; }
        if($bsize >50) { $bsize = 50;  }
       read $fh, $buf, $bsize;
         if($buf =~ /\n(\d+\.\d+): \[.*GC/) {
           $t0 =$1;
           $pts = $t0;
         }
         else  {  $lb +=10; 
           if(seek($fh, -$lb,2)==0) {  die "\n No Records to Show\n"; }
           $bsize = $lb;
         }
        } # while 

       while($diff < $timeback)  { #while loop ******
         $lb +=50;
         if(seek($fh, -$lb,2) ==0) { last; }
         $flag1 = 0;
         while($flag1==0) { #while -----------
           if($lb >$timeback*10000)  { $loopflag = 1; last; }
           $buf =" ";
           read $fh, $buf,50;
           if($buf =~ /\n(\d+\.\d+): \[.*GC/) {
             $ts =$1;
             $flag1=1; 
           }
           else  {  $lb +=10;    
             if(seek($fh, -$lb,2)==0)  { $loopflag = 1; last; }

           }
         }                   #endof while------

         if(loopflag==1) { last;  }
         if($ts > $t0) {   
           $diff += $t0 + $bounceInterval;
           $bouncecount++;
         }
         else { 
           $diff += $t0 - $ts;
         }
         $t0 = $ts;
       }                          #endof while loop*****
      
       $CurrTime = $fileMtime - $diff;
       $prevTime = 0;

   } #endof if timeback >0  ========================================

     if(seek($fh, -$lb, 2)==0)  {   }
     
     #read line while time diff does not exceed interval
     LINE: while (<$fh>) {  
         !(/\d+\.\d+:/) && next;
         $lincnt+=1;

         /^Total time for which application threads were stopped: (\d+\.\d+) seconds/ && ($stopped_sum+=$1) && (next);
		 # 2013-03-24T22:26:37.551-0400: (300955.139): [GC [PSYoungGen: <-- parens surround the intent of the following regex
		 #   2013-04-18T17:05:03.000-0400: (11.440): [Full GC  <-- parens surround the intent of the following regex
         if (/(\d+\.\d+):\s+\[.*GC/ || /(\d+\.\d+):\s+\[.*Full\s+GC/){
             if ( $1  >= $time) { 
				$time_sum+=$1-$time;
				$diffappTime = $1 - $time;
            }
            else {
              $diffappTime = $1 + $bounceInterval;
              &dumpstats;  #to get the last data from the previous appserver;
              $time_sum=$1;
              $perm_heap=0;

            }
            if($firstdataflag==1) { $diffappTime = 0; $time_sum = 0; }
            $firstdataflag = 0;
            $CurrTime += $diffappTime;
            $time=$1;
         }
        
        #  [GC [1 CMS-initial-mark: 1832164K(2818048K)] 1837665K(3104768K), 0.0521999 secs]
         if (/^\d+\.\d+: \[GC.*CMS.* (\d+)K\(\d+K\)\]\s+(\d+)K\((\d+)K\),\s+(\d+\.\d+) secs\]$/) {
            $tre_time+=$4;
            $trcount++;
            $e_time+=$4;
            if ($4>$e_time_max) {$e_time_max=$4;}
            if ($3 > $heap){ $heap = $3;}
            if ($1 > $max_end){ $max_end = $1;}
            $start+=$2;
            $end+=$1;
         }
		 
		#[PSYoungGen: 2047932K->0K(4096000K)] [PSOldGen: 7293637K->9341210K(12288000K)] 9341569K->9341210K(16384000K) [PSPermGen:
		#14950K->14950K(30464K)], 3.3134250 secs] [Times: user=1.78 sys=1.52, real=3.31 secs]
         if ( (/(\d+)K->(\d+)K\((\d+)K\)( \[.?.?Perm.?.?.?: \d+K->\d+K\(\d+K\)\], | )(\d+\.\d+) secs\]/)  
            || (/(\d+)K->(\d+)K\((\d+)K\),(\s*\[CMS\s*Perm\s*:\s*\d+K->\d+K\(\d+K\)\],\s*)(\d+\.\d+) secs\]$/) 
			|| (/(\d+)K->(\d+)K\((\d+)K\),(\s*\[CMS\s*Perm\s*:\s*\d+K->\d+K\(\d+K\)\],\s*)(\d+\.\d+) secs\]/) ) {

          $start+=$1;
          $end+=$2;
          $e_time+=$5;
          if ($5>$e_time_max) {$e_time_max=$5;}
          if ($3 > $heap){ $heap = $3;}
          if ($2 > $max_end){ $max_end = $2;}
          $count++;
         }

		 #425.673: [GC [PSYoungGen: 2048000K->839318K(4096000K)] 11389210K->10180529K(16384000K), 0.2617110 secs] [Times: user=1.56 #sys=0.01, real=0.26 secs]
		 #450.077: [GC [PSYoungGen: 2887318K->871729K(4096000K)] 12228529K->11051202K(16384000K), 24.4529920 secs] [Times: user=1.81 # sys=5.72, real=24.45 secs]
         if (/(\d+)K->(\d+)K\((\d+)K\)\] (\d+)K->(\d+)K\((\d+)K\),\s*(\d+\.\d+) secs\]/) {               
          $start+=$4; 
          $end+=$5; 
          $e_time+=$7; 
          if ($7>$e_time_max) {$e_time_max=$7;} 
          #if ($3 > $heap){ $heap = $3;}
          if ($6 > $heap){ $heap = $6;}
          if ($5 > $max_end){ $max_end = $5;}
          $count++;
         }

		# [PSYoungGen: 2048000K->0K(4096000K)] [PSOldGen: 11839401K->12094223K(12288000K)] 13887401K->12094223K(16384000K) [PSPermGen: 15353K->13883K(29888K)], 655.9455630 secs] [Times: user=7.56 sys=15.96, real=655.87 secs]
	 if ( ((/^: (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs\] (\d+)K->(\d+)K\((\d+)K\),/) 
	    || (/^  (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs\]/)
		|| (/:\s+(\d+)K->(\d+)K\((\d+)K\)\], (\d+\.\d+) secs\]/) ) && ($tenured==1)) {
    
            $trstrt+=$1; 
            $trend+=$2; 
            if ($3>$trheap) {  $trheap=$3;} 
            $tre_time+=$4; 
            $trcount++; 
            $tenured=0;
         }

         ###parse Cases DefNew/GCDetails and Minor Collection/No GCDetails...
         ####96940.516: [GC 96940.517: [DefNew: 311360K-.......734313 secs] 509730K->195005K(651648K), 3.0737579 secs]

         if ((/\[DefNew: (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs\]/) || (/: \[GC (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs\]/)  
             || (/\[ParNew: (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs\]/)) { 
            $dnstrt+=$1; 
            $dnend+=$2; 
            if ($3>$dnheap) {$dnheap=$3;} 
            $dne_time+=$4; 
            $dncount++;
         }elsif(/ParNew/){
			unless(/:/){
				$_ .= <$fh>;
				redo LINE;
			}
			if(/(\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs\]/){
				$dnstrt+=$1; 
				$dnend+=$2; 
				if ($3>$dnheap) {$dnheap=$3;} 
				$dne_time+=$4; 
				$dncount++;
			}
		 }

         #parse portion of a line (PSYoungGen is similar to DefNew but time sec not there)
         if(/\[PSYoungGen: (\d+)K->(\d+)K\((\d+)K\)/)  { 
            $dnstrt+=$1;
            $dnend+=$2;
            if ($3>$dnheap) {$dnheap=$3;}
            $dncount++;
            $java1dot5flag =1; 
         }

         #parse portion of a line (PSOldGen is similar to Tenured but time sec not there)
         if(/\[PSOldGen: (\d+)K->(\d+)K\((\d+)K\)/)  {
            $trstrt+=$1;
            $trend+=$2;
            if ($3>$trheap) {$trheap=$3;}
            $trcount++;
            $tenured = 0;
            $java1dot5flag =1;
         }

         if (/\[(Tenured:|Full GC) (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs\]/) {
            $trstrt+=$2; 
            $trend+=$3;  
            if ($4>$trheap) {$trheap=$4;} 
            $tre_time+=$5;  
            $trcount++;
         }

         /\[(Tenured|Full GC|CMS)\[Unloading/ &&($tenured=1);

          #parse Perm portion of a line
          if(( /\[.?.?Perm.?.?.?: (\d+)K->(\d+)K\((\d+)K\)\], (\d+\.\d+) secs\]/ ) 
              || (/\[CMS\s*Perm\s*:\s*(\d+)K->(\d+)K\((\d+)K\)\],\s*(\d+\.\d+) secs\]$/)
			  || (/\[CMS\s*Perm\s*:\s*(\d+)K->(\d+)K\((\d+)K\)\],\s*(\d+\.\d+) secs\]/) ) { 
	       $perm_start=$1;
	       $perm_end=$2;
	       if($3 > $perm_heap){ $perm_heap=$3; }
               #$perm_elapsed+=$4;
	       if($perm_start > $psm){ $psm=$perm_start; }
          }
           

     if ($time_sum>$interval && $tenured==0)  { &dumpstats; }

}
&dumpstats;
#--------------------------------------------------------------------------------------------
     #print if time diff exceeds interval or the app is bounced | sub function - dumpstats
#--------------------------------------------------------------------------------------------
sub dumpstats {
     if ($time_sum!=0) {
         $x = (($e_time / $time_sum)*100);	#set percent GC
         $size_dif = $start - $end;
         if ($count>0) {$avg_GC = ($size_dif/$count);}

         if(($threshold==0) || (($x >= $threshold) && ($time_sum >= $interval/2))) { 	
           if($print_hddr == 0) {
                 if($timeback > 0 && $aptime ==0) {
                     if($java1dot5flag==1) {  # for java1.5
                         printf "\n%5s%15s     %15s %5s %6s %6s   %6s   %6s   %4s  %10s\n", "Dn/Tr", "Time",
                         "Interval", "GCTime", "MaxGC", "%GC", "K Freed", ,"MaxEnd", "Perm", "HeapSize";
                     }
                     else { 
                       printf "\n%5s%15s     %15s %10s  %6s%6s   %6s   %6s   %4s  %10s\n", "Dn/Tr", "Time",
                       "Interval", "Dn/TrGCTime", "MaxGC", "%GC", "K Freed", ,"MaxEnd", "Perm", "HeapSize";
                     }
                 }
                 else  {
                   if($java1dot5flag==1) {   # for java1.5
                      printf "\n%5s%7s       %8s%5s  %5s %6s  %6s    %6s   %4s  %10s\n", "Dn/Tr", "Time",
                     "Interval", " GCTime", "MaxGC", "%GC", "K Freed", ,"MaxEnd", "Perm", "HeapSize";
                   }
                   else { 
                     printf "\n%5s%7s       %8s %10s %6s %6s  %6s   %6s   %4s  %10s\n", "Dn/Tr", "Time", 
                     "Interval", "Dn/TrGCTime", "MaxGC", "%GC", " K Freed", ,"MaxEnd", "Perm", "HeapSize";
                   }
                 }
                 $print_hddr=1;
           }        		

	       printf "%2d/%2d ", $dncount,$trcount;
               
               if($timeback > 0 && $aptime ==0)  {
                  $LCtime = localtime($CurrTime);
                  printf "%15s", $LCtime;
               }
	       else {  printf "%10.2f ", $time;   }

	       printf "%10.2f ", $time_sum;
               
                if($java1dot5flag==1) {  # for java1.5
                   printf "%6.2f ", $e_time;
                }
                else { 
	          printf "%5.2f/", $dne_time;
	          printf "%5.2f ", $tre_time;
                }
	        printf "%6.2f ", $e_time_max;
	        printf "%6.2f% ", $x;
	        printf "%8d ", $size_dif;
	        printf "%8d", $max_end;
	        printf "%8d", $perm_heap;
	        printf "%10d\n", $heap;
          }
               #reset varialbes
	       $count=0;
               $dncount=0;
               $trcount=0;
	       $e_time=0;
	       $e_time_max=0;
               $dne_time=0;
               $tre_time=0;
	       $start=0;
	       $dnstrt=0;
	       $trstrt=0;
	       $end=0;
	       $max_end=0;
	       $dnend=0;
	       $trend=0;
	       $heap=0;
               #$perm_heap =0;
               $perm_start = 0;
               $perm_end = 0;
               $psm=0;
               $trheap=0;
               $dnheap=0;
               $time_sum=0;
    }
}
#_____________________________end of dumpstats_____________________________________________________________
