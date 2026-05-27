CREATE PROCEDURE EXT.SP_POPULATE_EMITIDO (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
 
/*---------------------------------------------------------------------
    | Author: Rubén Martínez Fernández 
    | Company: Inycom
    | Initial Version Date: 03-Febrero-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta una vez que entra un fichero de EMITIDO e inserta los datos en las tablas finales de 
    |						RECIBOS, POLIZAS y GARANTIAS RECIBOS
    |		RECIOBLFTP211701P: Diario ASISA
	|		RECIAFLFTP162502P: Diario Eterna RRTT
	|		RECIABLFTP162702P: Diario Eterna RRGG
	|		RECIOFLFTP162402P: Diario Ocaso RRTT
	|		RECIOBLFTP162602P: Diario Ocaso RRGG
	|		RECIOBLFTPSOL162602P: Diario SOLNET
	|		RECIABLFTP163102P: Cartera Eterna RRGG
	|		RECIAFLFTP162902P: Cartera Eterna RRTT
	|		RECIOBLFTP163002P: Cartera Ocaso RRGG
	|		RECIOFLFTP162802P: Cartera Ocaso RRTT
	|		RECIOBLFTPSOL163002P: Cartera Ocaso SOLNET
	|		RECIOBLFTP165302P: Cobrado Ocaso RRGG
	|		RECIABLFTP165402P: Cobrado Eterna RRGG
	|		RECIOBLFTPSOL165302P: Cobrado SOLNET
	|		RECIOBLFTP211601P: Cobrado ASISA
	|
	| Version: 0.1	RMF 20250203		Initial Version.
	|
    -----------------------------------------------------------------------
*/
 
BEGIN
	USING SQLSCRIPT_STRING AS LIBRARY;
	--DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	--DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	
	DECLARE v_const_n VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N;
	DECLARE v_const_s VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S;
	DECLARE v_const_n_0 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N_0;
	DECLARE v_const_tipo_recibo_ad VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_RECIBO_AD;
	--DECLARE v_const_in_batch_preload INT := EXT.LIB_CONSTANTES:CONST_IN_BATCH_CONTROL_PRELOAD;
	--DECLARE v_const_in_batch_error INT := EXT.LIB_CONSTANTES:CONST_IN_BATCH_CONTROL_ERROR;
	--DECLARE v_const_in_batch_load INT := EXT.LIB_CONSTANTES:CONST_IN_BATCH_CONTROL_LOAD;
	--DECLARE v_const_prestage_status_load INT := EXT.LIB_CONSTANTES:CONST_PRESTAGE_STATUS_LOAD;
	--DECLARE v_const_prestage_status_ok INT := EXT.LIB_CONSTANTES:CONST_PRESTAGE_STATUS_OK;
	--DECLARE v_const_prestage_status_error INT := EXT.LIB_CONSTANTES:CONST_PRESTAGE_STATUS_ERROR;
	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR;
	DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK;
	DECLARE v_const_populate_status_error INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_ERROR;
	
	DECLARE v_const_recibos_especificos_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
	DECLARE v_const_recibos_especificos_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
	DECLARE v_const_recibos_especificos_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
	DECLARE v_const_recibos_especificos_10 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_10;
	DECLARE v_const_recibos_especificos_11 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_11;
	DECLARE v_const_recibos_especificos_0 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_0;
	DECLARE v_const_recibos_cartera_81 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_81;
	DECLARE v_const_recibos_cartera_72 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_72;
	DECLARE v_const_ramo_rrtt VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRTT;
	DECLARE v_const_ramo_rrgg VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRGG;
	DECLARE v_const_ramo_rrpp VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRPP;
	DECLARE v_const_cod_suplemento_defecto INTEGER := EXT.LIB_CONSTANTES:CONST_COD_SUPLEMENTO_DEFECTO;
	DECLARE v_const_cod_suplemento_desdobles INTEGER := EXT.LIB_CONSTANTES:CONST_COD_SUPLEMENTO_DESDOBLES;
	DECLARE v_const_cod_suplemento_100 INTEGER := EXT.LIB_CONSTANTES:CONST_COD_SUPLEMENTO_100;
	DECLARE v_const_motivo_baja_bb VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_BAJA_BB;
	DECLARE v_const_cod_recibo_anul_rrggpp VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRGGPP;
	DECLARE v_const_cod_recibo_anul_rrtt VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRTT;
	DECLARE v_const_tipo_rec_anul_k5 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_ANUL_K5;
	
	DECLARE v_const_tipo_mov_altapoli VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_ALTAPOLI;
	DECLARE v_const_recu_recibo VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECU_RECIBO;
	DECLARE v_const_tipo_rec_5 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_5;
	DECLARE v_const_tipo_rec_6 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_6;
	DECLARE v_const_motivo_alta_re VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_RE;
	DECLARE v_const_motivo_alta_ro VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_RO;
	DECLARE v_const_motivo_alta_rh VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_RH;
	DECLARE v_const_motivo_alta_ac VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_AC;
	DECLARE v_const_tipo_rec_gd VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_GD;
	DECLARE v_const_oficina_gestora_900 VARCHAR(3) := EXT.LIB_CONSTANTES:CONST_OFICINA_GESTORA_900;
	DECLARE v_const_oficina_gestora_0900 VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_OFICINA_GESTORA_0900;
	DECLARE v_const_recibo_cobrado VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
	DECLARE v_const_recibo_emitido VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EMITIDO;
	DECLARE v_const_recibo_pendiente VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_PENDIENTE;
	DECLARE v_const_recibo_anulado_d VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_ANULADO_D;
	DECLARE v_const_recibo_emitido_sinfirmar VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EMITIDO_SINFIRMAR;
	DECLARE v_const_cobros_solnet_ocaso VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_COBROS_SOLNET_OCASO;
	DECLARE v_const_365_dias NUMBER(3) := EXT.LIB_CONSTANTES:CONST_365_DIAS;
	
	DECLARE v_const_emi_diario_rrtt_eterna	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_ETERNA; -- AFLFTP162502P
	DECLARE v_const_emi_diario_rrtt_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_OCASO; --OFLFTP162402P
	DECLARE v_const_emi_diario_rrggrrpp_et	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_ET; --ABLFTP162702P
	DECLARE v_const_emi_diario_rrggrrpp_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_OC; --OBLFTP162602P
	DECLARE v_const_emi_diario_solnet_ocaso	VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_SOLNET_OCASO; --OBLFTPSOL162602P
	DECLARE v_file_type VARCHAR2(20) := NULL;
 
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
		
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
			--v_hayError := 1;
			v_num_rows := 0;
			
			CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE(i_file_name, i_id_proceso);	
			
			COMMIT;

			--Captura el error y lo envía a xDL
			RESIGNAL;
		END;

	BEGIN
		--Inicializamos el idProceso
		--SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, i_log_count, i_id_proceso, 'info');
		
		--Guardamos en una variable tabla información sobre jerarquía
		TBL_GEN_CODIGOS_AGENTE = SELECT * FROM EXT.VW_CODIGOS_DE_AGENTE VW
								WHERE 1=1
									AND VW.CODIGO_OCASO <> '0' 
									AND VW.CODIGO_OCASO <> '000000000' 
									AND VW.CODIGO_OCASO <> '0000000000'
								;
								
		v_num_rows = RECORD_COUNT(:TBL_GEN_CODIGOS_AGENTE);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_GEN_CODIGOS_AGENTE creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');						
		
		--Creacion de la tabla TBL_RECIBO_STAGE_ASC
		TBL_RECIBO_STAGE_ASC = SELECT 
					        TBL.CODIGO_POLIZA,
					        TBL.PERMANENCIA,
					        COUNT(*) AS CONTADOR_POLIZA,
					        ROW_NUMBER() OVER (
					            PARTITION BY TBL.CODIGO_POLIZA 
					            ORDER BY 
					                CASE 
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_71 THEN 0
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_65 THEN 0
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_66 THEN 1
					                    WHEN TBL.PERMANENCIA = v_const_recibos_cartera_81 THEN 3
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_0  THEN 3
					                    ELSE 2
					                END ASC
					        ) AS ROW_NUM
					    FROM EXT.STAGE_RECIBOS TBL
					    WHERE TBL.FILE_NAME = i_file_name
					      AND TBL.ESTADO = v_const_stage_status_ok
					    GROUP BY TBL.CODIGO_POLIZA, TBL.PERMANENCIA
		;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_STAGE_ASC);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_STAGE_ASC creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Se crea una segunda tabla auxiliar para ordenar las pólizas al revés. De esta manera, nos quedaremos con el RN_DESC = 1 (simulamos la historificación de pólizas en LP)
		TBL_RECIBO_STAGE_DESC = SELECT TBL.*, ROW_NUMBER() OVER(PARTITION BY TBL.CODIGO_POLIZA ORDER BY ROW_NUM DESC) AS RN_DESC FROM :TBL_RECIBO_STAGE_ASC TBL;
		
		--Creacion de la tabla TBL_RECIBO_STAGE_ASC
		/*TBL_RECIBO_STAGE_DESC = SELECT 
					        TBL.CODIGO_POLIZA,
					        TBL.PERMANENCIA,
					        COUNT(*) AS CONTADOR_POLIZA,
					        ROW_NUMBER() OVER (
					            PARTITION BY TBL.CODIGO_POLIZA 
					            ORDER BY 
					                CASE 
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_71 THEN 0
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_65 THEN 0
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_66 THEN 1
					                    ELSE 2
					                END DESC
					        ) AS ROW_NUM
					    FROM EXT.STAGE_RECIBOS TBL
					    WHERE TBL.FILE_NAME = i_file_name
					      AND TBL.ESTADO = v_const_stage_status_ok
					    GROUP BY TBL.CODIGO_POLIZA, TBL.PERMANENCIA
		;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_STAGE_DESC);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_STAGE_DESC creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');*/
		
		TBL_RECIBO_IND_POL = SELECT 
        					TBL.IDENTIFICADOR
							, TBL.RAMO
							, TBL.CODIGO_POLIZA
							, TBL.MOTIVO_ALTA
							, TBL.FECHA_EFECTO_POLIZA
							, TBL.FECHA_EMISION_POLIZA
							, TBL.FECHA_CESION_POLIZA
							, TBL.MOTIVO_BAJA
							, TBL.FECHA_BAJA
							, TBL.FECHA_EFECTO_SUPLEMENTO
							, TBL.FECHA_VENCIMIENTO
							, TBL.FECHA_REHABILITACION
							, TBL.FORMA_PAGO
							, TBL.TIPO_CAMPANIA
							, TBL.CODIGO_AGENTE_ORIGINAL
							, TBL.CODIGO_UNICO_AGENTE
							, TBL.INSPECTOR
							, TBL.OFICINA_COBRADORA
							, TBL.OFICINA_GESTORA
							, TBL.SEGUNDA_RESIDENCIA
							, TBL.TARIFA
							, TBL.ZONA
							, TBL.CLAVE_RIESGO
							, (CASE WHEN TBL.RAMO = v_const_ramo_rrtt 
										AND TBL.PERMANENCIA = v_const_recibos_especificos_66
										AND TBL.CODIGO_SUPLEMENTO = v_const_cod_suplemento_defecto
										AND TBL.TIPO_MOVIMIENTO = v_const_tipo_mov_altapoli
								THEN TO_CHAR(v_const_cod_suplemento_desdobles)
								ELSE (CASE WHEN TBL.RAMO = v_const_ramo_rrtt
										AND TBL.PERMANENCIA = v_const_recibos_especificos_10
									THEN TO_CHAR(v_const_cod_suplemento_100)
									ELSE IFNULL(TBL.CODIGO_SUPLEMENTO,TO_CHAR(v_const_cod_suplemento_defecto)) END) END) AS CODIGO_SUPLEMENTO
										--TBL.CODIGO_SUPLEMENTO
							, TBL.DISTRITO_COBRO
							, TBL.MODALIDAD
							, TBL.DURACION
							, TBL.IND_COMI_CALCULADA
							, TBL.IND_POR_CALCULADO
							, TBL.POR_COMI_CALCULADA
							, TBL.IMPORTE_COMISION
							, TBL.CLAUSULA
							, TBL.AUMENTO_CAPITALES_GAR
							, TBL.SUSTITUCION_INCENDIOS
							, TBL.CODIGO_SINIESTRO
							, TBL.EXCLUIDO_COMISIONES
							, TBL.TRASPASADA
							, TBL.INCRE_PRIMA_ANUAL
							, TBL.DTO_IMPT_SINIESTRALIDAD
							, TBL.DTO_POR_PRIORITARIO
							, TBL.RIESGO
							, TBL.COLECTIVO
							, TBL.AUTOLIQUIDA
							, TBL.KILOMETROS
							, TBL.PRIMER_RECIBO
							, TBL.CODIGO_RECIBO
							, TBL.PERMANENCIA
							, TBL.TIPO_RECIBO
							, TBL.ESTADO_RECIBO 
							, TBL.FECHA_COBRO
							, TBL.FECHA_EFECTO_RECIBO
							, TBL.FECHA_VENCIMIENTO_RECIBO
							, TBL.TIPO_MOVIMIENTO
							, TBL.PORC_DESTO_SOBREPC
							, TBL.VALOR_POLIZA
							, TBL.MARCA_RECUPERADO
							, TBL.PRODUCTO_CONTABLE
							, TBL.FECHA_ALTA_GAR_POL
							, TBL.FECHA_BAJA_GAR_POL
							, TBL.PRIMA_NETA_RECIBO
							, TBL.PRIMA_BRUTA_RECIBO
							, TBL.RECARGO
							, TBL.PORCENTAJE_BONIFICACION
							, TBL.POLIZA_CON_AGENTE
							, TBL.MOVILIDAD
							, TBL.PRIMA_UNICA
							, TBL.NUM_ORDEN_MOVIMIENTO
							, TBL.FECHA_EMISION_REC
							, TBL.CARGO_COMPENSACION
							, TBL.ZONA_EXPLOTACION
							, TBL.CODIGO_AGENTE_ZONA
							, TBL.FILE_NAME
							, TBL.ESTADO
							, TBL.FECHA_MODIFICACION
					        , ROW_NUMBER() OVER (
					            PARTITION BY TBL.CODIGO_POLIZA--, TBL.PERMANENCIA
					            ORDER BY 
					                TBL.FECHA_EFECTO_POLIZA DESC,
					                TBL.CARGO_COMPENSACION DESC,
					                CASE 
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_65 THEN TBL.NUM_ORDEN_MOVIMIENTO
					                    ELSE 0 --RAMO
					                END DESC,
					                TBL.FECHA_EFECTO_RECIBO ASC,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END ASC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END DESC,
					            	TBL.ESTADO_RECIBO ASC,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END DESC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END ASC,
					                TBL.PRODUCTO_CONTABLE ASC
					        ) AS ROW_NUM
					    FROM EXT.STAGE_RECIBOS TBL
					    /*INNER JOIN :TBL_RECIBO_STAGE_DESC RS
					    	ON RS.CODIGO_POLIZA = TBL.CODIGO_POLIZA
					    		AND RS.PERMANENCIA = TBL.PERMANENCIA
					    		AND RS.RN_DESC = 1*/
					    WHERE EXISTS (
					        SELECT 1 
					        FROM :TBL_RECIBO_STAGE_DESC RS
					        WHERE RS.CODIGO_POLIZA = TBL.CODIGO_POLIZA 
					          AND RS.PERMANENCIA = TBL.PERMANENCIA
					          --AND(RS.ROW_NUM = 1 AND PERMANENCIA <> 0 OR PERMANENCIA = 0)
					          AND RS.RN_DESC = 1
					          --AND RS.ROW_NUM = 1
						    )
						    AND TBL.ESTADO = v_const_stage_status_ok
						    AND TBL.FILE_NAME = i_file_name
						    --AND TBL.CODIGO_POLIZA = '0110300121828100000000N'
		;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_POL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_IND_POL creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--DEBUG
		/*DELETE FROM EXT.TBL_RECIBO_IND_POL_DEBUG;
		INSERT INTO EXT.TBL_RECIBO_IND_POL_DEBUG
		SELECT * FROM :TBL_RECIBO_IND_POL;*/
		
		TBL_RECIBO_IND_REC = SELECT 
        					TBL.IDENTIFICADOR
							, TBL.RAMO
							, TBL.CODIGO_POLIZA
							, TBL.MOTIVO_ALTA
							, TBL.FECHA_EFECTO_POLIZA
							, TBL.FECHA_EMISION_POLIZA
							, TBL.FECHA_CESION_POLIZA
							, TBL.MOTIVO_BAJA
							, TBL.FECHA_BAJA
							, TBL.FECHA_EFECTO_SUPLEMENTO
							, TBL.FECHA_VENCIMIENTO
							, TBL.FECHA_REHABILITACION
							, TBL.FORMA_PAGO
							, TBL.TIPO_CAMPANIA
							, TBL.CODIGO_AGENTE_ORIGINAL
							, TBL.CODIGO_UNICO_AGENTE
							, TBL.INSPECTOR
							, TBL.OFICINA_COBRADORA
							, TBL.OFICINA_GESTORA
							, TBL.SEGUNDA_RESIDENCIA
							, TBL.TARIFA
							, TBL.ZONA
							, TBL.CLAVE_RIESGO
							, (CASE WHEN TBL.RAMO = v_const_ramo_rrtt 
										AND TBL.PERMANENCIA = v_const_recibos_especificos_66
										AND TBL.CODIGO_SUPLEMENTO = v_const_cod_suplemento_defecto
										AND TBL.TIPO_MOVIMIENTO = v_const_tipo_mov_altapoli
								THEN TO_CHAR(v_const_cod_suplemento_desdobles)
								ELSE (CASE WHEN TBL.RAMO = v_const_ramo_rrtt
										AND TBL.PERMANENCIA = v_const_recibos_especificos_10
									THEN TO_CHAR(v_const_cod_suplemento_100)
									ELSE IFNULL(TBL.CODIGO_SUPLEMENTO,TO_CHAR(v_const_cod_suplemento_defecto)) END) END) AS CODIGO_SUPLEMENTO
										--TBL.CODIGO_SUPLEMENTO
							, TBL.DISTRITO_COBRO
							, TBL.MODALIDAD
							, TBL.DURACION
							, TBL.IND_COMI_CALCULADA
							, TBL.IND_POR_CALCULADO
							, TBL.POR_COMI_CALCULADA
							, TBL.IMPORTE_COMISION
							, TBL.CLAUSULA
							, TBL.AUMENTO_CAPITALES_GAR
							, TBL.SUSTITUCION_INCENDIOS
							, TBL.CODIGO_SINIESTRO
							, TBL.EXCLUIDO_COMISIONES
							, TBL.TRASPASADA
							, TBL.INCRE_PRIMA_ANUAL
							, TBL.DTO_IMPT_SINIESTRALIDAD
							, TBL.DTO_POR_PRIORITARIO
							, TBL.RIESGO
							, TBL.COLECTIVO
							, TBL.AUTOLIQUIDA
							, TBL.KILOMETROS
							, TBL.PRIMER_RECIBO
							, CASE WHEN (TBL.MOTIVO_ALTA = v_const_motivo_baja_bb AND TBL.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)) 
								THEN v_const_cod_recibo_anul_rrggpp 
								ELSE TBL.CODIGO_RECIBO 
							END AS CODIGO_RECIBO
							, TBL.PERMANENCIA
							, TBL.TIPO_RECIBO
							, CASE WHEN (TBL.MOTIVO_ALTA = v_const_motivo_baja_bb AND TBL.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)) 
								THEN v_const_recibo_cobrado 
								ELSE TBL.ESTADO_RECIBO 
							END AS ESTADO_RECIBO
							, TBL.FECHA_COBRO
							, TBL.FECHA_EFECTO_RECIBO
							, TBL.FECHA_VENCIMIENTO_RECIBO
							, TBL.TIPO_MOVIMIENTO
							, TBL.PORC_DESTO_SOBREPC
							, TBL.VALOR_POLIZA
							, TBL.MARCA_RECUPERADO
							, TBL.PRODUCTO_CONTABLE
							, TBL.FECHA_ALTA_GAR_POL
							, TBL.FECHA_BAJA_GAR_POL
							, TBL.PRIMA_NETA_RECIBO
							, TBL.PRIMA_BRUTA_RECIBO
							, TBL.RECARGO
							, TBL.PORCENTAJE_BONIFICACION
							, TBL.POLIZA_CON_AGENTE
							, TBL.MOVILIDAD
							, TBL.PRIMA_UNICA
							, TBL.NUM_ORDEN_MOVIMIENTO
							, TBL.FECHA_EMISION_REC
							, TBL.CARGO_COMPENSACION
							, TBL.ZONA_EXPLOTACION
							, TBL.CODIGO_AGENTE_ZONA
							, TBL.FILE_NAME
							, TBL.ESTADO
							, TBL.FECHA_MODIFICACION
					        , ROW_NUMBER() OVER (
					            PARTITION BY TBL.CODIGO_POLIZA, TBL.PERMANENCIA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO
					            ORDER BY 
					                TBL.FECHA_EFECTO_POLIZA DESC,
					                TBL.CARGO_COMPENSACION DESC,
					                CASE 
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_65 THEN TBL.NUM_ORDEN_MOVIMIENTO
					                    ELSE 2 --RAMO
					                END DESC,
					                TBL.FECHA_EFECTO_RECIBO ASC,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END ASC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END DESC,
					                TBL.ESTADO_RECIBO,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END DESC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END ASC,
					                TBL.PRODUCTO_CONTABLE ASC
					        ) AS ROW_NUM
					        , ROW_NUMBER() OVER (
					            PARTITION BY TBL.CODIGO_POLIZA--, TBL.PERMANENCIA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO
					            ORDER BY 
					                TBL.FECHA_EFECTO_POLIZA DESC,
					                TBL.CARGO_COMPENSACION DESC,
					                CASE 
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_65 THEN TBL.NUM_ORDEN_MOVIMIENTO
					                    ELSE 2 --RAMO
					                END DESC,
					                TBL.FECHA_EFECTO_RECIBO ASC,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END ASC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END DESC,
					                TBL.ESTADO_RECIBO ASC,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END DESC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END ASC,
					                TBL.PRODUCTO_CONTABLE ASC
					        ) AS ROW_NUM_POL
					        , ROW_NUMBER() OVER (
					            PARTITION BY TBL.CODIGO_POLIZA, TBL.PERMANENCIA, TBL.CODIGO_RECIBO, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.PRODUCTO_CONTABLE
					            ORDER BY 
					                TBL.FECHA_EFECTO_POLIZA DESC,
					                TBL.CARGO_COMPENSACION DESC,
					                CASE 
					                    WHEN TBL.PERMANENCIA = v_const_recibos_especificos_65 THEN TBL.NUM_ORDEN_MOVIMIENTO
					                    ELSE 2 --RAMO
					                END DESC,
					                TBL.FECHA_EFECTO_RECIBO ASC,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END ASC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN TBL.CODIGO_RECIBO END DESC,
					                TBL.ESTADO_RECIBO ASC,
					                CASE 
					                    WHEN TBL.RAMO = v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END DESC,
					                CASE 
					                    WHEN TBL.RAMO <> v_const_ramo_rrtt THEN IFNULL(TBL.CODIGO_SUPLEMENTO, v_const_cod_suplemento_defecto) END ASC,
					                TBL.PRODUCTO_CONTABLE ASC
					        ) AS ROW_NUM_GAR_REC
					    FROM EXT.STAGE_RECIBOS TBL
					    WHERE EXISTS (
					        SELECT 1 
					        FROM :TBL_RECIBO_STAGE_ASC RS
					        WHERE RS.CODIGO_POLIZA = TBL.CODIGO_POLIZA 
					          AND RS.PERMANENCIA = TBL.PERMANENCIA
						    )
						    AND TBL.ESTADO = v_const_stage_status_ok
						    AND TBL.FILE_NAME = i_file_name
		;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_REC);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_IND_REC creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--debug
	/*	DELETE FROM EXT.TBL_RECIBO_IND_REC_DEBUG;
		INSERT INTO EXT.TBL_RECIBO_IND_REC_DEBUG 
		SELECT * FROM :TBL_RECIBO_IND_REC;*/
		
		--Guardamos en TBL_STAGE_RECIBOS_BAJA los recibos con MOTIVO_BAJA = 'BB' y ramo = RRPP o RRGG
		TBL_RECIBO_IND_BAJA = SELECT TBL.IDENTIFICADOR
									, TBL.RAMO
									, TBL.CODIGO_POLIZA
									, TBL.MOTIVO_ALTA
									, TBL.FECHA_EFECTO_POLIZA
									, TBL.FECHA_EMISION_POLIZA
									, TBL.FECHA_CESION_POLIZA
									, TBL.MOTIVO_BAJA
									, TBL.FECHA_BAJA
									, TBL.FECHA_EFECTO_SUPLEMENTO
									, TBL.FECHA_VENCIMIENTO
									, TBL.FECHA_REHABILITACION
									, TBL.FORMA_PAGO
									, TBL.TIPO_CAMPANIA
									, TBL.CODIGO_AGENTE_ORIGINAL
									, TBL.CODIGO_UNICO_AGENTE
									, TBL.INSPECTOR
									, TBL.OFICINA_COBRADORA
									, TBL.OFICINA_GESTORA
									, TBL.SEGUNDA_RESIDENCIA
									, TBL.TARIFA
									, TBL.ZONA
									, TBL.CLAVE_RIESGO
									, TBL.CODIGO_SUPLEMENTO
									, TBL.DISTRITO_COBRO
									, TBL.MODALIDAD
									, TBL.DURACION
									, TBL.IND_COMI_CALCULADA
									, TBL.IND_POR_CALCULADO
									, TBL.POR_COMI_CALCULADA
									, TBL.IMPORTE_COMISION
									, TBL.CLAUSULA
									, TBL.AUMENTO_CAPITALES_GAR
									, TBL.SUSTITUCION_INCENDIOS
									, TBL.CODIGO_SINIESTRO
									, TBL.EXCLUIDO_COMISIONES
									, TBL.TRASPASADA
									, TBL.INCRE_PRIMA_ANUAL
									, TBL.DTO_IMPT_SINIESTRALIDAD
									, TBL.DTO_POR_PRIORITARIO
									, TBL.RIESGO
									, TBL.COLECTIVO
									, TBL.AUTOLIQUIDA
									, TBL.KILOMETROS
									, TBL.PRIMER_RECIBO
									, v_const_cod_recibo_anul_rrggpp--CONST_COD_RECIBO_ANUL_RRGGPP
									, TBL.PERMANENCIA
									, TBL.TIPO_RECIBO
									, v_const_recibo_cobrado --CONST_RECIBO_COBRADO
									, TBL.FECHA_COBRO
									, TBL.FECHA_EFECTO_RECIBO
									, TBL.FECHA_VENCIMIENTO_RECIBO
									, TBL.TIPO_MOVIMIENTO
									, TBL.PORC_DESTO_SOBREPC
									, TBL.VALOR_POLIZA
									, TBL.MARCA_RECUPERADO
									, TBL.PRODUCTO_CONTABLE
									, TBL.FECHA_ALTA_GAR_POL
									, TBL.FECHA_BAJA_GAR_POL
									, TBL.PRIMA_NETA_RECIBO
									, TBL.PRIMA_BRUTA_RECIBO
									, TBL.RECARGO
									, TBL.PORCENTAJE_BONIFICACION
									, TBL.POLIZA_CON_AGENTE
									, TBL.MOVILIDAD
									, TBL.PRIMA_UNICA
									, TBL.NUM_ORDEN_MOVIMIENTO
									, TBL.FECHA_EMISION_REC
									, TBL.CARGO_COMPENSACION
									, TBL.ZONA_EXPLOTACION
									, TBL.CODIGO_AGENTE_ZONA
									, TBL.FILE_NAME
									, TBL.ESTADO
									, TBL.FECHA_MODIFICACION
									, TBL.ROW_NUM
								FROM :TBL_RECIBO_IND_POL TBL
								WHERE TBL.MOTIVO_ALTA = v_const_motivo_baja_bb --CONST_MOTIVO_BAJA_BB
									AND TBL.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp);
									
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_BAJA);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBO_IND_BAJA creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Sacamos posibles duplicados la TBL_RECIBO_IND_POL
        TBL_RECIBO_IND_POL_DUPL = SELECT COUNT(*)
									, CODIGO_POLIZA
									, ROW_NUM
								FROM :TBL_RECIBO_IND_POL
								WHERE ROW_NUM = 1
									AND ESTADO = v_const_stage_status_ok
								GROUP BY CODIGO_POLIZA, ROW_NUM
								HAVING COUNT(*) > 1
								;
								
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_POL_DUPL);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_RECIBO_IND_POL_DUPL creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
							
		TBL_RECIBO_IND_POL_LIMPIO = SELECT * 
								FROM :TBL_RECIBO_IND_POL src
								WHERE NOT EXISTS(SELECT 1 
												FROM :TBL_RECIBO_IND_POL_DUPL dupl
												WHERE dupl.CODIGO_POLIZA = src.CODIGO_POLIZA
								)
								;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_POL_LIMPIO);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_RECIBO_IND_POL_LIMPIO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Iniciamos la historificacion de POLIZAS cruzando con TBL_RECIBO_IND
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en POLIZAS_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.POLIZAS POL
						SET ESTADO = v_const_populate_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.POLIZAS POL, :TBL_RECIBO_IND_BAJA src
					WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND src.ESTADO = v_const_stage_status_ok
						AND src.ROW_NUM = 1 --Cogemos el primer registro de cada póliza
					;
					
					COMMIT;
					
					RESIGNAL;

				END;
			INSERT INTO EXT.POLIZAS_HIST
				SELECT i_id_proceso, POL.* 
				FROM EXT.POLIZAS POL
				INNER JOIN :TBL_RECIBO_IND_POL_LIMPIO TBL_REC 
					ON POL.CODIGO_POLIZA = TBL_REC.CODIGO_POLIZA
				WHERE TBL_REC.FILE_NAME = i_file_name
					AND TBL_REC.ESTADO = v_const_stage_status_ok
					AND TBL_REC.ROW_NUM = 1 --Cogemos el primer registro de cada póliza
				;
			
			v_num_rows := ::rowcount;
				
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en POLIZAS_HIST ' || v_num_rows , i_log_count, i_id_proceso, 'info');
		END;
		
		-- Update de pólizas de Baja
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE para bajas - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_BAJA);
					
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
					
					--Se actualizan los registros de POLIZAS con estado erróneo
					UPDATE EXT.POLIZAS POL
						SET ESTADO = v_const_populate_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.POLIZAS POL, :TBL_RECIBO_IND_BAJA src
					WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA
					;
					
					COMMIT;
					
					RESIGNAL;

				END;
			
			--Modificamos POLIZAS con MOTIVO_ALTA = Baja
			UPDATE EXT.POLIZAS POL
	        SET POL.MOTIVO_ALTA = src.MOTIVO_ALTA, 
	            POL.FECHA_EFECTO_POLIZA = src.FECHA_EFECTO_POLIZA, 
	            POL.MOTIVO_BAJA = src.MOTIVO_BAJA, 
	        	POL.FECHA_BAJA = src.FECHA_BAJA, 
	            POL.FILE_NAME = src.FILE_NAME
	        FROM EXT.POLIZAS POL, :TBL_RECIBO_IND_BAJA src
	        WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA;
	        
	        v_num_rows := ::rowcount;
	        
	        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en POLIZAS para polizas RRPP y RRGG de baja. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
        
        END;
        
        --Update de pólizas existentes que no sean Baja
        
        BEGIN
        
        	DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
				
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE de pólizas - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_POL_LIMPIO);
					
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
					
					--Se actualizan los registros de STAGE_RECIBOS con estado erróneo
					UPDATE EXT.POLIZAS POL
						SET ESTADO = v_const_populate_status_error,
							FECHA_MODIFICACION = CURRENT_TIMESTAMP
						FROM EXT.POLIZAS POL, :TBL_RECIBO_IND_POL_LIMPIO src
					WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA
					;
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;

				END;
        
	        UPDATE EXT.POLIZAS x
	        SET x.ID_RECIBO = src.IDENTIFICADOR
	        	, x.FILE_NAME = src.FILE_NAME
				, x.ESTADO = v_const_populate_status_ok
				, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
				, x.CODIGO_POLIZA = src.CODIGO_POLIZA			
				, x.RAMO = src.RAMO
				, x.MOTIVO_ALTA	= src.MOTIVO_ALTA
				, x.FECHA_EFECTO_POLIZA	= src.FECHA_EFECTO_POLIZA
				, x.FECHA_EMISION_POLIZA = src.FECHA_EMISION_POLIZA
				, x.FECHA_CESION_POLIZA	= src.FECHA_CESION_POLIZA
				--Guardamos el MOTIVO_BAJA original si ya estaba informado y ahora no llega
				, x.MOTIVO_BAJA	= CASE WHEN (x.MOTIVO_BAJA IS NOT NULL AND src.MOTIVO_BAJA IS NULL) THEN x.MOTIVO_BAJA ELSE src.MOTIVO_BAJA END 
				--Guardamos la FECHA_BAJA original si ya estaba informada y ahora no llega O la fecha de baja original es mayor que la nueva
				, x.FECHA_BAJA = CASE WHEN (x.FECHA_BAJA IS NOT NULL AND src.FECHA_BAJA IS NULL) OR (x.FECHA_BAJA > src.FECHA_BAJA) THEN x.FECHA_BAJA ELSE src.FECHA_BAJA END
				, x.FECHA_VENCIMIENTO = src.FECHA_VENCIMIENTO
				--Guardamos la FECHA_REHABILITACION original si ya estaba informada y ahora no llega O la fecha de baja original es mayor que la nueva
				, x.FECHA_REHABILITACION = CASE WHEN (x.FECHA_REHABILITACION IS NOT NULL AND src.FECHA_REHABILITACION IS NULL) OR (x.FECHA_REHABILITACION > src.FECHA_REHABILITACION) 
												THEN x.FECHA_REHABILITACION ELSE src.FECHA_REHABILITACION 
										   END
				--Guardamos la FORMA_PAGO original si la permanencia no es 71 ni 81 O CODIGO_SUPLEMENTO <> 0 O (TIPO_RECIBO = AD Y RAMO <> RRTT)
				, x.FORMA_PAGO = CASE WHEN (src.PERMANENCIA NOT IN (v_const_recibos_especificos_71,v_const_recibos_cartera_81) 
									OR src.CODIGO_SUPLEMENTO <> v_const_n_0
									OR (IFNULL(src.TIPO_RECIBO,'ZZ') = v_const_tipo_recibo_ad AND src.RAMO <> v_const_ramo_rrtt)) 
								THEN x.FORMA_PAGO
								ELSE src.FORMA_PAGO END
				, x.TIPO_CAMPANIA = src.TIPO_CAMPANIA
				, x.SEGUNDA_RESIDENCIA = src.SEGUNDA_RESIDENCIA
				, x.TARIFA = src.TARIFA
				, x.ZONA = src.ZONA
				, x.CLAVE_RIESGO = src.CLAVE_RIESGO			
				, x.MODALIDAD = src.MODALIDAD
				, x.DURACION = src.DURACION
				, x.CLAUSULA = src.CLAUSULA	
				, x.SUSTITUCION_INCENDIOS = src.SUSTITUCION_INCENDIOS	
				, x.EXCLUIDO_COMISIONES	= src.EXCLUIDO_COMISIONES
				, x.TRASPASADA = src.TRASPASADA	
				, x.DESCUENTO_IMPORTE_SINIESTRALID = ROUND(src.DTO_IMPT_SINIESTRALIDAD,2)
				, x.DESCUENTO_POR_PRIORITARIO = ROUND(src.DTO_POR_PRIORITARIO,2)
				, x.RIESGO = src.RIESGO
				, x.COLECTIVO = src.COLECTIVO		
				, x.AUTOLIQUIDA = src.AUTOLIQUIDA
				, x.KILOMETROS = ROUND(src.KILOMETROS,2)
				, x.MOVILIDAD = src.MOVILIDAD
				, x.POLIZA_CON_AGENTE = src.POLIZA_CON_AGENTE
				, x.AGENTE_CARTERA = '' 
				, x.IMP_COMISION_CARTERA = 0 
				, x.PORC_COMISION_CARTERA = 0 
				, x.FECHA_FIN_COMISION_CARTERA = NULL 
	    	FROM EXT.POLIZAS x, :TBL_RECIBO_IND_POL_LIMPIO src
	    	WHERE x.CODIGO_POLIZA = src.CODIGO_POLIZA
	    		AND src.ROW_NUM = 1
	    		AND NOT EXISTS (SELECT 1
	    						FROM :TBL_RECIBO_IND_BAJA 
	    						WHERE CODIGO_POLIZA = src.CODIGO_POLIZA);
	    	
	    	v_num_rows := ::rowcount;
	        
	        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en POLIZAS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
	        
	    END;
	    
	    -- Insert de pólizas nuevas
	    
	    BEGIN
	    
	    	DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT de POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_POL_LIMPIO);
					
					--Se actualizan los campos de la in_batch_control para indicar el error
					UPDATE EXT.IN_BATCH_CONTROL
					SET REJECTED_ROWS = v_num_rows,
						STATUS = v_const_populate_status_error,
						END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = i_file_name
						AND ID_PROCESO = i_id_proceso;
					
					--Se actualizan los registros de STAGE_RECIBOS con estado erróneo
					UPDATE EXT.STAGE_RECIBOS STG
					SET STG.ESTADO = v_const_populate_status_error,
						STG.FECHA_MODIFICACION = CURRENT_TIMESTAMP
					FROM EXT.STAGE_RECIBOS STG, :TBL_RECIBO_IND_POL_LIMPIO src
					WHERE STG.FILE_NAME = i_file_name
						AND STG.ESTADO = v_const_stage_status_ok
						AND STG.CODIGO_POLIZA = src.CODIGO_POLIZA
			    		AND src.ROW_NUM = 1
			    		AND NOT EXISTS (SELECT 1
			    						FROM :TBL_RECIBO_IND_BAJA 
			    						WHERE CODIGO_POLIZA = src.CODIGO_POLIZA);	
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;

				END;
 
			INSERT INTO EXT.POLIZAS
				SELECT src.IDENTIFICADOR --ID_RECIBO
					, src.FILE_NAME
					, v_const_populate_status_ok
					, CURRENT_TIMESTAMP
					, src.CODIGO_POLIZA			
					, src.RAMO
					, src.MOTIVO_ALTA			
					, src.FECHA_EFECTO_POLIZA	
					, src.FECHA_EMISION_POLIZA	
					, src.FECHA_CESION_POLIZA	
					, src.MOTIVO_BAJA			
					, src.FECHA_BAJA				
					, src.FECHA_VENCIMIENTO		
					, src.FECHA_REHABILITACION	
					, src.FORMA_PAGO				
					, src.TIPO_CAMPANIA			
					, src.SEGUNDA_RESIDENCIA		
					, src.TARIFA
					, src.ZONA
					, src.CLAVE_RIESGO			
					, src.MODALIDAD				
					, src.DURACION				
					, src.CLAUSULA				
					, src.SUSTITUCION_INCENDIOS	
					, src.EXCLUIDO_COMISIONES	
					, src.TRASPASADA				
					, ROUND(src.DTO_IMPT_SINIESTRALIDAD,2)
					, ROUND(src.DTO_POR_PRIORITARIO,2)		
					, src.RIESGO
					, src.COLECTIVO				
					, src.AUTOLIQUIDA			
					, ROUND(src.KILOMETROS,2)
					, src.MOVILIDAD				
					, src.POLIZA_CON_AGENTE		
					, ''			
					, 0
					, 0
					, NULL
				FROM :TBL_RECIBO_IND_POL_LIMPIO src
				WHERE 1=1
					AND src.FILE_NAME = i_file_name
					AND src.ESTADO = v_const_stage_status_ok
					AND src.ROW_NUM = 1 --Cogemos el primer registro de cada recibo (póliza única)
					AND NOT EXISTS (SELECT 1 
									FROM EXT.POLIZAS POL
									WHERE POL.CODIGO_POLIZA = src.CODIGO_POLIZA)
				;
		
			v_num_rows := ::rowcount;
			
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en POLIZAS para polizas nuevas. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		END;
		
		--Se pone una variable par_esRH_SN_out a SI que luego provoca un error (incluyendo lógica de otros valores) en el POPULATE viejo para ese registro línea 15121
		--Se lleva esa variable como un AND en las condiciones de las distintas consultas: (PERMANENCIA = v_const_recibos_especificos_65 AND MOTIVO_ALTA = v_const_recu_recibo)
		
		--Update STAGE_RECIBOS con estado error para recibos rehabilitados y otros distintos
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE de RECIBOS para recibos rehabilitados y otros distintos - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
					--v_hayError := 1;
					SELECT COUNT(*) INTO v_num_rows
					FROM EXT.STAGE_RECIBOS
					WHERE 1=1
						AND FILE_NAME = i_file_name
						AND ((PERMANENCIA = v_const_recibos_especificos_65 OR MOTIVO_ALTA = v_const_recu_recibo) --v_esRH_SN = SI
							AND (PERMANENCIA <> v_const_recibos_especificos_65 OR TIPO_RECIBO NOT IN (v_const_motivo_alta_re, v_const_motivo_alta_ro
																									, v_const_motivo_alta_rh, v_const_motivo_alta_ac
																									, v_const_tipo_rec_gd, v_const_tipo_rec_5
																									, v_const_tipo_rec_6)
							)
						)
						OR (NOT(PERMANENCIA = v_const_recibos_especificos_65 OR MOTIVO_ALTA = v_const_recu_recibo) --v_esRH_SN = NO
							AND (PERMANENCIA = v_const_recibos_especificos_65 AND TIPO_RECIBO IN (v_const_motivo_alta_re, v_const_motivo_alta_ro
																									, v_const_motivo_alta_rh)
							)
						)
						OR ((PERMANENCIA = v_const_recibos_especificos_65 OR MOTIVO_ALTA = v_const_recu_recibo) --v_esRH_SN = SI
							AND RAMO <> v_const_ramo_rrtt AND MOTIVO_ALTA <> v_const_recu_recibo AND TIPO_RECIBO NOT IN (v_const_tipo_rec_5, v_const_tipo_rec_6)
						)
					;
					
					--Se actualizan los campos de la in_batch_control para indicar el error
					UPDATE EXT.IN_BATCH_CONTROL
					SET REJECTED_ROWS = v_num_rows,
						STATUS = v_const_populate_status_error,
						END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = i_file_name
						AND ID_PROCESO = i_id_proceso;
					
					COMMIT;
					
					RESIGNAL;

				END;
			
			
			UPDATE EXT.STAGE_RECIBOS
			SET ESTADO = v_const_populate_status_error
			, FECHA_MODIFICACION = CURRENT_TIMESTAMP
			WHERE 1=1
				AND FILE_NAME = i_file_name
				AND ((PERMANENCIA = v_const_recibos_especificos_65 OR MOTIVO_ALTA = v_const_recu_recibo) --v_esRH_SN = SI
					AND (PERMANENCIA <> v_const_recibos_especificos_65 OR TIPO_RECIBO NOT IN (v_const_motivo_alta_re, v_const_motivo_alta_ro
																							, v_const_motivo_alta_rh, v_const_motivo_alta_ac
																							, v_const_tipo_rec_gd, v_const_tipo_rec_5
																							, v_const_tipo_rec_6)
					)
				)
				OR (NOT(PERMANENCIA = v_const_recibos_especificos_65 OR MOTIVO_ALTA = v_const_recu_recibo) --v_esRH_SN = NO
					AND (PERMANENCIA = v_const_recibos_especificos_65 AND TIPO_RECIBO IN (v_const_motivo_alta_re, v_const_motivo_alta_ro
																							, v_const_motivo_alta_rh)
					)
				)
				OR ((PERMANENCIA = v_const_recibos_especificos_65 OR MOTIVO_ALTA = v_const_recu_recibo) --v_esRH_SN = SI
					AND RAMO <> v_const_ramo_rrtt AND MOTIVO_ALTA <> v_const_recu_recibo AND TIPO_RECIBO NOT IN (v_const_tipo_rec_5, v_const_tipo_rec_6)
				)
			;
			
			v_num_rows := ::rowcount;
			
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE Error Populate en STAGE_RECIBOS para recibos rehabilitados y otros distintos. Filas: ' 
												|| v_num_rows, i_log_count, i_id_proceso, 'info');
		
		END;
		
		--Sacamos posibles duplicados la TBL_RECIBO_IND_REC por clave de recibo
        TBL_RECIBO_IND_REC_DUPL = SELECT COUNT(*)
									, CODIGO_POLIZA
									, CODIGO_RECIBO
									, CODIGO_SUPLEMENTO
									, ESTADO_RECIBO
								FROM :TBL_RECIBO_IND_REC
								WHERE ROW_NUM = 1
									AND ESTADO = v_const_stage_status_ok
								GROUP BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO
								HAVING COUNT(*) > 1
								;
								
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_REC_DUPL);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_RECIBO_IND_REC_DUPL creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
							
		TBL_RECIBO_IND_REC_LIMPIO = SELECT * 
								FROM :TBL_RECIBO_IND_REC src
								WHERE NOT EXISTS(SELECT 1 
												FROM :TBL_RECIBO_IND_REC_DUPL dupl
												WHERE dupl.CODIGO_POLIZA = src.CODIGO_POLIZA
													AND dupl.CODIGO_RECIBO = src.CODIGO_RECIBO
													AND dupl.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
													AND dupl.ESTADO_RECIBO = src.ESTADO_RECIBO
								)
								;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_REC_LIMPIO);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_RECIBO_IND_REC_LIMPIO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Actualización de RECIBOS con clave duplicada con estado POPULATE_ERROR
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en STAGE_RECIBOS para RECIBOS NO validos y con clave duplicada - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
				END;
				
				UPDATE EXT.STAGE_RECIBOS x
				SET ESTADO = v_const_populate_status_error
					, FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE EXISTS(SELECT 1
							FROM :TBL_RECIBO_IND_REC_DUPL src
							WHERE x.CODIGO_POLIZA = src.CODIGO_POLIZA
								AND x.CODIGO_RECIBO = src.CODIGO_RECIBO
								AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
								AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
							)
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en STAGE_RECIBOS para clave duplicada por RECIBO. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		
		
		END;
		
		--TRATAR RECIBOS
		--Se incluye una nueva columna para RECIBO_VALIDO:
		--	IF (RAMO = RRTT Y ESTADO_RECIBO = COBRADO, EMITIDO, PENDIENTE) O
		--		(RAMO = RRGG, RRPP Y (ESTADO_RECIBO <> ANULADO_D O CODIGO_RECIBO = ANULADO_RRGGPP)) THEN
		--			IF (RAMO = RRTT, RRPP Y PERMANENCIA = 81 Y CODIGO_UNICO_AGENTE = 0 Y CODIGO_RECIBO = ANULADO_RRGGPP) THEN
		--				comprueba SUCURSAL: si es sucursal entonces no inserta el RECIBO
		
		TBL_RECIBOS_A_TRATAR_1 = SELECT TBL.IDENTIFICADOR
									, TBL.RAMO
									, TBL.CODIGO_POLIZA
									, TBL.MOTIVO_ALTA
									, TBL.FECHA_EFECTO_POLIZA
									, TBL.FECHA_EMISION_POLIZA
									, TBL.FECHA_CESION_POLIZA
									, TBL.MOTIVO_BAJA
									, TBL.FECHA_BAJA
									, TBL.FECHA_EFECTO_SUPLEMENTO
									, TBL.FECHA_VENCIMIENTO
									, TBL.FECHA_REHABILITACION
									, TBL.FORMA_PAGO
									, TBL.TIPO_CAMPANIA
									, TBL.CODIGO_AGENTE_ORIGINAL
									, TBL.CODIGO_UNICO_AGENTE
									, TBL.INSPECTOR
									, TBL.OFICINA_COBRADORA
									, TBL.OFICINA_GESTORA
									, TBL.SEGUNDA_RESIDENCIA
									, TBL.TARIFA
									, TBL.ZONA
									, TBL.CLAVE_RIESGO
									, TBL.CODIGO_SUPLEMENTO
									, TBL.DISTRITO_COBRO
									, TBL.MODALIDAD
									, TBL.DURACION
									, TBL.IND_COMI_CALCULADA
									, TBL.IND_POR_CALCULADO
									, TBL.POR_COMI_CALCULADA
									, TBL.IMPORTE_COMISION
									, TBL.CLAUSULA
									, TBL.AUMENTO_CAPITALES_GAR
									, TBL.SUSTITUCION_INCENDIOS
									, TBL.CODIGO_SINIESTRO
									, TBL.EXCLUIDO_COMISIONES
									, TBL.TRASPASADA
									, TBL.INCRE_PRIMA_ANUAL
									, TBL.DTO_IMPT_SINIESTRALIDAD
									, TBL.DTO_POR_PRIORITARIO
									, TBL.RIESGO
									, TBL.COLECTIVO
									, TBL.AUTOLIQUIDA
									, TBL.KILOMETROS
									, TBL.PRIMER_RECIBO
									, TBL.CODIGO_RECIBO
									, TBL.PERMANENCIA
									, TBL.TIPO_RECIBO
									, TBL.ESTADO_RECIBO 
									, TBL.FECHA_COBRO
									, TBL.FECHA_EFECTO_RECIBO
									, TBL.FECHA_VENCIMIENTO_RECIBO
									, TBL.TIPO_MOVIMIENTO
									, TBL.PORC_DESTO_SOBREPC
									, TBL.VALOR_POLIZA
									, TBL.MARCA_RECUPERADO
									, TBL.PRODUCTO_CONTABLE
									, TBL.FECHA_ALTA_GAR_POL
									, TBL.FECHA_BAJA_GAR_POL
									, TBL.PRIMA_NETA_RECIBO
									, TBL.PRIMA_BRUTA_RECIBO
									, TBL.RECARGO
									, TBL.PORCENTAJE_BONIFICACION
									, TBL.POLIZA_CON_AGENTE
									, TBL.MOVILIDAD
									, TBL.PRIMA_UNICA
									, TBL.NUM_ORDEN_MOVIMIENTO
									, TBL.FECHA_EMISION_REC
									, TBL.CARGO_COMPENSACION
									, TBL.ZONA_EXPLOTACION
									, TBL.CODIGO_AGENTE_ZONA
									, TBL.FILE_NAME
									, TBL.ESTADO
									, TBL.FECHA_MODIFICACION
									, TBL.ROW_NUM
									, 1 AS RECIBO_VALIDO
								FROM :TBL_RECIBO_IND_REC_LIMPIO TBL
									WHERE 1=1
										AND TBL.ROW_NUM = 1
										AND TBL.FILE_NAME = i_file_name
										AND TBL.ESTADO = v_const_stage_status_ok
										--Primer IF de TRATAR_DATOS_RECIBOS
										AND ((TBL.RAMO = v_const_ramo_rrtt AND TBL.ESTADO_RECIBO IN (v_const_recibo_cobrado,v_const_recibo_emitido,v_const_recibo_pendiente)) 
											OR ((TBL.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp) 
												AND TBL.ESTADO_RECIBO <> v_const_recibo_anulado_d 
												OR TBL.CODIGO_RECIBO = v_const_cod_recibo_anul_rrggpp)
												--Condición del IF anidado antes de la comprobación de sucursal
												OR (TBL.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)
													AND TBL.PERMANENCIA = v_const_recibos_cartera_81
													AND IFNULL(TRIM(TBL.CODIGO_UNICO_AGENTE),'0') = '0'
													AND TBL.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrggpp)
											)
										)
										
		;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR_1);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR_1 creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
		
		--Dentro de los recibos a tratar 1 hay que hacer diferenciación para los recibos RRGG, RRPP Y PERMANENCIA_81 Y CODIGO_UNICO_AGENTE = 0 Y CODIGO_RECIBO <> ANUL_RRGGPP
		TBL_RECIBOS_A_TRATAR_2 = SELECT TBL.IDENTIFICADOR
									, TBL.RAMO
									, TBL.CODIGO_POLIZA
									, TBL.MOTIVO_ALTA
									, TBL.FECHA_EFECTO_POLIZA
									, TBL.FECHA_EMISION_POLIZA
									, TBL.FECHA_CESION_POLIZA
									, TBL.MOTIVO_BAJA
									, TBL.FECHA_BAJA
									, TBL.FECHA_EFECTO_SUPLEMENTO
									, TBL.FECHA_VENCIMIENTO
									, TBL.FECHA_REHABILITACION
									, TBL.FORMA_PAGO
									, TBL.TIPO_CAMPANIA
									, TBL.CODIGO_AGENTE_ORIGINAL
									, TBL.CODIGO_UNICO_AGENTE
									, TBL.INSPECTOR
									, TBL.OFICINA_COBRADORA
									, TBL.OFICINA_GESTORA
									, TBL.SEGUNDA_RESIDENCIA
									, TBL.TARIFA
									, TBL.ZONA
									, TBL.CLAVE_RIESGO
									, TO_NUMBER(IFNULL(TBL.CODIGO_SUPLEMENTO,v_const_cod_suplemento_defecto)) AS CODIGO_SUPLEMENTO--TBL.CODIGO_SUPLEMENTO
									, TBL.DISTRITO_COBRO
									, TBL.MODALIDAD
									, TBL.DURACION
									, TBL.IND_COMI_CALCULADA
									, TBL.IND_POR_CALCULADO
									, TBL.POR_COMI_CALCULADA
									, TBL.IMPORTE_COMISION
									, TBL.CLAUSULA
									, TBL.AUMENTO_CAPITALES_GAR
									, TBL.SUSTITUCION_INCENDIOS
									, TBL.CODIGO_SINIESTRO
									, TBL.EXCLUIDO_COMISIONES
									, TBL.TRASPASADA
									, TBL.INCRE_PRIMA_ANUAL
									, TBL.DTO_IMPT_SINIESTRALIDAD
									, TBL.DTO_POR_PRIORITARIO
									, TBL.RIESGO
									, TBL.COLECTIVO
									, TBL.AUTOLIQUIDA
									, TBL.KILOMETROS
									, TBL.PRIMER_RECIBO
									, CASE WHEN TBL.PERMANENCIA = v_const_recibos_especificos_11 THEN TBL.CODIGO_RECIBO||'-' ELSE TBL.CODIGO_RECIBO END AS CODIGO_RECIBO--TBL.CODIGO_RECIBO
									, TBL.PERMANENCIA
									, TBL.TIPO_RECIBO
									, TBL.ESTADO_RECIBO 
									, TBL.FECHA_COBRO
									, TBL.FECHA_EFECTO_RECIBO
									, TBL.FECHA_VENCIMIENTO_RECIBO
									, TBL.TIPO_MOVIMIENTO
									, TBL.PORC_DESTO_SOBREPC
									, TBL.VALOR_POLIZA
									, TBL.MARCA_RECUPERADO
									, TBL.PRODUCTO_CONTABLE
									, TBL.FECHA_ALTA_GAR_POL
									, TBL.FECHA_BAJA_GAR_POL
									, TBL.PRIMA_NETA_RECIBO
									, TBL.PRIMA_BRUTA_RECIBO
									, TBL.RECARGO
									, TBL.PORCENTAJE_BONIFICACION
									, TBL.POLIZA_CON_AGENTE
									, TBL.MOVILIDAD
									, TBL.PRIMA_UNICA
									, TBL.NUM_ORDEN_MOVIMIENTO
									, TBL.FECHA_EMISION_REC
									, TBL.CARGO_COMPENSACION
									, TBL.ZONA_EXPLOTACION
									, TBL.CODIGO_AGENTE_ZONA
									, TBL.FILE_NAME
									, TBL.ESTADO
									, TBL.FECHA_MODIFICACION
									, TBL.ROW_NUM
									, CASE WHEN (SELECT DISTINCT TV.TIPO_OFICINA 
												FROM :TBL_GEN_CODIGOS_AGENTE TV
												WHERE TV.CODIGO_UNICO = TBL.OFICINA_GESTORA
													AND TV.TIPO_DATO = 1) = 1
												AND TBL.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)
												AND TBL.PERMANENCIA = v_const_recibos_cartera_81
												AND IFNULL(TRIM(TBL.CODIGO_UNICO_AGENTE),'0') = '0'
												AND TBL.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrggpp
										THEN 0 
										ELSE 1 END AS RECIBO_VALIDO
									, DAYS_BETWEEN(TBL.FECHA_REHABILITACION, TBL.FECHA_BAJA) AS DIFERENCIA_FECHAS
									, CASE WHEN TBL.CARGO_COMPENSACION IS NULL THEN NULL
										ELSE (CASE WHEN TBL.ESTADO_RECIBO = :v_const_recibo_pendiente
													OR (TBL.ESTADO_RECIBO = :v_const_recibo_emitido_sinfirmar AND SUBSTR_BEFORE(SUBSTR_AFTER(:i_file_name ,'RECI'),'_') = :v_const_cobros_solnet_ocaso)
												THEN ADD_MONTHS(TBL.CARGO_COMPENSACION,1)
												ELSE TBL.CARGO_COMPENSACION END) 
										END AS FECHA_COMPENSACION
								FROM :TBL_RECIBOS_A_TRATAR_1 TBL
									WHERE 1=1
										--AND TBL.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)
										--AND TBL.PERMANENCIA = v_const_recibos_cartera_81
										--AND IFNULL(TRIM(TBL.CODIGO_UNICO_AGENTE),'0') = '0'
										--AND TBL.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrggpp
										
		;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBOS_A_TRATAR_2);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_A_TRATAR_2 creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
		
		--debug
	/*	DELETE FROM EXT.TBL_RECIBOS_A_TRATAR_2_DEBUG;
		INSERT INTO EXT.TBL_RECIBOS_A_TRATAR_2_DEBUG 
		SELECT * FROM :TBL_RECIBOS_A_TRATAR_2;*/
		
		--Actualización de RECIBOS NO validos con estado POPULATE_ERROR
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en STAGE_RECIBOS para RECIBOS NO validos y con clave duplicada - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
				END;
				
				UPDATE EXT.STAGE_RECIBOS x
				SET ESTADO = v_const_populate_status_error
					, FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE EXISTS(SELECT 1
							FROM :TBL_RECIBOS_A_TRATAR_2 src
							WHERE src.RECIBO_VALIDO = 0
								AND x.CODIGO_RECIBO = src.CODIGO_RECIBO
								AND x.CODIGO_POLIZA = src.CODIGO_POLIZA
								AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
								AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
								
							)
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en STAGE_RECIBOS para indicador RECIBO_VALIDO = 0. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		
		
		END;
		
		--HISTORIFICACION DE RECIBOS
		BEGIN
			
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
					
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en RECIBOS_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
				END;
		
			INSERT INTO EXT.RECIBOS_HIST
				SELECT i_id_proceso, REC.* 
				FROM EXT.RECIBOS REC
				INNER JOIN :TBL_RECIBOS_A_TRATAR_2 TBL_REC 
					ON REC.CODIGO_POLIZA = TBL_REC.CODIGO_POLIZA
						AND REC.CODIGO_RECIBO = TBL_REC.CODIGO_RECIBO
						AND REC.CODIGO_SUPLEMENTO = TBL_REC.CODIGO_SUPLEMENTO
						AND REC.ESTADO_RECIBO = TBL_REC.ESTADO_RECIBO
						AND TBL_REC.RECIBO_VALIDO = 1
				WHERE TBL_REC.FILE_NAME = i_file_name
					AND TBL_REC.ESTADO = v_const_stage_status_ok
			;
			
			v_num_rows := ::rowcount;
				
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en RECIBOS_HIST. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		
		END;
		
		
		BEGIN
			
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE de RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
				END;
			
			--MERGE en RECIBOS
			MERGE INTO EXT.RECIBOS REC
				USING (
					SELECT
						TBL.*
					FROM :TBL_RECIBOS_A_TRATAR_2 TBL
				) src
				ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
					AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
					AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
					AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
					AND src.RECIBO_VALIDO = 1
				WHEN MATCHED THEN UPDATE
					SET  REC.IDENTIFICADOR = src.IDENTIFICADOR
						, REC.FILE_NAME = src.FILE_NAME
						, REC.ESTADO = v_const_populate_status_ok
						, REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
						, REC.ZONA_EXPLOTACION = src.ZONA_EXPLOTACION
						, REC.CODIGO_AGENTE_ZONA = src.CODIGO_AGENTE_ZONA
						--, REC.CODIGO_POLIZA = src.CODIGO_POLIZA --ES CLAVE
						--, REC.CODIGO_RECIBO = src.CODIGO_RECIBO --ES CLAVE
						, REC.PERMANENCIA = src.PERMANENCIA
						, REC.TIPO_RECIBO = src.TIPO_RECIBO
						--, REC.ESTADO_RECIBO = src.ESTADO_RECIBO --ES CLAVE
						, REC.FECHA_COBRO = src.FECHA_COBRO
						/*, REC.FECHA_COMPENSACION = (CASE WHEN src.CARGO_COMPENSACION IS NULL 
														THEN REC.FECHA_COMPENSACION
														ELSE (CASE WHEN src.ESTADO_RECIBO = v_const_recibo_pendiente 
																	OR (src.ESTADO_RECIBO = v_const_recibo_emitido_sinfirmar AND SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') = v_const_cobros_solnet_ocaso)
																THEN ADD_MONTHS(src.CARGO_COMPENSACION,1)
																ELSE src.CARGO_COMPENSACION END) END)*/
						, REC.FECHA_COMPENSACION = src.FECHA_COMPENSACION
						, REC.FECHA_EFECTO_RECIBO = src.FECHA_EFECTO_RECIBO
						, REC.FECHA_VTO_RECIBO = src.FECHA_VENCIMIENTO_RECIBO
						, REC.TIPO_MOVIMIENTO = src.TIPO_MOVIMIENTO
						, REC.PORCENTAJE_DESCUENTO_SOBRE_PC = ROUND(src.PORC_DESTO_SOBREPC,4)
						, REC.VALOR_POLIZA = ROUND(src.VALOR_POLIZA,2)
						, REC.CODIGO_UNICO_AGENTE = src.CODIGO_UNICO_AGENTE
						, REC.CODIGO_AGENTE_ORIGINAL = src.CODIGO_AGENTE_ORIGINAL
						, REC.INSPECTOR = src.INSPECTOR
						, REC.OFICINA_COBRADORA = src.OFICINA_COBRADORA
						, REC.OFICINA_GESTORA = src.OFICINA_GESTORA
						, REC.MARCA_RECUPERADO = (CASE WHEN src.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)
															AND src.PERMANENCIA <> v_const_recibos_especificos_11
															AND src.MARCA_RECUPERADO <> 'XX'
														THEN NULL
														ELSE src.MARCA_RECUPERADO END)
						, REC.MARCA_CUENTA = v_const_s
						, REC.PRIMER_RECIBO = src.PRIMER_RECIBO
						, REC.ASEGURADOS_NETOS = NULL
						, REC.AUMENTO_ASEGURADOS = NULL
						, REC.EXCLUIDO_COMISIONES = src.EXCLUIDO_COMISIONES
						, REC.BONIFICACION_POLIZA = NULL
						, REC.DISMINUCION_PRIMA = NULL
						, REC.TIPO_RECUPERACION = (CASE WHEN src.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)
															AND src.PERMANENCIA <> v_const_recibos_especificos_11
															AND src.MARCA_RECUPERADO <> 'XX'
														THEN src.MARCA_RECUPERADO
														ELSE NULL END)
						, REC.ES_PERMANENCIA_20 = NULL
						, REC.CODIGO_AGENTE_COMMISSIONS = NULL
						, REC.FECHA_EMISION_REC = src.FECHA_EMISION_REC
						, REC.FCHA_EFECTO_SUPLEMENTO = src.FECHA_EFECTO_SUPLEMENTO
						--, REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO --ES CLAVE
						, REC.DISTRITO_COBRO = src.DISTRITO_COBRO
						, REC.CODIGO_SINIESTRO = src.CODIGO_SINIESTRO
				WHEN NOT MATCHED THEN INSERT 
				-- ITL cambiado orden columnas 
					VALUES (
						src.IDENTIFICADOR
						, src.FILE_NAME
						, v_const_populate_status_ok
						, CURRENT_TIMESTAMP
						, src.CODIGO_POLIZA
						, src.CODIGO_RECIBO
						, src.PERMANENCIA
						, src.TIPO_RECIBO
						, src.ESTADO_RECIBO
						, src.FECHA_COBRO
						/*, (CASE WHEN src.CARGO_COMPENSACION IS NULL 
							THEN NULL
							ELSE (CASE WHEN src.ESTADO_RECIBO = v_const_recibo_pendiente
										OR (src.ESTADO_RECIBO = v_const_recibo_emitido_sinfirmar AND SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') = v_const_cobros_solnet_ocaso)
									THEN ADD_MONTHS(src.CARGO_COMPENSACION,1)
									ELSE src.CARGO_COMPENSACION END) END) --FECHA_COMPENSACION*/
						, src.FECHA_COMPENSACION
						, src.FECHA_EFECTO_RECIBO
						, src.FECHA_VENCIMIENTO_RECIBO
						, src.TIPO_MOVIMIENTO
						, ROUND(src.PORC_DESTO_SOBREPC,4)
						, ROUND(src.VALOR_POLIZA,2)
						, src.CODIGO_UNICO_AGENTE
						, src.CODIGO_AGENTE_ORIGINAL
						, src.INSPECTOR
						, src.OFICINA_COBRADORA
						, src.OFICINA_GESTORA
						, (CASE WHEN src.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)
								AND src.PERMANENCIA <> v_const_recibos_especificos_11
								AND src.MARCA_RECUPERADO <> 'XX'
							THEN NULL
							ELSE src.MARCA_RECUPERADO END) --MARCA_RECUPERADO
						, v_const_s --MARCA_CUENTA
						, src.PRIMER_RECIBO
						, 0 --src.ASEGURADOS_NETOS
						, NULL --src.AUMENTO_ASEGURADOS
						, src.EXCLUIDO_COMISIONES
						, 0 --src.BONIFICACION_POLIZA
						, NULL --src.DISMINUCION_PRIMA
						, (CASE WHEN src.RAMO IN (v_const_ramo_rrgg, v_const_ramo_rrpp)
								AND src.PERMANENCIA <> v_const_recibos_especificos_11
								AND src.MARCA_RECUPERADO <> 'XX'
							THEN src.MARCA_RECUPERADO
							ELSE NULL END) -- TIPO_RECUPERACION
						, NULL --src.ES_PERMANENCIA_20
						, NULL --src.CODIGO_AGENTE_COMMISSIONS
						, src.FECHA_EMISION_REC
						, src.FECHA_EFECTO_SUPLEMENTO
						, src.CODIGO_SUPLEMENTO
						, src.DISTRITO_COBRO
						, src.CODIGO_SINIESTRO
						, src.ZONA_EXPLOTACION
						, src.CODIGO_AGENTE_ZONA
					)
				
			;
			
			v_num_rows := ::rowcount;
				
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
		END;
		
		--Actualización de MARCA_CUENTA 
		BEGIN
			
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE de RECIBOS MARCA_CUENTA - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);	
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
					
				END;
			
			
			--Actualización de MARCA_CUENTA a NO para recibos coincidentes dentro del mismo fichero y CODIGO_RECIBO = CONST_COD_RECIBO_ANUL_RRTT
			--Actualización de MARCA_CUENTA a NO para recibos de rehabilitación y oficina gestora distinta de la 900, 0900
			--Actualización de MARCA_CUENTA a NO para recibos 65 y fecha_rehabilitacion - fecha_baja < 365 días
			
			UPDATE EXT.RECIBOS x
			SET MARCA_CUENTA = v_const_n
				, FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_2 src
		    	WHERE x.CODIGO_RECIBO = src.CODIGO_RECIBO AND x.CODIGO_POLIZA = src.CODIGO_POLIZA AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
		    		AND ((x.CODIGO_RECIBO = v_const_cod_recibo_anul_rrtt AND src.ROW_NUM <> 1)
		    		OR ((src.PERMANENCIA = v_const_recibos_especificos_65 OR src.MOTIVO_ALTA = v_const_recu_recibo) AND src.OFICINA_GESTORA NOT IN (v_const_oficina_gestora_900,v_const_oficina_gestora_0900))
		    		OR ((src.PERMANENCIA = v_const_recibos_especificos_65 AND src.MOTIVO_ALTA IN (v_const_motivo_alta_re,v_const_motivo_alta_ro,v_const_motivo_alta_rh)) 
                		OR (src.PERMANENCIA = v_const_recibos_especificos_65 AND src.DIFERENCIA_FECHAS < v_const_365_dias)))
		    	
		    		/*AND NOT EXISTS (SELECT 1
		    						FROM :TBL_RECIBO_IND_BAJA 
		    						WHERE CODIGO_POLIZA = src.CODIGO_POLIZA)*/
		    		--AND x.MARCA_CUENTA = v_const_s
		    	;
		    	
		    v_num_rows := ::rowcount;
			
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE_1 MARCA_CUENTA a NO. Filas:' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
			/*									
			UPDATE EXT.RECIBOS x
			SET MARCA_CUENTA = v_const_n
				, FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_2 src
			WHERE NOT(src.CODIGO_RECIBO IN (v_const_cod_recibo_anul_rrggpp,v_const_cod_recibo_anul_rrtt)
				AND x.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				AND x.CODIGO_RECIBO NOT IN (SELECT REPLACE(REC1.CODIGO_RECIBO,'_A','')
											FROM EXT.RECIBOS REC1
											WHERE REC1.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
												AND (REC1.TIPO_RECIBO = v_const_tipo_rec_anul_k5 OR REC1.CODIGO_RECIBO LIKE '%_A' OR SUBSTRING(REC1.CODIGO_POLIZA,LENGTH(REC1.CODIGO_POLIZA),1) IN ('X','S'))
												AND REC1.MARCA_CUENTA = v_const_s
												AND REC1.FECHA_COMPENSACION > x.FECHA_COMPENSACION
											)
				AND (x.TIPO_RECIBO <> v_const_tipo_rec_anul_k5 OR (x.TIPO_RECIBO IS NULL AND SUBSTRING(x.CODIGO_POLIZA,LENGTH(x.CODIGO_POLIZA),1) IN ('X','S')))
				AND x.CODIGO_RECIBO NOT LIKE '%_A'
				AND x.CODIGO_RECIBO NOT IN (v_const_cod_recibo_anul_rrggpp,v_const_cod_recibo_anul_rrtt)
				AND (x.PERMANENCIA = v_const_recibos_especificos_71 OR x.PERMANENCIA IN (v_const_recibos_cartera_72, v_const_recibos_cartera_81))
				AND x.ESTADO_RECIBO = v_const_recibo_cobrado
				AND x.FECHA_COMPENSACION >= (SELECT IFNULL(MAX(REC2.FECHA_COMPENSACION),TO_DATE('19000101','YYYYMMDD'))
												FROM EXT.RECIBOS REC2
												WHERE REC2.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
													AND REC2.CODIGO_RECIBO IN (v_const_cod_recibo_anul_rrggpp,v_const_cod_recibo_anul_rrtt)
													AND REC2.MARCA_CUENTA = v_const_s
													AND REC2.ESTADO_RECIBO = v_const_recibo_cobrado
											)
				)
				AND x.MARCA_CUENTA = v_const_s
			;*/
			
			v_file_type = SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_');
			
			--Para RRTT se puede hacer igualdad por codigo de poliza en lugar de like substring(1,20)
			--		Se puede eliminar el OR de la constante K5 IFNULL(src.TIPO_RECIBO,'X') NOT LIKE :v_const_tipo_rec_anul_k5 || '%'
			--Para RRGG nos podemos cargar lo del CODIGO_RECIBO NOT LIKE '%_A'
			--Partimos en dos bloques, uno para tratar RRTT y otro para RRGGPP
			/*
			IF :v_file_type IN  (:v_const_emi_diario_rrtt_eterna,
								:v_const_emi_diario_rrtt_ocaso,
								:v_const_emi_diario_rrggrrpp_et,
								:v_const_emi_diario_rrggrrpp_ocaso,
								:v_const_emi_diario_solnet_ocaso
								) THEN
																	
				TBL_RECIBOS_ANULADOS = SELECT REPLACE(REC.CODIGO_RECIBO,'_A','') AS CODIGO_RECIBO
				    						, REC.CODIGO_POLIZA
				    						, REC.FECHA_COMPENSACION
										FROM EXT.RECIBOS REC INNER JOIN :TBL_RECIBOS_A_TRATAR_2 TBL ON TBL.CODIGO_POLIZA LIKE SUBSTR(REC.CODIGO_POLIZA,1,20) || '%'
										WHERE (REC.TIPO_RECIBO LIKE :v_const_tipo_rec_anul_k5 || '%'
				    						OR REC.CODIGO_RECIBO LIKE '%_A' 
				    						--OR SUBSTRING(REC.CODIGO_POLIZA,LENGTH(REC.CODIGO_POLIZA)-1,1) IN ('X','S'))
				    						OR RIGHT(REC.CODIGO_POLIZA,1) IN ('X','S'))
											AND REC.MARCA_CUENTA = :v_const_s
											AND REC.FILE_NAME <> :i_file_name;
											
				v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANULADOS);
		
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_ANULADOS creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
				
											
				TBL_RECIBOS_MAX_FECHA_COMPENSACION = SELECT IFNULL(MAX(REC.FECHA_COMPENSACION),TO_DATE('19000101','YYYYMMDD')) AS MAX_FECHA_COMPENSACION
														, REC.CODIGO_POLIZA
													FROM EXT.RECIBOS REC  INNER JOIN :TBL_RECIBOS_A_TRATAR_2 TBL ON TBL.CODIGO_POLIZA LIKE SUBSTR(REC.CODIGO_POLIZA,1,20) || '%'
													WHERE REC.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
														AND REC.MARCA_CUENTA = :v_const_s
														AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
														AND REC.FILE_NAME <> :i_file_name
													GROUP BY REC.CODIGO_POLIZA
													;
													
				v_num_rows = RECORD_COUNT(:TBL_RECIBOS_MAX_FECHA_COMPENSACION);
		
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_MAX_FECHA_COMPENSACION creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
				
				--Para RRTT se puede hacer igualdad por codigo de poliza en lugar de like substring(1,20)
				--		Se puede eliminar el OR de la constante K5 IFNULL(src.TIPO_RECIBO,'X') NOT LIKE :v_const_tipo_rec_anul_k5 || '%'
				--Para RRGG nos podemos cargar lo del CODIGO_RECIBO NOT LIKE '%_A'
				
				UPDATE EXT.RECIBOS x
				SET MARCA_CUENTA = :v_const_n,
				    FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE NOT EXISTS (
				    SELECT 1 FROM :TBL_RECIBOS_A_TRATAR_2 TBL
				    --SELECT 1 FROM EXT.RECIBOS src
				    INNER JOIN EXT.RECIBOS src ON TBL.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				    LEFT JOIN :TBL_RECIBOS_MAX_FECHA_COMPENSACION FC ON fc.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				   -- WHERE x.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				    WHERE x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				    AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				    AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				    AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				    AND src.MARCA_CUENTA = :v_const_s
				    --AND x.ESTADO_RECIBO = :v_const_recibo_cobrado
				    --AND x.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrggpp, :v_const_cod_recibo_anul_rrtt)
				    --AND x.PERMANENCIA IN (:v_const_recibos_especificos_71,:v_const_recibos_cartera_72, :v_const_recibos_cartera_81)
				    --AND (src.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' OR (src.TIPO_RECIBO IS NULL AND SUBSTRING(src.CODIGO_POLIZA,LENGTH(src.CODIGO_POLIZA)-1,1) NOT IN ('X','S')))
				    AND (src.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' OR (src.TIPO_RECIBO IS NULL AND RIGHT(src.CODIGO_POLIZA,1) NOT IN ('X','S')))
					AND src.CODIGO_RECIBO NOT LIKE '%_A'
					AND src.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
					AND src.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_cartera_72, :v_const_recibos_cartera_81, :v_const_recibos_especificos_11)
					AND src.ESTADO_RECIBO = :v_const_recibo_cobrado
				    AND NOT EXISTS (SELECT 1 FROM :TBL_RECIBOS_ANULADOS RA 
				                   WHERE RA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				                		AND RA.CODIGO_POLIZA LIKE SUBSTR(TBL.CODIGO_POLIZA,1,20) || '%'
				                		--AND RA.FECHA_COMPENSACION > src.FECHA_COMPENSACION)
				                		--AND RA.FECHA_COMPENSACION > (CASE WHEN TBL.CARGO_COMPENSACION IS NULL 
										--							THEN NULL
										--							ELSE (CASE WHEN TBL.ESTADO_RECIBO = v_const_recibo_pendiente
										--										OR (TBL.ESTADO_RECIBO = v_const_recibo_emitido_sinfirmar AND SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') = v_const_cobros_solnet_ocaso)
										--									THEN ADD_MONTHS(TBL.CARGO_COMPENSACION,1)
										--									ELSE TBL.CARGO_COMPENSACION END) END))
										AND RA.FECHA_COMPENSACION > TBL.FECHA_COMPENSACION)
				    AND (src.FECHA_COMPENSACION >= FC.MAX_FECHA_COMPENSACION OR FC.MAX_FECHA_COMPENSACION IS NULL)
					)
					AND x.FILE_NAME = :i_file_name
					AND x.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
					
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE_2 MARCA_CUENTA a NO. Filas:' || v_num_rows, i_log_count, i_id_proceso, 'info');
				
			ELSE 
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'No se realiza el UPDATE 2 de MARCA_CUENTA ya que no es fichero de emitido.', i_log_count, i_id_proceso, 'info');
			
			END IF;
			*/
			
			IF :v_file_type IN  (:v_const_emi_diario_rrtt_eterna,
								:v_const_emi_diario_rrtt_ocaso
								) THEN
																	
				TBL_RECIBOS_ANULADOS = SELECT REPLACE(REC.CODIGO_RECIBO,'_A','') AS CODIGO_RECIBO
				    						, REC.CODIGO_POLIZA
				    						, REC.FECHA_COMPENSACION
										FROM EXT.RECIBOS REC INNER JOIN :TBL_RECIBOS_A_TRATAR_2 TBL ON TBL.CODIGO_POLIZA = REC.CODIGO_POLIZA
										WHERE (REC.TIPO_RECIBO LIKE :v_const_tipo_rec_anul_k5 || '%'
				    						OR REC.CODIGO_RECIBO LIKE '%_A' )
				    						--OR SUBSTRING(REC.CODIGO_POLIZA,LENGTH(REC.CODIGO_POLIZA)-1,1) IN ('X','S'))
				    						--OR RIGHT(REC.CODIGO_POLIZA,1) IN ('X','S')) --solo afecta a RRGG
											AND REC.MARCA_CUENTA = :v_const_s
											AND REC.FILE_NAME <> :i_file_name
										;
											
				v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANULADOS);
		
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_ANULADOS RRTT creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
				
											
				TBL_RECIBOS_MAX_FECHA_COMPENSACION = SELECT IFNULL(MAX(REC.FECHA_COMPENSACION),TO_DATE('19000101','YYYYMMDD')) AS MAX_FECHA_COMPENSACION
														, REC.CODIGO_POLIZA
													FROM EXT.RECIBOS REC  INNER JOIN :TBL_RECIBOS_A_TRATAR_2 TBL ON TBL.CODIGO_POLIZA = REC.CODIGO_POLIZA
													WHERE REC.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrtt)
														AND REC.MARCA_CUENTA = :v_const_s
														AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
														AND REC.FILE_NAME <> :i_file_name
													GROUP BY REC.CODIGO_POLIZA
													;
													
				v_num_rows = RECORD_COUNT(:TBL_RECIBOS_MAX_FECHA_COMPENSACION);
		
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_MAX_FECHA_COMPENSACION RRTT creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
				
				--Para RRTT se puede hacer igualdad por codigo de poliza en lugar de like substring(1,20)
				--		Se puede eliminar el OR de la constante K5 IFNULL(src.TIPO_RECIBO,'X') NOT LIKE :v_const_tipo_rec_anul_k5 || '%'
				--Para RRGG nos podemos cargar lo del CODIGO_RECIBO NOT LIKE '%_A'
				
				UPDATE EXT.RECIBOS x
				SET MARCA_CUENTA = :v_const_n,
				    FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE NOT EXISTS (
				    SELECT 1 FROM :TBL_RECIBOS_A_TRATAR_2 TBL
				    --SELECT 1 FROM EXT.RECIBOS src
				    INNER JOIN EXT.RECIBOS src ON TBL.CODIGO_POLIZA = src.CODIGO_POLIZA
				    LEFT JOIN :TBL_RECIBOS_MAX_FECHA_COMPENSACION FC ON fc.CODIGO_POLIZA = src.CODIGO_POLIZA
				   -- WHERE x.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				    WHERE x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				    AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				    AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				    AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				    AND src.MARCA_CUENTA = :v_const_s
				    --AND x.ESTADO_RECIBO = :v_const_recibo_cobrado
				    --AND x.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrggpp, :v_const_cod_recibo_anul_rrtt)
				    --AND x.PERMANENCIA IN (:v_const_recibos_especificos_71,:v_const_recibos_cartera_72, :v_const_recibos_cartera_81)
				    --AND (src.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' OR (src.TIPO_RECIBO IS NULL AND SUBSTRING(src.CODIGO_POLIZA,LENGTH(src.CODIGO_POLIZA)-1,1) NOT IN ('X','S')))
				    AND IFNULL(src.TIPO_RECIBO,'X') NOT LIKE :v_const_tipo_rec_anul_k5 || '%'
					AND src.CODIGO_RECIBO NOT LIKE '%_A'
					AND src.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
					AND src.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_cartera_72, :v_const_recibos_cartera_81, :v_const_recibos_especificos_11)
					AND src.ESTADO_RECIBO = :v_const_recibo_cobrado
				    AND NOT EXISTS (SELECT 1 FROM :TBL_RECIBOS_ANULADOS RA 
				                   WHERE RA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				                		AND RA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				                		--AND RA.FECHA_COMPENSACION > src.FECHA_COMPENSACION)
				                		--AND RA.FECHA_COMPENSACION > (CASE WHEN TBL.CARGO_COMPENSACION IS NULL 
										--							THEN NULL
										--							ELSE (CASE WHEN TBL.ESTADO_RECIBO = v_const_recibo_pendiente
										--										OR (TBL.ESTADO_RECIBO = v_const_recibo_emitido_sinfirmar AND SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') = v_const_cobros_solnet_ocaso)
										--									THEN ADD_MONTHS(TBL.CARGO_COMPENSACION,1)
										--									ELSE TBL.CARGO_COMPENSACION END) END))
										AND RA.FECHA_COMPENSACION > TBL.FECHA_COMPENSACION)
				    AND (src.FECHA_COMPENSACION >= FC.MAX_FECHA_COMPENSACION OR FC.MAX_FECHA_COMPENSACION IS NULL)
					)
					AND x.FILE_NAME = :i_file_name
					AND x.CODIGO_RECIBO = :v_const_cod_recibo_anul_rrtt
					
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE_2 MARCA_CUENTA a NO para RRTT. Filas:' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
			END IF;
			
			IF :v_file_type IN  (:v_const_emi_diario_rrggrrpp_et,
								:v_const_emi_diario_rrggrrpp_ocaso,
								:v_const_emi_diario_solnet_ocaso
								) THEN
																	
				TBL_RECIBOS_ANULADOS = SELECT REC.CODIGO_RECIBO AS CODIGO_RECIBO
				    						, REC.CODIGO_POLIZA
				    						, REC.FECHA_COMPENSACION
										FROM EXT.RECIBOS REC INNER JOIN :TBL_RECIBOS_A_TRATAR_2 TBL ON TBL.CODIGO_POLIZA LIKE SUBSTR(REC.CODIGO_POLIZA,1,20) || '%'
										WHERE (REC.TIPO_RECIBO LIKE :v_const_tipo_rec_anul_k5 || '%'
				    						--OR REC.CODIGO_RECIBO LIKE '%_A'  --solo aplica a RRGGPP
				    						--OR SUBSTRING(REC.CODIGO_POLIZA,LENGTH(REC.CODIGO_POLIZA)-1,1) IN ('X','S'))
				    						OR RIGHT(REC.CODIGO_POLIZA,1) IN ('X','S'))
											AND REC.MARCA_CUENTA = :v_const_s
											AND REC.FILE_NAME <> :i_file_name;
											
				v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANULADOS);
		
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_ANULADOS creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
				
											
				TBL_RECIBOS_MAX_FECHA_COMPENSACION = SELECT IFNULL(MAX(REC.FECHA_COMPENSACION),TO_DATE('19000101','YYYYMMDD')) AS MAX_FECHA_COMPENSACION
														, REC.CODIGO_POLIZA
													FROM EXT.RECIBOS REC  INNER JOIN :TBL_RECIBOS_A_TRATAR_2 TBL ON TBL.CODIGO_POLIZA LIKE SUBSTR(REC.CODIGO_POLIZA,1,20) || '%'
													WHERE REC.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrggpp)
														AND REC.MARCA_CUENTA = :v_const_s
														AND REC.ESTADO_RECIBO = :v_const_recibo_cobrado
														AND REC.FILE_NAME <> :i_file_name
													GROUP BY REC.CODIGO_POLIZA
													;
													
				v_num_rows = RECORD_COUNT(:TBL_RECIBOS_MAX_FECHA_COMPENSACION);
		
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_MAX_FECHA_COMPENSACION creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
				
				--Para RRTT se puede hacer igualdad por codigo de poliza en lugar de like substring(1,20)
				--		Se puede eliminar el OR de la constante K5 IFNULL(src.TIPO_RECIBO,'X') NOT LIKE :v_const_tipo_rec_anul_k5 || '%'
				--Para RRGG nos podemos cargar lo del CODIGO_RECIBO NOT LIKE '%_A'
				
				UPDATE EXT.RECIBOS x
				SET MARCA_CUENTA = :v_const_n,
				    FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE NOT EXISTS (
				    SELECT 1 FROM :TBL_RECIBOS_A_TRATAR_2 TBL
				    --SELECT 1 FROM EXT.RECIBOS src
				    INNER JOIN EXT.RECIBOS src ON TBL.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				    LEFT JOIN :TBL_RECIBOS_MAX_FECHA_COMPENSACION FC ON fc.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				    WHERE x.CODIGO_POLIZA LIKE SUBSTR(src.CODIGO_POLIZA,1,20) || '%'
				    --WHERE x.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				    --AND x.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				    --AND x.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
				    --AND x.ESTADO_RECIBO = TBL.ESTADO_RECIBO
				    AND src.MARCA_CUENTA = :v_const_s
				    --AND x.ESTADO_RECIBO = :v_const_recibo_cobrado
				    --AND x.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrggpp, :v_const_cod_recibo_anul_rrtt)
				    --AND x.PERMANENCIA IN (:v_const_recibos_especificos_71,:v_const_recibos_cartera_72, :v_const_recibos_cartera_81)
				    --AND (src.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' OR (src.TIPO_RECIBO IS NULL AND SUBSTRING(src.CODIGO_POLIZA,LENGTH(src.CODIGO_POLIZA)-1,1) NOT IN ('X','S')))
				    AND (src.TIPO_RECIBO NOT LIKE :v_const_tipo_rec_anul_k5 || '%' OR (src.TIPO_RECIBO IS NULL AND RIGHT(src.CODIGO_POLIZA,1) NOT IN ('X','S')))
					--AND src.CODIGO_RECIBO NOT LIKE '%_A' --No aplica a RRGGPP
					AND src.CODIGO_RECIBO NOT IN (:v_const_cod_recibo_anul_rrggpp,:v_const_cod_recibo_anul_rrtt)
					AND src.PERMANENCIA IN (:v_const_recibos_especificos_71, :v_const_recibos_cartera_72, :v_const_recibos_cartera_81, :v_const_recibos_especificos_11)
					AND src.ESTADO_RECIBO = :v_const_recibo_cobrado
				    AND NOT EXISTS (SELECT 1 FROM :TBL_RECIBOS_ANULADOS RA 
				                   WHERE RA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
				                		AND RA.CODIGO_POLIZA LIKE SUBSTR(TBL.CODIGO_POLIZA,1,20) || '%'
				                		--AND RA.FECHA_COMPENSACION > src.FECHA_COMPENSACION)
				                		--AND RA.FECHA_COMPENSACION > (CASE WHEN TBL.CARGO_COMPENSACION IS NULL 
										--							THEN NULL
										--							ELSE (CASE WHEN TBL.ESTADO_RECIBO = v_const_recibo_pendiente
										--										OR (TBL.ESTADO_RECIBO = v_const_recibo_emitido_sinfirmar AND SUBSTR_BEFORE(SUBSTR_AFTER(i_file_name ,'RECI'),'_') = v_const_cobros_solnet_ocaso)
										--									THEN ADD_MONTHS(TBL.CARGO_COMPENSACION,1)
										--									ELSE TBL.CARGO_COMPENSACION END) END))
										AND RA.FECHA_COMPENSACION > TBL.FECHA_COMPENSACION)
				    AND (src.FECHA_COMPENSACION >= FC.MAX_FECHA_COMPENSACION OR FC.MAX_FECHA_COMPENSACION IS NULL)
					)
					AND x.FILE_NAME = :i_file_name
					AND x.CODIGO_RECIBO IN (:v_const_cod_recibo_anul_rrggpp)
					
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE_2 MARCA_CUENTA a NO para RRGGPP. Filas:' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
			END IF;
			
			IF :v_file_type IN  (:v_const_emi_diario_rrggrrpp_et,
								:v_const_emi_diario_rrggrrpp_ocaso,
								:v_const_emi_diario_solnet_ocaso
								) THEN
				--Ponemos MARCA_CUENTA = N a los K5 de RRGG para los que no se haya cobrado el recibo. Desde SOLNET no envían siempre el K5, por lo que se hace por código de póliza entero.
				--En algunos ficheros vienen tanto el Pendiente como el Cobrado por lo que se añade condición de que los ESTADO_RECIBO de amblas tablas sean C. 
				--Al usar un cursor (o cuando solo tenemos cobrado y no pendiente), no hay problema, pone el MARCA_CUENTA a N del cobrado, pero al hacerlo en bloque nunca entra por el NOT EXISTS, poniendo ambas a S
				UPDATE EXT.RECIBOS x
				SET MARCA_CUENTA = :v_const_n
					, FECHA_MODIFICACION = CURRENT_TIMESTAMP
				FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_2 src1
				--WHERE src.CODIGO_RECIBO IN (v_const_cod_recibo_anul_rrggpp,v_const_cod_recibo_anul_rrtt)
				WHERE src1.RAMO IN (:v_const_ramo_rrgg,:v_const_ramo_rrpp)
					--AND SUBSTRING(src1.CODIGO_POLIZA,LENGTH(src1.CODIGO_POLIZA),1) IN ('X','S')
					AND RIGHT(src1.CODIGO_POLIZA,1) IN ('X','S')
					AND NOT EXISTS(SELECT 1 FROM :TBL_RECIBOS_A_TRATAR_2 src2
						WHERE x.CODIGO_RECIBO = src2.CODIGO_RECIBO
						AND x.ESTADO_RECIBO = :v_const_recibo_cobrado
						AND src2.ESTADO_RECIBO = :v_const_recibo_cobrado
						AND x.CODIGO_POLIZA <> src2.CODIGO_POLIZA
						AND x.FECHA_COMPENSACION <= src2.CARGO_COMPENSACION
						AND x.CODIGO_POLIZA LIKE SUBSTR(src2.CODIGO_POLIZA,1,20) || '%'
					)
					AND x.MARCA_CUENTA = :v_const_s
					AND x.CODIGO_POLIZA LIKE SUBSTR(src1.CODIGO_POLIZA,1,20) || '%'
					AND x.CODIGO_RECIBO = src1.CODIGO_RECIBO
					AND x.CODIGO_SUPLEMENTO = src1.CODIGO_SUPLEMENTO
					AND x.ESTADO_RECIBO = :v_const_recibo_cobrado --Se añade la condición sólo para el Recibo Cobrado
					
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE_3 MARCA_CUENTA a NO para RRGGPP. Filas:' || v_num_rows, i_log_count, i_id_proceso, 'info');
				
			ELSE 
			
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'No se realiza el UPDATE 3 de MARCA_CUENTA ya que no es fichero de emitido RRGGPP.', i_log_count, i_id_proceso, 'info');
				
			END IF;
			
			--Hacemos una doble ordenación, un ROW_NUM particionado por póliza de la tabla de recibos a tratar limpio y un segundo ROW_NUM ordenando DESC el primer ROW_NUM
			--de esta manera tenemos el último recibo en el RN_DESC = 1, pudiendo actualizar el MARCA_CUENTA a S para las PERMANENCIAS 65 y las recuperaciones de RRGG y RRPP
			--TBL_RECIBOS_A_TRATAR_2_LIMPIO_AUX = SELECT TBL.*, ROW_NUMBER() OVER(PARTITION BY TBL.CODIGO_POLIZA) AS RN FROM :TBL_RECIBOS_A_TRATAR_2_LIMPIO TBL;
			TBL_RECIBOS_A_TRATAR_2_RN = SELECT TBL.*, ROW_NUMBER() OVER(PARTITION BY TBL.CODIGO_POLIZA ORDER BY ROW_NUM_POL DESC) AS RN_DESC 
										FROM :TBL_RECIBO_IND_REC_LIMPIO TBL
										WHERE TBL.PERMANENCIA = :v_const_recibos_especificos_65
											OR TBL.MOTIVO_ALTA = :v_const_recu_recibo;
		/*	
			TBL_RECIBOS_MIN = SELECT TBL.CODIGO_RECIBO
									, TBL.CODIGO_POLIZA
									, TBL.CODIGO_SUPLEMENTO
									, TBL.ESTADO_RECIBO
									, MIN(TBL.RN_DESC) AS MIN_RN_DESC
									FROM :TBL_RECIBOS_A_TRATAR_2_RN TBL
									WHERE (TBL.PERMANENCIA = :v_const_recibos_especificos_65 OR TBL.MOTIVO_ALTA = :v_const_recu_recibo)
									GROUP BY TBL.CODIGO_RECIBO, TBL.CODIGO_POLIZA, TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO
								;
		*/	
			UPDATE EXT.RECIBOS x
			SET MARCA_CUENTA = v_const_s
				, FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.RECIBOS x, :TBL_RECIBOS_A_TRATAR_2_RN src
		    	WHERE x.CODIGO_RECIBO = src.CODIGO_RECIBO AND x.CODIGO_POLIZA = src.CODIGO_POLIZA AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
		    		AND (src.PERMANENCIA = v_const_recibos_especificos_65 OR src.MOTIVO_ALTA = v_const_recu_recibo)--v_esRH_SN=SI
		    		AND src.RN_DESC = 1
		/*    		AND src.RN_DESC = (SELECT MIN(AUX.RN_DESC) 
		    							FROM :TBL_RECIBOS_A_TRATAR_2_RN AUX
		    							WHERE x.CODIGO_RECIBO = AUX.CODIGO_RECIBO AND x.CODIGO_POLIZA = AUX.CODIGO_POLIZA AND x.CODIGO_SUPLEMENTO = AUX.CODIGO_SUPLEMENTO AND x.ESTADO_RECIBO = AUX.ESTADO_RECIBO
		    								AND (AUX.PERMANENCIA = v_const_recibos_especificos_65 OR AUX.MOTIVO_ALTA = v_const_recu_recibo)
		    							)*/
		    ;
		 
		 /*
			UPDATE EXT.RECIBOS x
			SET MARCA_CUENTA = v_const_s
				, FECHA_MODIFICACION = CURRENT_TIMESTAMP
			WHERE EXISTS(SELECT 1
						FROM :TBL_RECIBOS_A_TRATAR_2_RN src
						INNER JOIN :TBL_RECIBOS_MIN m ON src.CODIGO_POLIZA = m.CODIGO_POLIZA
							AND src.CODIGO_RECIBO = m.CODIGO_RECIBO
							AND src.CODIGO_SUPLEMENTO = m.CODIGO_SUPLEMENTO
							AND src.ESTADO_RECIBO = m.ESTADO_RECIBO
							AND src.RN_DESC = m.MIN_RN_DESC
						WHERE x.CODIGO_POLIZA = src.CODIGO_POLIZA
							AND x.CODIGO_RECIBO = src.CODIGO_RECIBO
							AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
							AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
							AND (src.PERMANENCIA = v_const_recibos_especificos_65 OR src.MOTIVO_ALTA = v_const_recu_recibo)
						)
			;
		*/	
		    v_num_rows := ::rowcount;
			
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE_4 MARCA_CUENTA a SI para PERMANENCIA 65 o Recuperaciones de RRGG/RRPP. Filas:' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
		END;
		
		
		--Sacamos posibles duplicados la TBL_RECIBO_IND_REC por clave de garantia de recibo
        TBL_RECIBO_IND_GAR_REC_DUPL = SELECT COUNT(*)
									, CODIGO_POLIZA
									, CODIGO_RECIBO
									, CODIGO_SUPLEMENTO
									, ESTADO_RECIBO
									, PRODUCTO_CONTABLE
									, PERMANENCIA
								FROM :TBL_RECIBO_IND_REC
								WHERE ROW_NUM_GAR_REC = 1
									AND ESTADO = v_const_stage_status_ok
								GROUP BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PRODUCTO_CONTABLE, PERMANENCIA
								HAVING COUNT(*) > 1
								;
								
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_GAR_REC_DUPL);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_RECIBO_IND_GAR_REC_DUPL creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
							
		TBL_RECIBO_IND_GAR_REC_LIMPIO = SELECT * 
								FROM :TBL_RECIBO_IND_REC src
								WHERE NOT EXISTS(SELECT 1 
												FROM :TBL_RECIBO_IND_GAR_REC_DUPL dupl
												WHERE dupl.CODIGO_POLIZA = src.CODIGO_POLIZA
													AND dupl.CODIGO_RECIBO = src.CODIGO_RECIBO
													AND dupl.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
													AND dupl.ESTADO_RECIBO = src.ESTADO_RECIBO
													AND dupl.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
													AND dupl.PERMANENCIA = src.PERMANENCIA
								)
								AND src.ROW_NUM_GAR_REC = 1
								;
		
		v_num_rows = RECORD_COUNT(:TBL_RECIBO_IND_GAR_REC_LIMPIO);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_RECIBO_IND_GAR_REC_LIMPIO creada. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
		
		--Actualización de GARANTIAS_RECIBO con clave duplicada con estado POPULATE_ERROR
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en STAGE_RECIBOS para GARANTIAS_RECIBO con clave duplicada - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
				END;
				
				UPDATE EXT.STAGE_RECIBOS x
				SET ESTADO = v_const_populate_status_error
					, FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE EXISTS(SELECT 1
							FROM :TBL_RECIBO_IND_GAR_REC_DUPL src
							WHERE x.CODIGO_POLIZA = src.CODIGO_POLIZA
								AND x.CODIGO_RECIBO = src.CODIGO_RECIBO
								AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
								AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
								AND x.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
								AND x.PERMANENCIA = src.PERMANENCIA
							)
				;
				
				UPDATE EXT.STAGE_RECIBOS x
				SET ESTADO = v_const_populate_status_error
					, FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE EXISTS(SELECT 1
							FROM :TBL_RECIBO_IND_REC src
							WHERE x.CODIGO_POLIZA = src.CODIGO_POLIZA
								AND x.CODIGO_RECIBO = src.CODIGO_RECIBO
								AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
								AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
								AND x.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
								AND x.PERMANENCIA = src.PERMANENCIA
								AND src.ROW_NUM_GAR_REC <> 1
							)
				;
				
				v_num_rows := ::rowcount;
				
				CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en STAGE_RECIBOS para clave duplicada por GARANTIAS_RECIBO. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		
		
		END;
		
		--HISTORIFICACION DE GARANTIAS_RECIBO
		BEGIN
			
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en RECIBOS_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);	
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
				END;
		
			INSERT INTO EXT.GARANTIAS_RECIBO_HIST
			-- ITL cambiado orden columnas 
				SELECT i_id_proceso
					, GAR.IDENTIFICADOR
					, GAR.ID_RECIBO
					, GAR.FILE_NAME
					, GAR.ESTADO
					, GAR.FECHA_MODIFICACION
					, GAR.CODIGO_POLIZA
					, GAR.CODIGO_RECIBO
					, GAR.PRODUCTO_CONTABLE
					, GAR.ESTADO_RECIBO
					, GAR.PRIMA_NETA_RECIBO
					, GAR.PRIMA_BRUTA_RECIBO
					, GAR.RECARGO
					, GAR.PORCENTAJE_BONIFICACION
					, GAR.INCREMENTO_PRIMA_ANUAL
					, GAR.PRIMA_COMISIONABLE
					, GAR.UNIDAD_DE_POLIZA
					, GAR.MESES_COBRADOS
					, GAR.FECHA_ALTA_GAR_POL
					, GAR.FECHA_BAJA_GAR_POL
					, GAR.PORCENTAJE_NIVELADA
					, GAR.PERIODO_EXTORNABLE
					, GAR.INDICADOR_COMISION_CALCULADA
					, GAR.INDICADOR_PORCENTAJE_CALCULA 
					, GAR.PORCENTAJE_COMISION_CALCULAD
					, GAR.IMPORTE_COMISION
					, GAR.PRIMA_UNICA
					, GAR.NUM_ORDEN_MOVIMIENTO
					, GAR.AUMENTO_CAPITALES_GARANTIA
					, GAR.PRIMA_NETA_ANUALIZADA
					, GAR.PORC_COMISION_NP
					, GAR.PORC_COMISION_CONSERVACION
					, GAR.CODIGO_SUPLEMENTO
					, GAR.PORC_COMISION_COBRO
				FROM EXT.GARANTIAS_RECIBO GAR
				INNER JOIN :TBL_RECIBO_IND_GAR_REC_LIMPIO TBL_REC 
					ON GAR.CODIGO_POLIZA = TBL_REC.CODIGO_POLIZA
						AND GAR.CODIGO_RECIBO = TBL_REC.CODIGO_RECIBO
						AND GAR.CODIGO_SUPLEMENTO = TBL_REC.CODIGO_SUPLEMENTO
						AND GAR.ESTADO_RECIBO = TBL_REC.ESTADO_RECIBO
						AND GAR.PRODUCTO_CONTABLE = TBL_REC.PRODUCTO_CONTABLE
						AND TBL_REC.ROW_NUM_GAR_REC = 1
				WHERE TBL_REC.FILE_NAME = i_file_name
					AND TBL_REC.ESTADO = v_const_stage_status_ok
			;
			
			v_num_rows := ::rowcount;
				
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en GARANTIAS_RECIBO_HIST. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
		
		END;
		
		--TRATAR GARANTIAS_RECIBO
		BEGIN
		
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
					
				END;
		
				
				MERGE INTO EXT.GARANTIAS_RECIBO x
				USING (
						SELECT
							TBL.*
						FROM :TBL_RECIBO_IND_GAR_REC_LIMPIO TBL
					) src
					ON x.CODIGO_POLIZA = src.CODIGO_POLIZA
						AND x.CODIGO_RECIBO = src.CODIGO_RECIBO
						AND x.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
						AND x.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
						AND x.ESTADO_RECIBO = src.ESTADO_RECIBO
						AND src.ROW_NUM_GAR_REC = 1
					WHEN MATCHED THEN UPDATE
						SET  x.ID_RECIBO = src.IDENTIFICADOR
							, x.FILE_NAME = src.FILE_NAME
							, x.ESTADO = v_const_populate_status_ok
							, x.FECHA_MODIFICACION = CURRENT_TIMESTAMP
							, x.PORCENTAJE_COMISION_CALCULAD = ROUND(src.POR_COMI_CALCULADA * 100,2)
							, x.IMPORTE_COMISION = src.IMPORTE_COMISION
							, x.PRIMA_UNICA = src.PRIMA_UNICA
							, x.NUM_ORDEN_MOVIMIENTO = src.NUM_ORDEN_MOVIMIENTO
							, x.AUMENTO_CAPITALES_GARANTIA = src.AUMENTO_CAPITALES_GAR
							, x.PRIMA_NETA_ANUALIZADA = NULL
							, x.PORC_COMISION_NP = NULL
							, x.PORC_COMISION_CONSERVACION = NULL
							--, x.CODIGO_SUPLEMENTO --ES CLAVE
							, x.PORC_COMISION_COBRO = NULL
							--, x.CODIGO_POLIZA --ES CLAVE
							--, x.CODIGO_RECIBO --ES CLAVE
							, x.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
							--, x.ESTADO_RECIBO --ES CLAVE
							, x.PRIMA_NETA_RECIBO = ROUND(src.PRIMA_NETA_RECIBO,2)
							, x.PRIMA_BRUTA_RECIBO = ROUND(src.PRIMA_BRUTA_RECIBO,2)
							, x.RECARGO = ROUND(src.RECARGO,2)
							, x.PORCENTAJE_BONIFICACION = ROUND(src.PORCENTAJE_BONIFICACION,2)
							, x.INCREMENTO_PRIMA_ANUAL = ROUND(src.INCRE_PRIMA_ANUAL,2)
							, x.PRIMA_COMISIONABLE = 0
							, x.UNIDAD_DE_POLIZA = 0
							, x.MESES_COBRADOS = 0
							, x.FECHA_ALTA_GAR_POL = src.FECHA_ALTA_GAR_POL
							, x.FECHA_BAJA_GAR_POL = src.FECHA_BAJA_GAR_POL
							, x.PORCENTAJE_NIVELADA = NULL
							, x.PERIODO_EXTORNABLE = ''
							, x.INDICADOR_COMISION_CALCULADA = CASE WHEN src.IND_COMI_CALCULADA > 0 THEN '1' ELSE '0' END
							, x.INDICADOR_PORCENTAJE_CALCULA = CASE WHEN src.IND_POR_CALCULADO > 0 THEN '1' ELSE '0' END
					WHEN NOT MATCHED THEN INSERT
					-- ITL cambio orden columnas 
						VALUES	(src.IDENTIFICADOR
								, src.FILE_NAME
								, v_const_populate_status_ok
								, CURRENT_TIMESTAMP
								, src.CODIGO_POLIZA
								, src.CODIGO_RECIBO
								, src.PRODUCTO_CONTABLE
								, src.ESTADO_RECIBO
								, ROUND(src.PRIMA_NETA_RECIBO,2)
								, ROUND(src.PRIMA_BRUTA_RECIBO,2)
								, ROUND(src.RECARGO,2)
								, ROUND(src.PORCENTAJE_BONIFICACION,2)
								, ROUND(src.INCRE_PRIMA_ANUAL,2)
								, 0 --x.PRIMA_COMISIONABLE
								, 0 --x.UNIDAD_DE_POLIZA
								, 0 --x.MESES_COBRADOS
								, src.FECHA_ALTA_GAR_POL
								, src.FECHA_BAJA_GAR_POL
								, NULL --x.PORCENTAJE_NIVELADA
								, '' --x.PERIODO_EXTORNABLE
								, CASE WHEN src.IND_COMI_CALCULADA > 0 THEN '1' ELSE '0' END
								, CASE WHEN src.IND_POR_CALCULADO > 0 THEN '1' ELSE '0' END
								, ROUND(src.POR_COMI_CALCULADA * 100,2)
								, ROUND(src.IMPORTE_COMISION,2)
								, src.PRIMA_UNICA
								, src.NUM_ORDEN_MOVIMIENTO
								, src.AUMENTO_CAPITALES_GAR
								, NULL --x.PRIMA_NETA_ANUALIZADA
								, NULL --x.PORC_COMISION_NP
								, NULL --x.PORC_COMISION_CONSERVACION
								, src.CODIGO_SUPLEMENTO
								, NULL --x.PORC_COMISION_COBRO
						)
				;
				
			v_num_rows := ::rowcount;
				
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en GARANTIAS_RECIBO. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
				
		END;
		
		--ACTUALIZAR ESTADO EN STAGE_RECIBOS
		BEGIN
		
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
					ROLLBACK;
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE ESTADO en STAGE_RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
										
					
					CALL EXT.LIB_ERRORES:SP_MARCA_STAGE_RECIBOS_ERROR_FROM_POPULATE (i_file_name, i_id_proceso);
					
					COMMIT;
		
					--Captura el error y lo envía a xDL
					RESIGNAL;
					
					
				END;
				
			UPDATE EXT.STAGE_RECIBOS STG
				SET STG.ESTADO = v_const_populate_status_ok
				, STG.FECHA_MODIFICACION = CURRENT_TIMESTAMP
			FROM EXT.STAGE_RECIBOS STG, :TBL_RECIBOS_A_TRATAR_2 src
			WHERE 1=1
				AND src.RECIBO_VALIDO = 1
				AND STG.CODIGO_POLIZA = src.CODIGO_POLIZA
				AND STG.PERMANENCIA = src.PERMANENCIA
				AND STG.ESTADO = v_const_stage_status_ok
				AND STG.FILE_NAME = i_file_name
			;
			
			v_num_rows := ::rowcount;
				
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE ESTADO OK en STAGE_RECIBOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
			
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_populate_status_ok
				, END_DATE = CURRENT_TIMESTAMP
			WHERE 1 = 1
				AND STATUS = v_const_stage_status_ok
				AND FILE_NAME = i_file_name
			;
			
			SELECT COUNT(*) INTO v_num_rows
			FROM EXT.STAGE_RECIBOS
			WHERE 1 = 1
				AND ESTADO IN (v_const_populate_status_error)
				AND FILE_NAME = i_file_name
			;
			
			UPDATE EXT.IN_BATCH_CONTROL
			SET REJECTED_ROWS = v_num_rows
				, END_DATE = CURRENT_TIMESTAMP
			WHERE 1 = 1
				AND FILE_NAME = i_file_name
				AND ID_PROCESO = i_id_proceso
			;
			
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE IN_BATCH_CONTROL con estado POPULATE_OK', i_log_count, i_id_proceso, 'info');
				
		END;
		
	END;	
 
END
