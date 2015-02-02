/*
	Assignment #3

	Topics: Macros, CRSP (CCM, DSF, MSF, DSIX, MSIX)

	1. Stock return over window
	Write SAS code to compute yearly abnormal stock return (monthly firm return - monthly index return) 
	over 2006-2009 for firms in the financial industry. 
	Use the vwretd (value weighted) index return in MSIX.

	*************************************************
*/

/* What follows is a logic outline to accomplish the assignment:

1)	financial industry is found in the 6000's SIC codes 
2)	MSF has monthly returns for stocks in CRSP
		I guess if any particular stock has problems (e.g., a missing value in an interior month) 
		it would be good to check that;
		for now presume that is not a concern
3)	MSIX has monthly index returns
4)	check that MSIX has all 4*12=48 monthly returns
5)	for each stock, calculate a monthly excess return, MERsubMandI = monthlystockreturnsubMandI - monthlyIXsubM,
		and a "monthly value growth factor", MVGFsubMandI = 1 + MERsubMandI
6)	for each stock, count number of months of excess returns per year, NofMinYsubI
		for example, ABC has returns from June 2006 to Nov 2009, so it has 7 monthly returns in 2006,
		and 11 monthly returns in 2009, and 12 monthly returns in 2007 and 2008
7)	for each year (or partial year) calculate NofMinYsubI-th root of the geometric sum to get annual excess return,
		AERsubYandI = (product of monthly MVGFsubMandI)^(1/NofMinYsubI) - 1
8)	No report output specified.  Maybe SumStats or other PROC MEANS just to check?

	*************************************************
*/

*  WRDS remote access: setup;
%let wrds = wrds.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;

/* rsubmit-endrsubmit block to obtain data from WRDS after remote access*/
rsubmit;
libname myfiles "~"; /* ~ is home directory in Linux, e.g. /home/ufl/victorj */

* get the MSF monthly returns;
proc sql;
	create table myfiles.MSF as
		select cusip, permno, HSICCD, date, month(date) as MSFmonth, 
		year(date) as MSFyear, ret
		from crsp.msf
		where 
			6000 <= HSICCD <= 6999
			and 2006 <= calculated MSFyear <= 2009;	
quit;


proc download data=myfiles.MSF out=MSF; run;

* get the MSIX monthly index returns;
proc sql;
	create table myfiles.MSIX as
		select caldt, vwretd, month(caldt) as MSIXmonth, 
		year(caldt) as MSIXyear
		from crsp.msix
		where 
			2006 <= calculated MSIXyear <= 2009;
quit;
proc download data=myfiles.MSIX out=MSIX; run;

endrsubmit;
/*remove all stocks where any month has a non-numeric return.
source for code comes from:
https://communities.sas.com/message/19883 
and
http://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a002194060.htm
*/
data MSF;
set MSF;
if anyalpha(ret) ne 0 then dropflag = 1;
if ret = . then dropflag = 1;
run;
/* not sure how to drop entire set of obs for same permno if only one month has a dropflag */

* check that MSIX has 4 years of 12 entries;
proc means data=MSIX NOPRINT; /* suppress output to screen */
  /* but, do output to dataset */
  OUTPUT OUT=MSIXOutput n=;
  by MSIXyear;
run;
/*
	for each stock, calculate a monthly excess return, 
	MERsubMandI = monthlystockreturnsubMandI - monthlyIXsubM,
	and a "monthly value growth factor", MVGFsubMandI = 1 + MERsubMandI
*/
proc sql;
	create table MER as
		select a.cusip, a.permno, a.HSICCD, a.date,
			a.MSFmonth, b.MSIXmonth, a.MSFyear, b.MSIXyear, a.ret, b.vwretd,
			a.ret - b.vwretd as MERsubMandI,
			1 + calculated MERsubMandI as MVGFsubMandI
		from MSF a, MSIX b
		where a.MSFmonth = b.MSIXmonth
		and a.MSFyear = b.MSIXyear
		order by a.permno, a.MSFyear, a.MSFmonth;
quit;

/*for each stock, count number of months of excess returns per year, NofMinYsubI*/
proc means data=MER NOPRINT;
output out=NofMinYperI n(MSFmonth)=NofMinYsubI;
by permno MSFyear;
run;

/*for each year (or partial year) and for each stock, calculate NofMinYsubI-th root 
  of the geometric sum to get annual excess return, 
  AERsubYandI = (product of monthly MVGFsubMandI)^(1/NofMinYsubI) - 1*/

* first, determine the product of monthly MVGFsubMandI,
  "annual value growth factor", AVGFsubYandI = MVGFsub1andI * MVGFsub2andI * etc;
*feels like a data step with retain;
data AVGF;
set MER;
retain AVGFsubYandI;
by permno MSFyear MSFmonth;
if first.MSFmonth then AVGFsubYandI = MVGFsubMandI;
AVGFsubYandI = lag(AVGFsubYandI) * MVGFsubMandI;
run;

/*
I'm stuck and I can't think anymore.  I'm submitting this for whatever little partial
credit you'll give me*/
