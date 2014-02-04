#!/usr/local/bin/perl5.8

# $DEBUG = 1; # uncomment this line to force debug mode to ENABLED

use File::Path ;

use DBI;

######################################################################
# First, figure out the level (cert/prod/case) ######################################################################
$level=&getlvl;

######################################################################
# Next, setup the Oracle defaults
######################################################################
if ( $level eq "cert" || $level eq "prod" ) {
   $ENV{ORACLE_BASE} = '/opt/oracle/sol-8.1.7';
   $ENV{ORACLE_HOME} = '/opt/oracle/sol-8.1.7'; 
   $ldpath = "/opt/oracle/sol-8.1.7/lib:$ENV{LD_LIBRARY_PATH}" ; 
   $ENV{LD_LIBRARY_PATH} = $ldpath ;
} else {
   $ENV{ORACLE_BASE} = '/serve/oracle/sol-8.1.7';
   $ENV{ORACLE_HOME} = '/serve/oracle/sol-8.1.7';
   $ldpath = "/serve/oracle/sol-8.1.7/lib:$ENV{LD_LIBRARY_PATH}" ;
   $ENV{LD_LIBRARY_PATH} = $ldpath ;
}

######################################################################
# Next, setup the Oracle database information ######################################################################
    $dbuser  = "cpm_user";
    $dbpass  = "cpm_user";
    $dbname  = "dbi:Oracle:CPSERMON";
    $dbowner = "usaowner";
    @dbtables = ("OS_IDENT","OS","HW_CPU", "INFO", "INFO_H", "OS", "OS_FS", "OS_H");     

######################################################################
# Now, setup the program's variables and constants ######################################################################
$i=0;
$csv_char     = ",";
$post         = "'";
$ppost        = "')";

$GETFLAG      = "";
$GETOSLIST    = "FALSE";
$GETBUSUNIT   = "FALSE";
$GETDOMLIST   = "FALSE";
$GETFLDLIST   = "FALSE";
$GETHOSTLIST  = "FALSE";
$GETSORTLIST  = "FALSE";
$GETSTATLIST  = "FALSE";
$GETCLASS     = "FALSE";
$GETFORMAT    = "FALSE";
$GETRETIRED   = "FALSE";
$GETCSV       = "FALSE";

@brief_fields = ("%host","%os","%rel","%ver","%dom","%bu");
@full_fields  = ("%host","%os","%rel","%ver","%dom","%bu","%class","%cpus","%mod","%sp","%cs","%stat");

@rep_fields   = @brief_fields;

$script       = $0; 
$script       =~ /(\w+)\.pl/; 
$script       = $1;

my @CmdString = @ARGV;

foreach $CmdArg (@CmdString)
{
   switch:
   {
      $i++;
      $_ = "$CmdArg";
      ($DEBUG) && (print "CmdArg #$i [$CmdArg]\n");

      if( ($GETFLAG ne "") && !(/^-.*/) ) {
         ($GETFLAG eq "CSV") && ($csv_char = $CmdArg) && ($GETCSV = "TRUE");
	 $GETFLAG = "";
         last switch; }
      ### -os   <OS name1 . . . OS name?>]      (filter on OS name(s))
      if( (($GETOSLIST eq "TRUE") || ($GETOSLIST eq "ERROR")) && !(/^-.*/) ) {
         $os_scope = $os_scope . $os_prefix . $CmdArg . $ppost;
	 $os_prefix	= " OR LOWER(o.kernel) like LOWER('";
         $GETOSLIST = "TRUE";
         last switch; }
      if( ($GETOSLIST eq "TRUE") && (/^-.*/) ) { $GETOSLIST = "DONE"; }
      if( /^-[Oo][Ss]$/ ) {
         $GETOSLIST = "ERROR";
	 $os_scope  = "";
	 $os_prefix = "LOWER(o.kernel) like LOWER('";
         last switch; }
	 
      ### -class <S | W>] (filter on box class)
      if( (($GETCLASS eq "TRUE") || ($GETCLASS eq "ERROR")) && !(/^-.*/) ) {
         $boxclass     = $boxclass . $class_prefix . $CmdArg . $ppost;
	 $class_prefix = " OR oi.class like UPPER('";
         $GETCLASS     = "TRUE";
         last switch; }
      if( ($GETCLASS eq "TRUE") && (/^-.*/) ) { $GETCLASS = "DONE"; }
      if( /^-[Cc][Ll][Aa][Ss][Ss]$/ ) {
         $GETCLASS     = "ERROR";
	 $boxclass     = "";
	 $class_prefix = "oi.class like UPPER('";
         last switch; }
	 
      ### -host <hostname1 . . . hostname?...>] (filter on hostname(s))
      if( (($GETHOSTLIST eq "TRUE") || ($GETHOSTLIST eq "ERROR")) && !(/^-.*/) ) {
         $hostnames = $hostnames . $host_prefix . $CmdArg . $post;
	 $host_prefix = " OR oi.hostname like '";
         $GETHOSTLIST = "TRUE";
         last switch; }
      if( ($GETHOSTLIST eq "TRUE") && (/^-.*/) ) { $GETHOSTLIST = "DONE"; }
      if( /^-[Hh][Oo][Ss][Tt]$/ ) {
         $GETHOSTLIST = "ERROR";
	 $hostnames   = "";
	 $host_prefix = "oi.hostname like '";
         last switch; }
	 
      ### -bu  <business unit1 . . . business unit?...>]   (filter on business unit(s))
      if( (($GETBUSUNIT eq "TRUE") || ($GETBUSUNIT eq "ERROR")) && !(/^-.*/) ) {
         $GETBUSUNIT = "TRUE";
         if( $CmdArg eq "" )
	 { $bus_unit = $bus_unit . "oin.businessunit is $bu_qual NULL"; }
	 else
	 { $bus_unit = $bus_unit . $bu_prefix . $CmdArg . $post; }
	 $bu_prefix = " $bu_prequal oin.businessunit $bu_qual like '";
         last switch; }
      if( ($GETBUSUNIT eq "TRUE") && (/^-.*/) ) { $GETBUSUNIT = "DONE"; }
      if( /^-[Nn][Oo][Bb][Uu]$/ ) { 
         $bu_qual = "NOT"; 
	 $bu_prequal = "AND";
         $GETBUSUNIT = "ERROR";
	 $bus_unit  = "oin.businessunit is NULL or ";
	 $bu_prefix = "oin.businessunit $bu_qual like '";
         last switch; }
      if( /^-[Bb][Uu]$/ ) { 
         $bu_qual = ""; 
	 $bu_prequal = "OR"; 
         $GETBUSUNIT = "ERROR";
	 $bus_unit  = "";
	 $bu_prefix = "oin.businessunit $bu_qual like '";
         last switch; }
	 
      ### -dom  <domname1 . . . domname?...>]   (filter on domain name(s))
      if( (($GETDOMLIST eq "TRUE") || ($GETDOMLIST eq "ERROR")) && !(/^-.*/) ) {
         $GETDOMLIST = "TRUE";
         if( $CmdArg eq "" )
	 { $dom_scope = $dom_scope . "o.domain is $dom_qual NULL"; }
	 else
	 { $dom_scope = $dom_scope . $dom_prefix . $CmdArg . $post; }
	 $dom_prefix = " $dom_prequal o.domain $dom_qual like '";
         last switch; }
      if( ($GETDOMLIST eq "TRUE") && (/^-.*/) ) { $GETDOMLIST = "DONE"; }
      if(( /^-[Nn][Oo][Dd][Oo][Mm]$/ ) || ( /^-[Nn][Oo][Dd][Oo][Mm][Aa][Ii][Nn]$/ )) { 
         $dom_qual = "NOT"; 
	 $dom_prequal = "AND";
         $GETDOMLIST = "ERROR";
	 $dom_scope  = "o.domain is NULL or ";
	 $dom_prefix = "o.domain $dom_qual like '";
         last switch; }
      if(( /^-[Dd][Oo][Mm]$/ ) || ( /^-[Dd][Oo][Mm][Aa][Ii][Nn]$/ )) { 
         $dom_qual = ""; 
	 $dom_prequal = "OR"; 
         $GETDOMLIST = "ERROR";
	 $dom_scope  = "";
	 $dom_prefix = "o.domain $dom_qual like '";
         last switch; }
	 
      ### -stat <ONLINE|OFFLINE|CLAIMED>]       (filter on box status(s))
      if( (($GETSTATLIST eq "TRUE") || ($GETSTATLIST eq "ERROR")) && !(/^-.*/) ) {
         $box_stat = $box_stat . $stat_prefix . $CmdArg . $ppost;
	 $stat_prefix = " OR UPPER(status) = UPPER('";
         $GETSTATLIST = "TRUE";
         last switch; }
      if( ($GETSTATLIST eq "TRUE") && (/^-.*/) ) { $GETSTATLIST = "DONE"; }
      if( /^-[Ss][Tt][Aa][Tt]$/ ) {
         $GETSTATLIST = "ERROR";
	 $box_stat    = "";
	 $stat_prefix = "UPPER(status) = UPPER('";
         last switch; }

      ### -sort <fld1 . . . fld?>]              (ORDER BY field name(s))	 
      if( (($GETSORTLIST eq "TRUE") || ($GETSORTLIST eq "ERROR")) && !(/^-.*/) ) {
	 $GETSORTLIST = "TRUE";
         push(@sort_fields, $CmdArg);
	 last switch; }
      if( ($GETSORTLIST eq "TRUE") && (/^-.*/) ) { $GETSORTLIST = "DONE"; }
      if( /^-[Ss][Oo][Rr][Tt]$/ ) {
         $GETSORTLIST = "ERROR";
	 $sort_order = "";
	 $sort_prefix = "ORDER BY "; }

      ### -csv <char> specify the character separator value 
      if(( /^-[Dd][Ee][Ll][Ii][Mm]$/ ) || (/^-[Cc][Ss][Vv]$/)) {
         $GETFLAG = "CSV"; 
	 $GETCSV = "ERROR";
         last switch; }

      ### -full include all fields in CSV output 
      if( /^-[Ff][Uu][Ll][Ll]$/ ) {
         @rep_fields = @full_fields;
         last switch; }
	 
      ### -fmt <user specified output record format entry> 
      if((($GETFORMAT eq "TRUE") || ($GETFORMAT eq "ERROR")) && !(/^-.*/) ) {
         $format = $format . $CmdArg . " ";
	 $GETFORMAT = "TRUE";
	 last switch; }
      if( ($GETFORMAT eq "TRUE") && (/^-.*/) ) { $GETFORMAT = "DONE"; }
      if(( /^-[Ff][Mm][Tt]$/ ) || ( /^-[Ff][Oo][Rr][Mm][Aa][Tt]$/ )) {
         $format = "";
	 $GETFORMAT = "ERROR";
         last switch; }
	 
      ### -fld <fld1 . . . fld?>] (order fields for CSV output)
      if( (($GETFLDLIST eq "TRUE") || ($GETFLDLIST eq "ERROR")) && !(/^-.*/) ) {
         $GETFLDLIST = "TRUE";
         push(@rep_fields, $CmdArg);
         last switch; }
      if( ($GETFLDLIST eq "TRUE") && (/^-.*/) ) { $GETFLDLIST = "DONE"; }
      if(( /^-[Ff][Ll][Dd]$/ ) || ( /^-[Ff][Ii][Ee][Ll][Dd]$/ )) {
         $GETFLDLIST = "ERROR";
	 undef @rep_fields;
         last switch; }
	 
      ### Enable Debug mode
      if( /^-[Dd][Ee][Bb][Uu][Gg]$/ ) { $DEBUG = 1 } 
	 
      ### Display examples of the script's usage information
      if(( /^-[Ee][Xx][Aa][Mm][Pp][Ll][Ee]$/ ) || ( /^-[Ee][Xx]$/ )) { &PrintExample; }
      
      ### Display the script's usage information
      if( /^-[Uu][Ss][Aa][Gg][Ee]$/ ) { &PrintUsage; }

      ### Display the database table information
      if( /^-[Tt][Aa][Bb][Ll][Ee]$/ ) { &PrintTables; exit; }

      ### Display version information and exit
      if(( /^-[Vv][Ee][Rr][Ss][Ii][Oo][Nn]$/ ) || ( /^-[Vv][Ee][Rr]$/ )) 
      { 
         die("$script \n\tver 1.0 [Server Information Script]\n",
	 	"\t\n"); 
      }

      ### shall be tolerant of users...
      if( ($GETFLAG != "") && (/^-.*/) ) {
         $GETFLAG = ""; 
	 last switch; }
   }   
}

if(($GETFORMAT eq "FALSE") || ($GETFLDLIST ne "FALSE"))   { $format = &BuildOutRecFmt; ($DEBUG) && (print "[$format]\n"); }
if($GETSORTLIST ne "FALSE") { &sortList; }

#
# If one or more of the user supplied switches didn't receive a proper value, print a message and stop # if(($GETHOSTLIST eq "ERROR") || ($GETFLDLIST eq "ERROR") || ($GETFORMAT eq "ERROR") ||
   ($GETSTATLIST eq "ERROR") || ($GETDOMLIST eq "ERROR") || ($GETOSLIST eq "ERROR") ||
   ($GETSORTLIST eq "ERROR") || ($GETBUSUNIT eq "ERROR") || ($GETCLASS eq "ERROR")  || 
   ($GETCSV eq "ERROR")) 
   { 
      die "one or more of the switches didn't receive a proper value, ",
          "please supply a value for the specified switch\n"; 
   }  

if(($GETHOSTLIST eq "TRUE") || ($GETHOSTLIST eq "DONE")) { 
   $hostnames = "(" . $hostnames . ") AND ";
   $GETHOSTLIST	= "DONE"; }
if(($GETOSLIST eq "TRUE")   || ($GETOSLIST eq "DONE"))   { 
   $os_scope = "(" . $os_scope . ") AND "; 
   $GETOSLIST = "DONE"; }
if(($GETBUSUNIT eq "TRUE")  || ($GETBUSUNIT eq "DONE"))  { 
   $bus_unit = "(" . $bus_unit . ") AND "; 
   $GETBUSUNIT = "DONE"; }
if(($GETDOMLIST eq "TRUE")  || ($GETDOMLIST eq "DONE"))  { 
   $dom_scope = "(" . $dom_scope . ") AND "; 
   $GETDOMLIST = "DONE"; }
if(($GETCLASS eq "TRUE") || ($GETCLASS eq "DONE")) { 
   $boxclass = "(" . $boxclass . ") AND "; 
   $GETCLASS = "DONE"; }
if(($GETSTATLIST eq "TRUE") || ($GETSTATLIST eq "DONE")) { 
   $box_stat = "(" . $box_stat . ") AND "; 
   $GETSTATLIST	= "DONE"; }
if(($GETSORTLIST eq "TRUE") || ($GETSORTLIST eq "DONE")) { 
   $sort_order =~ s/%host/oi.hostname/; 
   $sort_order =~ s/%rel/o.release/g ; 
   $sort_order =~ s/%ver/o.version/g ; 
   $sort_order =~ s/%dom/o.domain/; 
   $sort_order =~ s/%os/o.kernel/; 
   $GETSORTLIST	= "DONE"; }
   ($DEBUG) && (print "$sort_order\n") && (sleep 2); # (check a variable content and die)  die $sort_order;

$select_scope = $hostnames . $os_scope . $dom_scope . $boxclass . $bus_unit;


    $dbh = DBI->connect($dbname, $dbuser, $dbpass) or die "can't connect to $dbname: ", DBI::errstr;

    my @hostinfo=&SQLRetrieve("
    SELECT 
        oi.os_id, oi.hw_id, oi.hostname, o.kernel,
	o.release, o.version, o.domain, oi.class,
	oin.businessunit
    FROM
        usaowner.os_ident oi,
	usaowner.os o,
	usaowner.info oin
    WHERE 
	oi.os_id = o.os_id AND oi.os_id = oin.os_id AND oi.hostname is not NULL AND 
	$select_scope oi.status like '1%' 
	$sort_order");

    foreach $row ( sort @hostinfo )
    {
	my $cpu_cnt=0;
	my $hw_id=$row->{"HW_ID"};
	
	my @cpu=&SQLRetrieve("
	SELECT 
		cpu_id, model, speed, cache, status
	FROM
		usaowner.hw_cpu
	WHERE
		$box_stat hw_id = $hw_id");

	$match_found = @cpu;
	
	my ($c, $model, $speed, $cache, $status);
	foreach $c (@cpu)
	{
		$cpu_cnt++;
		$model=$c->{"MODEL"};
		$speed=$c->{"SPEED"};
		$cache=$c->{"CACHE"};
		$status=$c->{"STATUS"};
	}

	$foutput = $format;
	$foutput =~ s/%host/$row->{"HOSTNAME"}/g ;
	$foutput =~ s/%os/$row->{"KERNEL"}/g ; 
	$foutput =~ s/%rel/$row->{"RELEASE"}/g ; 
	$foutput =~ s/%ver/$row->{"VERSION"}/g ; 
	$foutput =~ s/%dom/$row->{"DOMAIN"}/g ; 
	$foutput =~ s/%class/$row->{"CLASS"}/g;
	$foutput =~ s/%bu/$row->{"BUSINESSUNIT"}/g;
	$foutput =~ s/%cpus/$cpu_cnt/g ; 
	$foutput =~ s/%mod/$model/g ; 
	$foutput =~ s/%sp/$speed/g ; 
	$foutput =~ s/%cs/$cache/g ; 
	$foutput =~ s/%stat/$status/g;

	if(( $match_found > 0 ) && ($GETSTATLIST eq "DONE")) { print "$foutput \n"; }
	if($GETSTATLIST eq "FALSE") { printf "$foutput \n"; }
	($DEBUG) && (die "run terminated");

}
	
sub SQLRetrieve
{
	my($query) =  @_;
	($DEBUG) && (print "Query Statement: $query\n");
	
	my @a=();
	my $sth = $dbh->prepare($query) || warn "couldn't prepare: ",  DBI::errstr, "\n";
	$sth->execute() || warn "couldn't execute: ", $sth->errstr(), "\n";
	while(my $ref = $sth->fetchrow_hashref())
	{
		push(@a, $ref);
	}
        $sth->finish();
	if(wantarray)
	{
		return @a;
	}
	else
	{
		return $a[0];
	}
}

sub sortList
{
	($debug) && (print "@sort_fields \n") && (sleep 10);
	if ($sort_fields[0] eq "") { @sort_fields = @rep_fields; }
	if ($sort_fields[0] eq "") { @sort_fields = @brief_fields; }
	$bad_sort_flds = "";
	foreach $rep (@sort_fields)
	{
		$bad_sort = 1;
		foreach $bf (@brief_fields)
		{
			if ($rep eq $bf)
			{
				$sort_order = $sort_order . $sort_prefix . $rep; 
				$bad_sort = 0;
				$sort_prefix = ", ";
				$GETSORTLIST = "TRUE";
			}
		}
		($bad_sort) && ($bad_sort_flds = $bad_sort_flds . $rep . " ");
	}
	($sort_order eq "") && die("@sort_fields is an invalid sort option\n");
	($debug) && ($bad_sort_flds ne "") && (print "Using sort option: ($sort_order)  discarding: ($bad_sort_flds)\n") && (sleep 7); }

sub PrintUsage
{
	die("Usage:\n  $script \n",
	   "           [-os    <OS name1  . . . OS name?>]     (filter on OS name(s))\n",
	   "           [-host  <hostname1 . . . hostname?...>] (filter on hostname(s))\n",
	   "           [-dom   <domname1  . . . domname?...>]  (filter on domain name(s))\n",
	   "           [-class <S|W>]                          (filter on box class\n",
	   "           [-stat  <ONLINE|OFFLINE|CLAIMED>]       (filter on box status(s))\n",
	   "           [-sort  <%dom|%host|%os>]               (ORDER BY field name(s))\n",
	   "           [-csv   <delimiter character>\n",
	   "           [-full include all fields in CSV output \n",
	   "           [-fmt  \"<user specified output record format entry>\"]\n",
	   "                   embed field names in text string for user-defined output\n\n",
	   "           [-fld  <fld1 . . . fld?>] (order fields for CSV output)\n\n",
	   "           Field Name        Data Field      Sample Data       \n",
	   "           %host             HOSTNAME        psdb1530          \n",
	   "           %os               KERNEL          SunOS             \n",
	   "           %rel              RELEASE         5.9               \n",
	   "           %ver              VERSION         Generic_112233-12 \n",
	   "           %dom              DOMAIN          olsprod           \n",
	   "           %cpus             CPU count       16                \n",
	   "           %mod              Model           US-IV             \n",
	   "           %sp               Speed           1200000           \n",
	   "           %cs               Cache Size      16777216          \n",
	   "           %stat             Status          OFFLINE           \n",
	   "           %class            Class           Server            \n\n",
	   "           [-example]  displays examples of script usage\n",
	   "           [-usage]    displays this usage screen\n",
	   "           [-version]  displays script version information\n",
	   "           * Synonymous switches:\n\n",
	   "              -csv can be used or -delim\n",
	   "              -dom can be used or -domain\n",
	   "              -ex  can be used or -example\n",
	   "              -fld can be used or -field\n",
	   "              -fmt can be used or -format\n",
	   "              -ver can be used or -version\n");
}


sub PrintTables
{
    ($DEBUG) && (print "test\n");
    $dbuser = "cpm_user";
    $dbpass = "cpm_user";
    $dbname = "dbi:Oracle:CPSERMON";

    $dbh = DBI->connect($dbname, $dbowner, $dbowner, {RaiseError => 1}) or die "can't connect to $dbname: ", DBI::errstr;

    my $tabsth = $dbh->table_info();
    ($DEBUG) && (print "$tabsth\n");

### Iterate through all the tables...
    while ( my ( $qual, $owner, $name, $type ) = $tabsth->fetchrow_array() ) {

    ($DEBUG) && (print "Owner {$owner}  Table {$name} \n");
    $validtbl = "FALSE";


    foreach $tname ( @dbtables ) {
       if($name eq $tname) { $validtbl = "TRUE"; }
    }   

    if(($owner eq "USAOWNER") && ($validtbl eq "TRUE")) {
  
        my $table = $name;
	$table = qq{"$owner"."$table"} if defined $owner;
	
#    while ( $tabsth->fetchrow_array() ) {                                                                          
        my $statement = "SELECT * FROM $table";

	print "\n";
	print "\nStatement:    $statement\n\n";
                                                    
	my $sth = $dbh->prepare( $statement );
	$sth->execute();

	my $fields = $sth->{NUM_OF_FIELDS};

	print "Column Name                     Size\n";
	print "------------------------------  ----\n";

	### Iterate through all the fields and dump the field information
	for ( my $i = 0 ; $i < $fields ; $i++ ) {

	    my $name = $sth->{NAME}->[$i];

	    my $size = $sth->{PRECISION}->[$i];

	    ### Display the field information
	    printf "%-30s %5d\n", $name, $size;
	}
	$sth->finish();
    }
    }
}

sub PrintExample
{
        $x = 1;
	print   "Example $x: \n\n",
		"       $script \n",
		"               displays a CSV of HOSTNAME KERNEL RELEASE VERSION DOMAIN\n\n",
		"       e.g:    psdb1530,SunOS,5.9,Generic_112233-12,olsprod \n\n";
	$x++;
	print	"Example $x: \n\n",
		"       $script -full \n",
		"               displays a CSV containing all fields\n\n",
		"       e.g:    psdb1530,SunOS,5.9,Generic_112233-12,olsprod,16,US-IV,1200000,16777216,OFFLINE\n\n";
	$x++;
	print	"Example $x: \n\n",
		"       $script -os linux% sunos% -host psc% psdb% -csv \"\|\" -fields %host %os %dom\n\n",
		"               displays a pipe delimited CSV report containing the following database fields\n",
		"                         HOSTNAME, RELEASE, and DOMAIN\n\n",
		"                  where: KERNEL   begins with linux or sunos (% allows trailing wildcard text)\n",
		"                         HOSTNAME begins with psc or psdb \n\n",
		"       e.g:    psdb1530|SunOS|olsprod \n\n";
	$x++;
	print	"Example $x: \n\n",
		"	$script -os linux% sunos% -host psc% psdb% -csv \"\|\" -sort %dom %os %host -field %host %os %dom\n\n",
		"               displays a pipe delimited CSV report containing the following database fields\n",
		"                         HOSTNAME, RELEASE, and DOMAIN\n\n",
		"                  where: KERNEL   begins with linux or sunos (% allows trailing wildcard text)\n",
		"                         HOSTNAME begins with psc or psdb \n",
		"               order by: domain, then by os, and then by hostname\n\n", 
		"       e.g:    psdb1530|SunOS|olsprod \n\n";
	$x++;
	print	"Example $x: \n\n",
		"       $script -host psdb1530 -format \"%host has %cpus processors running:\\ \\ \\ %os %rel\"\n\n",
		"       e.g:    psdb1530 has 16 processors running:   SunOS 5.9\n\n";
	print	"  note: you must escape out double quotes, pipe symbol, and multiple spaces\n\n";
	exit;
}

sub BuildOutRecFmt
{
	my($outrec);
	my($delimiter);

	$outrec = ""; 
	$delimiter = "";

	($DEBUG) && (print "@rep_fields\n\n") && (sleep 10);

	foreach $fldname (@rep_fields)
	{
	   $outrec = $outrec . $delimiter . $fldname;
	   $delimiter = $csv_char;
	}
	return $outrec;

	
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
}exit;

