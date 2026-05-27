CREATE PROCEDURE EXT.SP_POPULATE_REAJUSTES (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
 
/*---------------------------------------------------------------------
    | Author: Tania Garcés Villanueva 
    | Company: Inycom
    | Initial Version Date: 04-Febrero-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta una vez que entra un fichero de REAJUESTES e inserta las modificaciones oportunas en   GARANTIAS DE ASEGURADOS
    |			REAJUSTES ETERNA	REAJAFLFTP192402P
	|			REAJUSTES OCASO		REAJOFLFTP192302P
	|
	| Version: 0.1	TGV 20250203		Initial Version.
	|
    -----------------------------------------------------------------------
*/
 
BEGIN
	USING SQLSCRIPT_STRING AS LIBRARY;
--	DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
--	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();

	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK; --1
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR; --3
	DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK; --2
	DECLARE v_const_populate_status_error INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_ERROR; --4
	
	DECLARE v_const_recibos_especificos_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
	DECLARE v_const_recibos_especificos_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
	DECLARE v_const_recibos_especificos_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
	DECLARE v_const_ramo_rrtt VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRTT;
	DECLARE v_const_ramo_rrgg VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRGG;
	DECLARE v_const_ramo_rrpp VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRPP;
	DECLARE v_const_cod_suplemento_defecto INTEGER := EXT.LIB_CONSTANTES:CONST_COD_SUPLEMENTO_DEFECTO;
 
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
		
			ROLLBACK;
		
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
			--v_hayError := 1;
			v_num_rows := 0;
			
			--Se obtiene la cuenta del fichero
			SELECT COUNT(*) INTO v_num_rows
			FROM EXT.STAGE_RECIBOS
			WHERE FILE_NAME = i_file_name
				AND ESTADO = v_const_stage_status_ok;
			
			--Se actualizan los campos de la in_batch_control para indicar el error
			UPDATE EXT.IN_BATCH_CONTROL
			SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = i_id_proceso;
			
			--Se actualizan los registros de STAGE_RECIBOS con estado erróneo
			UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ESTADO = v_const_stage_status_ok;	
			
			COMMIT;

			--Captura el error y lo envía a xDL
			RESIGNAL;
		END;

	BEGIN
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, i_log_count, i_id_proceso, 'info');
		
		
		--Obtenemos los datos de la tablas de STAGE_ASEGURADOS para el fichero que estamos tratando y lo metemos en una tabla temporal.
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos la variable tabla con los reajustes que debemos actualizar', i_log_count, i_id_proceso, 'info');
		TBL_REAJUSTE_STAGE =
				SELECT 
					IDENTIFICADOR,
					FILE_NAME,
					ESTADO,
					FECHA_MODIFICACION,
					CODIGO_POLIZA,
					NUMERO_ASEGURADO,
					PRODUCTO_CONTABLE,
					PRIMA_NETA_ASEGURADO,
					CAPITAL_NATURAL,
					CAPITAL_NIVELADO,
					FECHA_BAJA_GAR_ASE,
					FECHA_EFECTO_SUPLEMENTO,
					NUM_ORDEN_MOVIMIENTO
				
					FROM EXT.STAGE_REAJUSTES
					WHERE FILE_NAME = i_file_name;
		v_num_rows := ::rowcount;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla TBL_REAJUSTE_STAGE Filas - '|| v_num_rows, i_log_count, i_id_proceso, 'info');
				
		--HISTORIFICAMOS LOS REGISTROS ANTES DE REALIZAR EL UPDATE DEL REAJUSTE
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Historificamos las garantias de asegurados que vamos a actualizar con el reajuste', i_log_count, i_id_proceso, 'info');
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE  en EXT.RECIBOS para ES_PERMANENCIA_20 --> NO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
				--v_hayError := 1;
				--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
				
				--Se actualizan los registros de POLIZAS con estado erróneo
				UPDATE EXT.GARANTIAS_ASEGURADO REC
					SET ESTADO = v_const_populate_status_error,
						FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_ASEGURADO REC, :TBL_REAJUSTE_STAGE src
				WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
				;
				
				COMMIT;
				RESIGNAL;

			END;
			INSERT INTO EXT.GARANTIAS_ASEGURADO_HIST
				SELECT i_id_proceso, GA.* 
				FROM EXT.GARANTIAS_ASEGURADO GA
				INNER JOIN :TBL_REAJUSTE_STAGE TBL_REAJ
					ON GA.CODIGO_POLIZA = TBL_REAJ.CODIGO_POLIZA
				    AND GA.NUMERO_ASEGURADO = TBL_REAJ.NUMERO_ASEGURADO
				    AND GA.PRODUCTO_CONTABLE = TBL_REAJ.PRODUCTO_CONTABLE
				    AND GA.NUM_ORDEN_MOVIMIENTO =  (SELECT MIN(NUM_ORDEN_MOVIMIENTO)
		                                            FROM EXT.GARANTIAS_ASEGURADO XA
		                                            WHERE XA.CODIGO_POLIZA = TBL_REAJ.CODIGO_POLIZA
		                                                AND XA.NUMERO_ASEGURADO = TBL_REAJ.NUMERO_ASEGURADO
		                                                AND XA.PRODUCTO_CONTABLE = TBL_REAJ.PRODUCTO_CONTABLE)
				WHERE TBL_REAJ.FILE_NAME = i_file_name
					AND TBL_REAJ.ESTADO = v_const_stage_status_ok
				;
				
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'INSERT GARANTIAS_ASEGURADO_HIST Filas - '|| v_num_rows, i_log_count, i_id_proceso, 'info');
			END;
		
		-- ACTUALIZAMOS LA TABLA DE GARANTIAS_ASEGURADOS LOS QUE COINCIDAN CON LO QUE NOS HA VENIDO EN EL FICHERO
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Actualizamos la tabla de Garantias de Asegurado con los que viene en los reajustes', i_log_count, i_id_proceso, 'info');
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE  en EXT.RECIBOS para ES_PERMANENCIA_20 --> NO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
				--v_hayError := 1;
				--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
				
				--Se actualizan los registros de POLIZAS con estado erróneo
				UPDATE EXT.GARANTIAS_ASEGURADO REC
					SET ESTADO = v_const_populate_status_error,
						FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_ASEGURADO REC, :TBL_REAJUSTE_STAGE src
				WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
				;
				
				COMMIT;
				RESIGNAL;

			END;
			
			MERGE INTO EXT.GARANTIAS_ASEGURADO GA
			USING (
				SELECT 	IDENTIFICADOR,
						FILE_NAME,
						ESTADO,
						FECHA_MODIFICACION,
						CODIGO_POLIZA,
						NUMERO_ASEGURADO,
						PRODUCTO_CONTABLE,
						PRIMA_NETA_ASEGURADO,
						CAPITAL_NATURAL,
						CAPITAL_NIVELADO,
						FECHA_BAJA_GAR_ASE,
						FECHA_EFECTO_SUPLEMENTO,
						NUM_ORDEN_MOVIMIENTO
						FROM :TBL_REAJUSTE_STAGE
			) X
			ON (GA.CODIGO_POLIZA = X.CODIGO_POLIZA
			    AND GA.NUMERO_ASEGURADO = X.NUMERO_ASEGURADO
			    AND GA.PRODUCTO_CONTABLE = X.PRODUCTO_CONTABLE
			    --AND GA.NUM_ORDEN_MOVIMIENTO = X.NUM_ORDEN_MOVIMIENTO
			    AND GA.NUM_ORDEN_MOVIMIENTO = (SELECT MIN(NUM_ORDEN_MOVIMIENTO)
                                            FROM EXT.GARANTIAS_ASEGURADO XA
                                            WHERE XA.CODIGO_POLIZA = X.CODIGO_POLIZA
                                                AND XA.NUMERO_ASEGURADO = X.NUMERO_ASEGURADO
                                                AND XA.PRODUCTO_CONTABLE = X.PRODUCTO_CONTABLE)
			    --AND GA.CODIGO_RECIBO = X.CODIGO_RECIBO
			) 	WHEN MATCHED THEN
				UPDATE SET
					GA.ID_REAJUSTE  = X.IDENTIFICADOR,
				    GA.PRIMA_NETA_ASEGURADO = X.PRIMA_NETA_ASEGURADO,
				    GA.CAPITAL_NATURAL = X.CAPITAL_NATURAL,
				    GA.CAPITAL_NIVELADO = X.CAPITAL_NIVELADO,
				    GA.FECHA_BAJA_GAR_ASE = X.FECHA_BAJA_GAR_ASE,
				    GA.NUM_ORDEN_MOVIMIENTO = X.NUM_ORDEN_MOVIMIENTO,
				    GA.FILE_NAME = X.FILE_NAME,
				    GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
					
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'MERGE GARANTIAS_ASEGURADO Filas - '|| v_num_rows, i_log_count, i_id_proceso, 'info');
		END;
		
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - End Procedure  for ' || i_file_name, i_log_count, i_id_proceso, 'info');
	END;
 
 
END
