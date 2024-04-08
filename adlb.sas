libname sasfile "/home/u60094620/projectB/sas_dataset";
libname prog "/home/u60094620/projectB/programB";
libname output "/home/u60094620/projectB/output";
/*extracting from adsl*/
proc sql;
create table  adsl as select  STUDYID, USUBJID ,SUBJID ,SITEID, INVID ,INVNAM, AGE, AGEU ,SEX ,RACE ,ETHNIC, 
		RANDDT ,COUNTRY, ARM, ARMCD, AGEGR1, AGEGR1N ,TRT01P ,TRT01PN, TRT01A ,TRT01AN ,ITTFL ,SAFFL, EFFL ,
		CA125FL , TRTSDT, TRTSDTC, TRTEDT ,TRTEDTC ,TRT01P as trtp from output.adsl_f group by USUBJID;
	quit;

/*extracting and merging supplb and lb*/
data lb;
set sasfile.lb;
where visit ne 'DAY 1'  ;

proc sort data=lb ;by usubjid lbseq;	

proc sql;
	create table supplb as select usubjid ,qval as LBTOXGR1,input(idvarval,best12.) as lbseq from sasfile.supplb
	where qnam='LBTOXGR1' ;	
	
proc sort data=supplb ;by usubjid lbseq;
	
data lb1;
 merge supplb lb;
 by usubjid lbseq;
proc sort data=lb1 ;by usubjid lbcat lbtestcd lbdtc;
	 
/*merging adsl and lb then FINDING ADT, ADY,ONTRTFL,ANL01FL,ANRHI ,PARAM, PARAMCD ,ANRIND ,ATOXGR , ATOXDIR from LB*/

data lb_adsl;
length ANRHI $30 ANRLO $30 ANRIND $10 ATOXGR $1 ATOXDIR $1;
merge adsl (in=a ) lb1 ;
by usubjid;	
if a;
if lbstresc ^='ND - NOT DONE' and compress(upcase(lbstat)) = ' '  then	AVAL=lbstresn;
else delete;
AVALC=strip(lbstresc);	


if lbstnrhi ^= . then	ANRHI=strip(put(lbstnrhi,best.));else ANRHI=' ';		
if	lbstnrlo ^= . then	ANRLO=strip(put(lbstnrlo,best.));	else ANRLO=' ';						

	/*adt and ady*/	
ADTC=strip(compress(substr(lbdtc,1,10)));
ADT=input(ADTC,is8601da.);
	format ADT yymmdd10.;
if adt>=trtsdt then ADY= adt-trtsdt+1;
 else ADY= adt-trtsdt;
   /*flag*/
if adtc ne ' ' and trtsdt<=adt=<trtedt	then	ONTRTFL='Y'; 
if aval ne . or avalc ne " " then ANL01FL='Y';

  /*ATOXGR and ATOXDIR*/
 ANRIND=lbnrind;
if lbtest ne 'Blood Urea Nitrogen' then ATOXGR=compress(strip(lbtoxgr),'HL');
else ATOXGR=compress(strip(lbtoxgr1),'HL');

if lbtest ne 'Blood Urea Nitrogen' then ATOXDIR=compress(strip(lbtoxgr),'1234567890');
else ATOXDIR=compress(strip(lbtoxgr1),'1234567890');


    /*finding param, paramcd*/
if lbstresu ne " " then PARAM=strip(lbcat)||"|"|| strip(lbtest)||" ("||strip(lbstresu)||")";
else  PARAM=strip(lbcat)||"|"|| strip(lbtest);

PARCAT2='SI';

if strip(upcase(lbcat))='CHEMISTRY' then  PARAMCD_ ='C'||strip(SUBSTR(lbtestcd,1,6));
else if strip(upcase(lbcat))='URINALYSIS' then  PARAMCD_ ='U'||strip(SUBSTR(lbtestcd,1,6));
else if strip(upcase(lbcat))='HEMATOLOGY' then  PARAMCD_ ='H'||strip(SUBSTR(lbtestcd,1,6));

if strip(lbstresu) = ' ' then paramcd=strip(PARAMCD_)||'N';
Else paramcd=strip(PARAMCD_)||'S';



/*finding ABLFL, and other variable*/
proc sort data=lb_adsl out=lb2(where=(adt ne . and (adt <= trtsdt) and  (aval ^= . or avalc ^= ' ') ));
by usubjid param descending adt descending lbseq ;
     /*where adt<trtsdt*/
    	data lb_bf(where=(ABLFL='Y'));
set lb2(where=(adt < trtsdt));
by usubjid param descending adt descending lbseq;
retain flag;
if first.param  then flag=0;
if flag=0  then do;
      	 ABLFL='Y';
      	 flag=1;
   		end;
   		
   /*where adt=trtsdt*/
data lb_eq ;
merge lb2 lb_bf(in=b );
by usubjid param ;
if not b;

data lb_eq2(where=(ABLFL='Y'));
set lb_eq;
by usubjid param descending adt descending lbseq;
	retain flag;
if first.param  and adt= trtsdt then flag=0;
if flag=0   then do;
  ABLFL='Y';
    flag=1;
   		end;

    /*concatenating both data and finding abfl*/
proc sort data =lb_bf; by usubjid param adt lbseq;
proc sort data =lb_eq2; by usubjid param adt lbseq;

data con_eqbf(keep= usubjid param blseq BASE BASEC BTOXGR BTOXDIR bNRIND);
length bNRIND $10 BTOXGR $1 BTOXDIR $1;
set lb_bf lb_eq2;
by usubjid param adt lbseq  ;
blseq=lbseq;
BASE=aval;
BASEC=avalc;			
BTOXGR=ATOXGR;
BTOXDIR=ATOXDIR;
bNRIND=ANRIND;

/*merging with final dataset and finding remaining variable*/
proc sort data =lb_adsl; by usubjid param;run;
proc sort data =con_eqbf; by usubjid param;run;

data merged1;
merge lb_adsl(in=a) con_eqbf;
by usubjid param ;
if a;

if lbseq=blseq then ABLFL='Y'; else =' '; 

proc sort data =merged1; by usubjid param adt visit;run;

data merged;
length   srcdom $2 srcseq 8 srcvar $10 visit $30 parcat1 $30 ;
set merged1;
by usubjid  param adt visit;

CHG=aval-base;	
if base ne 0 then PCHG=(chg/base)*100;	
srcdom=domain;
srcseq=lbseq;
srcvar='LBSTRESN';
visit=strip(visit);
parcat1=strip(lbcat);

 proc sort data =merged; by usubjid paramcd adt srcseq  ;run;
 

data output.adlbsi_f;
set merged(keep= STUDYID USUBJID SUBJID SITEID INVID INVNAM AGE AGEU AGEGR1 AGEGR1N  SEX RACE ETHNIC  ARM ARMCD
		RANDDT COUNTRY TRT01P TRT01PN TRT01A TRT01AN ITTFL SAFFL EFFL CA125FL TRTSDT TRTSDTC   TRTEDT TRTEDTC
		SRCDOM SRCSEQ TRTP ADTC ADT ADY VISIT ONTRTFL ANL01FL ANRIND ATOXGR ATOXDIR CHG PCHG SRCVAR PARAM PARAMCD 
		PARCAT1 PARCAT2 BASE BASEC BNRIND  BTOXGR BTOXDIR ABLFL AVAL AVALC ANRLO ANRHI);

attrib		
	SRCDOM label='source domain'
SRCSEQ label='source sequence number'
TRTP label='planned treatment(record level)'
ADTC label='character analysis date'
ADT label='analysis date'
ADY label='analysis relative day'
VISIT label='visit'
ONTRTFL label='on treatment record flag'
ANL01FL label='analysis record flag'
ANRIND label='analysis reference range  indicator'
ATOXGR label= 'analysis toxicity grade'
ATOXDIR label='analysis toxicity grade indicator'
CHG label='change from baseline'
PCHG label='percentage change from baseline'
SRCVAR label='source variable'
PARAM  label='analysis parameter description'
PARAMCD label='analysis parameter short name'
PARCAT1 label='parameter category 1'
PARCAT2 label='parameter category2'
BASE label='baseline value'
BASEC label='character baseline value'
BNRIND label='baseline reference range indicator'
BTOXGR label='baseline toxicity grade'
BTOXDIR label='baseline toxicity grade direction'
ABLFL label='baseline record flag'
AVAL label='analysis value'
AVALC label='character analysis value'
ANRLO label='analysis normal range low limit'
ANRHI label='analysis normal range upper limit';


	/*converting xpt in sasfile*/
	libname sas_v "/home/u60094620/projectB/adam_v";
	libname xpt xport "/home/u60094620/projectB/adam_v/ADLBSI.xpt" access=readonly;

proc copy inlib=xpt outlib=sas_v;
run;

/*validation of sas files*/
proc compare base=output.adlbsi_f compare=sas_v.ADLBSI;
run;