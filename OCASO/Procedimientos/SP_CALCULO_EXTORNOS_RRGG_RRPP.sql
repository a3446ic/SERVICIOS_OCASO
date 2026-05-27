CREATE  PROCEDURE EXT.SP_CALCULO_EXTORNOS_RRGG_RRPP (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS


/*---------------------------------------------------------------------
    | Author: Rub?n Mart?nez Fern?ndez
    | Company: Inycom
    | Initial Version Date: 04-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta desde el procedimineto de SP_CALCULO, para calcular los extornos de los ramos de RRGG RRPP
	|
	|
	| Version: 0.1	RMF 20250304		Initial Version.
	| Version: 1.0	RMF 20250918		Se elimina la partici?n del ROW_NUMBER por CODIGO_RECIBO, CODIGO_SUPLEMENTO y ESTADO_RECIBO para evitar problemas de elegir mal el recibo origen en caso de varios recibos 71 o 66
	|
    -----------------------------------------------------------------------
*/
BEGIN

	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '1.0';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_existen_extornos INTEGER := 0;
	DECLARE v_fecha_cobro DATE := LAST_DAY(CURRENT_DATE);
	DECLARE v_existe_tabla INTEGER := 0;
	
	--CONSTANTES GENERALES
	DECLARE v_const_n VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N;
	DECLARE v_const_n_0 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N_0;
	DECLARE v_const_s VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S;
	DECLARE v_const_si VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_SI;
	
	--CONSTANTES DE ESTADO
	DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK; --2
	DECLARE v_const_calculo_status_ok		INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_OK; --6
	DECLARE v_const_calculo_status_error	INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_ERROR;--7
	
	--CONSTANTES POLIZA
	DECLARE v_const_motivo_baja_bb VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_BAJA_BB;
	DECLARE v_const_ramo_rrgg VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRGG;
	DECLARE v_const_ramo_rrpp VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRPP;
	DECLARE v_const_baja_error VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_BAJA_ERROR;
	DECLARE v_const_baja_rescision VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_BAJA_RESCISION;
	DECLARE v_const_baja_vto VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_BAJA_VTO;
	DECLARE v_const_baja_rescate VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_BAJA_RESCATE;
	DECLARE v_const_baja_ya_fue_baja VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_BAJA_YA_FUE_BAJA;
	DECLARE v_const_baja_sustitucion VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_BAJA_SUSTITUCION;
	 
	--CONSTANTES DE RECIBO
	DECLARE v_const_recibos_especificos_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
	DECLARE v_const_recibos_especificos_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
	DECLARE v_const_recibos_especificos_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
	DECLARE v_const_recibos_especificos_11 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_11;
	DECLARE v_const_recibo_cobrado VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
	DECLARE v_const_recibo_emitido VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EMITIDO;
	DECLARE v_const_recibo_pendiente VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_PENDIENTE;
	DECLARE v_const_cod_recibo_anul_rrggpp VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRGGPP;
	DECLARE v_const_cod_recibo_anul_serco VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_SERCO;
	DECLARE v_const_cod_recibo_serco VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_SERCO;
	DECLARE v_const_tipo_rec_anul_k5 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_ANUL_K5;
	DECLARE v_const_permanencia_anu_2anio VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_PERMANENCIA_ANU_2ANIO;
	DECLARE v_const_permanencia_anu_mas2anio VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_PERMANENCIA_ANU_MAS2ANIO;
	
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
																												
			
			--v_hayError := 1;
			v_num_rows := 0;
		
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_calculo_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = i_id_proceso;
			commit;	
			RESIGNAL;
		
		END;
	
	
	BEGIN
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, i_log_count, i_id_proceso, 'info');
		
		--FT_COMPRUEBA_EXTORNO
		--Recibos que vienen en el fichero con MARCA_CUENTA = S o PERMANENCIA = 65
		TBL_C_RECIBOS = SELECT TBL.*
        				FROM EXT.RECIBOS TBL
                        WHERE TBL.FILE_NAME = :i_file_name
                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS creada: ' || v_num_rows || ' filas. RECIBOS con MARCA_CUENTA = S o PERMANENCIA = 65', i_log_count, i_id_proceso, 'debug');
		
		--Polizas asociadas a los recibos tratados
		TBL_C_POLIZAS = SELECT TBL.*
        				FROM EXT.POLIZAS TBL
                        WHERE EXISTS (SELECT 1
                        				FROM :TBL_C_RECIBOS src
                        				WHERE src.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        )
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_POLIZAS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_POLIZAS creada: ' || v_num_rows || ' filas. POLIZAS asociadas a los RECIBOS tratados', i_log_count, i_id_proceso, 'debug');
		
		--Se genera la tabla temporal de productos
		
		TBL_GEN_PRODUCTOS = SELECT * FROM EXT.VW_GEN_PRODUCTOS;
		v_num_rows = RECORD_COUNT(:TBL_GEN_PRODUCTOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_PRODUCTOS creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
        
        --Nos quedamos con los RECIBOS a calcular, RAMO = RRGG, RRPP, MOTIVO_ALTA = BB, MOTIVO_BAJA y FECHA_BAJA IS NOT NULL
        TBL_RECIBOS_A_CALCULAR = SELECT REC.*
        							, DAYS_BETWEEN(POL.FECHA_EFECTO_POLIZA,POL.FECHA_BAJA) AS PERIODO_ANULACION
        							, POL.RAMO
        							, POL.MOTIVO_ALTA
        							, POL.FECHA_BAJA
        							, POL.MOTIVO_BAJA
        							, POL.FECHA_EMISION_POLIZA --para RRPP
        							, POL.FORMA_PAGO --para SERCO
        						FROM :TBL_C_RECIBOS REC
        						INNER JOIN :TBL_C_POLIZAS POL ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA
        							AND POL.RAMO IN (:v_const_ramo_rrgg,:v_const_ramo_rrpp)--Nos quedamos con todos los recibos de RRGG, RRPP
        							AND POL.MOTIVO_ALTA = :v_const_motivo_baja_bb
        							AND POL.FECHA_BAJA IS NOT NULL
        							AND POL.MOTIVO_BAJA IS NOT NULL
        						WHERE REC.ESTADO = :v_const_populate_status_ok
                				;
                				
        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_CALCULAR);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_CALCULAR creada: ' || v_num_rows || ' filas. RAMO = RRGG, RRPP, MOTIVO_ALTA = BB, FECHA_BAJA y MOTIVO_BAJA NOT NULL', i_log_count, i_id_proceso, 'debug');
		
		TBL_GARANTIAS_RECIBO = SELECT GAR_REC.*
								FROM EXT.GARANTIAS_RECIBO GAR_REC
								WHERE EXISTS (SELECT 1 
												FROM :TBL_RECIBOS_A_CALCULAR TBL
												WHERE TBL.CODIGO_POLIZA = GAR_REC.CODIGO_POLIZA
													AND TBL.CODIGO_RECIBO = GAR_REC.CODIGO_RECIBO
											)
								;
		
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO creada: ' || v_num_rows || ' filas. GARANTIAS_RECIBO asociadas a los RECIBOS tratados', i_log_count, i_id_proceso, 'debug');
		
		--Existe un RECIBO cobrado anterior (PERMANENCIA 71 o 66)
		TBL_RECIBO_COBRADO = SELECT TBL.*
								, 1 AS RECIBO_COBRADO
							FROM :TBL_RECIBOS_A_CALCULAR TBL
							WHERE EXISTS (SELECT 1 
											FROM EXT.RECIBOS REC
											WHERE REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
												AND REC.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_especificos_66)
												AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
												AND REC.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrggpp
												AND ((REC.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' AND REC.TIPO_RECIBO IS NOT NULL) OR (REC.TIPO_RECIBO IS NULL AND RIGHT(REC.CODIGO_POLIZA,1) NOT IN ('X','S')))
												AND REC.CODIGO_SUPLEMENTO = 0
										)
							;
									
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_COBRADO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_COBRADO creada: ' || v_num_rows || ' filas. Recibos cobrados anteriores a partir de TBL_RECIBOS_A_CALCULAR', i_log_count, i_id_proceso, 'debug');
		
		--No se incluye la cuenta de no_es_poliza_antigua ya que coincide con la de recibo_cobrado
		
		--MAX FECHA_COMPENSACION para anulaciones de SERCO y PERMANENCIA = 11
		TBL_MAX_FECHA_COMPENSACION = SELECT IFNULL(MAX(x.FECHA_COMPENSACION),TO_DATE('19000101','YYYYMMDD')) AS MAX_FECHA_COMPENSACION
											, x.CODIGO_POLIZA
										FROM EXT.RECIBOS x
										INNER JOIN :TBL_RECIBOS_A_CALCULAR TBL ON TBL.CODIGO_POLIZA LIKE SUBSTR(x.CODIGO_POLIZA,1,20) || '%'
										WHERE x.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_serco,:v_const_cod_recibo_anul_rrggpp)
											AND x.PERMANENCIA = :v_const_recibos_especificos_11
										GROUP BY x.CODIGO_POLIZA
									;
									
		v_num_rows = RECORD_COUNT(:TBL_MAX_FECHA_COMPENSACION);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_MAX_FECHA_COMPENSACION creada: ' || v_num_rows || ' filas. MAX FECHA_COMPENSACION para anulaciones de SERCO y RRGGPP y PERMANENCIA = 11', i_log_count, i_id_proceso, 'debug');
		
		TBL_RECIBO_COBRADO_SERCO = SELECT TBL.*
										, 1 AS RECIBO_COBRADO_SERCO
									FROM :TBL_RECIBOS_A_CALCULAR TBL
									WHERE EXISTS (SELECT 1
													FROM EXT.RECIBOS REC
													LEFT JOIN :TBL_MAX_FECHA_COMPENSACION FC ON FC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
													WHERE REC.FILE_NAME <> TBL.FILE_NAME
														AND REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
														--AND REC.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_serco,:v_const_cod_recibo_anul_rrggpp)
														AND REC.FECHA_COMPENSACION < TBL.FECHA_COMPENSACION
														AND REC.PERMANENCIA = :v_const_recibos_especificos_11
														AND REC.EXCLUIDO_COMISIONES > :v_const_n_0
														AND REC.CODIGO_RECIBO = :v_const_cod_recibo_serco
														AND (REC.FECHA_COMPENSACION >= FC.MAX_FECHA_COMPENSACION OR FC.MAX_FECHA_COMPENSACION IS NULL)
												)
									;
									
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_COBRADO_SERCO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_COBRADO_SERCO creada: ' || v_num_rows || ' filas. Recibos cobrados anteriores a partir de TBL_RECIBOS_A_CALCULAR', i_log_count, i_id_proceso, 'debug');
		
		--Tabla general de ANULACIONES. Se a?aden los valores de RECIBO_COBRADO y RECIBO_COBRADO_SERCO calculados anteriormente y los indicadores de anulaci?n normal y anulaci?n SERCO
		TBL_ANULACIONES = SELECT TBL.*
							, IFNULL(COB.RECIBO_COBRADO,0) AS RECIBO_COBRADO
							, IFNULL(SER.RECIBO_COBRADO_SERCO,0) AS RECIBO_COBRADO_SERCO
							, CASE WHEN (IFNULL(COB.RECIBO_COBRADO,0) > 0 OR IFNULL(COB.RECIBO_COBRADO,0) = 0 AND TBL.PERIODO_ANULACION >= 365)
								THEN 1
								ELSE 0
							END AS ANUL_NORMAL
							, CASE WHEN IFNULL(SER.RECIBO_COBRADO_SERCO,0) > 0
								THEN 1
								ELSE 0
							END AS ANUL_SERCO
						FROM :TBL_RECIBOS_A_CALCULAR TBL
						LEFT JOIN :TBL_RECIBO_COBRADO COB ON COB.CODIGO_RECIBO = TBL.CODIGO_RECIBO
							AND COB.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						LEFT JOIN :TBL_RECIBO_COBRADO_SERCO SER ON SER.CODIGO_RECIBO = TBL.CODIGO_RECIBO
							AND SER.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						;
		
		v_num_rows = RECORD_COUNT(:TBL_ANULACIONES);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_ANULACIONES creada: ' || v_num_rows || ' filas. Informaci?n de recibos cobrados a?adida', i_log_count, i_id_proceso, 'debug');
		
		--FT_COMPRUEBA_ANULACION_SERCO
		--Montamos la tabla base
		--Todos los recibos que entran por aqu? ir?an marcados como anulaci?n SERCO = 1
		TBL_COMPRUEBA_ANULACION_SERCO = SELECT TBL.*
										FROM :TBL_ANULACIONES TBL
										WHERE TBL.RECIBO_COBRADO_SERCO > 0 
								;
								
		v_num_rows = RECORD_COUNT(:TBL_COMPRUEBA_ANULACION_SERCO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_COMPRUEBA_ANULACION_SERCO creada: ' || v_num_rows || ' filas. Se calculan las bajas si hay RECIBO_COBRADO_SERCO', i_log_count, i_id_proceso, 'debug');

		/*
		--MAX FECHA_COMPENSACION para anulaciones de SERCO y PERMANENCIA = 11
		TBL_MAX_FECHA_COMPENSACION_2 = SELECT IFNULL(MAX(x.FECHA_COMPENSACION),TO_DATE('19000101','YYYYMMDD')) AS MAX_FECHA_COMPENSACION
											, x.CODIGO_POLIZA
										FROM EXT.RECIBOS x
										RIGHT JOIN :TBL_COMPRUEBA_ANULACION_SERCO TBL ON TBL.CODIGO_POLIZA = x.CODIGO_POLIZA
										WHERE x.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_serco,:v_const_cod_recibo_anul_rrggpp)
											AND x.PERMANENCIA = :v_const_recibos_especificos_11
										GROUP BY x.CODIGO_POLIZA, x.FILE_NAME
									;
									
		v_num_rows = RECORD_COUNT(:TBL_MAX_FECHA_COMPENSACION_2);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_MAX_FECHA_COMPENSACION_2 creada: ' || v_num_rows || ' filas. MAX FECHA_COMPENSACION para anulaciones de SERCO y RRGGPP y PERMANENCIA = 11', i_log_count, i_id_proceso, 'debug');
		*/
		
		TBL_C_RECIBOS_SERCO = SELECT REC.*
								, GAR_REC.PRODUCTO_CONTABLE
								, GAR_REC.PRIMA_COMISIONABLE
								, GAR_REC.PRIMA_BRUTA_RECIBO
								, GAR_REC.RECARGO
								, GAR_REC.INCREMENTO_PRIMA_ANUAL
								, GAR_REC.PRIMA_NETA_ANUALIZADA
								, TBL.CODIGO_POLIZA AS CODIGO_POLIZA_SERCO
								, TBL.CODIGO_RECIBO AS CODIGO_RECIBO_SERCO
								, ROW_NUMBER() OVER (
									PARTITION BY REC.CODIGO_POLIZA, REC.CODIGO_RECIBO--, REC.CODIGO_SUPLEMENTO, REC.ESTADO_RECIBO
									ORDER BY REC.FECHA_COBRO ASC
								) AS ROW_NUM
							FROM :TBL_COMPRUEBA_ANULACION_SERCO TBL
							LEFT JOIN EXT.RECIBOS REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
								AND REC.FECHA_COMPENSACION < TBL.FECHA_COMPENSACION
								AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
								AND REC.PERMANENCIA = :v_const_recibos_especificos_11
								AND REC.EXCLUIDO_COMISIONES > :v_const_n_0
								AND REC.CODIGO_RECIBO = :v_const_cod_recibo_serco
							LEFT JOIN EXT.GARANTIAS_RECIBO GAR_REC ON REC.CODIGO_POLIZA = GAR_REC.CODIGO_POLIZA
								AND REC.CODIGO_RECIBO = GAR_REC.CODIGO_RECIBO
								AND REC.CODIGO_SUPLEMENTO = GAR_REC.CODIGO_SUPLEMENTO
								AND REC.ESTADO_RECIBO = GAR_REC.ESTADO_RECIBO
							WHERE EXISTS (SELECT 1
											FROM EXT.RECIBOS AUX
											LEFT JOIN :TBL_MAX_FECHA_COMPENSACION FC ON FC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
											WHERE AUX.FILE_NAME <> :i_file_name
												AND AUX.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
												--AND REC.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_serco,:v_const_cod_recibo_anul_rrggpp)
												AND AUX.PERMANENCIA = :v_const_recibos_especificos_11
												AND AUX.EXCLUIDO_COMISIONES > :v_const_n_0
												AND AUX.CODIGO_RECIBO = :v_const_cod_recibo_serco
												AND (AUX.FECHA_COMPENSACION > FC.MAX_FECHA_COMPENSACION OR FC.MAX_FECHA_COMPENSACION IS NULL)
												AND AUX.ESTADO_RECIBO = :v_const_recibo_cobrado
										)
							;
							
		v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_SERCO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_SERCO creada: ' || v_num_rows || ' filas. MAX FECHA_COMPENSACION para anulaciones de SERCO y RRGGPP y PERMANENCIA = 11', i_log_count, i_id_proceso, 'debug');
		
		 ----------------- Creamos una tabla de DEBUG.
		--COMENTAR EN PRD
		SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_RECIBOS_SERCO_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_C_RECIBOS_SERCO_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_C_RECIBOS_SERCO_DEBUG AS (SELECT * FROM :TBL_C_RECIBOS_SERCO);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_RECIBOS_SERCO_DEBUG' , i_log_count, i_id_proceso, 'debug');
		------------------COMENTAR EN PRD
		
		
							
		TBL_C_RECIBOS_SERCO_PER_EXTORNABLE = SELECT TBL.*
													, SUBSTR(TBL.CODIGO_POLIZA,1,2) AS COD_COMPANIA
													, SUBSTR(TBL.CODIGO_POLIZA,3,5) AS COD_PRODUCTO_POL
													, SUBSTR(TBL.CODIGO_POLIZA,8) AS COD_POLIZA_OUT
													, CASE WHEN PRO.CODIGO IS NULL
														THEN 0
														ELSE CASE WHEN PRO.PERIODO_EXTORNABLE IS NULL 
															THEN  12 
															ELSE PRO.PERIODO_EXTORNABLE
														END
													END AS PERIODO_EXTORNABLE
													--, MONTHS_BETWEEN(IFNULL(TBL.FECHA_EFECTO_RECIBO,TBL.FECHA_BAJA), SER.FECHA_EFECTO_RECIBO) AS MESES_VIGENTES
													, MONTHS_BETWEEN(SER.FECHA_EFECTO_RECIBO, IFNULL(TBL.FECHA_EFECTO_RECIBO,TBL.FECHA_BAJA)) AS MESES_VIGENTES
													, SER.FILE_NAME AS FILE_NAME_SERCO
													, SER.PRIMA_COMISIONABLE AS V_PRIMA_NETA
													, SER.PRODUCTO_CONTABLE
													, SER.CODIGO_SUPLEMENTO AS CODIGO_SUPLEMENTO_ORI
												FROM :TBL_COMPRUEBA_ANULACION_SERCO TBL
												LEFT JOIN :TBL_GEN_PRODUCTOS PRO ON PRO.CODIGO = SUBSTR(TBL.CODIGO_POLIZA,1,7) --COD_PRODUCTO
												INNER JOIN :TBL_C_RECIBOS_SERCO SER ON TBL.CODIGO_POLIZA = SER.CODIGO_POLIZA_SERCO
													AND TBL.CODIGO_RECIBO = SER.CODIGO_RECIBO_SERCO
													--AND SER.ROW_NUM = 1
											;
											
		v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_SERCO_PER_EXTORNABLE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_SERCO_PER_EXTORNABLE creada: ' || v_num_rows || ' filas. Se a?ade informaci?n de desglose de c?digos de p?liza, periodo extornable y meses vigentes', i_log_count, i_id_proceso, 'debug');
		
		-----------------Creamos una tabla de DEBUG.
		--COMENTAR EN PRD
		SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_RECIBOS_SERCO_PER_EXTORNABLE_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_C_RECIBOS_SERCO_PER_EXTORNABLE_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_C_RECIBOS_SERCO_PER_EXTORNABLE_DEBUG AS (SELECT * FROM :TBL_C_RECIBOS_SERCO_PER_EXTORNABLE);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_RECIBOS_SERCO_PER_EXTORNABLE_DEBUG' , i_log_count, i_id_proceso, 'debug');
		------------------COMENTAR EN PRD
		
		
		TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE = SELECT TBL.*
													, CASE WHEN TBL.PERIODO_EXTORNABLE > 0
														THEN CASE WHEN TBL.MESES_VIGENTES >= 0
															THEN CASE WHEN (IFNULL(TBL.PERIODO_EXTORNABLE,0) - IFNULL(TBL.MESES_VIGENTES,0)) > 0
																THEN 1
																ELSE 0 END
															ELSE 0 END
														ELSE 0 
													END AS ES_EXTORNABLE
												FROM :TBL_C_RECIBOS_SERCO_PER_EXTORNABLE TBL
												;
		
		v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE creada: ' || v_num_rows || ' filas. Se a?ade indicador a cada recibo de si es periodo extornable', i_log_count, i_id_proceso, 'debug');
		
		-----------------Creamos una tabla de DEBUG.
		--COMENTAR EN PRD
		SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE_DEBUG AS (SELECT * FROM :TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE_DEBUG' , i_log_count, i_id_proceso, 'debug');
		------------------COMENTAR EN PRD
		
		
		
		TBL_GEN_FORMAS_PAGO = SELECT * FROM EXT.VW_FORMAS_PAGO;
		v_num_rows = RECORD_COUNT(:TBL_GEN_FORMAS_PAGO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_FORMAS_PAGO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		TBL_C_RECIBOS_SERCO_PARA_INSERT = SELECT TBL.*
											, IFNULL(PAG.MENSUALIDADES,12) AS MENSUALIDADES
											, ROW_NUMBER() OVER (
												PARTITION BY TBL.CODIGO_POLIZA--, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO
												--ORDER BY TBL.FECHA_COBRO ASC
												ORDER BY TBL.FECHA_COBRO ASC
											) AS ROW_NUM_INS
										FROM :TBL_C_RECIBOS_SERCO_ES_PER_EXTORNABLE TBL
										LEFT JOIN :TBL_GEN_FORMAS_PAGO PAG ON TBL.FORMA_PAGO = PAG.CODIGO
										WHERE TBL.ES_EXTORNABLE = 1
										;
		
		v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_SERCO_PARA_INSERT);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_SERCO_PARA_INSERT creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
	-----------------Creamos una tabla de DEBUG.
	--COMENTAR EN PRD
	SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_RECIBOS_SERCO_PARA_INSERT_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_C_RECIBOS_SERCO_PARA_INSERT_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_C_RECIBOS_SERCO_PARA_INSERT_DEBUG AS (SELECT * FROM :TBL_C_RECIBOS_SERCO_PARA_INSERT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_RECIBOS_SERCO_PARA_INSERT_DEBUG' , i_log_count, i_id_proceso, 'debug');
	------------------COMENTAR EN PRD	
		
		
	/*	BEGIN AUTONOMOUS TRANSACTION
			DELETE FROM EXT.TBL_C_RECIBOS_SERCO_PARA_INSERT_DEBUG;
			INSERT INTO EXT.TBL_C_RECIBOS_SERCO_PARA_INSERT_DEBUG
				SELECT * FROM :TBL_C_RECIBOS_SERCO_PARA_INSERT;
		END;*/
		
		
		--Se insertan recibos nuevos de anulaci?n con los valores del cobrado
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT anulaciones de SERCO en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_C_RECIBOS_SERCO_PARA_INSERT TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			INSERT INTO EXT.RECIBOS
			SELECT TBL.IDENTIFICADOR 
				, TBL.FILE_NAME
				, :v_const_calculo_status_ok AS ESTADO
				, CURRENT_TIMESTAMP AS FECHA_MODIFICACION
				, TBL.CODIGO_POLIZA
				, :v_const_cod_recibo_anul_serco AS CODIGO_RECIBO
				, :v_const_recibos_especificos_11 AS PERMANENCIA 
				, SER.TIPO_RECIBO 
				, :v_const_recibo_cobrado AS ESTADO_RECIBO
				, SER.FECHA_COBRO
				, TBL.FECHA_COMPENSACION
				, SER.FECHA_EFECTO_RECIBO
				, SER.FECHA_VTO_RECIBO
				, SER.TIPO_MOVIMIENTO
				, NULL AS PORCENTAJE_DESCUENTO_SOBRE_PC
				, NULL AS VALOR_POLIZA
				, SER.CODIGO_UNICO_AGENTE
				, SER.CODIGO_AGENTE_ORIGINAL
				, SER.INSPECTOR
				, NULL AS OFICINA_COBRADORA 
				, NULL AS OFICINA_GESTORA 
				, NULL AS MARCA_RECUPERADO
				, :v_const_s AS MARCA_CUENTA
				, NULL AS PRIMER_RECIBO
				, NULL AS ASEGURADOS_NETOS
				, NULL AS AUMENTO_ASEGURADOS
				, NULL AS EXCLUIDO_COMISIONES
				, NULL AS BONIFICACION_POLIZA
				, NULL AS DISMINUCION_PRIMA
				, SER.TIPO_RECUPERACION
				, NULL AS ES_PERMANENCIA_20
				, SER.CODIGO_AGENTE_COMMISSIONS 
				, SER.FECHA_COMPENSACION AS FECHA_EMISION_REC
				, NULL AS FCHA_EFECTO_SUPLEMENTO
				, SER.CODIGO_SUPLEMENTO
				, NULL AS DISTRITO_COBRO
				, NULL AS CODIGO_SINIESTRO
				, NULL AS ZONA_EXPLOTACION
				, NULL AS CODIGO_AGENTE_ZONA 
			FROM :TBL_C_RECIBOS_SERCO_PARA_INSERT TBL
			INNER JOIN :TBL_C_RECIBOS_SERCO SER ON TBL.CODIGO_POLIZA = SER.CODIGO_POLIZA_SERCO
				AND TBL.CODIGO_RECIBO = SER.CODIGO_RECIBO_SERCO
				AND TBL.CODIGO_SUPLEMENTO_ORI = SER.CODIGO_SUPLEMENTO
					--AND SER.ROW_NUM = 1
			--WHERE TBL.ROW_NUM_INS = 1
			--TGV 20251027- descomentamos los row_num por errores de duplicados
				AND SER.ROW_NUM = 1
			WHERE TBL.ROW_NUM_INS = 1
			and not exists(select codigo_poliza from ext.recibos REC 
				where REC.codigo_poliza = tbl.codigo_poliza 
				and rec.codigo_recibo = v_const_cod_recibo_anul_serco
				and rec.estado_recibo = v_const_recibo_cobrado 
				and rec.codigo_suplemento = SER.CODIGO_SUPLEMENTO )
				
			;
		
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT anulaciones de SERCO en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT anulaciones de SERCO en GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO x, :TBL_C_RECIBOS_SERCO_PARA_INSERT TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			--Se insertan garant?as de recibo nuevas de anulaci?n con los valores del cobrado
			INSERT INTO EXT.GARANTIAS_RECIBO
			SELECT TBL.IDENTIFICADOR AS ID_RECIBO
				, TBL.FILE_NAME AS FILE_NAME
				, :v_const_calculo_status_ok
				, CURRENT_TIMESTAMP
				, TBL.CODIGO_POLIZA                 
				, :v_const_cod_recibo_anul_serco AS CODIGO_RECIBO               
				, SER.PRODUCTO_CONTABLE           
				, :v_const_recibo_cobrado AS ESTADO_RECIBO               
				, CASE WHEN SER.FECHA_COMPENSACION >= TO_DATE('20210201','YYYYMMDD')
					THEN (-1) * TBL.V_PRIMA_NETA 
					ELSE (-1) * TBL.V_PRIMA_NETA/TBL.MENSUALIDADES
				END AS PRIMA_NETA_RECIBO           
				, (-1) * SER.PRIMA_BRUTA_RECIBO AS PRIMA_BRUTA_RECIBO
				, (-1) * SER.RECARGO AS RECARGO
				, NULL AS PORCENTAJE_BONIFICACION
				, (-1) * SER.INCREMENTO_PRIMA_ANUAL AS INCREMENTO_PRIMA_ANUAL
				, CASE WHEN SER.FECHA_COMPENSACION >= TO_DATE('20210201','YYYYMMDD')
					THEN (-1) * TBL.V_PRIMA_NETA 
					ELSE (-1) * TBL.V_PRIMA_NETA/TBL.MENSUALIDADES
				END AS PRIMA_COMISIONABLE          
				, NULL AS UNIDAD_DE_POLIZA            
				, TBL.MENSUALIDADES AS MESES_COBRADOS              
				, NULL AS FECHA_ALTA_GAR_POL          
				, NULL AS FECHA_BAJA_GAR_POL          
				, NULL AS PORCENTAJE_NIVELADA         
				, NULL AS PERIODO_EXTORNABLE          
				, 0 AS INDICADOR_COMISION_CALCULADA
				, 0 AS INDICADOR_PORCENTAJE_CALCULA
				, NULL AS PORCENTAJE_COMISION_CALCULAD
				, NULL AS IMPORTE_COMISION            
				, NULL AS PRIMA_UNICA                 
				, NULL AS NUM_ORDEN_MOVIMIENTO        
				, NULL AS AUMENTO_CAPITALES_GARANTIA  
				, (-1) * SER.PRIMA_NETA_ANUALIZADA AS PRIMA_NETA_ANUALIZADA
				, NULL AS PORC_COMISION_NP            
				, NULL AS PORC_COMISION_CONSERVACION  
				, SER.CODIGO_SUPLEMENTO           
				, NULL AS PORC_COMISION_COBRO         
			FROM :TBL_C_RECIBOS_SERCO_PARA_INSERT TBL
			INNER JOIN :TBL_C_RECIBOS_SERCO SER ON TBL.CODIGO_POLIZA = SER.CODIGO_POLIZA_SERCO
				AND TBL.CODIGO_RECIBO = SER.CODIGO_RECIBO_SERCO
				AND TBL.CODIGO_SUPLEMENTO_ORI = SER.CODIGO_SUPLEMENTO
				--AND TBL.ESTADO_RECIBO = SER.ESTADO_RECIBO
				--AND TBL.CODIGO_SUPLEMENTO = SER.CODIGO_SUPLEMENTO
				--AND TBL.PRODUCTO_CONTABLE = SER.PRODUCTO_CONTABLE
				--TGV 20251027- descomentamos los row_num por errores de duplicados
			--	AND SER.ROW_NUM = 1
		--	WHERE TBL.ROW_NUM_INS = 1.
				AND SER.ROW_NUM = 1
			WHERE TBL.ROW_NUM_INS = 1
			and not exists(select codigo_poliza from ext.garantias_recibo REC 
				where REC.codigo_poliza = tbl.codigo_poliza 
				and rec.codigo_recibo = v_const_cod_recibo_anul_serco 
				and rec.estado_recibo = v_const_recibo_cobrado 
				and rec.codigo_suplemento = SER.CODIGO_SUPLEMENTO   
				and rec.producto_contable = ser.producto_contable
			)
			;
				
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT anulaciones de SERCO en GARANTIAS_RECIBO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		
		
		
		
		
		
		--FT_COMPRUEBA_ANULACION
		--Montamos la tabla base
		--Todos los recibos que entran por aqu? ir?an marcados como anulaci?n normal = 1
		TBL_COMPRUEBA_ANULACION = SELECT TBL.*
									FROM :TBL_ANULACIONES TBL
									WHERE TBL.RECIBO_COBRADO > 0 
										OR (TBL.RECIBO_COBRADO = 0 AND PERIODO_ANULACION >= 365)
								;
		
		v_num_rows = RECORD_COUNT(:TBL_COMPRUEBA_ANULACION);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_COMPRUEBA_ANULACION creada: ' || v_num_rows || ' filas. Se calculan las bajas si hay RECIBO_COBRADO o PERIODO_ANULACION >= 365 dias', i_log_count, i_id_proceso, 'debug');
		
		--Se filtran aquellas anulaciones en que RECIBO_COBRADO sea = 0 para hacer la b?squeda de FT_COD_AGENTE_COMMISSIONS
		--PENDIENTE!!
		
		
		--Datos principales para el c?lculo de extornos obtenidos de recibos ya cobrados
		TBL_C_REC = SELECT REC.CODIGO_POLIZA
						, REC.CODIGO_RECIBO
						, REC.CODIGO_UNICO_AGENTE
						, REC.CODIGO_AGENTE_ORIGINAL
						, REC.INSPECTOR
						, REC.OFICINA_COBRADORA
						, REC.OFICINA_GESTORA
						, REC.CODIGO_AGENTE_COMMISSIONS
						, REC.FECHA_EFECTO_RECIBO
						, REC.FECHA_VTO_RECIBO
						, REC.DISTRITO_COBRO
						, REC.CODIGO_SINIESTRO
						, GAR_REC.PRIMA_BRUTA_RECIBO
						, GAR_REC.RECARGO
						, GAR_REC.PORCENTAJE_BONIFICACION
						, GAR_REC.PORCENTAJE_NIVELADA
						, GAR_REC.INCREMENTO_PRIMA_ANUAL
						, GAR_REC.PRIMA_UNICA
						, 1 AS AGENTES_ENCONTRADOS
						, ROW_NUMBER() OVER (
							PARTITION BY SUBSTR(REC.CODIGO_POLIZA,1,LENGTH(REC.CODIGO_POLIZA)-1)--, REC.CODIGO_RECIBO, REC.CODIGO_SUPLEMENTO, REC.ESTADO_RECIBO
							ORDER BY REC.FECHA_COBRO ASC
						) AS ROW_NUM
					FROM EXT.GARANTIAS_RECIBO GAR_REC
					RIGHT JOIN EXT.RECIBOS REC ON GAR_REC.CODIGO_POLIZA = REC.CODIGO_POLIZA
						AND GAR_REC.CODIGO_RECIBO = REC.CODIGO_RECIBO
						AND GAR_REC.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
						AND GAR_REC.ESTADO_RECIBO = REC.ESTADO_RECIBO
					WHERE EXISTS (SELECT 1
									FROM :TBL_COMPRUEBA_ANULACION TBL
									WHERE REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%')
						AND REC.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_especificos_66)
						AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
						AND REC.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrggpp
						AND ((REC.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' AND REC.TIPO_RECIBO IS NOT NULL) OR (REC.TIPO_RECIBO IS NULL AND RIGHT(REC.CODIGO_POLIZA,1) NOT IN ('X','S')))
						AND REC.CODIGO_SUPLEMENTO = 0
					ORDER BY REC.FECHA_COBRO
				;
				
		v_num_rows = RECORD_COUNT(:TBL_C_REC);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_REC creada: ' || v_num_rows || ' filas. Datos principales para el c?lculo de extornos obtenidos de recibos ya cobrados', i_log_count, i_id_proceso, 'debug');
		
		--Se modifican los datos necesarios en TBL_COMPRUEBA_ANULACION seg?n el recibo cobrado encontrado
		TBL_RECIBO_TRATADO = SELECT TBL.IDENTIFICADOR
									, TBL.FILE_NAME
									, TBL.ESTADO
									, TBL.FECHA_MODIFICACION
									, TBL.ZONA_EXPLOTACION
									, TBL.CODIGO_AGENTE_ZONA
									, TBL.CODIGO_POLIZA
									, TBL.CODIGO_RECIBO
									, TBL.PERMANENCIA
									, TBL.TIPO_RECIBO
									, TBL.ESTADO_RECIBO
									, TBL.FECHA_COBRO
									, TBL.FECHA_COMPENSACION
									, IFNULL(REC.FECHA_EFECTO_RECIBO,TBL.FECHA_EFECTO_RECIBO) AS FECHA_EFECTO_RECIBO
									, IFNULL(REC.FECHA_VTO_RECIBO,TBL.FECHA_VTO_RECIBO) AS FECHA_VTO_RECIBO
									, TBL.TIPO_MOVIMIENTO
									, TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
									, TBL.VALOR_POLIZA
									, IFNULL(REC.CODIGO_UNICO_AGENTE,TBL.CODIGO_UNICO_AGENTE) AS CODIGO_UNICO_AGENTE
									, IFNULL(REC.CODIGO_AGENTE_ORIGINAL,TBL.CODIGO_AGENTE_ORIGINAL) AS CODIGO_AGENTE_ORIGINAL
									, IFNULL(REC.INSPECTOR,TBL.INSPECTOR) AS INSPECTOR
									, IFNULL(REC.OFICINA_COBRADORA,TBL.OFICINA_COBRADORA) AS OFICINA_COBRADORA
									, IFNULL(REC.OFICINA_GESTORA,TBL.OFICINA_GESTORA) AS OFICINA_GESTORA
									, TBL.MARCA_RECUPERADO
									, TBL.MARCA_CUENTA
									, TBL.PRIMER_RECIBO
									, TBL.ASEGURADOS_NETOS
									, TBL.AUMENTO_ASEGURADOS
									, TBL.EXCLUIDO_COMISIONES
									, TBL.BONIFICACION_POLIZA
									, TBL.DISMINUCION_PRIMA
									, TBL.TIPO_RECUPERACION
									, TBL.ES_PERMANENCIA_20
									, IFNULL(REC.CODIGO_AGENTE_COMMISSIONS,TBL.CODIGO_AGENTE_COMMISSIONS) AS CODIGO_AGENTE_COMMISSIONS
									, TBL.FECHA_EMISION_REC
									, TBL.FCHA_EFECTO_SUPLEMENTO
									, TBL.CODIGO_SUPLEMENTO
									, IFNULL(REC.DISTRITO_COBRO,TBL.DISTRITO_COBRO) AS DISTRITO_COBRO
									, IFNULL(REC.CODIGO_SINIESTRO,TBL.CODIGO_SINIESTRO) AS CODIGO_SINIESTRO
									, TBL.PERIODO_ANULACION
        							, TBL.RAMO
        							, TBL.MOTIVO_ALTA
        							, TBL.FECHA_BAJA
        							, TBL.MOTIVO_BAJA
        							, TBL.RECIBO_COBRADO
        							, TBL.RECIBO_COBRADO_SERCO
        							, TBL.FECHA_EMISION_POLIZA --para RRPP
								FROM :TBL_COMPRUEBA_ANULACION TBL
								LEFT JOIN :TBL_C_REC REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
									AND REC.ROW_NUM = 1 --Nos quedamos con un ?nico registro
								;
								
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_TRATADO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_TRATADO creada: ' || v_num_rows || ' filas. Se modifican los datos necesarios en TBL_COMPRUEBA_ANULACION seg?n el recibo cobrado encontrado', i_log_count, i_id_proceso, 'debug');
		
		--Se modifican los datos necesarios en TBL_GARANTIA_RECIBO_TRATADO seg?n el recibo cobrado encontrado
		TBL_GARANTIAS_RECIBO_TRATADO = SELECT TBL.IDENTIFICADOR
											, TBL.ID_RECIBO
											, TBL.FILE_NAME
											, TBL.ESTADO
											, TBL.FECHA_MODIFICACION
											, TBL.PORCENTAJE_COMISION_CALCULAD
											, TBL.IMPORTE_COMISION
											, IFNULL(REC.PRIMA_UNICA,TBL.PRIMA_UNICA) AS PRIMA_UNICA
											, TBL.NUM_ORDEN_MOVIMIENTO
											, TBL.AUMENTO_CAPITALES_GARANTIA
											, TBL.PRIMA_NETA_ANUALIZADA
											, TBL.PORC_COMISION_NP
											, TBL.PORC_COMISION_CONSERVACION
											, TBL.CODIGO_SUPLEMENTO
											, TBL.PORC_COMISION_COBRO
											, TBL.CODIGO_POLIZA
											, TBL.CODIGO_RECIBO
											, TBL.PRODUCTO_CONTABLE
											, TBL.ESTADO_RECIBO
											, TBL.PRIMA_NETA_RECIBO
											, IFNULL(REC.PRIMA_BRUTA_RECIBO,TBL.PRIMA_BRUTA_RECIBO) AS PRIMA_BRUTA_RECIBO
											, IFNULL(REC.RECARGO,TBL.RECARGO) AS RECARGO
											, IFNULL(REC.PORCENTAJE_BONIFICACION,TBL.PORCENTAJE_BONIFICACION) AS PORCENTAJE_BONIFICACION
											, IFNULL(REC.INCREMENTO_PRIMA_ANUAL,TBL.INCREMENTO_PRIMA_ANUAL) AS INCREMENTO_PRIMA_ANUAL
											, TBL.PRIMA_COMISIONABLE
											, TBL.UNIDAD_DE_POLIZA
											, TBL.MESES_COBRADOS
											, TBL.FECHA_ALTA_GAR_POL
											, TBL.FECHA_BAJA_GAR_POL
											, IFNULL(REC.PORCENTAJE_NIVELADA,TBL.PORCENTAJE_NIVELADA) AS PORCENTAJE_NIVELADA
											, TBL.PERIODO_EXTORNABLE
											, TBL.INDICADOR_COMISION_CALCULADA
											, TBL.INDICADOR_PORCENTAJE_CALCULA
										FROM :TBL_GARANTIAS_RECIBO TBL
										LEFT JOIN :TBL_C_REC REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
											AND REC.ROW_NUM = 1 --Nos quedamos con un ?nico registro
										;
										
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_TRATADO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_TRATADO creada: ' || v_num_rows || ' filas. Se modifican los datos necesarios en TBL_GARANTIAS_RECIBO seg?n el recibo cobrado encontrado', i_log_count, i_id_proceso, 'debug');
		
		--RECIBOS tratados de RRGG
		TBL_RECIBO_TRATADO_RRGG = SELECT TBL.*
									FROM :TBL_RECIBO_TRATADO TBL
									WHERE RAMO = :v_const_ramo_rrgg
								;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_TRATADO_RRGG);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_TRATADO_RRGG creada: ' || v_num_rows || ' filas. RECIBOS tratados de RRGG', i_log_count, i_id_proceso, 'debug');
		
		--GARANTIAS_RECIBO tratadas de RRGG
		TBL_GARANTIAS_RECIBO_TRATADO_RRGG = SELECT GAR_REC.*
											FROM :TBL_GARANTIAS_RECIBO_TRATADO GAR_REC
											WHERE EXISTS (SELECT 1 
															FROM :TBL_RECIBO_TRATADO_RRGG REC
															WHERE REC.CODIGO_POLIZA = GAR_REC.CODIGO_POLIZA
																AND REC.CODIGO_RECIBO = GAR_REC.CODIGO_RECIBO
														)
											;
		
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_TRATADO_RRGG);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_TRATADO_RRGG creada: ' || v_num_rows || ' filas. GARANTIAS_RECIBO tratadas de RRGG', i_log_count, i_id_proceso, 'debug');
		
		--FT_RRGG_ANUL_PRIMER_ANIO
		--FT_PRIMER_RECIBO_COBRADO
		--Se recupera la PRIMA_NETA del primer recibo cobrado a partir de las GARANTIAS_RECIBO
		TBL_C_PRIMA_NETA_PRIMER_ANIO = SELECT REC.CODIGO_POLIZA
												, REC.CODIGO_RECIBO
												, (-1) * GAR_REC.PRIMA_NETA_RECIBO AS PRIMA_NETA_RECIBO
												, :v_const_recibos_especificos_71 AS PERMANENCIA
												, 0 AS PRIMA_COMISIONABLE
												, -1 AS UNIDAD_DE_POLIZA
												, 1 AS PRIMER_RECIBO_COBRADO
												, ROW_NUMBER() OVER (
													--20250918 RMF: Se elimina la partici?n del ROW_NUMBER por CODIGO_RECIBO, CODIGO_SUPLEMENTO y ESTADO_RECIBO para evitar problemas de elegir mal el recibo origen en caso de varios recibos 71 o 66
													PARTITION BY SUBSTR(REC.CODIGO_POLIZA,1,LENGTH(REC.CODIGO_POLIZA)-1)--, REC.CODIGO_RECIBO, REC.CODIGO_SUPLEMENTO, REC.ESTADO_RECIBO
													ORDER BY REC.FECHA_COBRO ASC
												) AS ROW_NUM
											FROM EXT.GARANTIAS_RECIBO GAR_REC
											RIGHT JOIN EXT.RECIBOS REC ON GAR_REC.CODIGO_POLIZA = REC.CODIGO_POLIZA
												AND GAR_REC.CODIGO_RECIBO = REC.CODIGO_RECIBO
												AND GAR_REC.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
												AND GAR_REC.ESTADO_RECIBO = REC.ESTADO_RECIBO
											WHERE EXISTS (SELECT 1
															FROM :TBL_RECIBO_TRATADO_RRGG TBL
															WHERE REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
																AND PERIODO_ANULACION < 365 --Anulaci?n de primer a?o
											)
												AND REC.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_especificos_66)
												AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
												AND REC.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrggpp
												AND ((REC.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' AND REC.TIPO_RECIBO IS NOT NULL) OR (REC.TIPO_RECIBO IS NULL AND RIGHT(REC.CODIGO_POLIZA,1) NOT IN ('X','S')))
												AND REC.CODIGO_SUPLEMENTO = 0
											ORDER BY REC.FECHA_COBRO
										;
				
		v_num_rows = RECORD_COUNT(:TBL_C_PRIMA_NETA_PRIMER_ANIO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_PRIMA_NETA_PRIMER_ANIO creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de primer a?o', i_log_count, i_id_proceso, 'debug');
		
		--Se crean las tablas que recogen todos los cambios necesarios en RECIBOS y GARANTIAS_RECIBO
		TBL_RECIBOS_PARA_UPDATE_PRIMER_ANIO = SELECT TBL.IDENTIFICADOR
													, TBL.FILE_NAME
													, TBL.ESTADO
													, TBL.FECHA_MODIFICACION
													, TBL.ZONA_EXPLOTACION
													, TBL.CODIGO_AGENTE_ZONA
													, TBL.CODIGO_POLIZA
													, TBL.CODIGO_RECIBO
													, REC.PERMANENCIA
													, TBL.TIPO_RECIBO
													, TBL.ESTADO_RECIBO
													, TBL.FECHA_COBRO
													, TBL.FECHA_COMPENSACION
													, TBL.FECHA_EFECTO_RECIBO
													, TBL.FECHA_VTO_RECIBO
													, TBL.TIPO_MOVIMIENTO
													, TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
													, TBL.VALOR_POLIZA
													, TBL.CODIGO_UNICO_AGENTE
													, TBL.CODIGO_AGENTE_ORIGINAL
													, TBL.INSPECTOR
													, TBL.OFICINA_COBRADORA
													, TBL.OFICINA_GESTORA
													, TBL.MARCA_RECUPERADO
													, TBL.MARCA_CUENTA
													, TBL.PRIMER_RECIBO
													, TBL.ASEGURADOS_NETOS
													, TBL.AUMENTO_ASEGURADOS
													, TBL.EXCLUIDO_COMISIONES
													, TBL.BONIFICACION_POLIZA
													, TBL.DISMINUCION_PRIMA
													, TBL.TIPO_RECUPERACION
													, TBL.ES_PERMANENCIA_20
													, TBL.CODIGO_AGENTE_COMMISSIONS
													, TBL.FECHA_EMISION_REC
													, TBL.FCHA_EFECTO_SUPLEMENTO
													, TBL.CODIGO_SUPLEMENTO
													, TBL.DISTRITO_COBRO
													, TBL.CODIGO_SINIESTRO
													, TBL.PERIODO_ANULACION
				        							, TBL.RAMO
				        							, TBL.MOTIVO_ALTA
				        							, TBL.FECHA_BAJA
				        							, TBL.MOTIVO_BAJA
				        							, TBL.RECIBO_COBRADO
				        							, TBL.RECIBO_COBRADO_SERCO
				        							, IFNULL(REC.PRIMER_RECIBO_COBRADO,0) AS PRIMER_RECIBO_COBRADO
												FROM :TBL_RECIBO_TRATADO_RRGG TBL
												LEFT JOIN :TBL_C_PRIMA_NETA_PRIMER_ANIO REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
													AND REC.ROW_NUM = 1 --Nos quedamos con un ?nico registro
												;
												
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_PARA_UPDATE_PRIMER_ANIO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_PARA_UPDATE_PRIMER_ANIO creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de primer a?o', i_log_count, i_id_proceso, 'debug');
		
		TBL_GARANTIAS_RECIBO_PARA_UPDATE_PRIMER_ANIO = SELECT TBL.IDENTIFICADOR
															, TBL.ID_RECIBO
															, TBL.FILE_NAME
															, TBL.ESTADO
															, TBL.FECHA_MODIFICACION
															, TBL.PORCENTAJE_COMISION_CALCULAD
															, TBL.IMPORTE_COMISION
															, TBL.PRIMA_UNICA
															, TBL.NUM_ORDEN_MOVIMIENTO
															, TBL.AUMENTO_CAPITALES_GARANTIA
															, TBL.PRIMA_NETA_ANUALIZADA
															, TBL.PORC_COMISION_NP
															, TBL.PORC_COMISION_CONSERVACION
															, TBL.CODIGO_SUPLEMENTO
															, TBL.PORC_COMISION_COBRO
															, TBL.CODIGO_POLIZA
															, TBL.CODIGO_RECIBO
															, TBL.PRODUCTO_CONTABLE
															, TBL.ESTADO_RECIBO
															, CASE WHEN IFNULL(REC.PRIMER_RECIBO_COBRADO,0) = 0 
																		THEN TBL.PRIMA_NETA_RECIBO
																		ELSE REC.PRIMA_NETA_RECIBO
															END AS PRIMA_NETA_RECIBO --Si no encuentra recibo cobrado dejamos la prima neta que viene, sino la cambiamos por la del cobrado
															, TBL.PRIMA_BRUTA_RECIBO
															, TBL.RECARGO
															, TBL.PORCENTAJE_BONIFICACION
															, TBL.INCREMENTO_PRIMA_ANUAL
															, REC.PRIMA_COMISIONABLE
															, REC.UNIDAD_DE_POLIZA
															, TBL.MESES_COBRADOS
															, TBL.FECHA_ALTA_GAR_POL
															, TBL.FECHA_BAJA_GAR_POL
															, TBL.PORCENTAJE_NIVELADA
															, TBL.PERIODO_EXTORNABLE
															, TBL.INDICADOR_COMISION_CALCULADA
															, TBL.INDICADOR_PORCENTAJE_CALCULA
															, IFNULL(REC.PRIMER_RECIBO_COBRADO,0) AS PRIMER_RECIBO_COBRADO
														FROM :TBL_GARANTIAS_RECIBO_TRATADO_RRGG TBL
														LEFT JOIN :TBL_C_PRIMA_NETA_PRIMER_ANIO REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
															AND REC.ROW_NUM = 1 --Nos quedamos con un ?nico registro
														;
												
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_PARA_UPDATE_PRIMER_ANIO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_PARA_UPDATE_PRIMER_ANIO creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de primer a?o', i_log_count, i_id_proceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRGG PRIMER A?O en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_RECIBOS_PARA_UPDATE_PRIMER_ANIO TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.RECIBOS x
			SET x.ESTADO = :v_const_calculo_status_ok
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
				, x.PERMANENCIA = TBL.PERMANENCIA
				, x.FECHA_EFECTO_RECIBO = TBL.FECHA_EFECTO_RECIBO
				, x.FECHA_VTO_RECIBO = TBL.FECHA_VTO_RECIBO
				, x.CODIGO_UNICO_AGENTE = TBL.CODIGO_UNICO_AGENTE
				, x.CODIGO_AGENTE_ORIGINAL = TBL.CODIGO_AGENTE_ORIGINAL
				, x.INSPECTOR = TBL.INSPECTOR
				, x.OFICINA_COBRADORA = TBL.OFICINA_COBRADORA
				, x.OFICINA_GESTORA = TBL.OFICINA_GESTORA
				, x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_AGENTE_COMMISSIONS
				, x.DISTRITO_COBRO = TBL.DISTRITO_COBRO
				, x.CODIGO_SINIESTRO = TBL.CODIGO_SINIESTRO
				, x.FECHA_COBRO = :v_fecha_cobro
			FROM EXT.RECIBOS x, :TBL_RECIBOS_PARA_UPDATE_PRIMER_ANIO TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRGG PRIMER A?O en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--Se actualizan los datos de RECIBOS y GARANTIAS_RECIBOS para anulaciones de primer a?o
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRGG PRIMER A?O en GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_PARA_UPDATE_PRIMER_ANIO TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.GARANTIAS_RECIBO x
	        SET x.ESTADO = :v_const_calculo_status_ok
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        	, x.PRIMA_NETA_RECIBO = TBL.PRIMA_NETA_RECIBO
	        	, x.PRIMA_COMISIONABLE = TBL.PRIMA_COMISIONABLE
	        	, x.UNIDAD_DE_POLIZA = TBL.UNIDAD_DE_POLIZA
	        	, x.PRIMA_BRUTA_RECIBO = (-1) * TBL.PRIMA_BRUTA_RECIBO
	        	, x.RECARGO = (-1) * TBL.RECARGO
	        	, x.PORCENTAJE_BONIFICACION = TBL.PORCENTAJE_BONIFICACION
	        	, x.PORCENTAJE_NIVELADA = TBL.PORCENTAJE_NIVELADA
	        	, x.INCREMENTO_PRIMA_ANUAL = (-1) * TBL.INCREMENTO_PRIMA_ANUAL
	        	, x.PRIMA_UNICA = TBL.PRIMA_UNICA
			FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_PARA_UPDATE_PRIMER_ANIO TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRGG PRIMER A?O en GARANTIAS_RECIBO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--FT_RRGG_ANUL_MAS_SEGUN_ANIO
		--Se tratan de manera conjunta los casos de anulaciones de segundo a?o m?s de segundo a?o PERIODO_ANULACION >= 365
		--Tablas base: TBL_RECIBO_TRATADO_RRGG y TBL_GARANTIAS_RECIBO_TRATADO_RRGG
		--En este caso no es necesario ir a buscar datos del recibo cobrado, por lo que el proceso se simplifica
		TBL_RECIBOS_PARA_UPDATE_MASSEGUN_ANIO = SELECT TBL.IDENTIFICADOR
													, TBL.FILE_NAME
													, TBL.ESTADO
													, TBL.FECHA_MODIFICACION
													, TBL.ZONA_EXPLOTACION
													, TBL.CODIGO_AGENTE_ZONA
													, TBL.CODIGO_POLIZA
													, TBL.CODIGO_RECIBO
													, CASE WHEN TBL.PERIODO_ANULACION >= 730 --Anulaci?n de m?s de dos a?os
														THEN :v_const_permanencia_anu_mas2anio 
														ELSE CASE WHEN (TBL.PERIODO_ANULACION >= 365 AND TBL.PERIODO_ANULACION < 730) --Anulaci?n de segundo a?o
															THEN :v_const_permanencia_anu_2anio
														END
													END AS PERMANENCIA
													, TBL.TIPO_RECIBO
													, TBL.ESTADO_RECIBO
													, TBL.FECHA_COBRO
													, TBL.FECHA_COMPENSACION
													, TBL.FECHA_EFECTO_RECIBO
													, TBL.FECHA_VTO_RECIBO
													, TBL.TIPO_MOVIMIENTO
													, TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
													, TBL.VALOR_POLIZA
													, TBL.CODIGO_UNICO_AGENTE
													, TBL.CODIGO_AGENTE_ORIGINAL
													, TBL.INSPECTOR
													, TBL.OFICINA_COBRADORA
													, TBL.OFICINA_GESTORA
													, TBL.MARCA_RECUPERADO
													, TBL.MARCA_CUENTA
													, TBL.PRIMER_RECIBO
													, TBL.ASEGURADOS_NETOS
													, TBL.AUMENTO_ASEGURADOS
													, TBL.EXCLUIDO_COMISIONES
													, TBL.BONIFICACION_POLIZA
													, TBL.DISMINUCION_PRIMA
													, TBL.TIPO_RECUPERACION
													, TBL.ES_PERMANENCIA_20
													, TBL.CODIGO_AGENTE_COMMISSIONS
													, TBL.FECHA_EMISION_REC
													, TBL.FCHA_EFECTO_SUPLEMENTO
													, TBL.CODIGO_SUPLEMENTO
													, TBL.DISTRITO_COBRO
													, TBL.CODIGO_SINIESTRO
													, TBL.PERIODO_ANULACION
				        							, TBL.RAMO
				        							, TBL.MOTIVO_ALTA
				        							, TBL.FECHA_BAJA
				        							, TBL.MOTIVO_BAJA
				        							, TBL.RECIBO_COBRADO
				        							, TBL.RECIBO_COBRADO_SERCO
												FROM :TBL_RECIBO_TRATADO_RRGG TBL
												WHERE TBL.PERIODO_ANULACION >= 365 --Recibos anulados de dos a?os o posterior
												;
												
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_PARA_UPDATE_MASSEGUN_ANIO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_PARA_UPDATE_MASSEGUN_ANIO creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de segundo a?o y posteriores', i_log_count, i_id_proceso, 'debug');
		
		TBL_GARANTIAS_RECIBO_PARA_UPDATE_MASSEGUN_ANIO = SELECT TBL.IDENTIFICADOR
															, TBL.ID_RECIBO
															, TBL.FILE_NAME
															, TBL.ESTADO
															, TBL.FECHA_MODIFICACION
															, TBL.PORCENTAJE_COMISION_CALCULAD
															, TBL.IMPORTE_COMISION
															, TBL.PRIMA_UNICA
															, TBL.NUM_ORDEN_MOVIMIENTO
															, TBL.AUMENTO_CAPITALES_GARANTIA
															, TBL.PRIMA_NETA_ANUALIZADA
															, TBL.PORC_COMISION_NP
															, TBL.PORC_COMISION_CONSERVACION
															, TBL.CODIGO_SUPLEMENTO
															, TBL.PORC_COMISION_COBRO
															, TBL.CODIGO_POLIZA
															, TBL.CODIGO_RECIBO
															, TBL.PRODUCTO_CONTABLE
															, TBL.ESTADO_RECIBO
															, 0 AS PRIMA_NETA_RECIBO
															, TBL.PRIMA_BRUTA_RECIBO
															, TBL.RECARGO
															, TBL.PORCENTAJE_BONIFICACION
															, TBL.INCREMENTO_PRIMA_ANUAL
															, 0 AS PRIMA_COMISIONABLE
															, -1 AS UNIDAD_DE_POLIZA
															, TBL.MESES_COBRADOS
															, TBL.FECHA_ALTA_GAR_POL
															, TBL.FECHA_BAJA_GAR_POL
															, TBL.PORCENTAJE_NIVELADA
															, TBL.PERIODO_EXTORNABLE
															, TBL.INDICADOR_COMISION_CALCULADA
															, TBL.INDICADOR_PORCENTAJE_CALCULA
														FROM :TBL_GARANTIAS_RECIBO_TRATADO_RRGG TBL
														WHERE EXISTS (SELECT 1 
																		FROM :TBL_RECIBO_TRATADO_RRGG REC
																		WHERE TBL.CODIGO_POLIZA = REC.CODIGO_POLIZA
																			AND TBL.CODIGO_RECIBO = REC.CODIGO_RECIBO
																			AND REC.PERIODO_ANULACION >= 365 --Recibos anulados de dos a?os o posterior
															
																	)
														;
												
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_PARA_UPDATE_MASSEGUN_ANIO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_PARA_UPDATE_MASSEGUN_ANIO creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de m?s de segundo a?o y posteriores', i_log_count, i_id_proceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRGG m?s de SEGUNDO A?O en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_RECIBOS_PARA_UPDATE_MASSEGUN_ANIO TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.RECIBOS x
			SET x.ESTADO = :v_const_calculo_status_ok
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
				, x.PERMANENCIA = TBL.PERMANENCIA
				, x.FECHA_EFECTO_RECIBO = TBL.FECHA_EFECTO_RECIBO
				, x.FECHA_VTO_RECIBO = TBL.FECHA_VTO_RECIBO
				, x.CODIGO_UNICO_AGENTE = TBL.CODIGO_UNICO_AGENTE
				, x.CODIGO_AGENTE_ORIGINAL = TBL.CODIGO_AGENTE_ORIGINAL
				, x.INSPECTOR = TBL.INSPECTOR
				, x.OFICINA_COBRADORA = TBL.OFICINA_COBRADORA
				, x.OFICINA_GESTORA = TBL.OFICINA_GESTORA
				, x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_AGENTE_COMMISSIONS
				, x.DISTRITO_COBRO = TBL.DISTRITO_COBRO
				, x.CODIGO_SINIESTRO = TBL.CODIGO_SINIESTRO
				, x.FECHA_COBRO = :v_fecha_cobro
			FROM EXT.RECIBOS x, :TBL_RECIBOS_PARA_UPDATE_MASSEGUN_ANIO TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRGG m?s de SEGUNDO A?O en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--Se actualizan los datos de RECIBOS y GARANTIAS_RECIBOS para anulaciones de primer a?o
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRGG m?s de SEGUNDO A?O en GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_PARA_UPDATE_MASSEGUN_ANIO TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.GARANTIAS_RECIBO x
	        SET x.ESTADO = :v_const_calculo_status_ok
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        	, x.PRIMA_NETA_RECIBO = TBL.PRIMA_NETA_RECIBO
	        	, x.PRIMA_COMISIONABLE = TBL.PRIMA_COMISIONABLE
	        	, x.UNIDAD_DE_POLIZA = TBL.UNIDAD_DE_POLIZA
	        	, x.PRIMA_BRUTA_RECIBO = (-1) * TBL.PRIMA_BRUTA_RECIBO
	        	, x.RECARGO = (-1) * TBL.RECARGO
	        	, x.PORCENTAJE_BONIFICACION = TBL.PORCENTAJE_BONIFICACION
	        	, x.PORCENTAJE_NIVELADA = TBL.PORCENTAJE_NIVELADA
	        	, x.INCREMENTO_PRIMA_ANUAL = (-1) * TBL.INCREMENTO_PRIMA_ANUAL
	        	, x.PRIMA_UNICA = TBL.PRIMA_UNICA
			FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_PARA_UPDATE_MASSEGUN_ANIO TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRGG m?s de SEGUNDO A?O en GARANTIAS_RECIBO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--RECIBOS tratados de RRPP
		TBL_RECIBO_TRATADO_RRPP = SELECT TBL.*
									FROM :TBL_RECIBO_TRATADO TBL
									WHERE RAMO = :v_const_ramo_rrpp
										AND (TBL.MOTIVO_BAJA <> :v_const_baja_sustitucion
											OR TBL.MOTIVO_BAJA <> :v_const_baja_error
											OR TBL.MOTIVO_BAJA <> :v_const_baja_rescision
											OR TBL.MOTIVO_BAJA <> :v_const_baja_vto
											OR TBL.MOTIVO_BAJA <> :v_const_baja_rescate
											OR TBL.MOTIVO_BAJA <> :v_const_baja_ya_fue_baja
										)
								;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_TRATADO_RRPP);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_TRATADO_RRPP creada: ' || v_num_rows || ' filas. RECIBOS tratados de RRPP', i_log_count, i_id_proceso, 'debug');
		
		--GARANTIAS_RECIBO tratadas de RRGG
		TBL_GARANTIAS_RECIBO_TRATADO_RRPP = SELECT GAR_REC.*
											FROM :TBL_GARANTIAS_RECIBO_TRATADO GAR_REC
											WHERE EXISTS (SELECT 1 
															FROM :TBL_RECIBO_TRATADO_RRPP REC
															WHERE REC.CODIGO_POLIZA = GAR_REC.CODIGO_POLIZA
																AND REC.CODIGO_RECIBO = GAR_REC.CODIGO_RECIBO
														)
											;
		
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_TRATADO_RRPP);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_TRATADO_RRPP creada: ' || v_num_rows || ' filas. GARANTIAS_RECIBO tratadas de RRPP', i_log_count, i_id_proceso, 'debug');
		
		--FT_RRPP_ANUL_PRIMER_ANIO
		--Se tratan las anulaciones de RRPP de primer a?o PERIODO_ANULACION < 365
		--FT_PRIMER_RECIBO_COBRADO
		--Se recupera la PRIMA_NETA del primer recibo cobrado a partir de las GARANTIAS_RECIBO
		TBL_C_PRIMA_NETA_PRIMER_ANIO_RRPP = SELECT REC.CODIGO_POLIZA
													, REC.CODIGO_RECIBO
													, (-1) * GAR_REC.PRIMA_NETA_RECIBO AS PRIMA_NETA_RECIBO
													, :v_const_recibos_especificos_71 AS PERMANENCIA
													, GAR_REC.PRIMA_COMISIONABLE AS PRIMA_COMISIONABLE --Dejamos valor por defecto. Este valor puede cambiar en los siguientes pasos
													, -1 AS UNIDAD_DE_POLIZA
													, 1 AS PRIMER_RECIBO_COBRADO
													, ROW_NUMBER() OVER (
														--20250918 RMF: Se elimina la partici?n del ROW_NUMBER por CODIGO_RECIBO, CODIGO_SUPLEMENTO y ESTADO_RECIBO para evitar problemas de elegir mal el recibo origen en caso de varios recibos 71 o 66
														PARTITION BY SUBSTR(REC.CODIGO_POLIZA,1,LENGTH(REC.CODIGO_POLIZA)-1)--, REC.CODIGO_RECIBO, REC.CODIGO_SUPLEMENTO, REC.ESTADO_RECIBO
														ORDER BY REC.FECHA_COBRO ASC
													) AS ROW_NUM
												FROM EXT.GARANTIAS_RECIBO GAR_REC
												RIGHT JOIN EXT.RECIBOS REC ON GAR_REC.CODIGO_POLIZA = REC.CODIGO_POLIZA
													AND GAR_REC.CODIGO_RECIBO = REC.CODIGO_RECIBO
													AND GAR_REC.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
													AND GAR_REC.ESTADO_RECIBO = REC.ESTADO_RECIBO
												WHERE EXISTS (SELECT 1
																FROM :TBL_RECIBO_TRATADO_RRPP TBL
																WHERE REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
																	AND PERIODO_ANULACION < 365 --Anulaci?n de primer a?o
												)
													AND REC.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_especificos_66)
													AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
													AND REC.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrggpp
													AND ((REC.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' AND REC.TIPO_RECIBO IS NOT NULL) OR (REC.TIPO_RECIBO IS NULL AND RIGHT(REC.CODIGO_POLIZA,1) NOT IN ('X','S')))
													AND REC.CODIGO_SUPLEMENTO = 0
												ORDER BY REC.FECHA_COBRO
											;
				
		v_num_rows = RECORD_COUNT(:TBL_C_PRIMA_NETA_PRIMER_ANIO_RRPP);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_PRIMA_NETA_PRIMER_ANIO_RRPP creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de primer a?o de RRPP', i_log_count, i_id_proceso, 'debug');
		
		--Se crean las tablas que recogen todos los cambios necesarios en RECIBOS y GARANTIAS_RECIBO
		TBL_RECIBOS_PRIMER_ANIO_RRPP = SELECT TBL.IDENTIFICADOR
												, TBL.FILE_NAME
												, TBL.ESTADO
												, TBL.FECHA_MODIFICACION
												, TBL.ZONA_EXPLOTACION
												, TBL.CODIGO_AGENTE_ZONA
												, TBL.CODIGO_POLIZA
												, TBL.CODIGO_RECIBO
												, REC.PERMANENCIA
												, TBL.TIPO_RECIBO
												, TBL.ESTADO_RECIBO
												, TBL.FECHA_COBRO
												, TBL.FECHA_COMPENSACION
												, TBL.FECHA_EFECTO_RECIBO
												, TBL.FECHA_VTO_RECIBO
												, TBL.TIPO_MOVIMIENTO
												, TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
												, TBL.VALOR_POLIZA
												, TBL.CODIGO_UNICO_AGENTE
												, TBL.CODIGO_AGENTE_ORIGINAL
												, TBL.INSPECTOR
												, TBL.OFICINA_COBRADORA
												, TBL.OFICINA_GESTORA
												, TBL.MARCA_RECUPERADO
												, TBL.MARCA_CUENTA
												, TBL.PRIMER_RECIBO
												, TBL.ASEGURADOS_NETOS
												, TBL.AUMENTO_ASEGURADOS
												, TBL.EXCLUIDO_COMISIONES
												, TBL.BONIFICACION_POLIZA
												, TBL.DISMINUCION_PRIMA
												, TBL.TIPO_RECUPERACION
												, TBL.ES_PERMANENCIA_20
												, TBL.CODIGO_AGENTE_COMMISSIONS
												, TBL.FECHA_EMISION_REC
												, TBL.FCHA_EFECTO_SUPLEMENTO
												, TBL.CODIGO_SUPLEMENTO
												, TBL.DISTRITO_COBRO
												, TBL.CODIGO_SINIESTRO
												, TBL.PERIODO_ANULACION
			        							, TBL.RAMO
			        							, TBL.MOTIVO_ALTA
			        							, TBL.FECHA_BAJA
			        							, TBL.MOTIVO_BAJA
			        							, TBL.RECIBO_COBRADO
			        							, TBL.RECIBO_COBRADO_SERCO
			        							, IFNULL(REC.PRIMER_RECIBO_COBRADO,0) AS PRIMER_RECIBO_COBRADO
											FROM :TBL_RECIBO_TRATADO_RRPP TBL
											LEFT JOIN :TBL_C_PRIMA_NETA_PRIMER_ANIO_RRPP REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
												AND REC.ROW_NUM = 1 --Nos quedamos con un ?nico registro
											;
												
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_PRIMER_ANIO_RRPP);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_PRIMER_ANIO_RRPP creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de primer a?o RRPP', i_log_count, i_id_proceso, 'debug');
		
		TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP = SELECT TBL.IDENTIFICADOR
														, TBL.ID_RECIBO
														, TBL.FILE_NAME
														, TBL.ESTADO
														, TBL.FECHA_MODIFICACION
														, TBL.PORCENTAJE_COMISION_CALCULAD
														, TBL.IMPORTE_COMISION
														, TBL.PRIMA_UNICA
														, TBL.NUM_ORDEN_MOVIMIENTO
														, TBL.AUMENTO_CAPITALES_GARANTIA
														, TBL.PRIMA_NETA_ANUALIZADA
														, TBL.PORC_COMISION_NP
														, TBL.PORC_COMISION_CONSERVACION
														, TBL.CODIGO_SUPLEMENTO
														, TBL.PORC_COMISION_COBRO
														, TBL.CODIGO_POLIZA
														, TBL.CODIGO_RECIBO
														, TBL.PRODUCTO_CONTABLE
														, TBL.ESTADO_RECIBO
														, CASE WHEN IFNULL(REC.PRIMER_RECIBO_COBRADO,0) = 0 
															THEN TBL.PRIMA_NETA_RECIBO
															ELSE REC.PRIMA_NETA_RECIBO
														END AS PRIMA_NETA_RECIBO --Si no encuentra recibo cobrado dejamos la prima neta que viene, si no la cambiamos por la del cobrado
														, TBL.PRIMA_BRUTA_RECIBO
														, TBL.RECARGO
														, TBL.PORCENTAJE_BONIFICACION
														, TBL.INCREMENTO_PRIMA_ANUAL
														, CASE WHEN IFNULL(REC.PRIMER_RECIBO_COBRADO,0) = 0
															THEN 0 
															ELSE TBL.PRIMA_COMISIONABLE 
														END AS PRIMA_COMISIONABLE --Si no encuentra recibo cobrado dejamos un 0, si no dejamos la que viene en la anulaci?n
														, REC.UNIDAD_DE_POLIZA
														, TBL.MESES_COBRADOS
														, TBL.FECHA_ALTA_GAR_POL
														, TBL.FECHA_BAJA_GAR_POL
														, TBL.PORCENTAJE_NIVELADA
														, TBL.PERIODO_EXTORNABLE
														, TBL.INDICADOR_COMISION_CALCULADA
														, TBL.INDICADOR_PORCENTAJE_CALCULA
														, IFNULL(REC.PRIMER_RECIBO_COBRADO,0) AS PRIMER_RECIBO_COBRADO
													FROM :TBL_GARANTIAS_RECIBO_TRATADO_RRPP TBL
													LEFT JOIN :TBL_C_PRIMA_NETA_PRIMER_ANIO_RRPP REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
														AND REC.ROW_NUM = 1 --Nos quedamos con un ?nico registro
													;

		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de primer a?o RRPP', i_log_count, i_id_proceso, 'debug');
		
		--Hacemos el UPDATE en RECIBOS y GARANTIAS_RECIBO para aquellos casos en los que no se ha encontrado primer recibo cobrado (PRIMER_RECIBO_COBRADO = 0)
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRPP PRIMER A?O para recibo cobrado no encontrado en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_RECIBOS_PRIMER_ANIO_RRPP TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						--AND TBL.PRIMER_RECIBO_COBRADO = 0 --Se comenta esta l?nea porque en Oracle no se diferencia entre recibo cobrado y no. Ver comentarios l?nea 1377
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.RECIBOS x
			SET x.ESTADO = :v_const_calculo_status_ok
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
				, x.PERMANENCIA = TBL.PERMANENCIA
				, x.FECHA_EFECTO_RECIBO = TBL.FECHA_EFECTO_RECIBO
				, x.FECHA_VTO_RECIBO = TBL.FECHA_VTO_RECIBO
				, x.CODIGO_UNICO_AGENTE = TBL.CODIGO_UNICO_AGENTE
				, x.CODIGO_AGENTE_ORIGINAL = TBL.CODIGO_AGENTE_ORIGINAL
				, x.INSPECTOR = TBL.INSPECTOR
				, x.OFICINA_COBRADORA = TBL.OFICINA_COBRADORA
				, x.OFICINA_GESTORA = TBL.OFICINA_GESTORA
				, x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_AGENTE_COMMISSIONS
				, x.DISTRITO_COBRO = TBL.DISTRITO_COBRO
				, x.CODIGO_SINIESTRO = TBL.CODIGO_SINIESTRO
				, x.FECHA_COBRO = :v_fecha_cobro
			FROM EXT.RECIBOS x, :TBL_RECIBOS_PRIMER_ANIO_RRPP TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA like SUBSTR(TBL.CODIGO_POLIZA,1,LENGTH(TBL.CODIGO_POLIZA)-1) || '%'--AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = :v_const_cod_recibo_anul_rrggpp
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				--AND TBL.PRIMER_RECIBO_COBRADO = 0 --Se comenta esta l?nea porque en Oracle no se diferencia entre recibo cobrado y no. Ver comentarios l?nea 1377
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRPP PRIMER A?O para recibo cobrado no encontrado en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--Se actualizan los datos de RECIBOS y GARANTIAS_RECIBOS para anulaciones de primer a?o
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRPP PRIMER A?O para recibo cobrado no encontrado en GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
						--AND TBL.PRIMER_RECIBO_COBRADO = 0 --Se comenta esta l?nea porque en Oracle no se diferencia entre recibo cobrado y no. Ver comentarios l?nea 1377
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.GARANTIAS_RECIBO x
	        SET x.ESTADO = :v_const_calculo_status_ok
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        	, x.PRIMA_NETA_RECIBO = TBL.PRIMA_NETA_RECIBO
	        	, x.PRIMA_COMISIONABLE = TBL.PRIMA_COMISIONABLE
	        	, x.UNIDAD_DE_POLIZA = TBL.UNIDAD_DE_POLIZA
	        	, x.PRIMA_BRUTA_RECIBO = (-1) * TBL.PRIMA_BRUTA_RECIBO
	        	, x.RECARGO = (-1) * TBL.RECARGO
	        	, x.PORCENTAJE_BONIFICACION = TBL.PORCENTAJE_BONIFICACION
	        	, x.PORCENTAJE_NIVELADA = TBL.PORCENTAJE_NIVELADA
	        	, x.INCREMENTO_PRIMA_ANUAL = (-1) * TBL.INCREMENTO_PRIMA_ANUAL
	        	, x.PRIMA_UNICA = TBL.PRIMA_UNICA
			FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
				--AND TBL.PRIMER_RECIBO_COBRADO = 0 --Se comenta esta l?nea porque en Oracle no se diferencia entre recibo cobrado y no. Ver comentarios l?nea 1377
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRPP PRIMER A?O para recibo cobrado no encontrado en GARANTIAS_RECIBO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--Se comenta la siguiente parte. En Oracle la llamada a FT_ES_ANTICIPADA_RRGG_RRPP devuelve un valor de 0 o 1 para saber si es comisi?n anticipada
		--Pero fuera de la funci?n se compara con las constantes N o S, por lo que no entra por ninguna de las condiciones
		--SQL_0009_INYC_LP_PK_EXTORNOS_RRGG_RRPP.sql l?neas 745-800
		--Separamos los recibos con la marca de PRIMER_RECIBO_COBRADO = 1
		/*
		TBL_RECIBOS_PRIMER_ANIO_RRPP_REC_COBRADO = SELECT TBL.*
													FROM :TBL_RECIBOS_PRIMER_ANIO_RRPP TBL
													WHERE TBL.PRIMER_RECIBO_COBRADO = 1
												;
												
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_PRIMER_ANIO_RRPP_REC_COBRADO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_PRIMER_ANIO_RRPP_REC_COBRADO creada: ' || v_num_rows || ' filas. Nos quedamos con los recibos con marca de PRIMER_RECIBO_COBRADO = 1', i_log_count, i_id_proceso, 'debug');
		
		--Separamos los Garantias de recibo con la marca de PRIMER_RECIBO_COBRADO = 1
		TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP_REC_COBRADO = SELECT TBL.*
															FROM :TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP TBL
															WHERE TBL.PRIMER_RECIBO_COBRADO = 1
														;
												
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP_REC_COBRADO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP_REC_COBRADO creada: ' || v_num_rows || ' filas. Nos quedamos con los garant?as de recibo con marca de PRIMER_RECIBO_COBRADO = 1', i_log_count, i_id_proceso, 'debug');
		
		--FT_ES_ANTICIPADA_RRGG_RRPP
		--Indica si el agente comisiona anticipadamente
		--Se generan las tablas temporales de productos y c?digos de agente
		
		TBL_GEN_PRODUCTOS = SELECT * FROM EXT.VW_GEN_PRODUCTOS;
		v_num_rows = RECORD_COUNT(:TBL_GEN_PRODUCTOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_PRODUCTOS creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Guardamos en una variable tabla informaci?n sobre jerarqu?a
		TBL_GEN_CODIGOS_AGENTE = SELECT * FROM EXT.VW_CODIGOS_DE_AGENTE VW
								WHERE 1=1
									AND VW.CODIGO_OCASO <> '0' 
									AND VW.CODIGO_OCASO <> '000000000' 
									AND VW.CODIGO_OCASO <> '0000000000'
								;
								
		v_num_rows = RECORD_COUNT(:TBL_GEN_CODIGOS_AGENTE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_CODIGOS_AGENTE creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
		
		TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP_INFO_PRODUC = SELECT TBL.*
																	, IFNULL(PRO.COMISION_ANTICIPADA,0) AS PROD_ANTICIPADA
																	, PRO.PAGO_MENSUAL
															FROM :TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP_REC_COBRADO TBL
															LEFT JOIN :TBL_GEN_PRODUCTOS PRO ON PRO.CODIGO = TBL.PRODUCTO_CONTABLE
															;
		
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP_INFO_PRODUC);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_PRIMER_ANIO_RRPP_INFO_PRODUC creada: ' || v_num_rows || ' filas. Se a?ade informaci?n de PROD_ANTICIPADA y PAGO_MENSUAL a las GARANTIAS_RECIBO de primer a?o para recibos ya cobrados', i_log_count, i_id_proceso, 'debug');
		
		TBL_RECIBOS_PRIMER_ANIO_RRPP_INFO_AGENTE = SELECT TBL.*
														, AGE.TIPO_AGENTE
														, CASE WHEN POL.SUSTITUCION_INCENDIOS IS NULL 
															THEN IFNULL(AGE.ANTICIPADA_RRPP_OCASO,0)
															ELSE CASE WHEN POL.SUSTITUCION_INCENDIOS = 'S'
																THEN 1
																ELSE 0
															END
														END AS ANTICIPIDA_RRPP_OCASO
														, IFNULL(POL.FORMA_PAGO,0)
													FROM :TBL_RECIBOS_PRIMER_ANIO_RRPP_REC_COBRADO TBL
													LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
														AND AGE.EFFECTIVESTARTDATE <= TBL.FECHA_EMISION_POLIZA
														AND AGE.EFFECTIVEENDDATE > TBL.FECHA_EMISION_POLIZA
														AND AGE.FECHA_INI_PART <= TBL.FECHA_EMISION_POLIZA
														AND AGE.FECHA_FIN_PART > TBL.FECHA_EMISION_POLIZA
													LEFT JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
												;
												
		--No se incluyen las llamadas a FT_ES_DIFERENCIAL, FT_PRIMA_COMISIONABLE_EXT
		
		*/
		
		--FT_RRPP_ANUL_SEGUN_ANIO
		--FT_ES_COND_ESP_RESCATE
		--Se obtiene si el producto tiene condici?n especial de rescate para calcular a parte la prima comisionable a extornar. Si no tiene condiciones, la prima comisionable es 0
		--Se tratan los casos de anulaciones de segundo a?o y posteriores PERIODO_ANULACION >= 365
		--Tablas base: TBL_RECIBO_TRATADO_RRPP y TBL_GARANTIAS_RECIBO_TRATADO_RRPP
		
		--FT_PRIMA_COMISIONABLE_EXT
		--Se obtiene la prima comisionable a partir del recibo cobrado
		TBL_C_PRIMA_COMISIONABLE_SEGUNDO_ANIO_RRPP = SELECT REC.CODIGO_POLIZA
															, REC.CODIGO_RECIBO
															, IFNULL(SUM(GAR_REC.PRIMA_COMISIONABLE),0) AS PRIMA_PAGADA 
															, ROW_NUMBER() OVER (
																--20250918 RMF: Se elimina la partici?n del ROW_NUMBER por CODIGO_RECIBO, CODIGO_SUPLEMENTO y ESTADO_RECIBO para evitar problemas de elegir mal el recibo origen en caso de varios recibos 71 o 66
																PARTITION BY SUBSTR(REC.CODIGO_POLIZA,1,LENGTH(REC.CODIGO_POLIZA)-1)--, REC.CODIGO_RECIBO, REC.CODIGO_SUPLEMENTO, REC.ESTADO_RECIBO
																ORDER BY REC.FECHA_COBRO ASC
															) AS ROW_NUM
														FROM EXT.GARANTIAS_RECIBO GAR_REC
														RIGHT JOIN EXT.RECIBOS REC ON GAR_REC.CODIGO_POLIZA = REC.CODIGO_POLIZA
															AND GAR_REC.CODIGO_RECIBO = REC.CODIGO_RECIBO
															AND GAR_REC.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
															AND GAR_REC.ESTADO_RECIBO = REC.ESTADO_RECIBO
														WHERE EXISTS (SELECT 1
																		FROM :TBL_RECIBO_TRATADO_RRPP TBL
																		WHERE REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
																			AND PERIODO_ANULACION >= 365 --Anulaci?n de segundo a?o y posteriores
														)
															AND REC.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_especificos_66)
															AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
															AND REC.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrggpp
															AND ((REC.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' AND REC.TIPO_RECIBO IS NOT NULL) OR (REC.TIPO_RECIBO IS NULL AND RIGHT(REC.CODIGO_POLIZA,1) NOT IN ('X','S')))
															AND REC.CODIGO_SUPLEMENTO = 0
														GROUP BY REC.CODIGO_POLIZA
																, REC.CODIGO_RECIBO
																, REC.CODIGO_SUPLEMENTO
																, REC.ESTADO_RECIBO
																, REC.FECHA_COBRO
														ORDER BY REC.FECHA_COBRO
													;
				
		v_num_rows = RECORD_COUNT(:TBL_C_PRIMA_COMISIONABLE_SEGUNDO_ANIO_RRPP);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_PRIMA_COMISIONABLE_SEGUNDO_ANIO_RRPP creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de segundo a?o y posteriores de RRPP', i_log_count, i_id_proceso, 'debug');
		
		TBL_PRIMA_COMISIONABLE_SEGUN_ANIO_RRPP_TRATADO_MENSUALIDADES = SELECT TBL.CODIGO_POLIZA
																				, TBL.CODIGO_RECIBO
																				, TBL.PRIMA_PAGADA
																				, CASE WHEN MONTHS_BETWEEN(POL.FECHA_EFECTO_POLIZA,POL.FECHA_BAJA) > 12
																					THEN 12
																					ELSE MONTHS_BETWEEN(POL.FECHA_EFECTO_POLIZA,POL.FECHA_BAJA)
																				END AS MENSUALIDADES
																		FROM :TBL_C_PRIMA_COMISIONABLE_SEGUNDO_ANIO_RRPP TBL
																		LEFT JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
																	;
																	
		v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMISIONABLE_SEGUN_ANIO_RRPP_TRATADO_MENSUALIDADES);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_PRIMA_COMISIONABLE_SEGUN_ANIO_RRPP_TRATADO_MENSUALIDADES creada: ' || v_num_rows || ' filas. Se obtienen n?mero de mensualidades de anulaci?n de segundo a?o y posteriores de RRPP', i_log_count, i_id_proceso, 'debug');
		
		TBL_PRIMA_COMISIONABLE_EXT_SEGUN_ANIO_RRPP = SELECT TBL.CODIGO_POLIZA
															, TBL.CODIGO_RECIBO
															, 0 - (TBL.PRIMA_PAGADA - (TBL.PRIMA_PAGADA * TBL.MENSUALIDADES/12)) AS PRIMA_COMISIONABLE_EXT
													FROM :TBL_PRIMA_COMISIONABLE_SEGUN_ANIO_RRPP_TRATADO_MENSUALIDADES TBL
												;
																	
		v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMISIONABLE_EXT_SEGUN_ANIO_RRPP);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_PRIMA_COMISIONABLE_EXT_SEGUN_ANIO_RRPP creada: ' || v_num_rows || ' filas. Se obtiene prima comisionable a extornar de segundo a?o y posteriores de RRPP', i_log_count, i_id_proceso, 'debug');
		
		TBL_RECIBOS_RRPP_SEGUN_ANIO = SELECT TBL.IDENTIFICADOR
												, TBL.FILE_NAME
												, TBL.ESTADO
												, TBL.FECHA_MODIFICACION
												, TBL.ZONA_EXPLOTACION
												, TBL.CODIGO_AGENTE_ZONA
												, TBL.CODIGO_POLIZA
												, TBL.CODIGO_RECIBO
												, CASE WHEN TBL.PERIODO_ANULACION >= 730 --Anulaci?n de m?s de dos a?os
														THEN :v_const_permanencia_anu_mas2anio 
														ELSE CASE WHEN (TBL.PERIODO_ANULACION >= 365 AND TBL.PERIODO_ANULACION < 730) --Anulaci?n de segundo a?o
															THEN :v_const_permanencia_anu_2anio
														END
													END AS PERMANENCIA
												, TBL.TIPO_RECIBO
												, TBL.ESTADO_RECIBO
												, TBL.FECHA_COBRO
												, TBL.FECHA_COMPENSACION
												, TBL.FECHA_EFECTO_RECIBO
												, TBL.FECHA_VTO_RECIBO
												, TBL.TIPO_MOVIMIENTO
												, TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
												, TBL.VALOR_POLIZA
												, TBL.CODIGO_UNICO_AGENTE
												, TBL.CODIGO_AGENTE_ORIGINAL
												, TBL.INSPECTOR
												, TBL.OFICINA_COBRADORA
												, TBL.OFICINA_GESTORA
												, TBL.MARCA_RECUPERADO
												, TBL.MARCA_CUENTA
												, TBL.PRIMER_RECIBO
												, TBL.ASEGURADOS_NETOS
												, TBL.AUMENTO_ASEGURADOS
												, TBL.EXCLUIDO_COMISIONES
												, TBL.BONIFICACION_POLIZA
												, TBL.DISMINUCION_PRIMA
												, TBL.TIPO_RECUPERACION
												, TBL.ES_PERMANENCIA_20
												, TBL.CODIGO_AGENTE_COMMISSIONS
												, TBL.FECHA_EMISION_REC
												, TBL.FCHA_EFECTO_SUPLEMENTO
												, TBL.CODIGO_SUPLEMENTO
												, TBL.DISTRITO_COBRO
												, TBL.CODIGO_SINIESTRO
												, TBL.PERIODO_ANULACION
			        							, TBL.RAMO
			        							, TBL.MOTIVO_ALTA
			        							, TBL.FECHA_BAJA
			        							, TBL.MOTIVO_BAJA
			        							, TBL.RECIBO_COBRADO
			        							, TBL.RECIBO_COBRADO_SERCO
											FROM :TBL_RECIBO_TRATADO_RRPP TBL
											LEFT JOIN :TBL_PRIMA_COMISIONABLE_EXT_SEGUN_ANIO_RRPP REC ON REC.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
											WHERE TBL.PERIODO_ANULACION >= 365
											;
												
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_RRPP_SEGUN_ANIO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_RRPP_SEGUN_ANIO creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de RRPP de segundo a?o y posteriores', i_log_count, i_id_proceso, 'debug');
		
		
		
		TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO_COND_RESCATE = SELECT TBL.*
																, PRO.COND_ESP_RESCATE
																, SUBSTR(TBL.PRODUCTO_CONTABLE,3) AS PRODUC_ESP_RED_TOTAL
															FROM :TBL_GARANTIAS_RECIBO_TRATADO_RRPP TBL
															LEFT JOIN :TBL_GEN_PRODUCTOS PRO ON CODIGO = TBL.PRODUCTO_CONTABLE
														;
		
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO_COND_RESCATE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO_COND_RESCATE creada: ' || v_num_rows || ' filas. Se a?ade COND_ESP_RESCATE a los datos de anulaci?n de RRPP de segundo a?o' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--La funci?n FT_PRIMA_COMISIONABLE_EXT vuelve a llamar internamente para obtener si SUBSTR(PRODUCTO_CONTABLE,3) tiene condici?n especial, sin embargo ese substring no se encuentra en la vista de productos
		--por lo que no entra en la condici?n que modifica la prima comisionable (l?neas 349-370 de SQL_0009_INYC_LP_PK_EXTORNOS_RRGG_RRPP.sql en Oracle)
		
		TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO = SELECT TBL.IDENTIFICADOR
													, TBL.ID_RECIBO
													, TBL.FILE_NAME
													, TBL.ESTADO
													, TBL.FECHA_MODIFICACION
													, TBL.PORCENTAJE_COMISION_CALCULAD
													, TBL.IMPORTE_COMISION
													, TBL.PRIMA_UNICA
													, TBL.NUM_ORDEN_MOVIMIENTO
													, TBL.AUMENTO_CAPITALES_GARANTIA
													, TBL.PRIMA_NETA_ANUALIZADA
													, TBL.PORC_COMISION_NP
													, TBL.PORC_COMISION_CONSERVACION
													, TBL.CODIGO_SUPLEMENTO
													, TBL.PORC_COMISION_COBRO
													, TBL.CODIGO_POLIZA
													, TBL.CODIGO_RECIBO
													, TBL.PRODUCTO_CONTABLE
													, TBL.ESTADO_RECIBO
													, 0 AS PRIMA_NETA_RECIBO
													, TBL.PRIMA_BRUTA_RECIBO
													, TBL.RECARGO
													, TBL.PORCENTAJE_BONIFICACION
													, TBL.INCREMENTO_PRIMA_ANUAL
													, CASE WHEN PRO.COND_ESP_RESCATE = :v_const_si
														THEN ROUND(IFNULL(PRI.PRIMA_COMISIONABLE_EXT,0),2) 
														ELSE 0
													END AS PRIMA_COMISIONABLE
													, -1 AS UNIDAD_DE_POLIZA
													, TBL.MESES_COBRADOS
													, TBL.FECHA_ALTA_GAR_POL
													, TBL.FECHA_BAJA_GAR_POL
													, TBL.PORCENTAJE_NIVELADA
													, TBL.PERIODO_EXTORNABLE
													, TBL.INDICADOR_COMISION_CALCULADA
													, TBL.INDICADOR_PORCENTAJE_CALCULA
												FROM :TBL_GARANTIAS_RECIBO_TRATADO_RRPP TBL
												LEFT JOIN :TBL_PRIMA_COMISIONABLE_EXT_SEGUN_ANIO_RRPP PRI ON PRI.CODIGO_POLIZA LIKE TBL.CODIGO_POLIZA || '%'
												LEFT JOIN :TBL_GEN_PRODUCTOS PRO ON CODIGO = TBL.PRODUCTO_CONTABLE
												WHERE EXISTS (SELECT 1 
																FROM :TBL_RECIBOS_RRPP_SEGUN_ANIO REC
																WHERE TBL.CODIGO_POLIZA = REC.CODIGO_POLIZA
																	AND TBL.CODIGO_RECIBO = REC.CODIGO_RECIBO
																	AND REC.PERIODO_ANULACION >= 365
															)
												;
												
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO creada: ' || v_num_rows || ' filas. Se actualizan datos de anulaci?n de RRPP de segundo a?o', i_log_count, i_id_proceso, 'debug');
		
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRPP de SEGUNDO A?O y posteriores en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_RECIBOS_RRPP_SEGUN_ANIO TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.RECIBOS x
			SET x.ESTADO = :v_const_calculo_status_ok
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
				, x.PERMANENCIA = TBL.PERMANENCIA
				, x.FECHA_EFECTO_RECIBO = TBL.FECHA_EFECTO_RECIBO
				, x.FECHA_VTO_RECIBO = TBL.FECHA_VTO_RECIBO
				, x.CODIGO_UNICO_AGENTE = TBL.CODIGO_UNICO_AGENTE
				, x.CODIGO_AGENTE_ORIGINAL = TBL.CODIGO_AGENTE_ORIGINAL
				, x.INSPECTOR = TBL.INSPECTOR
				, x.OFICINA_COBRADORA = TBL.OFICINA_COBRADORA
				, x.OFICINA_GESTORA = TBL.OFICINA_GESTORA
				, x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_AGENTE_COMMISSIONS
				, x.DISTRITO_COBRO = TBL.DISTRITO_COBRO
				, x.CODIGO_SINIESTRO = TBL.CODIGO_SINIESTRO
				, x.FECHA_COBRO = :v_fecha_cobro
			FROM EXT.RECIBOS x, :TBL_RECIBOS_RRPP_SEGUN_ANIO TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRPP de SEGUNDO A?O y posteriores en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--Se actualizan los datos de RECIBOS y GARANTIAS_RECIBOS para anulaciones de primer a?o
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE Extornos RRPP de SEGUNDO A?O y posteriores en GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.GARANTIAS_RECIBO x
	        SET x.ESTADO = :v_const_calculo_status_ok
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        	, x.PRIMA_NETA_RECIBO = TBL.PRIMA_NETA_RECIBO
	        	, x.PRIMA_COMISIONABLE = TBL.PRIMA_COMISIONABLE
	        	, x.UNIDAD_DE_POLIZA = TBL.UNIDAD_DE_POLIZA
	        	, x.PRIMA_BRUTA_RECIBO = (-1) * TBL.PRIMA_BRUTA_RECIBO
	        	, x.RECARGO = (-1) * TBL.RECARGO
	        	, x.PORCENTAJE_BONIFICACION = TBL.PORCENTAJE_BONIFICACION
	        	, x.PORCENTAJE_NIVELADA = TBL.PORCENTAJE_NIVELADA
	        	, x.INCREMENTO_PRIMA_ANUAL = (-1) * TBL.INCREMENTO_PRIMA_ANUAL
	        	, x.PRIMA_UNICA = TBL.PRIMA_UNICA
			FROM EXT.GARANTIAS_RECIBO x, :TBL_GARANTIAS_RECIBO_RRPP_SEGUN_ANIO TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				--AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				--AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				--AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE Extornos RRPP de SEGUNDO A?O y posteriores en GARANTIAS_RECIBO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		
		
		--Update de la tabla RECIBOS para poner MARCA_CUENTA a N en caso de que se trate de una anulaci?n de SERCO y no una anulaci?n normal
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE1 MARCA_CUENTA a N para Anulaciones SERCO que no son Anulaciones normales en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_ANULACIONES TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND x.PERMANENCIA = TBL.PERMANENCIA
						AND TBL.ANUL_SERCO = 1
						AND TBL.ANUL_NORMAL = 0
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.RECIBOS x
	        SET x.ESTADO = :v_const_calculo_status_ok
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        	, x.MARCA_CUENTA = :v_const_n
			FROM EXT.RECIBOS x, :TBL_ANULACIONES TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND x.PERMANENCIA = TBL.PERMANENCIA
				AND TBL.ANUL_SERCO = 1
				AND TBL.ANUL_NORMAL = 0
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE1 MARCA_CUENTA a N para Anulaciones SERCO que no son Anulaciones normales en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
		
		--Update de la tabla RECIBOS para poner MARCA_CUENTA a N en otros casos
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE2 MARCA_CUENTA a N para combinaciones de MOTIVO_BAJA, RAMO en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_ANULACIONES TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND ((TBL.ANUL_SERCO <> 1 AND TBL.ANUL_NORMAL <> 1)
							OR (TBL.RAMO = :v_const_ramo_rrgg AND TBL.MOTIVO_BAJA IN (:v_const_baja_sustitucion,:v_const_baja_error,:v_const_baja_vto,:v_const_baja_ya_fue_baja))
							OR (TBL.RAMO = :v_const_ramo_rrpp AND TBL.MOTIVO_BAJA IN (:v_const_baja_sustitucion,:v_const_baja_error,:v_const_baja_rescision,:v_const_baja_vto,:v_const_baja_rescate,:v_const_baja_ya_fue_baja)))
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
			UPDATE EXT.RECIBOS x
	        SET x.ESTADO = :v_const_calculo_status_ok
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        	, x.MARCA_CUENTA = :v_const_n
			FROM EXT.RECIBOS x, :TBL_ANULACIONES TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND ((TBL.ANUL_SERCO <> 1 AND TBL.ANUL_NORMAL <> 1)
					OR (TBL.RAMO = :v_const_ramo_rrgg AND TBL.MOTIVO_BAJA IN (:v_const_baja_sustitucion,:v_const_baja_error,:v_const_baja_vto,:v_const_baja_ya_fue_baja))
					OR (TBL.RAMO = :v_const_ramo_rrpp AND TBL.MOTIVO_BAJA IN (:v_const_baja_sustitucion,:v_const_baja_error,:v_const_baja_rescision,:v_const_baja_vto,:v_const_baja_rescate,:v_const_baja_ya_fue_baja)))
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE2 MARCA_CUENTA a N para combinaciones de MOTIVO_BAJA, RAMO en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info'); 
			
		END;
			
	END;
		
END
