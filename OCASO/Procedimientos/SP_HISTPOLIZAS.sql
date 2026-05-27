CREATE PROCEDURE EXT.SP_HISTPOLIZAS (IN i_file_name varchar(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez
    | Company: Inycom
    | Initial Version Date: 21/03/2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se sube un fichero para historicos de POLIZAS a traves del CDL
    |
    | Version: 0.1  RMF 20250321    Initial Version.
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
		FROM EXT.PRESTAGE_HISTPOLIZAS;
		
		INSERT INTO EXT.IN_BATCH_CONTROL (ID_PROCESO, FILE_NAME, PROCEDURE_NAME, SOURCE_ROWS, STATUS, START_DATE)
		VALUES (v_id_proceso, i_file_name, proc_name, v_num_rows, :v_const_prestage_status_load, CURRENT_TIMESTAMP);
		
		INSERT INTO EXT.EJEC_HIST_CONTROL
		SELECT DISTINCT :v_id_proceso 
			, :i_file_name
			, HIST.FILE_NAME
		FROM EXT.PRESTAGE_HISTPOLIZAS HIST;
		
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
		DELETE FROM EXT.POLIZAS POL
		WHERE FILE_NAME IN (SELECT FILE_NAME_LP FROM :TBL_EJEC_HIST_CONTROL);
			
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin DELETE en POLIZAS. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		*/
		INSERT INTO EXT.POLIZAS
		SELECT -99999999 AS ID_RECIBO
			, HIST.FILE_NAME
			, :v_const_stage_status_ok
			, CURRENT_TIMESTAMP AS FECHA_MODIFICACION
			, HIST.CODIGO_POLIZA
			, HIST.RAMO
			, HIST.MOTIVO_ALTA
			, TO_DATE(HIST.FECHA_EFECTO_POLIZA,'DD/MM/YYYY')
			, TO_DATE(HIST.FECHA_EMISION_POLIZA,'DD/MM/YYYY')
			, TO_DATE(HIST.FECHA_CESION_POLIZA,'DD/MM/YYYY')
			, HIST.MOTIVO_BAJA
			, TO_DATE(HIST.FECHA_BAJA,'DD/MM/YYYY')
			, TO_DATE(HIST.FECHA_VENCIMIENTO,'DD/MM/YYYY')
			, TO_DATE(HIST.FECHA_REHABILITACION,'DD/MM/YYYY')
			, HIST.FORMA_PAGO
			, HIST.TIPO_CAMPANIA
			, HIST.SEGUNDA_RESIDENCIA
			, HIST.TARIFA
			, HIST.ZONA
			, HIST.CLAVE_RIESGO
			, HIST.MODALIDAD
			, HIST.DURACION
			, HIST.CLAUSULA
			, HIST.SUSTITUCION_INCENDIOS
			, HIST.EXCLUIDO_COMISIONES
			, HIST.TRASPASADA
			, TO_DECIMAL(REPLACE(HIST.DESCUENTO_IMPORTE_SINIESTRALID,',','.'),15,2)
			, TO_DECIMAL(REPLACE(HIST.DESCUENTO_POR_PRIORITARIO,',','.'),15,2)
			, HIST.RIESGO
			, HIST.COLECTIVO
			, HIST.AUTOLIQUIDA
			, TO_DECIMAL(REPLACE(HIST.KILOMETROS,',','.'),15,2)
			, HIST.MOVILIDAD
			, HIST.POLIZA_CON_AGENTE
			, HIST.AGENTE_CARTERA
			, TO_DECIMAL(REPLACE(HIST.IMP_COMISION_CARTERA,',','.'),15,2)
			, TO_DECIMAL(REPLACE(HIST.PORC_COMISION_CARTERA,',','.'),15,2)
			, TO_DATE(HIST.FECHA_FIN_COMISION_CARTERA,'DD/MM/YYYY')
		FROM EXT.PRESTAGE_HISTPOLIZAS HIST
		;
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en POLIZAS. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = :v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP WHERE FILE_NAME = i_file_name AND ID_PROCESO = v_id_proceso;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || i_file_name, v_log_count, v_id_proceso, 'info');
		
	END;
		
END
