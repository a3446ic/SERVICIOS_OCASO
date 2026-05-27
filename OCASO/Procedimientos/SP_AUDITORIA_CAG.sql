CREATE PROCEDURE EXT.SP_AUDITORIA_CAG (OUT FILENAME VARCHAR(120), IN i_pPlRunSeq VARCHAR(50)) 
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
    | Version: 0.3  DTB 		20250716	Añadido RPAD para que la longitud de linea coincida con la de Oracle.
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
    --DECLARE v_file_name_start VARCHAR(250) := 'RECIBOS.COMIS.AGENTE_';
    --DECLARE v_file_name_empresa VARCHAR(10) := '_OCASO';
	--DECLARE v_file_name_end VARCHAR(20) := '_COMAGWCAFTP212602P';
	DECLARE v_file_name VARCHAR(50) := 'COMA2126_AUDITO_COMIS_AGENTE_';
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

    
    -- BORRADO E INSERT EN EXT.OUT_AUDITORIA_INF_CAG_FILE
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
        TBL_DIM1 =
                SELECT DISTINCT
                    IND.RULEELEMENTSEQ,
                    IND.DIMENSIONSEQ,
                    IND.ORDINAL,
                    CASE WHEN IND.MINSTRING IS NULL
                        THEN (CASE WHEN CLAS.CLASSIFIERID IS NULL THEN TO_VARCHAR(IND.MINVALUE) ELSE TO_VARCHAR(CLAS.CLASSIFIERID) END)
                        ELSE IND.MINSTRING
                    END VAL_DIM
                FROM TCMP.CS_MDLTINDEX IND
                LEFT JOIN TCMP.CS_CLASSIFIER CLAS ON IND.CLASSIFIERSEQ = CLAS.CLASSIFIERSEQ
                    AND  CLAS.REMOVEDATE = :v_eot
                    AND CLAS.TENANTID = :v_idTenant
                WHERE  IND.REMOVEDATE = :v_eot
                    AND IND.TENANTID = :v_idTenant
                    AND IND.MODELSEQ = 0
                    AND IND.DIMENSIONSEQ = 1;
        v_num_rows := RECORD_COUNT(:TBL_DIM1);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'TBL_DIM1 creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');

        TBL_DIM2 =
                SELECT DISTINCT
                    IND.RULEELEMENTSEQ,
                    IND.DIMENSIONSEQ,
                    IND.ORDINAL,
                    CASE WHEN IND.MINSTRING IS NULL
                        THEN (CASE WHEN CLAS.CLASSIFIERID IS NULL THEN TO_VARCHAR(IND.MINVALUE) ELSE TO_VARCHAR(CLAS.CLASSIFIERID) END)
                        ELSE IND.MINSTRING
                    END VAL_DIM
                FROM TCMP.CS_MDLTINDEX IND
                LEFT JOIN TCMP.CS_CLASSIFIER CLAS ON IND.CLASSIFIERSEQ = CLAS.CLASSIFIERSEQ
                    AND CLAS.REMOVEDATE = :v_eot
                    AND CLAS.TENANTID = :v_idTenant
                WHERE IND.REMOVEDATE = :v_eot
                    AND IND.TENANTID = :v_idTenant
                    AND IND.MODELSEQ = 0
                    AND IND.DIMENSIONSEQ = 2;
        v_num_rows := RECORD_COUNT(:TBL_DIM2);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'TBL_DIM2 creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');

        TBL_DIM3 =
                SELECT DISTINCT
                    IND.RULEELEMENTSEQ,
                    IND.DIMENSIONSEQ,
                    IND.ORDINAL,
                    CASE WHEN IND.MINSTRING IS NULL
                        THEN (CASE WHEN CLAS.CLASSIFIERID IS NULL THEN TO_VARCHAR(TO_INT(IND.MINVALUE)) ELSE TO_VARCHAR(CLAS.CLASSIFIERID) END)
                        ELSE IND.MINSTRING
                    END VAL_DIM
                FROM TCMP.CS_MDLTINDEX IND
                LEFT JOIN TCMP.CS_CLASSIFIER CLAS ON IND.CLASSIFIERSEQ = CLAS.CLASSIFIERSEQ
                    AND CLAS.REMOVEDATE = :v_eot
                    AND CLAS.TENANTID = :v_idTenant
                WHERE IND.REMOVEDATE = :v_eot
                    AND IND.TENANTID = :v_idTenant
                    AND IND.MODELSEQ = 0
                    AND IND.DIMENSIONSEQ = 3;
        v_num_rows := RECORD_COUNT(:TBL_DIM3);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'TBL_DIM3 creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
		
		-- BORRADO EXT.OUT_AUDITORIA_INF_CAG_FILE    
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio borrado de la tabla EXT.OUT_AUDITORIA_INF_CAG_FILE', v_log_count, v_idproceso, 'info');
        TRUNCATE TABLE EXT.OUT_AUDITORIA_INF_CAG_FILE;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Borrado de la tabla EXT.OUT_AUDITORIA_INF_CAG_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        -- INSERT EN EXT.OUT_AUDITORIA_INF_CAG_FILE
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Insert en la tabla EXT.OUT_AUDITORIA_INF_CAG_FILE', v_log_count, v_idproceso, 'info');

        -- INSERT
        INSERT INTO EXT.OUT_AUDITORIA_INF_CAG_FILE
            SELECT DISTINCT
                RPAD(LPAD(IFNULL(ABS(POS.GENERICATTRIBUTE8),'0'),2,'0') ||                      -- COMPANIA (N2)
                LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,1,4),'0'),4,'0') ||               -- OFICINA  (N4)
                RPAD(IFNULL(CASE WHEN SUBSTR(POS.GENERICATTRIBUTE3, 5, 6) <> ' ' THEN SUBSTR(POS.GENERICATTRIBUTE3, 5, 6)
                    WHEN SUBSTR(POS.GENERICATTRIBUTE3, 1, 4) <> ' ' THEN SUBSTR(POS.GENERICATTRIBUTE3, 1, 6)
                END,'0'), 6,'0') ||                                                     -- AGENTE (A6)
                LPAD(IFNULL(SUBSTR(DIM1.VAL_DIM,1,7),'0'),7,'0') ||                        -- PRODUCTO (N5)
                LPAD(IFNULL(SUBSTR(DIM3.VAL_DIM,1,3),'0'),3,'0') ||                        -- CLAVE MECANIZACION(N3)
                RPAD(IFNULL((CASE WHEN SUBSTR(MDLT.NAME,8,3) = 'DIF' THEN '001'
                    WHEN SUBSTR(MDLT.NAME,15,1) IN ('1','2','3') THEN '003'
                    ELSE '002'
                END),' '),3,' ') ||                                                     -- TIPO_RETR (A3) (001-INSP,002-AGENTE,003-RRTT)
                RPAD(IFNULL(SUBSTR(DIM2.VAL_DIM,1,3),' '),3,' ') ||                        -- TIPO_COMISION (A3) (GES-GESTION,CON-CONSERVACION,COB-COBRO)
                LPAD(IFNULL(ABS(CAST(ROUND(VALUE, 2) AS INTEGER)),'0'),4,'0') ||
                LPAD(IFNULL(ABS(MOD(ROUND(VALUE,2),1)*100),'0'),2,'0')  ||                 -- PORCENTAJE
                LPAD(IFNULL(TO_VARCHAR(CELDA.EFFECTIVESTARTDATE,'YYYYMMDD'),'0'),8, '0') ||   -- FECHA INICIO
                LPAD(IFNULL(TO_VARCHAR(CELDA.EFFECTIVEENDDATE,'YYYYMMDD'),'0'), 8, '0'),255,' ')       -- FECHA FIN
            FROM TCMP.CS_POSITION POS
            INNER JOIN TCMP.CS_VARIABLEASSIGNMENT VAS ON POS.RULEELEMENTOWNERSEQ = VAS.RULEELEMENTOWNERSEQ
                AND VAS.REMOVEDATE = :v_eot
                AND VAS.EFFECTIVESTARTDATE <= LAST_DAY(v_fechafichero)
                AND VAS.EFFECTIVEENDDATE > LAST_DAY(v_fechafichero)
                AND VAS.MODELSEQ = 0
                AND VAS.TENANTID = :v_idTenant
            INNER JOIN TCMP.CS_VARIABLE VAR ON VAR.RULEELEMENTSEQ = VAS.VARIABLESEQ
                AND VAR.REMOVEDATE = :v_eot
                AND VAR.EFFECTIVESTARTDATE <= LAST_DAY(v_fechafichero)
                AND VAR.EFFECTIVEENDDATE > LAST_DAY(v_fechafichero)
                AND VAR.NAME LIKE 'MDLTV-%-CUADRO-%'
                AND VAR.MODELSEQ = 0
                AND VAR.TENANTID = :v_idTenant
            INNER JOIN TCMP.CS_RELATIONALMDLT MDLT ON VAS.ASSIGNMENTSEQ = MDLT.RULEELEMENTSEQ
                AND MDLT.REMOVEDATE = :v_eot
                AND MDLT.TENANTID = :v_idTenant
                AND MDLT.MODELSEQ = 0
                AND MDLT.EFFECTIVESTARTDATE <= LAST_DAY(v_fechafichero)
                AND MDLT.EFFECTIVEENDDATE > LAST_DAY(v_fechafichero)
            INNER JOIN TCMP.CS_MDLTCELL CELDA ON MDLT.RULEELEMENTSEQ = CELDA.MDLTSEQ
                AND CELDA.REMOVEDATE = :v_eot
                AND CELDA.MODELSEQ = 0
                AND CELDA.TENANTID = :v_idTenant
                AND CELDA.EFFECTIVESTARTDATE <= LAST_DAY(v_fechafichero)
                AND CELDA.EFFECTIVEENDDATE > LAST_DAY(v_fechafichero)
            INNER JOIN :TBL_DIM1 DIM1 ON CELDA.MDLTSEQ = DIM1.RULEELEMENTSEQ AND CELDA.DIM0INDEX = DIM1.ORDINAL
            INNER JOIN :TBL_DIM2 DIM2 ON CELDA.MDLTSEQ = DIM2.RULEELEMENTSEQ AND CELDA.DIM1INDEX = DIM2.ORDINAL
            INNER JOIN :TBL_DIM3 DIM3 ON CELDA.MDLTSEQ = DIM3.RULEELEMENTSEQ AND CELDA.DIM2INDEX = DIM3.ORDINAL
            WHERE POS.TENANTID = :v_idTenant AND POS.PROCESSINGUNITSEQ = 38280596832649217
                AND POS.REMOVEDATE = :v_eot
                AND POS.EFFECTIVESTARTDATE <= LAST_DAY(v_fechafichero)
                AND POS.EFFECTIVEENDDATE > LAST_DAY(v_fechafichero)
                AND POS.TITLESEQ <> 5629499534213290
                AND (POS.GENERICATTRIBUTE3 IS NOT NULL AND SUBSTR(POS.GENERICATTRIBUTE3,-6) <> '000000')
        ;
        
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insert en la tabla EXT.OUT_AUDITORIA_INF_CAG_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        UPDATE EXT.OUT_BATCH_CONTROL
	    SET STATUS = v_const_out_batch_control_ok,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    WHERE FILE_NAME = FILENAME
	    	AND ID_PROCESO = v_idproceso;
    
    	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');

    END;


END
