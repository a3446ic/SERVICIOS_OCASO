CREATE PROCEDURE EXT.SP_HIST_STAGERECIBOS (IN i_file_name varchar(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez
    | Company: Inycom
    | Initial Version Date: 24/03/2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se sube un fichero para historicos de STAGE_RECIBOS a traves del CDL
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
		FROM EXT.PRESTAGE_HIST_STAGERECIBOS;
		
		INSERT INTO EXT.IN_BATCH_CONTROL (ID_PROCESO, FILE_NAME, PROCEDURE_NAME, SOURCE_ROWS, STATUS, START_DATE)
		VALUES (v_id_proceso, i_file_name, proc_name, v_num_rows, :v_const_prestage_status_load, CURRENT_TIMESTAMP);
		
		INSERT INTO EXT.EJEC_HIST_CONTROL
		SELECT DISTINCT :v_id_proceso 
			, :i_file_name
			, HIST.FILE_NAME
		FROM EXT.PRESTAGE_HIST_STAGERECIBOS HIST;
		
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
		DELETE FROM EXT.STAGE_RECIBOS REC
		WHERE FILE_NAME IN (SELECT FILE_NAME_LP FROM :TBL_EJEC_HIST_CONTROL);
			
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin DELETE en STAGE_RECIBOS. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		*/
		INSERT INTO EXT.STAGE_RECIBOS
		SELECT HIST.FILE_NAME
				, TO_INTEGER(HIST.STATUS)
				, CURRENT_TIMESTAMP
				, HIST.RAMO
				, HIST.CODIGOPOLIZA
				, HIST.MOTIVOALTA
				, TO_DATE(HIST.FECHAEFECTOPOLIZA,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHAEMISIONPOLIZA,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHACESIONPOLIZA,'YYYY-MM-DD')
				, HIST.MOTIVOBAJA
				, TO_DATE(HIST.FECHABAJA,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHAEFECTOSUPLEMENTO,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHAVENCIMIENTO,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHAREHABILITACION,'YYYY-MM-DD')
				, HIST.FORMAPAGO
				, HIST.TIPOCAMPANIA
				, HIST.CODIGOAGENTEORIGINAL
				, HIST.CODIGOUNICOAGENTE
				, HIST.INSPECTOR
				, HIST.OFICINACOBRADORA
				, HIST.OFICINAGESTORA
				, HIST.SEGUNDARESIDENCIA
				, HIST.TARIFA
				, HIST.ZONA
				, HIST.CLAVERIESGO
				, HIST.CODIGOSUPLEMENTO
				, HIST.DISTRITOCOBRO
				, HIST.MODALIDAD
				, HIST.DURACION
				, TO_DECIMAL(REPLACE(HIST.INDCOMICALCULADA,',','.'),25,4)
				, TO_DECIMAL(REPLACE(HIST.INDPORCALCULADO,',','.'),25,4)
				, TO_DECIMAL(REPLACE(HIST.PORCOMICALCULADA,',','.'),25,4)
				, TO_DECIMAL(REPLACE(HIST.IMPORTE_COMISION,',','.'),25,4)
				, HIST.CLAUSULA
				, HIST.AUMENTOCAPITALESGAR
				, HIST.SUSTITUCION_INCENDIOS
				, HIST.CODIGOSINIESTRO
				, HIST.EXCLUIDOCOMISIONES
				, HIST.TRASPASADA
				, TO_DECIMAL(REPLACE(HIST.INCREPRIMAANUAL,',','.'),25,4)
				, TO_DECIMAL(REPLACE(HIST.DTOIMPTSINIESTRALIDAD,',','.'),25,4)
				, TO_DECIMAL(REPLACE(HIST.DTOPORPRIORITARIO,',','.'),25,4)
				, HIST.RIESGO
				, HIST.COLECTIVO
				, HIST.AUTOLIQUIDA
				, HIST.KILOMETROS
				, HIST.PRIMERRECIBO
				, HIST.CODIGORECIBO
				, HIST.PERMANENCIA
				, HIST.TIPORECIBO
				, HIST.ESTADORECIBO
				, TO_DATE(HIST.FECHACOBRO,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHAEFECTORECIBO,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHAVENCIMIENTORECIBO,'YYYY-MM-DD')
				, HIST.TIPOMOVIMIENTO
				, TO_DECIMAL(REPLACE(HIST.PORCDESTOSOBREPC,',','.'),25,4)
				, HIST.VALORPOLIZA
				, HIST.MARCARECUPERADO
				, HIST.PRODUCTOCONTABLE
				, TO_DATE(HIST.FECHAALTAGARPOL,'YYYY-MM-DD')
				, TO_DATE(HIST.FECHABAJAGARPOL,'YYYY-MM-DD')
				, TO_DECIMAL(REPLACE(HIST.PRIMANETARECIBO,',','.'),25,4)
				, TO_DECIMAL(REPLACE(HIST.PRIMABRUTARECIBO,',','.'),25,4)
				, HIST.RECARGO
				, TO_DECIMAL(REPLACE(HIST.PORCENTAJEBONIFICACION,',','.'),25,4)
				, HIST.POLIZACONAGENTE
				, HIST.MOVILIDAD
				, HIST.PRIMAUNICA
				, TO_INTEGER(HIST.NUMORDENMOVIMIENTO)
				, TO_DATE(HIST.FECHA_EMISION_REC,'YYYY-MM-DD')
				, HIST.CARGO_COMPENSACION
				, HIST.ZONA_EXPLOTACION
				, HIST.CODIGO_AGENTE_ZONA
		FROM EXT.PRESTAGE_HIST_STAGERECIBOS HIST
		;
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en STAGE_RECIBOS. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = :v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP WHERE FILE_NAME = i_file_name AND ID_PROCESO = v_id_proceso;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || i_file_name, v_log_count, v_id_proceso, 'info');
		
	END;
		
END
