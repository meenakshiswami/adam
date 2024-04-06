libname sasfile "/home/u60094620/projectB/sas_dataset";
libname prog "/home/u60094620/projectB/programB";
libname output "/home/u60094620/projectB/output";

data adsl;
	set output.adsl_f;
	keep STUDYID USUBJID SUBJID SITEID INVID INVNAM AGE AGEU SEX RACE ETHNIC 
		RANDDT COUNTRY AGEGR1 AGEGR1N TRT01P TRT01PN TRT01A TRT01AN ITTFL SAFFL EFFL 
		CA125FL TRTDCFL COMPLFL STDDCFL SFUDCFL SFUFL REMISS REMISSN TRTSDT TRTSDTC 
		TRTEDT TRTEDTC;

proc sort data=adsl;
	by studyid usubjid;
run;

/*extracting from suppae*/
data suppae;
set sasfile.suppae;
idvarvalN=input(idvarval,2.);

proc sort data=suppae out=suppae1;
	by studyid usubjid  idvarvalN;
run;

proc transpose data=suppae1 out=suppae11;
	by studyid usubjid idvar idvarvalN;
	id qnam;
	var qval;
run;

proc sort data=sasfile.ae out=ae1;
	by studyid usubjid;
run;

data supp_ae(keep=usubjid aeterm aemodify aedecod aebodsys aehlgt aehlt aellt aelltcd 
		aestdtc aestrtpt aeendtc aeenrtpt aesdt aeedt aeser aerel aereloth aetoxgr 
		aetoxgrn aeacn aetrtoth aesdth aedthdtc dthautyn aeslife aeshosp aehdtc 
		aesdisab aescong aesmie srcdom srcseq);
		length aetrtoth $200 AERELOTH $200;
	merge suppae11 ae1;
	by usubjid;
	aetoxgrn=input(aetoxgr, 1.);

	if length(strip(substr(aestdtc, 1, 10)))=10 then
		aesdt=input(substr(aestdtc, 1, 10), is8601da.);
	else
		aesdt=.;

	if length(strip(substr(aeendtc, 1, 10)))=10 then
		aeedt=input(substr(aeendtc, 1, 10), is8601da.);
	else
		aeedt=.;

	if aesdth='Y' then
		do;
			aedthdtc='Y';
			;
			dthautyn='Y';
		end;
	else
		do;
			aedthdtc=' ';
			dthautyn=' ';
		end;

	if aerelnst ne 'MULTIPLE' then AERELOTH=aerelnst;
	else if aerelnst='MULTIPLE' then AERELOTH=strip(AERELNS1)||"; "||strip(AERELNS2);

	if aeacnoth ^='MULTIPLE' And aecontrt='N' then aetrtoth=aeacnoth;
	else if aeacnoth in (' ' 'NONE') and aecontrt='Y' then aetrtoth='MEDICATION';
	else if aeacnoth ^ in('MULTIPLE' ' ' 'NONE') and aecontrt='Y' then aetrtoth=strip(aeacnoth)||'; MEDICATION';
	else aetrtoth='NONE';
	rename domain=srcdom aeseq=srcseq;

	/*finding aesday from ae and adsl*/
data merged;
	merge adsl supp_ae(in=b);
	by usubjid;
     if b;
	if aesdt>=trtsdt then
		aesdy=aesdt-trtsdt+1;
	else
		aesdy=aesdt-trtsdt;

	if trtsdt ne .  and aesdt ne . and aesdt<trtsdt then
		trtem='N';
	else if length(strip(aestdtc))=7 then
		do;
			amonth=compress(substr(aestdtc, 1, 7),'-');
			tmonth=compress(substr(trtsdtc, 1, 7),'-');
		if amonth<tmonth then
		trtem='N';
		else trtem='Y';
	end;
	else if length(strip(aestdtc))=4 then
		do;
			ayear=compress(substr(aestdtc, 1, 4),'-');
			tyear=compress(substr(trtsdtc, 1, 4),'-');

			if ayear<tyear then
				trtem='N';
				else trtem='Y';
		end;
	else
		trtem='Y';

	data output.adae_f;
	attrib
	STUDYID label="study identifier" length=$8.
	USUBJID label="unique subject identifoer" length=$21
	SUBJID label="subject identifier for the study" length=$10.
	SITEID label="study site identifier" length=$20
	INVID label="investigator identifier" length=$5.
	INVNAM label="investigator name" length=$13.
	AGE label="age" length=8.
	AGEU label="Age Units" length=$5.
	SEX label="sex" length=$1.
	RACE label="race" length=$32.
	ETHNIC label="ethnicity" length=$22.
	COUNTRY label="country" length=$3.
	TRT01P  label =' Planned Treatment' length = $10
	TRT01PN  label =' planned Treatment number' length = 8
	TRT01A  label =' Actual Treatment' length = $10
	TRT01AN  label =' Actual Treatment Number' length = 8
	ITTFL  label =' Intent-to-treat population flag' length = $1
	SAFFL  label =' safety population flag' length = $1
	EFFL  label =' efficacy-evaluable population flag ' length = $1
	CA125FL  label =' efficacy-evaluable CA125 population flag ' length = $1
	TRTDCFL  label =' treatment discountinuation flag' length = $1
	COMPLFL  label =' study period completers flag' length = $1
	STDDCFL  label =' study period discontinuation flag' length = $1
	SFUDCFL  label =' follow-up discontinuation flag' length = $1
	SFUFL  label =' survival follow-up period entry flag' length = $1
	REMISS  label =' current remission status(char)' length = $40
	REMISSN  label =' current remission status(num)' length = 8
	RANDDT label = 'randomization flag'  format=is8601da.
	TRTSDTC  label =' first treatment(GDC) date(char)' length = $20
	TRTSDT  label =' first treatment(GDC) date' format=is8601da.
	TRTEDTC  label =' last treatment(GDC) date(char)' length = $20
	TRTEDT  label =' last treatment(GDC) date' format=is8601da.
	
	SRCDOM  label =' source domain' length = $2
	SRCSEQ  label =' source sequence number' length = 8
	AETERM   label =' reported term for adverse event' length = $200
	AEMODIFY  label =' modified reported term' length = $200
	AEDECOD  label =' dictionary derived term' length = $200
	AEBODSYS  label =' body system or organ class' length = $200
	AEHLGT  label =' high level group term' length = $200
	AEHLT  label =' high level term' length = $200
	AELLT  label =' low level term' length = $200
	AELLTCD  label =' low level term code' length = $8
	AESTDTC  label =' satrt date/time of adverse event' length = $20
	AESTRTPT  label =' start relative to reference timepoint' length = $10
	AEENDTC  label =' end date/time of adverse evnt' length = $20
	AEENRTPT  label =' end relative to reference timepoint' length = $10
	AESDT  label =' ae start date' format=is8601da.
	AEEDT   label =' ae end date' format=is8601da.
	AESDY  label =' relative start day of ae' length =8
	AESER  label =' serious event' length = $2
	AEREL  label =' causality' length = $1
	AERELOTH  label =' relationship to non-study treatment' length = $200
	AETOXGR  label =' standard toxicity grade' length = $1
	AETOXGRN  label =' standard toxicity grade(num)' length =8
	AEACN  label =' action taken taken with study treatment' length = $20
	AETRTOTH  label =' treatment of AE' length = $200
	AESDTH  label =' Results in death' length = $2
	AEDTHDTC  label =' death date' length = $20
	DTHAUTYN  label =' was autopsy performed' length = $2
	AESLIFE  label =' is life threatening' length = $2
	AESHOSP  label =' requires or prolongs hospitalization' length = $3
	AEHDTC  label =' hospitalization admission date' length = $20
	AESDISAB  label =' persist or significant disability/incapacity' length = $20
	AESCONG  label =' congenital anomaly or bitrh defect' length = $20
	AESMIE  label =' other medically important serious event' length = $20
	TRTEM  label =' treatment emergent' length = $1;
	set merged;
	keep STUDYID USUBJID SUBJID SITEID INVID INVNAM AGE AGEU SEX RACE ETHNIC 
		RANDDT COUNTRY AGEGR1 AGEGR1N TRT01P TRT01PN TRT01A TRT01AN ITTFL SAFFL EFFL 
		CA125FL TRTDCFL COMPLFL STDDCFL SFUDCFL SFUFL REMISS REMISSN TRTSDT TRTSDTC 
		TRTEDT TRTEDTC AETERM 	AEMODIFY	AEDECOD	AEBODSYS	AEHLGT	AEHLT	AELLT	AELLTCD	
		AESTDTC	AESTRTPT	AEENDTC	AEENRTPT	AESDT	AEEDT 	 AESDY	AESER	AEREL	AERELOTH	AETOXGR	AETOXGRN	
		AEACN	AETRTOTH	AESDTH	AEDTHDTC	DTHAUTYN	AESLIFE	AESHOSP	AEHDTC	AESDISAB	AESCONG	AESMIE	TRTEM	
		SRCDOM	SRCSEQ;

proc sort data =output.adae_f; by USUBJID SRCSEQ AESTDTC    ;

	/*converting xpt in sasfile*/
	libname sas_v "/home/u60094620/projectB/adam_v";
	libname xpt xport "/home/u60094620/projectB/adam_v/ADAE.xpt" access=readonly;

proc copy inlib=xpt outlib=sas_v;
run;

/*validation of sas files*/
proc compare base=output.adae_f compare=sas_v.adae;
run;