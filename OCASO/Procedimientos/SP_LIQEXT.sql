CREATE PROCEDURE EXT.SP_LIQEXT(
    OUT FILENAME VARCHAR(120),
    IN i_pPlRunSeq VARCHAR(50)
) LANGUAGE SQLSCRIPT SQL SECURITY INVOKER DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
 | Author: Samuel Miralles Manresa
 | Company: Inycom
 | Initial Version Date: 17-Marzo-2025
 |----------------------------------------------------------------------
 | Procedure Purpose: Generacion datos para los fichero del interface de liquidacion 
 |
 | Version: 0.1	SMM 20250317		Initial Version.
 | Versión: 0.2 LFC 20260113        Corrección de TAXID 
 |
 -----------------------------------------------------------------------
 */
BEGIN --USING SQLSCRIPT_STRING AS LIBRARY;
	-- DECLARACIÓN DE CONSTANTES Y VARIABLES
    DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA || '.' || ::CURRENT_OBJECT_NAME;    
    DECLARE v_version VARCHAR2(10) := '0.1';
    DECLARE v_num_rows INTEGER := 0;
    DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
    DECLARE v_log_count INTEGER := 0;
    DECLARE v_idproceso INTEGER;
    DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
    DECLARE v_eot DATE = EXT.LIB_CONSTANTES :v_eot;
    DECLARE v_PeriodSeq BIGINT;
    DECLARE v_PeriodName VARCHAR2(255);
    DECLARE v_PeriodStartDate DATE;
    DECLARE v_ConceptoRAPP VARCHAR2(255);
    DECLARE v_ProgramaRAPP VARCHAR2(255);

    DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
    DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
    DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
    DECLARE v_file_name VARCHAR(25) := 'LIQEXT1641_';
	DECLARE v_fechalocal TIMESTAMP;
    
    --TABLA TEMPORAL
    DECLARE TEMP_LIQEXT_CABECERA_FILE TABLE (
        "POLIZAS" DECIMAL(25, 10),
        "DOC_NIF" VARCHAR(11),
        "PROGRAMA" VARCHAR(8),
        "IMPORTE" DECIMAL(25, 10),
        "PRODUCTO" VARCHAR(5),
        "COD_CONCEPTO" VARCHAR(255) NOT NULL,
        "POSICION_COMERCIAL" VARCHAR(127),
        "FECHA" LONGDATE,
        "TIPODOCUMENTO" VARCHAR(1) NOT NULL,
        "COMPANIA" VARCHAR(2) NOT NULL,
        "EARNINGGROUPID" VARCHAR(255),
        "DEPOSITO" VARCHAR(90),
        "DEPOSITSEQ" BIGINT
    );

    DECLARE TEMP_LIQEXT_CAB_DEPOSITOS_FILE TABLE (
        "DOC_NIF" VARCHAR(11),
        "PROGRAMA" VARCHAR(8),
        "IMPORTE_TOTAL" DECIMAL(25, 10),
        "COD_CONCEPTO" VARCHAR(255) NOT NULL,
        "POSICION_COMERCIAL" VARCHAR(127),
        "FECHA" LONGDATE,
        "TIPODOCUMENTO" VARCHAR(1) NOT NULL,
        "COMPANIA" VARCHAR(2) NOT NULL,
        "EARNINGGROUPID" VARCHAR(255) NOT NULL,
        "DEPOSITO" VARCHAR(90) NOT NULL,
        "PAYEESEQ" BIGINT,
        "POSITIONSEQ" BIGINT,
        "MEASUREMENTSEQ" BIGINT,
        "INCENTIVESEQ" BIGINT,
        "DEPOSITSEQ" BIGINT NOT NULL,
        "PERIODSEQ" BIGINT NOT NULL,
        "TENANTID" VARCHAR(4) NOT NULL,
        "PRODUCTID" VARCHAR(127)
    );

	
    --CONTROLADOR DE EXCEPCIONES
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
	
		ROLLBACK;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		v_num_rows := 0;
	
		UPDATE EXT.OUT_BATCH_CONTROL
		SET STATUS = v_const_out_batch_control_error,
			END_DATE = CURRENT_TIMESTAMP
		WHERE COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
			AND ID_PROCESO = v_idproceso;
		 COMMIT;	
		RESIGNAL;
		
	END;

     --INICIALIZAMOS IDPROCESO
    SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Version: ' || v_version || ' - Procedure starting...',v_log_count,v_idproceso,'info');

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq,v_log_count,v_idproceso,'info');
    
     BEGIN
		--REGISTRO OUT_BATCH_CONTROL
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_idproceso,FILENAME,::CURRENT_OBJECT_NAME,0,EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD,CURRENT_TIMESTAMP,NULL);
		COMMIT;
	END;
	
    -- SELECCIONAMOS PERIODSEQ
    SELECT PERIODSEQ, NAME, STARTDATE INTO v_PeriodSeq, v_PeriodName, v_PeriodStartDate FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);

    --FICHERO DE SALIDA  
    --EJ LIQEXT: INYC_LIQEXT_PRD_20250225_152151_OCASO_OMFTP164102_21k69.txt
    --SELECT v_file_name||TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_OMFTP164102.txt' INTO FILENAME FROM dummy;
    
    --20250812 TGV - A PETICION DE MIGUEL ANGEL ARENAS SE CAMBIAR EL NOMBRE DE SALIDA A LIQEXT_AAAAMMDD_HHMMSS.txt
    --SELECT v_file_name||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME FROM dummy;
	-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA
	SELECT UTCTOLOCAL (current_utctimestamp, 'CET') INTO v_fechalocal FROM DUMMY;
	SELECT v_file_name||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME FROM dummy;	
	

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'FICHERO DE SALIDA ' || FILENAME,v_log_count,v_idproceso,'info');

   

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Periodo: ' || v_PeriodName,v_log_count,v_idproceso,'info');

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Inicio Borrado Tablas auxiliares',v_log_count,v_idproceso,'info');

    /*******************************************************/
    /**********BORRADO DE TABLAS ***************************/
    /*******************************************************/
    --Cabecera
    TRUNCATE TABLE EXT.OUT_LIQEXT_CAB_INFORME_FILE;
    TRUNCATE TABLE EXT.TEMP_LIQEXT_CABECERA_FILE;

    --Detalle
    TRUNCATE TABLE EXT.FINAL_LIQEXT_FILE;
    TRUNCATE TABLE EXT.OUT_LIQEXT_DET_INFORME_FILE;
    
    

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Fin Borrado Tablas auxiliares',v_log_count,v_idproceso,'info');

    ----------------------------------------------------
    -- EXTRACCION DE DATOS PERCEPCIONES
    ----------------------------------------------------
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Inicio carga Clasificacion de Percepciones en TEMP_LIQEXT_PERCEPCIONES_FILE',v_log_count,v_idproceso,'info');

    
    TEMP_LIQEXT_PERCEPCIONES_FILE =
    SELECT
        DISTINCT GC.GENERICATTRIBUTE5 AS PROGRAMA,
        GC.GENERICATTRIBUTE4 AS DEPOSITO,
        GC.GENERICATTRIBUTE3 AS GRUPOPAGO,
        GC.GENERICATTRIBUTE2 AS CONCEPTOPAGO,
        GC.GENERICATTRIBUTE1 AS TIPOPERCEPCION
    FROM
        TCMP.CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN TCMP.CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
        AND C.TENANTID = v_idtenant
        AND C.REMOVEDATE = v_eot
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON C.EFFECTIVESTARTDATE < PD.ENDDATE
        AND C.EFFECTIVEENDDATE >= PD.ENDDATE
        AND PD.TENANTID = v_idtenant
        INNER JOIN TCMP.CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
        AND GC.EFFECTIVESTARTDATE < PD.ENDDATE
        AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
        AND GC.TENANTID = v_idtenant
        AND GC.REMOVEDATE = v_eot
    WHERE
        GCT.TENANTID = v_idtenant
        AND GCT.NAME LIKE 'Percepci%n'
        AND PD.PERIODSEQ = v_periodSeq;

    v_num_rows = RECORD_COUNT(:TEMP_LIQEXT_PERCEPCIONES_FILE);
    COMMIT;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Fin carga Clasificacion de Percepciones en TEMP_LIQEXT_PERCEPCIONES_FILE ' || v_num_rows || ' filas.',v_log_count,v_idproceso,'info');

    ----------------------------------------------------
    -- PERCEPCION ASOCIADA A RAPPEL PARTICULAR  --v2.4
    ----------------------------------------------------    
    BEGIN 
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN 
            ROLLBACK;
            CALL EXT.LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Error obtener valor RAPPEL - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE, '') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE,v_log_count,v_idproceso,'error');
            COMMIT;
            RESIGNAL;
        END;

        SELECT
            PERCE.CONCEPTOPAGO,
            PERCE.PROGRAMA INTO v_ConceptoRAPP,
            v_ProgramaRAPP
        FROM
            :TEMP_LIQEXT_PERCEPCIONES_FILE PERCE
        WHERE
            PERCE.TIPOPERCEPCION = 'Rappel Produccion Mensual Particular'
            AND PERCE.GRUPOPAGO LIKE '%01';

        CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Busqueda de Percepcion asociada a rappel particular en TEMP_LIQEXT_PERCEPCIONES_FILE ' || v_ProgramaRAPP || ' - ' || v_ConceptoRAPP,v_log_count,v_idproceso,'info');

    END;

    ----------------------------------------------------
    -- EXTRACCION DE IRPF
    ----------------------------------------------------
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Inicio Carga de la tabla de IRPF en TEMP_TABLA_IRPF_REP',v_log_count,v_idproceso,'info');

    TEMP_TABLA_IRPF_REP =
        SELECT
            GC.GENERICNUMBER1,
            SUBSTR(C.NAME, 1, 1) AS NAME,
            C.CLASSIFIERID
        FROM
            TCMP.CS_GENERICCLASSIFIERTYPE GCT
            INNER JOIN TCMP.CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = v_idtenant
            AND C.REMOVEDATE = v_eot
            INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON C.EFFECTIVESTARTDATE <= PD.ENDDATE
            AND C.EFFECTIVEENDDATE >= PD.ENDDATE
            AND PD.TENANTID = v_idtenant
            INNER JOIN TCMP.CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
            AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE
            AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = v_idtenant
            AND GC.REMOVEDATE = v_eot
            INNER JOIN TCMP.CS_CATEGORY_CLASSIFIERS CC ON C.CLASSIFIERSEQ = CC.CLASSIFIERSEQ
            AND CC.EFFECTIVESTARTDATE <= PD.ENDDATE
            AND CC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND CC.TENANTID = v_idtenant
            AND CC.REMOVEDATE = v_eot
            INNER JOIN TCMP.CS_CATEGORYTREE CT ON CC.CATEGORYTREESEQ = CT.CATEGORYTREESEQ
            AND CT.EFFECTIVESTARTDATE <= PD.ENDDATE
            AND CT.EFFECTIVEENDDATE >= PD.ENDDATE
            AND CT.TENANTID = v_idtenant
            AND CT.REMOVEDATE = v_eot
            AND CT.NAME = 'Tipo IRPF'
        WHERE
            GCT.TENANTID = v_idtenant
            AND GCT.NAME = 'Tipo IRPF'
            AND PD.PERIODSEQ = v_periodSeq;
    

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Fin Carga de la tabla de IRPF en TEMP_TABLA_IRPF_REP ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    -------------------------------------------------------------------------------------------
    --  CS_SALESTRANSACTION (Transacciones) : Se filtran las transacciones del periodo
    -- SE USA en CABECERA Y DETALLE
    -------------------------------------------------------------------------------------------
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Inicio Filtro de Transacciones del periodo TEMP_LIQEXT_TXN_FILE',v_log_count,v_idproceso,'info');

    TEMP_LIQEXT_TXN_FILE =
        SELECT
            SALTX.PRODUCTID AS PRODUCTID,
            SUBSTR(ETYPE.EVENTTYPEID, 1, 2) AS TIPO_RECIBO,
            SALTX.GENERICATTRIBUTE3 AS TIPO_RECUPERACION,
            SALTX.GENERICBOOLEAN1 AS IND_PRIMA_UNICA,
            SALTX.GENERICATTRIBUTE2 AS FORMA_PAGO,
            SALTX.UNITVALUE AS UNIDAD_POLIZA,
            SALTX.VALUE AS PRIMA_COMISIONABLE,
            SALTX.GENERICNUMBER2 AS INC_PRIMA,
            SALTX.GENERICNUMBER1 AS PRIMA_NETA,
            SALTX.GENERICATTRIBUTE9 AS COD_SUPLEMENTO,
            SALTX.GENERICATTRIBUTE1 AS COD_POLIZA,
            SALTX.PRODUCTID AS COD_PRODUCTO,
            SALTX.ACCOUNTINGDATE,
            SALTX.COMPENSATIONDATE,
            SALTX.EVENTTYPESEQ,
            SALTX.SUBLINENUMBER,
            SALTX.LINENUMBER,
            SALTX.SALESTRANSACTIONSEQ,
            SALTX.SALESORDERSEQ,
            PD.PERIODSEQ,
            SALTX.TENANTID
        FROM
            TCMP.CS_SALESTRANSACTION SALTX
            INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON SALTX.COMPENSATIONDATE >= PD.STARTDATE
            AND SALTX.COMPENSATIONDATE < PD.ENDDATE
            INNER JOIN TCMP.CS_EVENTTYPE ETYPE ON SALTX.EVENTTYPESEQ = ETYPE.DATATYPESEQ
            AND ETYPE.TENANTID = v_idtenant
            AND ETYPE.REMOVEDATE = v_eot
        WHERE
            SALTX.TENANTID = v_idtenant
            AND PD.PERIODSEQ = v_periodSeq;
    
    v_num_rows = RECORD_COUNT(:TEMP_LIQEXT_TXN_FILE);

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Fin Filtro de Transacciones del periodo TEMP_LIQEXT_TXN_FILE ' || v_num_rows || ' filas.',v_log_count,v_idproceso,'info');

    ----------------------------------------------------------------------------
    -- CABECERA: EXTRACCION DE DEPOSITOS No pagos Fijos (sin 150,201 y 309)
    ----------------------------------------------------------------------------
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA No pagos Fijos (sin 150,201 y 309) TEMP_LIQEXT_CABECERA_FILE',v_log_count,v_idproceso,'info');


    INSERT INTO :TEMP_LIQEXT_CABECERA_FILE(
        POLIZAS,
        DOC_NIF,
        PROGRAMA,
        IMPORTE,
        PRODUCTO,
        COD_CONCEPTO,
        POSICION_COMERCIAL,
        FECHA,
        TIPODOCUMENTO,
        COMPANIA,
        EARNINGGROUPID,
        DEPOSITO,
        DEPOSITSEQ
    )
    SELECT
        DISTINCT 0 AS POLIZAS,
        SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 as DOC_NIF,
        PERC.PROGRAMA AS PROGRAMA,
        DEPO.VALUE AS IMPORTE,
        (
            CASE
                WHEN (
                    SUBSTR(DEPO.EARNINGCODEID, 1, 3) = '308'
                    AND DEPO.NAME = 'D-O-REH-Inspector-PagoMensual'
                ) THEN '00002'
                WHEN (
                    SUBSTR(DEPO.EARNINGCODEID, 1, 3) = '308'
                    AND DEPO.NAME = 'D-O-REP-Inspector-PagoMensual'
                ) THEN '00991'
                WHEN (
                    SUBSTR(DEPO.EARNINGCODEID, 1, 3) = '153'
                    AND DEPO.NAME = 'D-O-AGA-PagoRappel'
                ) THEN '20000'
                ELSE SUBSTR(DEPO.EARNINGCODEID, 7, 5)
            END
        ) AS PRODUCTO,
        SUBSTR(DEPO.EARNINGCODEID, 1, 3) AS COD_CONCEPTO,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10) AS POSICION_COMERCIAL,
        PD.STARTDATE AS FECHA,
        SUBSTR(DEPO.EARNINGGROUPID, 5, 1) AS TIPODOCUMENTO,
        SUBSTR(DEPO.EARNINGGROUPID, 7, 2) AS COMPANIA,
        DEPO.EARNINGGROUPID AS EARNINGGROUPID,
        DEPO.NAME AS DEPOSITO,
        DEPO.DEPOSITSEQ
    FROM
        TCMP.CS_DEPOSIT DEPO
        INNER JOIN TCMP.CS_PLRUN PL ON DEPO.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0
        LEFT JOIN TCMP.CSA_PADIMENSION PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ
        AND PAD_INS.PERIODSEQ = DEPO.PERIODSEQ
        AND PAD_INS.TENANTID = v_idtenant
        AND PAD_INS.ISPAYEE = 1
        AND (
            PAD_INS.TERMINATIONDATE > v_PeriodStartDate
            OR PAD_INS.TERMINATIONDATE IS NULL
        )
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON DEPO.PERIODSEQ = PD.PERIODSEQ
        AND PD.TENANTID = v_idtenant
        LEFT JOIN :TEMP_LIQEXT_PERCEPCIONES_FILE PERC ON PERC.CONCEPTOPAGO = SUBSTR(DEPO.EARNINGCODEID, 1, 3)
        AND PERC.GRUPOPAGO = DEPO.EARNINGGROUPID
        AND PERC.DEPOSITO = DEPO.NAME
    WHERE
        DEPO.TENANTID = v_idtenant
        AND DEPO.PERIODSEQ = v_periodSeq
        AND DEPO.NAME NOT LIKE 'D%-Pagos-Fijos%'
        AND --ALM 20200228: Excluimos los Pagos de SERCO
        DEPO.NAME NOT LIKE 'DD-%-SER-%'
        AND SUBSTR(DEPO.EARNINGCODEID, 1, 3) <> '150' -- Earning code de ASISTENCIAS
        AND SUBSTR(DEPO.EARNINGCODEID, 1, 3) <> '309' -- Earning code de cumplimiento anulaciones 
        AND SUBSTR(DEPO.EARNINGCODEID, 1, 3) <> '201' -- Earning code de Regularizacion diferenciales Anual 
        AND SUBSTR(DEPO.EARNINGCODEID, 1, 3) NOT IN ('101', '102', '106', '112', '701')
        AND DEPO.NAME <> 'D-O-COM-RRGG-Conservacion-107' --Corresponde con el concepto de pago 107, pero solo con los depositos de comisiones
        --ALM 20200727: Excluimos el deposito del nuevo pagos de comisiones de la campania de comunidades
        AND DEPO.NAME <> 'D-O-COM-INC-Agente-Pago' --ALM 20180205: Excluimos los conceptos 4** de agentes ya que se van a calcular a parte para insertar el numero de polizas
        AND NOT(
            SUBSTR(DEPO.EARNINGCODEID, 1, 1) = '4'
            AND SUBSTR(DEPO.EARNINGGROUPID, 5, 1) = '4'
        );

    v_num_rows = RECORD_COUNT(:TEMP_LIQEXT_CABECERA_FILE);

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA No pagos Fijos (sin 150,201 y 309) TEMP_LIQEXT_CABECERA_FILE ' || v_num_rows || ' filas.',v_log_count,v_idproceso,'info');

  
    ----------------------------------------------------------------------------
    -- CABECERA: EXTRACCION DE DEPOSITOS No pagos Fijos (sin 150,201 y 309)
    ----------------------------------------------------------------------------
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA No pagos Fijos (4**) de agentes TEMP_LIQEXT_CABECERA_FILE',v_log_count,v_idproceso,'info');

    INSERT INTO :TEMP_LIQEXT_CABECERA_FILE(
        POLIZAS,
        DOC_NIF,
        PROGRAMA,
        IMPORTE,
        PRODUCTO,
        COD_CONCEPTO,
        POSICION_COMERCIAL,
        FECHA,
        TIPODOCUMENTO,
        COMPANIA,
        EARNINGGROUPID,
        DEPOSITO,
        DEPOSITSEQ
    )
    SELECT
        DISTINCT CASE
            WHEN DEPO.NAME = 'D-E-ARA-ImportePago' THEN (
                SELECT
                    M.GENERICNUMBER1
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-E-ARA-ImportePago'
            ) --F-E-ARA-TotalPolizas
            WHEN DEPO.NAME = 'D-E-ASR-ImportePago' THEN (
                SELECT
                    M.GENERICNUMBER1
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-E-ASR-ImporteFinal'
            ) --F-E-ASR-TotalPolizas
            WHEN DEPO.NAME = 'D-E-R-Agente-Pago' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-E-RS-Agente-NumeroPolizas-TotalMes'
            )
            WHEN DEPO.NAME = 'D-E-S-Agente-Pago' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-E-RS-Agente-NumeroPolizas-TotalMes'
            )
            WHEN DEPO.NAME = 'D-O-ARA-ImportePago' THEN (
                SELECT
                    M.GENERICNUMBER1
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-ARA-ImportePago'
            ) --F-O-ARA-TotalPolizas
            WHEN DEPO.NAME = 'D-O-ARA-ImportePagoTrim-Final' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-GEN-Agente-NumeroPolizasCorregidas-998-TotalTrimestre'
            )
            WHEN DEPO.NAME = 'D-O-ARA-TotalPagoSubvencion' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-GEN-Agente-NumeroPolizas-998-TotalMes'
            )
            WHEN DEPO.NAME = 'D-O-ASR-ImportePago' THEN (
                SELECT
                    M.GENERICNUMBER1
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-ASR-ImporteFinal'
            ) --F-O-ASR-TotalPolizas
            WHEN DEPO.NAME = 'D-O-FIN-Agente-Pago' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-GEN-Agente-NumeroPolizas-998-TotalMes'
            )
            WHEN DEPO.NAME = 'D-O-MO-ImportePago' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes'
            )
            WHEN DEPO.NAME = 'D-O-RPP-Agente-ImporteRegNetaCuat' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes'
            )
            WHEN DEPO.NAME = 'D-O-RPP-Agente-N2N3-Pago' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes'
            )
            WHEN DEPO.NAME = 'D-O-RPP-Agente-N2N3-Pago-SuperRappel' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes'
            )
            WHEN DEPO.NAME = 'D-O-RPP-Agente-Pago' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes'
            )
            WHEN DEPO.NAME = 'D-O-RPP-Agente-Pago-Reg-PlanesCarrera' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes'
            )
            WHEN DEPO.NAME = 'D-O-RPP-Agente-Pago-SuperRappel' THEN (
                SELECT
                    M.VALUE
                FROM
                    TCMP.CS_MEASUREMENT M
                    INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND MODELSEQ = 0
                WHERE
                    M.PERIODSEQ = v_periodSeq
                    AND M.PAYEESEQ = DEPO.PAYEESEQ
                    AND M.POSITIONSEQ = DEPO.POSITIONSEQ
                    AND M.NAME = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes'
            )
            ELSE 0
        END AS POLIZAS,
        SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 AS DOC_NIF,
        PERC.PROGRAMA AS PROGRAMA,
        DEPO.VALUE AS IMPORTE,
        SUBSTR(DEPO.EARNINGCODEID, 7, 5) AS PRODUCTO,
        SUBSTR(DEPO.EARNINGCODEID, 1, 3) AS COD_CONCEPTO,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10) AS POSICION_COMERCIAL,
        PD.STARTDATE AS FECHA,
        SUBSTR(DEPO.EARNINGGROUPID, 5, 1) AS TIPODOCUMENTO,
        SUBSTR(DEPO.EARNINGGROUPID, 7, 2) AS COMPANIA,
        DEPO.EARNINGGROUPID AS EARNINGGROUPID,
        DEPO.NAME AS DEPOSITO,
        DEPO.DEPOSITSEQ --     PAD_INS.POSITIONNAME               As POSICION_COMERCIAL,     v1.2
    FROM
        TCMP.CS_DEPOSIT DEPO
        INNER JOIN TCMP.CS_PLRUN PL ON DEPO.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0
        LEFT JOIN TCMP.CSA_PADIMENSION PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ
        AND PAD_INS.PERIODSEQ = DEPO.PERIODSEQ
        AND PAD_INS.TENANTID = v_idtenant
        AND PAD_INS.ISPAYEE = 1 --Por peticion de Javier excluimos los Participant dados de baja 
        AND (
            PAD_INS.TERMINATIONDATE > v_periodStartDate
            OR PAD_INS.TERMINATIONDATE IS NULL
        )
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON DEPO.PERIODSEQ = PD.PERIODSEQ
        AND PD.TENANTID = v_idtenant 
        LEFT JOIN :TEMP_LIQEXT_PERCEPCIONES_FILE PERC ON PERC.CONCEPTOPAGO = SUBSTR(DEPO.EARNINGCODEID, 1, 3)
        AND PERC.GRUPOPAGO = DEPO.EARNINGGROUPID
        AND PERC.DEPOSITO = DEPO.NAME
    WHERE
        DEPO.TENANTID = v_idtenant
        AND DEPO.PERIODSEQ = v_periodSeq
        AND DEPO.NAME NOT LIKE 'D%-Pagos-Fijos%'
        AND SUBSTR(DEPO.EARNINGCODEID, 1, 1) = '4'
        AND SUBSTR(DEPO.EARNINGGROUPID, 5, 1) = '4';

    v_num_rows = RECORD_COUNT(:TEMP_LIQEXT_CABECERA_FILE);

    --select 'TEMP_LIQEXT_CABECERA_FILE-2',v_num_rows from dummy;
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA No pagos Fijos (4**) de agentes TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

   
    ---------------------------------------------------------------------------------
    --  ACTUALIZACION PERCEPCION ASOCIADA A RAPPEL PARTICULAR  --v2.4
    ---------------------------------------------------------------------------------    
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio Actualizacion de percepcion asociada a rappel particular TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    UPDATE
        :TEMP_LIQEXT_CABECERA_FILE
    SET
        COD_CONCEPTO = v_ConceptoRAPP,
        PROGRAMA = v_ProgramaRAPP
    WHERE
        DEPOSITO = 'D-RPP-Inspector-Pago'
        AND POSICION_COMERCIAL IN (
            SELECT
                LCT.POSICION_COMERCIAL
            FROM
                :TEMP_LIQEXT_CABECERA_FILE LCT
            WHERE
                LCT.DEPOSITO = 'D-MIN-Rappel-ImportePago'
        );

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin Actualizacion de percepcion asociada a rappel particular TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    ----------------------------------------------------
    -- CABECERA: EXTRACCION DE DEPOSITOS PAGOS FIJOS
    ----------------------------------------------------
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA Pagos Fijos y Serco TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO :TEMP_LIQEXT_CABECERA_FILE(
        POLIZAS,
        DOC_NIF,
        PROGRAMA,
        IMPORTE,
        PRODUCTO,
        COD_CONCEPTO,
        POSICION_COMERCIAL,
        FECHA,
        TIPODOCUMENTO,
        COMPANIA,
        EARNINGGROUPID,
        DEPOSITO,
        DEPOSITSEQ
    )
    SELECT
        DISTINCT 0 as POLIZAS,
        SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 as DOC_NIF,
        PERC.PROGRAMA as PROGRAMA,
        DEPO.VALUE as IMPORTE,
        IFNULL(
            SUBSTR(DEPO.GENERICATTRIBUTE1, 3, 5),
            SUBSTR(DEPO.EARNINGCODEID, 7, 5)
        ) as PRODUCTO,
        SUBSTR(DEPO.EARNINGCODEID, 1, 3) as COD_CONCEPTO,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10) as POSICION_COMERCIAL,
        PD.STARTDATE as FECHA,
        SUBSTR(DEPO.EARNINGGROUPID, 5, 1) as TIPODOCUMENTO,
        SUBSTR(DEPO.EARNINGGROUPID, 7, 2) as COMPANIA,
        DEPO.EARNINGGROUPID as EARNINGGROUPID,
        DEPO.NAME as DEPOSITO,
        DEPO.DEPOSITSEQ --     PAD_INS.POSITIONNAME               as POSICION_COMERCIAL,     v1.2        
    FROM
        TCMP.CS_DEPOSIT DEPO
        INNER JOIN TCMP.CS_PLRUN PL ON DEPO.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0
        LEFT JOIN TCMP.CSA_PADIMENSION PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ
        AND PAD_INS.PERIODSEQ = DEPO.PERIODSEQ
        AND PAD_INS.TENANTID = v_idtenant
        AND PAD_INS.ISPAYEE = 1 --Por peticion de Javier excluimos los Participant dados de baja 
        AND (
            PAD_INS.TERMINATIONDATE > v_PeriodStartDate
            OR PAD_INS.TERMINATIONDATE IS NULL
        )
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON DEPO.PERIODSEQ = PD.PERIODSEQ
        AND PD.TENANTID = v_idtenant
        LEFT JOIN :TEMP_LIQEXT_PERCEPCIONES_FILE PERC ON PERC.CONCEPTOPAGO = SUBSTR(DEPO.EARNINGCODEID, 1, 3)
        AND PERC.GRUPOPAGO = DEPO.EARNINGGROUPID
        AND PERC.DEPOSITO = DEPO.NAME
    WHERE
        DEPO.TENANTID = v_idtenant
        AND DEPO.PERIODSEQ = v_PeriodSeq
        AND --Anadimos los depositos de Serco        
        (
            DEPO.NAME LIKE 'D%-Pagos-Fijos%'
            OR DEPO.NAME LIKE 'DD-%-SER-%'
        );

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA Pagos Fijos y Serco TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    -------------------------------------------------------------
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio filtro CARTERA DERECO (DDEE) -  TEMP_LIQEXT_CAB_DEPOSITOS_FILE  fin. ',v_log_count,v_idproceso,'info');

    INSERT INTO :TEMP_LIQEXT_CAB_DEPOSITOS_FILE(
        DOC_NIF,
        PROGRAMA,
        IMPORTE_TOTAL,
        COD_CONCEPTO,
        POSICION_COMERCIAL,
        FECHA,
        TIPODOCUMENTO,
        COMPANIA,
        EARNINGGROUPID,
        DEPOSITO,
        PAYEESEQ,
        POSITIONSEQ,
        MEASUREMENTSEQ,
        INCENTIVESEQ,
        DEPOSITSEQ,
        PERIODSEQ,
        TENANTID,
        PRODUCTID
    )
    SELECT
        --DISTINCT
        SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 AS DOC_NIF,
        'MACB11P' AS PROGRAMA,
        SUM(CAR_LP.IMPORTE) AS IMPORTE_TOTAL,
        CAR_LP.EARNINGCODEID AS COD_CONCEPTO,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10) AS POSICION_COMERCIAL,
        PD.STARTDATE AS FECHA,
        SUBSTR(CAR_LP.EARNINGGROUPID, 5, 1) AS TIPODOCUMENTO,
        SUBSTR(CAR_LP.EARNINGGROUPID, 7, 2) AS COMPANIA,
        CAR_LP.EARNINGGROUPID AS EARNINGGROUPID,
        'Comisiones Cartera DDEE' AS DEPOSITO,        
        PAD_INS.PARTICIPANTSEQ AS PAYEESEQ,        
        PAD_INS.POSITIONSEQ,
        0 AS MEASUREMENTSEQ,
        0 AS INCENTIVESEQ,
        0 AS DEPOSITSEQ,
        PD.PERIODSEQ,
        v_idtenant AS TENANTID,
        CAR_LP.PRODUCTID
    FROM
        EXT.CARTERA_DDEE CAR_LP
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON CAR_LP.COMPENSATIONDATE = PD.STARTDATE
        AND PD.TENANTID = v_idtenant
        AND PD.PERIODTYPESEQ = 2814749767106561 --SMM ¿VALOR FIJO?
        AND PD.PERIODSEQ = v_periodSeq --Utilizamos un inner para que no aparezcan filas con el campo POSICION_COMERCIAL nulo.
        --              Finalmente, por peticion de Javier, las dejamos con el campo a nulo, pero hay que tener en cuenta que no se deben de pagar!!!!!!!!
        --              PARA EVITAR PROBLEMAS EN EL FUTURO Y DE CARA AL USO DEL REPEXT PONEMOS UN INNER FINALMENTE
        INNER JOIN TCMP.CSA_PADIMENSION PAD_INS ON PAD_INS.POSITIONNAME = CAR_LP.POSITIONNAME
        AND PAD_INS.PERIODSEQ = PD.PERIODSEQ
        AND PAD_INS.TENANTID = v_idtenant
        AND PAD_INS.ISPAYEE = 1 --NO TENEMOS EN CUENTA LOS AGENTES DADOS DE BAJA
        AND (
            PAD_INS.TERMINATIONDATE > v_PeriodStartDate
            OR PAD_INS.TERMINATIONDATE IS NULL
        )
    WHERE
        CAR_LP.COMPENSATIONDATE = v_PeriodStartDate
        AND CAR_LP.SEQ_POST IS NOT NULL --SOLO DEVOLVEMOS DATOS COBRADOS
        AND CAR_LP.ESTADO = 'C'
    GROUP BY
        PD.PERIODSEQ,
        PAD_INS.POSITIONSEQ,
        PAD_INS.PARTICIPANTSEQ,
        CAR_LP.EARNINGGROUPID,
        SUBSTR(CAR_LP.EARNINGGROUPID, 7, 2),
        SUBSTR(CAR_LP.EARNINGGROUPID, 5, 1),
        PD.STARTDATE,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10),
        CAR_LP.EARNINGCODEID,
        SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1,
        CAR_LP.PRODUCTID;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin  filtro CARTERA DERECO (DDEE) -  TEMP_LIQEXT_CAB_DEPOSITOS_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    -------------------------------------------------------------------
    -- CABECERA: EXTRACCION DE DATOS DE ASISTENCIAS (150) Y ANULACIONES (309)
    --------------------------------------------------------------------    
    -- CABECERA: FILTRO DEPOSITOS 
    ----------------------------------------------------    
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio filtro depositos 150 y 309 -  TEMP_LIQEXT_CAB_DEPOSITOS_FILE. ',v_log_count,v_idproceso,'info');

    INSERT INTO :TEMP_LIQEXT_CAB_DEPOSITOS_FILE(
        DOC_NIF,
        PROGRAMA,
        IMPORTE_TOTAL,
        COD_CONCEPTO,
        POSICION_COMERCIAL,
        FECHA,
        TIPODOCUMENTO,
        COMPANIA,
        EARNINGGROUPID,
        DEPOSITO,
        PAYEESEQ,
        POSITIONSEQ,
        MEASUREMENTSEQ,
        INCENTIVESEQ,
        DEPOSITSEQ,
        PERIODSEQ,
        TENANTID,
        PRODUCTID
    )
    SELECT
        DISTINCT SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 AS DOC_NIF,
        PERC.PROGRAMA AS PROGRAMA,
        DEPO.VALUE AS IMPORTE_TOTAL,
        DEPO.EARNINGCODEID AS COD_CONCEPTO,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10) AS POSICION_COMERCIAL,
        PD.STARTDATE AS FECHA,
        SUBSTR(DEPO.EARNINGGROUPID, 5, 1) AS TIPODOCUMENTO,
        SUBSTR(DEPO.EARNINGGROUPID, 7, 2) AS COMPANIA,
        DEPO.EARNINGGROUPID AS EARNINGGROUPID,
        DEPO.NAME AS DEPOSITO,
        DEPO.PAYEESEQ,
        DEPO.POSITIONSEQ,
        IPM.MEASUREMENTSEQ,
        INCE.INCENTIVESEQ,
        DEPO.DEPOSITSEQ,
        DEPO.PERIODSEQ,
        DEPO.TENANTID,
        --POr un error en Commissions se coge el primer caracter del GA2 (participant 203281359170 con valor erroneo CIF en lugar de C)
        --Cargar el campo PRODUCTID en la tabla INYC_LIQEXT_CAB_DEPOSITOS_TEMP
        '' AS PRODUCTID
    FROM
        TCMP.CS_DEPOSIT DEPO
        INNER JOIN TCMP.CS_PLRUN PL ON DEPO.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0
        INNER JOIN TCMP.CS_DEPOSITINCENTIVETRACE DI ON DI.DEPOSITSEQ = DEPO.DEPOSITSEQ
        AND DI.TENANTID = v_idtenant
        INNER JOIN TCMP.CS_INCENTIVE INCE ON INCE.INCENTIVESEQ = DI.INCENTIVESEQ
        AND INCE.TENANTID = v_idtenant
        INNER JOIN TCMP.CS_INCENTIVEPMTRACE IPM ON IPM.INCENTIVESEQ = INCE.INCENTIVESEQ
        AND IPM.TENANTID = v_idtenant
        LEFT JOIN TCMP.CSA_PADIMENSION PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ
        AND PAD_INS.PERIODSEQ = DEPO.PERIODSEQ
        AND PAD_INS.TENANTID = v_idtenant
        AND PAD_INS.ISPAYEE = 1 --Por peticion de Javier excluimos los Participant dados de baja 
        AND (
            PAD_INS.TERMINATIONDATE > v_PeriodStartDate
            OR PAD_INS.TERMINATIONDATE IS NULL
        )
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON DEPO.PERIODSEQ = PD.PERIODSEQ
        AND PD.TENANTID = v_idtenant
        LEFT JOIN :TEMP_LIQEXT_PERCEPCIONES_FILE PERC ON PERC.CONCEPTOPAGO = SUBSTR(DEPO.EARNINGCODEID, 1, 3)
        AND PERC.GRUPOPAGO = DEPO.EARNINGGROUPID
        AND PERC.DEPOSITO = DEPO.NAME
    WHERE
        DEPO.TENANTID = v_idtenant
        AND DEPO.PERIODSEQ = v_periodSeq
        AND DEPO.NAME NOT LIKE 'D%-Pagos-Fijos%'
        AND (
            --ALM 20180205: Incluimos el resto de Comisiones
            --ALM 20180301: Distinguimos los conceptos 107 entre Comisiones y RDC
            --SUBSTR(DEPO.EARNINGCODEID,1,3) IN ('101','102','106','107','112','701') -- Earning code de Comisiones
            --ALM 20191228: Incluimos el nuevo concepto 123
            --ALM 20200228: Excluimos el concepto 123
            --SUBSTR(DEPO.EARNINGCODEID,1,3) IN ('101','102','106','112','123','701') -- Earning code de Comisiones
            SUBSTR(DEPO.EARNINGCODEID, 1, 3) IN ('101', '102', '106', '112', '701') -- Earning code de Comisiones
            OR DEPO.NAME = 'D-O-COM-RRGG-Conservacion-107' --Corresponde con el concepto de pago 107, pero solo con los depositos de comisiones
            OR --ALM 20200727: Incluimos el deposito del nuevo pagos de comisiones de la campania de comunidades
            DEPO.NAME = 'D-O-COM-INC-Agente-Pago'
            OR SUBSTR(DEPO.EARNINGCODEID, 1, 3) = '150' -- Earning code de ASISTENCIAS
            OR SUBSTR(DEPO.EARNINGCODEID, 1, 3) = '309' -- Earning code de ASISTENCIAS
        );

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin  filtro depositos 150 y 309 -  TEMP_LIQEXT_CAB_DEPOSITOS_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    
    ----------------------------------------------------    
    -- CABECERA: ASISTENCIAS 150 -- FILTRO MEDIDAS Y CREDITOS 
    ----------------------------------------------------    
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio filtro medidas y creditos de asistencia (150) -  TEMP_LIQEXT_CAB_CREDIMED_FILE ',v_log_count,v_idproceso,'info');

    TEMP_LIQEXT_CAB_CREDIMED_FILE = 
        SELECT
            C.GENERICNUMBER4 AS POLIZAS,
            C.GENERICATTRIBUTE2 AS PRODUCTO,
            C.SALESTRANSACTIONSEQ,
            C.VALUE AS IMPORTE,
            C.NAME AS CREDITNAME,
            C.CREDITSEQ,
            PM.VALUE AS PMVALUE,
            PM.NAME AS PMNAME,
            PM.MEASUREMENTSEQ AS PMSEQ,
            SM.VALUE AS SMVALUE,
            SM.NAME AS SMNAME,
            SM.MEASUREMENTSEQ AS SMSEQ,
            C.CREDITSEQ AS PERIODSEQ,
            C.TENANTID
        FROM
            TCMP.CS_CREDIT C
            INNER JOIN TCMP.CS_PLRUN PL ON C.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
            AND PL.MODELSEQ = 0
            INNER JOIN TCMP.CS_PMCREDITTRACE PMC ON C.CREDITSEQ = PMC.CREDITSEQ
            AND PMC.TENANTID = v_idtenant
            INNER JOIN TCMP.CS_MEASUREMENT PM ON PM.MEASUREMENTSEQ = PMC.MEASUREMENTSEQ
            AND PM.TENANTID = v_idtenant
            AND PM.PERIODSEQ = v_periodSeq
            INNER JOIN TCMP.CS_PMSELFTRACE PMS ON PMS.SOURCEMEASUREMENTSEQ = PM.MEASUREMENTSEQ
            AND PMS.TENANTID = v_idtenant
            INNER JOIN TCMP.CS_MEASUREMENT SM ON SM.MEASUREMENTSEQ = PMS.TARGETMEASUREMENTSEQ
            AND SM.TENANTID = v_idtenant
            AND SM.PERIODSEQ = v_periodSeq
        WHERE
            C.TENANTID = v_idtenant
            AND C.PERIODSEQ = v_periodSeq
            --ALM 20180205: Incluimos todas las Comisiones  
            AND C.NAME LIKE 'DC-%-COM-%';

    v_num_rows = RECORD_COUNT(:TEMP_LIQEXT_CAB_CREDIMED_FILE);

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin filtro medidas y creditos de asistencia (150) -  TEMP_LIQEXT_CAB_CREDIMED_FILE ' || v_num_rows || ' filas.',v_log_count,v_idproceso,'info');

    
    --------------------------------------------------------------------------    
    -- CABECERA: ASISTENCIAS 150 -- JOIN DEPOSITOS, MEDIDAS, CREDITOS y TXN 
    --------------------------------------------------------------------------    
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (150) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        sum(IFNULL(ccred.POLIZAS, 0)) AS POLIZAS,
        CDEPO.DOC_NIF,
        CDEPO.PROGRAMA,
        sum(ccred.IMPORTE),
        SUBSTR(ccred.PRODUCTO, 3, 5) AS PRODUCTO,
        --SUBSTR(txnt.PRODUCTID,3,5)      as PRODUCTO,
        --ALM 20180205: No nos hace falta unir por las transaciones porque tenemos el producto al nivel del credito
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) AS COD_CONCEPTO,
        CDEPO.POSICION_COMERCIAL,
        CDEPO.FECHA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.COMPANIA,
        CDEPO.EARNINGGROUPID,
        CDEPO.DEPOSITO,
        CDEPO.DEPOSITSEQ
    FROM
        :TEMP_LIQEXT_CAB_DEPOSITOS_FILE CDEPO
        INNER JOIN :TEMP_LIQEXT_CAB_CREDIMED_FILE ccred ON CCRED.SMSEQ = CDEPO.MEASUREMENTSEQ 
        --ALM 20180205: No nos hace falta unir por las transaciones porque tenemos el producto al nivel del credito
        --ALM 20180205: Incluimos todas las Comisiones
        --ALM 20180301: Lo dejamos como esta ahora porque ya hemos filtrado en la tabla INYC_LIQEXT_CAB_DEPOSITOS_TEMP
        --ALM 20191228: Incluimos el concepto 123
        --ALM 20200228: Excluimos el concepto 123
    WHERE
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) IN ('101', '102', '106', '107', '112', '150', '701') 
        --ALM 20200727: Incluimos el deposito del nuevo pagos de comisiones de la campania de comunidades
        OR CDEPO.DEPOSITO = 'D-O-COM-INC-Agente-Pago'
    GROUP BY
        CDEPO.DEPOSITSEQ,
        CDEPO.DEPOSITO,
        CDEPO.EARNINGGROUPID,
        CDEPO.COMPANIA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.FECHA,
        CDEPO.POSICION_COMERCIAL,
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3),
        SUBSTR(ccred.PRODUCTO, 3, 5),
        CDEPO.PROGRAMA,
        CDEPO.DOC_NIF;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (150) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: Anulaciones 309 -- JOIN DEPOSITOS y MEDIDAS  
    --------------------------------------------------------------------------    
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (309) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        0 AS POLIZAS,
        CDEPO.DOC_NIF,
        CDEPO.PROGRAMA,
        SUM(M.VALUE),
        CASE
            WHEN UPPER(M.NAME) = 'SM-O-RECOA-INSPECTOR-PAGO-HOGAR' THEN '00002'
            WHEN UPPER(M.NAME) = 'SM-O-RECOA-INSPECTOR-PAGO-RRTT' THEN '00001'
            WHEN UPPER(M.NAME) = 'SM-O-RECOA-INSPECTOR-PAGO-AHORRO' THEN '00004'
        END AS PRODUCTO,
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) AS COD_CONCEPTO,
        CDEPO.POSICION_COMERCIAL,
        CDEPO.FECHA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.COMPANIA,
        CDEPO.EARNINGGROUPID,
        CDEPO.DEPOSITO,
        CDEPO.DEPOSITSEQ
    FROM
        :TEMP_LIQEXT_CAB_DEPOSITOS_FILE CDEPO
        LEFT JOIN TCMP.CS_MEASUREMENT M ON M.MEASUREMENTSEQ = CDEPO.MEASUREMENTSEQ
        AND M.TENANTID = v_idtenant --ALM 20170426: Quitamos esta condicion porque sino el sumatorio puede ser nulo y dar error el insert
        --AND M.VALUE <> 0
        INNER JOIN TCMP.CS_PLRUN PL ON M.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0
    WHERE
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) = '309'
    GROUP BY
        CDEPO.DEPOSITSEQ,
        CDEPO.DEPOSITO,
        CDEPO.EARNINGGROUPID,
        CDEPO.COMPANIA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.FECHA,
        CDEPO.POSICION_COMERCIAL,
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3),
        CASE
            WHEN UPPER(M.NAME) = 'SM-O-RECOA-INSPECTOR-PAGO-HOGAR' THEN '00002'
            WHEN UPPER(M.NAME) = 'SM-O-RECOA-INSPECTOR-PAGO-RRTT' THEN '00001'
            WHEN UPPER(M.NAME) = 'SM-O-RECOA-INSPECTOR-PAGO-AHORRO' THEN '00004'
        END,
        CDEPO.PROGRAMA,
        CDEPO.DOC_NIF;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (309) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: 201 Regularizacion diferenciales Anual  -- JOIN DEPOSITOS e incentivos  
    -------------------------------------------------------------------------- 
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio Filtro depositos 201 -  TEMP_LIQEXT_CAB_DEPOSITOS_FILE. ',v_log_count,v_idproceso,'info');

    INSERT INTO :TEMP_LIQEXT_CAB_DEPOSITOS_FILE(
        DOC_NIF,
        PROGRAMA,
        IMPORTE_TOTAL,
        COD_CONCEPTO,
        POSICION_COMERCIAL,
        FECHA,
        TIPODOCUMENTO,
        COMPANIA,
        EARNINGGROUPID,
        DEPOSITO,
        PAYEESEQ,
        POSITIONSEQ,
        MEASUREMENTSEQ,
        INCENTIVESEQ,
        DEPOSITSEQ,
        PERIODSEQ,
        TENANTID,
        PRODUCTID
    )
    SELECT
        DISTINCT SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 AS DOC_NIF,
        PERC.PROGRAMA AS PROGRAMA,
        DEPO.VALUE AS IMPORTE_TOTAL,
        DEPO.EARNINGCODEID AS COD_CONCEPTO,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10) AS POSICION_COMERCIAL,
        PD.STARTDATE AS FECHA,
        SUBSTR(DEPO.EARNINGGROUPID, 5, 1) AS TIPODOCUMENTO,
        SUBSTR(DEPO.EARNINGGROUPID, 7, 2) AS COMPANIA,
        DEPO.EARNINGGROUPID AS EARNINGGROUPID,
        DEPO.NAME AS DEPOSITO,
        DEPO.PAYEESEQ,
        DEPO.POSITIONSEQ,
        0 AS MEASUREMENTSEQ,
        -- No hay seq de Medida 
        INST.SOURCEINCENTIVESEQ AS INCENTIVESEQ,
        DEPO.DEPOSITSEQ,
        DEPO.PERIODSEQ,
        DEPO.TENANTID,
        '' AS PRODUCTID -- RAP 20211229
        --PAD_INS.PARTICIPANTGENERICATTRIBUTE2 || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 as DOC_NIF,
        --LLS 20220204: Cargar el campo PRODUCTID en la tabla INYC_LIQEXT_CAB_DEPOSITOS_TEMP
    FROM
        TCMP.CS_DEPOSIT DEPO
        INNER JOIN TCMP.CS_PLRUN PL ON DEPO.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0
        INNER JOIN TCMP.CS_DEPOSITINCENTIVETRACE DI ON DI.DEPOSITSEQ = DEPO.DEPOSITSEQ
        AND DI.TENANTID = v_idtenant --  INNER JOIN TCMP.CS_INCENTIVESELFTRACE inst on INST.TARGETINCENTIVESEQ =  DI.INCENTIVESEQ
        LEFT JOIN TCMP.CS_INCENTIVESELFTRACE INST on INST.TARGETINCENTIVESEQ = DI.INCENTIVESEQ
        AND INST.TENANTID = v_idtenant
        LEFT JOIN CSA_PADIMENSION PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ
        AND PAD_INS.PERIODSEQ = DEPO.PERIODSEQ
        AND PAD_INS.TENANTID = v_idtenant
        AND PAD_INS.ISPAYEE = 1 --ALM 20180507: Por peticion de Javier excluimos los Participant dados de baja 
        AND (
            PAD_INS.TERMINATIONDATE > v_PeriodStartDate
            OR PAD_INS.TERMINATIONDATE IS NULL
        )
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON DEPO.PERIODSEQ = PD.PERIODSEQ
        AND PD.TENANTID = v_idtenant
        LEFT JOIN :TEMP_LIQEXT_PERCEPCIONES_FILE PERC ON PERC.CONCEPTOPAGO = SUBSTR(DEPO.EARNINGCODEID, 1, 3)
        AND PERC.GRUPOPAGO = DEPO.EARNINGGROUPID
        AND PERC.DEPOSITO = DEPO.NAME
    WHERE
        DEPO.TENANTID = v_idtenant
        AND DEPO.PERIODSEQ = v_PeriodSeq
        AND DEPO.NAME NOT LIKE 'D%-Pagos-Fijos%'
        AND DEPO.EARNINGCODEID = '201';

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin Filtro depositos 201 -  TEMP_LIQEXT_CAB_DEPOSITOS_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: 201 Regularizacion diferenciales Anual  --  DATOS CABECERA 
    --------------------------------------------------------------------------        
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (201) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        0 AS POLIZAS,
        CDEPO.DOC_NIF,
        CDEPO.PROGRAMA,
        SUM(COM.VALUE),
        SUBSTR(C.GENERICATTRIBUTE2, 3, 5) AS PRODUCTO,
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) AS COD_CONCEPTO,
        CDEPO.POSICION_COMERCIAL,
        CDEPO.FECHA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.COMPANIA,
        CDEPO.EARNINGGROUPID,
        CDEPO.DEPOSITO,
        CDEPO.DEPOSITSEQ
    FROM
        :TEMP_LIQEXT_CAB_DEPOSITOS_FILE CDEPO
        INNER JOIN TCMP.CS_COMMISSION COM ON COM.INCENTIVESEQ = CDEPO.INCENTIVESEQ
        AND COM.TENANTID = v_idtenant
        INNER JOIN TCMP.CS_CREDIT C ON C.CREDITSEQ = COM.CREDITSEQ
        AND C.TENANTID = v_idtenant
        INNER JOIN TCMP.CS_PLRUN PL ON C.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0
    WHERE
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) = '201' -- AND CDEPO.COMPANIA='01'  -- TEMPORAL - FILTRO 01
    GROUP BY
        CDEPO.DEPOSITSEQ,
        CDEPO.DEPOSITO,
        CDEPO.EARNINGGROUPID,
        CDEPO.COMPANIA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.FECHA,
        CDEPO.POSICION_COMERCIAL,
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3),
        SUBSTR(C.GENERICATTRIBUTE2, 3, 5),
        CDEPO.PROGRAMA,
        CDEPO.DOC_NIF;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (201) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: 201 NO Diferenciales con reglas de Commission  --  DATOS CABECERA 
    --------------------------------------------------------------------------     
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (201 - Reg.Anual,Gestor,MinR) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        DISTINCT 0 AS POLIZAS,
        CDEPO.DOC_NIF,
        CDEPO.PROGRAMA,
        CDEPO.IMPORTE_TOTAL,
        '' AS PRODUCTO,
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) AS COD_CONCEPTO,
        CDEPO.POSICION_COMERCIAL,
        CDEPO.FECHA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.COMPANIA,
        CDEPO.EARNINGGROUPID,
        CDEPO.DEPOSITO,
        CDEPO.DEPOSITSEQ
    FROM
        :TEMP_LIQEXT_CAB_DEPOSITOS_FILE CDEPO 
    WHERE
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) = '201'
        AND (
            CDEPO.DEPOSITO LIKE 'D-O-DIF-Inspector-Pago-Reg-%'
            OR CDEPO.DEPOSITO LIKE 'D-O-DIF-Gestor-Pago-%'
            OR CDEPO.DEPOSITO = 'D-O-DIF-MinimoR'
        );

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (201 - Reg.Anual,Gestor,MinR) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: DATOS DE LOS AGENTES DE DERECHOS ECONOMICOS  --  DATOS CABECERA 
    --------------------------------------------------------------------------  
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (DDEE) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        DISTINCT 0 AS POLIZAS,
        CDEPO.DOC_NIF,
        CDEPO.PROGRAMA,
        CDEPO.IMPORTE_TOTAL,
        SUBSTR(CDEPO.PRODUCTID, 3, 5) AS PRODUCTO,
        --LLS 20220204: Cargar el campo PRODUCTID en la tabla INYC_LIQEXT_CAB_DEPOSITOS_TEMP
        SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) AS COD_CONCEPTO,
        CDEPO.POSICION_COMERCIAL,
        CDEPO.FECHA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.COMPANIA,
        CDEPO.EARNINGGROUPID,
        CDEPO.DEPOSITO,
        CDEPO.DEPOSITSEQ
    FROM
        :TEMP_LIQEXT_CAB_DEPOSITOS_FILE CDEPO
    WHERE
        CDEPO.DEPOSITO = 'Comisiones Cartera DDEE';

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (DDEE) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: 601 IRPF  --  DATOS CABECERA 
    --------------------------------------------------------------------------        
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (601-IRPF) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        DISTINCT 0 as POLIZAS,
        CCAB.DOC_NIF,
        '        ' AS PROGRAMA,
        SUM(
            CASE
                WHEN CCAB.COD_CONCEPTO = '801' THEN 0
                ELSE CCAB.IMPORTE
            END
        ) * CASE
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'F' --ALM 20170307: A los pagos del S5 de los empleados no se les aplica IRPF.
            --              Ya se habia modificado anteriormente en las facturas del S5
            --THEN CASE WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0 
            --            AND PAD_INS.PARTICIPANTGENERICATTRIBUTE5 = SUBSTR(CCAB.EARNINGGROUPID,7,2)
            --        THEN PAD_INS.PARTICIPANTGENERICNUMBER5 ELSE IRPF.GENERICNUMBER1 END 
            --ALM 20170629: Ponemos IRPF 0 a los agentes pedidos por Javier que apareceran en el NOMEXT
            THEN CASE
                WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE1 IN ('50115742F', '52096024N') THEN 0
                ELSE CASE
                    WHEN CCAB.TIPODOCUMENTO = '5' THEN CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0 THEN 0
                        ELSE IRPF.GENERICNUMBER1
                    END
                    ELSE CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0
                        AND PAD_INS.PARTICIPANTGENERICATTRIBUTE5 = SUBSTR(CCAB.EARNINGGROUPID, 7, 2) --ALM 20181004: Controlamos que si el campo del Participant no esta relleno (es nulo) ponemos un 0.
                        --THEN PAD_INS.PARTICIPANTGENERICNUMBER5 ELSE IRPF.GENERICNUMBER1 END
                        THEN IFNULL(PAD_INS.PARTICIPANTGENERICNUMBER5, 0)
                        ELSE IRPF.GENERICNUMBER1
                    END
                END
            END -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
            --WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'J' AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1,1,1) IN ('G','J','E','U','V')
            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
            --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'J'
            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
            	--AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
            	AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')
            	-- AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 <> 'J72106826' 
            	AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
            THEN IRPF.GENERICNUMBER1
            ELSE 0
        END AS IRPF,
        '00000' AS PRODUCTO,
        '601' AS COD_CONCEPTO,
        CCAB.POSICION_COMERCIAL,
        CCAB.FECHA,
        CCAB.TIPODOCUMENTO,
        CCAB.COMPANIA,
        '' AS EARNINGGROUPID,
        '' AS DEPOSITO,
        0 AS DEPOSITSEQ --ALM 20170227: No tenemos que tener en cuenta los conceptos 801 para el calculo del IRPF.
        --              Pedido por Javier  
    FROM
        :TEMP_LIQEXT_CABECERA_FILE CCAB
        INNER JOIN TCMP.CS_DEPOSIT DEPO ON CCAB.DEPOSITSEQ = DEPO.DEPOSITSEQ
        INNER JOIN TCMP.CS_PLRUN PL ON DEPO.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        AND PL.MODELSEQ = 0 --ALM 20171102: Extraemos de la tabla de jerarquia solo los datos necesarios para evitar duplicidades
        INNER JOIN (
            SELECT
                DISTINCT X.PARTICIPANTSEQ,
                X.POSITIONSEQ,
                X.PERIODSEQ,
             --   X.TAXID,
             -- LFC 20260113 Cogemos el campo TAXID de la tabla cs_participant
                PAR.TAXID,
                X.PARTICIPANTGENERICATTRIBUTE3,
                X.PARTICIPANTGENERICATTRIBUTE1,
                X.PARTICIPANTGENERICNUMBER4,
                X.PARTICIPANTGENERICATTRIBUTE5,
                X.PARTICIPANTGENERICNUMBER5
            FROM
                TCMP.CSA_PADIMENSION X
            -- LFC 20260113 Cogemos el campo TAXID de la tabla cs_participant   
            INNER JOIN TCMP.CSA_PERIODDIMENSION PER
                ON X.PERIODSEQ = PER.PERIODSEQ
            INNER JOIN TCMP.CS_PARTICIPANT PAR    
                ON X.PARTICIPANTSEQ = PAR.PAYEESEQ AND PAR.EFFECTIVESTARTDATE < PER.ENDDATE AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE AND PAR.REMOVEDATE = v_eot
            WHERE
                X.TENANTID = v_idtenant
                AND X.ISPAYEE = 1 --ALM 20180507: Por peticion de Javier excluimos los Participant dados de baja 
                AND (
                    X.TERMINATIONDATE > v_PeriodStartDate
                    OR X.TERMINATIONDATE IS NULL
                )
        ) PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ
        AND PAD_INS.PERIODSEQ = DEPO.PERIODSEQ --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
        INNER JOIN :TEMP_TABLA_IRPF_REP IRPF ON (
            CASE
                WHEN PAD_INS.TAXID IS NULL
                OR CAST(PAD_INS.TAXID AS NVARCHAR(15)) NOT IN ('I', 'E', 'S', 'C') THEN 'P'
                ELSE CAST(PAD_INS.TAXID AS NVARCHAR(15))
            END
        ) = IRPF.NAME
    WHERE
        LPAD(COMPANIA, 2, '0') IN ('01', '03')
    GROUP BY
        CCAB.COMPANIA,
        CCAB.TIPODOCUMENTO,
        CCAB.FECHA,
        CCAB.POSICION_COMERCIAL,
        CASE
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'F' 
            --ALM 20170307: A los pagos del S5 de los empleados no se les aplica IRPF.
            --              Ya se habia modificado anteriormente en las facturas del S5
            --ALM 20170629: Ponemos IRPF 0 a los agentes pedidos por Javier que apareceran en el NOMEXT
            THEN CASE
                WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE1 IN ('50115742F', '52096024N') THEN 0
                ELSE CASE
                    WHEN CCAB.TIPODOCUMENTO = '5' THEN CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0 THEN 0
                        ELSE IRPF.GENERICNUMBER1
                    END
                    ELSE CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0
                        AND PAD_INS.PARTICIPANTGENERICATTRIBUTE5 = SUBSTR(CCAB.EARNINGGROUPID, 7, 2) 
                        --ALM 20181004: Controlamos que si el campo del Participant no esta relleno (es nulo) ponemos un 0.
                        THEN IFNULL(PAD_INS.PARTICIPANTGENERICNUMBER5, 0)
                        ELSE IRPF.GENERICNUMBER1
                    END
                END
            END 
            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
            --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'J'
            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
            	--AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
            	AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')
            	-- AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 <> 'J72106826' 
            	AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
            THEN IRPF.GENERICNUMBER1
            ELSE 0
        END,
        CCAB.DOC_NIF;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (601-IRPF) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: Todos los conceptos de BALANCES  --  DATOS CABECERA 
    --------------------------------------------------------------------------        
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (BALANCES) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        DISTINCT 0 AS POLIZAS,
        SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE2, 1, 1) || PAD_INS.PARTICIPANTGENERICATTRIBUTE1 AS DOC_NIF,
        SUBSTR(DEPO.EARNINGGROUPID, 1, 8) AS PROGRAMA,
        --ALM 20170427:  En los balances no tenemos el nombre del deposito por lo que no podemos unir a las percepciones y sacar el programa
        --              Por peticion de Javier, le paso el EARNINGGROUP aqui para que le sea facil a el cuadrar los datos de tamano 8 caracteres
        DEPO.VALUE AS IMPORTE,
        --ALM 20171102: Quitamos la suma porque los balances ya vienen agrupados por concepto y earninggroup y sino se duplican valores
        '' AS PRODUCTO,
        --ALM 20170427:  En los balances no tenemos el producto
        SUBSTR(DEPO.EARNINGCODEID, 1, 3) AS COD_CONCEPTO,
        SUBSTR(PAD_INS.POSITIONGENERICATTRIBUTE3, 1, 10) AS POSICION_COMERCIAL,
        PD.STARTDATE AS FECHA,
        --ALM 20170427: Ponemos la fecha final de mes para que saque el mes siguiente que el que corresponde
        --ALM 20170531: No vale si sacamos balances de varios meses. Ponemos la STARTDATE del periodo en el que se pide el fichero
        SUBSTR(DEPO.EARNINGGROUPID, 5, 1) AS TIPODOCUMENTO,
        SUBSTR(DEPO.EARNINGGROUPID, 7, 2) AS COMPANIA,
        DEPO.EARNINGGROUPID AS EARNINGGROUPID,
        '' AS DEPOSITO,
        --ALM 20170427:  En los balances no tenemos el nombre del deposito
        DEPO.BALANCESEQ AS DEPOSITSEQ
    FROM
        TCMP.CS_BALANCE DEPO --ALM 20170608: Unimos los balances con los pagos para filtrar balances que finalmente no se abonen en el periodo
        INNER JOIN TCMP.CS_BALANCEPAYMENTTRACE BPAY ON DEPO.BALANCESEQ = BPAY.BALANCESEQ
        INNER JOIN TCMP.CS_PAYMENT PAY ON BPAY.PAYMENTSEQ = PAY.PAYMENTSEQ
        AND PAY.PERIODSEQ = v_periodSeq
        LEFT JOIN TCMP.CSA_PADIMENSION PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ 
        --ALM 20170515: Por peticion de Javier cogemos los datos de la jerarquia del mes actual no del del balance
        AND PAD_INS.PERIODSEQ = v_periodSeq
        AND PAD_INS.TENANTID = v_idtenant
        AND PAD_INS.ISPAYEE = 1 
        --ALM 20170515: Por peticion de Javier no tenemos en cuenta los depositos de los payees dados de baja
        AND (
            PAD_INS.TERMINATIONDATE > v_PeriodStartDate
            OR PAD_INS.TERMINATIONDATE IS NULL
        ) --ALM 20170531: Unimos el periodo con la jerarquia para tener el actual
        INNER JOIN TCMP.CSA_PERIODDIMENSION PD ON PAD_INS.PERIODSEQ = PD.PERIODSEQ
        AND PD.TENANTID = v_idtenant 
        --ALM 20170427:  En los balances no tenemos el nombre del deposito por lo que no podemos unir a las percepciones
    WHERE
        DEPO.TENANTID = v_idtenant
        AND DEPO.APPLYPIPELINERUNDATE < ADD_DAYS(PD.ENDDATE, 1)
        AND DEPO.APPLYPIPELINERUNDATE > PD.STARTDATE;

    
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (BALANCES) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: 601 IRPF BALANCES  --  DATOS CABECERA 
    --------------------------------------------------------------------------     
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (601-IRPF-BALANCES) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        DISTINCT 0 as POLIZAS,
        CCAB.DOC_NIF,
        '        ' as PROGRAMA,
        --ALM 20170227: No tenemos que tener en cuenta los conceptos 801 para el calculo del IRPF.
        --              Pedido por Javier  
        SUM(
            CASE
                WHEN CCAB.COD_CONCEPTO = '801' THEN 0
                ELSE CCAB.IMPORTE
            END
        ) * CASE
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'F' --ALM 20170307: A los pagos del S5 de los empleados no se les aplica IRPF.           
            THEN CASE
                WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE1 IN ('50115742F', '52096024N') THEN 0
                ELSE CASE
                    WHEN CCAB.TIPODOCUMENTO = '5' THEN CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0 THEN 0
                        ELSE IRPF.GENERICNUMBER1
                    END
                    ELSE CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0
                        AND PAD_INS.PARTICIPANTGENERICATTRIBUTE5 = SUBSTR(CCAB.EARNINGGROUPID, 7, 2) 
                        --ALM 20181004: Controlamos que si el campo del Participant no esta relleno (es nulo) ponemos un 0.
                        THEN IFNULL(PAD_INS.PARTICIPANTGENERICNUMBER5, 0)
                        ELSE IRPF.GENERICNUMBER1
                    END
                END
            END 
            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF   
            --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'J'
            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
            	--AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
            	AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')
            	-- AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 <> 'J72106826' 
            	AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
            THEN IRPF.GENERICNUMBER1
            ELSE 0
        END AS IRPF,
        '00000' AS PRODUCTO,
        '601' AS COD_CONCEPTO,
        CCAB.POSICION_COMERCIAL,
        CCAB.FECHA,
        CCAB.TIPODOCUMENTO,
        CCAB.COMPANIA,
        '' AS EARNINGGROUPID,
        '' AS DEPOSITO,
        0 AS DEPOSITSEQ
    FROM
        :TEMP_LIQEXT_CABECERA_FILE CCAB
        INNER JOIN TCMP.CS_BALANCE DEPO ON CCAB.DEPOSITSEQ = DEPO.BALANCESEQ --ALM 20170608: Unimos los balances con los pagos para filtrar balances que finalmente no se abonen en el periodo
        INNER JOIN TCMP.CS_BALANCEPAYMENTTRACE BPAY ON DEPO.BALANCESEQ = BPAY.BALANCESEQ
        INNER JOIN TCMP.CS_PAYMENT PAY ON BPAY.PAYMENTSEQ = PAY.PAYMENTSEQ
        AND PAY.PERIODSEQ = v_periodSeq --ALM 20171102: Extraemos de la tabla de jerarquia solo los datos necesarios para evitar duplicidades       
        INNER JOIN (
            SELECT
                DISTINCT X.PARTICIPANTSEQ,
                X.POSITIONSEQ,
             --   X.TAXID,
             -- LFC 20260113 Cogemos el campo TAXID de la tabla cs_participant
                PAR.TAXID,
                X.PARTICIPANTGENERICATTRIBUTE3,
                X.PARTICIPANTGENERICATTRIBUTE1,
                X.PARTICIPANTGENERICNUMBER4,
                X.PARTICIPANTGENERICATTRIBUTE5,
                X.PARTICIPANTGENERICNUMBER5
            FROM
                TCMP.CSA_PADIMENSION X
            -- LFC 20260113 Cogemos el campo TAXID de la tabla cs_participant   
            INNER JOIN TCMP.CSA_PERIODDIMENSION PER
                ON X.PERIODSEQ = PER.PERIODSEQ
            INNER JOIN TCMP.CS_PARTICIPANT PAR    
                ON X.PARTICIPANTSEQ = PAR.PAYEESEQ AND PAR.EFFECTIVESTARTDATE < PER.ENDDATE AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE AND PAR.REMOVEDATE = v_eot
            WHERE
                X.TENANTID = v_idtenant
                AND X.ISPAYEE = 1
                AND X.PERIODSEQ = v_periodSeq --ALM 20180507: Por peticion de Javier excluimos los Participant dados de baja 
                AND (
                    X.TERMINATIONDATE > v_PeriodStartDate
                    OR X.TERMINATIONDATE IS NULL
                )
        ) PAD_INS ON PAD_INS.PARTICIPANTSEQ = DEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = DEPO.POSITIONSEQ --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.       
        INNER JOIN :TEMP_TABLA_IRPF_REP IRPF ON (
            CASE
                WHEN PAD_INS.TAXID IS NULL
                OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I', 'E', 'S', 'C') THEN 'P'
                ELSE CAST(PAD_INS.TAXID AS VARCHAR(15))
            END
        ) = IRPF.NAME
    WHERE
        LPAD(COMPANIA, 2, '0') IN ('01', '03')
    GROUP BY
        CCAB.COMPANIA,
        CCAB.TIPODOCUMENTO,
        CCAB.FECHA,
        CCAB.POSICION_COMERCIAL,
        CASE
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'F' --ALM 20170307: A los pagos del S5 de los empleados no se les aplica IRPF.          
            THEN CASE
                WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE1 IN ('50115742F', '52096024N') THEN 0
                ELSE CASE
                    WHEN CCAB.TIPODOCUMENTO = '5' THEN CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0 THEN 0
                        ELSE IRPF.GENERICNUMBER1
                    END
                    ELSE CASE
                        WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                        AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0
                        AND PAD_INS.PARTICIPANTGENERICATTRIBUTE5 = SUBSTR(CCAB.EARNINGGROUPID, 7, 2) 
                        --ALM 20181004: Controlamos que si el campo del Participant no esta relleno (es nulo) ponemos un 0.
                        THEN IFNULL(PAD_INS.PARTICIPANTGENERICNUMBER5, 0)
                        ELSE IRPF.GENERICNUMBER1
                    END
                END
            END -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF      
            --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
            WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'J'
            	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
            	--AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
            	AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')
            	-- AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 <> 'J72106826' 
            	AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
            THEN IRPF.GENERICNUMBER1
            ELSE 0
        END,
        CCAB.DOC_NIF;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (601-IRPF-BALANCES) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --------------------------------------------------------------------------    
    -- CABECERA: 601 IRPF DDEE  --  DATOS CABECERA 
    --------------------------------------------------------------------------        
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio extraccion DATOS CABECERA (601-IRPF-DDEE) TEMP_LIQEXT_CABECERA_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        :TEMP_LIQEXT_CABECERA_FILE(
            POLIZAS,
            DOC_NIF,
            PROGRAMA,
            IMPORTE,
            PRODUCTO,
            COD_CONCEPTO,
            POSICION_COMERCIAL,
            FECHA,
            TIPODOCUMENTO,
            COMPANIA,
            EARNINGGROUPID,
            DEPOSITO,
            DEPOSITSEQ
        )
    SELECT
        0 as POLIZAS,
        CDEPO.DOC_NIF,
        '        ' AS PROGRAMA,
        SUM (
            CDEPO.IMPORTE_TOTAL * CASE
                WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'F' THEN CASE
                    WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE1 IN ('50115742F', '52096024N') THEN 0 
                    ELSE CASE
                        WHEN CDEPO.TIPODOCUMENTO = '5' THEN CASE
                            WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                            AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0 THEN 0
                            ELSE IRPF.GENERICNUMBER1
                        END
                        ELSE CASE
                            WHEN PAD_INS.PARTICIPANTGENERICNUMBER4 IS NOT NULL
                            AND PAD_INS.PARTICIPANTGENERICNUMBER4 <> 0 
                            AND PAD_INS.PARTICIPANTGENERICATTRIBUTE5 = SUBSTR(CDEPO.EARNINGGROUPID, 7, 2) THEN IFNULL(PAD_INS.PARTICIPANTGENERICNUMBER5, 0)
                            ELSE IRPF.GENERICNUMBER1
                        END
                    END
                END
                --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
                WHEN PAD_INS.PARTICIPANTGENERICATTRIBUTE3 = 'J'
                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	            	--AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
	            	AND SUBSTR(PAD_INS.PARTICIPANTGENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')
                	-- AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 <> 'J72106826' 
                	AND PAD_INS.PARTICIPANTGENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
                THEN IRPF.GENERICNUMBER1
                ELSE 0
            END
        ) AS IMPORTE,
        '00000' AS PRODUCTO,
        '601' AS COD_CONCEPTO, 
        CDEPO.POSICION_COMERCIAL,
        CDEPO.FECHA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.COMPANIA,
        '' AS EARNINGGROUPID,
        'Comisiones Cartera DDEE' AS DEPOSITO,
        0 AS DEPOSITSEQ 
    FROM
        :TEMP_LIQEXT_CAB_DEPOSITOS_FILE CDEPO
        INNER JOIN (
            SELECT
                DISTINCT X.PARTICIPANTSEQ,
                X.POSITIONSEQ,
                X.PERIODSEQ,
             --   X.TAXID,
             -- LFC 20260113 Cogemos el campo TAXID de la tabla cs_participant
                PAR.TAXID,
                X.PARTICIPANTGENERICATTRIBUTE3,
                X.PARTICIPANTGENERICATTRIBUTE1,
                X.PARTICIPANTGENERICNUMBER4,
                X.PARTICIPANTGENERICATTRIBUTE5,
                X.PARTICIPANTGENERICNUMBER5
            FROM
                TCMP.CSA_PADIMENSION X
            -- LFC 20260113 Cogemos el campo TAXID de la tabla cs_participant   
            INNER JOIN TCMP.CSA_PERIODDIMENSION PER
                ON X.PERIODSEQ = PER.PERIODSEQ
            INNER JOIN TCMP.CS_PARTICIPANT PAR    
                ON X.PARTICIPANTSEQ = PAR.PAYEESEQ AND PAR.EFFECTIVESTARTDATE < PER.ENDDATE AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE AND PAR.REMOVEDATE = v_eot
            WHERE
                X.TENANTID = v_idtenant
                AND X.ISPAYEE = 1
                AND X.PERIODSEQ = v_periodSEQ 
                --ALM 20180507: Por peticion de Javier excluimos los Participant dados de baja 
                AND (
                    X.TERMINATIONDATE > TO_DATE('20220101', 'YYYYMMDD')
                    OR X.TERMINATIONDATE IS NULL
                )
        ) PAD_INS ON PAD_INS.PARTICIPANTSEQ = CDEPO.PAYEESEQ
        AND PAD_INS.POSITIONSEQ = CDEPO.POSITIONSEQ
        AND PAD_INS.PERIODSEQ = CDEPO.PERIODSEQ 
        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
        INNER JOIN :TEMP_TABLA_IRPF_REP IRPF ON (
            CASE
                WHEN PAD_INS.TAXID IS NULL
                OR CAST(PAD_INS.TAXID AS VARCHAR(15)) NOT IN ('I', 'E', 'S', 'C') THEN 'P'
                ELSE CAST(PAD_INS.TAXID AS VARCHAR(15))
            END
        ) = IRPF.NAME
    WHERE
        LPAD(CDEPO.COMPANIA, 2, '0') IN ('01', '03')
        AND CDEPO.DEPOSITO = 'Comisiones Cartera DDEE'
        AND CDEPO.PRODUCTID IS NOT NULL 
        AND SUBSTR(CDEPO.COD_CONCEPTO, 1, 3) <> '601'
    GROUP BY
        CDEPO.COMPANIA,
        CDEPO.TIPODOCUMENTO,
        CDEPO.FECHA,
        CDEPO.POSICION_COMERCIAL,
        CDEPO.DOC_NIF;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin extraccion DATOS CABECERA (601-IRPF-DDEE) TEMP_LIQEXT_CABECERA_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    ----------------------------------------------------    
    -- CABECERA: INFORME FINAL   
    ----------------------------------------------------
    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Inicio INFORME FINAL - OUT_LIQEXT_CAB_INFORME_FILE ',v_log_count,v_idproceso,'info');

    INSERT INTO
        EXT.OUT_LIQEXT_CAB_INFORME_FILE(LINE)
    SELECT
        LPAD(COMPANIA, 2, '0')
        || TIPODOCUMENTO
        || TO_NVARCHAR(FECHA, 'YYYYMM')
        || LPAD(IFNULL(POSICION_COMERCIAL, '0'), 10, '0')
        || SUBSTR(COD_CONCEPTO, 1, 3)
        || CASE
            WHEN PRODUCTO is null
                THEN '00000'
                else LPAD(PRODUCTO, 5, '0')
            end
        || CASE
            WHEN IMPORTE >= 0
                THEN '+'
                ELSE '-'
            END
        || LPAD(floor(abs(ROUND(IMPORTE, 2))), 9, '0')
        || ','
        || LPAD((abs(mod(ROUND(IMPORTE, 2), 1) * 100)), 2, '0')
        || CASE
            WHEN PROGRAMA is NULL
                THEN '        '
                ELSE RPAD(PROGRAMA, 8, ' ')
            END
        --|| RPAD(DOC_NIF, 11, ' ')
        --SMM 20250909 DOC_NIF NULL
        || CASE WHEN DOC_NIF IS NULL THEN '           ' ELSE RPAD(DOC_NIF, 11, ' ') END
        || CASE
            WHEN POLIZAS >= 0
                THEN '+'
                ELSE '-'
            END
        || LPAD(floor(abs(ROUND(POLIZAS, 2))), 3, '0') 
        || ',' 
        || LPAD((abs(mod(ROUND(POLIZAS, 2), 1) * 100)), 2, '0')
    FROM
        :TEMP_LIQEXT_CABECERA_FILE
    where
        LPAD(COMPANIA, 2, '0') IN ('01', '03');
    COMMIT;

    CALL LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'CAB-Fin INFORME FINAL - OUT_LIQEXT_CAB_INFORME_FILE ' || To_VARCHAR(::ROWCOUNT) || ' filas.',v_log_count,v_idproceso,'info');

    --Pasamos contenido de la tabla temporal a la física
    INSERT INTO EXT.TEMP_LIQEXT_CABECERA_FILE (POLIZAS,DOC_NIF,PROGRAMA,IMPORTE,PRODUCTO,COD_CONCEPTO,POSICION_COMERCIAL,FECHA,TIPODOCUMENTO,COMPANIA,EARNINGGROUPID,DEPOSITO,DEPOSITSEQ)
    SELECT POLIZAS,DOC_NIF,PROGRAMA,IMPORTE,PRODUCTO,COD_CONCEPTO,POSICION_COMERCIAL,FECHA,TIPODOCUMENTO,COMPANIA,EARNINGGROUPID,DEPOSITO,DEPOSITSEQ FROM :TEMP_LIQEXT_CABECERA_FILE;


    UPDATE
        EXT.OUT_BATCH_CONTROL
    SET
        STATUS = v_const_out_batch_control_ok,
        FILE_NAME = FILENAME,
        TARGET_ROWS = v_num_rows,
        END_DATE = CURRENT_TIMESTAMP
    WHERE ID_PROCESO = v_idproceso;

    --FIN
    CALL EXT.LIB_CONSTANTES :WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...',v_log_count,v_idproceso,'info');

  
   

END