CREATE or replace PROCEDURE EXT.SP_CALCULO_EXTORNOS_RRTT (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS


/*---------------------------------------------------------------------
	| Author: Tania Garcés Villanueva
	| Company: Inycom
	| Initial Version Date: 04-Marzo-2025
	|----------------------------------------------------------------------
	| Procedure Purpose: Procedimiento que se ejecuta desde el procedimineto de SP_CALCULO_RRGG, para calcular el ramo de RRTT
	|
	|
	| Version: 0.1	TGV 20250304		Initial Version.
	|
	-----------------------------------------------------------------------
*/
BEGIN
	
	USING SQLSCRIPT_STRING AS LIBRARY;
	

	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_existe_tabla INTEGER := 0;

	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_existen_extornos INTEGER := 0;
	DECLARE v_const_n VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_N;
	DECLARE v_const_s VARCHAR(1) :=  EXT.LIB_CONSTANTES:CONST_S;
	DECLARE v_const_s_1 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S_1;
	DECLARE v_const_n_0 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N_0;
	
	--CONSTANTES DE ESTADO
	DECLARE v_const_populate_status_ok		INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK; --2
	DECLARE v_const_calculo_status_ok		INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_OK; --6
	DECLARE v_const_calculo_status_error	INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_ERROR;--7
	
	--CONSTANTES CODIGO_RECIBO
	DECLARE v_const_cod_recibo_anul_rrtt VARCHAR2(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRTT;
	DECLARE v_const_cod_recibo_serco VARCHAR2(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_SERCO;
	
	DECLARE v_const_tipo_rec_anul_k5 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_ANUL_K5;
	 
	--CONSTANTES DE TIPOS RECIBOS
	DECLARE v_const_recibos_especificos_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
	DECLARE v_const_recibos_especificos_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
	DECLARE v_const_recibos_especificos_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
	DECLARE v_const_recibos_especificos_55 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_55;
	DECLARE v_const_recibos_cartera_72 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_72;
	DECLARE v_const_recibos_cartera_81 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_81;
	DECLARE v_const_recibos_especificos_11 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_11;
	
	--CONSTANTES ESTADO RECIBO
	DECLARE v_const_recibo_cobrado VARCHAR2(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
	DECLARE v_const_recibo_pendiente VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_PENDIENTE;
	DECLARE v_const_recibo_anulado VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBO_ANULADO;
	
	
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
																												
			ROLLBACK;
			
			--v_hayError := 1;
			v_num_rows := 0;
			
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_calculo_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = i_id_proceso;
			
			COMMIT;
			
			RESIGNAL;
		
		END;
		
	BEGIN
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, i_log_count, i_id_proceso, 'info');
		
		--FT_COMPRUEBA_EXTORNO
		--Nos quedamos con los recibos con codigo = C_ANUL_RRTT y STATUS = 2 para generar los extornos.
		--Debe existir la poliza con MOTIVO_BAJA no nulo.
		TBL_RECIBOS_ANULRRTT =
			SELECT R.*,P.MOTIVO_BAJA,P.FECHA_BAJA,P.IDENTIFICADOR AS ID_POLIZA
			FROM EXT.RECIBOS R
			INNER JOIN EXT.POLIZAS P ON R.CODIGO_POLIZA = P.CODIGO_POLIZA
			WHERE R.CODIGO_RECIBO = v_const_cod_recibo_anul_rrtt
				AND R.ESTADO = v_const_populate_status_ok
				AND R.FILE_NAME = i_file_name
		;
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANULRRTT);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_ANULRRTT creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--FT_BAJA_POLIZA
		--Guardamos los registros que tengan el MOTIVO_BAJA nulo ya que no se debe hacer nada con ellos.
		TBL_RECIBOS_ANULRRTT_SIN_MOTIVOBAJA =
			SELECT RA.*
			FROM :TBL_RECIBOS_ANULRRTT RA
			WHERE RA.MOTIVO_BAJA IS NULL
		;
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANULRRTT_SIN_MOTIVOBAJA);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_ANULRRTT_SIN_MOTIVOBAJA creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Tabla con la informacion de los diferentes Motivos de Baja.
		TBL_GEN_MOTIVOS_BAJA =
			SELECT MB.* FROM EXT.VW_MOTIVOS_BAJA MB
		;
		v_num_rows = RECORD_COUNT(:TBL_GEN_MOTIVOS_BAJA);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_MOTIVOS_BAJA creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Cruzamos en una nueva tabla los recibos a extornar con la informacion de los motivos de baja para quedarnos solo los que hay que extornar finalmente.
		TBL_RECIBOS_ANULRRTT_EXTORNABLE =
			SELECT RA.*
			FROM :TBL_RECIBOS_ANULRRTT RA
			INNER JOIN :TBL_GEN_MOTIVOS_BAJA MB ON RA.MOTIVO_BAJA = MB.CODIGO
			WHERE RA.MOTIVO_BAJA IS NOT NULL
				--AND IFNULL(MB.EXTORNABLE,'0') IN (v_const_s,v_const_s_1)
				AND IFNULL(MB.EXTORNABLE,'0') IN (v_const_s_1)
		;
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANULRRTT_EXTORNABLE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_ANULRRTT_EXTORNABLE creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Creamos una tabla que contenga los registros con MOTIVO_BAJA nulo o con la variable EXTORNABLE distinta de 1 o S.
		TBL_RECIBOS_ANULRRTT_SIN_EXTORNO =
			SELECT X.* FROM :TBL_RECIBOS_ANULRRTT_SIN_MOTIVOBAJA X 
			UNION ALL
			SELECT Y.* FROM :TBL_RECIBOS_ANULRRTT Y
			WHERE NOT EXISTS(
				SELECT 1 FROM :TBL_RECIBOS_ANULRRTT_EXTORNABLE Z
				WHERE Z.IDENTIFICADOR = Y.IDENTIFICADOR
					AND Z.CODIGO_POLIZA = Y.CODIGO_POLIZA
					AND Z.CODIGO_RECIBO = Y.CODIGO_RECIBO
					AND Z.CODIGO_SUPLEMENTO = Y.CODIGO_SUPLEMENTO
					AND Z.ESTADO_RECIBO = Y.ESTADO_RECIBO
			)
		;
		
		--Actualizamos en las tablas finales los registros de estos recibos con MOTIVO_BAJA nulo el estado y la fecha de modificacion para dejarlos finalizados.
		-- --POLIZAS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO
		--PENDIENTE!!!! NO VEO CLARA LA ACTUALIZACION DE POLIZAS PORQUE PODRIA HABER OTRO RECIBO DISTINTO DE LA ANULACION.
		-- BEGIN
		-- 	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		-- 		BEGIN
					
		-- 			ROLLBACK;
					
		-- 			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en POLIZAS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO - SQL_ERROR_MESSAGE: ' 
		-- 																										|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
		-- 																										|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
		-- 			UPDATE EXT.POLIZAS POL
		-- 			SET POL.ESTADO = v_const_calculo_status_error,
		-- 				POL.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		-- 			FROM EXT.POLIZAS POL, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
		-- 			WHERE POL.IDENTIFICADOR = TBL.ID_POLIZA
		-- 				AND POL.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		-- 			;
					
		-- 			COMMIT;
					
		-- 			RESIGNAL;
					
		-- 		END;
			
		-- 	UPDATE EXT.POLIZAS POL
		-- 	SET POL.ESTADO = v_const_calculo_status_ok,
		-- 		POL.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		-- 	FROM EXT.POLIZAS POL, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
		-- 	WHERE POL.IDENTIFICADOR = TBL.ID_POLIZA
		-- 		AND POL.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		-- 	;
		-- 	v_num_rows = ::rowcount;
			
		-- 	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en POLIZAS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO. Filas: ' 
		-- 														|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
			
		-- END;
		
		--RECIBOS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en RECIBOS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO - SQL_ERROR_MESSAGE: ' 
																												|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
																												|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
					UPDATE EXT.RECIBOS REC
					SET REC.ESTADO = v_const_calculo_status_error,
						REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS REC, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
					WHERE REC.IDENTIFICADOR = TBL.IDENTIFICADOR
						AND REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
			
			UPDATE EXT.RECIBOS REC
			SET REC.ESTADO = v_const_calculo_status_ok,
				REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.RECIBOS REC, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
			WHERE REC.IDENTIFICADOR = TBL.IDENTIFICADOR
				AND REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			;
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en RECIBOS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
			
		END;
		
		--GARANTIAS_RECIBO con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en GARANTIAS_RECIBO con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO - SQL_ERROR_MESSAGE: ' 
																												|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
																												|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
					UPDATE EXT.GARANTIAS_RECIBO GR
					SET GR.ESTADO = v_const_calculo_status_error,
						GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO GR, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
					WHERE GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND GR.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
			
			UPDATE EXT.GARANTIAS_RECIBO GR
			SET GR.ESTADO = v_const_calculo_status_ok,
				GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.GARANTIAS_RECIBO GR, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
			WHERE GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				AND GR.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			;
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en GARANTIAS_RECIBO con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
			
		END;
		
		-- --ASEGURADOS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO
		--PENDIENTE!!!! NO VEO CLARA LA ACTUALIZACION DE ASEGURADOS PORQUE PODRIA HABER OTRO RECIBO DISTINTO DE LA ANULACION.
		-- BEGIN
		-- 	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		-- 		BEGIN
					
		-- 			ROLLBACK;
					
		-- 			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en ASEGURADOS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO - SQL_ERROR_MESSAGE: ' 
		-- 																										|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
		-- 																										|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
		-- 			UPDATE EXT.ASEGURADOS A
		-- 			SET A.ESTADO = v_const_calculo_status_error,
		-- 				A.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		-- 			FROM EXT.ASEGURADOS A, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
		-- 			WHERE A.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		-- 			;
					
		-- 			COMMIT;
					
		-- 			RESIGNAL;
					
		-- 		END;
			
		-- 	UPDATE EXT.ASEGURADOS A
		-- 	SET A.ESTADO = v_const_calculo_status_ok,
		-- 		A.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		-- 	FROM EXT.ASEGURADOS A, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
		-- 	WHERE A.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		-- 	;
		-- 	v_num_rows = ::rowcount;
			
		-- 	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en ASEGURADOS con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO. Filas: ' 
		-- 														|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
			
		-- END;
		
		--GARANTIAS_ASEGURADO con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en GARANTIAS_ASEGURADO con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO - SQL_ERROR_MESSAGE: ' 
																												|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
																												|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
					UPDATE EXT.GARANTIAS_ASEGURADO GA
					SET GA.ESTADO = v_const_calculo_status_error,
						GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
					WHERE GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
			
			UPDATE EXT.GARANTIAS_ASEGURADO GA
			SET GA.ESTADO = v_const_calculo_status_ok,
				GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_RECIBOS_ANULRRTT_SIN_EXTORNO TBL
			WHERE GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			;
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en GARANTIAS_ASEGURADO con TBL_RECIBOS_ANULRRTT_SIN_EXTORNO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
			
		END;
		
		
		--Tabla con la informacion de los diferentes Productos.
		TBL_GEN_PRODUCTOS = SELECT * FROM EXT.VW_GEN_PRODUCTOS;
		v_num_rows = RECORD_COUNT(:TBL_GEN_PRODUCTOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_PRODUCTOS creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Cruzamos en una nueva tabla los recibos a extornar con la informacion de los productos para anadir el en cada registro el preiodo extornable.
		TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE =
			SELECT RAE.*,
				(CASE WHEN SUBSTR(RAE.CODIGO_POLIZA,1,3) = '012' AND PR.PERIODO_EXTORNABLE IS NULL THEN 17
					WHEN SUBSTR(RAE.CODIGO_POLIZA,1,3) = '032' AND PR.PERIODO_EXTORNABLE IS NULL THEN 18
					WHEN SUBSTR(RAE.CODIGO_POLIZA,3,1) <> '2' AND PR.PERIODO_EXTORNABLE IS NULL THEN 12
					ELSE IFNULL(PR.PERIODO_EXTORNABLE,0)
				END) AS PERIODO_EXTORNABLE
			FROM :TBL_RECIBOS_ANULRRTT_EXTORNABLE RAE
			INNER JOIN :TBL_GEN_PRODUCTOS PR ON PR.CODIGO = SUBSTR(RAE.CODIGO_POLIZA,1,7)
			WHERE (CASE WHEN SUBSTR(RAE.CODIGO_POLIZA,1,3) = '012' AND PR.PERIODO_EXTORNABLE IS NULL THEN 17
					WHEN SUBSTR(RAE.CODIGO_POLIZA,1,3) = '032' AND PR.PERIODO_EXTORNABLE IS NULL THEN 18
					WHEN SUBSTR(RAE.CODIGO_POLIZA,3,1) <> '2' AND PR.PERIODO_EXTORNABLE IS NULL THEN 12
					ELSE IFNULL(PR.PERIODO_EXTORNABLE,0)
				END) > 0
		;
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
	-------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE_DEBUG AS (SELECT * FROM :TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE_DEBUG' , i_log_count, i_id_proceso, 'debug');
	------------------------------
		
		
		--FT_EXTORNAR_RECUPERACIONES
		--Creamos una tabla con los registros de SERCO suceptibles de ser extornados.
		TBL_REC_EXT_SERCO =
			SELECT DISTINCT R.*,
				GR.PRODUCTO_CONTABLE,GR.PRIMA_COMISIONABLE,GR.PRIMA_NETA_RECIBO,--GR.IDENTIFICADOR AS ID_GAR_REC,
				GR.INCREMENTO_PRIMA_ANUAL,GR.PRIMA_BRUTA_RECIBO,GR.RECARGO,GR.PRIMA_NETA_ANUALIZADA,
				MONTHS_BETWEEN(R.FECHA_EFECTO_RECIBO,RAPE.FECHA_EFECTO_RECIBO) AS MESES_VIGENTES,
				IFNULL((
					SELECT SUM(ROUND(MONTHS_BETWEEN(RC.FECHA_EFECTO_RECIBO,RC.FECHA_VTO_RECIBO),2))
					FROM EXT.RECIBOS RC
					WHERE RC.CODIGO_POLIZA = RAPE.CODIGO_POLIZA
						AND RC.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
						AND RC.ESTADO_RECIBO = v_const_recibo_cobrado
						AND RC.MARCA_CUENTA = v_const_s
						AND RC.FECHA_EFECTO_RECIBO > R.FECHA_EFECTO_RECIBO
						AND RC.FECHA_EFECTO_RECIBO <= RAPE.FECHA_EFECTO_RECIBO
						AND RC.FECHA_COMPENSACION IN ( 
							SELECT MAX(T.FECHA_COMPENSACION)
							FROM EXT.RECIBOS T
							WHERE T.CODIGO_POLIZA = RC.CODIGO_POLIZA
								AND T.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
								AND T.ESTADO_RECIBO IN (v_const_recibo_cobrado,v_const_recibo_pendiente,v_const_recibo_anulado)
								AND T.CODIGO_RECIBO = RC.CODIGO_RECIBO
						)
				),0) AS RECIBOS_COBRADOS,
				RAPE.IDENTIFICADOR AS ID_REC,
				RAPE.FILE_NAME AS FILE_NAME_REC,
				RAPE.FECHA_COMPENSACION AS FEC_COMPENSACION_REC,
				RAPE.EXCLUIDO_COMISIONES AS EXCLUIDO_COMISIONES_REC,
				RAPE.DISMINUCION_PRIMA AS DISMINUCION_PRIMA_REC,
				RAPE.DISTRITO_COBRO AS DISTRITO_COBRO_REC,
				RAPE.PERIODO_EXTORNABLE
				 , ROW_NUMBER() OVER(
                      		PARTITION BY R.CODIGO_POLIZA, R.CODIGO_RECIBO, R.CODIGO_SUPLEMENTO
                      		ORDER BY R.CODIGO_POLIZA, R.CODIGO_RECIBO, R.CODIGO_SUPLEMENTO DESC
                      ) AS ROW_N
			FROM :TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE RAPE
			INNER JOIN EXT.RECIBOS R 
				ON RAPE.CODIGO_POLIZA = R.CODIGO_POLIZA
				AND RAPE.CODIGO_RECIBO <> R.CODIGO_RECIBO
				--AND RAPE.CODIGO_SUPLEMENTO = R.CODIGO_SUPLEMENTO
				--AND RAPE.ESTADO_RECIBO = R.ESTADO_RECIBO
			INNER JOIN EXT.GARANTIAS_RECIBO GR 
				ON R.CODIGO_POLIZA = GR.CODIGO_POLIZA
				AND R.CODIGO_RECIBO = GR.CODIGO_RECIBO
				AND R.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
				AND R.ESTADO_RECIBO = GR.ESTADO_RECIBO
			--Solo cogemos las recuperaciones que han comisionado. Ponemos >0 en lugar de =1 porque tambien hay que coger las que tengan un 2.
			WHERE R.EXCLUIDO_COMISIONES > v_const_n_0
				AND R.PERMANENCIA = v_const_recibos_especificos_11
				AND R.CODIGO_RECIBO = v_const_cod_recibo_serco
				--En SERCO solo se generan registros para el producto principal.
				AND GR.PRODUCTO_CONTABLE = SUBSTR(RAPE.CODIGO_POLIZA,1,7)
				--No tenemos en cuenta los que tengan PRIMA_COMISIONABLE = 0 porque ya se les ha extornado lo que les correspondia.
				AND GR.PRIMA_COMISIONABLE > 0
				AND R.FECHA_COMPENSACION < RAPE.FECHA_COMPENSACION
				--Comprobamos si hay alguna anulacion anterior de SERCO en la poliza y nos quedamos solo con recibos posteriores.
				AND R.FECHA_COMPENSACION > IFNULL((
					SELECT MAX(X.FECHA_COMPENSACION) FROM EXT.RECIBOS X 
					WHERE X.CODIGO_POLIZA = RAPE.CODIGO_POLIZA
						AND X.FILE_NAME <> RAPE.FILE_NAME
						AND X.CODIGO_RECIBO = v_const_cod_recibo_anul_rrtt
						AND X.PERMANENCIA = v_const_recibos_especificos_11
				),TO_DATE('19000101','YYYYMMDD'))
		;
		v_num_rows = RECORD_COUNT(:TBL_REC_EXT_SERCO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_REC_EXT_SERCO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		-------------------------------TABLA DEBUG PENDIENTE BORRAR
	    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_REC_EXT_SERCO_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_REC_EXT_SERCO_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_REC_EXT_SERCO_DEBUG AS (SELECT * FROM :TBL_REC_EXT_SERCO);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_REC_EXT_SERCO_DEBUG' , i_log_count, i_id_proceso, 'debug');
		------------------------------
		
		--Creamos una tabla que contenga los registros fuera de periodo extornable que no generar extorno para SERCO.
		TBL_REC_SERCO_SIN_EXTORNO =
			SELECT RES.*
			FROM :TBL_REC_EXT_SERCO RES
			--No extornamos si el periodo extornable es menor o igual que los RECIBOS_COBRADOS (para Eterna) o que los MESES_VIGENTES (para Ocaso).
			WHERE RES.PERIODO_EXTORNABLE <= (CASE WHEN SUBSTR(RES.CODIGO_POLIZA,1,2) = '03' THEN RES.RECIBOS_COBRADOS ELSE RES.MESES_VIGENTES END)
		;
		v_num_rows = RECORD_COUNT(:TBL_REC_SERCO_SIN_EXTORNO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_REC_SERCO_SIN_EXTORNO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Insertamos en la tabla de recibos los registros que no alcancen el periodo extornable.
		--RECIBOS con TBL_REC_EXT_SERCO
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en RECIBOS con TBL_REC_EXT_SERCO - SQL_ERROR_MESSAGE: ' 
																												|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
																												|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
					UPDATE EXT.RECIBOS REC
					SET REC.ESTADO = v_const_calculo_status_error,
						REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS REC, :TBL_REC_EXT_SERCO TBL
					WHERE REC.IDENTIFICADOR = TBL.ID_REC
						AND REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
				
			INSERT INTO EXT.RECIBOS
				SELECT 
					RES.ID_REC,						--IDENTIFICADOR
					RES.FILE_NAME_REC,				--FILE_NAME
					v_const_calculo_status_ok,		--ESTADO
					CURRENT_TIMESTAMP,				--FECHA_MODIFICACION
					RES.CODIGO_POLIZA,
					v_const_cod_recibo_anul_rrtt,	--CODIGO_RECIBO
					v_const_recibos_especificos_11,	--PERMANENCIA
					RES.TIPO_RECIBO,
					v_const_recibo_cobrado,			--ESTADO_RECIBO
					RES.FECHA_COBRO,
					RES.FEC_COMPENSACION_REC,		--FECHA_COMPENSACION
					RES.FECHA_EFECTO_RECIBO,
					RES.FECHA_VTO_RECIBO,
					RES.TIPO_MOVIMIENTO,
					NULL,							--PORCENTAJE_DESCUENTO_SOBRE_PC
					NULL,							--VALOR_POLIZA
					RES.CODIGO_UNICO_AGENTE,
					RES.CODIGO_AGENTE_ORIGINAL,
					RES.INSPECTOR,
					NULL,							--OFICINA_COBRADORA
					NULL,							--OFICINA_GESTORA
					NULL,							--MARCA_RECUPERADO
					v_const_s,						--MARCA_CUENTA
					NULL,							--PRIMER_RECIBO
					NULL,							--ASEGURADOS_NETOS
					NULL,							--AUMENTO_ASEGURADOS
					RES.EXCLUIDO_COMISIONES_REC,	--EXCLUIDO_COMISIONES
					NULL,							--BONIFICACION_POLIZA
					RES.DISMINUCION_PRIMA_REC,		--DISMINUCION_PRIMA
					RES.TIPO_RECUPERACION,
					NULL,							--ES_PERMANENCIA_20,
					RES.CODIGO_AGENTE_COMMISSIONS,
					RES.FECHA_COMPENSACION,			--FECHA_EMISION_REC
					NULL,							--FCHA_EFECTO_SUPLEMENTO,
					RES.CODIGO_SUPLEMENTO,
					RES.DISTRITO_COBRO_REC,			--DISTRITO_COBRO
					NULL,							--CODIGO_SINIESTRO
					NULL,							--ZONA_EXPLOTACION
					NULL							--CODIGO_AGENTE_ZONA
				FROM :TBL_REC_EXT_SERCO RES
				--Extornamos si el periodo extornable es mayor que los RECIBOS_COBRADOS (para Eterna) o que los MESES_VIGENTES (para Ocaso).
				WHERE RES.PERIODO_EXTORNABLE > (CASE WHEN SUBSTR(RES.CODIGO_POLIZA,1,2) = '03' THEN RES.RECIBOS_COBRADOS ELSE RES.MESES_VIGENTES END)
				AND ROW_N = 1
				
			;
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en RECIBOS con TBL_REC_EXT_SERCO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
		END;
		
		--Insertamos en la tabla de recibos los registros que no alcancen el periodo extornable.
		--GARANTIAS_RECIBO con TBL_REC_EXT_SERCO
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en GARANTIAS_RECIBO con TBL_REC_EXT_SERCO - SQL_ERROR_MESSAGE: ' 
																												|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
																												|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
					UPDATE EXT.GARANTIAS_RECIBO GR
					SET GR.ESTADO = v_const_calculo_status_error,
						GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO GR, :TBL_REC_EXT_SERCO TBL
					WHERE GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND GR.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
			
			INSERT INTO EXT.GARANTIAS_RECIBO
				SELECT
					--RES.ID_GAR_REC,						--IDENTIFICADOR (AUTONUMERICO)
					RES.ID_REC,								--ID_RECIBO
					RES.FILE_NAME_REC,						--FILE_NAME
					v_const_calculo_status_ok,				--ESTADO
					CURRENT_TIMESTAMP,						--FECHA_MODIFICACION
					RES.CODIGO_POLIZA,
					v_const_cod_recibo_anul_rrtt,			--CODIGO_RECIBO
					RES.PRODUCTO_CONTABLE,
					v_const_recibo_cobrado,					--ESTADO_RECIBO
					(CASE WHEN SUBSTR(RES.CODIGO_POLIZA,1,2) = '03'
						THEN RES.PRIMA_NETA_RECIBO * ((18 - RES.RECIBOS_COBRADOS)/18) * (-1)
						ELSE RES.PRIMA_NETA_RECIBO * (-1)
					END),									--PRIMA_NETA_RECIBO
					RES.PRIMA_BRUTA_RECIBO * (-1),			--PRIMA_BRUTA_RECIBO
					RES.RECARGO * (-1),						--RECARGO
					NULL,									--PORCENTAJE_BONIFICACION
					RES.INCREMENTO_PRIMA_ANUAL * (-1),		--INCREMENTO_PRIMA_ANUAL
					(CASE WHEN SUBSTR(RES.CODIGO_POLIZA,1,2) = '03'
						THEN RES.PRIMA_NETA_RECIBO * ((18 - RES.RECIBOS_COBRADOS)/18) * (-1)
						ELSE RES.PRIMA_NETA_RECIBO * (-1)
					END),									--PRIMA_COMISIONABLE
					NULL,									--UNIDAD_DE_POLIZA
					RES.RECIBOS_COBRADOS,					--MESES_COBRADOS
					NULL,									--FECHA_ALTA_GAR_POL
					NULL,									--FECHA_BAJA_GAR_POL
					NULL,									--PORCENTAJE_NIVELADA
					NULL,									--PERIODO_EXTORNABLE
					0,										--INDICADOR_COMISION_CALCULADA
					0,										--INDICADOR_PORCENTAJE_CALCULA
					NULL,									--PORCENTAJE_COMISION_CALCULAD
					(CASE WHEN SUBSTR(RES.CODIGO_POLIZA,1,2) = '03'
						THEN RES.PRIMA_COMISIONABLE * ((18 - RES.RECIBOS_COBRADOS)/18) * (-1)
						ELSE RES.PRIMA_COMISIONABLE * (-1)
					END),									--IMPORTE_COMISION
					NULL,									--PRIMA_UNICA
					NULL,									--NUM_ORDEN_MOVIMIENTO
					NULL,									--AUMENTO_CAPITALES_GARANTIA
					RES.PRIMA_NETA_ANUALIZADA * (-1),		--PRIMA_NETA_ANUALIZADA
					NULL,									--PORC_COMISION_NP
					NULL,									--PORC_COMISION_CONSERVACION
					RES.CODIGO_SUPLEMENTO,
					NULL									--PORC_COMISION_COBRO
				FROM :TBL_REC_EXT_SERCO RES
				--Extornamos si el periodo extornable es mayor que los RECIBOS_COBRADOS (para Eterna) o que los MESES_VIGENTES (para Ocaso).
				WHERE RES.PERIODO_EXTORNABLE > (CASE WHEN SUBSTR(RES.CODIGO_POLIZA,1,2) = '03' THEN RES.RECIBOS_COBRADOS ELSE RES.MESES_VIGENTES END)
			;
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en GARANTIAS_RECIBOS con TBL_REC_EXT_SERCO. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
			
		END;
		
		
		--FT_EXTORNAR_RESTO_PERMANENCIAS
		--Creamos una tabla con los registros del RESTO de permanencias suceptibles de ser extornados.
		TBL_REC_EXT_RESTO =
			SELECT DISTINCT R.*,
				GR.PRODUCTO_CONTABLE,GR.PRIMA_COMISIONABLE,GR.PRIMA_NETA_RECIBO,--GR.IDENTIFICADOR AS ID_GAR_REC,
				GR.INCREMENTO_PRIMA_ANUAL,GR.PRIMA_BRUTA_RECIBO,GR.RECARGO,GR.PRIMA_NETA_ANUALIZADA,
				GR.IMPORTE_COMISION,GR.UNIDAD_DE_POLIZA,
				GR.PORCENTAJE_COMISION_CALCULAD,GR.PRIMA_UNICA,GR.NUM_ORDEN_MOVIMIENTO,GR.AUMENTO_CAPITALES_GARANTIA,
				GR.PORC_COMISION_NP,GR.PORC_COMISION_CONSERVACION,GR.PORC_COMISION_COBRO,GR.PORCENTAJE_BONIFICACION,
				GR.FECHA_ALTA_GAR_POL,GR.FECHA_BAJA_GAR_POL,GR.PORCENTAJE_NIVELADA,GR.INDICADOR_PORCENTAJE_CALCULA,
				ROUND(MONTHS_BETWEEN(R.FECHA_EFECTO_RECIBO,RAPE.FECHA_EFECTO_RECIBO),2) AS MESES_VIGENTES,
				CASE WHEN EXTRACT(DAY FROM R.FECHA_EFECTO_RECIBO) =  EXTRACT(DAY FROM R.FECHA_VTO_RECIBO) 
					THEN ROUND(MONTHS_BETWEEN(R.FECHA_EFECTO_RECIBO,R.FECHA_VTO_RECIBO),2) 
					ELSE  ROUND(DAYS_BETWEEN(R.FECHA_EFECTO_RECIBO,ADD_DAYS(R.FECHA_VTO_RECIBO,-1))/30,2) 
					END  AS MESES_RECIBO_INI,
				IFNULL((
					SELECT SUM(ROUND(MONTHS_BETWEEN(RC.FECHA_EFECTO_RECIBO,RC.FECHA_VTO_RECIBO),2))
					FROM EXT.RECIBOS RC
					WHERE RC.CODIGO_POLIZA = RAPE.CODIGO_POLIZA
						AND RC.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
						AND RC.ESTADO_RECIBO = v_const_recibo_cobrado
						AND RC.MARCA_CUENTA = v_const_s
						AND RC.FECHA_EFECTO_RECIBO > R.FECHA_EFECTO_RECIBO
						AND RC.FECHA_COMPENSACION IN ( 
							SELECT MAX(T.FECHA_COMPENSACION)
							FROM EXT.RECIBOS T
							WHERE T.CODIGO_POLIZA = RC.CODIGO_POLIZA
								AND T.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
								AND T.ESTADO_RECIBO IN (v_const_recibo_cobrado,v_const_recibo_pendiente,v_const_recibo_anulado)
								AND T.CODIGO_RECIBO = RC.CODIGO_RECIBO
						)
				),0) AS RECIBOS_COBRADOS,
				IFNULL((
					SELECT SUM(T_GAR_ASE.UNIDAD_DE_POLIZA)
					FROM EXT.ASEGURADOS T_ASE
					INNER JOIN EXT.GARANTIAS_ASEGURADO T_GAR_ASE ON T_ASE.CODIGO_POLIZA = T_GAR_ASE.CODIGO_POLIZA 
						AND T_ASE.NUMERO_ASEGURADO = T_GAR_ASE.NUMERO_ASEGURADO
					WHERE T_GAR_ASE.CODIGO_POLIZA = RAPE.CODIGO_POLIZA
						AND T_GAR_ASE.CODIGO_RECIBO = R.CODIGO_RECIBO
						AND T_GAR_ASE.PRODUCTO_CONTABLE = SUBSTR(RAPE.CODIGO_POLIZA,1,7)
						--Asegurados NO dados de baja ahora.
						AND T_ASE.FECHA_BAJA <> RAPE.FECHA_BAJA
						--Asegurados dados de alta en ese recibo.
						AND T_GAR_ASE.FECHA_ALTA_GAR_ASE = R.FECHA_EFECTO_RECIBO
				),0) AS UNIDAD_POLIZA_DES,
				IFNULL((
					SELECT COUNT(DISTINCT T_ASE.NUMERO_ASEGURADO)
					FROM EXT.ASEGURADOS T_ASE
					INNER JOIN EXT.GARANTIAS_ASEGURADO T_GAR_ASE ON T_ASE.CODIGO_POLIZA = T_GAR_ASE.CODIGO_POLIZA 
						AND T_ASE.NUMERO_ASEGURADO = T_GAR_ASE.NUMERO_ASEGURADO
					WHERE T_GAR_ASE.CODIGO_POLIZA = RAPE.CODIGO_POLIZA
						AND T_GAR_ASE.CODIGO_RECIBO = R.CODIGO_RECIBO
						AND T_GAR_ASE.PRODUCTO_CONTABLE = SUBSTR(RAPE.CODIGO_POLIZA,1,7)
						--Asegurados NO dados de baja ahora.
						AND T_ASE.FECHA_BAJA <> RAPE.FECHA_BAJA
						--Asegurados dados de alta en ese recibo.
						AND T_GAR_ASE.FECHA_ALTA_GAR_ASE = R.FECHA_EFECTO_RECIBO
				),0) AS NUM_ASEG_DES,
				RAPE.IDENTIFICADOR AS ID_REC,
				RAPE.FILE_NAME AS FILE_NAME_REC,
				RAPE.FECHA_COMPENSACION AS FEC_COMPENSACION_REC,
				RAPE.EXCLUIDO_COMISIONES AS EXCLUIDO_COMISIONES_REC,
				RAPE.DISMINUCION_PRIMA AS DISMINUCION_PRIMA_REC,
				RAPE.DISTRITO_COBRO AS DISTRITO_COBRO_REC,
				RAPE.PERIODO_EXTORNABLE,
				RAPE.FECHA_BAJA
			FROM :TBL_RECIBOS_ANULRRTT_PERIODO_EXTORNABLE RAPE
			INNER JOIN EXT.RECIBOS R 
				ON RAPE.CODIGO_POLIZA = R.CODIGO_POLIZA
				AND RAPE.CODIGO_RECIBO <> R.CODIGO_RECIBO
				--AND RAPE.CODIGO_SUPLEMENTO = R.CODIGO_SUPLEMENTO
				--AND RAPE.ESTADO_RECIBO = R.ESTADO_RECIBO
			INNER JOIN EXT.GARANTIAS_RECIBO GR 
				ON R.CODIGO_POLIZA = GR.CODIGO_POLIZA
				AND R.CODIGO_RECIBO = GR.CODIGO_RECIBO
				AND R.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
				AND R.ESTADO_RECIBO = GR.ESTADO_RECIBO
			WHERE R.ESTADO_RECIBO = v_const_recibo_cobrado
				AND R.MARCA_CUENTA = v_const_s
				AND GR.CODIGO_RECIBO NOT IN (
					SELECT REPLACE(T.CODIGO_RECIBO,'_A','')
					FROM EXT.RECIBOS T
					WHERE T.CODIGO_POLIZA LIKE RAPE.CODIGO_POLIZA || '%'
						--Quitamos los recibos si hay un K5 o una anulacion
						AND (T.TIPO_RECIBO = v_const_tipo_rec_anul_k5 OR T.CODIGO_RECIBO LIKE '%_A')
					)
				--No se tiene que extornar si el recibo original es negativo.
				AND ((R.PERMANENCIA = v_const_recibos_especificos_71 AND GR.PRIMA_NETA_RECIBO > 0)
					--Los suplementos (permanencias 66) solo se extornan si han contado PC positiva o unidad de poliza positiva o numero de asegurados positivo.
					OR (R.PERMANENCIA = v_const_recibos_especificos_66 
						AND (GR.PRIMA_COMISIONABLE > 0
						  OR GR.UNIDAD_DE_POLIZA > 0
						  OR R.ASEGURADOS_NETOS > 0))
					--Las rehabilitaciones (permanencias 65) solo se extornan si la prima comisionable (PC) es positiva.
					--No hace falta filtrar por el primer 65 porque solo uno tendra PC positiva.
					OR (R.PERMANENCIA = v_const_recibos_especificos_65 AND GR.PRIMA_COMISIONABLE > 0))
				AND R.PERMANENCIA IN (v_const_recibos_especificos_71,v_const_recibos_especificos_66,v_const_recibos_especificos_65)
				--Para todos los casos, solo se tiene que extornar si el recibo original es positivo.
				AND GR.PRIMA_NETA_RECIBO > 0
				--Descartamos las polizas de ASISA porque al no anticiparse no tienen que generar extorno, salvo para 3 agentes solicitados por Ocaso.
				--BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
				AND NOT((IFNULL(R.OFICINA_GESTORA,'0') = '0900' OR IFNULL(R.OFICINA_COBRADORA,'0') = '900') AND IFNULL(R.CODIGO_UNICO_AGENTE,'0') NOT IN ('0900000579','0900000580','0900000442','0900000560')
				--TGV 20260414 - Por peticion de David Y Cristian se añade a la excepcion de ASISA el producto 29024
				or R.CODIGO_POLIZA LIKE '0129024%')
		;
		v_num_rows = RECORD_COUNT(:TBL_REC_EXT_RESTO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_REC_EXT_RESTO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		
	-------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_REC_EXT_RESTO_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_REC_EXT_RESTO_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_REC_EXT_RESTO_DEBUG AS (SELECT * FROM :TBL_REC_EXT_RESTO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_REC_EXT_RESTO_DEBUG' , i_log_count, i_id_proceso, 'debug');
	------------------------------
		
		
		--Creamos una tabla que contenga los registros fuera de periodo extornable que no generar extorno para el RESTO de permanencias.
		TBL_REC_RESTO_SIN_EXTORNO =
			SELECT RER.*
			FROM :TBL_REC_EXT_RESTO RER
			--No extornamos si el periodo extornable es menor o igual que los meses/recibos cobrados.
			--Para los productos 23*** usamos la variable de MESES_VIGENTES (resta de fechas de efecto entre el recibo y su anulacion).
			WHERE ((SUBSTR(RER.CODIGO_POLIZA,3,2) = '23'
					AND RER.PERIODO_EXTORNABLE <= RER.MESES_VIGENTES
				) OR (SUBSTR(RER.CODIGO_POLIZA,3,2) <> '23'
					--Para los meses de recibo inicial controlamos que no sean menores de 0 ni mayores de 12.
					AND RER.PERIODO_EXTORNABLE <= RER.RECIBOS_COBRADOS + (CASE WHEN RER.MESES_RECIBO_INI < 0 THEN 0 WHEN RER.MESES_RECIBO_INI > 12 THEN 12 ELSE RER.MESES_RECIBO_INI END)
				))
		;
		v_num_rows = RECORD_COUNT(:TBL_REC_RESTO_SIN_EXTORNO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_REC_RESTO_SIN_EXTORNO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Creamos una tabla que contenga los registros dentro del periodo extornable que incluya la suma de prima comisionable a nivel de asegurado.
		TBL_REC_EXT_RESTO_ASEG =
			SELECT X.ID_REC,
				X.FILE_NAME_REC,
				X.CODIGO_POLIZA,
				X.CODIGO_RECIBO,
				X.PERMANENCIA,
				X.TIPO_RECIBO,
				X.FECHA_COBRO,
				X.FEC_COMPENSACION_REC,
				X.FECHA_EFECTO_RECIBO,
				X.FECHA_VTO_RECIBO,
				X.TIPO_MOVIMIENTO,
				X.PORCENTAJE_DESCUENTO_SOBRE_PC,
				X.VALOR_POLIZA,
				X.CODIGO_UNICO_AGENTE,
				X.CODIGO_AGENTE_ORIGINAL,
				X.INSPECTOR,
				X.OFICINA_COBRADORA,
				X.OFICINA_GESTORA,
				X.MARCA_RECUPERADO,
				X.PRIMER_RECIBO,
				X.ASEGURADOS_NETOS,
				X.NUM_ASEG_DES,
				X.AUMENTO_ASEGURADOS,
				X.EXCLUIDO_COMISIONES_REC,
				X.BONIFICACION_POLIZA,
				X.DISMINUCION_PRIMA_REC,
				X.TIPO_RECUPERACION,
				X.ES_PERMANENCIA_20,
				X.CODIGO_AGENTE_COMMISSIONS,
				X.FECHA_COMPENSACION,
				X.FCHA_EFECTO_SUPLEMENTO,
				X.CODIGO_SUPLEMENTO,
				X.DISTRITO_COBRO_REC,
				X.CODIGO_SINIESTRO,
				X.ZONA_EXPLOTACION,
				X.CODIGO_AGENTE_ZONA,
				X.PRODUCTO_CONTABLE,
				X.PRIMA_NETA_RECIBO,
				X.PRIMA_BRUTA_RECIBO,
				X.RECARGO,
				X.PORCENTAJE_BONIFICACION,
				SUM(X.PC_ASEG) AS PRIMA_COMISIONABLE,
				X.UNIDAD_DE_POLIZA,
				X.UNIDAD_POLIZA_DES,
				(CASE WHEN SUBSTR(X.CODIGO_POLIZA,3,2) = '23'
					--Para los productos 23*** usamos la variable de MESES_VIGENTES (resta de fechas de efecto entre el recibo y su anulacion).
					THEN X.MESES_VIGENTES
					--Para los meses de recibo inicial controlamos que no sean menores de 0 ni mayores de 12.
					ELSE X.RC_ASEG + (CASE WHEN X.MESES_RECIBO_INI < 0 THEN 0 WHEN X.MESES_RECIBO_INI > 12 THEN 12 ELSE X.MESES_RECIBO_INI END)
				END) AS MESES_COBRADOS,
				X.FECHA_ALTA_GAR_POL,
				X.FECHA_BAJA_GAR_POL,
				X.PORCENTAJE_NIVELADA,
				X.PERIODO_EXTORNABLE,
				X.INDICADOR_PORCENTAJE_CALCULA,
				X.PORCENTAJE_COMISION_CALCULAD,
				X.IMPORTE_COMISION,
				X.PRIMA_UNICA,
				X.NUM_ORDEN_MOVIMIENTO,
				X.AUMENTO_CAPITALES_GARANTIA,
				X.PRIMA_NETA_ANUALIZADA,
				X.PORC_COMISION_NP,
				X.PORC_COMISION_CONSERVACION,
				X.PORC_COMISION_COBRO
			FROM (
				SELECT RER.*,
					GA.PRIMA_COMISIONABLE AS PC_ASEG,
					IFNULL((
						SELECT SUM(ROUND(MONTHS_BETWEEN(RC.FECHA_EFECTO_RECIBO,RC.FECHA_VTO_RECIBO),2))
						FROM EXT.RECIBOS RC
						WHERE RC.CODIGO_POLIZA = RER.CODIGO_POLIZA
							AND RC.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
							AND RC.ESTADO_RECIBO = v_const_recibo_cobrado
							AND RC.MARCA_CUENTA = v_const_s
							AND RC.FECHA_EFECTO_RECIBO > GA.FECHA_ALTA_GAR_ASE
							AND RC.FECHA_EFECTO_RECIBO <= A.FECHA_BAJA
							AND RC.FECHA_EFECTO_RECIBO > RER.FECHA_EFECTO_RECIBO
							AND RC.FECHA_COMPENSACION IN ( 
								SELECT MAX(T.FECHA_COMPENSACION)
								FROM EXT.RECIBOS T
								WHERE T.CODIGO_POLIZA = RC.CODIGO_POLIZA
									AND T.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
									AND T.ESTADO_RECIBO IN (v_const_recibo_cobrado,v_const_recibo_pendiente,v_const_recibo_anulado)
									AND T.CODIGO_RECIBO = RC.CODIGO_RECIBO
							)
					),0) AS RC_ASEG
				FROM :TBL_REC_EXT_RESTO RER
				INNER JOIN EXT.ASEGURADOS A ON RER.CODIGO_POLIZA = A.CODIGO_POLIZA
					--Solo los asegurados dados de baja ahora.
					AND A.FECHA_BAJA = RER.FECHA_BAJA
				INNER JOIN GARANTIAS_ASEGURADO GA ON RER.CODIGO_POLIZA = GA.CODIGO_POLIZA
					AND RER.PRODUCTO_CONTABLE = GA.PRODUCTO_CONTABLE
					AND A.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
					AND GA.CODIGO_RECIBO IN (RER.CODIGO_RECIBO, 'C_INI')
					--Sin contar los asegurados dados de baja previamente.
					AND GA.FECHA_BAJA_GAR_ASE IS NULL
					--Usamos la fecha de alta en la garantia porque tenemos los cambios por recibo y sino perdemos informacion.
					AND GA.FECHA_ALTA_GAR_ASE = RER.FECHA_EFECTO_RECIBO
				--No extornamos si el periodo extornable es menor o igual que los meses/recibos cobrados.
				--Para los productos 23*** usamos la variable de MESES_VIGENTES (resta de fechas de efecto entre el recibo y su anulacion).
				WHERE ((SUBSTR(RER.CODIGO_POLIZA,3,2) = '23'
						AND RER.PERIODO_EXTORNABLE > RER.MESES_VIGENTES
					) OR (SUBSTR(RER.CODIGO_POLIZA,3,2) <> '23'
						--Para los meses de recibo inicial controlamos que no sean menores de 0 ni mayores de 12.
						AND RER.PERIODO_EXTORNABLE > RER.RECIBOS_COBRADOS + (CASE WHEN RER.MESES_RECIBO_INI < 0 THEN 0 WHEN RER.MESES_RECIBO_INI > 12 THEN 12 ELSE RER.MESES_RECIBO_INI END)
					))
			) X
			GROUP BY
				X.ID_REC,
				X.FILE_NAME_REC,
				X.CODIGO_POLIZA,
				X.CODIGO_RECIBO,
				X.PERMANENCIA,
				X.TIPO_RECIBO,
				X.FECHA_COBRO,
				X.FEC_COMPENSACION_REC,
				X.FECHA_EFECTO_RECIBO,
				X.FECHA_VTO_RECIBO,
				X.TIPO_MOVIMIENTO,
				X.PORCENTAJE_DESCUENTO_SOBRE_PC,
				X.VALOR_POLIZA,
				X.CODIGO_UNICO_AGENTE,
				X.CODIGO_AGENTE_ORIGINAL,
				X.INSPECTOR,
				X.OFICINA_COBRADORA,
				X.OFICINA_GESTORA,
				X.MARCA_RECUPERADO,
				X.PRIMER_RECIBO,
				X.ASEGURADOS_NETOS,
				X.NUM_ASEG_DES,
				X.AUMENTO_ASEGURADOS,
				X.EXCLUIDO_COMISIONES_REC,
				X.BONIFICACION_POLIZA,
				X.DISMINUCION_PRIMA_REC,
				X.TIPO_RECUPERACION,
				X.ES_PERMANENCIA_20,
				X.CODIGO_AGENTE_COMMISSIONS,
				X.FECHA_COMPENSACION,
				X.FCHA_EFECTO_SUPLEMENTO,
				X.CODIGO_SUPLEMENTO,
				X.DISTRITO_COBRO_REC,
				X.CODIGO_SINIESTRO,
				X.ZONA_EXPLOTACION,
				X.CODIGO_AGENTE_ZONA,
				X.PRODUCTO_CONTABLE,
				X.PRIMA_NETA_RECIBO,
				X.PRIMA_BRUTA_RECIBO,
				X.RECARGO,
				X.PORCENTAJE_BONIFICACION,
				X.UNIDAD_DE_POLIZA,
				X.UNIDAD_POLIZA_DES,
				(CASE WHEN SUBSTR(X.CODIGO_POLIZA,3,2) = '23'
					--Para los productos 23*** usamos la variable de MESES_VIGENTES (resta de fechas de efecto entre el recibo y su anulacion).
					THEN X.MESES_VIGENTES
					--Para los meses de recibo inicial controlamos que no sean menores de 0 ni mayores de 12.
					ELSE X.RC_ASEG + (CASE WHEN X.MESES_RECIBO_INI < 0 THEN 0 WHEN X.MESES_RECIBO_INI > 12 THEN 12 ELSE X.MESES_RECIBO_INI END)
				END),
				X.FECHA_ALTA_GAR_POL,
				X.FECHA_BAJA_GAR_POL,
				X.PORCENTAJE_NIVELADA,
				X.PERIODO_EXTORNABLE,
				X.INDICADOR_PORCENTAJE_CALCULA,
				X.PORCENTAJE_COMISION_CALCULAD,
				X.IMPORTE_COMISION,
				X.PRIMA_UNICA,
				X.NUM_ORDEN_MOVIMIENTO,
				X.AUMENTO_CAPITALES_GARANTIA,
				X.PRIMA_NETA_ANUALIZADA,
				X.PORC_COMISION_NP,
				X.PORC_COMISION_CONSERVACION,
				X.PORC_COMISION_COBRO
		;
		v_num_rows = RECORD_COUNT(:TBL_REC_EXT_RESTO_ASEG);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_REC_EXT_RESTO_ASEG creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		-------------------------------TABLA DEBUG PENDIENTE BORRAR
	    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_REC_EXT_RESTO_ASEG_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_REC_EXT_RESTO_ASEG_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_REC_EXT_RESTO_ASEG_DEBUG AS (SELECT * FROM :TBL_REC_EXT_RESTO_ASEG);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_REC_EXT_RESTO_ASEG_DEBUG' , i_log_count, i_id_proceso, 'debug');
		------------------------------
		
		
		
		
		--Creamos una tabla que contenga los registros fuera de periodo extornable que no generar extorno para el RESTO de permanencias.
		TBL_REC_RESTO_ASEG_SIN_EXTORNO =
			SELECT RERA.*
			FROM :TBL_REC_EXT_RESTO_ASEG RERA
			--No extornamos si el periodo extornable es menor o igual que los meses cobrados.
			WHERE RERA.PERIODO_EXTORNABLE <= RERA.MESES_COBRADOS
		;
		v_num_rows = RECORD_COUNT(:TBL_REC_RESTO_ASEG_SIN_EXTORNO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_REC_RESTO_ASEG_SIN_EXTORNO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Insertamos en la tabla de recibos los registros que no alcancen el periodo extornable.
		--RECIBOS con TBL_REC_EXT_RESTO_ASEG
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en RECIBOS con TBL_REC_EXT_RESTO_ASEG - SQL_ERROR_MESSAGE: ' 
																												|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
																												|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
					UPDATE EXT.RECIBOS REC
					SET REC.ESTADO = v_const_calculo_status_error,
						REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS REC, :TBL_REC_EXT_RESTO_ASEG TBL
					WHERE REC.IDENTIFICADOR = TBL.ID_REC
						AND REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = v_const_recibo_cobrado
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
				
			INSERT INTO EXT.RECIBOS
				SELECT
					RERA.ID_REC,															--IDENTIFICADOR
					RERA.FILE_NAME_REC,														--FILE_NAME
					v_const_calculo_status_ok,												--ESTADO
					CURRENT_TIMESTAMP,														--FECHA_MODIFICACION
					RERA.CODIGO_POLIZA,
					RERA.CODIGO_RECIBO || '_A',												--CODIGO_RECIBO
					RERA.PERMANENCIA,
					RERA.TIPO_RECIBO,
					v_const_recibo_cobrado,													--ESTADO_RECIBO
					RERA.FECHA_COBRO,
					RERA.FEC_COMPENSACION_REC,												--FECHA_COMPENSACION
					RERA.FECHA_EFECTO_RECIBO,
					RERA.FECHA_VTO_RECIBO,
					RERA.TIPO_MOVIMIENTO,
					RERA.PORCENTAJE_DESCUENTO_SOBRE_PC,
					RERA.VALOR_POLIZA,
					RERA.CODIGO_UNICO_AGENTE,
					RERA.CODIGO_AGENTE_ORIGINAL,
					RERA.INSPECTOR,
					RERA.OFICINA_COBRADORA,
					RERA.OFICINA_GESTORA,
					RERA.MARCA_RECUPERADO,
					v_const_s,																--MARCA_CUENTA
					RERA.PRIMER_RECIBO,
					(IFNULL(RERA.ASEGURADOS_NETOS,0) - IFNULL(RERA.NUM_ASEG_DES,0)) * (-1),	--ASEGURADOS_NETOS
					RERA.AUMENTO_ASEGURADOS,
					RERA.EXCLUIDO_COMISIONES_REC,											--EXCLUIDO_COMISIONES
					RERA.BONIFICACION_POLIZA,
					RERA.DISMINUCION_PRIMA_REC,												--DISMINUCION_PRIMA
					RERA.TIPO_RECUPERACION,
					RERA.ES_PERMANENCIA_20,
					RERA.CODIGO_AGENTE_COMMISSIONS,
					RERA.FECHA_COMPENSACION,												--FECHA_EMISION_REC
					RERA.FCHA_EFECTO_SUPLEMENTO,
					RERA.CODIGO_SUPLEMENTO,
					RERA.DISTRITO_COBRO_REC,												--DISTRITO_COBRO
					RERA.CODIGO_SINIESTRO,
					RERA.ZONA_EXPLOTACION,
					RERA.CODIGO_AGENTE_ZONA
				FROM :TBL_REC_EXT_RESTO_ASEG RERA
				--No extornamos si el periodo extornable es menor o igual que los meses cobrados.
				WHERE RERA.PERIODO_EXTORNABLE > RERA.MESES_COBRADOS
				GROUP BY
					RERA.ID_REC,
					RERA.FILE_NAME_REC,
					RERA.CODIGO_POLIZA,
					RERA.CODIGO_RECIBO,
					RERA.PERMANENCIA,
					RERA.TIPO_RECIBO,
					RERA.FECHA_COBRO,
					RERA.FEC_COMPENSACION_REC,
					RERA.FECHA_EFECTO_RECIBO,
					RERA.FECHA_VTO_RECIBO,
					RERA.TIPO_MOVIMIENTO,
					RERA.PORCENTAJE_DESCUENTO_SOBRE_PC,
					RERA.VALOR_POLIZA,
					RERA.CODIGO_UNICO_AGENTE,
					RERA.CODIGO_AGENTE_ORIGINAL,
					RERA.INSPECTOR,
					RERA.OFICINA_COBRADORA,
					RERA.OFICINA_GESTORA,
					RERA.MARCA_RECUPERADO,
					RERA.PRIMER_RECIBO,
					RERA.ASEGURADOS_NETOS,
					RERA.NUM_ASEG_DES,
					RERA.AUMENTO_ASEGURADOS,
					RERA.EXCLUIDO_COMISIONES_REC,
					RERA.BONIFICACION_POLIZA,
					RERA.DISMINUCION_PRIMA_REC,
					RERA.TIPO_RECUPERACION,
					RERA.ES_PERMANENCIA_20,
					RERA.CODIGO_AGENTE_COMMISSIONS,
					RERA.FECHA_COMPENSACION,
					RERA.FCHA_EFECTO_SUPLEMENTO,
					RERA.CODIGO_SUPLEMENTO,
					RERA.DISTRITO_COBRO_REC,
					RERA.CODIGO_SINIESTRO,
					RERA.ZONA_EXPLOTACION,
					RERA.CODIGO_AGENTE_ZONA
			;
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en RECIBOS con TBL_REC_EXT_RESTO_ASEG. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
			
		END;
		
		--Insertamos en la tabla de recibos los registros que no alcancen el periodo extornable.
		--GARANTIAS_RECIBO con TBL_REC_EXT_RESTO_ASEG
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en GARANTIAS_RECIBO con TBL_REC_EXT_RESTO_ASEG - SQL_ERROR_MESSAGE: ' 
																												|| IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' 
																												|| ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					
					UPDATE EXT.GARANTIAS_RECIBO GR
					SET GR.ESTADO = v_const_calculo_status_error,
						GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO GR, :TBL_REC_EXT_RESTO_ASEG TBL
					WHERE GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND GR.ESTADO_RECIBO = v_const_recibo_cobrado
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
		
			INSERT INTO EXT.GARANTIAS_RECIBO
				SELECT
					--RERA.ID_GAR_REC,																--IDENTIFICADOR (AUTONUMERICO)
					RERA.ID_REC,																	--ID_RECIBO
					RERA.FILE_NAME_REC,																--FILE_NAME
					v_const_calculo_status_ok,														--ESTADO
					CURRENT_TIMESTAMP,																--FECHA_MODIFICACION
					RERA.CODIGO_POLIZA,
					RERA.CODIGO_RECIBO || '_A',														--CODIGO_RECIBO
					RERA.PRODUCTO_CONTABLE,
					v_const_recibo_cobrado,															--ESTADO_RECIBO
					RERA.PRIMA_NETA_RECIBO * (-1),													--PRIMA_NETA_RECIBO
					RERA.PRIMA_BRUTA_RECIBO * (-1),													--PRIMA_BRUTA_RECIBO
					RERA.RECARGO * (-1),															--RECARGO
					RERA.PORCENTAJE_BONIFICACION,
					IFNULL(ROUND(RERA.PRIMA_COMISIONABLE * ((RERA.PERIODO_EXTORNABLE - RERA.MESES_COBRADOS) / RERA.PERIODO_EXTORNABLE),2) * (-1)
					,0),																			--INCREMENTO_PRIMA_ANUAL
					IFNULL(ROUND(RERA.PRIMA_COMISIONABLE * ((RERA.PERIODO_EXTORNABLE - RERA.MESES_COBRADOS) / RERA.PERIODO_EXTORNABLE),2) * (-1)
					,0),																			--PRIMA_COMISIONABLE
					(IFNULL(RERA.UNIDAD_DE_POLIZA,0) - IFNULL(RERA.UNIDAD_POLIZA_DES,0)) * (-1),	--UNIDAD_DE_POLIZA
					RERA.MESES_COBRADOS,															--MESES_COBRADOS
					RERA.FECHA_ALTA_GAR_POL,
					RERA.FECHA_BAJA_GAR_POL,
					RERA.PORCENTAJE_NIVELADA,
					CASE WHEN (CASE WHEN IFNULL(RERA.PERIODO_EXTORNABLE,0) >= 0 THEN IFNULL(RERA.PERIODO_EXTORNABLE,0) - IFNULL(RERA.MESES_COBRADOS,0) ELSE 0 END) > 0 THEN v_const_s_1 ELSE v_const_n_0 END
        			AS PERIODO_EXTORNABLE,
					--RERA.PERIODO_EXTORNABLE,
					(CASE WHEN IFNULL(ROUND(RERA.IMPORTE_COMISION * ((RERA.PERIODO_EXTORNABLE - RERA.MESES_COBRADOS) / RERA.PERIODO_EXTORNABLE),2) * (-1),0) <> 0
						THEN '1' ELSE '0'
					END),																			--INDICADOR_COMISION_CALCULADA
					RERA.INDICADOR_PORCENTAJE_CALCULA,
					RERA.PORCENTAJE_COMISION_CALCULAD,
					IFNULL(ROUND(RERA.IMPORTE_COMISION * ((RERA.PERIODO_EXTORNABLE - RERA.MESES_COBRADOS) / RERA.PERIODO_EXTORNABLE),2) * (-1)
					,0),																			--IMPORTE_COMISION
					RERA.PRIMA_UNICA,
					RERA.NUM_ORDEN_MOVIMIENTO,
					RERA.AUMENTO_CAPITALES_GARANTIA,
					RERA.PRIMA_NETA_ANUALIZADA * (-1),												--PRIMA_NETA_ANUALIZADA
					RERA.PORC_COMISION_NP,
					RERA.PORC_COMISION_CONSERVACION,
					RERA.CODIGO_SUPLEMENTO,
					RERA.PORC_COMISION_COBRO
				FROM :TBL_REC_EXT_RESTO_ASEG RERA
				--No extornamos si el periodo extornable es menor o igual que los meses cobrados.
				WHERE RERA.PERIODO_EXTORNABLE > RERA.MESES_COBRADOS
				--20260326- TGV , SE ANADE UN NOT EXIST SOBRE LA TABLA DE GARANTIAS_RECIBOS
					AND NOT EXISTS (
					SELECT 1 FROM EXT.GARANTIAS_RECIBO G
					WHERE RERA.CODIGO_POLIZA = G.CODIGO_POLIZA
					AND RERA.CODIGO_RECIBO|| '_A' = G.CODIGO_RECIBO 
					AND RERA.PRODUCTO_CONTABLE = G.PRODUCTO_CONTABLE
					AND v_const_recibo_cobrado = G.ESTADO_RECIBO
					AND RERA.CODIGO_SUPLEMENTO = G.CODIGO_SUPLEMENTO
					)
			;
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en GARANTIAS_RECIBOS con TBL_REC_EXT_RESTO_ASEG. Filas: ' 
																|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
		END;
		
	END;
END
