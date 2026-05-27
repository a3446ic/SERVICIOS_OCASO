CREATE PROCEDURE EXT.SP_POST_DDEE (OUT FILENAME VARCHAR(120), IN iPipelineRunSeq VARCHAR(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rub�n Mart�nez 
    | Company: Inycom
    | Initial Version Date: 10-Noviembre-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta con un Data Extract desde Control-M
    |      para la actualizaci�n de la tabla de CARTERA_DDEE tras el Post del periodo (POSTDDEE1834)
 |
 | Version: 0.1 RMF 20251110 Initial Version.
 |
    -----------------------------------------------------------------------
*/

BEGIN

 USING SQLSCRIPT_STRING AS LIBRARY;
 USING SQLSCRIPT_SYNC AS SYNCLIB;--Para pruebas de Control-M
 
 DECLARE v_idproceso INTEGER;
 DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
 DECLARE v_version VARCHAR2(10) := '0.1';
 DECLARE v_num_rows INTEGER := 0;
 DECLARE v_log_count INTEGER := 0;
 DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
 DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
 DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
 
 DECLARE v_max_post_pipelinerunseq BIGINT;
 DECLARE v_periodSeq BIGINT;
 DECLARE v_periodName VARCHAR(50);
 DECLARE vYYYYMM VARCHAR(6);
 DECLARE vPipeStartTime TIMESTAMP;
 
 --Variables de estado
 DECLARE v_const_out_batch_control_load INT := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
 DECLARE v_const_out_batch_control_ok INT := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
 DECLARE v_const_out_batch_control_error INT := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
 
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
  
   ROLLBACK;
   
   CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
                            
   
   --v_hayError := 1;
   v_num_rows := 0;
  
   UPDATE EXT.OUT_BATCH_CONTROL
   SET STATUS = v_const_out_batch_control_error,
    END_DATE = CURRENT_TIMESTAMP
   WHERE FILE_NAME = FILENAME
    -- AND ID_PROCESO = v_idproceso
   ;
   
   commit; 
   RESIGNAL;
  
  END;
 
 BEGIN
  
  --Inicializamos el idProceso
  SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
  CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for pipelineRunSeq: ' || iPipelineRunSeq, v_log_count, v_idproceso, 'info');
  
  FILENAME = 'OUT_POSTDDEE_' || TO_VARCHAR(CURRENT_TIMESTAMP,'YYYYMMDD_HHMISS')|| '.txt';
  
  INSERT INTO "EXT"."OUT_BATCH_CONTROL" VALUES(
   v_idproceso/*ID_PROCESO <BIGINT>*/,
   FILENAME/*FILE_NAME <VARCHAR(100)>*/,
   proc_name/*PROCEDURE_NAME <VARCHAR(50)>*/,
   0/*TARGET_ROWS <INTEGER>*/,
   :v_const_out_batch_control_load/*STATUS <INTEGER>*/,
   CURRENT_TIMESTAMP/*START_DATE <TIMESTAMP>*/,
   NULL/*END_DATE <TIMESTAMP>*/
  );
  
  CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'INSERT l�nea de control en OUT_BATCH_CONTROL para FILENAME: ' || FILENAME, v_log_count, v_idproceso, 'info');
  
  SELECT PL.PERIODSEQ INTO v_periodSeq
  FROM TCMP.CS_PLRUN PL
  WHERE PL.PIPELINERUNSEQ = :iPipelineRunSeq
  ;
  
  SELECT PER.NAME, TO_VARCHAR(PER.STARTDATE,'YYYYMM') INTO v_periodName, vYYYYMM
  FROM TCMP.CS_PERIOD PER
  WHERE PER.PERIODSEQ = v_periodSeq
   AND PER.REMOVEDATE = v_eot
  ;
  
  CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Periodo a ejecutar -> periodSeq: ' || IFNULL(v_periodSeq,0) || ' | periodName: ' || IFNULL(v_periodName,'NO_ENCONTRADO') || ' | vYYYYMM: ' || vYYYYMM
         , v_log_count, v_idproceso, 'info');
  
  SELECT MAX(PL.PIPELINERUNSEQ) INTO v_max_post_pipelinerunseq
  FROM TCMP.CS_PLRUN PL
  WHERE PL.RUNPARAMETERS LIKE '%[Sequence]Post%'
            AND PL.COMMAND = 'PipelineRun'
            AND PL.STATUS = 'Successful'
            AND PL.PERIODSEQ = v_periodSeq
        ;
  
  IF(v_max_post_pipelinerunseq IS NULL)THEN
   CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Post NO ejecutado.' , v_log_count, v_idproceso, 'error');
   SIGNAL SQL_ERROR_CODE 10000 SET MESSAGE_TEXT = 'No se ha ejecutado ning�n Post para el periodo.';
  ELSE
   CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Post ejecutado: ' || v_max_post_pipelinerunseq, v_log_count, v_idproceso, 'info'); 
  END IF;
  
  SELECT PL.STARTTIME INTO vPipeStartTime
  FROM TCMP.CS_PLRUN PL
  WHERE PL.PIPELINERUNSEQ = v_max_post_pipelinerunseq
  ;
  
  BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
     
     ROLLBACK;
     
     CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en CARTERA_DDEE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
          || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
     
     RESIGNAL;
     
    END;
    
    UPDATE EXT.CARTERA_DDEE
       SET FECHA_POST = vPipeStartTime,
           SEQ_POST = v_max_post_pipelinerunseq 
       WHERE COMPENSATIONDATE = TO_DATE(vYYYYMM || '01','YYYYMMDD') AND FECHA_POST IS NULL
        AND IMPORTE <> 0 --Evitamos facturas vac�as
       ;
   
    v_num_rows := ::rowcount;
         
       CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en CARTERA_DDEE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
           
  END;
  
  UPDATE EXT.OUT_BATCH_CONTROL
  SET STATUS = :v_const_out_batch_control_ok
   , TARGET_ROWS = :v_num_rows
   , END_DATE = CURRENT_TIMESTAMP
  WHERE 1 = 1
   AND FILE_NAME = FILENAME
   -- AND ID_PROCESO = :v_idproceso
  ;
   
  CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE OUT_BATCH_CONTROL con estado OK', v_log_count, v_idproceso, 'info');
  
  
  CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin procedure SP_POST_DDEE', v_log_count, v_idproceso, 'info');
           
 END; 
END
