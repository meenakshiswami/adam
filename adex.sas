
libname sasfile "/home/u60094620/projectB/sas_dataset";
libname prog "/home/u60094620/projectB/programB";
libname output "/home/u60094620/projectB/output";
data adsl;
set output.adsl_f;
days=(TRTEDT-TRTSDT+1);
TRTP= TRT01P;
keep STUDYID  USUBJID SUBJID SITEID INVID INVNAM AGE AGEU SEX RACE ETHNIC
RANDDT COUNTRY	 AGEGR1	AGEGR1N	TRT01P	TRT01PN	TRT01A	TRT01AN	ITTFL	SAFFL	EFFL	
CA125FL	TRTDCFL	COMPLFL	STDDCFL	SFUDCFL	SFUFL	REMISS	
REMISSN	TRTSDT	TRTEDT 	TRTDUR	FPDUR days;
run;

/*DURATION (MONTHS) TREATMENT RECEIVED*/
data durn (keep=USUBJID param paramcd aval dtype);
length param $40 paramcd $8 dtype $40;
set adsl;
param='Duration of Treatment Received (months)';
paramcd='TXDUR';
If trtsdt ne . then aval=(TRTEDT-TRTSDT+1)/30.4375;
dtype='DIFFERENCE';
run;

/*TOTAL Number OF 150 MG CAPSULE TAKEN*/
proc sort data=sasfile.da out=cumcap nodupkey;
  by USUBJID darftdtc dadtc datestcd daorres;
 run;
 
 proc sql;
 create table cum_cap as select USUBJID,
'Total Number of 150mg Capsules Taken' as param length=40 ,'CUMCAP' as paramcd length=8, 
'SUM' as dtype length=40, sum(DASTRESN) as aval1 from cumcap
 where datestcd='TAKENAMT' group by USUBJID;
 quit;
 
/*TOTAL CUMULATIVE DOSE(g*/
data cum_dose(drop=aval1);
length param $40 paramcd $8 dtype $40;
set cum_cap(keep=USUBJID aval1);
param='Total Cumulative Dose (g)';
paramcd='CUMDOSE';
aval=(aval1*150)/1000;
dtype='SUM';
run;

/*DOSE INTENSITY(%)*/
proc sort data=adsl ;by USUBJID;run;
proc sort data= cum_cap;by USUBJID;run;

data dose_int(keep=USUBJID  param paramcd aval dtype);
length param $40 paramcd $8 dtype $40;
merge adsl(in=a) cum_cap(keep=USUBJID aval1);
by usubjid;
param='Dose Intensity (%)';
paramcd='INTENS';
aval=(aval1/days)*100;
dtype='PERCENTAGE';
run;

/*concatenating all 4 dataset*/
proc sort data=durn ;by USUBJID;run;

proc sort data= cum_cap(rename=(aval1=aval)) out=cum_cap1;by USUBJID;run;

proc sort data=cum_dose ;by USUBJID;run;

proc sort data= dose_int;by USUBJID;run;


data joined;
set   cum_cap1 cum_dose dose_int durn;
by USUBJID;run;
run;

/*meging with adsl*/
data merged(drop=days);
merge adsl(in=a) joined;
by USUBJID;
if a;
run;

data output.adex_f;
attrib 
PARAM  label =' analysis parameter description' 
PARAMCD  label =' analysis parameter short name' 
AVAL  label =' analysis value' format = best.
DTYPE  label =' derivation type'
;
set merged;
run;



	
/*converting xpt in sasfile*/	
libname sas_v  "/home/u60094620/projectB/adam_v";
libname xpt xport "/home/u60094620/projectB/adam_v/ADEX.xpt" access=readonly; 
proc copy inlib=xpt outlib=sas_v; run;

/*validation of sas files*/
proc compare base=output.adex_f compare=sas_v.adex;
run;