CREATE LIBRARY "EXT"."LIB_ERRORES" LANGUAGE SQLSCRIPT AS
BEGIN
  PUBLIC PROCEDURE SP_validarRecibos (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR;
		DECLARE v_sql_statement_fecha NVARCHAR(5000);
		DECLARE v_sql_statement_fecha_delete NVARCHAR(5000);
		DECLARE v_sql_statement_numero NVARCHAR(5000);
		DECLARE v_sql_statement_numero_delete NVARCHAR(5000);
		DECLARE v_num_rows INTEGER := 0;
		
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_validarRecibos: Revisad el insert dinamico'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
		  
	CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS FECHAS VALIDAS ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
		/*v_sql_statement_fecha := 
		'INSERT INTO EXT.PRESTAGE_RECIBOS_ERROR ' ||
		 'SELECT ''' ||
		 :i_id_proceso || ''',''' ||
		 :i_file_name || ''',' ||
		 'CURRENT_TIMESTAMP, ''Fecha no valida'', STG.* '|| 
		 'FROM '|| :i_tabla ||' STG WHERE '||
				'LENGTH(LTRIM(FECHA_EFECTO_POLIZA, ''0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(FECHA_EMISION_POLIZA, ''0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(FECHA_CESION_POLIZA, ''0123456789'')) != 0 AND FECHA_CESION_POLIZA IS NOT NULL) OR  ' ||
				'(LENGTH(LTRIM(FECHA_BAJA, ''0123456789'')) != 0 AND FECHA_BAJA IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(FECHA_EFECTO_SUPLEMENTO, ''0123456789'')) != 0 AND FECHA_EFECTO_SUPLEMENTO IS NOT NULL) OR ' ||
				'LENGTH(LTRIM(FECHA_VENCIMIENTO, ''0123456789'')) != 0 OR ' ||
				'(LENGTH(LTRIM(FECHA_REHABILITACION, ''0123456789'')) != 0 AND FECHA_REHABILITACION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(FECHA_COBRO, ''0123456789'')) != 0 AND FECHA_COBRO IS NOT NULL) OR ' ||
				'LENGTH(LTRIM(FECHA_EFECTO_RECIBO, ''0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(FECHA_VENCIMIENTO_RECIBO, ''0123456789'')) != 0 OR ' ||
				'(LENGTH(LTRIM(FECHA_ALTA_GAR_POL, ''0123456789'')) != 0 AND FECHA_ALTA_GAR_POL IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(FECHA_BAJA_GAR_POL, ''0123456789'')) != 0 AND FECHA_BAJA_GAR_POL IS NOT NULL) OR ' ||
				'LENGTH(LTRIM(FECHA_EMISION_REC, ''0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(CARGO_COMPENSACION, ''0123456789'')) != 0  ' ;
		*/
		--Version con LIKE_REGEXPR
		v_sql_statement_fecha := 
		'INSERT INTO EXT.PRESTAGE_RECIBOS_ERROR ' ||
		 'SELECT ''' ||
		 :i_id_proceso || ''',''' ||
		 :i_file_name || ''',' ||
		 'CURRENT_TIMESTAMP, ''Fecha no valida'', STG.* '|| 
		 'FROM '|| :i_tabla ||' STG WHERE '||
				'FECHA_EFECTO_POLIZA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' || --'(LENGTH(LTRIM(FECHA_EFECTO_POLIZA, ''0123456789'')) != 0 OR LENGTH(FECHA_EFECTO_POLIZA) != 8) OR ' ||
				'FECHA_EMISION_POLIZA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' || --'(LENGTH(LTRIM(FECHA_EMISION_POLIZA, ''0123456789'')) != 0 OR LENGTH(FECHA_EMISION_POLIZA) != 8) OR ' ||
				'(FECHA_CESION_POLIZA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_CESION_POLIZA IS NOT NULL ) OR '|| --'(LENGTH(LTRIM(FECHA_CESION_POLIZA, ''0123456789'')) != 0 AND FECHA_CESION_POLIZA IS NOT NULL AND LENGTH(FECHA_CESION_POLIZA) != 8) OR  ' ||
				'(FECHA_BAJA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA IS NOT NULL ) OR ' || --'(LENGTH(LTRIM(FECHA_BAJA, ''0123456789'')) != 0 AND FECHA_BAJA IS NOT NULL) OR ' ||
				'(FECHA_EFECTO_SUPLEMENTO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_EFECTO_SUPLEMENTO IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_EFECTO_SUPLEMENTO, ''0123456789'')) != 0 AND FECHA_EFECTO_SUPLEMENTO IS NOT NULL) OR ' ||
				'FECHA_VENCIMIENTO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_VENCIMIENTO, ''0123456789'')) != 0 OR ' ||
				'(FECHA_REHABILITACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_REHABILITACION IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_REHABILITACION, ''0123456789'')) != 0 AND FECHA_REHABILITACION IS NOT NULL) OR ' ||
				'(FECHA_COBRO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_COBRO IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_COBRO, ''0123456789'')) != 0 AND FECHA_COBRO IS NOT NULL) OR ' ||
				'FECHA_EFECTO_RECIBO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_EFECTO_RECIBO, ''0123456789'')) != 0 OR ' ||
				'FECHA_VENCIMIENTO_RECIBO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_VENCIMIENTO_RECIBO, ''0123456789'')) != 0 OR ' ||
				'(FECHA_ALTA_GAR_POL NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_ALTA_GAR_POL IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_ALTA_GAR_POL, ''0123456789'')) != 0 AND FECHA_ALTA_GAR_POL IS NOT NULL) OR ' ||
				'(FECHA_BAJA_GAR_POL NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA_GAR_POL IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_BAJA_GAR_POL, ''0123456789'')) != 0 AND FECHA_BAJA_GAR_POL IS NOT NULL) OR ' ||
				'FECHA_EMISION_REC NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_EMISION_REC, ''0123456789'')) != 0 OR ' ||
				'CARGO_COMPENSACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'')' --'LENGTH(LTRIM(CARGO_COMPENSACION, ''0123456789'')) != 0  ' 
		;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_fecha , i_log_count, i_id_proceso, 'debug');
		EXECUTE IMMEDIATE :v_sql_statement_fecha;
		
		
			v_sql_statement_fecha_delete := 
			 'DELETE FROM '|| :i_tabla ||' STG WHERE '||
				'FECHA_EFECTO_POLIZA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' || --'(LENGTH(LTRIM(FECHA_EFECTO_POLIZA, ''0123456789'')) != 0 OR LENGTH(FECHA_EFECTO_POLIZA) != 8) OR ' ||
				'FECHA_EMISION_POLIZA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' || --'(LENGTH(LTRIM(FECHA_EMISION_POLIZA, ''0123456789'')) != 0 OR LENGTH(FECHA_EMISION_POLIZA) != 8) OR ' ||
				'(FECHA_CESION_POLIZA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_CESION_POLIZA IS NOT NULL ) OR '|| --'(LENGTH(LTRIM(FECHA_CESION_POLIZA, ''0123456789'')) != 0 AND FECHA_CESION_POLIZA IS NOT NULL AND LENGTH(FECHA_CESION_POLIZA) != 8) OR  ' ||
				'(FECHA_BAJA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA IS NOT NULL ) OR ' || --'(LENGTH(LTRIM(FECHA_BAJA, ''0123456789'')) != 0 AND FECHA_BAJA IS NOT NULL) OR ' ||
				'(FECHA_EFECTO_SUPLEMENTO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_EFECTO_SUPLEMENTO IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_EFECTO_SUPLEMENTO, ''0123456789'')) != 0 AND FECHA_EFECTO_SUPLEMENTO IS NOT NULL) OR ' ||
				'FECHA_VENCIMIENTO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_VENCIMIENTO, ''0123456789'')) != 0 OR ' ||
				'(FECHA_REHABILITACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_REHABILITACION IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_REHABILITACION, ''0123456789'')) != 0 AND FECHA_REHABILITACION IS NOT NULL) OR ' ||
				'(FECHA_COBRO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_COBRO IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_COBRO, ''0123456789'')) != 0 AND FECHA_COBRO IS NOT NULL) OR ' ||
				'FECHA_EFECTO_RECIBO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_EFECTO_RECIBO, ''0123456789'')) != 0 OR ' ||
				'FECHA_VENCIMIENTO_RECIBO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_VENCIMIENTO_RECIBO, ''0123456789'')) != 0 OR ' ||
				'(FECHA_ALTA_GAR_POL NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_ALTA_GAR_POL IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_ALTA_GAR_POL, ''0123456789'')) != 0 AND FECHA_ALTA_GAR_POL IS NOT NULL) OR ' ||
				'(FECHA_BAJA_GAR_POL NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA_GAR_POL IS NOT NULL ) OR ' ||--'(LENGTH(LTRIM(FECHA_BAJA_GAR_POL, ''0123456789'')) != 0 AND FECHA_BAJA_GAR_POL IS NOT NULL) OR ' ||
				'FECHA_EMISION_REC NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_EMISION_REC, ''0123456789'')) != 0 OR ' ||
				'CARGO_COMPENSACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'')' --'LENGTH(LTRIM(CARGO_COMPENSACION, ''0123456789'')) != 0  ' 
			;
				
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_fecha_delete , i_log_count, i_id_proceso, 'debug');	
		EXECUTE IMMEDIATE :v_sql_statement_fecha_delete;	
			
		v_num_rows := ::rowcount;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS FECHAS VALIDAS - DELETE DE ' || v_num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'debug');
				
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS NUMERICOS VALIDOS ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
		v_sql_statement_numero := 
		'INSERT INTO EXT.PRESTAGE_RECIBOS_ERROR ' ||
		 'SELECT ''' ||
		 :i_id_proceso || ''',''' ||
		 :i_file_name || ''',' ||
		 'CURRENT_TIMESTAMP, ''Numero no valido'', STG.* '||
		 'FROM '|| :i_tabla ||' STG WHERE '||
				'LENGTH(LTRIM(IND_COMI_CALCULADA, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(IND_POR_CALCULADO, ''-.0123456789'')) != 0 OR ' ||
				'(LENGTH(LTRIM(POR_COMI_CALCULADA, ''-.0123456789'')) != 0 AND POR_COMI_CALCULADA IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(IMPORTE_COMISION, ''-.0123456789'')) != 0 AND  IMPORTE_COMISION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(INCRE_PRIMA_ANUAL, ''-.0123456789'')) != 0 AND INCRE_PRIMA_ANUAL IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_IMPT_SINIESTRALIDAD, ''-.0123456789'')) != 0 AND DTO_IMPT_SINIESTRALIDAD IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_POR_PRIORITARIO, ''-.0123456789'')) != 0 AND DTO_POR_PRIORITARIO IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(PORC_DESTO_SOBREPC, ''-.0123456789'')) != 0 AND PORC_DESTO_SOBREPC IS NOT NULL) OR ' ||
				'LENGTH(LTRIM(PRIMA_NETA_RECIBO, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(PRIMA_BRUTA_RECIBO, ''-.0123456789'')) != 0  OR ' ||
				'(LENGTH(LTRIM(PORCENTAJE_BONIFICACION, ''-.0123456789'')) != 0  AND PORCENTAJE_BONIFICACION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(NUM_ORDEN_MOVIMIENTO, ''-.0123456789'')) != 0 AND NUM_ORDEN_MOVIMIENTO IS NOT NULL) ' 
			;
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_numero , i_log_count, i_id_proceso, 'debug');	
		EXECUTE IMMEDIATE :v_sql_statement_numero;
				
		v_sql_statement_numero_delete := 
			 'DELETE FROM '|| :i_tabla ||' STG WHERE '||
			 	'LENGTH(LTRIM(IND_COMI_CALCULADA, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(IND_POR_CALCULADO, ''-.0123456789'')) != 0 OR ' ||
				'(LENGTH(LTRIM(POR_COMI_CALCULADA, ''-.0123456789'')) != 0 AND POR_COMI_CALCULADA IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(IMPORTE_COMISION, ''-.0123456789'')) != 0 AND  IMPORTE_COMISION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(INCRE_PRIMA_ANUAL, ''-.0123456789'')) != 0 AND INCRE_PRIMA_ANUAL IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_IMPT_SINIESTRALIDAD, ''-.0123456789'')) != 0 AND DTO_IMPT_SINIESTRALIDAD IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_POR_PRIORITARIO, ''-.0123456789'')) != 0 AND DTO_POR_PRIORITARIO IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(PORC_DESTO_SOBREPC, ''-.0123456789'')) != 0 AND PORC_DESTO_SOBREPC IS NOT NULL) OR ' ||
				'LENGTH(LTRIM(PRIMA_NETA_RECIBO, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(PRIMA_BRUTA_RECIBO, ''-.0123456789'')) != 0  OR ' ||
				'(LENGTH(LTRIM(PORCENTAJE_BONIFICACION, ''-.0123456789'')) != 0  AND PORCENTAJE_BONIFICACION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(NUM_ORDEN_MOVIMIENTO, ''-.0123456789'')) != 0 AND NUM_ORDEN_MOVIMIENTO IS NOT NULL) ' 
			;
	
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_numero_delete , i_log_count, i_id_proceso, 'debug');	
		EXECUTE IMMEDIATE :v_sql_statement_numero_delete;	
			
		v_num_rows := ::rowcount;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS NUMERICOS VALIDOS - DELETE DE ' || v_num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
	
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en SP_validarRecibos ' || i_file_name, i_log_count, i_id_proceso, 'debug');
		
		COMMIT;
			
	END;
  PUBLIC PROCEDURE SP_validarRecibosGestiones (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR;
		DECLARE v_sql_statement_fecha NVARCHAR(5000);
		DECLARE v_sql_statement_fecha_delete NVARCHAR(5000);
		DECLARE v_sql_statement_numero NVARCHAR(5000);
		DECLARE v_sql_statement_numero_delete NVARCHAR(5000);
		DECLARE v_num_rows INTEGER := 0;
		
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_validarRecibosGestiones: Revisad el insert dinamico'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
		  
	CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS FECHAS VALIDAS ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
		v_sql_statement_fecha := 
		'INSERT INTO EXT.PRESTAGE_RECIBOS_ERROR ' ||
		'SELECT ' || :i_id_proceso || ''', ''' || :i_file_name || ''', ' ||
		'CURRENT_TIMESTAMP, ''Fecha no valida'', STG.*, NULL, NULL ' ||
		'FROM ' || :i_tabla || ' STG WHERE ' ||
		'FECHA_COBRO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--' length(trim(FECHA_COBRO)) <> 8 OR ' ||
		'FECHA_EMISION_REC NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--' length(trim(FECHA_EMISION_REC)) <> 8 OR ' ||
		'CARGO_COMPENSACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'')' --' length(trim(CARGO_COMPENSACION)) <> 8 '
		;
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_fecha , i_log_count, i_id_proceso, 'debug');
		EXECUTE IMMEDIATE :v_sql_statement_fecha;
		
		
		v_sql_statement_fecha_delete := 
		 'DELETE FROM '|| :i_tabla ||' STG WHERE '||
		'FECHA_COBRO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--' length(trim(FECHA_COBRO)) <> 8 OR ' ||
		'FECHA_EMISION_REC NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--' length(trim(FECHA_EMISION_REC)) <> 8 OR ' ||
		'CARGO_COMPENSACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'')' --' length(trim(CARGO_COMPENSACION)) <> 8 '
		;
				
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_fecha_delete , i_log_count, i_id_proceso, 'debug');	
		EXECUTE IMMEDIATE :v_sql_statement_fecha_delete;	
			
		v_num_rows := ::rowcount;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS FECHAS VALIDAS - DELETE DE ' || v_num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'debug');
				
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS NUMERICOS VALIDOS ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
		v_sql_statement_numero := 
		'INSERT INTO EXT.PRESTAGE_RECIBOS_ERROR ' ||
		 'SELECT ''' ||
		 :i_id_proceso || ''',''' ||
		 :i_file_name || ''',' ||
		 'CURRENT_TIMESTAMP, ''Numero no valido'', STG.*, NULL, NULL  '||
		 'FROM '|| :i_tabla ||' STG WHERE '||
				'LENGTH(LTRIM(IND_COMI_CALCULADA, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(IND_POR_CALCULADO, ''-.0123456789'')) != 0 OR ' ||
				'(LENGTH(LTRIM(POR_COMI_CALCULADA, ''-.0123456789'')) != 0 AND POR_COMI_CALCULADA IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(IMPORTE_COMISION, ''-.0123456789'')) != 0 AND  IMPORTE_COMISION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(INCRE_PRIMA_ANUAL, ''-.0123456789'')) != 0 AND INCRE_PRIMA_ANUAL IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_IMPT_SINIESTRALIDAD, ''-.0123456789'')) != 0 AND DTO_IMPT_SINIESTRALIDAD IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_POR_PRIORITARIO, ''-.0123456789'')) != 0 AND DTO_POR_PRIORITARIO IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(PORC_DESTO_SOBREPC, ''-.0123456789'')) != 0 AND PORC_DESTO_SOBREPC IS NOT NULL) OR ' ||
				'LENGTH(LTRIM(PRIMA_NETA_RECIBO, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(PRIMA_BRUTA_RECIBO, ''-.0123456789'')) != 0  OR ' ||
				'(LENGTH(LTRIM(PORCENTAJE_BONIFICACION, ''-.0123456789'')) != 0  AND PORCENTAJE_BONIFICACION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(NUM_ORDEN_MOVIMIENTO, ''-.0123456789'')) != 0 AND NUM_ORDEN_MOVIMIENTO IS NOT NULL) ' 
			;
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_numero , i_log_count, i_id_proceso, 'debug');	
		EXECUTE IMMEDIATE :v_sql_statement_numero;
				
		v_sql_statement_numero_delete := 
			 'DELETE FROM '|| :i_tabla ||' STG WHERE '||
			 	'LENGTH(LTRIM(IND_COMI_CALCULADA, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(IND_POR_CALCULADO, ''-.0123456789'')) != 0 OR ' ||
				'(LENGTH(LTRIM(POR_COMI_CALCULADA, ''-.0123456789'')) != 0 AND POR_COMI_CALCULADA IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(IMPORTE_COMISION, ''-.0123456789'')) != 0 AND  IMPORTE_COMISION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(INCRE_PRIMA_ANUAL, ''-.0123456789'')) != 0 AND INCRE_PRIMA_ANUAL IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_IMPT_SINIESTRALIDAD, ''-.0123456789'')) != 0 AND DTO_IMPT_SINIESTRALIDAD IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(DTO_POR_PRIORITARIO, ''-.0123456789'')) != 0 AND DTO_POR_PRIORITARIO IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(PORC_DESTO_SOBREPC, ''-.0123456789'')) != 0 AND PORC_DESTO_SOBREPC IS NOT NULL) OR ' ||
				'LENGTH(LTRIM(PRIMA_NETA_RECIBO, ''-.0123456789'')) != 0 OR ' ||
				'LENGTH(LTRIM(PRIMA_BRUTA_RECIBO, ''-.0123456789'')) != 0  OR ' ||
				'(LENGTH(LTRIM(PORCENTAJE_BONIFICACION, ''-.0123456789'')) != 0  AND PORCENTAJE_BONIFICACION IS NOT NULL) OR ' ||
				'(LENGTH(LTRIM(NUM_ORDEN_MOVIMIENTO, ''-.0123456789'')) != 0 AND NUM_ORDEN_MOVIMIENTO IS NOT NULL) ' 
			;
	
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_numero_delete , i_log_count, i_id_proceso, 'debug');	
		EXECUTE IMMEDIATE :v_sql_statement_numero_delete;	
			
		v_num_rows := ::rowcount;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS NUMERICOS VALIDOS - DELETE DE ' || v_num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
	
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en SP_validarRecibosGestiones ' || i_file_name, i_log_count, i_id_proceso, 'debug');
		
		COMMIT;
			
	END;
  PUBLIC PROCEDURE SP_validarAsegurados (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR;
		DECLARE v_sql_statement_fecha NVARCHAR(5000);
		DECLARE v_sql_statement_fecha_delete NVARCHAR(5000);
		DECLARE v_sql_statement_numero NVARCHAR(5000);
		DECLARE v_sql_statement_numero_delete NVARCHAR(5000);
		DECLARE v_num_rows INTEGER := 0;
		
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_validarAsegurados: Revisad el insert dinamico'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
		  
	CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS FECHAS VALIDAS ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
	v_sql_statement_fecha := 
		'INSERT INTO EXT.PRESTAGE_ASEGURADOS_ERROR ' ||
		 'SELECT ''' ||
		 :i_id_proceso || ''',''' ||
		 :i_file_name || ''',' ||
		 'CURRENT_TIMESTAMP, '' Fecha no valida '', STG.* '||
		 'FROM '|| :i_tabla ||' STG WHERE '||
				'FECHA_NACIMIENTO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_NACIMIENTO, ''0123456789'')) != 0 OR ' ||
				'FECHA_DERECHOS NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_DERECHOS, ''0123456789'')) != 0 OR ' ||
				'FECHA_ALTA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_ALTA, ''0123456789'')) != 0 OR ' ||
				'(FECHA_BAJA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA IS NOT NULL ) OR '||--'(LENGTH(LTRIM(FECHA_BAJA, ''0123456789'')) != 0 AND FECHA_BAJA IS NOT NULL)  OR ' ||
				'(FECHA_REHABILITACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_REHABILITACION IS NOT NULL ) OR '||--'(LENGTH(LTRIM(FECHA_REHABILITACION, ''0123456789'')) != 0 AND FECHA_REHABILITACION IS NOT NULL) OR ' ||
				'FECHA_ALTA_GAR_ASE NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_ALTA_GAR_ASE, ''0123456789'')) != 0 OR ' ||
				'(FECHA_BAJA_GAR_ASE NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA_GAR_ASE IS NOT NULL )'--'(LENGTH(LTRIM(FECHA_BAJA_GAR_ASE, ''0123456789'')) != 0 AND FECHA_BAJA_GAR_ASE IS NOT NULL)'  ;
		; 
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_fecha , i_log_count, i_id_proceso, 'debug');
		EXECUTE IMMEDIATE :v_sql_statement_fecha;
		
		
			v_sql_statement_fecha_delete := 
			 'DELETE FROM '|| :i_tabla ||' STG WHERE '||
				'FECHA_NACIMIENTO NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_NACIMIENTO, ''0123456789'')) != 0 OR ' ||
				'FECHA_DERECHOS NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_DERECHOS, ''0123456789'')) != 0 OR ' ||
				'FECHA_ALTA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_ALTA, ''0123456789'')) != 0 OR ' ||
				'(FECHA_BAJA NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA IS NOT NULL ) OR '||--'(LENGTH(LTRIM(FECHA_BAJA, ''0123456789'')) != 0 AND FECHA_BAJA IS NOT NULL)  OR ' ||
				'(FECHA_REHABILITACION NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_REHABILITACION IS NOT NULL ) OR '||--'(LENGTH(LTRIM(FECHA_REHABILITACION, ''0123456789'')) != 0 AND FECHA_REHABILITACION IS NOT NULL) OR ' ||
				'FECHA_ALTA_GAR_ASE NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') OR ' ||--'LENGTH(LTRIM(FECHA_ALTA_GAR_ASE, ''0123456789'')) != 0 OR ' ||
				'(FECHA_BAJA_GAR_ASE NOT LIKE_REGEXPR(''^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$'') AND FECHA_BAJA_GAR_ASE IS NOT NULL )'--'(LENGTH(LTRIM(FECHA_BAJA_GAR_ASE, ''0123456789'')) != 0 AND FECHA_BAJA_GAR_ASE IS NOT NULL)'  ;
			;
				
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement_fecha_delete , i_log_count, i_id_proceso, 'debug');	
		EXECUTE IMMEDIATE :v_sql_statement_fecha_delete;	
			
		v_num_rows := ::rowcount;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'COMPROBACION CAMPOS FECHA VALIDOS - DELETE DE ' || v_num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'debug');
	
	
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en SP_validarAsegurados ' || i_file_name, i_log_count, i_id_proceso, 'debug');
		
		COMMIT;
	
	END;
  PUBLIC PROCEDURE SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE ( IN i_file_name VARCHAR(120), IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR;
		DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
		DECLARE v_const_populate_status_error INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_ERROR;
		DECLARE v_num_rows INTEGER := 0;
		  
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
	
	END;
END