CREATE PROCEDURE EXT.SP_AUDITORIA_AGE (OUT FILENAME VARCHAR(120), IN i_pPlRunSeq VARCHAR(50)) 
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER  
DEFAULT SCHEMA EXT AS
/*--------------------------------------------------------------------- 
    | Author: Diego Teijo Barral 
    | Company: Inycom 
    | Initial Version Date: 10-Junio-2025
    |
    |---------------------------------------------------------------------- 
    | Procedure Purpose:
    | Version: 0.01	DTB 		20250610	Initial Version
    | Version: 0.2  DTB 		20250611	Añadida modificación al FILENAME para que coincida con Oracle.
    | Version: 0.3  DTB 		20250716	Añadido RPAD para que la longitud de linea coincida con Oracle.
    | Version: 0.4  DTB 		20250716	Cambio FILENAME
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
    --DECLARE v_file_name_start VARCHAR(250) := 'RECIBOS.AGENTES_';
    --DECLARE v_file_name_empresa VARCHAR(10) := '_OCASO';
	--DECLARE v_file_name_end VARCHAR(20) := '_AGENGWCAFTP212602P';
	DECLARE v_file_name VARCHAR(50) := 'AGEN2126_AUDITO_AGENTES_';

    -- CONTROLADOR DE EXCEPCIONES
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	    BEGIN	
	    	ROLLBACK;		
	    	CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	    	v_num_rows := 0;
	    	UPDATE EXT.OUT_BATCH_CONTROL
	    	SET STATUS = v_const_out_batch_control_error,
	    		END_DATE = CURRENT_TIMESTAMP
	    	WHERE FILE_NAME = :FILENAME
	    		AND ID_PROCESO = :v_idproceso;
	    	 commit;	
	    --	RESIGNAL;		
	  END;

    
    -- BORRADO E INSERT EN EXT.OUT_AUDITORIA_INF_AGE_FILE
    BEGIN

        -- INICIALIZAMOS EL PROCESO
        SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;

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

        -- VARIABLES TABLA PARA EL INSERT
        TBL_PR =
                SELECT PR.PARENTPOSITIONSEQ,PR.CHILDPOSITIONSEQ
                FROM TCMP.CS_POSITIONRELATION PR
                INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT ON PR.POSITIONRELATIONTYPESEQ = PRT.DATATYPESEQ
                    AND PRT.TENANTID = :v_idTenant
                    AND PRT.REMOVEDATE = v_eot
                    AND PRT.NAME='Contract Rollup'
                WHERE PR.TENANTID = :v_idTenant
                    AND PR.CREATEDATE < LAST_DAY(:v_fechafichero)
                    AND PR.REMOVEDATE > LAST_DAY(:v_fechafichero)
                    AND PR.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
                    AND PR.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero);
        v_num_rows := RECORD_COUNT(:TBL_PR);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'TBL_PR creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');

		-- BORRADO EXT.OUT_AUDITORIA_INF_AGE_FILE    
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio borrado de la tabla EXT.OUT_AUDITORIA_INF_AGE_FILE', v_log_count, v_idproceso, 'info');
        TRUNCATE TABLE EXT.OUT_AUDITORIA_INF_AGE_FILE;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Borrado de la tabla EXT.OUT_AUDITORIA_INF_AGE_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

		-- INSERT EN EXT.OUT_AUDITORIA_INF_AGE_FILE
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Insert en la tabla EXT.OUT_AUDITORIA_INF_AGE_FILE', v_log_count, v_idproceso, 'info');
        
        -- INSERT
        INSERT INTO EXT.OUT_AUDITORIA_INF_AGE_FILE
            SELECT DISTINCT
                RPAD(LPAD(IFNULL(ABS(POS.GENERICATTRIBUTE8),'01'),2,'0') ||             -- COMPANIA (N2)
                LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3, 1, 4),'0') ,4,'0') ||    -- OFICINA  (N4)
                RPAD(IFNULL(CASE WHEN SUBSTR(POS.GENERICATTRIBUTE3, 5, 6) <> ' ' THEN SUBSTR(POS.GENERICATTRIBUTE3, 5, 6)
                    WHEN SUBSTR(POS.GENERICATTRIBUTE3, 1, 4) <> ' ' THEN SUBSTR(POS.GENERICATTRIBUTE3, 1, 6)
                END,'0'), 6,'0') ||                                             -- AGENTE (A6)
                RPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE6,1,3),' '), 3,' ') ||      -- WCOADRON cuadro que corresponde al agente RRGG/VIDA
                RPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE7,1,3),' '), 3,' ') ||      -- WCOADRORT Cuadro que corresponde al agente RRTT
                --JGE 20231030 modificacion del proyecto de Reparto de Costes
                --RPAD(' ',1) ||                                                  -- Indicador de empleado
                (CASE WHEN PAR.GENERICATTRIBUTE4 IS NOT NULL THEN 'S' ELSE 'N' END) ||
                RPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE5,1,3),' '), 3 ,' ') ||     -- CUADRO_INSPECTOR
                --LPAD(IFNULL(TO_CHAR(POS.GENERICDATE2,'YYYYMMDD'),'0'),8, '0') ||   -- FECHA INICIO AGENTE
                LPAD(IFNULL(TO_VARCHAR((
                    SELECT MIN(X.EFFECTIVESTARTDATE) FROM TCMP.CS_POSITION X
                    WHERE X.REMOVEDATE = v_eot AND X.RULEELEMENTOWNERSEQ = POS.RULEELEMENTOWNERSEQ
                ),'YYYYMMDD'),'0'),8, '0') ||
                LPAD(IFNULL(CASE WHEN POS.GENERICNUMBER2 >= 50
                    THEN LPAD(IFNULL(TO_VARCHAR((
                        SELECT MIN(X.EFFECTIVESTARTDATE) FROM TCMP.CS_POSITION X
                        WHERE X.REMOVEDATE = v_eot AND X.RULEELEMENTOWNERSEQ = POS.RULEELEMENTOWNERSEQ AND X.GENERICNUMBER2 >= 50
                    ),'YYYYMMDD'),'0'), 8,'0')
                    ELSE '00000000'
                END,'0'),8,'0') ||                                              -- FECHA INICIO INSPECTOR
                RPAD(IFNULL(SUBSTR(PAR.GENERICATTRIBUTE14,1,10),' '), 10, ' ') ||  -- TELEFONO
                RPAD(IFNULL(CASE WHEN SUBSTR(PPRIN.GENERICATTRIBUTE3,1,12) IS NULL
                    THEN SUBSTR(POS.GENERICATTRIBUTE3,1,12)
                    ELSE SUBSTR(PPRIN.GENERICATTRIBUTE3,1,12)
                END,'0'), 12,'0'), 255, ' ')                                               -- CODIGO DOCUMENTOS
            FROM TCMP.CS_POSITION POS
            INNER JOIN TCMP.CS_PARTICIPANT PAR ON POS.PAYEESEQ = PAR.PAYEESEQ
                AND PAR.TENANTID = :v_idTenant
                AND PAR.REMOVEDATE = v_eot
                AND PAR.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
                AND PAR.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
                AND (PAR.TERMINATIONDATE IS NULL OR PAR.TERMINATIONDATE > LAST_DAY(:v_fechafichero))
            LEFT JOIN :TBL_PR PR ON POS.RULEELEMENTOWNERSEQ = PR.CHILDPOSITIONSEQ
            LEFT JOIN TCMP.CS_POSITION PPRIN ON PR.PARENTPOSITIONSEQ = PPRIN.RULEELEMENTOWNERSEQ
                AND PPRIN.TENANTID = :v_idTenant
                AND PPRIN.CREATEDATE < LAST_DAY(:v_fechafichero)
                AND PPRIN.REMOVEDATE > LAST_DAY(:v_fechafichero)
                AND PPRIN.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
                AND PPRIN.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
                AND PPRIN.PROCESSINGUNITSEQ = 38280596832649217
            WHERE POS.TENANTID = :v_idTenant AND POS.PROCESSINGUNITSEQ = 38280596832649217
                AND POS.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
                AND POS.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
                AND POS.REMOVEDATE = v_eot
                --20220323 RAP Title sin plan
                AND POS.TITLESEQ <> 5629499534213290
                AND (POS.GENERICATTRIBUTE3 IS NOT NULL AND SUBSTR(POS.GENERICATTRIBUTE3,-6) <> '000000');
        
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insert en la tabla EXT.OUT_AUDITORIA_INF_AGE_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        UPDATE EXT.OUT_BATCH_CONTROL
	    SET STATUS = v_const_out_batch_control_ok,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    WHERE FILE_NAME = FILENAME
	    	AND ID_PROCESO = v_idproceso;
    
    	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');

    END;


END
