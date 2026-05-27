CREATE OR REPLACE PROCEDURE EXT.SP_CARGA_BASES_REPARTO(IN i_par_tipo_ejecucion INTEGER, IN i_tipo_reparto VARCHAR(10), IN i_periodseq BIGINT, IN i_fecha_reparto DATE
	, IN i_proc_name_principal VARCHAR(50) ,IN v_idproceso INTEGER, INOUT v_log_count INTEGER)
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 08-Abril-2026
    |----------------------------------------------------------------------
    | Procedure Purpose: Carga Bases de Reparto
	|
	| Version: 0.1	SMM 20260410		Initial Version.
	|
    -----------------------------------------------------------------------
*/
BEGIN

	DECLARE v_proc_name VARCHAR(50) := i_proc_name_principal;
	DECLARE v_proc_name_secundario VARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR(10) := '0.1';
	DECLARE v_num_rows BIGINT := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	-- DECLARE v_log_count BIGINT := 0;
	-- DECLARE v_idproceso BIGINT;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE = EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_periodSeq BIGINT;
	DECLARE v_PeriodName VARCHAR(255);
	DECLARE v_PeriodStartDate TIMESTAMP;
    DECLARE v_PeriodEndDate TIMESTAMP;
	DECLARE v_fechaliquidacion VARCHAR(6);
	-- DECLARE i_fecha_reparto DATE;
	DECLARE v_caracter_unicode_49824 VARCHAR(5) := '힀';
	DECLARE i_periodSeq_anterior BIGINT;
	DECLARE v_PeriodName_anterior VARCHAR(255);
	DECLARE v_PeriodStartDateCierre TIMESTAMP;
    DECLARE v_PeriodEndDate_anterior TIMESTAMP;
	
	
	-- CONTROLADOR DE EXCEPCIONES
	DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK;
        CALL EXT.LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,v_proc_name_secundario || ' Error en procedimiento principal ' || v_proc_name_secundario || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE, '') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE,v_log_count,v_idproceso,'error');
        
	    COMMIT;
        -- RESIGNAL;

    END;
    
    --Rellenamos las variables de entrada del procedimiento si se ejecuta por separado de la carga.
	IF v_idproceso = 0 THEN
		v_log_count := 0;
		-- SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	END IF;
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
    
    IF i_tipo_reparto = 'BALANCE' THEN
    	SELECT STARTDATE INTO v_PeriodStartDateCierre FROM CS_PERIOD WHERE PERIODSEQ = i_PeriodSeq;
    	
    	SELECT PERIODSEQ,PER.NAME,STARTDATE,ENDDATE INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate,v_PeriodEndDate
		FROM CS_PERIOD PER
		INNER JOIN TCMP.CS_CALENDAR CAL ON CAL.CALENDARSEQ = PER.CALENDARSEQ
			AND CAL.REMOVEDATE = v_eot
			AND UPPER(CAL.NAME) = 'MAIN MONTHLY CALENDAR'
		WHERE PER.PERIODTYPESEQ = 2814749767106561 AND PER.REMOVEDATE = v_eot
			AND PER.ENDDATE = v_PeriodStartDateCierre
		;
		
		i_PeriodSeq := v_PeriodSeq;
	
		
		SELECT MAX(PL.STARTTIME) INTO i_fecha_reparto
    	FROM TCMP.CS_PLRUN PL
    	WHERE PL.RUNPARAMETERS LIKE '%[Sequence]CompensateAndPay%'
        	AND PL.COMMAND = 'PipelineRun'
        	AND PL.STATUS = 'Successful'
        	AND PL.PERIODSEQ = i_PeriodSeq
        	AND PL.STARTTIME < (
        	    --Usamos la fecha del ultimo Post ejecutado anterior al Finalize del periodo, si se ha realizado sino cogemos la fecha del ultimo Post ejecutado anterior a la fecha actual. 
        	    SELECT MAX(X.STARTTIME) FROM TCMP.CS_PLRUN X
        	    WHERE X.RUNPARAMETERS LIKE '%[Sequence]Post%'
        	        AND X.COMMAND = 'PipelineRun'
        	        AND X.STATUS = 'Successful'
        	        AND X.PERIODSEQ = i_PeriodSeq
			)
		;
		
		
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Variable i_fecha_reparto (FECHA REPARTO BALANCE): ' || i_fecha_reparto, v_log_count, v_idproceso, 'info');     
   
		
		
	
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Periodo obtenido BALANCE (NUEVA BASE REPARTO) = ' || v_PeriodName || ' PeriodSeq: ' || v_periodSeq || ' StartDate: ' || v_PERIODSTARTDATE || ' EndDate: ' || v_PeriodEndDate, v_log_count, v_idproceso, 'info');
	
    
    END IF;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Parámetros entrada. i_tipo_reparto: ' || i_tipo_reparto || ' ,i_PERIODSEQ: ' || i_PERIODSEQ || ' i_fecha_reparto: ' || i_fecha_reparto, v_log_count, v_idproceso, 'info');
	
	
    --TEMP_REPEXT_TXN_FILE -->     TEMP_REPEXT_TXN_FILE_NUEVA_BASE_REPARTO
    IF (i_par_tipo_ejecucion = 1 AND i_tipo_reparto = 'CIERRE') THEN 
    
    	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.TEMP_REPEXT_TXN_FILE';
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Inicio Carga de la tabla TEMP_REPEXT_TXN_FILE.', v_log_count, v_idproceso, 'info');
        
        INSERT INTO EXT.TEMP_REPEXT_TXN_FILE(SALESTRANSACTIONSEQ,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,COMPENSATIONDATE,POSITIONNAME,POS_PRIN,PRODUCTID,
        	VALUE,POLIZA,ESTADO,PRIMA_NETA,INCR_PRIMA,SUPLEMENTO,FECHA_EFECTO,FECHA_EMISION,FECHA_VTO_RECIBO,AUTOLIQUIDA
        )
        SELECT 
			--Cogemos el campo SALESTRANSACTIONSEQ de la tabla de transacciones ya que siempre debe ser el mismo aunque haya ajustes.
            ST.SALESTRANSACTIONSEQ,
			--Buscamos el ORDERID dependiendo si se ha modificado la transaccion o no.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL
            	THEN (SELECT SO.ORDERID FROM TCMP.CS_SALESORDER SO WHERE SO.SALESORDERSEQ = TJ.SALESORDERSEQ
                	AND SO.TENANTID = v_idtenant AND SO.PROCESSINGUNITSEQ = 38280596832649217 AND SO.REMOVEDATE = v_eot)
                    --JGE 20230531 por unas transacciones manuales de Javier sin orderid se pone el filtro para que no falle el reparto
                    --ELSE (SO.ORDERID FROM TCMP.CS_SALESORDER SO WHERE SO.SALESORDERSEQ = ST.SALESORDERSEQ
                    --AND SO.TENANTID = v_idtenant AND SO.PROCESSINGUNITSEQ = 38280596832649217 AND SO.REMOVEDATE = v_eot)
                ELSE SO.ORDERID
            END) ORDERID,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.LINENUMBER ELSE ST.LINENUMBER END) LINENUMBER,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.SUBLINENUMBER ELSE ST.SUBLINENUMBER END) SUBLINENUMBER,
            --Buscamos el EVENTTYPEID dependiendo si se ha modificado la transaccion o no.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL
                THEN (SELECT ET.EVENTTYPEID FROM TCMP.CS_EVENTTYPE ET WHERE ET.DATATYPESEQ = TJ.EVENTTYPESEQ
                      AND ET.TENANTID = v_idtenant AND ET.REMOVEDATE = v_eot)
                ELSE (SELECT ET.EVENTTYPEID FROM TCMP.CS_EVENTTYPE ET WHERE ET.DATATYPESEQ = ST.EVENTTYPESEQ
                      AND ET.TENANTID = v_idtenant AND ET.REMOVEDATE = v_eot)
            END) EVENTTYPEID,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL 
                THEN TO_DATE(TO_CHAR(TJ.COMPENSATIONDATE,'YYYYMM') || '01','YYYYMMDD')
                ELSE TO_DATE(TO_CHAR(ST.COMPENSATIONDATE,'YYYYMM') || '01','YYYYMMDD')
            END) COMPENSATIONDATE,
            TA.POSITIONNAME,
			--Control para transacciones modificadas manualmente que incluyen un codigo erroneo.
           --Quitamos espacios y el caracter extrano con ascii 49824 para evitar errores manuales al crear pagos comerciales.
            (CASE 
			    WHEN LENGTH(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))) < 5 
			        THEN SUBSTRING(RIGHT(CONCAT(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, '')), '0000000000'), 10), 1, 10)
			    WHEN LENGTH(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))) BETWEEN 5 AND 9 
			        THEN RIGHT(CONCAT('0000000000', TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))), 10)
			    WHEN LENGTH(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))) = 10 
			        THEN TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))
			    ELSE '0000000000'
			END) AS POS_PRIN ,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.PRODUCTID ELSE ST.PRODUCTID END) PRODUCTID,
            --Comprobar que campo es el correspondiente (TOTALADJUSTVALUE) y si siempre esta relleno o solo si se ha modificado.
            ST.VALUE,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICATTRIBUTE1 ELSE ST.GENERICATTRIBUTE1 END) AS POLIZA,
            --Para los pagos Comercilaes devolvemos el GENERICATTRIBUTE2 que corresponde con el earningcodeid.
            --(CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICATTRIBUTE6 ELSE ST.GENERICATTRIBUTE6 END) AS ESTADO,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL
                --Usamos el EVENTTYPESEQ de los Pagos Comerciales para no tener que hacer la subconsulta de nuevo.
                THEN (CASE WHEN TJ.EVENTTYPESEQ = 16607023625929688 THEN TJ.GENERICATTRIBUTE2 ELSE TJ.GENERICATTRIBUTE6 END)
                ELSE (CASE WHEN ST.EVENTTYPESEQ = 16607023625929688 THEN ST.GENERICATTRIBUTE2 ELSE ST.GENERICATTRIBUTE6 END)
            END) AS ESTADO,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICNUMBER1 ELSE ST.GENERICNUMBER1 END) AS PRIMA_NETA,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICNUMBER2 ELSE ST.GENERICNUMBER2 END) AS INCR_PRIMA,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICATTRIBUTE9 ELSE ST.GENERICATTRIBUTE9 END) AS SUPLEMENTO,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICDATE1 ELSE ST.GENERICDATE1 END) AS FECHA_EFECTO,
            --Necesitamos la FECHA_EMISION para coger el Manager al que se le paga por esa poliza.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICDATE2 ELSE ST.GENERICDATE2 END) AS FECHA_EMISION,
            TA.GENERICDATE1 AS FECHA_VTO_RECIBO,
            --Necesitamos el boolean de AUTOLIQUIDA para diferenciar las polizas de los pagos de autoliquidacion.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICBOOLEAN6 ELSE ST.GENERICBOOLEAN6 END) AS AUTOLIQUIDA
        FROM TCMP.CS_SALESTRANSACTION ST
                INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    AND TA.TENANTID = v_idtenant AND TA.PROCESSINGUNITSEQ = 38280596832649217
                --por unas transacciones manuales de Javier sin orderid se pone el filtro para que no falle el reparto
                INNER JOIN TCMP.CS_SALESORDER SO ON ST.SALESORDERSEQ = SO.SALESORDERSEQ
                    AND SO.TENANTID = v_idtenant AND SO.PROCESSINGUNITSEQ = 38280596832649217 AND SO.REMOVEDATE = v_eot
                    AND SO.ORDERID IS NOT NULL
                --No tenemos en cuenta las transacciones subidas despues del cierre.
                LEFT JOIN TCMP.CS_PLRUN PL ON ST.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND PL.TENANTID = v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217 AND PL.MODELSEQ = 0
                    AND PL.REMOVEDATE = v_eot
                    AND PL.COMMAND = 'Import' AND PL.RUNPARAMETERS LIKE '%[Sequence]ValidateAndTransfer%'
                --Cogemos la version de la transaccion si existe que se corresponde con la fecha del cierre.
                LEFT JOIN TCMP.CS_TRANSACTIONADJUSTMENT TJ ON ST.SALESTRANSACTIONSEQ = TJ.SALESTRANSACTIONSEQ
                    AND ST.COMPENSATIONDATE = TJ.COMPENSATIONDATE
                    AND TJ.TENANTID = v_idtenant AND TJ.PROCESSINGUNITSEQ = 38280596832649217
                    AND TJ.CREATEDATE < i_fecha_reparto
                    AND TJ.REMOVEDATE > i_fecha_reparto
        WHERE ST.TENANTID = v_idtenant AND ST.PROCESSINGUNITSEQ = 38280596832649217 AND ST.MODELSEQ = 0
            AND TO_CHAR(ST.COMPENSATIONDATE,'YYYYMM') = TO_CHAR(v_periodStartDate,'YYYYMM')
            --Cogemos las transacciones de los ficheros subidos anteriores al ultimo calculo o los subidos a mano.
            AND (PL.STARTTIME < i_fecha_reparto
            --De las transacciones subidas a mano solo cogemos aquellas que sean anteriores a la fechas del cierre.  
            OR (PL.PIPELINERUNSEQ IS NULL AND ST.MODIFICATIONDATE < i_fecha_reparto))
        ;
        
        v_num_rows = RECORD_COUNT(EXT.TEMP_REPEXT_TXN_FILE);
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Fin Carga de la tabla TEMP_REPEXT_TXN_FILE: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        
        
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Inicio Carga de la tabla TEMP_REPEXT_CREDITOS_FILE.', v_log_count, v_idproceso, 'info');

        -- TEMP_REPEXT_CREDITOS_FILE = 
        --     SELECT C.CREDITSEQ,
        --         C.SALESTRANSACTIONSEQ,
        --         C.PAYEESEQ,
        --         C.POSITIONSEQ,
        --         C.PERIODSEQ,
        --         C.NAME,
        --         C.VALUE,
        --         C.GENERICNUMBER4,
        --         C.GENERICNUMBER5,
        --         --ALM 20221115: Incluimos nuevo campo Cambio Agente Inspector (GB3) necesario para descartar trx en el calculo de diferenciales y locomocion.
        --         C.GENERICBOOLEAN3
        --     FROM TCMP.CS_CREDIT C
        --         INNER JOIN TCMP.CS_PLRUN PL ON C.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
        --             AND PL.TENANTID = v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217 AND PL.MODELSEQ = 0
        --     WHERE C.TENANTID = v_idtenant AND C.PROCESSINGUNITSEQ = 38280596832649217 AND C.PERIODSEQ = i_periodSeq
        --     ;
            
        -- v_num_rows = RECORD_COUNT(:TEMP_REPEXT_CREDITOS_FILE);
        -- CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name_secundario, 'Fin Carga de la tabla TEMP_REPEXT_CREDITOS_FILE: ' || v_num_rows, v_log_count, v_idproceso, 'info'); 
        
    ELSEIF (i_par_tipo_ejecucion = 1 AND i_tipo_reparto = 'BALANCE') THEN
    
    	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.TEMP_REPEXT_TXN_FILE_NUEVA_BASE_REPARTO';
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Inicio Carga de la tabla TEMP_REPEXT_TXN_FILE_NUEVA_BASE_REPARTO.', v_log_count, v_idproceso, 'info');
    	
    	INSERT INTO EXT.TEMP_REPEXT_TXN_FILE_NUEVA_BASE_REPARTO(SALESTRANSACTIONSEQ,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,COMPENSATIONDATE,POSITIONNAME,POS_PRIN,PRODUCTID,
        	VALUE,POLIZA,ESTADO,PRIMA_NETA,INCR_PRIMA,SUPLEMENTO,FECHA_EFECTO,FECHA_EMISION,FECHA_VTO_RECIBO,AUTOLIQUIDA
        )
        SELECT 
			--Cogemos el campo SALESTRANSACTIONSEQ de la tabla de transacciones ya que siempre debe ser el mismo aunque haya ajustes.
            ST.SALESTRANSACTIONSEQ,
			--Buscamos el ORDERID dependiendo si se ha modificado la transaccion o no.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL
            	THEN (SELECT SO.ORDERID FROM TCMP.CS_SALESORDER SO WHERE SO.SALESORDERSEQ = TJ.SALESORDERSEQ
                	AND SO.TENANTID = v_idtenant AND SO.PROCESSINGUNITSEQ = 38280596832649217 AND SO.REMOVEDATE = v_eot)
                    --JGE 20230531 por unas transacciones manuales de Javier sin orderid se pone el filtro para que no falle el reparto
                    --ELSE (SO.ORDERID FROM TCMP.CS_SALESORDER SO WHERE SO.SALESORDERSEQ = ST.SALESORDERSEQ
                    --AND SO.TENANTID = v_idtenant AND SO.PROCESSINGUNITSEQ = 38280596832649217 AND SO.REMOVEDATE = v_eot)
                ELSE SO.ORDERID
            END) ORDERID,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.LINENUMBER ELSE ST.LINENUMBER END) LINENUMBER,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.SUBLINENUMBER ELSE ST.SUBLINENUMBER END) SUBLINENUMBER,
            --Buscamos el EVENTTYPEID dependiendo si se ha modificado la transaccion o no.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL
                THEN (SELECT ET.EVENTTYPEID FROM TCMP.CS_EVENTTYPE ET WHERE ET.DATATYPESEQ = TJ.EVENTTYPESEQ
                      AND ET.TENANTID = v_idtenant AND ET.REMOVEDATE = v_eot)
                ELSE (SELECT ET.EVENTTYPEID FROM TCMP.CS_EVENTTYPE ET WHERE ET.DATATYPESEQ = ST.EVENTTYPESEQ
                      AND ET.TENANTID = v_idtenant AND ET.REMOVEDATE = v_eot)
            END) EVENTTYPEID,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL 
                THEN TO_DATE(TO_CHAR(TJ.COMPENSATIONDATE,'YYYYMM') || '01','YYYYMMDD')
                ELSE TO_DATE(TO_CHAR(ST.COMPENSATIONDATE,'YYYYMM') || '01','YYYYMMDD')
            END) COMPENSATIONDATE,
            TA.POSITIONNAME,
			--Control para transacciones modificadas manualmente que incluyen un codigo erroneo.
           --Quitamos espacios y el caracter extrano con ascii 49824 para evitar errores manuales al crear pagos comerciales.
            (CASE 
			    WHEN LENGTH(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))) < 5 
			        THEN SUBSTRING(RIGHT(CONCAT(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, '')), '0000000000'), 10), 1, 10)
			    WHEN LENGTH(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))) BETWEEN 5 AND 9 
			        THEN RIGHT(CONCAT('0000000000', TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))), 10)
			    WHEN LENGTH(TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))) = 10 
			        THEN TRIM(REPLACE(TA.GENERICATTRIBUTE3, v_caracter_unicode_49824, ''))
			    ELSE '0000000000'
			END) AS POS_PRIN ,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.PRODUCTID ELSE ST.PRODUCTID END) PRODUCTID,
            --Comprobar que campo es el correspondiente (TOTALADJUSTVALUE) y si siempre esta relleno o solo si se ha modificado.
            ST.VALUE,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICATTRIBUTE1 ELSE ST.GENERICATTRIBUTE1 END) AS POLIZA,
            --Para los pagos Comercilaes devolvemos el GENERICATTRIBUTE2 que corresponde con el earningcodeid.
            --(CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICATTRIBUTE6 ELSE ST.GENERICATTRIBUTE6 END) AS ESTADO,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL
                --Usamos el EVENTTYPESEQ de los Pagos Comerciales para no tener que hacer la subconsulta de nuevo.
                THEN (CASE WHEN TJ.EVENTTYPESEQ = 16607023625929688 THEN TJ.GENERICATTRIBUTE2 ELSE TJ.GENERICATTRIBUTE6 END)
                ELSE (CASE WHEN ST.EVENTTYPESEQ = 16607023625929688 THEN ST.GENERICATTRIBUTE2 ELSE ST.GENERICATTRIBUTE6 END)
            END) AS ESTADO,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICNUMBER1 ELSE ST.GENERICNUMBER1 END) AS PRIMA_NETA,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICNUMBER2 ELSE ST.GENERICNUMBER2 END) AS INCR_PRIMA,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICATTRIBUTE9 ELSE ST.GENERICATTRIBUTE9 END) AS SUPLEMENTO,
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICDATE1 ELSE ST.GENERICDATE1 END) AS FECHA_EFECTO,
            --Necesitamos la FECHA_EMISION para coger el Manager al que se le paga por esa poliza.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICDATE2 ELSE ST.GENERICDATE2 END) AS FECHA_EMISION,
            TA.GENERICDATE1 AS FECHA_VTO_RECIBO,
            --Necesitamos el boolean de AUTOLIQUIDA para diferenciar las polizas de los pagos de autoliquidacion.
            (CASE WHEN TJ.SALESTRANSACTIONSEQ IS NOT NULL THEN TJ.GENERICBOOLEAN6 ELSE ST.GENERICBOOLEAN6 END) AS AUTOLIQUIDA
        FROM TCMP.CS_SALESTRANSACTION ST
                INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    AND TA.TENANTID = v_idtenant AND TA.PROCESSINGUNITSEQ = 38280596832649217
                --por unas transacciones manuales de Javier sin orderid se pone el filtro para que no falle el reparto
                INNER JOIN TCMP.CS_SALESORDER SO ON ST.SALESORDERSEQ = SO.SALESORDERSEQ
                    AND SO.TENANTID = v_idtenant AND SO.PROCESSINGUNITSEQ = 38280596832649217 AND SO.REMOVEDATE = v_eot
                    AND SO.ORDERID IS NOT NULL
                --No tenemos en cuenta las transacciones subidas despues del cierre.
                LEFT JOIN TCMP.CS_PLRUN PL ON ST.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND PL.TENANTID = v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217 AND PL.MODELSEQ = 0
                    AND PL.REMOVEDATE = v_eot
                    AND PL.COMMAND = 'Import' AND PL.RUNPARAMETERS LIKE '%[Sequence]ValidateAndTransfer%'
                --Cogemos la version de la transaccion si existe que se corresponde con la fecha del cierre.
                LEFT JOIN TCMP.CS_TRANSACTIONADJUSTMENT TJ ON ST.SALESTRANSACTIONSEQ = TJ.SALESTRANSACTIONSEQ
                    AND ST.COMPENSATIONDATE = TJ.COMPENSATIONDATE
                    AND TJ.TENANTID = v_idtenant AND TJ.PROCESSINGUNITSEQ = 38280596832649217
                    AND TJ.CREATEDATE < i_fecha_reparto
                    AND TJ.REMOVEDATE > i_fecha_reparto
        WHERE ST.TENANTID = v_idtenant AND ST.PROCESSINGUNITSEQ = 38280596832649217 AND ST.MODELSEQ = 0
            AND TO_CHAR(ST.COMPENSATIONDATE,'YYYYMM') = TO_CHAR(v_periodStartDate,'YYYYMM')
            --Cogemos las transacciones de los ficheros subidos anteriores al ultimo calculo o los subidos a mano.
            AND (PL.STARTTIME < i_fecha_reparto
            --De las transacciones subidas a mano solo cogemos aquellas que sean anteriores a la fechas del cierre.  
            OR (PL.PIPELINERUNSEQ IS NULL AND ST.MODIFICATIONDATE < i_fecha_reparto))
        ;
        
        v_num_rows = RECORD_COUNT(EXT.TEMP_REPEXT_TXN_FILE_NUEVA_BASE_REPARTO);
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Fin Carga de la tabla TEMP_REPEXT_TXN_FILE_NUEVA_BASE_REPARTO: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        
        
        
        
    END IF;
    
    -- TEMP_REPEXT_CREDITOS_FILE. L MISMA PARA CIERRE Y BALANCE DEPENDE DE PERIODSEQ
    IF i_par_tipo_ejecucion = 1 THEN
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Inicio Carga de la tabla TEMP_REPEXT_TXN_FILE.', v_log_count, v_idproceso, 'info');
    	
    	TEMP_REPEXT_CREDITOS_FILE = 
            SELECT C.CREDITSEQ,
                C.SALESTRANSACTIONSEQ,
                C.PAYEESEQ,
                C.POSITIONSEQ,
                C.PERIODSEQ,
                C.NAME,
                C.VALUE,
                C.GENERICNUMBER4,
                C.GENERICNUMBER5,
                --ALM 20221115: Incluimos nuevo campo Cambio Agente Inspector (GB3) necesario para descartar trx en el calculo de diferenciales y locomocion.
                C.GENERICBOOLEAN3
            FROM TCMP.CS_CREDIT C
                INNER JOIN TCMP.CS_PLRUN PL ON C.PIPELINERUNSEQ = PL.PIPELINERUNSEQ
                    AND PL.TENANTID = v_idtenant AND PL.PROCESSINGUNITSEQ = 38280596832649217 AND PL.MODELSEQ = 0
            WHERE C.TENANTID = v_idtenant AND C.PROCESSINGUNITSEQ = 38280596832649217 AND C.PERIODSEQ = i_periodSeq
            ;
            
        v_num_rows = RECORD_COUNT(:TEMP_REPEXT_CREDITOS_FILE);
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Fin Carga de la tabla TEMP_REPEXT_CREDITOS_FILE: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END IF;
    
    IF i_par_tipo_ejecucion IN (1,3,6) AND i_tipo_reparto = 'CIERRE' THEN
            
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Inicio Carga de la tabla FINAL_BASES_REPARTO_POLIZA_FILE.', v_log_count, v_idproceso, 'info');   
            
        INSERT INTO EXT.FINAL_BASES_REPARTO_POLIZA_FILE (PARTICIPANTSEQ,POSITIONSEQ,PERIODSEQ,POSITIONNAME,POS_PRIN,MANAGER_POS_PRIN,MAN_ACT_POS_PRIN,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,PRODUCTID
        	,CODIGO_POLIZA,COMPENSATIONDATE,ESTADO,AUTOLIQUIDA,IMPORTE_COMISION,IMPORTE_GRATIF,SERVICIO_ASISTENCIAS,IMP_SERV_ASISTENCIAS,POLIZA_FISICA,POLIZA_CORREGIDA,NUM_ASEG,PRIMA_NETA,PRIMA_NETA_ANUAL
            ,PRIMA_CORREGIDA,POLIZA_FISICA_MANAGER,POLIZA_CORR_MANAGER,DIF_INSP,DIF_RESP,LOC_INSP,LOC_RESP,PRIMA_COMIS_S4,PRIMA_COMIS_S5,SALESTRANSACTIONSEQ,COD_AGENTE,CAMBIO_AG_INSP,CAPTADOR_POS_PRIN,DIF_CAPT)
        SELECT
        	(CASE WHEN P.PAYEESEQ IS NULL THEN POS.PAYEESEQ ELSE P.PAYEESEQ END),
        	(CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END),
        	C.PERIODSEQ,
        	--Tenemos que coger el POSITIONNAME de la Position principal del agente.
        	(CASE WHEN P.NAME IS NULL THEN POS.NAME ELSE P.NAME END),--ST.POSITIONNAME,
        	(CASE WHEN P.GENERICATTRIBUTE3 IS NULL THEN POS.GENERICATTRIBUTE3 ELSE P.GENERICATTRIBUTE3 END),--POS.GENERICATTRIBUTE3,--J.POS_PRIN,
        	
        	--	Tenemos que coger el Manager de la fecha de emision de la poliza que es al que se le paga por esa poliza.
        	--  Ej: Poliza 01501213081277000000000N9027, para position 0004002379 en Octubre 2021, su manager actual es 0004 y al que se le paga es el 0004004246
        	--  Finalmente usamos la tabla de Position para evitar errores y duplicados.
        	-- LFC 20251211: (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END) AS MANAGER_POS_PRIN
        	IFNULL((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END),'0') AS MANAGER_POS_PRIN,
        	
        	--Incluimos un nuevo campo con el manger actual del agente para poder usarlo para el reparto de los pagos del responsable.
        	--Tal vez seria necesario coger la position principal del manager segun la Contract Rollup
        	--Comercial ha cambiado el criterio de los Responsables de Oficina (R) y ahora tambien se cogen segun la fecha de emision de la poliza.
        	--Por tanto, ya no tiene sentido este campo, pero lo vamos a usar para sacar el manager del manger en la fecha de emision.
        	
        	MAX((SELECT X.GENERICATTRIBUTE3 FROM TCMP.CS_POSITION X
        	    WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	    AND X.CREATEDATE < i_fecha_reparto
        	    AND X.REMOVEDATE > i_fecha_reparto
        	    AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	    AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	    AND X.GENERICNUMBER2 = 82
        	)) AS MAN_ACT_POS_PRIN,
        	
        	ST.ORDERID,
        	ST.LINENUMBER,
        	ST.SUBLINENUMBER,
        	ST.EVENTTYPEID,
        	ST.PRODUCTID,
        	ST.POLIZA AS CODIGO_POLIZA,
        	ST.COMPENSATIONDATE,
        	ST.ESTADO,
        	--Necesitamos el boolean de AUTOLIQUIDA para diferenciar las polizas de los pagos de autoliquidacion.
        	ST.AUTOLIQUIDA,
        	--Redondeamos los valores de la base de reparto a 2 decimales
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME LIKE 'DC-O-COM-%' OR
        	            C.NAME LIKE 'DC-E-COM-%' OR
        	            C.NAME = 'DC-O-GEN-Pagos-Fijos' OR
        	            --Faltaban los Pagos Comerciales de Eterna.
        	            C.NAME = 'DC-E-GEN-Pagos-Fijos' OR
        	            C.NAME LIKE 'DC-O-SER-COM%' OR
        	            C.NAME LIKE 'DC-E-SER-COM%') AND
        	            --Quitamos los nuevos creditos de Asistencia.
        	            C.NAME <> 'DC-O-COM-NumeroAsistencias' AND
        	            C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS IMPORTE_COMISION,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-SER-SUBV' OR
        	            C.NAME = 'DC-E-SER-SUBV')
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS IMPORTE_GRATIF,
        	
        	ROUND(IFNULL(SUM(CASE WHEN C.NAME = 'DC-O-COM-NumeroAsistencias' THEN C.VALUE ELSE 0 END),0),2) AS SERVICIO_ASISTENCIAS,
        	
        	--Tener en cuenta los diferentes depositos creados para cada EVENTTYPEID.
        	--Tenemos que diferenciar por Compania porque para Ocaso siguen generandose ambos creditos y duplica el valor, pero para Eterna hay que mantener el credito original.
        	ROUND(IFNULL(SUM(CASE WHEN SUBSTR(ST.PRODUCTID,1,2) = '03' AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe' THEN C.VALUE
        	    WHEN SUBSTR(ST.PRODUCTID,1,2) = '01' AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe' AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%' THEN C.VALUE
        	    ELSE 0 
        	END),0),2) AS IMP_SERV_ASISTENCIAS,
        	
        	ROUND(IFNULL(SUM(CASE WHEN ST.EVENTTYPEID = '81'
        	    --Nos indica Javier que NO se deben usar los filtros extras sobre el credito de cartera porque ya incluye lo que debe por si mismo.
        	    
        	    THEN (CASE WHEN C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998-81'
        	        THEN C.VALUE ELSE 0 END)
        	    ELSE (CASE WHEN (C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998' OR
        	                --Nos indica Javier que este credito solo vale para las polizas corregidas no para las fisicas.
        	                --Usamos los creditos de inspector porque los de agente no se calculan para los agentes con grupo.
        	                C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	                C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')
        	        THEN C.VALUE ELSE 0 END)
        	END),0),2) AS POLIZA_FISICA,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998' OR
        	            C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998-Renov' OR
        	            --Usamos los creditos de inspector porque los de agente no se calculan para los agentes con grupo.
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')-- OR
        	            --Hay que incluir para los agentes con grupo de OCASO porque no calculan el credito de agentes para las renvaciones de cartera.
        	            --Desde Comercial anaden el credito de agentes de renovaciones para los agentes con grupo, asi que ya no hay que tener en cuenta el de inpectores.
        	    THEN C.GENERICNUMBER4 ELSE 0
        	END),0),2) AS POLIZA_CORREGIDA,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Agente-NumAsegurados' OR
        	            C.NAME = 'DC-E-GEN-Agente-NumAsegurados')
        	     THEN C.VALUE ELSE 0
        	END),0),2) AS NUM_ASEG,
        	
        	--Para las recuperaciones de Serco (11) tenemos que coger el valor del GN5 del credito.
        	ROUND(IFNULL((CASE WHEN ST.EVENTTYPEID <> '11'
        	    THEN ST.PRIMA_NETA
        	    ELSE SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Agente-Prima-998' OR
        	                        C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998')
        	                THEN C.GENERICNUMBER5 ELSE 0 END)
        	END),0),2) AS PRIMA_NETA,
        	
        	--Para RRTT y los 66 devolver el ST.GENERICNUMBER2 para el resto lo que hay
        	ROUND(IFNULL((CASE WHEN ST.ORDERID LIKE '012%' OR ST.ORDERID LIKE '032%' OR ST.EVENTTYPEID = '66'
        	    THEN ST.INCR_PRIMA
        	    ELSE SUM(CASE WHEN (ST.EVENTTYPEID IN ('71','65') AND
        	                        C.NAME = 'DC-O-GEN-Agente-Prima-998')
        	                THEN C.GENERICNUMBER5 ELSE 0 END)
        	END),0),2) AS PRIMA_NETA_ANUAL,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998')
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS PRIMA_CORREGIDA,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998-Renov' OR
        	            C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	            --ALM 20220513: Incluimos el credito de renovaciones para Eterna.
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS POLIZA_FISICA_MANAGER,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998-Renov' OR
        	            C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	            --ALM 20220513: Incluimos el credito de renovaciones para Eterna.
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')
        	    THEN C.GENERICNUMBER4 ELSE 0
        	END),0),2) AS POLIZA_CORR_MANAGER,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) >= 50 AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) <> 82
        	    THEN (SELECT SUM(COM_DIF.VALUE) FROM CS_COMMISSION COM_DIF
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
        	                        --Filtramos para no tener en cuenta las Commission Anuales
        	                        AND I_DIF.TENANTID = v_idtenant AND I_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND I_DIF.PERIODSEQ = i_periodSeq
        	                        AND I_DIF.NAME LIKE 'C-%-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
        	                    WHERE COM_DIF.TENANTID = v_idtenant AND COM_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND COM_DIF.PERIODSEQ = i_periodSeq
        	                    AND COM_DIF.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS DIF_INSP,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998-RO' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998-RO') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) = 82
        	    THEN (SELECT SUM(COM_DIF.VALUE) FROM CS_COMMISSION COM_DIF
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
        	                        --Filtramos para no tener en cuenta las Commission Anuales
        	                        AND I_DIF.TENANTID = v_idtenant AND I_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND I_DIF.PERIODSEQ = i_periodSeq
        	                        AND I_DIF.NAME LIKE 'C-%-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
        	                    WHERE COM_DIF.TENANTID = v_idtenant AND COM_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND COM_DIF.PERIODSEQ = i_periodSeq
        	                    AND COM_DIF.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS DIF_RESP,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) >= 50 AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) <> 82
        	    THEN (SELECT SUM(COM_CT.VALUE) FROM CS_COMMISSION COM_CT
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_CT.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_CT ON COM_CT.INCENTIVESEQ = I_CT.INCENTIVESEQ AND COM_CT.PIPELINERUNSEQ = I_CT.PIPELINERUNSEQ
        	                        AND I_CT.TENANTID = v_idtenant AND I_CT.PROCESSINGUNITSEQ = 38280596832649217 AND I_CT.PERIODSEQ = i_periodSeq
        	                        AND I_CT.NAME LIKE 'C-O-CT-%'
        	                    WHERE COM_CT.TENANTID = v_idtenant AND COM_CT.PROCESSINGUNITSEQ = 38280596832649217 AND COM_CT.PERIODSEQ = i_periodSeq
        	                    AND COM_CT.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS LOC_INSP,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998-RO' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998-RO') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) = 82
        	    THEN (SELECT SUM(COM_CT.VALUE) FROM CS_COMMISSION COM_CT
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_CT.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_CT ON COM_CT.INCENTIVESEQ = I_CT.INCENTIVESEQ AND COM_CT.PIPELINERUNSEQ = I_CT.PIPELINERUNSEQ
        	                        AND I_CT.TENANTID = v_idtenant AND I_CT.PROCESSINGUNITSEQ = 38280596832649217 AND I_CT.PERIODSEQ = i_periodSeq
        	                        AND I_CT.NAME LIKE 'C-O-CT-%'
        	                    WHERE COM_CT.TENANTID = v_idtenant AND COM_CT.PROCESSINGUNITSEQ = 38280596832649217 AND COM_CT.PERIODSEQ = i_periodSeq
        	                    AND COM_CT.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS LOC_RESP,
        	
        	ROUND(IFNULL(ST.VALUE,0),2) AS PRIMA_COMIS_S4,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998')
        	    THEN C.GENERICNUMBER5 ELSE 0
        	END),0),2) AS PRIMA_COMIS_S5,
        	
        	--Incluimos en las bases de reparto el SALESTRANSACTIONSEQ para poder usar esta tabla en los informes pedidos por Ocaso.
        	ST.SALESTRANSACTIONSEQ,
        	--Incluimos el codigo de agente que viene en la transaccion porque es necesario para para los ficheros de salida.
        	ST.POS_PRIN AS COD_AGENTE,
        	--Sacamos solo el MAX que que no agrupe
        	MAX(IFNULL(C.GENERICBOOLEAN3,'0')) AS CAMBIO_AG_INSP,
        	
        	--Anadimos nuevo campo CAPTADOR_POS_PRIN y DIF_CAPT
        	(SELECT DISTINCT Y.GENERICATTRIBUTE3 FROM TCMP.CS_POSITION Y
        	    WHERE Y.NAME = (CASE WHEN P.GENERICATTRIBUTE14 IS NULL THEN POS.GENERICATTRIBUTE14 ELSE P.GENERICATTRIBUTE14 END) 
        	    AND Y.CREATEDATE < i_fecha_reparto
        	    AND Y.REMOVEDATE > i_fecha_reparto
        	    AND Y.EFFECTIVESTARTDATE <= i_fecha_reparto
        	    AND Y.EFFECTIVEENDDATE > i_fecha_reparto
        	    AND Y.TENANTID = v_idtenant
        	) AS CAPTADOR_POS_PRIN,	
        	ROUND(IFNULL(SUM(CASE WHEN C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998-Captacion' AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) >= 50 AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE >i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) <> 82
        	    THEN (SELECT SUM(COM_DIF.VALUE) FROM CS_COMMISSION COM_DIF
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
        	                        --Filtramos para no tener en cuenta las Commission Anuales
        	                        AND I_DIF.TENANTID = v_idtenant AND I_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND I_DIF.PERIODSEQ = i_periodSeq
        	                        AND I_DIF.NAME LIKE 'C-%-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
        	                    WHERE COM_DIF.TENANTID = v_idtenant AND COM_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND COM_DIF.PERIODSEQ = i_periodSeq
        	                    AND COM_DIF.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS DIF_CAPT
                
        FROM EXT.TEMP_REPEXT_TXN_FILE ST
            INNER JOIN :TEMP_REPEXT_CREDITOS_FILE C ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
            --Utilizamos la tabla de POSITION en lugar de la de jerarquia para evitar errores con algunas Position.
            INNER JOIN TCMP.CS_POSITION POS ON ST.POSITIONNAME = POS.NAME
                AND POS.TENANTID = v_idtenant
                AND POS.CREATEDATE < i_fecha_reparto
                AND POS.REMOVEDATE > i_fecha_reparto
                --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
                AND POS.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND POS.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            --Incluimos la jerarquia de Contract Rollup para quedarnos con la Positon principal de cada agente porque sera esta la que cobre el pago.
            LEFT JOIN (SELECT PRP.PARENTPOSITIONSEQ,PRP.CHILDPOSITIONSEQ
                FROM TCMP.CS_POSITIONRELATION PRP
                INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT ON PRP.POSITIONRELATIONTYPESEQ = PRT.DATATYPESEQ
                    AND PRT.TENANTID = v_idtenant AND PRT.REMOVEDATE = v_eot
                    AND PRT.NAME='Contract Rollup'
                WHERE PRP.TENANTID = v_idtenant
                    AND PRP.CREATEDATE < i_fecha_reparto
                    AND PRP.REMOVEDATE > i_fecha_reparto
                    --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
                    AND PRP.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                    AND PRP.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            ) PR ON POS.RULEELEMENTOWNERSEQ = PR.CHILDPOSITIONSEQ
            LEFT JOIN TCMP.CS_POSITION P ON PR.PARENTPOSITIONSEQ = P.RULEELEMENTOWNERSEQ
                AND P.TENANTID = v_idtenant
                AND P.CREATEDATE < i_fecha_reparto
                AND P.REMOVEDATE > i_fecha_reparto
                --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
                AND P.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND P.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            --Incluimos los INNER necesarios para poder atacar al manager principal de la position sin usar subconsultas que influyen demasiado en el rendimiento.
            --Buscamos la Position Principal del agente de la transaccion en la fecha de emision de la poliza (PP) ya que el manager que buscamos es el de esa fecha.
            LEFT JOIN TCMP.CS_POSITION PP ON PP.RULEELEMENTOWNERSEQ = (CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END) 
                AND PP.CREATEDATE < i_fecha_reparto
                AND PP.REMOVEDATE > i_fecha_reparto
                AND PP.EFFECTIVESTARTDATE <= (CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
                AND PP.EFFECTIVEENDDATE > (CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
                AND PP.TENANTID = v_idtenant
            --Cogemos la version a cierre del periodo del manager (MAN) que tenia la Posicion Principal del agente en la fecha emision de la poliza (PP). 
            LEFT JOIN TCMP.CS_POSITION MAN ON MAN.RULEELEMENTOWNERSEQ = PP.MANAGERSEQ
                AND MAN.CREATEDATE < i_fecha_reparto
                AND MAN.REMOVEDATE > i_fecha_reparto
                AND MAN.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND MAN.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
                AND MAN.TENANTID = v_idtenant
            --Comprobamos con la Contract Rollup cual es la position proncipal del Manager (MAN).
            LEFT JOIN (SELECT PRP_M.PARENTPOSITIONSEQ,PRP_M.CHILDPOSITIONSEQ
                FROM TCMP.CS_POSITIONRELATION PRP_M
                INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT_M ON PRP_M.POSITIONRELATIONTYPESEQ = PRT_M.DATATYPESEQ
                    AND PRT_M.TENANTID = v_idtenant AND PRT_M.REMOVEDATE = v_eot
                    AND PRT_M.NAME='Contract Rollup'
                WHERE PRP_M.TENANTID = v_idtenant
                    AND PRP_M.CREATEDATE < i_fecha_reparto
                    AND PRP_M.REMOVEDATE > i_fecha_reparto
                    AND PRP_M.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                    AND PRP_M.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            ) PR_M ON MAN.RULEELEMENTOWNERSEQ = PR_M.CHILDPOSITIONSEQ
            LEFT JOIN TCMP.CS_POSITION P_M ON PR_M.PARENTPOSITIONSEQ = P_M.RULEELEMENTOWNERSEQ
                AND P_M.TENANTID = v_idtenant
                AND P_M.CREATEDATE < i_fecha_reparto
                AND P_M.REMOVEDATE > i_fecha_reparto
                AND P_M.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND P_M.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        --Por peticion de Mariano, se deberia quitar el producto 0110199 porque no deberia de derivarse gasto a este producto.
        WHERE ST.PRODUCTID <> '0110199'
			AND ST.ESTADO <> 'N'
        GROUP BY 
            (CASE WHEN P.PAYEESEQ IS NULL THEN POS.PAYEESEQ ELSE P.PAYEESEQ END),
            (CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END),
            C.PERIODSEQ,
            (CASE WHEN P.NAME IS NULL THEN POS.NAME ELSE P.NAME END),
            (CASE WHEN P.GENERICATTRIBUTE3 IS NULL THEN POS.GENERICATTRIBUTE3 ELSE P.GENERICATTRIBUTE3 END),
            (CASE WHEN P.GENERICATTRIBUTE14 IS NULL THEN POS.GENERICATTRIBUTE14 ELSE P.GENERICATTRIBUTE14 END),
            
            (CASE WHEN P.MANAGERSEQ IS NULL THEN POS.MANAGERSEQ ELSE P.MANAGERSEQ END),
            
            --Agrupamos por el Manager principal de la poliza.
            (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END),
            --Tenemos que coger el Manager de la fecha de emision de la poliza que es al que se le paga por esa poliza.
            ST.FECHA_EMISION,
            ST.ORDERID,
            ST.LINENUMBER,
            ST.SUBLINENUMBER,
            ST.EVENTTYPEID,
            ST.PRODUCTID,
            ST.POLIZA,
            ST.COMPENSATIONDATE,
            ST.ESTADO,
            ST.AUTOLIQUIDA,
            ST.VALUE,
            ST.PRIMA_NETA,
            ST.INCR_PRIMA,
            ST.SALESTRANSACTIONSEQ,
            ST.POS_PRIN          
        ;
        
        v_num_rows = ::ROWCOUNT;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name_secundario,'Fin Carga de la tabla FINAL_BASES_REPARTO_POLIZA_FILE: ' || v_num_rows, v_log_count, v_idproceso, 'info');


		/* ------------------------------LFC:20251202 --TABLA COPIA BASES DE REPARTO PENDIENTE BORRAR
			    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'FINAL_BASES_REPARTO_POLIZA_FILE_COPIA';
				
				TEMP_FINAL_BASES_REPARTO_POLIZA_FILE_COPIA =
									SELECT * FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE WHERE PERIODSEQ = i_periodSeq
				
				IF v_existe_tabla > 0 THEN
				
					INSERT INTO EXT.FINAL_BASES_REPARTO_POLIZA_FILE_COPIA_2 (SELECT * FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE);
					
					DROP TABLE EXT.FINAL_BASES_REPARTO_POLIZA_FILE_COPIA;
				END IF;
				
				CREATE TABLE EXT.FINAL_BASES_REPARTO_POLIZA_FILE_COPIA AS (SELECT * FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE WHERE PERIODSEQ = i_periodSeq);
			    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name_secundario, 'Creada la tabla temporal FINAL_BASES_REPARTO_POLIZA_FILE_COPIA' , v_log_count, v_idproceso, 'debug');
		------------------------------             
		*/            
    ELSEIF i_par_tipo_ejecucion IN (1,3,6) AND i_tipo_reparto = 'BALANCE' THEN
            
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Inicio Carga de la tabla FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO.', v_log_count, v_idproceso, 'info');   
        
        DELETE FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO WHERE PERIODSEQ = i_periodseq;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Fin Borrado FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO: ' || ::ROWCOUNT , v_log_count, v_idproceso, 'info');  
        
        -- INSERT INTO EXT.FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO (PARTICIPANTSEQ,POSITIONSEQ,PERIODSEQ,POSITIONNAME,POS_PRIN,MANAGER_POS_PRIN,MAN_ACT_POS_PRIN,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,PRODUCTID
        -- 	,CODIGO_POLIZA,COMPENSATIONDATE,ESTADO,AUTOLIQUIDA,IMPORTE_COMISION,IMPORTE_GRATIF,SERVICIO_ASISTENCIAS,IMP_SERV_ASISTENCIAS,POLIZA_FISICA,POLIZA_CORREGIDA,NUM_ASEG,PRIMA_NETA,PRIMA_NETA_ANUAL
        --     ,PRIMA_CORREGIDA,POLIZA_FISICA_MANAGER,POLIZA_CORR_MANAGER,DIF_INSP,DIF_RESP,LOC_INSP,LOC_RESP,PRIMA_COMIS_S4,PRIMA_COMIS_S5,SALESTRANSACTIONSEQ,COD_AGENTE,CAMBIO_AG_INSP,CAPTADOR_POS_PRIN,DIF_CAPT)
        TEMP_FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO = 
        SELECT
        	(CASE WHEN P.PAYEESEQ IS NULL THEN POS.PAYEESEQ ELSE P.PAYEESEQ END) PARTICIPANTSEQ,
        	(CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END) POSITIONSEQ,
        	C.PERIODSEQ,
        	--Tenemos que coger el POSITIONNAME de la Position principal del agente.
        	(CASE WHEN P.NAME IS NULL THEN POS.NAME ELSE P.NAME END) POSITIONNAME,--ST.POSITIONNAME,
        	(CASE WHEN P.GENERICATTRIBUTE3 IS NULL THEN POS.GENERICATTRIBUTE3 ELSE P.GENERICATTRIBUTE3 END) POS_PRIN,--POS.GENERICATTRIBUTE3,--J.POS_PRIN,
        	
        	--	Tenemos que coger el Manager de la fecha de emision de la poliza que es al que se le paga por esa poliza.
        	--  Ej: Poliza 01501213081277000000000N9027, para position 0004002379 en Octubre 2021, su manager actual es 0004 y al que se le paga es el 0004004246
        	--  Finalmente usamos la tabla de Position para evitar errores y duplicados.
        	-- LFC 20251211: (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END) AS MANAGER_POS_PRIN
        	IFNULL((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END),'0') AS MANAGER_POS_PRIN,
        	
        	--Incluimos un nuevo campo con el manger actual del agente para poder usarlo para el reparto de los pagos del responsable.
        	--Tal vez seria necesario coger la position principal del manager segun la Contract Rollup
        	--Comercial ha cambiado el criterio de los Responsables de Oficina (R) y ahora tambien se cogen segun la fecha de emision de la poliza.
        	--Por tanto, ya no tiene sentido este campo, pero lo vamos a usar para sacar el manager del manger en la fecha de emision.
        	
        	MAX((SELECT X.GENERICATTRIBUTE3 FROM TCMP.CS_POSITION X
        	    WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	    AND X.CREATEDATE < i_fecha_reparto
        	    AND X.REMOVEDATE > i_fecha_reparto
        	    AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	    AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	    AND X.GENERICNUMBER2 = 82
        	)) AS MAN_ACT_POS_PRIN,
        	
        	ST.ORDERID,
        	ST.LINENUMBER,
        	ST.SUBLINENUMBER,
        	ST.EVENTTYPEID,
        	ST.PRODUCTID,
        	ST.POLIZA AS CODIGO_POLIZA,
        	ST.COMPENSATIONDATE,
        	ST.ESTADO,
        	--Necesitamos el boolean de AUTOLIQUIDA para diferenciar las polizas de los pagos de autoliquidacion.
        	ST.AUTOLIQUIDA,
        	--Redondeamos los valores de la base de reparto a 2 decimales
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME LIKE 'DC-O-COM-%' OR
        	            C.NAME LIKE 'DC-E-COM-%' OR
        	            C.NAME = 'DC-O-GEN-Pagos-Fijos' OR
        	            --Faltaban los Pagos Comerciales de Eterna.
        	            C.NAME = 'DC-E-GEN-Pagos-Fijos' OR
        	            C.NAME LIKE 'DC-O-SER-COM%' OR
        	            C.NAME LIKE 'DC-E-SER-COM%') AND
        	            --Quitamos los nuevos creditos de Asistencia.
        	            C.NAME <> 'DC-O-COM-NumeroAsistencias' AND
        	            C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS IMPORTE_COMISION,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-SER-SUBV' OR
        	            C.NAME = 'DC-E-SER-SUBV')
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS IMPORTE_GRATIF,
        	
        	ROUND(IFNULL(SUM(CASE WHEN C.NAME = 'DC-O-COM-NumeroAsistencias' THEN C.VALUE ELSE 0 END),0),2) AS SERVICIO_ASISTENCIAS,
        	
        	--Tener en cuenta los diferentes depositos creados para cada EVENTTYPEID.
        	--Tenemos que diferenciar por Compania porque para Ocaso siguen generandose ambos creditos y duplica el valor, pero para Eterna hay que mantener el credito original.
        	ROUND(IFNULL(SUM(CASE WHEN SUBSTR(ST.PRODUCTID,1,2) = '03' AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe' THEN C.VALUE
        	    WHEN SUBSTR(ST.PRODUCTID,1,2) = '01' AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe' AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%' THEN C.VALUE
        	    ELSE 0 
        	END),0),2) AS IMP_SERV_ASISTENCIAS,
        	
        	ROUND(IFNULL(SUM(CASE WHEN ST.EVENTTYPEID = '81'
        	    --Nos indica Javier que NO se deben usar los filtros extras sobre el credito de cartera porque ya incluye lo que debe por si mismo.
        	    
        	    THEN (CASE WHEN C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998-81'
        	        THEN C.VALUE ELSE 0 END)
        	    ELSE (CASE WHEN (C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998' OR
        	                --Nos indica Javier que este credito solo vale para las polizas corregidas no para las fisicas.
        	                --Usamos los creditos de inspector porque los de agente no se calculan para los agentes con grupo.
        	                C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	                C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')
        	        THEN C.VALUE ELSE 0 END)
        	END),0),2) AS POLIZA_FISICA,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998' OR
        	            C.NAME = 'DC-O-GEN-Agente-NumeroPolizas-998-Renov' OR
        	            --Usamos los creditos de inspector porque los de agente no se calculan para los agentes con grupo.
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')-- OR
        	            --Hay que incluir para los agentes con grupo de OCASO porque no calculan el credito de agentes para las renvaciones de cartera.
        	            --Desde Comercial anaden el credito de agentes de renovaciones para los agentes con grupo, asi que ya no hay que tener en cuenta el de inpectores.
        	    THEN C.GENERICNUMBER4 ELSE 0
        	END),0),2) AS POLIZA_CORREGIDA,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Agente-NumAsegurados' OR
        	            C.NAME = 'DC-E-GEN-Agente-NumAsegurados')
        	     THEN C.VALUE ELSE 0
        	END),0),2) AS NUM_ASEG,
        	
        	--Para las recuperaciones de Serco (11) tenemos que coger el valor del GN5 del credito.
        	ROUND(IFNULL((CASE WHEN ST.EVENTTYPEID <> '11'
        	    THEN ST.PRIMA_NETA
        	    ELSE SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Agente-Prima-998' OR
        	                        C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998')
        	                THEN C.GENERICNUMBER5 ELSE 0 END)
        	END),0),2) AS PRIMA_NETA,
        	
        	--Para RRTT y los 66 devolver el ST.GENERICNUMBER2 para el resto lo que hay
        	ROUND(IFNULL((CASE WHEN ST.ORDERID LIKE '012%' OR ST.ORDERID LIKE '032%' OR ST.EVENTTYPEID = '66'
        	    THEN ST.INCR_PRIMA
        	    ELSE SUM(CASE WHEN (ST.EVENTTYPEID IN ('71','65') AND
        	                        C.NAME = 'DC-O-GEN-Agente-Prima-998')
        	                THEN C.GENERICNUMBER5 ELSE 0 END)
        	END),0),2) AS PRIMA_NETA_ANUAL,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998')
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS PRIMA_CORREGIDA,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998-Renov' OR
        	            C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	            --ALM 20220513: Incluimos el credito de renovaciones para Eterna.
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')
        	    THEN C.VALUE ELSE 0
        	END),0),2) AS POLIZA_FISICA_MANAGER,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998-Renov' OR
        	            C.NAME = 'DC-O-GEN-Inspector-NumeroPolizas-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998' OR
        	            --ALM 20220513: Incluimos el credito de renovaciones para Eterna.
        	            C.NAME = 'DC-E-GEN-Inspector-NumeroPolizas-998-Renov')
        	    THEN C.GENERICNUMBER4 ELSE 0
        	END),0),2) AS POLIZA_CORR_MANAGER,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) >= 50 AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) <> 82
        	    THEN (SELECT SUM(COM_DIF.VALUE) FROM CS_COMMISSION COM_DIF
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
        	                        --Filtramos para no tener en cuenta las Commission Anuales
        	                        AND I_DIF.TENANTID = v_idtenant AND I_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND I_DIF.PERIODSEQ = i_periodSeq
        	                        AND I_DIF.NAME LIKE 'C-%-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
        	                    WHERE COM_DIF.TENANTID = v_idtenant AND COM_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND COM_DIF.PERIODSEQ = i_periodSeq
        	                    AND COM_DIF.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS DIF_INSP,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998-RO' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998-RO') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) = 82
        	    THEN (SELECT SUM(COM_DIF.VALUE) FROM CS_COMMISSION COM_DIF
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
        	                        --Filtramos para no tener en cuenta las Commission Anuales
        	                        AND I_DIF.TENANTID = v_idtenant AND I_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND I_DIF.PERIODSEQ = i_periodSeq
        	                        AND I_DIF.NAME LIKE 'C-%-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
        	                    WHERE COM_DIF.TENANTID = v_idtenant AND COM_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND COM_DIF.PERIODSEQ = i_periodSeq
        	                    AND COM_DIF.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS DIF_RESP,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) >= 50 AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) <> 82
        	    THEN (SELECT SUM(COM_CT.VALUE) FROM CS_COMMISSION COM_CT
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_CT.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_CT ON COM_CT.INCENTIVESEQ = I_CT.INCENTIVESEQ AND COM_CT.PIPELINERUNSEQ = I_CT.PIPELINERUNSEQ
        	                        AND I_CT.TENANTID = v_idtenant AND I_CT.PROCESSINGUNITSEQ = 38280596832649217 AND I_CT.PERIODSEQ = i_periodSeq
        	                        AND I_CT.NAME LIKE 'C-O-CT-%'
        	                    WHERE COM_CT.TENANTID = v_idtenant AND COM_CT.PROCESSINGUNITSEQ = 38280596832649217 AND COM_CT.PERIODSEQ = i_periodSeq
        	                    AND COM_CT.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS LOC_INSP,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-004' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-004' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998' OR C.NAME = 'IC-E-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998-RO' OR C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998-RO') AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) = 82
        	    THEN (SELECT SUM(COM_CT.VALUE) FROM CS_COMMISSION COM_CT
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_CT.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_CT ON COM_CT.INCENTIVESEQ = I_CT.INCENTIVESEQ AND COM_CT.PIPELINERUNSEQ = I_CT.PIPELINERUNSEQ
        	                        AND I_CT.TENANTID = v_idtenant AND I_CT.PROCESSINGUNITSEQ = 38280596832649217 AND I_CT.PERIODSEQ = i_periodSeq
        	                        AND I_CT.NAME LIKE 'C-O-CT-%'
        	                    WHERE COM_CT.TENANTID = v_idtenant AND COM_CT.PROCESSINGUNITSEQ = 38280596832649217 AND COM_CT.PERIODSEQ = i_periodSeq
        	                    AND COM_CT.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS LOC_RESP,
        	
        	ROUND(IFNULL(ST.VALUE,0),2) AS PRIMA_COMIS_S4,
        	
        	ROUND(IFNULL(SUM(CASE WHEN (C.NAME = 'DC-O-GEN-Inspector-PrimaCorregida-998' OR
        	            C.NAME = 'DC-E-GEN-Inspector-PrimaCorregida-998')
        	    THEN C.GENERICNUMBER5 ELSE 0
        	END),0),2) AS PRIMA_COMIS_S5,
        	
        	--Incluimos en las bases de reparto el SALESTRANSACTIONSEQ para poder usar esta tabla en los informes pedidos por Ocaso.
        	ST.SALESTRANSACTIONSEQ,
        	--Incluimos el codigo de agente que viene en la transaccion porque es necesario para para los ficheros de salida.
        	ST.POS_PRIN AS COD_AGENTE,
        	--Sacamos solo el MAX que que no agrupe
        	MAX(IFNULL(C.GENERICBOOLEAN3,'0')) AS CAMBIO_AG_INSP,
        	
        	--Anadimos nuevo campo CAPTADOR_POS_PRIN y DIF_CAPT
        	(SELECT DISTINCT Y.GENERICATTRIBUTE3 FROM TCMP.CS_POSITION Y
        	    WHERE Y.NAME = (CASE WHEN P.GENERICATTRIBUTE14 IS NULL THEN POS.GENERICATTRIBUTE14 ELSE P.GENERICATTRIBUTE14 END) 
        	    AND Y.CREATEDATE < i_fecha_reparto
        	    AND Y.REMOVEDATE > i_fecha_reparto
        	    AND Y.EFFECTIVESTARTDATE <= i_fecha_reparto
        	    AND Y.EFFECTIVEENDDATE > i_fecha_reparto
        	    AND Y.TENANTID = v_idtenant
        	) AS CAPTADOR_POS_PRIN,	
        	ROUND(IFNULL(SUM(CASE WHEN C.NAME = 'IC-O-GEN-Inspector-PrimaCorregida-998-Captacion' AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE > i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) >= 50 AND
        	            (SELECT MAX(X.GENERICNUMBER2) FROM TCMP.CS_POSITION X
        	            WHERE X.PAYEESEQ = C.PAYEESEQ AND X.RULEELEMENTOWNERSEQ = C.POSITIONSEQ
        	            AND X.CREATEDATE < i_fecha_reparto
        	            AND X.REMOVEDATE >i_fecha_reparto
        	            --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
        	            AND X.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
        	            AND X.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        	            ) <> 82
        	    THEN (SELECT SUM(COM_DIF.VALUE) FROM CS_COMMISSION COM_DIF
        	                    --Anadimos condicion para no coger posibles resultados de los MODELS
        	                    INNER JOIN TCMP.CS_PLRUN PL ON COM_DIF.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
        	                    INNER JOIN TCMP.CS_INCENTIVE I_DIF ON COM_DIF.INCENTIVESEQ = I_DIF.INCENTIVESEQ AND COM_DIF.PIPELINERUNSEQ = I_DIF.PIPELINERUNSEQ
        	                        --Filtramos para no tener en cuenta las Commission Anuales
        	                        AND I_DIF.TENANTID = v_idtenant AND I_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND I_DIF.PERIODSEQ = i_periodSeq
        	                        AND I_DIF.NAME LIKE 'C-%-DIF-%' AND I_DIF.NAME NOT LIKE '%-Anual'
        	                    WHERE COM_DIF.TENANTID = v_idtenant AND COM_DIF.PROCESSINGUNITSEQ = 38280596832649217 AND COM_DIF.PERIODSEQ = i_periodSeq
        	                    AND COM_DIF.CREDITSEQ = C.CREDITSEQ)
        	    ELSE 0
        	END),0),2) AS DIF_CAPT
                
        FROM EXT.TEMP_REPEXT_TXN_FILE_NUEVA_BASE_REPARTO ST
            INNER JOIN :TEMP_REPEXT_CREDITOS_FILE C ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
            --Utilizamos la tabla de POSITION en lugar de la de jerarquia para evitar errores con algunas Position.
            INNER JOIN TCMP.CS_POSITION POS ON ST.POSITIONNAME = POS.NAME
                AND POS.TENANTID = v_idtenant
                AND POS.CREATEDATE < i_fecha_reparto
                AND POS.REMOVEDATE > i_fecha_reparto
                --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
                AND POS.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND POS.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            --Incluimos la jerarquia de Contract Rollup para quedarnos con la Positon principal de cada agente porque sera esta la que cobre el pago.
            LEFT JOIN (SELECT PRP.PARENTPOSITIONSEQ,PRP.CHILDPOSITIONSEQ
                FROM TCMP.CS_POSITIONRELATION PRP
                INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT ON PRP.POSITIONRELATIONTYPESEQ = PRT.DATATYPESEQ
                    AND PRT.TENANTID = v_idtenant AND PRT.REMOVEDATE = v_eot
                    AND PRT.NAME='Contract Rollup'
                WHERE PRP.TENANTID = v_idtenant
                    AND PRP.CREATEDATE < i_fecha_reparto
                    AND PRP.REMOVEDATE > i_fecha_reparto
                    --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
                    AND PRP.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                    AND PRP.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            ) PR ON POS.RULEELEMENTOWNERSEQ = PR.CHILDPOSITIONSEQ
            LEFT JOIN TCMP.CS_POSITION P ON PR.PARENTPOSITIONSEQ = P.RULEELEMENTOWNERSEQ
                AND P.TENANTID = v_idtenant
                AND P.CREATEDATE < i_fecha_reparto
                AND P.REMOVEDATE > i_fecha_reparto
                --Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
                AND P.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND P.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            --Incluimos los INNER necesarios para poder atacar al manager principal de la position sin usar subconsultas que influyen demasiado en el rendimiento.
            --Buscamos la Position Principal del agente de la transaccion en la fecha de emision de la poliza (PP) ya que el manager que buscamos es el de esa fecha.
            LEFT JOIN TCMP.CS_POSITION PP ON PP.RULEELEMENTOWNERSEQ = (CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END) 
                AND PP.CREATEDATE < i_fecha_reparto
                AND PP.REMOVEDATE > i_fecha_reparto
                AND PP.EFFECTIVESTARTDATE <= (CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
                AND PP.EFFECTIVEENDDATE > (CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
                AND PP.TENANTID = v_idtenant
            --Cogemos la version a cierre del periodo del manager (MAN) que tenia la Posicion Principal del agente en la fecha emision de la poliza (PP). 
            LEFT JOIN TCMP.CS_POSITION MAN ON MAN.RULEELEMENTOWNERSEQ = PP.MANAGERSEQ
                AND MAN.CREATEDATE < i_fecha_reparto
                AND MAN.REMOVEDATE > i_fecha_reparto
                AND MAN.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND MAN.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
                AND MAN.TENANTID = v_idtenant
            --Comprobamos con la Contract Rollup cual es la position proncipal del Manager (MAN).
            LEFT JOIN (SELECT PRP_M.PARENTPOSITIONSEQ,PRP_M.CHILDPOSITIONSEQ
                FROM TCMP.CS_POSITIONRELATION PRP_M
                INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT_M ON PRP_M.POSITIONRELATIONTYPESEQ = PRT_M.DATATYPESEQ
                    AND PRT_M.TENANTID = v_idtenant AND PRT_M.REMOVEDATE = v_eot
                    AND PRT_M.NAME='Contract Rollup'
                WHERE PRP_M.TENANTID = v_idtenant
                    AND PRP_M.CREATEDATE < i_fecha_reparto
                    AND PRP_M.REMOVEDATE > i_fecha_reparto
                    AND PRP_M.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                    AND PRP_M.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
            ) PR_M ON MAN.RULEELEMENTOWNERSEQ = PR_M.CHILDPOSITIONSEQ
            LEFT JOIN TCMP.CS_POSITION P_M ON PR_M.PARENTPOSITIONSEQ = P_M.RULEELEMENTOWNERSEQ
                AND P_M.TENANTID = v_idtenant
                AND P_M.CREATEDATE < i_fecha_reparto
                AND P_M.REMOVEDATE > i_fecha_reparto
                AND P_M.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND P_M.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
        --Por peticion de Mariano, se deberia quitar el producto 0110199 porque no deberia de derivarse gasto a este producto.
        WHERE ST.PRODUCTID <> '0110199'
			AND ST.ESTADO <> 'N'
        GROUP BY 
            (CASE WHEN P.PAYEESEQ IS NULL THEN POS.PAYEESEQ ELSE P.PAYEESEQ END),
            (CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END),
            C.PERIODSEQ,
            (CASE WHEN P.NAME IS NULL THEN POS.NAME ELSE P.NAME END),
            (CASE WHEN P.GENERICATTRIBUTE3 IS NULL THEN POS.GENERICATTRIBUTE3 ELSE P.GENERICATTRIBUTE3 END),
            (CASE WHEN P.GENERICATTRIBUTE14 IS NULL THEN POS.GENERICATTRIBUTE14 ELSE P.GENERICATTRIBUTE14 END),
            
            (CASE WHEN P.MANAGERSEQ IS NULL THEN POS.MANAGERSEQ ELSE P.MANAGERSEQ END),
            
            --Agrupamos por el Manager principal de la poliza.
            (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END),
            --Tenemos que coger el Manager de la fecha de emision de la poliza que es al que se le paga por esa poliza.
            ST.FECHA_EMISION,
            ST.ORDERID,
            ST.LINENUMBER,
            ST.SUBLINENUMBER,
            ST.EVENTTYPEID,
            ST.PRODUCTID,
            ST.POLIZA,
            ST.COMPENSATIONDATE,
            ST.ESTADO,
            ST.AUTOLIQUIDA,
            ST.VALUE,
            ST.PRIMA_NETA,
            ST.INCR_PRIMA,
            ST.SALESTRANSACTIONSEQ,
            ST.POS_PRIN          
        ;
        
        v_num_rows = ::ROWCOUNT;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name, v_proc_name_secundario || ' Fin Carga de la tabla TEMP_FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO: ' || v_num_rows, v_log_count, v_idproceso, 'info');

		INSERT INTO EXT.FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO (PARTICIPANTSEQ,POSITIONSEQ,PERIODSEQ,POSITIONNAME,POS_PRIN,MANAGER_POS_PRIN,MAN_ACT_POS_PRIN,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,PRODUCTID
        	,CODIGO_POLIZA,COMPENSATIONDATE,ESTADO,AUTOLIQUIDA,IMPORTE_COMISION,IMPORTE_GRATIF,SERVICIO_ASISTENCIAS,IMP_SERV_ASISTENCIAS,POLIZA_FISICA,POLIZA_CORREGIDA,NUM_ASEG,PRIMA_NETA,PRIMA_NETA_ANUAL
            ,PRIMA_CORREGIDA,POLIZA_FISICA_MANAGER,POLIZA_CORR_MANAGER,DIF_INSP,DIF_RESP,LOC_INSP,LOC_RESP,PRIMA_COMIS_S4,PRIMA_COMIS_S5,SALESTRANSACTIONSEQ,COD_AGENTE,CAMBIO_AG_INSP,CAPTADOR_POS_PRIN,DIF_CAPT)
        SELECT PARTICIPANTSEQ,POSITIONSEQ,PERIODSEQ,POSITIONNAME,POS_PRIN,MANAGER_POS_PRIN,MAN_ACT_POS_PRIN,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,PRODUCTID,CODIGO_POLIZA,COMPENSATIONDATE
				,ESTADO,AUTOLIQUIDA,SUM(IMPORTE_COMISION) IMPORTE_COMISION,SUM(IMPORTE_GRATIF) IMPORTE_GRATIF,SERVICIO_ASISTENCIAS,SUM(IMP_SERV_ASISTENCIAS) IMP_SERV_ASISTENCIAS,POLIZA_FISICA,POLIZA_CORREGIDA,NUM_ASEG,PRIMA_NETA,PRIMA_NETA_ANUAL
				,PRIMA_CORREGIDA,POLIZA_FISICA_MANAGER,POLIZA_CORR_MANAGER,SUM(DIF_INSP) DIF_INSP,SUM(DIF_RESP) DIF_RESP,SUM(LOC_INSP) LOC_INSP,SUM(LOC_RESP) LOC_RESP
				,PRIMA_COMIS_S4,PRIMA_COMIS_S5,SALESTRANSACTIONSEQ,COD_AGENTE,CAMBIO_AG_INSP,CAPTADOR_POS_PRIN,SUM(DIF_CAPT) DIF_CAPT
		FROM (
			SELECT PARTICIPANTSEQ,POSITIONSEQ,PERIODSEQ,POSITIONNAME,POS_PRIN,MANAGER_POS_PRIN,MAN_ACT_POS_PRIN,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,PRODUCTID,CODIGO_POLIZA,COMPENSATIONDATE
				,ESTADO,AUTOLIQUIDA,(-1)*IMPORTE_COMISION IMPORTE_COMISION,(-1)*IMPORTE_GRATIF IMPORTE_GRATIF,SERVICIO_ASISTENCIAS,(-1)*IMP_SERV_ASISTENCIAS IMP_SERV_ASISTENCIAS,POLIZA_FISICA,POLIZA_CORREGIDA,NUM_ASEG,PRIMA_NETA,PRIMA_NETA_ANUAL
				,PRIMA_CORREGIDA,POLIZA_FISICA_MANAGER,POLIZA_CORR_MANAGER,(-1)*DIF_INSP DIF_INSP,(-1)*DIF_RESP DIF_RESP,(-1)*LOC_INSP LOC_INSP,(-1)*LOC_RESP LOC_RESP
				,PRIMA_COMIS_S4,PRIMA_COMIS_S5,SALESTRANSACTIONSEQ,COD_AGENTE,CAMBIO_AG_INSP,CAPTADOR_POS_PRIN,(-1)*DIF_CAPT DIF_CAPT
			FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE WHERE PERIODSEQ = i_periodseq
			UNION ALL 
			SELECT PARTICIPANTSEQ,POSITIONSEQ,PERIODSEQ,POSITIONNAME,POS_PRIN,MANAGER_POS_PRIN,MAN_ACT_POS_PRIN,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,PRODUCTID,CODIGO_POLIZA,COMPENSATIONDATE
				,ESTADO,AUTOLIQUIDA,IMPORTE_COMISION,IMPORTE_GRATIF,SERVICIO_ASISTENCIAS,IMP_SERV_ASISTENCIAS,POLIZA_FISICA,POLIZA_CORREGIDA,NUM_ASEG,PRIMA_NETA,PRIMA_NETA_ANUAL
				,PRIMA_CORREGIDA,POLIZA_FISICA_MANAGER,POLIZA_CORR_MANAGER,DIF_INSP,DIF_RESP,LOC_INSP,LOC_RESP
				,PRIMA_COMIS_S4,PRIMA_COMIS_S5,SALESTRANSACTIONSEQ,COD_AGENTE,CAMBIO_AG_INSP,CAPTADOR_POS_PRIN,DIF_CAPT
			FROM :TEMP_FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO WHERE PERIODSEQ = i_periodseq
		)
		GROUP BY PARTICIPANTSEQ,POSITIONSEQ,PERIODSEQ,POSITIONNAME,POS_PRIN,MANAGER_POS_PRIN,MAN_ACT_POS_PRIN,ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,PRODUCTID,CODIGO_POLIZA,COMPENSATIONDATE
				,ESTADO,AUTOLIQUIDA,IMPORTE_GRATIF,SERVICIO_ASISTENCIAS,IMP_SERV_ASISTENCIAS,POLIZA_FISICA,POLIZA_CORREGIDA,NUM_ASEG,PRIMA_NETA,PRIMA_NETA_ANUAL
				,PRIMA_CORREGIDA,POLIZA_FISICA_MANAGER,POLIZA_CORR_MANAGER,DIF_INSP,DIF_RESP,LOC_INSP,LOC_RESP,PRIMA_COMIS_S4,PRIMA_COMIS_S5,SALESTRANSACTIONSEQ,COD_AGENTE,CAMBIO_AG_INSP,CAPTADOR_POS_PRIN,DIF_CAPT
		HAVING SUM(IMPORTE_COMISION) <> 0
		;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name, v_proc_name_secundario || ' Fin Carga de la tabla FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		/* ------------------------------LFC:20251202 --TABLA COPIA BASES DE REPARTO PENDIENTE BORRAR
			    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'FINAL_BASES_REPARTO_POLIZA_FILE_COPIA';
				
				TEMP_FINAL_BASES_REPARTO_POLIZA_FILE_COPIA =
									SELECT * FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE WHERE PERIODSEQ = i_periodSeq
				
				IF v_existe_tabla > 0 THEN
				
					INSERT INTO EXT.FINAL_BASES_REPARTO_POLIZA_FILE_COPIA_2 (SELECT * FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE);
					
					DROP TABLE EXT.FINAL_BASES_REPARTO_POLIZA_FILE_COPIA;
				END IF;
				
				CREATE TABLE EXT.FINAL_BASES_REPARTO_POLIZA_FILE_COPIA AS (SELECT * FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE WHERE PERIODSEQ = i_periodSeq);
			    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name_secundario, 'Creada la tabla temporal FINAL_BASES_REPARTO_POLIZA_FILE_COPIA' , v_log_count, v_idproceso, 'debug');
		------------------------------             
		*/     
		
	-- 	SELECT distinct 'TEMP_FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO',* FROM :TEMP_FINAL_BASES_REPARTO_POLIZA_FILE_NUEVA_BASE_REPARTO WHERE POS_PRIN = '0020000452'
	-- AND EVENTTYPEID = 16;
    -- END IF;


CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_proc_name_secundario || ' Fin del proceso.', v_log_count, v_idproceso, 'info');
	
END;
	


