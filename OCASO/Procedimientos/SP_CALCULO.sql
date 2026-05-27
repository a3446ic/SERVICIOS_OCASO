CREATE OR REPLACE PROCEDURE EXT.SP_CALCULO ( OUT o_file_name VARCHAR(120), IN i_file_name VARCHAR(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez 
    | Company: Inycom
    | Initial Version Date: 03-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se sube un fichero para 
    | Nombre fichero entrada - CALCULO_ABLFTP162702P_20241219_214036_1wio5.txt
	|
	| Version: 1.0	RMF 20251024	Se añaden condiciones a las consultas de recibo para excluir los tratados por LENGTH(CODIGO_UNICO_AGENTE) > 10 y que se traten dos veces
	| Version: 0.1	RMF 20250303	Initial Version.
	|
    -----------------------------------------------------------------------
*/

BEGIN

	USING SQLSCRIPT_STRING AS LIBRARY;
	USING SQLSCRIPT_SYNC AS SYNCLIB;--Para pruebas de Control-M
	
	DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_count_bucle INTEGER := 0;
	DECLARE v_existe_tabla INTEGER := 0;
	
	--CONSTANTES DE ESTADO
	DECLARE v_const_calculo_status_ok		INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_OK; --6
	DECLARE v_const_calculo_status_error	INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_ERROR;--7
	DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK;--2

	--CONSTANTES DE NOMBRES DE FICHEROS EMITIDOS
	DECLARE v_const_emi_diario_rrtt_eterna	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_ETERNA; -- AFLFTP162502P
	DECLARE v_const_emi_diario_rrtt_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_OCASO; --OFLFTP162402P
	DECLARE v_const_emi_diario_rrggrrpp_et	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_ET; --ABLFTP162702P
	DECLARE v_const_emi_diario_rrggrrpp_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_OC; --OBLFTP162602P
	DECLARE v_const_emi_diario_solnet_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_SOLNET_OCASO; --OBLFTPSOL162602P
	--CONSTANTES DE NOMBRES DE FICHEROS CARTERA
	DECLARE v_const_cartera_rrtt_eterna	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_RRTT_ETERNA; --AFLFTP162902P
	DECLARE v_const_cartera_rrtt_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_RRTT_OCASO; --OFLFTP162802P
	DECLARE v_const_cartera_rrggrrpp_eterna	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_RRGGRRPP_ETERNA; --ABLFTP163102P
	DECLARE v_const_cartera_rrggrrpp_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_RRGGRRPP_OCASO; --OBLFTP163002P
	DECLARE v_const_minicartera_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_MINICARTERA_OCASO; --OBLFTP163702P
	DECLARE v_const_cartera_solnet_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_SOLNET_OCASO; --OBLFTPSOL163002P
	--CONSTANTES DE NOMBRES DE FICHEROS COBRADO
	DECLARE v_const_cobros_rrtt_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRTT_OCASO; --OFLFTP163202P
	DECLARE v_const_cobros_rrtt_eterna	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRTT_ETERNA; --AFLFTP163302P
	DECLARE v_const_cobros_rrggrrpp_eterna	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGGRRPP_ETERNA; --ABLFTP165402P
	DECLARE v_const_cobros_rrggrrpp_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGGRRPP_OCASO; --OBLFTP165302P
	DECLARE v_const_cobros_solnet_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_SOLNET_OCASO; --OBLFTPSOL165302P
	DECLARE v_const_cobros_rrtt_ocaso_serco	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRTT_OCASO_SERCO; --OFLFTP195102P
	DECLARE v_const_cobros_rrtt_eterna_serco	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRTT_ETERNA_SERCO; --AFLFTP195202P
	DECLARE v_const_cobros_rrgg_ocaso_serco	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGG_OCASO_SERCO; --ORLFTP195102P
	DECLARE v_const_cobros_rrgg_eterna_serco	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGG_ETERNA_SERCO; --ARLFTP195202P
	DECLARE v_const_cobros_solnet_serco	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_SOLNET_SERCO; --ORLFTPSOL195102P

	
	--CONSTANTES GENERALES
	DECLARE v_const_s VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S;
	DECLARE v_const_n VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N;
	
	--CONSTANTES DE RAMOS
	DECLARE v_const_ramo_rrtt VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRTT;
	DECLARE v_const_ramo_rrgg VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRGG;
	DECLARE v_const_ramo_rrpp VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRPP;
	
	--CONSTANTES DE RECIBOS ESPECIFICOS
	DECLARE v_const_recibos_especificos_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
	DECLARE v_const_recibos_especificos_10 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_10;
	DECLARE v_const_recibos_especificos_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
	DECLARE v_const_recibos_especificos_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
	DECLARE v_const_recibos_especificos_16 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_16;
	DECLARE v_const_recibos_cartera_81 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_81;
	
	--CONSTANTES DE CODIGOS DE RECIBO
	DECLARE v_const_cod_recibo_anul_rrggpp VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRGGPP;
	DECLARE v_const_cod_recibo_anul_rrtt VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRTT;
	
	--CONSTANTES DE ESTADOS DE RECIBO
	DECLARE v_const_recibo_cobrado VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
	
	DECLARE v_const_no_encontrado VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_NO_ENCONTRADO; 

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																												
			
			--v_hayError := 1;
			v_num_rows := 0;
		
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_calculo_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				-- AND ID_PROCESO = v_idproceso
				;
			commit;	
			RESIGNAL;
		
		END;
	
	
	BEGIN
		
		--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_idproceso, 'info');
		
		--Nombre de fichero de salida
		o_file_name = 'OUT_CALCULO_'||TO_VARCHAR(CURRENT_TIMESTAMP,'YYYYMMDD_HH24MISS')||'.txt';
		
		--Eliminar tras pruebas de Control-M
		/*IF SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') = :v_const_emi_diario_rrtt_ocaso THEN
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name, 'Sleeping 10 minutes...', v_log_count, v_idproceso, 'info');
		CALL SYNCLIB:SLEEP_SECONDS(120);
		END IF;*/
		
		
		--FT_REGENERAR_TABLAS_GENERALES
		
		TBL_GEN_FORMAS_PAGO = SELECT * FROM EXT.VW_FORMAS_PAGO;
		v_num_rows = RECORD_COUNT(:TBL_GEN_FORMAS_PAGO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_FORMAS_PAGO creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
	
		TBL_GEN_MOTIVOS_ALTA = SELECT * FROM EXT.VW_MOTIVOS_ALTA;
		v_num_rows = RECORD_COUNT(:TBL_GEN_MOTIVOS_ALTA);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_MOTIVOS_ALTA creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
        		
		TBL_GEN_MOTIVOS_BAJA = SELECT * FROM EXT.VW_MOTIVOS_BAJA;
		v_num_rows = RECORD_COUNT(:TBL_GEN_MOTIVOS_BAJA);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_MOTIVOS_BAJA creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
		
		
		TBL_GEN_PRODUCTOS = SELECT * FROM EXT.VW_GEN_PRODUCTOS;
		v_num_rows = RECORD_COUNT(:TBL_GEN_PRODUCTOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_PRODUCTOS creada. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
		
		--Guardamos en una variable tabla información sobre jerarquía
		TBL_GEN_CODIGOS_AGENTE = SELECT * FROM EXT.VW_CODIGOS_DE_AGENTE VW
								WHERE 1=1
									AND VW.CODIGO_OCASO <> '0' 
									AND VW.CODIGO_OCASO <> '000000000' 
									AND VW.CODIGO_OCASO <> '0000000000'
								;
								
		v_num_rows = RECORD_COUNT(:TBL_GEN_CODIGOS_AGENTE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_CODIGOS_AGENTE creada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');		
      	
    	
    	--FT_INI_REC_OFICCOBPER20
    	--Monta una tabla temporal con la mínima fecha efectiva de inicio y con la máxima fecha efectiva de fin para las distintas oficinas
        TBL_C_OFIC = SELECT POS.GENERICATTRIBUTE3 AS COD_OCASO
        					, SUBSTR(POS.GENERICATTRIBUTE3,1,4) AS OFI_COBRADORA
        					, v_const_s AS ES_PERMANENCIA_20
			        		, MIN(POS.EFFECTIVESTARTDATE) AS FECHA_DESDE
			        		, MAX(POS.EFFECTIVEENDDATE) AS FECHA_HASTA
			        FROM TCMP.CS_POSITION POS
			        WHERE POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
			        	AND POS.GENERICNUMBER2 = 100
			        	AND POS.TITLESEQ <> 5629499534213290 --Se filtra por TTL distinto de TTL SIN PLAN
			        GROUP BY POS.GENERICATTRIBUTE3
			        --ORDER BY 1, 3
			        --Añadimos agencias del corte inglés
			        UNION ALL
						SELECT '0940', '0940', :v_const_s, TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy
					UNION ALL
						SELECT '0946', '0946', :v_const_s, TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy
			        ;
		
		v_num_rows = RECORD_COUNT(:TBL_C_OFIC);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFIC creada: ' || v_num_rows || ' filas. Indicador de es_PERMANENCIA_20 con fechas de efectividad', v_log_count, v_idproceso, 'debug');	
	
		--FT_CALCULAR_RECIBO_FICHERO
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en DELETE en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_calculo_status_error
						, FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE CODIGO_RECIBO LIKE '%+'
						AND FILE_NAME = i_file_name
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
					
			DELETE FROM EXT.RECIBOS
			WHERE CODIGO_RECIBO LIKE '%+'
				AND FILE_NAME = i_file_name;
			
			v_num_rows := ::rowcount;
	        
	    	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin DELETE en RECIBOS para recibos %+. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
	    	
	    END;
	    
	    BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en DELETE en GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_calculo_status_error
						, FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE CODIGO_RECIBO LIKE '%+'
						AND FILE_NAME = i_file_name
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
					
			DELETE FROM EXT.GARANTIAS_RECIBO
			WHERE CODIGO_RECIBO LIKE '%+'
				AND FILE_NAME = i_file_name;
			
			v_num_rows := ::rowcount;
		        
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin DELETE en GARANTIAS_RECIBO para recibos %+. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
	    	
	    END;
			
		
	    --Nos quedamos con los recibos cuyo FILE_NAME es el que llega como parámetro, MARCA_CUENTA = S O PERMANENCIA 65
	    TBL_C_RECIBOS = SELECT TBL.*
        				FROM EXT.RECIBOS TBL
                        WHERE TBL.FILE_NAME = :i_file_name
                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS creada: ' || v_num_rows || ' filas. Recibos con MARCA_CUENTA o PERMANENCIA = 65 ', v_log_count, v_idproceso, 'debug');
		
		--Nos quedamos con las pólizas para las que tenemos recibo en TBL_C_RECIBOS
		TBL_C_POLIZAS = SELECT TBL.*
        				FROM EXT.POLIZAS TBL
                        WHERE EXISTS (SELECT 1
                        				FROM :TBL_C_RECIBOS src
                        				WHERE src.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        )
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_POLIZAS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_POLIZAS creada: ' || v_num_rows || ' filas. Pólizas existentes para los recibos de TBL_C_RECIBOS', v_log_count, v_idproceso, 'debug');
        
        --FT_CALCULAR_RECIBO
        --Se llama a los procedimientos de calculo de extornos de RRTT y de RRGGPP
        --Se mira el nombre de fichero para saber a que proceso de calculo debemos llamar
        
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Comprobacion Extornos', v_log_count, v_idproceso, 'info');

		IF SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') IN  (	:v_const_emi_diario_rrtt_eterna,
																	:v_const_emi_diario_rrtt_ocaso--,
																	--:v_const_cartera_rrtt_eterna,
																	--:v_const_cartera_rrtt_ocaso
																) THEN
			--Se llama el calculo de Extornos de RRTT
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se llama al paquete de Extonos RRTT', v_log_count, v_idproceso, 'info');

			CALL EXT.SP_CALCULO_EXTORNOS_RRTT(i_file_name,v_idproceso, v_log_count);
			
		END IF;
		 
		IF SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') IN  (	:v_const_emi_diario_rrggrrpp_et,
																	:v_const_emi_diario_rrggrrpp_ocaso,
																	:v_const_emi_diario_solnet_ocaso
																) THEN
																
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se llama al paquete de Extonos RRGG', v_log_count, v_idproceso, 'info');
		
			--Se llama al calculo de Extornos de RRGG
			CALL EXT.SP_CALCULO_EXTORNOS_RRGG_RRPP(i_file_name,v_idproceso, v_log_count);
			
		END IF;
        
        --FT_INICIALIZAR_RECIBO
        --Los recibos que vamos a tratar son aquellos que ESTADO = POPULATE_OK y CODIGO_RECIBO no es ANUL_RRGGPP ni ANUL_RRTT
        TBL_RECIBOS_A_CALCULAR = SELECT REC.*
        							, POL.FORMA_PAGO
        						FROM :TBL_C_RECIBOS REC
        						INNER JOIN :TBL_C_POLIZAS POL ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA
        						WHERE REC.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
        							--AND (REC.MARCA_CUENTA = :v_const_s OR src.PERMANENCIA = :v_const_recibos_especificos_65)
        							AND REC.ESTADO = :v_const_populate_status_ok
                				;
                				
        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_CALCULAR);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_CALCULAR creada: ' || v_num_rows || ' filas. Cruce con POLIZAS cuando el recibo no es de anulación', v_log_count, v_idproceso, 'debug');
                				
        --Llamada a FT_CALCULAR_RECIBO_COMUN
        --		Llamada a FT_MESES_COBRADOS // Comentado con Alberto que no se usa actualmente porque no calcula bien los meses cobrados para todos los casos
        --		Llamada a FT_GET_COD_COMMISSIONS_AGENTE_DB
        --		Llamada a FT_COD_AGENTE_COMMISIONS
        --		Llamada a FT_CALCULA_EDAD_ASE
        --		Llamada a FT_ACTUALIZA_CARTERA
        --		Llamada a FT_ACTUALIZA_PRIMA_NETA_ANUAL
        --		Llamada a FT_ACTUALIZA_PORC_COM_NP_CONS
        
        --FT_GET_COD_COMMISSIONS_AGENTE_DB
        --TBL_GET_COD_COMMISSIONS_AGENTE_DB se queda con los registros de RECIBOS_A_CALCULAR cuya longitud es mayor estricto de 10
        TBL_GET_COD_COMMISSIONS_AGENTE_DB = SELECT TBL.IDENTIFICADOR
												, TBL.FILE_NAME
												, TBL.ESTADO
												, TBL.FECHA_MODIFICACION
												--, TBL.ZONA_EXPLOTACION
												--, TBL.CODIGO_AGENTE_ZONA
												, TBL.CODIGO_POLIZA
												, TBL.CODIGO_RECIBO
												, TBL.PERMANENCIA
												--, TBL.TIPO_RECIBO
												, TBL.ESTADO_RECIBO
												--, TBL.FECHA_COBRO
												--, TBL.FECHA_COMPENSACION
												, TBL.FECHA_EFECTO_RECIBO
												--, TBL.FECHA_VTO_RECIBO
												-- , TBL.TIPO_MOVIMIENTO
												-- , TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
												-- , TBL.VALOR_POLIZA
												, TBL.CODIGO_UNICO_AGENTE
												, TBL.CODIGO_AGENTE_ORIGINAL
												-- , TBL.INSPECTOR
												-- , TBL.OFICINA_COBRADORA
												-- , TBL.OFICINA_GESTORA
												-- , TBL.MARCA_RECUPERADO
												-- , TBL.MARCA_CUENTA
												-- , TBL.PRIMER_RECIBO
												-- , TBL.ASEGURADOS_NETOS
												-- , TBL.AUMENTO_ASEGURADOS
												-- , TBL.EXCLUIDO_COMISIONES
												-- , TBL.BONIFICACION_POLIZA
												-- , TBL.DISMINUCION_PRIMA
												-- , TBL.TIPO_RECUPERACION
												-- , TBL.ES_PERMANENCIA_20
												, TBL.CODIGO_AGENTE_COMMISSIONS
												-- , TBL.FECHA_EMISION_REC
												-- , TBL.FCHA_EFECTO_SUPLEMENTO
												 , TBL.CODIGO_SUPLEMENTO
												-- , TBL.DISTRITO_COBRO
												-- , TBL.CODIGO_SINIESTRO
												-- , TBL.FORMA_PAGO
											FROM :TBL_RECIBOS_A_CALCULAR TBL
											--WHERE LENGTH(TBL.CODIGO_UNICO_AGENTE) > 10
											WHERE LENGTH(IFNULL(TBL.CODIGO_UNICO_AGENTE,'0')) > 10
											;
        									
        v_num_rows = RECORD_COUNT(:TBL_GET_COD_COMMISSIONS_AGENTE_DB);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GET_COD_COMMISSIONS_AGENTE_DB creada: ' || v_num_rows || ' filas. Recibos cuyo CODIGO_UNICO_AGENTE es LENGTH > 10', v_log_count, v_idproceso, 'debug');
        
        --Se cruza la tabla TBL_GEN_CODIGOS_AGENTE con TBL_GET_COD_COMMISSIONS_AGENTE_DB por CODIGO_UNICO = CODIGO_UNICO_AGENTE
        TBL_CODIGOS_AGENTE_1 = SELECT TBL.*
        					, IFNULL(COD.CODIGO_UNICO,:v_const_no_encontrado) AS V_CODIGO_AGENTE_UNICO_1
        					, COD.CODIGO_OCASO AS V_CODIGO_OCASO_1
        					, ROW_NUMBER() OVER (
	        					--PARTITION BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA, COD.CODIGO_UNICO, COD.CODIGO_OCASO 
	        					PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_UNICO_AGENTE, TBL.CODIGO_RECIBO
	        					ORDER BY
	        						COD.EFFECTIVESTARTDATE DESC
	        						, COD.EFFECTIVEENDDATE DESC
	        						, CASE WHEN TBL.CODIGO_UNICO_AGENTE = COD.CODIGO_OCASO 
	        							THEN 1 
	        							ELSE 2 
	        						END ASC
	        					) AS ROW_NUM_1
        				FROM :TBL_GEN_CODIGOS_AGENTE COD
        				RIGHT JOIN :TBL_GET_COD_COMMISSIONS_AGENTE_DB TBL
        					ON TBL.CODIGO_UNICO_AGENTE = COD.CODIGO_UNICO
        				;
        
        v_num_rows = RECORD_COUNT(:TBL_CODIGOS_AGENTE_1);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_CODIGOS_AGENTE_1 creada: ' || v_num_rows || ' filas. Se cruza la tabla TBL_GEN_CODIGOS_AGENTE con TBL_GET_COD_COMMISSIONS_AGENTE_DB por CODIGO_UNICO = CODIGO_UNICO_AGENTE', v_log_count, v_idproceso, 'debug');
		
		--Filtramos por ROW_NUM_1 la tabla TBL_CODIGOS_AGENTE_1 (particionado por TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA, COD.CODIGO_UNICO, COD.CODIGO_OCASO)
		--y se actualiza el valor de CODIGO_AGENTE_COMMISSIONS con los valores de la tabla anterior
		TBL_AGENTE_COD_UNICO_AG_1 = SELECT TBL.IDENTIFICADOR
											, TBL.FILE_NAME
											, TBL.ESTADO
											, TBL.FECHA_MODIFICACION
											-- , TBL.ZONA_EXPLOTACION
											-- , TBL.CODIGO_AGENTE_ZONA
											, TBL.CODIGO_POLIZA
											, TBL.CODIGO_RECIBO
											, TBL.PERMANENCIA
											-- , TBL.TIPO_RECIBO
											, TBL.ESTADO_RECIBO
											-- , TBL.FECHA_COBRO
											-- , TBL.FECHA_COMPENSACION
											, TBL.FECHA_EFECTO_RECIBO
											-- , TBL.FECHA_VTO_RECIBO
											-- , TBL.TIPO_MOVIMIENTO
											-- , TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
											-- , TBL.VALOR_POLIZA
											, TBL.V_CODIGO_OCASO_1 AS CODIGO_UNICO_AGENTE
											, TBL.V_CODIGO_OCASO_1 AS CODIGO_AGENTE_ORIGINAL
											-- , TBL.INSPECTOR
											-- , TBL.OFICINA_COBRADORA
											-- , TBL.OFICINA_GESTORA
											-- , TBL.MARCA_RECUPERADO
											-- , TBL.MARCA_CUENTA
											-- , TBL.PRIMER_RECIBO
											-- , TBL.ASEGURADOS_NETOS
											-- , TBL.AUMENTO_ASEGURADOS
											-- , TBL.EXCLUIDO_COMISIONES
											-- , TBL.BONIFICACION_POLIZA
											-- , TBL.DISMINUCION_PRIMA
											-- , TBL.TIPO_RECUPERACION
											-- , TBL.ES_PERMANENCIA_20
											, CASE WHEN TBL.V_CODIGO_AGENTE_UNICO_1 = :v_const_no_encontrado --Si es NO_ENCONTRADO mantenemos el valor que tenía el campo CODIGO_UNICO_AGENTE para las siguientes comprobaciones
												THEN TBL.CODIGO_UNICO_AGENTE
												ELSE TBL.V_CODIGO_AGENTE_UNICO_1 
											END AS CODIGO_AGENTE_COMMISSIONS
											-- , TBL.FECHA_EMISION_REC
											-- , TBL.FCHA_EFECTO_SUPLEMENTO
											 , TBL.CODIGO_SUPLEMENTO
											-- , TBL.DISTRITO_COBRO
											-- , TBL.CODIGO_SINIESTRO
											-- , TBL.FORMA_PAGO
											, TBL.V_CODIGO_AGENTE_UNICO_1
											, TBL.V_CODIGO_OCASO_1
									FROM :TBL_CODIGOS_AGENTE_1 TBL 
									WHERE 1 = 1
										AND TBL.ROW_NUM_1 = 1
        						;
        						
        v_num_rows = RECORD_COUNT(:TBL_AGENTE_COD_UNICO_AG_1);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_AGENTE_COD_UNICO_AG_1 creada: ' || v_num_rows || ' filas. Filtramos por ROW_NUM_1 la tabla TBL_CODIGOS_AGENTE_1 (particionado por TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA, COD.CODIGO_UNICO, COD.CODIGO_OCASO) y se actualiza el valor de CODIGO_AGENTE_COMMISSIONS con los valores de la tabla anterior.', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE1 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
					SET x.ESTADO = :v_const_calculo_status_error
						, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_AGENTE_COD_UNICO_AG_1 TBL
					WHERE x.IDENTIFICADOR = TBL.IDENTIFICADOR
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						AND TBL.V_CODIGO_AGENTE_UNICO_1 <> :v_const_no_encontrado
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
		
			--Se actualizan los campos de CODIGO_AGENTE para aquellos casos en los que se haya cruzado el CODIGO_UNICO con la tabla de jerarquía
			UPDATE EXT.RECIBOS x
			SET x.CODIGO_UNICO_AGENTE = TBL.CODIGO_UNICO_AGENTE
				, x.CODIGO_AGENTE_ORIGINAL = TBL.CODIGO_AGENTE_ORIGINAL
				, x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_AGENTE_COMMISSIONS,:v_const_no_encontrado)
				--, x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_AGENTE_COMMISSIONS
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.RECIBOS x, :TBL_AGENTE_COD_UNICO_AG_1 TBL
			WHERE x.IDENTIFICADOR = TBL.IDENTIFICADOR
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				AND TBL.V_CODIGO_AGENTE_UNICO_1 <> :v_const_no_encontrado
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE1 CODIGO_UNICO_AGENTE/CODIGO_AGENTE_ORIGINAL/CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
			
		END;
		
		--Se tratan los registros para los que el CODIGO_AGENTE_UNICO ha quedado como NO_ENCONTRADO
		TBL_CODIGOS_AGENTE_NO_ENCONTRADO = SELECT TBL.*
											FROM :TBL_AGENTE_COD_UNICO_AG_1 TBL
											WHERE 1 = 1
												AND TBL.V_CODIGO_AGENTE_UNICO_1 = :v_const_no_encontrado
											;
											
		v_num_rows = RECORD_COUNT(:TBL_CODIGOS_AGENTE_NO_ENCONTRADO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_CODIGOS_AGENTE_NO_ENCONTRADO creada: ' || v_num_rows || ' filas. Se tratan los registros para los que el CODIGO_AGENTE_UNICO ha quedado como NO_ENCONTRADO', v_log_count, v_idproceso, 'debug');
		
		TBL_CODIGOS_AGENTE_2 = SELECT TBL.*
        					, IFNULL(COD.CODIGO_UNICO,:v_const_no_encontrado) AS V_CODIGO_AGENTE_UNICO_2
        					, COD.CODIGO_OCASO AS V_CODIGO_OCASO_2
        					, ROW_NUMBER() OVER (
	        					--PARTITION BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA, COD.CODIGO_UNICO, COD.CODIGO_OCASO
	        					PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_AGENTE_ORIGINAL, TBL.CODIGO_RECIBO
	        					ORDER BY
	        						COD.EFFECTIVESTARTDATE DESC
	        						, COD.EFFECTIVEENDDATE DESC
	        						, CASE WHEN TBL.CODIGO_AGENTE_ORIGINAL = COD.CODIGO_OCASO 
	        							THEN 1 
	        							ELSE 2 
	        						END ASC
	        					) AS ROW_NUM_2
        				FROM :TBL_GEN_CODIGOS_AGENTE COD
        				RIGHT JOIN :TBL_CODIGOS_AGENTE_NO_ENCONTRADO TBL
        					ON TBL.CODIGO_AGENTE_ORIGINAL = COD.CODIGO_UNICO
        				;
        				
        v_num_rows = RECORD_COUNT(:TBL_CODIGOS_AGENTE_2);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_CODIGOS_AGENTE_2 creada: ' || v_num_rows || ' filas. Se cruza la tabla TBL_GEN_CODIGOS_AGENTE con TBL_CODIGOS_AGENTE_NO_ENCONTRADO por CODIGO_UNICO = CODIGO_AGENTE_ORIGINAL', v_log_count, v_idproceso, 'debug');
        
        TBL_AGENTE_COD_UNICO_AG_2 = SELECT TBL.IDENTIFICADOR
											, TBL.FILE_NAME
											, TBL.ESTADO
											, TBL.FECHA_MODIFICACION
											-- , TBL.ZONA_EXPLOTACION
											-- , TBL.CODIGO_AGENTE_ZONA
											, TBL.CODIGO_POLIZA
											, TBL.CODIGO_RECIBO
											, TBL.PERMANENCIA
											-- , TBL.TIPO_RECIBO
											, TBL.ESTADO_RECIBO
											-- , TBL.FECHA_COBRO
											-- , TBL.FECHA_COMPENSACION
											, TBL.FECHA_EFECTO_RECIBO
											-- , TBL.FECHA_VTO_RECIBO
											-- , TBL.TIPO_MOVIMIENTO
											-- , TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
											-- , TBL.VALOR_POLIZA
											, CASE WHEN TBL.V_CODIGO_AGENTE_UNICO_2 = :v_const_no_encontrado
												THEN NULL
												ELSE TBL.V_CODIGO_OCASO_2 
											END AS CODIGO_UNICO_AGENTE
											, TBL.V_CODIGO_OCASO_2 AS CODIGO_AGENTE_ORIGINAL
											-- , TBL.INSPECTOR
											-- , TBL.OFICINA_COBRADORA
											-- , TBL.OFICINA_GESTORA
											-- , TBL.MARCA_RECUPERADO
											-- , TBL.MARCA_CUENTA
											-- , TBL.PRIMER_RECIBO
											-- , TBL.ASEGURADOS_NETOS
											-- , TBL.AUMENTO_ASEGURADOS
											-- , TBL.EXCLUIDO_COMISIONES
											-- , TBL.BONIFICACION_POLIZA
											-- , TBL.DISMINUCION_PRIMA
											-- , TBL.TIPO_RECUPERACION
											-- , TBL.ES_PERMANENCIA_20
											, CASE WHEN TBL.V_CODIGO_AGENTE_UNICO_2 = :v_const_no_encontrado
												THEN TBL.CODIGO_AGENTE_COMMISSIONS --Hemos mantenido previamente el CODIGO_UNICO_ORIGINAL en TBL_AGENTE_COD_UNICO_AG1
												ELSE TBL.V_CODIGO_AGENTE_UNICO_2 
											END AS CODIGO_AGENTE_COMMISSIONS
											-- , TBL.FECHA_EMISION_REC 
											-- , TBL.FCHA_EFECTO_SUPLEMENTO
											 , TBL.CODIGO_SUPLEMENTO
											-- , TBL.DISTRITO_COBRO
											-- , TBL.CODIGO_SINIESTRO
											-- , TBL.FORMA_PAGO
											, TBL.V_CODIGO_AGENTE_UNICO_1
											, TBL.V_CODIGO_OCASO_1
											, TBL.V_CODIGO_AGENTE_UNICO_2
											, TBL.V_CODIGO_OCASO_2
									FROM :TBL_CODIGOS_AGENTE_2 TBL 
									WHERE 1 = 1
										AND TBL.ROW_NUM_2 = 1
        						;
        						
        v_num_rows = RECORD_COUNT(:TBL_AGENTE_COD_UNICO_AG_2);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_AGENTE_COD_UNICO_AG_2 creada: ' || v_num_rows || ' filas. Filtramos por ROW_NUM_2 la tabla TBL_CODIGOS_AGENTE_2 (particionado por TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA, COD.CODIGO_UNICO, COD.CODIGO_OCASO) y se actualiza el valor de CODIGO_AGENTE_ORIGINAL, CODIGO_AGENTE_COMMISSIONS con los valores de la tabla anterior.', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE2 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
					SET x.ESTADO = :v_const_calculo_status_error
						, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.RECIBOS x, :TBL_AGENTE_COD_UNICO_AG_2 TBL
					WHERE x.IDENTIFICADOR = TBL.IDENTIFICADOR
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
					
					COMMIT;
					
					RESIGNAL;
					
				END;
		
			--Se actualizan los campos de CODIGO_AGENTE para aquellos casos en los que se haya cruzado el CODIGO_ORIGINAL con la tabla de jerarquía y los que no han cruzado
			UPDATE EXT.RECIBOS x
			SET x.CODIGO_UNICO_AGENTE = TBL.CODIGO_UNICO_AGENTE
				, x.CODIGO_AGENTE_ORIGINAL = TBL.CODIGO_AGENTE_ORIGINAL
				, x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_AGENTE_COMMISSIONS,:v_const_no_encontrado)
			--	,x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_AGENTE_COMMISSIONS
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.RECIBOS x, :TBL_AGENTE_COD_UNICO_AG_2 TBL
			WHERE x.IDENTIFICADOR = TBL.IDENTIFICADOR
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE2 CODIGO_UNICO_AGENTE/CODIGO_AGENTE_ORIGINAL/CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		END;
        
        --FT_GET_COD_COMMISSIONS_AGENTE_DB/FT_COMPROBAR_MANAGER_COLABORADOR
        --Llamada recursiva para encontrar el manager y asignarle a él la transaccion en el futuro
        --Bucle loop que se quede solo con los códigos cuyo tipo agente principal es 15 y vaya actualizando en EXT.RECIBOS a cada vuelta
        --Recargamos la tabla temporal de RECIBOS
        
        TBL_C_RECIBOS = SELECT TBL.*
        				FROM EXT.RECIBOS TBL
                        WHERE TBL.FILE_NAME = :i_file_name
                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
                        	AND TBL.ESTADO = :v_const_populate_status_ok
                        	AND TBL.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
                        	--AND LENGTH(TBL.CODIGO_UNICO_AGENTE) > 10 --Condición para FT_GET_COD_COMMISSIONS_AGENTE_DB
                        	--20251024 RMF:Cambiamos la condición para tratar únicamente los registros que se han tratado en las tablas anteriores TBL_AGENTE_COD_UNICO_AG_1 y TBL_AGENTE_COD_UNICO_AG_2
                        	--AND LENGTH(IFNULL(TBL.CODIGO_UNICO_AGENTE,'0')) > 10 --Condición para FT_GET_COD_COMMISSIONS_AGENTE_DB
                        	AND EXISTS(SELECT 1 
                    					FROM :TBL_AGENTE_COD_UNICO_AG_1 REC
                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                    		   	)
                    		AND EXISTS(SELECT 1
                    					FROM :TBL_AGENTE_COD_UNICO_AG_2 REC
                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                    		)
                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS actualizada: ' || v_num_rows || ' filas. Se recarga TBL_C_RECIBOS con la información actualizada de EXT.RECIBOS', v_log_count, v_idproceso, 'debug');
        
        --Para cada CODIGO_AGENTE_COMMISSIONS nos quedamos con su máximo TIPO_AGENTE_PRIN
        TBL_MAX_AGE_TIPO_PRIN = SELECT TBL.CODIGO_AGENTE_COMMISSIONS AS CODIGO_UNICO
        							, MAX(AGE.TIPO_AGENTE_PRIN) AS TIPO_AGENTE_PRIN
        						FROM :TBL_C_RECIBOS TBL
        						LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE
        							ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
        								AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
        								AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
        						GROUP BY TBL.CODIGO_AGENTE_COMMISSIONS
        						;
        						
        v_num_rows = RECORD_COUNT(:TBL_MAX_AGE_TIPO_PRIN);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_MAX_AGE_TIPO_PRIN creada: ' || v_num_rows || ' filas. Para cada CODIGO_AGENTE_COMMISSIONS nos quedamos con su máximo TIPO_AGENTE_PRIN', v_log_count, v_idproceso, 'debug');
        
        --Nos quedamos solo con aquellos cuyo TIPO_AGENTE_PRIN = 15
        TBL_C_RECIBOS_AGE_15 = SELECT TBL.*
        						FROM :TBL_C_RECIBOS TBL
        						WHERE EXISTS (SELECT 1 
        										FROM :TBL_MAX_AGE_TIPO_PRIN AGE
        										WHERE AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
        											AND AGE.TIPO_AGENTE_PRIN = 15
        									)
        						;
        						
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15 creada: ' || v_num_rows || ' filas. Nos quedamos solo con aquellos recibos cuyo TIPO_AGENTE_PRIN = 15', v_log_count, v_idproceso, 'debug');
        
        WHILE NOT(IS_EMPTY(:TBL_C_RECIBOS_AGE_15)) DO
        	
        	v_count_bucle := v_count_bucle + 1;
        	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio del bucle mientras haya registros con TIPO_AGENTE_PRIN = 15. Vuelta ' || :v_count_bucle, v_log_count, v_idproceso, 'debug');
        	--Se separa en dos partes, una para PERMANENCIA 16 y otra para el resto. El manager de PERMANENCIA 16 se busca por FECHA_COMPENSACION, el resto por FECHA_EMISION_REC
        	--Registros con PERMANENCIA = 16
        	TBL_C_RECIBOS_AGE_15_PERM_16 = SELECT TBL.*
        									FROM :TBL_C_RECIBOS_AGE_15 TBL
        									WHERE TBL.PERMANENCIA = :v_const_recibos_especificos_16
        									;
        	
        	v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_16);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_16 creada: ' || v_num_rows || ' filas. Registros con PERMANENCIA = 16', v_log_count, v_idproceso, 'debug');
        	
        	--Registros con PERMANENCIA <> 16
        	TBL_C_RECIBOS_AGE_15_PERM_NO_16 = SELECT TBL.*
	        									FROM :TBL_C_RECIBOS_AGE_15 TBL
	        									WHERE TBL.PERMANENCIA <> :v_const_recibos_especificos_16
	        								;
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_NO_16);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_NO_16 creada: ' || v_num_rows || ' filas. Registros con PERMANENCIA <> 16', v_log_count, v_idproceso, 'debug');
	        
	        --Se cruzan los registros de PERMANENCIA = 16 con TBL_GEN_CODIGOS_AGENTE (por CODIGO_UNICO = CODIGO_AGENTE_COMMISSIONS y FECHA_COMPENSACION) y se añade ROW_NUM particionado por TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        TBL_C_RECIBOS_AGE_15_PERM_16_RN = SELECT TBL.*
	        										, AGE.MANAGERSEQ
	        										, ROW_NUMBER() OVER (
	        											PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        											ORDER BY AGE.EFFECTIVEENDDATE DESC
	        										) AS ROW_NUM
	        								FROM :TBL_C_RECIBOS_AGE_15_PERM_16 TBL
	        								LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
	        									AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
	        									AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
	        							;
	        
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_16_RN);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_16_RN creada: ' || v_num_rows || ' filas. Se cruzan los registros de PERMANENCIA = 16 con TBL_GEN_CODIGOS_AGENTE (por CODIGO_UNICO = CODIGO_AGENTE_COMMISSIONS y FECHA_COMPENSACION) y se añade ROW_NUM particionado por TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS', v_log_count, v_idproceso, 'debug');
	        							
	        TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN = SELECT TBL.*
	        										, AGE.MANAGERSEQ
	        										, ROW_NUMBER() OVER (
	        											PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        											ORDER BY AGE.EFFECTIVEENDDATE DESC
	        										) AS ROW_NUM
		        								FROM :TBL_C_RECIBOS_AGE_15_PERM_NO_16 TBL
		        								LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
		        									AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_EMISION_REC)
		        									AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_EMISION_REC)
	        							;
	        
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN creada: ' || v_num_rows || ' filas. Se cruzan los registros de PERMANENCIA <> 16 con TBL_GEN_CODIGOS_AGENTE (por CODIGO_UNICO = CODIGO_AGENTE_COMMISSIONS y FECHA_EMISION_REC) y se añade ROW_NUM particionado por TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS', v_log_count, v_idproceso, 'debug');
	        
	        --Unimos ambas tablas porque se van a tratar igual
	        TBL_RECIBOS_AGE_15_A_TRATAR = SELECT * FROM :TBL_C_RECIBOS_AGE_15_PERM_16_RN
	        						UNION ALL SELECT * FROM :TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_AGE_15_A_TRATAR);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_AGE_15_A_TRATAR creada: ' || v_num_rows || ' filas. UNION ALL de tablas TBL_C_RECIBOS_AGE_15_PERM_16_RN y TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN', v_log_count, v_idproceso, 'debug');
	        
	        --Se añade RULEELEMENTOWNERSEQ y NAME de la position del MANAGER indicado en la TBL_RECIBOS_AGE_15_A_TRATAR para cada recibo	
	        TBL_RECIBOS_A_TRATAR = SELECT TBL.*
	        						, POS.RULEELEMENTOWNERSEQ AS EXISTE_MANAGER
	        						, POS.NAME AS MANAGER_NAME
	        						FROM :TBL_RECIBOS_AGE_15_A_TRATAR TBL
	        						LEFT JOIN TCMP.CS_POSITION POS ON TBL.MANAGERSEQ = POS.RULEELEMENTOWNERSEQ
	        							AND POS.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
	        							AND POS.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
	        							AND POS.REMOVEDATE = v_eot
	        							AND POS.TENANTID = v_idtenant
	        							AND POS.TITLESEQ <> 5629499534213290 --No se tienen en cuenta las que tienen TTL SIN PLAN
	        							AND TBL.ROW_NUM = 1
	        						;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR creada: ' || v_num_rows || ' filas. Se añade RULEELEMENTOWNERSEQ y NAME de la position del MANAGER indicado en la TBL_RECIBOS_AGE_15_A_TRATAR para cada recibo', v_log_count, v_idproceso, 'debug');
	        
	        --Recibos para los que se ha encontrado el manager
	        TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER = SELECT TBL.*
	        										FROM :TBL_RECIBOS_A_TRATAR TBL
	        										WHERE EXISTE_MANAGER IS NOT NULL
	        									;
	        									
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER creada: ' || v_num_rows || ' filas. Recibos para los que se ha encontrado el manager', v_log_count, v_idproceso, 'debug');
	        										
	        TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER = SELECT TBL.*
	        											FROM :TBL_RECIBOS_A_TRATAR TBL
	        											WHERE EXISTE_MANAGER IS NULL
	        										;
	        
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER creada: ' || v_num_rows || ' filas. Recibos para los que no se ha encontrado el manager', v_log_count, v_idproceso, 'debug');
	        
	        BEGIN
				DECLARE EXIT HANDLER FOR SQLEXCEPTION
					BEGIN
						
						ROLLBACK;
						
						CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE1 en RECIBOS para TIPO_PRINCIPAL 15 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
											
						UPDATE EXT.RECIBOS x
						SET x.ESTADO = :v_const_calculo_status_error
							, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER TBL
				    	WHERE 1 = 1
				    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				    	;
				    	
				    	COMMIT;
				    	
				    	RESIGNAL;
				    	
				    END;
						
		        --Se hace un update de RECIBOS para aquellos que existe el manager
		        UPDATE EXT.RECIBOS x
		        --SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.MANAGER_NAME,:v_const_no_encontrado)
		        SET x.CODIGO_AGENTE_COMMISSIONS = TBL.MANAGER_NAME
		        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		        FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER TBL
		    	WHERE 1 = 1
		    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
		    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
		    	;
	    	
		    	v_num_rows = ::rowcount;
			
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE CODIGO_AGENTE_COMMISSIONS en RECIBOS para TIPO_PRINCIPAL 15. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
															
			END;
			
			--RECIBOS para los que no existe el Manager
			TBL_RECIBOS_INSPECTOR_A_TRATAR_RN = SELECT TBL.*
												, CASE WHEN TBL.PERMANENCIA = :v_const_recibos_especificos_16 
													THEN IFNULL(AGE.CODIGO_UNICO,:v_const_no_encontrado)
													ELSE :v_const_no_encontrado 
												END AS MANAGER_NAME_2
												, ROW_NUMBER() OVER (
	        										PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        										ORDER BY AGE.EFFECTIVEENDDATE DESC
	        											, CASE WHEN TBL.INSPECTOR = AGE.CODIGO_OCASO
	        												THEN 1
	        												ELSE 2
	        											END ASC
	        									) AS ROW_NUM_INSP
											FROM :TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER TBL
											LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE
												ON AGE.CODIGO_UNICO = TBL.INSPECTOR
											;
											
			v_num_rows = RECORD_COUNT(:TBL_RECIBOS_INSPECTOR_A_TRATAR_RN);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_INSPECTOR_A_TRATAR_RN creada: ' || v_num_rows || ' filas. Se cruzan los recibos para los que no existe Manager con TBL_GEN_CODIGOS_AGENTE por CODIGO_UNICO = INSPECTOR', v_log_count, v_idproceso, 'debug');
			
			BEGIN
				DECLARE EXIT HANDLER FOR SQLEXCEPTION
					BEGIN
						
						ROLLBACK;
						
						CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE2 en RECIBOS para TIPO_PRINCIPAL 15 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
						UPDATE EXT.RECIBOS x
						SET x.ESTADO = :v_const_calculo_status_error
							, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS x, :TBL_RECIBOS_INSPECTOR_A_TRATAR_RN TBL
				    	WHERE 1 = 1
				    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				    		AND TBL.ROW_NUM_INSP = 1
				    	;
				    	
				    	COMMIT;
				    	
				    	RESIGNAL;
				    	
				    END;
						
		        UPDATE EXT.RECIBOS x
				SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.MANAGER_NAME_2,:v_const_no_encontrado)
				--SET x.CODIGO_AGENTE_COMMISSIONS = TBL.MANAGER_NAME_2
		        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		        FROM EXT.RECIBOS x, :TBL_RECIBOS_INSPECTOR_A_TRATAR_RN TBL
		    	WHERE 1 = 1
		    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
		    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
		    		AND TBL.ROW_NUM_INSP = 1
		    	;
				
				v_num_rows = ::rowcount;
			
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE2 CODIGO_AGENTE_COMMISSIONS en RECIBOS para TIPO_PRINCIPAL 15. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
															
			END;
											
			
			
			--Se vuelven a regenerar las tablas origen de antes del bucle para ir quitando registros. En cada vuelta tendrán que salir menos registros con tipo principal 15
			TBL_C_RECIBOS = SELECT TBL.*
	        				FROM EXT.RECIBOS TBL
	                        WHERE TBL.FILE_NAME = :i_file_name
	                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
	                        	AND TBL.ESTADO = :v_const_populate_status_ok
	                        	AND TBL.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
	                        	--AND LENGTH(TBL.CODIGO_UNICO_AGENTE) > 10 --Condición para FT_GET_COD_COMMISSIONS_AGENTE_DB
	                        	--20251024 RMF:Cambiamos la condición para tratar únicamente los registros que se han tratado en las tablas anteriores TBL_AGENTE_COD_UNICO_AG_1 y TBL_AGENTE_COD_UNICO_AG_2
	                        	--AND LENGTH(IFNULL(TBL.CODIGO_UNICO_AGENTE,'0')) > 10 --Condición para FT_GET_COD_COMMISSIONS_AGENTE_DB
	                        	AND EXISTS(SELECT 1 
	                    					FROM :TBL_AGENTE_COD_UNICO_AG_1 REC
	                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	                    		   	)
	                    		AND EXISTS(SELECT 1
	                    					FROM :TBL_AGENTE_COD_UNICO_AG_2 REC
	                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	                    		)
	                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
	                    	;
	                    	
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se vuelven a regenerar las tablas origen de antes del bucle para ir quitando registros', v_log_count, v_idproceso, 'debug');
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
			
	        TBL_MAX_AGE_TIPO_PRIN = SELECT TBL.CODIGO_AGENTE_COMMISSIONS AS CODIGO_UNICO
	        							, MAX(AGE.TIPO_AGENTE_PRIN) AS TIPO_AGENTE_PRIN
	        						FROM :TBL_C_RECIBOS TBL
	        						LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE
	        							ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
		        							AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
	        								AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
	        						GROUP BY TBL.CODIGO_AGENTE_COMMISSIONS
	        						;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_MAX_AGE_TIPO_PRIN);
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_MAX_AGE_TIPO_PRIN actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
	        
	        
	        TBL_C_RECIBOS_AGE_15 = SELECT TBL.*
	        						FROM :TBL_C_RECIBOS TBL
	        						WHERE EXISTS (SELECT 1 
	        										FROM :TBL_MAX_AGE_TIPO_PRIN AGE
	        										WHERE AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
	        											AND AGE.TIPO_AGENTE_PRIN = 15
	        									)
	        						;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15);
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15 actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin de vuelta ' || :v_count_bucle || ' del bucle TIPO_AGENTE_PRIN = 15', v_log_count, v_idproceso, 'debug');
        
        END WHILE
        ;
        
        --FT_COD_AGENTE_COMMISIONS
        --Se vuelve a regenerar la TBL_C_RECIBOS 
        --Se toma la TBL_C_RECIBOS como una combinación de la TBL_C_RECIBOS original y la TBL_RECIBOS_A_CALCULAR ya que no vamos a filtrar por extornos
        TBL_C_RECIBOS = SELECT TBL.*
        				FROM EXT.RECIBOS TBL
                        WHERE TBL.FILE_NAME = :i_file_name
                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
                        	AND TBL.ESTADO = :v_const_populate_status_ok
                        	AND TBL.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
                        	--AND LENGTH(TBL.CODIGO_UNICO_AGENTE) <= 10 --Condición para FT_COD_AGENTE_COMMISSIONS
                        	AND LENGTH(IFNULL(TBL.CODIGO_UNICO_AGENTE,'0')) <= 10 --Condición para FT_COD_AGENTE_COMMISSIONS
                        	--20251024 RMF: Añadimos condición para excluir los recibos tratados cuando el CODIGO_UNICO_AGENTE tiene longitud mayor de 10
                        	AND NOT EXISTS(SELECT 1 
                    					FROM :TBL_AGENTE_COD_UNICO_AG_1 REC
                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                    		   	)
                    		AND NOT EXISTS(SELECT 1
                    					FROM :TBL_AGENTE_COD_UNICO_AG_2 REC
                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                    		)
                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS actualizada: ' || v_num_rows || ' filas. Recibos cuyo CODIGO_UNICO_AGENTE es LENGTH <= 10', v_log_count, v_idproceso, 'debug');
        
        --Nos quedamos con los recibos cuya OFICINA_GESTORA es NOT NULL
        TBL_RECIBOS_OFI_GESTORA = SELECT TBL.*
    								FROM :TBL_C_RECIBOS TBL
    								WHERE TBL.OFICINA_GESTORA IS NOT NULL
        						;
        						
        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_OFI_GESTORA);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_OFI_GESTORA creada: ' || v_num_rows || ' filas. Filtra los recibos cuya OFICINA_GESTORA es NO nula', v_log_count, v_idproceso, 'debug');
		
		-----------------ALM 20250820: Creamos una tabla de DEBUG.
		--COMENTAR EN PRD
		SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_OFI_GESTORA_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_RECIBOS_OFI_GESTORA_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_RECIBOS_OFI_GESTORA_DEBUG AS (SELECT * FROM :TBL_RECIBOS_OFI_GESTORA);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_OFI_GESTORA_DEBUG' , v_log_count, v_idproceso, 'debug');
		------------------COMENTAR EN PRD	
        				
		--Nos quedamos con los recibos cuya OFICINA_GESTORA es NULL		
        TBL_RECIBOS_OFI_GESTORA_NULL = SELECT TBL.*
        								FROM :TBL_C_RECIBOS TBL
        								WHERE TBL.OFICINA_GESTORA IS NULL
        							;
        
        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_OFI_GESTORA_NULL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_OFI_GESTORA_NULL creada: ' || v_num_rows || ' filas. Filtra los recibos cuya OFICINA_GESTORA es nula', v_log_count, v_idproceso, 'debug');
        
        --Cruce con TBL_C_OFI de oficinas con es_PERMANENCIA_20
        TBL_C_OFICINA_GEST = SELECT GES.*
        						FROM :TBL_RECIBOS_OFI_GESTORA GES
        						INNER JOIN :TBL_C_OFIC OFI ON OFI.OFI_COBRADORA = LPAD(GES.OFICINA_GESTORA,4,'0')
        							AND GES.FECHA_COMPENSACION >= OFI.FECHA_DESDE
        							AND GES.FECHA_COMPENSACION < OFI.FECHA_HASTA
        					;
        					
        v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST creada: ' || v_num_rows || ' filas. Cruce con TBL_C_OFI de oficinas con es_PERMANENCIA_20 y FECHA_COMPENSACION dentro del rango de la OFICINA_GESTORA', v_log_count, v_idproceso, 'debug');
        
       /* -----------------ALM 20250820: Creamos una tabla de DEBUG.
		--COMENTAR EN PRD
		SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_OFICINA_GEST_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_C_OFICINA_GEST_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_C_OFICINA_GEST_DEBUG AS (SELECT * FROM :TBL_C_OFICINA_GEST);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_OFICINA_GEST_DEBUG' , v_log_count, v_idproceso, 'debug');
		------------------COMENTAR EN PRD
        */
        
        
        --Cruce de recibos de oficina gestora con es_PERMANENCIA_20 por CODIGO_OCASO = Codigo OFICINA_GESTORA || 999999
        --Si la oficina gestora es una agencia, ponemos como CODIGO_AGENTE_COMMISSIONS el codigo correspondiente de la gestora + 999999.
        TBL_C_AGENCIA_GEST = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_C_OFICINA_GEST GES
        						ON AGE.CODIGO_OCASO = LPAD(GES.OFICINA_GESTORA,4,'0') || '999999'
        						--ON AGE.CODIGO_OCASO = '000' || SUBSTR(GES.OFICINA_GESTORA,LENGTH(GES.OFICINA_GESTORA)-4) || '999999'
        					;
        					
        v_num_rows = RECORD_COUNT(:TBL_C_AGENCIA_GEST);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_AGENCIA_GEST creada: ' || v_num_rows || ' filas. Cruce de recibos de oficina gestora con es_PERMANENCIA_20 por CODIGO_OCASO = Codigo OFICINA_GESTORA || 999999', v_log_count, v_idproceso, 'debug');
        
        BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE3 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_GEST TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.RECIBOS x
	        --SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	         SET x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_UNICO
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_GEST TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE3 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE1 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_GEST TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_GEST TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE1 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		
		END;
														
		--Se crea una nueva tabla con los registros que no se han tratado de la tabla anterior. Esta tabla será la base para las dos próximas condiciones	
		TBL_C_OFICINA_GEST_NO = SELECT TBL.*
									FROM :TBL_RECIBOS_OFI_GESTORA TBL
									WHERE NOT EXISTS(SELECT 1 
													FROM :TBL_C_OFICINA_GEST GES
													WHERE GES.CODIGO_POLIZA = TBL.CODIGO_POLIZA
														AND GES.CODIGO_RECIBO = TBL.CODIGO_RECIBO
														AND GES.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
														AND GES.ESTADO_RECIBO = TBL.ESTADO_RECIBO
													)
									;
									
		v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO);
		
	/*	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO creada: ' || v_num_rows || ' filas. Recibos para los que NO es_PERMANENCIA_20 o FECHA_COMPENSACION no está dentro de rango de fechas por OFICINA_GESTORA', v_log_count, v_idproceso, 'debug');
		-----------------ALM 20250820: Creamos una tabla de DEBUG.
		--COMENTAR EN PRD
		SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_OFICINA_GEST_NO_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_C_OFICINA_GEST_NO_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_C_OFICINA_GEST_NO_DEBUG AS (SELECT * FROM :TBL_C_OFICINA_GEST_NO);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_OFICINA_GEST_NO_DEBUG' , v_log_count, v_idproceso, 'debug');
		------------------COMENTAR EN PRD*/
		
		
		--TGV 20260127 PONEMOS UN TRIM ANTES DE HACER LA CONVERSION 
		--Nos quedamos con aquellos casos en los que CODIGO_UNICO_AGENTE = 0 e INSPECTOR = 0
		TBL_C_OFICINA_GEST_NO_1 = SELECT TBL.*
									FROM :TBL_C_OFICINA_GEST_NO TBL
									--WHERE TO_NUMBER('000000' || SUBSTR(IFNULL(TBL.CODIGO_UNICO_AGENTE,'0'),LENGTH(TBL.CODIGO_UNICO_AGENTE) - 6)) = 0
										--AND TO_NUMBER('000000' || SUBSTR(IFNULL(TBL.INSPECTOR,'0'),LENGTH(TBL.INSPECTOR) - 6)) = 0
									WHERE TO_NUMBER('000000' || RIGHT(IFNULL(TRIM(TBL.CODIGO_UNICO_AGENTE),'0'),6)) = 0
										AND TO_NUMBER('000000' || RIGHT(IFNULL(TRIM(TBL.INSPECTOR),'0'),6)) = 0
									;
									
		v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO_1);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO_1 creada: ' || v_num_rows || ' filas. Recibos para los que NO es_PERMANENCIA_20 o FECHA_COMPENSACION no está dentro de rango de fechas por OFICINA_GESTORA y CODIGO_UNICO_AGENTE = 0 e INSPECTOR = 0', v_log_count, v_idproceso, 'debug');
		
		--Se cruza con la tabla de es_PERMANENCIA_20 por OFICINA_COBRADORA y FECHA_COMPENSACION en rango de fechas
		TBL_C_OFICINA_GEST_NO_2 = SELECT GES.*
									FROM :TBL_C_OFICINA_GEST_NO_1 GES
									INNER JOIN :TBL_C_OFIC OFI ON OFI.OFI_COBRADORA = LPAD(GES.OFICINA_COBRADORA,4,'0')
	        							AND GES.FECHA_COMPENSACION >= OFI.FECHA_DESDE
	        							AND GES.FECHA_COMPENSACION < OFI.FECHA_HASTA
        							;
									
		v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO_2);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO_2 creada: ' || v_num_rows || ' filas. Cruce con TBL_C_OFI de oficinas con es_PERMANENCIA_20 y FECHA_COMPENSACION dentro del rango de la OFICINA_COBRADORA', v_log_count, v_idproceso, 'debug');
		
		--Cruce con TBL_GEN_CODIGOS_AGENTE por CODIGO_OCASO = OFICINA_COBRADORA
		TBL_C_AGENCIA_COB = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_C_OFICINA_GEST_NO_2 GES
        						--ON AGE.CODIGO_OCASO = '000' || SUBSTR(GES.OFICINA_COBRADORA,LENGTH(GES.OFICINA_COBRADORA)-4) || '999999'
        						  ON AGE.CODIGO_OCASO = LPAD(GES.OFICINA_COBRADORA,4,'0') || '999999'
        					;
        					
        v_num_rows = RECORD_COUNT(:TBL_C_AGENCIA_COB);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_AGENCIA_COB creada: ' || v_num_rows || ' filas. Cruce con TBL_GEN_CODIGOS_AGENTE por CODIGO_OCASO = OFICINA_COBRADORA', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE4 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_COB TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			UPDATE EXT.RECIBOS x
	        --SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        SET x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_UNICO
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_COB TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE4 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE2 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_COB TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_COB TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE2 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		
		END;
		
        TBL_C_OFICINA_GEST_NO_1_NO = SELECT TBL.*
        								FROM :TBL_C_OFICINA_GEST_NO_1 TBL
        								WHERE NOT EXISTS(SELECT 1
        												FROM :TBL_C_OFICINA_GEST_NO_2 GES
        												WHERE TBL.CODIGO_POLIZA = GES.CODIGO_POLIZA
        													AND TBL.CODIGO_RECIBO = GES.CODIGO_RECIBO
        													AND TBL.CODIGO_SUPLEMENTO = GES.CODIGO_SUPLEMENTO
        													AND TBL.ESTADO_RECIBO = GES.ESTADO_RECIBO
        												)
        								;
        
        v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO_1_NO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO_1_NO creada: ' || v_num_rows || ' filas. Cruce de oficinas que no cruzan por OFICINA_GESTORA ni OFICINA_COBRADORA para es_PERMENANCIA_20', v_log_count, v_idproceso, 'debug');
		
		
		TBL_C_OFICINA_GEST_NO_1_NO_1 = SELECT TBL.*
										FROM :TBL_C_OFICINA_GEST_NO_1_NO TBL
										--WHERE '000000' || SUBSTR(IFNULL(TBL.CODIGO_AGENTE_ORIGINAL,'0'),LENGTH(TBL.CODIGO_AGENTE_ORIGINAL) - 6) <> '000000'
										WHERE TO_NUMBER('000000' || RIGHT(IFNULL(TBL.CODIGO_AGENTE_ORIGINAL,'0'),6)) <> 0
										;
		
		v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO_1_NO_1);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO_1_NO_1 creada: ' || v_num_rows || ' filas. Cruce de oficinas que no cruzan por OFICINA_GESTORA ni OFICINA_COBRADORA para es_PERMENANCIA_20 y el CODIGO_AGENTE_ORIGINAL es <> 0', v_log_count, v_idproceso, 'debug');
										
		TBL_C_AGENCIA_AGE_ORIGINAL = SELECT GES.* 
	        						, AGE.CODIGO_UNICO
	        						, AGE.IMP_COMISION_CARTERA
	        						, AGE.PORC_COMISION_CARTERA
	        						, AGE.FECHA_FIN_COMISION_CARTERA
	        						, ROW_NUMBER() OVER (
			        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
			        					ORDER BY
			        						AGE.EFFECTIVEENDDATE DESC
			        						, CASE WHEN GES.CODIGO_AGENTE_ORIGINAL = AGE.CODIGO_OCASO 
			        							THEN 1 
			        							ELSE 2 
			        						END ASC
		        					) AS ROW_NUM_POL
		        					, ROW_NUMBER() OVER (
		        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
		        						ORDER BY
			        						AGE.EFFECTIVEENDDATE DESC
			        						, CASE WHEN GES.CODIGO_AGENTE_ORIGINAL = AGE.CODIGO_OCASO 
			        							THEN 1 
			        							ELSE 2 
			        						END ASC
		        					) AS ROW_NUM_REC
		        					--Se añade esta subconsulta para comprobar que la position está de alta en la fecha de compensación del recibo
		        					, (SELECT COUNT(*) 
		        						FROM :TBL_GEN_CODIGOS_AGENTE X 
		        						WHERE X.CODIGO_UNICO = AGE.CODIGO_UNICO
		        							AND X.EFFECTIVESTARTDATE <= LAST_DAY(GES.FECHA_COMPENSACION) 
	                    					AND X.EFFECTIVEENDDATE > LAST_DAY(GES.FECHA_COMPENSACION)
		        					) AS EXISTE_POSNAME
	        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
	        					RIGHT JOIN :TBL_C_OFICINA_GEST_NO_1_NO_1 GES
	        						ON AGE.CODIGO_OCASO = GES.CODIGO_AGENTE_ORIGINAL
	        					;
	        					
	    v_num_rows = RECORD_COUNT(:TBL_C_AGENCIA_AGE_ORIGINAL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_AGENCIA_AGE_ORIGINAL creada: ' || v_num_rows || ' filas. Cruce con TBL_GEN_CODIGOS_AGENTE por CODIGO_OCASO = CODIGO_AGENTE_ORIGINAL', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE5 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_AGE_ORIGINAL TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
	        					
		    UPDATE EXT.RECIBOS x
	        --SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        SET x.CODIGO_AGENTE_COMMISSIONS = CASE WHEN TBL.EXISTE_POSNAME > 0 THEN TBL.CODIGO_UNICO ELSE :v_const_no_encontrado END
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_AGE_ORIGINAL TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE5 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE3 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_AGE_ORIGINAL TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_AGE_ORIGINAL TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE3 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
															
		END;
															
		TBL_C_OFICINA_GEST_NO_1_NO_1_NO = SELECT GES.*
											FROM :TBL_C_OFICINA_GEST_NO_1 GES
											WHERE NOT EXISTS(SELECT 1
															FROM :TBL_C_OFICINA_GEST_NO_1_NO_1 TBL
															WHERE TBL.CODIGO_POLIZA = GES.CODIGO_POLIZA
																AND TBL.CODIGO_RECIBO = GES.CODIGO_RECIBO
																AND TBL.CODIGO_SUPLEMENTO = GES.CODIGO_SUPLEMENTO
																AND TBL.ESTADO_RECIBO = GES.ESTADO_RECIBO
															)
												AND NOT EXISTS(SELECT 1
															FROM :TBL_C_OFICINA_GEST_NO_2 TBL
        													WHERE TBL.CODIGO_POLIZA = GES.CODIGO_POLIZA
        														AND TBL.CODIGO_RECIBO = GES.CODIGO_RECIBO
        														AND TBL.CODIGO_SUPLEMENTO = GES.CODIGO_SUPLEMENTO
        														AND TBL.ESTADO_RECIBO = GES.ESTADO_RECIBO
												)
											;
											
		v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO_1_NO_1_NO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO_1_NO_1_NO creada: ' || v_num_rows || ' filas. No cumple ninguna de las condiciones anteriores', v_log_count, v_idproceso, 'debug');
		
		TBL_C_AGENCIA_AGE_0 = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_C_OFICINA_GEST_NO_1_NO_1_NO GES
        						  ON AGE.CODIGO_OCASO = LPAD(GES.OFICINA_GESTORA,4,'0') || '009999'
        						--ON AGE.CODIGO_OCASO = '000' || SUBSTR(GES.OFICINA_GESTORA,LENGTH(GES.OFICINA_GESTORA)-4) || '009999'
        					;
		
		v_num_rows = RECORD_COUNT(:TBL_C_AGENCIA_AGE_0);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_AGENCIA_AGE_0 creada: ' || v_num_rows || ' filas. Cruce con TBL_GEN_CODIGOS_AGENTE por OFICINA_GESTORA', v_log_count, v_idproceso, 'debug');
        
        ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
	    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_AGENCIA_AGE_0_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_C_AGENCIA_AGE_0_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_C_AGENCIA_AGE_0_DEBUG AS (SELECT * FROM :TBL_C_AGENCIA_AGE_0);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_AGENCIA_AGE_0_DEBUG' , v_log_count, v_idproceso, 'debug');
------------------------------
        
        BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE6 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_AGE_0 TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.RECIBOS x
	        SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        --SET x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_UNICO
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_AGENCIA_AGE_0 TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE6 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
        
        END;
        
        BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE4 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_AGE_0 TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	--, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_AGENTE_COMMISSIONS,:v_const_no_encontrado)
	        	, x.AGENTE_CARTERA = TBL.CODIGO_UNICO
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_AGENCIA_AGE_0 TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE4 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
															
		TBL_C_OFICINA_GEST_NO_ELSE = SELECT TBL.*	
										FROM :TBL_C_OFICINA_GEST_NO TBL
										WHERE NOT EXISTS(SELECT 1
														FROM :TBL_C_OFICINA_GEST_NO_1 GES
														WHERE GES.CODIGO_POLIZA = TBL.CODIGO_POLIZA
															AND GES.CODIGO_RECIBO = TBL.CODIGO_RECIBO
															AND GES.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
															AND GES.ESTADO_RECIBO = TBL.ESTADO_RECIBO
														)
										;
										
		v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO_ELSE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO_ELSE creada: ' || v_num_rows || ' filas. Recibos para los que NO es_PERMANENCIA_20 o FECHA_COMPENSACION no está dentro de rango de fechas por OFICINA_GESTORA y CODIGO_UNICO_AGENTE <> 0 e INSPECTOR <> 0', v_log_count, v_idproceso, 'debug');
		
		TBL_C_CURSOR_AGENTE = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
	        					--Se añade esta subconsulta para comprobar que la position está de alta en la fecha de compensación del recibo
	        					, (SELECT COUNT(*) 
	        						FROM :TBL_GEN_CODIGOS_AGENTE X 
	        						WHERE X.CODIGO_UNICO = AGE.CODIGO_UNICO
	        							AND X.EFFECTIVESTARTDATE <= LAST_DAY(GES.FECHA_COMPENSACION) 
                    					AND X.EFFECTIVEENDDATE > LAST_DAY(GES.FECHA_COMPENSACION)
	        					) AS EXISTE_POSNAME
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_C_OFICINA_GEST_NO_ELSE GES
        						ON AGE.CODIGO_OCASO = GES.CODIGO_UNICO_AGENTE
        						--AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(GES.FECHA_COMPENSACION) 
                    			--AND AGE.EFFECTIVEENDDATE > LAST_DAY(GES.FECHA_COMPENSACION)
        					;
		
		v_num_rows = RECORD_COUNT(:TBL_C_CURSOR_AGENTE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_CURSOR_AGENTE creada: ' || v_num_rows || ' filas. Cruce TBL_C_OFICINA_GEST_NO_ELSE con TBL_GEN_CODIGOS_AGENTE por CODIGO_OCASO = CODIGO_UNICO_AGENTE', v_log_count, v_idproceso, 'debug');
		
		-------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_CURSOR_AGENTE_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_C_CURSOR_AGENTE_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_C_CURSOR_AGENTE_DEBUG AS (SELECT * FROM :TBL_C_CURSOR_AGENTE);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_CURSOR_AGENTE' , v_log_count, v_idproceso, 'debug');
    ------------------------------
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE7 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_CURSOR_AGENTE TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			UPDATE EXT.RECIBOS x
	        --SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        SET x.CODIGO_AGENTE_COMMISSIONS = CASE WHEN TBL.EXISTE_POSNAME > 0 THEN TBL.CODIGO_UNICO ELSE :v_const_no_encontrado END
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_CURSOR_AGENTE TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE7 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		
		END;
        
        BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE5 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_CURSOR_AGENTE TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = CASE WHEN TBL.EXISTE_POSNAME > 0 THEN TBL.CODIGO_UNICO ELSE :v_const_no_encontrado END
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_CURSOR_AGENTE TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE5 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		--regeneramos la tabla para el tratamiento del tbl_c_cursor_inspector y que coja los datos actualizados de tbl_cursor_agente
		TBL_C_OFICINA_GEST_NO_ELSE = SELECT TBL.*	
									FROM EXT.RECIBOS TBL
									WHERE EXISTS(SELECT 1
													FROM :TBL_C_CURSOR_AGENTE GES
													WHERE GES.CODIGO_POLIZA = TBL.CODIGO_POLIZA
														AND GES.CODIGO_RECIBO = TBL.CODIGO_RECIBO
														AND GES.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
														AND GES.ESTADO_RECIBO = TBL.ESTADO_RECIBO
													)
										AND TBL.FILE_NAME = i_file_name
										AND (TBL.CODIGO_AGENTE_COMMISSIONS IS NULL OR TBL.CODIGO_AGENTE_COMMISSIONS = :v_const_no_encontrado)
										AND TBL.ESTADO = v_const_populate_status_ok	
									;
										
		v_num_rows = RECORD_COUNT(:TBL_C_OFICINA_GEST_NO_ELSE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFICINA_GEST_NO_ELSE actualizada: ' || v_num_rows || ' filas. Recibos para los que NO es_PERMANENCIA_20 o FECHA_COMPENSACION no está dentro de rango de fechas por OFICINA_GESTORA y CODIGO_UNICO_AGENTE <> 0 e INSPECTOR <> 0', v_log_count, v_idproceso, 'debug');
		
		
		
        
        TBL_C_CURSOR_INSPECTOR = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_C_OFICINA_GEST_NO_ELSE GES
        						ON AGE.CODIGO_OCASO = GES.INSPECTOR
        						AND (GES.CODIGO_AGENTE_COMMISSIONS = :v_const_no_encontrado OR GES.CODIGO_AGENTE_COMMISSIONS IS NULL)
        					
        					;
		
		v_num_rows = RECORD_COUNT(:TBL_C_CURSOR_INSPECTOR);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_CURSOR_INSPECTOR creada: ' || v_num_rows || ' filas. Cruce TBL_C_OFICINA_GEST_NO_ELSE con TBL_GEN_CODIGOS_AGENTE por CODIGO_OCASO = INSPECTOR y CODIGO_AGENTE_COMMISSIONS = NO_ENCONTRADO', v_log_count, v_idproceso, 'debug');
		
		-------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_CURSOR_INSPECTOR_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_C_CURSOR_INSPECTOR_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_C_CURSOR_INSPECTOR_DEBUG AS (SELECT * FROM :TBL_C_CURSOR_INSPECTOR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_CURSOR_INSPECTOR_DEBUG' , v_log_count, v_idproceso, 'debug');
    ------------------------------
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE8 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_CURSOR_INSPECTOR TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			UPDATE EXT.RECIBOS x
	        	SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        --SET x.CODIGO_AGENTE_COMMISSIONS = TBL.CODIGO_UNICO
	        	 ,x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_CURSOR_INSPECTOR TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE8 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE6 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_CURSOR_INSPECTOR TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_CURSOR_INSPECTOR TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = v_const_recibos_especificos_10
	        ;
        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE6 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
															
		--Comenzamos a tratar aquellos registros con oficina gestora nula (línea 3281 de SQL_0002_INYC_LP_PK_CALC_FUNC_GENERICAS.sql)
		
        TBL_C_CURSOR_AGENTE = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
	        					--Se añade esta subconsulta para comprobar que la position está de alta en la fecha de compensación del recibo
	        					, (SELECT COUNT(*) 
	        						FROM :TBL_GEN_CODIGOS_AGENTE X 
	        						WHERE X.CODIGO_UNICO = AGE.CODIGO_UNICO
	        							AND X.EFFECTIVESTARTDATE <= LAST_DAY(GES.FECHA_COMPENSACION) 
                    					AND X.EFFECTIVEENDDATE > LAST_DAY(GES.FECHA_COMPENSACION)
	        					) AS EXISTE_POSNAME
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_RECIBOS_OFI_GESTORA_NULL GES
        						ON AGE.CODIGO_OCASO = GES.CODIGO_UNICO_AGENTE
        					;
		
		v_num_rows = RECORD_COUNT(:TBL_C_CURSOR_AGENTE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_CURSOR_AGENTE creada: ' || v_num_rows || ' filas. Cruce TBL_RECIBOS_OFI_GESTORA_NULL con TBL_GEN_CODIGOS_AGENTE por CODIGO_OCASO = CODIGO_UNICO_AGENTE para OFICINA_GESTORA nula', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE9 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_CURSOR_AGENTE TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;

		
			UPDATE EXT.RECIBOS x
	        SET x.CODIGO_AGENTE_COMMISSIONS = CASE WHEN TBL.EXISTE_POSNAME > 0 THEN TBL.CODIGO_UNICO ELSE :v_const_no_encontrado END
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_CURSOR_AGENTE TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE9 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		
		END;
        
        BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE7 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_CURSOR_AGENTE TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
				
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_CURSOR_AGENTE TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE7 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		
		END;						
		
		--regeneramos la tabla para el tratamiento del tbl_c_cursor_inspector y que coja los datos actualizados de tbl_cursor_agente
		TBL_RECIBOS_OFI_GESTORA_NULL = SELECT TBL.*	
									FROM EXT.RECIBOS TBL
									WHERE EXISTS(SELECT 1
													FROM :TBL_C_CURSOR_AGENTE GES
													WHERE GES.CODIGO_POLIZA = TBL.CODIGO_POLIZA
														AND GES.CODIGO_RECIBO = TBL.CODIGO_RECIBO
														AND GES.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
														AND GES.ESTADO_RECIBO = TBL.ESTADO_RECIBO
													)
										AND TBL.FILE_NAME = i_file_name
										AND (TBL.CODIGO_AGENTE_COMMISSIONS IS NULL OR TBL.CODIGO_AGENTE_COMMISSIONS = :v_const_no_encontrado)
										AND TBL.ESTADO = v_const_populate_status_ok	
									;
										
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_OFI_GESTORA_NULL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_OFI_GESTORA_NULL actualizada: ' || v_num_rows || ' filas. Recibos para los que NO es_PERMANENCIA_20 o FECHA_COMPENSACION no está dentro de rango de fechas por OFICINA_GESTORA y CODIGO_UNICO_AGENTE <> 0 e INSPECTOR <> 0', v_log_count, v_idproceso, 'debug');
		
		
		
		TBL_C_CURSOR_INSPECTOR = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_UNICO_AGENTE = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_RECIBOS_OFI_GESTORA_NULL GES
        						ON AGE.CODIGO_OCASO = GES.INSPECTOR
        						AND GES.CODIGO_AGENTE_COMMISSIONS = :v_const_no_encontrado
        					;
		
		v_num_rows = RECORD_COUNT(:TBL_C_CURSOR_INSPECTOR);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_CURSOR_INSPECTOR actualizada: ' || v_num_rows || ' filas. Cruce TBL_RECIBOS_OFI_GESTORA_NULL con TBL_GEN_CODIGOS_AGENTE para OFICINA_GESTORA es nula por CODIGO_OCASO = INSPECTOR y CODIGO_AGENTE_COMMISSIONS = NO_ENCONTRADO', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE10 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_CURSOR_INSPECTOR TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			UPDATE EXT.RECIBOS x
	        SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_CURSOR_INSPECTOR TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE10 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		
		END;
        
        BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE8 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_CURSOR_INSPECTOR TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_CURSOR_INSPECTOR TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE8 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		--regeneramos la tabla para el tratamiento del tbl_c_cursor_solnet y que coja los datos actualizados de tbl_cursor_inspector
		TBL_RECIBOS_OFI_GESTORA_NULL = SELECT TBL.*	
									FROM EXT.RECIBOS TBL
									WHERE EXISTS(SELECT 1
													FROM :TBL_C_CURSOR_INSPECTOR GES
													WHERE GES.CODIGO_POLIZA = TBL.CODIGO_POLIZA
														AND GES.CODIGO_RECIBO = TBL.CODIGO_RECIBO
														AND GES.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
														AND GES.ESTADO_RECIBO = TBL.ESTADO_RECIBO
													)
										AND TBL.FILE_NAME = i_file_name
										AND (TBL.CODIGO_AGENTE_COMMISSIONS IS NULL OR TBL.CODIGO_AGENTE_COMMISSIONS = :v_const_no_encontrado)
										AND TBL.ESTADO = v_const_populate_status_ok	
									;
										
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_OFI_GESTORA_NULL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_OFI_GESTORA_NULL actualizada: ' || v_num_rows || ' filas. Actualización para TBL_C_CURSOR_SOLNET', v_log_count, v_idproceso, 'debug');
													
		TBL_C_CURSOR_SOLNET = SELECT GES.* 
        						, AGE.CODIGO_UNICO
        						, AGE.IMP_COMISION_CARTERA
        						, AGE.PORC_COMISION_CARTERA
        						, AGE.FECHA_FIN_COMISION_CARTERA
        						, ROW_NUMBER() OVER (
		        					PARTITION BY CODIGO_POLIZA, AGE.CODIGO_OCASO
		        					ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_AGENTE_ORIGINAL = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_POL
	        					, ROW_NUMBER() OVER (
	        						PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA
	        						ORDER BY
		        						AGE.EFFECTIVEENDDATE DESC
		        						, CASE WHEN GES.CODIGO_AGENTE_ORIGINAL = AGE.CODIGO_OCASO 
		        							THEN 1 
		        							ELSE 2 
		        						END ASC
	        					) AS ROW_NUM_REC
        					FROM :TBL_GEN_CODIGOS_AGENTE AGE
        					RIGHT JOIN :TBL_RECIBOS_OFI_GESTORA_NULL GES
        						ON AGE.CODIGO_OCASO = GES.CODIGO_AGENTE_ORIGINAL
        						AND GES.CODIGO_AGENTE_COMMISSIONS = :v_const_no_encontrado
        					;
		
		v_num_rows = RECORD_COUNT(:TBL_C_CURSOR_SOLNET);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_CURSOR_SOLNET actualizada: ' || v_num_rows || ' filas. Cruce TBL_RECIBOS_OFI_GESTORA_NULL con TBL_GEN_CODIGOS_AGENTE por CODIGO_OCASO = CODIGO_AGENTE_ORIGINAL y CODIGO_AGENTE_COMMISSIONS = NO_ENCONTRADO', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE11 en RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.RECIBOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.RECIBOS x, :TBL_C_CURSOR_SOLNET TBL
			        WHERE 1 = 1
			        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			        	AND TBL.ROW_NUM_REC = 1
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			UPDATE EXT.RECIBOS x
	        SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.RECIBOS x, :TBL_C_CURSOR_SOLNET TBL
	        WHERE 1 = 1
	        	AND x.IDENTIFICADOR = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        	AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	        	AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        	AND TBL.ROW_NUM_REC = 1
	        ;
	        
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE11 CODIGO_AGENTE_COMMISSIONS en RECIBOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
		
		END;
        
        BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE9 en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.POLIZAS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.POLIZAS x, :TBL_C_CURSOR_SOLNET TBL
			        WHERE 1 = 1
			        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
			        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			        	AND TBL.ROW_NUM_POL = 1
			        	AND TBL.PERMANENCIA = :v_const_recibos_especificos_10
			        ;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.IMP_COMISION_CARTERA = TBL.IMP_COMISION_CARTERA
	        	, x.AGENTE_CARTERA = IFNULL(TBL.CODIGO_UNICO,:v_const_no_encontrado)
	        	, x.PORC_COMISION_CARTERA = TBL.PORC_COMISION_CARTERA
	        	, x.FECHA_FIN_COMISION_CARTERA = TBL.FECHA_FIN_COMISION_CARTERA
	        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        FROM EXT.POLIZAS x, :TBL_C_CURSOR_SOLNET TBL
	        WHERE 1 = 1
	        	AND x.ID_RECIBO = TBL.IDENTIFICADOR
	        	AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        	AND TBL.ROW_NUM_POL = 1
	        	AND TBL.PERMANENCIA = v_const_recibos_especificos_10
	        ;
	        						
	        v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE9 en IMP_COMISION_CARTERA/PORC_COMISION_CARTERA/FECHA_FIN_COMISION_CARTERA en POLIZAS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		--FT_COD_AGENTE_COMMISIONS/FT_COMPROBAR_MANAGER_COLABORADOR
        --Llamada recursiva para encontrar el manager y asignarle a él la transaccion en el futuro
        --Bucle loop que se quede solo con los códigos cuyo tipo agente principal es 15 y vaya actualizando en EXT.RECIBOS a cada vuelta
        --Recargamos la tabla temporal de RECIBOS
        
        TBL_C_RECIBOS = SELECT TBL.*
        				FROM EXT.RECIBOS TBL
                        WHERE TBL.FILE_NAME = :i_file_name
                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
                        	AND TBL.ESTADO = :v_const_populate_status_ok
                        	AND TBL.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
                        	--AND LENGTH(TBL.CODIGO_UNICO_AGENTE) <= 10 --Condición para FT_COD_AGENTE_COMMISIONS
                        	AND LENGTH(IFNULL(TBL.CODIGO_UNICO_AGENTE,'0')) <= 10 --Condición para FT_COD_AGENTE_COMMISIONS
                        	--20251024 RMF: Añadimos condición para excluir los recibos tratados cuando el CODIGO_UNICO_AGENTE tiene longitud mayor de 10
                        	AND NOT EXISTS(SELECT 1 
                    					FROM :TBL_AGENTE_COD_UNICO_AG_1 REC
                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                    		   	)
                    		AND NOT EXISTS(SELECT 1
                    					FROM :TBL_AGENTE_COD_UNICO_AG_2 REC
                    					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                    		)
                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS actualizada: ' || v_num_rows || ' filas. Se recarga TBL_C_RECIBOS con la información actualizada de EXT.RECIBOS', v_log_count, v_idproceso, 'debug');
        
        --Para cada CODIGO_AGENTE_COMMISSIONS nos quedamos con su máximo TIPO_AGENTE_PRIN
        TBL_MAX_AGE_TIPO_PRIN = SELECT TBL.CODIGO_AGENTE_COMMISSIONS AS CODIGO_UNICO
        							, MAX(AGE.TIPO_AGENTE_PRIN) AS TIPO_AGENTE_PRIN
        						FROM :TBL_C_RECIBOS TBL
        						LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE
        							ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
        								AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
        								AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
        						GROUP BY TBL.CODIGO_AGENTE_COMMISSIONS
        						;
        						
        v_num_rows = RECORD_COUNT(:TBL_MAX_AGE_TIPO_PRIN);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_MAX_AGE_TIPO_PRIN creada: ' || v_num_rows || ' filas. Para cada CODIGO_AGENTE_COMMISSIONS nos quedamos con su máximo TIPO_AGENTE_PRIN', v_log_count, v_idproceso, 'debug');
        
        	-------------------------------TABLA DEBUG PENDIENTE BORRAR
	    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_MAX_AGE_TIPO_PRIN_DEBUG';
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_MAX_AGE_TIPO_PRIN_DEBUG;
		END IF;
		CREATE TABLE EXT.TBL_MAX_AGE_TIPO_PRIN_DEBUG AS (SELECT * FROM :TBL_MAX_AGE_TIPO_PRIN);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MAX_AGE_TIPO_PRIN_DEBUG' , v_log_count, v_idproceso, 'debug');
	    ------------------------------
        
        --Nos quedamos solo con aquellos cuyo TIPO_AGENTE_PRIN = 15
        TBL_C_RECIBOS_AGE_15 = SELECT TBL.*
        						FROM :TBL_C_RECIBOS TBL
        						WHERE EXISTS (SELECT 1 
        										FROM :TBL_MAX_AGE_TIPO_PRIN AGE
        										WHERE AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
        											AND AGE.TIPO_AGENTE_PRIN = 15
        									)
        						;
        						
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15 creada: ' || v_num_rows || ' filas. Nos quedamos solo con aquellos recibos cuyo TIPO_AGENTE_PRIN = 15', v_log_count, v_idproceso, 'debug');
		
		-------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_RECIBOS_AGE_15_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_C_RECIBOS_AGE_15_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_C_RECIBOS_AGE_15_DEBUG AS (SELECT * FROM :TBL_C_RECIBOS_AGE_15);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_RECIBOS_AGE_15_DEBUG' , v_log_count, v_idproceso, 'debug');
    ------------------------------
		
        
        WHILE NOT(IS_EMPTY(:TBL_C_RECIBOS_AGE_15)) DO
        	
        	v_count_bucle := v_count_bucle + 1;
        	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio del bucle mientras haya registros con TIPO_AGENTE_PRIN = 15. Vuelta ' || :v_count_bucle, v_log_count, v_idproceso, 'debug');
        	--Se separa en dos partes, una para PERMANENCIA 16 y otra para el resto. El manager de PERMANENCIA 16 se busca por FECHA_COMPENSACION, el resto por FECHA_EMISION_REC
        	--Registros con PERMANENCIA = 16
        	TBL_C_RECIBOS_AGE_15_PERM_16 = SELECT TBL.*
        									FROM :TBL_C_RECIBOS_AGE_15 TBL
        									WHERE TBL.PERMANENCIA = :v_const_recibos_especificos_16
        									;
        	
        	v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_16);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_16 creada: ' || v_num_rows || ' filas. Registros con PERMANENCIA = 16', v_log_count, v_idproceso, 'debug');
        	
        	--Registros con PERMANENCIA <> 16
        	TBL_C_RECIBOS_AGE_15_PERM_NO_16 = SELECT TBL.*
	        									FROM :TBL_C_RECIBOS_AGE_15 TBL
	        									WHERE TBL.PERMANENCIA <> :v_const_recibos_especificos_16
	        								;
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_NO_16);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_NO_16 creada: ' || v_num_rows || ' filas. Registros con PERMANENCIA <> 16', v_log_count, v_idproceso, 'debug');
	        
	        --Se cruzan los registros de PERMANENCIA = 16 con TBL_GEN_CODIGOS_AGENTE (por CODIGO_UNICO = CODIGO_AGENTE_COMMISSIONS y FECHA_COMPENSACION) y se añade ROW_NUM particionado por TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        TBL_C_RECIBOS_AGE_15_PERM_16_RN = SELECT TBL.*
	        										, AGE.MANAGERSEQ
	        										, ROW_NUMBER() OVER (
	        											PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        											ORDER BY AGE.EFFECTIVEENDDATE DESC
	        										) AS ROW_NUM
	        								FROM :TBL_C_RECIBOS_AGE_15_PERM_16 TBL
	        								LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
	        									AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
	        									AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
	        							;
	        
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_16_RN);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_16_RN creada: ' || v_num_rows || ' filas. Se cruzan los registros de PERMANENCIA = 16 con TBL_GEN_CODIGOS_AGENTE (por CODIGO_UNICO = CODIGO_AGENTE_COMMISSIONS y FECHA_COMPENSACION) y se añade ROW_NUM particionado por TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS', v_log_count, v_idproceso, 'debug');
	        							
	        TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN = SELECT TBL.*
	        										, AGE.MANAGERSEQ
	        										, ROW_NUMBER() OVER (
	        											PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        											ORDER BY AGE.EFFECTIVEENDDATE DESC
	        										) AS ROW_NUM
		        								FROM :TBL_C_RECIBOS_AGE_15_PERM_NO_16 TBL
		        								LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
		        									AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_EMISION_REC)
		        									AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_EMISION_REC)
	        							;
	        
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN creada: ' || v_num_rows || ' filas. Se cruzan los registros de PERMANENCIA <> 16 con TBL_GEN_CODIGOS_AGENTE (por CODIGO_UNICO = CODIGO_AGENTE_COMMISSIONS y FECHA_EMISION_REC) y se añade ROW_NUM particionado por TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS', v_log_count, v_idproceso, 'debug');
	        
	        --COMENTAR EN PRD
			SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN_DEBUG';
			
			IF v_existe_tabla > 0 THEN
				DROP TABLE EXT.TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN_DEBUG;
			END IF;
			
			CREATE TABLE EXT.TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN_DEBUG AS (SELECT * FROM :TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN);
		    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN_DEBUG: ' , v_log_count, v_idproceso, 'debug');
			--COMENTAR EN PRD
	        
	        --Unimos ambas tablas porque se van a tratar igual
	        TBL_RECIBOS_AGE_15_A_TRATAR = SELECT * FROM :TBL_C_RECIBOS_AGE_15_PERM_16_RN
	        						UNION ALL SELECT * FROM :TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_AGE_15_A_TRATAR);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_AGE_15_A_TRATAR creada: ' || v_num_rows || ' filas. UNION ALL de tablas TBL_C_RECIBOS_AGE_15_PERM_16_RN y TBL_C_RECIBOS_AGE_15_PERM_NO_16_RN', v_log_count, v_idproceso, 'debug');
	        
	        --COMENTAR EN PRD
			SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_AGE_15_A_TRATAR_DEBUG';
			
			IF v_existe_tabla > 0 THEN
				DROP TABLE EXT.TBL_RECIBOS_AGE_15_A_TRATAR_DEBUG;
			END IF;
			
			CREATE TABLE EXT.TBL_RECIBOS_AGE_15_A_TRATAR_DEBUG AS (SELECT * FROM :TBL_RECIBOS_AGE_15_A_TRATAR);
		    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_AGE_15_A_TRATAR_DEBUG: ' , v_log_count, v_idproceso, 'debug');
			--COMENTAR EN PRD
	        
	        --Se añade RULEELEMENTOWNERSEQ y NAME de la position del MANAGER indicado en la TBL_RECIBOS_AGE_15_A_TRATAR para cada recibo	
	        TBL_RECIBOS_A_TRATAR = SELECT TBL.*
	        						, POS.RULEELEMENTOWNERSEQ AS EXISTE_MANAGER
	        						, POS.NAME AS MANAGER_NAME
	        						FROM :TBL_RECIBOS_AGE_15_A_TRATAR TBL
	        						LEFT JOIN TCMP.CS_POSITION POS ON TBL.MANAGERSEQ = POS.RULEELEMENTOWNERSEQ
	        							AND POS.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
	        							AND POS.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
	        							AND POS.REMOVEDATE = v_eot
	        							AND POS.TENANTID = v_idtenant
	        							AND POS.TITLESEQ <> 5629499534213290 --No se tienen en cuenta las que tienen TTL SIN PLAN
	        						WHERE TBL.ROW_NUM = 1
	        						;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR creada: ' || v_num_rows || ' filas. Se añade RULEELEMENTOWNERSEQ y NAME de la position del MANAGER indicado en la TBL_RECIBOS_AGE_15_A_TRATAR para cada recibo', v_log_count, v_idproceso, 'debug');
	        
	        --Recibos para los que se ha encontrado el manager
	        TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER = SELECT TBL.*
	        										FROM :TBL_RECIBOS_A_TRATAR TBL
	        										WHERE EXISTE_MANAGER IS NOT NULL
	        									;
	        									
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER creada: ' || v_num_rows || ' filas. Recibos para los que se ha encontrado el manager', v_log_count, v_idproceso, 'debug');
	        										
	        TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER = SELECT TBL.*
	        											FROM :TBL_RECIBOS_A_TRATAR TBL
	        											WHERE EXISTE_MANAGER IS NULL
	        										;
	        
	        v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER creada: ' || v_num_rows || ' filas. Recibos para los que no se ha encontrado el manager', v_log_count, v_idproceso, 'debug');
	        
	        BEGIN
				DECLARE EXIT HANDLER FOR SQLEXCEPTION
					BEGIN
						
						ROLLBACK;
						
						CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE1 en RECIBOS para TIPO_PRINCIPAL 15 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
											
						UPDATE EXT.RECIBOS x
						SET x.ESTADO = :v_const_calculo_status_error
							, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER TBL
				    	WHERE 1 = 1
				    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				    	;
				    	
				    	COMMIT;
				    	
				    	RESIGNAL;
				    	
				    END;
						
		        --Se hace un update de RECIBOS para aquellos que existe el manager
		        UPDATE EXT.RECIBOS x
		        SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.MANAGER_NAME,:v_const_no_encontrado)
		        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		        FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_EXISTE_MANAGER TBL
		    	WHERE 1 = 1
		    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
		    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
		    	;
	    	
		    	v_num_rows = ::rowcount;
			
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE CODIGO_AGENTE_COMMISSIONS en RECIBOS para TIPO_PRINCIPAL 15. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
															
			END;
			
			--RECIBOS para los que no existe el Manager
			TBL_RECIBOS_INSPECTOR_A_TRATAR_RN = SELECT TBL.*
												, CASE WHEN TBL.PERMANENCIA = :v_const_recibos_especificos_16 
													THEN IFNULL(AGE.CODIGO_UNICO,:v_const_no_encontrado)
													ELSE :v_const_no_encontrado 
												END AS MANAGER_NAME_2
												, ROW_NUMBER() OVER (
	        										PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.CODIGO_AGENTE_COMMISSIONS
	        										ORDER BY AGE.EFFECTIVEENDDATE DESC
	        											, CASE WHEN TBL.INSPECTOR = AGE.CODIGO_OCASO
	        												THEN 1
	        												ELSE 2
	        											END ASC
	        									) AS ROW_NUM_INSP
											FROM :TBL_RECIBOS_A_TRATAR_NO_EXISTE_MANAGER TBL
											LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE
												ON AGE.CODIGO_UNICO = TBL.INSPECTOR
											;
											
			v_num_rows = RECORD_COUNT(:TBL_RECIBOS_INSPECTOR_A_TRATAR_RN);
		
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_INSPECTOR_A_TRATAR_RN creada: ' || v_num_rows || ' filas. Se cruzan los recibos para los que no existe Manager con TBL_GEN_CODIGOS_AGENTE por CODIGO_UNICO = INSPECTOR', v_log_count, v_idproceso, 'debug');
			
			BEGIN
				DECLARE EXIT HANDLER FOR SQLEXCEPTION
					BEGIN
						
						ROLLBACK;
						
						CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE2 en RECIBOS para TIPO_PRINCIPAL 15 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
						UPDATE EXT.RECIBOS x
						SET x.ESTADO = :v_const_calculo_status_error
							, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.RECIBOS x, :TBL_RECIBOS_INSPECTOR_A_TRATAR_RN TBL
				    	WHERE 1 = 1
				    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				    		AND TBL.ROW_NUM_INSP = 1
				    	;
				    	
				    	COMMIT;
				    	
				    	RESIGNAL;
				    	
				    END;
						
		        UPDATE EXT.RECIBOS x
				SET x.CODIGO_AGENTE_COMMISSIONS = IFNULL(TBL.MANAGER_NAME_2,:v_const_no_encontrado)
		        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
		        FROM EXT.RECIBOS x, :TBL_RECIBOS_INSPECTOR_A_TRATAR_RN TBL
		    	WHERE 1 = 1
		    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
		    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
		    		AND TBL.ROW_NUM_INSP = 1
		    	;
				
				v_num_rows = ::rowcount;
			
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE2 CODIGO_AGENTE_COMMISSIONS en RECIBOS para TIPO_PRINCIPAL 15. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
			END;
											
			
			
			--Se vuelven a regenerar las tablas origen de antes del bucle para ir quitando registros. En cada vuelta tendrán que salir menos registros con tipo principal 15
			TBL_C_RECIBOS = SELECT TBL.*
	        				FROM EXT.RECIBOS TBL
	                        WHERE TBL.FILE_NAME = :i_file_name
	                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
	                        	AND TBL.ESTADO = :v_const_populate_status_ok
	                        	AND TBL.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
	                        	--AND LENGTH(TBL.CODIGO_UNICO_AGENTE) <= 10 --Condición para FT_COD_AGENTE_COMMISIONS
	                        	AND LENGTH(IFNULL(TBL.CODIGO_UNICO_AGENTE,'0')) <= 10 --Condición para FT_COD_AGENTE_COMMISIONS
	                        	--20251024 RMF: Añadimos condición para excluir los recibos tratados cuando el CODIGO_UNICO_AGENTE tiene longitud mayor de 10
	                        	AND NOT EXISTS(SELECT 1 
                        					FROM :TBL_AGENTE_COD_UNICO_AG_1 REC
                        					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                        						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                        						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                        		   	)
                        		AND NOT EXISTS(SELECT 1
                        					FROM :TBL_AGENTE_COD_UNICO_AG_2 REC
                        					WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        						AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                        						AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                        						AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                        		)
	                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
	                    	;
	                    	
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se vuelven a regenerar las tablas origen de antes del bucle para ir quitando registros', v_log_count, v_idproceso, 'debug');
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
			
	        TBL_MAX_AGE_TIPO_PRIN = SELECT TBL.CODIGO_AGENTE_COMMISSIONS AS CODIGO_UNICO
	        							, MAX(AGE.TIPO_AGENTE_PRIN) AS TIPO_AGENTE_PRIN
	        						FROM :TBL_C_RECIBOS TBL
	        						LEFT JOIN :TBL_GEN_CODIGOS_AGENTE AGE
	        							ON AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
	        								AND AGE.EFFECTIVESTARTDATE <= LAST_DAY(TBL.FECHA_COMPENSACION)
        									AND AGE.EFFECTIVEENDDATE > LAST_DAY(TBL.FECHA_COMPENSACION)
	        						GROUP BY TBL.CODIGO_AGENTE_COMMISSIONS
	        						;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_MAX_AGE_TIPO_PRIN);
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_MAX_AGE_TIPO_PRIN actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
	        
	        
	        TBL_C_RECIBOS_AGE_15 = SELECT TBL.*
	        						FROM :TBL_C_RECIBOS TBL
	        						WHERE EXISTS (SELECT 1 
	        										FROM :TBL_MAX_AGE_TIPO_PRIN AGE
	        										WHERE AGE.CODIGO_UNICO = TBL.CODIGO_AGENTE_COMMISSIONS
	        											AND AGE.TIPO_AGENTE_PRIN = 15
	        									)
	        						;
	        						
	        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS_AGE_15);
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS_AGE_15 actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin de vuelta ' || :v_count_bucle || ' del bucle TIPO_AGENTE_PRIN = 15', v_log_count, v_idproceso, 'debug');
        
        END WHILE
        ;
        
        
        --FT_CALCULA_EDAD_ASE
        --Volvemos a regenerar las tablas TBL_C_RECIBOS y TBL_C_POLIZAS
        TBL_C_RECIBOS = SELECT TBL.*
        				FROM EXT.RECIBOS TBL
                        WHERE TBL.FILE_NAME = :i_file_name
                        	AND (TBL.MARCA_CUENTA = :v_const_s OR TBL.PERMANENCIA = :v_const_recibos_especificos_65)
                        	AND TBL.ESTADO = :v_const_populate_status_ok
                        	AND TBL.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
                    	ORDER BY TBL.CODIGO_POLIZA, TBL.FECHA_EFECTO_RECIBO, TBL.CODIGO_RECIBO, TBL.PERMANENCIA DESC
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_RECIBOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_RECIBOS actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
		
		TBL_C_POLIZAS = SELECT TBL.*
        				FROM EXT.POLIZAS TBL
                        WHERE EXISTS (SELECT 1
                        				FROM :TBL_C_RECIBOS src
                        				WHERE src.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        )
                    	;
                    	
        v_num_rows = RECORD_COUNT(:TBL_C_POLIZAS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_POLIZAS actualizada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
		
		TBL_C_ASEGURADOS = SELECT ASE.CODIGO_POLIZA
								, ASE.NUMERO_ASEGURADO
								, ASE.FECHA_NACIMIENTO
								, REC.FECHA_EFECTO_RECIBO
								, ASE.FECHA_DE_DERECHOS
								, FLOOR(MONTHS_BETWEEN(ASE.FECHA_NACIMIENTO, REC.FECHA_EFECTO_RECIBO)/12) AS EDAD_ASEGURADO
								, FLOOR(MONTHS_BETWEEN(ASE.FECHA_NACIMIENTO, ASE.FECHA_DE_DERECHOS)/12) AS EDAD_DERECHOS
							FROM EXT.ASEGURADOS ASE
							INNER JOIN :TBL_C_RECIBOS REC ON REC.CODIGO_POLIZA = ASE.CODIGO_POLIZA
							;
		
		v_num_rows = RECORD_COUNT(:TBL_C_ASEGURADOS);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_ASEGURADOS creada: ' || v_num_rows || ' filas. Se calcula EDAD_ASEGURADO y EDAD_DERECHOS', v_log_count, v_idproceso, 'debug');
		
		TBL_C_ASEGURADOS_RN = SELECT TBL.*
										, ROW_NUMBER() OVER(
											PARTITION BY TBL.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO
											ORDER BY TBL.CODIGO_POLIZA ASC, TBL.NUMERO_ASEGURADO ASC,  TBL.FECHA_EFECTO_RECIBO desc, TBL.FECHA_DE_DERECHOS desc
										) AS ROW_NUM
									FROM :TBL_C_ASEGURADOS TBL
								;
								
		v_num_rows = RECORD_COUNT(:TBL_C_ASEGURADOS_RN);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_ASEGURADOS_RN creada: ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en ASEGURADOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.ASEGURADOS x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			        FROM EXT.ASEGURADOS x, :TBL_C_ASEGURADOS_RN TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
						AND TBL.ROW_NUM = 1 --Nos quedamos con un único valor para evitar problemas de duplicados si vienen varios recibos diferentes para la misma póliza
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			UPDATE EXT.ASEGURADOS x
			SET x.EDAD = TBL.EDAD_ASEGURADO
				, x.EDAD_DERECHOS = TBL.EDAD_DERECHOS
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.ASEGURADOS x, :TBL_C_ASEGURADOS_RN TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
				AND TBL.ROW_NUM = 1 --Nos quedamos con un único valor para evitar problemas de duplicados si vienen varios recibos diferentes para la misma póliza
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en EDAD / EDAD_DERECHOS en ASEGURADOS. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
																
		END;
		
		--FT_ACTUALIZA_PRIMA_NETA_ANUAL
		--Cruzamos GARANTIAS_RECIBO con RECIBOS para PERMANENCIA = 71, 66, 65 y con POLIZAS por RAMO = RRTT
		TBL_C_GARANTIAS_RECIBO = SELECT GAR_REC.CODIGO_POLIZA
										, GAR_REC.CODIGO_RECIBO
										, GAR_REC.CODIGO_SUPLEMENTO
										, GAR_REC.ESTADO_RECIBO
										, GAR_REC.PRODUCTO_CONTABLE
									FROM EXT.GARANTIAS_RECIBO GAR_REC
									INNER JOIN :TBL_C_RECIBOS TBL_REC ON TBL_REC.CODIGO_POLIZA = GAR_REC.CODIGO_POLIZA
										AND TBL_REC.CODIGO_RECIBO = GAR_REC.CODIGO_RECIBO
										AND TBL_REC.CODIGO_SUPLEMENTO = GAR_REC.CODIGO_SUPLEMENTO
										AND TBL_REC.ESTADO_RECIBO = GAR_REC.ESTADO_RECIBO
										AND TBL_REC.PERMANENCIA IN (:v_const_recibos_especificos_71,:v_const_recibos_especificos_65,:v_const_recibos_especificos_66)
									INNER JOIN :TBL_C_POLIZAS TBL_POL ON TBL_REC.CODIGO_POLIZA = TBL_POL.CODIGO_POLIZA
										AND TBL_POL.RAMO = :v_const_ramo_rrtt
								;
								
		v_num_rows = RECORD_COUNT(:TBL_C_GARANTIAS_RECIBO);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_GARANTIAS_RECIBO creada: ' || v_num_rows || ' filas. Cruce de GARANTIAS_RECIBO con TBL_C_RECIBOS para PERMANENCIA 71, 65 y 66 y RAMO = RRTT', v_log_count, v_idproceso, 'debug');
		
		--Calculamos el incremento de prima anual de un producto
		TBL_INCR_PRIMA_ANUAL = SELECT GAR_ASE.CODIGO_POLIZA
									, GAR_ASE.CODIGO_RECIBO
									, GAR_ASE.PRODUCTO_CONTABLE
									, TBL.CODIGO_SUPLEMENTO
									, TBL.ESTADO_RECIBO
									, SUM(GAR_ASE.PRIMA_NETA_ASEGURADO) AS INCREMENTO_PRIMA_ANUAL
								FROM EXT.GARANTIAS_ASEGURADO GAR_ASE
								INNER JOIN :TBL_C_GARANTIAS_RECIBO TBL ON TBL.CODIGO_POLIZA = GAR_ASE.CODIGO_POLIZA
									AND TBL.CODIGO_RECIBO = GAR_ASE.CODIGO_RECIBO
									AND TBL.PRODUCTO_CONTABLE = GAR_ASE.PRODUCTO_CONTABLE
								GROUP BY GAR_ASE.CODIGO_POLIZA, GAR_ASE.CODIGO_RECIBO, GAR_ASE.PRODUCTO_CONTABLE, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO
								;
		
		v_num_rows = RECORD_COUNT(:TBL_INCR_PRIMA_ANUAL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_INCR_PRIMA_ANUAL creada: ' || v_num_rows || ' filas. Suma de PRIMA_NETA_ASEGURADO para INCR_PRIMA_ANUAL', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en ASEGURADOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO x, :TBL_INCR_PRIMA_ANUAL TBL
					WHERE 1 = 1 
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
						AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			UPDATE EXT.GARANTIAS_RECIBO x
			SET x.PRIMA_NETA_ANUALIZADA = TBL.INCREMENTO_PRIMA_ANUAL
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.GARANTIAS_RECIBO x, :TBL_INCR_PRIMA_ANUAL TBL
			WHERE 1 = 1 
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
				AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
			;
			
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en PRIMA_NETA_ANUALIZADA en GARANTIAS_RECIBO. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
															
		END;
		
		--FT_ACTUALIZA_PORC_COM_NP_CONS
		--Volvemos a regenerar la tabla TBL_C_GARANTIAS_RECIBO ya que tenemos otros filtros. Se añade el PORCENTAJE_COMISION_CALCULAD si existe, sino se calcula
		TBL_PORCENTAJE_COMISION = SELECT GAR_REC.CODIGO_POLIZA
										, GAR_REC.CODIGO_RECIBO
										, GAR_REC.CODIGO_SUPLEMENTO
										, GAR_REC.ESTADO_RECIBO
										, GAR_REC.PRODUCTO_CONTABLE
										, TBL_REC.PERMANENCIA
										, CASE WHEN (GAR_REC.PORCENTAJE_COMISION_CALCULAD IS NULL OR GAR_REC.PORCENTAJE_COMISION_CALCULAD = 0)
											THEN CASE WHEN (GAR_REC.PRIMA_COMISIONABLE = 0) 
												THEN 0
												ELSE (GAR_REC.IMPORTE_COMISION/GAR_REC.PRIMA_COMISIONABLE)*100 END
											ELSE GAR_REC.PORCENTAJE_COMISION_CALCULAD
										END AS PORCENTAJE_COMISION
									FROM EXT.GARANTIAS_RECIBO GAR_REC
									INNER JOIN :TBL_C_RECIBOS TBL_REC ON TBL_REC.CODIGO_POLIZA = GAR_REC.CODIGO_POLIZA
										AND TBL_REC.CODIGO_RECIBO = GAR_REC.CODIGO_RECIBO
										AND TBL_REC.CODIGO_SUPLEMENTO = GAR_REC.CODIGO_SUPLEMENTO
										AND TBL_REC.ESTADO_RECIBO = :v_const_recibo_cobrado
										AND TBL_REC.PERMANENCIA IN (:v_const_recibos_especificos_71,:v_const_recibos_especificos_65,:v_const_recibos_cartera_81)
								;

		v_num_rows = RECORD_COUNT(:TBL_PORCENTAJE_COMISION);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_PORCENTAJE_COMISION creada: ' || v_num_rows || ' filas. Cruce GARANTIAS_RECIBO con TBL_C_RECIBOS con PERMANENCIA = 71, 65, 81 y ESTADO_RECIBO = C', v_log_count, v_idproceso, 'debug');
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
										
					UPDATE EXT.GARANTIAS_RECIBO x
			        SET x.ESTADO = :v_const_calculo_status_error
			        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.GARANTIAS_RECIBO x, :TBL_PORCENTAJE_COMISION TBL
					WHERE 1 = 1
						AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
						AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
						AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
						AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
					;
			        
			        COMMIT;
			        
			        RESIGNAL;
			        
				END;
		
			--Actualizamos GARANTIAS_RECIBO PORC_COMISION_NP para PERMANENCIAS 71 y 65 y PORC_COMISION_CONVERSACION para PERMANENCIA 81
			UPDATE EXT.GARANTIAS_RECIBO x
			SET x.PORC_COMISION_NP = CASE WHEN TBL.PERMANENCIA IN (:v_const_recibos_especificos_71,:v_const_recibos_especificos_65) 
										THEN TBL.PORCENTAJE_COMISION
										ELSE x.PORC_COMISION_NP
									END
				, x.PORC_COMISION_CONSERVACION = CASE WHEN TBL.PERMANENCIA IN (:v_const_recibos_cartera_81) 
													THEN TBL.PORCENTAJE_COMISION
													ELSE x.PORC_COMISION_CONSERVACION
												END
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.GARANTIAS_RECIBO x, :TBL_PORCENTAJE_COMISION TBL
			WHERE 1 = 1
				AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				AND x.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			;
		
			v_num_rows = ::rowcount;
			
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en PORC_COMISION_NP / PORC_COMISION_CONSERVACION en GARANTIAS_RECIBO. Filas: ' 
																|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
			
		END;
		
		--Se mira el nombre de fichero para saber a que proceso de calculo debemos llamar
		
		IF SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') IN  (	v_const_emi_diario_rrtt_eterna,
																	v_const_emi_diario_rrtt_ocaso,
																	v_const_cartera_rrtt_eterna,
																	v_const_cartera_rrtt_ocaso
																) THEN
			--Se llama el calculo de RRTT
			CALL EXT.SP_CALCULO_RRTT(i_file_name,v_idproceso, v_log_count);
		 
		ELSE
			--Se llama al calculo de RRGG
			CALL EXT.SP_CALCULO_RRGG(i_file_name,v_idproceso, v_log_count);
		END IF;


	TBL_RECIBOS_PENDIENTES = SELECT REC.CODIGO_RECIBO
									, REC.CODIGO_POLIZA
									, REC.ESTADO_RECIBO
									, REC.CODIGO_SUPLEMENTO
								FROM EXT.RECIBOS REC
								WHERE FILE_NAME = :i_file_name
									AND ESTADO = :v_const_populate_status_ok
							;
							
	v_num_rows = RECORD_COUNT(:TBL_RECIBOS_PENDIENTES);
		
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_PENDIENTES creada: ' || v_num_rows || ' filas. Recibos sin tratar por los procedimientos de CALCULO', v_log_count, v_idproceso, 'info');	
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en RECIBOS para MARCA_CUENTA = N de RECIBOS NO TRATADOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.RECIBOS x
				SET x.ESTADO = :v_const_calculo_status_error
					, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
				FROM EXT.RECIBOS x, :TBL_RECIBOS_PENDIENTES TBL
		    	WHERE 1 = 1
		    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
		    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
		    	;
		    	
		    	COMMIT;
		    	
		    	RESIGNAL;
		    	
		    END;
				
        UPDATE EXT.RECIBOS x
		SET x.MARCA_CUENTA = :v_const_n
        	, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
        FROM EXT.RECIBOS x, :TBL_RECIBOS_PENDIENTES TBL
    	WHERE 1 = 1
    		AND x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    		AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
    		AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
    		AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
    	;
		
		v_num_rows = ::rowcount;
	
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin UPDATE en RECIBOS para MARCA_CUENTA = N de RECIBOS NO TRATADOS. Filas: ' 
														|| v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
													
	END;
	
	TBL_GAR_REC_PENDIENTES = SELECT GAR_REC.CODIGO_RECIBO
								FROM EXT.GARANTIAS_RECIBO GAR_REC
								WHERE FILE_NAME = :i_file_name
									AND ESTADO = :v_const_populate_status_ok
							;
							
	v_num_rows = RECORD_COUNT(:TBL_GAR_REC_PENDIENTES);
		
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GAR_REC_PENDIENTES creada: ' || v_num_rows || ' filas. Garantías de Recibo sin tratar por los procedimientos de CALCULO', v_log_count, v_idproceso, 'info');	
	
	SELECT COUNT(*) INTO v_num_rows
	FROM EXT.RECIBOS
	WHERE 1 = 1
		AND ESTADO = :v_const_calculo_status_error
		AND FILE_NAME = :i_file_name
	;
			
	UPDATE EXT.IN_BATCH_CONTROL
	SET STATUS = :v_const_calculo_status_ok
		, REJECTED_ROWS = :v_num_rows
		, END_DATE = CURRENT_TIMESTAMP
	WHERE 1 = 1
		AND FILE_NAME = :i_file_name
		-- AND ID_PROCESO = :v_idproceso
	;
			
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE IN_BATCH_CONTROL con estado CALCULO_OK', v_log_count, v_idproceso, 'info');
	
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin procedure SP_CALCULO', v_log_count, v_idproceso, 'info');	
		
	END;	
END