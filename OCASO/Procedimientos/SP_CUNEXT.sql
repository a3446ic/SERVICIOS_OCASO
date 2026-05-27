CREATE PROCEDURE EXT.SP_CUNEXT(OUT FILENAME VARCHAR(120) , IN i_pPlRunSeq VARCHAR(50))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 03-Abril-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: nos permite obtener en la tabla FINAL_CUNEXT_FILE los 
    | cambios en que se han producido en las posiciones, relacionando código
    | único de Callidus con el código de OCASO.
	|
	| Version:	0.1	SMM 20250403		Initial Version.
	|			0.2	BRG	20250813		Cambio FILENAME
	|
    -----------------------------------------------------------------------
*/
BEGIN
    -- DECLARACIÓN DE CONSTANTES Y VARIABLES
    DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.2';
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
	DECLARE v_file_name VARCHAR(250) := 'CUNEXT1636_';
	DECLARE v_fechalocal TIMESTAMP;

	
    --CONTROLADOR DE EXCEPCIONES
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
	
		-- ROLLBACK;
		
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
		COMMIT;
	END;
	
	-- SELECCIONAMOS PERIODSEQ
	SELECT PERIODSEQ, NAME, STARTDATE, TO_CHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate,v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
	
	-- LFC 20251205: A petición de OCASO fijamos fecha de inicio del periodo en Enero 2000
	v_PeriodStartDate := '200001';
	
	
	--FICHERO DE SALIDA  
	--EJ CUNEXT: INYC_CUNEXT_PRD_20250128_180000_OCASO_GMFTP163601P_1zif2.txt
    --SELECT v_file_name||TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_GMFTP163601P.txt' INTO FILENAME from dummy;
    --BRG 20250813 Nuevos nombres de ficheros por petición de MAA
	--SELECT v_file_name||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME from dummy;
	-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA
	SELECT UTCTOLOCAL (current_utctimestamp, 'CET') INTO v_fechalocal FROM DUMMY;
	SELECT v_file_name||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME from dummy;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA ' || FILENAME, v_log_count, v_idproceso, 'info');      
	
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Periodo ' || v_PeriodName, v_log_count, v_idproceso, 'info');   

	/*******************************************************/
    /**********BORRADO DE TABLAS ***************************/
    /*******************************************************/
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Inicio Borrado Tabla FINAL_CUNEXT_FILE',v_log_count,v_idproceso,'info');
    TRUNCATE TABLE EXT.FINAL_CUNEXT_FILE;
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Fin Borrado Tabla FINAL_CUNEXT_FILE',v_log_count,v_idproceso,'info');
    
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de TEMP_CUNEXT_FILE.', v_log_count, v_idproceso, 'info');

    TEMP_CUNEXT_FILE= 
        SELECT DISTINCT                   
            pos.name AS CODIGO_CALLIDUS,
            pos.genericattribute3 AS CODIGO_OCASO,
            POS.EFFECTIVESTARTDATE,
            POS.EFFECTIVEENDDATE
        from cs_position pos
        where POS.TENANTID = v_idtenant
            AND pos.createdate >= v_PeriodStartDate
            AND POS.REMOVEDATE = to_date('22000101','YYYYMMDD')
        order by POS.NAME,pos.genericattribute3,POS.EFFECTIVESTARTDATE;
        
        
    v_num_rows = RECORD_COUNT(:TEMP_CUNEXT_FILE);

	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de TEMP_CUNEXT_FILE ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');

    --------------- Creacion de la cabecera de FINAL_CUNEXT_FILE -----------------
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la cabecera tabla de FINAL_CUNEXT_FILE.', v_log_count, v_idproceso, 'info');

   
    INSERT INTO EXT.FINAL_CUNEXT_FILE(CABECERA,LINE) 
    SELECT 
         0 AS CABECERA,                --Marco que es la cabecera
        'CODIGO_CALLIDUS'||'|'||
        'CODIGO_OCASO'||'|'||
        'EFFECTIVESTARTDATE'||'|'||
        'EFFECTIVEENDDATE' AS LINE 
    FROM DUMMY;

    -- v_num_rows = RECORD_COUNT(EXT.FINAL_CUNEXT_FILE);
    v_num_rows = ::ROWCOUNT;

	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la cabecera tabla de FINAL_CUNEXT_FILE ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');

    ----------------- Insertamos los datos en FINAL_CUNEXT_FILE -----------------
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de FINAL_CUNEXT_FILE.', v_log_count, v_idproceso, 'info');
  
  
  INSERT INTO EXT.FINAL_CUNEXT_FILE(CABECERA,LINE)  
        SELECT
             ROW_NUMBER() OVER (ORDER BY tablacun.CODIGO_CALLIDUS,tablacun.CODIGO_OCASO,tablacun.EFFECTIVESTARTDATE),
             IFNULL(tablacun.CODIGO_CALLIDUS,'')||'|'||
             IFNULL(tablacun.CODIGO_OCASO,'')||'|'||
             IFNULL(TO_char(tablacun.EFFECTIVESTARTDATE,'YYYYMMDD'),'')||'|'||  
             IFNULL(TO_char(tablacun.EFFECTIVEENDDATE,'YYYYMMDD'),'')
             AS line
    	FROM :TEMP_CUNEXT_FILE tablacun;

    
    
    -- v_num_rows = RECORD_COUNT(:TEMP_FINAL_CUNEXT_FILE);
    v_num_rows = ::ROWCOUNT;
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la cabecera tabla de FINAL_CUNEXT_FILE ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');
    
    
    
    
    
   UPDATE EXT.OUT_BATCH_CONTROL
	SET STATUS = v_const_out_batch_control_ok,
		TARGET_ROWS = v_num_rows,
		FILE_NAME = FILENAME,
		END_DATE = CURRENT_TIMESTAMP
	WHERE ID_PROCESO = v_idproceso;
    
    CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');
    
    

END