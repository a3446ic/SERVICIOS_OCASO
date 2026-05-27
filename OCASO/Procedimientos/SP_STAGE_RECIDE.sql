CREATE PROCEDURE EXT.SP_STAGE_RECIDE ( OUT o_file_name VARCHAR(120), IN i_file_name VARCHAR(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez 
    | Company: Inycom
    | Initial Version Date: 05-Junio-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se realiza una llamada al interfaz de RECIDE de xDL pasando un nombre de fichero por parámetro 
    | Nombre fichero entrada - RECIDE_20250606_000000_OCASOMANUALE.txt
	|
	| Version: 0.1	RMF 20250605	Initial Version.
	|
    -----------------------------------------------------------------------
*/

BEGIN

	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_count_bucle INTEGER := 0;
	DECLARE v_timestamp VARCHAR(50) := TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
	
	--CONSTANTES DE ESTADO
	DECLARE v_const_prestage_status_load INT = EXT.LIB_CONSTANTES:CONST_PRESTAGE_STATUS_LOAD; --0
	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK; --1
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR; --3
	DECLARE v_const_de_agente_registrado INT :=	EXT.LIB_CONSTANTES:CONST_DE_AGENTE_REGISTRADO;-- 0
	DECLARE v_const_de_agente_insertado_stage INT := EXT.LIB_CONSTANTES:CONST_DE_AGENTE_INSERTADO_STAGE; --1
	DECLARE v_const_de_agente_insertado_batch INT := EXT.LIB_CONSTANTES:CONST_DE_AGENTE_INSERTADO_BATCH; -- 2
	DECLARE v_const_de_agente_email_enviado INT := EXT.LIB_CONSTANTES:CONST_DE_AGENTE_EMAIL_ENVIADO; --3
	
	--CONSTANTES DE RECIBO
	DECLARE v_const_recibos_cartera_81 VARCHAR(2)		:= EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_81;
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			--v_hayError := 1;
			v_num_rows := 0;
		
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_stage_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_idproceso;
				
			COMMIT;		
			RESIGNAL;
		END;
		
	BEGIN
	
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_idproceso, 'info');
		
		BEGIN AUTONOMOUS TRANSACTION 
			INSERT INTO EXT.IN_BATCH_CONTROL (ID_PROCESO, FILE_NAME, PROCEDURE_NAME, SOURCE_ROWS, STATUS, START_DATE)
			VALUES (:v_idproceso, :i_file_name, :proc_name, 0, :v_const_prestage_status_load, CURRENT_TIMESTAMP);
		
		END;
		
		
		--Cruce de STAGE_RECIBOS con DERECHOS_ECONOMICOS para regenerar recibos
		INSERT INTO EXT.STAGE_RECIBOS
	    SELECT
	    	:i_file_name AS FILE_NAME
	    	, :v_const_stage_status_ok AS ESTADO
	    	, CURRENT_TIMESTAMP AS FECHA_MODIFICACION
	    	, RAMO
	    	, CODIGO_POLIZA
	    	, MOTIVO_ALTA
	    	, FECHA_EFECTO_POLIZA
	    	, FECHA_EMISION_POLIZA
	    	, FECHA_CESION_POLIZA
	    	, MOTIVO_BAJA
	    	, FECHA_BAJA
	    	, FECHA_EFECTO_SUPLEMENTO
	    	, FECHA_VENCIMIENTO
	    	, FECHA_REHABILITACION
	    	, FORMA_PAGO
	    	, TIPO_CAMPANIA
	    	, CODIGO_AGENTE_ORIGINAL
	    	, CODIGO_UNICO_AGENTE
	    	, INSPECTOR
	    	, OFICINA_COBRADORA
	    	, OFICINA_GESTORA
	    	, SEGUNDA_RESIDENCIA
	    	, TARIFA
	    	, ZONA
	    	, CLAVE_RIESGO
	    	, CODIGO_SUPLEMENTO
	    	, DISTRITO_COBRO
	    	, MODALIDAD
	    	, DURACION
	    	, IND_COMI_CALCULADA
	    	, IND_POR_CALCULADO
	    	, POR_COMI_CALCULADA
	    	, IMPORTE_COMISION
	    	, CLAUSULA
	    	, AUMENTO_CAPITALES_GAR
	    	, SUSTITUCION_INCENDIOS
	    	, CODIGO_SINIESTRO
	    	, EXCLUIDO_COMISIONES
	        , TRASPASADA
	        , INCRE_PRIMA_ANUAL
	        , DTO_IMPT_SINIESTRALIDAD
	        , DTO_POR_PRIORITARIO
	        , RIESGO
	        , COLECTIVO
	        , AUTOLIQUIDA
	        , KILOMETROS
	        , PRIMER_RECIBO
	        , CODIGO_RECIBO
	        , PERMANENCIA
	        , TIPO_RECIBO
	        , ESTADO_RECIBO
	        , FECHA_COBRO
	        , FECHA_EFECTO_RECIBO
	        , FECHA_VENCIMIENTO_RECIBO
	        , TIPO_MOVIMIENTO
	        , PORC_DESTO_SOBREPC
	        , VALOR_POLIZA
	        , MARCA_RECUPERADO
	        , PRODUCTO_CONTABLE
	        , FECHA_ALTA_GAR_POL
	        , FECHA_BAJA_GAR_POL
	        , PRIMA_NETA_RECIBO
	        , PRIMA_BRUTA_RECIBO
	        , RECARGO
	        , PORCENTAJE_BONIFICACION 
	        , POLIZA_CON_AGENTE
	        , MOVILIDAD
	        , PRIMA_UNICA
	        , NUM_ORDEN_MOVIMIENTO
	        , FECHA_EMISION_REC
	        , A.FECHA_CARGO AS CARGO_COMPENSACION
	        , ZONA_EXPLOTACION
	        , CODIGO_AGENTE_ZONA
	    FROM EXT.STAGE_RECIBOS R
	    JOIN EXT.DERECHOS_ECONOMICOS_CONTROL_AGENTE A
	       ON R.CODIGO_UNICO_AGENTE = A.COD_AGENTE
	       AND CARGO_COMPENSACION = A.FECHA_CARGO
	       AND A.STATUS = :v_const_de_agente_registrado
	       --AND A.FILE_NAME = :i_file_name
	       AND A.FILE_NAME LIKE '%' || SUBSTR(:i_file_name,15)
	    WHERE PERMANENCIA = :v_const_recibos_cartera_81
	      AND NOT EXISTS (
	          SELECT 1
	          FROM EXT.RECIBOS REC
	          WHERE REC.CODIGO_POLIZA = R.CODIGO_POLIZA
	            AND REC.CODIGO_RECIBO = R.CODIGO_RECIBO
	            AND REC.ESTADO_RECIBO = R.ESTADO_RECIBO
	            AND REC.CODIGO_SUPLEMENTO = R.CODIGO_SUPLEMENTO
	      );
	      
	    v_num_rows := ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'INSERT en STAGE_RECIBOS para PERMANENCIA 81. Filas: '|| v_num_rows, v_log_count, v_idproceso, 'info');
	
		--Actualizamos los registros de DERECHOS_ECONOMICOS para marcarlos como tratados (STATUS OK)
		UPDATE EXT.DERECHOS_ECONOMICOS_CONTROL_AGENTE
		SET STATUS = :v_const_de_agente_insertado_batch
			, FECHA_MODIFICACION = CURRENT_TIMESTAMP
    	WHERE STATUS = :v_const_de_agente_registrado
    		AND FILE_NAME = :i_file_name;
		
		v_num_rows := ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'UPDATE STATUS OK en DERECHOS_ECONOMICOS_CONTROL_AGENTE. Filas: '|| v_num_rows, v_log_count, v_idproceso, 'info');
		
		--Actualizamos la IN_BATCH_CONTROL y ponemos el estado a 1
		UPDATE EXT.IN_BATCH_CONTROL 
		SET STATUS = :v_const_stage_status_ok
			, SOURCE_ROWS = :v_num_rows
			, END_DATE = CURRENT_TIMESTAMP 
		WHERE FILE_NAME = :i_file_name 
			AND ID_PROCESO = v_idproceso;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,proc_name, 'Llamada a SP_POPULATE_EMITIDO para ' || :i_file_name, v_log_count, v_idproceso, 'info');
		
		CALL EXT.SP_POPULATE_EMITIDO(:i_file_name,v_idproceso, v_log_count);
	
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || :i_file_name, v_log_count, v_idproceso, 'info');
		
	
	END;
	
END
