CREATE OR REPLACE PROCEDURE EXT.SP_CREAR_TABLAS_ALL ( OUT o_file_name VARCHAR(120), IN iPipelineRunSeq BIGINT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez 
    | Company: Inycom
    | Initial Version Date: 16-Mayo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento para la recarga de tablas de informes. 
    | El procedimiento funciona desde una llamada de DataExtract, generando dos
	| parámetros, fecha para la que se quiere lanzar el procedimiento e informes a recalcular (ALL en este caso)
	|
	| Version: 	0.1	RMF 20250516	Initial Version.
	|  			0.2 BRG	20260416	Añadido i_tipo a NULL en la llamada a SP_CREAR_TABLAS
	|
    -----------------------------------------------------------------------
*/

BEGIN

	USING SQLSCRIPT_STRING AS LIBRARY;
	
	--VARIABLES DE USO GENERAL
	DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.2';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_periodSeq BIGINT := 0;
	
	--VARIABLES DE ESTADO
	DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
	DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
	DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
		
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																												
			v_num_rows := 0;
		
			UPDATE EXT.OUT_BATCH_CONTROL
			SET STATUS = :v_const_out_batch_control_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = :o_file_name
				AND ID_PROCESO = :v_idproceso;
			
			COMMIT;	
			
			RESIGNAL;
		
		END;
	
	BEGIN
	
		--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting ...', v_log_count, v_idproceso, 'info');
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Parámetros de entrada -> iPipelineRunSeq: ' || iPipelineRunSeq, v_log_count, v_idproceso, 'info');
		
		--Nombre de fichero de salida
		o_file_name = 'OUT_CREAR_TABLAS_ALL_'||TO_VARCHAR(CURRENT_TIMESTAMP,'YYYYMMDD_HH24MISS')||'.txt';
		
		--Insertar registro en OUT_BATCH_CONTROL
		INSERT INTO EXT.OUT_BATCH_CONTROL (ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_idproceso, o_file_name, proc_name, 0, v_const_out_batch_control_load, CURRENT_TIMESTAMP, NULL);
		
		COMMIT;
		
		--Obtener periodSeq a partir del iPipelineRunseq
		CALL LIB_GLOBAL:getPeriodSeqFromPlrunseq(v_idtenant, iPipelineRunSeq, v_periodSeq);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'periodSeq: ' || v_periodSeq, v_log_count, v_idproceso, 'info');
		
		--Llamar al procedimiento con la lógica de informes
		CALL EXT.SP_CREAR_TABLAS(v_periodseq, 'ALL', v_idproceso, NULL, v_log_count);
		
		--Actualizar el registro en OUT_BATCH_CONTROL
		UPDATE EXT.OUT_BATCH_CONTROL
		SET STATUS = :v_const_out_batch_control_ok
			, END_DATE = CURRENT_TIMESTAMP
		WHERE ID_PROCESO = :v_idproceso
			AND FILE_NAME = :o_file_name
		;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE OUT_BATCH_CONTROL con estado OK', v_log_count, v_idproceso, 'info');
	
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin procedure ' || proc_name, v_log_count, v_idproceso, 'info');
		
	END;
END
