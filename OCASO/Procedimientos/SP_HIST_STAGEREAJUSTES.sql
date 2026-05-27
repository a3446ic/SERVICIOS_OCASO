CREATE PROCEDURE EXT.SP_HIST_STAGEREAJUSTES (IN i_file_name varchar(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez
    | Company: Inycom
    | Initial Version Date: 24/03/2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se sube un fichero para historicos de STAGE_REAJUSTES a traves del CDL
    |
    | Version: 0.1  RMF 20250324    Initial Version.
    |
    -----------------------------------------------------------------------
*/

BEGIN
	
	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE v_id_proceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_const_prestage_status_load INT = EXT.LIB_CONSTANTES:CONST_PRESTAGE_STATUS_LOAD; --0
	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK; --1
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR; --3
	
	BEGIN
	
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_id_proceso, 'error');
			--v_hayError := 1;
			v_num_rows := 0;
		
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_stage_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_id_proceso;
			
			COMMIT;
			
			RESIGNAL;
		END;
	
	--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_id_proceso FROM DUMMY;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_id_proceso, 'info');
	
		SELECT COUNT(*) INTO v_num_rows
		FROM EXT.PRESTAGE_HIST_STAGEREAJUSTES;
		
		INSERT INTO EXT.IN_BATCH_CONTROL (ID_PROCESO, FILE_NAME, PROCEDURE_NAME, SOURCE_ROWS, STATUS, START_DATE)
		VALUES (v_id_proceso, i_file_name, proc_name, v_num_rows, :v_const_prestage_status_load, CURRENT_TIMESTAMP);
		
		INSERT INTO EXT.EJEC_HIST_CONTROL
		SELECT DISTINCT :v_id_proceso 
			, :i_file_name
			, HIST.FILE_NAME
		FROM EXT.PRESTAGE_HIST_STAGEREAJUSTES HIST;
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en EJEC_HIST_CONTROL. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
		TBL_EJEC_HIST_CONTROL = SELECT TBL.FILE_NAME_EXTRACCION
									, TBL.FILE_NAME_LP
								FROM EXT.EJEC_HIST_CONTROL TBL
								WHERE ID_PROCESO = :v_id_proceso
								;
		
		v_num_rows = RECORD_COUNT(:TBL_EJEC_HIST_CONTROL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_EJEC_HIST_CONTROL creada. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		/*	
		DELETE FROM EXT.STAGE_REAJUSTES REC
		WHERE FILE_NAME IN (SELECT FILE_NAME_LP FROM :TBL_EJEC_HIST_CONTROL);
			
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin DELETE en STAGE_REAJUSTES. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		*/
		INSERT INTO EXT.STAGE_REAJUSTES
		SELECT HIST.FILE_NAME
				, TO_INTEGER(HIST.STATUS)
				, CURRENT_TIMESTAMP
				, HIST.CODIGO_POLIZA
				, HIST.NUMERO_ASEGURADO
				, HIST.PRODUCTO_CONTABLE
				, HIST.PRIMA_NETA_ASEGURADO
				, HIST.CAPITAL_NATURAL
				, HIST.CAPITAL_NIVELADO
				, TO_DATE(HIST.FECHA_BAJA_GAR_ASE,'DD/MM/YYYY')
				, TO_DATE(HIST.FECHA_EFECTO_SUPLEMENTO,'DD/MM/YYYY')
				, HIST.NUM_ORDEN_MOVIMIENTO
		FROM EXT.PRESTAGE_HIST_STAGEREAJUSTES HIST
		;
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en STAGE_REAJUSTES. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = :v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP WHERE FILE_NAME = i_file_name AND ID_PROCESO = v_id_proceso;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || i_file_name, v_log_count, v_id_proceso, 'info');
		
	END;
		
END
