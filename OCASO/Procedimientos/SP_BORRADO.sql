CREATE PROCEDURE EXT.SP_BORRADO ( OUT o_file_name VARCHAR(120), IN i_file_name VARCHAR(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
 
/*---------------------------------------------------------------------
    | Author: Tania Garc�s Villanueva 
    | Company: Inycom
    | Initial Version Date: 03-Febrero-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que restaura la version anterior de las polizas del fichero a eliminar. 
    |						
	|
	| Version: 0.1	TGV 20250612		Initial Version.
	|
    -----------------------------------------------------------------------
*/
 
BEGIN
	USING SQLSCRIPT_STRING AS LIBRARY;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_idproceso INTEGER;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_const_borrado_status_ok INT := EXT.LIB_CONSTANTES:CONST_BORRADO_STATUS_OK;
	DECLARE v_const_borrado_status_error INT := EXT.LIB_CONSTANTES:CONST_BORRADO_STATUS_ERROR;
	

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
		
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			--v_hayError := 1;
			v_num_rows := 0;
			
			--CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE(i_file_name, v_idproceso);	
			
			COMMIT;

			--Captura el error y lo env�a a xDL
			RESIGNAL;
		END;

	BEGIN
		--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_idproceso, 'info');
	
		---------------------------------------------------------TABLAS VIRTUALES---------------------------------------------------------
		
		-->>>>>>>CREAMOS TABLA TEMPORAL CON LAS GARANTIAS DE ASEGURADO HISTORICAS
		TBL_GARANTIAS_ASEGURADO_HIST = SELECT GAH.* FROM EXT.GARANTIAS_ASEGURADO_HIST GAH
							INNER JOIN EXT.GARANTIAS_ASEGURADO GA
								ON GA.CODIGO_POLIZA = GAH.CODIGO_POLIZA
								AND GA.CODIGO_RECIBO = GAH.CODIGO_RECIBO
								AND GA.PRODUCTO_CONTABLE = GAH.PRODUCTO_CONTABLE
								AND GA.NUMERO_ASEGURADO = GAH.NUMERO_ASEGURADO	
								AND GA.FILE_NAME = i_file_name
							WHERE ID_PROCESO = (SELECT MAX (ID_PROCESO) FROM EXT.GARANTIAS_ASEGURADO_HIST x WHERE 
												GAH.CODIGO_POLIZA = x.CODIGO_POLIZA
												AND GAH.CODIGO_RECIBO = x.CODIGO_RECIBO
												AND GAH.PRODUCTO_CONTABLE = x.PRODUCTO_CONTABLE
												AND GAH.NUMERO_ASEGURADO = x.NUMERO_ASEGURADO							)
												
							;
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_HIST);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla virtual para las garantias asegurado historicos. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		-->>>>>>>CREAMOS TABLA TEMPORAL CON LOS ASEGURADOS HISTORICOS 
		TBL_ASEGURADOS_HIST = SELECT ASEGH.* FROM EXT.ASEGURADOS_HIST ASEGH
							INNER JOIN EXT.ASEGURADOS ASEG
								ON ASEG.CODIGO_POLIZA = ASEGH.CODIGO_POLIZA
								AND ASEG.NUMERO_ASEGURADO = ASEGH.NUMERO_ASEGURADO
								AND ASEG.FILE_NAME = i_file_name
							WHERE ID_PROCESO = (SELECT MAX (ID_PROCESO) FROM EXT.ASEGURADOS_HIST x WHERE 
												ASEGH.CODIGO_POLIZA = x.CODIGO_POLIZA
												AND ASEGH.NUMERO_ASEGURADO = x.NUMERO_ASEGURADO)
							;
							
		v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_HIST);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla virtual para los asegurados historicos. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		
		-->>>>>>>CREAMOS TABLA TEMPORAL CON LAS GARANTIAS DE RECIBOS HISTORICAS
		TBL_GARANTIAS_RECIBO_HIST = SELECT GRH.* FROM EXT.GARANTIAS_RECIBO_HIST GRH
							INNER JOIN EXT.GARANTIAS_RECIBO GR
								ON GR.CODIGO_POLIZA = GRH.CODIGO_POLIZA
								AND GR.CODIGO_RECIBO = GRH.CODIGO_RECIBO
								AND GR.PRODUCTO_CONTABLE = GRH.PRODUCTO_CONTABLE
								AND GR.CODIGO_SUPLEMENTO = GRH.CODIGO_SUPLEMENTO
								AND GR.ESTADO_RECIBO = GRH.ESTADO_RECIBO
								AND GR.FILE_NAME = i_file_name
							WHERE ID_PROCESO = (SELECT MAX (ID_PROCESO) FROM EXT.GARANTIAS_RECIBO_HIST x WHERE 
												GRH.CODIGO_POLIZA = x.CODIGO_POLIZA
												AND GRH.CODIGO_RECIBO = x.CODIGO_RECIBO
												AND GRH.PRODUCTO_CONTABLE = x.PRODUCTO_CONTABLE
												AND GRH.CODIGO_SUPLEMENTO = x.CODIGO_SUPLEMENTO
												AND GRH.ESTADO_RECIBO = x.ESTADO_RECIBO)
												
							;
		v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_HIST);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla virtual para las garantias recibo historicos. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		-->>>>>>>CREAMOS TABLA TEMPORAL CON LOS RECIBOS HISTORICOS 
		TBL_RECIBOS_HIST = SELECT RECH.* FROM EXT.RECIBOS_HIST RECH
							INNER JOIN EXT.RECIBOS REC
								ON REC.CODIGO_POLIZA = RECH.CODIGO_POLIZA
								AND REC.CODIGO_RECIBO = RECH.CODIGO_RECIBO
								AND REC.CODIGO_SUPLEMENTO = RECH.CODIGO_SUPLEMENTO
								AND REC.ESTADO_RECIBO = RECH.ESTADO_RECIBO
								AND REC.FILE_NAME = i_file_name
							WHERE ID_PROCESO = (SELECT MAX (ID_PROCESO) FROM EXT.RECIBOS_HIST x WHERE 
												RECH.CODIGO_POLIZA = x.CODIGO_POLIZA
												AND RECH.CODIGO_RECIBO = x.CODIGO_RECIBO
												AND RECH.CODIGO_SUPLEMENTO = x.CODIGO_SUPLEMENTO
												AND RECH.ESTADO_RECIBO = x.ESTADO_RECIBO)
							;
							
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_HIST);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla virtual para los recibos historicos. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		-->>>>>>>CREAMOS TABLA TEMPORAL CON LAS POLIZAS HISTORICOS 
		TBL_POLIZAS_HIST = SELECT POLH.* FROM EXT.POLIZAS_HIST POLH
							INNER JOIN EXT.POLIZAS POL
								ON POL.CODIGO_POLIZA = POLH.CODIGO_POLIZA
								AND POL.FILE_NAME = i_file_name
							WHERE ID_PROCESO = (SELECT MAX (ID_PROCESO) FROM EXT.POLIZAS_HIST x WHERE 
												POLH.CODIGO_POLIZA = x.CODIGO_POLIZA
												)
							;
							
		v_num_rows = RECORD_COUNT(:TBL_POLIZAS_HIST);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla virtual para los polizas historicos. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		-->>>>>>>CREAMOS TABLA TEMPORAL CON LAS TRANSACCIONES HISTORICOS 
		TBL_SALESTRANSACTION_HIST = SELECT STH.* FROM EXT.SALESTRANSACTION_HIST STH
							INNER JOIN EXT.SALESTRANSACTION ST
								ON ST.ORDERID = STH.ORDERID
								AND ST.LINENUMBER = STH.LINENUMBER
								AND ST.SUBLINENUMBER = STH.SUBLINENUMBER
								AND ST.EVENTTYPEID = STH.EVENTTYPEID
								AND ST.FILE_IN_RECIBOS = i_file_name
							WHERE ID_PROCESO = (SELECT MAX (ID_PROCESO) FROM EXT.SALESTRANSACTION_HIST x WHERE 
												STH.ORDERID = x.ORDERID
												AND STH.LINENUMBER = x.LINENUMBER
												AND STH.SUBLINENUMBER = x.SUBLINENUMBER
												AND STH.EVENTTYPEID = x.EVENTTYPEID
												)
							;
					
		v_num_rows = RECORD_COUNT(:TBL_SALESTRANSACTION_HIST);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla virtual para las transacciones(ST) historicas. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		-->>>>>>>CREAMOS TABLA TEMPORAL CON LAS TRANSACTIONASSIGN HISTORICOS 
		TBL_TRANSACTIONASSIGN_HIST = SELECT TAH.* FROM EXT.TRANSACTIONASSIGN_HIST TAH
							INNER JOIN EXT.TRANSACTIONASSIGN TA
								ON TA.ORDERID = TAH.ORDERID
								AND TA.LINENUMBER = TAH.LINENUMBER
								AND TA.SUBLINENUMBER = TAH.SUBLINENUMBER
								AND TA.EVENTTYPEID = TAH.EVENTTYPEID
								AND TA.FILE_IN_RECIBOS = i_file_name
							WHERE ID_PROCESO = (SELECT MAX (ID_PROCESO) FROM EXT.TRANSACTIONASSIGN_HIST x WHERE 
												TAH.ORDERID = x.ORDERID
												AND TAH.LINENUMBER = x.LINENUMBER
												AND TAH.SUBLINENUMBER = x.SUBLINENUMBER
												AND TAH.EVENTTYPEID = x.EVENTTYPEID
												)
							;
					
		v_num_rows = RECORD_COUNT(:TBL_TRANSACTIONASSIGN_HIST);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla virtual para las transacciones(TA) historicas. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------GARANTIAS ASEGURADOS---------------------------------------------------------
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error merge garantias asegurados - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
				
					--Se actualizan los campos de la in_batch_control para indicar el error
					UPDATE EXT.IN_BATCH_CONTROL
					SET REJECTED_ROWS = v_num_rows,
					STATUS = v_const_borrado_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = i_file_name
					AND ID_PROCESO = v_idproceso;
				
				COMMIT;
				
				RESIGNAL;
			
			END;
	
			-->>>>>>>REALIZAMOS EN MERGE PARA ACTUALIZAR ESOS ASEGURADOS
			MERGE INTO EXT.GARANTIAS_ASEGURADO GA
			USING (
				SELECT * FROM :TBL_GARANTIAS_ASEGURADO_HIST
			) src
				ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA
				AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
				AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
				AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
				AND GA.FILE_NAME = i_file_name
			WHEN MATCHED THEN UPDATE
				SET --GR.IDENTIFICADOR = src.IDENTIFICADOR,
					GA.PRIMA_UNICA = src.PRIMA_UNICA ,
					GA.GARANTIA_IP = src.GARANTIA_IP ,
					GA.PRIMA_NETA_ASEGURADO = src.PRIMA_NETA_ASEGURADO ,
					GA.PORCENTAJE_PARTICIPACION = src.PORCENTAJE_PARTICIPACION ,
					GA.PORCENTAJE_NIVELADA = src.PORCENTAJE_NIVELADA ,
					GA.CAPITAL_NATURAL = src.CAPITAL_NATURAL ,
					GA.CAPITAL_NIVELADO = src.CAPITAL_NIVELADO,
					GA.SUBTIPO_MOVIMIENTO = src.SUBTIPO_MOVIMIENTO ,
					GA.MARCA_CUENTA = src.MARCA_CUENTA ,
					GA.PRIMA_COMISIONABLE = src.PRIMA_COMISIONABLE ,
					GA.UNIDAD_DE_POLIZA = src.UNIDAD_DE_POLIZA ,
					GA.MESES_COBRADOS = src.MESES_COBRADOS  ,
					GA.FECHA_ALTA_GAR_ASE = src.FECHA_ALTA_GAR_ASE ,
					GA.FECHA_BAJA_GAR_ASE = src.FECHA_BAJA_GAR_ASE ,
					GA.FILE_NAME = src.FILE_NAME ,
					GA.NUM_ORDEN_MOVIMIENTO = src.NUM_ORDEN_MOVIMIENTO ,
					GA.PC_PERIODO = src.PC_PERIODO ,
					GA.NUM_PERIODOS = src.NUM_PERIODOS
			;

			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Merge garantias asegurado. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete garantias asegurado - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
				
					--Se actualizan los campos de la in_batch_control para indicar el error
					UPDATE EXT.IN_BATCH_CONTROL
					SET REJECTED_ROWS = v_num_rows,
					STATUS = v_const_borrado_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = i_file_name
					AND ID_PROCESO = v_idproceso;
				
				COMMIT;
				
				RESIGNAL;
			
			END;
		
			-->>>>>>>BORRAMOS LAS GARANTIAS_ASEGURADO CON EL NOMBRE DE FICHERO QUE QUEREMOS ELIMINAR
			DELETE FROM EXT.GARANTIAS_ASEGURADO WHERE FILE_NAME = i_file_name;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete garantias asegurado. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete garantias asegurado hist - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
			END;
			
			-->>>>>>>BORRAMOS LAS GARANTIAS ASEGURADO RESTAURADOS DE LA TABLA DE _HIST
			DELETE FROM EXT.GARANTIAS_ASEGURADO_HIST GA
			WHERE EXISTS ( SELECT 1 FROM :TBL_GARANTIAS_ASEGURADO_HIST X
							WHERE X.CODIGO_POLIZA = GA.CODIGO_POLIZA
							AND X.CODIGO_RECIBO = GA.CODIGO_RECIBO			
							AND X.PRODUCTO_CONTABLE = GA.PRODUCTO_CONTABLE
							AND X.ID_PROCESO = GA.ID_PROCESO
							)
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete garantias_asegurado_hist. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;
		---------------------------------------------------------ASEGURADOS---------------------------------------------------------	
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error merge asegurados - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>REALIZAMOS EN MERGE PARA ACTUALIZAR ESOS ASEGURADOS
			MERGE INTO EXT.ASEGURADOS ASE
			USING (
				SELECT * FROM :TBL_ASEGURADOS_HIST
			) src
				ON ASE.CODIGO_POLIZA = src.CODIGO_POLIZA
				AND ASE.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
				AND ASE.FILE_NAME = i_file_name
			WHEN MATCHED THEN UPDATE
				SET ASE.IDENTIFICADOR = src.IDENTIFICADOR,
					ASE.NIF =  src.NIF,
					ASE.FECHA_NACIMIENTO = src.FECHA_NACIMIENTO ,
					ASE.FECHA_DE_DERECHOS = src.FECHA_DE_DERECHOS ,
					ASE.MOTIVO_ALTA = src.MOTIVO_ALTA,
					ASE.CONTO_COMO_ALTA = src.CONTO_COMO_ALTA ,
					ASE.CONTO_COMO_NUEVO = src.CONTO_COMO_NUEVO ,
					ASE.FECHA_ALTA = src.FECHA_ALTA ,
					ASE.MOTIVO_BAJA = src.MOTIVO_BAJA ,
					ASE.FECHA_BAJA = src.FECHA_BAJA ,
					ASE.FECHA_REHABILITACION = src.FECHA_REHABILITACION ,
					ASE.POLIZA_ORIGEN = src.POLIZA_ORIGEN ,
					ASE.ASEGURADO_ORIGEN = src.ASEGURADO_ORIGEN ,
					ASE.FILE_NAME = src.FILE_NAME ,
					ASE.EDAD = src.EDAD ,
					ASE.EDAD_DERECHOS = src.EDAD_DERECHOS
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Merge asegurados. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete  asegurados - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
			
			END;
			
			-->>>>>>>BORRAMOS LOS ASEGURADOS CON EL NOMBRE DE FICHERO QUE QUEREMOS ELIMINAR
			DELETE FROM EXT.ASEGURADOS WHERE FILE_NAME = i_file_name;
		END;
		v_num_rows := ::rowcount;
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete asegurados. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete asegurados hist - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>BORRAMOS LOS ASEGURADOS RESTAURADOS DE LA TABLA DE _HIST
			DELETE FROM EXT.ASEGURADOS_HIST A
			WHERE EXISTS ( SELECT 1 FROM :TBL_ASEGURADOS_HIST X
							WHERE X.CODIGO_POLIZA = A.CODIGO_POLIZA
							AND X.NUMERO_ASEGURADO = A.NUMERO_ASEGURADO
							AND X.ID_PROCESO = A.ID_PROCESO)
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete asegurados_hist. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;
		---------------------------------------------------------GARANTIAS RECIBOS---------------------------------------------------------
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error merge garantias recibos - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
			END;
	
			-->>>>>>>REALIZAMOS EN MERGE PARA ACTUALIZAR ESOS RECIBOS
			MERGE INTO EXT.GARANTIAS_RECIBO GR
			USING (
				SELECT * FROM :TBL_GARANTIAS_RECIBO_HIST
			) src
				ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
				AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
				AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
				AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
				AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
				AND GR.FILE_NAME = i_file_name
			WHEN MATCHED THEN UPDATE
				SET --GR.IDENTIFICADOR = src.IDENTIFICADOR,
					GR.ID_RECIBO = src.ID_RECIBO,
					GR.FILE_NAME = src.FILE_NAME,
					GR.ESTADO = src.ESTADO,
					GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP,
					GR.CODIGO_POLIZA = src.CODIGO_POLIZA,
					GR.CODIGO_RECIBO = src.CODIGO_RECIBO,
					GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE,
					GR.ESTADO_RECIBO = src.ESTADO_RECIBO,
					GR.PRIMA_NETA_RECIBO = src.PRIMA_NETA_RECIBO,
					GR.PRIMA_BRUTA_RECIBO = src.PRIMA_BRUTA_RECIBO,
					GR.RECARGO = src.RECARGO,
					GR.PORCENTAJE_BONIFICACION = src.PORCENTAJE_BONIFICACION,
					GR.INCREMENTO_PRIMA_ANUAL = src.INCREMENTO_PRIMA_ANUAL,
					GR.PRIMA_COMISIONABLE = src.PRIMA_COMISIONABLE,
					GR.UNIDAD_DE_POLIZA = src.UNIDAD_DE_POLIZA,
					GR.MESES_COBRADOS = src.MESES_COBRADOS,
					GR.FECHA_ALTA_GAR_POL = src.FECHA_ALTA_GAR_POL,
					GR.FECHA_BAJA_GAR_POL = src.FECHA_BAJA_GAR_POL,
					GR.PORCENTAJE_NIVELADA = src.PORCENTAJE_NIVELADA,
					GR.PERIODO_EXTORNABLE = src.PERIODO_EXTORNABLE,
					GR.INDICADOR_COMISION_CALCULADA = src.INDICADOR_COMISION_CALCULADA,
					GR.INDICADOR_PORCENTAJE_CALCULA = src.INDICADOR_PORCENTAJE_CALCULA,
					GR.PORCENTAJE_COMISION_CALCULAD = src.PORCENTAJE_COMISION_CALCULAD,
					GR.IMPORTE_COMISION = src.IMPORTE_COMISION,
					GR.PRIMA_UNICA = src.PRIMA_UNICA,
					GR.NUM_ORDEN_MOVIMIENTO = src.NUM_ORDEN_MOVIMIENTO,
					GR.AUMENTO_CAPITALES_GARANTIA = src.AUMENTO_CAPITALES_GARANTIA,
					GR.PRIMA_NETA_ANUALIZADA = src.PRIMA_NETA_ANUALIZADA,
					GR.PORC_COMISION_NP = src.PORC_COMISION_NP,
					GR.PORC_COMISION_CONSERVACION = src.PORC_COMISION_CONSERVACION,
					GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO,
					GR.PORC_COMISION_COBRO = src.PORC_COMISION_COBRO
			;

			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Merge garantias recibo. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete garantias recibos - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
		
			-->>>>>>>BORRAMOS LAS GARANTIAS_RECIBO CON EL NOMBRE DE FICHERO QUE QUEREMOS ELIMINAR
			DELETE FROM EXT.GARANTIAS_RECIBO WHERE FILE_NAME = i_file_name;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete garantias recibo. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
			
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete garantias recibos hist - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
			
				RESIGNAL;
			END;
			
			-->>>>>>>BORRAMOS LOS RECIBOS RESTAURADOS DE LA TABLA DE _HIST
			DELETE FROM EXT.GARANTIAS_RECIBO_HIST GR
			WHERE EXISTS ( SELECT 1 FROM :TBL_GARANTIAS_RECIBO_HIST X
							WHERE X.CODIGO_POLIZA = GR.CODIGO_POLIZA
							AND X.CODIGO_RECIBO = GR.CODIGO_RECIBO			
							AND X.PRODUCTO_CONTABLE = GR.PRODUCTO_CONTABLE
							AND X.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
							AND X.ESTADO_RECIBO = GR.ESTADO_RECIBO
							AND X.ID_PROCESO = GR.ID_PROCESO
			)
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete garantias_recibo_hist. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;
	
		---------------------------------------------------------RECIBOS---------------------------------------------------------	
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
			
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error merge recibos - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>REALIZAMOS EN MERGE PARA ACTUALIZAR ESOS RECIBOS
			MERGE INTO EXT.RECIBOS REC
			USING (
				SELECT * FROM :TBL_RECIBOS_HIST
			) src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
				AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
				AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
				AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
				AND REC.FILE_NAME = i_file_name
			WHEN MATCHED THEN UPDATE
				SET REC.IDENTIFICADOR = src.IDENTIFICADOR,
					REC.FILE_NAME = src.FILE_NAME,
					REC.ESTADO = src.ESTADO,
					REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP,
					REC.CODIGO_POLIZA = src.CODIGO_POLIZA,
					REC.CODIGO_RECIBO = src.CODIGO_RECIBO,
					REC.PERMANENCIA = src.PERMANENCIA,
					REC.TIPO_RECIBO = src.TIPO_RECIBO,
					REC.ESTADO_RECIBO = src.ESTADO_RECIBO,
					REC.FECHA_COBRO = src.FECHA_COBRO,
					REC.FECHA_COMPENSACION = src.FECHA_COMPENSACION,
					REC.FECHA_EFECTO_RECIBO = src.FECHA_EFECTO_RECIBO,
					REC.FECHA_VTO_RECIBO = src.FECHA_VTO_RECIBO,
					REC.TIPO_MOVIMIENTO = src.TIPO_MOVIMIENTO,
					REC.PORCENTAJE_DESCUENTO_SOBRE_PC = src.PORCENTAJE_DESCUENTO_SOBRE_PC,
					REC.VALOR_POLIZA = src.VALOR_POLIZA,
					REC.CODIGO_UNICO_AGENTE = src.CODIGO_UNICO_AGENTE,
					REC.CODIGO_AGENTE_ORIGINAL = src.CODIGO_AGENTE_ORIGINAL,
					REC.INSPECTOR = src.INSPECTOR,
					REC.OFICINA_COBRADORA = src.OFICINA_COBRADORA,
					REC.OFICINA_GESTORA = src.OFICINA_GESTORA,
					REC.MARCA_RECUPERADO = src.MARCA_RECUPERADO,
					REC.MARCA_CUENTA = src.MARCA_CUENTA,
					REC.PRIMER_RECIBO = src.PRIMER_RECIBO,
					REC.ASEGURADOS_NETOS = src.ASEGURADOS_NETOS,
					REC.AUMENTO_ASEGURADOS = src.AUMENTO_ASEGURADOS,
					REC.EXCLUIDO_COMISIONES = src.EXCLUIDO_COMISIONES,
					REC.BONIFICACION_POLIZA = src.BONIFICACION_POLIZA,
					REC.DISMINUCION_PRIMA = src.DISMINUCION_PRIMA,
					REC.TIPO_RECUPERACION = src.TIPO_RECUPERACION,
					REC.ES_PERMANENCIA_20 = src.ES_PERMANENCIA_20,
					REC.CODIGO_AGENTE_COMMISSIONS = src.CODIGO_AGENTE_COMMISSIONS,
					REC.FECHA_EMISION_REC = src.FECHA_EMISION_REC,
					REC.FCHA_EFECTO_SUPLEMENTO = src.FCHA_EFECTO_SUPLEMENTO,
					REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO,
					REC.DISTRITO_COBRO = src.DISTRITO_COBRO,
					REC.CODIGO_SINIESTRO = src.CODIGO_SINIESTRO,
					REC.ZONA_EXPLOTACION = src.ZONA_EXPLOTACION,
					REC.CODIGO_AGENTE_ZONA = src.CODIGO_AGENTE_ZONA
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Merge recibos. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete  recibos - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>BORRAMOS LOS RECIBOS CON EL NOMBRE DE FICHERO QUE QUEREMOS ELIMINAR
			DELETE FROM EXT.RECIBOS WHERE FILE_NAME = i_file_name;
		END;
		v_num_rows := ::rowcount;
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete recibos. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete recibos hist - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>BORRAMOS LOS RECIBOS RESTAURADOS DE LA TABLA DE _HIST
			DELETE FROM EXT.RECIBOS_HIST R
			WHERE EXISTS ( SELECT 1 FROM :TBL_RECIBOS_HIST X
							WHERE X.CODIGO_POLIZA = R.CODIGO_POLIZA
							AND X.CODIGO_RECIBO = R.CODIGO_RECIBO									
							AND X.CODIGO_SUPLEMENTO = R.CODIGO_SUPLEMENTO
							AND X.ESTADO_RECIBO = R.ESTADO_RECIBO
							AND X.ID_PROCESO = R.ID_PROCESO
			)
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete recibos_hist. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;
		---------------------------------------------------------POLIZAS---------------------------------------------------------	
	
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error merge polizas - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>REALIZAMOS EN MERGE PARA ACTUALIZAR ESAS POLIZAS
			MERGE INTO EXT.POLIZAS POL
			USING (
				SELECT * FROM :TBL_POLIZAS_HIST
			) src
				ON POL.CODIGO_POLIZA = src.CODIGO_POLIZA
				AND POL.FILE_NAME = i_file_name
			WHEN MATCHED THEN UPDATE
				SET --POL.IDENTIFICADOR = src.IDENTIFICADOR,
					POL.ID_RECIBO = src.ID_RECIBO,
					POL.FILE_NAME = src.FILE_NAME,
					POL.ESTADO = src.ESTADO,
					POL.FECHA_MODIFICACION = CURRENT_TIMESTAMP,
					POL.CODIGO_POLIZA = src.CODIGO_POLIZA,
					POL.RAMO = src.RAMO,
					POL.MOTIVO_ALTA = src.MOTIVO_ALTA,
					POL.FECHA_EFECTO_POLIZA = src.FECHA_EFECTO_POLIZA,
					POL.FECHA_EMISION_POLIZA = src.FECHA_EMISION_POLIZA,
					POL.FECHA_CESION_POLIZA = src.FECHA_CESION_POLIZA,
					POL.MOTIVO_BAJA = src.MOTIVO_BAJA,
					POL.FECHA_BAJA = src.FECHA_BAJA,
					POL.FECHA_VENCIMIENTO = src.FECHA_VENCIMIENTO,
					POL.FECHA_REHABILITACION = src.FECHA_REHABILITACION,
					POL.FORMA_PAGO = src.FORMA_PAGO,
					POL.TIPO_CAMPANIA = src.TIPO_CAMPANIA,
					POL.SEGUNDA_RESIDENCIA = src.SEGUNDA_RESIDENCIA,
					POL.TARIFA = src.TARIFA,
					POL.ZONA = src.ZONA,
					POL.CLAVE_RIESGO = src.CLAVE_RIESGO,
					POL.MODALIDAD = src.MODALIDAD,
					POL.DURACION = src.DURACION,
					POL.CLAUSULA = src.CLAUSULA,
					POL.SUSTITUCION_INCENDIOS = src.SUSTITUCION_INCENDIOS,
					POL.EXCLUIDO_COMISIONES = src.EXCLUIDO_COMISIONES,
					POL.TRASPASADA = src.TRASPASADA,
					POL.DESCUENTO_IMPORTE_SINIESTRALID = src.DESCUENTO_IMPORTE_SINIESTRALID,
					POL.DESCUENTO_POR_PRIORITARIO = src.DESCUENTO_POR_PRIORITARIO,
					POL.RIESGO = src.RIESGO,
					POL.COLECTIVO = src.COLECTIVO,
					POL.AUTOLIQUIDA = src.AUTOLIQUIDA,
					POL.KILOMETROS = src.KILOMETROS,
					POL.MOVILIDAD = src.MOVILIDAD,
					POL.POLIZA_CON_AGENTE = src.POLIZA_CON_AGENTE,
					POL.AGENTE_CARTERA = src.AGENTE_CARTERA,
					POL.IMP_COMISION_CARTERA = src.IMP_COMISION_CARTERA,
					POL.PORC_COMISION_CARTERA = src.PORC_COMISION_CARTERA,
					POL.FECHA_FIN_COMISION_CARTERA = src.FECHA_FIN_COMISION_CARTERA
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Merge polizas. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete polizas - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>BORRAMOS LAS POLIZAS CON EL NOMBRE DE FICHERO QUE QUEREMOS ELIMINAR
			DELETE FROM EXT.POLIZAS WHERE FILE_NAME = i_file_name;
		
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete polizas. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete polizas hist - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			
			-->>>>>>>BORRAMOS LAS POLIZAS RESTAURADOS DE LA TABLA DE _HIST
			DELETE FROM EXT.POLIZAS_HIST P
			WHERE EXISTS ( SELECT 1 FROM :TBL_POLIZAS_HIST X
							WHERE X.CODIGO_POLIZA = P.CODIGO_POLIZA
								AND X.ID_PROCESO = P.ID_PROCESO
							)
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete polizas_hist. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;
		---------------------------------------------------------TRANSACIONES---------------------------------------------------------	
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
			
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error merge salestransaction - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
			
				RESIGNAL;
			END;
		
			-->>>>>>>REALIZAMOS EN MERGE PARA ACTUALIZAR ESAS TRANSACCIONES
			MERGE INTO EXT.SALESTRANSACTION ST
			USING (
				SELECT * FROM :TBL_SALESTRANSACTION_HIST
			) src
				ON ST.ORDERID = src.ORDERID
				AND ST.LINENUMBER = src.LINENUMBER
				AND ST.SUBLINENUMBER = src.SUBLINENUMBER
				AND ST.EVENTTYPEID = src.EVENTTYPEID
				AND ST.FILE_IN_RECIBOS = i_file_name
			WHEN MATCHED THEN UPDATE
				SET ST.BATCHNAME = src.BATCHNAME,
					ST.FILE_IN_RECIBOS = src.FILE_IN_RECIBOS,
	            	ST.LINENUMBER = src.LINENUMBER,
					ST.COMPENSATIONDATE = src.COMPENSATIONDATE,
					ST.GENERICATTRIBUTE6 = src.GENERICATTRIBUTE6
	                              
			;
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Merge salestransaction. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete salestransaction - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
			
				RESIGNAL;
			END;
			
			-->>>>>>>BORRAMOS LAS POLIZAS CON EL NOMBRE DE FICHERO QUE QUEREMOS ELIMINAR
			DELETE FROM EXT.SALESTRANSACTION WHERE FILE_IN_RECIBOS = i_file_name;
		
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete salestransaction. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete salestransaction hist - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
			
				RESIGNAL;
			END;
			
			-->>>>>>>BORRAMOS LAS SALESTRANSACTION RESTAURADOS DE LA TABLA DE _HIST
			DELETE FROM EXT.SALESTRANSACTION_HIST ST
			WHERE EXISTS ( SELECT 1 FROM :TBL_SALESTRANSACTION_HIST X
							WHERE X.ORDERID = ST.ORDERID
							AND X.LINENUMBER = ST.LINENUMBER
							AND X.SUBLINENUMBER = ST.SUBLINENUMBER
							AND X.EVENTTYPEID = ST.EVENTTYPEID
							AND X.ID_PROCESO = ST.ID_PROCESO
							)
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete salestransaction_hist. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;
	
	
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error merge transactionassign - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
			END;
		
			-->>>>>>>REALIZAMOS EN MERGE PARA ACTUALIZAR ESAS TRANSACTIONASSIGN
			MERGE INTO EXT.TRANSACTIONASSIGN TA
			USING (
				SELECT * FROM :TBL_TRANSACTIONASSIGN_HIST
			) src
				ON TA.ORDERID = src.ORDERID
				AND TA.LINENUMBER = src.LINENUMBER
				AND TA.SUBLINENUMBER = src.SUBLINENUMBER
				AND TA.EVENTTYPEID = src.EVENTTYPEID
				AND TA.POSITIONNAME = src.POSITIONNAME
				AND TA.FILE_IN_RECIBOS = i_file_name
			WHEN MATCHED THEN UPDATE
				SET TA.BATCHNAME = src.BATCHNAME,
					TA.FILE_IN_RECIBOS = src.FILE_IN_RECIBOS,
	            	TA.LINENUMBER = src.LINENUMBER
					
	                              
			;
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Merge transacciones(TA). Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
				ROLLBACK;
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete transactionassign - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
				
				RESIGNAL;
				
			END;
			-->>>>>>>BORRAMOS LAS POLIZAS CON EL NOMBRE DE FICHERO QUE QUEREMOS ELIMINAR
			DELETE FROM EXT.TRANSACTIONASSIGN WHERE FILE_IN_RECIBOS = i_file_name;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete transacciones(TA). Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');	
		END;
		
		BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error delete transactionassign hist - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			
				--Se actualizan los campos de la in_batch_control para indicar el error
				UPDATE EXT.IN_BATCH_CONTROL
				SET REJECTED_ROWS = v_num_rows,
				STATUS = v_const_borrado_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
			
				COMMIT;
			
				RESIGNAL;
			END;
			
			-->>>>>>>BORRAMOS LAS SALESTRANSACTION RESTAURADOS DE LA TABLA DE _HIST
			DELETE FROM EXT.TRANSACTIONASSIGN_HIST TA
			WHERE EXISTS ( SELECT 1 FROM :TBL_TRANSACTIONASSIGN_HIST X
							WHERE X.ORDERID = TA.ORDERID
							AND X.LINENUMBER = TA.LINENUMBER
							AND X.SUBLINENUMBER = TA.SUBLINENUMBER
							AND X.EVENTTYPEID = TA.EVENTTYPEID
							AND X.POSITIONNAME = TA.POSITIONNAME
							AND X.ID_PROCESO = TA.ID_PROCESO
							)
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin Delete transacciones(TA_HIST). Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
	
		END;
	
	
		-------------------------------------------------------------------------------------------------------------------------
			--ACTUALIZAMOS LA STAGE_RECIBOS A -1 PARA ESTE NOMBRE DE FICHERO
		UPDATE EXT.STAGE_RECIBOS SET ESTADO = v_const_borrado_status_ok WHERE FILE_NAME = i_file_name;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Update stage_recibos a estado -1. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		--ACTUALIZAMOS LA IN_BATCH_CONTROL A -1 PARA ESTE NOMBRE DE FICHERO
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = v_const_borrado_status_ok WHERE FILE_NAME = i_file_name;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Update in_batch_control a estado -1. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name,'Fin procedimiento borrado' , v_log_count, v_idproceso, 'info');
	END;	
 
END
