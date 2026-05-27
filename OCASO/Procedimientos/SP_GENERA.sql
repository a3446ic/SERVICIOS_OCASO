CREATE OR REPLACE PROCEDURE EXT.SP_GENERA ( OUT o_file_name VARCHAR(120), IN i_file_name VARCHAR(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Jorge Gracia 
    | Company: Inycom
    | Initial Version Date: 01-Abril-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se sube un fichero para 
    | Nombre fichero entrada - CARGA_ABLFTP162702P_20241219_214036_1wio5.txt
	|
	| Version:	0.1	JGE 20250401	Initial Version.
    |           0.2 BRG 20250822    Solucion de errores
	|			1.0	RMF	20250926	Se incluyen bloques de manejo de excepciones y rollback del c�digo
	|			1.1 BRG 20251006	Revisi�n de creaci�n de POSITIONNAME y v_existe_positionname
	|			1.2 RMF	20251105	Modificaci�n en la extracci�n de la variable fecha_compensacion cuando llega un fichero de DDEE (RECDE)
	|			1.3 TGV 20260224	Control para el bucle infinito de la actualizacion de manager en los agentes tipo 15  
	|
    -----------------------------------------------------------------------
*/

BEGIN
		USING SQLSCRIPT_STRING AS LIBRARY;
	
		DECLARE v_idproceso BIGINT := 0;
		DECLARE v_log_count INTEGER := 0;
		DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
		DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
		DECLARE v_version VARCHAR2(10) := '1.3';
		DECLARE v_num_rows INTEGER := 0;
		DECLARE CONST_NO_ENCONTRADO VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_NO_ENCONTRADO; 
		DECLARE CONST_S VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S;
		DECLARE CONST_RECIBO_EXTORNO VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EXTORNO;
		DECLARE CONST_RECIBO_COBRADO VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO; ----C
		DECLARE CONST_RECIBO_EMITIDO VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EMITIDO; ----E
		DECLARE CONST_RECIBO_COBRADO_SINFIRMAR VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO_SINFIRMAR; --- N
		DECLARE CONST_RECIBO_EMITIDO_SINFIRMAR  VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_EMITIDO_SINFIRMAR; -----S
		DECLARE CONST_RECIBO_PENDIENTE VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_PENDIENTE; --- P
		
		DECLARE CONST_RAMA_RRGG VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRGG;
		DECLARE CONST_RAMA_RRPP VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRPP;
		DECLARE CONST_COD_RECIBO_ANUL_RRGGPP VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRGGPP;
		DECLARE CONST_RAMA_RRTT VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRTT;
		
		DECLARE CONST_RECIBOS_ESPECIFICOS_10 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_10;
		DECLARE CONST_RECIBOS_ESPECIFICOS_20 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_20;
		DECLARE CONST_RECIBOS_ESPECIFICOS_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
		DECLARE CONST_RECIBOS_ESPECIFICOS_16 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_16;
		DECLARE CONST_RECIBOS_ESPECIFICOS_55 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_55;
		DECLARE CONST_RECIBOS_ESPECIFICOS_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
		DECLARE CONST_RECIBOS_ESPECIFICOS_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
		DECLARE CONST_RECIBOS_CARTERA_81 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_81;
		DECLARE CONST_RECIBOS_CARTERA_72 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_72;
		
		DECLARE CONST_TIPO_REC_ANUL_K5 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_ANUL_K5;
		DECLARE CONST_COD_RECIBO_ANUL_RRTT VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRTT;
		DECLARE CONST_SUBLINE_RRGGRRPP VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_SUBLINE_RRGGRRPP;
		DECLARE CONST_MOTIVO_ALTA_DE VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_DE;
		DECLARE CONST_TIPO_EURO VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_EURO;
		DECLARE CONST_TIPO_QUANTITY VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_QUANTITY;
		DECLARE CONST_TIPO_PERCENTAGE VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_PERCENTAGE;
		DECLARE CONST_TIPO_ESP VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_ESP;
		
		DECLARE CONST_CAMPANIA_CRUZADA VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_CAMPANIA_CRUZADA;
		DECLARE CONST_MOVILIDAD_MOV VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_MOVILIDAD_MOV; 
		DECLARE CONST_SI VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_SI;
		DECLARE CONST_NO VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_NO;
		
		DECLARE CONST_TIPO_INTEGER VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_INTEGER;
		DECLARE CONST_COBROS_RRGGRRPP_OCASO VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGGRRPP_OCASO;
		DECLARE CONST_COBROS_RRGGRRPP_ETERNA VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGGRRPP_ETERNA;
		DECLARE CONST_COBROS_SOLNET_OCASO VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_COBROS_SOLNET_OCASO;
		DECLARE CONST_COD_RECIBO_ANUL_SERCO VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_SERCO;
		DECLARE CONST_EMI_DIARIO_RRTT_OCASO VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_OCASO;
		DECLARE CONST_EMI_DIARIO_RRTT_ETERNA VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_ETERNA;
		DECLARE CONST_EMI_DIARIO_RRGGRRPP_OC VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_OC;
		DECLARE CONST_EMI_DIARIO_RRGGRRPP_ET VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_ET;


		DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
		DECLARE v_fecha_compensacion DATE;

		
		DECLARE v_const_genera_status_error	INT := EXT.LIB_CONSTANTES:CONST_GENERA_TRX_STATUS_ERROR;--5
		DECLARE v_const_genera_status_ok INT := EXT.LIB_CONSTANTES:CONST_GENERA_TRX_STATUS_OK; --9
		DECLARE v_const_calculo_status_ok INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_OK; --6
		DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK;--2
		
		DECLARE v_batchname VARCHAR(255) := '';
		DECLARE v_tenantid VARCHAR(4) := '';
		DECLARE v_count_bucle INTEGER := 0;
		DECLARE v_status INTEGER := 0;
		DECLARE v_vueltas INTEGER := 1;
		
		DECLARE v_existe_tabla INTEGER := 0;

		
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
		
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																												
			--v_hayError := 1;
			v_num_rows := 0;
		
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = :v_const_genera_status_error,
			END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = :i_file_name
			AND STATUS = :v_const_calculo_status_ok
			;
			
			UPDATE EXT.GARANTIAS_RECIBO
			SET ESTADO = :v_const_genera_status_error,
			FECHA_MODIFICACION = CURRENT_TIMESTAMP
			WHERE FILE_NAME = :i_file_name
			AND ESTADO = :v_const_calculo_status_ok
			;
			
			UPDATE EXT.RECIBOS
			SET ESTADO = :v_const_genera_status_error,
			FECHA_MODIFICACION = CURRENT_TIMESTAMP
			WHERE FILE_NAME = :i_file_name
			AND ESTADO = :v_const_calculo_status_ok
			;
				
			commit;	
			RESIGNAL;
		
		END;
	
	BEGIN
	
	--Inicializamos el idProceso
	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_idproceso, 'info');
		
	--Nombre de fichero de salida
	-- o_file_name = 'OUT_CARGA_'||TO_VARCHAR(CURRENT_TIMESTAMP,'YYYYMMDD_HH24MISS')||'.txt';
		
	--Se comprueba estado del fichero
	SELECT STATUS INTO v_status FROM EXT.IN_BATCH_CONTROL WHERE FILE_NAME = :i_file_name ORDER BY START_DATE DESC LIMIT 1;
	
	IF (v_status <> v_const_calculo_status_ok) THEN
		SIGNAL SQL_ERROR_CODE 10001
    	SET MESSAGE_TEXT = 'Estado inv�lido: ' || :v_status;
    ELSE 
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Estado IN_BATCH_CONTROL correcto' , v_log_count, v_idproceso, 'info');
	END IF;
		
	--Comprobar que el parametro de entrada es correcto	
	IF TRIM(i_file_name) IS NULL THEN
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Parametros entrada incorrectos' , v_log_count, v_idproceso, 'info');
	END IF;
	
	-- SELECT max(R.FECHA_COMPENSACION) INTO v_fecha_compensacion 
	-- FROM EXT.RECIBOS R 
	-- WHERE R.FILE_NAME = :i_file_name 
	-- -- GROUP BY R.FECHA_COMPENSACION
	-- ;
	
	--20251105 RMF: Se a�ade condici�n para ficheros de DDEE (RECDE)
	--v_fecha_compensacion := substr(SUBSTR_AFTER(:i_file_name,'_'),1,8);
	IF(:i_file_name LIKE 'RECDE%') THEN
		v_fecha_compensacion := substr_before(substr_after(substr_after(:i_file_name,'_'),'_'),'_');
	ELSE
		v_fecha_compensacion := substr(SUBSTR_AFTER(:i_file_name,'_'),1,8);
	END IF;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'FECHA DE COMPENSACION: ' || v_fecha_compensacion, v_log_count, v_idproceso, 'info');
	--se rellena la variable batchname una vez en toda la ejecucion
	--v_batchname := EXT.LIB_GLOBAL:genera_batchname(i_file_name);
	
	--se rellena la variable tenantid una vez en toda la ejecucion
	SELECT DISTINCT TENANTID INTO v_tenantid FROM TCMP.CS_TENANT;
	
	--Guardamos en una variable tabla informaci�n sobre jerarqu�a
	TBL_GEN_CODIGOS_AGENTE = SELECT * FROM EXT.VW_CODIGOS_DE_AGENTE VW
							WHERE 1=1
								AND VW.CODIGO_OCASO <> '0' 
								AND VW.CODIGO_OCASO <> '000000000' 
								AND VW.CODIGO_OCASO <> '0000000000'
							;
							
	v_num_rows = RECORD_COUNT(:TBL_GEN_CODIGOS_AGENTE);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'tabla agentes creada. Filas: ' || v_num_rows || ' filas' , v_log_count, v_idproceso, 'info');
	
	--Creamos una tabla para guardar la informacion de si es permanencia 20 para cada una de las oficinas
	lt_ofic_cob_per_20 = 
	    SELECT
	    	pos.genericattribute3 AS OFI_COBRADORA,
	        'S' AS REC_OFI_PERMANENCIA_20,
	        pos.effectivestartdate AS FECHA_EFEC_DESDE,
	        pos.effectiveenddate   AS FECHA_EFEC_HASTA
	    FROM TCMP.cs_position AS pos
	    WHERE pos.removedate = TO_DATE('22000101', 'yyyymmdd')
	      AND pos.genericnumber2 = 100
	      AND pos.titleseq <> 5629499534213290
		-- BRG 20250822 Anyadimos casos Corte Ingles
		UNION ALL
		SELECT '0940', 'S', TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy
		UNION ALL
		SELECT '0946', 'S', TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy;
	      
	v_num_rows = RECORD_COUNT(:lt_ofic_cob_per_20);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'tabla oficinas permanencia 20 creada. Filas: ' || v_num_rows || ' filas' , v_log_count, v_idproceso, 'info');
	
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'INICIO TRATAMIENTO VISTA'  , v_log_count, v_idproceso, 'info');
	--empezamos a extraer los datos que vamos a insertar en la transaccion
	TBL_C_TXN = (
		SELECT
			POL.RAMO,
			SUBSTR(TO_VARCHAR(REPLACE(REC.FECHA_COMPENSACION,'-','')),1,6) AS LINE,
			SUBSTR (POL.CODIGO_POLIZA, 1, 2) AS CIA,
            SUBSTR (POL.CODIGO_POLIZA, 8) AS CODIGO_POLIZA_I,
            REC.FECHA_MODIFICACION,
            POL.CODIGO_POLIZA,
            POL.MOTIVO_ALTA,
            POL.FECHA_EFECTO_POLIZA,
            POL.FECHA_EMISION_POLIZA,
            POL.FECHA_CESION_POLIZA,
            REC.FCHA_EFECTO_SUPLEMENTO,
            POL.FECHA_VENCIMIENTO,
            POL.MOTIVO_BAJA,
            POL.FECHA_BAJA,
            POL.FORMA_PAGO,                                               
            POL.TIPO_CAMPANIA,
            POL.SEGUNDA_RESIDENCIA,
            POL.TARIFA,
            POL.ZONA,
            POL.CLAVE_RIESGO,
            REC.CODIGO_SUPLEMENTO,
            REC.DISTRITO_COBRO,
            POL.MODALIDAD,
            POL.DURACION,
            POL.CLAUSULA,
            POL.SUSTITUCION_INCENDIOS,                        
            POL.TRASPASADA,
            POL.DESCUENTO_IMPORTE_SINIESTRALID,
            POL.DESCUENTO_POR_PRIORITARIO,
            POL.RIESGO,
            POL.COLECTIVO,    
            POL.AUTOLIQUIDA,                                                      
            POL.KILOMETROS,
            POL.POLIZA_CON_AGENTE,           
            POL.MOVILIDAD, 
            REC.CODIGO_RECIBO,
            REC.TIPO_RECIBO,
            REC.ES_PERMANENCIA_20,                        
            REC.PERMANENCIA,                        
            REC.ESTADO_RECIBO,
            (CASE WHEN UPPER(REC.ESTADO_RECIBO) = CONST_RECIBO_EXTORNO THEN CONST_RECIBO_COBRADO ELSE REC.ESTADO_RECIBO END) AS ESTADO_RECIBO_DEF,
            REC.FECHA_COBRO,
            REC.FECHA_COMPENSACION,
            REC.FECHA_EMISION_REC,
            REC.FECHA_EFECTO_RECIBO,
            REC.FECHA_VTO_RECIBO,
            REC.TIPO_MOVIMIENTO,
            REC.PORCENTAJE_DESCUENTO_SOBRE_PC,
            REC.VALOR_POLIZA,
            (CASE WHEN REC.CODIGO_UNICO_AGENTE = :CONST_NO_ENCONTRADO THEN '0' ELSE REC.CODIGO_UNICO_AGENTE END) AS CODIGO_UNICO_AGENTE,                       
            REC.CODIGO_AGENTE_ORIGINAL,                       
            (CASE WHEN REC.INSPECTOR = :CONST_NO_ENCONTRADO THEN '0' ELSE REC.INSPECTOR END) AS INSPECTOR,
            REC.CODIGO_AGENTE_COMMISSIONS,
            REC.OFICINA_COBRADORA,
            REC.OFICINA_GESTORA,   
            REC.PRIMER_RECIBO,                                           
            REC.BONIFICACION_POLIZA,
            REC.DISMINUCION_PRIMA,
            REC.ASEGURADOS_NETOS   AS ASEGURADOS_NETOS_ORI,
            REC.CODIGO_SINIESTRO,
            REC.TIPO_RECUPERACION,
            REC.MARCA_CUENTA,             --Anadimos el campo MARCA_CUENTA. Lo necesitamos para no generar las transacciones 65 con MARCA_CUENTA = 'N'
            REC.MARCA_RECUPERADO,
            REC.FILE_NAME,
            REC.CODIGO_AGENTE_ZONA
		FROM 
			EXT.RECIBOS REC,
			EXT.POLIZAS POL
		WHERE
			POL.CODIGO_POLIZA = REC.CODIGO_POLIZA
			AND (REC.MARCA_CUENTA = CONST_S OR REC.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_65)
			AND REC.FILE_NAME = :i_file_name
			AND REC.PERMANENCIA <> '0'
			AND REC.ESTADO = :v_const_calculo_status_ok
			--JGE 20250925 David Rubio que nos ha dicho que no hacen falta de momento
			AND REC.PERMANENCIA NOT IN ('A','B')
		ORDER BY POL.CODIGO_POLIZA, REC.CODIGO_RECIBO, REC.ESTADO_RECIBO
	);
	
	v_num_rows = RECORD_COUNT(:TBL_C_TXN);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Insert TBL_C_TXN: ' || v_num_rows || ' filas'  , v_log_count, v_idproceso, 'info');
	--extraemos mas datos para usar en las transacciones
	TBL_C_TXN_GR = (
		SELECT
			C_TNX.*,
			GAR_REC.PRODUCTO_CONTABLE AS CODIGO_PRODUCTO,
            GAR_REC.PRIMA_NETA_RECIBO,
            GAR_REC.PRIMA_BRUTA_RECIBO,
            GAR_REC.RECARGO,
            GAR_REC.PORCENTAJE_BONIFICACION,
            GAR_REC.INCREMENTO_PRIMA_ANUAL,
            GAR_REC.UNIDAD_DE_POLIZA,
            GAR_REC.PORCENTAJE_NIVELADA,
            GAR_REC.PERIODO_EXTORNABLE,                                
            GAR_REC.PORCENTAJE_COMISION_CALCULAD,
            GAR_REC.IMPORTE_COMISION,
            GAR_REC.PRIMA_UNICA,
            GAR_REC.NUM_ORDEN_MOVIMIENTO,                                                                
            SUBSTR(GAR_REC.INDICADOR_PORCENTAJE_CALCULA,1,1) AS INDICADOR_PORCENTAJE_CALCULA,
            SUBSTR(GAR_REC.INDICADOR_COMISION_CALCULADA,1,1) AS INDICADOR_COMISION_CALCULADA,
            GAR_REC.PRIMA_COMISIONABLE,
            GAR_REC.AUMENTO_CAPITALES_GARANTIA                                                              
        FROM EXT.GARANTIAS_RECIBO GAR_REC
        INNER JOIN :TBL_C_TXN C_TNX
        ON GAR_REC.CODIGO_POLIZA = C_TNX.CODIGO_POLIZA
        	AND GAR_REC.CODIGO_RECIBO = C_TNX.CODIGO_RECIBO
        	AND GAR_REC.ESTADO_RECIBO = C_TNX.ESTADO_RECIBO
        	AND GAR_REC.CODIGO_SUPLEMENTO = C_TNX.CODIGO_SUPLEMENTO
        ORDER BY GAR_REC.PRODUCTO_CONTABLE 
	);
	
	v_num_rows = RECORD_COUNT(:TBL_C_TXN_GR);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Insert TBL_C_TXN_GR: ' || v_num_rows || ' filas'  , v_log_count, v_idproceso, 'info');

	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN = SELECT * FROM :TBL_C_TXN WHERE 1=0;

	--Para poder calcular todos los campos de la transaccion sin sobrecargar de subconsultas los inserts, calculamos algunos de los campos de la txn previamente 	
	TBL_C_TXN_CALCULADO = (
		SELECT 
			C_TNX.*,
			CASE 
		        WHEN C_TNX.RAMO IN (CONST_RAMA_RRGG, CONST_RAMA_RRPP) THEN
		            CASE 
		                WHEN C_TNX.CODIGO_RECIBO NOT IN (CONST_COD_RECIBO_ANUL_RRGGPP, CONST_COD_RECIBO_ANUL_SERCO) 
		                    THEN C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8,17) || IFNULL(C_TNX.CODIGO_SINIESTRO, '')
		                ELSE C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8,17)
		            END
		
		        WHEN C_TNX.RAMO = CONST_RAMA_RRTT AND C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		            AND UPPER(C_TNX.TIPO_RECIBO) = CONST_TIPO_REC_ANUL_K5 
		            THEN SUBSTR(C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8),1,23) || ' ' || 
		                 CASE 
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		                         THEN C_TNX.OFICINA_COBRADORA
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81, 
		                                                CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_66, 
		                                                CONST_RECIBOS_ESPECIFICOS_65) 
		                         THEN C_TNX.OFICINA_GESTORA
		                     ELSE IFNULL(C_TNX.OFICINA_GESTORA,'') --'NULL'
		                 END 
		                 || C_TNX.CODIGO_RECIBO || '1'
		
		        WHEN C_TNX.RAMO = CONST_RAMA_RRTT AND C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		            THEN CASE 
		                WHEN UPPER(C_TNX.ESTADO_RECIBO) = CONST_RECIBO_EXTORNO 
		                    THEN SUBSTR(C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8),1,23) || ' ' || 
		                         CASE 
		                             WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		                                 THEN C_TNX.OFICINA_COBRADORA
		                             WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81, 
		                                                        CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_66, 
		                                                        CONST_RECIBOS_ESPECIFICOS_65) 
		                                 THEN C_TNX.OFICINA_GESTORA
		                             ELSE IFNULL(C_TNX.OFICINA_GESTORA,'') --'NULL'
		                         END 
		                         || C_TNX.CODIGO_RECIBO || '2'
		                ELSE SUBSTR(C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8),1,23) || ' ' || 
		                     CASE 
		                         WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		                             THEN C_TNX.OFICINA_COBRADORA
		                         WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81, 
		                                                    CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_66, 
		                                                    CONST_RECIBOS_ESPECIFICOS_65) 
		                             THEN C_TNX.OFICINA_GESTORA
		                         ELSE IFNULL(C_TNX.OFICINA_GESTORA,'') --'NULL'
		                     END 
		                     || C_TNX.CODIGO_RECIBO
		            END
		
		        WHEN C_TNX.RAMO = CONST_RAMA_RRTT AND C_TNX.PERMANENCIA NOT IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		            AND UPPER(C_TNX.TIPO_RECIBO) = CONST_TIPO_REC_ANUL_K5 
		            THEN SUBSTR(C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8),1,23) || ' ' || 
		                 CASE 
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		                         THEN C_TNX.OFICINA_COBRADORA
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81, 
		                                                CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_66, 
		                                                CONST_RECIBOS_ESPECIFICOS_65) 
		                         THEN C_TNX.OFICINA_GESTORA
		                     ELSE IFNULL(C_TNX.OFICINA_GESTORA,'') --'NULL'
		                 END 
		                 || C_TNX.CODIGO_RECIBO || '1'
		
		        WHEN SUBSTR(C_TNX.CODIGO_RECIBO,LENGTH(C_TNX.CODIGO_RECIBO)-1,2) = '_A' 
		            THEN SUBSTR(C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8),1,23) || ' ' || 
		                 CASE 
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		                         THEN C_TNX.OFICINA_COBRADORA
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81, 
		                                                CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_66, 
		                                                CONST_RECIBOS_ESPECIFICOS_65) 
		                         THEN C_TNX.OFICINA_GESTORA
		                     ELSE IFNULL(C_TNX.OFICINA_GESTORA,'') --'NULL'
		                 END 
		                 || SUBSTR(C_TNX.CODIGO_RECIBO,1,11) || 'A'
		
		        WHEN C_TNX.PERMANENCIA = '11' 
		            THEN SUBSTR(C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8),1,23) || ' ' || 
		                 CASE 
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		                         THEN C_TNX.OFICINA_COBRADORA
		                     WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81, 
		                                                CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_66, 
		                                                CONST_RECIBOS_ESPECIFICOS_65) 
		                         THEN C_TNX.OFICINA_GESTORA
		                     ELSE IFNULL(C_TNX.OFICINA_GESTORA,'') --'NULL'
		                 END 
		                 || SUBSTR(C_TNX.CODIGO_RECIBO,1,10-LENGTH(C_TNX.CODIGO_SUPLEMENTO)) || C_TNX.CODIGO_SUPLEMENTO || 'X'
		
		        ELSE 
		            SUBSTR(C_TNX.CODIGO_PRODUCTO || SUBSTR(C_TNX.CODIGO_POLIZA,8),1,23) || ' ' || 
		            CASE 
		                WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) 
		                    THEN C_TNX.OFICINA_COBRADORA
		                WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81, 
		                                           CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_66, 
		                                           CONST_RECIBOS_ESPECIFICOS_65) 
		                    THEN C_TNX.OFICINA_GESTORA
		                ELSE IFNULL(C_TNX.OFICINA_GESTORA,'') --'NULL'
		            END 
		            || C_TNX.CODIGO_RECIBO
		    END AS ORDERID,
			CASE
			    WHEN C_TNX.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP, CONST_COD_RECIBO_ANUL_RRTT, CONST_COD_RECIBO_ANUL_SERCO)
			         OR C_TNX.CODIGO_RECIBO LIKE '%_A' THEN
			        1
			
			    WHEN C_TNX.RAMO = CONST_RAMA_RRTT THEN
			        TO_NUMBER(SUBSTR(C_TNX.CODIGO_POLIZA, 3, 5)) * 1000 + TO_NUMBER(IFNULL(C_TNX.NUM_ORDEN_MOVIMIENTO, 0))
			
			    WHEN C_TNX.RAMO IN (CONST_RAMA_RRGG, CONST_RAMA_RRPP) THEN
			        CASE
			            WHEN SUBSTR(C_TNX.CODIGO_PRODUCTO,1,5) IN ('01502','01503')
			              OR SUBSTR(C_TNX.CODIGO_PRODUCTO,1,6) = '015012%'
			              OR C_TNX.FILE_NAME LIKE '%SOL%'
			              --OR C_TNX.FILE_NAME LIKE '%SOLNE%' 
			              THEN
			                TO_NUMBER(RPAD(REPLACE(C_TNX.CODIGO_RECIBO,'-',''),11,'0') || SUBSTR('000' || C_TNX.CODIGO_SUPLEMENTO,LENGTH('000' || C_TNX.CODIGO_SUPLEMENTO)-3,4) || '0')
			                --ASISA
			        	WHEN C_TNX.FILE_NAME LIKE 'RECI2116%'
			        	  OR C_TNX.FILE_NAME LIKE 'RECI2117%' THEN
			        		TO_NUMBER(REPLACE(C_TNX.CODIGO_RECIBO,'-','') || 
			                TO_VARCHAR(LPAD(IFNULL(C_TNX.NUM_ORDEN_MOVIMIENTO,'0'),4,'0')) || '0')
			            ELSE
			                TO_NUMBER(REPLACE(C_TNX.CODIGO_RECIBO,'-','') || 
			                TO_VARCHAR(LPAD(IFNULL(C_TNX.NUM_ORDEN_MOVIMIENTO,'0'),4,'0')) || CONST_SUBLINE_RRGGRRPP)
			        END
			END AS SUBLINENUMBER,
			CASE
			    WHEN C_TNX.MOTIVO_ALTA = CONST_MOTIVO_ALTA_DE
			         AND C_TNX.ASEGURADOS_NETOS_ORI = 0
			         AND C_TNX.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_71 THEN
			        CONST_RECIBOS_ESPECIFICOS_66
			    ELSE
			        C_TNX.PERMANENCIA
			END AS EVENTTYPEID,
			(
				/*SELECT COUNT(*) FROM :TBL_GEN_CODIGOS_AGENTE T 
		    	WHERE T.CODIGO_OCASO = (CASE WHEN (C_TNX.CODIGO_UNICO_AGENTE IS NULL OR (SUBSTR('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE,'0'),
		    	LENGTH('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE,'0'))-5,6)) = '000000')
                   AND (SUBSTR('000000' || COALESCE(C_TNX.CODIGO_AGENTE_ORIGINAL,'0'),LENGTH('000000' || COALESCE(C_TNX.CODIGO_AGENTE_ORIGINAL,'0'))-5,6)) <> '000000'
                   AND 'C' IS NULL 
                	THEN C_TNX.CODIGO_AGENTE_ORIGINAL ELSE C_TNX.CODIGO_UNICO_AGENTE END)
		    	AND T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.FECHA_COMPENSACION)
                AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.FECHA_COMPENSACION)*/
                --BRG Equivalente a la de arriba
                SELECT COUNT(*)  
                FROM :TBL_GEN_CODIGOS_AGENTE T
                --WHERE T.CODIGO_OCASO = C_TNX.CODIGO_UNICO_AGENTE
                --Metemos una subconsulta para sacar el CODIGO_UNICO
                WHERE T.CODIGO_UNICO = (SELECT MAX(X.CODIGO_UNICO) FROM (
												SELECT T.CODIGO_UNICO
												, ROW_NUMBER() OVER (
						        						--PARTITION BY T.CODIGO_UNICO
                                                        --BRG 20251007 Modificamos particion para obtener codigo_unico correcto
                                                        PARTITION BY C_TNX.CODIGO_POLIZA, C_TNX.CODIGO_RECIBO, C_TNX.CODIGO_SUPLEMENTO, C_TNX.ESTADO_RECIBO, C_TNX.PERMANENCIA
						        						ORDER BY T.EFFECTIVEENDDATE DESC
						        							, CASE WHEN C_TNX.CODIGO_UNICO_AGENTE = T.CODIGO_OCASO
						        								THEN 1
						        								ELSE 2
						        							END ASC
						        					) AS ROW_NUM_COD_UNI 
												FROM :TBL_GEN_CODIGOS_AGENTE T
								                WHERE T.CODIGO_OCASO = C_TNX.CODIGO_UNICO_AGENTE
											) X WHERE X.ROW_NUM_COD_UNI = 1 
                						)
                    AND T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.FECHA_COMPENSACION)
                    AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.FECHA_COMPENSACION)
			) AS v_existe_positionname,
			(
			COALESCE((SELECT REC_OFI_PERMANENCIA_20 FROM :lt_ofic_cob_per_20 P
                --BRG 20250822 metemos LPAD para comparar correctamente con OFI_COBRADORA
	         	WHERE LPAD(C_TNX.OFICINA_GESTORA,4,'0') = SUBSTR(P.OFI_COBRADORA,1,4)
	         	AND C_TNX.FECHA_COMPENSACION >= P.FECHA_EFEC_DESDE
	         	AND C_TNX.FECHA_COMPENSACION < P.FECHA_EFEC_HASTA
	         ), 'N')	
			) AS REC_OFI_PERMANENCIA_20,
			(
				SELECT COUNT(*) FROM :TBL_GEN_CODIGOS_AGENTE T
				WHERE T.CODIGO_OCASO = C_TNX.INSPECTOR
			) AS v_existe_inspector_DE
		FROM :TBL_C_TXN_GR C_TNX
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'1-calculo de campos:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN_GR = SELECT * FROM :TBL_C_TXN_GR WHERE 1=0;
	
	TBL_C_TXN_CALCULADO_FILTRADO = (
		SELECT * FROM 
			(SELECT *, ROW_NUMBER() OVER (PARTITION BY ORDERID,LINE,SUBLINENUMBER,EVENTTYPEID ORDER BY CODIGO_SUPLEMENTO DESC) AS RN
			FROM :TBL_C_TXN_CALCULADO)  C_TNX
		WHERE C_TNX.RN = 1
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'1.5-filtro de registros repetidos:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	TBL_C_TXN_CALCULADO = SELECT * FROM :TBL_C_TXN_CALCULADO WHERE 1=0;
	
	TBL_C_TXN_CALCULADO_2 = (
		SELECT 
			C_TNX.*,
			CASE	
				-- TGV 20260210 -- se quita el tratamiento especial para la gestion directa a peticion de Cristian y David en reunion de seguimiento
				--	WHEN UPPER(C_TNX.TIPO_RECIBO) = 'GD' AND C_TNX.PERMANENCIA NOT IN (CONST_RECIBOS_ESPECIFICOS_10, CONST_RECIBOS_ESPECIFICOS_20) THEN '1'
				    WHEN C_TNX.OFICINA_GESTORA IN ('0900', '900') THEN '0'
				    WHEN (C_TNX.OFICINA_GESTORA IS NULL OR C_TNX.OFICINA_COBRADORA IS NULL) AND (v_existe_positionname) > 0 THEN '0'
				    WHEN (C_TNX.OFICINA_GESTORA IS NULL OR C_TNX.OFICINA_COBRADORA IS NULL) AND (v_existe_positionname) = 0 THEN '1'
				    WHEN REC_OFI_PERMANENCIA_20 = CONST_S
				         THEN '0'
				    WHEN SUBSTR('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0'), LENGTH('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0')) -5, 6) = '000000'
				         AND SUBSTR('000000' || COALESCE(C_TNX.INSPECTOR, '0'), LENGTH('000000' || COALESCE(C_TNX.INSPECTOR, '0')) -5, 6) = '000000'
				         AND C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66, CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_65) THEN '1'
				    WHEN ((SUBSTR('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0'), LENGTH('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0')) -5, 6) = '000000'
				         AND SUBSTR('000000' || COALESCE(C_TNX.INSPECTOR, '0'), LENGTH('000000' || COALESCE(C_TNX.INSPECTOR, '0')) -5, 6) <> '000000') OR (v_existe_positionname) = 0)
				         AND C_TNX.PERMANENCIA NOT IN (CONST_RECIBOS_CARTERA_81, CONST_RECIBOS_ESPECIFICOS_10) THEN '1'
				    ELSE '0'
			END AS ST_GENERICATTRIBUTE20,
			CASE
				    WHEN C_TNX.OFICINA_GESTORA IN ('0900', '900') THEN C_TNX.CODIGO_UNICO_AGENTE
				    WHEN (C_TNX.OFICINA_GESTORA IS NULL OR C_TNX.OFICINA_COBRADORA IS NULL) AND (v_existe_positionname) > 0 THEN ''
				    WHEN (C_TNX.OFICINA_GESTORA IS NULL OR C_TNX.OFICINA_COBRADORA IS NULL) AND (v_existe_positionname) = 0 THEN C_TNX.INSPECTOR
				    WHEN C_TNX.REC_OFI_PERMANENCIA_20 = CONST_S
				         THEN C_TNX.CODIGO_UNICO_AGENTE
				    WHEN SUBSTR('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0'), LENGTH('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0')) -5, 6 ) = '000000'
				         AND SUBSTR('000000' || COALESCE(C_TNX.INSPECTOR, '0'), LENGTH('000000' || COALESCE(C_TNX.INSPECTOR, '0')) -5, 6 ) = '000000'
				         AND C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66, CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_65) THEN C_TNX.CODIGO_UNICO_AGENTE
				    WHEN ((SUBSTR('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0'), LENGTH('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0')) -5, 6 ) = '000000'
				         AND SUBSTR('000000' || COALESCE(C_TNX.INSPECTOR, '0'), LENGTH('000000' || COALESCE(C_TNX.INSPECTOR, '0')) -5, 6 ) <> '000000') OR (v_existe_positionname) = 0)
				         AND C_TNX.PERMANENCIA NOT IN (CONST_RECIBOS_CARTERA_81, CONST_RECIBOS_ESPECIFICOS_10) THEN C_TNX.CODIGO_UNICO_AGENTE
				    ELSE ''
			END AS TA_GENERICATTRIBUTE1,
			IFNULL(CASE
				    WHEN C_TNX.OFICINA_GESTORA IN ('0900', '900') THEN SUBSTR('000' || C_TNX.OFICINA_GESTORA,LENGTH('000' || C_TNX.OFICINA_GESTORA) -3, 4) || '000001'
				    WHEN (C_TNX.OFICINA_GESTORA IS NULL OR C_TNX.OFICINA_COBRADORA IS NULL) AND (v_existe_positionname) > 0 THEN C_TNX.CODIGO_UNICO_AGENTE
				    WHEN (C_TNX.OFICINA_GESTORA IS NULL OR C_TNX.OFICINA_COBRADORA IS NULL) AND (v_existe_positionname) = 0 THEN C_TNX.CODIGO_UNICO_AGENTE
				    WHEN C_TNX.REC_OFI_PERMANENCIA_20 = CONST_S
				         THEN SUBSTR('000' || C_TNX.OFICINA_GESTORA,LENGTH('000' || C_TNX.OFICINA_GESTORA)-3,4) || '999999'
                    --BRG 20250903 El SUBSTR se estaba haciendo con INSPECTOR en vez de con CODIGO_UNICO_AGENTE
				    WHEN SUBSTR('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0'), LENGTH('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0')) -5, 6 ) = '000000'
				         AND SUBSTR('000000' || COALESCE(C_TNX.INSPECTOR, '0'),LENGTH('000000' || COALESCE(C_TNX.INSPECTOR, '0')) -5, 6 ) = '000000'
				         AND C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66, CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_65) THEN SUBSTR('000' || C_TNX.OFICINA_GESTORA,LENGTH('000' || C_TNX.OFICINA_GESTORA) -3, 4) || '009999'
                    --BRG 20250903 El SUBSTR se estaba haciendo con INSPECTOR en vez de con CODIGO_UNICO_AGENTE
				    WHEN ((SUBSTR('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0'), LENGTH('000000' || COALESCE(C_TNX.CODIGO_UNICO_AGENTE, '0')) -5, 6 ) = '000000'
				         AND SUBSTR('000000' || COALESCE(C_TNX.INSPECTOR, '0'), LENGTH('000000' || COALESCE(C_TNX.INSPECTOR, '0')) -5, 6 ) <> '000000') OR (v_existe_positionname) = 0)
				         AND C_TNX.PERMANENCIA NOT IN (CONST_RECIBOS_CARTERA_81, CONST_RECIBOS_ESPECIFICOS_10) THEN C_TNX.INSPECTOR
				    ELSE C_TNX.CODIGO_UNICO_AGENTE
			END, CONST_NO_ENCONTRADO) AS TA_GENERICATTRIBUTE3,
			(SELECT MAX(REC.FECHA_VTO_RECIBO)
			                      FROM EXT.RECIBOS REC
			                      WHERE REC.CODIGO_POLIZA = C_TNX.CODIGO_POLIZA
			                        AND REC.PERMANENCIA = C_TNX.PERMANENCIA
			                        AND REC.ESTADO_RECIBO = CONST_RECIBO_COBRADO
			                        AND REC.CODIGO_RECIBO <> C_TNX.CODIGO_RECIBO) AS FECHA_VENCIMIENTO_REC
		
		FROM :TBL_C_TXN_CALCULADO_FILTRADO C_TNX
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'2-calculo de campos:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN_CALCULADO_FILTRADO = SELECT * FROM :TBL_C_TXN_CALCULADO_FILTRADO WHERE 1=0;
	
	TBL_C_TXN_CALCULADO_3 = (
		SELECT 
			C_TNX.*,
			--BRG 20251006 Modificamos esta consulta para extraer correctamente las asignaciones de las transacciones
			IFNULL(
				(SELECT MAX(X.CODIGO_UNICO) FROM (
					SELECT T.CODIGO_UNICO
					, ROW_NUMBER() OVER (
                        --PARTITION BY T.CODIGO_UNICO
                        --BRG 20251007 Modificamos particion para obtener codigo_unico correcto
                        PARTITION BY C_TNX.CODIGO_POLIZA, C_TNX.CODIGO_RECIBO, C_TNX.CODIGO_SUPLEMENTO, C_TNX.ESTADO_RECIBO, C_TNX.PERMANENCIA
                        ORDER BY T.EFFECTIVEENDDATE DESC
                            , CASE WHEN C_TNX.TA_GENERICATTRIBUTE3 = T.CODIGO_OCASO
                                THEN 1
                                ELSE 2
                            END ASC) AS ROW_NUM_COD_UNI
					FROM :TBL_GEN_CODIGOS_AGENTE T
					WHERE T.CODIGO_OCASO = C_TNX.TA_GENERICATTRIBUTE3
				) T INNER JOIN :TBL_GEN_CODIGOS_AGENTE X ON X.CODIGO_UNICO = T.CODIGO_UNICO
				WHERE T.ROW_NUM_COD_UNI = 1
				-- AND X.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.FECHA_COMPENSACION)
				-- AND X.EFFECTIVEENDDATE > LAST_DAY(C_TNX.FECHA_COMPENSACION) 
			), CONST_NO_ENCONTRADO) AS POSITIONNAME,
			--TIPO-16 mirar rrgg rrpp si el ultimo caracter del codigo poliza es X o S, poner agente zona anterior
			IFNULL(
				CASE WHEN C_TNX.RAMO IN ('RRPP', 'RRGG') AND SUBSTR(C_TNX.CODIGO_POLIZA, LENGTH(C_TNX.CODIGO_POLIZA),1) IN ('X', 'S') THEN
					COALESCE(
						(SELECT 
		                    CODIGO_AGENTE_ZONA
		                FROM (
		                    SELECT 
		                        CODIGO_AGENTE_ZONA,
		                        ROW_NUMBER() OVER (
		                            PARTITION BY REC.CODIGO_RECIBO
		                            ORDER BY REC.FECHA_COMPENSACION DESC
		                        ) AS NUM_FILAS
		                    FROM EXT.RECIBOS REC -- ITL 20250801 modificamos porque antes tiraba de INYC_LP_RECIBOS
		                    WHERE 
		                        REC.CODIGO_RECIBO = C_TNX.CODIGO_RECIBO
		                        AND REC.CODIGO_SUPLEMENTO = C_TNX.CODIGO_SUPLEMENTO
		                        AND SUBSTR(REC.CODIGO_POLIZA, LENGTH(REC.CODIGO_POLIZA),1) = 'N'
		                        AND SUBSTR(REC.CODIGO_POLIZA, 1, LENGTH(REC.CODIGO_POLIZA) - 1) = 
		                            SUBSTR(C_TNX.CODIGO_POLIZA, 1, LENGTH(C_TNX.CODIGO_POLIZA) - 1)
		                        AND REC.ESTADO_RECIBO = C_TNX.ESTADO_RECIBO
		                ) SUB
		                WHERE NUM_FILAS = 1)
					, CONST_NO_ENCONTRADO)
				ELSE C_TNX.CODIGO_AGENTE_ZONA 
				END
			, CONST_NO_ENCONTRADO)AS POSITIONNAME_16
			FROM :TBL_C_TXN_CALCULADO_2 C_TNX
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'3-calculo de campos:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	--------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_TXN_CALCULADO_3_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_C_TXN_CALCULADO_3_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_C_TXN_CALCULADO_3_DEBUG AS (SELECT * FROM :TBL_C_TXN_CALCULADO_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_TXN_CALCULADO_3_DEBUG' , v_log_count, v_idproceso, 'debug');
    ------------------------------

	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN_CALCULADO_2 = SELECT * FROM :TBL_C_TXN_CALCULADO_2 WHERE 1=0;

	TBL_C_TXN_CALCULADO_4 = (
		SELECT 
			C_TNX.*,
			CASE
			    WHEN C_TNX.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP, CONST_COD_RECIBO_ANUL_SERCO) THEN
			        CASE
			            WHEN C_TNX.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_66 THEN (
			                SELECT MAX(REC.FECHA_EMISION_REC)
			                FROM EXT.RECIBOS REC
			                WHERE REC.CODIGO_POLIZA = C_TNX.CODIGO_POLIZA
			                  AND REC.PERMANENCIA = C_TNX.PERMANENCIA
			                  AND REC.ESTADO_RECIBO = CONST_RECIBO_COBRADO
			                  AND REC.CODIGO_RECIBO <> C_TNX.CODIGO_RECIBO
			                  AND REC.FECHA_VTO_RECIBO = C_TNX.FECHA_VENCIMIENTO_REC
			            )
			            WHEN C_TNX.PERMANENCIA = '11' THEN C_TNX.FECHA_EMISION_REC
			            ELSE C_TNX.FECHA_EMISION_POLIZA
			        END
			
			    WHEN SUBSTR(C_TNX.CODIGO_RECIBO,LENGTH(C_TNX.CODIGO_RECIBO)-1,2) = '_A' OR C_TNX.CODIGO_RECIBO = CONST_COD_RECIBO_ANUL_RRTT THEN
			        CASE
			            WHEN C_TNX.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_66 THEN C_TNX.FECHA_EMISION_REC
			            WHEN C_TNX.PERMANENCIA = '11' THEN C_TNX.FECHA_EMISION_REC
			            ELSE C_TNX.FECHA_EMISION_POLIZA
			        END
			
			    WHEN C_TNX.PERMANENCIA = '11' THEN C_TNX.FECHA_COMPENSACION
			
			    WHEN (C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66)
			       OR (C_TNX.RAMO = CONST_RAMA_RRPP AND C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81)
			           AND C_TNX.CODIGO_SUPLEMENTO > 0)) THEN
			        CASE
			            WHEN (C_TNX.ESTADO_RECIBO_DEF = CONST_RECIBO_COBRADO AND C_TNX.LINE = '202001')
			              OR (C_TNX.ESTADO_RECIBO_DEF = CONST_RECIBO_PENDIENTE AND C_TNX.LINE = '202002') THEN C_TNX.FCHA_EFECTO_SUPLEMENTO
			            ELSE C_TNX.FECHA_EMISION_REC
			        END
			
			    ELSE C_TNX.FECHA_EMISION_POLIZA
			END AS ST_GENERICDATE2
		FROM :TBL_C_TXN_CALCULADO_3 C_TNX
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'4-calculo de campos:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN_CALCULADO_3 = SELECT * FROM :TBL_C_TXN_CALCULADO_3 WHERE 1=0;
	

	--20250827 RMF: Se a�ade una tabla para el cursor C_CURSOR_AGENTE_TIPOLOGIA y poder sacar el MAX(TIPO_AGENTE) para el CODIGO_OCASO encontrado
	-- TBL_C_CURSOR_AGENTE_TIPOLOGIA = SELECT T.CODIGO_OCASO
	-- 		        					, (SELECT MAX(X.TIPO_AGENTE) 
	-- 		        						FROM :TBL_GEN_CODIGOS_AGENTE X 
	-- 		        						WHERE X.CODIGO_UNICO = T.CODIGO_UNICO
	-- 		        							AND X.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.ST_GENERICDATE2) 
	-- 	                    					AND X.EFFECTIVEENDDATE > LAST_DAY(C_TNX.ST_GENERICDATE2)
	-- 		        					) AS MAX_TIPO_AGENTE
	-- 								FROM :TBL_GEN_CODIGOS_AGENTE T
	-- 								INNER JOIN :TBL_C_TXN_CALCULADO_4 C_TNX
	-- 									ON T.CODIGO_OCASO = (CASE WHEN C_TNX.ST_GENERICATTRIBUTE20 =  '1' THEN C_TNX.CODIGO_AGENTE_ORIGINAL ELSE C_TNX.TA_GENERICATTRIBUTE3 END)
	-- 								WHERE T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.ST_GENERICDATE2) 
 --               					AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.ST_GENERICDATE2)
	-- 								ORDER BY T.EFFECTIVEENDDATE DESC
	-- 								;
	--JGE 20251027 Se cambia la tabla temporal para coger el tipo_agente, la anterior fallaba para algunos casos
	TBL_C_CURSOR_AGENTE_TIPOLOGIA = SELECT T.*
			        					,ROW_NUMBER() OVER (
			        						PARTITION BY CODIGO_OCASO
					                        ORDER BY T.EFFECTIVEENDDATE DESC) AS ROW_NUM_COD_UNI
									FROM :TBL_GEN_CODIGOS_AGENTE T
									;
	v_num_rows = RECORD_COUNT(:TBL_C_CURSOR_AGENTE_TIPOLOGIA);
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_C_CURSOR_AGENTE_TIPOLOGIA creada:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	TBL_C_TXN_CALCULADO_5 = (
		SELECT 
			C_TNX.*,
			(
				SELECT IFNULL(MAX(TIPO_AGENTE),0) FROM :TBL_GEN_CODIGOS_AGENTE T 
				WHERE T.CODIGO_UNICO = C_TNX.POSITIONNAME
				AND T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.FECHA_COMPENSACION) 
	            AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.FECHA_COMPENSACION)
			) AS v_tipo_agente,
			IFNULL(to_decimal((
				--JGE 20250812 buscar por inspector, solo se busca el max ins_captador, se deberia elegir ordenando por max effectivestartdate
	            SELECT IFNULL(MAX(T.TIPO_AGENTE_PRIN),0) FROM :TBL_C_CURSOR_AGENTE_TIPOLOGIA T 
				WHERE T.CODIGO_UNICO = (
					SELECT MAX(INSP_CAPTADOR) FROM :TBL_C_CURSOR_AGENTE_TIPOLOGIA T 
					WHERE T.CODIGO_UNICO = C_TNX.POSITIONNAME
					-- AND T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.FECHA_COMPENSACION) 
					-- AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.FECHA_COMPENSACION)
					AND T.ROW_NUM_COD_UNI = 1
				)
				AND T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.FECHA_COMPENSACION) 
				AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.FECHA_COMPENSACION)
				AND T.ROW_NUM_COD_UNI = 1
			),25,10),0) AS vr_tipo_agente_insp,	--TA.GENERICNUMBER4
            -- JGE 20240212 ocaso habilita campo Gn5 para pasarles tipo de agente que tenia el agente de la transaccion, segun los criterios indicados en la reunion del martes 6-2-2024
			IFNULL(to_decimal(
				-- (SELECT IFNULL(MAX(TIPO_AGENTE),0) FROM :TBL_GEN_CODIGOS_AGENTE T 
				-- WHERE T.CODIGO_OCASO = (CASE WHEN C_TNX.ST_GENERICATTRIBUTE20 =  '1' THEN C_TNX.CODIGO_AGENTE_ORIGINAL ELSE C_TNX.TA_GENERICATTRIBUTE3 END)
				-- AND T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.ST_GENERICDATE2) 
	   --         AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.ST_GENERICDATE2)
	            (SELECT MAX(TIPO_AGENTE) FROM :TBL_C_CURSOR_AGENTE_TIPOLOGIA T
	            	WHERE T.CODIGO_OCASO = (CASE WHEN C_TNX.ST_GENERICATTRIBUTE20 =  '1' THEN C_TNX.CODIGO_AGENTE_ORIGINAL ELSE C_TNX.TA_GENERICATTRIBUTE3 END)
		            AND T.EFFECTIVESTARTDATE <= LAST_DAY(C_TNX.ST_GENERICDATE2) 
		            AND T.EFFECTIVEENDDATE > LAST_DAY(C_TNX.ST_GENERICDATE2)
		            AND T.ROW_NUM_COD_UNI = 1
	            )
			,25,10),0) AS vr_tipo_agente_an5,	--TA.GENERICNUMBER5
			IFNULL(
				(SELECT MAX(T.CODIGO_UNICO)
				FROM :TBL_GEN_CODIGOS_AGENTE T
				WHERE T.CODIGO_OCASO = (SUBSTR('000' || C_TNX.OFICINA_COBRADORA,LENGTH('000' || C_TNX.OFICINA_COBRADORA)-3,4) || '999999')
			),:CONST_NO_ENCONTRADO) AS POSITIONNAME_20
		FROM :TBL_C_TXN_CALCULADO_4 C_TNX
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'5-calculo de campos:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN_CALCULADO_4 = SELECT * FROM :TBL_C_TXN_CALCULADO_4 WHERE 1=0;
	
	TBL_C_TXN_CALCULADO_6 = (
		SELECT 
			C_TNX.*,
			CASE
			 	--WHEN C_TNX.v_tipo_agente IN (12, 6) THEN
				--20260406 TGV -- Por peticion de comercial se eliminan los tipo 6 corredores en derechos
			    --WHEN C_TNX.v_tipo_agente IN (12) THEN
				WHEN C_TNX.v_tipo_agente = 12 THEN
			      CASE
			        WHEN C_TNX.v_existe_inspector_DE > 0 AND 
			             (C_TNX.PERMANENCIA <> :CONST_RECIBOS_CARTERA_81 OR 
			              (C_TNX.PERMANENCIA = :CONST_RECIBOS_CARTERA_81 AND 
			               EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) AND
			               EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO) - 1))
			        THEN '13'
			        
			        WHEN C_TNX.v_existe_inspector_DE = 0 AND 
			             (C_TNX.PERMANENCIA <> :CONST_RECIBOS_CARTERA_81 OR 
			              (C_TNX.PERMANENCIA = :CONST_RECIBOS_CARTERA_81 AND 
			               EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) AND
			               EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO) - 1))
			        THEN '13'
			        
			        ELSE '12'
			      END
			    ELSE '0'
			  END AS PAYMENTTERMS
		FROM :TBL_C_TXN_CALCULADO_5 C_TNX
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'6-calculo de campos:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	 ----------------------------------------
		--COMENTAR EN PRD
		SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_TXN_CALCULADO_6_DEBUG';
		
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_C_TXN_CALCULADO_6_DEBUG;
		END IF;
		
		CREATE TABLE EXT.TBL_C_TXN_CALCULADO_6_DEBUG AS (SELECT * FROM :TBL_C_TXN_CALCULADO_6);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_TXN_CALCULADO_6_DEBUG' , v_log_count, v_idproceso, 'debug');
		 ----------------------------------------
	
	
	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN_CALCULADO_5 = SELECT * FROM :TBL_C_TXN_CALCULADO_5 WHERE 1=0;
	
	TNX_ST_EXISTENTES = (
		SELECT DISTINCT T.*
		FROM EXT.SALESTRANSACTION T
		JOIN (
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		    UNION ALL
			--bajas rrgg
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        ORDERID || '_BB' AS ORDERID, 
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		    UNION ALL
			--bajas rrtt
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        SUBSTR(ORDERID, 1, LENGTH(ORDERID)-1) || 'B' AS ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		    UNION ALL
			--trashera
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        SUBSTR(ORDERID, 1, LENGTH(ORDERID)-1) || '_R' AS ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		    
		    UNION ALL
			--tipo 20
		    SELECT 
		        TO_BIGINT(CASE WHEN RAMO = CONST_RAMA_RRTT THEN (LINE || PERMANENCIA) ELSE LINE END) AS LINENUMBER,
		        SUBLINENUMBER,
		        CONST_RECIBOS_ESPECIFICOS_20 AS EVENTTYPEID,
		        ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		    
		    UNION ALL
			--tipo 16
		    SELECT 
		        TO_BIGINT(CASE WHEN RAMO = CONST_RAMA_RRTT THEN (LINE || PERMANENCIA) ELSE LINE END) AS LINENUMBER,
		        SUBLINENUMBER,
		        CONST_RECIBOS_ESPECIFICOS_16 AS EVENTTYPEID,
		        ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		) VARIANTES
		  ON T.LINENUMBER = VARIANTES.LINENUMBER
		 AND T.SUBLINENUMBER = VARIANTES.SUBLINENUMBER
		 AND T.EVENTTYPEID = VARIANTES.EVENTTYPEID
		 AND T.ORDERID = VARIANTES.ORDERID
		 --AND T.BATCHNAME = VARIANTES.BATCHNAME
	);
	
	TNX_TA_EXISTENTES = (
		SELECT DISTINCT T.*
		FROM EXT.TRANSACTIONASSIGN T
		JOIN (
			--tnx normal
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		    UNION ALL
			--bajas rrgg
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        ORDERID || '_BB' AS ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		    UNION ALL
		--bajas rrtt
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        SUBSTR(ORDERID, 1, LENGTH(ORDERID)-1) || 'B' AS ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		    UNION ALL
			--trashera
		    SELECT 
		        TO_BIGINT(LINE) AS LINENUMBER,
		        SUBLINENUMBER,
		        EVENTTYPEID,
		        SUBSTR(ORDERID, 1, LENGTH(ORDERID)-1) || '_R' AS ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		    
		    UNION ALL
			--tipo 20
		    SELECT 
		        TO_BIGINT(CASE WHEN RAMO = CONST_RAMA_RRTT THEN (LINE || PERMANENCIA) ELSE LINE END) AS LINENUMBER,
		        SUBLINENUMBER,
		        CONST_RECIBOS_ESPECIFICOS_20 AS EVENTTYPEID,
		        ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		    
		    UNION ALL
			--tipo 16
		    SELECT 
		        TO_BIGINT(CASE WHEN RAMO = CONST_RAMA_RRTT THEN (LINE || PERMANENCIA) ELSE LINE END) AS LINENUMBER,
		        SUBLINENUMBER,
		        CONST_RECIBOS_ESPECIFICOS_16 AS EVENTTYPEID,
		        ORDERID,
		        'TXSTA_' || FILE_NAME	/*v_batchname*/	AS BATCHNAME
		    FROM :TBL_C_TXN_CALCULADO_6
		
		) VARIANTES
		  ON T.LINENUMBER = VARIANTES.LINENUMBER
		 AND T.SUBLINENUMBER = VARIANTES.SUBLINENUMBER
		 AND T.EVENTTYPEID = VARIANTES.EVENTTYPEID
		 AND T.ORDERID = VARIANTES.ORDERID
		 --AND T.BATCHNAME = VARIANTES.BATCHNAME
	);
	
	--comprobamos si hay que historificar
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'INICIO HISTORIFICACION'  , v_log_count, v_idproceso, 'info');
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en SALESTRANSACTION_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
								
				RESIGNAL;
				
			END;
	
		INSERT INTO EXT.SALESTRANSACTION_HIST 
		(
			SELECT v_idproceso, SRC.* 
			FROM :TNX_ST_EXISTENTES SRC
		);
		v_num_rows := ::rowcount;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Insert SALESTRANSACTION_HIST: ' || v_num_rows || ' filas' , v_log_count, v_idproceso, 'info');
		
	END;
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en DELETE en SALESTRANSACTION_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
								
				RESIGNAL;
				
			END;
	
		DELETE FROM EXT.SALESTRANSACTION T
		WHERE (T.ORDERID,T.LINENUMBER,T.SUBLINENUMBER,T.EVENTTYPEID) IN 
		(
			SELECT SRC.ORDERID, SRC.LINENUMBER, SRC.SUBLINENUMBER, SRC.EVENTTYPEID
			FROM :TNX_ST_EXISTENTES SRC
		);
		v_num_rows := ::rowcount;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DELETE SALESTRANSACTION: ' || v_num_rows || ' filas' , v_log_count, v_idproceso, 'info');
		
	END;
	
	TNX_ST_EXISTENTES = SELECT * FROM :TNX_ST_EXISTENTES WHERE 1=0;
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT en TRANSACTIONASSIGN_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
								
				RESIGNAL;
				
			END;
	
		INSERT INTO EXT.TRANSACTIONASSIGN_HIST 
		(
			SELECT v_idproceso, SRC.* 
			FROM :TNX_TA_EXISTENTES SRC
		);
		v_num_rows := ::rowcount;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Insert TRANSACTIONASSIGN_HIST: ' || v_num_rows || ' filas' , v_log_count, v_idproceso, 'info');
		
	END;
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en DELETE en TRANSACTIONASSIGN_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
									|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
								
				RESIGNAL;
				
			END;
	
		DELETE FROM EXT.TRANSACTIONASSIGN T
		WHERE (T.ORDERID,T.LINENUMBER,T.SUBLINENUMBER,T.EVENTTYPEID) IN 
		(
			SELECT SRC.ORDERID, SRC.LINENUMBER, SRC.SUBLINENUMBER, SRC.EVENTTYPEID
			FROM :TNX_TA_EXISTENTES SRC
		);
		v_num_rows := ::rowcount;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DELETE TRANSACTIONASSIGN: ' || v_num_rows || ' filas' , v_log_count, v_idproceso, 'info');
	
	END;
	
	TNX_TA_EXISTENTES = SELECT * FROM :TNX_TA_EXISTENTES WHERE 1=0;
	
	TBL_SALESTRANSACTION = (
		SELECT 
			--TENANTID
			v_tenantid	AS TENANTID,
			--STAGESALESTRANSACTIONSEQ
			--ORDERID
		    C_TNX.ORDERID AS ORDERID,
		    --BATCHNAME
			'TXSTA_' || C_TNX.FILE_NAME	/*v_batchname*/	AS BATCHNAME,
			--FILE_IN_RECIBOS
			C_TNX.FILE_NAME	AS FILE_IN_RECIBOS,
			--LINENUMBER
			TO_BIGINT(C_TNX.LINE) AS LINENUMBER,
			--SUBLINENUMBER	
			TO_BIGINT(C_TNX.SUBLINENUMBER) AS SUBLINENUMBER,
			--EVENTTYPEID
			C_TNX.EVENTTYPEID AS EVENTTYPEID,
			--SALESTRANSACTIONSEQ
			NULL	AS SALESTRANSACTIONSEQ,
			--SALESORDERSEQ
			NULL	AS SALESORDERSEQ,
			--ACCOUNTINGDATE
			C_TNX.FECHA_COBRO	AS ACCOUNTINGDATE,
			--PRODUCTID
			C_TNX.CODIGO_PRODUCTO AS PRODUCTID,
			--PRODUCTNAME
			NULL AS PRODUCTNAME,
			--PRODUCTDESCRIPTION
			NULL AS PRODUCTDESCRIPTION,
			-- VALUE
			TO_DECIMAL(CASE 
			    WHEN C_TNX.MARCA_RECUPERADO = 'XX' THEN IFNULL(C_TNX.PRIMA_NETA_RECIBO, 0)
			    ELSE IFNULL(C_TNX.PRIMA_COMISIONABLE, 0)
			END,25,10) AS VALUE,
			-- UNITTYPEFORVALUE
			CONST_TIPO_EURO AS UNITTYPEFORVALUE, 
			-- NUMBEROFUNITS
			TO_DECIMAL(CASE 
			    WHEN C_TNX.CODIGO_PRODUCTO = SUBSTR(C_TNX.CODIGO_POLIZA, 1, 7) 
			    THEN C_TNX.ASEGURADOS_NETOS_ORI 
			    ELSE 0 
			END,25,10) AS NUMBEROFUNITS,
			-- UNITVALUE
			ROUND(TO_DECIMAL(C_TNX.UNIDAD_DE_POLIZA,25,10),2) AS UNITVALUE,
			-- UNITTYPEFORUNITVALUE
			CASE 
			    WHEN C_TNX.UNIDAD_DE_POLIZA IS NOT NULL 
			    THEN CONST_TIPO_QUANTITY 
			    ELSE NULL 
			END AS UNITTYPEFORUNITVALUE,
			-- COMPENSATIONDATE
			C_TNX.FECHA_COMPENSACION AS COMPENSATIONDATE,
			-- PAYMENTTERMS
			C_TNX.PAYMENTTERMS AS PAYMENTTERMS,
			-- PONUMBER
			NULL AS PONUMBER,
			-- CHANNEL
			C_TNX.CIA AS CHANNEL,
			-- ALTERNATEORDERNUMBER
			NULL AS ALTERNATEORDERNUMBER,
			-- DATASOURCE
			NULL AS DATASOURCE,
			-- NATIVECURRENCY
			CASE 
			    WHEN C_TNX.IMPORTE_COMISION IS NOT NULL 
			    THEN CONST_TIPO_EURO 
			    ELSE NULL
			END AS NATIVECURRENCY,
			-- NATIVECURRENCYAMOUNT
			TO_DECIMAL(C_TNX.IMPORTE_COMISION,25,10) AS NATIVECURRENCYAMOUNT,
			-- DISCOUNTPERCENT
			TO_DECIMAL(C_TNX.PORCENTAJE_COMISION_CALCULAD / 100,25,10) AS DISCOUNTPERCENT,
			-- DISCOUNTTYPE
			CASE 
			    WHEN C_TNX.PORCENTAJE_COMISION_CALCULAD IS NOT NULL 
			    THEN CONST_TIPO_PERCENTAGE 
			    ELSE NULL 
			END AS DISCOUNTTYPE,
			-- BILLTOCUSTID
			NULL AS BILLTOCUSTID,
			-- BILLTOCONTACT
			NULL AS BILLTOCONTACT,
			-- BILLTOCOMPANY
			NULL AS BILLTOCOMPANY,
			-- BILLTOAREACODE
			NULL AS BILLTOAREACODE,
			-- BILLTOPHONE
			NULL AS BILLTOPHONE,
			-- BILLTOFAX
			NULL AS BILLTOFAX,
			-- BILLTOADDRESS1
			NULL AS BILLTOADDRESS1,
			-- BILLTOADDRESS2
			NULL AS BILLTOADDRESS2,
			-- BILLTOADDRESS3
			NULL AS BILLTOADDRESS3,
			-- BILLTOCITY
			NULL AS BILLTOCITY,
			-- BILLTOSTATE
			NULL AS BILLTOSTATE,
			-- BILLTOCOUNTRY
			NULL AS BILLTOCOUNTRY,
			-- BILLTOPOSTALCODE
			NULL AS BILLTOPOSTALCODE,
			-- BILLTOINDUSTRY
			NULL AS BILLTOINDUSTRY,
			-- BILLTOGEOGRAPHY
			NULL AS BILLTOGEOGRAPHY,
			-- SHIPTOCUSTID
			NULL AS SHIPTOCUSTID,
			-- SHIPTOCONTACT
			NULL AS SHIPTOCONTACT,
			-- SHIPTOCOMPANY
			NULL AS SHIPTOCOMPANY,
			-- SHIPTOAREACODE
			NULL AS SHIPTOAREACODE,
			-- SHIPTOPHONE
			NULL AS SHIPTOPHONE,
			-- SHIPTOFAX
			NULL AS SHIPTOFAX,
			-- SHIPTOADDRESS1
			NULL AS SHIPTOADDRESS1,
			-- SHIPTOADDRESS2
			NULL AS SHIPTOADDRESS2,
			-- SHIPTOADDRESS3
			NULL AS SHIPTOADDRESS3,
			-- SHIPTOCITY
			NULL AS SHIPTOCITY,
			-- SHIPTOSTATE
			NULL AS SHIPTOSTATE,
			-- SHIPTOCOUNTRY
			NULL AS SHIPTOCOUNTRY,
			-- SHIPTOPOSTALCODE
			NULL AS SHIPTOPOSTALCODE,
			-- SHIPTOINDUSTRY
			NULL AS SHIPTOINDUSTRY,
			-- SHIPTOGEOGRAPHY
			NULL AS SHIPTOGEOGRAPHY,
			-- OTHERTOCUSTID
			NULL AS OTHERTOCUSTID,
			-- OTHERTOCONTACT
			NULL AS OTHERTOCONTACT,
			-- OTHERTOCOMPANY
			NULL AS OTHERTOCOMPANY,
			-- OTHERTOAREACODE
			NULL AS OTHERTOAREACODE,
			-- OTHERTOPHONE
			NULL AS OTHERTOPHONE,
			-- OTHERTOFAX
			NULL AS OTHERTOFAX,
			-- OTHERTOADDRESS1
			NULL AS OTHERTOADDRESS1,
			-- OTHERTOADDRESS2
			NULL AS OTHERTOADDRESS2,
			-- OTHERTOADDRESS3
			NULL AS OTHERTOADDRESS3,
			-- OTHERTOCITY
			NULL AS OTHERTOCITY,
			-- OTHERTOSTATE
			NULL AS OTHERTOSTATE,
			-- OTHERTOCOUNTRY
			NULL AS OTHERTOCOUNTRY,
			-- OTHERTOPOSTALCODE
			NULL AS OTHERTOPOSTALCODE,
			-- OTHERTOINDUSTRY
			NULL AS OTHERTOINDUSTRY,
			-- OTHERTOGEOGRAPHY
			NULL AS OTHERTOGEOGRAPHY,
			-- REASONID
			NULL AS REASONID,
			-- COMMENTS
			NULL AS COMMENTS,
			-- STAGEPROCESSDATE
			CURRENT_TIMESTAMP AS STAGEPROCESSDATE,
			-- STAGEPROCESSFLAG
			0 AS STAGEPROCESSFLAG,
			-- BUSINESSUNITNAME
			CONST_TIPO_ESP AS BUSINESSUNITNAME,
			-- BUSINESSUNITMAP
			NULL AS BUSINESSUNITMAP,
			-- GENERICATTRIBUTE1
			CASE 
			    WHEN C_TNX.RAMO = CONST_RAMA_RRTT THEN 
			        C_TNX.CODIGO_POLIZA_I
			    WHEN C_TNX.RAMO IN (CONST_RAMA_RRGG, CONST_RAMA_RRPP) THEN 
			        SUBSTR(SUBSTR(C_TNX.CODIGO_POLIZA, 8), 1, LENGTH(SUBSTR(C_TNX.CODIGO_POLIZA, 8)) - 1)
			    ELSE 
			        NULL
			END AS GENERICATTRIBUTE1,
			-- GENERICATTRIBUTE2
			CASE 
			    WHEN C_TNX.PRIMA_UNICA = '1' THEN '9'
			    ELSE C_TNX.FORMA_PAGO
			END AS GENERICATTRIBUTE2,
			-- GENERICATTRIBUTE3
			IFNULL(C_TNX.TIPO_RECUPERACION,'*') AS GENERICATTRIBUTE3,
			-- GENERICATTRIBUTE4
			C_TNX.TARIFA AS GENERICATTRIBUTE4, 
			-- GENERICATTRIBUTE5
			C_TNX.ZONA AS GENERICATTRIBUTE5, 
			-- GENERICATTRIBUTE6
			CASE 
			    WHEN (C_TNX.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP, CONST_COD_RECIBO_ANUL_RRTT, CONST_COD_RECIBO_ANUL_SERCO) 
			           OR C_TNX.CODIGO_RECIBO LIKE '%_A') 
			           AND (
                           --BRG 20250828 Anyadidas constantes
			               I_FILE_NAME LIKE '%'||CONST_EMI_DIARIO_RRTT_OCASO||'%' OR   -- Diario RRTT Ocaso
			               I_FILE_NAME LIKE '%'||CONST_EMI_DIARIO_RRTT_ETERNA||'%' OR   -- Diario RRTT Eterna
			               I_FILE_NAME LIKE '%'||CONST_EMI_DIARIO_RRGGRRPP_OC||'%' OR   -- Diario RRGG Ocaso y SOLNET
			               I_FILE_NAME LIKE '%'||CONST_EMI_DIARIO_RRGGRRPP_ET||'%'      -- Diario RRGG Eterna
			           -- ALM 20210701: A�adimos las rehabilitaciones de SOLNET
			           ) 
			    OR C_TNX.TIPO_RECIBO = 'TRASREHA' 
			    THEN CONST_RECIBO_EMITIDO
			    ELSE C_TNX.ESTADO_RECIBO_DEF
			END AS GENERICATTRIBUTE6,
			-- GENERICATTRIBUTE7
			CASE 
			    WHEN C_TNX.PERMANENCIA = '11' 
			    THEN C_TNX.TIPO_RECIBO
			    ELSE C_TNX.CODIGO_RECIBO
			END AS GENERICATTRIBUTE7,
			-- GENERICATTRIBUTE8
			CASE 
			    WHEN C_TNX.RAMO = CONST_RAMA_RRTT 
			    THEN SUBSTR(C_TNX.CODIGO_POLIZA, 3, 5)
			    ELSE C_TNX.CLAVE_RIESGO
			END AS GENERICATTRIBUTE8,
			-- GENERICATTRIBUTE9
			C_TNX.CODIGO_SUPLEMENTO AS GENERICATTRIBUTE9,
			-- GENERICATTRIBUTE10
			C_TNX.DISTRITO_COBRO AS GENERICATTRIBUTE10, 
			-- GENERICATTRIBUTE11
			C_TNX.MODALIDAD AS GENERICATTRIBUTE11, 
			-- GENERICATTRIBUTE12
			C_TNX.DURACION AS GENERICATTRIBUTE12,
			-- GENERICATTRIBUTE13
			CASE 
			    WHEN C_TNX.RAMO = CONST_RAMA_RRTT 
			         AND C_TNX.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_55 
			    THEN '1'
			    WHEN C_TNX.INDICADOR_COMISION_CALCULADA IS NULL 
			    THEN '0'
			    ELSE C_TNX.INDICADOR_COMISION_CALCULADA
			END AS GENERICATTRIBUTE13,
			-- GENERICATTRIBUTE14
			CASE 
			    WHEN C_TNX.INDICADOR_PORCENTAJE_CALCULA IS NULL 
			    THEN '0'
			    ELSE C_TNX.INDICADOR_PORCENTAJE_CALCULA
			END AS GENERICATTRIBUTE14,
			-- GENERICATTRIBUTE15
			C_TNX.CLAUSULA AS GENERICATTRIBUTE15, 
			-- GENERICATTRIBUTE16
			CASE 
			    WHEN C_TNX.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_66 
			         AND C_TNX.ASEGURADOS_NETOS_ORI <> 0 
			    THEN '1'
			    ELSE '0'
			END AS GENERICATTRIBUTE16,
			-- GENERICATTRIBUTE17
			C_TNX.AUMENTO_CAPITALES_GARANTIA AS GENERICATTRIBUTE17, 
			-- GENERICATTRIBUTE18
			C_TNX.SUSTITUCION_INCENDIOS AS GENERICATTRIBUTE18, 
			-- GENERICATTRIBUTE19
			CASE 
			    WHEN C_TNX.RAMO = CONST_RAMA_RRTT THEN C_TNX.CODIGO_SINIESTRO
			    WHEN C_TNX.RAMO = CONST_RAMA_RRGG OR C_TNX.RAMO = CONST_RAMA_RRPP THEN ' '
			END AS GENERICATTRIBUTE19,
			-- GENERICATTRIBUTE20
			C_TNX.ST_GENERICATTRIBUTE20 AS GENERICATTRIBUTE20,
			-- GENERICATTRIBUTE21
			CASE 
			    WHEN C_TNX.RAMO = CONST_RAMA_RRTT AND INSTR(C_TNX.TIPO_CAMPANIA, 'CRUZADA',1) > 0 
			        THEN CONST_CAMPANIA_CRUZADA
			    ELSE C_TNX.TIPO_CAMPANIA
			END AS GENERICATTRIBUTE21,
			-- GENERICATTRIBUTE22
			IFNULL(C_TNX.MOTIVO_BAJA,'00') AS GENERICATTRIBUTE22,
			-- GENERICATTRIBUTE23
			C_TNX.TRASPASADA AS GENERICATTRIBUTE23,
			-- GENERICATTRIBUTE24
			CASE 
			    WHEN UPPER(C_TNX.MOVILIDAD) = CONST_MOVILIDAD_MOV 
			        THEN CONST_SI
			    ELSE CONST_NO
			END AS GENERICATTRIBUTE24,
			-- GENERICATTRIBUTE25
			CASE 
			    WHEN C_TNX.PERMANENCIA = '11' 
			        THEN UPPER(C_TNX.TIPO_MOVIMIENTO)
			    ELSE UPPER(C_TNX.TIPO_RECIBO)
			END AS GENERICATTRIBUTE25,
			-- GENERICATTRIBUTE26
			C_TNX.MOTIVO_ALTA AS GENERICATTRIBUTE26,
			-- GENERICATTRIBUTE27
			NULL AS GENERICATTRIBUTE27,
			-- GENERICATTRIBUTE28
			NULL AS GENERICATTRIBUTE28,
			-- GENERICATTRIBUTE29
			NULL AS GENERICATTRIBUTE29,
			-- GENERICATTRIBUTE30
			NULL AS GENERICATTRIBUTE30,
			-- GENERICATTRIBUTE31
			NULL AS GENERICATTRIBUTE31,
			-- GENERICATTRIBUTE32
			NULL AS GENERICATTRIBUTE32,
			-- GENERICNUMBER1
			TO_DECIMAL(CASE 
			    WHEN C_TNX.MARCA_RECUPERADO = 'XX' 
			        THEN 0
			    WHEN C_TNX.CIA = '01' 
			        THEN C_TNX.PRIMA_NETA_RECIBO + IFNULL(C_TNX.RECARGO, 0)
			    ELSE C_TNX.PRIMA_NETA_RECIBO
			END,25,10) AS GENERICNUMBER1,
			-- UNITTYPEFORGENERICNUMBER1
			CASE 
			    WHEN C_TNX.PRIMA_NETA_RECIBO IS NOT NULL 
			        THEN CONST_TIPO_EURO
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER1,
			-- GENERICNUMBER2
			TO_DECIMAL(C_TNX.INCREMENTO_PRIMA_ANUAL,25,10) AS GENERICNUMBER2, 
			-- UNITTYPEFORGENERICNUMBER2
			CASE 
			    WHEN C_TNX.INCREMENTO_PRIMA_ANUAL IS NOT NULL 
			        THEN CONST_TIPO_EURO
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER2,
			-- GENERICNUMBER3
			TO_DECIMAL(CASE 
			    WHEN C_TNX.RAMO = CONST_RAMA_RRGG OR C_TNX.RAMO = CONST_RAMA_RRPP 
			        THEN C_TNX.PORCENTAJE_DESCUENTO_SOBRE_PC
			    ELSE C_TNX.DESCUENTO_IMPORTE_SINIESTRALID
			END,25,10) AS GENERICNUMBER3,
			-- UNITTYPEFORGENERICNUMBER3
			CASE 
			    WHEN C_TNX.RAMO = CONST_RAMA_RRGG OR C_TNX.RAMO = CONST_RAMA_RRPP THEN
			        CASE 
			            WHEN C_TNX.PORCENTAJE_DESCUENTO_SOBRE_PC IS NOT NULL 
			                THEN CONST_TIPO_PERCENTAGE
			            ELSE NULL
			        END
			    WHEN  C_TNX.DESCUENTO_IMPORTE_SINIESTRALID IS NOT NULL 
			        THEN CONST_TIPO_PERCENTAGE
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER3,
			-- GENERICNUMBER4
			TO_DECIMAL(C_TNX.DESCUENTO_POR_PRIORITARIO,25,10) AS GENERICNUMBER4, 
			-- UNITTYPEFORGENERICNUMBER4
			CASE 
			    WHEN C_TNX.DESCUENTO_POR_PRIORITARIO IS NOT NULL 
			        THEN CONST_TIPO_PERCENTAGE
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER4,
			-- GENERICNUMBER5
			TO_DECIMAL(C_TNX.PORCENTAJE_NIVELADA,25,10) AS GENERICNUMBER5,
			-- UNITTYPEFORGENERICNUMBER5
			CASE 
			    WHEN C_TNX.PORCENTAJE_NIVELADA IS NOT NULL 
			        THEN CONST_TIPO_PERCENTAGE
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER5,
			-- GENERICNUMBER6
			TO_DECIMAL(CASE 
			    WHEN C_TNX.TIPO_CAMPANIA = 'DUATHLON' 
			        THEN C_TNX.BONIFICACION_POLIZA
			    WHEN C_TNX.TIPO_RECUPERACION IS NOT NULL 
			        THEN C_TNX.PORCENTAJE_BONIFICACION
			    ELSE C_TNX.BONIFICACION_POLIZA
			END,25,10) AS GENERICNUMBER6,
			-- UNITTYPEFORGENERICNUMBER6
			CASE 
			    WHEN 
			        (CASE 
			            WHEN C_TNX.TIPO_CAMPANIA = 'DUATHLON' 
			                THEN C_TNX.BONIFICACION_POLIZA
			            WHEN C_TNX.TIPO_RECUPERACION IS NOT NULL 
			                THEN C_TNX.PORCENTAJE_BONIFICACION
			            ELSE C_TNX.BONIFICACION_POLIZA
			        END) IS NOT NULL 
			        THEN CONST_TIPO_QUANTITY
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER6,
			-- GENERICDATE1
			C_TNX.FECHA_EFECTO_POLIZA AS GENERICDATE1,
			-- GENERICDATE2
			C_TNX.ST_GENERICDATE2 AS GENERICDATE2,
			-- GENERICDATE3
			C_TNX.FECHA_EMISION_POLIZA AS GENERICDATE3,
			-- GENERICDATE4
			CASE
			    WHEN C_TNX.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66)
			         OR (
			             C_TNX.RAMO = CONST_RAMA_RRPP
			             AND C_TNX.PERMANENCIA IN (
			                 CONST_RECIBOS_ESPECIFICOS_71,
			                 CONST_RECIBOS_CARTERA_72,
			                 CONST_RECIBOS_CARTERA_81
			             )
			             AND C_TNX.CODIGO_SUPLEMENTO > 0
			         )
			    THEN C_TNX.FCHA_EFECTO_SUPLEMENTO
			
			    WHEN C_TNX.CODIGO_RECIBO IN (
			        CONST_COD_RECIBO_ANUL_RRGGPP,
			        CONST_COD_RECIBO_ANUL_RRTT,
			        CONST_COD_RECIBO_ANUL_SERCO
			    )
			         OR SUBSTR(C_TNX.CODIGO_RECIBO,LENGTH(C_TNX.CODIGO_RECIBO)-1,2) = '_A'
			    THEN C_TNX.FECHA_BAJA
			
			    ELSE NULL
			END AS GENERICDATE4,
			-- GENERICDATE5
			C_TNX.FECHA_VTO_RECIBO AS GENERICDATE5,
			-- GENERICDATE6
			C_TNX.FECHA_CESION_POLIZA AS GENERICDATE6,
			-- GENERICBOOLEAN1
			TO_SMALLINT(C_TNX.PRIMA_UNICA) AS GENERICBOOLEAN1,
			-- GENERICBOOLEAN2
			TO_SMALLINT(CASE
			    WHEN C_TNX.PERMANENCIA = '11' THEN 0
			    ELSE C_TNX.RIESGO
			END) AS GENERICBOOLEAN2,
			-- GENERICBOOLEAN3
			TO_SMALLINT(CASE
			    WHEN C_TNX.PERMANENCIA = '11' THEN 1
			    WHEN C_TNX.DISMINUCION_PRIMA IS NULL OR C_TNX.DISMINUCION_PRIMA = '' THEN 0
			    ELSE C_TNX.DISMINUCION_PRIMA
			END) AS GENERICBOOLEAN3,
			-- GENERICBOOLEAN4
			TO_SMALLINT(CASE
			    WHEN C_TNX.PERMANENCIA = '11' THEN 1
			    WHEN C_TNX.PERIODO_EXTORNABLE IS NULL OR C_TNX.PERIODO_EXTORNABLE = '' OR C_TNX.PERIODO_EXTORNABLE = 'N' THEN 0
			    ELSE C_TNX.PERIODO_EXTORNABLE
			END) AS GENERICBOOLEAN4,
			-- GENERICBOOLEAN5
			TO_SMALLINT(CASE
			    WHEN C_TNX.PERMANENCIA = '11' AND C_TNX.MOTIVO_ALTA IN ('TP', 'TS', 'DT', 'RC', 'DE') THEN 1
			    WHEN C_TNX.COLECTIVO IS NULL OR C_TNX.COLECTIVO = '' THEN 0
			    ELSE C_TNX.COLECTIVO
			END) AS GENERICBOOLEAN5,
			-- GENERICBOOLEAN6
			TO_SMALLINT(CASE
			    WHEN C_TNX.PERMANENCIA = '11' AND C_TNX.MOTIVO_BAJA IN ('94', '92', '56', '80') THEN 1
			    WHEN C_TNX.AUTOLIQUIDA IS NULL OR C_TNX.AUTOLIQUIDA = '' THEN 0
			    ELSE C_TNX.AUTOLIQUIDA
			END) AS GENERICBOOLEAN6,
			-- STAGEERRORCODE
			0 AS STAGEERRORCODE,
			-- COMPENSATIONDATE_OLD
			NULL AS COMPENSATIONDATE_OLD,
			-- PUSEQ_OLD
			NULL AS PUSEQ_OLD,
			--campos necesarios para las condiciones de insercion de transaccion
			MARCA_CUENTA,
			PERMANENCIA,
			POSITIONNAME,
			CODIGO_RECIBO,
			RAMO,
			CODIGO_PRODUCTO,
			TIPO_RECUPERACION,
			PORCENTAJE_COMISION_CALCULAD,
			IMPORTE_COMISION,
			ES_PERMANENCIA_20,
			POSITIONNAME_16,
			TIPO_RECIBO,
			--campos necesarios para calcular otros campos
			LINE,
			PRIMA_NETA_RECIBO,
			v_tipo_agente,
			RECARGO,
			CODIGO_POLIZA,
			FILE_NAME,
			CODIGO_AGENTE_ZONA,
			FECHA_COMPENSACION,
			ESTADO_RECIBO_DEF
		FROM :TBL_C_TXN_CALCULADO_6 C_TNX
		
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_SALESTRANSACTION filas:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	TBL_TRANSACTIONASSIGN = (
		SELECT 
			-- TENANTID
			v_tenantid	AS TENANTID,
			-- STAGESALESTRANSACTIONSEQ
			NULL AS STAGESALESTRANSACTIONSEQ,
			-- SETNUMBER
			1 AS SETNUMBER,
			-- BATCHNAME
			'TXSTA_' || C_TNX.FILE_NAME/*v_batchname*/ AS BATCHNAME,
			-- FILE_IN_RECIBOS
			C_TNX.FILE_NAME AS FILE_IN_RECIBOS,
			-- ORDERID
			C_TNX.ORDERID,
			-- LINENUMBER
			TO_BIGINT(C_TNX.LINE) AS LINENUMBER,
			-- SUBLINENUMBER
			TO_BIGINT(C_TNX.SUBLINENUMBER) AS SUBLINENUMBER,
			-- EVENTTYPEID
			CASE
			    WHEN C_TNX.MOTIVO_ALTA = CONST_MOTIVO_ALTA_DE
			         AND C_TNX.ASEGURADOS_NETOS_ORI = 0
			         AND C_TNX.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_71 THEN
			        CONST_RECIBOS_ESPECIFICOS_66
			    ELSE
			        C_TNX.PERMANENCIA
			END AS EVENTTYPEID,
			-- SALESTRANSACTIONSEQ
			NULL	AS SALESTRANSACTIONSEQ,
			-- PAYEEID
			NULL AS PAYEEID, 
			-- PAYEETYPE
			NULL AS PAYEETYPE,
			-- POSITIONNAME
			C_TNX.POSITIONNAME AS POSITIONNAME,
			-- TITLENAME
			NULL AS TITLENAME,
			-- GENERICATTRIBUTE1
			C_TNX.TA_GENERICATTRIBUTE1 AS GENERICATTRIBUTE1,
			-- GENERICATTRIBUTE2
			C_TNX.CODIGO_AGENTE_ORIGINAL AS GENERICATTRIBUTE2,
			-- GENERICATTRIBUTE3
			C_TNX.TA_GENERICATTRIBUTE3 AS GENERICATTRIBUTE3,
			-- GENERICATTRIBUTE4
			C_TNX.TIPO_RECIBO AS GENERICATTRIBUTE4,
			-- GENERICATTRIBUTE5
			NULL AS GENERICATTRIBUTE5,
			-- GENERICATTRIBUTE6
			NULL AS GENERICATTRIBUTE6,
			-- GENERICATTRIBUTE7
			NULL AS GENERICATTRIBUTE7,
			-- GENERICATTRIBUTE8
			NULL AS GENERICATTRIBUTE8,
			-- GENERICATTRIBUTE9
			NULL AS GENERICATTRIBUTE9,
			-- GENERICATTRIBUTE10
			NULL AS GENERICATTRIBUTE10,
			-- GENERICATTRIBUTE11
			NULL AS GENERICATTRIBUTE11,
			-- GENERICATTRIBUTE12
			NULL AS GENERICATTRIBUTE12,
			-- GENERICATTRIBUTE13
			NULL AS GENERICATTRIBUTE13,
			-- GENERICATTRIBUTE14
			NULL AS GENERICATTRIBUTE14,
			-- GENERICATTRIBUTE15
			NULL AS GENERICATTRIBUTE15,
			-- GENERICATTRIBUTE16
			NULL AS GENERICATTRIBUTE16,
			-- GENERICNUMBER1
			TO_DECIMAL(C_TNX.VALOR_POLIZA,25,10) AS GENERICNUMBER1,
			-- UNITTYPEFORGENERICNUMBER1
			CASE 
			    WHEN C_TNX.VALOR_POLIZA IS NOT NULL 
			        THEN CONST_TIPO_EURO
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER1,
			-- GENERICNUMBER2
			TO_DECIMAL(C_TNX.KILOMETROS,25,10) AS GENERICNUMBER2,
			-- UNITTYPEFORGENERICNUMBER2
			CASE 
			    WHEN C_TNX.KILOMETROS IS NOT NULL 
			        THEN CONST_TIPO_QUANTITY
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER2,
			-- GENERICNUMBER3
			TO_DECIMAL(C_TNX.PRIMA_BRUTA_RECIBO,25,10) AS GENERICNUMBER3,
			-- UNITTYPEFORGENERICNUMBER3
			CASE 
			    WHEN C_TNX.PRIMA_BRUTA_RECIBO IS NOT NULL 
			        THEN CONST_TIPO_EURO
			    ELSE NULL
			END AS UNITTYPEFORGENERICNUMBER3,
			-- GENERICNUMBER4
			IFNULL(vr_tipo_agente_insp,0) AS GENERICNUMBER4,
			-- UNITTYPEFORGENERICNUMBER4
			CONST_TIPO_INTEGER AS UNITTYPEFORGENERICNUMBER4,
			-- GENERICNUMBER5
			IFNULL(vr_tipo_agente_an5,0) AS GENERICNUMBER5,
			-- UNITTYPEFORGENERICNUMBER5
			-- CASE 
			--     WHEN vr_tipo_agente_an5 IS NOT NULL 
			--         THEN CONST_TIPO_INTEGER
			--     ELSE NULL
			-- END AS UNITTYPEFORGENERICNUMBER5,
			CONST_TIPO_INTEGER AS UNITTYPEFORGENERICNUMBER5,
			-- GENERICNUMBER6
			NULL AS GENERICNUMBER6,
			-- UNITTYPEFORGENERICNUMBER6
			NULL AS UNITTYPEFORGENERICNUMBER6,
			-- GENERICDATE1
			C_TNX.FECHA_EFECTO_RECIBO AS GENERICDATE1,
			-- GENERICDATE2
			NULL AS GENERICDATE2,
			-- GENERICDATE3
			NULL AS GENERICDATE3,
			-- GENERICDATE4
			NULL AS GENERICDATE4,
			-- GENERICDATE5
			NULL AS GENERICDATE5,
			-- GENERICDATE6
			NULL AS GENERICDATE6,
			-- GENERICBOOLEAN1
			CASE 
			    WHEN C_TNX.POLIZA_CON_AGENTE IS NULL OR TRIM(C_TNX.POLIZA_CON_AGENTE) = '' 
			        THEN '0'
			    ELSE C_TNX.POLIZA_CON_AGENTE
			END AS GENERICBOOLEAN1,
			-- GENERICBOOLEAN2
			CASE 
			    WHEN C_TNX.PRIMER_RECIBO IS NULL OR TRIM(C_TNX.PRIMER_RECIBO) = '' 
			        THEN '0'
			    ELSE C_TNX.PRIMER_RECIBO
			END AS GENERICBOOLEAN2,
			-- GENERICBOOLEAN3
			NULL AS GENERICBOOLEAN3,
			-- GENERICBOOLEAN4
			NULL AS GENERICBOOLEAN4,
			-- GENERICBOOLEAN5
			NULL AS GENERICBOOLEAN5,
			-- GENERICBOOLEAN6
			NULL AS GENERICBOOLEAN6,
			--campos necesarios para las condiciones de insercion de transaccion
			MARCA_CUENTA,
			PERMANENCIA,
			-- POSITIONNAME,
			CODIGO_RECIBO,
			RAMO,
			CODIGO_PRODUCTO,
			TIPO_RECUPERACION,
			PORCENTAJE_COMISION_CALCULAD,
			IMPORTE_COMISION,
			ES_PERMANENCIA_20,
			CODIGO_AGENTE_ZONA,
			TIPO_RECIBO,
			--campos necesarios para calcular otros campos
			LINE,
			POSITIONNAME_20,
			OFICINA_COBRADORA,
			POSITIONNAME_16,
			FECHA_COMPENSACION,
			INSPECTOR
		FROM :TBL_C_TXN_CALCULADO_6 C_TNX 
	);
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_TRANSACTIONASSIGN filas:  ' || v_num_rows || ' filas', v_log_count, v_idproceso, 'info');
	
	
	  ------------------------------JGE 20251016 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_TRANSACTIONASSIGN_INICIAL_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_TRANSACTIONASSIGN_INICIAL_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_TRANSACTIONASSIGN_INICIAL_DEBUG AS (SELECT * FROM :TBL_C_CURSOR_AGENTE_TIPOLOGIA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_TRANSACTIONASSIGN_INICIAL_DEBUG' , v_log_count, v_idproceso, 'debug');
    ------------------------------
	
	
	--insertarmos si no existe en salestransaction
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX SALESTRANSACTION- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
		
		INSERT INTO EXT.SALESTRANSACTION
			SELECT 
				SRC.TENANTID,
				EXT.SEQSTAGESALESTRANSACTION.NEXTVAL,
				SRC.BATCHNAME, SRC.FILE_IN_RECIBOS, 
				SRC.ORDERID, SRC.LINENUMBER, SRC.SUBLINENUMBER, SRC.EVENTTYPEID, 
				SRC.SALESTRANSACTIONSEQ, SRC.SALESORDERSEQ, SRC.ACCOUNTINGDATE, SRC.PRODUCTID, 
				SRC.PRODUCTNAME, SRC.PRODUCTDESCRIPTION, SRC.VALUE, SRC.UNITTYPEFORVALUE, 
				SRC.NUMBEROFUNITS, SRC.UNITVALUE, SRC.UNITTYPEFORUNITVALUE, SRC.COMPENSATIONDATE, 
				SRC.PAYMENTTERMS, SRC.PONUMBER, SRC.CHANNEL, SRC.ALTERNATEORDERNUMBER, 
				SRC.DATASOURCE, SRC.NATIVECURRENCY, SRC.NATIVECURRENCYAMOUNT, SRC.DISCOUNTPERCENT, 
				SRC.DISCOUNTTYPE, SRC.BILLTOCUSTID, SRC.BILLTOCONTACT, SRC.BILLTOCOMPANY, 
				SRC.BILLTOAREACODE, SRC.BILLTOPHONE, SRC.BILLTOFAX, SRC.BILLTOADDRESS1, 
				SRC.BILLTOADDRESS2, SRC.BILLTOADDRESS3, SRC.BILLTOCITY, SRC.BILLTOSTATE, 
				SRC.BILLTOCOUNTRY, SRC.BILLTOPOSTALCODE, SRC.BILLTOINDUSTRY, SRC.BILLTOGEOGRAPHY, 
				SRC.SHIPTOCUSTID, SRC.SHIPTOCONTACT, SRC.SHIPTOCOMPANY, SRC.SHIPTOAREACODE, 
				SRC.SHIPTOPHONE, SRC.SHIPTOFAX, SRC.SHIPTOADDRESS1, SRC.SHIPTOADDRESS2, 
				SRC.SHIPTOADDRESS3, SRC.SHIPTOCITY, SRC.SHIPTOSTATE, SRC.SHIPTOCOUNTRY, 
				SRC.SHIPTOPOSTALCODE, SRC.SHIPTOINDUSTRY, SRC.SHIPTOGEOGRAPHY, SRC.OTHERTOCUSTID, 
				SRC.OTHERTOCONTACT, SRC.OTHERTOCOMPANY, SRC.OTHERTOAREACODE, SRC.OTHERTOPHONE, 
				SRC.OTHERTOFAX, SRC.OTHERTOADDRESS1, SRC.OTHERTOADDRESS2, SRC.OTHERTOADDRESS3, 
				SRC.OTHERTOCITY, SRC.OTHERTOSTATE, SRC.OTHERTOCOUNTRY, SRC.OTHERTOPOSTALCODE, 
				SRC.OTHERTOINDUSTRY, SRC.OTHERTOGEOGRAPHY, SRC.REASONID, SRC.COMMENTS, 
				SRC.STAGEPROCESSDATE, SRC.STAGEPROCESSFLAG, SRC.BUSINESSUNITNAME, SRC.BUSINESSUNITMAP, 
				SRC.GENERICATTRIBUTE1, SRC.GENERICATTRIBUTE2, SRC.GENERICATTRIBUTE3, 
				SRC.GENERICATTRIBUTE4, SRC.GENERICATTRIBUTE5, SRC.GENERICATTRIBUTE6, 
				SRC.GENERICATTRIBUTE7, SRC.GENERICATTRIBUTE8, SRC.GENERICATTRIBUTE9, 
				SRC.GENERICATTRIBUTE10, SRC.GENERICATTRIBUTE11, SRC.GENERICATTRIBUTE12, 
				SRC.GENERICATTRIBUTE13, SRC.GENERICATTRIBUTE14, SRC.GENERICATTRIBUTE15, 
				SRC.GENERICATTRIBUTE16, SRC.GENERICATTRIBUTE17, SRC.GENERICATTRIBUTE18, 
				SRC.GENERICATTRIBUTE19, SRC.GENERICATTRIBUTE20, SRC.GENERICATTRIBUTE21, 
				SRC.GENERICATTRIBUTE22, SRC.GENERICATTRIBUTE23, SRC.GENERICATTRIBUTE24, 
				SRC.GENERICATTRIBUTE25, SRC.GENERICATTRIBUTE26, SRC.GENERICATTRIBUTE27, 
				SRC.GENERICATTRIBUTE28, SRC.GENERICATTRIBUTE29, SRC.GENERICATTRIBUTE30, 
				SRC.GENERICATTRIBUTE31, SRC.GENERICATTRIBUTE32, SRC.GENERICNUMBER1, 
				SRC.UNITTYPEFORGENERICNUMBER1, SRC.GENERICNUMBER2, SRC.UNITTYPEFORGENERICNUMBER2, 
				SRC.GENERICNUMBER3, SRC.UNITTYPEFORGENERICNUMBER3, SRC.GENERICNUMBER4, 
				SRC.UNITTYPEFORGENERICNUMBER4, SRC.GENERICNUMBER5, SRC.UNITTYPEFORGENERICNUMBER5, 
				SRC.GENERICNUMBER6, SRC.UNITTYPEFORGENERICNUMBER6, SRC.GENERICDATE1, 
				SRC.GENERICDATE2, SRC.GENERICDATE3, SRC.GENERICDATE4, SRC.GENERICDATE5, 
				SRC.GENERICDATE6, SRC.GENERICBOOLEAN1, SRC.GENERICBOOLEAN2, SRC.GENERICBOOLEAN3, 
				SRC.GENERICBOOLEAN4, SRC.GENERICBOOLEAN5, SRC.GENERICBOOLEAN6, SRC.STAGEERRORCODE, 
				SRC.COMPENSATIONDATE_OLD, SRC.PUSEQ_OLD
			FROM :TBL_SALESTRANSACTION SRC
			WHERE (SRC.POSITIONNAME <> CONST_NO_ENCONTRADO OR SRC.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP,CONST_COD_RECIBO_ANUL_RRTT,CONST_COD_RECIBO_ANUL_SERCO) or SRC.CODIGO_RECIBO like '%_A')
			AND (SRC.MARCA_CUENTA = CONST_S)
			AND ((SRC.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND SRC.RAMO = CONST_RAMA_RRTT
            AND ((IFNULL(SRC.PORCENTAJE_COMISION_CALCULAD,0) <> 0) OR IFNULL(SRC.IMPORTE_COMISION,0) <> 0)) 
                OR (SRC.PERMANENCIA <> CONST_RECIBOS_CARTERA_81) 
                OR (SRC.RAMO IN (CONST_RAMA_RRGG,CONST_RAMA_RRPP)) 
                OR (SRC.CODIGO_PRODUCTO LIKE '0122%')
                OR (SRC.TIPO_RECUPERACION IS NOT NULL)
                OR (SRC.CODIGO_PRODUCTO LIKE '0129%23'))
        	AND (SRC.PERMANENCIA <> '0')
        	AND NOT EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = SRC.ORDERID
				AND EXISTE.SUBLINENUMBER = SRC.SUBLINENUMBER
				AND EXISTE.LINENUMBER = SRC.LINENUMBER
				AND EXISTE.EVENTTYPEID = SRC.EVENTTYPEID
			);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;			
		--insertamos en transactionassign si no existe
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX TRANSACTIONASSIGN- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
		
			INSERT INTO EXT.TRANSACTIONASSIGN
			SELECT 
				SRC.TENANTID, SRC.STAGESALESTRANSACTIONSEQ, SRC.SETNUMBER, SRC.BATCHNAME, SRC.FILE_IN_RECIBOS, SRC.ORDERID,
				SRC.LINENUMBER, SRC.SUBLINENUMBER, SRC.EVENTTYPEID, SRC.SALESTRANSACTIONSEQ, SRC.PAYEEID, SRC.PAYEETYPE,
				SRC.POSITIONNAME,
				SRC.TITLENAME, SRC.GENERICATTRIBUTE1, SRC.GENERICATTRIBUTE2, SRC.GENERICATTRIBUTE3, 
				(CASE WHEN SRC.EVENTTYPEID <> '81' THEN '' ELSE SRC.GENERICATTRIBUTE4 END),
				SRC.GENERICATTRIBUTE5, SRC.GENERICATTRIBUTE6, SRC.GENERICATTRIBUTE7, SRC.GENERICATTRIBUTE8, SRC.GENERICATTRIBUTE9, SRC.GENERICATTRIBUTE10,
				SRC.GENERICATTRIBUTE11, SRC.GENERICATTRIBUTE12, SRC.GENERICATTRIBUTE13, SRC.GENERICATTRIBUTE14, SRC.GENERICATTRIBUTE15, SRC.GENERICATTRIBUTE16,
				SRC.GENERICNUMBER1, SRC.UNITTYPEFORGENERICNUMBER1, SRC.GENERICNUMBER2, SRC.UNITTYPEFORGENERICNUMBER2, SRC.GENERICNUMBER3, SRC.UNITTYPEFORGENERICNUMBER3,
				IFNULL(SRC.GENERICNUMBER4,0), SRC.UNITTYPEFORGENERICNUMBER4, IFNULL(SRC.GENERICNUMBER5,0), SRC.UNITTYPEFORGENERICNUMBER5, SRC.GENERICNUMBER6, SRC.UNITTYPEFORGENERICNUMBER6,
				SRC.GENERICDATE1, SRC.GENERICDATE2, SRC.GENERICDATE3, SRC.GENERICDATE4, SRC.GENERICDATE5, SRC.GENERICDATE6,
				SRC.GENERICBOOLEAN1, SRC.GENERICBOOLEAN2, SRC.GENERICBOOLEAN3, SRC.GENERICBOOLEAN4, SRC.GENERICBOOLEAN5, SRC.GENERICBOOLEAN6
			FROM :TBL_TRANSACTIONASSIGN SRC
			WHERE (SRC.POSITIONNAME <> CONST_NO_ENCONTRADO OR SRC.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP,CONST_COD_RECIBO_ANUL_RRTT,CONST_COD_RECIBO_ANUL_SERCO) or SRC.CODIGO_RECIBO like '%_A')
			AND (SRC.MARCA_CUENTA = CONST_S)
			AND ((SRC.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND SRC.RAMO = CONST_RAMA_RRTT
                AND ((IFNULL(SRC.PORCENTAJE_COMISION_CALCULAD,0) <> 0) OR IFNULL(SRC.IMPORTE_COMISION,0) <> 0)) 
                    OR (SRC.PERMANENCIA <> CONST_RECIBOS_CARTERA_81) 
                    OR (SRC.RAMO IN (CONST_RAMA_RRGG,CONST_RAMA_RRPP)) 
                    OR (SRC.CODIGO_PRODUCTO LIKE '0122%')
                    OR (SRC.TIPO_RECUPERACION IS NOT NULL)
                    OR (SRC.CODIGO_PRODUCTO LIKE '0129%23'))
            AND (SRC.PERMANENCIA <> '0')
            AND NOT EXISTS ( 
				SELECT 1 
				FROM EXT.TRANSACTIONASSIGN EXISTE
				WHERE EXISTE.ORDERID = SRC.ORDERID
				AND EXISTE.SUBLINENUMBER = SRC.SUBLINENUMBER
				AND EXISTE.LINENUMBER = SRC.LINENUMBER
				AND EXISTE.EVENTTYPEID = SRC.EVENTTYPEID
			);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN ' || v_num_rows , v_log_count, v_idproceso, 'info');
		
	END;
	
	
	--INSERTAMOS LAS TRANSACCIONES 20
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX TIPO 20 SALESTRANSACTION- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
	
		--SALESTRANSACTION TIPO 20
		INSERT INTO EXT.SALESTRANSACTION (
			SELECT
				ST.TENANTID, EXT.SEQSTAGESALESTRANSACTION.NEXTVAL, ST.BATCHNAME, ST.FILE_IN_RECIBOS, 
				ST.ORDERID, TO_BIGINT(CASE WHEN ST.RAMO = CONST_RAMA_RRTT THEN (ST.LINE || ST.PERMANENCIA) ELSE ST.LINENUMBER END) AS LINENUMBER, 
				ST.SUBLINENUMBER, CONST_RECIBOS_ESPECIFICOS_20 AS EVENTTYPEID, 
				ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, 
				TO_DECIMAL(CASE 
				    WHEN ST.RAMO IN (CONST_RAMA_RRGG, CONST_RAMA_RRPP) THEN 
				        CASE 
				            WHEN ST.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66, CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_65) THEN 0
				            ELSE IFNULL(ST.PRIMA_NETA_RECIBO, 0) + IFNULL(ST.RECARGO, 0)
				        END
				    ELSE 
				        CASE 
				            WHEN ST.PRIMA_NETA_RECIBO IS NOT NULL THEN COALESCE(ST.PRIMA_NETA_RECIBO, 0)
				            ELSE 0
				        END
				END,25,10) AS VALUE, ST.UNITTYPEFORVALUE, 0 AS NUMBEROFUNITS, 0 AS UNITVALUE, :CONST_TIPO_QUANTITY AS UNITTYPEFORUNITVALUE, ST.COMPENSATIONDATE, 
				(CASE WHEN v_tipo_agente in (12,6) THEN '0' ELSE ST.PAYMENTTERMS END) AS PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
				ST.DATASOURCE, CONST_TIPO_EURO AS NATIVECURRENCY, 0 AS NATIVECURRENCYAMOUNT, 0 AS DISCOUNTPERCENT, 
				CONST_TIPO_PERCENTAGE AS DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
				ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, 
				ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
				ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, 
				ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
				ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, 
				ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
				ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, 
				ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
				ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, 
				ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
				ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, 
				ST.STAGEPROCESSDATE, ST.STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
				ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, 
				ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, 
					--TGV 20260415 -- Por peticion de comercial los tipo 16 nunca pueden ser ni S ni N
				CASE	WHEN ST.GENERICATTRIBUTE6 = CONST_RECIBO_EMITIDO_SINFIRMAR THEN CONST_RECIBO_EMITIDO
						WHEN  ST.GENERICATTRIBUTE6 = CONST_RECIBO_COBRADO_SINFIRMAR THEN CONST_RECIBO_COBRADO
						ELSE  ST.GENERICATTRIBUTE6 END , 
				---ST.GENERICATTRIBUTE6,
				ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, 
				ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
				0 AS GENERICATTRIBUTE13, 0 AS GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, 
				ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
				ST.GENERICATTRIBUTE19, 0 AS GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, 
				ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
				CASE 
				    WHEN 
				        (
				            SUBSTR(ST.CODIGO_PRODUCTO, 1, 5) IN ('01502', '01503') OR 
				            SUBSTR(ST.CODIGO_PRODUCTO, 1, 6) LIKE '015012%' OR 
				            ST.FILE_NAME LIKE '%OBLFTPSOL%' OR 
				            ST.FILE_NAME LIKE '%SOLNE%'
				        ) AND
				        ST.PERMANENCIA IN (CONST_RECIBOS_CARTERA_72, CONST_RECIBOS_CARTERA_81) AND
				        SUBSTR(ST.CODIGO_POLIZA, LENGTH(ST.CODIGO_POLIZA)-1, LENGTH(ST.CODIGO_POLIZA)) IN ('X', 'S')
				    THEN CONST_TIPO_REC_ANUL_K5
				    ELSE ST.GENERICATTRIBUTE25
				END AS GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, 
				ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
				ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, 
				TO_DECIMAL(CASE WHEN ST.RAMO IN (CONST_RAMA_RRGG,CONST_RAMA_RRPP) AND 
	                ST.PERMANENCIA in (CONST_RECIBOS_ESPECIFICOS_66,CONST_RECIBOS_ESPECIFICOS_71,CONST_RECIBOS_ESPECIFICOS_65) THEN 0 ELSE ST.GENERICNUMBER1 END,25,10) AS GENERICNUMBER1, 
				CONST_TIPO_EURO AS UNITTYPEFORGENERICNUMBER1, 
				TO_DECIMAL(CASE 
				    WHEN ST.RAMO IN (CONST_RAMA_RRGG, CONST_RAMA_RRPP) 
				         AND ST.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66, CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_65)
				    THEN 0
				    ELSE ST.PRIMA_NETA_RECIBO
				END,25,10) AS GENERICNUMBER2, 
				CASE 
				    WHEN ST.RAMO IN (CONST_RAMA_RRGG, CONST_RAMA_RRPP) 
				         AND ST.PERMANENCIA IN (CONST_RECIBOS_ESPECIFICOS_66, CONST_RECIBOS_ESPECIFICOS_71, CONST_RECIBOS_ESPECIFICOS_65)
				    THEN CONST_TIPO_EURO
				    WHEN ST.PRIMA_NETA_RECIBO IS NOT NULL
				    THEN CONST_TIPO_EURO
				    ELSE NULL
				END AS UNITTYPEFORGENERICNUMBER2, 
				ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, 
				ST.UNITTYPEFORGENERICNUMBER4, 0 AS GENERICNUMBER5, CONST_TIPO_PERCENTAGE AS UNITTYPEFORGENERICNUMBER5, 
				ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, 
				ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
				ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, 
				ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
				ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
			FROM :TBL_SALESTRANSACTION ST
			WHERE /*EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = ST.ORDERID
				AND EXISTE.SUBLINENUMBER = ST.SUBLINENUMBER
				AND EXISTE.LINENUMBER = ST.LINENUMBER
				AND EXISTE.EVENTTYPEID = ST.EVENTTYPEID
			)
			AND*/ ST.ES_PERMANENCIA_20 = CONST_S
			
	
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION TIPO-20 ' || v_num_rows , v_log_count, v_idproceso, 'info');
	
	END;
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX TIPO 20 TRANSACTIONASSIGN- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;	
		--TRANSACTIONASSIGN TIPO 20
		INSERT INTO EXT.TRANSACTIONASSIGN 
		(
			SELECT 	
				TA.TENANTID, TA.STAGESALESTRANSACTIONSEQ, TA.SETNUMBER, TA.BATCHNAME, TA.FILE_IN_RECIBOS, TA.ORDERID,
				TO_BIGINT(CASE WHEN TA.RAMO = CONST_RAMA_RRTT THEN TA.LINE || TA.PERMANENCIA ELSE TA.LINENUMBER END) AS LINENUMBER, 
				TA.SUBLINENUMBER, CONST_RECIBOS_ESPECIFICOS_20 AS EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
				TA.POSITIONNAME_20 AS POSITIONNAME, TA.TITLENAME, 
				(CASE 
				    WHEN TA.GENERICATTRIBUTE3 NOT LIKE '%999999' 
				    THEN TA.GENERICATTRIBUTE3 
				    ELSE TA.GENERICATTRIBUTE1 
				END) AS GENERICATTRIBUTE1, 
				TA.GENERICATTRIBUTE2, SUBSTR('000' || TA.OFICINA_COBRADORA,LENGTH('000' || TA.OFICINA_COBRADORA)-3,4) || '999999' AS GENERICATTRIBUTE3, 
				TA.GENERICATTRIBUTE4,TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, 
				TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
				TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
				TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
				TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
				TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
				TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
			FROM :TBL_TRANSACTIONASSIGN TA 
			WHERE /*EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = TA.ORDERID
				AND EXISTE.SUBLINENUMBER = TA.SUBLINENUMBER
				AND EXISTE.LINENUMBER = TA.LINENUMBER
				AND EXISTE.EVENTTYPEID = TA.EVENTTYPEID
			)
			AND*/ TA.ES_PERMANENCIA_20 = CONST_s
		);
			
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN TIPO-20 ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;
	
	
	-- TRANSACCTIONES TIPO 16
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar SALESTRANSACTION TIPO 16 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
		-- SALETRANSACTION16
		INSERT INTO EXT.SALESTRANSACTION
		(
			SELECT
				ST.TENANTID, EXT.SEQSTAGESALESTRANSACTION.NEXTVAL, ST.BATCHNAME, ST.FILE_IN_RECIBOS, 
				ST.ORDERID, TO_BIGINT(CASE WHEN ST.RAMO = CONST_RAMA_RRTT THEN (ST.LINE || ST.PERMANENCIA) ELSE ST.LINENUMBER END) AS LINENUMBER, 
				ST.SUBLINENUMBER, CONST_RECIBOS_ESPECIFICOS_16 AS EVENTTYPEID, 
				ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, 
				ST.VALUE, ST.UNITTYPEFORVALUE, ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ST.COMPENSATIONDATE, 
				(CASE WHEN v_tipo_agente in ('12','6') THEN '0' ELSE ST.PAYMENTTERMS END) AS PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
				ST.DATASOURCE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, 
				ST.DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
				ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, 
				ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
				ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, 
				ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
				ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, 
				ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
				ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, 
				ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
				ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, 
				ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
				ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, 
				ST.STAGEPROCESSDATE, ST.STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
				ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, 
				ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5,
				--ST.GENERICATTRIBUTE6,
				--TGV 20260415 -- Por peticion de comercial los tipo 16 nunca pueden ser ni S ni N
				CASE	WHEN ST.GENERICATTRIBUTE6 = CONST_RECIBO_EMITIDO_SINFIRMAR THEN CONST_RECIBO_EMITIDO
						WHEN  ST.GENERICATTRIBUTE6 = CONST_RECIBO_COBRADO_SINFIRMAR THEN CONST_RECIBO_COBRADO
						ELSE  ST.GENERICATTRIBUTE6 END , ---ST.GENERICATTRIBUTE6,
				ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, 
				ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
				ST.GENERICATTRIBUTE13, ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, 
				ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
				ST.GENERICATTRIBUTE19, 0 AS GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, 
				ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
				ST.GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, 
				ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
				ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, 
				ST.GENERICNUMBER1, 
				ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, 
				ST.UNITTYPEFORGENERICNUMBER2, 
				ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, 
				ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, 
				ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, 
				ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
				ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, 
				ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
				ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
			FROM :TBL_SALESTRANSACTION ST 
			WHERE /*EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = ST.ORDERID
				AND EXISTE.SUBLINENUMBER = ST.SUBLINENUMBER
				AND EXISTE.LINENUMBER = ST.LINENUMBER
				AND EXISTE.EVENTTYPEID = ST.EVENTTYPEID
			)
			AND*/ TRIM(ST.CODIGO_AGENTE_ZONA) IS NOT NULL 
			AND TRIM(ST.CODIGO_AGENTE_ZONA) <> ''
			AND ST.POSITIONNAME_16 <> :CONST_NO_ENCONTRADO
			AND LENGTH(EXT.LIB_GLOBAL:limpiar_campo(ST.CODIGO_AGENTE_ZONA)) > 0
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION TIPO-16 ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;
		
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRANSACTIONASSIGN TIPO-16 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;	
		--TRANSACTIONASSIGN 16
		
		INSERT INTO EXT.TRANSACTIONASSIGN
		(
			SELECT 
				TA.TENANTID, TA.STAGESALESTRANSACTIONSEQ, TA.SETNUMBER, TA.BATCHNAME, TA.FILE_IN_RECIBOS, TA.ORDERID,
				TO_BIGINT(CASE WHEN TA.RAMO = CONST_RAMA_RRTT THEN (TA.LINE || TA.PERMANENCIA) ELSE TA.LINENUMBER END) AS LINENUMBER, 
				TA.SUBLINENUMBER, CONST_RECIBOS_ESPECIFICOS_16 AS EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
				TA.POSITIONNAME_16,
				TA.TITLENAME, 
				TA.GENERICATTRIBUTE1, 
				TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3, 
				TA.GENERICATTRIBUTE4,TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, 
				TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
				TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
				TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
				TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
				TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
				TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
			FROM :TBL_TRANSACTIONASSIGN TA 
			WHERE /*EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = TA.ORDERID
				AND EXISTE.SUBLINENUMBER = TA.SUBLINENUMBER
				AND EXISTE.LINENUMBER = TA.LINENUMBER
				AND EXISTE.EVENTTYPEID = TA.EVENTTYPEID
			)
			AND*/ TRIM(TA.CODIGO_AGENTE_ZONA) IS NOT NULL 
			AND TRIM(TA.CODIGO_AGENTE_ZONA) <> ''
			AND TA.POSITIONNAME_16 <> :CONST_NO_ENCONTRADO
			AND LENGTH(EXT.LIB_GLOBAL:limpiar_campo(TA.CODIGO_AGENTE_ZONA)) > 0
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN TIPO-16 ' || v_num_rows , v_log_count, v_idproceso, 'info');
		
	END;
	
	--BAJAS RRGG
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar SALESTRANSACTION BAJAS RRGG - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;

		INSERT INTO EXT.SALESTRANSACTION 
		(
			SELECT 
				ST.TENANTID, EXT.SEQSTAGESALESTRANSACTION.NEXTVAL, 'BAJAS_RRGG_' || to_char(ST.FECHA_COMPENSACION,'yyyymm') || '01' AS BATCHNAME, ST.FILE_IN_RECIBOS, ST.ORDERID||'_BB' AS ORDERID,
				ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID, 
				ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, 
				ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, ST.VALUE, ST.UNITTYPEFORVALUE, 
				ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ST.COMPENSATIONDATE, 
				ST.PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
				ST.DATASOURCE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, 
				ST.DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
				ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, 
				ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
				ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, 
				ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
				ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, 
				ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
				ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, 
				ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
				ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, 
				ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
				ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, 
				ST.STAGEPROCESSDATE, ST.STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
				ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, 
				ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, ST.ESTADO_RECIBO_DEF AS GENERICATTRIBUTE6, 
				ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, 
				ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
				ST.GENERICATTRIBUTE13, ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, 
				ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
				ST.GENERICATTRIBUTE19, ST.GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, 
				ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
				ST.GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, 
				ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
				ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, ST.GENERICNUMBER1, 
				ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, ST.UNITTYPEFORGENERICNUMBER2, 
				ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, 
				ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, 
				ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, 
				ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
				ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, 
				ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
				ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
			FROM :TBL_SALESTRANSACTION ST 
			WHERE EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = ST.ORDERID
				AND EXISTE.SUBLINENUMBER = ST.SUBLINENUMBER
				AND EXISTE.LINENUMBER = ST.LINENUMBER
				AND EXISTE.EVENTTYPEID = ST.EVENTTYPEID
			)	
			AND ST.SUBLINENUMBER = 1
			AND (ST.RAMO = CONST_RAMA_RRGG OR ST.RAMO = CONST_RAMA_RRPP)
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION BAJAS RRGG ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRANSACTIONASSIGN BAJAS RRGG - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
		INSERT INTO EXT.TRANSACTIONASSIGN 
		(
			SELECT 
				TA.TENANTID, TA.STAGESALESTRANSACTIONSEQ, TA.SETNUMBER, 'BAJAS_RRGG_' || to_char(TA.FECHA_COMPENSACION,'yyyymm') || '01' AS BATCHNAME, TA.FILE_IN_RECIBOS, TA.ORDERID||'_BB' AS ORDERID,
				TA.LINENUMBER, 
				TA.SUBLINENUMBER, TA.EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
				TA.POSITIONNAME,
				TA.TITLENAME, 
				TA.GENERICATTRIBUTE1, 
				TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3, 
				TA.GENERICATTRIBUTE4,TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, 
				TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
				TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
				TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
				TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
				TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
				TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
			FROM :TBL_TRANSACTIONASSIGN TA
			WHERE EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = TA.ORDERID
				AND EXISTE.SUBLINENUMBER = TA.SUBLINENUMBER
				AND EXISTE.LINENUMBER = TA.LINENUMBER
				AND EXISTE.EVENTTYPEID = TA.EVENTTYPEID
			)	
			AND TA.SUBLINENUMBER = 1
			AND (TA.RAMO = CONST_RAMA_RRGG OR TA.RAMO = CONST_RAMA_RRPP)
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN BAJAS RRGG ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;	
		
	--BAJAS RRTT
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK; 
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX BAJAS RRTT SALESTRANSACTION - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
		INSERT INTO EXT.SALESTRANSACTION 
		(
			SELECT 
				ST.TENANTID, EXT.SEQSTAGESALESTRANSACTION.NEXTVAL, 'BAJAS_RRTT_' || to_char(ST.FECHA_COMPENSACION,'yyyymm') || '01' AS BATCHNAME, ST.FILE_IN_RECIBOS, 
				SUBSTR(ST.ORDERID,1,LENGTH(ST.ORDERID)-1) || 'B' AS ORDERID,
				ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID, 
				ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, 
				ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, ST.VALUE, ST.UNITTYPEFORVALUE, 
				ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ST.COMPENSATIONDATE, 
				ST.PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
				ST.DATASOURCE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, 
				ST.DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
				ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, 
				ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
				ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, 
				ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
				ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, 
				ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
				ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, 
				ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
				ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, 
				ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
				ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, 
				ST.STAGEPROCESSDATE, ST.STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
				ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, 
				ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, ST.ESTADO_RECIBO_DEF AS GENERICATTRIBUTE6, 
				ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, 
				ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
				ST.GENERICATTRIBUTE13, ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, 
				ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
				ST.GENERICATTRIBUTE19, ST.GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, 
				ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
				ST.GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, 
				ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
				ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, ST.GENERICNUMBER1, 
				ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, ST.UNITTYPEFORGENERICNUMBER2, 
				ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, 
				ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, 
				ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, 
				ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
				ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, 
				ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
				ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
			FROM :TBL_SALESTRANSACTION ST 
			WHERE EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = ST.ORDERID
				AND EXISTE.SUBLINENUMBER = ST.SUBLINENUMBER
				AND EXISTE.LINENUMBER = ST.LINENUMBER
				AND EXISTE.EVENTTYPEID = ST.EVENTTYPEID
			)	
			AND ST.SUBLINENUMBER = 1
			AND ST.RAMO = CONST_RAMA_RRTT
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION BAJAS RRTT ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK; 
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX BAJAS RRTT TRANSACTIONASSIGN - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
			
		INSERT INTO EXT.TRANSACTIONASSIGN 
		(
			SELECT 
				TA.TENANTID, TA.STAGESALESTRANSACTIONSEQ, TA.SETNUMBER, 'BAJAS_RRTT_' || to_char(TA.FECHA_COMPENSACION,'yyyymm') || '01' AS BATCHNAME, TA.FILE_IN_RECIBOS,
				SUBSTR(TA.ORDERID,1,LENGTH(TA.ORDERID)-1) || 'B' AS ORDERID,
				TA.LINENUMBER, 
				TA.SUBLINENUMBER, TA.EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
				TA.POSITIONNAME,
				TA.TITLENAME, 
				TA.GENERICATTRIBUTE1, 
				TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3, 
				TA.GENERICATTRIBUTE4,TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, 
				TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
				TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
				TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
				TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
				TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
				TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
			FROM :TBL_TRANSACTIONASSIGN TA
			WHERE EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = TA.ORDERID
				AND EXISTE.SUBLINENUMBER = TA.SUBLINENUMBER
				AND EXISTE.LINENUMBER = TA.LINENUMBER
				AND EXISTE.EVENTTYPEID = TA.EVENTTYPEID
			)	
			AND TA.SUBLINENUMBER = 1
			AND TA.RAMO = CONST_RAMA_RRTT
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN BAJAS RRTT ' || v_num_rows , v_log_count, v_idproceso, 'info');
		
	END;
	
	-- TRASREHA SOLNET COBRADO
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX TRASHERA SALESTRANSACTION- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
		INSERT INTO EXT.SALESTRANSACTION 
		(
			SELECT 
				ST.TENANTID, EXT.SEQSTAGESALESTRANSACTION.NEXTVAL, 'TRASREHA_' || to_char(ST.FECHA_COMPENSACION,'yyyymm') || '01' AS BATCHNAME, ST.FILE_IN_RECIBOS, 
				SUBSTR(ST.ORDERID,1,LENGTH(ST.ORDERID)-1) || '_R' AS ORDERID,
				ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID, 
				ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, 
				ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, ST.VALUE, ST.UNITTYPEFORVALUE, 
				ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ST.COMPENSATIONDATE, 
				ST.PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
				ST.DATASOURCE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, 
				ST.DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
				ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, 
				ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
				ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, 
				ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
				ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, 
				ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
				ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, 
				ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
				ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, 
				ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
				ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, 
				ST.STAGEPROCESSDATE, ST.STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
				ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, 
				ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, ST.ESTADO_RECIBO_DEF AS GENERICATTRIBUTE6, 
				ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, 
				ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
				ST.GENERICATTRIBUTE13, ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, 
				ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
				ST.GENERICATTRIBUTE19, ST.GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, 
				ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
				ST.GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, 
				ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
				ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, ST.GENERICNUMBER1, 
				ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, ST.UNITTYPEFORGENERICNUMBER2, 
				ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, 
				ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, 
				ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, 
				ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
				ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, 
				ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
				ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
			FROM :TBL_SALESTRANSACTION ST 
			WHERE EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = ST.ORDERID
				AND EXISTE.SUBLINENUMBER = ST.SUBLINENUMBER
				AND EXISTE.LINENUMBER = ST.LINENUMBER
				AND EXISTE.EVENTTYPEID = ST.EVENTTYPEID
			)	
			AND ST.TIPO_RECIBO = 'TRASREHA'
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION TRASREHA SOLNET COBRADO ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;	
		
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error al Insertar TRX TRASHERA TRANSACTIONASSIGN- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
		INSERT INTO EXT.TRANSACTIONASSIGN 
		(
			SELECT 
				TA.TENANTID, TA.STAGESALESTRANSACTIONSEQ, TA.SETNUMBER, 'TRASREHA_' || to_char(TA.FECHA_COMPENSACION,'yyyymm') || '01' AS BATCHNAME, TA.FILE_IN_RECIBOS,
				SUBSTR(TA.ORDERID,1,LENGTH(TA.ORDERID)-1) || '_R' AS ORDERID,
				TA.LINENUMBER, 
				TA.SUBLINENUMBER, TA.EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
				TA.POSITIONNAME,
				TA.TITLENAME, 
				TA.GENERICATTRIBUTE1, 
				TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3, 
				TA.GENERICATTRIBUTE4,TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, 
				TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
				TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
				TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
				TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
				TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
				TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
			FROM :TBL_TRANSACTIONASSIGN TA
			WHERE EXISTS ( 
				SELECT 1 
				FROM EXT.SALESTRANSACTION EXISTE
				WHERE EXISTE.ORDERID = TA.ORDERID
				AND EXISTE.SUBLINENUMBER = TA.SUBLINENUMBER
				AND EXISTE.LINENUMBER = TA.LINENUMBER
				AND EXISTE.EVENTTYPEID = TA.EVENTTYPEID
			)	
			AND TA.TIPO_RECIBO = 'TRASREHA'
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN TRASREHA SOLNET COBRADO ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;	
	
	--BAJAS RRGG COBRADO
	IF (i_file_name LIKE ('%' || CONST_COBROS_RRGGRRPP_OCASO || '%') OR i_file_name LIKE ('%' || CONST_COBROS_RRGGRRPP_ETERNA || '%') OR i_file_name LIKE ('%' || CONST_COBROS_SOLNET_OCASO || '%' )) THEN
	
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK; 
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error UPDATE SALESTRANSACTION BAJAS RRGG COBRADO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					COMMIT;
					RESIGNAL;
				END;
					
			-- UPDATE EXT.SALESTRANSACTION T
			-- SET T.BATCHNAME = 'TXSTA_' || i_file_name	
			-- WHERE T.BATCHNAME = ('BAJAS_RRGG_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01)
			-- AND (CASE WHEN i_file_name LIKE '%' || CONST_COBROS_RRGGRRPP_OCASO || '%' THEN 1 
		 --             WHEN i_file_name LIKE '%' || CONST_COBROS_RRGGRRPP_ETERNA || '%' THEN 2 
		 --             WHEN i_file_name LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN 3 END) =
		 --       (CASE WHEN T.ORDERID LIKE '03%' THEN 2
		 --             WHEN T.ORDERID LIKE '015012%' OR T.ORDERID LIKE '01502%' OR T.ORDERID LIKE '01503%' OR T.BATCHNAME LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN 3
		 --             ELSE 1 END) 
		 --   AND NOT EXISTS (
		 --   	SELECT 1 FROM EXT.SALESTRANSACTION X
		 --   	WHERE X.ORDERID LIKE SUBSTR(T.ORDERID,1,20) || '%'
		 --   	AND (CASE WHEN X.BATCHNAME LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN SUBSTR(X.ORDERID,24,1) ELSE SUBSTR(X.ORDERID,23,1) END) IN ('S','X')
		 --                           --Solo comprobamos si ha llegado un K5 del 71
		 --                           AND X.EVENTTYPEID = CONST_RECIBOS_ESPECIFICOS_71
		 --                           --Incluimos un control por fecha de compensacion para comprobar si el K5 es el ultimo registro recibido para el recibo 71 de cada poliza.
		 --                           AND X.COMPENSATIONDATE > (
		 --                               SELECT MAX(Y.COMPENSATIONDATE) FROM EXT.SALESTRANSACTION Y
		 --                               WHERE Y.ORDERID LIKE SUBSTR(X.ORDERID,1,20) || '%'
		 --                                   AND NOT (CASE WHEN Y.BATCHNAME LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN SUBSTR(Y.ORDERID,24,1) ELSE SUBSTR(Y.ORDERID,23,1) END) IN ('S','X')
		 --                                   AND Y.EVENTTYPEID = '71'
		 --                                   AND Y.GENERICATTRIBUTE6 = 'C'
		 --                                   AND Y.SUBLINENUMBER <> 1
		 --                           )
		 --   );
			
			
			UPDATE EXT.SALESTRANSACTION T
			SET T.BATCHNAME = 'TXSTA_' || :i_file_name
			WHERE T.BATCHNAME = 'BAJAS_RRGG_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01
			AND (CASE WHEN SUBSTR(:i_file_name,1,8) =  'RECI' || :CONST_COBROS_RRGGRRPP_OCASO THEN 1 
		              WHEN SUBSTR(:i_file_name,1,8) =  'RECI' || :CONST_COBROS_RRGGRRPP_ETERNA THEN 2 
		              WHEN SUBSTR(:i_file_name,1,11) =  'RECI' || :CONST_COBROS_SOLNET_OCASO THEN 3 END) =
		        (CASE WHEN SUBSTR(T.ORDERID,1,2) = '03' THEN 2
		              WHEN SUBSTR(T.ORDERID,1,6) = '015012' OR SUBSTR(T.ORDERID,1,5) = '01502' OR SUBSTR(T.ORDERID,1,5) = '01503' /*OR T.BATCHNAME LIKE '%' || :CONST_COBROS_SOLNET_OCASO || '%'*/ THEN 3
		              ELSE 1 END) 
		    AND NOT EXISTS (
		    	SELECT 1 FROM EXT.SALESTRANSACTION X
		    	WHERE SUBSTR(X.ORDERID,1,20) = SUBSTR(T.ORDERID,1,20) --LIKE SUBSTR(T.ORDERID,1,20) || '%'
		    	AND (CASE WHEN SUBSTR(X.BATCHNAME,1,17)  = 'TXSTA_RECI'|| :CONST_COBROS_SOLNET_OCASO 
		    	 --20251126 - TGV - a�adimos control para los nombres de ficheros antiguo de ORACLE
		    	OR X.BATCHNAME LIKE '%'||:CONST_COBROS_SOLNET_OCASO ||'%'
		    			THEN SUBSTR(X.ORDERID,24,1) ELSE SUBSTR(X.ORDERID,23,1) END) IN ('S','X')
                --Solo comprobamos si ha llegado un K5 del 71
                AND X.EVENTTYPEID = :CONST_RECIBOS_ESPECIFICOS_71
                --Incluimos un control por fecha de compensacion para comprobar si el K5 es el ultimo registro recibido para el recibo 71 de cada poliza.
                AND X.COMPENSATIONDATE > (
                	SELECT MAX(Y.COMPENSATIONDATE) --INTO v_max_compensationdate
					FROM EXT.SALESTRANSACTION Y
			        WHERE SUBSTR(Y.ORDERID,1,20) = SUBSTR(X.ORDERID,1,20) --LIKE SUBSTR(X.ORDERID,1,20) || '%'
			            AND NOT (CASE WHEN SUBSTR(Y.BATCHNAME,1,17) = 'TXSTA_RECI'|| :CONST_COBROS_SOLNET_OCASO 
			             --20251126 - TGV - a�adimos control para los nombres de ficheros antiguo de ORACLE
			            OR X.BATCHNAME LIKE '%'||:CONST_COBROS_SOLNET_OCASO ||'%'
			            	THEN SUBSTR(Y.ORDERID,24,1) ELSE SUBSTR(Y.ORDERID,23,1) END) IN ('S','X') --LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN SUBSTR(Y.ORDERID,24,1) ELSE SUBSTR(Y.ORDERID,23,1) END) IN ('S','X')
			            AND Y.EVENTTYPEID = '71'
			            AND Y.GENERICATTRIBUTE6 = 'C'
			            AND Y.SUBLINENUMBER <> 1
                )
		    );
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin CARGA BAJAS_RRGG_COBRADO en SALESTRANSACTION: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK; 
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error UPDATE TRANSACTIONASSIGN BAJAS RRGG COBRADO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					COMMIT;
					RESIGNAL;
				END;
			
			-- UPDATE EXT.TRANSACTIONASSIGN T
			-- SET T.BATCHNAME = 'TXSTA_' || i_file_name
			-- WHERE T.BATCHNAME = 'BAJAS_RRGG_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01
			-- AND (CASE WHEN i_file_name LIKE '%' || CONST_COBROS_RRGGRRPP_OCASO || '%' THEN 1 
		 --             WHEN i_file_name LIKE '%' || CONST_COBROS_RRGGRRPP_ETERNA || '%' THEN 2 
		 --             WHEN i_file_name LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN 3 END) =
		 --       (CASE WHEN T.ORDERID LIKE '03%' THEN 2
		 --             WHEN T.ORDERID LIKE '015012%' OR T.ORDERID LIKE '01502%' OR T.ORDERID LIKE '01503%' OR T.BATCHNAME LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN 3
		 --             ELSE 1 END) 
		 --   AND NOT EXISTS (
		 --   	SELECT 1 FROM EXT.SALESTRANSACTION X
		 --   	WHERE X.ORDERID LIKE SUBSTR(T.ORDERID,1,20) || '%'
		 --   	AND (CASE WHEN X.BATCHNAME LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN SUBSTR(X.ORDERID,24,1) ELSE SUBSTR(X.ORDERID,23,1) END) IN ('S','X')
		 --                           --Solo comprobamos si ha llegado un K5 del 71
		 --                           AND X.EVENTTYPEID = CONST_RECIBOS_ESPECIFICOS_71
		 --                           --Incluimos un control por fecha de compensacion para comprobar si el K5 es el ultimo registro recibido para el recibo 71 de cada poliza.
		 --                           AND X.COMPENSATIONDATE > (
		 --                               SELECT MAX(Y.COMPENSATIONDATE) FROM EXT.SALESTRANSACTION Y
		 --                               WHERE Y.ORDERID LIKE SUBSTR(X.ORDERID,1,20) || '%'
		 --                                   AND NOT (CASE WHEN Y.BATCHNAME LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN SUBSTR(Y.ORDERID,24,1) ELSE SUBSTR(Y.ORDERID,23,1) END) IN ('S','X')
		 --                                   AND Y.EVENTTYPEID = '71'
		 --                                   AND Y.GENERICATTRIBUTE6 = 'C'
		 --                                   AND Y.SUBLINENUMBER <> 1
		 --                           )
		 --   );
		    
		    
		 --   MAX_COMPENSATIONDATE := (
		 --   	SELECT * 
		 --   	FROM EXT.SALESTRANSACTION Y
		 --   	WHERE (CASE WHEN SUBSTR(Y.BATCHNAME,1,17) = 'TXSTA_RECI' || :CONST_COBROS_SOLNET_OCASO THEN SUBSTR(Y.ORDERID,24,1) ELSE SUBSTR(Y.ORDERID,23,1) END) NOT IN ('S','X')
		 --   	AND Y.EVENTTYPEID = '71'
	  --          AND Y.GENERICATTRIBUTE6 = 'C'
	  --          AND Y.SUBLINENUMBER <> 1
		 --   );
		    
		    
		    
			UPDATE EXT.TRANSACTIONASSIGN T
			SET T.BATCHNAME = 'TXSTA_' || :i_file_name
			WHERE T.BATCHNAME = 'BAJAS_RRGG_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01
			AND (CASE WHEN SUBSTR(:i_file_name,1,8) =  'RECI' || :CONST_COBROS_RRGGRRPP_OCASO THEN 1 
		              WHEN SUBSTR(:i_file_name,1,8) =  'RECI' || :CONST_COBROS_RRGGRRPP_ETERNA THEN 2 
		              WHEN SUBSTR(:i_file_name,1,11) =  'RECI' || :CONST_COBROS_SOLNET_OCASO THEN 3 END) =
		        (CASE WHEN SUBSTR(T.ORDERID,1,2) = '03' THEN 2
		              WHEN SUBSTR(T.ORDERID,1,6) = '015012' OR SUBSTR(T.ORDERID,1,5) = '01502' OR SUBSTR(T.ORDERID,1,5) = '01503' /*OR T.BATCHNAME LIKE '%' || :CONST_COBROS_SOLNET_OCASO || '%'*/ THEN 3
		              ELSE 1 END) 
		    AND NOT EXISTS (
		    	SELECT 1 FROM EXT.SALESTRANSACTION X
		    	WHERE SUBSTR(X.ORDERID,1,20) = SUBSTR(T.ORDERID,1,20) --LIKE SUBSTR(T.ORDERID,1,20) || '%'
		    	AND (CASE WHEN SUBSTR(X.BATCHNAME,1,17)  = 'TXSTA_RECI'|| :CONST_COBROS_SOLNET_OCASO 
		    	 --20251126 - TGV - a�adimos control para los nombres de ficheros antiguo de ORACLE
		    	OR X.BATCHNAME LIKE '%'||:CONST_COBROS_SOLNET_OCASO ||'%'
		    		THEN SUBSTR(X.ORDERID,24,1) ELSE SUBSTR(X.ORDERID,23,1) END) IN ('S','X')
                --Solo comprobamos si ha llegado un K5 del 71
                AND X.EVENTTYPEID = :CONST_RECIBOS_ESPECIFICOS_71
                --Incluimos un control por fecha de compensacion para comprobar si el K5 es el ultimo registro recibido para el recibo 71 de cada poliza.
                AND X.COMPENSATIONDATE > (
                	SELECT MAX(Y.COMPENSATIONDATE) --INTO v_max_compensationdate
					FROM EXT.SALESTRANSACTION Y
			        WHERE SUBSTR(Y.ORDERID,1,20) = SUBSTR(X.ORDERID,1,20) --LIKE SUBSTR(X.ORDERID,1,20) || '%'
			            AND NOT (CASE WHEN SUBSTR(Y.BATCHNAME,1,17) = 'TXSTA_RECI'|| :CONST_COBROS_SOLNET_OCASO 
			            --20251126 - TGV - a�adimos control para los nombres de ficheros antiguo de ORACLE
			            OR X.BATCHNAME LIKE '%'||:CONST_COBROS_SOLNET_OCASO ||'%'
			            	THEN SUBSTR(Y.ORDERID,24,1) ELSE SUBSTR(Y.ORDERID,23,1) END) IN ('S','X') --LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' THEN SUBSTR(Y.ORDERID,24,1) ELSE SUBSTR(Y.ORDERID,23,1) END) IN ('S','X')
			            AND Y.EVENTTYPEID = '71'
			            AND Y.GENERICATTRIBUTE6 = 'C'
			            AND Y.SUBLINENUMBER <> 1
                )
		    );
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin CARGA BAJAS_RRGG_COBRADO en TRANSACTIONASSIGN: ' || v_num_rows , v_log_count, v_idproceso, 'info');
		END;	
	END IF;
	
	--TRASREHA_SOLNET_COBRADO
	IF (i_file_name LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%') THEN
	
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error UPDATE SALESTRANSACTION TRASREHA SOLNET COBRADO- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					COMMIT;
					RESIGNAL;
				END;
		
			UPDATE EXT.SALESTRANSACTION T 
			SET T.BATCHNAME = 'TXSTA_' || i_file_name
			WHERE T.BATCHNAME = 'TRASREHA_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin CARGA TRASREHA_SOLNET_COBRADO en SALESTRANSACTION: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
		END;
			
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error UPDATE TRANSACTIONASSIGN TRASREHA SOLNET COBRADO- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					COMMIT;
					RESIGNAL;
				END;	
			
			UPDATE EXT.TRANSACTIONASSIGN T 
			SET T.BATCHNAME = 'TXSTA_' || i_file_name
			WHERE T.BATCHNAME = 'TRASREHA_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin CARGA TRASREHA_SOLNET_COBRADO en TRANSACTIONASSIGN: ' || v_num_rows , v_log_count, v_idproceso, 'info');
		END;
	END IF;
	
	--POLIZAS SIN FIRMAR
	IF (i_file_name LIKE '%' || CONST_COBROS_SOLNET_OCASO || '%' ) THEN

		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error UPDATE SALESTRANSACTION POLIZAS SIN FIRMAR - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
		    -- Incluir las transacciones procedentes del cobrado del mes pasado y duplicadas para este mes en el fichero de cobrado del mes actual
			UPDATE EXT.SALESTRANSACTION T
			SET T.BATCHNAME = 'TXSTA_' || i_file_name
			WHERE T.BATCHNAME = 'POLIZAS_SIN_FIRMAR_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01
			;
			
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error UPDATE TRANSACTIONASSIGN POLIZAS SIN FIRMAR - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
			
			UPDATE EXT.TRANSACTIONASSIGN T 
			SET T.BATCHNAME = 'TXSTA_' || i_file_name
			WHERE T.BATCHNAME = 'POLIZAS_SIN_FIRMAR_' || REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'COBROS_SOLNET_OCASO Transacciones cobradas de meses pasados incluidas para este mes: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error Transacciones sin firmar duplicadas en SALESTRANSACTION para el siguiente mes - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
		
			-- Duplicamos la transsacciones N con fecha de compensacion y linenumber del mes siguiente
			INSERT INTO EXT.SALESTRANSACTION(
				SELECT
					ST.TENANTID, EXT.SEQSTAGESALESTRANSACTION.NEXTVAL, ST.BATCHNAME, ST.FILE_IN_RECIBOS, ST.ORDERID, 
					CASE WHEN SUBSTR(ST.LINENUMBER,5,2) = 12 THEN (ST.LINENUMBER + 89) ELSE (ST.LINENUMBER + 1) END, 
					ST.SUBLINENUMBER, ST.EVENTTYPEID, 
					ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, ST.VALUE, ST.UNITTYPEFORVALUE, 
					ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ADD_MONTHS(ST.COMPENSATIONDATE, 1), ST.PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
					ST.DATASOURCE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, ST.DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
					ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
					ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
					ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
					ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
					ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
					ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, ST.STAGEPROCESSDATE, ST.STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
					ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, ST.GENERICATTRIBUTE6, 
					ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
					ST.GENERICATTRIBUTE13, ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
					ST.GENERICATTRIBUTE19, ST.GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
					ST.GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
					ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, ST.GENERICNUMBER1, ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, ST.UNITTYPEFORGENERICNUMBER2, 
					ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, 
					ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
					ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
					ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
				FROM EXT.SALESTRANSACTION ST
				WHERE ST.GENERICATTRIBUTE6 = 'N'
				-- AND ST.BATCHNAME = 'TXSTA_' || i_file_name
				AND ST.COMPENSATIONDATE = TO_DATE(REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01, 'YYYYMMDD')
	            --Incidencias cierre, tenemos transacciones repetidas con estado firmado y no firmado a la vez
				AND NOT EXISTS (
					SELECT 1 FROM EXT.SALESTRANSACTION T
					WHERE T.ORDERID = ST.ORDERID
	                AND T.LINENUMBER = CASE WHEN SUBSTR(ST.LINENUMBER,5,2) = 12 THEN (ST.LINENUMBER + 89) ELSE (ST.LINENUMBER + 1) END
	                AND T.SUBLINENUMBER = ST.SUBLINENUMBER
	                AND T.EVENTTYPEID = ST.EVENTTYPEID
	                AND T.COMPENSATIONDATE = ADD_MONTHS(ST.COMPENSATIONDATE, 1) 
				)
			);
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Transacciones sin firmar duplicadas en SALESTRANSACTION para el siguiente mes: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error Transacciones sin firmar duplicadas en TRANSACTIONASSIGN para el siguiente mes - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
			
			INSERT INTO EXT.TRANSACTIONASSIGN  (
				SELECT 
					TA.TENANTID, TA.STAGESALESTRANSACTIONSEQ, TA.SETNUMBER, TA.BATCHNAME, TA.FILE_IN_RECIBOS, TA.ORDERID,
					CASE WHEN SUBSTR(TA.LINENUMBER,5,2) = 12 THEN (TA.LINENUMBER + 89) ELSE (ST.LINENUMBER + 1) END,
					TA.SUBLINENUMBER, TA.EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
					TA.POSITIONNAME, TA.TITLENAME, TA.GENERICATTRIBUTE1, TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3, TA.GENERICATTRIBUTE4,
					TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
					TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
					TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
					TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
					TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
					TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
				FROM EXT.TRANSACTIONASSIGN TA
				JOIN EXT.SALESTRANSACTION ST
					ON TA.ORDERID = ST.ORDERID
					AND TA.LINENUMBER = ST.LINENUMBER
			        AND TA.SUBLINENUMBER = ST.SUBLINENUMBER
			        AND TA.EVENTTYPEID = ST.EVENTTYPEID
			        AND ST.GENERICATTRIBUTE6 = 'N' 
			        -- AND ST.BATCHNAME = 'TXSTA_' || i_file_name
			        AND ST.COMPENSATIONDATE = TO_DATE(REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01, 'YYYYMMDD')
		        WHERE NOT EXISTS (
		        	SELECT 1 FROM EXT.TRANSACTIONASSIGN T
		        	WHERE T.ORDERID = TA.ORDERID
	                    AND T.LINENUMBER = CASE WHEN SUBSTR(TA.LINENUMBER,5,2) = 12 THEN (TA.LINENUMBER + 89) ELSE (TA.LINENUMBER + 1) END
	                    AND T.SUBLINENUMBER = TA.SUBLINENUMBER
	                    AND T.EVENTTYPEID = TA.EVENTTYPEID
		        )
		        -- AND TA.BATCHNAME = 'TXSTA_' || i_file_name
			);
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Transacciones sin firmar duplicadas en TRANSACTIONASSIGN para el siguiente mes: ' || v_num_rows , v_log_count, v_idproceso, 'info');
		
		END;
		
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error sin firmar duplicadas en CARTERA_DDEE para el siguiente mes - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;	
			--mantener funcionalidad en DDEE
			INSERT INTO EXT.CARTERA_DDEE
			(
				SELECT 
					CAR.ESTADO, NULL,CAR.FECHA_EFECTO,CAR.COD_SUPLEMENTO,CAR.FORMA_PAGO,
					CAR.ORDERID,CAR.SUBLINENUMBER,CASE WHEN SUBSTR(CAR.LINENUMBER,5,2) = 12 THEN (CAR.LINENUMBER + 89) ELSE (CAR.LINENUMBER + 1) END,
					CAR.EVENTTYPEID,ADD_MONTHS(CAR.COMPENSATIONDATE, 1),CAR.PRODUCTID,CAR.ACCOUNTINGDATE,CAR.VALUE,CAR.NATIVECURRENCYAMOUNT,CAR.DISCOUNTPERCENT,
                    CAR.POLIZA,CAR.PRIMA_NETA,CAR.FECHA_EMISION,CAR.POSITIONNAME,CAR.COD_AGENTE,CAR.FEC_VTO_REC,CAR.EVENTO,CAR.PRODUCTO,CAR.GARANTIA,CAR.IMPORTE,CAR.EARNINGCODEID,
                    CAR.EARNINGGROUPID,CAR.FILE_NAME,NULL
				FROM EXT.CARTERA_DDEE CAR
				WHERE CAR.ESTADO = 'N'
				AND CAR.COMPENSATIONDATE = TO_DATE(REPLACE(SUBSTR(v_fecha_compensacion,1,7),'-','') || 01, 'YYYYMMDD')
			);
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Registros sin firmar duplicadas en CARTERA_DDEE para el siguiente mes: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
			
		END;	
	END IF;
	
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE en TRANSACTIONASSIGN para igualar STAGESALESTRANSACTIONSEQ- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_genera_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND STATUS = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.GARANTIAS_RECIBO
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
				
				UPDATE EXT.RECIBOS
				SET ESTADO = :v_const_genera_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_calculo_status_ok
				;
			
				COMMIT;
				RESIGNAL;
			END;
	
	--hacer coincidir los stagesaletransactionseq para transactionassign
	    MERGE INTO EXT.TRANSACTIONASSIGN src
			USING (
				SELECT ST.ORDERID, ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID, ST.STAGESALESTRANSACTIONSEQ FROM EXT.SALESTRANSACTION ST
				WHERE ST.FILE_IN_RECIBOS = :i_file_name
			) x
			ON src.ORDERID = x.ORDERID AND src.LINENUMBER = x.LINENUMBER AND src.SUBLINENUMBER = x.SUBLINENUMBER AND src.EVENTTYPEID = x.EVENTTYPEID AND src.FILE_IN_RECIBOS = :i_file_name
			WHEN MATCHED THEN UPDATE 
				SET src.STAGESALESTRANSACTIONSEQ = x.STAGESALESTRANSACTIONSEQ
			;
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'stagesalestransactionseq igualados: ' || v_num_rows , v_log_count, v_idproceso, 'info');
		
	END;
	
	
	TBL_TIPO_AGENTE_PRINCIPAL_15 = (
		SELECT DISTINCT SRC.*
		FROM (
			SELECT IFNULL(A.TIPO_AGENTE_PRIN,0) AS TIPO_AGENTE_PRIN, 
					TA.*,
					--TGV 20260224: Control Bucle infinito.
					--SRC.INSPECTOR
				(CASE WHEN SRC.INSPECTOR <> TA.GENERICATTRIBUTE3 THEN SRC.INSPECTOR END) AS INSPECTOR
			FROM EXT.TRANSACTIONASSIGN TA
			LEFT JOIN :TBL_GEN_CODIGOS_AGENTE A
			ON TA.POSITIONNAME = A.CODIGO_UNICO
			LEFT JOIN :TBL_TRANSACTIONASSIGN SRC
			ON TA.ORDERID = SRC.ORDERID
			AND TA.SUBLINENUMBER = SRC.SUBLINENUMBER
			WHERE TA.FILE_IN_RECIBOS = :i_file_name
			AND A.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion)
            AND A.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
		) SRC
		WHERE TIPO_AGENTE_PRIN = 15
	);

	
 --   TBL_TIPO_AGENTE_PRINCIPAL_15 = (
 --   SELECT *
 --   FROM (
	--         SELECT 
	--             TA.*,
	--             SRC.INSPECTOR,
	--             (
	--                 SELECT MAX(T.TIPO_AGENTE_PRIN)
	--                 FROM :TBL_GEN_CODIGOS_AGENTE T
	--                 WHERE T.CODIGO_UNICO = TA.POSITIONNAME
	--                   AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
	--                   AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
	--             ) AS TIPO_AGENTE_PRIN
	--         FROM EXT.TRANSACTIONASSIGN TA
	--         LEFT JOIN :TBL_TRANSACTIONASSIGN SRC
	--             ON TA.ORDERID = SRC.ORDERID
	--             AND TA.SUBLINENUMBER = SRC.SUBLINENUMBER
	--         AND TA.FILE_IN_RECIBOS = :i_file_name
 --   	) AS SUB
 --   WHERE SUB.TIPO_AGENTE_PRIN = 15
	-- );
    
	v_num_rows := RECORD_COUNT(:TBL_TIPO_AGENTE_PRINCIPAL_15);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Creada tabla temporal TBL_TIPO_AGENTE_PRINCIPAL_15, filas : ' || v_num_rows , v_log_count, v_idproceso, 'debug');
	
	----------------------------------------
	--COMENTAR EN PRD
	SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_TIPO_AGENTE_PRINCIPAL_15_INI_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_TIPO_AGENTE_PRINCIPAL_15_INI_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_TIPO_AGENTE_PRINCIPAL_15_INI_DEBUG AS (SELECT * FROM :TBL_TIPO_AGENTE_PRINCIPAL_15);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_TIPO_AGENTE_PRINCIPAL_15_INI_DEBUG' , v_log_count, v_idproceso, 'debug');
	 ----------------------------------------
	
	--ACTUALIZAR POSITIONNAME A MANAGERS PARA AGENTES TIPO 15
	WHILE (v_num_rows > 0) DO
	
		BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE para actualizaci�n de POSITIONNAME AGENTES TIPO 15 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
	
			TBL_EXISTE_MANAGER_PARA_AGENTE_TIPO_15 = (
				SELECT TA.ORDERID, TA.SUBLINENUMBER, TA.LINENUMBER, TA.EVENTTYPEID, ST.GENERICDATE2, ST.COMPENSATIONDATE, TA.GENERICATTRIBUTE3, TA.INSPECTOR, ST.GENERICATTRIBUTE20, TA.POSITIONNAME,
						(
							SELECT COUNT(*) 
							FROM TCMP.CS_POSITION POS
							WHERE POS.RULEELEMENTOWNERSEQ = (
	                            SELECT MAX(T.MANAGERSEQ)
	                            FROM :TBL_GEN_CODIGOS_AGENTE T
	                            WHERE T.CODIGO_UNICO = TA.POSITIONNAME
	                                AND T.EFFECTIVESTARTDATE <= CASE WHEN TA.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) ELSE LAST_DAY(ST.GENERICDATE2) END
	                                AND T.EFFECTIVEENDDATE > CASE WHEN TA.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) ELSE LAST_DAY(ST.GENERICDATE2) END
                        	)
	                        AND POS.EFFECTIVESTARTDATE <= LAST_DAY(ST.COMPENSATIONDATE)
	                        AND POS.EFFECTIVEENDDATE > LAST_DAY(ST.COMPENSATIONDATE)
	                        --AND POS.TENANTID = 'G204'
	                        AND POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
	                        --20251125 TGV- quitamos para que no excluya el TTL_SIN_PLAN
	                        --AND POS.TITLESEQ <> 5629499534213290
						) AS EXISTE_MANAGER
				FROM :TBL_TIPO_AGENTE_PRINCIPAL_15 TA
				INNER JOIN EXT.SALESTRANSACTION ST
				ON TA.ORDERID = ST.ORDERID
				AND TA.SUBLINENUMBER = ST.SUBLINENUMBER
				AND TA.LINENUMBER = ST.LINENUMBER
				AND TA.EVENTTYPEID = ST.EVENTTYPEID
				AND ST.FILE_IN_RECIBOS = :i_file_name
				-- WHERE TA.TIPO_AGENTE_PRIN = 15
			);
			v_num_rows := RECORD_COUNT(:TBL_EXISTE_MANAGER_PARA_AGENTE_TIPO_15);
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Creada tabla temporal TBL_EXISTE_MANAGER_PARA_AGENTE_TIPO_15, filas : ' || v_num_rows , v_log_count, v_idproceso, 'debug');
			
			TBL_FINAL_CON_DATOS_A_ACTUALIZAR = (
				SELECT SRC.*,
					(CASE WHEN SRC.EXISTE_MANAGER > 0 
						THEN
							IFNULL(
								(SELECT POS.NAME
								FROM TCMP.CS_POSITION POS
								WHERE POS.RULEELEMENTOWNERSEQ = (
		                            SELECT MAX(T.MANAGERSEQ)
		                            FROM :TBL_GEN_CODIGOS_AGENTE T
		                            WHERE T.CODIGO_UNICO = SRC.POSITIONNAME
		                                AND T.EFFECTIVESTARTDATE <= CASE WHEN SRC.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) ELSE LAST_DAY(SRC.GENERICDATE2) END
		                                AND T.EFFECTIVEENDDATE > CASE WHEN SRC.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) ELSE LAST_DAY(SRC.GENERICDATE2) END
	                        	)
		                        AND POS.EFFECTIVESTARTDATE <= LAST_DAY(SRC.COMPENSATIONDATE)
		                        AND POS.EFFECTIVEENDDATE > LAST_DAY(SRC.COMPENSATIONDATE)
		                        --AND POS.TENANTID = 'INYC'
		                        AND POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
		                        --20251125 TGV- quitamos para que no excluya el TTL_SIN_PLAN
		                        --AND POS.TITLESEQ <> 5629499534213290
									
								)
							,:CONST_NO_ENCONTRADO)
							
						ELSE
							
							IFNULL(
								(SELECT MAX(X.CODIGO_UNICO)
								FROM (
									SELECT T.CODIGO_UNICO
									, ROW_NUMBER() OVER (
				                        PARTITION BY T.CODIGO_OCASO
				                        ORDER BY T.EFFECTIVEENDDATE DESC
				                            , CASE WHEN SRC.GENERICATTRIBUTE3 = T.CODIGO_OCASO
				                                THEN 1
				                                ELSE 2
				                            END ASC) AS ROW_NUM_COD_UNI
									FROM :TBL_GEN_CODIGOS_AGENTE T
									WHERE T.CODIGO_OCASO = SRC.INSPECTOR
								) T INNER JOIN :TBL_GEN_CODIGOS_AGENTE X ON X.CODIGO_UNICO = T.CODIGO_UNICO
								WHERE T.ROW_NUM_COD_UNI = 1)
							,:CONST_NO_ENCONTRADO)
					END) AS POSITIONNAME_MANAGER, 
					-- (CASE WHEN EXISTE_MANAGER > 0 THEN SRC.GENERICATTRIBUTE3 ELSE SRC.GENERICATTRIBUTE3 END) AS TA_GENERICATTRIBUTE1,
					(CASE WHEN EXISTE_MANAGER > 0 
						THEN 
							IFNULL(
								(SELECT POS.GENERICATTRIBUTE3
								FROM TCMP.CS_POSITION POS
								WHERE POS.RULEELEMENTOWNERSEQ = 
								(
		                            SELECT MAX(T.MANAGERSEQ)
		                            FROM :TBL_GEN_CODIGOS_AGENTE T
		                            WHERE T.CODIGO_UNICO = SRC.POSITIONNAME
		                                AND T.EFFECTIVESTARTDATE <= LAST_DAY(SRC.GENERICDATE2) 
		                                AND T.EFFECTIVEENDDATE > LAST_DAY(SRC.GENERICDATE2)
	                        	)
		                        AND POS.EFFECTIVESTARTDATE <= LAST_DAY(SRC.COMPENSATIONDATE)
		                        AND POS.EFFECTIVEENDDATE > LAST_DAY(SRC.COMPENSATIONDATE)
		                        --AND POS.TENANTID = 'INYC'
		                        AND POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
		                        --20251125 TGV- quitamos para que no excluya el TTL_SIN_PLAN
		                       -- AND POS.TITLESEQ <> 5629499534213290
								)
							,:CONST_NO_ENCONTRADO)
						ELSE SRC.INSPECTOR
					END) AS TA_GENERICATTRIBUTE3,
					(CASE WHEN EXISTE_MANAGER > 0 THEN SRC.GENERICATTRIBUTE20 ELSE '1' END) AS ST_GENERICATTRIBUTE20
				FROM :TBL_EXISTE_MANAGER_PARA_AGENTE_TIPO_15 SRC
			);
			v_num_rows := RECORD_COUNT(:TBL_FINAL_CON_DATOS_A_ACTUALIZAR);
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Creada tabla temporal TBL_FINAL_CON_DATOS_A_ACTUALIZAR, filas : ' || v_num_rows , v_log_count, v_idproceso, 'debug');
			
			UPDATE EXT.TRANSACTIONASSIGN TA
			SET TA.POSITIONNAME = SRC.POSITIONNAME_MANAGER, 
				TA.GENERICATTRIBUTE3 = SRC.TA_GENERICATTRIBUTE3,
				TA.GENERICATTRIBUTE1 = SRC.GENERICATTRIBUTE3
			FROM  EXT.TRANSACTIONASSIGN TA
			JOIN :TBL_FINAL_CON_DATOS_A_ACTUALIZAR SRC
			ON TA.ORDERID = SRC.ORDERID
				AND TA.SUBLINENUMBER = SRC.SUBLINENUMBER
				AND TA.LINENUMBER = SRC.LINENUMBER
				AND TA.EVENTTYPEID = SRC.EVENTTYPEID 
			WHERE TA.FILE_IN_RECIBOS = :i_file_name;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name, v_vueltas || ' - UPDATE TRANSACTIONASSIGN MANAGERS: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
			UPDATE EXT.SALESTRANSACTION ST
			SET ST.GENERICATTRIBUTE20 = SRC.ST_GENERICATTRIBUTE20
			FROM  EXT.SALESTRANSACTION ST
			JOIN :TBL_FINAL_CON_DATOS_A_ACTUALIZAR SRC
			ON ST.ORDERID = SRC.ORDERID
				AND ST.SUBLINENUMBER = SRC.SUBLINENUMBER
				AND ST.LINENUMBER = SRC.LINENUMBER
				AND ST.EVENTTYPEID = SRC.EVENTTYPEID 
			WHERE ST.FILE_IN_RECIBOS = :i_file_name;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name, v_vueltas || ' - UPDATE SALESTRANSACTION MANAGERS: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
			-- UPDATE EXT.TRANSACTIONASSIGN TA
			-- SET (TA.POSITIONNAME, TA.GENERICATTRIBUTE3, TA.GENERICATTRIBUTE2) = (
				
			-- 	SELECT IFNULL(MAX(POS.NAME), CONST_NO_ENCONTRADO), IFNULL(MAX(POS.GENERICATTRIBUTE3), CONST_NO_ENCONTRADO) , TA.GENERICATTRIBUTE3
			-- 	FROM TCMP.CS_POSITION POS
			-- 	WHERE POS.RULEELEMENTOWNERSEQ = (
			-- 		SELECT MAX(P.MANAGERSEQ) FROM :TBL_GEN_CODIGOS_AGENTE P
			-- 		WHERE P.CODIGO_UNICO = TA.POSITIONNAME
   --                 AND P.EFFECTIVESTARTDATE <= CASE WHEN TA.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) 
   --                 							ELSE LAST_DAY((SELECT MAX(R.FECHA_EMISION_REC)  FROM EXT.RECIBOS R WHERE SUBSTR(R.CODIGO_POLIZA,1,21) = SUBSTR(TA.ORDERID,1,21) AND R.FILE_NAME = :i_file_name)) END
   --                 AND P.EFFECTIVEENDDATE > CASE WHEN TA.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) 
   --                 							ELSE LAST_DAY((SELECT MAX(R.FECHA_EMISION_REC)  FROM EXT.RECIBOS R WHERE SUBSTR(R.CODIGO_POLIZA,1,21) = SUBSTR(TA.ORDERID,1,21) AND R.FILE_NAME = :i_file_name)) END
			-- 	)
   --             AND POS.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion)
   --             AND POS.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
   --             AND POS.TENANTID = :v_tenantid
   --             AND POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
   --             -- No tenemos en cuenta las Position de manager que no tengan plan (TTL_SIN_PLAN).
   --             AND POS.TITLESEQ <> 5629499534213290
                
			-- )
			-- WHERE (
			-- 		SELECT MAX(T.TIPO_AGENTE_PRIN) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_UNICO = TA.POSITIONNAME 
			-- 		AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
		 --           AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
			-- 	) = 15 
			-- AND FILE_IN_RECIBOS = :i_file_name;
		
			-- v_num_rows := ::rowcount;
			-- CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name, v_vueltas || ' - POSITIONNAMEs actualizados a MANAGERS: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			v_vueltas := v_vueltas + 1;
			
			--TGV 20260224 - v_vueltas sirve para ir haciendo saltos de jerarquia, no	es la cantidad de vueltas que va a dar el bucle.
			IF (v_vueltas = 10) THEN
				SIGNAL SQL_ERROR_CODE 10001
		    	SET MESSAGE_TEXT = 'Error: salida del bucle forzada, el bucle es infinito';
		    	--break;
			END IF;
			
			TBL_TIPO_AGENTE_PRINCIPAL_15 = (
				SELECT DISTINCT SRC.*
				FROM (
					SELECT IFNULL(A.TIPO_AGENTE_PRIN,0) AS TIPO_AGENTE_PRIN, 
							TA.*,
							--TGV 20260224: Control Bucle infinito.
							--SRC.INSPECTOR
							(CASE WHEN SRC.INSPECTOR <> TA.GENERICATTRIBUTE3 THEN SRC.INSPECTOR END) AS INSPECTOR
					FROM EXT.TRANSACTIONASSIGN TA
					LEFT JOIN :TBL_GEN_CODIGOS_AGENTE A
					ON TA.POSITIONNAME = A.CODIGO_UNICO
					LEFT JOIN :TBL_TRANSACTIONASSIGN SRC
					ON TA.ORDERID = SRC.ORDERID
					AND TA.SUBLINENUMBER = SRC.SUBLINENUMBER
					WHERE TA.FILE_IN_RECIBOS = :i_file_name
					AND A.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion)
		            AND A.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
				) SRC
				WHERE TIPO_AGENTE_PRIN = 15
			);
			
			-- TBL_TIPO_AGENTE_PRINCIPAL_15 = (
			--     SELECT *
			--     FROM (
			-- 	        SELECT 
			-- 	            TA.*,
			-- 	            SRC.INSPECTOR,
			-- 	            (
			-- 	                SELECT MAX(T.TIPO_AGENTE_PRIN)
			-- 	                FROM :TBL_GEN_CODIGOS_AGENTE T
			-- 	                WHERE T.CODIGO_UNICO = TA.POSITIONNAME
			-- 	                  AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
			-- 	                  AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
			-- 	            ) AS TIPO_AGENTE_PRIN
			-- 	        FROM EXT.TRANSACTIONASSIGN TA
			-- 	        LEFT JOIN :TBL_TRANSACTIONASSIGN SRC
			-- 	            ON TA.ORDERID = SRC.ORDERID
			-- 	            AND TA.SUBLINENUMBER = SRC.SUBLINENUMBER
			--     	) AS SUB
			--     WHERE SUB.TIPO_AGENTE_PRIN = 15
			-- );
			v_num_rows := RECORD_COUNT(:TBL_TIPO_AGENTE_PRINCIPAL_15);
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Regenerar tabla temporal TBL_TIPO_AGENTE_PRINCIPAL_15, filas : ' || v_num_rows , v_log_count, v_idproceso, 'debug');
			
			 ----------------------------------------
			--COMENTAR EN PRD
			SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_TIPO_AGENTE_PRINCIPAL_15_DEBUG';
			
			IF v_existe_tabla > 0 THEN
				DROP TABLE EXT.TBL_TIPO_AGENTE_PRINCIPAL_15_DEBUG;
			END IF;
			
			CREATE TABLE EXT.TBL_TIPO_AGENTE_PRINCIPAL_15_DEBUG AS (SELECT * FROM :TBL_TIPO_AGENTE_PRINCIPAL_15);
		    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_TIPO_AGENTE_PRINCIPAL_15_DEBUG' , v_log_count, v_idproceso, 'debug');
			 ----------------------------------------
			
			
		END;
	
	END WHILE;
	
	TBL_TIPO_AGENTE_PRINCIPAL_15 = SELECT * FROM :TBL_TIPO_AGENTE_PRINCIPAL_15 WHERE 1=0;
	TBL_EXISTE_MANAGER_PARA_AGENTE_TIPO_15 = SELECT * FROM :TBL_EXISTE_MANAGER_PARA_AGENTE_TIPO_15 WHERE 1=0;
	TBL_FINAL_CON_DATOS_A_ACTUALIZAR = SELECT * FROM :TBL_FINAL_CON_DATOS_A_ACTUALIZAR WHERE 1=0;
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE para actualizaci�n CODIGO_OCASO AGENTES TIPO 16 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
	
	--ACTUALIZAMOS CODIGO_OCASO DE LAS TIPO 16 CON EL MANAGER BIEN ASIGNADO
		UPDATE EXT.TRANSACTIONASSIGN TA
		SET (TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3) = (
			SELECT IFNULL(MAX(CODIGO_OCASO), CONST_NO_ENCONTRADO), IFNULL(MAX(CODIGO_OCASO), CONST_NO_ENCONTRADO) FROM :TBL_GEN_CODIGOS_AGENTE WHERE CODIGO_UNICO = TA.POSITIONNAME
		)
		WHERE TA.EVENTTYPEID = '16'
		AND FILE_IN_RECIBOS = :i_file_name
		;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'CODIGO_OCASO actualizado para tipo 16: ' || v_num_rows , v_log_count, v_idproceso, 'info');	
	
	END;
	
	--JGE 20250822 faltaba esta parte, falta de probar
	--COMPROBACION AGENTE DERECHOS ECONOMICOS
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE SALESTRANSACTION para DDEE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
			
			
			UPDATE EXT.SALESTRANSACTION ST
			SET GENERICATTRIBUTE20 = CASE 
									WHEN (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN '1'
									ELSE ST.GENERICATTRIBUTE20
									END,
				BATCHNAME = CASE	--JGE 20251112 este IFNULL en permanencia solo tiene que ir para campos que NO se modifiquen a posteriori en las 20 o 16 en oracle y en el batchname, al ser un left join, las 20 y 16 tienen ese valor null 
									WHEN (IFNULL(C_TNX.PERMANENCIA,TA.EVENTTYPEID) <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN ST.BATCHNAME
									WHEN EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN 'DE_'|| ST.BATCHNAME
									ELSE ST.BATCHNAME
									END
				--20250827: Incluimos PAYMENTTERMS
				, PAYMENTTERMS = CASE 
									WHEN (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN '13'
									ELSE 
										CASE WHEN TA.EVENTTYPEID IN ('20','16') THEN ST.PAYMENTTERMS ELSE '12' END
									END
			FROM EXT.TRANSACTIONASSIGN TA
			JOIN SALESTRANSACTION ST
			ON TA.ORDERID = ST.ORDERID
			AND TA.LINENUMBER = ST.LINENUMBER
			AND TA.SUBLINENUMBER = ST.SUBLINENUMBER
			AND TA.EVENTTYPEID = ST.EVENTTYPEID
			LEFT JOIN :TBL_C_TXN_CALCULADO_6 C_TNX
			ON TA.ORDERID = (
								CASE 
									WHEN RIGHT(TA.ORDERID,3) = '_BB' THEN C_TNX.ORDERID || '_BB' 
									WHEN RIGHT(TA.ORDERID,1) = 'B' THEN C_TNX.ORDERID || 'B' 
									WHEN RIGHT(TA.ORDERID,2) = '_R' THEN C_TNX.ORDERID || '_R' 
									ELSE C_TNX.ORDERID
								END
							)
			AND TA.LINENUMBER = TO_BIGINT(C_TNX.LINE)
			AND TA.SUBLINENUMBER = C_TNX.SUBLINENUMBER
			AND TA.EVENTTYPEID = C_TNX.EVENTTYPEID
			WHERE (
					SELECT MAX(T.TIPO_AGENTE) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_UNICO = TA.POSITIONNAME 
					AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
		            AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
				--) IN (12,6) 
				--20260406 TGV -- Por peticion de comercial se eliminan los tipo 6 corredores en derechos
				--) IN (12) 
			) = 12
			AND TA.FILE_IN_RECIBOS = :i_file_name
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'COMPROBACION AGENTE DERECHOS ECONOMICOS, filas actualizadas SALESTRANSACTION_ : ' || v_num_rows , v_log_count, v_idproceso, 'info');	
	
	END;
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE TRANSACTIONASSIGN para DDEE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
	
			UPDATE EXT.TRANSACTIONASSIGN TA
			SET POSITIONNAME = CASE 
									WHEN (SELECT COUNT(*) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_OCASO IN (C_TNX.INSPECTOR)) > 0 
									AND (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM TA.GENERICDATE1)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN
											(
												--20250827 RMF: Cambio en la b�squeda de CODIGO_UNICO por C_TNX.INSPECTOR
												--SELECT MAX(T.CODIGO_UNICO)
			                                	--FROM :TBL_GEN_CODIGOS_AGENTE T
			                                	--WHERE T.CODIGO_OCASO IN (C_TNX.INSPECTOR)
			                                	IFNULL(
													(SELECT MAX(X.CODIGO_UNICO) FROM (
														SELECT T.CODIGO_UNICO
														, ROW_NUMBER() OVER (
																--JGE 20251024 cambiamos la particion de codigo_unico por codigo_ocaso
								        						PARTITION BY T.CODIGO_OCASO
								        						ORDER BY T.EFFECTIVEENDDATE DESC
								        							, CASE WHEN C_TNX.INSPECTOR = T.CODIGO_OCASO
								        								THEN 1
								        								ELSE 2
								        							END ASC
								        					) AS ROW_NUM_COD_UNI 
														FROM :TBL_GEN_CODIGOS_AGENTE T
										                WHERE T.CODIGO_OCASO = C_TNX.INSPECTOR
													) X WHERE X.ROW_NUM_COD_UNI = 1 
												), TA.POSITIONNAME)
											)
											
									WHEN (SELECT COUNT(*) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_OCASO IN (C_TNX.INSPECTOR)) = 0 
									AND (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN 'NO_INSPECTOR'
									
									ELSE TA.POSITIONNAME
									END,
									
				GENERICATTRIBUTE4 =	CASE 
									WHEN (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN TA.POSITIONNAME
									ELSE TA.GENERICATTRIBUTE4
									END, 
									
				GENERICATTRIBUTE1 = CASE 
									WHEN (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN TA.GENERICATTRIBUTE3
									ELSE TA.GENERICATTRIBUTE1
									END,
									
				GENERICATTRIBUTE3 = CASE 
									WHEN (SELECT COUNT(*) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_OCASO IN (C_TNX.INSPECTOR)) > 0 
									AND (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN
											C_TNX.INSPECTOR
											
									WHEN (SELECT COUNT(*) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_OCASO IN (C_TNX.INSPECTOR)) = 0 
									AND (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN ''
									ELSE TA.GENERICATTRIBUTE3
									END,
									
				BATCHNAME = CASE	--JGE 20251112 este IFNULL en permanencia solo tiene que ir para campos que NO se modifiquen a posteriori y en el batchname en las 20 o 16 en oracle, al ser un left join, las 20 y 16 tienen ese valor null  
									WHEN (IFNULL(C_TNX.PERMANENCIA,TA.EVENTTYPEID) <> CONST_RECIBOS_CARTERA_81
										OR (C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND  EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(MONTH FROM C_TNX.FECHA_EFECTO_RECIBO) 
										AND EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_POLIZA) = EXTRACT(YEAR FROM C_TNX.FECHA_EFECTO_RECIBO)-1)
										)
									AND EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN TA.BATCHNAME
									WHEN EXTRACT(YEAR FROM :v_fecha_compensacion) >= '2022'
										THEN 'DE_'|| TA.BATCHNAME
									ELSE TA.BATCHNAME
									END
			FROM EXT.TRANSACTIONASSIGN TA
			LEFT JOIN :TBL_C_TXN_CALCULADO_6 C_TNX
			ON TA.ORDERID = (
								CASE 
									WHEN RIGHT(TA.ORDERID,3) = '_BB' THEN C_TNX.ORDERID || '_BB' 
									WHEN RIGHT(TA.ORDERID,1) = 'B' THEN C_TNX.ORDERID || 'B' 
									WHEN RIGHT(TA.ORDERID,2) = '_R' THEN C_TNX.ORDERID || '_R' 
									ELSE C_TNX.ORDERID
								END
							)
			AND TA.LINENUMBER = TO_BIGINT(C_TNX.LINE)
			AND TA.SUBLINENUMBER = C_TNX.SUBLINENUMBER
			AND TA.EVENTTYPEID = C_TNX.EVENTTYPEID
			WHERE (
					SELECT MAX(T.TIPO_AGENTE) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_UNICO = TA.POSITIONNAME 
					AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
		            AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
				--) IN (12,6) 
				--20260406 TGV -- Por peticion de comercial se eliminan los tipo 6 corredores en derechos
				--) IN (12) 
			) = 12
			AND TA.FILE_IN_RECIBOS = :i_file_name
			;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'COMPROBACION AGENTE DERECHOS ECONOMICOS, filas actualizadas TRANSACTIONASSIGN : ' || v_num_rows , v_log_count, v_idproceso, 'info');	

	END;
	
	--DERECHOS ECONOMICOS
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO TRATAMIENTO DDEE' , v_log_count, v_idproceso, 'info');
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE RECIBOS para DDEE ES_PERMANENCIA_20 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;

		UPDATE EXT.RECIBOS R SET R.ES_PERMANENCIA_20 = 'D'
		WHERE (R.CODIGO_POLIZA, R.ESTADO_RECIBO, R.CODIGO_RECIBO, R.CODIGO_SUPLEMENTO, R.FILE_NAME) IN
		(
			SELECT C_TNX.CODIGO_POLIZA, ST.GENERICATTRIBUTE6, ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE9, ST.FILE_IN_RECIBOS
			FROM EXT.SALESTRANSACTION ST
			JOIN :TBL_C_TXN_CALCULADO_6 C_TNX 
			ON ST.ORDERID = C_TNX.ORDERID
			AND ST.LINENUMBER = C_TNX.LINE
			AND ST.SUBLINENUMBER = C_TNX.SUBLINENUMBER
			AND ST.EVENTTYPEID = C_TNX.EVENTTYPEID
			--AND C_TNX.v_tipo_agente IN (12,6)
			--20260406 TGV -- Por peticion de comercial se eliminan los tipo 6 corredores en derechos
			--AND C_TNX.v_tipo_agente IN (12)
			AND C_TNX.v_tipo_agente = 12
			AND C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81
			--JGE 20250811 agregar condiciones que faltaban
			AND (C_TNX.POSITIONNAME <> CONST_NO_ENCONTRADO OR C_TNX.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP,CONST_COD_RECIBO_ANUL_RRTT,CONST_COD_RECIBO_ANUL_SERCO) or C_TNX.CODIGO_RECIBO like '%_A')
			AND (C_TNX.MARCA_CUENTA = CONST_S)
			AND ((C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND C_TNX.RAMO = CONST_RAMA_RRTT
	        AND ((IFNULL(C_TNX.PORCENTAJE_COMISION_CALCULAD,0) <> 0) OR IFNULL(C_TNX.IMPORTE_COMISION,0) <> 0)) 
	            OR (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81) 
	            OR (C_TNX.RAMO IN (CONST_RAMA_RRGG,CONST_RAMA_RRPP)) 
	            OR (C_TNX.CODIGO_PRODUCTO LIKE '0122%')
	            OR (C_TNX.TIPO_RECUPERACION IS NOT NULL)
	            OR (C_TNX.CODIGO_PRODUCTO LIKE '0129%23'))
	    	AND (C_TNX.PERMANENCIA <> '0')
			WHERE ST.FILE_IN_RECIBOS = :i_file_name
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'UPDATE ES_PERMANENCIA_20 EN RECIBOS: ' || v_num_rows , v_log_count, v_idproceso, 'info');
	
	END;
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en DELETE CARTERA_DDEE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
	
			DELETE FROM EXT.CARTERA_DDEE DDEE
			WHERE (DDEE.ORDERID, DDEE.LINENUMBER, DDEE.SUBLINENUMBER, DDEE.EVENTTYPEID) IN
			(
				SELECT ST.ORDERID, ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID
				FROM EXT.SALESTRANSACTION ST
				JOIN :TBL_C_TXN_CALCULADO_6 C_TNX 
				ON ST.ORDERID = C_TNX.ORDERID
				AND ST.LINENUMBER = C_TNX.LINE
				AND ST.SUBLINENUMBER = C_TNX.SUBLINENUMBER
				AND ST.EVENTTYPEID = C_TNX.EVENTTYPEID
				--AND C_TNX.v_tipo_agente IN (12,6)
				--20260406 TGV -- Por peticion de comercial se eliminan los tipo 6 corredores en derechos
				--AND C_TNX.v_tipo_agente IN (12)
				AND C_TNX.v_tipo_agente = 12
				AND C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81
				--JGE 20250811 agregar condiciones que faltaban
				AND (C_TNX.POSITIONNAME <> CONST_NO_ENCONTRADO OR C_TNX.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP,CONST_COD_RECIBO_ANUL_RRTT,CONST_COD_RECIBO_ANUL_SERCO) or C_TNX.CODIGO_RECIBO like '%_A')
				AND (C_TNX.MARCA_CUENTA = CONST_S)
				AND ((C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND C_TNX.RAMO = CONST_RAMA_RRTT
		        AND ((IFNULL(C_TNX.PORCENTAJE_COMISION_CALCULAD,0) <> 0) OR IFNULL(C_TNX.IMPORTE_COMISION,0) <> 0)) 
		            OR (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81) 
		            OR (C_TNX.RAMO IN (CONST_RAMA_RRGG,CONST_RAMA_RRPP)) 
		            OR (C_TNX.CODIGO_PRODUCTO LIKE '0122%')
		            OR (C_TNX.TIPO_RECUPERACION IS NOT NULL)
		            OR (C_TNX.CODIGO_PRODUCTO LIKE '0129%23'))
		    	AND (C_TNX.PERMANENCIA <> '0')
				WHERE ST.FILE_IN_RECIBOS = :i_file_name
			);
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin DELETE en CARTERA_DDEE: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
	END;
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en INSERT CARTERA_DDEE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
	
			INSERT INTO EXT.CARTERA_DDEE 
			(
				SELECT 
					ST.GENERICATTRIBUTE6    AS ESTADO,
					NULL                    AS SEQ_POST,
					ST.GENERICDATE1         AS FECHA_EFECTO,
		            ST.GENERICATTRIBUTE9    AS COD_SUPLEMENTO,
		            ST.GENERICATTRIBUTE2    AS FORMA_PAGO,
					ST.ORDERID				AS ORDERID,
		            ST.SUBLINENUMBER		AS SUBLINENUMBER,
		            ST.LINENUMBER			AS LINENUMBER,
		            ST.EVENTTYPEID			AS EVENTTYPEID,
		            ST.COMPENSATIONDATE		AS COMPENSATIONDATE,
		            ST.PRODUCTID			AS PRODUCTID,
		            ST.ACCOUNTINGDATE		AS ACCOUNTINGDATE,
		            IFNULL(ST.VALUE,0)		AS VALUE,
		            IFNULL(ST.NATIVECURRENCYAMOUNT,0) 
		            						AS NATIVECURRENCYAMOUNT,
		            IFNULL(ST.DISCOUNTPERCENT,0)
		            						AS DISCOUNTPERCENT,
		            ST.GENERICATTRIBUTE1    AS POLIZA,
		            ST.GENERICNUMBER1       AS PRIMA_NETA,
		            ST.GENERICDATE2         AS FECHA_EMISION,
		            (CASE WHEN ST.PAYMENTTERMS = '13' THEN TA.GENERICATTRIBUTE4 ELSE TA.POSITIONNAME END) AS POSITIONNAME,
		            (CASE WHEN ST.PAYMENTTERMS = '13' THEN TA.GENERICATTRIBUTE1 ELSE TA.GENERICATTRIBUTE3 END) AS COD_AGENTE,
		            TA.GENERICDATE1         AS FECHA_VTO_REC,
		            ET.DESCRIPTION          AS EVENTO,
		            PROD.GENERICATTRIBUTE5  AS PRODUCTO,
		            PROD.GENERICBOOLEAN1    AS GARANTIA,
		            IFNULL((CASE WHEN ST.GENERICATTRIBUTE13 = '1'
		                 THEN ST.NATIVECURRENCYAMOUNT
		                 ELSE (CASE WHEN ST.GENERICATTRIBUTE14 = '1' THEN (ST.VALUE * ST.DISCOUNTPERCENT) END)
		            END),0)                 AS IMPORTE,
		            '102'                   AS EARNINGCODEID,
		            (CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2'
		                THEN --RRTT
		                    (CASE WHEN SUBSTR(ST.PRODUCTID,1,2) = '03'
		                        THEN '01-S4-03-RT' --ETERNA
		                        ELSE '01-S4-01-RT' --OCASO
		                    END)
		                ELSE --RESTO RAMOS
		                    (CASE WHEN SUBSTR(ST.PRODUCTID,1,2) = '03'
		                        THEN '01-S4-03-RG' --ETERNA
		                        ELSE '01-S4-01-RG' --OCASO
		                    END)
		            END)                    AS EARNINGGROUPID,
		            ST.FILE_IN_RECIBOS      AS FILE_NAME,
		            NULL                    AS FECHA_POST
		        FROM EXT.SALESTRANSACTION ST
		        JOIN :TBL_C_TXN_CALCULADO_6 C_TNX 
					ON ST.ORDERID = C_TNX.ORDERID
					AND ST.LINENUMBER = C_TNX.LINE
					AND ST.SUBLINENUMBER = C_TNX.SUBLINENUMBER
					AND ST.EVENTTYPEID = C_TNX.EVENTTYPEID
		        JOIN EXT.TRANSACTIONASSIGN TA
		        	ON ST.ORDERID = TA.ORDERID
		        	AND ST.LINENUMBER = TA.LINENUMBER
		        	AND ST.SUBLINENUMBER = TA.SUBLINENUMBER
		        	AND ST.EVENTTYPEID = TA.EVENTTYPEID
		        LEFT OUTER JOIN TCMP.CS_EVENTTYPE ET ON ST.EVENTTYPEID = ET.EVENTTYPEID
		                        AND ET.REMOVEDATE = :v_eot
		                        AND ET. TENANTID = :v_tenantid
		            
		        LEFT OUTER JOIN TCMP.CS_CLASSIFIER CL ON ST.PRODUCTID = CL.CLASSIFIERID
		                AND CL.REMOVEDATE = :v_eot
		                AND CL.EFFECTIVESTARTDATE <= ST.COMPENSATIONDATE
		                AND CL.EFFECTIVEENDDATE > ST.COMPENSATIONDATE
		                AND CL.TENANTID = :v_tenantid
		    
		        LEFT OUTER JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ
		                AND PROD.REMOVEDATE = :v_eot
		                AND PROD.EFFECTIVESTARTDATE <= ST.COMPENSATIONDATE
		                AND PROD.EFFECTIVEENDDATE > ST.COMPENSATIONDATE
		                AND PROD.TENANTID = :v_tenantid
		        --WHERE C_TNX.v_tipo_agente IN (12,6)
				--20260406 TGV -- Por peticion de comercial se eliminan los tipo 6 corredores en derechos
				--WHERE C_TNX.v_tipo_agente IN (12)
				WHERE C_TNX.v_tipo_agente = 12
		        	AND C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81
		            AND ST.FILE_IN_RECIBOS = :i_file_name
		            --JGE 20250811 agregar condiciones que faltaban
					AND (C_TNX.POSITIONNAME <> CONST_NO_ENCONTRADO OR C_TNX.CODIGO_RECIBO IN (CONST_COD_RECIBO_ANUL_RRGGPP,CONST_COD_RECIBO_ANUL_RRTT,CONST_COD_RECIBO_ANUL_SERCO) or C_TNX.CODIGO_RECIBO like '%_A')
					AND (C_TNX.MARCA_CUENTA = CONST_S)
					AND ((C_TNX.PERMANENCIA = CONST_RECIBOS_CARTERA_81 AND C_TNX.RAMO = CONST_RAMA_RRTT
			        AND ((IFNULL(C_TNX.PORCENTAJE_COMISION_CALCULAD,0) <> 0) OR IFNULL(C_TNX.IMPORTE_COMISION,0) <> 0)) 
			            OR (C_TNX.PERMANENCIA <> CONST_RECIBOS_CARTERA_81) 
			            OR (C_TNX.RAMO IN (CONST_RAMA_RRGG,CONST_RAMA_RRPP)) 
			            OR (C_TNX.CODIGO_PRODUCTO LIKE '0122%')
			            OR (C_TNX.TIPO_RECUPERACION IS NOT NULL)
			            OR (C_TNX.CODIGO_PRODUCTO LIKE '0129%23'))
			    	AND (C_TNX.PERMANENCIA <> '0')
			);
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en CARTERA_DDEE: ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
	END;
	
	--Limpiamos los datos de la tabla temporal para liberar memoria. Como declaramos las varaibles tabla como varaible implicitas (VISTAS TEMPORALES) no podemos asignar otra definicion de columnas para ahorrarnos mas memoria
	TBL_C_TXN_CALCULADO_6 = SELECT * FROM :TBL_C_TXN_CALCULADO_6 WHERE 1=0;
	
	--volvemos a calcular gn4 y gn5 de la transactionassign por si han cambiado datos con los que se calculaban
	-- UPDATE EXT.TRANSACTIONASSIGN TA
	-- SET TA.GENERICNUMBER4 = IFNULL(to_decimal((
	--             SELECT IFNULL(MAX(T.TIPO_AGENTE_PRIN),0) FROM EXT.VW_CODIGOS_DE_AGENTE T 
	-- 			WHERE T.CODIGO_UNICO = (
	-- 				SELECT MAX(INSP_CAPTADOR) FROM EXT.VW_CODIGOS_DE_AGENTE T 
	-- 				WHERE T.CODIGO_UNICO = TA.POSITIONNAME
	-- 				AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
	-- 				AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
	-- 			)
	-- 			AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
	-- 			AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
	-- 			),25,10),0) , --TA.GENERICNUMBER4
	-- 	TA.GENERICNUMBER5 = IFNULL(to_decimal(
	--             (SELECT MAX(MAX_TIPO_AGENTE) FROM :TBL_C_CURSOR_AGENTE_TIPOLOGIA T
	--             	WHERE T.CODIGO_OCASO = (CASE WHEN ST.GENERICATTRIBUTE20 =  '1' THEN TA.GENERICATTRIBUTE2 ELSE TA.GENERICATTRIBUTE3 END)
	--             ),25,10),0)  -- --TA.GENERICNUMBER5
	-- FROM EXT.TRANSACTIONASSIGN TA
	-- JOIN EXT.SALESTRANSACTION ST
	-- ON TA.ORDERID = ST.ORDERID
	-- AND TA.LINENUMBER = ST.LINENUMBER
	-- AND TA.SUBLINENUMBER = ST.SUBLINENUMBER
	-- AND TA.EVENTTYPEID = ST.EVENTTYPEID
	-- WHERE TA.FILE_IN_RECIBOS = :i_file_name
	-- AND ST.FILE_IN_RECIBOS = :i_file_name
	-- ;
	
	--BORRAMOS DATOS PREVIOS PARA SOBREESCRIBIRLOS
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en DELETE en TCMP.CS_STAGESALESTRANSACTION - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
				
				
			DELETE FROM TCMP.CS_STAGESALESTRANSACTION
			WHERE BATCHNAME = 'TXSTA_' || i_file_name;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'DELETE en TCMP.CS_STAGESALESTRANSACTION, filas : ' || v_num_rows , v_log_count, v_idproceso, 'info');
			
	END;
	
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en DELETE en TCMP.CS_STAGETRANSACTIONASSIGN - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
	
	
			DELETE FROM TCMP.CS_STAGETRANSACTIONASSIGN
			WHERE BATCHNAME = 'TXSTA_' || i_file_name;
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'DELETE en TCMP.CS_STAGETRANSACTIONASSIGN, filas : ' || v_num_rows , v_log_count, v_idproceso, 'info');
	
	END;
	
	TBL_STAGESALESTRANSACTION = SELECT 
					ST.TENANTID, EXT.SEQSTAGESALESTRANSACTION.NEXTVAL AS STAGESALESTRANSACTIONSEQ , 'TXSTA_' || :i_file_name AS BATCHNAME, --ST.FILE_IN_RECIBOS,
					ST.ORDERID, ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID, 
					ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, ST.VALUE, ST.UNITTYPEFORVALUE, 
					ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ST.COMPENSATIONDATE, ST.PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
					ST.DATASOURCE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, ST.DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
					ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
					ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
					ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
					ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
					ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
					ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, ST.STAGEPROCESSDATE, IFNULL(ST.STAGEPROCESSFLAG,0) AS STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
					ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, ST.GENERICATTRIBUTE6, 
					ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
					ST.GENERICATTRIBUTE13, ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
					ST.GENERICATTRIBUTE19, ST.GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
					ST.GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
					ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, ST.GENERICNUMBER1, ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, ST.UNITTYPEFORGENERICNUMBER2, 
					ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, 
					ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
					ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
					ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
				FROM EXT.SALESTRANSACTION ST
			        WHERE ST.BATCHNAME = 'TXSTA_' || :i_file_name
					-- AND (ST.ORDERID, ST.SUBLINENUMBER, ST.LINENUMBER, ST.EVENTTYPEID) IN (
					-- 	SELECT TA.ORDERID, TA.SUBLINENUMBER, TA.LINENUMBER, TA.EVENTTYPEID FROM EXT.TRANSACTIONASSIGN TA WHERE TA.BATCHNAME = 'TXSTA_' || :i_file_name AND TA.POSITIONNAME <> :CONST_NO_ENCONTRADO 
					-- )
					AND EXISTS (
						SELECT 1 FROM EXT.TRANSACTIONASSIGN TA
						WHERE TA.ORDERID = ST.ORDERID
						AND TA.SUBLINENUMBER = ST.SUBLINENUMBER
						AND TA.LINENUMBER = ST.LINENUMBER
						AND TA.EVENTTYPEID = ST.EVENTTYPEID
						AND TA.BATCHNAME = 'TXSTA_' || :i_file_name 
						AND TA.POSITIONNAME <> :CONST_NO_ENCONTRADO 
					)
			;
			
			v_num_rows := RECORD_COUNT(:TBL_STAGESALESTRANSACTION);
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Creada tabla temporal TBL_STAGESALESTRANSACTION, filas : ' || v_num_rows , v_log_count, v_idproceso, 'debug');
			
			
	TBL_STAGETRANSACTIONASSIGN = SELECT 
					TA.TENANTID, TBL.STAGESALESTRANSACTIONSEQ, TA.SETNUMBER, TBL.BATCHNAME, --TA.FILE_IN_RECIBOS, 
					TA.ORDERID, TA.LINENUMBER, TA.SUBLINENUMBER, TA.EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
					TA.POSITIONNAME, TA.TITLENAME, TA.GENERICATTRIBUTE1, TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3, TA.GENERICATTRIBUTE4,
					TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
					TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
					TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
					TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
					TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
					TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
				FROM EXT.TRANSACTIONASSIGN TA
				INNER JOIN :TBL_STAGESALESTRANSACTION TBL ON TBL.ORDERID = TA.ORDERID
					AND TA.SUBLINENUMBER = TBL.SUBLINENUMBER
					AND TA.LINENUMBER = TBL.LINENUMBER
					AND TA.EVENTTYPEID = TBL.EVENTTYPEID
			    WHERE TA.BATCHNAME = 'TXSTA_' || :i_file_name
			        AND TA.POSITIONNAME <> :CONST_NO_ENCONTRADO 
			        AND EXISTS (
						SELECT 1 FROM EXT.SALESTRANSACTION ST
						WHERE TA.ORDERID = ST.ORDERID
						AND TA.SUBLINENUMBER = ST.SUBLINENUMBER
						AND TA.LINENUMBER = ST.LINENUMBER
						AND TA.EVENTTYPEID = ST.EVENTTYPEID
						AND ST.BATCHNAME = 'TXSTA_' || :i_file_name 
					)
			;
			
			v_num_rows := RECORD_COUNT(:TBL_STAGETRANSACTIONASSIGN);
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Creada tabla temporal TBL_STAGETRANSACTIONASSIGN, filas : ' || v_num_rows , V_log_count, v_idproceso, 'debug');
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error INSERT TCMP.CS_STAGESALESTRANSACTION - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
		
		--INSERTAR EN CS_SALESTRANSACTION Y CS_TRANSACTIONASSIGNMENT DE TCMP
		INSERT INTO TCMP.CS_STAGESALESTRANSACTION
			SELECT 
				ST.TENANTID, ST.STAGESALESTRANSACTIONSEQ, ST.BATCHNAME, --ST.FILE_IN_RECIBOS,
				ST.ORDERID, ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID, 
				ST.SALESTRANSACTIONSEQ, ST.SALESORDERSEQ, ST.ACCOUNTINGDATE, ST.PRODUCTID, ST.PRODUCTNAME, ST.PRODUCTDESCRIPTION, ST.VALUE, ST.UNITTYPEFORVALUE, 
				ST.NUMBEROFUNITS, ST.UNITVALUE, ST.UNITTYPEFORUNITVALUE, ST.COMPENSATIONDATE, ST.PAYMENTTERMS, ST.PONUMBER, ST.CHANNEL, ST.ALTERNATEORDERNUMBER, 
				ST.DATASOURCE, ST.NATIVECURRENCY, ST.NATIVECURRENCYAMOUNT, ST.DISCOUNTPERCENT, ST.DISCOUNTTYPE, ST.BILLTOCUSTID, ST.BILLTOCONTACT, ST.BILLTOCOMPANY, 
				ST.BILLTOAREACODE, ST.BILLTOPHONE, ST.BILLTOFAX, ST.BILLTOADDRESS1, ST.BILLTOADDRESS2, ST.BILLTOADDRESS3, ST.BILLTOCITY, ST.BILLTOSTATE, 
				ST.BILLTOCOUNTRY, ST.BILLTOPOSTALCODE, ST.BILLTOINDUSTRY, ST.BILLTOGEOGRAPHY, ST.SHIPTOCUSTID, ST.SHIPTOCONTACT, ST.SHIPTOCOMPANY, ST.SHIPTOAREACODE, 
				ST.SHIPTOPHONE, ST.SHIPTOFAX, ST.SHIPTOADDRESS1, ST.SHIPTOADDRESS2, ST.SHIPTOADDRESS3, ST.SHIPTOCITY, ST.SHIPTOSTATE, ST.SHIPTOCOUNTRY, 
				ST.SHIPTOPOSTALCODE, ST.SHIPTOINDUSTRY, ST.SHIPTOGEOGRAPHY, ST.OTHERTOCUSTID, ST.OTHERTOCONTACT, ST.OTHERTOCOMPANY, ST.OTHERTOAREACODE, ST.OTHERTOPHONE, 
				ST.OTHERTOFAX, ST.OTHERTOADDRESS1, ST.OTHERTOADDRESS2, ST.OTHERTOADDRESS3, ST.OTHERTOCITY, ST.OTHERTOSTATE, ST.OTHERTOCOUNTRY, ST.OTHERTOPOSTALCODE, 
				ST.OTHERTOINDUSTRY, ST.OTHERTOGEOGRAPHY, ST.REASONID, ST.COMMENTS, ST.STAGEPROCESSDATE, ST.STAGEPROCESSFLAG, ST.BUSINESSUNITNAME, ST.BUSINESSUNITMAP, 
				ST.GENERICATTRIBUTE1, ST.GENERICATTRIBUTE2, ST.GENERICATTRIBUTE3, ST.GENERICATTRIBUTE4, ST.GENERICATTRIBUTE5, ST.GENERICATTRIBUTE6, 
				ST.GENERICATTRIBUTE7, ST.GENERICATTRIBUTE8, ST.GENERICATTRIBUTE9, ST.GENERICATTRIBUTE10, ST.GENERICATTRIBUTE11, ST.GENERICATTRIBUTE12, 
				ST.GENERICATTRIBUTE13, ST.GENERICATTRIBUTE14, ST.GENERICATTRIBUTE15, ST.GENERICATTRIBUTE16, ST.GENERICATTRIBUTE17, ST.GENERICATTRIBUTE18, 
				ST.GENERICATTRIBUTE19, ST.GENERICATTRIBUTE20, ST.GENERICATTRIBUTE21, ST.GENERICATTRIBUTE22, ST.GENERICATTRIBUTE23, ST.GENERICATTRIBUTE24, 
				ST.GENERICATTRIBUTE25, ST.GENERICATTRIBUTE26, ST.GENERICATTRIBUTE27, ST.GENERICATTRIBUTE28, ST.GENERICATTRIBUTE29, ST.GENERICATTRIBUTE30, 
				ST.GENERICATTRIBUTE31, ST.GENERICATTRIBUTE32, ST.GENERICNUMBER1, ST.UNITTYPEFORGENERICNUMBER1, ST.GENERICNUMBER2, ST.UNITTYPEFORGENERICNUMBER2, 
				ST.GENERICNUMBER3, ST.UNITTYPEFORGENERICNUMBER3, ST.GENERICNUMBER4, ST.UNITTYPEFORGENERICNUMBER4, ST.GENERICNUMBER5, ST.UNITTYPEFORGENERICNUMBER5, 
				ST.GENERICNUMBER6, ST.UNITTYPEFORGENERICNUMBER6, ST.GENERICDATE1, ST.GENERICDATE2, ST.GENERICDATE3, ST.GENERICDATE4, ST.GENERICDATE5, 
				ST.GENERICDATE6, ST.GENERICBOOLEAN1, ST.GENERICBOOLEAN2, ST.GENERICBOOLEAN3, ST.GENERICBOOLEAN4, ST.GENERICBOOLEAN5, ST.GENERICBOOLEAN6, ST.STAGEERRORCODE, 
				ST.COMPENSATIONDATE_OLD, ST.PUSEQ_OLD
			FROM :TBL_STAGESALESTRANSACTION ST
			/* FROM EXT.SALESTRANSACTION ST
			WHERE ST.BATCHNAME = 'TXSTA_' || :i_file_name
			AND EXISTS (
					SELECT 1 FROM EXT.TRANSACTIONASSIGN TA
					WHERE TA.ORDERID = ST.ORDERID
					AND TA.SUBLINENUMBER = ST.SUBLINENUMBER
					AND TA.LINENUMBER = ST.LINENUMBER
					AND TA.EVENTTYPEID = ST.EVENTTYPEID
					AND TA.BATCHNAME = 'TXSTA_' || :i_file_name 
					AND TA.POSITIONNAME <> :CONST_NO_ENCONTRADO 
				)
				*/
		;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Insert en TCMP.CS_STAGESALESTRANSACTION, filas : ' || v_num_rows , v_log_count, v_idproceso, 'info');
	END;
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK; 
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error INSERT TCMP.CS_STAGETRANSACTIONASSIGN - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_genera_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.GARANTIAS_RECIBO
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					UPDATE EXT.RECIBOS
					SET ESTADO = :v_const_genera_status_error,
					FECHA_MODIFICACION = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND ESTADO = :v_const_calculo_status_ok
					;
					
					COMMIT;
					RESIGNAL;
				END;
	
		INSERT INTO TCMP.CS_STAGETRANSACTIONASSIGN
			SELECT 
				TA.TENANTID, TA.STAGESALESTRANSACTIONSEQ, 1 AS SETNUMBER, TA.BATCHNAME, --TA.FILE_IN_RECIBOS, 
				TA.ORDERID, TA.LINENUMBER, TA.SUBLINENUMBER, TA.EVENTTYPEID, TA.SALESTRANSACTIONSEQ, TA.PAYEEID, TA.PAYEETYPE,
				TA.POSITIONNAME, TA.TITLENAME, TA.GENERICATTRIBUTE1, TA.GENERICATTRIBUTE2, TA.GENERICATTRIBUTE3, TA.GENERICATTRIBUTE4,
				TA.GENERICATTRIBUTE5, TA.GENERICATTRIBUTE6, TA.GENERICATTRIBUTE7, TA.GENERICATTRIBUTE8, TA.GENERICATTRIBUTE9, TA.GENERICATTRIBUTE10,
				TA.GENERICATTRIBUTE11, TA.GENERICATTRIBUTE12, TA.GENERICATTRIBUTE13, TA.GENERICATTRIBUTE14, TA.GENERICATTRIBUTE15, TA.GENERICATTRIBUTE16,
				TA.GENERICNUMBER1, TA.UNITTYPEFORGENERICNUMBER1, TA.GENERICNUMBER2, TA.UNITTYPEFORGENERICNUMBER2, TA.GENERICNUMBER3, TA.UNITTYPEFORGENERICNUMBER3,
				TA.GENERICNUMBER4, TA.UNITTYPEFORGENERICNUMBER4, TA.GENERICNUMBER5, TA.UNITTYPEFORGENERICNUMBER5, TA.GENERICNUMBER6, TA.UNITTYPEFORGENERICNUMBER6,
				TA.GENERICDATE1, TA.GENERICDATE2, TA.GENERICDATE3, TA.GENERICDATE4, TA.GENERICDATE5, TA.GENERICDATE6,
				TA.GENERICBOOLEAN1, TA.GENERICBOOLEAN2, TA.GENERICBOOLEAN3, TA.GENERICBOOLEAN4, TA.GENERICBOOLEAN5, TA.GENERICBOOLEAN6
			FROM :TBL_STAGETRANSACTIONASSIGN TA
		/*	 FROM EXT.TRANSACTIONASSIGN TA
			WHERE TA.BATCHNAME = 'TXSTA_' || :i_file_name
			AND TA.POSITIONNAME <> :CONST_NO_ENCONTRADO 
			AND EXISTS (
					SELECT 1 FROM EXT.SALESTRANSACTION ST
					WHERE ST.ORDERID = TA.ORDERID
					AND ST.SUBLINENUMBER = TA.SUBLINENUMBER
					AND ST.LINENUMBER = TA.LINENUMBER
					AND ST.EVENTTYPEID = TA.EVENTTYPEID
					AND ST.BATCHNAME = 'TXSTA_' || :i_file_name
				)*/
		;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Insert en TCMP.CS_STAGETRANSACTIONASSIGN, filas : ' || v_num_rows , v_log_count, v_idproceso, 'info');
		
	END;
	
	--UPDATE BATCH_CONTROL, RECIBOS Y GARANTIAS_RECIBO
	UPDATE EXT.RECIBOS
	SET ESTADO = :v_const_genera_status_ok,
	FECHA_MODIFICACION = CURRENT_TIMESTAMP
	WHERE FILE_NAME = :i_file_name
	AND ESTADO = :v_const_calculo_status_ok
	;
		
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Estado actualizado a 9 en RECIBOS : ' || v_num_rows , v_log_count, v_idproceso, 'info');
	
	UPDATE EXT.GARANTIAS_RECIBO
	SET ESTADO = :v_const_genera_status_ok,
	FECHA_MODIFICACION = CURRENT_TIMESTAMP
	WHERE FILE_NAME = :i_file_name
	AND ESTADO = :v_const_calculo_status_ok
	;
		
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Estado actualizado a 9 en GARNTIAS_RECIBO : ' || v_num_rows , v_log_count, v_idproceso, 'info');
		
	
	UPDATE EXT.IN_BATCH_CONTROL
	SET STATUS = :v_const_genera_status_ok,
	END_DATE = CURRENT_TIMESTAMP
	WHERE FILE_NAME = :i_file_name
	AND STATUS = :v_const_calculo_status_ok
	;
		
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Estado actualizado a 9 en IN_BATCH_CONTROL : ' || v_num_rows , v_log_count, v_idproceso, 'info');
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin proceso SP_GENERA ' , v_log_count, v_idproceso, 'info');
					
	END;
END
