--VERSIONES
	--	v1	20250402	Inicial
	
CREATE STRUCTURED PRIVILEGE REP_SECURITY_EXT
FOR SELECT
ON EXT.CSA_ESTRUCTURA_COMERCIAL_SVW
WHERE (positionseq, periodseq) in ( 
	select DESCENDANTPOSITIONSEQ, periodseq
	from csa_pareportingdimension 
	where (ancestorpa_sk, periodseq) in (
		select pa_sk, periodseq 
		from csa_padimension pad
		where  userid = SESSION_CONTEXT('APPLICATIONUSER')
			or userid in  (	select par.userid from CSA_DataSecurity ds
									inner join CS_POSITION pos on ds.VALUE = pos.RULEELEMENTOWNERSEQ and pos.removeDate=TO_DATE('22000101','YYYYMMDD') and pos.islast=1
									Inner join CS_PARTICIPANT par on pos.PAYEESEQ = par.PAYEESEQ and par.removeDate=TO_DATE('22000101','YYYYMMDD') and par.islast=1
								where  ds.userid = SESSION_CONTEXT('APPLICATIONUSER')
									and  ds.removeDate=TO_DATE('22000101','YYYYMMDD') 
									and ds.securityType='POS')
			or exists ( 
				select 1 
				from CSA_DataSecurity 
				where ( userid = SESSION_CONTEXT('APPLICATIONUSER') 
					and securityType='ALL' 
					and removeDate=TO_DATE('22000101','YYYYMMDD') ) or  (SESSION_CONTEXT('APPLICATIONUSER') like 'WEBIDE_PS%')
				)
	)	
);
