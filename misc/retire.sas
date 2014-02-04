I believe this is it.  The last time it was touched was march of 2005.
Lots of stuff that just set up the HTML (the SAS stuff was junk at the time).
Highlighted are the core metric(s) that were used.

Gordon L. Galloway
Consulting Capacity & Performance Eng.
Reed Elsevier Technology Services
(937) 247-1723


%macro HTML_Head1;
	put 
	'<STYLE type="text/css">' /
	'.selection' / '{' / '	COLOR: blue;' / '	FONT-FAMILY: Arial;' / '	FONT-SIZE: 10pt;' / '	FONT-WEIGHT: normal;' / '	TEXT-DECORATION: underline;' / '	CURSOR: Hand;' / '}' /
	'.detail' / '{' / '	COLOR: black;' / '	FONT-FAMILY: Arial;' / '	FONT-SIZE: 10pt;' / '	FONT-WEIGHT: normal;' / '	CURSOR: default;' / '}' / 
	'</STYLE>' /
	'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">' /
	'<HTML><HEAD><META NAME="GENERATOR" CONTENT="SAS Institute Inc. HTML Formatting Tools, http://www.sas.com/">' /
	'<TITLE>Server Use by Business Unit & Role</TITLE></HEAD><BODY BGCOLOR=#FFFFFF TEXT=black>' /
	'<PRE><H3><FONT FACE=times COLOR=green SIZE="+2">' /
	'Current Use of Servers by Business Unit & Role.<BR>' /
	"Data as of &sysdate..</FONT></H3></PRE><P>";
%mend;
%macro Table1;
	put
	'<TABLE BORDER="3" ALIGN="LEFT" CELLPADDING="3" CELLSPACING="1" BGCOLOR=#FFFFEE>' /
	'  <CAPTION ALIGN="LEFT" VALIGN="TOP"><FONT FACE=arial COLOR=red>Select Business Unit</FONT>&nbsp&nbsp&nbsp' /
	'  Low Use:<IMG SRC="../../Images/DotBlue.gif">&nbsp&nbsp&nbsp' /
	'  Target Use:<IMG SRC="../../Images/DotGreen.gif">&nbsp&nbsp&nbsp' /
	'  High Use:<IMG SRC="../../Images/DotRed.gif">' /
	'  </CAPTION>' /
	'        <TR>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">Business / Group / Role / Domain</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">Avg. CPU</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">Avg. Mem</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">1-Ways</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">2-Ways</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">4-Ways</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">8-Ways</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-1">Server Count</FONT></TH>' /
	'        </TR>';
%mend;
%macro TR1(item=BusiUnit);
	put
	'  <TR><TD ALIGN="LEFT" VALIGN="TOP" NOWRAP>' /
	'        <DIV><SPAN class="selection" onclick="javascript:ToggleMenu(''' ID +(-1) ''')">' /
	'        <FONT COLOR="blue"><U><STRONG>' &item '</STRONG></U></FONT></SPAN></DIV></TD>' /
	'      <TD class="detail" ALIGN="CENTER" WIDTH="5%" VALIGN="MIDDLE">' CPU '</TD>' /
	'      <TD class="detail" ALIGN="CENTER" WIDTH="5%" VALIGN="MIDDLE">' MEM '</TD>' /
	'      <TD class="detail" ALIGN="CENTER" WIDTH="5%" VALIGN="MIDDLE">' c1_way '</TD>' /
	'      <TD class="detail" ALIGN="CENTER" WIDTH="5%" VALIGN="MIDDLE">' c2_way '</TD>' /
	'      <TD class="detail" ALIGN="CENTER" WIDTH="5%" VALIGN="MIDDLE">' c4_way '</TD>' /
	'      <TD class="detail" ALIGN="CENTER" WIDTH="5%" VALIGN="MIDDLE">' c8_way '</TD>' /
	'      <TD class="detail" ALIGN="CENTER" WIDTH="8%" VALIGN="MIDDLE">' SCnt '</TD></TR>' /
	'  <TR><TD COLSPAN="8"><TABLE WIDTH="' width +(-1) '" ID=''' ID +(-1) ''' BORDER="3" ALIGN="RIGHT" CELLPADDING="3" CELLSPACING="1" style="CURSOR:Hand; display:none" BGCOLOR=' bgcolor '>';
%mend;
%macro TR2;
	put
	'        <TR>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-2">Server</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-2">CPU</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-2">Memory</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-2"># Proc</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-2">Proc MHz</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-2">OS</FONT></TH>' /
	'          <TH BGCOLOR=yellow ALIGN="CENTER" VALIGN="MIDDLE"><FONT FACE=arial COLOR=black SIZE="-2">Retirement</FONT></TH>' /
	'        </TR>';
%mend;
%macro TR3;
	put
	'  <TR><TD ALIGN="LEFT" VALIGN="TOP" NOWRAP>' /
	'        <DIV><SPAN class="selection" onclick="javascript:ToggleMenu(''' ID +(-1) ''')">' /
	'        <FONT COLOR="blue"><U><STRONG>' SysName '</STRONG></U></FONT></SPAN></DIV></TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="5%">' / CPUhref /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="5%">' / MEMhref /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="5%">' Procs '</TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="8%">' MHz '</TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE">' OS '</TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE">' Retire '</TD>' /
	'  <TR><TD COLSPAN="7"><TABLE WIDTH="' width '" ID=''' ID +(-1) ''' BORDER="3" ALIGN="RIGHT" CELLPADDING="3" CELLSPACING="1" style="CURSOR:Hand; display:none" BGCOLOR=' bgcolor '>';
%mend;
%macro TR4;
	put
	'      <TR>' /
	'        <TD class="detail" ALIGN="LEFT" VALIGN="MIDDLE" NOWRAP><STRONG>' SysName '</STRONG></TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="5%">' / CPUhref /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="5%">' / MEMhref /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="5%">' Procs '</TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE" WIDTH="8%">' MHz '</TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE">' OS '</TD>' /
	'        <TD class="detail" ALIGN="CENTER" VALIGN="MIDDLE">' Retire '</TD>' /
	'      </TR>';
%mend;
%macro TR5;
	put
	'      <TR><TD class="detail" ALIGN="LEFT" VALIGN="MIDDLE" NOWRAP>' Project '</TD></TR>';
%mend;
%macro Table4_End;
	put '    </TABLE></TD></TR>';
	%mend;
%macro Table_End;
	put '</TABLE>';
%mend;
%macro LineRule;
	put '<BR CLEAR="ALL"><HR>';
%mend;
%macro HTML_End1;
	put
	'<PRE><H3><FONT FACE=times COLOR=green> LEXIS-NEXIS Confidential<BR>' /
	'For further information contact <a href="mailto: nt.cpm@lexisnexis.com">NT CPM</a></FONT></H3></PRE><HR></BODY>' /
	'<script language="JavaScript">' /
	'function ToggleMenu(strMenu) {' /
	' if (document.all.item(strMenu)) {' /
	" document.all.item(strMenu).style.display=document.all.item(strMenu).style.display=='none' ? 'block' : 'none' ;  " /
	' }' /
	' }' /
	'</script></HTML>';
%mend;

data _null_;  length dd $22.;
	dd = '''' || trim(left(put(datetime()-2419200, IS8601DN.))) || ' 00:00:00' || '''';  
	call symput('SQLdate', dd);  run;

proc sql;
	connect to ODBC as PerfNTIntranet (noprompt = "uid=ntperfdbo;pwd=idontcare;dsn=PerfNTIntranet");
	create table Stats as Select * from connection to PerfNTIntranet
(	
	SELECT convert(char(20),Systems.SysName) AS SysName,
		Objects.ObjName,
		tblSystemStats.[Date],
		tblSystemStats.Statistic,
		tblSystemStats.[Value],
		tblSystemStats.Time_Period, 
		tblSystemStats.InstID,
		Counters.CntrName,
		Counters.Units,
		SysGroup
	FROM tblSystemStats 
		INNER JOIN Objects ON tblSystemStats.objID = Objects.ObjID
		INNER JOIN Systems ON tblSystemStats.SysID = Systems.SysID
		INNER JOIN Counters ON tblSystemStats.cntID = Counters.CntrID
	WHERE (tblSystemStats.[Date] > CONVERT(DATETIME, &SQLdate, 102)) AND (Time_Period = '8am to 8pm') AND 
      	( (ObjName = 'Memory') AND (CntrName = 'Available Bytes') AND (Statistic = '10th Percentile') OR
      	  (ObjName = 'Memory') AND (CntrName = 'Pages/sec') AND (Statistic = '90th Percentile') OR
      	  (ObjName = 'Processor') AND (CntrName = '% Processor Time') AND (Statistic = '90th Percentile') )
)
	disconnect;

data Stats;  set Stats;
	SysName = upcase(SysName);
	date = datepart(date);
	if 1 < weekday(date) < 7;
	if CntrName = '% Processor Time' then Counter = 'Processor';
	else if CntrName = 'Pages/sec' then Counter = 'Paging';
	else if CntrName = 'Available Bytes' then Counter = 'MemUse';
	CntrName = compress(trim(ObjName)||'|'||trim(CntrName)||'|'||substr(Statistic,1,3),'%');
	run;

proc sort data=Stats;  by SysGroup SysName Counter CntrName;  run;

proc summary data=Stats;  by SysGroup SysName Counter CntrName;
	var value;  output out=Stats(drop=_type_ _freq_) mean=;  run;

proc transpose data=Stats out=Stats(drop=_NAME_ _LABEL_);  by SysGroup SysName;
	ID Counter;  IDlabel CntrName;  var Value;   run;
	

proc sql;
	connect to ODBC as DCNSSystems (noprompt = "uid=cpmuser;pwd=ConSol1D8;dsn=DCNSSystems");
	create table BusUnit as select * from connection to DCNSSystems
(
	SELECT convert(char(20),BusinessUnit.vcBusinessUnitName) AS BusiUnit,
		Project.vcProjectName AS Project,
		convert(char(20),Server.vcServerName) AS SysName, 
		Server.inServerNumProcessors AS Procs,
		Server.inServerProcessorSpeed AS MHz,
		Server.inServerMemory AS Memory, 
		convert(char(30),ServerRole.vcServerRoleName) AS ServerRole,
		convert(char(20),[Domain].vcDomainName) AS DomainName,
		convert(char(20),[Group].vcGroupName) AS GroupName,
		convert(char(60),ServerOS.vcServerOSName) AS OS,
		dtServerPurchaseDate AS Purchase
	FROM Project 
		INNER JOIN ProjectServer ON Project.inProjectID = ProjectServer.inProjectID
		INNER JOIN BusinessUnit ON Project.inBusinessUnitID = BusinessUnit.inBusinessUnitID 
		RIGHT OUTER JOIN Server ON ProjectServer.inServerID = Server.inServerID
		INNER JOIN ServerRole ON Server.inServerRoleID = ServerRole.inServerRoleID 
		INNER JOIN [Domain] ON Server.inDomainID = [Domain].inDomainID
		INNER JOIN [Group] ON Server.inGroupID = [Group].inGroupID
		INNER JOIN ServerOS ON Server.inServerOSID = ServerOS.inServerOSID
	WHERE (inProjectStatus is NULL OR inProjectStatus = 1) AND
		[Domain].inDomainTypeID <> 2 AND inServerStatus = 1
	ORDER BY BusinessUnit.vcBusinessUnitName, Project.vcProjectName, Server.vcServerName
)
	disconnect;

data BusUnit;  set BusUnit;
	SysName = upcase(SysName);
	Retire = datepart(Purchase) + 1096;  format Retire date.;
	run;

proc sort data=BusUnit;  by SysName;  run;
proc sort data=Stats;  by SysName;  run;

data Stats sumry;  merge Stats(in=a) BusUnit(in=b);  by SysName;
	if (a and b) or (GroupName not in('','[Unknown]'));
	if BusiUnit='' then BusiUnit='[Unknown]';
	if Project='' then Project='[Unknown]';
	if (a and b) then do;
		MEMtarget = .7;  
		if Memory in(.,0) then MEM = .;
		else if index(SysName,'SQL')>0 then MEM=1;
		else do;
			MEM = 1 - (MemUse / (1024*Memory));
			if MEM <= MEMtarget then MEM = (MEM/MEMtarget - 1)**3 + 1;
			else MEM = ((MEM-1)/(1-MEMtarget) + 1)**3 + 1;
			end;
		CPUtarget = .7;  CPU = Processor/100;
		if CPU <= CPUtarget then CPU = (CPU/CPUtarget - 1)**3 + 1;
		else CPU = ((CPU-1)/(1-CPUtarget) + 1)**3 + 1;
		end;
	else do;  MEM=.;  CPU=.;  end;
	*keep ServerRole BusiUnit Processor SysName CPU MEM;
	run;

proc sort data=Stats;  by BusiUnit GroupName ServerRole DomainName SysName;  run;
proc sort data=sumry nodupkey;  by BusiUnit GroupName ServerRole DomainName SysName;  run;

proc summary data=sumry missing;  class Procs DomainName ServerRole GroupName BusiUnit;
	var CPU MEM;
	output out=sumry(where=(_type_ in(1,3,7,15,17,19,23,31))) n=Cnt mean=;
	run; 
proc sort data=sumry nodupkey;  by BusiUnit GroupName ServerRole DomainName Procs;  run;
data sumry;  set sumry;  by BusiUnit GroupName ServerRole DomainName Procs;
	retain SCnt c_way c1_way c2_way c4_way c8_way 0;
	if first.DomainName then do;
		SCnt=0;  c_way=0;  c1_way=0;  c2_way=0;  c4_way=0;  c8_way=0;
		end;
	if Procs=. then SCnt=Cnt;
	else if Procs=. then c_way=Cnt;
	else if Procs=1 then c1_way=Cnt;
	else if Procs=2 then c2_way=Cnt;
	else if Procs=4 then c4_way=Cnt;
	else if Procs=8 then c8_way=Cnt;
	if last.DomainName then output;
	drop Procs Cnt _type_ _freq_;  run;

filename BUrpt "&webout.BusinessUnit\reports\BusiUnit.htm";
proc format;
	picture Dot . = '??'
				0.000-0.977 = '<IMG SRC="../../Images/DotBlue.gif">'
				0.977-1.037 = '<IMG SRC="../../Images/DotGreen.gif">'
				1.037-2.000 = '<IMG SRC="../../Images/DotRed.gif">'
				2.000-high  = '??'  (noedit);
	
data _null_;  file BUrpt ls=220;
	length ID $10. CPUhref MEMhref $220.;  format ID $varying10. CPU MEM Dot. Procs 3. MHz 7.;
	retain Tab 'A' bgcolor '#EEEEEE' nnum indent 0;
	if indent=0 then do;
		set sumry;  by BusiUnit GroupName ServerRole DomainName;
		if _n_=1 then do;  %HTML_Head1;  %Table1;  end;
		if first.BusiUnit then do;  bgcolor='#FFEEFF';  width='99%';  link productID;  %TR1(item=BusiUnit);  end;
		else if first.GroupName then do;  bgcolor='#EEFFFF';  width='98%';  link productID;  %TR1(item=GroupName);  end;  
		else if first.ServerRole then do;  bgcolor='#FFFFEE';  width='97%';  link productID;  %TR1(item=ServerRole);  end;
		else if first.DomainName then do;   bgcolor='#FFFFFF';  width='96%';  link productID;  %TR1(item=DomainName);  %TR2;  indent=1;  end;
		end;
	if indent=1 then do;
		set Stats end=eof;  by BusiUnit GroupName ServerRole DomainName SysName;
		if first.SysName and last.SysName and Project='' then do; link ServDom;  %TR4;  end;
		else do;  
			if first.SysName then do;  bgcolor='#FEFEFE';  width='94%';  link ServDom;  %TR3;  end;
			%TR5;
			if last.SysName then do;  %Table4_End;  end;
			end;
		if last.DomainName then do;  %Table4_End;  indent=0;  end;
		if last.ServerRole then do;  %Table4_End;  end;
		if last.GroupName then do;  %Table4_End;  end;
		if last.BusiUnit then do;  %Table4_End;  end;
		if eof then do;
			%Table_End;
			%LineRule;
			%HTML_End1;
			end;
		end;
	return;
ServDom:
	if SysGroup ~= '' then do;
		CPUhref='<A href="http://www-cpm/PerfCharts/wfPerfChart.aspx?domain=' || trim(SysGroup) || '&Server=' || trim(SysName)|| '&CounterName=Processor:%%20Processor%20Time:_Total" target="_blank">' || trim(put(CPU, Dot.)) || '</A></TD>';
		MEMhref='<A href="http://www-cpm/PerfCharts/wfPerfChart.aspx?domain=' || trim(SysGroup) || '&Server=' || trim(SysName)|| '&CounterName=Memory:Available%20Bytes:N/A" target="_blank">' || trim(put(MEM, Dot.)) || '</A></TD>';
		end;
	else do;
		CPUhref=trim(put(CPU, Dot.));
		MEMhref=trim(put(MEM, Dot.));
		end;
productID:
	nnum+1;  ID=trim(Tab)||trim(left(put(nnum,5.)));
	return;
	run;

proc datasets;  delete BusUnit Stats Sumry;  run;  quit;

