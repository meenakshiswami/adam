  libname sasfile "/home/u60094620/projectB/sas_dataset";
libname prog "/home/u60094620/projectB/programB";
libname output "/home/u60094620/projectB/output";

%let cutoff='15may2010'd;
%put &cutoff;	 

proc sql;
create table  adsl as select  STUDYID, USUBJID ,SUBJID ,SITEID, INVID ,INVNAM, AGE, AGEU ,SEX ,RACE ,ETHNIC, 
		RANDDT ,COUNTRY,  AGEGR1, AGEGR1N ,TRT01P ,TRT01PN, TRT01A ,TRT01AN ,SAFFL,ITTFL , EFFL ,
		CA125FL , TRTSDT, TRTEDT  ,TRT01P as trtp ,BECOG, REMISS,	REMISSN, RSP125,	HPATHTYP,
	    HSUBTYP, STDSDT ,STDEDT,DTHPER,DTHDT from output.adsl_f group by USUBJID;


/*finding from LB*/
proc sql;
create table  lb as 
select a.usubjid,a.trtsdt,a.ca125fl,b.lbtestcd,input(lborres,8.)as lborresn,lborres,input(lbornrhi,8.) as lbornrhin,
lbornrhi,input(lbdtc,is8601da.) as lbdt  format=is8601da. from sasfile.lb as b , adsl as a
 where input(lbdtc,yymmdd10.) <=&cutoff and ca125fl='Y' and lbtestcd='CA125' and lborres ^=' ' and trtsdt ne . and lbdtc ne ' ' 
and a.usubjid=b.usubjid ;
 
create table lb2 as select usubjid, max(lbdt) as lca125dt  format=is8601da. from lb where lbdt>=trtsdt group by usubjid ;
quit;
/*finding from TU -for new tumor identification*/
data tuu;set sasfile.tu;

proc sql;	
create table tu as select usubjid, max(input(tudtc,is8601da.))  as tumldt format=is8601da.  from sasfile.tu 
where input(tudtc,yymmdd10.) <= &cutoff and tuorres ^=' '
 group by usubjid ;
create table tu1 as select usubjid, min(input(tudtc,is8601da.))  as fpddt format=is8601da. from sasfile.tu 
where input(tudtc,yymmdd10.) <=&cutoff and substr(tuorres,1,2) in ('Y','NL')
 group by usubjid ;
quit;

/*finding FCA125DT from lb*/
proc sort data=lb out=lb11;
 where lbdt>=trtsdt and lborresn>= (lbornrhin*2) ;
 by usubjid lbdt;
 
data lb3(keep= usubjid fca125dt) ;
set lb11;
by usubjid lbdt;
retain firstdt;

if first.usubjid then firstdt=lbdt ;
else if last.usubjid then lastdt=lbdt ;

 if lastdt - firstdt>=7 then fca125dt=firstdt;
 format fca125dt is8601da.;
 
 if last.usubjid;

proc sort data=lb3 ;by usubjid ;

/*finding FPD125DT from merging records*/
data adsl_lb_tu;
merge adsl(in=a) lb2(keep= usubjid lca125dt) lb3(keep= usubjid fca125dt) 
tu(keep= usubjid tumldt) tu1(keep= usubjid fpddt);
by usubjid ;
if a;

if ca125fl = 'Y' then do;
 if nmiss(fca125dt,fpddt)=0  then fpd125dt=min(fca125dt,fpddt);
else if fpddt ^=. then fpd125dt=fpddt ;
else if fca125dt ^=.	then fpd125dt= fca125dt	;
else fpd125dt= .;
end;
format fpd125dt is8601da.;


/* 1.TTPFS*/
data pfs;
set adsl_lb_tu(where =(ittfl='Y'));
attrib
 PARAM length =$80
PARAMCD length =$8
STARTDT length =8 format =is8601da.
ADT length =8 format =is8601da.
CNSR length =8
EVNTDESC length =$80
AVAL length =8
_dthdt length =8 format =is8601da.;

param='TIME TO PROGRESSION FREE SURVIVAL (month)';
paramcd='TTPFS';
startdt=randdt;

IF dthdt>0 and dthdt=<&cutoff then _dthdt=dthdt;

 if nmiss(fpddt,_dthdt)=0 then do;cnsr=0;
        if fpddt<=_dthdt then do;evntdesc='DISEASE PROGRESSION';adt=fpddt;end;
        else do;evntdesc='DEATH'; adt=_dthdt;end;
 end;   
 else if nmiss(fpddt,_dthdt)=1 then do;cnsr=0; 
        if fpddt>0 then do;evntdesc='DISEASE PROGRESSION';adt=fpddt;end;
        else if _dthdt>0 then do;evntdesc='DEATH'; adt=_dthdt;end;
 end;       
 else if tumldt>0 then do;
         adt=tumldt;
          cnsr=1;
          evntdesc='CENSORED AS OF LAST TUMOR SCAN DATE';
 end;
 else do; cnsr=2; adt=randdt;evntdesc='CENSORED AS OF RANDOMIZATION DATE';end;


aval=(adt-startdt+1)/30.4375;


/* 2.TTPFS125*/
data pfs125;
set adsl_lb_tu(where =(ittfl='Y' AND ca125fl='Y'));
attrib
PARAM length =$80
PARAMCD length =$8
STARTDT length =8 format =is8601da.
ADT length =8 format =is8601da.
CNSR length =8
EVNTDESC length =$80
AVAL length =8
_dthdt length =8 format =is8601da.;
;
param='TIME TO PROGRESSION FREE SURVIVAL CA-125 RESPONDER (month)';
paramcd='TTPFS125';
startdt=randdt;

if dthdt >0 and dthdt=<&cutoff then _dthdt=dthdt; 
  /*adt*/
  if nmiss(_dthdt,fpddt,fca125dt)=0 then do; 
           cnsr=0;
          adt=min(fpddt,_dthdt,fca125dt);
          if adt=fpddt then evntdesc='DISEASE PROGRESSION';
           else if  adt=_dthdt then evntdesc='DEATH';
                else  evntdesc='CA-125 CRITERIA AS DISEASE PROGRESSION';
  end;
  else if nmiss(_dthdt,fpddt,fca125dt)=1 then do;
                  cnsr=0;
                   if nmiss(_dthdt,fpddt)=0 then do;
                                   if _dthdt<fpddt then do;adt=_dthdt;evntdesc='DEATH';end;
                                   else  do; adt=fpddt;evntdesc='DISEASE PROGRESSION';end;
                   end;
                else if nmiss(fca125dt,fpddt)=0 then do;
                   if fca125dt>=fpddt then do;adt=fpddt;evntdesc='DISEASE PROGRESSION';end;
                   else  do;adt=fca125dt;evntdesc='CA-125 CRITERIA AS DISEASE PROGRESSION';end;
                 end;
                   
               else if nmiss(_dthdt,fca125dt)=0 then do;
                   if _dthdt<fca125dt then do;adt=_dthdt;evntdesc='DEATH';end;
                   else do;adt=fca125dt;evntdesc='CA-125 CRITERIA AS DISEASE PROGRESSION';end;
               end;
  end;                                       
                                                 
  else if nmiss(_dthdt,fpddt,fca125dt)=2 then do;
               cnsr=0; 
               if fpddt>0 then do;adt=fpddt;evntdesc='DISEASE PROGRESSION';end;
               else if _dthdt>0 then do; adt=_dthdt;evntdesc='DEATH';end;
               else if fca125dt>0 then do;adt=fca125dt;evntdesc='CA-125 CRITERIA AS DISEASE PROGRESSION';end;
  end;
  
  else if nmiss(_dthdt,fpddt,fca125dt)=3 and nmiss(tumldt,lca125dt)=0 then do;
            if tumldt>=lca125dt then do;cnsr=1; adt=tumldt;evntdesc='CENSORED AS OF LAST TUMOR SCAN DATE';end;
             else do;cnsr=2; adt=lca125dt;evntdesc='CENSORED AS OF LAST CA-125 LAB ASSESSMENT DATE';end;
  end;
  else if nmiss(tumldt,lca125dt)=1 then do;
            if tumldt>0 then do;cnsr=1; adt=tumldt;evntdesc='CENSORED AS OF LAST TUMOR SCAN DATE';end;
             else do;cnsr=2; adt=lca125dt;evntdesc='CENSORED AS OF LAST CA-125 LAB ASSESSMENT DATE';end;
  end;          
            
  else do; adt=randdt;cnsr=3;evntdesc='CENSORED AS OF RANDOMIZATION DATE';  
  end;
 
  aval=(adt-startdt+1)/30.4375;
/* 3.TTOS*/

proc sql;
create table ds as select distinct(usubjid),input(max(dsstdtc),is8601da.) as maxdt format=is8601da. from sasfile.ds 
where dscat='DISPOSITION EVENT' and dsscat IN('STUDY PERIOD','FOLLOW-UP') group by usubjid order by usubjid ,dsstdtc desc ;
quit;


data OS;
merge ds(keep= usubjid maxdt dsdecod ) adsl(in=a where =(ittfl='Y'));
by usubjid;
if a;
attrib 
PARAM length =$80
PARAMCD length =$8
STARTDT length =8 format =is8601da.
ADT length =8 format =is8601da.
CNSR length =8
EVNTDESC length =$80
AVAL length =8
maxdt length =8 format =is8601da.
;
if a;
param='TIME TO OVERALL SURVIVAL (month)';
paramcd='TTOS';
startdt=randdt;
 
 if dthdt >0 then Do;adt=dthdt;cnsr=0;evntdesc='EVENT: DEATH DUE TO ANY CAUSE'; end;
 else if dthdt=. and dsdecod ^='DEATH' then  adt=maxdt;
  else adt=randdt;
  
 if dsdecod ^= 'DEATH' then do;
   if dsdecod='STUDY TERMINATED BY SPONSOR' Then do;cnsr=1;evntdesc='CENSORED AS OF DATE SPONSOR DECIDED TO TERMINATE THE STUDY';END;
   ELSE IF dsdecod='LOST TO FOLLOW-UP' Then do;cnsr=2;evntdesc='CENSORED AS OF DATE DUE TO LOST TO FOLLOW-UP';END;
ELSE IF dsdecod='WITHDRAWAL BY SUBJECT' Then do;cnsr=3;evntdesc='CENSORED AS OF DATE SUBJECT DECIDED TO WITHDRAW'; END;
ELSE IF dsdecod='OTHER' Then do;cnsr=4;evntdesc='CENSORED AS OF DATE OF WITHDRAWAL DUE TO OTHER REASONS';END;
ELSE IF dsdecod='PROGRESSIVE DISEASE' Then do;cnsr=5;evntdesc='CENSORED AS OF DATE OF DISEASE PROGRESSION';END;
else evntdesc= ' ' and cnsr= .;
end;
aval=(adt-startdt+1)/30.4375;


data merged(drop= maxdt); 
attrib
PARAM LABEL= 'analysis parameter description ' 
PARAMCD LABEL='analysis parameter short name ' 
STARTDT LABEL='time to event origin date for subject ' 
ADT LABEL='analysis date ' 
CNSR LABEL='censoring indicator ' 
EVNTDESC LABEL='event description ' 
AVAL LABEL='analysis value ' 
TRTP LABEL='planned treatment(record level) ' 
TUMLPD LABEL='last tumor assessment date ' 
FPDDT LABEL='first pd date ' 
FPD125DT LABEL='first pd  date  for CA-125 responder ' 
FCA125DT LABEL='first CA-125 elevation date ' 
LCA125DT LABEL='last CA-125 assessment date ' ;
set  pfs pfs125 os ;

keep STUDYID USUBJID SUBJID SITEID INVID INVNAM AGE AGEU SEX RACE ETHNIC 
		RANDDT COUNTRY  AGEGR1 AGEGR1N TRT01P TRT01PN TRT01A TRT01AN ITTFL SAFFL EFFL 
		CA125FL TRTSDT TRTEDT  STDSDT STDEDT trtp  BECOG  REMISS	REMISSN  RSP125	HPATHTYP
	    HSUBTYP DTHPER DTHDT TUMLDT FPDDT FPD125DT FCA125DT LCA125DT PARAM PARAMCD STARTDT AVAL EVNTDESC CNSR ADT;

 
 proc sort data =merged out=output.adtte_f;by usubjid paramcd param;run;
/*converting xpt in sasfile*/
	libname sas_v "/home/u60094620/projectB/adam_v";
	libname xpt xport "/home/u60094620/projectB/adam_v/ADTTE.xpt" access=readonly;

proc copy inlib=xpt outlib=sas_v;
run;

/*validation of sas files*/
proc compare base=output.adtte_f compare=sas_v.ADTTE;
run;