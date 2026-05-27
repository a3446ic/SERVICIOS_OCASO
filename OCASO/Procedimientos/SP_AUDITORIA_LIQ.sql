CREATE PROCEDURE EXT.SP_AUDITORIA_LIQ (OUT FILENAME VARCHAR(120), IN i_pPlRunSeq VARCHAR(50)) 
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER  
DEFAULT SCHEMA EXT AS
/*--------------------------------------------------------------------- 
    | Author: Diego Teijo Barral 
    | Company: Inycom 
    | Initial Version Date: 06-Junio-2025
    |
    |---------------------------------------------------------------------- 
    | Procedure Purpose:
    | Version: 0.01	DTB 		20250606	Initial Version 
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
    --DECLARE v_file_name_start VARCHAR(250) := 'RECIBOS.LIQUID.S4S5_';
    --DECLARE v_file_name_empresa VARCHAR(10) := '_OCASO';
	--DECLARE v_file_name_end VARCHAR(20) := '_LIQSGWCAFTP212602P';
	DECLARE v_file_name VARCHAR(50) := 'LIQS2126_AUDITO_LIQUID_S4S5_';

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

    
    -- BORRADO E INSERT EN EXT.OUT_AUDITORIA_INF_LIQ_FILE
    BEGIN
        -- INICIALIZAMOS EL PROCESO
        SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;

        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq , v_log_count, v_idproceso, 'info');
    
	    -- SELECCIONAMOS PERIODSEQ
	    SELECT PERIODSEQ, NAME, STARTDATE, TO_CHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate, v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
    	
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


        -- BORRADO EXT.OUT_AUDITORIA_INF_LIQ_FILE    
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio borrado de la tabla EXT.OUT_AUDITORIA_INF_LIQ_FILE', v_log_count, v_idproceso, 'info');
        TRUNCATE TABLE EXT.OUT_AUDITORIA_INF_LIQ_FILE;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Borrado de la tabla EXT.OUT_AUDITORIA_INF_LIQ_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        -- INSERT EN EXT.OUT_AUDITORIA_INF_LIQ_FILE
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Insert en la tabla EXT.OUT_AUDITORIA_INF_LIQ_FILE', v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.OUT_AUDITORIA_INF_LIQ_FILE
            SELECT DISTINCT
                RPAD(LPAD(IFNULL(SUBSTR(LIQ.COMPANIA,1,2),'0'),2,'0') ||                                -- COMPANIA
                LPAD(IFNULL(SUBSTR(LIQ.TIPODOCUMENTO,1,1),'0'),1,'0') ||                           -- TIPO-DOCUMENTO
                LPAD(IFNULL(TO_VARCHAR(LIQ.FECHA,'YYYYMM'),'0'),6,'0') ||                             -- FECHA CARGO
                LPAD(IFNULL(SUBSTR(LIQ.POSICION_COMERCIAL,2,3),'0'),3, '0') ||                     -- OFICINA
                LPAD(IFNULL(SUBSTR(LIQ.POSICION_COMERCIAL,7,4),'0'),4, '0') ||                     -- AGENTE
                LPAD(IFNULL(SUBSTR(LIQ.COD_CONCEPTO,1,3),'0'),3,'0') ||                            -- CONCEPTO
                LPAD(IFNULL(SUBSTR(LIQ.PRODUCTO,1,5),'0'),5,'0') ||                                -- PRODUCTO
                RPAD(IFNULL(CASE WHEN LIQ.IMPORTE < 0 THEN '-' ELSE '+' END,' '),1,' ' ) ||        -- SIGNO
                LPAD(IFNULL(ABS(CAST(ROUND(LIQ.IMPORTE, 2) AS INTEGER)),'0'),8,'0') ||
                LPAD(IFNULL(ABS(MOD(ROUND(LIQ.IMPORTE,2),1)*100),'0'),2,'0') ||                    -- IMPORTE
                LPAD(IFNULL(SUBSTR(LIQ.POSICION_COMERCIAL,2,3),'0'),3, '0') ||                     -- OFICINA RECEPTORA
                RPAD(IFNULL(SUBSTR(LIQ.PROGRAMA,1,8),' '),8,' ') ||                                -- PROGRAMA
                RPAD(IFNULL(CASE
                    WHEN SUBSTR(LIQ.DOC_NIF,1,1) IN('A','B','C','D','E','F','G','H','J', 'N', 'P','Q', 'R','S','K','L','M', 'U','V','W') THEN 'C'
                    WHEN SUBSTR(LIQ.DOC_NIF,1,1) IN( 'X','Y','Z') THEN 'N'
                    WHEN SUBSTR(LIQ.DOC_NIF,1,1) IN ('0','1','2','3','4','5','6','7','8','9') THEN 'D'
                END,' '),1,' ') ||
                RPAD(IFNULL(SUBSTR(LIQ.DOC_NIF,1,8),' '),8,' ') ||
                RPAD(IFNULL(SUBSTR(POS.NAME,10,2),' '),2,' '), 255, ' ')
            FROM EXT.FINAL_LIQEXT_CABECERA_FILE LIQ
            INNER JOIN TCMP.CS_POSITION POS ON LIQ.POSICION_COMERCIAL = POS.GENERICATTRIBUTE3
                AND POS.TENANTID = :v_idtenant AND POS.PROCESSINGUNITSEQ = 38280596832649217
                AND POS.EFFECTIVESTARTDATE <= LAST_DAY(v_fechafichero)
                AND POS.EFFECTIVEENDDATE >= LAST_DAY(v_fechafichero)
                AND POS.REMOVEDATE = :v_eot
            WHERE LIQ.PERIODSEQ = :v_PeriodSeq;
        
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insert en la tabla EXT.OUT_AUDITORIA_INF_LIQ_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        UPDATE EXT.OUT_BATCH_CONTROL
	    SET STATUS = v_const_out_batch_control_ok,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    WHERE FILE_NAME = FILENAME
	    	AND ID_PROCESO = v_idproceso;
    	
    	CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,v_proc_name,'FILENAME: ' || FILENAME, v_log_count, v_idproceso, 'info');
    	CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');

    END;


END
