CREATE PROCEDURE EXT.SP_CALCULO_RRGG (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS


/*---------------------------------------------------------------------
    | Author: Tania Garcés Villanueva
    | Company: Inycom
    | Initial Version Date: 04-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta desde el procedimineto de SP_CALCULO, para calcular el ramo de RRGG RRPP
	|
	|
	| Version: 0.1	TGV 20250304		Initial Version.
	|			0.2	BRG	20250820		Solucion de errores menores
	|			0.3	BRG	20250826		Caso suplementos negativos
	|				RMF 20250826		Se añade una tabla intermedia para saber si el recibo 66 o 71 es primer recibo y asignar correctamente el valor ES_PERMANENCIA_20
	|			0.4 BRG/RMF/TGV 20250904 Solucionados errores encontrados en la cartera
    -----------------------------------------------------------------------
*/
BEGIN

	USING SQLSCRIPT_STRING AS LIBRARY;
	
	--DECLARE i_id_proceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.4';
	DECLARE v_num_rows INTEGER := 0;
	--DECLARE i_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_existen_extornos INTEGER := 0;
	DECLARE v_const_n VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_N;
	DECLARE v_const_s VARCHAR(1) :=  EXT.LIB_CONSTANTES:CONST_S;
	DECLARE v_const_s_1 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S_1;
	DECLARE v_const_n_0 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N_0;
	
	--CONSTANTES DE TIPOS RECIBOS
	DECLARE v_const_recibos_especificos_43 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_43;
	DECLARE v_const_recibos_especificos_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
	DECLARE v_const_recibos_especificos_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
	DECLARE v_const_recibos_especificos_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
	DECLARE v_const_recibos_cartera_81 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_81;
	DECLARE v_const_recibos_cartera_72 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_72;
	
	--CONSTANTES DE ESTADO FICHERO
	DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK; --2
	DECLARE v_const_calculo_status_ok		INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_OK; --6
	DECLARE v_const_calculo_status_error	INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_ERROR;--7
	
	--CONSTANTES POLIZA
	 DECLARE v_const_motivo_baja_bb VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_BAJA_BB;
	 
	 --CONSTANTES ESTADO RECIBO
	 DECLARE v_const_recibo_cobrado VARCHAR2(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
	 DECLARE v_const_recibo_anulado VARCHAR2(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_ANULADO;
	 
	 DECLARE v_const_tipo_rec_anul_k5 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_ANUL_K5;
	 
	 DECLARE v_const_no_encontrado VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_NO_ENCONTRADO; 
	 
	 DECLARE v_const_modalidad_d VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_MODALIDAD_D;
	 
	 --CONSTANTES CAMPANIAS
	  DECLARE v_const_compania_cruzada VARCHAR2(255) := EXT.LIB_CONSTANTES:CONST_CAMPANIA_CRUZADA;
	  DECLARE v_const_bonificacion_cruzada NUMBER(15,2) :=EXT.LIB_CONSTANTES:CONST_BONIFICACION_CRUZADA; --0.75
	  DECLARE v_const_porcentaje_bonifica_10 NUMBER(12,2) := EXT.LIB_CONSTANTES:CONST_PORCENTAJE_BONIFICA_10; --0.1
	  DECLARE v_const_bonificacion_poliza NUMBER(15,2) := EXT.LIB_CONSTANTES:CONST_BONIFICACION_POLIZA;--0.5
	  DECLARE v_const_bonificacion_duathlon NUMBER(15,2) := EXT.LIB_CONSTANTES:CONST_BONIFICACION_DUATHLON;--0.25;
	  DECLARE v_const_campania_duathlon VARCHAR2(255) := EXT.LIB_CONSTANTES:CONST_CAMPANIA_DUATHLON;
	  DECLARE v_const_campania_duathlon_n1  VARCHAR2(255) := EXT.LIB_CONSTANTES:CONST_CAMPANIA_DUATHLON_N1;
	  
	 --CONSTANTES RECUPERACION
	 DECLARE v_const_recu_poliza VARCHAR(2) := EXT.LIB_CONSTANTES:COSNT_RECU_POLIZA; --'RP'
	 DECLARE v_const_recu_recibo VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECU_RECIBO;-- 'RR'
	 
	 --CONSTANTES AGENTES
	 DECLARE v_const_rp_neg_con_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RP_NEG_CON_AGENTE; --7
	 DECLARE v_const_rp_neg_sin_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RP_NEG_SIN_AGENTE; --8
	 DECLARE v_const_rp_pos_con_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RP_POS_CON_AGENTE; --5
	 DECLARE v_const_rp_pos_sin_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RP_POS_SIN_AGENTE; --6
	 DECLARE v_const_rr_neg_con_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RR_NEG_CON_AGENTE; --7
	 DECLARE v_const_rr_neg_sin_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RR_NEG_SIN_AGENTE; --8
	 DECLARE v_const_rr_pos_con_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RR_POS_CON_AGENTE; --3
	 DECLARE v_const_rr_pos_sin_agente	VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_RR_POS_SIN_AGENTE; --4
	 
	 --CONSTANTES AGENCIA
	 DECLARE v_const_tipo_agente_agencia NUMBER := EXT.LIB_CONSTANTES:CONST_TIPO_AGENTE_AGENCIA; --100
	 DECLARE v_const_oficina_seci VARCHAR2(10) := EXT.LIB_CONSTANTES:CONST_OFICINA_SECI;
	 
	 --CONSTANTES RAMO
	 DECLARE v_const_rama_rrgg VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRGG;
	 DECLARE v_const_rama_rrpp VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRPP;
	 
	 --CONSTANTES PRODUCTO
	 DECLARE v_const_producto_50114 VARCHAR2(10) := EXT.LIB_CONSTANTES:CONST_PRODUCTO_50114;
		
	
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
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
		
		--Se comprueban si existen extornos para el fichero, y asi llamar a un procedimiento separado para el calculo de extornos
		SELECT COUNT(*) INTO v_existen_extornos 
			FROM EXT.RECIBOS R INNER JOIN EXT.POLIZAS P  ON R.CODIGO_POLIZA = P.CODIGO_POLIZA
				WHERE R.FILE_NAME = i_file_name and R.ESTADO = v_const_populate_status_ok 
				AND P.MOTIVO_ALTA = v_const_motivo_baja_bb AND P.FECHA_BAJA IS NOT NULL AND P.MOTIVO_BAJA IS NOT NULL;
				
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se comprueba la cantidad de extornos:  ' || v_existen_extornos || ' filas', i_log_count, i_id_proceso, 'debug');
		
		------------------------------EXTORNOS------------------------------
	/*	IF v_existen_extornos > 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se llama al procedimiento SP_CALCULO_EXTORNOS_RRGG_RRPP', i_log_count, i_id_proceso, 'debug');
			CALL EXT.SP_CALCULO_EXTORNOS_RRGG_RRPP(i_file_name,i_id_proceso, i_log_count);
		END IF;*/
		------------------------------EXTORNOS------------------------------
		
		TBL_GEN_CODIGOS_AGENTE = SELECT * FROM EXT.VW_CODIGOS_DE_AGENTE VW
								WHERE 1=1
									AND VW.CODIGO_OCASO <> '0' 
									AND VW.CODIGO_OCASO <> '000000000' 
									AND VW.CODIGO_OCASO <> '0000000000'
								;
		
		
		TBL_RECIBOS = SELECT R.*
			FROM EXT.RECIBOS R INNER JOIN EXT.POLIZAS P  ON R.CODIGO_POLIZA = P.CODIGO_POLIZA
				WHERE R.FILE_NAME = i_file_name and R.ESTADO = v_const_populate_status_ok 
				AND NOT (P.MOTIVO_ALTA =v_const_motivo_baja_bb AND P.FECHA_BAJA IS NOT NULL AND P.MOTIVO_BAJA IS NOT NULL);
				
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS sin extornos '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
		
		
		--FT_INI_REC_OFICCOBPER20
    	--Monta una tabla temporal con la mínima fecha efectiva de inicio y con la máxima fecha efectiva de fin para las distintas oficinas
        TBL_C_OFIC = SELECT POS.GENERICATTRIBUTE3 AS COD_OCASO
        					,SUBSTR(POS.GENERICATTRIBUTE3,1,4)  AS OFI_COBRADORA
        					, v_const_s AS ES_PERMANENCIA_20
			        		, MIN(POS.EFFECTIVESTARTDATE) AS FECHA_DESDE
			        		, MAX(POS.EFFECTIVEENDDATE) AS FECHA_HASTA
			        FROM TCMP.CS_POSITION POS
			        WHERE POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
			        	AND POS.GENERICNUMBER2 = 100
			        	AND POS.TITLESEQ <> 5629499534213290 --Se filtra por TTL distinto de TTL SIN PLAN
			        GROUP BY POS.GENERICATTRIBUTE3
			        UNION ALL
					SELECT '0940999999', '0940', 'S', TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy
					UNION ALL
					SELECT '0946999999', '0946', 'S', TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy
			        ORDER BY 1, 3;
			        
		v_num_rows = RECORD_COUNT(:TBL_C_OFIC);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFIC creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
		
		------------------------------ES_PERMANENCIA_20------------------------------
		 --POR DEFECTO MARCAMOS TODOS LOS RECIBOS A PERMANENCIA_20 NO
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE  en EXT.RECIBOS para ES_PERMANENCIA_20 --> NO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.RECIBOS REC
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS REC, :TBL_RECIBOS src
					WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;
				
				UPDATE EXT.RECIBOS REC
				SET  REC.ES_PERMANENCIA_20 = v_const_n
					,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					,REC.ESTADO = v_const_calculo_status_ok
				WHERE FILE_NAME = i_file_name;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.RECIBOS para ES_PERMANENCIA_20 = N. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
				
				
		END;
		
		-----------MERGES PARA MARCAR ES_PERMANENCIA_20 - S
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para ES_PERMANENCIA_20 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.RECIBOS REC
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS REC, :TBL_RECIBOS src
					WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ESTADO = v_const_populate_status_ok
					;
					
					COMMIT;
					RESIGNAL;
				END;
				
				--20250806 RMF: Añadimos si es primer recibo para permanencia 66
				TBL_PRIMER_RECIBO_66 = SELECT TBL.*
											, CASE WHEN REC.CODIGO_RECIBO IS NULL THEN 0 ELSE 1 END AS PRIMER_RECIBO_ENCONTRADO
											, ROW_NUMBER() OVER(
												PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO
												ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO DESC
											) AS ROW_NUM_REC
										FROM :TBL_RECIBOS TBL
										LEFT JOIN EXT.RECIBOS REC ON REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
											AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
											AND REC.PERMANENCIA = :v_const_recibos_especificos_66
											AND REC.FECHA_EFECTO_RECIBO < TBL.FECHA_EFECTO_RECIBO
										WHERE TBL.PERMANENCIA = :v_const_recibos_especificos_66
										;
										
				v_num_rows = RECORD_COUNT(:TBL_PRIMER_RECIBO_66);
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_PRIMER_RECIBO_66 creada. Indicador de PRIMER_RECIBO_ENCONTRADO: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
				
				--Debemos comprobar si ya existe un recibo 66 anterior para la poliza con el mismo codigo_suplemento. Si es así se genera 20 sino no
				MERGE INTO EXT.RECIBOS REC
				USING (
					SELECT
						TBL.*
					--20250826 RMF: Cambiamos la tabla TBL_RECIBOS por la TBL_PRIMER_RECIBO_66 con la marca de PRIMER_RECIBO_ENCONTRADO
					--FROM :TBL_RECIBOS TBL INNER JOIN :TBL_C_OFIC OFI ON OFI.OFI_COBRADORA = LPAD(TBL.OFICINA_COBRADORA,4,'0')
					FROM :TBL_PRIMER_RECIBO_66 TBL INNER JOIN :TBL_C_OFIC OFI ON OFI.OFI_COBRADORA = LPAD(TBL.OFICINA_COBRADORA,4,'0')
						AND TBL.PERMANENCIA = :v_const_recibos_especificos_66
						AND OFI.ES_PERMANENCIA_20 = :v_const_s
						AND TBL.FECHA_COMPENSACION >= OFI.FECHA_DESDE 
						AND TBL.FECHA_COMPENSACION < OFI.FECHA_HASTA
						AND IFNULL(TBL.TIPO_RECIBO,'00') <> 'AD'
						--20250826 RMF: Añadimos condición de PRIMER_RECIBO_ENCONTRADO
						AND TBL.PRIMER_RECIBO_ENCONTRADO = :v_const_s_1
						AND TBL.ROW_NUM_REC = 1
				) src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
					AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
					AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
					AND REC.FILE_NAME = src.FILE_NAME
				
				WHEN MATCHED THEN UPDATE
					SET  REC.ES_PERMANENCIA_20 = v_const_s
						,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						,REC.ESTADO = v_const_calculo_status_ok
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para ES_PERMANENCIA_20 y PERMANENCIA 66. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
				
				--Para los 71 solo se genera 20 para los recibos con CODIGO_SUPLEMENTO = 0 
				--Para los recibos AD no se genran trx 20 (BRG 20251014 a no ser que sean 71...)
				MERGE INTO EXT.RECIBOS REC
				USING (
					SELECT
						TBL.*
					FROM :TBL_RECIBOS TBL INNER JOIN :TBL_C_OFIC OFI ON OFI.OFI_COBRADORA = LPAD(TBL.OFICINA_COBRADORA,4,'0')
					WHERE TBL.PERMANENCIA = v_const_recibos_especificos_71
					AND TBL.CODIGO_SUPLEMENTO IN (0,999)
					AND OFI.ES_PERMANENCIA_20 = v_const_s
					AND TBL.FECHA_COMPENSACION >= OFI.FECHA_DESDE 
					AND TBL.FECHA_COMPENSACION < OFI.FECHA_HASTA
				) src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
					AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
					AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
					AND REC.FILE_NAME = src.FILE_NAME
			
				
				WHEN MATCHED THEN UPDATE
					SET  REC.ES_PERMANENCIA_20 = v_const_s
					,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					,REC.ESTADO = v_const_calculo_status_ok
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE 2 en EXT.RECIBOS para ES_PERMANENCIA_20 y PERMANENCIA 71. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
				
				MERGE INTO EXT.RECIBOS REC
				USING (
					SELECT
						TBL.*
					FROM :TBL_RECIBOS TBL INNER JOIN :TBL_C_OFIC OFI ON OFI.OFI_COBRADORA = LPAD(TBL.OFICINA_COBRADORA,4,'0')
					WHERE IFNULL(TBL.TIPO_RECIBO,'00') <> 'AD'
					AND OFI.ES_PERMANENCIA_20 = v_const_s
					AND TBL.FECHA_COMPENSACION >= OFI.FECHA_DESDE 
					AND TBL.FECHA_COMPENSACION < OFI.FECHA_HASTA
					AND PERMANENCIA NOT IN ( v_const_recibos_especificos_71, v_const_recibos_especificos_66)
				) src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
					AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
					AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
					AND REC.FILE_NAME = src.FILE_NAME
			
				
				WHEN MATCHED THEN UPDATE
					SET  REC.ES_PERMANENCIA_20 = v_const_s
					,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					,REC.ESTADO = v_const_calculo_status_ok
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE 3 en EXT.RECIBOS para ES_PERMANENCIA_20 y resto PERMANENCIAS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');

		END;
		
	
		
		
		
		------------------------------EXCLUIDO_COMISIONES------------------------------
		--update para marcar todos los registros con excluido comisiones = 0
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en EXT.RECIBOS para EXCLUIDO_COMISIONES = 0 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.RECIBOS REC
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS REC, :TBL_RECIBOS src
					WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ESTADO = v_const_populate_status_ok
					;
					COMMIT;
					RESIGNAL;

				END;
				UPDATE EXT.RECIBOS REC
				SET  REC.EXCLUIDO_COMISIONES = v_const_n_0
					,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					,REC.ESTADO = v_const_calculo_status_ok
				WHERE FILE_NAME = i_file_name;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.RECIBOS para EXCLUIDO_COMISIONES = 0. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
				
			END;
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE en EXT.RECIBOS para EXCLUIDO_COMISIONES - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.RECIBOS REC
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS REC, :TBL_RECIBOS src
					WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ESTADO = v_const_populate_status_ok
					;
					COMMIT;
					RESIGNAL;

				END;
				
				MERGE INTO EXT.RECIBOS REC
				USING (
					SELECT
						TBL.*
					FROM :TBL_RECIBOS TBL
					WHERE TBL.PERMANENCIA <> v_const_recibos_cartera_81
					AND TBL.CODIGO_AGENTE_COMMISSIONS = v_const_no_encontrado
				) src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
					AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
					AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
					AND REC.FILE_NAME = src.FILE_NAME
				WHEN MATCHED THEN UPDATE
					SET  REC.EXCLUIDO_COMISIONES = v_const_s_1
						,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						,REC.ESTADO = v_const_calculo_status_ok
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para EXCLUIDO_COMISIONES. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
		END;	
		
		------------------------------DISMINUCION PRIMA------------------------------
		
		--MARCAMOS TODOS LOS REGISTROS A DISMINUCION_PRIMA = 0
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en EXT.RECIBOS para DISMINUCION_PRIMA - 0 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
			
				UPDATE EXT.RECIBOS REC
					SET ESTADO = v_const_calculo_status_error,
						FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS REC, :TBL_RECIBOS src
				WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
					AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
					AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
					AND src.ESTADO = v_const_populate_status_ok
					
				;
				
				COMMIT;
				RESIGNAL;
			END;
			
			UPDATE EXT.RECIBOS REC
			SET  REC.DISMINUCION_PRIMA = v_const_n_0
				,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP 
				,REC.ESTADO = v_const_calculo_status_ok
			WHERE FILE_NAME = i_file_name;
			
			v_num_rows := ::rowcount;
				
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.RECIBOS para DISMINUCION_PRIMA = 0. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		END;
		
		------MERGES PARA MARCAR DISMINUCION_PRIMA = 1
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE en EXT.RECIBOS para DISMINUCION_PRIMA - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.RECIBOS REC
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS REC, :TBL_RECIBOS src
					WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;
				
				MERGE INTO EXT.RECIBOS REC
				USING (
					SELECT
						TBL.*, gr.PRIMA_NETA_RECIBO
					FROM :TBL_RECIBOS TBL   INNER JOIN EXT.GARANTIAS_RECIBO GR
							ON  GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	            			AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	            			AND GR.ESTADO_RECIBO = TBL.ESTADO_RECIBO 
	            			AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	            			AND GR.FILE_NAME = TBL.FILE_NAME
            				AND GR.FECHA_BAJA_GAR_POL IS NULL
            				AND TBL.TIPO_RECIBO <> v_const_tipo_rec_anul_k5
							AND GR.PRIMA_NETA_RECIBO < 0 
				) src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
					AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
					AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
					AND REC.FILE_NAME = src.FILE_NAME
				
					
				WHEN MATCHED THEN UPDATE
					SET  REC.DISMINUCION_PRIMA = v_const_s_1
						,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						,REC.ESTADO = v_const_calculo_status_ok
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para DISMINUCION_PRIMA. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		END;
		------------------------------TBL_GARANTIAS_RECIBO------------------------------
		TBL_GARANTIAS_RECIBO = 
			select GR.* FROM EXT.GARANTIAS_RECIBO GR 
				INNER JOIN :TBL_RECIBOS R ------------------------------DUDA SI USAR RECIBOS O LA TABLA DE RECIBOS SIN EXTORNOS CREADA ANTES
					ON  GR.CODIGO_POLIZA = R.CODIGO_POLIZA
	            	AND GR.CODIGO_RECIBO = R.CODIGO_RECIBO
	            	AND GR.ESTADO_RECIBO = R.ESTADO_RECIBO
	            	AND GR.CODIGO_SUPLEMENTO = R.CODIGO_SUPLEMENTO
	            	AND GR.FILE_NAME = R.FILE_NAME
	            	AND GR.FECHA_BAJA_GAR_POL IS NULL
            		AND GR.PRODUCTO_CONTABLE NOT IN ('0110199','0110399');
        v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_RECIBO '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');		
		
		------------------------------PERIODO_EXTORNABLE------------------------------ 
		--Si es un suplemento negativo, no se calcula el periodo extornable
		--PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_66 AND par_reg_gar_recibo.PRIMA_NETA_RECIBO < 0
		
		--BUSCAMOS LAS FORMAS DE PAGO
		TBL_FORMAS_PAGO = SELECT  REC.CODIGO_POLIZA, REC.CODIGO_RECIBO, REC.ESTADO_RECIBO, REC.CODIGO_SUPLEMENTO, POL.FORMA_PAGO, (SELECT IFNULL(SUBSTR_BEFORE(MESES_COBRADOS,'.'),'1') FROM EXT.VW_FORMAS_PAGO WHERE CODIGO = POL.FORMA_PAGO ) AS V_MESES_FORMAPGO
							FROM :TBL_RECIBOS REC INNER JOIN EXT.POLIZAS POL 
							ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA;
							
		v_num_rows = RECORD_COUNT(:TBL_FORMAS_PAGO);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_FORMAS_PAGO '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');	
							
        TBL_MESES_COBRADOS = SELECT  REC.CODIGO_POLIZA, REC.CODIGO_RECIBO, REC.ESTADO_RECIBO, REC.CODIGO_SUPLEMENTO, COUNT(*) AS MESES_COBRADOS
        						FROM :TBL_RECIBOS REC INNER JOIN EXT.RECIBOS R 
        						ON REC.CODIGO_POLIZA = R.CODIGO_POLIZA
					            	AND REC.CODIGO_RECIBO = R.CODIGO_RECIBO
					            	AND REC.ESTADO_RECIBO = R.ESTADO_RECIBO 
					            	AND REC.CODIGO_SUPLEMENTO = R.CODIGO_SUPLEMENTO
        						WHERE R.PERMANENCIA IN ( v_const_recibos_cartera_81,v_const_recibos_cartera_72)
        						AND R.ESTADO_RECIBO = v_const_recibo_cobrado
        						AND R.MARCA_CUENTA = v_const_s
        						AND R.FECHA_EFECTO_RECIBO <= REC.FECHA_EFECTO_RECIBO
        						AND R.FECHA_COMPENSACION IN ( 
        								SELECT MAX(T.FECHA_COMPENSACION)
        								FROM EXT.RECIBOS T
        								WHERE T.CODIGO_POLIZA = REC.CODIGO_POLIZA
                        				AND T.PERMANENCIA IN (v_const_recibos_cartera_81,v_const_recibos_cartera_72)
                        				AND T.ESTADO_RECIBO IN (v_const_recibo_cobrado,v_const_recibo_anulado)
                        				AND T.CODIGO_RECIBO =R.CODIGO_RECIBO
        							
        						)
        						GROUP BY REC.CODIGO_POLIZA,REC.CODIGO_RECIBO, REC.ESTADO_RECIBO, REC.CODIGO_SUPLEMENTO;
        						
		v_num_rows = RECORD_COUNT(:TBL_MESES_COBRADOS);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MESES_COBRADOS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');

		
		
		
		TBL_PRODUCTOS = 
			SELECT MC.CODIGO_POLIZA , (MC.MESES_COBRADOS + 1) * FP.V_MESES_FORMAPGO AS MESES_COBRADOS, 
					(SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE ) AS PERIODO_EXTORNABLE,
					(SELECT COMISION_ANTICIPADA FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE ) AS COMISION_ANTICIPADA,
					(SELECT PAGO_MENSUAL FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE ) AS PAGO_MENSUAL--,
				--	(SELECT TIPO_AGENTE FROM )
					
				FROM :TBL_MESES_COBRADOS MC 
				INNER JOIN :TBL_FORMAS_PAGO FP 
					ON MC.CODIGO_POLIZA = FP.CODIGO_POLIZA
				INNER JOIN :TBL_GARANTIAS_RECIBO GR
					ON  GR.CODIGO_POLIZA = MC.CODIGO_POLIZA
	            	AND GR.CODIGO_RECIBO = MC.CODIGO_RECIBO
	            	AND GR.ESTADO_RECIBO = MC.ESTADO_RECIBO 
	            	AND GR.CODIGO_SUPLEMENTO = MC.CODIGO_SUPLEMENTO;
	            	
	    v_num_rows = RECORD_COUNT(:TBL_PRODUCTOS);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRODUCTOS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
	    BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE en EXT.RECIBOS para PERIODO_EXTORNABLE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.RECIBOS REC
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS REC, :TBL_RECIBOS src
					WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;        	
		-------PARA RAMOS GENERALES, EL PERIODO EXTORNABLE SIEMPRE = 12 (FUNCIONES GENERICAS DEL CODIGO DE ORACLE)
			MERGE INTO EXT.GARANTIAS_RECIBO GR
			USING (
				SELECT * FROM :TBL_GARANTIAS_RECIBO
				
			)src
			 ON  GR.CODIGO_POLIZA = src.CODIGO_POLIZA
		      	AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
		      	AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO 
		      	AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
		      	AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
		    WHEN MATCHED THEN UPDATE
				SET  GR.PERIODO_EXTORNABLE = src.PERIODO_EXTORNABLE --12
					 ,GR.MESES_COBRADOS = src.MESES_COBRADOS
					,GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					,GR.ESTADO = v_const_calculo_status_ok
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para PERIODO_EXTORNABLE. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		END;
		------------------------------PRIMA_COMISIONABLE------------------------------ 
		--en la tabla temporal para las garantias,
		TBL_PRIMAS_RRPP =
			SELECT REC.*
				,(SELECT COMISION_ANTICIPADA FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE) AS COMISION_ANTICIPADA_PROD
				,(SELECT PAGO_MENSUAL FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE) AS PAGO_MENSUAL_PROD
				,(SELECT TIPO_AGENTE FROM VW_CODIGOS_DE_AGENTE T
						WHERE CODIGO_UNICO = REC.CODIGO_AGENTE_COMMISSIONS
				        AND T.EFFECTIVESTARTDATE <= POL.FECHA_EMISION_POLIZA
				        AND T.EFFECTIVEENDDATE > POL.FECHA_EMISION_POLIZA
				        AND T.FECHA_INI_PART <= POL.FECHA_EMISION_POLIZA
				        AND T.FECHA_FIN_PART > POL.FECHA_EMISION_POLIZA) AS TIPO_AGENTE
				,CASE 
				    WHEN SUSTITUCION_INCENDIOS = 'S' THEN 1 
					WHEN SUSTITUCION_INCENDIOS = 'N' THEN 0 
					-- BRG 20250820 anyadida una excepcion no contemplada para el calculo de anticipada
					ELSE (SELECT ANTICIPADA_RRPP_OCASO FROM VW_CODIGOS_DE_AGENTE
						WHERE CODIGO_UNICO = REC.CODIGO_AGENTE_COMMISSIONS
							AND EFFECTIVESTARTDATE <= POL.FECHA_EMISION_POLIZA
							AND EFFECTIVEENDDATE > POL.FECHA_EMISION_POLIZA
							AND FECHA_INI_PART <= POL.FECHA_EMISION_POLIZA
							AND FECHA_FIN_PART > POL.FECHA_EMISION_POLIZA) END AS ANTICIPADA_RRPP_OCASO
				,FORMA_PAGO AS FORMA_PAGO
				,GR.PRODUCTO_CONTABLE
				,GR.PRIMA_UNICA
				,GR.PRIMA_NETA_RECIBO
				,GR.RECARGO
				, (SELECT T.MENSUALIDADES FROM VW_FORMAS_PAGO T  WHERE T.CODIGO = FORMA_PAGO) AS MENSUALIDADES
				-- BRG 20250820 anyadidos IFNULL para evitar comparar con NULL
				, IFNULL((SELECT UNIDAD_DE_POLIZA FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE), v_const_n_0) AS UNIDAD_DE_POLIZA
				, IFNULL((SELECT UNIDAD_DE_CUENTA FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE), v_const_n_0) AS UNIDAD_DE_CUENTA
				
				FROM :TBL_RECIBOS REC INNER JOIN :TBL_GARANTIAS_RECIBO GR
					ON  GR.CODIGO_POLIZA = REC.CODIGO_POLIZA
			      	AND GR.CODIGO_RECIBO = REC.CODIGO_RECIBO
			      	AND GR.ESTADO_RECIBO = REC.ESTADO_RECIBO 
			      	AND GR.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
			       INNER JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA = REC.CODIGO_POLIZA	
				WHERE POL.RAMO = v_const_rama_rrpp;
				
		v_num_rows = RECORD_COUNT(:TBL_PRIMAS_RRPP);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMAS_RRPP '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');		
				
		TBL_PRIMAS_RRPP_2 = 
			SELECT REC.*
			, CASE 	WHEN FORMA_PAGO = 1 AND PRODUCTO_CONTABLE IN ('0110100', '0110110') THEN 0
					WHEN FORMA_PAGO NOT IN (1,2,3,6) THEN 0
					WHEN REC.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_especificos_71) AND CODIGO_SUPLEMENTO <> 0 AND PRODUCTO_CONTABLE LIKE  '0110%' THEN 0
					-- BRG 20250903 Ponemos esta condicion al final, ya que en Oracle las otras son mas restrictivas
					WHEN (COMISION_ANTICIPADA_PROD = 1 AND ANTICIPADA_RRPP_OCASO = 1) OR (COMISION_ANTICIPADA_PROD = 1 AND TIPO_AGENTE = v_const_tipo_agente_agencia) THEN 1
					-- BRG 20250820 Si no se cumple ninguna, forzamos 0
					ELSE 0
			END  AS COMISION_ANTICIPADA
			
			FROM :TBL_PRIMAS_RRPP REC
		;
		
		v_num_rows = RECORD_COUNT(:TBL_PRIMAS_RRPP_2);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMAS_RRPP_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');	
		
		TBL_PRIMAS_RRPP_PRIMA_COMISIONABLE =
			SELECT REC.*
			,CASE	WHEN PERMANENCIA = v_const_recibos_especificos_71 AND (COMISION_ANTICIPADA = 0 OR PRIMA_UNICA = 1) THEN IFNULL(PRIMA_NETA_RECIBO,0) + IFNULL(RECARGO ,0)
					-- BRG 20250820 Corregido error en el producto por mensualidades, que también engloba a PRIMA_NETA_RECIBO
					WHEN PERMANENCIA = v_const_recibos_especificos_71 AND NOT(COMISION_ANTICIPADA = 0 OR PRIMA_UNICA = 1) THEN (IFNULL(PRIMA_NETA_RECIBO,0) + IFNULL(RECARGO,0)) * MENSUALIDADES
					WHEN PERMANENCIA = v_const_recibos_cartera_72 AND COMISION_ANTICIPADA = 0 THEN IFNULL(PRIMA_NETA_RECIBO,0) + IFNULL(RECARGO,0)
					WHEN PERMANENCIA = v_const_recibos_cartera_72 AND COMISION_ANTICIPADA = 1 THEN 0
					WHEN (PERMANENCIA = v_const_recibos_cartera_81 OR PERMANENCIA = v_const_recibos_especificos_43) AND UNIDAD_DE_CUENTA = v_const_s_1 THEN 0
					WHEN (PERMANENCIA = v_const_recibos_cartera_81 OR PERMANENCIA = v_const_recibos_especificos_43) AND UNIDAD_DE_CUENTA = v_const_n_0 THEN IFNULL(PRIMA_NETA_RECIBO,0) + IFNULL(RECARGO,0)
					WHEN PERMANENCIA = v_const_recibos_especificos_66 AND PRODUCTO_CONTABLE = '0110700' THEN IFNULL(PRIMA_NETA_RECIBO,0) + IFNULL(RECARGO,0)
					WHEN PERMANENCIA = v_const_recibos_especificos_65 AND UNIDAD_DE_CUENTA = v_const_s_1 THEN 0
					WHEN PERMANENCIA = v_const_recibos_especificos_65 AND UNIDAD_DE_CUENTA = v_const_n_0 THEN IFNULL(PRIMA_NETA_RECIBO,0) + IFNULL(RECARGO,0)
				
				
				END AS PRIMA_COMISIONABLE
			FROM :TBL_PRIMAS_RRPP_2 REC;
			
		v_num_rows = RECORD_COUNT(:TBL_PRIMAS_RRPP_PRIMA_COMISIONABLE);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMAS_RRPP_PRIMA_COMISIONABLE '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');		
---!!!!!!-------------------------------------------------------PENDIENTE LOS K5-----------------------------------------------------------
	
		
		TBL_PRIMAS_RRGG = 
			SELECT REC.* 
			,GR.PRIMA_NETA_RECIBO AS BASE_1
			,CASE WHEN POL.MODALIDAD = v_const_modalidad_d AND SUBSTR(GR.PRODUCTO_CONTABLE,3) = v_const_producto_50114 AND INSTR(OFICINA_GESTORA,v_const_oficina_seci) > 0 THEN v_const_s ELSE v_const_n  END
			AS ES_PRIMA_BRUTA
			,GR.RECARGO
			,GR.PRIMA_BRUTA_RECIBO
			, (SELECT T.MENSUALIDADES FROM VW_FORMAS_PAGO T  WHERE T.CODIGO = FORMA_PAGO) AS MENSUALIDADES
			-- BRG 20250820 Si no existe suplemento el INCREMENTO_PRIMA_ANUAL es 0
			,CASE WHEN (EXISTS (SELECT CODIGO_POLIZA FROM EXT.RECIBOS R 
					WHERE R.CODIGO_POLIZA=REC.CODIGO_POLIZA 
					AND R.PERMANENCIA = v_const_recibos_especificos_66 
					AND R.MARCA_CUENTA = v_const_s 
					AND R.ESTADO_RECIBO = v_const_recibo_cobrado 
					AND R.FECHA_EFECTO_RECIBO BETWEEN POL.FECHA_EFECTO_POLIZA 
					AND ADD_MONTHS(POL.FECHA_EFECTO_POLIZA,12)) 
					-- BRG 20250820 Excluimos los casos que no sean PERMANENCIA 72, 81, 43 o 65
					OR REC.PERMANENCIA NOT IN (v_const_recibos_cartera_72, v_const_recibos_cartera_81, v_const_recibos_especificos_43, v_const_recibos_especificos_65))
				THEN GR.INCREMENTO_PRIMA_ANUAL
				ELSE 0 END AS INCREMENTO_PRIMA_ANUAL
			,GR.PRODUCTO_CONTABLE
			,GR.PRIMA_NETA_RECIBO
		
			
			FROM :TBL_RECIBOS REC INNER JOIN :TBL_GARANTIAS_RECIBO GR
					ON  GR.CODIGO_POLIZA = REC.CODIGO_POLIZA
			      	AND GR.CODIGO_RECIBO = REC.CODIGO_RECIBO
			      	AND GR.ESTADO_RECIBO = REC.ESTADO_RECIBO 
			      	AND GR.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
			       INNER JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA = REC.CODIGO_POLIZA	
			       
				WHERE POL.RAMO = v_const_rama_rrgg;
		
		v_num_rows = RECORD_COUNT(:TBL_PRIMAS_RRGG);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMAS_RRGG '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
				
		TBL_PRIMAS_RRGG_2 =
			SELECT REC.*
			,CASE WHEN ES_PRIMA_BRUTA = v_const_s THEN IFNULL(PRIMA_BRUTA_RECIBO,0) ELSE BASE_1 END AS BASE
		FROM :TBL_PRIMAS_RRGG rec;
		
		v_num_rows = RECORD_COUNT(:TBL_PRIMAS_RRGG_2);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMAS_RRGG_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
		
		TBL_PRIMAS_RRGG_PRIMA_COMISIONABLE = 
			SELECT REC.* 
			,CASE	WHEN PERMANENCIA = v_const_recibos_especificos_71 THEN BASE + IFNULL(RECARGO,0)
					WHEN PERMANENCIA = v_const_recibos_cartera_72 OR PERMANENCIA = v_const_recibos_cartera_81 OR PERMANENCIA = v_const_recibos_especificos_65 OR PERMANENCIA = v_const_recibos_especificos_43 AND SUP.CODIGO_POLIZA <> REC.CODIGO_POLIZA THEN BASE + IFNULL(RECARGO, 0)
					WHEN PERMANENCIA = v_const_recibos_cartera_72 OR PERMANENCIA = v_const_recibos_cartera_81 OR PERMANENCIA = v_const_recibos_especificos_65 OR PERMANENCIA = v_const_recibos_especificos_43 AND SUP.CODIGO_POLIZA = REC.CODIGO_POLIZA AND MENSUALIDADES = 0 THEN BASE
					-- BRG 20250901 Anyadido IFNULL a INCREMENTO_PRIMA_ANUAL
					WHEN PERMANENCIA = v_const_recibos_cartera_72 OR PERMANENCIA = v_const_recibos_cartera_81 OR PERMANENCIA = v_const_recibos_especificos_65 OR PERMANENCIA = v_const_recibos_especificos_43 AND SUP.CODIGO_POLIZA = REC.CODIGO_POLIZA AND MENSUALIDADES > 0 THEN BASE - (IFNULL(INCREMENTO_PRIMA_ANUAL,0)/MENSUALIDADES)
					WHEN PERMANENCIA = v_const_recibos_especificos_66 AND PRODUCTO_CONTABLE IN ('0130101','0130102') THEN IFNULL(BASE,0) + IFNULL(RECARGO,0)
					WHEN PERMANENCIA = v_const_recibos_especificos_66 AND PRODUCTO_CONTABLE NOT IN ('0130101','0130102') THEN IFNULL(INCREMENTO_PRIMA_ANUAL,0)
                    -- BRG 20250821 En Oracle se inicializa a 0
					else 0
			END AS PRIMA_COMISIONABLE
			
			FROM :TBL_PRIMAS_RRGG_2 REC left join (
			-- BRG 20250820 cambiada la tabla para tener el caso donde NO existe suplemento
			-- BRG 20250820 No hemos conseguido que funcione sin que sea subconsulta... pero funciona. REVISAR
			SELECT REC.CODIGO_POLIZA
			,CASE WHEN EXISTS (SELECT CODIGO_POLIZA FROM EXT.RECIBOS R 
					WHERE R.CODIGO_POLIZA=REC.CODIGO_POLIZA 
					AND R.PERMANENCIA = v_const_recibos_especificos_66 
					AND R.MARCA_CUENTA = v_const_s 
					AND R.ESTADO_RECIBO = v_const_recibo_cobrado 
					AND R.FECHA_EFECTO_RECIBO BETWEEN POL.FECHA_EFECTO_POLIZA 
					AND ADD_MONTHS(POL.FECHA_EFECTO_POLIZA,12)) THEN v_const_s
					ELSE v_const_n END
			FROM EXT.RECIBOS REC INNER JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA = REC.CODIGO_POLIZA
			) SUP ON REC.CODIGO_POLIZA = SUP.CODIGO_POLIZA;
		
		v_num_rows = RECORD_COUNT(:TBL_PRIMAS_RRGG_PRIMA_COMISIONABLE);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMAS_RRGG_PRIMA_COMISIONABLE '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');	
			
		TBL_PRIMER_RECIBO_RRGG_66 =
			SELECT TBL.CODIGO_POLIZA,
					TBL.CODIGO_RECIBO,
					TBL.CODIGO_SUPLEMENTO,
					TBL.PERMANENCIA,
			COUNT(*) AS PRIMER_RECIBO FROM :TBL_PRIMAS_RRGG TBL INNER JOIN EXT.RECIBOS REC 
			ON 			 REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	                        AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	                        AND REC.PERMANENCIA = :v_const_recibos_especificos_66
	                        --BRG 20251014 El recibo a modificar también tiene que ser 66
	                        AND TBL.PERMANENCIA = :v_const_recibos_especificos_66
	                        AND REC.FECHA_EMISION_REC < TBL.FECHA_EMISION_REC
	                        GROUP BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO,TBL.CODIGO_SUPLEMENTO, TBL.PERMANENCIA;
        v_num_rows = RECORD_COUNT(:TBL_PRIMER_RECIBO_RRGG_66);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMER_RECIBO_RRGG_66 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');	
	    
        -- BRG 20250821 Excepcion suplementos negativos
        TBL_EXISTE_RECIBO_ANTERIOR_RRGG_66 =
			SELECT
				TBL.CODIGO_POLIZA,
				TBL.CODIGO_RECIBO,
				TBL.CODIGO_SUPLEMENTO,
				(SELECT COUNT(*)
				FROM EXT.RECIBOS REC
				INNER JOIN EXT.GARANTIAS_RECIBO GAR_REC ON GAR_REC.CODIGO_POLIZA = REC.CODIGO_POLIZA
					AND GAR_REC.CODIGO_RECIBO = REC.CODIGO_RECIBO
					AND GAR_REC.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
					AND GAR_REC.ESTADO_RECIBO = REC.ESTADO_RECIBO
				WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO <> TBL.CODIGO_RECIBO
					AND REC.PERMANENCIA IN (v_const_recibos_especificos_71,v_const_recibos_especificos_66)
					AND REC.MARCA_CUENTA = v_const_s
					AND REC.ESTADO_RECIBO = v_const_recibo_cobrado
					AND REC.FECHA_EFECTO_RECIBO >= ADD_MONTHS(TBL.FECHA_EFECTO_RECIBO,-12)
					AND GAR_REC.PRIMA_COMISIONABLE > 0
				) AS EXISTE_RECIBO_ANT
			FROM :TBL_PRIMAS_RRGG_PRIMA_COMISIONABLE TBL
			WHERE TBL.PRIMA_COMISIONABLE < 0
				AND TBL.FECHA_EMISION_REC >= TO_DATE('20210423', 'YYYYMMDD')
				AND TBL.PERMANENCIA = '66';
        v_num_rows = RECORD_COUNT(:TBL_EXISTE_RECIBO_ANTERIOR_RRGG_66);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_EXISTE_RECIBO_ANTERIOR_RRGG_66 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');	
	    	
			
			BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE en EXT.GARANTIAS_RECIBO para PRIMA_COMISIONABLE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.GARANTIAS_RECIBO GR
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.GARANTIAS_RECIBO GR, :TBL_PRIMAS_RRGG_PRIMA_COMISIONABLE src
					WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
			    		AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						--AND src.ESTADO = v_const_populate_status_ok
						
					;
					COMMIT;
					RESIGNAL;
				END;         
			
				MERGE INTO GARANTIAS_RECIBO GR
				USING(
					SELECT DISTINCT CODIGO_POLIZA,CODIGO_RECIBO,CODIGO_SUPLEMENTO,PRIMA_COMISIONABLE FROM :TBL_PRIMAS_RRGG_PRIMA_COMISIONABLE
					
				)src
				ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
				     AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
				     AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
				WHEN MATCHED THEN UPDATE
					SET PRIMA_COMISIONABLE = IFNULL(src.PRIMA_COMISIONABLE,0)
						,FECHA_MODIFICACION = CURRENT_TIMESTAMP
						,ESTADO = v_const_calculo_status_ok;
					
				 v_num_rows := ::rowcount;
								
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para PRIMA_COMISIONABLE. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			END;
			
			--BRG 20251014 El caso primer recibo 66 lo ponemos DESPUÉS de la actualizacion de prima_comisionable
			BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE en EXT.UPDATE para caso PRIMER_RECIBO_66 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de GARANTIAS_RECIBO con estado erróneo
					UPDATE EXT.GARANTIAS_RECIBO GR
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.GARANTIAS_RECIBO GR, :TBL_PRIMER_RECIBO_RRGG_66 src
					WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
			    		AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						--AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;                    
			     MERGE INTO EXT.GARANTIAS_RECIBO GR
			     USING (
			     	SELECT * FROM :TBL_PRIMER_RECIBO_RRGG_66
			     	
			     ) src
			     ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
			     AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
			     AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
			     --AND GR.PERMANENCIA = src.PERMANENCIA
			     WHEN MATCHED THEN UPDATE
			    	SET GR.INCREMENTO_PRIMA_ANUAL = 0
					-- BRG 20250902 Ponemos tambien la PRIMA_COMISIONABLE a 0
						,GR.PRIMA_COMISIONABLE = 0
			    		,GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			    		,GR.ESTADO = v_const_calculo_status_ok;
			    	
			      v_num_rows := ::rowcount;
							
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para caso PRIMER_RECIBO_66. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info'); 
			END;
            
            -- BRG 20250821 Excepcion suplementos negativos
		    BEGIN
             DECLARE EXIT HANDLER FOR SQLEXCEPTION
                BEGIN

                    ROLLBACK;

                    CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name , 'UPDATE de EXT.GARANTIAS_RECIBO - Caso Suplementos Negativos - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                    --v_hayError := 1;
                    --CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);

                    --Se actualizan los registros de GARANTIAS_RECIBO con estado erróneo
                    UPDATE EXT.GARANTIAS_RECIBO GR
                        SET ESTADO = v_const_calculo_status_error,
                            FECHA_MODIFICACION = CURRENT_TIMESTAMP
                        FROM EXT.GARANTIAS_RECIBO GR, :TBL_EXISTE_RECIBO_ANTERIOR_RRGG_66 TBL
                    WHERE GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                        AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                        AND TBL.EXISTE_RECIBO_ANT = 0;

                    COMMIT;
                    RESIGNAL;
                END;

                UPDATE EXT.GARANTIAS_RECIBO GR
                    SET GR.PRIMA_COMISIONABLE = 0,
                        GR.INCREMENTO_PRIMA_ANUAL = 0
                    FROM EXT.GARANTIAS_RECIBO GR, :TBL_EXISTE_RECIBO_ANTERIOR_RRGG_66 TBL
                WHERE GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    AND TBL.EXISTE_RECIBO_ANT = 0;

                v_num_rows := ::rowcount;

                CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.GARANTIAS_RECIBO - Caso Suplementos Negativos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			END;

			BEGIN
			 DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE 2 en EXT.GARANTIAS_RECIBO UPDATE para PRIMA_COMISIONABLE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.GARANTIAS_RECIBO GR
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.GARANTIAS_RECIBO GR, :TBL_PRIMAS_RRPP_PRIMA_COMISIONABLE src
					WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
			    		AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						--AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;         
			
				MERGE INTO GARANTIAS_RECIBO GR
				USING(
					SELECT * FROM :TBL_PRIMAS_RRPP_PRIMA_COMISIONABLE
					
				)src
				ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
				     AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
				     AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
				WHEN MATCHED THEN UPDATE
					SET PRIMA_COMISIONABLE = IFNULL(src.PRIMA_COMISIONABLE,0)
						,FECHA_MODIFICACION = CURRENT_TIMESTAMP
						,ESTADO = v_const_calculo_status_ok;
					
				 v_num_rows := ::rowcount;
								
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE 2 en EXT.GARANTIAS_RECIBO para PRIMA_COMISIONABLE. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			END;
--20250408 TGV  -->David Rubio nos comenta que estos campos ya no se utilizan
		------------------------------TIPO_CAMPANIA------------------------------
	/*	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'UPDATE en EXT.UPDATE para TIPO_CAMPANIA - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.POLIZAS POL
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.POLIZAS POL, :TBL_RECIBOS src
					WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;       

			UPDATE EXT.POLIZAS
				SET TIPO_CAMPANIA = v_const_campania_duathlon, 
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE EXISTS (
				   SELECT REC.CODIGO_POLIZA 
				   FROM :TBL_RECIBOS REC 
				   INNER JOIN :TBL_GARANTIAS_RECIBO GR
				       ON REC.CODIGO_POLIZA = GR.CODIGO_POLIZA
				       AND REC.CODIGO_RECIBO = GR.CODIGO_RECIBO
				       AND REC.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
				       AND REC.ESTADO_RECIBO = GR.ESTADO_RECIBO
				   INNER JOIN EXT.POLIZAS POL 
				       ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA
				   WHERE REC.PERMANENCIA = v_const_recibos_especificos_71
				       AND REC.ESTADO_RECIBO = v_const_recibo_cobrado
				       AND (SELECT TIPO_AGENTE 
				            FROM VW_CODIGOS_DE_AGENTE 
				            WHERE CODIGO_UNICO = REC.CODIGO_AGENTE_COMMISSIONS 
				            AND effectivestartdate <= REC.FECHA_EMISION_REC) IN (31, 32, 39, 40, 44, 45)
				       AND GR.PRODUCTO_CONTABLE LIKE '01501%'
				       AND NOT ((GR.PRODUCTO_CONTABLE = '0150114' AND POL.MODALIDAD = 'E') OR
				                (GR.PRODUCTO_CONTABLE = '0150114' AND POL.MODALIDAD = 'A') OR
				                (GR.PRODUCTO_CONTABLE = '0150120') OR
				                (GR.PRODUCTO_CONTABLE LIKE '015015%') OR
				                (GR.PRODUCTO_CONTABLE LIKE '015016%'))
				       AND GR.PRIMA_NETA_RECIBO >= 0
				       AND REC.FECHA_EMISION_REC >= TO_DATE('24/03/2020','dd/mm/yyyy')
				       AND REC.FECHA_EMISION_REC <= TO_DATE('21/04/2020','dd/mm/yyyy')
				);
				
				v_num_rows := ::rowcount;
					
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.POLIZAS para TIPO_CAMPANIA. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			END;
			
			BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE 2 en EXT.UPDATE para TIPO_CAMPANIA - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.POLIZAS POL
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.POLIZAS POL, :TBL_RECIBOS src
					WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;    
				
				UPDATE EXT.POLIZAS
				SET TIPO_CAMPANIA = v_const_campania_duathlon_n1, FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE EXISTS (
				   SELECT REC.CODIGO_POLIZA 
				   FROM :TBL_RECIBOS REC 
				   INNER JOIN :TBL_GARANTIAS_RECIBO GR
				       ON REC.CODIGO_POLIZA = GR.CODIGO_POLIZA
				       AND REC.CODIGO_RECIBO = GR.CODIGO_RECIBO
				       AND REC.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
				       AND REC.ESTADO_RECIBO = GR.ESTADO_RECIBO
				   INNER JOIN EXT.POLIZAS POL 
				       ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA
				   WHERE REC.PERMANENCIA = v_const_recibos_especificos_71
				       AND REC.ESTADO_RECIBO = v_const_recibo_cobrado
				       AND (SELECT DISTINCT TIPO_AGENTE 
				            FROM VW_CODIGOS_DE_AGENTE 
				            WHERE CODIGO_UNICO = REC.CODIGO_AGENTE_COMMISSIONS 
				            AND effectivestartdate <= REC.FECHA_EMISION_REC) IN (16)
				       AND GR.PRODUCTO_CONTABLE LIKE '01501%'
				       AND NOT ((GR.PRODUCTO_CONTABLE = '0150114' AND POL.MODALIDAD = 'E') OR
				                (GR.PRODUCTO_CONTABLE = '0150114' AND POL.MODALIDAD = 'A') OR
				                (GR.PRODUCTO_CONTABLE = '0150120') OR
				                (GR.PRODUCTO_CONTABLE LIKE '015015%') OR
				                (GR.PRODUCTO_CONTABLE LIKE '015016%'))
				       AND GR.PRIMA_NETA_RECIBO >= 0
				       AND REC.FECHA_EMISION_REC >= TO_DATE('24/03/2020','dd/mm/yyyy')
				       AND REC.FECHA_EMISION_REC <= TO_DATE('21/04/2020','dd/mm/yyyy')
				);
				
				v_num_rows := ::rowcount;
					
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE 2 en EXT.POLIZAS para TIPO_CAMPANIA. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		
			END;
		*/
--20250408 TGV  -->David Rubio nos comenta que estos campos ya no se utilizan		
		------------------------------BONIFICACION_DE_POLIZA------------------------------
/*		TBL_BONIFICACION_POLIZA = 
			SELECT REC.CODIGO_POLIZA, REC.CODIGO_RECIBO,REC.ESTADO_RECIBO ,REC.CODIGO_SUPLEMENTO,POL.TIPO_CAMPANIA,
				(SELECT  max(TIPO_AGENTE )FROM VW_CODIGOS_DE_AGENTE WHERE CODIGO_UNICO = REC.CODIGO_AGENTE_COMMISSIONS AND effectivestartdate <= REC.FECHA_EMISION_REC  ) 
				AS TIPO_AGENTE,
				CASE WHEN LOCATE(UPPER(POL.TIPO_CAMPANIA),v_const_compania_cruzada) > 0 THEN v_const_bonificacion_cruzada 
					ELSE CASE WHEN REC.MARCA_RECUPERADO IS NOT NULL OR REC.MARCA_RECUPERADO <> '' AND GR.PORCENTAJE_BONIFICACION <= v_const_porcentaje_bonifica_10 THEN	v_const_porcentaje_bonifica_10 
						ELSE CASE WHEN REC.MARCA_RECUPERADO IS NOT NULL OR REC.MARCA_RECUPERADO <> '' AND GR.PORCENTAJE_BONIFICACION > v_const_porcentaje_bonifica_10 THEN v_const_bonificacion_poliza END
						END
				END AS BONIFICACION_POLIZA_CALCULADA
			FROM :TBL_RECIBOS REC INNER JOIN EXT.POLIZAS POL
			ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA
			INNER JOIN :TBL_GARANTIAS_RECIBO GR
			 ON  GR.CODIGO_POLIZA = REC.CODIGO_POLIZA
	           	AND GR.CODIGO_RECIBO = REC.CODIGO_RECIBO
	           	AND GR.ESTADO_RECIBO = REC.ESTADO_RECIBO 
	           	AND GR.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
	           	AND GR.FILE_NAME = REC.FILE_NAME;
		
		v_num_rows = RECORD_COUNT(:TBL_BONIFICACION_POLIZA);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_BONIFICACION_POLIZA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
			TBL_BONIFICACION_POLIZA_2 = 
			SELECT CODIGO_POLIZA, CODIGO_RECIBO,ESTADO_RECIBO ,CODIGO_SUPLEMENTO,TIPO_CAMPANIA, TIPO_AGENTE,
			CASE WHEN TIPO_CAMPANIA = v_const_campania_duathlon_n1 
					THEN v_const_bonificacion_duathlon ELSE
				CASE WHEN TIPO_CAMPANIA = v_const_campania_duathlon 
						AND (SELECT COUNT(*) 
					                FROM :TBL_RECIBOS R
					                INNER JOIN EXT.POLIZAS P
					                ON R.CODIGO_POLIZA = P.CODIGO_POLIZA
					                WHERE R.CODIGO_AGENTE_COMMISSIONS = R.CODIGO_AGENTE_COMMISSIONS
					                AND P.TIPO_CAMPANIA = v_const_campania_duathlon
					                AND R.PERMANENCIA = v_const_recibos_especificos_71
					                AND R.ESTADO_RECIBO = v_const_recibo_cobrado
					                AND R.FILE_NAME = R.FILE_NAME)> 0
	                THEN v_const_bonificacion_duathlon ELSE 0 END END AS BONIFICACION_POLIZA_CALCULADA
		
			FROM :TBL_BONIFICACION_POLIZA 
			--	WHERE BONIFICACION_POLIZA_CALCULADA <> 0 OR BONIFICACION_POLIZA_CALCULADA IS NOT NULL OR BONIFICACION_POLIZA_CALCULADA = ''
			; 
		
		v_num_rows = RECORD_COUNT(:TBL_BONIFICACION_POLIZA_2);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_BONIFICACION_POLIZA_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');		
		
		TBL_BONIFICACION_POLIZA_FINAL = 
			SELECT * FROM :TBL_BONIFICACION_POLIZA WHERE BONIFICACION_POLIZA_CALCULADA <> 0 --OR BONIFICACION_POLIZA_CALCULADA IS NOT NULL OR BONIFICACION_POLIZA_CALCULADA = '' 
			UNION ALL
			SELECT * FROM :TBL_BONIFICACION_POLIZA_2;
		
		v_num_rows = RECORD_COUNT(:TBL_BONIFICACION_POLIZA_FINAL);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_BONIFICACION_POLIZA_FINAL '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');		
			
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE 2 en EXT.UPDATE para TIPO_CAMPANIA - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.RECIBOS REC
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS REC, :TBL_RECIBOS src
					WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;   
				
			MERGE INTO RECIBOS REC
			USING(
				SELECT * FROM :TBL_BONIFICACION_POLIZA_FINAL
				
			)src
			ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
			   AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
			   AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO 
			   AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
			 WHEN MATCHED THEN UPDATE
					SET REC.BONIFICACION_POLIZA = src.BONIFICACION_POLIZA_CALCULADA
						,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
			      	
		    v_num_rows := ::rowcount;
					
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para BONIFICACION_POLIZA. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info'); 
		END;
	*/	
--20250408 TGV  -->David Rubio nos comenta que estos campos ya no se utilizan		
		------------------------------TIPO_RECUPERACION------------------------------
/*		TBL_TIPO_RECUPERACION = 
			SELECT REC.*, 
			CASE WHEN GR.PRIMA_NETA_RECIBO <0 THEN v_const_n ELSE v_const_s END AS RECIBO_POSITIVO,
			CASE WHEN REC.CODIGO_UNICO_AGENTE IS NULL OR REC.CODIGO_UNICO_AGENTE = '' THEN v_const_n ELSE v_const_s END AS TIENE_AGENTE
			
			FROM :TBL_RECIBOS REC INNER JOIN :TBL_GARANTIAS_RECIBO GR
			ON  REC.CODIGO_POLIZA = GR.CODIGO_POLIZA
			   AND REC.CODIGO_RECIBO = GR.CODIGO_RECIBO
			   AND REC.ESTADO_RECIBO = GR.ESTADO_RECIBO 
			   AND REC.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
			WHERE REC.CODIGO_UNICO_AGENTE<> CODIGO_AGENTE_ORIGINAL
			AND MARCA_RECUPERADO IN (v_const_recu_poliza,v_const_recu_recibo);
		
		v_num_rows = RECORD_COUNT(:TBL_TIPO_RECUPERACION);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_TIPO_RECUPERACION '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
		TBL_TIPO_RECUPERACION_POLIZA =
			SELECT TBL.*,
			CASE WHEN RECIBO_POSITIVO = v_const_n AND TIENE_AGENTE = v_const_s THEN v_const_rp_neg_con_agente 
				 WHEN RECIBO_POSITIVO = v_const_n AND TIENE_AGENTE = v_const_n THEN v_const_rp_neg_sin_agente 
				 WHEN RECIBO_POSITIVO = v_const_s AND TIENE_AGENTE = v_const_s THEN v_const_rp_pos_con_agente
				 WHEN RECIBO_POSITIVO = v_const_s AND TIENE_AGENTE = v_const_n THEN v_const_rp_pos_sin_agente
		
			END AS TIPO_RECU,
			CASE WHEN (RECIBO_POSITIVO = v_const_n AND TIENE_AGENTE = v_const_s ) OR (RECIBO_POSITIVO = v_const_s AND TIENE_AGENTE = v_const_s ) THEN 1 ELSE 0 END AS TIENE_AGE
			
			FROM :TBL_TIPO_RECUPERACION TBL WHERE MARCA_RECUPERADO = v_const_recu_poliza;
		
		v_num_rows = RECORD_COUNT(:TBL_TIPO_RECUPERACION_POLIZA);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_TIPO_RECUPERACION_POLIZA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
			
		TBL_TIPO_RECUPERACION_RECIBO =
			SELECT TBL.*,
			CASE WHEN RECIBO_POSITIVO = v_const_n AND TIENE_AGENTE = v_const_s THEN v_const_rr_neg_con_agente 
				 WHEN RECIBO_POSITIVO = v_const_n AND TIENE_AGENTE = v_const_n THEN v_const_rr_neg_sin_agente 
				 WHEN RECIBO_POSITIVO = v_const_s AND TIENE_AGENTE = v_const_s THEN v_const_rr_pos_con_agente
				 WHEN RECIBO_POSITIVO = v_const_s AND TIENE_AGENTE = v_const_n THEN v_const_rr_pos_sin_agente
		
			END AS TIPO_RECU,
			CASE WHEN (RECIBO_POSITIVO = v_const_n AND TIENE_AGENTE = v_const_s ) OR (RECIBO_POSITIVO = v_const_s AND TIENE_AGENTE = v_const_s ) THEN 1 ELSE 0 END AS TIENE_AGE
			FROM :TBL_TIPO_RECUPERACION TBL WHERE MARCA_RECUPERADO = v_const_recu_recibo;
		
		v_num_rows = RECORD_COUNT(:TBL_TIPO_RECUPERACION_RECIBO);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_TIPO_RECUPERACION_RECIBO '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
		TBL_TIPO_RECUPERACION_FINAL = SELECT * FROM :TBL_TIPO_RECUPERACION_POLIZA UNION ALL SELECT * FROM :TBL_TIPO_RECUPERACION_RECIBO;
		
		v_num_rows = RECORD_COUNT(:TBL_TIPO_RECUPERACION_FINAL);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_TIPO_RECUPERACION_FINAL '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE  en EXT.UPDATE para TIPO_RECUPERACION - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.POLIZAS POL
						SET ESTADO = v_const_calculo_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.POLIZAS POL, :TBL_RECIBOS src
					WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND src.ESTADO = v_const_populate_status_ok
						
					;
					
					COMMIT;
					
					RESIGNAL;

				END;   
		
			MERGE INTO EXT.RECIBOS REC
			USING(
				SELECT * FROM :TBL_TIPO_RECUPERACION_FINAL
			)src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
				   AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
				   AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO 
				   AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
				 WHEN MATCHED THEN UPDATE
						SET REC.TIPO_RECUPERACION = src.TIPO_RECU
							,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
				      	
			    v_num_rows := ::rowcount;
						
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para TIPO_RECUPERACION. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info'); 
		END;
	
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'MERGE  en EXT.UPDATE para TIPO_RECUPERACION - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
				--v_hayError := 1;
				--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
				
				--Se actualizan los registros de POLIZAS con estado erróneo
				UPDATE EXT.POLIZAS POL
					SET ESTADO = v_const_calculo_status_error,
						FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.POLIZAS POL, :TBL_RECIBOS src
				WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND src.ESTADO = v_const_populate_status_ok
					
				;
				
				COMMIT;
				
				RESIGNAL;
			END;   
			
			MERGE INTO EXT.POLIZAS POL
			USING(	
				SELECT * FROM :TBL_TIPO_RECUPERACION_FINAL
			)src
				ON POL.CODIGO_POLIZA = src.CODIGO_POLIZA
				WHEN MATCHED THEN UPDATE
					SET POL.POLIZA_CON_AGENTE = src.TIENE_AGE
						,POL.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
					
			v_num_rows := ::rowcount;
						
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.POLIZAS para POLIZA_CON_AGENTE. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info'); 
			
		END;	*/
	END;
END
