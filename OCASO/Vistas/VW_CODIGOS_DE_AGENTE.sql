CREATE VIEW "EXT"."VW_CODIGOS_DE_AGENTE"(
	"CODIGO_UNICO",
	"CODIGO_OCASO",
	"EFFECTIVESTARTDATE",
	"EFFECTIVEENDDATE",
	"ANTICIPADA_RRPP_OCASO",
	"TIPO_OFICINA",
	"TIPO_DATO",
	"CARTERA_RRTT",
	"TIPO_AGENTE",
	"PORC_COMISION_CARTERA",
	"IMP_COMISION_CARTERA",
	"FECHA_FIN_COMISION_CARTERA",
	"FECHA_INI_PART",
	"FECHA_FIN_PART",
	"TIPO_AGENTE_PRIN",
	"MANAGERSEQ",
	"INSP_CAPTADOR") AS
( 		(SELECT 
			T.CODIGO_UNICO,
			T.CODIGO_OCASO,
			T.effectivestartdate,
			T.effectiveenddate,
			MAX(T.ANTICIPADA_RRPP_OCASO) AS ANTICIPADA_RRPP_OCASO,
			T.TIPO_OFICINA,
			T.TIPO_DATO,
			MAX(T.CARTERA_RRTT) AS CARTERA_RRTT,
			T.TIPO_AGENTE,
			T.PORC_COMISION_CARTERA,
			T.IMP_COMISION_CARTERA,
			T.FECHA_FIN_COMISION_CARTERA,
			T.FECHA_INI_PART,
			T.FECHA_FIN_PART,
			T.TIPO_AGENTE_PRIN,
			T.MANAGERSEQ,
			T.INSP_CAPTADOR
		FROM 
			(
				(SELECT 
					pos.name AS CODIGO_UNICO,
					pos.genericattribute3 AS CODIGO_OCASO,
					pos.effectivestartdate,
					pos.effectiveenddate,
					par.genericboolean5 AS ANTICIPADA_RRPP_OCASO,
					pos.genericnumber4 AS TIPO_OFICINA,
					pos.islast AS TIPO_DATO,
					ifnull( par.genericboolean6, 0 ) AS CARTERA_RRTT,
					pos.genericnumber2 AS TIPO_AGENTE,
					pos.genericnumber5 AS PORC_COMISION_CARTERA,
					pos.genericnumber6 AS IMP_COMISION_CARTERA,
					pos.genericdate6 AS FECHA_FIN_COMISION_CARTERA,
					par.effectivestartdate AS FECHA_INI_PART,
					par.effectiveenddate AS FECHA_FIN_PART,
					pos.genericnumber1 AS TIPO_AGENTE_PRIN,
					pos.managerseq AS MANAGERSEQ,
					pos.genericattribute14 AS INSP_CAPTADOR
				FROM 
					tcmp.cs_position AS pos,
					tcmp.cs_participant AS par
				WHERE pos.payeeseq = par.payeeseq
					AND pos.removedate = TO_DATE( '22000101', 'yyyymmdd' )
					AND par.removedate = TO_DATE( '22000101', 'yyyymmdd' )
					AND --ALM 20200320: David nos indica que debemos filtrar por title distinto de TTL SIN PLAN
					pos.titleseq <> 5629499534213290
					AND (par.terminationdate > current_timestamp
						OR par.terminationdate IS NULL))
			) AS T
		GROUP BY 
			T.CODIGO_UNICO,
			T.CODIGO_OCASO,
			T.effectivestartdate,
			T.effectiveenddate,
			
--ANTICIPADA_RRPP_OCASO,      
		T.TIPO_OFICINA,
			T.TIPO_DATO,
			--CARTERA_RRTT,
		T.TIPO_AGENTE,
			T.PORC_COMISION_CARTERA,
			T.IMP_COMISION_CARTERA,
			T.FECHA_FIN_COMISION_CARTERA,
			T.FECHA_INI_PART,
			T.FECHA_FIN_PART,
			T.TIPO_AGENTE_PRIN,
			T.MANAGERSEQ,
			T.INSP_CAPTADOR) )
WITH READ ONLY;
