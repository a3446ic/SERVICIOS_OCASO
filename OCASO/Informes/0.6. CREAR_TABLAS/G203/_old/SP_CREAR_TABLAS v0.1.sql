CREATE PROCEDURE EXT.SP_CREAR_TABLAS (IN i_PeriodSeq BIGINT, IN i_lista_informes VARCHAR(5000), IN i_id_proceso BIGINT, IN i_log_count INTEGER)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez 
    | Company: Inycom
    | Initial Version Date: 16-Mayo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento para la recarga de tablas de informes. 
    | El procedimiento funciona desde un interfaz de salida de xDL, pasando la fecha en formato YYYYMMDD y el listado de informes a ejecutar
    |
	|
	| Version: 0.1	RMF 20250516	Initial Version.
	|
    -----------------------------------------------------------------------
*/

BEGIN

	USING SQLSCRIPT_STRING AS LIBRARY;
	
	--VARIABLES DE USO GENERAL
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
		
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
																												
			v_num_rows := 0;
		
			RESIGNAL;
		
		END;
	
	BEGIN
	
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting ...', i_log_count, i_id_proceso, 'info');
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Parámetros de entrada -> i_periodSeq: ' || i_PeriodSeq || ' | i_listado_informes: ' || i_lista_informes, i_log_count, i_id_proceso, 'info');
		
		--LOGICA CREAR_TABLAS
		
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin procedure ' || proc_name, i_log_count, i_id_proceso, 'info');
		
	END;
END