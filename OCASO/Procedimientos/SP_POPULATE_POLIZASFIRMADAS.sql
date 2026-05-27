CREATE PROCEDURE EXT.SP_POPULATE_POLIZASFIRMADAS (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Jorge Gracia Estaun 
    | Company: Inycom
    | Initial Version Date: 05-Febrero-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta una vez que entra un fichero de POLIZAS FIRMADAS y actualiza estado en la tabla recibos de las polizas que vengan en el fichero
	|
	| Version: 0.1	JGE 20250205		Initial Version.
	|
    -----------------------------------------------------------------------
*/

BEGIN
	DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	
	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR;
	DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK;
	DECLARE v_const_populate_status_error INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_ERROR;
	
	DECLARE CONST_COBROS_SOLNET_OCASO VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_COBROS_SOLNET_OCASO;
	DECLARE CONST_RECIBO_COBRADO VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
	DECLARE CONST_RECIBO_EMITIDO VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EMITIDO;
	DECLARE CONST_RECIBO_PENDIENTE VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_PENDIENTE;
	DECLARE CONST_RECIBO_COBRADO_SINFIRMAR VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO_SINFIRMAR;
	DECLARE CONST_RECIBO_EMITIDO_SINFIRMAR VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EMITIDO_SINFIRMAR;
	DECLARE CONST_RECIBO_PENDIENTE_SINFIRMAR VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_PENDIENTE_SINFIRMAR;

	
	--variable para buscar los cobrados del mes anterior (los cobrados de un mes llevan la compensationdate del mes siguiente)
	DECLARE v_mesActual NVARCHAR(6); 

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
		
	--Inicializamos el idProceso
	-- SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, i_id_proceso, 'info');
	
	v_mesActual := substr(:i_file_name,13,6);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'FECHA DE COMPENSACION: ' || v_mesActual, i_log_count, i_id_proceso, 'info');
	
	
	TBL_POL_FIRMADAS = (
		SELECT SR.CODIGO_POLIZA
		FROM EXT.STAGE_RECIBOS SR
		WHERE SR.FILE_NAME = i_file_name	
	);
	v_num_rows = RECORD_COUNT(:TBL_POL_FIRMADAS);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_POL_FIRMADAS ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	--Actualizamos estados dependiendo de las polizas que no lleguen en el fichero
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
			
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE para bajas - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
				
				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado erróneo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ESTADO = v_const_stage_status_ok;	
			END;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO ACTUALIZAR POLIZAS FIRMADAS ',v_log_count, i_id_proceso, 'info');
		--UPDATE RECIBOS
		UPDATE EXT.RECIBOS R
        SET R.ESTADO_RECIBO = (CASE WHEN R.ESTADO_RECIBO = CONST_RECIBO_COBRADO_SINFIRMAR THEN CONST_RECIBO_COBRADO
                              WHEN (R.ESTADO_RECIBO IN (CONST_RECIBO_PENDIENTE_SINFIRMAR,CONST_RECIBO_EMITIDO_SINFIRMAR) AND R.FILE_NAME LIKE '%'||CONST_COBROS_SOLNET_OCASO||'%') THEN CONST_RECIBO_PENDIENTE
                              WHEN R.ESTADO_RECIBO = CONST_RECIBO_EMITIDO_SINFIRMAR THEN CONST_RECIBO_EMITIDO
                              ELSE R.ESTADO_RECIBO 
                              END)
		WHERE SUBSTR(R.CODIGO_POLIZA,1,23) IN (
			SELECT (SUBSTR(CODIGO_POLIZA,1,5)||'00'||SUBSTR(CODIGO_POLIZA,8))
			FROM :TBL_POL_FIRMADAS
		)
		AND R.ESTADO_RECIBO NOT IN ('C','P','E')
        --JGE Nos aseguramos de que no existan registros previos firmados para no duplicar registros
		AND NOT EXISTS (SELECT 1 FROM EXT.RECIBOS T 
                    WHERE T.CODIGO_POLIZA = R.CODIGO_POLIZA
                    AND T.CODIGO_RECIBO = R.CODIGO_RECIBO
                    AND T.CODIGO_SUPLEMENTO = R.CODIGO_SUPLEMENTO
                    AND T.ESTADO_RECIBO = (CASE WHEN R.ESTADO_RECIBO = CONST_RECIBO_COBRADO_SINFIRMAR THEN CONST_RECIBO_COBRADO
			                              WHEN (R.ESTADO_RECIBO IN (CONST_RECIBO_PENDIENTE_SINFIRMAR,CONST_RECIBO_EMITIDO_SINFIRMAR) AND R.FILE_NAME LIKE '%'||CONST_COBROS_SOLNET_OCASO||'%') THEN CONST_RECIBO_PENDIENTE
			                              WHEN R.ESTADO_RECIBO = CONST_RECIBO_EMITIDO_SINFIRMAR THEN CONST_RECIBO_EMITIDO
			                              ELSE R.ESTADO_RECIBO 
			                              END)
                );
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'FIN ACTUALIZAR POLIZAS FIRMADAS ' || v_num_rows , v_log_count, i_id_proceso, 'info');

		--Funcionalidad DDEE
		UPDATE EXT.CARTERA_DDEE CAR
            SET CAR.ESTADO = 
                (CASE 
                    WHEN CAR.ESTADO = CONST_RECIBO_COBRADO_SINFIRMAR THEN CONST_RECIBO_COBRADO
                    WHEN (CAR.ESTADO IN (CONST_RECIBO_PENDIENTE_SINFIRMAR,CONST_RECIBO_EMITIDO_SINFIRMAR) AND CAR.FILE_NAME LIKE '%'||CONST_COBROS_SOLNET_OCASO||'%') THEN CONST_RECIBO_PENDIENTE
                    WHEN CAR.ESTADO =  CONST_RECIBO_EMITIDO_SINFIRMAR THEN CONST_RECIBO_EMITIDO 
                    ELSE CAR.ESTADO
                END)
        WHERE SUBSTR(CAR.ORDERID,1,5)||'00'|| SUBSTR(CAR.ORDERID,8,16) IN
        (
        	SELECT (SUBSTR(POLIZA_FIRMADA.CODIGO_POLIZA,1,5)||'00'||SUBSTR(POLIZA_FIRMADA.CODIGO_POLIZA,8,16))
        	FROM :TBL_POL_FIRMADAS POLIZA_FIRMADA
        	)
        AND CAR.ESTADO NOT IN ('C','P','E','X'); 
        
        v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'FIN ACTUALIZAR DDEE ' || v_num_rows , v_log_count, i_id_proceso, 'info');

	END;
	
	
	--Se actualizan las transacciones N (procedentes del cobrado del mes pasado y duplicadas para este mes) con el estado N o C 
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE para bajas - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado erróneo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ESTADO = v_const_stage_status_ok;
				
			END;
	
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO Actualizar tabla TRANSACTIONASSIGN',v_log_count, i_id_proceso, 'info');
		--UPDATE TRANSACTIONASSIGN 
		UPDATE EXT.TRANSACTIONASSIGN TA SET TA.BATCHNAME = 'POLIZAS_SIN_FIRMAR_'||v_mesActual||'01'
	    WHERE (TA.ORDERID,TA.LINENUMBER,TA.SUBLINENUMBER,TA.EVENTTYPEID) IN
	        (SELECT ST.ORDERID,ST.LINENUMBER,ST.SUBLINENUMBER,ST.EVENTTYPEID 
	        FROM EXT.SALESTRANSACTION ST
	        WHERE ST.COMPENSATIONDATE = TO_DATE(v_mesActual||'01', 'YYYYMMDD') AND ST.GENERICATTRIBUTE6 = 'N' AND ST.FILE_IN_RECIBOS LIKE '%'||CONST_COBROS_SOLNET_OCASO||'%'
	        )
	    ;
	    
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'FIN Actualizar tabla TRANSACTIONASSIGN' || v_num_rows, v_log_count, i_id_proceso, 'info');
		

		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO Actualizar tabla SALESTRANSACTION', v_log_count, i_id_proceso, 'info');
		--UPDATE SALESTRANSACTION
	    UPDATE EXT.SALESTRANSACTION STR SET STR.BATCHNAME = 'POLIZAS_SIN_FIRMAR_'||v_mesActual||'01', 
	        STR.GENERICATTRIBUTE6 = IFNULL((
	            SELECT COALESCE(MAX(RE.ESTADO_RECIBO),STR.GENERICATTRIBUTE6)
	            FROM EXT.RECIBOS RE
	            WHERE RE.CODIGO_POLIZA = (CASE WHEN SUBSTR(STR.ORDERID,1,1) = '0' 
                    THEN SUBSTR(STR.ORDERID,1,3)||'0100'|| trim(SUBSTR(STR.ORDERID,8,17)) --|| '00000' 
                    ELSE '0'||SUBSTR(STR.ORDERID,1,2)||'0100'|| trim(SUBSTR(STR.ORDERID,7,17)) --|| '00000' 
                    END)
	            AND RE.CODIGO_RECIBO = SUBSTR(STR.SUBLINENUMBER,1,11)
	            AND RE.FILE_NAME LIKE '%'||CONST_COBROS_SOLNET_OCASO||'%'
	            ), STR.GENERICATTRIBUTE6)
	    WHERE (STR.ORDERID,STR.LINENUMBER,STR.SUBLINENUMBER,STR.EVENTTYPEID) IN
	        (SELECT ST.ORDERID,ST.LINENUMBER,ST.SUBLINENUMBER,ST.EVENTTYPEID 
	        FROM EXT.SALESTRANSACTION ST
	        WHERE ST.COMPENSATIONDATE = TO_DATE(v_mesActual||'01', 'YYYYMMDD') AND ST.GENERICATTRIBUTE6 = 'N' AND ST.FILE_IN_RECIBOS LIKE '%'||CONST_COBROS_SOLNET_OCASO||'%'
	        )
	    ;
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'FIN Actualizar tabla SALESTRANSACTION' || v_num_rows, v_log_count, i_id_proceso, 'info');
		
	    COMMIT; 
	END;
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO ACTUALIZAR ESTADO DE IN_BATCH PARA ' || i_file_name, v_log_count, i_id_proceso, 'info');

		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = :v_const_populate_status_ok WHERE FILE_NAME = i_file_name;
		
		v_num_rows := ::rowcount;
	    
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'FIN ACTUALIZAR IN_BATCH' || v_num_rows , v_log_count, i_id_proceso, 'info');
END
