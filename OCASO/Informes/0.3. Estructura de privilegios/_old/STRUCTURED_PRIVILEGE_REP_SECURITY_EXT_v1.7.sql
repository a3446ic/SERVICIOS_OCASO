--VERSIONES
	--	v1	20250402	Inicial
	--	v2	20250404	Añadidas las vistas CSA_PROD_AGENTES_SVW_E, CSA_S4_POLIZAS_SVW, CSA_S4_FACTURA_SVW
	--	v3	20250407	Añadidas las vistas CSA_S5_FACTURA_SVW, CSA_DIST_RAPPEL_MENSUAL_SVW_E, EXT.CSA_REPARTO_PAGOS_SVW, EXT.CSA_RESUMEN_REPARTO_PAGOS_SVW, EXT.CSA_S5_POLIZAS_SVW, EXT.CSA_S5_POLIZAS_SVW
	--  v4  20250410    Añadida la vista CSA_PERCEPCION_INSPECTORES_SVW
	--  v5  20250422    Añadida la vista CSA_PROD_AGENTES_SVW_O
	--  v6  20250423    Añadida la vista CSA_PERCEPCION_AGENTES_SVW
	--  v7  20250424    Añadida la vista CSA_INSPECTORES_ACTIVOS_SVW

ALTER STRUCTURED PRIVILEGE REP_SECURITY_EXT
FOR SELECT
ON EXT.CSA_ESTRUCTURA_COMERCIAL_SVW, EXT.CSA_PROD_AGENTES_SVW_E, EXT.CSA_S4_POLIZAS_SVW, EXT.CSA_S4_FACTURA_SVW, EXT.CSA_S5_FACTURA_SVW,
	EXT.CSA_DIST_RAPPEL_MENSUAL_SVW_E, EXT.CSA_REPARTO_PAGOS_SVW, EXT.CSA_RESUMEN_REPARTO_PAGOS_SVW, EXT.CSA_S5_POLIZAS_SVW,
	EXT.CSA_PERCEPCION_INSPECTORES_SVW, EXT.CSA_PROD_AGENTES_SVW_O, EXT.CSA_PERCEPCION_AGENTES_SVW, EXT.CSA_INSPECTORES_ACTIVOS_SVW
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
						and removeDate=TO_DATE('22000101','YYYYMMDD') ) 
					or  (SESSION_CONTEXT('APPLICATIONUSER') like 'WEBIDE_PS%')
				)
	)	
);
