CREATE PROCEDURE EXT.SP_STAGE_RECI_COB_EA_SERCO_RRTT (IN i_file_name varchar(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Diego Teijo Barral
    | Company: Inycom
    | Initial Version Date: 23-Enero-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se sube un fichero para RECIBOS COBRADO DE RRTT ETERNA SERCO a traves del CDL, 
    | y que mueve los datos de la tabla PRESTAGE_RECI_COB_EA_SERCO_RRTT a STAGE_RECIBOS
	|
	| Version: 0.1	DTB 20250123	Initial Version.
	|
    -----------------------------------------------------------------------
*/

BEGIN
	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	
	
	DECLARE v_const_prestage_status_load INT = EXT.LIB_CONSTANTES:CONST_PRESTAGE_STATUS_LOAD; --0
	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK; --1
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR; --3

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			--v_hayError := 1;
			num_rows := 0;
		
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_stage_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
			COMMIT;	
			RESIGNAL;
		END;
	
	
	BEGIN
		
		--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_idproceso, 'info');
		
		--Insertamos un registro en la tabla IN_BATCH_CONTROL en estado 0.
		INSERT INTO EXT.IN_BATCH_CONTROL (ID_PROCESO, FILE_NAME, PROCEDURE_NAME, SOURCE_ROWS, STATUS, START_DATE)
		VALUES (v_idproceso, i_file_name, proc_name, 0, v_const_prestage_status_load, CURRENT_TIMESTAMP);
		
		COMMIT;
		--Llamamos a la libreria global para realizar la insercion a la stage_recibos
		CALL ext.lib_global:SP_insertaStageSerco (v_permisos_log, proc_name , 'EXT.PRESTAGE_RECI_COB_EA_SERCO_RRTT', i_file_name ,v_log_count, v_idproceso);
		
		--Actualizamos la IN_BATCH_CONTROL y ponemos el estado a 1
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP WHERE FILE_NAME = i_file_name AND ID_PROCESO = v_idproceso;
	
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name, 'Llamada a SP_POPULATE_SERCO para ' || i_file_name, v_log_count, v_idproceso, 'info');
		
		CALL EXT.SP_POPULATE_SERCO(i_file_name,v_idproceso, v_log_count);

	CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || i_file_name, v_log_count, v_idproceso, 'info');
	END;


END
