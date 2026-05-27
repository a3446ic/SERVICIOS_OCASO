CREATE PROCEDURE EXT.SP_AUDITORIA_PCO (OUT FILENAME VARCHAR(120), IN i_pPlRunSeq VARCHAR(50)) 
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT AS
/*  --------------------------------------------------------------------- 
    | Author: Brais Romero Garcia
    | Company: Inycom 
    | Initial Version Date: 10-Junio-2025
    |
    |-------------------------------------------------------------------- 
    | Procedure Purpose: Fichero de auditoría de Pagos Comerciales
    | Version: 0.1	BRG 		20250610	Initial Version
    | Version: 0.2  DTB 		20250611	Añadida modificación al FILENAME para que coincida con Oracle.
    | Version: 0.3  DTB 		20250716	Añadido RPAD para que la longitud de linea coincida con Oracle.
    | Version: 0.4  DTB 		20250716	Modificación FILENAME.
    | Version: 0.5	BRG			20250813	Cambio FILENAME
    | 
    ---------------------------------------------------------------------
*/ 
BEGIN 
    USING SQLSCRIPT_STRING AS LIBRARY; 

    -- DECLARACION DE CONSTANTES Y VARIABLES
    DECLARE v_proc_name VARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
    DECLARE v_version VARCHAR(10) := '0.5';
    DECLARE v_num_rows INTEGER := 0;
    DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
    DECLARE v_log_count INTEGER := 0;
    DECLARE v_idproceso INTEGER; 
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
    DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot; 
    DECLARE v_PeriodSeq BIGINT;
    DECLARE v_PeriodName VARCHAR(255);
    DECLARE v_PeriodStartDate TIMESTAMP;
    DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
	DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
	DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
    DECLARE v_fechaliquidacion VARCHAR(6);
    DECLARE v_fechafichero DATE;
    DECLARE v_period_name VARCHAR(50);
    DECLARE v_period_startdate DATE;
    DECLARE v_period_enddate DATE;
    --DECLARE v_file_name_start VARCHAR(250) := 'RECIBOS.PAGOS.COMERC_';
    --DECLARE v_file_name_empresa VARCHAR(10) := '_OCASO';
	--DECLARE v_file_name_end VARCHAR(20) := '_PAGOGWCAFTP212602P';
	DECLARE v_file_name VARCHAR(50) := 'PAGO2126_AUDITO_PAGOS_COMERC_';

    -- CONTROLADOR DE EXCEPCIONES
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	    BEGIN	
	    	ROLLBACK;		
	    	CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	    	v_num_rows := 0;
	    	UPDATE EXT.OUT_BATCH_CONTROL
	    	SET STATUS = v_const_out_batch_control_error,
	    		END_DATE = CURRENT_TIMESTAMP
	    	WHERE FILE_NAME = FILENAME
	    		AND ID_PROCESO = v_idproceso;
	    	 commit;	
	    --	RESIGNAL;		
	  END;

    
    -- BORRADO E INSERT EN EXT.OUT_AUDITORIA_INF_TIP_FILE
    BEGIN
		-- Iniciamos ID Proceso
    	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
    	
        -- INICIALIZAMOS EL PROCESO
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq , v_log_count, v_idproceso, 'info');
    	
	    -- SELECCIONAMOS PERIODSEQ
	    SELECT PERIODSEQ, NAME, STARTDATE, TO_VARCHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate, v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
    	
    	-- Informamos v_fechafichero
    	SELECT TO_DATE(SUBSTR(:v_fechaliquidacion,1,6) || '01','YYYYMMDD') INTO v_fechafichero FROM DUMMY;
    	
	    --FICHERO DE SALIDA  
        --SELECT v_file_name || '.txt' INTO FILENAME from dummy;
        --BRG 20250813 Nuevos nombres de ficheros por petición de MAA
		SELECT v_file_name||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME from dummy;
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA ' || FILENAME, v_log_count, v_idproceso, 'info');
	    
	    BEGIN
			--REGISTRO OUT_BATCH_CONTROL
			INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO, FILE_NAME, PROCEDURE_NAME, TARGET_ROWS, STATUS, START_DATE, END_DATE)
			VALUES (v_idproceso, FILENAME, ::CURRENT_OBJECT_NAME, 0, :v_const_out_batch_control_load, CURRENT_TIMESTAMP, NULL);
			COMMIT;
		END;

        -- BORRADO EXT.OUT_AUDITORIA_INF_PCO_FILE
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio borrado de la tabla EXT.OUT_AUDITORIA_INF_PCO_FILE', v_log_count, v_idproceso, 'info');
        TRUNCATE TABLE EXT.OUT_AUDITORIA_INF_PCO_FILE;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Borrado de la tabla EXT.OUT_AUDITORIA_INF_PCO_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        -- INSERT EN EXT.OUT_AUDITORIA_INF_PCO_FILE
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Insert en la tabla EXT.OUT_AUDITORIA_INF_PCO_FILE', v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.OUT_AUDITORIA_INF_PCO_FILE
            SELECT DISTINCT
                RPAD(LPAD(IFNULL(SUBSTR(ST.CHANNEL,1,2),'0'),2,'0') ||                      -- COMPANIA (N2)
                LPAD(IFNULL(SUBSTR(TA.GENERICATTRIBUTE3,1, 4),'0'),4,'0') ||           -- OFICINA (N4)
                LPAD(IFNULL(TO_VARCHAR(ST.COMPENSATIONDATE,'YYYYMM'),'0'),6,'0') ||       -- FECHA CARGO FIN N(6)
                LPAD(IFNULL(SUBSTR(TA.GENERICATTRIBUTE3,5,6),'0'),6,'0') ||            -- AGENTE (N6)
                RPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE1,5,1),' '),1,' ') ||            -- TIPO_PAGO (A1)
                LPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE2,1,3),'0'),3,'0') ||            -- CONCEPTO PAGO (N3)
                LPAD(IFNULL(SUBSTR(ST.PRODUCTID,3,5),'0'),5,'0') ||                    -- PRODUCTO (N5)
                RPAD(IFNULL(CASE WHEN VALUE < 0 THEN '-' ELSE '+' END,' '),1,' ') ||   -- SIGNO (A1)
                LPAD(IFNULL(ABS(CAST(ROUND(VALUE, 2) AS INTEGER)),'0'),4,'0') ||
                LPAD(IFNULL(ABS(MOD(ROUND(VALUE,2),1)*100),'0'),2,'0')  ||             -- IMPORTE DE PAGO 5,2
                LPAD(IFNULL(TO_VARCHAR(ST.COMPENSATIONDATE,'YYYYMM'),'0'),6,'0'), 255, ' ')          -- FECHA CARGO FIN N(6)
            FROM TCMP.CS_SALESTRANSACTION ST
            INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                AND TA.TENANTID = :v_idtenant AND TA.PROCESSINGUNITSEQ = 38280596832649217
            INNER JOIN TCMP.CS_EVENTTYPE ET ON ST.EVENTTYPESEQ = ET.DATATYPESEQ
            	AND ET.REMOVEDATE = :v_eot
            	--Filtramos directamente por el SEQ de los eventtypeid de Pago Comercial
            	AND ET.EVENTTYPEID = 'Pago Comercial' 
            WHERE ST.TENANTID = :v_idtenant AND ST.PROCESSINGUNITSEQ = 38280596832649217
                AND ST.MODELSEQ = 0
                AND ST.COMPENSATIONDATE = :v_fechafichero;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insert en la tabla EXT.OUT_AUDITORIA_INF_PCO_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        UPDATE EXT.OUT_BATCH_CONTROL
	    SET STATUS = v_const_out_batch_control_ok,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    WHERE FILE_NAME = FILENAME
	    	AND ID_PROCESO = v_idproceso;
    
    	CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');

    END;


END
