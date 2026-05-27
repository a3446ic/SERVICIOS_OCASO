--VERSIONES
	--	v1.1	20250402	Inicial
	--	v1.2	20250404	Añadidas las vistas CSA_PROD_AGENTES_SVW_E, CSA_S4_POLIZAS_SVW, CSA_S4_FACTURA_SVW
	--	v1.3	20250407	Añadidas las vistas CSA_S5_FACTURA_SVW, CSA_DIST_RAPPEL_MENSUAL_SVW_E, EXT.CSA_REPARTO_PAGOS_SVW, EXT.CSA_RESUMEN_REPARTO_PAGOS_SVW, EXT.CSA_S5_POLIZAS_SVW, EXT.CSA_S5_POLIZAS_SVW
	--  v1.4	20250410    Añadida la vista CSA_PERCEPCION_INSPECTORES_SVW
	--  v1.5	20250422    Añadida la vista CSA_PROD_AGENTES_SVW_O
	--  v1.6	20250423    Añadida la vista CSA_PERCEPCION_AGENTES_SVW
	--  v1.7	20250424    Añadida la vista CSA_INSPECTORES_ACTIVOS_SVW
	--  v1.8	20250506    Añadida la visibilidad de oficinas por posiciones con tipo de relación "Empleados"
	--  V1.9	20250507    Añadida la vista CSA_PROD_INSPECTORES_SVW
	--  V1.10	20250507    Añadida la vista CSA_RPA_RESUMEN_SVW
	--	v1.11	20250625	Modificada la estructura para incluír --SELECCIONAR--
	--	v1.12	20250630	Eliminada la vista CSA_RESUMEN_REPARTO_PAGOS_SVW

ALTER STRUCTURED PRIVILEGE REP_SECURITY_EXT
FOR SELECT
ON EXT.CSA_ESTRUCTURA_COMERCIAL_SVW, EXT.CSA_PROD_AGENTES_SVW_E, EXT.CSA_S4_POLIZAS_SVW, EXT.CSA_S4_FACTURA_SVW, EXT.CSA_S5_FACTURA_SVW,
	EXT.CSA_DIST_RAPPEL_MENSUAL_SVW_E, EXT.CSA_REPARTO_PAGOS_SVW, EXT.CSA_S5_POLIZAS_SVW,
	EXT.CSA_PERCEPCION_INSPECTORES_SVW, EXT.CSA_PROD_AGENTES_SVW_O, EXT.CSA_PERCEPCION_AGENTES_SVW, EXT.CSA_INSPECTORES_ACTIVOS_SVW,
	EXT.CSA_PROD_INSPECTORES_SVW, EXT.CSA_RPA_RESUMEN_SVW
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
		-- visibilidad de oficinas por posiciones con tipo de relación "Empleados" 
			or userid in  (	select parpar.userid as userid_Padre from tcmp.cs_positionrelation posrel
									inner join tcmp.cs_positionrelationtype reltyp on reltyp.datatypeseq = posrel.positionrelationtypeseq
										and reltyp.removedate = to_date('22000101','yyyymmdd')
										and reltyp.Name ='Empleados'
									inner join tcmp.cs_position pospar on pospar.ruleelementownerseq = posrel.parentpositionseq
										and pospar.removedate = to_date('22000101','yyyymmdd')
									inner join tcmp.CS_PARTICIPANT parpar on pospar.PAYEESEQ = parpar.PAYEESEQ 
										and parpar.removeDate=TO_DATE('22000101','YYYYMMDD') 
										and parpar.islast=1
									inner join tcmp.cs_position poschi on poschi.ruleelementownerseq = posrel.childpositionseq
										and poschi.removedate = to_date('22000101','yyyymmdd')
										and poschi.islast =1
									inner join tcmp.CS_PARTICIPANT parchi on poschi.PAYEESEQ = parchi.PAYEESEQ 
										and parchi.removeDate=TO_DATE('22000101','YYYYMMDD') 
										and parchi.islast=1
								where 1=1
									and posrel.removedate = to_date('22000101','yyyymmdd')
									and posrel.islast = 1
									and parchi.userid = 'OFPY' -- SESSION_CONTEXT('APPLICATIONUSER')
			)
			or exists ( 
				select 1 
				from CSA_DataSecurity 
				where ( userid = SESSION_CONTEXT('APPLICATIONUSER') 
						and securityType='ALL' 
						and removeDate=TO_DATE('22000101','YYYYMMDD') ) 
					or  (SESSION_CONTEXT('APPLICATIONUSER') like 'WEBIDE_PS%')
				)
	)
	-- Caso --SELECCIONAR--, donde POSITIONSEQ está fijado a -1
	UNION
	SELECT -1, PERIODSEQ
	FROM csa_pareportingdimension 
);


