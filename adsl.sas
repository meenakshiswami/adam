
libname sasfile "/home/u60094620/projectB/sas_dataset";
libname prog "/home/u60094620/projectB/programB";
libname output "/home/u60094620/projectB/output";

data dm1 (keep=STUDYID USUBJID SUBJID SITEID INVID INVNAM AGE AGEU SEX RACE 
		ETHNIC ARMCD ARM TRT01P TRT01PN COUNTRY);
	set sasfile.dm;

data adsl1;
	set dm1;

	if 18<=age<=40 then
		do;
			agegr1='18 - 40';
			agegr1n=1;
		end;
	else if 41<=age<=64 then
		do;
			agegr1='41 - 64';
			agegr1n=2;
		end;
	else if 65<=age then
		do;
			agegr1='>= 65';
			agegr1n=3;
		end;
	else
		do;
			agegr1='.';
			agegr1n=.;
		end;

	if upcase(arm)='CMP-135' THEN
		DO;
			TRT01P='CMP-135';
			TRT01PN=1;
		end;
	else if upcase(arm)='PLACEBO' THEN
		DO;
			TRT01P='Placebo';
			TRT01PN=0;
		end;
run;	
proc sort data =adsl1; by usubjid;run;
	/*extracting from ex*/
data ex;
	set sasfile.ex;
	by usubjid;
if first.usubjid then do;
	if upcase(extrt)='CMP-135' THEN
		DO;
			TRT01A='CMP-135';
			TRT01AN=1;
		end;
	else if upcase(extrt)='PLACEBO' THEN
		DO;
			TRT01A='Placebo';
			TRT01AN=0;
		end;
end;
else delete;		

/*****extracting Flags ,dates and discontinuation reason from ds****/
proc sort data=sasfile.ds out=ds;
	by usubjid dsstdtc;

data dc_trt(keep=usubjid trtdcdt  trtdcdtc trtdcrs TRTDCFL)
     ds_start(keep=usubjid  stdsdt stdsdtc randdt ittfl)
     ds_end(keep=usubjid stdedt stdedtc stddcrs STDDCFL COMPLFL)
     ds_fu(keep=usubjid sfuedt  sfuedtc  sfudcrs )
     ds_dth(keep=usubjid dthdt dthdcrs dthper dthtmfl)
     ;
     length dthper $30 ;
	set ds;
	by usubjid dsstdtc;
	

	if upcase(dscat)='DISPOSITION EVENT' and upcase(dsscat) in('CMP-135','PLACEBO') and upcase(epoch)='STUDY PERIOD'  then
			do;
			if dsdecod ne ' ' then TRTDCFL='Y';
	         else TRTDCFL='N';

			trtdcrs=dsdecod;
			if dsterm ne ' ' then
			     do;
			     trtdcdtc=dsdtc;
			       trtdcdt=input(dsdtc, is8601da.);
			     end;  
			output dc_trt;
		end;

	if upcase(dscat)='PROTOCOL MILESTONE' and upcase(dsterm)='RANDOMIZATION' and upcase(epoch)='SCREENING' then
			do;
			stdsdtc=dsstdtc;
			stdsdt=input(dsstdtc, is8601da.);
			randdt=stdsdt;

			if randdt>0 then ittfl='Y';
			else ittfl='N';
			output ds_start;
		end;

	if upcase(dscat)='DISPOSITION EVENT' and upcase(dsscat)='STUDY PERIOD' and upcase(epoch)='STUDY PERIOD' then
			do;
			if dsterm ne ' ' then STDDCFL='Y'; else STDDCFL='N';
          if upcase(strip(dsterm)) IN('DISEASE PROGRESSION - RADIOGRAPHIC' ,'DEATH')Then COMPLFL='Y';
		   else COMPLFL='N';
		   
			stdedtc=dsstdtc;
			stdedt=input(dsstdtc, is8601da.);

			if first.dsstdtc then
				stddcrs=dsdecod;
			
				output ds_end;
		end;

	if upcase(dscat)='DISPOSITION EVENT' and upcase(dsscat)='FOLLOW-UP' and upcase(epoch)='SURVIVAL FOLLOW-UP' then
			do;
			sfuedtc=dsstdtc;
			sfuedt=input(dsstdtc, is8601da.);
			
			output ds_fu;
		end;

	if upcase(dscat)='OTHER EVENT' and upcase(dsscat)='DEATH' and upcase(epoch) IN('STUDY PERIOD', 'SURVIVAL FOLLOW-UP') then
			do;
			dthdt=input(dsstdtc, is8601da.);
			dthdcrs=strip(dsterm);
			if upcase(epoch)='STUDY PERIOD' then do; dthper='STUDY PERIOD';  dthtmfl='STD';end;
			else if upcase(epoch)='SURVIVAL FOLLOW-UP' then do; dthper='SURVIVAL FOLLOW-UP PERIOD'; dthtmfl='SFU';end;
			output ds_dth;
		end;
	
data ds_adsl;
merge adsl1 (in=a) dc_trt
     ds_start
     ds_end
     ds_fu
     ds_dth;
by usubjid; 
if a;    

	/*finding stddur from ds*/
proc sql;
	create table study_st as select usubjid, stdsdt from ds_adsl where stdsdt ^=. group by usubjid;
	create table study_ed as select usubjid, stdedt from ds_adsl where stdedt ^=. group by usubjid;
quit;

data ds_merge;
	merge study_st study_ed;
	by usubjid;

	if stdedt>stdsdt then
		stddur=stdedt-stdsdt+1;
	else
		stddur=.;

	/*flag from suppds*/

proc sql;
	create table suppds as select distinct(usubjid),qval as sfufl from sasfile.suppds where qnam='DSFUYN' ;


	/*finding dates and trtdur from da*/
	proc sql;
create table da1 as select usubjid, min(darftdtc) as trtsdtc
	from sasfile.da where darftdtc ne ' ' and dastresn>0
	group by usubjid;

create table da2 as select usubjid,max(dadtc) as trtedtc
	from sasfile.da where dadtc ne ' ' and dastresn>0
	group by usubjid;
	
data mergd_da;
merge da1 da2;	
by usubjid;
	trtsdt=input(trtsdtc, is8601da.);
	trtedt=input(trtedtc, is8601da.);
		
	if trtedt>trtsdt then
		trtdur=trtedt-trtsdt+1;
	else
		trtdur=.;

	/*finding RSP125, remissn from zh*/
proc sort data=sasfile.zh;
	by usubjid;
run;

proc transpose data=sasfile.zh out=zh1;
	by usubjid;
	var zhorres;
	id zhtestcd;

data zh2;
	set zh1(rename=(DXRMS=remiss));

	if RSP125YN='Y' then
		RSP125='Y';
	else
		RSP125='N';

	if remiss='SECOND COMPLETE REMISSION' then
		remissn=1;
	else if remiss='THIRD COMPLETE REMISSION' then
		remissn=2;
	Else
		remissn='.';
	keep usubjid hsubtyp hpathtyp RSP125 remiss remissn;

	/*finding bwt, bht from vs*/
proc sql;
	create table vs1 as select usubjid, visit, visitnum, vstestcd , vsdtc, 
		vsstresn from sasfile.vs where vstestcd in ('WEIGHT') and visitnum in (1, 2) 
		and vsstresn>0 and vsdtc ^=" " order by usubjid, visitnum , vsdtc;

data vs11;
	set vs1;
	by usubjid;
	bwt=vsstresn;

	if last.usubjid;

proc sql;
	create table vs2 as 
	select usubjid, visitnum, vstestcd , vsdtc, max(vsstresn) as bht from sasfile.vs 
		where vstestcd='HEIGHT' and visitnum=1 and vsstresn>0 and vsdtc ^=" " 
		group by usubjid order by usubjid, visitnum , vsdtc;
 

	/*finding becog from qs*/

data qs11;
set sasfile.qs 
	(where =(qstestcd ='ECOG' and visitnum in (1, 2) and qsstresn>=0));
by usubjid;
becog=qsstresn;
if last.usubjid;

/*finding  from yp ,xr,cm*/
	/***prior surgery***/
proc sql;
	create table surgery as select distinct(usubjid), max(ypendtc) as prtxdtc , ypcat from sasfile.yp
	where ypcat='PRIOR CANCER-RELATED SURGERY OR PROCEDURE' 
		group by usubjid;
  /***prior radiotherapy***/
proc sql;
	create table radiotx as select distinct(usubjid), max(Xrendtc) as prtxdtc from sasfile.xr 
	where xroccur='Y' group by usubjid;
  /***prior cancer systemic therapy***/
proc sql;
	create table systx as select distinct(usubjid), max(cmendtc) as prtxdtc from sasfile.cm 
		where cmcat='PRIOR CANCER THERAPY' group by usubjid;

/*concatenating all 3 therapy and imputing dates to june-15 */
data yp_xr_cm;
	set surgery radiotx systx;
by usubjid;
	if length(prtxdtc)=10 then
		prtxdt=input(prtxdtc, is8601da.);
	else if length(prtxdtc)=7 then
		prtxdt=input(prtxdtc, is8601da.)||'-15';
	else if length(prtxdtc)=4 then
		prtxdt=input(prtxdtc, is8601da.)||'-06-15';
run;
	/*to find latest therapy and date*/	
proc sql;
create table prtx as select usubjid, max(prtxdt)as prtxdt format is8601da. from yp_xr_cm group by usubjid ;

/*flags*/
data flags;
	merge surgery(in=a keep=usubjid) radiotx(in=b keep=usubjid) systx(in=c keep=usubjid);
by usubjid	;
if a then prsurgfl='Y';
	else prsurgfl='N';

if b then prradfl='Y';
	else prradfl='N';

if c THEN prsysfl='Y';
	else prsysfl='N';

		
/*finding  from tu*/
proc sql;
	create table tu as select distinct(usubjid) 
	from sasfile.tu where visitnum>1 and strip(tuspid)='CTSA'	and tuorres ^=' ';
	
/*merging all dataset*/	
proc sort data =suppds; by usubjid;run;
	
data final;
merge adsl1(in=a)  ex ds_adsl ds_merge suppds qs11  zh2  mergd_da  prtx flags  vs11  vs2  tu(in=t);
by usubjid;	
if a;

if becog= . then becog=0 ;
if sfuedt>0 then SFUDCFL='Y';else SFUDCFL='N';
if dthdt>0 then dthfl='Y';
if trtsdt>0 then SAFFL='Y';ELSE SAFFL='N';
if saffl='Y' and RSP125='Y' Then CA125FL='Y'; else CA125FL='N';
if(t and SAFFL='Y' and remissn>0  ) then  effl='Y'; else effl='N';

if randdt ne . and prtxdt ne . then prtxdur=(randdt-prtxdt+1)/7;
	else prtxdur=.;	
	
fpdate=max(stdedt,sfuedt);
if trtsdt*fpdate>0 then fpdur=(fpdate-trtsdt+1)	;
run;

/*labelling*/
data output.adsl_f;
	attrib
	STUDYID label="study identifier" length=$8.
	USUBJID label="unique subject identifoer" length=$21
	SUBJID label="subject identifier for the study" length=$5.
	SITEID label="study site identifier" length=$6
	INVID label="investigator identifier" length=$5.
	INVNAM label="investigator name" length=$50
	AGE label="age" length=8.
	AGEU label="Age Units" length=$5.
	SEX label="sex" length=$1.
	RACE label="race" length=$32.
	ETHNIC label="ethnicity" length=$22.
	ARMCD label="planned arm code" length=$8.
	ARM label="planned arm" length=$40
	COUNTRY label="country" length=$3.
	AGEGR1 label = 'Age Group1(char)'  length =$8
	AGEGR1N label = 'Age Group1(num)'  length =8
	TRT01P label = 'Planned Treatment'  length =$10
	TRT01PN label = 'planned Treatment number'  length =8
	TRT01A label = 'Actual Treatment'  length =$10
	TRT01AN label = 'Actual Treatment Number'  length =8
	ITTFL label = 'Intent-to-treat population flag'  length =$1
	SAFFL label = 'safety population flag'  length =$1
	EFFL label = 'efficacy-evaluable population flag '  length =$1
	CA125FL label = 'efficacy-evaluable CA125 population flag '  length =$1
	TRTDCFL label = 'treatment discountinuation flag'  length =$1
	COMPLFL label = 'study period completers flag'  length =$1
	STDDCFL label = 'study period discontinuation flag'  length =$1
	SFUDCFL label = 'follow-up discontinuation flag'  length =$1
	SFUFL label = 'survival follow-up period entry flag'  length =$1
	DTHFL label = 'death population flag'  length =$1
	DTHTMFL label = 'death time flag' length = $3
	RANDDT label = 'randomization date'  format=IS8601DA.
	TRTSDTC label = 'first treatment date(char)'  length =$20
	TRTSDT label = 'first treatment date(num)'   format=IS8601DA.
	TRTEDTC label = 'last treatment date(char)'  length =$20
	TRTEDT label = 'last treatment date(num)'  format=IS8601DA.
	TRTDCDT label = 'treatment discountinuation date '  format=IS8601DA.
	STDSDTC label = 'study start date (char)'  length =$20
	STDSDT  label = 'study start date'  format=IS8601DA.
	STDEDT label = 'study end date'  format=IS8601DA.
	STDEDTC label = 'study end date (char)'  length =$20
	SFUEDTC label = 'survival follow-up end date(char)'  length =$20
	SFUEDT label = 'survival follow-up end date '  format=IS8601DA.
	DTHDT label = 'date of death'  format=IS8601DA.
	TRTDUR label = 'Duration of treatment'  length =8
	STDDUR label = 'duration of study period(days)'  length =8
	FPDUR label = 'safety follow-up duration(days)'  length =8
	
	DTHPER label = 'death time period'  length =$30
	TRTDCRS label = 'tratment discontinuation reason'  length =$80
	STDDCRS label = 'stuady period discontinuation reason'  length =$80
	DTHDCRS label = 'death reason'  length =$80
	
	
	PRTXDT label = 'last prior cancer treatment date' format=IS8601DA.
	PRTXDUR label = 'weeks since last prior cancer TX'  length =8
	PRSURGFL label = 'prior cancer surgery flag'  length =$1
	PRRADFL label = 'prior cancer radiotherapy flag'  length =$1
	PRSYSFL label = 'prior cancer systemic therapy flag'  length =$1
	BWT label = 'baseline weight'  length =8
	BHT label = 'baseline height'  length =8
	BECOG label = 'baseline ECOG score'  length =8
	REMISS label = 'current remission status(char)'  length =$40
	REMISSN label = 'current remission status(num)'  length =8
	RSP125 label = 'CA-125 responder flag'  length =$1
	HPATHTYP label = 'histopathologic type'  length =$40
	HSUBTYP label = 'histologic subtype'  length =$40;
	set final;
	keep STUDYID  USUBJID SUBJID SITEID INVID INVNAM AGE AGEU SEX RACE ETHNIC COUNTRY
	ARMCD ARM AGEGR1	AGEGR1N	TRT01P	TRT01PN	TRT01A	TRT01AN	ITTFL	SAFFL
	EFFL	CA125FL	TRTDCFL	COMPLFL	STDDCFL	SFUDCFL	SFUFL	DTHFL DTHTMFL	RANDDT	TRTSDTC
	TRTSDT	TRTEDTC	TRTEDT	TRTDCDT	STDSDTC	STDSDT 	STDEDT	STDEDTC	SFUEDTC	SFUEDT
	DTHDT	TRTDUR	STDDUR	FPDUR	DTHPER	TRTDCRS	STDDCRS	DTHDCRS	PRTXDT	PRTXDUR
	PRSURGFL	PRRADFL	PRSYSFL	BWT	BHT	BECOG	REMISS	REMISSN	RSP125	HPATHTYP
	HSUBTYP;
run;
	
/*converting xpt in sasfile*/	
libname sas_v  "/home/u60094620/projectB/adam_v";
libname xpt xport "/home/u60094620/projectB/adam_v/ADSL.xpt" access=readonly; 
proc copy inlib=xpt outlib=sas_v; run;



/*validation of sas files*/
proc compare base=output.adsl_f compare=sas_v.adsl;
run;