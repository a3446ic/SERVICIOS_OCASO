CREATE OR REPLACE PROCEDURE EXT.SP_CREAR_TABLAS (IN i_PeriodSeq BIGINT, IN i_lista_informes VARCHAR(5000), IN i_id_proceso BIGINT, IN i_tipo INTEGER DEFAULT NULL, INOUT i_log_count INTEGER)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Authors: Rubén Martínez, Brais Romero, Diego Teijo
    | Company: Inycom
    | Initial Version Date: 16-Mayo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento para la recarga de tablas de informes. 
    | El procedimiento funciona desde un interfaz de salida de xDL, pasando la fecha en formato YYYYMMDD y el listado de informes a ejecutar
    |
	|
	| Version: 	0.1		RMF 20250516		Initial Version.
	|          	0.2  	MLR 20250521		Completado el esqueleto
	| 		   	0.3  	BRG/DTB 20250522	Tablas temporales adaptadas a variables tabla
	|		   	0.4  	BRG/DTB 20250523	Creada primera version de la tabla OUT_PERC_AGENTES_REP	
	|		   	0.5  	BRG/DTB 20250523	Creadas tablas finales OUT_PERC_AGENTES_FINAL_REP y OUT_PERC_INSPECTORES_FINAL_REP para informes 1.11 y 1.13
	|			0.6  	BRG/DTB 20250526	Creadas tablas finales OUT_PROD_AGENTES_FINAL_REP y OUT_PROD_INSPECTORES_FINAL_REP para informes 1.12 y 1.14
	|		   	0.7  	BRG/DTB 20250526	Creadas tablas finales OUT_INSP_ACTIVOS_FINAL_REP y OUT_RPA_RESUMEN_FINAL_REP para informes 1.16 y 1.26
	|		   	0.8  	BRG/DTB 20250527	Creadas tablas finales OUT_S4_POLIZAS_FINAL_REP y OUT_S5_POLIZAS_FINAL_REP para informes S4 y S5 Pólizas
	|			0.9  	BRG/DTB 20250528	Creadas tablas finales OUT_S4_FACTURA_FINAL_REP y OUT_S5_FACTURA_FINAL_REP para informes S4 y S5 Factura
	|			1.0 	BRG/DTB 20250528	Informes migrados hasta el momento incluidos (1.11, 1.12, 1.13, 1.14, 1.16, 1.26, S4 FAC/POL y S5 FAC/POL)
	|			1.1 	BRG/DTB	20250529	Problemas menores solucionados, primera ejecución correcta
	|			1.2		BRG/DTB	20250529	Cambiado RTRIM(FIRSTNAME) || ' ' || RTRIM(LASTNAME) || ' ' || RTRIM(SUFFIX) a IFNULL(RTRIM(FIRSTNAME) || ' ', '') || IFNULL(RTRIM(LASTNAME) || ' ', '') || IFNULL(RTRIM(SUFFIX), '') 
	|			1.3		BRG/DTB	20250529	Añadida creación del informe ESTRUCTURA_COMERCIAL
	|			1.4		BRG		20250618	Añadido IFNULL a los campos de ESTRUCTURA COMERCIAL
	|			1.5		DTB		20250619	Cambiado ',' por ';' en el IF de 'i_lista_informes like...'
	|			1.6		LLS		20250620	Añadido en OUT_PROD_AGENTES_FINAL_REP la carga de los campos FEC_ACTUALIZACION y FEC_ACTUALIZACION_FORMATO
	|			1.7 	BRG 	20250627	Añadido INSERT del valor '--SELECCIONAR--' en la tabla OUT_S4_POLIZAS_FINAL_REP y OUT_S5_POLIZAS_FINAL_REP
	|			1.8		BRG		20250630	Corregido error en insert, añadido WHERE PERIODSEQ = :i_PeriodSeq a ESTRUCTURA_COMERCIAl
	|			1.9		BRG		20250702	Corregido error relacionado con EXTRACT(MONTH) para PERC_AGENTES y PERC_INSPECTORES
	|			2.0		LLS		20251002	Redondear a 2 decimales VALOR_IRPF para OUT_S4_FACTURA_FINAL_REP y OUT_S5_FACTURA_FINAL_REP
    |           2.1     DTB     20251021    Añadida la creación de las tablas OUT_PEPA_RESUMEN_REP (+LC+BALANCES). Informe S4 Percepciones Resumen
    |           2.2     DTB     20251022    Añadido insert a OUT_PEPA_RESUMEN_FINAL_REP
    |           2.3     LLS     20251022    Añadido el campo SALESTRANSACTIONSEQ en el insert de OUT_S4_POLIZAS_FINAL_REP
    |           2.4     DTB     20251030    Añadido informe S4/S5 Percepciones Resumen (TABLAS PEPA COMPLETAS, TABLAS PEPI SOLO CIERRE)
	|			2.5		BRG		20251031	Añadido informe Rappel Producción Ag. con Grupo -S4- (TABLAS RPP)
    |           2.6     LLS     20251031    Añadido informe S4 Rappel Producción Agentes (TABLAS RPA)
	|           2.7     BRG     20251031    Añadido informe Rappel Producción Inspectores (TABLAS RPI)
	|           2.8     DTB     20251104    Añadido insert de Agentes con Grupo a informe PRAG
    |           2.9     BRG     20251104    Cambiadas las ',' por '|' en los IF con i_lista_informes para poder llamar a más de un informe con el CREARTABLASMANUAL
    |           3.0     DTB     20251104    Cambiado RTRIM(FIRSTNAME) || ' ' || RTRIM(LASTNAME) || ' ' || RTRIM(SUFFIX) a IFNULL(RTRIM(FIRSTNAME) || ' ', '') || IFNULL(RTRIM(LASTNAME) || ' ', '') || IFNULL(RTRIM(SUFFIX), '') otra vez
    |           3.1     DTB     20251105    Añadido insert a RPA_RESUMEN_FINAL de Balances
	|			3.2		BRG		20251106	Añadido insert a la parte no trimestral de RPA_RESUMEN_FINAL - Balances
	|			3.3 	BRG/DTB	20251110	Eliminado 'TEST_' de ESTRUCTURA_COMERCIAL
	|										Modificada EFFECTIVEENDDATE en ESTRUCTURA_COMERCIAL (si es eot le restamos 100 años, si no le restamos 1 segundo)
    |           3.4     BRG     20251112    Eliminado 'TEST_' de las tablas OUT
    |           3.5     LLS     20251112    Corrección de error: Modificar INYC_BAL_RPI_RESUMEN por OUT_BAL_RPI_RESUMEN_REP
	|										Corrección de error: PEPI, para N_MEDIDA %906% falta el = a 2024
	|										Añadida la parte histórica para OUT_S4_RPA_RESUMEN_FINAL_REP. Los cálculos cuatrimestrales no
	|										Corrección de error: Cruce con OUT_JERARQUIA_REP hacer DISTINCT
	|										Corrección de error: Añadido el campo SALESTRANSACTIONSEQ a la tabla OUT_PROD_AGENTES_FINAL_REP
	|										Borrada la parte de BALANCES de S4 Rappel Producción Agentes (TABLAS RPA)
    |			3.6		BRG/DTB	20251112	Revisado SOLO_DIFERENCIAS y ROUND en campos numéricos de las tablas FINAL
	|			4.0		BRG		20251113	Eliminada la parte de rellenado de tablas FINAL en este procedimiento, se llama al RELLENAR_TABLAS al final
	|			4.1		BRG		20251124	Añadido WHERE PERIODSEQ = :i_PeriodSeq a los UPDATE de SECUENCIAL en las tablas de FACTURA
    |           4.2     BRG     20251126    Incidencia de Soporte, eliminado estado 'N' al hacer cruce con cartera DDEE para S4_POLIZAS
	|			4.3		BRG		20251216	Añadido informe Rappel Especial (TABLAS RE)
	|			4.4		BRG		20251218	Cambiado el insert del SECUENCIAL antes del UPDATE a 0
	|			4.5		BRG		20260112	Corregido error en MES_PERCEPCION en el 1.13
    |           4.6     BRG     20260112    Corregido error relacionado con IRPF en TBL_AGENTES_MES
	|			4.7		BRG		20260113	Corregido error en MES_PERCEPCION en el 1.11
	|			4.8		BRG		20260113	La corrección de TBL_AGENTES_MES duplicaba agentes, solucionado
	|			4.9		BRG		20260116	Añado LOG para saber si estamos en CIERRE, LC o BAL
    |			4.10	DTB		20260127	Añado bloques LC y BAL para PEPI
	|			4.10.1	BRG		20260210	Incidencia Factura Correo Cristian 20260210
	|			4.11	BRG		20260210	Bloque RDC añadido
	|			4.12	BRG		20260219	Bloques PP, CARTERA y RPA DETALLE añadidos (últimos????)
	|			4.13	DTB		20260312	Insert de CARTERA_DD en PEAG corregido. Ahora se insertan los datos de todo el año anterioroes al periodo actual
	|			4.14	DTB		20260324	Modificado el insert a la tabla OUT_CARTERA_AGENTES_REP, ahora tiene un campo más "PRIMA"
	|			4.15    BRG		20260414	Nueva columna COMPANIA en OUT_CARTERA_AGENTES_REP y OUT_PROD_AGENTES_REP por correo Cristian
	|			5.0		BRG		20260416	Añadido nuevo parametro i_tipo para llamar manualmente a CIERRE, LC o BAL sin cambiar la clasificación
	|			5.1		DTB		20260511	Añadidos periodos anteriores para DDEE en PEPA
	|			5.2		DTB		20260511	Corregido mensaje debug para el tipo de ejecución: 1,2,3 -> 0,1,2
	|
    -----------------------------------------------------------------------
*/

BEGIN

	USING SQLSCRIPT_STRING AS LIBRARY;
	
	--	VARIABLES DE USO GENERAL
	DECLARE proc_name VARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR(10) := '5.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_tablas_a_cargar VARCHAR(20) := '';
	DECLARE v_periodo_posteado INTEGER := 0;
	DECLARE v_periodo_finalizado INTEGER := 0;
	DECLARE v_period_name VARCHAR(100);
	DECLARE v_period_startdate DATE;
	DECLARE v_period_enddate DATE;
	DECLARE v_carga INTEGER := 0;
	DECLARE v_stop NUMBER(1);
	DECLARE v_FV_EstadoTrx number(1);
	DECLARE v_startdate_cartera DATE;
	DECLARE v_PeriodSeq_1 BIGINT; --LLS 20251031
	DECLARE v_PeriodSeq_2 BIGINT; --LLS 20251031
	DECLARE v_PeriodParentSeq BIGINT;
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
		
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

			v_num_rows := 0;
		
			RESIGNAL;
		
		END;
	
	BEGIN
	
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting ...', i_log_count, i_id_proceso, 'info');
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Parámetros de entrada -> i_PeriodSeq: ' || i_PeriodSeq || ' | i_lista_informes: ' || i_lista_informes || ' | i_tipo: ' || IFNULL(TO_VARCHAR(i_tipo), 'NULL'), i_log_count, i_id_proceso, 'info');

		-- Revisamos si se debe detener el proceso
		call EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;
		
		-- Obtenemos datos del Periodo
		SELECT per.NAME, per.STARTDATE, per.ENDDATE INTO v_period_name, v_period_startdate, v_period_enddate
		FROM TCMP.cs_period per
		WHERE per.periodseq = :i_PeriodSeq AND
				per.removedate = :v_eot;

		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Periodo -> NAME: ' || :v_period_name || ' | STARTDATE: ' || :v_period_startdate || ' | ENDDATE: ' || v_period_enddate, i_log_count, i_id_proceso, 'info');
		
		-- Obtenemos clasificador de Tablas a Cargar
		SELECT GC.GENERICATTRIBUTE1 INTO v_tablas_a_cargar
		FROM CS_CLASSIFIER C 
		INNER JOIN CS_GENERICCLASSIFIER gc ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ AND gc.REMOVEDATE = :v_eot  AND	gc.ISLAST = 1
		INNER JOIN CS_CATEGORY_CLASSIFIERS CCC ON CCC.CLASSIFIERSEQ = C.CLASSIFIERSEQ AND CCC.REMOVEDATE = :v_eot AND CCC.ISLAST = 1 AND CCC.MODELSEQ = 0
		INNER JOIN CS_CATEGORYTREE ct ON CCC.CATEGORYTREESEQ = CT.CATEGORYTREESEQ AND ct.REMOVEDATE =  :v_eot AND ct.ISLAST = 1
		WHERE CT.NAME = 'Permisos' AND C.classifierid = 'RECARGA' AND C.REMOVEDATE = :v_eot AND C.ISLAST = 1;	

		IF i_tipo IS NOT NULL THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se recargan las tablas de informes en función del valor de i_tipo: '|| i_tipo, i_log_count, i_id_proceso, 'info');
			IF i_tipo = 0 THEN
				v_periodo_posteado := 0;
				v_periodo_finalizado := 0;
			ELSEIF i_tipo = 1 THEN
				v_periodo_posteado := 1;
				v_periodo_finalizado := 0;
			ELSEIF i_tipo = 2 THEN
				v_periodo_posteado := 1;
				v_periodo_finalizado := 1;
			ELSE
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Valor de i_tipo no válido. Debe ser 0 (CIERRE), 1 (LC) o 2 (BAL). Revisar!!!!!!!' , i_log_count, i_id_proceso, 'warning');
				SIGNAL SQL_ERROR_CODE 10002 SET MESSAGE_TEXT = 'VALOR DE I_TIPO NO VALIDO. ERROR EN LA LLAMADA';
				RETURN;
			END IF;

		ELSEIF v_tablas_a_cargar = 'AUTO' THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se recargan las tablas de informes por defecto dependiendo de si el periodo esta posteado o finalizado: '|| v_tablas_a_cargar , i_log_count, i_id_proceso, 'info');    	
			
			SELECT COUNT(DISTINCT PAY.POSTPIPELINERUNSEQ) INTO v_periodo_posteado
			FROM TCMP.CS_PAYMENT PAY
			INNER JOIN TCMP.CS_PLRUN PL ON PAY.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
			WHERE PAY.POSTPIPELINERUNSEQ IS NOT NULL AND PAY.PERIODSEQ = :i_PeriodSeq;
		
			SELECT COUNT(1) INTO v_periodo_finalizado
			FROM TCMP.CS_BALANCE BAL
			INNER JOIN TCMP.CS_PLRUN PL ON BAL.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
			WHERE BAL.PERIODSEQ = :i_PeriodSeq;
	
			--PARA CARGAR LAS TABLAS DE CIERRE BASTA CON PONER LA VARIABLE v_periodo_posteado = 0 
			--v_periodo_posteado := 0;
			--v_periodo_finalizado := 0;
			-- PARA CARGAR LAS TABLAS DE LIQUIDACION COMPLEMENTARIA HAY QUE PONER LA VARIABLE v_periodo_posteado = 1 Y LA VARIABLE v_periodo_finalizado = 0
			--v_periodo_posteado := 1;
			--v_periodo_finalizado := 0;
			-- PARA CARGAR LAS TABLAS DE BALANCE HAY QUE PONER LA VARIABLE v_periodo_posteado = 1 Y LA VARIABLE v_periodo_finalizado = 1
			--v_periodo_posteado := 1;
			--v_periodo_finalizado := 1;

		ELSE
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se recargan las tablas de informes dependiendo de los clasificadores POST y FINALIZE: '|| v_tablas_a_cargar , i_log_count, i_id_proceso, 'info');    	

			SELECT GC.GENERICBOOLEAN1 INTO v_periodo_posteado
			FROM CS_CLASSIFIER C 
			INNER JOIN CS_GENERICCLASSIFIER gc ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ AND gc.REMOVEDATE = :v_eot AND gc.islast = 1
			INNER JOIN CS_CATEGORY_CLASSIFIERS CCC ON  CCC.CLASSIFIERSEQ = C.CLASSIFIERSEQ AND CCC.REMOVEDATE = :v_eot AND CCC.ISLAST = 1 AND CCC.MODELSEQ = 0
			INNER JOIN CS_CATEGORYTREE ct ON CCC.CATEGORYTREESEQ = CT.CATEGORYTREESEQ AND ct.REMOVEDATE = :v_eot AND ct.ISLAST = 1
			WHERE CT.NAME = 'Permisos' AND C.classifierid = 'POST' AND C.REMOVEDATE = :v_eot AND C.ISLAST = 1;
		
			SELECT GC.GENERICBOOLEAN1 INTO v_periodo_finalizado
			FROM CS_CLASSIFIER C 
			INNER JOIN CS_GENERICCLASSIFIER gc ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ AND gc.REMOVEDATE = :v_eot AND gc.islast = 1
			INNER JOIN CS_CATEGORY_CLASSIFIERS CCC ON CCC.CLASSIFIERSEQ = C.CLASSIFIERSEQ AND CCC.REMOVEDATE = :v_eot AND CCC.ISLAST = 1 AND CCC.MODELSEQ = 0
			INNER JOIN CS_CATEGORYTREE ct ON CCC.CATEGORYTREESEQ = CT.CATEGORYTREESEQ AND ct.REMOVEDATE = :v_eot AND ct.ISLAST = 1
			WHERE CT.NAME ='Permisos' AND C.classifierid = 'FINALIZE' AND C.REMOVEDATE = :v_eot AND C.ISLAST = 1;

		END IF;        

		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Carga variable v_periodo_posteado: '|| v_periodo_posteado , i_log_count, i_id_proceso, 'info');
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Carga variable v_periodo_finalizado: '|| v_periodo_finalizado , i_log_count, i_id_proceso, 'info');    	

		IF v_periodo_finalizado != 0 THEN
			IF v_periodo_posteado = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'PERIODO FINALIZADO SIN PAGOS POSTEADOS. POSIBLE ERROR EN LOS DATOS. REVISAR!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	

				-- RAISE_APPLICATION_ERROR(-20000, 'Finalizacion Forzada.');
				SIGNAL SQL_ERROR_CODE 10001 SET MESSAGE_TEXT = 'PERIODO FINALIZADO SIN PAGOS POSTEADOS. POSIBLE ERROR EN LOS DATOS.';
				RETURN;
			ELSE
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'SE CARGAN LAS TABLAS DE BALANCES', i_log_count, i_id_proceso, 'info');
			END IF;
		ELSE
			IF v_periodo_posteado = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'SE CARGAN LAS TABLAS DE CIERRE', i_log_count, i_id_proceso, 'info');
			ELSE
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'SE CARGAN LAS TABLAS DE LIQUIDACIÓN COMPLEMENTARIA', i_log_count, i_id_proceso, 'info');
			END IF;
		END IF;


		-- ALM 20210924; Proyecto Licencias Payee. Consultamos el parametro para saber si estamos en paralelo o ya en Produccion.
		SELECT MAX(VALUE) INTO v_FV_EstadoTrx
		FROM TCMP.CS_FIXEDVALUE
		WHERE NAME = 'FV-CONF-Estado-Transaccion'
			AND REMOVEDATE = :v_eot
			AND MODELSEQ = 0
			AND EFFECTIVESTARTDATE <= :v_period_startdate
			AND EFFECTIVEENDDATE > :v_period_startdate;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Carga variable v_FV_EstadoTrx: '|| v_FV_EstadoTrx , i_log_count, i_id_proceso, 'info');

		--ALM 20160510: Nos quedamos con la ultima ejecucion exitosa para actualizar la tabla de parametros
		SELECT MAX(PIPELINERUNSEQ) INTO v_carga 
		FROM TCMP.CS_PLRUN 
		WHERE COMMAND = 'PipelineRun' 
			AND STATUS = 'Successful'
			AND SUBSTR(DESCRIPTION, 
							LOCATE('stage', DESCRIPTION) + 6, 
							LOCATE('useDeferredReset', DESCRIPTION) - LOCATE('stage', DESCRIPTION) - 7
						) IN ('CompensateAndPay', 'Compensate', 'Summarize', 'Reward')
			--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
			AND MODELSEQ = 0;

		-- Variables proceso anterior - No migradas:
			-- v_Licencias - no se aplica 
			-- v_recarga_temp - se recargan siempre

		-- LLS 20251024 Si estamos en fin de trimestre
		IF SUBSTR_BEFORE(:v_period_name, ' ') IN ('Marzo', 'Junio', 'Septiembre', 'Diciembre')
		THEN
			-- Obtenemos los datos del ParentSeq del periodo
			SELECT PARENTSEQ INTO v_PeriodParentSeq
			FROM TCMP.CS_PERIOD WHERE REMOVEDATE= :v_eot AND PERIODSEQ = :i_PeriodSeq;

			-- Obtenemos los datos del Periodo-1 y Periodo-2
			SELECT PERIODSEQ INTO v_PeriodSeq_1
			FROM TCMP.CS_PERIOD 
			WHERE REMOVEDATE= :v_eot AND PARENTSEQ = :v_PeriodParentSeq AND STARTDATE = ADD_MONTHS(:v_period_startdate,-1);
			
			SELECT PERIODSEQ INTO v_PeriodSeq_2
			FROM TCMP.CS_PERIOD 
			WHERE REMOVEDATE= :v_eot AND PARENTSEQ = :v_PeriodParentSeq AND STARTDATE = ADD_MONTHS(:v_period_startdate,-2);
			
		END IF;


    -------------------------------------------------------------------------------------------------------------------------------------
    -- INICIO TABLAS EXTRACCIONES (TEMPORALES)
	-- uso de variables de tabla si es posible
	---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: Tabla temporal TEMP_TABLA_IRPF_REP pasa a ser TBL_TABLA_IRPF
		TBL_TABLA_IRPF = SELECT C.CLASSIFIERID, SUBSTR(C.NAME,1,1) AS NAME, GC.GENERICNUMBER1
			FROM TCMP.CS_GENERICCLASSIFIERTYPE GCT
			INNER JOIN TCMP.CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
				AND C.TENANTID = :v_idtenant 
				AND C.REMOVEDATE = :v_eot
			INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON C.EFFECTIVESTARTDATE < PD.ENDDATE AND C.EFFECTIVEENDDATE >= PD.ENDDATE
				AND PD.TENANTID = :v_idtenant
			INNER JOIN TCMP.CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
				AND GC.EFFECTIVESTARTDATE < PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
				AND GC.TENANTID = :v_idtenant
				AND GC.REMOVEDATE = :v_eot
			INNER JOIN TCMP.CS_CATEGORY_CLASSIFIERS CC ON C.CLASSIFIERSEQ = CC.CLASSIFIERSEQ 
				AND CC.EFFECTIVESTARTDATE < PD.ENDDATE AND CC.EFFECTIVEENDDATE >= PD.ENDDATE
				AND CC.TENANTID = :v_idtenant
				AND CC.REMOVEDATE = :v_eot
				-- ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
				AND MODELSEQ = 0
			INNER JOIN TCMP.CS_CATEGORYTREE CT ON CC.CATEGORYTREESEQ = CT.CATEGORYTREESEQ
				AND CT.EFFECTIVESTARTDATE < PD.ENDDATE AND CT.EFFECTIVEENDDATE >= PD.ENDDATE
				AND CT.TENANTID = :v_idtenant
				AND CT.REMOVEDATE = :v_eot
				AND CT.NAME = 'Tipo IRPF'
			WHERE GCT.TENANTID = :v_idtenant
				AND GCT.NAME = 'Tipo IRPF'
				AND PD.PERIODSEQ = :i_PeriodSeq;
		v_num_rows := RECORD_COUNT(:TBL_TABLA_IRPF);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_TABLA_IRPF creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;
	
		---------------------------------------------------------------------------------------------------------------------------------
		-- DTB 20250522: Tabla temporal INYC_TABLA_PERCEPCIONES pasa a ser TBL_TABLA_PERCEPCIONES
		TBL_TABLA_PERCEPCIONES = SELECT DISTINCT GC.GENERICATTRIBUTE4 AS DEPOSITO, GC.GENERICATTRIBUTE1 AS DESCRIPCION, GC.GENERICATTRIBUTE2 AS EARNINGCODE, GC.GENERICATTRIBUTE3 AS EARNINGGROUP
			FROM TCMP.CS_GENERICCLASSIFIERTYPE GCT
			INNER JOIN TCMP.CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
				AND C.TENANTID = :v_idtenant
				AND C.REMOVEDATE = :v_eot
			INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON C.EFFECTIVESTARTDATE < PD.ENDDATE AND C.EFFECTIVEENDDATE >= PD.ENDDATE
				AND PD.TENANTID = :v_idtenant
			INNER JOIN TCMP.CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
				AND GC.EFFECTIVESTARTDATE < PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
				AND GC.TENANTID = :v_idtenant
				AND GC.REMOVEDATE = :v_eot
			INNER JOIN TCMP.CS_CATEGORY_CLASSIFIERS CC ON C.CLASSIFIERSEQ = CC.CLASSIFIERSEQ 
				AND CC.EFFECTIVESTARTDATE < PD.ENDDATE AND CC.EFFECTIVEENDDATE >= PD.ENDDATE
				AND CC.TENANTID = :v_idtenant
				AND CC.REMOVEDATE = :v_eot
				--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
				AND MODELSEQ = 0
			INNER JOIN TCMP.CS_CATEGORYTREE CT ON CC.CATEGORYTREESEQ = CT.CATEGORYTREESEQ
				AND CT.EFFECTIVESTARTDATE < PD.ENDDATE AND CT.EFFECTIVEENDDATE >= PD.ENDDATE
				AND CT.TENANTID = :v_idtenant
				AND CT.REMOVEDATE = :v_eot
				AND CT.NAME = 'Percepciones'    
			WHERE GCT.TENANTID = :v_idtenant
				AND GCT.NAME LIKE 'Percepci%n'
				AND PD.PERIODSEQ = :i_PeriodSeq;
		v_num_rows := RECORD_COUNT(:TBL_TABLA_PERCEPCIONES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_TABLA_PERCEPCIONES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;
		---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: Modificacion de EXT.CARTERA_DDEE
		-- ALM 20220330: Solo hacemos esta modificacion si se ejecuta un periodo antes de la LC y los balances.
		IF v_periodo_posteado = 0 THEN

            -- PENDIENTE descomentar después de la migración
            /*
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio modificacion EXT.CARTERA_DDEE si ya no es derechos economicos.', i_log_count, i_id_proceso, 'debug');

			-- BRG 20250522: Creamos variable v_startdate_cartera para optimizar
			SELECT STARTDATE INTO v_startdate_cartera
			FROM CSA_PERIODDIMENSION 
			WHERE TENANTID = :v_idtenant
				AND PERIODSEQ = :i_PeriodSeq;

			-- BRG 20250522: Variable tabla TBL_POSITIONS_CARTERA para optimizar
			TBL_POSITIONS_CARTERA = SELECT P.NAME
				FROM TCMP.CSA_PERIODDIMENSION PD
				INNER JOIN TCMP.CS_POSITION P ON P.EFFECTIVESTARTDATE <= PD.STARTDATE
					AND P.EFFECTIVEENDDATE > PD.STARTDATE
					AND P.REMOVEDATE = :v_eot
					AND P.TENANTID = :v_idtenant
					AND P.GENERICNUMBER2 IN (6,12) 
				WHERE PD.TENANTID = :v_idtenant
					AND PD.PERIODSEQ = :i_PeriodSeq;

            
			-- MCR 20220329: En el caso de que a un agente DDEE le cambien de tipologia, se borraba de la tabla. Cambiamos el estado para que no se tenga en cuenta pero no se borren los datos. 
            -- ATV 20240710: Anyadimos el tipo 6 (que ahora es DDEE) para que no ponga el estado X.
			UPDATE EXT.CARTERA_DDEE
				SET ESTADO = 'X'
				WHERE COMPENSATIONDATE = :v_startdate_cartera
					AND POSITIONNAME NOT IN (SELECT NAME FROM :TBL_POSITIONS_CARTERA)
					AND ESTADO = 'C'
					--ALM 20220331: Control manual para no tener en cuenta agentes concretos:
					AND (COMPENSATIONDATE <> TO_DATE('20220301','YYYYMMDD') OR COD_AGENTE <> '0316003359'); --Pedido por David para 2022-03
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin modificacion EXT.CARTERA_DDEE si ya no es derechos economicos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
            */
		
		END IF;
		
		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;
		-------------------------------------------------------------------------------------------------------------------------------------		
		-- DTB 20250522: Modificación de CONF_PARAMETROS_FILE
		UPDATE EXT.CONF_PARAMETROS_FILE 
			SET VALOR = v_carga 
			WHERE NOMBRE = 'CARGA_TABLAS_TEMP';
		
		---------------------------------------------------------------------------------------------------------------------------------
		-- DTB 20250522: Tabla temporal INYC_TXN_MES_TEMP pasa a ser TBL_TXN_MES      
        TBL_TXN_MES = 
            SELECT ST.TENANTID, ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPESEQ, ST.PIPELINERUNSEQ, ST.ORIGINTYPEID,
                ST.COMPENSATIONDATE, ST.BILLTOADDRESSSEQ, ST.SHIPTOADDRESSSEQ, ST.OTHERTOADDRESSSEQ, ST.ISRUNNABLE, ST.BUSINESSUNITMAP, ST.ACCOUNTINGDATE,
                ST.PRODUCTID, ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ST.PREADJUSTEDVALUE,
                ST.UNITTYPEFORPREADJUSTEDVALUE, ST.VALUE, ST.UNITTYPEFORVALUE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, ST.DISCOUNTTYPE,
                ST.PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, ST.DATASOURCE, ST.REASONSEQ, ST.COMMENTS, ST.GENERICATTRIBUTE1,
                ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, ST.GENERICATTRIBUTE6, ST.GENERICATTRIBUTE7,
                ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, ST.GENERICATTRIBUTE13,
                ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, ST.GENERICATTRIBUTE19,
                ST.GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, ST.GENERICATTRIBUTE25,
                ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, ST.GENERICATTRIBUTE31,
                ST.GENERICATTRIBUTE32, ST.GENERICNUMBER1, ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, ST.UNITTYPEFORGENERICNUMBER2, ST.GENERICNUMBER3,
                ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, ST.GENERICNUMBER6,
                ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, ST.GENERICDATE6,
                ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.PROCESSINGUNITSEQ,
                ST.MODIFICATIONDATE, ST.UNITTYPEFORLINENUMBER, ST.UNITTYPEFORSUBLINENUMBER, ST.UNITTYPEFORNUMBEROFUNITS, ST.UNITTYPEFORDISCOUNTPERCENT,
                ST.UNITTYPEFORNATIVECURRENCYAMT, ST.MODELSEQ,
                CASE WHEN ET.EVENTTYPEID IN ('66','81') AND ST.GENERICATTRIBUTE3 IN ('3','4','5','6','7','8') THEN 'Recuperacion' 
                    --ALM 20180921: Cambiamos la tipologia de las transacciones generadas por Javier para la Venta Simultanea 1+1
                    --              Son transacciones tipo 71 y llevan en el campo Tipo de Campania (GA21) el codigo 'VS11' 
                    WHEN ET.EVENTTYPEID = '71' AND ST.GENERICATTRIBUTE21 = 'VS11' THEN 'Bonif Venta Simultanea'
                    --ATV 20241231 Anyadimos modificacion para polizas sin firmar
                    WHEN ST.GENERICATTRIBUTE6 IN ('S','N') THEN ET.DESCRIPTION || ' - No firmadas Cond. Part'
                    ELSE ET.DESCRIPTION
				END AS EVENTO,
                PROD.GENERICATTRIBUTE5 AS PRODUCTO, PROD.GENERICBOOLEAN1 AS GARANTIA,
                TA.GENERICDATE1 AS FEC_VTO_REC, TA.GENERICNUMBER2 AS KM, TA.GENERICBOOLEAN2 AS RECIBO,
				-- BRG 20250527: Añadimos el campo EVENTTYPEID para deshacernos de los EVENTTYPESEQ
				ET.EVENTTYPEID AS EVENTTYPEID
            FROM TCMP.CS_SALESTRANSACTION ST
            INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                AND TA.TENANTID = :v_idtenant
                --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                AND TA.PROCESSINGUNITSEQ = 38280596832649217
            INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON ST.COMPENSATIONDATE >= PD.STARTDATE AND ST.COMPENSATIONDATE < PD.ENDDATE
                AND PD.TENANTID = :v_idtenant
            LEFT JOIN TCMP.CS_EVENTTYPE ET ON ST.EVENTTYPESEQ = ET.DATATYPESEQ
                AND ET.REMOVEDATE = :v_eot 
                AND ET.TENANTID = :v_idtenant
            LEFT JOIN TCMP.CS_CLASSIFIER CL ON ST.PRODUCTID = CL.CLASSIFIERID 
                AND CL.REMOVEDATE = :v_eot  
                AND CL.EFFECTIVESTARTDATE <= ST.COMPENSATIONDATE AND CL.EFFECTIVEENDDATE > ST.COMPENSATIONDATE
                AND CL.TENANTID = :v_idtenant
            LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                AND PROD.REMOVEDATE = :v_eot  
                AND PROD.EFFECTIVESTARTDATE <= ST.COMPENSATIONDATE AND PROD.EFFECTIVEENDDATE > ST.COMPENSATIONDATE
                AND PROD.TENANTID = :v_idtenant
            WHERE ST.TENANTID = :v_idtenant AND PD.PERIODSEQ = :i_PeriodSeq
                --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                AND ST.MODELSEQ = 0
                --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                AND ST.PROCESSINGUNITSEQ = 38280596832649217;
		v_num_rows := RECORD_COUNT(:TBL_TXN_MES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_TXN_MES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

		---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: Tabla temporal INYC_CREDITOS_MES_TEMP pasa a ser TBL_CREDITOS_MES
		TBL_CREDITOS_MES = SELECT C.TENANTID, C.CREDITSEQ, C.PAYEESEQ, C.POSITIONSEQ, C.SALESORDERSEQ, C.SALESTRANSACTIONSEQ, C.PERIODSEQ, C.CREDITTYPESEQ, C.NAME, C.PIPELINERUNSEQ,
                C.ORIGINTYPEID, C.COMPENSATIONDATE, C.PIPELINERUNDATE, C.BUSINESSUNITMAP, C.PREADJUSTEDVALUE, C.UNITTYPEFORPREADJUSTEDVALUE, C.VALUE,
                C.UNITTYPEFORVALUE, C.RELEASEDATE, C.RULESEQ, C.ISHELD, C.ISROLLABLE, C.ROLLDATE, C.REASONSEQ, C.COMMENTS, C.GENERICATTRIBUTE1, C.GENERICATTRIBUTE2,
                C.GENERICATTRIBUTE3, C.GENERICATTRIBUTE4, C.GENERICATTRIBUTE5, C.GENERICATTRIBUTE6, C.GENERICATTRIBUTE7, C.GENERICATTRIBUTE8, C.GENERICATTRIBUTE9,
                C.GENERICATTRIBUTE10, C.GENERICATTRIBUTE11, C.GENERICATTRIBUTE12, C.GENERICATTRIBUTE13, C.GENERICATTRIBUTE14, C.GENERICATTRIBUTE15,
                C.GENERICATTRIBUTE16, C.GENERICNUMBER1, C.UNITTYPEFORGENERICNUMBER1, C.GENERICNUMBER2, C.UNITTYPEFORGENERICNUMBER2, C.GENERICNUMBER3,
                C.UNITTYPEFORGENERICNUMBER3, C.GENERICNUMBER4, C.UNITTYPEFORGENERICNUMBER4, C.GENERICNUMBER5, C.UNITTYPEFORGENERICNUMBER5, C.GENERICNUMBER6,
                C.UNITTYPEFORGENERICNUMBER6, C.GENERICDATE1, C.GENERICDATE2, C.GENERICDATE3, C.GENERICDATE4, C.GENERICDATE5, C.GENERICDATE6, C.GENERICBOOLEAN1,
                C.GENERICBOOLEAN2, C.GENERICBOOLEAN3, C.GENERICBOOLEAN4, C.GENERICBOOLEAN5, C.GENERICBOOLEAN6, C.PROCESSINGUNITSEQ
            FROM TCMP.CS_CREDIT C
            --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
            INNER JOIN TCMP.CS_PLRUN PL ON C.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
            WHERE C.TENANTID = :v_idtenant AND C.PERIODSEQ = :i_PeriodSeq
				--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                AND C.PROCESSINGUNITSEQ = 38280596832649217;
		v_num_rows := RECORD_COUNT(:TBL_CREDITOS_MES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_CREDITOS_MES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

		-------------------------------------------------------------------------------------------------------------------------------------
		--DTB 20250522: Tabla temporal INYC_MEDIDAS_MES_TEMP pasa a ser TBL_MEDIDAS_MES
        TBL_MEDIDAS_MES =
            SELECT M.TENANTID, M.MEASUREMENTSEQ, M.NAME, M.PAYEESEQ, M.POSITIONSEQ, M.PERIODSEQ, M.PIPELINERUNSEQ, M.PIPELINERUNDATE, M.PLANSEQ, M.RULESEQ, M.VALUE,
                M.UNITTYPEFORVALUE, M.NUMBEROFCREDITS, M.BUSINESSUNITMAP, M.GENERICATTRIBUTE1, M.GENERICATTRIBUTE2, M.GENERICATTRIBUTE3, M.GENERICATTRIBUTE4,
                M.GENERICATTRIBUTE5, M.GENERICATTRIBUTE6, M.GENERICATTRIBUTE7, M.GENERICATTRIBUTE8, M.GENERICATTRIBUTE9, M.GENERICATTRIBUTE10, M.GENERICATTRIBUTE11,
                M.GENERICATTRIBUTE12, M.GENERICATTRIBUTE13, M.GENERICATTRIBUTE14, M.GENERICATTRIBUTE15, M.GENERICATTRIBUTE16, M.GENERICNUMBER1,
                M.UNITTYPEFORGENERICNUMBER1, M.GENERICNUMBER2, M.UNITTYPEFORGENERICNUMBER2, M.GENERICNUMBER3, M.UNITTYPEFORGENERICNUMBER3, M.GENERICNUMBER4,
                M.UNITTYPEFORGENERICNUMBER4, M.GENERICNUMBER5, M.UNITTYPEFORGENERICNUMBER5, M.GENERICNUMBER6, M.UNITTYPEFORGENERICNUMBER6, M.GENERICDATE1,
                M.GENERICDATE2, M.GENERICDATE3, M.GENERICDATE4, M.GENERICDATE5, M.GENERICDATE6, M.GENERICBOOLEAN1, M.GENERICBOOLEAN2, M.GENERICBOOLEAN3,
                M.GENERICBOOLEAN4, M.GENERICBOOLEAN5, M.GENERICBOOLEAN6, M.PROCESSINGUNITSEQ, M.UNITTYPEFORNUMBEROFCREDITS 
            FROM TCMP.CS_MEASUREMENT M
            --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
            INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
            WHERE M.TENANTID = :v_idtenant AND M.PERIODSEQ = :i_PeriodSeq
                --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                AND M.PROCESSINGUNITSEQ = 38280596832649217;
		v_num_rows := RECORD_COUNT(:TBL_MEDIDAS_MES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_MEDIDAS_MES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

		---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: Tabla temporal INYC_PAGOS_MES_TEMP pasa a ser TBL_PAGOS_MES
		TBL_PAGOS_MES = SELECT P.TENANTID, P.PAYMENTSEQ, P.PAYEESEQ, P.POSITIONSEQ, P.PERIODSEQ, P.EARNINGGROUPID, P.EARNINGCODEID, P.TRIALPIPELINERUNSEQ, P.TRIALPIPELINERUNDATE, P.POSTPIPELINERUNSEQ,
                P.POSTPIPELINERUNDATE, P.BUSINESSUNITMAP, P.VALUE, P.UNITTYPEFORVALUE, P.REASONSEQ, P.PROCESSINGUNITSEQ,
                P.GENERICATTRIBUTE1, P.GENERICATTRIBUTE2, P.GENERICATTRIBUTE3, P.GENERICATTRIBUTE4, P.GENERICATTRIBUTE5, P.GENERICATTRIBUTE6, P.GENERICATTRIBUTE7, P.GENERICATTRIBUTE8,
                P.GENERICATTRIBUTE9, P.GENERICATTRIBUTE10, P.GENERICATTRIBUTE11, P.GENERICATTRIBUTE12, P.GENERICATTRIBUTE13, P.GENERICATTRIBUTE14, P.GENERICATTRIBUTE15, P.GENERICATTRIBUTE16,
                P.GENERICNUMBER1, P.GENERICNUMBER2, P.GENERICNUMBER3, P.GENERICNUMBER4, P.GENERICNUMBER5, P.GENERICNUMBER6,
                P.UNITTYPEFORGENERICNUMBER1, P.UNITTYPEFORGENERICNUMBER2, P.UNITTYPEFORGENERICNUMBER3, P.UNITTYPEFORGENERICNUMBER4, P.UNITTYPEFORGENERICNUMBER5, P.UNITTYPEFORGENERICNUMBER6,
                P.GENERICDATE1, P.GENERICDATE2, P.GENERICDATE3, P.GENERICDATE4, P.GENERICDATE5, P.GENERICDATE6,
                P.GENERICBOOLEAN1, P.GENERICBOOLEAN2, P.GENERICBOOLEAN3, P.GENERICBOOLEAN4, P.GENERICBOOLEAN5, P.GENERICBOOLEAN6 
            FROM TCMP.CS_PAYMENT P
            --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
            INNER JOIN TCMP.CS_PLRUN PL ON P.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
            WHERE P.TENANTID = :v_idtenant AND P.PERIODSEQ = :i_PeriodSeq
                --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                AND P.PROCESSINGUNITSEQ = 38280596832649217;
		v_num_rows := RECORD_COUNT(:TBL_PAGOS_MES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_PAGOS_MES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

		---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: Tabla temporal INYC_OFICINAS_MES_TEMP pasa a ser TBL_OFICINAS_MES
		TBL_OFICINAS_MES = SELECT PAD.TENANTID, PAD.PERIODSEQ, PAD.POSITIONSEQ, PAD.PARTICIPANTSEQ, PAD.PARTICIPANTID, PAD.USERID, PAD.PREFIX, PAD.FIRSTNAME, PAD.MIDDLENAME, 
                PAD.LASTNAME, PAD.SUFFIX, PAD.FULLNAME, PAD.TAXID, PAD.SALARY, PAD.UTSFORSALARY, PAD.HIREDATE, PAD.TERMINATIONDATE, PAD.BUSINESSUNITMAP,
                PAD.POSITIONNAME, PAD.POSITIONDESCRIPTION, PAD.TITLENAME, PAD.TITLEDESCRIPTION, PAD.TARGETCOMPENSATION, PAD.UTSFORTARGETCOMPENSATION, PAD.PLANNAME,
                PAD.PLANSEQ, PAD.PROCESSINGUNITNAME, PAD.PROCESSINGUNITSEQ, PAD.POSITIONGENERICATTRIBUTE1, PAD.POSITIONGENERICATTRIBUTE2,
                PAD.POSITIONGENERICATTRIBUTE3, PAD.POSITIONGENERICATTRIBUTE4, PAD.POSITIONGENERICATTRIBUTE5, PAD.POSITIONGENERICATTRIBUTE6,
                PAD.POSITIONGENERICATTRIBUTE7, PAD.POSITIONGENERICATTRIBUTE8, PAD.POSITIONGENERICATTRIBUTE9, PAD.POSITIONGENERICATTRIBUTE10,
                PAD.POSITIONGENERICATTRIBUTE11, PAD.POSITIONGENERICATTRIBUTE12, PAD.POSITIONGENERICATTRIBUTE13, PAD.POSITIONGENERICATTRIBUTE14,
                PAD.POSITIONGENERICATTRIBUTE15, PAD.POSITIONGENERICATTRIBUTE16, PAD.POSITIONGENERICNUMBER1, PAD.UTSFORPOSITIONGN1, PAD.POSITIONGENERICNUMBER2,
                PAD.UTSFORPOSITIONGN2, PAD.POSITIONGENERICNUMBER3, PAD.UTSFORPOSITIONGN3, PAD.POSITIONGENERICNUMBER4, PAD.UTSFORPOSITIONGN4,
                PAD.POSITIONGENERICNUMBER5, PAD.UTSFORPOSITIONGN5, PAD.POSITIONGENERICNUMBER6, PAD.UTSFORPOSITIONGN6, PAD.POSITIONGENERICDATE1,
                PAD.POSITIONGENERICDATE2, PAD.POSITIONGENERICDATE3, PAD.POSITIONGENERICDATE4, PAD.POSITIONGENERICDATE5, PAD.POSITIONGENERICDATE6,
                PAD.POSITIONGENERICBOOLEAN1, PAD.POSITIONGENERICBOOLEAN2, PAD.POSITIONGENERICBOOLEAN3, PAD.POSITIONGENERICBOOLEAN4, PAD.POSITIONGENERICBOOLEAN5,
                PAD.POSITIONGENERICBOOLEAN6, PAD.PARTICIPANTGENERICATTRIBUTE1, PAD.PARTICIPANTGENERICATTRIBUTE2, PAD.PARTICIPANTGENERICATTRIBUTE3,
                PAD.PARTICIPANTGENERICATTRIBUTE4, PAD.PARTICIPANTGENERICATTRIBUTE5, PAD.PARTICIPANTGENERICATTRIBUTE6, PAD.PARTICIPANTGENERICATTRIBUTE7,
                PAD.PARTICIPANTGENERICATTRIBUTE8, PAD.PARTICIPANTGENERICATTRIBUTE9, PAD.PARTICIPANTGENERICATTRIBUTE10, PAD.PARTICIPANTGENERICATTRIBUTE11,
                PAD.PARTICIPANTGENERICATTRIBUTE12, PAD.PARTICIPANTGENERICATTRIBUTE13, PAD.PARTICIPANTGENERICATTRIBUTE14, PAD.PARTICIPANTGENERICATTRIBUTE15,
                PAD.PARTICIPANTGENERICATTRIBUTE16, PAD.PARTICIPANTGENERICNUMBER1, PAD.UTSFORPARTICIPANTGN1, PAD.PARTICIPANTGENERICNUMBER2,
                PAD.UTSFORPARTICIPANTGN2, PAD.PARTICIPANTGENERICNUMBER3, PAD.UTSFORPARTICIPANTGN3, PAD.PARTICIPANTGENERICNUMBER4, PAD.UTSFORPARTICIPANTGN4,
                PAD.PARTICIPANTGENERICNUMBER5, PAD.UTSFORPARTICIPANTGN5, PAD.PARTICIPANTGENERICNUMBER6, PAD.UTSFORPARTICIPANTGN6, PAD.PARTICIPANTGENERICDATE1,
                PAD.PARTICIPANTGENERICDATE2, PAD.PARTICIPANTGENERICDATE3, PAD.PARTICIPANTGENERICDATE4, PAD.PARTICIPANTGENERICDATE5, PAD.PARTICIPANTGENERICDATE6, 
                PAD.PARTICIPANTGENERICBOOLEAN1, PAD.PARTICIPANTGENERICBOOLEAN2, PAD.PARTICIPANTGENERICBOOLEAN3, PAD.PARTICIPANTGENERICBOOLEAN4,
                PAD.PARTICIPANTGENERICBOOLEAN5, PAD.PARTICIPANTGENERICBOOLEAN6, PAD.TITLEGENERICATTRIBUTE1, PAD.TITLEGENERICATTRIBUTE2, PAD.TITLEGENERICATTRIBUTE3,
                PAD.TITLEGENERICATTRIBUTE4, PAD.TITLEGENERICATTRIBUTE5, PAD.TITLEGENERICATTRIBUTE6, PAD.TITLEGENERICATTRIBUTE7, PAD.TITLEGENERICATTRIBUTE8,
                PAD.TITLEGENERICATTRIBUTE9, PAD.TITLEGENERICATTRIBUTE10, PAD.TITLEGENERICATTRIBUTE11, PAD.TITLEGENERICATTRIBUTE12, PAD.TITLEGENERICATTRIBUTE13,
                PAD.TITLEGENERICATTRIBUTE14, PAD.TITLEGENERICATTRIBUTE15, PAD.TITLEGENERICATTRIBUTE16, PAD.TITLEGENERICNUMBER1, PAD.UTSFORTITLEGN1,
                PAD.TITLEGENERICNUMBER2, PAD.UTSFORTITLEGN2, PAD.TITLEGENERICNUMBER3, PAD.UTSFORTITLEGN3, PAD.TITLEGENERICNUMBER4, PAD.UTSFORTITLEGN4,
                PAD.TITLEGENERICNUMBER5, PAD.UTSFORTITLEGN5, PAD.TITLEGENERICNUMBER6, PAD.UTSFORTITLEGN6, PAD.TITLEGENERICDATE1, PAD.TITLEGENERICDATE2,
                PAD.TITLEGENERICDATE3, PAD.TITLEGENERICDATE4, PAD.TITLEGENERICDATE5, PAD.TITLEGENERICDATE6, PAD.TITLEGENERICBOOLEAN1, PAD.TITLEGENERICBOOLEAN2,
                PAD.TITLEGENERICBOOLEAN3, PAD.TITLEGENERICBOOLEAN4, PAD.TITLEGENERICBOOLEAN5, PAD.TITLEGENERICBOOLEAN6, PAD.MANAGERSEQ, PAD.MANAGERFULLNAME,
                PAD.FULLNAMELEVEL_1, PAD.FULLNAMELEVEL_2, PAD.FULLNAMELEVEL_3, PAD.FULLNAMELEVEL_4, PAD.FULLNAMELEVEL_5, PAD.FULLNAMELEVEL_6, PAD.FULLNAMELEVEL_7,
                PAD.FULLNAMELEVEL_8, PAD.ISPAYEE, PAD.BOUSERID, PAD.ETLHISTORYKEY, PAD.ISRELEASEDFORRPT
            FROM TCMP.CSA_PADIMENSION PAD
            WHERE PAD.TENANTID = :v_idtenant AND PAD.ISPAYEE = 1 AND PAD.POSITIONGENERICNUMBER2 IS NULL 
                AND PAD.PERIODSEQ = :i_PeriodSeq;
		v_num_rows := RECORD_COUNT(:TBL_OFICINAS_MES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_OFICINAS_MES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

		---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: Tabla temporal INYC_AGENTES_MES_TEMP pasa a ser TBL_AGENTES_MES
		TBL_AGENTES_MES = SELECT PAD.TENANTID, PAD.PERIODSEQ, PAD.POSITIONSEQ, PAD.PARTICIPANTSEQ, PAD.PARTICIPANTID, PAD.USERID, PAD.PREFIX, PAD.FIRSTNAME, PAD.MIDDLENAME, 
                PAD.LASTNAME, PAD.SUFFIX, PAD.FULLNAME, PAR.TAXID, PAD.SALARY, PAD.UTSFORSALARY, PAD.HIREDATE, PAD.TERMINATIONDATE, PAD.BUSINESSUNITMAP,
                PAD.POSITIONNAME, PAD.POSITIONDESCRIPTION, PAD.TITLENAME, PAD.TITLEDESCRIPTION, PAD.TARGETCOMPENSATION, PAD.UTSFORTARGETCOMPENSATION, PAD.PLANNAME,
                PAD.PLANSEQ, PAD.PROCESSINGUNITNAME, PAD.PROCESSINGUNITSEQ, PAD.POSITIONGENERICATTRIBUTE1, PAD.POSITIONGENERICATTRIBUTE2,
                PAD.POSITIONGENERICATTRIBUTE3, PAD.POSITIONGENERICATTRIBUTE4, PAD.POSITIONGENERICATTRIBUTE5, PAD.POSITIONGENERICATTRIBUTE6,
                PAD.POSITIONGENERICATTRIBUTE7, PAD.POSITIONGENERICATTRIBUTE8, PAD.POSITIONGENERICATTRIBUTE9, PAD.POSITIONGENERICATTRIBUTE10,
                PAD.POSITIONGENERICATTRIBUTE11, PAD.POSITIONGENERICATTRIBUTE12, PAD.POSITIONGENERICATTRIBUTE13, PAD.POSITIONGENERICATTRIBUTE14,
                PAD.POSITIONGENERICATTRIBUTE15, PAD.POSITIONGENERICATTRIBUTE16, PAD.POSITIONGENERICNUMBER1, PAD.UTSFORPOSITIONGN1, PAD.POSITIONGENERICNUMBER2,
                PAD.UTSFORPOSITIONGN2, PAD.POSITIONGENERICNUMBER3, PAD.UTSFORPOSITIONGN3, PAD.POSITIONGENERICNUMBER4, PAD.UTSFORPOSITIONGN4,
                PAD.POSITIONGENERICNUMBER5, PAD.UTSFORPOSITIONGN5, PAD.POSITIONGENERICNUMBER6, PAD.UTSFORPOSITIONGN6, PAD.POSITIONGENERICDATE1,
                PAD.POSITIONGENERICDATE2, PAD.POSITIONGENERICDATE3, PAD.POSITIONGENERICDATE4, PAD.POSITIONGENERICDATE5, PAD.POSITIONGENERICDATE6,
                PAD.POSITIONGENERICBOOLEAN1, PAD.POSITIONGENERICBOOLEAN2, PAD.POSITIONGENERICBOOLEAN3, PAD.POSITIONGENERICBOOLEAN4, PAD.POSITIONGENERICBOOLEAN5,
                PAD.POSITIONGENERICBOOLEAN6, PAD.PARTICIPANTGENERICATTRIBUTE1, PAD.PARTICIPANTGENERICATTRIBUTE2, PAD.PARTICIPANTGENERICATTRIBUTE3,
                PAD.PARTICIPANTGENERICATTRIBUTE4, PAD.PARTICIPANTGENERICATTRIBUTE5, PAD.PARTICIPANTGENERICATTRIBUTE6, PAD.PARTICIPANTGENERICATTRIBUTE7,
                PAD.PARTICIPANTGENERICATTRIBUTE8, PAD.PARTICIPANTGENERICATTRIBUTE9, PAD.PARTICIPANTGENERICATTRIBUTE10, PAD.PARTICIPANTGENERICATTRIBUTE11,
                PAD.PARTICIPANTGENERICATTRIBUTE12, PAD.PARTICIPANTGENERICATTRIBUTE13, PAD.PARTICIPANTGENERICATTRIBUTE14, PAD.PARTICIPANTGENERICATTRIBUTE15,
                PAD.PARTICIPANTGENERICATTRIBUTE16, PAD.PARTICIPANTGENERICNUMBER1, PAD.UTSFORPARTICIPANTGN1, PAD.PARTICIPANTGENERICNUMBER2,
                PAD.UTSFORPARTICIPANTGN2, PAD.PARTICIPANTGENERICNUMBER3, PAD.UTSFORPARTICIPANTGN3, PAD.PARTICIPANTGENERICNUMBER4, PAD.UTSFORPARTICIPANTGN4,
                PAD.PARTICIPANTGENERICNUMBER5, PAD.UTSFORPARTICIPANTGN5, PAD.PARTICIPANTGENERICNUMBER6, PAD.UTSFORPARTICIPANTGN6, PAD.PARTICIPANTGENERICDATE1,
                PAD.PARTICIPANTGENERICDATE2, PAD.PARTICIPANTGENERICDATE3, PAD.PARTICIPANTGENERICDATE4, PAD.PARTICIPANTGENERICDATE5, PAD.PARTICIPANTGENERICDATE6, 
                PAD.PARTICIPANTGENERICBOOLEAN1, PAD.PARTICIPANTGENERICBOOLEAN2, PAD.PARTICIPANTGENERICBOOLEAN3, PAD.PARTICIPANTGENERICBOOLEAN4,
                PAD.PARTICIPANTGENERICBOOLEAN5, PAD.PARTICIPANTGENERICBOOLEAN6, PAD.TITLEGENERICATTRIBUTE1, PAD.TITLEGENERICATTRIBUTE2, PAD.TITLEGENERICATTRIBUTE3,
                PAD.TITLEGENERICATTRIBUTE4, PAD.TITLEGENERICATTRIBUTE5, PAD.TITLEGENERICATTRIBUTE6, PAD.TITLEGENERICATTRIBUTE7, PAD.TITLEGENERICATTRIBUTE8,
                PAD.TITLEGENERICATTRIBUTE9, PAD.TITLEGENERICATTRIBUTE10, PAD.TITLEGENERICATTRIBUTE11, PAD.TITLEGENERICATTRIBUTE12, PAD.TITLEGENERICATTRIBUTE13,
                PAD.TITLEGENERICATTRIBUTE14, PAD.TITLEGENERICATTRIBUTE15, PAD.TITLEGENERICATTRIBUTE16, PAD.TITLEGENERICNUMBER1, PAD.UTSFORTITLEGN1,
                PAD.TITLEGENERICNUMBER2, PAD.UTSFORTITLEGN2, PAD.TITLEGENERICNUMBER3, PAD.UTSFORTITLEGN3, PAD.TITLEGENERICNUMBER4, PAD.UTSFORTITLEGN4,
                PAD.TITLEGENERICNUMBER5, PAD.UTSFORTITLEGN5, PAD.TITLEGENERICNUMBER6, PAD.UTSFORTITLEGN6, PAD.TITLEGENERICDATE1, PAD.TITLEGENERICDATE2,
                PAD.TITLEGENERICDATE3, PAD.TITLEGENERICDATE4, PAD.TITLEGENERICDATE5, PAD.TITLEGENERICDATE6, PAD.TITLEGENERICBOOLEAN1, PAD.TITLEGENERICBOOLEAN2,
                PAD.TITLEGENERICBOOLEAN3, PAD.TITLEGENERICBOOLEAN4, PAD.TITLEGENERICBOOLEAN5, PAD.TITLEGENERICBOOLEAN6, PAD.MANAGERSEQ, PAD.MANAGERFULLNAME,
                PAD.FULLNAMELEVEL_1, PAD.FULLNAMELEVEL_2, PAD.FULLNAMELEVEL_3, PAD.FULLNAMELEVEL_4, PAD.FULLNAMELEVEL_5, PAD.FULLNAMELEVEL_6, PAD.FULLNAMELEVEL_7,
                PAD.FULLNAMELEVEL_8, PAD.ISPAYEE, PAD.BOUSERID, PAD.ETLHISTORYKEY, PAD.ISRELEASEDFORRPT, PAD.MANAGERPARTICIPANTSEQ
            from CSA_PADIMENSION PAD 
			INNER JOIN CSA_PERIODDIMENSION PER 
				ON PAD.PERIODSEQ = PER.PERIODSEQ
			INNER JOIN CS_PARTICIPANT PAR -- Se hace un JOIN con CS_PARTICIPANT a ultimo dia del mes de cada periodo para extraer: PAR.PARTICIPANTEMAIL, PAR.TAXID y fechas de efectividad por si quisieran filtrar por fecha concreta
				ON PAD.PARTICIPANTSEQ = PAR.PAYEESEQ and PAR.REMOVEDATE = TO_DATE('22000101','yyyymmdd')
				AND PAR.EFFECTIVESTARTDATE < PER.ENDDATE and  PAR.EFFECTIVEENDDATE >= PER.ENDDATE
            WHERE PAD.TENANTID = :v_idtenant AND PAD.ISPAYEE = 1
                --ALM 20170925: No filtrmaos por TerminationDate nula sino porque sea mayor que el periodo actual o nula 
                --AND PAD.TERMINATIONDATE IS NULL
                AND (PAD.TERMINATIONDATE IS NULL OR PAD.TERMINATIONDATE >= :v_period_enddate)
                --ALM 20170711: Quitamos las Position sin Plan, ya que no aportan calculos
                AND PAD.TITLENAME <> 'TTL SIN PLAN'
                AND PAD.PERIODSEQ = :i_PeriodSeq;
		v_num_rows := RECORD_COUNT(:TBL_AGENTES_MES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_AGENTES_MES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

		---------------------------------------------------------------------------------------------------------------------------------
		
		-- BRG 20250522: Tabla auxiliar TBL_POSITION_RELATION_CR
		TBL_POSITION_RELATION_CR = SELECT PR.PARENTPOSITIONSEQ,PR.CHILDPOSITIONSEQ,PR.EFFECTIVESTARTDATE,PR.EFFECTIVEENDDATE 
			FROM TCMP.CS_POSITIONRELATION PR
			INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT ON PR.POSITIONRELATIONTYPESEQ=PRT.DATATYPESEQ 
				AND PRT.REMOVEDATE = :v_eot
				AND PRT.NAME = 'Contract Rollup'
				AND PRT.TENANTID = :v_idtenant
			WHERE PR.REMOVEDATE = :v_eot
				AND PR.TENANTID = :v_idtenant;
		
		-- BRG 20250522: Tabla temporal INYC_AGENTES_PRIN_MES_TEMP pasa a ser TBL_AGENTES_PRIN_MES
		TBL_AGENTES_PRIN_MES = SELECT DISTINCT 
                --ALM 20161201: Anadimos los campos de la tabla de PERIODOS que se utilizan en los diferentes informes
                PD.YEAR,PD.QUARTER,
                PD.NAME AS PERIODO,
                PD.STARTDATE,
                PD.PERIODSEQ,
                CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN PAD_INS.POSITIONSEQ ELSE P.RULEELEMENTOWNERSEQ END AS POSITIONSEQ_PRIN,
                PAD_INS.POSITIONSEQ,
                PAD_INS.PARTICIPANTSEQ,
                PAD_INS.BOUSERID,
                --ALM 20160404: MODIFICACIoN PARA EL CAMBIO AL CoDIGO uNICO
                PAD_INS.POSITIONNAME AS POS_CALLIDUS,
                PAD_INS.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME,
                PAD_INS.FIRSTNAME,
                PAD_INS.LASTNAME,
                PAD_INS.SUFFIX,
                PAD_INS.TAXID,
                --ALM 20170512: Anadimos todos los campos existentes del Participant y la Position
                PAD_INS.HIREDATE,
                PAD_INS.TERMINATIONDATE,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE1 AS NIF,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE2 AS TIPO_DOCUMENTO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE3 AS TIPO_PERSONA,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE4 AS COD_DGS,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE5 AS CIA_EMPLEADO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE6 AS TIPO_MEDIADOR_OCASO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE7 AS MUNICIPIO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE8 AS TIPO_VIA,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE9 AS DOMICILIO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE10 AS NUMERO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE11 AS RESTO_DOMICILIO,   
                PAD_INS.PARTICIPANTGENERICATTRIBUTE12 AS SEXO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE13 AS ESTADO_CIVIL,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE14 AS TELEFONO_FIJO,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE15 AS TELEFONO_MOVIL,
                PAD_INS.PARTICIPANTGENERICATTRIBUTE16 AS IBAN,
                PAD_INS.PARTICIPANTGENERICNUMBER1 AS CP,
                PAD_INS.PARTICIPANTGENERICNUMBER2 AS COD_PROVINCIA,
                PAD_INS.PARTICIPANTGENERICNUMBER3 AS COD_MUNICIPIO,
                PAD_INS.PARTICIPANTGENERICNUMBER4 AS ID_EMPLEADO,
                PAD_INS.PARTICIPANTGENERICNUMBER5 AS IRPF_EMPLEADO,
                PAD_INS.PARTICIPANTGENERICNUMBER6 AS FAX,
                PAD_INS.PARTICIPANTGENERICDATE1 AS FEC_NACIMIENTO,
                PAD_INS.PARTICIPANTGENERICDATE2 AS FEC_REG_DGS,
                PAD_INS.PARTICIPANTGENERICDATE3 AS FEC_ENVIO_DGS,
                PAD_INS.PARTICIPANTGENERICDATE4 AS FEC_FIN_CIASE,
                PAD_INS.PARTICIPANTGENERICDATE5 AS FEC_EFECTO_SUPERRAPEL,
                PAD_INS.PARTICIPANTGENERICDATE6 AS FEC_REGULA_SUPERRAPEL,
                PAD_INS.PARTICIPANTGENERICBOOLEAN1 AS AUTOLIQUIDA,
                PAD_INS.PARTICIPANTGENERICBOOLEAN2 AS CORREDOR,
                PAD_INS.PARTICIPANTGENERICBOOLEAN3 AS PROPIEDAD,
                PAD_INS.PARTICIPANTGENERICBOOLEAN4 AS SUPERRAPEL,
                PAD_INS.PARTICIPANTGENERICBOOLEAN5 AS COMIS_ANUAL_RRPP,
                PAD_INS.PARTICIPANTGENERICBOOLEAN6 AS PAGO_POR_IBAN,
                --ALM 20160315: MODIFICACIoN PARA EL CAMBIO AL CoDIGO uNICO
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE1 ELSE P.GENERICATTRIBUTE1 END AS TIPO_PRIN_AGENTE,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE2 ELSE P.GENERICATTRIBUTE2 END AS TIPO_AGENTE,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE3 ELSE P.GENERICATTRIBUTE3 END AS POS_PRIN,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE5 ELSE P.GENERICATTRIBUTE5 END AS CUADRO_INSP_OCASO,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE6 ELSE P.GENERICATTRIBUTE6 END AS CUADRO_RRGG_OCASO,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE7 ELSE P.GENERICATTRIBUTE7 END AS CUADRO_RRTT_OCASO,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE8 ELSE P.GENERICATTRIBUTE8 END AS CIA_POS,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE9 ELSE P.GENERICATTRIBUTE9 END AS PROMOCION,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE10 ELSE P.GENERICATTRIBUTE10 END AS CUADRO_INSP_ETERNA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE11 ELSE P.GENERICATTRIBUTE11 END AS CUADRO_RRGG_ETERNA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE12 ELSE P.GENERICATTRIBUTE12 END AS CUADRO_RRTT_ETERNA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE13 ELSE P.GENERICATTRIBUTE13 END AS ANIO_CAPTACION,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE14 ELSE P.GENERICATTRIBUTE14 END AS INSP_CAPTACION,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE15 ELSE P.GENERICATTRIBUTE15 END AS NUM_MESES_PREPLAN,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICATTRIBUTE16 ELSE P.GENERICATTRIBUTE16 END AS ESCALADO,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICNUMBER1 ELSE P.GENERICNUMBER1 END AS ID_TIPO_PRIN_AGENTE,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICNUMBER2 ELSE P.GENERICNUMBER2 END AS ID_TIPO_AGENTE,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICNUMBER3 ELSE P.GENERICNUMBER3 END AS ID_CLASE_OFICINA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICNUMBER4 ELSE P.GENERICNUMBER4 END AS ID_TIPO_OFICINA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICNUMBER5 ELSE P.GENERICNUMBER5 END AS PORC_COMIS_CARTERA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICNUMBER6 ELSE P.GENERICNUMBER6 END AS IMP_COMIS_CARTERA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICDATE1 ELSE P.GENERICDATE1 END AS FEC_ALTA_POS,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICDATE2 ELSE P.GENERICDATE2 END AS FEC_BAJA_POS,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICDATE3 ELSE P.GENERICDATE3 END AS FEC_INI_CONS_PC,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICDATE4 ELSE P.GENERICDATE4 END AS FEC_FIN_CONS_PC,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICDATE5 ELSE P.GENERICDATE5 END AS FEC_INI_ASIS,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICDATE6 ELSE P.GENERICDATE6 END AS FEC_LIM_COMIS,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICBOOLEAN1 ELSE P.GENERICBOOLEAN1 END AS REDUCCION,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICBOOLEAN2 ELSE P.GENERICBOOLEAN2 END AS PRODUCTOR_OCASO,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICBOOLEAN3 ELSE P.GENERICBOOLEAN3 END AS CONSOLIDA,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICBOOLEAN4 ELSE P.GENERICBOOLEAN4 END AS INI_AGENTE_ASIS,
                CASE WHEN P.NAME IS NULL THEN PAD_INS.POSITIONGENERICBOOLEAN5 ELSE P.GENERICBOOLEAN5 END AS PRODUCTOR_ETERNA,
                --ALM 20180613: Anadimos campos para poder unir por Manager y incluir sus campos en la tabla INYC_JERARQUIA
                CASE WHEN P.NAME IS NULL THEN PAD_INS.MANAGERSEQ ELSE P.MANAGERSEQ END AS MANAGERSEQ_PRIN,
                PAD_INS.MANAGERSEQ AS MANAGERSEQ
            FROM :TBL_AGENTES_MES PAD_INS
            INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON PAD_INS.PERIODSEQ = PD.PERIODSEQ
                AND PD.TENANTID = :v_idtenant
            LEFT JOIN :TBL_POSITION_RELATION_CR PR ON PAD_INS.POSITIONSEQ = PR.CHILDPOSITIONSEQ 
                AND PR.EFFECTIVESTARTDATE < PD.ENDDATE AND PR.EFFECTIVEENDDATE >= PD.ENDDATE
            LEFT JOIN TCMP.CS_POSITION P ON PR.PARENTPOSITIONSEQ = P.RULEELEMENTOWNERSEQ
                AND P.REMOVEDATE = :v_eot
                AND P.EFFECTIVESTARTDATE <= PD.STARTDATE AND P.EFFECTIVEENDDATE > PD.STARTDATE 
                AND P.TENANTID = :v_idtenant
            WHERE PD.PERIODSEQ = :i_PeriodSeq;
		v_num_rows := RECORD_COUNT(:TBL_AGENTES_PRIN_MES);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_AGENTES_PRIN_MES creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;
		
	-------------------------------------------------------------------------------------------------------------------------------------
    -- INICIO TABLAS DE INFORMES
	------------------------------------------------------------------------------------------------------------------------------------
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado y Carga Tabla Jerarquia.', i_log_count, i_id_proceso, 'info');
		
		-- Siempre se genera la tabla de jerarquía
		-- BRG 20250522: Tabla INYC_JERARQUIA pasa a ser OUT_JERARQUIA_REP
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_JERARQUIA_REP.', i_log_count, i_id_proceso, 'debug');
		DELETE FROM EXT.OUT_JERARQUIA_REP WHERE PERIODSEQ = :i_PeriodSeq;
		v_num_rows := ::ROWCOUNT;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_JERARQUIA_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_JERARQUIA_REP.', i_log_count, i_id_proceso, 'debug');
		INSERT INTO EXT.OUT_JERARQUIA_REP (COD_REGIONAL, REGIONAL, COD_SUCURSAL, SUCURSAL, COD_OFICINA, OFICINA, YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, BOUSERID, POS_PRIN, POS_CALLIDUS, POSITIONNAME, NIF, NOMBRE, TIPO_PERSONA, TAXID, MUNICIPIO, DOMICILIO, CP, ID_EMPLEADO, IRPF_EMPLEADO, CIA_EMPLEADO, ID_TIPO_AGENTE, TIPO_AGENTE, CUADRO_INSP_OCASO, CUADRO_INSP_ETERNA, CUADRO_RRGG_OCASO, CUADRO_RRTT_OCASO, CUADRO_RRGG_ETERNA, CUADRO_RRTT_ETERNA, PROMOCION, SUPERRAPEL, ESCALADO, FEC_BAJA_POS, FEC_ALTA_POS, MANAGER_POS_PRIN, MANAGER_POS_CALLIDUS, MANAGER_POSITIONNAME, MANAGER_NIF, MANAGER_NOMBRE, MANAGER_ID_TIPO_AGENTE, MANAGER_TIPO_AGENTE, MANAGER_CUADRO_INSP_OCASO, MANAGER_CUADRO_INSP_ETERNA, MANAGER_FEC_BAJA_POS, MANAGER_FEC_ALTA_POS, FEC_ALTA_CAT_INS)
			SELECT
				CASE 
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
                        THEN PAD_REG.POSITIONNAME
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
                        THEN PAD_SUC.POSITIONNAME
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) 
                        THEN PAD_OF.POSITIONNAME
                    ELSE PAD_PTO_VENTA.POSITIONNAME 
                    END AS COD_REGIONAL,
                CASE 
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
                        THEN PAD_REG.LASTNAME
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
                        THEN PAD_SUC.LASTNAME
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) 
                        THEN PAD_OF.LASTNAME
                    ELSE PAD_PTO_VENTA.LASTNAME
                    END AS REGIONAL,
				CASE 
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
						THEN PAD_SUC.POSITIONNAME
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
						THEN PAD_OF.POSITIONNAME
                    ELSE PAD_PTO_VENTA.POSITIONNAME 
					END AS COD_SUCURSAL,
				CASE 
					WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
						THEN PAD_SUC.LASTNAME
                    WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
						THEN PAD_OF.LASTNAME
                    ELSE PAD_PTO_VENTA.LASTNAME 
					END AS SUCURSAL,
				CASE 
					WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
						THEN PAD_OF.POSITIONNAME  
                    ELSE PAD_PTO_VENTA.POSITIONNAME 
					END AS COD_OFICINA,
				CASE 
					WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
						THEN PAD_OF.LASTNAME  
                    ELSE PAD_PTO_VENTA.LASTNAME 
					END AS OFICINA,
				PAD_INS.YEAR, PAD_INS.QUARTER, PAD_INS.PERIODO, PAD_INS.STARTDATE,
                PAD_INS.PERIODSEQ, PAD_INS.POSITIONSEQ_PRIN, PAD_INS.POSITIONSEQ, PAD_INS.PARTICIPANTSEQ, PAD_INS.BOUSERID,
                PAD_INS.POS_PRIN, PAD_INS.POS_CALLIDUS, PAD_INS.POSITIONNAME, PAD_INS.NIF,
                IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                PAD_INS.TIPO_PERSONA, PAD_INS.TAXID, PAD_INS.MUNICIPIO, PAD_INS.DOMICILIO,   
                PAD_INS.CP, PAD_INS.ID_EMPLEADO AS ID_EMPLEADO, 
				PAD_INS.IRPF_EMPLEADO, PAD_INS.CIA_EMPLEADO,
                PAD_INS.ID_TIPO_AGENTE, PAD_INS.TIPO_AGENTE, PAD_INS.CUADRO_INSP_OCASO, PAD_INS.CUADRO_INSP_ETERNA,
                PAD_INS.CUADRO_RRGG_OCASO, PAD_INS.CUADRO_RRTT_OCASO, PAD_INS.CUADRO_RRGG_ETERNA, PAD_INS.CUADRO_RRTT_ETERNA,
                PAD_INS.PROMOCION, PAD_INS.SUPERRAPEL, PAD_INS.ESCALADO, PAD_INS.FEC_BAJA_POS, PAD_INS.FEC_ALTA_POS,
                --ALM 20180613: Anadimos campos del Manager para el nuevo informe 1.12.1 Produccion Agentes por Meses
                MANAGER.POS_PRIN AS MANAGER_POS_PRIN, MANAGER.POS_CALLIDUS AS MANAGER_POS_CALLIDUS, MANAGER.POSITIONNAME AS MANAGER_POSITIONNAME, MANAGER.NIF AS MANAGER_NIF,
				IFNULL(RTRIM(MANAGER.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(MANAGER.LASTNAME) || ' ', '') || IFNULL(RTRIM(MANAGER.SUFFIX), '') AS MANAGER_NOMBRE,
                MANAGER.ID_TIPO_AGENTE AS MANAGER_ID_TIPO_AGENTE, MANAGER.TIPO_AGENTE AS MANAGER_TIPO_AGENTE,
                MANAGER.CUADRO_INSP_OCASO AS MANAGER_CUADRO_INSP_OCASO, MANAGER.CUADRO_INSP_ETERNA AS MANAGER_CUADRO_INSP_ETERNA,
                MANAGER.FEC_BAJA_POS AS MANAGER_FEC_BAJA_POS, MANAGER.FEC_ALTA_POS AS MANAGER_FEC_ALTA_POS,
				(SELECT IFNULL(MAX(POS_ANT.EFFECTIVEENDDATE), MIN(POS_ACT.EFFECTIVESTARTDATE))
				FROM TCMP.CS_POSITION POS_ACT
				--ALM 20170510: Tenemos que tener en cuenta cualquier cambio de tipologia no solo el paso de agente a inspector
				LEFT JOIN TCMP.CS_POSITION POS_ANT ON POS_ACT.PAYEESEQ = POS_ANT.PAYEESEQ
					--ALM 20170519: Tenemos en cuenta todas las versiones anteriores porque puede que venga de una tipologia que no sea inspector
					AND POS_ACT.EFFECTIVESTARTDATE >= POS_ANT.EFFECTIVEENDDATE
					--ATV 20240228 Los cuadros A, D y N se reagrupan en el cuadro P, la modificacion se debe a que no se debe tener en cuenta que ha habido un cambio de categoria y asi puedan acumular
					AND (REPLACE(REPLACE(REPLACE(POS_ACT.GENERICATTRIBUTE5, 'A', 'P'), 'D', 'P'), 'N', 'P') <> REPLACE(REPLACE(REPLACE(POS_ANT.GENERICATTRIBUTE5, 'A', 'P'), 'D', 'P'), 'N', 'P') OR POS_ANT.GENERICATTRIBUTE5 IS NULL)
					AND POS_ANT.REMOVEDATE = :v_eot
				WHERE POS_ACT.REMOVEDATE = :v_eot
					--ALM 20170512: Filtramos las versiones de las posiciones con tipologia de agente con grupo/inspector/responsable
					AND POS_ACT.GENERICNUMBER2 >= 50
					AND POS_ACT.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE
					AND POS_ACT.PAYEESEQ = PAD_INS.PARTICIPANTSEQ) AS FEC_ALTA_CAT_INS
            FROM :TBL_AGENTES_PRIN_MES PAD_INS
			LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
			LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
			LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
                AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
			LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
                AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
			--ALM 20180613: Unimos por el Manager para poder extraer informacion de el para el nuevo informe 1.12.1 Produccion Agentes por Meses
            LEFT JOIN :TBL_AGENTES_PRIN_MES MANAGER ON PAD_INS.PERIODSEQ = MANAGER.PERIODSEQ 
                AND PAD_INS.MANAGERSEQ_PRIN = MANAGER.POSITIONSEQ_PRIN
			WHERE PAD_INS.POS_PRIN <> '0000000000';
		v_num_rows := ::ROWCOUNT;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_JERARQUIA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado y Carga Tabla Jerarquia.', i_log_count, i_id_proceso, 'info');

		-- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

		---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: Tabla auxiliar para el formato del periodo
		TBL_PER_FORMAT = SELECT DISTINCT
				J.PERIODO,
				SUBSTR_AFTER(J.PERIODO, ' ') || CASE 
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Enero' THEN ' 01 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Febrero' THEN ' 02 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Marzo' THEN ' 03 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Abril' THEN ' 04 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Mayo' THEN ' 05 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Junio' THEN ' 06 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Julio' THEN ' 07 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Agosto' THEN ' 08 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Septiembre' THEN ' 09 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Octubre' THEN ' 10 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Noviembre' THEN ' 11 '
					WHEN SUBSTR_BEFORE(J.PERIODO, ' ') = 'Diciembre' THEN ' 12 '
					END || SUBSTR_BEFORE(J.PERIODO, ' ') AS PERIODO_FORMATO
			FROM EXT.OUT_JERARQUIA_REP J;

		---------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250522: TABLAS PARA INFORME 1.11 PERCEPCION AGENTES
		IF :i_lista_informes = 'PEAG' OR :i_lista_informes LIKE '%|PEAG|%' OR :i_lista_informes LIKE '%|PEAG' OR :i_lista_informes LIKE 'PEAG|%' 
			OR :i_lista_informes = 'ALL' THEN
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe 1.11 Percepción Agentes.', i_log_count, i_id_proceso, 'info');

			-- BRG 20250522: Tabla INYC_PERC_AGENTES pasa a ser OUT_PERC_AGENTES_REP
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_PERC_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			DELETE FROM EXT.OUT_PERC_AGENTES_REP WHERE PERIODSEQ = :i_PeriodSeq;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_PERC_AGENTES_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_PERC_AGENTES_REP. Percepciones.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PERC_AGENTES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, PERCEPCION, IMP_PERCEPCION, MES_PERCEPCION, BALANCE, EARNINGCODEID, EARNINGGROUPID, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME)
				SELECT
					PAD_INS.YEAR,PAD_INS.QUARTER, PAD_INS.PERIODO, PAD_INS.STARTDATE, PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					PERC.DESCRIPCION AS PERCEPCION, D.VALUE AS IMP_PERCEPCION,
					(SELECT EXTRACT(MONTH FROM PD.STARTDATE) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ AND PD.REMOVEDATE = :v_eot) AS MES_PERCEPCION,
					0 AS BALANCE, D.EARNINGCODEID, D.EARNINGGROUPID,
					PAD_INS.POSITIONSEQ_PRIN, PAD_INS.POSITIONSEQ, PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN, PAD_INS.POS_CALLIDUS, PAD_INS.POSITIONNAME
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
					AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
					AND D.PERIODSEQ IN (
						SELECT P.PERIODSEQ
						FROM TCMP.CS_PERIOD P
						INNER JOIN TCMP.CS_PERIODTYPE PT ON P.PERIODTYPESEQ = PT.PERIODTYPESEQ
							AND PT.REMOVEDATE = :v_eot
							-- BRG 20250522: Filtramos por el tipo de periodo para quedarnos solo los meses
							AND PT.NAME = 'month'
							AND PT.TENANTID = :v_idtenant
						WHERE P.REMOVEDATE = :v_eot
							AND RIGHT(P.NAME, 4) = RIGHT(PAD_INS.PERIODO, 4)
							AND P.STARTDATE <= PAD_INS.STARTDATE
							AND P.TENANTID = :v_idtenant)
					AND D.TENANTID = :v_idtenant
					--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
					AND D.PROCESSINGUNITSEQ = 38280596832649217
					AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
					--ALM 20170309: A peticion de Alfonso filtramos por los depositos del S4
					AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S4'
					--ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
					AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
				--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
				INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
				INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
					AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
					AND D.EARNINGGROUPID = PERC.EARNINGGROUP
				INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
					AND AG.COD_INFORME = 112
					AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_PERC_AGENTES_REP. Percepciones. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_PERC_AGENTES_REP. Percepciones DDEE.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PERC_AGENTES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, PERCEPCION, IMP_PERCEPCION, MES_PERCEPCION, BALANCE, EARNINGCODEID, EARNINGGROUPID, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME)
				SELECT
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					'Comision DDEE' as PERCEPCION,
					SUM(CAR_LP.IMPORTE) AS IMP_PERCEPCION,
					MONTH(CAR_LP.COMPENSATIONDATE) AS MES_PERCEPCION,
					0 AS BALANCE,
					CAR_LP.EARNINGCODEID,CAR_LP.EARNINGGROUPID,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME
					AND PAD_INS.STARTDATE >= CAR_LP.COMPENSATIONDATE
					AND YEAR(PAD_INS.STARTDATE) = YEAR(CAR_LP.COMPENSATIONDATE)
					AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
					--JGE 20230816 Solamente tiene que salir los 01 Ocaso
					AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
					AND SUBSTR(CAR_LP.EARNINGGROUPID,4,2) = 'S4'
					AND SUBSTR(CAR_LP.EARNINGCODEID,1,3) <> '801'
					--ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
					AND CAR_LP.IMPORTE <> 0
				GROUP BY
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,CAR_LP.EARNINGCODEID,CAR_LP.EARNINGGROUPID, CAR_LP.COMPENSATIONDATE,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_PERC_AGENTES_REP. Percepciones DDEE. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_PERC_AGENTES_REP. Balances.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PERC_AGENTES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, PERCEPCION, IMP_PERCEPCION, MES_PERCEPCION, BALANCE, EARNINGCODEID, EARNINGGROUPID, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME)
				SELECT 
					PAD_INS.YEAR,PAD_INS.QUARTER, PAD_INS.PERIODO, PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					'Balance ' || (SELECT PER.NAME FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
						AND PER.PERIODSEQ = B.PERIODSEQ) ||' - ' || INITCAP(EC.DESCRIPTION) AS PERCEPCION,
					B.VALUE AS IMP_PERCEPCION,
					EXTRACT(MONTH FROM PAD_INS.STARTDATE) AS MES_PERCEPCION,                
					1 AS BALANCE,B.EARNINGCODEID,B.EARNINGGROUPID,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN TCMP.CS_BALANCE B ON PAD_INS.POSITIONSEQ = B.POSITIONSEQ
					AND PAD_INS.PARTICIPANTSEQ = B.PAYEESEQ
					AND B.POSTPIPELINERUNDATE < (SELECT PER.ENDDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
						AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
					AND B.POSTPIPELINERUNDATE > (SELECT PER.STARTDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
						AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
					AND B.TENANTID = :v_idtenant
					--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
					AND B.PROCESSINGUNITSEQ = 38280596832649217
					--AND D.VALUE <> 0
					AND SUBSTR(B.EARNINGGROUPID,7,2) = '01'
					--ALM 20170309: A peticion de Alfonso filtramos por los depositos del S4
					AND SUBSTR(B.EARNINGGROUPID,4,2) = 'S4'
					--ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
					AND SUBSTR(B.EARNINGCODEID,1,3) <> '801'
				--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
				INNER JOIN TCMP.CS_PLRUN PL ON B.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
					--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
					AND PL.TENANTID = :v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217
				--ALM 20170609: Unimos los balances con los pagos para filtrar balances que finalmente no se abonen en el periodo
				INNER JOIN TCMP.CS_BALANCEPAYMENTTRACE BPAY ON B.BALANCESEQ = BPAY.BALANCESEQ
					--ALM 20211025: Anadimos condicion para mejorar el rendimiento de la consulta
					AND BPAY.TENANTID = :v_idtenant AND BPAY.PROCESSINGUNITSEQ = 38280596832649217
					AND BPAY.TARGETPERIODSEQ = :i_PeriodSeq
				INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(B.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
					AND EC.TENANTID = :v_idtenant
					AND EC.REMOVEDATE = :v_eot;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_PERC_AGENTES_REP. Balances. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PERC_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_PERC_AGENTES_REP');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PERC_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado y Carga Tablas Intermedias Informe 1.11 Percepción Agentes.', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			call EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

		
		-- Fin informe 1.11 Percepcion Agentes
		END IF;

		-------------------------------------------------------------------------------------------------------------------------------------

		--DTB 20250526: TABLAS PARA INFORME 1.12 PRODUCCION AGENTES
		IF :i_lista_informes = 'PRAG' OR :i_lista_informes LIKE '%|PRAG|%' OR :i_lista_informes LIKE '%|PRAG' OR :i_lista_informes LIKE 'PRAG|%' 
			OR i_lista_informes = 'ALL' THEN

			--ALM 20170420: No tenemos en cuenta si el periodo esta cerrado para este informe porque no se entrega a agentes.
			--              Por lo tanto lo recargamos siempre con la ultima informacion.    
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe 1.12 Producción Agentes', i_log_count, i_id_proceso, 'info');


			-- DBT 20250526: Tabla INYC_PROD_AGENTES pasa a ser OUT_PROD_AGENTES_REP
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_PROD_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			DELETE FROM EXT.OUT_PROD_AGENTES_REP WHERE PERIODSEQ = :i_PeriodSeq;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_PROD_AGENTES_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_PROD_AGENTES_REP. Créditos Agente.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PROD_AGENTES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, NAME, VALUE, C_GN4, COMPANIA, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, ACCOUNTINGDATE, ST_GD2, EVENTO, PRODUCTO, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME, ID_TIPO_AGENTE, TIPO_AGENTE, PRIMA_NETA)
				SELECT 
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					C.NAME,C.VALUE,
					--ALM 20170510: Solo tomamos el valor de polizas corregidas para los creditos de Polizas'
					CASE WHEN C.NAME LIKE '%NumeroPolizas-998%' THEN C.GENERICNUMBER4 ELSE 0 END AS C_GN4,
					LEFT(ST.PRODUCTID, 2) AS COMPANIA,
					CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
					ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.EVENTO,ST.PRODUCTO,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME,
					--ALM 20180613: Anadimos la tipoligia del agente para el nuevo informe 1.12.1 Produccion Agentes por Meses
					PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
					--ALM 20210514: Por peticion de Alfonso, anadimos para los creditos de prima la Prima Neta de Recibo
					CASE WHEN C.NAME LIKE '%Prima-998%' THEN ST.GENERICNUMBER1 ELSE 0 END AS PRIMA_NETA
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
					AND PAD_INS.PERIODSEQ = C.PERIODSEQ
					AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
					----ALM 20160928: Filtramos para que los creditos 998-81 solo se tengan en cuenta con los productos de Hogar con polizas corregidas
					--AND (C.NAME LIKE '%998' OR (C.NAME LIKE '%998-81' AND C.GENERICATTRIBUTE2 LIKE '01501%' AND C.GENERICNUMBER4 <> 0))
					AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
					--ALM 20170407: Filtramos por los creditos de agente
					AND C.NAME LIKE 'DC-%-GEN-Agente-%'
				INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
				INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
					AND REG.COD_INFORME = 112.1
					AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
				INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
					AND AG.COD_INFORME = 112
					AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					--ALM 20170405: Filtramos por las tipologias de agentes
					--BRG 20260416 Caso correduría ZARASEGUR
					AND (AG.ID_TIPO_AGENTE < 50 OR AG.ID_TIPO_AGENTE = 306);
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_PROD_AGENTES_REP. Créditos Agente. Filas: '|| v_num_rows , i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_PROD_AGENTES_REP. Créditos Agente con Grupo.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PROD_AGENTES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, NAME, VALUE, C_GN4, COMPANIA, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, ACCOUNTINGDATE, ST_GD2, EVENTO, PRODUCTO, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME, ID_TIPO_AGENTE, TIPO_AGENTE, PRIMA_NETA)
				SELECT 
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					C.NAME,C.VALUE,
					--ALM 20170510: Solo tomamos el valor de polizas corregidas para los creditos de Polizas'
					CASE WHEN C.NAME LIKE '%NumeroPolizas-998%' THEN C.GENERICNUMBER4 ELSE 0 END AS C_GN4,
					LEFT(ST.PRODUCTID, 2) AS COMPANIA,
					CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
					ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.EVENTO,ST.PRODUCTO,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME,
					--ALM 20180613: Anadimos la tipoligia del agente para el nuevo informe 1.12.1 Produccion Agentes por Meses
					PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
					--ALM 20210514: Por peticion de Alfonso, anadimos para los creditos de prima la Prima Neta de Recibo
					CASE WHEN C.NAME LIKE '%Prima-998%' THEN ST.GENERICNUMBER1 ELSE 0 END AS PRIMA_NETA
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
					AND PAD_INS.PERIODSEQ = C.PERIODSEQ
					AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
					----ALM 20160928: Filtramos para que los creditos 998-81 solo se tengan en cuenta con los productos de Hogar con polizas corregidas
					--AND (C.NAME LIKE '%998' OR (C.NAME LIKE '%998-81' AND C.GENERICATTRIBUTE2 LIKE '01501%' AND C.GENERICNUMBER4 <> 0))
					AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
					--ALM 20170407: Filtramos por los creditos de agente
					AND (C.NAME LIKE 'DC-O-GEN-Inspector-%' OR C.NAME = 'DC-O-GEN-Agente-NumAsegurados')
				INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                --ALM 20170711: Filtramos las transacciones con el campo Excluido Comisiones (GA20) = 1
                --              No son propias del agente con grupo sino de algun agente de su grupo que ya esta de baja
                AND (ST.GENERICATTRIBUTE20 IS NULL OR ST.GENERICATTRIBUTE20 = 0)
				INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
					AND REG.COD_INFORME = 112.1
					AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
				INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
					AND AG.COD_INFORME = 112
					AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					--ALM 20170405: Filtramos por las tipologias de agentes
					AND AG.ID_TIPO_AGENTE >= 50
					--BRG 20260416 Caso correduría ZARASEGUR
					AND AG.ID_TIPO_AGENTE <> 306; 
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_PROD_AGENTES_REP. Créditos Agente con Grupo. Filas: '|| v_num_rows , i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PROD_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_PROD_AGENTES_REP');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PROD_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado y Carga Tablas Intermedias Informe 1.12 Producción Agentes.', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		
		-- Fin informe 1.12 Producción agentes
		END IF;
		
		--------------------------------------------------------------------------------------------------------------
	
		-- DTB 20250522: TABLAS PARA INFORME 1.13 PERCEPCIONES INSPECTORES
		IF :i_lista_informes = 'PEIN' OR :i_lista_informes LIKE '%|PEIN|%' OR :i_lista_informes LIKE '%|PEIN' OR :i_lista_informes LIKE 'PEIN|%' 
			OR :i_lista_informes = 'ALL' THEN

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe 1.13 Percepción Inspectores', i_log_count, i_id_proceso, 'info');


			-- DTB 20250522: Tabla INYC_PERC_INSPECTORES pasa a ser OUT_PERC_INSPECTORES_REP
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_PERC_INSPECTORES_REP.', i_log_count, i_id_proceso, 'debug');
			DELETE FROM EXT.OUT_PERC_INSPECTORES_REP WHERE PERIODSEQ = :i_PeriodSeq;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_PERC_INSPECTORES_REP. Percepciones. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_PERC_INSPECTORES_REP. Percepciones', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PERC_INSPECTORES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, PERCEPCION, IMP_PERCEPCION, MES_PERCEPCION, BALANCE, EARNINGCODEID, EARNINGGROUPID, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME)
				SELECT 
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					PERC.DESCRIPCION AS PERCEPCION,D.VALUE AS IMP_PERCEPCION,
					(SELECT EXTRACT(MONTH FROM PD.STARTDATE) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ AND PD.REMOVEDATE = :v_eot) AS MES_PERCEPCION,
					0 AS BALANCE,D.EARNINGCODEID,D.EARNINGGROUPID,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                    AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
                    AND D.PERIODSEQ IN (SELECT PD.PERIODSEQ FROM TCMP.CS_PERIOD PD WHERE PD.REMOVEDATE = :v_eot 
                                            AND RIGHT(PD.NAME, 4) = RIGHT(PAD_INS.PERIODO, 4)
                                            AND PD.STARTDATE <= PAD_INS.STARTDATE
                                            --Filtramos por el tipo de periodo para quedarnos solo los meses
                                            AND PD.PERIODTYPESEQ = 2814749767106561)
                    AND D.TENANTID = :v_idtenant
                    --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                    AND D.PROCESSINGUNITSEQ = 38280596832649217
                    --AND D.VALUE <> 0
                    AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
                    --ALM 20170220: Modificacion pedida por David para incluir unicamente Percepciones derivadas del S5,
                    --              debido a indicaciones del departamente de laboral
                    AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S5'
                    --ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
                    AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
                --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                    --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                    AND PL.TENANTID = :v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217
                INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
                    AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
                    AND D.EARNINGGROUPID = PERC.EARNINGGROUP
                INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
                    AND AG.COD_INFORME = 114
                    AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_PERC_INSPECTORES_REP. Percepciones. Filas: '|| v_num_rows , i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_PERC_INSPECTORES_REP. Balances', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PERC_INSPECTORES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, PERCEPCION, IMP_PERCEPCION, MES_PERCEPCION, BALANCE, EARNINGCODEID, EARNINGGROUPID, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME)
				SELECT
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					'Balance ' || (SELECT PER.NAME FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot
						AND PER.PERIODSEQ = B.PERIODSEQ) ||' - ' || INITCAP(EC.DESCRIPTION) AS PERCEPCION,
					B.VALUE AS IMP_PERCEPCION,
					EXTRACT(MONTH FROM PAD_INS.STARTDATE) AS MES_PERCEPCION,
					1 AS BALANCE,B.EARNINGCODEID,B.EARNINGGROUPID,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN TCMP.CS_BALANCE B ON PAD_INS.POSITIONSEQ = B.POSITIONSEQ
                    AND PAD_INS.PARTICIPANTSEQ = B.PAYEESEQ
                    AND B.POSTPIPELINERUNDATE < (SELECT PER.ENDDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot
                        AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
                    AND B.POSTPIPELINERUNDATE > (SELECT PER.STARTDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot
                        AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
                    AND B.TENANTID = :v_idtenant
                    --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                    AND B.PROCESSINGUNITSEQ = 38280596832649217
                    --AND D.VALUE <> 0
                    AND SUBSTR(B.EARNINGGROUPID,7,2) = '01'
                    --ALM 20170220: Modificacion pedida por David para incluir unicamente Percepciones derivadas del S5,
                    --              debido a indicaciones del departamente de laboral
                    AND SUBSTR(B.EARNINGGROUPID,4,2) = 'S5'
                    --ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
                    AND SUBSTR(B.EARNINGCODEID,1,3) <> '801'
                --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                INNER JOIN TCMP.CS_PLRUN PL ON B.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                    --ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
                    AND PL.TENANTID = :v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217
                --ALM 20170609: Unimos los balances con los pagos para filtrar balances que finalmente no se abonen en el periodo
                INNER JOIN TCMP.CS_BALANCEPAYMENTTRACE BPAY ON B.BALANCESEQ = BPAY.BALANCESEQ
                    --ALM 20211025: Anadimos condicion para mejorar el rendimiento de la consulta
                    AND BPAY.TENANTID = :v_idtenant AND BPAY.PROCESSINGUNITSEQ = 38280596832649217
                    AND BPAY.TARGETPERIODSEQ = :i_PeriodSeq
                --ATV 20250108 Comentamos la linea por problemas de rendicimiento
                INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(B.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                    AND EC.TENANTID = :v_idtenant AND EC.REMOVEDATE = :v_eot;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_PERC_INSPECTORES_REP. Balances. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PERC_INSPECTORES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_PERC_INSPECTORES_REP');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PERC_INSPECTORES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado y Carga Tablas Intermedias Informe 1.13 Percepción Inspectores', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

		-- Fin informe 1.13 Percepciones Inspectores
		END IF;
		
		-------------------------------------------------------------------------------------------------------------------------------------
		--DTB 20250526: TABLAS PARA INFORME 1.14 PRODUCCION INSPECTORES
		IF :i_lista_informes = 'PRIN' OR :i_lista_informes LIKE '%|PRIN|%' OR :i_lista_informes LIKE '%|PRIN' OR :i_lista_informes LIKE 'PRIN|%' 
			OR i_lista_informes = 'ALL' THEN

			--ALM 20170420: No tenemos en cuenta si el periodo esta cerrado para este informe porque no se entrega a agentes.
			--              Por lo tanto lo recargamos siempre con la ultima informacion.    
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe 1.14 Producción Inspectores', i_log_count, i_id_proceso, 'info');


			-- DTB 20250526: Tabla INYC_PROD_INSPECTORES pasa a ser OUT_PROD_INSPECTORES_REP
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_PROD_INSPECTORES_REP.', i_log_count, i_id_proceso, 'debug');
			DELETE FROM EXT.OUT_PROD_INSPECTORES_REP WHERE PERIODSEQ = :i_PeriodSeq;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_PROD_INSPECTORES_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_PROD_INSPECTORES_REP.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_PROD_INSPECTORES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, NAME, VALUE, C_GN5, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, ACCOUNTINGDATE, ST_GD2, EVENTO, PRODUCTO, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME, POLIZ_CORR, PRIMA_NETA, C_GA4)
				SELECT 
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					C.NAME,C.VALUE,
					--ALM 20170607: Solo tomamos el valor de la prima neta para los creditos de Primas
					CASE WHEN C.NAME LIKE '%PrimaCorregida-998%' THEN C.GENERICNUMBER5 ELSE 0 END AS C_GN5,
					CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
					ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.EVENTO,ST.PRODUCTO,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME,
					--ALM 20180119: Anadimos las polizas corregidas
					CASE WHEN C.NAME LIKE '%NumeroPolizas-998%' THEN C.GENERICNUMBER4 ELSE 0 END AS POLIZ_CORR,
					--ALM 20210514: Por peticion de Alfonso, anadimos para los creditos de prima la Prima Neta de Recibo
					CASE WHEN C.NAME LIKE '%PrimaCorregida-998%' THEN ST.GENERICNUMBER1 ELSE 0 END AS PRIMA_NETA,
					--ATV 20230428 Anyadimos nuevo campo de agente para sacar nuevo informe por detalle de agente
					C.GENERICATTRIBUTE4 AS C_GA4
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = C.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
						--ALM 20161004: Filtramos los creditos que tengan el valor y la prima neta a 0, sino no coinciden con las medidas de Prima
						--ALM 20180212: Filtramos por los creditos que cuentan polizas corregidas
						AND (C.VALUE <> 0 OR C.GENERICNUMBER5 <> 0 OR (C.GENERICNUMBER4 <> 0 AND C.NAME LIKE '%Polizas%'))
						--ALM 20161004: Filtramos para no tener en cuenta los creditos directos que pertenecen a inspectores que cuando emitieron la poliza eran agentes
						AND (C.NAME LIKE 'IC-%' OR C.GENERICBOOLEAN3 = 0)
				INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
				INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
						AND REG.COD_INFORME = 114.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
				INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
					AND AG.COD_INFORME = 114
					AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
				WHERE ((SELECT MAX(X.POSITIONGENERICNUMBER2) FROM :TBL_AGENTES_MES X WHERE X.PERIODSEQ = PAD_INS.PERIODSEQ
								--ALM 20170628: Por peticion de David anadimos los tipos 82
								AND X.PARTICIPANTSEQ = PAD_INS.PARTICIPANTSEQ AND X.POSITIONSEQ = PAD_INS.POSITIONSEQ) IN (82,61)
							OR ST.EVENTO <> 'Recuperaciones Ramos Tradicionales');
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_PROD_INSPECTORES_REP. Filas: '|| v_num_rows , i_log_count, i_id_proceso, 'debug');

			--Actualizacion fechas webi tabla OUT_PROD_INSPECTORES_REP
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PROD_INSPECTORES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_PROD_INSPECTORES_REP');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PROD_INSPECTORES_REP.', i_log_count, i_id_proceso, 'debug');
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado y Carga Tablas Intermedias Informe 1.14 Producción Inspectores', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		
		-- Fin informe 1.14 Produccion Inspectores
		END IF;
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250526: TABLAS PARA INFORME 1.16 AGENTES ACTIVOS (OMESCU)
		IF :i_lista_informes = 'OMESCU' OR :i_lista_informes LIKE '%|OMESCU|%' OR :i_lista_informes LIKE '%|OMESCU' OR :i_lista_informes LIKE 'OMESCU|%' 
			OR :i_lista_informes = 'ALL' THEN

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe 1.16 Agentes Activos (OMESCU)', i_log_count, i_id_proceso, 'info');


			-- BRG 20250526: Tabla INYC_INSP_ACTIVOS pasa a ser OUT_INSP_ACTIVOS_REP
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_INSP_ACTIVOS_REP.', i_log_count, i_id_proceso, 'debug');
			DELETE FROM EXT.OUT_INSP_ACTIVOS_REP WHERE PERIODSEQ = :i_PeriodSeq;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_INSP_ACTIVOS_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_INSP_ACTIVOS_REP.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_INSP_ACTIVOS_REP (COD_REGIONAL, REGIONAL, COD_SUCURSAL, SUCURSAL, COD_OFICINA, OFICINA, POS_PRIN, NOMBRE, NIF, CUADRO_INSP, ID_TIPO_AGENTE, TIPO_AGENTE, NUM_POL, NUM_PRIMA_NETA, NUM_PRIMA_CORR, OBJ_POL, OBJ_PRIMA, FEC_ALTA_POS, FEC_ALTA_CAT, PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, NUM_POL_CORR) 
				SELECT DISTINCT
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_REG.POSITIONNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_SUC.POSITIONNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) 
							THEN PAD_OF.POSITIONNAME
						ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_REGIONAL,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_REG.LASTNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_SUC.LASTNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) 
							THEN PAD_OF.LASTNAME
						ELSE PAD_PTO_VENTA.LASTNAME END AS REGIONAL,   
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_SUC.POSITIONNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_OF.POSITIONNAME
						ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_SUCURSAL,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_SUC.LASTNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_OF.LASTNAME
						ELSE PAD_PTO_VENTA.LASTNAME END AS SUCURSAL,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_OF.POSITIONNAME  
						ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
						ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
					PAD_INS.POS_PRIN,
					IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
					PAD_INS.NIF,
					PAD_INS.CUADRO_INSP_OCASO AS CUADRO_INSP,
					PAD_INS.ID_TIPO_AGENTE,
					PAD_INS.TIPO_AGENTE,
					SUM(CASE WHEN M.NAME = 'SM-O-GEN-Inspector-NumeroPolizas-998-TotalMes'
						THEN M.VALUE ELSE 0 END) AS NUM_POL,
					SUM(CASE WHEN M.NAME = 'SM-O-GEN-Inspector-Prima-998-TotalMes'
						THEN M.VALUE ELSE 0 END) AS NUM_PRIMA_NETA,
					SUM(CASE WHEN M.NAME = 'SM-O-GEN-Inspector-PrimaCorregida-998-TotalMes'
						THEN M.VALUE ELSE 0 END) AS NUM_PRIMA_CORR,
					--ALM 20170622: Se modifica las medidas para que sea Callidus el que calcule el objetivo que tiene cada inspector
					SUM(CASE WHEN M.NAME = 'SM-O-RPP-Inspector-ObjetivoAnual-NumPolizas-998'
						THEN M.VALUE ELSE 0 END) AS OBJ_POL,
					SUM(CASE WHEN M.NAME = 'SM-O-RPP-Inspector-ObjetivoUnicoAnual-PrimaCorregida'
						THEN M.VALUE ELSE 0 END) AS OBJ_PRIMA,
					--POS_INS.FEC_ALTA_POS as FEC_ALTA_POS,
					(SELECT MIN(POS.GENERICDATE1) FROM TCMP.CS_POSITION POS 
						WHERE POS.REMOVEDATE = :v_eot
							AND POS.GENERICNUMBER2 >= 50 
							AND POS.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE
							AND POS.PAYEESEQ = PAD_INS.PARTICIPANTSEQ
					) AS FEC_ALTA_POS,
					--ALM 20170512: Nos quedamos con la fecha final de la version anterior al ultimo cambio de cuadro 
					--              o, si es nula, con la fecha inicial de la primera version en la que tiene tipologia de agente con grupo/inspector/responsable  
					(SELECT IFNULL(MAX(POS_ANT.EFFECTIVEENDDATE),MIN(POS_ACT.EFFECTIVESTARTDATE)) 
						FROM TCMP.CS_POSITION POS_ACT
						--ALM 20170510: Tenemos que tener en cuenta cualquier cambio de tipologia no solo el paso de agente a inspector
						LEFT JOIN TCMP.CS_POSITION POS_ANT ON POS_ACT.PAYEESEQ = POS_ANT.PAYEESEQ
							--ALM 20170519: Tenemos en cuenta todas las versiones anteriores porque puede que venga de una tipologia que no sea inspector
							AND POS_ACT.EFFECTIVESTARTDATE >= POS_ANT.EFFECTIVEENDDATE
							AND (REPLACE(REPLACE(REPLACE(POS_ACT.GENERICATTRIBUTE5, 'A', 'P'), 'D', 'P'), 'N', 'P') <> REPLACE(REPLACE(REPLACE(POS_ANT.GENERICATTRIBUTE5, 'A', 'P'), 'D', 'P'), 'N', 'P') OR POS_ANT.GENERICATTRIBUTE5 IS NULL)
							AND POS_ANT.REMOVEDATE = :v_eot
						WHERE POS_ACT.REMOVEDATE = :v_eot
							--ALM 20170320: Se tiene que tener en cuenta la fecha de la version de cuando ha sido TTL SIN PLAN.
							--ALM 20170512: Filtramos las versiones de las posiciones con tipologia de agente con grupo/inspector/responsable
							AND POS_ACT.GENERICNUMBER2 >= 50
							AND POS_ACT.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE
							AND POS_ACT.PAYEESEQ = PAD_INS.PARTICIPANTSEQ
					) AS FEC_ALTA_CAT,
					PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
					PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
					--ALM 20180130: Anadimos las polizas corregidas por peticion de Alfonso.
					SUM(CASE WHEN M.NAME = 'SM-O-GEN-Inspector-NumeroPolizasCorregidas-998-TotalMes'
						THEN M.VALUE ELSE 0 END) AS NUM_POL_CORR
				FROM :TBL_AGENTES_PRIN_MES PAD_INS  
				INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
					AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
					AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
				INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
					AND REG.COD_INFORME = 116.1
					AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
				INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
					AND AG.COD_INFORME = 116
					AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
				LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
					AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
				LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
					AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
				LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
					AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
				LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
					AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
				GROUP BY
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_REG.POSITIONNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_SUC.POSITIONNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) 
							THEN PAD_OF.POSITIONNAME
						ELSE PAD_PTO_VENTA.POSITIONNAME END,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_REG.LASTNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_SUC.LASTNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) 
							THEN PAD_OF.LASTNAME
						ELSE PAD_PTO_VENTA.LASTNAME END,   
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_SUC.POSITIONNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_OF.POSITIONNAME
						ELSE PAD_PTO_VENTA.POSITIONNAME END,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_SUC.LASTNAME
						WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) 
							THEN PAD_OF.LASTNAME
						ELSE PAD_PTO_VENTA.LASTNAME END,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) 
							THEN PAD_OF.POSITIONNAME  
						ELSE PAD_PTO_VENTA.POSITIONNAME END,
					CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
						ELSE PAD_PTO_VENTA.LASTNAME END,
					PAD_INS.POS_PRIN,
					IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
					PAD_INS.NIF,
					PAD_INS.CUADRO_INSP_OCASO,
					PAD_INS.ID_TIPO_AGENTE,
					PAD_INS.TIPO_AGENTE,
					PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
					PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.STARTDATE;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_INSP_ACTIVOS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_INSP_ACTIVOS_REP.', i_log_count, i_id_proceso, 'debug');
			CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_INSP_ACTIVOS_REP');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_INSP_ACTIVOS_REP.', i_log_count, i_id_proceso, 'debug');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado y Carga Tablas Intermedias Informe 1.16 Agentes Activos (OMESCU)', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

		-- Fin informe 1.16 Agentes Activos (OMESCU)
		END IF;
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250526: TABLAS PARA INFORME 1.26 Rappel Producción Agentes
		IF :i_lista_informes = 'RPA' OR :i_lista_informes LIKE '%|RPA|%' OR :i_lista_informes LIKE '%|RPA' OR :i_lista_informes LIKE 'RPA|%' 
			OR :i_lista_informes = 'ALL' THEN
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe 1.26 Rappel Producción Agentes', i_log_count, i_id_proceso, 'info');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas RPA', i_log_count, i_id_proceso, 'info');
			--ALM 20171113: Comprobamos si el periodo esta posteado y si no lo esta cargamos las tablas de cierre
			IF v_periodo_posteado = 0 THEN
				-- BRG 20250526: Tabla INYC_RPA_RESUMEN pasa a ser OUT_RPA_RESUMEN_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RPA_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RPA_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RPA_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, M_GN1, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, GA1_MEDIDA)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,  
						M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,M.GENERICNUMBER1 AS M_GN1,
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF,
						--ALM 20220420: Nuevo campo para coger la bolsa de financiacion marcada para el calculo.
						M.GENERICATTRIBUTE1 AS GA1_MEDIDA
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 6.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 6
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					WHERE PAD_INS.BOUSERID IN (
						SELECT DISTINCT X.BOUSERID 
						FROM :TBL_AGENTES_MES X 
						INNER JOIN :TBL_CREDITOS_MES Y ON X.PERIODSEQ = Y.PERIODSEQ
							AND X.POSITIONSEQ = Y.POSITIONSEQ
							AND X.PARTICIPANTSEQ = Y.PAYEESEQ
						INNER JOIN EXT.CONF_REGLAS_REP Z ON Y.NAME = Z.REGLA
							AND Z.COD_INFORME = 6.2
						WHERE X.BOUSERID = PAD_INS.BOUSERID
							AND Z.F_INICIO <= PAD_INS.STARTDATE AND  Z.F_FIN > PAD_INS.STARTDATE
							AND Y.VALUE <> 0);
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RPA_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RPA_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');

				-- BRG 20260219: Tabla INYC_RPA_DETALLE pasa a ser OUT_RPA_DETALLE_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RPA_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RPA_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RPA_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, NAME, VALUE, C_GN4, C_GB1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GD3, ST_GN1, ST_GN2, ST_GN3, EVENTO, TIPO_CREDITO, PRODUCTO, POSITIONNAME_AG, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, SALESTRANSACTIONSEQ, NIF)
					SELECT
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,             
                        C.NAME,
                        --ALM 20161006: Para los creditos de polizas de recuperadas y renovaciones incluimos en el valor de la prima
                        CASE WHEN C.NAME LIKE 'DC-O-GEN-Agente-NumeroPolizas-998-Re%' THEN C.GENERICNUMBER5 ELSE C.VALUE END AS VALUE,
                        C.GENERICNUMBER4 AS C_GN4,
                        C.GENERICBOOLEAN1 AS C_GB1,
                        ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE, 
                        ST.EVENTO,
                        CT.DESCRIPTION AS TIPO_CREDITO,
                        ST.PRODUCTO,
                        PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
                        PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
                        PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),PAD_INS.NIF
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        ----ALM 20161006: Filtramos para que los creditos 998-81 solo se tengan en cuenta con los productos de Hogar con polizas corregidas(Renovaciones)
                        --AND (C.NAME LIKE '%998' OR (C.NAME LIKE '%998-81' AND C.GENERICATTRIBUTE2 LIKE '01501%' AND C.GENERICNUMBER4 <> 0))
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                    INNER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
                        AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.COD_INFORME = 6.2
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                    LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
                        AND CT.REMOVEDATE = v_eot
                        AND CT.TENANTID = :v_idtenant
                    INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
                        AND AG.COD_INFORME = 6
                        AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RPA_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RPA_DETALLE_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					-- BRG 20250526: Tabla INYC_LC_RPA_RESUMEN pasa a ser OUT_LC_RPA_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_RPA_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_RPA_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_RPA_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, M_GN1, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, GA1_MEDIDA)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,  
							M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,M.GENERICNUMBER1 AS M_GN1,
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF,
							--ALM 20220420: Nuevo campo para coger la bolsa de financiacion marcada para el calculo.
							M.GENERICATTRIBUTE1 AS GA1_MEDIDA
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 6.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 6
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						WHERE PAD_INS.BOUSERID IN (
							SELECT DISTINCT X.BOUSERID 
							FROM :TBL_AGENTES_MES X 
							INNER JOIN :TBL_CREDITOS_MES Y ON X.PERIODSEQ = Y.PERIODSEQ
								AND X.POSITIONSEQ = Y.POSITIONSEQ
								AND X.PARTICIPANTSEQ = Y.PAYEESEQ
							INNER JOIN EXT.CONF_REGLAS_REP Z ON Y.NAME = Z.REGLA
								AND Z.COD_INFORME = 6.2
							WHERE X.BOUSERID = PAD_INS.BOUSERID
								AND Z.F_INICIO <= PAD_INS.STARTDATE AND  Z.F_FIN > PAD_INS.STARTDATE
								AND Y.VALUE <> 0);
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_RPA_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_RPA_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');

					-- BRG 20260219: Tabla INYC_LC_RPA_DETALLE pasa a ser OUT_LC_RPA_DETALLE_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_RPA_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_RPA_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_RPA_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, NAME, VALUE, C_GN4, C_GB1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GD3, ST_GN1, ST_GN2, ST_GN3, EVENTO, TIPO_CREDITO, PRODUCTO, POSITIONNAME_AG, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, SALESTRANSACTIONSEQ, NIF)
						SELECT
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,             
                            C.NAME,
                            --ALM 20161006: Para los creditos de polizas de recuperadas y renovaciones incluimos en el valor de la prima
                            CASE WHEN C.NAME LIKE 'DC-O-GEN-Agente-NumeroPolizas-998-Re%' THEN C.GENERICNUMBER5 ELSE C.VALUE END AS VALUE,
                            C.GENERICNUMBER4 AS C_GN4,
                            C.GENERICBOOLEAN1 AS C_GB1,
                            ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE, 
                            ST.EVENTO,
                            CT.DESCRIPTION AS TIPO_CREDITO,
                            ST.PRODUCTO,
                            PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
                            PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
                            PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),PAD_INS.NIF
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                            ----ALM 20161006: Filtramos para que los creditos 998-81 solo se tengan en cuenta con los productos de Hogar con polizas corregidas(Renovaciones)
                            --AND (C.NAME LIKE '%998' OR (C.NAME LIKE '%998-81' AND C.GENERICATTRIBUTE2 LIKE '01501%' AND C.GENERICNUMBER4 <> 0))
                            AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                        INNER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
                            AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                            AND REG.COD_INFORME = 6.2
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
                            AND CT.REMOVEDATE = v_eot
                            AND CT.TENANTID = :v_idtenant
                        INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
                            AND AG.COD_INFORME = 6
                            AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE 
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_RPA_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_RPA_DETALLE_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					-- BRG 20250526: Tabla INYC_BAL_RPA_RESUMEN pasa a ser OUT_BAL_RPA_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RPA_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RPA_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RPA_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, M_GN1, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, GA1_MEDIDA)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,  
							M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,M.GENERICNUMBER1 AS M_GN1,
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF,
							--ALM 20220420: Nuevo campo para coger la bolsa de financiacion marcada para el calculo.
							M.GENERICATTRIBUTE1 AS GA1_MEDIDA
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							--AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 6.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 6
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						WHERE PAD_INS.BOUSERID IN (
							SELECT DISTINCT X.BOUSERID 
							FROM :TBL_AGENTES_MES X 
							INNER JOIN :TBL_CREDITOS_MES Y ON X.PERIODSEQ = Y.PERIODSEQ
								AND X.POSITIONSEQ = Y.POSITIONSEQ
								AND X.PARTICIPANTSEQ = Y.PAYEESEQ
							INNER JOIN EXT.CONF_REGLAS_REP Z ON Y.NAME = Z.REGLA
								AND Z.COD_INFORME = 6.2
							WHERE X.BOUSERID = PAD_INS.BOUSERID
								AND Z.F_INICIO <= PAD_INS.STARTDATE AND  Z.F_FIN > PAD_INS.STARTDATE
								AND Y.VALUE <> 0);
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RPA_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RPA_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');

					-- BRG 20260219: Tabla INYC_BAL_RPA_DETALLE pasa a ser OUT_BAL_RPA_DETALLE_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RPA_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RPA_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');


					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RPA_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, NAME, VALUE, C_GN4, C_GB1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GD3, ST_GN1, ST_GN2, ST_GN3, EVENTO, TIPO_CREDITO, PRODUCTO, POSITIONNAME_AG, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, SALESTRANSACTIONSEQ, NIF)
						SELECT
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,             
                            C.NAME,
                            --ALM 20161006: Para los creditos de polizas de recuperadas y renovaciones incluimos en el valor de la prima
                            CASE WHEN C.NAME LIKE 'DC-O-GEN-Agente-NumeroPolizas-998-Re%' THEN C.GENERICNUMBER5 ELSE C.VALUE END AS VALUE,
                            C.GENERICNUMBER4 AS C_GN4,
                            C.GENERICBOOLEAN1 AS C_GB1,
                            ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE, 
                            ST.EVENTO,
                            CT.DESCRIPTION AS TIPO_CREDITO,
                            ST.PRODUCTO,
                            PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
                            PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
                            PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),PAD_INS.NIF
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                            ----ALM 20161006: Filtramos para que los creditos 998-81 solo se tengan en cuenta con los productos de Hogar con polizas corregidas(Renovaciones)
                            --AND (C.NAME LIKE '%998' OR (C.NAME LIKE '%998-81' AND C.GENERICATTRIBUTE2 LIKE '01501%' AND C.GENERICNUMBER4 <> 0))
                            AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                        INNER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
                            AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                            AND REG.COD_INFORME = 6.2
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
                            AND CT.REMOVEDATE = v_eot
                            AND CT.TENANTID = :v_idtenant
                        INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
                            AND AG.COD_INFORME = 6
                            AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RPA_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RPA_DETALLE_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPA_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				END IF;
			END IF;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas RPA', i_log_count, i_id_proceso, 'info');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas ASI', i_log_count, i_id_proceso, 'info');
			--ALM 20171113: Comprobamos si el periodo esta posteado y si no lo esta cargamos las tablas de cierre
			IF v_periodo_posteado = 0 THEN
				-- BRG 20250526: Tabla INYC_ASI_RESUMEN pasa a ser OUT_ASI_RESUMEN_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_ASI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_ASI_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_ASI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, ESCALADO, GN1_MEDIDA, GA1_MEDIDA)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
						M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						PAD_INS.NIF,PAD_INS.ESCALADO,
						--ALM 20220324: Nuevo campo para coger el objetivo marcado para el calculo.
						M.GENERICNUMBER1 AS GN1_MEDIDA,
						--ALM 20220420: Nuevo campo para coger la bolsa de financiacion marcada para el calculo.
						M.GENERICATTRIBUTE1 AS GA1_MEDIDA
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						--AND M.VALUE <> 0
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 19.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 19
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_ASI_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_ASI_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					-- BRG 20250526: Tabla INYC_LC_ASI_RESUMEN pasa a ser OUT_LC_ASI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_ASI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_ASI_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_ASI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, ESCALADO, GN1_MEDIDA, GA1_MEDIDA)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
							PAD_INS.NIF,PAD_INS.ESCALADO,
							--ALM 20220324: Nuevo campo para coger el objetivo marcado para el calculo.
							M.GENERICNUMBER1 AS GN1_MEDIDA,
							--ALM 20220420: Nuevo campo para coger la bolsa de financiacion marcada para el calculo.
							M.GENERICATTRIBUTE1 AS GA1_MEDIDA
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							--AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 19.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 19
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_ASI_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_ASI_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					-- BRG 20250526: Tabla INYC_BAL_ASI_RESUMEN pasa a ser OUT_BAL_ASI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_ASI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_ASI_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_ASI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, ESCALADO, GN1_MEDIDA, GA1_MEDIDA)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
							PAD_INS.NIF,PAD_INS.ESCALADO,
							--ALM 20220324: Nuevo campo para coger el objetivo marcado para el calculo.
							M.GENERICNUMBER1 AS GN1_MEDIDA,
							--ALM 20220420: Nuevo campo para coger la bolsa de financiacion marcada para el calculo.
							M.GENERICATTRIBUTE1 AS GA1_MEDIDA
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							--AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 19.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 19
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_ASI_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_ASI_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_ASI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				END IF;
			END IF;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas ASI', i_log_count, i_id_proceso, 'info');

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado y Carga Tablas Intermedias Informe 1.26 Rappel Producción Agentes', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
	
		-- Fin informe 1.26 Rappel Producción Agentes
		END IF;
		
		---------------------------------------------------------------------------------------------------------------------------------------
		--DTB 20250527: TABLAS PARA INFORME S4 Detalle Pólizas
		IF :i_lista_informes = 'S4' OR :i_lista_informes LIKE '%|S4|%' OR :i_lista_informes LIKE '%|S4' OR :i_lista_informes LIKE 'S4|%' 
			OR i_lista_informes = 'S4_E' OR i_lista_informes LIKE '%|S4_E|%' OR i_lista_informes LIKE '%|S4_E' OR i_lista_informes LIKE 'S4_E|%' 
			OR :i_lista_informes = 'ALL' THEN
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe S4 Detalle Pólizas', i_log_count, i_id_proceso, 'info');


			--ALM 20170420: Comprobamos si el periodo esta cerrado y si no lo esta cargamos las tablas de cierre
			--ALM 20171113: Comprobamos si el periodo esta posteado y si no lo esta cargamos las tablas de cierre
			IF v_periodo_posteado = 0 THEN
				--OCASO
				--DTB 20250526: Tabla INYC_S4_POLIZAS pasa a ser OUT_S4_POLIZAS_REP
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_S4_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_S4_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_POLIZAS_REP. Creditos (Nueva Produccion)', i_log_count, i_id_proceso, 'debug');            
				INSERT INTO EXT.OUT_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
						ST.CHANNEL AS COMPANIA,
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
						--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
						CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' 
								-- AND ST.EVENTTYPESEQ = 16607023625928867
								-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
								AND ST.EVENTTYPEID = '71'
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) 
							ELSE 0 END AS POLIZ_NP,
						CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
						-- ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
						-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997)
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
								THEN 0
							ELSE ST.VALUE END AS PRIMA_COMISIONABLE,
						ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
						ST.GENERICNUMBER1 AS PRIMA_NETA,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME
						END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME
						END AS REGIONAL,
						--ALM 20180119: Anadimos campos a incluir para el PAC 2018
						PAD_INS.SUPERRAPEL,
						C.GENERICNUMBER1 AS ASEGURADOS,
						--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
						ST.GENERICATTRIBUTE7 AS COD_RECIBO
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = C.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
						--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
						AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0) 
						AND C.NAME LIKE 'DC-O-COM-NuevaProduccion%'
					INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
						AND REG.COD_INFORME = 100.2
					LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_POLIZAS_REP. Creditos (Nueva Produccion). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_POLIZAS_REP. Creditos (Asistencias)', i_log_count, i_id_proceso, 'debug');            
				INSERT INTO EXT.OUT_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
						ST.CHANNEL AS COMPANIA,
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						--PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
						--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
						--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
						-- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID = '71'
							AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
						CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
						--ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1.  
						-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997)
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
								THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
						ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
						ST.GENERICNUMBER1 AS PRIMA_NETA,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME 
						END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME
						END AS REGIONAL,
						--ALM 20180119: Anadimos campos a incluir para el PAC 2018
						PAD_INS.SUPERRAPEL,
						C.GENERICNUMBER1 AS ASEGURADOS,
						--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
						ST.GENERICATTRIBUTE7 AS COD_RECIBO
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = C.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
						--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
						AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
						--ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
						--AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
						AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
						AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
						--ALM 20170329: Filtramos para quedarnos con creditos de Ocaso igual que hacemos en Eterna
						AND C.GENERICATTRIBUTE9 = '01'
					INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						AND REG.COD_INFORME = 100.2
					--ALM 20160907: Para las Asistencias filtramos para agentes segun su PLAN
					INNER JOIN :TBL_AGENTES_MES PAD_AG ON PAD_INS.PARTICIPANTSEQ = PAD_AG.PARTICIPANTSEQ 
						AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = PAD_AG.POSITIONSEQ
						AND PAD_AG.PLANNAME LIKE 'Plan_O_%'
					LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_POLIZAS_REP. Creditos (Resto Creditos)', i_log_count, i_id_proceso, 'debug');      
				INSERT INTO EXT.OUT_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
						ST.CHANNEL AS COMPANIA,
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						--PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
						--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
						--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP, 
						-- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID = '71' 
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
						CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
						--ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1.  
						-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997)
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
								THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
						ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
						ST.GENERICNUMBER1 AS PRIMA_NETA,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME
						END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME
						END AS REGIONAL,
						--ALM 20180119: Anadimos campos a incluir para el PAC 2018
						PAD_INS.SUPERRAPEL,
						--ALM 20220530: Los creditos de las Gestiones traen en el GN1 el objetivo por lo que ponemos este valor a 0.
						--C.GENERICNUMBER1 AS ASEGURADOS
						(CASE WHEN C.NAME = 'DC-O-COM-GestionExplotacion' THEN 0 ELSE C.GENERICNUMBER1 END) AS ASEGURADOS,
						--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
						ST.GENERICATTRIBUTE7 AS COD_RECIBO
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = C.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
						--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o num de polizas corregidas distinto de 0 
						AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
						--ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
						--AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
						AND C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
						AND C.NAME NOT LIKE 'DC-O-COM-NuevaProduccion%'
					INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
					INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
						AND REG.COD_INFORME = 100.2
					LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;              
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_POLIZAS_REP. Creditos (Resto Creditos). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**', i_log_count, i_id_proceso, 'debug');        
				INSERT INTO EXT.OUT_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)        
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
						SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
						--ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
						SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
						'999999900000000' AS POLIZA,
						CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
							THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
						D.DEPOSITDATE AS FEC_CARGO,
						0 AS PRIMA_COMISIONABLE,
						--ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
						--              depende del concepto de pago.
						CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
							WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
							--ALM 20180420: Anadimos los pagos comerciales de concepto 107 a las recuperaciones por peticion de Miguel Angel Arrabe
							WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('107') THEN 'Recuperacion'
							WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
							--ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
							WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
							WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
							ELSE 'Division Comercial'
						END AS EVENTO,
						PROD.GENERICATTRIBUTE5 AS PRODUCTO,
						'' AS FEC_VTO_REC,0 AS PRIMA_NETA,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						--ALM 20180119: Anadimos campos a incluir para el PAC 2018
						PAD_INS.SUPERRAPEL,
						0 AS ASEGURADOS,
						--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
						'' AS COD_RECIBO
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = D.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
						AND D.TENANTID = :v_idtenant
						--ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
						AND D.EARNINGGROUPID LIKE '%S4%'
						--ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
						--              Correo de Afonso el 06/09/2016
						AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
					--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
					INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
					--ALM 20180822: Nos quedamos con las 15 primeras letras del nombre del deposito para tener en cuenta los depositos antiguos de Abril y Mayo
					--              de 2016 que pueden venir con diferentes nombre (D-O-Pagos-Fijos-x)    
					INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,15) = REG.REGLA
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						AND REG.COD_INFORME = 100.2 
					--ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
					--              Necesario para Pagos Comerciales de Abril y Mayo 2016
					INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = (CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
							THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END)
						AND CL.REMOVEDATE = :v_eot  
						AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
						AND CL.TENANTID = :v_idtenant
					LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
						AND PROD.REMOVEDATE = :v_eot  
						AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
						AND PROD.TENANTID = :v_idtenant
					LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				--LLS 20220124: Caso especifico del deposito D-O-GestionExplotacion-PagoInicial (regla D-O-COM-GestionExplotacion-PagoInicial) de Enero 2022
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_POLIZAS_REP.  Pago Inicial Gestion Explotacion', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)      
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
						SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
						SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
						'999999900000000' AS POLIZA,
						CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
							THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
						D.DEPOSITDATE AS FEC_CARGO,
						0 AS PRIMA_COMISIONABLE,
						'Gestiones referencias explotacion' AS EVENTO,
						PROD.GENERICATTRIBUTE5 AS PRODUCTO,
						'' AS FEC_VTO_REC,0 AS PRIMA_NETA,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						PAD_INS.SUPERRAPEL,
						0 AS ASEGURADOS,
						--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
						'' AS COD_RECIBO
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = D.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
						AND D.TENANTID = :v_idtenant
						AND D.EARNINGGROUPID LIKE '%S4%'
						AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
						AND D.NAME = 'D-O-GestionExplotacion-PagoInicial'
					INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
					INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						AND REG.COD_INFORME = 100.2 
					LEFT JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = (CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
							THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END)
						AND CL.REMOVEDATE = :v_eot  
						AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
						AND CL.TENANTID = :v_idtenant
					LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
						AND PROD.REMOVEDATE = :v_eot  
						AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
						AND PROD.TENANTID = :v_idtenant
					LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_POLIZAS_REP. Agentes Derechos Económicos', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)        
					SELECT 
						PAD_INS.PARTICIPANTSEQ, 
						PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
						PAD_INS.BOUSERID,
						PAD_INS.POSITIONNAME,
						PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_RRGG_OCASO,
						PAD_INS.CUADRO_RRTT_OCASO,
						SUBSTR (CAR_LP.ORDERID,1,2) AS COMPANIA, --order id 2 primeros digitos
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						'CARTERA_LP' AS NAME, --C.NAME,
						CAR_LP.IMPORTE AS VALUE, --C.VALUE,
						0 AS POLIZ_CORR,
						0 AS POLIZ_NP,
						CAR_LP.ORDERID || CAST(CAR_LP.SUBLINENUMBER AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
						CAR_LP.POLIZA, --ST.GENERICATTRIBUTE1 AS POLIZA,
						CAR_LP.PRODUCTID,
						CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
						CAR_LP.VALUE AS PRIMA_COMISIONABLE,
						CAR_LP.EVENTO,--ST.EVENTO,
						CAR_LP.PRODUCTO,--ST.PRODUCTO,
						CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
						CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
						PAD_INS.ID_TIPO_AGENTE,
						PAD_INS.TIPO_AGENTE,
						CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						PAD_INS.SUPERRAPEL,
						0 AS ASEGURADOS,
						--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
						'' AS COD_RECIBO
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
						--LLS 20220125: Filtro para tener solo Ocaso
						AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
						--ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
						--ATV 20250205 Anyadimos el estado N
						--BRG 20251126 Eliminado estado N
						AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
						--ALM 20220603: No incluimos registros sin importe de comision.
						AND CAR_LP.IMPORTE <> 0
					--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
					LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
						AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
						AND Y.TENANTID = :v_idtenant
						AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
						AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
					--dejamos estos left join para tener los datos de las oficinas
					LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
					WHERE Y.POSITIONSEQ IS NULL;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_POLIZAS_REP. Agentes Derechos Económicos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_S4_POLIZAS_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				

				--ETERNA
				--DTB 20250526: Tabla INYC_S4_E_POLIZAS pasa a ser OUT_S4_E_POLIZAS_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
                DELETE FROM EXT.OUT_S4_E_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_S4_E_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_E_POLIZAS_REP. Creditos (Sin asistencias)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.OUT_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                        ST.CHANNEL AS COMPANIA,
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        -- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID = '71'
							AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        -- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
							THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        C.GENERICNUMBER1 AS ASEGURADOS
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20160616: Pedido por Celeste
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 102.2 
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_E_POLIZAS_REP. Creditos (Sin asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
    
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_E_POLIZAS_REP. Creditos (Asistencias)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.OUT_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                        ST.CHANNEL AS COMPANIA,
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        -- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID = '71'
							AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        -- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
						-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
						CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
							THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        C.GENERICNUMBER1 AS ASEGURADOS
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20160616: Pedido por Celeste
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
                        --ALM 20161027: Filtramos para quedarnos con creditos de Eterna
                        AND C.GENERICATTRIBUTE9 = '03'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 102.2
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_E_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
				
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_E_POLIZAS_REP. Pagos Comerciales 1** y 2**', i_log_count, i_id_proceso, 'debug');           
                INSERT INTO EXT.OUT_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                        SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                        --ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
                        SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                        '999999900000000' AS POLIZA,
                        SUBSTR(D.EARNINGCODEID,5,7) AS PRODUCTID,
                        D.DEPOSITDATE AS FEC_CARGO,
                        0 AS PRIMA_COMISIONABLE, 
                        --ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
                        --              depende del concepto de pago.
                        --(SELECT ET.DESCRIPTION FROM TCMP.CS_EVENTTYPE ET WHERE ET.EVENTTYPEID = 'Pago Comercial' AND ET.REMOVEDATE = :v_eot)
                        CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
                            --ATV 20240228 Anyadimos concepto 107 a peticion de Celeste
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '107' THEN 'CA 13 Comision'
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
                            --ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
                            ELSE 'Division Comercial'
                        END AS EVENTO,
                        PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                        '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                        AND D.TENANTID = :v_idtenant
                        --ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
                        AND D.EARNINGGROUPID LIKE '%S4%'
                        --ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
                        --              Correo de Afonso el 06/09/2016
                        AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                    --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                    INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 102.2 
                    --ALM 20160701: Utilizamos un INNER porque si el Pago Comercial viene sin producto no queremos que aparezca en el detalle (correo Javier 21/06)
                    --              Unimos por el Producto que vendra en el EARNINGCODEID (ej: 101-0121000)
                    INNER JOIN TCMP.CS_CLASSIFIER CL ON SUBSTR(D.EARNINGCODEID,5,7) = CL.CLASSIFIERID 
                        AND CL.REMOVEDATE = :v_eot  
                        AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND CL.TENANTID = :v_idtenant
                    LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                        AND PROD.REMOVEDATE = :v_eot  
                        AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND PROD.TENANTID = :v_idtenant
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_E_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
    
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_E_POLIZAS_REP. DERECHOS ECONOMICOS', i_log_count, i_id_proceso, 'debug'); 
                INSERT INTO EXT.OUT_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                    SELECT               
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.POSITIONNAME,
                        PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_ETERNA,
                        PAD_INS.CUADRO_RRTT_ETERNA,
                        SUBSTR(CAR_LP.ORDERID,1,2) AS COMPANIA,
                        PAD_OF.POSITIONNAME AS COD_OFICINA,
                        PAD_OF.LASTNAME AS OFICINA,
                        'CARTERA_LP' AS NAME, --C.NAME,
                        CAR_LP.IMPORTE AS VALUE, --C.VALUE,
                        0 AS POLIZ_CORR, 
                        0 AS POLIZ_NP,
                        CAR_LP.ORDERID ||CAST(CAR_LP.SUBLINENUMBER AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
                        CAR_LP.POLIZA,
                        CAR_LP.PRODUCTID,
                        CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
                        CAR_LP.VALUE AS PRIMA_COMISIONABLE, 
                        CAR_LP.EVENTO,--ST.EVENTO,
                        CAR_LP.PRODUCTO,--ST.PRODUCTO,
                        CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
                        CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,
                        PAD_INS.TIPO_AGENTE,
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS             
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
                        --LLS 20220125: Filtro para tener solo Eterna
                        AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03'
                        --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                        AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
                        --ALM 20220603: No incluimos registros sin importe de comision.
                        AND CAR_LP.IMPORTE <> 0
                    --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                    LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
                        AND Y.TENANTID = :v_idtenant
                        AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                        AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'                                        
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                    WHERE Y.POSITIONSEQ IS NULL;  
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_E_POLIZAS_REP. DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
                
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_S4_E_POLIZAS_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');

			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
			--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					--OCASO
					--DTB 20250526: Tabla INYC_LC_S4_POLIZAS pasa a ser OUT_LC_S4_POLIZAS_REP
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_S4_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_LC_S4_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_POLIZAS_REP. Creditos (Nueva producción)', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO) 
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							ST.CHANNEL AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							--PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
							--ALM 20170719: Para los nuevos creditos del Corte Ingles (SECI) no contamos polizas
							--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
							--CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' AND ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI'
								-- AND ST.EVENTTYPESEQ = 16607023625928867 
								-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
								AND ST.EVENTTYPEID = '71'
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							--ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
							-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997)
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID in ('AS50','AS90','AS91','AS10','AS110') 
									THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							C.GENERICNUMBER1 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							ST.GENERICATTRIBUTE7 AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
							AND C.NAME LIKE 'DC-O-COM-NuevaProduccion%'
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
						--ALM 20161221: Al tener TXN de mas de 3 meses no podemos unir con este tipo de tablas directamente porque hacen que el proceso se eternice.
						--INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
						--    AND TA.TENANTID = :v_idtenant
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2 
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_POLIZAS_REP. Creditos (Nueva producción). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_POLIZAS_REP. Creditos (Asistencias)', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							ST.CHANNEL AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							--PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
							--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
							--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,												
							-- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID = '71'
									AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							--ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1.  
							-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID in ('AS50','AS90','AS91','AS10','AS110')
									THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							C.GENERICNUMBER1 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							ST.GENERICATTRIBUTE7 AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
							--ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
							--AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
							AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
							AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
							--ALM 20170329: Filtramos para quedarnos con creditos de Ocaso igual que hacemos en Eterna
							AND C.GENERICATTRIBUTE9 = '01'
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2
						--ALM 20160907: Para las Asistencias filtramos para agentes segun su PLAN
						INNER JOIN :TBL_AGENTES_MES PAD_AG ON PAD_INS.PARTICIPANTSEQ = PAD_AG.PARTICIPANTSEQ
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = PAD_AG.POSITIONSEQ
							AND PAD_AG.PLANNAME LIKE 'Plan_O_%'
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ 
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_POLIZAS_REP. Creditos (Resto Creditos)', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							ST.CHANNEL AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							--PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
							--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
							--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							-- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID = '71'
									AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							-- ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
							-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997)
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID in ('AS50','AS90','AS91','AS10','AS110')
									THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							--ALM 20220530: Los creditos de las Gestiones traen en el GN1 el objetivo por lo que ponemos este valor a 0.
							--C.GENERICNUMBER1 AS ASEGURADOS
							(CASE WHEN C.NAME = 'DC-O-COM-GestionExplotacion' THEN 0 ELSE C.GENERICNUMBER1 END) AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							ST.GENERICATTRIBUTE7 AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
							--ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
							--AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
							AND C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
							AND C.NAME NOT LIKE 'DC-O-COM-NuevaProduccion%'
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2 
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;              
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_POLIZAS_REP. Creditos (Resto Creditos). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**)', i_log_count, i_id_proceso, 'debug');                        
					INSERT INTO EXT.OUT_LC_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)           
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
							--ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
							SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
							'999999900000000' AS POLIZA,
							CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
							D.DEPOSITDATE AS FEC_CARGO,
							0 AS PRIMA_COMISIONABLE,
							--ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
							--              depende del concepto de pago.
							CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
								WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
								--ALM 20180420: Anadimos los pagos comerciales de concepto 107 a las recuperaciones por peticion de Miguel Angel Arrabe
								WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('107') THEN 'Recuperacion'
								WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
								--ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
								WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
								WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
								ELSE 'Division Comercial'
							END AS EVENTO,
							PROD.GENERICATTRIBUTE5 AS PRODUCTO,
							'' AS FEC_VTO_REC,0 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							0 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							'' AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = D.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND D.TENANTID = :v_idtenant
							--ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
							AND D.EARNINGGROUPID LIKE '%S4%'
							--ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
							--              Correo de Afonso el 06/09/2016
							AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						--ALM 20180822: Nos quedamos con las 15 primeras letras del nombre del deposito para tener en cuenta los depositos antiguos de Abril y Mayo
						--              de 2016 que pueden venir con diferentes nombre (D-O-Pagos-Fijos-x)    
						INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,15) = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2
						--ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
						--              Necesario para Pagos Comerciales de Abril y Mayo 2016
						INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = (CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END)
							AND CL.REMOVEDATE = :v_eot  
							AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND CL.TENANTID = :v_idtenant
						LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
							AND PROD.REMOVEDATE = :v_eot  
							AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND PROD.TENANTID = :v_idtenant
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					--LLS 20220124: Caso espec�fico del dep�sito D-O-GestionExplotacion-PagoInicial (regla D-O-COM-GestionExplotacion-PagoInicial) de Enero 2022
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion.)', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
							SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
							'999999900000000' AS POLIZA,
							CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
							D.DEPOSITDATE AS FEC_CARGO,
							0 AS PRIMA_COMISIONABLE,
							'Gestiones referencias explotacion' AS EVENTO,
							PROD.GENERICATTRIBUTE5 AS PRODUCTO,
							'' AS FEC_VTO_REC,0 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							PAD_INS.SUPERRAPEL,
							0 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							'' AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = D.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND D.TENANTID = :v_idtenant
							AND D.EARNINGGROUPID LIKE '%S4%'
							AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
							AND D.NAME = 'D-O-GestionExplotacion-PagoInicial'
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2 
						LEFT JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
							AND CL.REMOVEDATE = :v_eot  
							AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND CL.TENANTID = :v_idtenant
						LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
							AND PROD.REMOVEDATE = :v_eot  
							AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND PROD.TENANTID = :v_idtenant
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;           
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS.)', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)     
						SELECT 
							PAD_INS.PARTICIPANTSEQ, 
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.POSITIONNAME,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							SUBSTR (CAR_LP.ORDERID,1,2) AS COMPANIA, --order id 2 primeros digitos
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							'CARTERA_LP' AS NAME, --C.NAME,
							CAR_LP.IMPORTE AS VALUE, --C.VALUE,
							0 as POLIZ_CORR,
							0 as POLIZ_NP,
							CAR_LP.ORDERID ||CAST(CAR_LP.SUBLINENUMBER AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
							CAR_LP.POLIZA, --ST.GENERICATTRIBUTE1 AS POLIZA,
							CAR_LP.PRODUCTID,
							CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
							CAR_LP.VALUE AS PRIMA_COMISIONABLE,
							CAR_LP.EVENTO,--ST.EVENTO,
							CAR_LP.PRODUCTO,--ST.PRODUCTO,
							CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
							CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							PAD_INS.SUPERRAPEL,
							0 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							'' AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
							--LLS 20220125: Filtro para tener solo Ocaso
							AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
							--ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
							--ATV 20250205 Anyadimos el estado N
							--BRG 20251126 Eliminado estado N
							AND CAR_LP.ESTADO = 'C'
							--ALM 20220603: No incluimos registros sin importe de comision.
							AND CAR_LP.IMPORTE <> 0
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
							AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
							AND Y.TENANTID = :v_idtenant
							AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
							AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
						-- dejamos estos left join para tener los datos de las oficinas 
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						WHERE Y.POSITIONSEQ IS NULL;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_S4_POLIZAS_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');


					--ETERNA
                    --DTB 20250527: Tabla INYC_LC_S4_E_POLIZAS pasa a ser OUT_LC_S4_E_POLIZAS_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.OUT_LC_S4_E_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_LC_S4_E_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                    
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_E_POLIZAS_REP. Creditos (Sin asistencias)', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            ST.CHANNEL AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                            C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                            --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                            --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            -- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID = '71' 
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                            --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                            -- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
								THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                            ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                            ST.GENERICNUMBER1 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                            PAD_INS.SUPERRAPEL,
                            C.GENERICNUMBER1 AS ASEGURADOS
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                            --ALM 20160616: Pedido por Celeste
                            --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                            AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                            AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                        INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                            AND REG.COD_INFORME = 102.2 
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_E_POLIZAS_REP. Creditos (Sin asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');               
                        
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_E_POLIZAS_REP. Creditos (Asistencias)', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            ST.CHANNEL AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                            C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                            --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                            --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            -- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID = '71'
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                            --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                            -- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
								THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                            ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                            ST.GENERICNUMBER1 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                            PAD_INS.SUPERRAPEL,
                            C.GENERICNUMBER1 AS ASEGURADOS
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                            --ALM 20160616: Pedido por Celeste
                            --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                            AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                            AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
                            --ALM 20161027: Filtramos para quedarnos con creditos de Eterna
                            AND C.GENERICATTRIBUTE9 = '03'
                        INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                            AND REG.COD_INFORME = 102.2
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_E_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');           
					
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_E_POLIZAS_REP. Pagos Comerciales 1** y 2**', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)   
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                            D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                            --ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
                            SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                            '999999900000000' AS POLIZA,
                            SUBSTR(D.EARNINGCODEID,5,7) AS PRODUCTID,
                            D.DEPOSITDATE AS FEC_CARGO,
                            0 AS PRIMA_COMISIONABLE, 
                            --ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
                            --              depende del concepto de pago.
                            --(SELECT ET.DESCRIPTION FROM TCMP.CS_EVENTTYPE ET WHERE ET.EVENTTYPEID = 'Pago Comercial' AND ET.REMOVEDATE = :v_eot)
                            CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
                                --ATV 20240228 Anyadimos concepto 107 a peticion de Celeste
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '107' THEN 'CA 13 Comision'
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
                                --ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
                                ELSE 'Division Comercial'
                            END AS EVENTO,
                            PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                            '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                            PAD_INS.SUPERRAPEL,
                            0 AS ASEGURADOS
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                            AND D.TENANTID = :v_idtenant
                            --ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
                            AND D.EARNINGGROUPID LIKE '%S4%'
                            --ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
                            --              Correo de Afonso el 06/09/2016
                            AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                        --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                        INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                            AND REG.COD_INFORME = 102.2 
                        --ALM 20160701: Utilizamos un INNER porque si el Pago Comercial viene sin producto no queremos que aparezca en el detalle (correo Javier 21/06)
                        --              Unimos por el Producto que vendra en el EARNINGCODEID (ej: 101-0121000)
                        INNER JOIN TCMP.CS_CLASSIFIER CL ON SUBSTR(D.EARNINGCODEID,5,7) = CL.CLASSIFIERID 
                            AND CL.REMOVEDATE = :v_eot  
                            AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                            AND CL.TENANTID = :v_idtenant
                        LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                            AND PROD.REMOVEDATE = :v_eot  
                            AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                            AND PROD.TENANTID = :v_idtenant
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_E_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
				
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_E_POLIZAS_REP. DERECHOS ECONOMICOS', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                        SELECT               
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.POSITIONNAME,
                            PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,
                            PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(CAR_LP.ORDERID,1,2) AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,
                            PAD_OF.LASTNAME AS OFICINA,
                            'CARTERA_LP' AS NAME, --C.NAME,
                            CAR_LP.IMPORTE AS VALUE, --C.VALUE,
                            0 AS POLIZ_CORR, 
                            0 AS POLIZ_NP,
                            CAR_LP.ORDERID || CAST(CAR_LP.SUBLINENUMBER AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
                            CAR_LP.POLIZA,
                            CAR_LP.PRODUCTID,
                            CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
                            CAR_LP.VALUE AS PRIMA_COMISIONABLE, 
                            CAR_LP.EVENTO,--ST.EVENTO,
                            CAR_LP.PRODUCTO,--ST.PRODUCTO,
                            CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
                            CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,
                            PAD_INS.TIPO_AGENTE,
                            PAD_INS.SUPERRAPEL,
                            0 AS ASEGURADOS             
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
                            --LLS 20220125: Filtro para tener solo Eterna
                            AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03'
                            --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                            AND CAR_LP.ESTADO = 'C'
                            --ALM 20220603: No incluimos registros sin importe de comision.
                            AND CAR_LP.IMPORTE <> 0
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        WHERE Y.POSITIONSEQ IS NULL
                        ;  
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_E_POLIZAS_REP. DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
					
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
                    CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_S4_E_POLIZAS_REP');
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				
					--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					--OCASO
					--DTB 20250526: Tabla INYC_BAL_S4_POLIZAS pasa a ser OUT_BAL_S4_POLIZAS_REP
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_S4_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_S4_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_POLIZAS_REP. Creditos (Nueva Produccion).)', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							ST.CHANNEL AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
							--ALM 20170719: Para los nuevos creditos del Corte Ingles (SECI) no contamos polizas
							--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
							--CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' AND ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI'						
								-- AND ST.EVENTTYPESEQ = 16607023625928867
								-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
								AND ST.EVENTTYPEID = '71'
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							-- ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1.
							-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID IN ('AS50', 'AS90', 'AS91', 'AS10', 'AS110')
									THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							C.GENERICNUMBER1 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							ST.GENERICATTRIBUTE7 AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
							AND C.NAME LIKE 'DC-O-COM-NuevaProduccion%'
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
						--ALM 20161221: Al tener TXN de mas de 3 meses no podemos unir con este tipo de tablas directamente porque hacen que el proceso se eternice.
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2 
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_POLIZAS_REP. Creditos (Nueva Produccion). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_POLIZAS_REP. Creditos (Asistencias).)', i_log_count, i_id_proceso, 'debug');                
					INSERT INTO EXT.OUT_BAL_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							ST.CHANNEL AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
							--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
							--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,							
							-- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID = '71'
									AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							--ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
							-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID IN ('AS50', 'AS90', 'AS91', 'AS10', 'AS110')
									THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							C.GENERICNUMBER1 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							ST.GENERICATTRIBUTE7 AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
							--ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no haya que cogerlo.
							--AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
							AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
							AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
							--ALM 20170329: Filtramos para quedarnos con creditos de Ocaso igual que hacemos en Eterna
							AND C.GENERICATTRIBUTE9 = '01'
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
						--INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
						--    AND TA.TENANTID = :v_idtenant
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2
						--ALM 20160907: Para las Asistencias filtramos para agentes segun su PLAN
						INNER JOIN :TBL_AGENTES_MES PAD_AG ON PAD_INS.PARTICIPANTSEQ = PAD_AG.PARTICIPANTSEQ 
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = PAD_AG.POSITIONSEQ
							AND PAD_AG.PLANNAME LIKE 'Plan_O_%'
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_POLIZAS_REP. Creditos (Resto Creditos).', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							ST.CHANNEL AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							--PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
							--ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
							--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP, 
							-- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID = '71'
									AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							--ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
							-- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID IN ('AS50', 'AS90', 'AS91', 'AS10', 'AS110')
									THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							--ALM 20220530: Los creditos de las Gestiones traen en el GN1 el objetivo por lo que ponemos este valor a 0.
							--C.GENERICNUMBER1 AS ASEGURADOS
							(CASE WHEN C.NAME = 'DC-O-COM-GestionExplotacion' THEN 0 ELSE C.GENERICNUMBER1 END) AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							ST.GENERICATTRIBUTE7 AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
							--ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no haya que cogerlo.
							--AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
							AND C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
							AND C.NAME NOT LIKE 'DC-O-COM-NuevaProduccion%'
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2 
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;              
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_POLIZAS_REP. Creditos (Resto Creditos). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)           
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
							--ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
							SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
							'999999900000000' AS POLIZA,
							CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
							D.DEPOSITDATE AS FEC_CARGO,
							0 AS PRIMA_COMISIONABLE,
							--ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
							--              depende del concepto de pago.
							CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
								WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
								--ALM 20180420: Anadimos los pagos comerciales de concepto 107 a las recuperaciones por peticion de Miguel Angel Arrabe
								WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('107') THEN 'Recuperacion'
								WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
								--ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
								WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
								WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
								ELSE 'Division Comercial'
							END AS EVENTO,
							PROD.GENERICATTRIBUTE5 AS PRODUCTO,
							'' AS FEC_VTO_REC,0 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							PAD_INS.SUPERRAPEL,
							0 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							'' AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = D.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND D.TENANTID = :v_idtenant
							--ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
							AND D.EARNINGGROUPID LIKE '%S4%'
							--ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
							--              Correo de Afonso el 06/09/2016
							AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						--ALM 20180822: Nos quedamos con las 15 primeras letras del nombre del deposito para tener en cuenta los depositos antiguos de Abril y Mayo
						--              de 2016 que pueden venir con diferentes nombre (D-O-Pagos-Fijos-x)
						INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,15) = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2
						--ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
						--              Necesario para Pagos Comerciales de Abril y Mayo 2016
						INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
							AND CL.REMOVEDATE = :v_eot  
							AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND CL.TENANTID = :v_idtenant
						LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
							AND PROD.REMOVEDATE = :v_eot  
							AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND PROD.TENANTID = :v_idtenant
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					--LLS 20220124: Caso especifico del deposito D-O-GestionExplotacion-PagoInicial (regla D-O-COM-GestionExplotacion-PagoInicial) de Enero 2022
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion.', i_log_count, i_id_proceso, 'debug');                        
					INSERT INTO EXT.OUT_BAL_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)           
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
							SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
							SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
							'999999900000000' AS POLIZA,
							CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
							D.DEPOSITDATE AS FEC_CARGO,
							0 AS PRIMA_COMISIONABLE,
							'Gestiones referencias explotacion' AS EVENTO,
							PROD.GENERICATTRIBUTE5 AS PRODUCTO,
							'' AS FEC_VTO_REC,0 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							PAD_INS.SUPERRAPEL,
							0 AS ASEGURADOS,
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							'' AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = D.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND D.TENANTID = :v_idtenant
							AND D.EARNINGGROUPID LIKE '%S4%'
							AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
							AND D.NAME = 'D-O-GestionExplotacion-PagoInicial'
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 100.2 
						LEFT JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
							AND CL.REMOVEDATE = :v_eot  
							AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND CL.TENANTID = :v_idtenant
						LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
							AND PROD.REMOVEDATE = :v_eot  
							AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND PROD.TENANTID = :v_idtenant
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');                        
					INSERT INTO EXT.OUT_BAL_S4_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, SUPERRAPEL, ASEGURADOS, COD_RECIBO)
						SELECT 
							PAD_INS.PARTICIPANTSEQ, 
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.POSITIONNAME,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							SUBSTR (CAR_LP.ORDERID,1,2) AS COMPANIA, -- order id 2 primeros digitos
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							'CARTERA_LP' AS NAME, --C.NAME,
							CAR_LP.IMPORTE AS VALUE, --C.VALUE,
							0 AS POLIZ_CORR,
							0 AS POLIZ_NP,
							CAR_LP.ORDERID ||CAST(CAR_LP.SUBLINENUMBER AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
							CAR_LP.POLIZA, --ST.GENERICATTRIBUTE1 AS POLIZA,
							CAR_LP.PRODUCTID,
							CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
							CAR_LP.VALUE AS PRIMA_COMISIONABLE,
							CAR_LP.EVENTO,--ST.EVENTO,
							CAR_LP.PRODUCTO,--ST.PRODUCTO,
							CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
							CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							PAD_INS.SUPERRAPEL,
							0 AS ASEGURADOS, 
							--ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
							'' AS COD_RECIBO
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
							--LLS 20220125: Filtro para tener solo Ocaso
							AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
							--ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
							--ATV 20250205 Anyadimos el estado N
                            --BRG 20251126 Eliminado estado N
							AND CAR_LP.ESTADO = 'C'
							--ALM 20220603: No incluimos registros sin importe de comision.
							AND CAR_LP.IMPORTE <> 0
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
							AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
							AND Y.TENANTID = :v_idtenant
							AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
							AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
						-- dejamos estos left join para tener los datos de las oficinas 
						LEFT JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						WHERE Y.POSITIONSEQ IS NULL;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_S4_POLIZAS_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_S4_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					

					--ETERNA
					--DTB 20250527: Tabla INYC_BAL_S4_E_POLIZAS pasa a ser OUT_BAL_S4_E_POLIZAS_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.OUT_BAL_S4_E_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_S4_E_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
    
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_E_POLIZAS_REP. Creditos (Sin asistencias)', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_BAL_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            ST.CHANNEL AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                            C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                            --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                            --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            -- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID 
							CASE WHEN ST.EVENTTYPEID = '71'
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                            --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                            -- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID	
							CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
								THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                            ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                            ST.GENERICNUMBER1 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                            PAD_INS.SUPERRAPEL,
                            C.GENERICNUMBER1 AS ASEGURADOS
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                            --ALM 20160616: Pedido por Celeste
                            --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                            AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                            AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                        INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                            AND REG.COD_INFORME = 102.2 
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_E_POLIZAS_REP. Creditos (Sin asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');               
					
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_E_POLIZAS_REP. Creditos (Asistencias)', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_BAL_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            ST.CHANNEL AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                            C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                            --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                            --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            -- CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID = '71'
								AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                            CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                            --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                            -- CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) 
							-- BRG 20250527: Cambiamos EVENTTYPESEQ por EVENTTYPEID
							CASE WHEN ST.EVENTTYPEID IN ('AS50','AS90','AS110','AS91','AS10')
								THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                            ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                            ST.GENERICNUMBER1 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                            PAD_INS.SUPERRAPEL,
                            C.GENERICNUMBER1 AS ASEGURADOS
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                            --ALM 20160616: Pedido por Celeste
                            --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                            AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                            AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
                            --ALM 20161027: Filtramos para quedarnos con creditos de Eterna
                            AND C.GENERICATTRIBUTE9 = '03'
                        INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                            AND REG.COD_INFORME = 102.2
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_E_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');           
						
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_E_POLIZAS_REP. Pagos Comerciales 1** y 2**', i_log_count, i_id_proceso, 'debug');            
                    INSERT INTO EXT.OUT_BAL_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                            D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                            --ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
                            SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                            '999999900000000' AS POLIZA,
                            SUBSTR(D.EARNINGCODEID,5,7) AS PRODUCTID,
                            D.DEPOSITDATE AS FEC_CARGO,
                            0 AS PRIMA_COMISIONABLE, 
                            --ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
                            --              depende del concepto de pago.
                            --(SELECT ET.DESCRIPTION FROM TCMP.CS_EVENTTYPE ET WHERE ET.EVENTTYPEID = 'Pago Comercial' AND ET.REMOVEDATE = :v_eot)
                            CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
                                --ATV 20240228 Anyadimos concepto 107 a peticion de Celeste
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '107' THEN 'CA 13 Comision'
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
                                --ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
                                WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
                                ELSE 'Division Comercial'
                            END AS EVENTO,
                            PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                            '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                            PAD_INS.SUPERRAPEL,
                            0 AS ASEGURADOS
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                            AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                            AND D.TENANTID = :v_idtenant
                            --ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
                            AND D.EARNINGGROUPID LIKE '%S4%'
                            --ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
                            --              Correo de Afonso el 06/09/2016
                            AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                        --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                        INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                            AND REG.COD_INFORME = 102.2 
                        --ALM 20160701: Utilizamos un INNER porque si el Pago Comercial viene sin producto no queremos que aparezca en el detalle (correo Javier 21/06)
                        --              Unimos por el Producto que vendra en el EARNINGCODEID (ej: 101-0121000)
                        INNER JOIN TCMP.CS_CLASSIFIER CL ON SUBSTR(D.EARNINGCODEID,5,7) = CL.CLASSIFIERID 
                            AND CL.REMOVEDATE = :v_eot  
                            AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                            AND CL.TENANTID = :v_idtenant
                        LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                            AND PROD.REMOVEDATE = :v_eot  
                            AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                            AND PROD.TENANTID = :v_idtenant
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4);
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_E_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
				
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S4_E_POLIZAS_REP. DERECHOS ECONOMICOS', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_BAL_S4_E_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, POLIZ_CORR, POLIZ_NP, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_COMIS, EVENTO, PRODUCTO, FEC_VTO_REC, PRIMA_NETA, ID_TIPO_AGENTE, TIPO_AGENTE, SUPERRAPEL, ASEGURADOS)
                        SELECT               
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.POSITIONNAME,
                            PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,
                            PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(CAR_LP.ORDERID,1,2) AS COMPANIA,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,
                            PAD_OF.LASTNAME AS OFICINA,
                            'CARTERA_LP' AS NAME, --C.NAME,
                            CAR_LP.IMPORTE AS VALUE, --C.VALUE,
                            0 AS POLIZ_CORR, 
                            0 AS POLIZ_NP,
                            CAR_LP.ORDERID || CAST(CAR_LP.SUBLINENUMBER AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
                            CAR_LP.POLIZA,
                            CAR_LP.PRODUCTID,
                            CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
                            CAR_LP.VALUE AS PRIMA_COMISIONABLE, 
                            CAR_LP.EVENTO,--ST.EVENTO,
                            CAR_LP.PRODUCTO,--ST.PRODUCTO,
                            CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
                            CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
                            PAD_INS.ID_TIPO_AGENTE,
                            PAD_INS.TIPO_AGENTE,
                            PAD_INS.SUPERRAPEL,
                            0 AS ASEGURADOS             
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
                            --LLS 20220125: Filtro para tener solo Eterna
                            AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03'
                            --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                            AND CAR_LP.ESTADO = 'C'
                            --ALM 20220603: No incluimos registros sin importe de comision.
                            AND CAR_LP.IMPORTE <> 0
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        WHERE Y.POSITIONSEQ IS NULL;  
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S4_E_POLIZAS_REP. DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');        
					
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
                    CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_S4_E_POLIZAS_REP');
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_S4_E_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
		
				END IF;
			
			END IF;        
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe S4 Detalle Pólizas', i_log_count, i_id_proceso, 'info');			

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

		-- Fin informe S4 Detalle Pólizas
		END IF;
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250527: TABLAS PARA INFORME S5 Detalle Pólizas (sólo se migra Ocaso)
		IF :i_lista_informes = 'S5' OR :i_lista_informes LIKE '%|S5|%' OR :i_lista_informes LIKE '%|S5' OR :i_lista_informes LIKE 'S5|%' 
			OR i_lista_informes = 'ALL' THEN

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe S5 Detalle Pólizas', i_log_count, i_id_proceso, 'info');


			--ALM 20171113: Comprobamos si el periodo esta posteado y si no lo esta cargamos las tablas de cierre
			IF v_periodo_posteado = 0 THEN
				-- BRG 20250526: Tabla INYC_S5_POLIZAS pasa a ser OUT_S5_POLIZAS_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_S5_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_S5_POLIZAS_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_S5_POLIZAS_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_S5_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_INSP, ID_TIPO_AGENTE, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, COEF_CORR, PORC_DIFERENCIAL, IMP_DIFERENCIAL, POLIZ_NP, PORC_LOCOMOCION, IMP_LOCOMOCION, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_NETA, DURACION, POSITIONNAME_AG, CUADRO_RRGG_AG, EVENTO, PRODUCTO, FEC_VTO_REC, TIPO_AGENTE, POLIZ_CORR, ASEGURADOS, ID_TIPO_AGENTE_AG, POLIZ_CORR_AG, CORR_TIPO_AGENTE, CORR_CAPTACION)
					--ALM 20170215: Modificamos la select para incluir los creditos que cuentan extornos
					SELECT
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_INSP_OCASO,
						PAD_INS.ID_TIPO_AGENTE,
						ST.CHANNEL AS COMPANIA,
						PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
						SUBSTR(C.NAME,1,1) || 'C-O-GEN-Inspector-PrimaCorregida' AS NAME,
						MAX(ABS(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.VALUE ELSE 0 END)) *
							MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN SIGN(C.VALUE) ELSE -1 END) AS VALUE,
						MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.GENERICNUMBER1 ELSE 0 END) AS COEF_CORR,
						SUM(DIF.RATEVALUE) AS PORC_DIFERENCIAL,SUM(DIF.VALUE) AS IMP_DIFERENCIAL,
						--ALM 20160629: Anadimos un campo para contar las Polizas de Nueva Produccion
						SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.VALUE ELSE 0 END) AS POLIZ_NP,
						SUM(CT.RATEVALUE) AS PORC_LOCOMOCION,SUM(CT.VALUE) AS IMP_LOCOMOCION,
						CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
						ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
						MAX(ABS(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.GENERICNUMBER5 ELSE 0 END)) *
							MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN SIGN(C.GENERICNUMBER5) ELSE -1 END) AS PRIMA_NETA,
						ST.GENERICATTRIBUTE12 AS DURACION,
						PAD_AG.POSITIONNAME AS POSITIONNAME_AG,PAD_AG.CUADRO_RRGG_OCASO AS CUADRO_RRGG_AG,
						ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
						PAD_INS.TIPO_AGENTE,
						--ALM 20180119: Anadimos campos a incluir para el PAC 2018
						SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER4 ELSE 0 END) AS POLIZ_CORR,
						SUM(CASE WHEN C.NAME LIKE '%-NumAsegurados%' THEN C.VALUE ELSE 0 END) AS ASEGURADOS,
						--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
						PAD_AG.ID_TIPO_AGENTE AS ID_TIPO_AGENTE_AG,
						SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER1 ELSE 0 END) AS POLIZ_CORR_AG,
						SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER2 ELSE 0 END) AS CORR_TIPO_AGENTE,
						SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER6 ELSE 0 END) AS CORR_CAPTACION
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = C.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
						--ALM 20180125: Filtramos por los creditos que cuentan polizas corregidas
						AND (C.VALUE <> 0 OR C.GENERICNUMBER5 <> 0 OR (C.GENERICNUMBER4 <> 0 AND C.NAME LIKE '%Polizas%'))
						--Filtramos por el GB3 que marca si el inspector era antes un agente para no tener en cuenta estos creditos
						AND (C.NAME LIKE 'IC-%' OR C.GENERICBOOLEAN3 = 0)
					INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
					INNER JOIN :TBL_AGENTES_PRIN_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POS_CALLIDUS
						AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						AND REG.COD_INFORME = 101.2
					--ALM 20160630: Al anadir las Commission de CT hay que filtrar unicamente por las de DIF, para ello necesitamos hacer un inner con cs_incentive
					LEFT JOIN (SELECT COM_DIF.CREDITSEQ,COM_DIF.RATEVALUE,COM_DIF.VALUE 
							FROM TCMP.CS_COMMISSION COM_DIF 
							--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
							INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
							INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
								--ALM 20171213: Filtramos para no tener en cuenta las Commission Anuales 
								AND I_DIF.TENANTID = :v_idtenant AND I_DIF.PERIODSEQ = :i_PeriodSeq AND I_DIF.NAME LIKE 'C-O-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
							WHERE COM_DIF.TENANTID = :v_idtenant AND COM_DIF.PERIODSEQ = :i_PeriodSeq
						) DIF ON C.CREDITSEQ = DIF.CREDITSEQ 
					--ALM 20160630: Por las modificaciones en el CT tenemos que usar las Commissions para calcular el CT
					LEFT JOIN (SELECT COM_CT.CREDITSEQ,COM_CT.RATEVALUE,COM_CT.VALUE 
							FROM TCMP.CS_COMMISSION COM_CT 
							--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
							INNER JOIN TCMP.CS_PLRUN PL ON COM_CT.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
							INNER JOIN TCMP.CS_INCENTIVE I_CT ON COM_CT.INCENTIVESEQ = I_CT.INCENTIVESEQ AND COM_CT.PIPELINERUNSEQ = I_CT.PIPELINERUNSEQ
								AND I_CT.TENANTID = :v_idtenant AND I_CT.PERIODSEQ = :i_PeriodSeq AND I_CT.NAME LIKE 'C-O-CT-%'
							WHERE COM_CT.TENANTID = :v_idtenant AND COM_CT.PERIODSEQ = :i_PeriodSeq
						) CT ON C.CREDITSEQ = CT.CREDITSEQ 
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						AND AG.COD_INFORME = 101
					--ALM 20160912: Anadimos un filtro para que no se carguen casos en los que los Diferenciales y la Locomocion sea nula
					--ALM 20170215: Ademas de lo anterior incluimos los creditos que cuentan polizas distintos de 0
					--ALM 20170301: Ademas de lo anterior incluimos los resultados de la consulta cumplan el resto de filtros o no para los agentes 79
					--              necesario para el nuevo informe de Produccion Oficina que usa tambien esta tabla
					WHERE (DIF.VALUE IS NOT NULL OR CT.VALUE IS NOT NULL OR PAD_INS.ID_TIPO_AGENTE = 79
							OR (CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.VALUE ELSE 0 END) <> 0
							--ALM 20180119: Cogemos tambien los creditos que cuentes pol. corregidas o asegurados
							OR (CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER4 ELSE 0 END) <> 0
							OR (CASE WHEN C.NAME LIKE '%-NumAsegurados%' THEN C.VALUE ELSE 0 END) <> 0)
						--ALM 20170518: Filtramos las transaccion con tipo de evento REC-RRTT para los agentes que no sean 57 y 61
						--              Tenemos que usar la tipologia de la Position del inspector que recibe la poliza no del principal.
						AND ((SELECT MAX(X.POSITIONGENERICNUMBER2) FROM :TBL_AGENTES_MES X WHERE X.PERIODSEQ = PAD_INS.PERIODSEQ
								--ALM 20170628: Por peticion de David anadimos los tipos 82
								AND X.PARTICIPANTSEQ = PAD_INS.PARTICIPANTSEQ AND X.POSITIONSEQ = PAD_INS.POSITIONSEQ) IN (82,61)
							OR ST.EVENTO <> 'Recuperaciones Ramos Tradicionales')
					GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),PAD_INS.POS_PRIN,PAD_INS.CUADRO_INSP_OCASO,
						PAD_INS.ID_TIPO_AGENTE,ST.CHANNEL,PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,SUBSTR(C.NAME,1,1),
						CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,
						ST.GENERICATTRIBUTE12,PAD_AG.POSITIONNAME,PAD_AG.CUADRO_RRGG_OCASO,ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,PAD_INS.TIPO_AGENTE,
						--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
						PAD_AG.ID_TIPO_AGENTE;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_S5_POLIZAS_REP. Creditos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_S5_POLIZAS_REP. Pagos Comerciales 2** y 5**.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_S5_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_INSP, ID_TIPO_AGENTE, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, COEF_CORR, PORC_DIFERENCIAL, IMP_DIFERENCIAL, POLIZ_NP, PORC_LOCOMOCION, IMP_LOCOMOCION, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_NETA, DURACION, POSITIONNAME_AG, CUADRO_RRGG_AG, EVENTO, PRODUCTO, FEC_VTO_REC, TIPO_AGENTE, POLIZ_CORR, ASEGURADOS, ID_TIPO_AGENTE_AG, POLIZ_CORR_AG, CORR_TIPO_AGENTE, CORR_CAPTACION)
					SELECT
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
						PAD_INS.POS_PRIN,
						PAD_INS.CUADRO_INSP_OCASO,
						PAD_INS.ID_TIPO_AGENTE,
						SUBSTR(D.EARNINGCODEID,5,2) AS COMPANIA,
						PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
						D.NAME,CASE WHEN D.NAME = 'D-O-Pagos-Fijos' THEN 0 ELSE D.VALUE END AS VALUE,0 AS COEF_CORR,
						0 AS PORC_DIFERENCIAL,
						CASE WHEN SUBSTR(D.EARNINGCODEID,1,1) = '2' THEN D.VALUE ELSE 0 END AS IMP_DIFERENCIAL,
						0 AS POLIZ_NP,
						0 AS PORC_LOCOMOCION,
						CASE WHEN SUBSTR(D.EARNINGCODEID,1,1) = '5' THEN D.VALUE ELSE 0 END AS IMP_LOCOMOCION,
						--ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
						SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
						'999999900000000' AS POLIZA,
						--ALM 20160914: Para Abril y Mayo los Pagos Comerciales no traen el producto en el EARNINGCODEID sino en el GA1
						CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
							THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
						D.DEPOSITDATE AS FEC_CARGO,0 AS PRIMA_NETA,'' AS DURACION,
						'' AS POSITIONNAME_AG,'' CUADRO_RRGG_AG,
						--ALM 20160914: Como solo cogemos conceptos 2xx y 5xx ponemos regularizacion a todo.
						'Regularizacion' AS EVENTO,
						PROD.GENERICATTRIBUTE5 AS PRODUCTO,
						'' AS FEC_VTO_REC,
						PAD_INS.TIPO_AGENTE,
						--ALM 20180119: Anadimos campos a incluir para el PAC 2018
						0 AS POLIZ_CORR,
						0 AS ASEGURADOS,
						--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
						NULL AS ID_TIPO_AGENTE_AG,
						0 AS POLIZ_CORR_AG,
						0 AS CORR_TIPO_AGENTE,
						0 AS CORR_CAPTACION
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = D.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
						AND D.TENANTID = :v_idtenant
						--ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S5% (ej: 04-S5-03)
						AND D.EARNINGGROUPID LIKE '%S5%'
						--ALM 20160914: Solo nos quedamos con los Pagos Comerciales que pertenezcan a Diferenciales o Compensacion por Transaporte
						AND ((D.NAME = 'D-O-Pagos-Fijos' AND SUBSTR(D.EARNINGCODEID,1,1) IN ('2','5')) OR D.NAME LIKE 'DD-O-COLC-Inspector-Pago-00%')
					--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
					INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
					INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,27) = REG.REGLA
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						AND REG.COD_INFORME = 101.2
					--ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
					--              Necesario para Pagos Comerciales de Abril y Mayo 2016
					INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = (CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
							THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END)
						AND CL.REMOVEDATE = :v_eot  
						AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
						AND CL.TENANTID = :v_idtenant
					LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
						AND PROD.REMOVEDATE = :v_eot  
						AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
						AND PROD.TENANTID = :v_idtenant
					LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						AND AG.COD_INFORME = 101;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_S5_POLIZAS_REP. Pagos Comerciales 2** y 5**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_S5_POLIZAS_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					-- BRG 20250526: Tabla INYC_LC_S5_POLIZAS pasa a ser OUT_LC_S5_POLIZAS_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_S5_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_S5_POLIZAS_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S5_POLIZAS_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_S5_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_INSP, ID_TIPO_AGENTE, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, COEF_CORR, PORC_DIFERENCIAL, IMP_DIFERENCIAL, POLIZ_NP, PORC_LOCOMOCION, IMP_LOCOMOCION, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_NETA, DURACION, POSITIONNAME_AG, CUADRO_RRGG_AG, EVENTO, PRODUCTO, FEC_VTO_REC, TIPO_AGENTE, POLIZ_CORR, ASEGURADOS, ID_TIPO_AGENTE_AG, POLIZ_CORR_AG, CORR_TIPO_AGENTE, CORR_CAPTACION)
						--ALM 20170215: Modificamos la select para incluir los creditos que cuentan extornos
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_INSP_OCASO,
							PAD_INS.ID_TIPO_AGENTE,
							ST.CHANNEL AS COMPANIA,
							PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							--C.NAME,C.VALUE,C.GENERICNUMBER1 AS COEF_CORR,
							SUBSTR(C.NAME,1,1) || 'C-O-GEN-Inspector-PrimaCorregida' AS NAME,
							MAX(ABS(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.VALUE ELSE 0 END)) *
								MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN SIGN(C.VALUE) ELSE -1 END) AS VALUE,
							MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.GENERICNUMBER1 ELSE 0 END) AS COEF_CORR,
							--DIF.RATEVALUE AS PORC_DIFERENCIAL,DIF.VALUE AS IMP_DIFERENCIAL,
							SUM(DIF.RATEVALUE) AS PORC_DIFERENCIAL,SUM(DIF.VALUE) AS IMP_DIFERENCIAL,
							--ALM 20160629: Anadimos un campo para contar las Polizas de Nueva Produccion
							--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.VALUE ELSE 0 END) AS POLIZ_NP,
							--CT.RATEVALUE AS PORC_LOCOMOCION,CT.VALUE AS IMP_LOCOMOCION,
							SUM(CT.RATEVALUE) AS PORC_LOCOMOCION,SUM(CT.VALUE) AS IMP_LOCOMOCION,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
							ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							--C.GENERICNUMBER5 AS PRIMA_NETA,
							MAX(ABS(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.GENERICNUMBER5 ELSE 0 END)) *
								MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN SIGN(C.GENERICNUMBER5) ELSE -1 END) AS PRIMA_NETA,
							ST.GENERICATTRIBUTE12 AS DURACION,
							PAD_AG.POSITIONNAME AS POSITIONNAME_AG,PAD_AG.CUADRO_RRGG_OCASO AS CUADRO_RRGG_AG,
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							PAD_INS.TIPO_AGENTE,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER4 ELSE 0 END) AS POLIZ_CORR,
							SUM(CASE WHEN C.NAME LIKE '%-NumAsegurados%' THEN C.VALUE ELSE 0 END) AS ASEGURADOS,
							--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
							PAD_AG.ID_TIPO_AGENTE AS ID_TIPO_AGENTE_AG,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER1 ELSE 0 END) AS POLIZ_CORR_AG,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER2 ELSE 0 END) AS CORR_TIPO_AGENTE,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER6 ELSE 0 END) AS CORR_CAPTACION
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20180125: Filtramos por los creditos que cuentan polizas corregidas
							AND (C.VALUE <> 0 OR (C.GENERICNUMBER4 <> 0 AND C.NAME LIKE '%Polizas%'))
							--Filtramos por el GB3 que marca si el inspector era antes un agente para no tener en cuenta estos creditos
							AND (C.NAME LIKE 'IC-%' OR C.GENERICBOOLEAN3 = 0)
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
						INNER JOIN :TBL_AGENTES_PRIN_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POS_CALLIDUS
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 101.2
						--ALM 20160630: Al anadir las Commission de CT hay que filtrar unicamente por las de DIF, para ello necesitamos hacer un inner con cs_incentive
						LEFT JOIN (SELECT COM_DIF.CREDITSEQ,COM_DIF.RATEVALUE,COM_DIF.VALUE 
								FROM TCMP.CS_COMMISSION COM_DIF 
								--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
								INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
								INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
								--ALM 20171213: Filtramos para no tener en cuenta las Commission Anuales 
								AND I_DIF.TENANTID = :v_idtenant AND I_DIF.PERIODSEQ = :i_PeriodSeq AND I_DIF.NAME LIKE 'C-O-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
								WHERE COM_DIF.TENANTID = :v_idtenant AND COM_DIF.PERIODSEQ = :i_PeriodSeq
							) DIF ON C.CREDITSEQ = DIF.CREDITSEQ 
						--ALM 20160630: Por las modificaciones en el CT tenemos que usar las Commissions para calcular el CT
						LEFT JOIN (SELECT COM_CT.CREDITSEQ,COM_CT.RATEVALUE,COM_CT.VALUE 
								FROM TCMP.CS_COMMISSION COM_CT 
								--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
								INNER JOIN TCMP.CS_PLRUN PL ON COM_CT.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
								INNER JOIN TCMP.CS_INCENTIVE I_CT ON COM_CT.INCENTIVESEQ = I_CT.INCENTIVESEQ AND COM_CT.PIPELINERUNSEQ = I_CT.PIPELINERUNSEQ
									AND I_CT.TENANTID = :v_idtenant AND I_CT.PERIODSEQ = :i_PeriodSeq AND I_CT.NAME LIKE 'C-O-CT-%' 
								WHERE COM_CT.TENANTID = :v_idtenant AND COM_CT.PERIODSEQ = :i_PeriodSeq
							) CT ON C.CREDITSEQ = CT.CREDITSEQ 
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
							AND AG.COD_INFORME = 101
						--ALM 20160912: Anadimos un filtro para que no se carguen casos en los que los Diferenciales y la Locomocion sea nula
						--ALM 20170215: Ademas de lo anterior incluimos los creditos que cuentan polizas distintos de 0
						--ALM 20170301: Ademas de lo anterior incluimos los resultados de la consulta cumplan el resto de filtros o no para los agentes 79
						--              necesario para el nuevo informe de Produccion Oficina que usa tambien esta tabla
						WHERE (DIF.VALUE IS NOT NULL OR CT.VALUE IS NOT NULL OR PAD_INS.ID_TIPO_AGENTE = 79
								OR (CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.VALUE ELSE 0 END) <> 0
								--ALM 20180119: Cogemos tambien los creditos que cuentes pol. corregidas o asegurados
								OR (CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER4 ELSE 0 END) <> 0
								OR (CASE WHEN C.NAME LIKE '%-NumAsegurados%' THEN C.VALUE ELSE 0 END) <> 0)
							--ALM 20170518: Filtramos las transaccion con tipo de evento REC-RRTT para los agentes que no sean 57 y 61
							--              Tenemos que usar la tipologia de la Position del inspector que recibe la poliza no del principal.
							AND ((SELECT MAX(X.POSITIONGENERICNUMBER2) 
								FROM :TBL_AGENTES_MES X 
								WHERE X.PERIODSEQ = PAD_INS.PERIODSEQ
									--ALM 20170628: Por peticion de David anadimos los tipos 82
									AND X.PARTICIPANTSEQ = PAD_INS.PARTICIPANTSEQ AND X.POSITIONSEQ = PAD_INS.POSITIONSEQ) IN (82,61)
								OR ST.EVENTO <> 'Recuperaciones Ramos Tradicionales')
						GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),PAD_INS.POS_PRIN,PAD_INS.CUADRO_INSP_OCASO,
							PAD_INS.ID_TIPO_AGENTE,ST.CHANNEL,PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,SUBSTR(C.NAME,1,1),
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,
							ST.GENERICATTRIBUTE12,PAD_AG.POSITIONNAME,PAD_AG.CUADRO_RRGG_OCASO,ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,PAD_INS.TIPO_AGENTE,
							--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
							PAD_AG.ID_TIPO_AGENTE;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_S5_POLIZAS_REP. Creditos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S5_POLIZAS_REP. Pagos Comerciales 2** y 5**.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_S5_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_INSP, ID_TIPO_AGENTE, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, COEF_CORR, PORC_DIFERENCIAL, IMP_DIFERENCIAL, POLIZ_NP, PORC_LOCOMOCION, IMP_LOCOMOCION, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_NETA, DURACION, POSITIONNAME_AG, CUADRO_RRGG_AG, EVENTO, PRODUCTO, FEC_VTO_REC, TIPO_AGENTE, POLIZ_CORR, ASEGURADOS, ID_TIPO_AGENTE_AG, POLIZ_CORR_AG, CORR_TIPO_AGENTE, CORR_CAPTACION)
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_INSP_OCASO,
							PAD_INS.ID_TIPO_AGENTE,
							SUBSTR(D.EARNINGCODEID,5,2) AS COMPANIA,
							PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							D.NAME,CASE WHEN D.NAME = 'D-O-Pagos-Fijos' THEN 0 ELSE D.VALUE END AS VALUE,0 AS COEF_CORR,
							0 AS PORC_DIFERENCIAL,
							CASE WHEN SUBSTR(D.EARNINGCODEID,1,1) = '2' THEN D.VALUE ELSE 0 END AS IMP_DIFERENCIAL,
							0 AS POLIZ_NP,
							0 AS PORC_LOCOMOCION,
							CASE WHEN SUBSTR(D.EARNINGCODEID,1,1) = '5' THEN D.VALUE ELSE 0 END AS IMP_LOCOMOCION,
							--ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
							SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
							'999999900000000' AS POLIZA,
							--ALM 20160914: Para Abril y Mayo los Pagos Comerciales no traen el producto en el EARNINGCODEID sino en el GA1
							CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
							D.DEPOSITDATE AS FEC_CARGO,0 AS PRIMA_NETA,'' AS DURACION,
							'' AS POSITIONNAME_AG,'' CUADRO_RRGG_AG,
							--ALM 20160914: Como solo cogemos conceptos 2xx y 5xx ponemos regularizacion a todo.
							'Regularizacion' AS EVENTO,
							PROD.GENERICATTRIBUTE5 AS PRODUCTO,
							'' AS FEC_VTO_REC,
							PAD_INS.TIPO_AGENTE,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							0 AS POLIZ_CORR,
							0 AS ASEGURADOS,
							--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
							NULL AS ID_TIPO_AGENTE_AG,
							0 AS POLIZ_CORR_AG,
							0 AS CORR_TIPO_AGENTE,
							0 AS CORR_CAPTACION
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = D.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND D.TENANTID = :v_idtenant
							--ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S5% (ej: 04-S5-03)
							AND D.EARNINGGROUPID LIKE '%S5%'
							--ALM 20160914: Solo nos quedamos con los Pagos Comerciales que pertenezcan a Diferenciales o Compensacion por Transaporte
							AND ((D.NAME = 'D-O-Pagos-Fijos' AND SUBSTR(D.EARNINGCODEID,1,1) IN ('2','5')) OR D.NAME LIKE 'DD-O-COLC-Inspector-Pago-00%')
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,27) = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 101.2
						--ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
						--              Necesario para Pagos Comerciales de Abril y Mayo 2016
						INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = (CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END)
							AND CL.REMOVEDATE = :v_eot  
							AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND CL.TENANTID = :v_idtenant
						LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
							AND PROD.REMOVEDATE = :v_eot  
							AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND PROD.TENANTID = :v_idtenant
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
							AND AG.COD_INFORME = 101;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_S5_POLIZAS_REP. Pagos Comerciales 2** y 5**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_S5_POLIZAS_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					-- BRG 20250526: Tabla INYC_BAL_S5_POLIZAS pasa a ser OUT_BAL_S5_POLIZAS_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_S5_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_S5_POLIZAS_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S5_POLIZAS_REP. Creditos', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_S5_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_INSP, ID_TIPO_AGENTE, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, COEF_CORR, PORC_DIFERENCIAL, IMP_DIFERENCIAL, POLIZ_NP, PORC_LOCOMOCION, IMP_LOCOMOCION, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_NETA, DURACION, POSITIONNAME_AG, CUADRO_RRGG_AG, EVENTO, PRODUCTO, FEC_VTO_REC, TIPO_AGENTE, POLIZ_CORR, ASEGURADOS, ID_TIPO_AGENTE_AG, POLIZ_CORR_AG, CORR_TIPO_AGENTE, CORR_CAPTACION) 
						--ALM 20170215: Modificamos la select para incluir los creditos que cuentan extornos
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_INSP_OCASO,
							PAD_INS.ID_TIPO_AGENTE,
							ST.CHANNEL AS COMPANIA,
							PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							SUBSTR(C.NAME,1,1) || 'C-O-GEN-Inspector-PrimaCorregida' AS NAME,
							MAX(ABS(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.VALUE ELSE 0 END)) *
								MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN SIGN(C.VALUE) ELSE -1 END) AS VALUE,
							MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.GENERICNUMBER1 ELSE 0 END) AS COEF_CORR,
							--DIF.RATEVALUE AS PORC_DIFERENCIAL,DIF.VALUE AS IMP_DIFERENCIAL,
							SUM(DIF.RATEVALUE) AS PORC_DIFERENCIAL,SUM(DIF.VALUE) AS IMP_DIFERENCIAL,
							--ALM 20160629: Anadimos un campo para contar las Polizas de Nueva Produccion
							--CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.VALUE ELSE 0 END) AS POLIZ_NP,
							--CT.RATEVALUE AS PORC_LOCOMOCION,CT.VALUE AS IMP_LOCOMOCION,
							SUM(CT.RATEVALUE) AS PORC_LOCOMOCION,SUM(CT.VALUE) AS IMP_LOCOMOCION,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
							ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
							--C.GENERICNUMBER5 AS PRIMA_NETA,
							MAX(ABS(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN C.GENERICNUMBER5 ELSE 0 END)) *
								MAX(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-PrimaCorregida%' THEN SIGN(C.GENERICNUMBER5) ELSE -1 END) AS PRIMA_NETA,
							ST.GENERICATTRIBUTE12 AS DURACION,
							PAD_AG.POSITIONNAME AS POSITIONNAME_AG,PAD_AG.CUADRO_RRGG_OCASO AS CUADRO_RRGG_AG,
							ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
							PAD_INS.TIPO_AGENTE,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER4 ELSE 0 END) AS POLIZ_CORR,
							SUM(CASE WHEN C.NAME LIKE '%-NumAsegurados%' THEN C.VALUE ELSE 0 END) AS ASEGURADOS,
							--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
							PAD_AG.ID_TIPO_AGENTE AS ID_TIPO_AGENTE_AG,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER1 ELSE 0 END) AS POLIZ_CORR_AG,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER2 ELSE 0 END) AS CORR_TIPO_AGENTE,
							SUM(CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER6 ELSE 0 END) AS CORR_CAPTACION
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							--ALM 20180125: Filtramos por los creditos que cuentan polizas corregidas
							AND (C.VALUE <> 0 OR (C.GENERICNUMBER4 <> 0 AND C.NAME LIKE '%Polizas%'))
							--Filtramos por el GB3 que marca si el inspector era antes un agente para no tener en cuenta estos creditos
							AND (C.NAME LIKE 'IC-%' OR C.GENERICBOOLEAN3 = 0)
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
						INNER JOIN :TBL_AGENTES_PRIN_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POS_CALLIDUS
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 101.2
						--ALM 20160630: Al anadir las Commission de CT hay que filtrar unicamente por las de DIF, para ello necesitamos hacer un inner con cs_incentive
						LEFT JOIN (SELECT COM_DIF.CREDITSEQ,COM_DIF.RATEVALUE,COM_DIF.VALUE 
								FROM TCMP.CS_COMMISSION COM_DIF 
								--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
								INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
								INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
								--ALM 20171213: Filtramos para no tener en cuenta las Commission Anuales 
								AND I_DIF.TENANTID = :v_idtenant AND I_DIF.PERIODSEQ = :i_PeriodSeq AND I_DIF.NAME LIKE 'C-O-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
								WHERE COM_DIF.TENANTID = :v_idtenant AND COM_DIF.PERIODSEQ = :i_PeriodSeq
							) DIF ON C.CREDITSEQ = DIF.CREDITSEQ 
						--ALM 20160630: Por las modificaciones en el CT tenemos que usar las Commissions para calcular el CT
						LEFT JOIN (SELECT COM_CT.CREDITSEQ,COM_CT.RATEVALUE,COM_CT.VALUE 
								FROM TCMP.CS_COMMISSION COM_CT 
								--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
								INNER JOIN TCMP.CS_PLRUN PL ON COM_CT.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
								INNER JOIN TCMP.CS_INCENTIVE I_CT ON COM_CT.INCENTIVESEQ = I_CT.INCENTIVESEQ AND COM_CT.PIPELINERUNSEQ = I_CT.PIPELINERUNSEQ
									AND I_CT.TENANTID = :v_idtenant AND I_CT.PERIODSEQ = :i_PeriodSeq AND I_CT.NAME LIKE 'C-O-CT-%' 
								WHERE COM_CT.TENANTID = :v_idtenant AND COM_CT.PERIODSEQ = :i_PeriodSeq
							) CT ON C.CREDITSEQ = CT.CREDITSEQ 
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
							AND AG.COD_INFORME = 101
						--ALM 20160912: Anadimos un filtro para que no se carguen casos en los que los Diferenciales y la Locomocion sea nula
						--ALM 20170215: Ademas de lo anterior incluimos los creditos que cuentan polizas distintos de 0
						--ALM 20170301: Ademas de lo anterior incluimos los resultados de la consulta cumplan el resto de filtros o no para los agentes 79
						--              necesario para el nuevo informe de Produccion Oficina que usa tambien esta tabla
						WHERE (DIF.VALUE IS NOT NULL OR CT.VALUE IS NOT NULL OR PAD_INS.ID_TIPO_AGENTE = 79
								OR (CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.VALUE ELSE 0 END) <> 0
								--ALM 20180119: Cogemos tambien los creditos que cuentes pol. corregidas o asegurados
								OR (CASE WHEN C.NAME LIKE '%C-O-GEN-Inspector-NumeroPolizas-%' THEN C.GENERICNUMBER4 ELSE 0 END) <> 0
								OR (CASE WHEN C.NAME LIKE '%-NumAsegurados%' THEN C.VALUE ELSE 0 END) <> 0)
							--ALM 20170518: Filtramos las transaccion con tipo de evento REC-RRTT para los agentes que no sean 57 y 61
							--              Tenemos que usar la tipologia de la Position del inspector que recibe la poliza no del principal.
							AND ((SELECT MAX(X.POSITIONGENERICNUMBER2) 
									FROM :TBL_AGENTES_MES X 
									WHERE X.PERIODSEQ = PAD_INS.PERIODSEQ
										--ALM 20170628: Por peticion de David anadimos los tipos 82
										AND X.PARTICIPANTSEQ = PAD_INS.PARTICIPANTSEQ AND X.POSITIONSEQ = PAD_INS.POSITIONSEQ) IN (82,61)
								OR ST.EVENTO <> 'Recuperaciones Ramos Tradicionales')
						GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),PAD_INS.POS_PRIN,PAD_INS.CUADRO_INSP_OCASO,
							PAD_INS.ID_TIPO_AGENTE,ST.CHANNEL,PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,SUBSTR(C.NAME,1,1),
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,
							ST.GENERICATTRIBUTE12,PAD_AG.POSITIONNAME,PAD_AG.CUADRO_RRGG_OCASO,ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,PAD_INS.TIPO_AGENTE,
							--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
							PAD_AG.ID_TIPO_AGENTE;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S5_POLIZAS_REP. Creditos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_S5_POLIZAS_REP. Pagos Comerciales 2** y 5**.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_S5_POLIZAS_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, POSITIONNAME, NIF, NOMBRE, POS_PRIN, CUADRO_INSP, ID_TIPO_AGENTE, COMPANIA, COD_OFICINA, OFICINA, NAME, VALUE, COEF_CORR, PORC_DIFERENCIAL, IMP_DIFERENCIAL, POLIZ_NP, PORC_LOCOMOCION, IMP_LOCOMOCION, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, FEC_CARGO, PRIMA_NETA, DURACION, POSITIONNAME_AG, CUADRO_RRGG_AG, EVENTO, PRODUCTO, FEC_VTO_REC, TIPO_AGENTE, POLIZ_CORR, ASEGURADOS, ID_TIPO_AGENTE_AG, POLIZ_CORR_AG, CORR_TIPO_AGENTE, CORR_CAPTACION)
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
							PAD_INS.POS_PRIN,
							PAD_INS.CUADRO_INSP_OCASO,
							PAD_INS.ID_TIPO_AGENTE,
							SUBSTR(D.EARNINGCODEID,5,2) AS COMPANIA,
							PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
							D.NAME,CASE WHEN D.NAME = 'D-O-Pagos-Fijos' THEN 0 ELSE D.VALUE END AS VALUE,0 AS COEF_CORR,
							0 AS PORC_DIFERENCIAL,
							CASE WHEN SUBSTR(D.EARNINGCODEID,1,1) = '2' THEN D.VALUE ELSE 0 END AS IMP_DIFERENCIAL,
							0 AS POLIZ_NP,
							0 AS PORC_LOCOMOCION,
							CASE WHEN SUBSTR(D.EARNINGCODEID,1,1) = '5' THEN D.VALUE ELSE 0 END AS IMP_LOCOMOCION,
							--ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
							SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
							'999999900000000' AS POLIZA,
							--ALM 20160914: Para Abril y Mayo los Pagos Comerciales no traen el producto en el EARNINGCODEID sino en el GA1
							CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
							D.DEPOSITDATE AS FEC_CARGO,0 AS PRIMA_NETA,'' AS DURACION,
							'' AS POSITIONNAME_AG,'' CUADRO_RRGG_AG,
							--ALM 20160914: Como solo cogemos conceptos 2xx y 5xx ponemos regularizacion a todo.
							'Regularizacion' AS EVENTO,
							PROD.GENERICATTRIBUTE5 AS PRODUCTO,
							'' AS FEC_VTO_REC,
							PAD_INS.TIPO_AGENTE,
							--ALM 20180119: Anadimos campos a incluir para el PAC 2018
							0 AS POLIZ_CORR,
							0 AS ASEGURADOS,
							--ALM 20230201: Incluimos nuevos campos solicitados para el PAC 2023.
							NULL AS ID_TIPO_AGENTE_AG,
							0 AS POLIZ_CORR_AG,
							0 AS CORR_TIPO_AGENTE,
							0 AS CORR_CAPTACION
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = D.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND D.TENANTID = :v_idtenant
							--ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S5% (ej: 04-S5-03)
							AND D.EARNINGGROUPID LIKE '%S5%'
							--ALM 20160914: Solo nos quedamos con los Pagos Comerciales que pertenezcan a Diferenciales o Compensacion por Transaporte
							AND ((D.NAME = 'D-O-Pagos-Fijos' AND SUBSTR(D.EARNINGCODEID,1,1) IN ('2','5')) OR D.NAME LIKE 'DD-O-COLC-Inspector-Pago-00%')
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,27) = REG.REGLA
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
							AND REG.COD_INFORME = 101.2
						--ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
						--              Necesario para Pagos Comerciales de Abril y Mayo 2016
						INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = (CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
								THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END)
							AND CL.REMOVEDATE = :v_eot  
							AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND CL.TENANTID = :v_idtenant
						LEFT JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
							AND PROD.REMOVEDATE = :v_eot  
							AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
							AND PROD.TENANTID = :v_idtenant
						LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
							AND AG.COD_INFORME = 101;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_S5_POLIZAS_REP. Pagos Comerciales 2** y 5**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_S5_POLIZAS_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_S5_POLIZAS_REP.', i_log_count, i_id_proceso, 'debug');
				END IF;
			END IF;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe S5 Detalle Pólizas', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

		-- Fin informe S5 Detalle Pólizas
		END IF;
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- BRG 20250528: TABLAS PARA INFORMES S4 y S5 Factura
		IF :i_lista_informes = 'FAC_S4' OR :i_lista_informes LIKE '%|FAC_S4|%' OR :i_lista_informes LIKE '%|FAC_S4' OR :i_lista_informes LIKE 'FAC_S4|%' 
            OR :i_lista_informes = 'FAC_S5' OR :i_lista_informes LIKE '%|FAC_S5|%' OR :i_lista_informes LIKE '%|FAC_S5' OR :i_lista_informes LIKE 'FAC_S5|%'
            OR :i_lista_informes = 'FAC_S4_E' OR :i_lista_informes LIKE '%|FAC_S4_E|%' OR :i_lista_informes LIKE '%|FAC_S4_E' OR :i_lista_informes LIKE 'FAC_S4_E|%'
            OR :i_lista_informes = 'ALL' THEN
            
		
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informes S4 Factura', i_log_count, i_id_proceso, 'info');
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informes S5 Factura', i_log_count, i_id_proceso, 'info');


            --ALM 20171113: Comprobamos si el periodo esta posteado y si no lo esta cargamos las tablas de cierre
            IF v_periodo_posteado = 0 THEN
				-- OCASO
                -- BRG 20250527: INYC_S4_FACTURA pasa a ser OUT_S4_FACTURA_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                DELETE FROM EXT.OUT_S4_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.OUT_S4_FACTURA_REP(PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, NIF, NOMBRE, MUNICIPIO, DOMICILIO, CP, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, IRPF, COD_OFICINA, OFICINA, COMISION, TIPO_INFORME, IMPORTE, SECUENCIAL, NUMERO, RESTO_DOMICILIO)
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE 
                            WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END) 
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J'
                            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
	                            AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END AS IRPF,   
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        SUM(PAY.VALUE) AS IMPORTE,
                        0 AS SECUENCIAL,
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        PAD_INS.NUMERO,
                        PAD_INS.RESTO_DOMICILIO
                    FROM (SELECT DISTINCT  
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
							--BRG 20260210 Modificación por indicencia facturas duplicadas, correo Cristian 20260209
                            MAX(X.CUADRO_RRGG_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRGG_OCASO,
                            MAX(X.CUADRO_RRTT_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRTT_OCASO,
							X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                        FROM :TBL_AGENTES_PRIN_MES X 
                        INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ 
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                    ) PAD_INS
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME
                    --ALM 20160908: Solo cogemos agentes con pagos
                    --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                    INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                        AND PAY.TENANTID = :v_idtenant
                        --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                        --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                        AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                        AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot 
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)    
                    --WHERE PAD_INS.PERIODSEQ = :i_PeriodSeq
                    GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END) 
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907: Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' 
	                            --BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
	                            AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END,   
                        PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2),
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.OUT_S4_FACTURA_REP(PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, NIF, NOMBRE, MUNICIPIO, DOMICILIO, CP, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, IRPF, COD_OFICINA, OFICINA, COMISION, TIPO_INFORME, IMPORTE, SECUENCIAL, NUMERO, RESTO_DOMICILIO)
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                            WHEN PAD_INS.TIPO_PERSONA = 'J' 
                            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                            	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END AS IRPF,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        PAD_OF.POSITIONNAME AS COD_OFICINA,
                        PAD_OF.LASTNAME AS OFICINA,
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        sum(CAR_LP.importe) as importe, --SUM(PAY.VALUE) AS IMPORTE
                        0 AS SECUENCIAL,
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        PAD_INS.NUMERO,
                        PAD_INS.RESTO_DOMICILIO
                    FROM (SELECT DISTINCT
                        x.startdate, x.pos_callidus, -- variables añadidas, daba error al no encontrarlas
                        X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                            --BRG 20260210 Modificación por indicencia facturas duplicadas, correo Cristian 20260209
                            MAX(X.CUADRO_RRGG_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRGG_OCASO,
                            MAX(X.CUADRO_RRTT_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRTT_OCASO,
							X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                        FROM :TBL_AGENTES_PRIN_MES X
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                        WHERE Y.POSITIONSEQ IS NULL
                    ) PAD_INS
                    INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                        --LLS 20220125: Filtro para tener solo Ocaso
                        AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
                        --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                        --ATV 20250205 Anyadimos el estado N
                        --ATV 20250313 Quitamos el estado N
                        AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
                        --AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO IN ('C', 'N')))
                        --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                        AND CAR_LP.IMPORTE <> 0
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    GROUP BY
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                            WHEN PAD_INS.TIPO_PERSONA = 'J' 
                            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                            	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        PAD_OF.POSITIONNAME,
                        PAD_OF.LASTNAME,
                        EC.DESCRIPTION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2),
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                    --ATV 20250321 Modificamos para evitar facturas a 0
                    HAVING SUM(CAR_LP.importe) <> 0;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                
                -- BRG 20250527: INYC_S5_FACTURA pasa a ser OUT_S5_FACTURA_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                DELETE FROM EXT.OUT_S5_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.OUT_S5_FACTURA_REP(PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, NIF, NOMBRE, MUNICIPIO, DOMICILIO, CP, POS_PRIN, CUADRO_INSP, COMPANIA, IRPF, COD_OFICINA, OFICINA, COMISION, TIPO_INFORME, IMPORTE, SECUENCIAL, NUMERO, RESTO_DOMICILIO)
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_INSP_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                        --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                        THEN 0 ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' 
                            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                            	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END AS IRPF,   
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        SUM(PAY.VALUE) AS IMPORTE,
                        0 AS SECUENCIAL,
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        PAD_INS.NUMERO,
                        PAD_INS.RESTO_DOMICILIO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME   
                    INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ = PAY.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                        AND PAY.TENANTID = :v_idtenant
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    WHERE SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                        AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S5'
                    GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.BOUSERID,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_INSP_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                        --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                        THEN 0 ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' 
                            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                            	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END,   
                        PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2),
                        PAD_INS.NUMERO,
                        PAD_INS.RESTO_DOMICILIO;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                
                --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_S4_FACTURA
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL OUT_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                UPDATE EXT.OUT_S4_FACTURA_REP F
                    SET SECUENCIAL = 1 + (
                        SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                        FROM (
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_LC_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_LC_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            ) Y 
					)
					WHERE F.PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL OUT_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_S4_FACTURA_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');

                --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_S5_FACTURA
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL OUT_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                UPDATE EXT.OUT_S5_FACTURA_REP F
                    SET SECUENCIAL = 1 + (
                        SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                        FROM (
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_LC_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_LC_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            ) Y 
                    )
					WHERE F.PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL OUT_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_S5_FACTURA_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');


				-- ETERNA
                -- BRG 20250528: INYC_S4_E_FACTURA pasa a ser OUT_S4_E_FACTURA_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                DELETE FROM EXT.OUT_S4_E_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.OUT_S4_E_FACTURA_REP(PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, NIF, NOMBRE, MUNICIPIO, DOMICILIO, CP, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, IRPF, COD_OFICINA, OFICINA, COMISION, TIPO_INFORME, IMPORTE, SECUENCIAL)
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                        SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' 
                            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                            	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END AS IRPF,   
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        SUM(PAY.VALUE) AS IMPORTE,
                        0 AS SECUENCIAL
                    FROM (SELECT DISTINCT  
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                            X.CUADRO_RRGG_ETERNA,X.CUADRO_RRTT_ETERNA,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                        FROM :TBL_AGENTES_PRIN_MES X 
                        INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ 
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                    ) PAD_INS
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME
                    --ALM 20160908: Solo cogemos agentes con pagos
                    --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                    INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                        AND PAY.TENANTID = :v_idtenant
                        --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                        --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                        AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '03'
                        AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                        SUBSTR(PAY.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' 
                            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
	                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                            	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END,   
                        PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2);
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.OUT_S4_E_FACTURA_REP(PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, NIF, NOMBRE, MUNICIPIO, DOMICILIO, CP, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, IRPF, COD_OFICINA, OFICINA, COMISION, TIPO_INFORME, IMPORTE, SECUENCIAL)
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END AS IRPF,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        PAD_OF.POSITIONNAME AS COD_OFICINA,
                        PAD_OF.LASTNAME AS OFICINA,
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        sum(CAR_LP.importe) as importe,--SUM(PAY.VALUE) AS IMPORTE
                        0 AS SECUENCIAL
                    FROM (SELECT DISTINCT
                            x.startdate, x.pos_callidus, --variables a�adidas, daba error al no encontrarlas 
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                            --BRG 20260210 Modificación por indicencia facturas duplicadas, correo Cristian 20260209
                            MAX(X.CUADRO_RRGG_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRGG_OCASO,
                            MAX(X.CUADRO_RRTT_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRTT_OCASO,
							X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                        FROM :TBL_AGENTES_PRIN_MES X
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                        WHERE Y.POSITIONSEQ IS NULL
                    ) PAD_INS
                    INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                        --LLS 20220125: Filtro para tener solo Eterna
                        AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03'
                        --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                        AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
                        --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                        AND CAR_LP.IMPORTE <> 0
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    GROUP BY
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        --SUBSTR(CAR_LP.COD_AGENTE, 1, 4),
                        PAD_OF.POSITIONNAME,
                        PAD_OF.LASTNAME,
                        EC.DESCRIPTION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2)
                    --ATV 20250321 Modificamos para evitar facturas a 0
                    HAVING SUM(CAR_LP.importe) <> 0;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_S4_E_FACTURA
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL OUT_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                UPDATE EXT.OUT_S4_E_FACTURA_REP F
                    SET SECUENCIAL = 1 + (
                        SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                        FROM (
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_S4_E_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.OUT_LC_S4_E_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                    AND P.REMOVEDATE = :v_eot)
                            ) Y 
                    )
					WHERE F.PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL OUT_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_S4_E_FACTURA_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');

            ELSE
                --ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria            
                IF v_periodo_finalizado = 0 THEN
                    -- OCASO
					-- BRG 20250527: INYC_LC_S4_FACTURA pasa a ser OUT_LC_S4_FACTURA_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.OUT_LC_S4_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_LC_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_FACTURA_REP(PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, NIF, NOMBRE, MUNICIPIO, DOMICILIO, CP, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, IRPF, COD_OFICINA, OFICINA, COMISION, TIPO_INFORME, IMPORTE, SECUENCIAL, NUMERO, RESTO_DOMICILIO)
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END AS IRPF,   
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            SUM(PAY.VALUE) AS IMPORTE,
                            0 AS SECUENCIAL,
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                        FROM (SELECT DISTINCT  
                                X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                                --BRG 20260210 Modificación por indicencia facturas duplicadas, correo Cristian 20260209
								MAX(X.CUADRO_RRGG_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRGG_OCASO,
								MAX(X.CUADRO_RRTT_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRTT_OCASO,
								X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                            FROM :TBL_AGENTES_PRIN_MES X 
                            INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ 
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                                --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                                AND (Y.POSTPIPELINERUNSEQ IS NULL
                                    --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                    OR (v_periodo_posteado > 1
                                        AND Y.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        ) PAD_INS
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME 
                        --ALM 20160908: Solo cogemos agentes con pagos
                        --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                        INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                            AND PAY.TENANTID = :v_idtenant
                            --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                            --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                            AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                            --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                            AND (PAY.POSTPIPELINERUNSEQ IS NULL
                                --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                OR (v_periodo_posteado > 1
                                    AND PAY.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot 
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)    
                        GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END,   
                            PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2),
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_FACTURA_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, NIF, NOMBRE, MUNICIPIO, DOMICILIO, CP, POS_PRIN, CUADRO_RRGG, CUADRO_RRTT, COMPANIA, IRPF, COD_OFICINA, OFICINA, COMISION, TIPO_INFORME, IMPORTE, SECUENCIAL, NUMERO, RESTO_DOMICILIO)
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END AS IRPF,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,
                            PAD_OF.LASTNAME AS OFICINA,
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            sum(CAR_LP.importe) as importe,
                            0 AS SECUENCIAL,
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        FROM (SELECT DISTINCT
								x.startdate, x.pos_callidus, -- variables a�adidas, daba error al no encontrarlas 
								X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
								--BRG 20260210 Modificación por indicencia facturas duplicadas, correo Cristian 20260209
								MAX(X.CUADRO_RRGG_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRGG_OCASO,
								MAX(X.CUADRO_RRTT_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRTT_OCASO,
								X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                            FROM :TBL_AGENTES_PRIN_MES X
                            --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                            LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                            WHERE Y.POSITIONSEQ IS NULL
                        ) PAD_INS
                        INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                            --LLS 20220125: Filtro para tener solo Ocaso
                            AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
                            --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                            AND CAR_LP.ESTADO = 'C'
                            --ALM 20220425: Filtramos para datos no posteados asi evitamos coger los ya pagados en el cierre.
                            AND CAR_LP.SEQ_POST IS NULL
                            --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                            AND CAR_LP.IMPORTE <> 0
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        GROUP BY
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END,
                            PAD_OF.POSITIONNAME,
                            PAD_OF.LASTNAME,
                            EC.DESCRIPTION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2),
                            --ATV 20250509 Anyadimos los campos numero y rersto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                        --ATV 20250321 Modificamos para evitar facturas a 0
                        HAVING SUM(CAR_LP.importe) <> 0;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                
					-- BRG 20250527: INYC_LC_S5_FACTURA pasa a ser OUT_LC_S5_FACTURA_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.OUT_LC_S5_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_LC_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S5_FACTURA_REP (PARTICIPANTSEQ , POSITIONSEQ_PRIN , PERIODSEQ , PERIODO , BOUSERID , NIF , NOMBRE , MUNICIPIO , DOMICILIO , CP , POS_PRIN , CUADRO_INSP , COMPANIA , IRPF , COD_OFICINA , OFICINA , COMISION , TIPO_INFORME , IMPORTE , SECUENCIAL , NUMERO , RESTO_DOMICILIO)
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_INSP_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                            THEN 0 ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END AS IRPF,   
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            SUM(PAY.VALUE) AS IMPORTE,
                            0 AS SECUENCIAL,
                            --ATV 20250509 Anyadimos los campos numero y rersto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME   
                        INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ = PAY.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                            AND PAY.TENANTID = :v_idtenant
                            --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                            AND (PAY.POSTPIPELINERUNSEQ IS NULL
                                --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                OR (v_periodo_posteado > 1
                                    AND PAY.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        WHERE SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S5'
                        GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.BOUSERID,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_INSP_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                            THEN 0 ELSE IRPF.GENERICNUMBER1 END)
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907: Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END,   
                            PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2),
                            --ATV 20250509 Anyadimos los campos numero y rersto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_LC_S4_FACTURA
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL OUT_LC_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    UPDATE EXT.OUT_LC_S4_FACTURA_REP F
                        SET SECUENCIAL = 1 + (
                            SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                            FROM (
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_LC_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_LC_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                ) Y 
                        )
						WHERE F.PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL OUT_LC_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_S4_FACTURA_REP');
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');

                    --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_LC_S5_FACTURA
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL OUT_LC_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    UPDATE EXT.OUT_LC_S5_FACTURA_REP F
                        SET SECUENCIAL = 1 + (
                            SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                            FROM (
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_LC_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_LC_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                ) Y 
                        )
						WHERE F.PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL OUT_LC_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_S5_FACTURA_REP');
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S5_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');


					-- ETERNA
                    -- BRG 20250528: INYC_LC_S4_E_FACTURA pasa a ser OUT_LC_S4_E_FACTURA_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.OUT_LC_S4_E_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_LC_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_E_FACTURA_REP(PARTICIPANTSEQ ,POSITIONSEQ_PRIN ,PERIODSEQ ,PERIODO ,BOUSERID ,NIF ,NOMBRE ,MUNICIPIO ,DOMICILIO ,CP ,POS_PRIN ,CUADRO_RRGG ,CUADRO_RRTT ,COMPANIA ,IRPF ,COD_OFICINA ,OFICINA ,COMISION ,TIPO_INFORME ,IMPORTE ,SECUENCIAL)
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END AS IRPF,   
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            SUM(PAY.VALUE) AS IMPORTE,
                            0 AS SECUENCIAL
                        FROM (SELECT DISTINCT  
                                X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                                X.CUADRO_RRGG_ETERNA,X.CUADRO_RRTT_ETERNA,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                            FROM :TBL_AGENTES_PRIN_MES X 
                            INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ 
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                                --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                                AND (Y.POSTPIPELINERUNSEQ IS NULL
                                    --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                    OR (v_periodo_posteado > 1
                                        AND Y.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        ) PAD_INS
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME 
                        --ALM 20160908: Solo cogemos agentes con pagos
                        --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                        INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                            AND PAY.TENANTID = :v_idtenant
                            --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                            --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                            AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                            --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                            AND (PAY.POSTPIPELINERUNSEQ IS NULL
                                --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                OR (v_periodo_posteado > 1
                                    AND PAY.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        --WHERE PAD_INS.PERIODSEQ = :i_PeriodSeq
                        GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(PAY.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V') 
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END,   
                            PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2);
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
    
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_LC_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.OUT_LC_S4_E_FACTURA_REP(PARTICIPANTSEQ ,POSITIONSEQ_PRIN ,PERIODSEQ ,PERIODO ,BOUSERID ,NIF ,NOMBRE ,MUNICIPIO ,DOMICILIO ,CP ,POS_PRIN ,CUADRO_RRGG ,CUADRO_RRTT ,COMPANIA ,IRPF ,COD_OFICINA ,OFICINA ,COMISION ,TIPO_INFORME ,IMPORTE ,SECUENCIAL)
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), '') AS NOMBRE,
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END AS IRPF,
                            --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                            --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                            PAD_OF.POSITIONNAME AS COD_OFICINA,
                            PAD_OF.LASTNAME AS OFICINA,
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            sum(CAR_LP.importe) as importe,--SUM(PAY.VALUE) AS IMPORTE
                            0 AS SECUENCIAL
                        FROM (SELECT DISTINCT
                            	x.startdate, x.pos_callidus, -- variables a�adidas, daba error al no encontrarlas 
                            	X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                                --BRG 20260210 Modificación por indicencia facturas duplicadas, correo Cristian 20260209
								MAX(X.CUADRO_RRGG_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRGG_OCASO,
								MAX(X.CUADRO_RRTT_OCASO) OVER (PARTITION BY X.PARTICIPANTSEQ, X.POSITIONSEQ_PRIN, X.PERIODSEQ, X.POS_PRIN) AS CUADRO_RRTT_OCASO,
								X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                            FROM :TBL_AGENTES_PRIN_MES X
                            --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                            LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                            WHERE Y.POSITIONSEQ IS NULL
                        ) PAD_INS
                        INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                            --LLS 20220125: Filtro para tener solo Eterna
                            AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03'
                            --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                            AND CAR_LP.ESTADO = 'C'
                            --ALM 20220425: Filtramos para datos no posteados asi evitamos coger los ya pagados en el cierre.
                            AND CAR_LP.SEQ_POST IS NULL
                            --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                            AND CAR_LP.IMPORTE <> 0
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR(15)) END) = IRPF.NAME
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        GROUP BY
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX), ''),
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' 
                                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		                            --AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') 
		                            AND SUBSTR(PAD_INS.NIF, 1, 1) IN ('J','E','V')
                                	AND PAD_INS.NIF NOT IN ('J72106826','J45884319') ----20260430 IBM Añadimos NIF J45884319
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END,
                            --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                            --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                            PAD_OF.POSITIONNAME,
                            PAD_OF.LASTNAME,
                            EC.DESCRIPTION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2)
                        --ATV 20250321 Modificamos para evitar facturas a 0
                        HAVING SUM(CAR_LP.importe) <> 0;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_LC_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_LC_S4_E_FACTURA
					CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL OUT_LC_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    UPDATE EXT.OUT_LC_S4_E_FACTURA_REP F
                        SET SECUENCIAL = 1 + (
                            SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                            FROM (
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_S4_E_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.OUT_LC_S4_E_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || RIGHT(F.PERIODO,4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || RIGHT(F.PERIODO,4)
                                        AND P.REMOVEDATE = :v_eot)
                                ) Y 
                        )
						WHERE F.PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL OUT_LC_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');
                    CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_S4_E_FACTURA_REP');
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_S4_E_FACTURA_REP.', i_log_count, i_id_proceso, 'debug');

                    
                END IF;
                
            END IF;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informes S4 Factura', i_log_count, i_id_proceso, 'info');
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informes S5 Factura', i_log_count, i_id_proceso, 'info');
            
            -- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

        -- Fin informes S4 y S5 Factura
		END IF;

		---------------------------------------------------------------------------------------------------------------------------------------
		-- DTB 20251021: TABLAS PARA INFORME S4 Percepciones Resumen	
		
		IF :i_lista_informes = 'PEPA' OR :i_lista_informes LIKE '%|PEPA|%' OR :i_lista_informes LIKE '%|PEPA' OR :i_lista_informes LIKE 'PEPA|%' OR :i_lista_informes = 'ALL' THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe S4 Percepciones Resumen.', i_log_count, i_id_proceso, 'info');
			IF v_periodo_posteado = 0 THEN
			
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Borrado OUT_PEPA_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_PEPA_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Borrado OUT_PEPA_RESUMEN_REP: Filas borradas: '|| :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_PEPA_RESUMEN_REP. Percepciones.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID) 
					SELECT 
						PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
						PAD_INS.BOUSERID,
						PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,
						PAD_INS.TIPO_AGENTE,
						PAD_INS.CUADRO_RRGG_OCASO,
						PAD_INS.CUADRO_RRTT_OCASO,
						PAD_INS.PROMOCION,
						PAD_INS.SUPERRAPEL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						PERC.DESCRIPCION AS COMISION,
						D.VALUE AS IMPORTE,
						(SELECT EXTRACT(MONTH FROM PD.STARTDATE) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ 
						AND PD.REMOVEDATE = to_date('22000101','yyyymmdd')) AS PERIODO_DEPOSITO,                
						'' AS N_MEDIDA,
						0 AS V_MEDIDA,
						D.EARNINGCODEID,
						D.EARNINGGROUPID
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
						AND D.PERIODSEQ IN (SELECT PD.PERIODSEQ FROM TCMP.CS_PERIOD PD WHERE PD.REMOVEDATE = to_date('22000101','yyyymmdd') 
												AND RIGHT(PD.NAME,4) = RIGHT(PAD_INS.PERIODO,4)
												AND PD.STARTDATE <= PAD_INS.STARTDATE
												--Filtramos por el tipo de periodo para quedarnos solo los meses
												AND PD.PERIODTYPESEQ = 2814749767106561)
						AND D.TENANTID = :v_idtenant
						--AND D.VALUE <> 0
						AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
						--ALM 20170309: A peticion de Alfonso filtramos por los depositos del S4
						AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S4'
						--ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
						AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
					--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
					INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
					INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
						AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
						AND D.EARNINGGROUPID = PERC.EARNINGGROUP
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					;
				v_num_rows := ::ROWCOUNT;                     
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_PEPA_RESUMEN_REP. Percepciones. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_PEPA_RESUMEN_REP. Balances.', i_log_count,i_id_proceso,'debug');
				INSERT INTO EXT.OUT_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID) 
					SELECT 
						PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ AS POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
						PAD_INS.BOUSERID,
						PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,
						PAD_INS.TIPO_AGENTE,
						PAD_INS.CUADRO_RRGG_OCASO,
						PAD_INS.CUADRO_RRTT_OCASO,
						PAD_INS.PROMOCION,PAD_INS.SUPERRAPEL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						--ALM 20170526: Introduccimos el mes del que proviene el balance
						--'Regularizacion meses anteriores ' || INITCAP(EC.DESCRIPTION) AS COMISION,
						'Balance ' || (SELECT PER.NAME FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
							AND PER.PERIODSEQ = B.PERIODSEQ) ||' - ' || INITCAP(EC.DESCRIPTION) AS COMISION,
						B.VALUE AS IMPORTE,
						EXTRACT(MONTH FROM PAD_INS.STARTDATE) AS PERIODO_DEPOSITO,                
						'Balance' AS N_MEDIDA,
						0 AS V_MEDIDA,
						B.EARNINGCODEID,B.EARNINGGROUPID
					--ALM 20170523: Modificamos la carga para coger la jerarquia del mes en ejecucion no la de cuando se realizo el balance
					--FROM TCMP.CSA_PADIMENSION PAD_INS
					--INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON PAD_INS.PERIODSEQ = PD.PERIODSEQ AND PD.TENANTID = :v_idtenant
					FROM :TBL_AGENTES_PRIN_MES PAD_INS 
					INNER JOIN TCMP.CS_BALANCE B ON PAD_INS.POSITIONSEQ = B.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = B.PAYEESEQ
						--ALM 20170516: No filtramos por el PERIODSEQ de los balances sino por las fechas de posteado para aplicarlos a un mes u otro
						--AND B.PERIODSEQ IN (SELECT PER.PERIODSEQ FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
						--                        AND RIGHT(PER.NAME,4) = RIGHT(PD.NAME,4)
						--                        AND PER.STARTDATE <= PD.STARTDATE
						--                        --Filtramos por el tipo de periodo para quedarnos solo los meses
						--                        AND PER.PERIODTYPESEQ = 2814749767106561)
						AND B.POSTPIPELINERUNDATE < (SELECT PER.ENDDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
							AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
						AND B.POSTPIPELINERUNDATE > (SELECT PER.STARTDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
							AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
						AND B.TENANTID = :v_idtenant
						--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
						AND B.PROCESSINGUNITSEQ = 38280596832649217
						--AND D.VALUE <> 0
						AND SUBSTR(B.EARNINGGROUPID,7,2) = '01'
						--ALM 20170309: A peticion de Alfonso filtramos por los depositos del S4
						AND SUBSTR(B.EARNINGGROUPID,4,2) = 'S4'
						--ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
						AND SUBSTR(B.EARNINGCODEID,1,3) <> '801'
					--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
					INNER JOIN TCMP.CS_PLRUN PL ON B.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
						AND PL.TENANTID = :v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217
					--ALM 20170609: Unimos los balances con los pagos para filtrar balances que finalmente no se abonen en el periodo
					--ALM 20211126: Comentamos estas inner porque provocan errores en el proceso para el cierre de noviembre 2021.
					/*
					INNER JOIN TCMP.CS_BALANCEPAYMENTTRACE BPAY ON B.BALANCESEQ = BPAY.BALANCESEQ
						--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
						AND BPAY.TENANTID = :v_idtenant AND BPAY.PROCESSINGUNITSEQ = 38280596832649217
						AND BPAY.TARGETPERIODSEQ = :i_PeriodSeq
					INNER JOIN :TBL_PAGOS_MES PAY ON BPAY.PAYMENTSEQ = PAY.PAYMENTSEQ
					*/
					INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(B.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
						AND EC.TENANTID = :v_idtenant
						AND EC.REMOVEDATE = :v_eot 
					--ALM 20170427: No podemos unir con las percepciones porque no podemos diferenciar entre depositos del mismo earningcode y earninggroup
					--INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
					--    AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
					--    AND D.EARNINGGROUPID = PERC.EARNINGGROUP
					--ALM 20170307: Modificamos la obtencion de la regional, sucursal y oficina de los agentes 
					--              debido a la existencia de Puntos de Venta ocasionales dependientes de algunas oficinas
					--LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
					--    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ 
					--ALM 20170427: Para los balances no filtramos por tipologias porque pueden haber cambiado. Devolvemos todos los balances.
					--INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.POSITIONGENERICNUMBER2 = AG.ID_TIPO_AGENTE
					--    AND AG.COD_INFORME = 104
					--    AND AG.F_INICIO <= PD.STARTDATE AND  AG.F_FIN > PD.STARTDATE
					--ALM 20170427: Filtramos por el periodo anterior al atual
					--ALM 20170523: No hace falta filtrar porque ya viene filtrada la tabla temporal principal por el periodo actual
					--WHERE PAD_INS.PERIODSEQ = (SELECT MAX(PER.PERIODSEQ) FROM TCMP.CS_PERIOD PER
					--                            INNER JOIN TCMP.CS_PERIODTYPE PT ON PER.PERIODTYPESEQ = PT.PERIODTYPESEQ AND PT.REMOVEDATE = :v_eot
					--                            WHERE PER.REMOVEDATE = :v_eot AND PT.NAME = 'month' AND PER.PERIODSEQ < :i_PeriodSeq)
					;
				v_num_rows := ::ROWCOUNT;           
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_PEPA_RESUMEN_REP. Balances: Filas: ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_PEPA_RESUMEN_REP. Medidas Agentes.', :i_log_count, :i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
						PAD_INS.BOUSERID,
						PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						PAD_INS.CUADRO_RRGG_OCASO,
						PAD_INS.CUADRO_RRTT_OCASO,
						PAD_INS.PROMOCION,
						PAD_INS.SUPERRAPEL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						'' AS COMISION,
						0 AS IMPORTE,
						0 AS IMPORTE_ACUMULADO,
						M.NAME AS N_MEDIDA,
						M.VALUE AS V_MEDIDA,
						'' AS EARNINGCODEID,
						'' AS EARNINGGROUPID
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						AND PAD_INS.PERIODSEQ = M.PERIODSEQ 
						AND M.TENANTID = :v_idtenant
						AND M.VALUE <> 0
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 104.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					;		
				v_num_rows := ::ROWCOUNT;           
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_PEPA_RESUMEN_REP. Medidas Agente: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
		
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_PEPA_RESUMEN_REP. DERECHOS ECONOMICOS', :i_log_count, :i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
						PAD_INS.BOUSERID,
						PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,
						PAD_INS.TIPO_AGENTE,
						PAD_INS.CUADRO_RRGG_OCASO,
						PAD_INS.CUADRO_RRTT_OCASO,
						PAD_INS.PROMOCION,
						PAD_INS.SUPERRAPEL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						'Comisiones Cartera DDEE' AS COMISION,
						SUM(CAR_LP.IMPORTE) AS IMPORTE,
						MONTH(CAR_LP.COMPENSATIONDATE) AS PERIODO_DEPOSITO,  --DTB 20260511 Hay que guardar el mes de cartera              
						'' AS N_MEDIDA,
						0 AS V_MEDIDA,
						CAR_LP.EARNINGCODEID,
						CAR_LP.EARNINGGROUPID
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME
					--DTB 20260511 Se incluyen periodos anteriores de ese año
						AND YEAR(PAD_INS.STARTDATE) = YEAR(CAR_LP.COMPENSATIONDATE)
						AND PAD_INS.STARTDATE >= CAR_LP.COMPENSATIONDATE
					--DTB 20260511 Fin del cambio
						AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
						AND SUBSTR(CAR_LP.EARNINGGROUPID,4,2) = 'S4'
						AND SUBSTR(CAR_LP.EARNINGCODEID,1,3) <> '801'
						--ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
						AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
						--ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
						AND CAR_LP.IMPORTE <> 0
					--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
					LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
							AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
							AND Y.TENANTID = :v_idtenant
							AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
							AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
					WHERE Y.POSITIONSEQ IS NULL
					GROUP BY
						PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
						PAD_INS.BOUSERID,
						PAD_INS.NIF,
						IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),''), 
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,
						PAD_INS.TIPO_AGENTE,
						PAD_INS.CUADRO_RRGG_OCASO,
						PAD_INS.CUADRO_RRTT_OCASO,
						PAD_INS.PROMOCION,
						PAD_INS.SUPERRAPEL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END,
						MONTH(CAR_LP.COMPENSATIONDATE),                
						CAR_LP.EARNINGCODEID,
						CAR_LP.EARNINGGROUPID;		
				v_num_rows := ::ROWCOUNT;           	
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_PEPA_RESUMEN_REP. DERECHOS ECONOMICOS: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
					
				--ALM 20220221: Quitamos el uso del parametro v_licencias para reducir codigo.
				--END IF;
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PEPA_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_PEPA_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PEPA_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
					
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
				
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Borrado OUT_LC_PEPA_RESUMEN_REP.', :i_log_count, :i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_PEPA_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					
					v_num_rows := ::ROWCOUNT;           
					
					
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Borrado OUT_LC_PEPA_RESUMEN_REP: Filas: ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
					
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_LC_PEPA_RESUMEN_REP. Percepciones.', :i_log_count, :i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							PERC.DESCRIPCION AS COMISION,D.VALUE AS IMPORTE,
							(SELECT EXTRACT(MONTH FROM PD.STARTDATE) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ AND PD.REMOVEDATE = :v_eot) AS PERIODO_DEPOSITO,                
							'' AS N_MEDIDA,
							0 AS V_MEDIDA,
							D.EARNINGCODEID,
							D.EARNINGGROUPID
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
							AND D.PERIODSEQ IN (SELECT PD.PERIODSEQ FROM TCMP.CS_PERIOD PD WHERE PD.REMOVEDATE = to_date('22000101','yyyymmdd') 
													AND RIGHT(PD.NAME,4) = RIGHT(PAD_INS.PERIODO,4)
													AND PD.STARTDATE <= PAD_INS.STARTDATE
													--Filtramos por el tipo de periodo para quedarnos solo los meses
													AND PD.PERIODTYPESEQ = 2814749767106561)
							AND D.TENANTID = :v_idtenant
							--AND D.VALUE <> 0
							AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
							--ALM 20170309: A peticion de Alfonso filtramos por los depositos del S4
							AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S4'
							--ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
							AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
							AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
							AND D.EARNINGGROUPID = PERC.EARNINGGROUP
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						;
					v_num_rows := ::ROWCOUNT;           
							
						
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_LC_PEPA_RESUMEN_REP. Percepciones: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
					
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_LC_PEPA_RESUMEN_REP. Balances.', :i_log_count, :i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID) 
						SELECT 
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ AS POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							'Balance ' || (SELECT PER.NAME FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
								AND PER.PERIODSEQ = B.PERIODSEQ) ||' - ' || INITCAP(EC.DESCRIPTION) AS COMISION,
							B.VALUE AS IMPORTE,
							EXTRACT(MONTH FROM PAD_INS.STARTDATE) AS PERIODO_DEPOSITO,                
							'Balance' AS N_MEDIDA,
							0 AS V_MEDIDA,
							B.EARNINGCODEID,
							B.EARNINGGROUPID
						FROM :TBL_AGENTES_PRIN_MES PAD_INS 
						INNER JOIN TCMP.CS_BALANCE B ON PAD_INS.POSITIONSEQ = B.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = B.PAYEESEQ
							AND B.POSTPIPELINERUNDATE < (SELECT PER.ENDDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
								AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
							AND B.POSTPIPELINERUNDATE > (SELECT PER.STARTDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
								AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
							AND B.TENANTID = :v_idtenant
							--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
							AND B.PROCESSINGUNITSEQ = 38280596832649217
							--AND D.VALUE <> 0
							AND SUBSTR(B.EARNINGGROUPID,7,2) = '01'
							--ALM 20170309: A peticion de Alfonso filtramos por los depositos del S4
							AND SUBSTR(B.EARNINGGROUPID,4,2) = 'S4'
							--ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
							AND SUBSTR(B.EARNINGCODEID,1,3) <> '801'
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON B.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
						AND PL.TENANTID = :v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217
						--ALM 20170609: Unimos los balances con los pagos para filtrar balances que finalmente no se abonen en el periodo
						INNER JOIN TCMP.CS_BALANCEPAYMENTTRACE BPAY ON B.BALANCESEQ = BPAY.BALANCESEQ
						--ALM 20211025: Anadimos condicion para mejorar el rendimeinto de la consulta
						AND BPAY.TENANTID = :v_idtenant AND BPAY.PROCESSINGUNITSEQ = 38280596832649217
						AND BPAY.TARGETPERIODSEQ = :i_PeriodSeq
						INNER JOIN :TBL_PAGOS_MES PAY ON BPAY.PAYMENTSEQ = PAY.PAYMENTSEQ
						INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(B.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
							AND EC.TENANTID = :v_idtenant
							AND EC.REMOVEDATE = :v_eot 
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						;
					v_num_rows := ::ROWCOUNT;           
							
						
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_LC_PEPA_RESUMEN_REP. Balances: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
					
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_LC_PEPA_RESUMEN_REP. Medidas Agentes.', :i_log_count, :i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							'' AS COMISION,
							0 AS IMPORTE,
							0 AS IMPORTE_ACUMULADO,
							M.NAME AS N_MEDIDA,
							M.VALUE AS V_MEDIDA,
							'' AS EARNINGCODEID,
							'' AS EARNINGGROUPID
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							AND PAD_INS.PERIODSEQ = M.PERIODSEQ 
							AND M.TENANTID = :v_idtenant
							AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 104.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						;
								
					v_num_rows := ::ROWCOUNT;           
							
						
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_LC_PEPA_RESUMEN_REP. Medidas Agente: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
				
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_LC_PEPA_RESUMEN_REP. DERECHOS ECONOMICOS', :i_log_count, :i_id_proceso, 'debug');
		
					INSERT INTO EXT.OUT_LC_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							'Comisiones Cartera DDEE' AS COMISION,
							SUM(CAR_LP.IMPORTE) AS IMPORTE,
							MONTH(CAR_LP.COMPENSATIONDATE) AS PERIODO_DEPOSITO,  --DTB 20260511 Hay que guardar el mes de cartera              
							'' AS N_MEDIDA,
							0 AS V_MEDIDA,
							CAR_LP.EARNINGCODEID,
							CAR_LP.EARNINGGROUPID
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME
						--DTB 20260511 Se incluyen periodos anteriores de ese año
						AND YEAR(PAD_INS.STARTDATE) = YEAR(CAR_LP.COMPENSATIONDATE)
						AND PAD_INS.STARTDATE >= CAR_LP.COMPENSATIONDATE
						--DTB 20260511 Fin del cambio 
							AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
							AND SUBSTR(CAR_LP.EARNINGGROUPID,4,2) = 'S4'
							AND SUBSTR(CAR_LP.EARNINGCODEID,1,3) <> '801'
							--ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
							AND CAR_LP.ESTADO = 'C'
							--ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
							AND CAR_LP.IMPORTE <> 0
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
							AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
							AND Y.TENANTID = :v_idtenant
							AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
							AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						WHERE Y.POSITIONSEQ IS NULL
						GROUP BY
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),''), 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END,
							MONTH(CAR_LP.COMPENSATIONDATE),                
							CAR_LP.EARNINGCODEID,
							CAR_LP.EARNINGGROUPID;
							
					v_num_rows := ::ROWCOUNT;           
							
							
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_LC_PEPA_RESUMEN_REP. DERECHOS ECONOMICOS: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
						
					--ALM 20220221: Quitamos el uso del parametro v_licencias para reducir codigo.
					--END IF;
					
				
					--Actualizamos el parametro de ultima actualizacion en la tabla INYC_FECHAS_WEBI 
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_PEPA_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_PEPA_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_PEPA_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');        
				
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
			
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Borrado OUT_BAL_PEPA_RESUMEN_REP.', :i_log_count, :i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_PEPA_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					
					v_num_rows := ::ROWCOUNT;           
					
					
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Borrado OUT_BAL_PEPA_RESUMEN_REP: Filas: ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
					
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_BAL_PEPA_RESUMEN_REP. Percepciones.', :i_log_count, :i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID) 
						SELECT 
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							PERC.DESCRIPCION AS COMISION,
							D.VALUE AS IMPORTE,
							(SELECT EXTRACT(MONTH FROM PD.STARTDATE) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ AND PD.REMOVEDATE = :v_eot) AS PERIODO_DEPOSITO,                
							'' AS N_MEDIDA,
							0 AS V_MEDIDA,
							D.EARNINGCODEID,
							D.EARNINGGROUPID
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
							AND D.PERIODSEQ IN (SELECT PD.PERIODSEQ FROM TCMP.CS_PERIOD PD WHERE PD.REMOVEDATE = to_date('22000101','yyyymmdd') 
													AND RIGHT(PD.NAME,4) = RIGHT(PAD_INS.PERIODO,4)
													AND PD.STARTDATE <= PAD_INS.STARTDATE
													--Filtramos por el tipo de periodo para quedarnos solo los meses
													AND PD.PERIODTYPESEQ = 2814749767106561)
							AND D.TENANTID = :v_idtenant
							--AND D.VALUE <> 0
							AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
							--ALM 20170309: A peticion de Alfonso filtramos por los depositos del S4
							AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S4'
							--ALM 20170309: A peticion de Alfonso excluimos el concepto de pago 801 porque van despues del calculo del IRPF
							AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
							AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
							AND D.EARNINGGROUPID = PERC.EARNINGGROUP
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						;
					v_num_rows := ::ROWCOUNT;           
							
						
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_BAL_PEPA_RESUMEN_REP. Percepciones: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
					
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_BAL_PEPA_RESUMEN_REP. Medidas Agentes.', :i_log_count, :i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							'' AS COMISION,
							0 AS IMPORTE,
							0 AS IMPORTE_ACUMULADO,
							M.NAME AS N_MEDIDA,
							M.VALUE AS V_MEDIDA,
							'' AS EARNINGCODEID,
							'' AS EARNINGGROUPID
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							AND PAD_INS.PERIODSEQ = M.PERIODSEQ 
							AND M.TENANTID = :v_idtenant
							AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 104.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						;
								
					v_num_rows := ::ROWCOUNT;           
							
						
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_BAL_PEPA_RESUMEN_REP. Medidas Agente: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
				
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_BAL_PEPA_RESUMEN_REP. DERECHOS ECONOMICOS', :i_log_count, :i_id_proceso, 'debug');
		
					INSERT INTO EXT.OUT_BAL_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							'Comisiones Cartera DDEE' AS COMISION,
							SUM(CAR_LP.IMPORTE) AS IMPORTE,
							MONTH(CAR_LP.COMPENSATIONDATE) AS PERIODO_DEPOSITO,  --DTB 20260511 Hay que guardar el mes de cartera                
							'' AS N_MEDIDA,
							0 AS V_MEDIDA,
							CAR_LP.EARNINGCODEID,
							CAR_LP.EARNINGGROUPID
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME 
							--DTB 20260511 Se incluyen periodos anteriores de ese año
							AND YEAR(PAD_INS.STARTDATE) = YEAR(CAR_LP.COMPENSATIONDATE)
							AND PAD_INS.STARTDATE >= CAR_LP.COMPENSATIONDATE
							--DTB 20260511 Fin del cambio 
							AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
							AND SUBSTR(CAR_LP.EARNINGGROUPID,4,2) = 'S4'
							AND SUBSTR(CAR_LP.EARNINGCODEID,1,3) <> '801'
							--ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
							AND CAR_LP.ESTADO = 'C'
							--ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
							AND CAR_LP.IMPORTE <> 0
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
							AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
							AND Y.TENANTID = :v_idtenant
							AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
							AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						--LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
						WHERE Y.POSITIONSEQ IS NULL
						GROUP BY
							PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
							PAD_INS.BOUSERID,
							PAD_INS.NIF,
							IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),''), 
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,
							PAD_INS.TIPO_AGENTE,
							PAD_INS.CUADRO_RRGG_OCASO,
							PAD_INS.CUADRO_RRTT_OCASO,
							PAD_INS.PROMOCION,
							PAD_INS.SUPERRAPEL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END,
							MONTH(CAR_LP.COMPENSATIONDATE),                
							CAR_LP.EARNINGCODEID,
							CAR_LP.EARNINGGROUPID;
							
					v_num_rows := ::ROWCOUNT;          
							
							
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_BAL_PEPA_RESUMEN_REP. DERECHOS ECONOMICOS: Filas : ' || :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
						
					--ALM 20220221: Quitamos el uso del parametro v_licencias para reducir codigo.
					--END IF;
					--Actualizamos el parametro de ultima actualizacion en la tabla INYC_FECHAS_WEBI
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_PEPA_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_PEPA_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_PEPA_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
				
				
				END IF;
			
			END IF;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe S4 Percepciones Resumen', i_log_count, i_id_proceso, 'info');
					
			--Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		END IF;
		
		---------------------------------------------------------------------------------------------------------------------------------------
		-- DTB 20251021: TABLAS PARA INFORME S5 Percepciones Resumen
		--INFORME S5 PERCEPCIONES RESUMEN
		IF :i_lista_informes = 'PEPI' OR :i_lista_informes LIKE '%|PEPI|%' OR :i_lista_informes LIKE '%|PEPI' OR :i_lista_informes LIKE 'PEPI|%' OR :i_lista_informes = 'ALL' THEN

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe S5 Percepciones Resumen.', i_log_count, i_id_proceso, 'info');

			IF :v_periodo_posteado = 0 THEN
				--BORRADO OUT_PEPI_RESUMEN
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Borrado OUT_PEPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_PEPI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Borrado OUT_PEPI_RESUMEN_REP: Filas borradas: '|| :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
				
				-- INSERT DE PERCEPCIONES EN OUT_PEPI_RESUMEN
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_PEPI_RESUMEN_REP. Percepciones.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
					SELECT 
                	    PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ_PRIN,
                	    PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
                	    PAD_INS.BOUSERID,
						PAD_INS.NIF,
                	    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE,
                	    PAD_INS.POS_PRIN,
                	    PAD_INS.ID_TIPO_AGENTE,
                	    PAD_INS.TIPO_AGENTE,
                	    PAD_INS.CUADRO_INSP_OCASO,                
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                	        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                	        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                	            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                	    END AS COD_SUCURSAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                	            ELSE PAD_PTO_VENTA.LASTNAME END 
                	    END AS SUCURSAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                	            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                	                ELSE PAD_PTO_VENTA.POSITIONNAME END
                	    END END AS COD_REGIONAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                	            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                	                ELSE PAD_PTO_VENTA.LASTNAME END
                	    END END AS REGIONAL,
                	    PERC.DESCRIPCION AS COMISION,D.VALUE AS IMPORTE,
                	    (SELECT EXTRACT(MONTH FROM MAX(PD.STARTDATE)) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ) AS PERIODO_DEPOSITO,
                	    '' AS N_MEDIDA,
						0 AS V_MEDIDA,
                	    D.EARNINGCODEID,
						D.EARNINGGROUPID
                	FROM :TBL_AGENTES_PRIN_MES PAD_INS
                	INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                	    AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
                	    AND D.PERIODSEQ IN (SELECT PD.PERIODSEQ FROM TCMP.CS_PERIOD PD WHERE PD.REMOVEDATE = to_date('22000101','yyyymmdd') 
                	                            AND RIGHT(PD.NAME,4) = RIGHT(PAD_INS.PERIODO,4)
                	                            AND PD.STARTDATE <= PAD_INS.STARTDATE
                	                            AND PD.PERIODTYPESEQ = 2814749767106561)
                	    AND D.TENANTID = :v_idtenant
                	    AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
                	    AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S5'
                	    AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
                	INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                	INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
                	    AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
                	    AND D.EARNINGGROUPID = PERC.EARNINGGROUP
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                	    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                	    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
                	    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
                	    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                ;
				v_num_rows := ::ROWCOUNT;                     
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_PEPI_RESUMEN_REP. Percepciones. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');	

				--INSERT DE BALANCES EN OUT_PEPI_RESUMEN
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_PEPI_RESUMEN_REP. Balances.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
					SELECT 
                	    PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ AS POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
                	    PAD_INS.BOUSERID,
						PAD_INS.NIF,
                	    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
                	    PAD_INS.POS_PRIN,
                	    PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                	    PAD_INS.CUADRO_INSP_OCASO,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                	        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                	        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                	            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                	    END AS COD_SUCURSAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                	            ELSE PAD_PTO_VENTA.LASTNAME END 
                	    END AS SUCURSAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                	            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                	                ELSE PAD_PTO_VENTA.POSITIONNAME END
                	    END END AS COD_REGIONAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                	            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                	                ELSE PAD_PTO_VENTA.LASTNAME END
                	    END END AS REGIONAL,
                	    'Balance ' || (SELECT PER.NAME FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
                	        AND PER.PERIODSEQ = B.PERIODSEQ) ||' - ' || INITCAP(EC.DESCRIPTION) AS COMISION,
                	    B.VALUE AS IMPORTE,
                	    EXTRACT(MONTH FROM PAD_INS.STARTDATE) AS PERIODO_DEPOSITO,                
                	    'Balance' AS N_MEDIDA,0 AS V_MEDIDA,
                	    B.EARNINGCODEID,B.EARNINGGROUPID
                	FROM :TBL_AGENTES_PRIN_MES PAD_INS 
                	INNER JOIN TCMP.CS_BALANCE B ON PAD_INS.POSITIONSEQ = B.POSITIONSEQ
                	    AND PAD_INS.PARTICIPANTSEQ = B.PAYEESEQ
                	    AND B.POSTPIPELINERUNDATE < (SELECT PER.ENDDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
                	        AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
                	    AND B.POSTPIPELINERUNDATE > (SELECT PER.STARTDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
                	        AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
                	    AND B.TENANTID = :v_idtenant
                	    AND B.PROCESSINGUNITSEQ = 38280596832649217
                	    AND SUBSTR(B.EARNINGGROUPID,7,2) = '01'
                	    AND SUBSTR(B.EARNINGGROUPID,4,2) = 'S5'
                	    AND SUBSTR(B.EARNINGCODEID,1,3) <> '801'
                	INNER JOIN TCMP.CS_PLRUN PL ON B.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                	    AND PL.TENANTID = :v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217
                	INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(B.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                	    AND EC.TENANTID = :v_idtenant
                	    AND EC.REMOVEDATE = :v_eot 
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                	    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                	    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                	    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                	    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                ;
				v_num_rows := ::ROWCOUNT;                     
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_PEPI_RESUMEN_REP. Balances. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');	

				--INSERT DE MEDIDAS EN OUT_PEPI_RESUMEN
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_PEPI_RESUMEN_REP. Medidas.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
					SELECT 
                	    PAD_INS.PARTICIPANTSEQ,
						PAD_INS.POSITIONSEQ_PRIN,
                	    PAD_INS.PERIODSEQ,
						PAD_INS.PERIODO,
                	    PAD_INS.BOUSERID,PAD_INS.NIF,
                	    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
                	    PAD_INS.POS_PRIN,
                	    PAD_INS.ID_TIPO_AGENTE,
                	    PAD_INS.TIPO_AGENTE,
                	    PAD_INS.CUADRO_INSP_OCASO,                
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                	        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                	        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                	            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                	    END AS COD_SUCURSAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                	            ELSE PAD_PTO_VENTA.LASTNAME END 
                	    END AS SUCURSAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                	            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                	                ELSE PAD_PTO_VENTA.POSITIONNAME END
                	    END END AS COD_REGIONAL,
                	    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                	        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                	            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                	                ELSE PAD_PTO_VENTA.LASTNAME END
                	    END END AS REGIONAL,
                	    '' AS COMISION,0 AS IMPORTE,0 AS IMPORTE_ACUMULADO,
                	    M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,
                	    '' AS EARNINGCODEID,'' AS EARNINGGROUPID
                	FROM :TBL_AGENTES_PRIN_MES PAD_INS
                	INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.POSITIONSEQ = M.POSITIONSEQ
                	    AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
                	    AND PAD_INS.PERIODSEQ = M.PERIODSEQ 
                	    AND M.TENANTID = :v_idtenant
                	    AND M.VALUE <> 0
                	INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
                	    AND REG.COD_INFORME = 105.1
                	    AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                	    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                	    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
                	    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                	LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
                	    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
				;
				v_num_rows := ::ROWCOUNT;                     
				CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_PEPI_RESUMEN_REP. Medidas. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');
				--Actualizamos el parametro de ultima actualizacion en la tabla INYC_FECHAS_WEBI
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PEPI_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_PEPI_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PEPI_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');	
            ELSE
                IF :v_periodo_finalizado = 0 THEN
					--BORRADO OUT_LC_PEPI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Borrado OUT_LC_PEPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_PEPI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
				
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Borrado OUT_LC_PEPI_RESUMEN_REP: Filas borradas: '|| :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
                    -- INSERT DE PERCEPCIONES EN OUT_LC_PEPI_RESUMEN
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_LC_PEPI_RESUMEN_REP. Percepciones.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
                		    PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
                		    PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
                		    PAD_INS.BOUSERID,
							PAD_INS.NIF,
                		    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE,
                		    PAD_INS.POS_PRIN,
                		    PAD_INS.ID_TIPO_AGENTE,
                		    PAD_INS.TIPO_AGENTE,
                		    PAD_INS.CUADRO_INSP_OCASO,                
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                		        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                		        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                		            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                		    END AS COD_SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                		            ELSE PAD_PTO_VENTA.LASTNAME END 
                		    END AS SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                		                ELSE PAD_PTO_VENTA.POSITIONNAME END
                		    END END AS COD_REGIONAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                		                ELSE PAD_PTO_VENTA.LASTNAME END
                		    END END AS REGIONAL,
                		    PERC.DESCRIPCION AS COMISION,D.VALUE AS IMPORTE,
                		    (SELECT EXTRACT(MONTH FROM MAX(PD.STARTDATE)) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ) AS PERIODO_DEPOSITO,
                		    '' AS N_MEDIDA,
							0 AS V_MEDIDA,
                		    D.EARNINGCODEID,
							D.EARNINGGROUPID
                		FROM :TBL_AGENTES_PRIN_MES PAD_INS
                		INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                		    AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
                		    AND D.PERIODSEQ IN (SELECT PD.PERIODSEQ FROM TCMP.CS_PERIOD PD WHERE PD.REMOVEDATE = to_date('22000101','yyyymmdd') 
                		                            AND RIGHT(PD.NAME,4) = RIGHT(PAD_INS.PERIODO,4)
                		                            AND PD.STARTDATE <= PAD_INS.STARTDATE
                		                            AND PD.PERIODTYPESEQ = 2814749767106561)
                		    AND D.TENANTID = :v_idtenant
                		    AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
                		    AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S5'
                		    AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
                		INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                		INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
                		    AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
                		    AND D.EARNINGGROUPID = PERC.EARNINGGROUP
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                		    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                		    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
                		    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
                		    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                	;
					v_num_rows := ::ROWCOUNT;                     
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_LC_PEPI_RESUMEN_REP. Percepciones. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');	

					--INSERT DE BALANCES EN OUT_PEPI_RESUMEN
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_LC_PEPI_RESUMEN_REP. Balances.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
                		    PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ AS POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
                		    PAD_INS.BOUSERID,
							PAD_INS.NIF,
                		    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
                		    PAD_INS.POS_PRIN,
                		    PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                		    PAD_INS.CUADRO_INSP_OCASO,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                		        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                		        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                		            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                		    END AS COD_SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                		            ELSE PAD_PTO_VENTA.LASTNAME END 
                		    END AS SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                		                ELSE PAD_PTO_VENTA.POSITIONNAME END
                		    END END AS COD_REGIONAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                		                ELSE PAD_PTO_VENTA.LASTNAME END
                		    END END AS REGIONAL,
                		    'Balance ' || (SELECT PER.NAME FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
                		        AND PER.PERIODSEQ = B.PERIODSEQ) ||' - ' || INITCAP(EC.DESCRIPTION) AS COMISION,
                		    B.VALUE AS IMPORTE,
                		    EXTRACT(MONTH FROM PAD_INS.STARTDATE) AS PERIODO_DEPOSITO,                
                		    'Balance' AS N_MEDIDA,0 AS V_MEDIDA,
                		    B.EARNINGCODEID,B.EARNINGGROUPID
                		FROM :TBL_AGENTES_PRIN_MES PAD_INS 
                		INNER JOIN TCMP.CS_BALANCE B ON PAD_INS.POSITIONSEQ = B.POSITIONSEQ
                		    AND PAD_INS.PARTICIPANTSEQ = B.PAYEESEQ
                		    AND B.POSTPIPELINERUNDATE < (SELECT PER.ENDDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
                		        AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
                		    AND B.POSTPIPELINERUNDATE > (SELECT PER.STARTDATE FROM TCMP.CS_PERIOD PER WHERE PER.REMOVEDATE = :v_eot 
                		        AND PER.PERIODSEQ = PAD_INS.PERIODSEQ)
                		    AND B.TENANTID = :v_idtenant
                		    AND B.PROCESSINGUNITSEQ = 38280596832649217
                		    AND SUBSTR(B.EARNINGGROUPID,7,2) = '01'
                		    AND SUBSTR(B.EARNINGGROUPID,4,2) = 'S5'
                		    AND SUBSTR(B.EARNINGCODEID,1,3) <> '801'
                		INNER JOIN TCMP.CS_PLRUN PL ON B.TRIALPIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                		    AND PL.TENANTID = :v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217
                		INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(B.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                		    AND EC.TENANTID = :v_idtenant
                		    AND EC.REMOVEDATE = :v_eot 
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                		    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                		    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                		    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                		    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                	;
					v_num_rows := ::ROWCOUNT;                     
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_LC_PEPI_RESUMEN_REP. Balances. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');	

					--INSERT DE MEDIDAS EN OUT_PEPI_RESUMEN
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_LC_PEPI_RESUMEN_REP. Medidas.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
                		    PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
                		    PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
                		    PAD_INS.BOUSERID,PAD_INS.NIF,
                		    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
                		    PAD_INS.POS_PRIN,
                		    PAD_INS.ID_TIPO_AGENTE,
                		    PAD_INS.TIPO_AGENTE,
                		    PAD_INS.CUADRO_INSP_OCASO,                
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                		        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                		        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                		            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                		    END AS COD_SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                		            ELSE PAD_PTO_VENTA.LASTNAME END 
                		    END AS SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                		                ELSE PAD_PTO_VENTA.POSITIONNAME END
                		    END END AS COD_REGIONAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                		                ELSE PAD_PTO_VENTA.LASTNAME END
                		    END END AS REGIONAL,
                		    '' AS COMISION,0 AS IMPORTE,0 AS IMPORTE_ACUMULADO,
                		    M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,
                		    '' AS EARNINGCODEID,'' AS EARNINGGROUPID
                		FROM :TBL_AGENTES_PRIN_MES PAD_INS
                		INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.POSITIONSEQ = M.POSITIONSEQ
                		    AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
                		    AND PAD_INS.PERIODSEQ = M.PERIODSEQ 
                		    AND M.TENANTID = :v_idtenant
                		    AND M.VALUE <> 0
                		INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
                		    AND REG.COD_INFORME = 105.1
                		    AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                		    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                		    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
                		    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
                		    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					;
					v_num_rows := ::ROWCOUNT;                     
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_LC_PEPI_RESUMEN_REP. Medidas. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');
					--Actualizamos el parametro de ultima actualizacion en la tabla INYC_FECHAS_WEBI
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_PEPI_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_PEPI_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_PEPI_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');

                ELSE
                    --BORRADO OUT_BAL_PEPI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Borrado OUT_BAL_PEPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_PEPI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
				
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Borrado OUT_BAL_PEPI_RESUMEN_REP: Filas borradas: '|| :v_num_rows, :i_log_count, :i_id_proceso, 'debug');
                    -- INSERT DE PERCEPCIONES EN OUT_BAL_PEPI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_BAL_PEPI_RESUMEN_REP. Percepciones.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
                		    PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
                		    PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
                		    PAD_INS.BOUSERID,
							PAD_INS.NIF,
                		    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE,
                		    PAD_INS.POS_PRIN,
                		    PAD_INS.ID_TIPO_AGENTE,
                		    PAD_INS.TIPO_AGENTE,
                		    PAD_INS.CUADRO_INSP_OCASO,                
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                		        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                		        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                		            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                		    END AS COD_SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                		            ELSE PAD_PTO_VENTA.LASTNAME END 
                		    END AS SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                		                ELSE PAD_PTO_VENTA.POSITIONNAME END
                		    END END AS COD_REGIONAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                		                ELSE PAD_PTO_VENTA.LASTNAME END
                		    END END AS REGIONAL,
                		    PERC.DESCRIPCION AS COMISION,D.VALUE AS IMPORTE,
                		    (SELECT EXTRACT(MONTH FROM MAX(PD.STARTDATE)) FROM TCMP.CS_PERIOD PD WHERE PD.PERIODSEQ = D.PERIODSEQ) AS PERIODO_DEPOSITO,
                		    '' AS N_MEDIDA,
							0 AS V_MEDIDA,
                		    D.EARNINGCODEID,
							D.EARNINGGROUPID
                		FROM :TBL_AGENTES_PRIN_MES PAD_INS
                		INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                		    AND PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ
                		    AND D.PERIODSEQ IN (SELECT PD.PERIODSEQ FROM TCMP.CS_PERIOD PD WHERE PD.REMOVEDATE = to_date('22000101','yyyymmdd') 
                		                            AND RIGHT(PD.NAME,4) = RIGHT(PAD_INS.PERIODO,4)
                		                            AND PD.STARTDATE <= PAD_INS.STARTDATE
                		                            AND PD.PERIODTYPESEQ = 2814749767106561)
                		    AND D.TENANTID = :v_idtenant
                		    AND SUBSTR(D.EARNINGGROUPID,7,2) = '01'
                		    AND SUBSTR(D.EARNINGGROUPID,4,2) = 'S5'
                		    AND SUBSTR(D.EARNINGCODEID,1,3) <> '801'
                		INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                		INNER JOIN :TBL_TABLA_PERCEPCIONES PERC ON D.NAME = PERC.DEPOSITO
                		    AND SUBSTR(D.EARNINGCODEID,1,3) = PERC.EARNINGCODE
                		    AND D.EARNINGGROUPID = PERC.EARNINGGROUP
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                		    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                		    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
                		    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
                		    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                	;
					v_num_rows := ::ROWCOUNT;                     
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_BAL_PEPI_RESUMEN_REP. Percepciones. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');	

					--INSERT DE MEDIDAS EN OUT_BAL_PEPI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Inicio Carga OUT_BAL_PEPI_RESUMEN_REP. Medidas.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
						SELECT 
                		    PAD_INS.PARTICIPANTSEQ,
							PAD_INS.POSITIONSEQ_PRIN,
                		    PAD_INS.PERIODSEQ,
							PAD_INS.PERIODO,
                		    PAD_INS.BOUSERID,PAD_INS.NIF,
                		    IFNULL(RTRIM(PAD_INS.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.LASTNAME) || ' ', '') || IFNULL(RTRIM(PAD_INS.SUFFIX),'') AS NOMBRE, 
                		    PAD_INS.POS_PRIN,
                		    PAD_INS.ID_TIPO_AGENTE,
                		    PAD_INS.TIPO_AGENTE,
                		    PAD_INS.CUADRO_INSP_OCASO,                
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                		        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                		        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                		            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                		    END AS COD_SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                		            ELSE PAD_PTO_VENTA.LASTNAME END 
                		    END AS SUCURSAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                		                ELSE PAD_PTO_VENTA.POSITIONNAME END
                		    END END AS COD_REGIONAL,
                		    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                		        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                		            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                		                ELSE PAD_PTO_VENTA.LASTNAME END
                		    END END AS REGIONAL,
                		    '' AS COMISION,0 AS IMPORTE,0 AS IMPORTE_ACUMULADO,
                		    M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,
                		    '' AS EARNINGCODEID,'' AS EARNINGGROUPID
                		FROM :TBL_AGENTES_PRIN_MES PAD_INS
                		INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.POSITIONSEQ = M.POSITIONSEQ
                		    AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
                		    AND PAD_INS.PERIODSEQ = M.PERIODSEQ 
                		    AND M.TENANTID = :v_idtenant
                		    AND M.VALUE <> 0
                		INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
                		    AND REG.COD_INFORME = 105.1
                		    AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                		    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                		    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_INS.PERIODSEQ = PAD_SUC.PERIODSEQ
                		    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                		LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_INS.PERIODSEQ = PAD_REG.PERIODSEQ
                		    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					;
					v_num_rows := ::ROWCOUNT;                     
					CALL LIB_GLOBAL:WRITE_LOG(:v_permisos_log, proc_name,'Fin Carga OUT_BAL_PEPI_RESUMEN_REP. Medidas. Filas: ' || :v_num_rows,i_log_count,i_id_proceso,'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_PEPI_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_PEPI_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_PEPI_RESUMEN_REP', i_log_count, i_id_proceso, 'debug');

                END IF;
            END IF;
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe S5 Percepciones Resumen', i_log_count, i_id_proceso, 'info');
            
            --Revisamos si se debe detener el proceso
            	CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
                IF v_stop = 0 THEN
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
                    RETURN;
                END IF;
            END IF; 
        --FIN informe S5 PERCEPCIONES RESUMEN

		--------------------------------------------------------------------------------------------------------------------------------------
		--BRG 20251031: TABLAS PARA INFORME RAPPEL PRODUCCIÓN PROPIA AGENTES CON GRUPO
		IF :i_lista_informes = 'RPP' OR :i_lista_informes LIKE '%|RPP|%' OR :i_lista_informes LIKE '%|RPP' OR :i_lista_informes LIKE 'RPP|%' OR :i_lista_informes = 'ALL' THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe Rappel Producción Propia.', i_log_count, i_id_proceso, 'info');
			
			IF v_periodo_posteado = 0 THEN
				--BRG 20251031: Tabla INYC_RPP_RESUMEN pasa a ser OUT_RPP_RESUMEN_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RPP_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RPP_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RPP_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, M_GN1, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,  
						M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,M.GENERICNUMBER1 AS M_GN1,
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 32.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 32
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RPP_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RPP_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');


				--BRG 20251031: Tabla INYC_RPP_DETALLE pasa a ser OUT_RPP_DETALLE_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RPP_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RPP_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RPP_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, NAME, VALUE, C_GN1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GN1, ST_GN2, ST_GN3, ST_GD3, EVENTO, TIPO_CREDITO, PRODUCTO, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, SALESTRANSACTIONSEQ, NIF)
					SELECT
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,
						C.NAME,C.VALUE,C.GENERICNUMBER4,
						ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE,ST.GENERICDATE2, 
						ST.EVENTO,
						CT.DESCRIPTION AS TIPO_CREDITO,
						ST.PRODUCTO,
						PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),PAD_INS.NIF
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
					INNER JOIN TCMP.CS_PMCREDITTRACE PM ON M.MEASUREMENTSEQ = PM.MEASUREMENTSEQ
					INNER JOIN :TBL_CREDITOS_MES C ON PM.CREDITSEQ = C.CREDITSEQ
						AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
					INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 32.2
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
					LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
						AND CT.REMOVEDATE = :v_eot
						AND CT.TENANTID = :v_idtenant
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 32
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND AG.F_FIN > PAD_INS.STARTDATE
					--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RPP_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RPP_DETALLE_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					--BRG 20251031: Tabla INYC_LC_RPP_RESUMEN pasa a ser OUT_LC_RPP_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_RPP_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_RPP_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_RPP_RESUMEN_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_RPP_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, M_GN1, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,  
							M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,M.GENERICNUMBER1 AS M_GN1,
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 32.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 32
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_RPP_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_RPP_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			

					--BRG 20251031: Tabla INYC_LC_RPP_DETALLE pasa a ser OUT_LC_RPP_DETALLE_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_RPP_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_RPP_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
	
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_RPP_DETALLE_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
						INSERT INTO EXT.OUT_LC_RPP_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, NAME, VALUE, C_GN1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GN1, ST_GN2, ST_GN3, ST_GD3, EVENTO, TIPO_CREDITO, PRODUCTO, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, SALESTRANSACTIONSEQ, NIF)
							SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,
							C.NAME,C.VALUE,C.GENERICNUMBER4,
							ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE,ST.GENERICDATE2, 
							ST.EVENTO,
							CT.DESCRIPTION AS TIPO_CREDITO,
							ST.PRODUCTO,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),PAD_INS.NIF
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						INNER JOIN TCMP.CS_PMCREDITTRACE PM ON M.MEASUREMENTSEQ = PM.MEASUREMENTSEQ
						INNER JOIN :TBL_CREDITOS_MES C ON PM.CREDITSEQ = C.CREDITSEQ
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 32.2
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
							AND CT.REMOVEDATE = :v_eot
							AND CT.TENANTID = :v_idtenant
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 32
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_RPP_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_RPP_DETALLE_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					--BRG 20251031: Tabla INYC_BAL_RPP_RESUMEN pasa a ser OUT_BAL_RPP_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RPP_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RPP_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RPP_RESUMEN_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RPP_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, M_GN1, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,  
							M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA,M.GENERICNUMBER1 AS M_GN1,
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 32.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 32
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RPP_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RPP_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			

					--BRG 20251031: Tabla INYC_BAL_RPP_DETALLE pasa a ser OUT_BAL_RPP_DETALLE_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RPP_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RPP_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
	
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RPP_DETALLE_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
						INSERT INTO EXT.OUT_BAL_RPP_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, NAME, VALUE, C_GN1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GN1, ST_GN2, ST_GN3, ST_GD3, EVENTO, TIPO_CREDITO, PRODUCTO, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, SALESTRANSACTIONSEQ, NIF)
							SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,
							C.NAME,C.VALUE,C.GENERICNUMBER4,
							ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE,ST.GENERICDATE2, 
							ST.EVENTO,
							CT.DESCRIPTION AS TIPO_CREDITO,
							ST.PRODUCTO,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
							CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)),PAD_INS.NIF
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						INNER JOIN TCMP.CS_PMCREDITTRACE PM ON M.MEASUREMENTSEQ = PM.MEASUREMENTSEQ
						INNER JOIN :TBL_CREDITOS_MES C ON PM.CREDITSEQ = C.CREDITSEQ
							AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 32.2
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
							AND CT.REMOVEDATE = :v_eot
							AND CT.TENANTID = :v_idtenant
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 32
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RPP_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RPP_DETALLE_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPP_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				
				END IF;
			END IF;
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe Rappel Producción Propia', i_log_count, i_id_proceso, 'info');

            --Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

		END IF;
		--FIN informe Rappel Producción Propia

		--------------------------------------------------------------------------------------------------------------------------------------
		--BRG 20251031: TABLAS PARA INFORME Rappel Producción Inspectores
		IF :i_lista_informes = 'RPI' OR :i_lista_informes LIKE '%|RPI|%' OR :i_lista_informes LIKE '%|RPI' OR :i_lista_informes LIKE 'RPI|%' OR :i_lista_informes = 'ALL' THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe Rappel Producción Inspectores.', i_log_count, i_id_proceso, 'info');

			IF v_periodo_posteado = 0 THEN
				--BRG 20251031: Tabla INYC_RPI_RESUMEN pasa a ser OUT_RPI_RESUMEN_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RPI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RPI_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RPI_RESUMEN_REP. Medidas.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RPI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, COD_OFICINA, OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, C_GN4)
					SELECT
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
						M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA, 
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
						PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
						--ALM 20180126: Anadimos un * al codigo del agente para informar si el agente pertenece al grupo del inspector
						CASE WHEN PAD_AG.MANAGERPARTICIPANTSEQ = PAD_INS.PARTICIPANTSEQ THEN '*' ELSE '' END || PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						C.GENERICNUMBER4 as C_GN4
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME in (1.1, 25.1)
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
						AND PMCT.TENANTID = :v_idtenant 
					LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
					LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
					LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
						AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME in (1, 25.1)
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RPI_RESUMEN_REP. Medidas. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
				           					
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RPI_RESUMEN_REP. Incentivos.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RPI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, COD_OFICINA, OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, C_GN4)
					SELECT
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
						I.NAME AS N_MEDIDA,I.VALUE AS V_MEDIDA, 
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						'' AS N_CREDITO,0 AS V_CREDITO,
						'' AS FIRSTNAME_AG,'' AS LASTNAME_AG,'' AS SUFFIX_AG,
						'' AS POSITIONNAME_AG,
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																		ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
							ELSE 4
						END AS NIVEL_PTO_VENTA,
						PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
						PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																					ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																			ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
							ELSE 3
						END AS NIVEL_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
							ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
							ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
						CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
									ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
							ELSE 2
						END AS NIVEL_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
								ELSE PAD_PTO_VENTA.POSITIONNAME END 
						END AS COD_SUCURSAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
								ELSE PAD_PTO_VENTA.LASTNAME END 
						END AS SUCURSAL,
						1 AS NIVEL_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END
						END END AS COD_REGIONAL,
						CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
							ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END
						END END AS REGIONAL,
						--ALM 20180123: Anadimos las polizas corregidas del credito para poder sacarlo a nivel de detalle de agentes en el informe
						0 as C_GN4
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN TCMP.CS_INCENTIVE I ON PAD_INS.PERIODSEQ = I.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = I.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = I.PAYEESEQ
					INNER JOIN TCMP.CS_PLRUN PL ON I.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
					INNER JOIN EXT.CONF_REGLAS_REP REG ON I.NAME = REG.REGLA
						AND REG.COD_INFORME in (1.1, 25.1)
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
						AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
						AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
						AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
					LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
						AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME in (1, 25.1)
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RPI_RESUMEN_REP. Incentivos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RPI_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					--BRG 20251031: Tabla INYC_LC_RPI_RESUMEN pasa a ser OUT_LC_RPI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_RPI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_RPI_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_RPI_RESUMEN_REP. Medidas.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_RPI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, COD_OFICINA, OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, C_GN4)
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
							PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
							--ALM 20180126: Anadimos un * al codigo del agente para informar si el agente pertenece al grupo del inspector
							CASE WHEN PAD_AG.MANAGERPARTICIPANTSEQ = PAD_INS.PARTICIPANTSEQ THEN '*' ELSE '' END || PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							C.GENERICNUMBER4 as C_GN4
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME in (1.1, 25.1)
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
							AND PMCT.TENANTID = :v_idtenant 
						LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
						LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
						LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME in (1, 25.1)
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_RPI_RESUMEN_REP. Medidas. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_RPI_RESUMEN_REP. Incentivos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_RPI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, COD_OFICINA, OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, C_GN4) 
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							I.NAME AS N_MEDIDA,I.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							'' AS N_CREDITO,0 AS V_CREDITO,
							'' AS FIRSTNAME_AG,'' AS LASTNAME_AG,'' AS SUFFIX_AG,
							--ALM 20180126: Anadimos un * al codigo del agente para informar si el agente pertenece al grupo del inspector
							'' AS POSITIONNAME_AG,
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180123: Anadimos las polizas corregidas del credito para poder sacarlo a nivel de detalle de agentes en el informe
							0 as C_GN4
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_INCENTIVE I ON PAD_INS.PERIODSEQ = I.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = I.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = I.PAYEESEQ
						--ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
						INNER JOIN TCMP.CS_PLRUN PL ON I.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON I.NAME = REG.REGLA
						--ATV 20240719 Anyadimos el informe 25.1
							AND REG.COD_INFORME in (1.1, 25.1)
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						--ATV 20240719 Anyadimos el informe 25.1
							AND AG.COD_INFORME in (1, 25.1)
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_RPI_RESUMEN_REP. Incentivos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_RPI_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');			
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					--BRG 20251031: Tabla INYC_BAL_RPI_RESUMEN pasa a ser OUT_BAL_RPI_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RPI_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RPI_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RPI_RESUMEN_REP. Medidas.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RPI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, COD_OFICINA, OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, C_GN4)
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							M.NAME AS N_MEDIDA,M.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
							PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
							--ALM 20180126: Anadimos un * al codigo del agente para informar si el agente pertenece al grupo del inspector
							CASE WHEN PAD_AG.MANAGERPARTICIPANTSEQ = PAD_INS.PARTICIPANTSEQ THEN '*' ELSE '' END || PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							--ALM 20180123: Anadimos las polizas corregidas del credito para poder sacarlo a nivel de detalle de agentes en el informe
							C.GENERICNUMBER4 as C_GN4
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							--AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						--ATV 20240719 Anyadimos el informe 25.1
							AND REG.COD_INFORME in (1.1, 25.1)
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
							AND PMCT.TENANTID = :v_idtenant 
						LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
						LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
						LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						--ATV 20240719 Anyadimos el informe 25.1
							AND AG.COD_INFORME in (1, 25.1)
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RPI_RESUMEN_REP. Medidas. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
					
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RPI_RESUMEN_REP. Incentivos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RPI_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF, NIVEL_PTO_VENTA, COD_PTO_VENTA, PTO_VENTA, NIVEL_OFICINA, COD_OFICINA, OFICINA, NIVEL_SUCURSAL, COD_SUCURSAL, SUCURSAL, NIVEL_REGIONAL, COD_REGIONAL, REGIONAL, C_GN4)
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							I.NAME AS N_MEDIDA,I.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							'' AS N_CREDITO,0 AS V_CREDITO,
							'' AS FIRSTNAME_AG,'' AS LASTNAME_AG,'' AS SUFFIX_AG,
							--ALM 20180126: Anadimos un * al codigo del agente para informar si el agente pertenece al grupo del inspector
							'' AS POSITIONNAME_AG,
							PAD_INS.POS_PRIN,
							PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
							--ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
							,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																		ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																			ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																	ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
																	ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
								ELSE 4
							END AS NIVEL_PTO_VENTA,
							PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
							PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																						ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
																				ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
																				ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
								ELSE 3
							END AS NIVEL_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
								ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
								ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
							CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
										ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
										ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
																					ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
																						ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
																							ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
								ELSE 2
							END AS NIVEL_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
									ELSE PAD_PTO_VENTA.POSITIONNAME END 
							END AS COD_SUCURSAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
									ELSE PAD_PTO_VENTA.LASTNAME END 
							END AS SUCURSAL,
							1 AS NIVEL_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
										ELSE PAD_PTO_VENTA.POSITIONNAME END
							END END AS COD_REGIONAL,
							CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
								ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
									ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
										ELSE PAD_PTO_VENTA.LASTNAME END
							END END AS REGIONAL,
							0 as C_GN4
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN TCMP.CS_INCENTIVE I ON PAD_INS.PERIODSEQ = I.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = I.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = I.PAYEESEQ
						INNER JOIN TCMP.CS_PLRUN PL ON I.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON I.NAME = REG.REGLA
							AND REG.COD_INFORME in (1.1, 25.1)
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
							AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
							AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
							AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
						LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
							AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME in (1, 25.1)
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RPI_RESUMEN_REP. Incentivos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RPI_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RPI_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				END IF;
			END IF;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe Rappel Producción Inspectores', i_log_count, i_id_proceso, 'info');

			--Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		END IF;
		--FIN informe Rappel Producción Inspectores

		---------------------------------------------------------------------------------------------------------------------------------------
		--BRG 20251216 TABLAS PARA INFORME Rappel Especial
		IF :i_lista_informes = 'RE' OR :i_lista_informes LIKE '%|RE|%' OR :i_lista_informes LIKE '%|RE' OR :i_lista_informes LIKE 'RE|%' OR :i_lista_informes = 'ALL' THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe Rappel Especial.', i_log_count, i_id_proceso, 'info');
			
			IF v_periodo_posteado = 0 THEN
				--BRG 20251031: Tabla INYC_RE_RESUMEN pasa a ser OUT_RE_RESUMEN_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RE_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RE_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RE_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, VCORRECCION)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
						M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
						PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
						PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						--ATV 20240912 Anyadimos campo GN4 a peticion de comercial
						C.GENERICNUMBER4 AS VCorreccion
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						--AND M.VALUE <> 0
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 17.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
						AND PMCT.TENANTID = :v_idtenant 
					LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
					LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
					LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
						AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 17
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RE_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RE_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');


				--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					--BRG 20251031: Tabla INYC_LC_RE_RESUMEN pasa a ser OUT_LC_RE_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_RE_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_RE_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_RE_RESUMEN_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_RE_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, VCORRECCION)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
							PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
							--ATV 20240912 Anyadimos campo GN4 a peticion de comercial
							C.GENERICNUMBER4 AS VCorreccion
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							--AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 17.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
							AND PMCT.TENANTID = :v_idtenant 
						LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
						LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
						LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 17
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_RE_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_RE_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					--BRG 20251031: Tabla INYC_BAL_RE_RESUMEN pasa a ser OUT_BAL_RE_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RE_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RE_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RE_RESUMEN_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RE_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, VCORRECCION)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
							PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
							--ATV 20240912 Anyadimos campo GN4 a peticion de comercial
							C.GENERICNUMBER4 AS VCorreccion
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							--AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 17.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
							AND PMCT.TENANTID = :v_idtenant 
						LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
						LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
						LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 17
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RE_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RE_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RE_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			
				END IF;
			END IF;
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe Rappel Especial', i_log_count, i_id_proceso, 'info');

            --Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		END IF;
		--FIN informe Rappel Especial

		---------------------------------------------------------------------------------------------------------------------------------------
		--BRG 20260210 TABLAS PARA INFORME Rappel Mantenimiento
		IF :i_lista_informes = 'RDC' OR :i_lista_informes LIKE '%|RDC|%' OR :i_lista_informes LIKE '%|RDC' OR :i_lista_informes LIKE 'RDC|%' OR :i_lista_informes = 'ALL' THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe Rappel Mantenimiento.', i_log_count, i_id_proceso, 'info');
			
			IF v_periodo_posteado = 0 THEN
				--BRG 20260210: Tabla INYC_RDC_RESUMEN pasa a ser OUT_RDC_RESUMEN_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RDC_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RDC_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RDC_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RDC_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RDC_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, CUADRO, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
						M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						PAD_INS.CUADRO_INSP_OCASO,
						C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
						PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
						PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 10.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
						AND PMCT.TENANTID = :v_idtenant
					LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
					LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
					LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
						AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 10
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RDC_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RDC_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RDC_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RDC_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			

				--BRG 20260210: Tabla INYC_RDC_DETALLE pasa a ser OUT_RDC_DETALLE_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_RDC_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_RDC_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_RDC_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_RDC_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_RDC_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, CUADRO, NAME, VALUE, C_GN1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GD3, ST_GN1, ST_GN2, ST_GN3, EVENTO, TIPO_CREDITO, PRODUCTO, POSITIONNAME_AG, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
					SELECT
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,
						PAD_INS.CUADRO_INSP_OCASO,
						C.NAME,C.VALUE,C.GENERICNUMBER1 AS C_GN1,
						ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE, 
						ST.EVENTO,
						CT.DESCRIPTION AS TIPO_CREDITO,
						ST.PRODUCTO,
						PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
						PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
						PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
						AND PAD_INS.PERIODSEQ = C.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
						AND C.VALUE <> 0
					INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
					INNER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
						AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
					INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
						AND REG.COD_INFORME = 10.2
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
					LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
						AND CT.REMOVEDATE = :v_eot
						AND CT.TENANTID = :v_idtenant
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 10
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_RDC_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RDC_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_RDC_DETALLE_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_RDC_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				IF v_periodo_finalizado <> 0 THEN
					--BRG 20260210: Tabla INYC_BAL_RDC_RESUMEN pasa a ser OUT_BAL_RDC_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RDC_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RDC_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RDC_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RDC_RESUMEN_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RDC_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, CUADRO, N_CREDITO, V_CREDITO, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POSITIONNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
						SELECT 
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
							M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
							PAD_INS.CUADRO_INSP_OCASO,
							C.NAME AS N_CREDITO,C.VALUE AS V_CREDITO,
							PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
							AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
							--AND M.VALUE <> 0
						INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
							AND REG.COD_INFORME = 10.1
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
						LEFT OUTER JOIN TCMP.CS_PMCREDITTRACE PMCT ON M.MEASUREMENTSEQ=PMCT.MEASUREMENTSEQ
							AND PMCT.TENANTID = :v_idtenant 
						LEFT OUTER JOIN :TBL_CREDITOS_MES C ON PMCT.CREDITSEQ=C.CREDITSEQ
						LEFT OUTER JOIN :TBL_TXN_MES ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
						LEFT OUTER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 10
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RDC_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RDC_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RDC_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RDC_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				

					--BRG 20260210: Tabla INYC_BAL_RDC_DETALLE pasa a ser OUT_BAL_RDC_DETALLE_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_RDC_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_RDC_DETALLE_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_RDC_DETALLE_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_RDC_DETALLE_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_RDC_DETALLE_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, CUADRO, NAME, VALUE, C_GN1, ST_GA1, PRODUCTID, ACCOUNTINGDATE, ST_GD3, ST_GN1, ST_GN2, ST_GN3, EVENTO, TIPO_CREDITO, PRODUCTO, POSITIONNAME_AG, FIRSTNAME_AG, MIDDLENAME_AG, LASTNAME_AG, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
						SELECT
							PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
							PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
							PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,
							PAD_INS.CUADRO_INSP_OCASO,
							C.NAME,C.VALUE,C.GENERICNUMBER1 AS C_GN1,
							ST.GENERICATTRIBUTE1,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.GENERICNUMBER1,ST.GENERICNUMBER2,ST.VALUE, 
							ST.EVENTO,
							CT.DESCRIPTION AS TIPO_CREDITO,
							ST.PRODUCTO,
							PAD_AG.POSITIONGENERICATTRIBUTE3 AS POSITIONNAME_AG,
							PAD_AG.FIRSTNAME,PAD_AG.LASTNAME,PAD_AG.SUFFIX,
							PAD_INS.POS_PRIN,PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,PAD_INS.NIF
						FROM :TBL_AGENTES_PRIN_MES PAD_INS
						INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
							AND PAD_INS.PERIODSEQ = C.PERIODSEQ
							AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
							AND C.VALUE <> 0
						INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
						INNER JOIN :TBL_AGENTES_MES PAD_AG ON C.GENERICATTRIBUTE4 = PAD_AG.POSITIONNAME
							AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
						INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
							AND REG.COD_INFORME = 10.2
							AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
						LEFT OUTER JOIN TCMP.CS_CREDITTYPE CT ON C.CREDITTYPESEQ = CT.DATATYPESEQ
							AND CT.REMOVEDATE = :v_eot
							AND CT.TENANTID = :v_idtenant
						INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
							AND AG.COD_INFORME = 10
							AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						--WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_RDC_DETALLE_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RDC_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_RDC_DETALLE_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_RDC_DETALLE_REP.', i_log_count, i_id_proceso, 'debug');
				END IF;
			END IF;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe Rappel Mantenimiento', i_log_count, i_id_proceso, 'info');

            --Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		END IF;
		--FIN informe Rappel Mantenimiento

		---------------------------------------------------------------------------------------------------------------------------------------
		--BRG 20260219 TABLAS PARA INFORME Producción Propia Agentes con Grupo
		IF :i_lista_informes = 'PP' OR :i_lista_informes LIKE '%|PP|%' OR :i_lista_informes LIKE '%|PP' OR :i_lista_informes LIKE 'PP|%' OR :i_lista_informes = 'ALL' THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe Producción Propia Agentes con Grupo.', i_log_count, i_id_proceso, 'info');
			
			IF v_periodo_posteado = 0 THEN
				--BRG 20260219: Tabla INYC_PP_RESUMEN pasa a ser OUT_PP_RESUMEN_REP
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				DELETE FROM EXT.OUT_PP_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_PP_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				INSERT INTO EXT.OUT_PP_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
					SELECT 
						PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
						PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
						M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
						PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
						PAD_INS.POS_PRIN,
						PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
						--ALM 20180312: Anadimos el NIF para actualizar la cabecera del informe
						PAD_INS.NIF
					FROM :TBL_AGENTES_PRIN_MES PAD_INS
					INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
						AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
						AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
						--AND M.VALUE <> 0
					INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
						AND REG.COD_INFORME = 14.1
						AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
					INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
						AND AG.COD_INFORME = 14
						AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
					;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_PP_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
				
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_PP_RESUMEN_REP');
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
			--ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
			ELSE
				--ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
				IF v_periodo_finalizado = 0 THEN
					--BRG 20260219: Tabla INYC_LC_PP_RESUMEN pasa a ser OUT_LC_PP_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_LC_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_LC_PP_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_LC_PP_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_LC_PP_RESUMEN_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_LC_PP_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
						SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
                            M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
                            PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
                            PAD_INS.POS_PRIN,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180312: Anadimos el NIF para actualizar la cabecera del informe
                            PAD_INS.NIF
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
                            --AND M.VALUE <> 0
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
                            AND REG.COD_INFORME = 14.1
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
                        INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
                            AND AG.COD_INFORME = 14
                            AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_LC_PP_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_LC_PP_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_LC_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				--ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
				ELSE
					--BRG 20260219: Tabla INYC_BAL_PP_RESUMEN pasa a ser OUT_BAL_PP_RESUMEN_REP
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_BAL_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					DELETE FROM EXT.OUT_BAL_PP_RESUMEN_REP WHERE PERIODSEQ = :i_PeriodSeq;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_BAL_PP_RESUMEN_REP. Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_BAL_PP_RESUMEN_REP. Creditos.', i_log_count, i_id_proceso, 'debug');
					INSERT INTO EXT.OUT_BAL_PP_RESUMEN_REP (PARTICIPANTSEQ, POSITIONSEQ_PRIN, PERIODSEQ, PERIODO, QUARTER, YEAR, STARTDATE, N_MEDIDA, V_MEDIDA, BOUSERID, FIRSTNAME, MIDDLENAME, LASTNAME, POSITIONNAME, POS_PRIN, ID_TIPO_AGENTE, TIPO_AGENTE, NIF)
						SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO, PAD_INS.QUARTER,PAD_INS.YEAR,PAD_INS.STARTDATE,
                            M.NAME AS N_MEDIDA, M.VALUE AS V_MEDIDA, 
                            PAD_INS.BOUSERID,PAD_INS.FIRSTNAME,PAD_INS.LASTNAME,PAD_INS.SUFFIX,PAD_INS.POSITIONNAME,
                            PAD_INS.POS_PRIN,
                            PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE,
                            --ALM 20180312: Anadimos el NIF para actualizar la cabecera del informe
                            PAD_INS.NIF
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        INNER JOIN :TBL_MEDIDAS_MES M ON PAD_INS.PERIODSEQ = M.PERIODSEQ
                            AND PAD_INS.POSITIONSEQ = M.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = M.PAYEESEQ
                            --AND M.VALUE <> 0
                        INNER JOIN EXT.CONF_REGLAS_REP REG ON M.NAME = REG.REGLA
                            AND REG.COD_INFORME = 14.1
                            AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE 
                        INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
                            AND AG.COD_INFORME = 14
                            AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
						;
					v_num_rows := ::ROWCOUNT;
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_BAL_PP_RESUMEN_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
					CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_BAL_PP_RESUMEN_REP');
					CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_BAL_PP_RESUMEN_REP.', i_log_count, i_id_proceso, 'debug');
				END IF;
			END IF;

            --Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(:v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		END IF;
		--FIN informe Rappel Mantenimiento		

		---------------------------------------------------------------------------------------------------------------------------------------
		--BRG 20260219 TABLAS PARA INFORME 1.23 Estadístico Contable
		IF :i_lista_informes = 'CARTERA' OR :i_lista_informes LIKE '%|CARTERA|%' OR :i_lista_informes LIKE '%|CARTERA' OR :i_lista_informes LIKE 'CARTERA|%' 
			OR i_lista_informes = 'ALL' THEN

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Tablas Intermedias Informe 1.23 Estadístico Contable', i_log_count, i_id_proceso, 'info');

			-- BRG 20260219: Tabla INYC_CARTERA_AGENTES pasa a ser OUT_CARTERA_AGENTES_REP
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado OUT_CARTERA_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			DELETE FROM EXT.OUT_CARTERA_AGENTES_REP WHERE PERIODSEQ = :i_PeriodSeq;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado OUT_CARTERA_AGENTES_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_CARTERA_AGENTES_REP. Commissions.', i_log_count, i_id_proceso, 'debug');
			INSERT INTO EXT.OUT_CARTERA_AGENTES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, NAME, VALUE, C_GN4, COMPANIA, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, ACCOUNTINGDATE, ST_GD2, EVENTO, PRODUCTO, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME, PRIMA)
				SELECT 
					PAD_INS.YEAR,PAD_INS.QUARTER,PAD_INS.PERIODO,PAD_INS.STARTDATE,PAD_INS.PERIODSEQ,
					PAD_INS.NIF,
					C.NAME,C.VALUE,C.GENERICNUMBER4 AS C_GN4,
					LEFT(ST.PRODUCTID, 2) AS COMPANIA,
					CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
					ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE,ST.GENERICDATE2,ST.EVENTO,ST.PRODUCTO,
					PAD_INS.POSITIONSEQ_PRIN,PAD_INS.POSITIONSEQ,PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,PAD_INS.POS_CALLIDUS,PAD_INS.POSITIONNAME, 0 AS PRIMA --DTB 20260324 Añadido campo PRIMA
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
					AND PAD_INS.PERIODSEQ = C.PERIODSEQ
					AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
					AND C.VALUE <> 0
					AND C.NAME LIKE 'DC-%-CA-%'
				INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
				INNER JOIN EXT.CONF_AGENTES_REP AG ON PAD_INS.ID_TIPO_AGENTE = AG.ID_TIPO_AGENTE
					AND AG.COD_INFORME = 112
					AND AG.F_INICIO <= PAD_INS.STARTDATE AND  AG.F_FIN > PAD_INS.STARTDATE
				;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_CARTERA_AGENTES_REP. Commissions. Filas: '|| v_num_rows , i_log_count, i_id_proceso, 'debug');
			
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga OUT_CARTERA_AGENTES_REP. DDEE.', i_log_count, i_id_proceso, 'debug');				
			INSERT INTO EXT.OUT_CARTERA_AGENTES_REP (YEAR, QUARTER, PERIODO, STARTDATE, PERIODSEQ, NIF, NAME, VALUE, C_GN4, COMPANIA, SALESTRANSACTIONSEQ, POLIZA, PRODUCTID, ACCOUNTINGDATE, ST_GD2, EVENTO, PRODUCTO, POSITIONSEQ_PRIN, POSITIONSEQ, PARTICIPANTSEQ, POS_PRIN, POS_CALLIDUS, POSITIONNAME, PRIMA)
				SELECT
					PAD_INS.YEAR,
					PAD_INS.QUARTER,
					PAD_INS.PERIODO,
					PAD_INS.STARTDATE,
					PAD_INS.PERIODSEQ,
					PAD_INS.NIF,            
					'CARTERA_DDEE' as NAME,
					CAR_LP.IMPORTE as VALUE,
					0 as C_GN4,
					SUBSTR(CAR_LP.ORDERID,1,2) AS COMPANIA,
					CAR_LP.ORDERID ||CAST(CAR_LP.SUBLINENUMBER AS VARCHAR(127)) AS SALESTRANSACTIONSEQ,
					CAR_LP.POLIZA,
					CAR_LP.PRODUCTID,
					CAR_LP.ACCOUNTINGDATE,
					CAR_LP.FEC_VTO_REC,  --ST.GENERICDATE2,
					CAR_LP.EVENTO,
					CAR_LP.PRODUCTO,
					PAD_INS.POSITIONSEQ_PRIN,
					PAD_INS.POSITIONSEQ,
					PAD_INS.PARTICIPANTSEQ,
					PAD_INS.POS_PRIN,
					PAD_INS.POS_CALLIDUS,
					PAD_INS.POSITIONNAME,
					CAR_LP.VALUE AS PRIMA --DTB 20260324 Añadido campo PRIMA
				FROM :TBL_AGENTES_PRIN_MES PAD_INS
				INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
				--ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
				AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
				--ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
					AND CAR_LP.IMPORTE <> 0
				;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga OUT_CARTERA_AGENTES_REP. DDEE. Filas: '|| v_num_rows , i_log_count, i_id_proceso, 'debug');
			
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_CARTERA_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');
			CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'OUT_CARTERA_AGENTES_REP');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en OUT_FECHAS_WEBI_REP de OUT_CARTERA_AGENTES_REP.', i_log_count, i_id_proceso, 'debug');					

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Tablas Intermedias Informe 1.23 Estadístico Contable', i_log_count, i_id_proceso, 'info');

			-- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;
		
		END IF;
		-- Fin informe 1.23 Estadístico Contable

		---------------------------------------------------------------------------------------------------------------------------------------
		--BRG 20251113 Llamada al SP_RELLENAR_TABLAS
		--Llamar al procedimiento con la lógica de informes
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name,'Llamamos al RELLENAR_TABLAS para tener info en las tablas FINAL y los informes', i_log_count, i_id_proceso, 'info');
		CALL EXT.SP_RELLENAR_TABLAS(i_PeriodSeq, i_lista_informes, i_id_proceso, i_log_count);
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name,'Fin llamada RELLENAR_TABLAS', i_log_count, i_id_proceso, 'info');

		---------------------------------------------------------------------------------------------------------------------------------------
		-- FIN PROCEDIMIENTO	
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name,'Fin procedure ' || proc_name, i_log_count, i_id_proceso, 'info');
		
	END;
END