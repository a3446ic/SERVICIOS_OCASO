CREATE PROCEDURE EXT.SP_COMREC(OUT FILENAME VARCHAR(120) , IN i_pPlRunSeq VARCHAR(50))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS 
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 26-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Paquete PL/SQl que nos permite obtener en la tabla OUT_COMREC_INFORME_FILE
    | el contenido del fichero de recuperaciones mensuales.
    | Con parÁmetros de entrada, la fecha , fecha'YYYYMM'
	|
	| Version: 0.1	SMM 20250326		Initial Version.
	|
    -----------------------------------------------------------------------
*/
BEGIN
	
	-- DECLARACIÓN DE CONSTANTES Y VARIABLES
	DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso INTEGER;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE = EXT.LIB_CONSTANTES:v_eot; 
	DECLARE v_PeriodSeq BIGINT;
	DECLARE v_PeriodName VARCHAR2(255);
	DECLARE v_PeriodStartDate TIMESTAMP;
	DECLARE v_fechaliquidacion VARCHAR(6);
	DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
	DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
	DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
	DECLARE v_file_name VARCHAR(25) := 'COMREC_PRD_';
    
    --TABLA TEMPORAL
    DECLARE TEMP_NOMINA_FILE TABLE (
        CIA VARCHAR(2),
        DNI VARCHAR(11),
        CONCEPTO VARCHAR(6),
        IMPORTE DECIMAL(15,2),
        FCH_INI VARCHAR(6),
        FCH_FIN VARCHAR(6),
        FCH_PAGA VARCHAR(6)
    );
	
	
	--CONTROLADOR DE EXCEPCIONES
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		
		--ROLLBACK;
			
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		v_num_rows := 0;
		
		UPDATE EXT.OUT_BATCH_CONTROL
		SET STATUS = v_const_out_batch_control_error,
			END_DATE = CURRENT_TIMESTAMP
		WHERE COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
			AND ID_PROCESO = v_idproceso;
		commit;	
		RESIGNAL;
			
	END;
	
	--INICIALIZAMOS IDPROCESO
	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq , v_log_count, v_idproceso, 'info');
	
	BEGIN
		--REGISTRO OUT_BATCH_CONTROL
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_idproceso,FILENAME,::CURRENT_OBJECT_NAME,0,EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD,CURRENT_TIMESTAMP,NULL);
		-- COMMIT;
	END;
	
	-- SELECCIONAMOS PERIODSEQ
	SELECT PERIODSEQ, NAME, STARTDATE, TO_CHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate,v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
	
	
	--FICHERO DE SALIDA  
	--EJ COMREC: INYC_COMREC_PRD_20250315_200000_OCASO_OFLFTP204201P_22xhs.txt_0
    SELECT v_file_name||TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_OFLFTP204201P.txt' INTO FILENAME FROM dummy;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA ' || FILENAME, v_log_count, v_idproceso, 'info');      
	
	
	

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' Procedure starting...', v_log_count, v_idproceso, 'info');
    -- CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' Parametros de entrada: fechaCargo= ' || fecha , v_log_count, v_idproceso, 'info');
    -- checkParameters(fecha);                  --Compruebo los parametros de entrada
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' Parametros de entrada correctos', v_log_count, v_idproceso, 'info');
   
    --------------- Truncado de FINAL_COMREC_FILE -------------- 
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Truncado de la tabla FINAL_COMREC_FILE.', v_log_count, v_idproceso, 'info');
    TRUNCATE TABLE EXT.FINAL_COMREC_FILE;
    -- COMMIT;
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Truncado de la tabla de FINAL_COMREC_FILE.', v_log_count, v_idproceso, 'info');
    
    
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Truncado de la tabla de OUT_COMREC_INFORME_FILE.', v_log_count, v_idproceso, 'info');
	TRUNCATE TABLE EXT.OUT_COMREC_INFORME_FILE;
	-- COMMIT;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Truncado de la tabla de OUT_COMREC_INFORME_FILE.', v_log_count, v_idproceso, 'info');
   
    
    --------------- Creacion de FINAL_COMREC_FILE --------------
     
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla de FINAL_COMREC_FILE.', v_log_count, v_idproceso, 'info');
    
    INSERT INTO EXT.FINAL_COMREC_FILE
    SELECT 
        SUBSTR(c.genericattribute2,2,1) AS CCOMPANI,
        '' AS C_REGIONA,
        (SELECT EXTRACT(YEAR FROM per.startdate) || SUBSTR('0' || EXTRACT(MONTH FROM per.startdate),-2) FROM tcmp.cs_period per WHERE per.periodseq = pad.periodseq) AS FCARGO,
        SUBSTR(pad.positiongenericattribute3,1,4) AS COFICINA,
        '' AS CCOBRADO,
        '' AS CTIPCOBR,
        RIGHT(pad.positiongenericattribute3, 5) AS CAGERECU,
        RIGHT(c.genericattribute2,5) AS CRAMO,
        SUBSTR(so.orderid,8,16) AS CFAMILIA,
        SUBSTR(so.orderid,12,7) AS CFAMILIA,
        CASE 
			WHEN c.value < 0 THEN 
    			'-' || LPAD(TO_VARCHAR(CAST(ABS(FLOOR(c.value)) AS INTEGER)), 3, '0') || ',' || 
    				rpad(abs(mod(round(c.value,2),1)*100),2,'0') 
			ELSE 
    			LPAD(TO_VARCHAR(CAST(FLOOR(c.value) AS INTEGER)), 4, '0') || ',' || 
    				rpad((mod(round(c.value,2),1)*100),2,'0')
			END AS ICOMRECU

        FROM tcmp.csa_padimension pad
        INNER JOIN tcmp.cs_measurement m on pad.periodseq = m.periodseq AND pad.participantseq = m.payeeseq AND pad.positionseq = m.positionseq
            AND m.tenantid = v_idtenant
        INNER JOIN tcmp.cs_pmcredittrace pmct on m.measurementseq = pmct.measurementseq
            AND pmct.tenantid = v_idtenant
        INNER JOIN tcmp.cs_credit c on pad.periodseq = c.periodseq AND pmct.creditseq = c.creditseq
            AND c.tenantid = v_idtenant
        INNER JOIN tcmp.cs_salestransaction st on c.salestransactionseq = st.salestransactionseq
            AND st.tenantid = v_idtenant AND st.modelseq = 0
        INNER JOIN tcmp.cs_salesorder so on st.salesorderseq = so.salesorderseq
        WHERE pad.tenantid = v_idtenant AND pad.ispayee = 1
            AND m.name = 'PM-O-SER-COM-RRTT-Tipo39'
            AND pad.periodseq IN (SELECT periodseq FROM cs_period WHERE startdate = TO_DATE(v_fechaliquidacion, 'yyyymm'))
        ORDER BY 3,1,8,10,1;
                    
                   
           
    -- v_num_rows = RECORD_COUNT(EXT.FINAL_COMREC_FILE);
    v_num_rows = ::ROWCOUNT;
    -- COMMIT;
        
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla de FINAL_COMREC_FILE: '|| to_char(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info');
        
   
   --------------- Creacion de OUT_COMREC_INFORME_FILE --------------  
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla de OUT_COMREC_INFORME_FILE', v_log_count, v_idproceso, 'info');
    
    INSERT INTO EXT.OUT_COMREC_INFORME_FILE
        SELECT
            CCOMPANI || ';' ||
            RPAD(IFNULL(C_REGIONA,' '),4,' ') || ';' ||
            FCARGO || ';' ||
            COFICINA || ';' ||
            RPAD(IFNULL(CCOBRADO,' '),4, ' ') || ';' ||
            RPAD(IFNULL(CTIPCOBR,' '),1, ' ') || ';' ||
            CAGERECU || ';' ||
            CRAMO || ';' ||
            CFAMILIA || ';' ||
            CFAMILIA_1 || ';' ||
            ICOMRECU
        FROM EXT.FINAL_COMREC_FILE;
             
              
              
        v_num_rows = ::ROWCOUNT;
	-- COMMIT;
        
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla de OUT_COMREC_INFORME_FILE: '|| to_char(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info');
 
	UPDATE EXT.OUT_BATCH_CONTROL
	    	SET STATUS = v_const_out_batch_control_ok,
	    	FILE_NAME = FILENAME,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    	WHERE 1=1--COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
	    	AND ID_PROCESO = v_idproceso;
		
	-- INSERT INTO EXT.OUT_COMREC_INFORME_FILE
 --   VALUES ('');
 
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso, 'info');

END;
