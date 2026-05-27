CREATE PROCEDURE EXT.SP_SAPINF(OUT FILENAME VARCHAR(120), IN i_param VARCHAR(50))
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Brais Romero Garcia
    | Company: Inycom
    | Initial Version Date: 09-Junio-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Extracción de datos de la tabla SAP
 |
 | Version: 0.1 BRG 20250609  Initial Version.
 |   0.2 BRG 20250611  Añadida modificación al FILENAME para que coincida con Oracle.
 |   0.3 BRG 20250721  Cambiado FILENAME por petición de ocaso
 |   0.4 BRG 20250813  Cambio FILENAME
 |   0.5 SMM 20250922  Cambio parámetros de entrada
 |
    -----------------------------------------------------------------------
*/
BEGIN
 DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
 DECLARE v_version VARCHAR2(10) := '0.5';
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
 DECLARE v_file_name VARCHAR(20) := 'SAPINF2119_';
	DECLARE v_fechalocal TIMESTAMP;

 DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
    DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
    DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK;
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,v_proc_name,'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE, '') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE,v_log_count,v_idproceso,'error');
        v_num_rows := 0;
        UPDATE EXT.OUT_BATCH_CONTROL
         SET
             STATUS = v_const_out_batch_control_error,
             END_DATE = CURRENT_TIMESTAMP
         WHERE
             FILE_NAME = FILENAME
             AND ID_PROCESO = v_idproceso;
        COMMIT;
        RESIGNAL;
    END;
    
    -- Iniciamos ID Proceso
    SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
    
    -------------------------------------------------------------------------------
    --FILTRAMOS PARAMETROS DE ENTRADA
    -------------------------------------------------------------------------------
    IF ( (SELECT LENGTH(:i_param) FROM DUMMY ) > 6) THEN
     
     -- SELECCIONAMOS PERIODSEQ
  SELECT PERIODSEQ, NAME, STARTDATE, TO_VARCHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName, v_PeriodStartDate,v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(:v_idTenant, :i_param);
     
    ELSE
     
     -- Función para sacar periodo a partir de la fecha
     SELECT PERIODSEQ, NAME, STARTDATE, TO_VARCHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName, v_PeriodStartDate, v_fechaliquidacion 
     FROM EXT.LIB_GLOBAL:getPeriodRowFromFecha(:v_idtenant, :i_param || '01');
     
     
    END IF;
    -------------------------------------------------------------------------------
    
 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_fecha_cargo: ' || v_fechaliquidacion , v_log_count, v_idproceso, 'info');
 
 -- Función para sacar periodo a partir de la fecha
    -- SELECT PERIODSEQ, NAME, STARTDATE, TO_VARCHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName, v_PeriodStartDate, v_fechaliquidacion 
    -- FROM EXT.LIB_GLOBAL:getPeriodRowFromFecha(:v_idtenant, :i_fecha_cargo || '01');
    
    -- Fichero de salida 
    --SELECT :v_file_name_start || :v_fechaliquidacion || :v_file_name_end || '.txt' INTO FILENAME FROM DUMMY;
    --BRG 20250813 Nuevos nombres de ficheros por petición de MAA
 --SELECT v_file_name||TO_VARCHAR(v_PeriodStartDate, 'YYYYMM')||'_'||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME from dummy;
 	-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA
	SELECT UTCTOLOCAL (current_utctimestamp, 'CET') INTO v_fechalocal FROM DUMMY;
	SELECT v_file_name||TO_VARCHAR(v_PeriodStartDate, 'YYYYMM')||'_'||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME from dummy;
 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA: ' || FILENAME, v_log_count, v_idproceso, 'info');
 
 BEGIN
  --REGISTRO OUT_BATCH_CONTROL
  INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO, FILE_NAME, PROCEDURE_NAME, TARGET_ROWS, STATUS, START_DATE, END_DATE)
  VALUES (v_idproceso, FILENAME, ::CURRENT_OBJECT_NAME, 0, :v_const_out_batch_control_load, CURRENT_TIMESTAMP, NULL);
  COMMIT;
 END;
    
    --------------- Truncado de OUT_REPEXT_INF_SAP_FILE -------------- 
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Truncado de la tabla de OUT_REPEXT_INF_SAP_FILE.', v_log_count, v_idproceso, 'info');
    TRUNCATE TABLE EXT.OUT_REPEXT_INF_SAP_FILE;
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Truncado de la tabla de OUT_REPEXT_INF_SAP_FILE.', v_log_count, v_idproceso, 'info');
    
    --------------- Creacion de OUT_REPEXT_INF_SAP_FILE --------------
 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla OUT_REPEXT_INF_SAP_FILE.', v_log_count, v_idproceso, 'info'); 
 
 INSERT INTO EXT.OUT_REPEXT_INF_SAP_FILE
  SELECT P.LINE
  FROM EXT.FINAL_REPEXT_INF_SAP_FILE P
  WHERE P.PERIODSEQ = :v_PeriodSeq
  ORDER BY 
   CASE WHEN SUBSTR(P.LINE,7,10) IS NULL OR TRIM(SUBSTR(P.LINE,7,10)) = '' THEN 1 ELSE 0 END
   , SUBSTR(P.LINE,7,10) ASC, SUBSTR(P.LINE,18,23) ASC, SUBSTR(P.LINE,1,2) ASC, SUBSTR(P.LINE,100,3) ASC, SUBSTR(P.LINE,109,5) ASC, P.LINE ASC
   --, CASE WHEN SUBSTR(P.LINE,100,3) IS NULL OR TRIM(SUBSTR(P.LINE,100,3)) = ';' OR TRIM(SUBSTR(P.LINE,100,3)) = '' THEN SUBSTR(P.LINE,7,10) ELSE TRIM(SUBSTR(P.LINE,100,3)) END 
  -- , CASE WHEN SUBSTR(P.LINE,109,5) IS NULL OR TRIM(SUBSTR(P.LINE,109,5)) = ';' OR TRIM(SUBSTR(P.LINE,109,5)) = '' THEN SUBSTR(P.LINE,7,10) ELSE TRIM(SUBSTR(P.LINE,109,5)) END  
  ;
  --  ,SUBSTR(P.LINE,7,10) ASC--, SUBSTR(P.LINE,18,23) ASC, SUBSTR(P.LINE,1,2) ASC, SUBSTR(P.LINE,100,3) ASC, SUBSTR(P.LINE,109,5) ASC, P.LINE ASC
 
 
 v_num_rows = RECORD_COUNT(EXT.OUT_REPEXT_INF_SAP_FILE);
 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla OUT_REPEXT_INF_SAP_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');
 
 --------------- Actualización OUT_BATCH_CONTROL --------------
    UPDATE EXT.OUT_BATCH_CONTROL
  SET STATUS = v_const_out_batch_control_ok,
  TARGET_ROWS = v_num_rows,
  END_DATE = CURRENT_TIMESTAMP
  WHERE FILE_NAME = FILENAME
   AND ID_PROCESO = v_idproceso;

 --FIN
 CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');
    
END