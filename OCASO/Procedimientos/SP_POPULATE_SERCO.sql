CREATE PROCEDURE EXT.SP_POPULATE_SERCO (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Jorge Gracia Estaun 
    | Company: Inycom
    | Initial Version Date: 05-Febrero-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta una vez que entra un fichero de serco e inserta o actualiza los datos en las tablas finales de 
    |						RECIBOS, POLIZAS, GARANTIAS RECIBOS, SALESTRANSACTION Y TRANSACTIONASSIGN
	|
	| Version: 0.1	JGE 20250205		Initial Version.
	|
    -----------------------------------------------------------------------
*/

BEGIN
	DECLARE proc_name VARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	-- DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_tenantid VARCHAR(4) := '';

	DECLARE CONST_RECIBO_COBRADO VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
	DECLARE CONST_COD_RECIBO_SERCO VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_SERCO;
	DECLARE CONST_RECIBOS_ESPECIFICOS_11 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_11;
	DECLARE CONST_S VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S;
	DECLARE CONST_S_1 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S_1;
	DECLARE CONST_N_0 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N_0;
	DECLARE CONST_RAMA_RRTT VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRTT;
	DECLARE COSNT_RECU_POLIZA VARCHAR(2) := EXT.LIB_CONSTANTES:COSNT_RECU_POLIZA;
	DECLARE CONST_RECU_RECIBO VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECU_RECIBO;
	DECLARE CONST_RP_NEG_CON_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RP_NEG_CON_AGENTE;
    DECLARE CONST_RP_NEG_SIN_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RP_NEG_SIN_AGENTE;
    DECLARE CONST_RP_POS_CON_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RP_POS_CON_AGENTE;
    DECLARE CONST_RP_POS_SIN_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RP_POS_SIN_AGENTE;
    DECLARE CONST_RR_NEG_CON_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RR_NEG_CON_AGENTE;
    DECLARE CONST_RR_NEG_SIN_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RR_NEG_SIN_AGENTE;
    DECLARE CONST_RR_POS_CON_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RR_POS_CON_AGENTE;
    DECLARE CONST_RR_POS_SIN_AGENTE VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_RR_POS_SIN_AGENTE;
    DECLARE CONST_TIPO_EURO VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_EURO;
    DECLARE CONST_TIPO_ESP VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_ESP;
    DECLARE CONST_TIPO_PERCENTAGE VARCHAR(255) := EXT.LIB_CONSTANTES:CONST_TIPO_PERCENTAGE;
    DECLARE v_status INTEGER := 0;
    DECLARE CONST_NO_ENCONTRADO VARCHAR(20) := EXT.LIB_CONSTANTES:CONST_NO_ENCONTRADO; 
	
	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR;
	DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK;
	DECLARE v_const_populate_status_error INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_ERROR;
	DECLARE v_const_carga_status_ok INT := EXT.LIB_CONSTANTES:CONST_GENERA_TRX_STATUS_OK;

	DECLARE v_fecha_compensacion DATE;
	DECLARE v_vueltas INTEGER := 1;
	DECLARE v_existe_tabla INTEGER = 0;
	
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
			SET REJECTED_ROWS = :v_num_rows,
				STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
			--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
			UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
			WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;	
			
			COMMIT;

			--Captura el error y lo env�a a xDL
			RESIGNAL;
		END;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, i_id_proceso, 'info');
		--Se comprueba estado del fichero
	SELECT STATUS INTO v_status FROM EXT.IN_BATCH_CONTROL WHERE FILE_NAME = :i_file_name ORDER BY START_DATE DESC LIMIT 1;
	
	IF (v_status <> v_const_stage_status_ok) THEN
		SIGNAL SQL_ERROR_CODE 10001
    	SET MESSAGE_TEXT = 'Estado inv�lido: ' || :v_status;
	ELSE 
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Estado IN_BATCH_CONTROL correcto' , v_log_count, i_id_proceso, 'info');
	END IF;
	
	--se rellena la variable tenantid una vez en toda la ejecucion
	SELECT DISTINCT TENANTID INTO v_tenantid FROM TCMP.CS_TENANT;
	
	--Regenerar tablas cod_agente
	TBL_GEN_CODIGOS_AGENTE = SELECT * FROM EXT.VW_CODIGOS_DE_AGENTE VW
								WHERE VW.CODIGO_OCASO <> '0' 
									AND VW.CODIGO_OCASO <> '000000000' 
									AND VW.CODIGO_OCASO <> '0000000000'
								;
	v_num_rows := RECORD_COUNT(:TBL_GEN_CODIGOS_AGENTE);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_GEN_CODIGOS_AGENTE ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	--guardan en una variable tabla los registros de serco 
	TBL_C_SERCO_STAGE = SELECT *
							FROM (
							    SELECT *,
							    	ROW_NUMBER() OVER (
								            PARTITION BY 
								            			CODIGO_POLIZA,
								            			ESTADO_RECIBO,
							            				PRODUCTO_CONTABLE,
							            				TIPO_MOVIMIENTO
						            					
								            ORDER BY 
								                       FECHA_EFECTO_POLIZA DESC, 
								                       CARGO_COMPENSACION DESC,
								                       FECHA_EFECTO_RECIBO ASC, 
								                       CODIGO_RECIBO ASC,
								                       ESTADO_RECIBO, 
								                       PRODUCTO_CONTABLE DESC, 
								                       CODIGO_AGENTE_ORIGINAL
								        ) AS RN_AGENTE_RRTT,
							        ROW_NUMBER() OVER (
							            PARTITION BY 
							            			CODIGO_POLIZA,
							            			ESTADO_RECIBO,
							            			CODIGO_AGENTE_ORIGINAL,
						            				TIPO_MOVIMIENTO
							            ORDER BY 
							                       FECHA_EFECTO_POLIZA DESC, 
							                       CARGO_COMPENSACION DESC,
							                       FECHA_EFECTO_RECIBO ASC, 
							                       CODIGO_RECIBO ASC,
							                       ESTADO_RECIBO, 
							                       PRODUCTO_CONTABLE DESC, 
							                       CODIGO_AGENTE_ORIGINAL
							        ) AS RN_PRODUCTO_RRTT,
								    ROW_NUMBER() OVER (
								            PARTITION BY 
								            			CODIGO_POLIZA,
								            			ESTADO_RECIBO,
							            				PRODUCTO_CONTABLE,
							            				CODIGO_AGENTE_ORIGINAL
						            					
								            ORDER BY 
								                       FECHA_EFECTO_POLIZA DESC, 
								                       CARGO_COMPENSACION DESC,
								                       FECHA_EFECTO_RECIBO ASC, 
								                       CODIGO_RECIBO ASC,
								                       ESTADO_RECIBO, 
								                       PRODUCTO_CONTABLE DESC, 
								                       CODIGO_AGENTE_ORIGINAL
								        ) AS RN_MOVIMIENTO_RRGG,
							        ROW_NUMBER() OVER (
							            PARTITION BY 
							            			CODIGO_POLIZA,
							            			ESTADO_RECIBO,
						            				PRODUCTO_CONTABLE
							            ORDER BY 
							                       FECHA_EFECTO_POLIZA DESC, 
							                       CARGO_COMPENSACION DESC,
							                       FECHA_EFECTO_RECIBO ASC, 
							                       CODIGO_RECIBO ASC,
							                       ESTADO_RECIBO, 
							                       PRODUCTO_CONTABLE DESC, 
							                       CODIGO_AGENTE_ORIGINAL
							        ) AS RN_AGENTE_RRGG,
							        ROW_NUMBER() OVER (
							            PARTITION BY 
							            			CODIGO_POLIZA,
							            			ESTADO_RECIBO,
							            			CODIGO_AGENTE_ORIGINAL
							            ORDER BY 
							                       FECHA_EFECTO_POLIZA DESC, 
							                       CARGO_COMPENSACION DESC,
							                       FECHA_EFECTO_RECIBO ASC, 
							                       CODIGO_RECIBO ASC,
							                       ESTADO_RECIBO, 
							                       PRODUCTO_CONTABLE DESC, 
							                       CODIGO_AGENTE_ORIGINAL
							        ) AS RN_PRODUCTO_RRGG
							   FROM EXT.STAGE_RECIBOS SRC
							        WHERE FILE_NAME = i_file_name 
								        AND ESTADO = v_const_stage_status_ok
								        AND LENGTH(PRODUCTO_CONTABLE) = 7
							) AS SERCO_FILTRADO
							WHERE  (CASE WHEN RAMO <> 'RRTT' THEN RN_PRODUCTO_RRGG ELSE RN_PRODUCTO_RRTT END) = 1
							   AND (CASE WHEN RAMO <> 'RRTT' THEN RN_AGENTE_RRGG ELSE RN_AGENTE_RRTT END) = 1
							   AND (CASE WHEN RAMO <> 'RRTT' THEN RN_MOVIMIENTO_RRGG ELSE 1 END) = 1
							ORDER BY FECHA_EFECTO_POLIZA DESC, CARGO_COMPENSACION DESC,
        					FECHA_EFECTO_RECIBO ASC, CODIGO_RECIBO ASC, ESTADO_RECIBO, PRODUCTO_CONTABLE DESC, CODIGO_AGENTE_ORIGINAL;
         
         
	v_num_rows := RECORD_COUNT(:TBL_C_SERCO_STAGE);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_C_SERCO_STAGE ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	--------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_C_SERCO_STAGE_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_C_SERCO_STAGE_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_C_SERCO_STAGE_DEBUG AS (SELECT * FROM :TBL_C_SERCO_STAGE);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_C_SERCO_STAGE_DEBUG' , v_log_count, i_id_proceso, 'debug');
    ------------------------------
	

	SELECT max(R.CARGO_COMPENSACION) INTO v_fecha_compensacion 
	FROM :TBL_C_SERCO_STAGE R 
	;

	TBL_CODIGO_SUPLEMENTO_CALCULADO = (
		SELECT 
	        SRC.*, 
	        IFNULL(
	            (SELECT MAX(R.CODIGO_SUPLEMENTO) 
	             FROM EXT.RECIBOS R
	             WHERE R.CODIGO_POLIZA = SRC.CODIGO_POLIZA
	             AND R.PERMANENCIA = :CONST_RECIBOS_ESPECIFICOS_11
	             --AND R.CODIGO_RECIBO = SRC.CODIGO_RECIBO
	             --AND R.PRODUCTO_CONTABLE = SRC.PRODUCTO_CONTABLE
	             AND R.CODIGO_RECIBO = :CONST_COD_RECIBO_SERCO
	        	 AND R.ESTADO_RECIBO = SRC.ESTADO_RECIBO
	            ),0) + ROW_NUMBER() OVER(PARTITION BY SRC.CODIGO_POLIZA, SRC.CODIGO_RECIBO, SRC.ESTADO_RECIBO, SRC.CODIGO_SUPLEMENTO ORDER BY SRC.CODIGO_POLIZA ASC) AS CODIGO_SUPLEMENTO_CALCULADO, -- Calculamos CODIGO_SUPLEMENTO con ROW_NUMBER
	            (SELECT COUNT(*) FROM EXT.POLIZAS POL WHERE SUBSTR(POL.CODIGO_POLIZA,1,22) = SUBSTR(SRC.CODIGO_POLIZA,1,22) AND POL.RAMO = SRC.RAMO) AS v_ExistePoliza
	    FROM :TBL_C_SERCO_STAGE SRC
	);
	
	-- TBL_CODIGO_SUPLEMENTO_CALCULADO = (
	-- 	SELECT 
	-- 		SRC.*,
	-- 		IFNULL(MAX_R.MAX_COD_SUPLEMENTO, 0) + 1 AS CODIGO_SUPLEMENTO_CALCULADO
	-- 	FROM :TBL_C_SERCO_STAGE SRC
	-- 	LEFT JOIN (
	-- 	    SELECT 
	-- 	        GR.CODIGO_POLIZA,
	-- 	        IFNULL(MAX(GR.CODIGO_SUPLEMENTO),0) AS MAX_COD_SUPLEMENTO
	-- 	    FROM EXT.GARANTIAS_RECIBO GR
	-- 	    WHERE GR.ESTADO_RECIBO = :CONST_RECIBO_COBRADO
	-- 	    AND GR.CODIGO_RECIBO = :CONST_COD_RECIBO_SERCO
	-- 	    --AND GR.PERMANENCIA = :CONST_RECIBOS_ESPECIFICOS_11
	-- 	    GROUP BY GR.CODIGO_POLIZA
	-- 	) MAX_R
	-- 	ON SRC.CODIGO_POLIZA = MAX_R.CODIGO_POLIZA
	-- );
	
	v_num_rows := RECORD_COUNT(:TBL_CODIGO_SUPLEMENTO_CALCULADO);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_CODIGO_SUPLEMENTO_CALCULADO  ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	
	--------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_CODIGO_SUPLEMENTO_CALCULADO_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_CODIGO_SUPLEMENTO_CALCULADO_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_CODIGO_SUPLEMENTO_CALCULADO_DEBUG AS (SELECT * FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_CODIGO_SUPLEMENTO_CALCULADO_DEBUG' , v_log_count, i_id_proceso, 'debug');
	--------------------------------TABLA DEBUG PENDIENTE BORRAR
	--GET_PERIODO_EXTORNABLE
	--Se guarda el periodo extornable para cada producto en TBL_PERIOD_EXTORNABLE
	TBL_PERIOD_EXTORNABLE = (
		WITH TEMP AS (
			SELECT 
				CR.*,
				(SELECT GC.PERIODO_EXTORNABLE FROM EXT.VW_GEN_PRODUCTOS GC WHERE GC.CODIGO = CR.PRODUCTO_CONTABLE) AS PERIOD_EXT
			FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
		)
		SELECT DISTINCT
			*,
			IFNULL((
				CASE WHEN PERIOD_EXT IS NULL 
					THEN
						CASE WHEN SUBSTR(PRODUCTO_CONTABLE,3,1) = '2' 
							THEN 
								CASE WHEN SUBSTR(PRODUCTO_CONTABLE,1,3) = '012' 
									THEN 17 
									ELSE 18 
								END
							ELSE 12 
						END
					ELSE PERIOD_EXT 
				END
			),0) AS PERIODO_EXTORNABLE
		FROM TEMP	
	);
	
	v_num_rows := RECORD_COUNT(:TBL_PERIOD_EXTORNABLE);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_PERIOD_EXTORNABLE ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	
	--Comprobamos si las polizas existen aunque no haya recuperaciones
	--Esta tabla solo deber�a tener los datos de las polizas de los registros que existen en la tabla POLIZAS, con estos datos se hara un update en POLIZAS
	TBL_EXISTE_POLIZA = (
		SELECT 
		    POL.*
		FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO R
		INNER JOIN EXT.POLIZAS POL ON
		SUBSTR(POL.CODIGO_POLIZA,1,22) = SUBSTR(R.CODIGO_POLIZA,1,22)
		AND POL.RAMO = R.RAMO
		);
	
	v_num_rows := RECORD_COUNT(:TBL_EXISTE_POLIZA);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'TBL_EXISTE_POLIZA. Polizas que ya existen: ' || v_num_rows , v_log_count, i_id_proceso, 'info');

	--RRGG/RRPP/SOLNET solo nos quedamos con el primer tipo de movimiento segun la FECHAEFECTORECIBO
	
	--para tratar la recuperacion hay que comprobar que no haya otra recu en periodo extornable
	--Comprobamos si hay alguna recuperaci�n comisionada anteriormente
	TBL_EXISTE11_COM = 
		(SELECT DISTINCT CR.*,
		    IFNULL((	SELECT COUNT(R.CODIGO_RECIBO)
						FROM EXT.RECIBOS R 
						-- JOIN EXT.POLIZAS P 
					 --   	ON SUBSTR(P.CODIGO_POLIZA,1,22) = SUBSTR(CR.CODIGO_POLIZA,1,22)
					    WHERE R.CODIGO_POLIZA = CR.CODIGO_POLIZA
						    AND R.ESTADO_RECIBO = :CONST_RECIBO_COBRADO
						    AND R.CODIGO_RECIBO = :CONST_COD_RECIBO_SERCO
						    AND R.PERMANENCIA = :CONST_RECIBOS_ESPECIFICOS_11
						    AND R.MARCA_CUENTA = :CONST_S
						    AND R.EXCLUIDO_COMISIONES >= :CONST_S_1 --1
		    ), 0) AS EXISTE_11_COM
		FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
	);
	
	v_num_rows := RECORD_COUNT(:TBL_EXISTE11_COM);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_EXISTE11_COM ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	--Comprobamos si hay alguna recuperaci�n subvencionada anteriormente
	TBL_EXISTE11_SUB = 
		(SELECT DISTINCT CR.*,
		    IFNULL((
		    	SELECT COUNT(R.CODIGO_RECIBO) 
		    	FROM EXT.RECIBOS R 
				WHERE R.CODIGO_POLIZA = CR.CODIGO_POLIZA
					AND R.ESTADO_RECIBO = :CONST_RECIBO_COBRADO
				    AND R.CODIGO_RECIBO = :CONST_COD_RECIBO_SERCO
				    AND R.PERMANENCIA = :CONST_RECIBOS_ESPECIFICOS_11
				    AND R.MARCA_CUENTA = :CONST_S
				    AND R.DISMINUCION_PRIMA = :CONST_S_1 --1
		    ), 0) AS EXISTE_11_SUB
		FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
		);
		
	v_num_rows := RECORD_COUNT(:TBL_EXISTE11_SUB);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_EXISTE11_SUB ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	--Se coge las ultimas fechas de los recibos 11 que subvencionaron
	TBL_SUBVENCIONES = (
		SELECT	R.CODIGO_POLIZA,
				R.FECHA_EFECTO_RECIBO,
				P.FECHA_EFECTO_POLIZA,
				R.ESTADO_RECIBO, 
				R.CODIGO_AGENTE_ORIGINAL,
				ROW_NUMBER() OVER (
					    PARTITION BY R.CODIGO_POLIZA
					    ORDER BY R.FECHA_EFECTO_RECIBO DESC, P.FECHA_EFECTO_POLIZA DESC) AS ROW_NUM
		FROM EXT.RECIBOS R
		JOIN EXT.POLIZAS P 
			ON SUBSTR(P.CODIGO_POLIZA,1,22) = SUBSTR(R.CODIGO_POLIZA,1,22)
		WHERE R.CODIGO_RECIBO = :CONST_COD_RECIBO_SERCO
				AND R.ESTADO_RECIBO = :CONST_RECIBO_COBRADO
				AND R.PERMANENCIA = :CONST_RECIBOS_ESPECIFICOS_11
				AND R.MARCA_CUENTA = :CONST_S
				AND R.DISMINUCION_PRIMA = :CONST_S_1	
	);
	v_num_rows := RECORD_COUNT(:TBL_SUBVENCIONES);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Registros de subvenciones TBL_SUBVENCIONES: ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	TBL_ULTIMO_RECIBO_11_SUB = (
		SELECT 
			CS.*,
			IFNULL((CASE WHEN CS.EXISTE_11_SUB > 0 
					THEN 
						CASE WHEN TRIM(SUB.CODIGO_AGENTE_ORIGINAL) = TRIM(CS.CODIGO_AGENTE_ORIGINAL) 
							THEN ROUND(MONTHS_BETWEEN(SUB.FECHA_EFECTO_RECIBO, CS.FECHA_EFECTO_RECIBO),2)
						    ELSE 20 
						END
					ELSE 20
			END),20) AS DIFERENCIA_MESES_RRTT,
			IFNULL((CASE WHEN CS.EXISTE_11_SUB > 0 
					THEN 
						ROUND(MONTHS_BETWEEN(SUB.FECHA_EFECTO_POLIZA, CS.FECHA_EFECTO_POLIZA),2)
					ELSE 20
			END),20) AS DIFERENCIA_MESES_RRGG
		FROM :TBL_EXISTE11_SUB CS
		LEFT JOIN :TBL_SUBVENCIONES SUB
		ON CS.CODIGO_POLIZA = SUB.CODIGO_POLIZA
		AND ROW_NUM = 1
	);
	
	v_num_rows := RECORD_COUNT(:TBL_ULTIMO_RECIBO_11_SUB);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_ULTIMO_RECIBO_11_SUB ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	TBL_SUBVENCIONES = SELECT * FROM :TBL_SUBVENCIONES WHERE 1=0;
	
	TBL_COMISIONES = (
		SELECT R.CODIGO_POLIZA,
		R.FECHA_EFECTO_RECIBO,
		P.FECHA_EFECTO_POLIZA,
		R.CODIGO_AGENTE_ORIGINAL, 
		R.CODIGO_AGENTE_COMMISSIONS, 
		R.FECHA_COMPENSACION,
		ROW_NUMBER() OVER (
			    PARTITION BY R.CODIGO_POLIZA
			    ORDER BY R.FECHA_EFECTO_RECIBO DESC, P.FECHA_EFECTO_POLIZA DESC) AS ROW_NUM
		FROM EXT.RECIBOS R
		JOIN EXT.POLIZAS P 
			ON SUBSTR(P.CODIGO_POLIZA,1,22) = SUBSTR(R.CODIGO_POLIZA,1,22)
		WHERE R.CODIGO_RECIBO = :CONST_COD_RECIBO_SERCO
				AND R.ESTADO_RECIBO = :CONST_RECIBO_COBRADO
				AND R.PERMANENCIA = :CONST_RECIBOS_ESPECIFICOS_11
				AND R.MARCA_CUENTA = :CONST_S
				AND R.EXCLUIDO_COMISIONES > :CONST_N_0	
	);
	v_num_rows := RECORD_COUNT(:TBL_COMISIONES);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Registros de comisiones TBL_COMISIONES: ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	--Se coge las ultimas fechas de los recibos 11 que comisionaron
	TBL_ULTIMO_RECIBO_11_COM = (
		SELECT 
			CS.*,
			COM.CODIGO_AGENTE_ORIGINAL AS CODIGO_AGENTE_ORIGINAL_LAST_RECIBO,
			IFNULL((CASE WHEN CS.EXISTE_11_COM > 0 
					THEN 
						ROUND(MONTHS_BETWEEN(COM.FECHA_EFECTO_RECIBO, CS.FECHA_EFECTO_RECIBO),2)
					ELSE 20
			END),20) AS DIFERENCIA_MESES
		FROM :TBL_EXISTE11_COM CS
		LEFT JOIN :TBL_COMISIONES COM
		ON CS.CODIGO_POLIZA = COM.CODIGO_POLIZA
		AND ROW_NUM = 1
	);
	
	v_num_rows := RECORD_COUNT(:TBL_ULTIMO_RECIBO_11_COM);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_ULTIMO_RECIBO_11_COM ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	TBL_COMISIONES = SELECT * FROM :TBL_COMISIONES WHERE 1=0;
	
	TBL_COBRA_SUBVENCION = (
		SELECT DISTINCT
			LAST_R_SUB.*,
			CR.PERIODO_EXTORNABLE,
			IFNULL((CASE WHEN CR.RAMO = CONST_RAMA_RRTT --RRTT
			    THEN
			        CASE WHEN (CR.DISTRITO_COBRO IN ('A','D')) 
			            THEN 
			            	CASE WHEN (LAST_R_SUB.DIFERENCIA_MESES_RRTT > CR.PERIODO_EXTORNABLE AND 
	                            (CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','PA','RO','RP','TD') OR
	                             (CR.TIPO_MOVIMIENTO IN ('SU','TP') AND CR.MOTIVO_BAJA IN ('94','92','56','80')))
	                        )
	                            THEN 1
	                            ELSE 0
	                        END
			                -- CASE WHEN IFNULL(LAST_R_SUB.EXISTE_11_SUB,0) > 0 
			                --     THEN
			                --         CASE WHEN (LAST_R_SUB.DIFERENCIA_MESES_RRTT > CR.PERIODO_EXTORNABLE AND 
			                --             (CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','PA','RO','RP','TD') OR
			                --              (CR.TIPO_MOVIMIENTO IN ('SU','TP') AND CR.MOTIVO_BAJA IN ('94','92','56','80')))
			                --         )
			                --             THEN 1
			                --             ELSE 0
			                --         END
			                --     ELSE 
			                --     	CASE WHEN (--IFNULL(LAST_R_SUB.DIFERENCIA_MESES,20) > CR.PERIODO_EXTORNABLE AND 
			                --             (CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','PA','RO','RP','TD') OR
			                --              (CR.TIPO_MOVIMIENTO IN ('SU','TP') AND CR.MOTIVO_BAJA IN ('94','92','56','80')))
			                --     	)
			                --             THEN 1
			                --             ELSE 0
			                --         END
			                -- END
			            ELSE 0
			        END
			    ELSE --RRGG|RRPP|SOLNET
			    	CASE WHEN (LAST_R_SUB.DIFERENCIA_MESES_RRGG > CR.PERIODO_EXTORNABLE AND 
	                    (CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','PA','RO','RP','TD') OR
	                     (CR.TIPO_MOVIMIENTO IN ('SU','TP') AND CR.MOTIVO_BAJA IN ('94','92','56','80')))
					)
	                    THEN 1
	                    ELSE 0
	                END	
			    --     CASE WHEN IFNULL(LAST_R_SUB.EXISTE_11_SUB,0) > 0
			    --         THEN
			    --             CASE WHEN (LAST_R_SUB.DIFERENCIA_MESES_RRGG > CR.PERIODO_EXTORNABLE AND 
			    --                 (CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','PA','RO','RP','TD') OR
			    --                  (CR.TIPO_MOVIMIENTO IN ('SU','TP') AND CR.MOTIVO_BAJA IN ('94','92','56','80')))
							-- )
			    --                 THEN 1
			    --                 ELSE 0
			    --             END
			    --         ELSE 
			    --         	CASE WHEN (--IFNULL(LAST_R_SUB.DIFERENCIA_MESES,20) > CR.PERIODO_EXTORNABLE AND 
			    --                 (CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','PA','RO','RP','TD') OR
			    --                  (CR.TIPO_MOVIMIENTO IN ('SU','TP') AND CR.MOTIVO_BAJA IN ('94','92','56','80')))
			    --         	)
			    --         		THEN 1
			    --                 ELSE 0
			    --             END
			    --     END
			END),0) AS cobraSubvencion
		FROM (

		    SELECT *,
		           ROW_NUMBER() OVER (PARTITION BY CODIGO_POLIZA ORDER BY FECHA_EFECTO_POLIZA DESC) AS RN
		    FROM :TBL_PERIOD_EXTORNABLE
		
			) CR
		INNER JOIN :TBL_ULTIMO_RECIBO_11_SUB LAST_R_SUB
		    ON TRIM(CR.CODIGO_POLIZA) = TRIM(LAST_R_SUB.CODIGO_POLIZA)
		    AND CR.RN = 1
	);
	
	v_num_rows := RECORD_COUNT(:TBL_COBRA_SUBVENCION);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_COBRA_SUBVENCION ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	TBL_ULTIMO_RECIBO_11_SUB = SELECT * FROM :TBL_ULTIMO_RECIBO_11_SUB WHERE 1=0;
	
	------------------------------20251029 --TABLA DEBUG PENDIENTE BORRAR------------------------------
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_COBRA_SUBVENCION_DEBUG';
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_COBRA_SUBVENCION_DEBUG;
	END IF;
	CREATE TABLE EXT.TBL_COBRA_SUBVENCION_DEBUG AS (SELECT * FROM :TBL_COBRA_SUBVENCION);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_COBRA_SUBVENCION_DEBUG' , v_log_count, i_id_proceso, 'debug');
    ---------------------------------------------------------------------------------------------------
	
	
	
	TBL_COBRA_COMISION = (
		SELECT DISTINCT
			LAST_R_COM.*,
			CR.PERIODO_EXTORNABLE,
			IFNULL((CASE WHEN CR.RAMO = CONST_RAMA_RRTT -- RRTT
			    THEN
			        CASE WHEN CR.DISTRITO_COBRO = 'A' 
			            THEN 
			                CASE WHEN CR.ESTADO_RECIBO <> 'A' AND 
			                	TO_NUMBER(CR.PRIMA_NETA_RECIBO) > 0 
			                    --(CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) > 0 
			                    AND (CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','RC','RD') OR 
			                        (CR.TIPO_MOVIMIENTO IN ('SU','TP') AND CR.MOTIVO_ALTA IN ('TP','TS','DT','RC','DE'))
			                   )
			                    THEN
			                        CASE WHEN IFNULL(LAST_R_COM.EXISTE_11_COM,0) > 0 
			                            THEN
			                                CASE WHEN LAST_R_COM.DIFERENCIA_MESES >= CR.PERIODO_EXTORNABLE
			                                    THEN 1
			                                    ELSE 
			                                        CASE WHEN trim(LAST_R_COM.CODIGO_AGENTE_ORIGINAL_LAST_RECIBO) <> trim(CR.CODIGO_AGENTE_ORIGINAL)
			                                            THEN 2 
			                                            ELSE 0
			                                        END
			                                END
			                            ELSE 1
			                        END
			                    ELSE 0
			                END
			            ELSE 0
			        END
			    ELSE -- RRGG|RRPP|SOLNET
			        CASE WHEN CR.ESTADO_RECIBO <> 'A' AND CR.TIPO_MOVIMIENTO IN ('BP','CB','DB','DC','RC','RD','SU','TP')
			            THEN 1
			            ELSE 0
			        END
			END),0) AS cobraComision
		FROM (

		    SELECT *,
		           ROW_NUMBER() OVER (PARTITION BY TRIM(CODIGO_POLIZA) ORDER BY FECHA_EFECTO_POLIZA DESC) AS RN
		    FROM :TBL_PERIOD_EXTORNABLE
		
			) CR
		INNER JOIN :TBL_ULTIMO_RECIBO_11_COM LAST_R_COM
		    ON TRIM(CR.CODIGO_POLIZA) = TRIM(LAST_R_COM.CODIGO_POLIZA)
		    AND CR.RN = 1
	);
	
	v_num_rows := RECORD_COUNT(:TBL_COBRA_COMISION);
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_COBRA_COMISION ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	TBL_ULTIMO_RECIBO_11_COM = SELECT * FROM :TBL_ULTIMO_RECIBO_11_COM WHERE 1=0;
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO HISTORIFICAR POLIZAS ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en HISTORIFICAR POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
				
			END;
	
		--Solo se actualizan las polizas si la recuperacion ya existe y las nuevas subvencionan porque las fechas de la poliza se usan para la subvencion
		--HISTORIFICAR
		
			INSERT INTO EXT.POLIZAS_HIST (
			    ID_PROCESO, 
			    ID_RECIBO,
			    FILE_NAME,
			    ESTADO,
			    FECHA_MODIFICACION,
			    CODIGO_POLIZA,
			    RAMO,
			    MOTIVO_ALTA,
			    FECHA_EFECTO_POLIZA,
			    FECHA_EMISION_POLIZA,
			    FECHA_CESION_POLIZA,
			    MOTIVO_BAJA,
			    FECHA_BAJA,
			    FECHA_VENCIMIENTO,
			    FECHA_REHABILITACION,
			    FORMA_PAGO,
			    TIPO_CAMPANIA,
			    SEGUNDA_RESIDENCIA,
			    TARIFA,
			    ZONA,
			    CLAVE_RIESGO,
			    MODALIDAD,
			    DURACION,
			    CLAUSULA,
			    SUSTITUCION_INCENDIOS,
			    EXCLUIDO_COMISIONES,
			    TRASPASADA,
			    DESCUENTO_IMPORTE_SINIESTRALID,
			    DESCUENTO_POR_PRIORITARIO,
			    RIESGO,
			    COLECTIVO,
			    AUTOLIQUIDA,
			    KILOMETROS,
			    MOVILIDAD,
			    POLIZA_CON_AGENTE,
			    AGENTE_CARTERA,
			    IMP_COMISION_CARTERA,
			    PORC_COMISION_CARTERA,
			    FECHA_FIN_COMISION_CARTERA
			)
			SELECT 
			    i_id_proceso,
			    ID_RECIBO,
			    FILE_NAME,
			    ESTADO,
			    FECHA_MODIFICACION,
			    CODIGO_POLIZA,
			    RAMO,
			    MOTIVO_ALTA,
			    FECHA_EFECTO_POLIZA,
			    FECHA_EMISION_POLIZA,
			    FECHA_CESION_POLIZA,
			    MOTIVO_BAJA,
			    FECHA_BAJA,
			    FECHA_VENCIMIENTO,
			    FECHA_REHABILITACION,
			    FORMA_PAGO,
			    TIPO_CAMPANIA,
			    SEGUNDA_RESIDENCIA,
			    TARIFA,
			    ZONA,
			    CLAVE_RIESGO,
			    MODALIDAD,
			    DURACION,
			    CLAUSULA,
			    SUSTITUCION_INCENDIOS,
			    EXCLUIDO_COMISIONES,
			    TRASPASADA,
			    DESCUENTO_IMPORTE_SINIESTRALID,
			    DESCUENTO_POR_PRIORITARIO,
			    RIESGO,
			    COLECTIVO,
			    AUTOLIQUIDA,
			    KILOMETROS,
			    MOVILIDAD,
			    POLIZA_CON_AGENTE,
			    AGENTE_CARTERA,
			    IMP_COMISION_CARTERA,
			    PORC_COMISION_CARTERA,
			    FECHA_FIN_COMISION_CARTERA
			FROM (
			    SELECT
			        POL.*,
			        ROW_NUMBER() OVER (
			            PARTITION BY POL.CODIGO_POLIZA
			            ORDER BY POL.CODIGO_POLIZA DESC
			        ) AS RN
			    FROM :TBL_EXISTE_POLIZA POL
			    INNER JOIN :TBL_COBRA_SUBVENCION COB
			        ON SUBSTR(POL.CODIGO_POLIZA,1,22) = SUBSTR(COB.CODIGO_POLIZA,1,22)
			       AND POL.MOTIVO_ALTA = COB.MOTIVO_ALTA
			    WHERE COB.cobraSubvencion = 1
			) FILTRADO
			WHERE FILTRADO.RN = 1;
			
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en POLIZAS_HIST ' || v_num_rows , v_log_count, i_id_proceso, 'info');
			
			--SE ACTUALIZA LA TABLA POLIZAS, FECHA DE EFECTO DE LA POLIZA Y EL NOMBRE DEL FICHERO
			MERGE INTO EXT.POLIZAS P
			USING 
				(
			        SELECT *
				    FROM (
				        SELECT 
				            EXIST_P.CODIGO_POLIZA,
				            CR.FECHA_EFECTO_POLIZA,
				            CR.cobraSubvencion,
				            CR.FILE_NAME,
				            ROW_NUMBER() OVER (
				                PARTITION BY EXIST_P.CODIGO_POLIZA
				                ORDER BY CR.FECHA_EFECTO_POLIZA DESC  -- o alg�n otro criterio
				            ) AS RN
				        FROM :TBL_COBRA_SUBVENCION CR
				        JOIN :TBL_EXISTE_POLIZA EXIST_P 
				            ON SUBSTR(CR.CODIGO_POLIZA,1,22) = SUBSTR(EXIST_P.CODIGO_POLIZA,1,22)
				            AND CR.MOTIVO_ALTA = EXIST_P.MOTIVO_ALTA
				        WHERE CR.cobraSubvencion = 1
				    )
				    WHERE RN = 1
			    ) SRC
			ON P.CODIGO_POLIZA = SRC.CODIGO_POLIZA
				AND SRC.cobraSubvencion = 1
			WHEN MATCHED THEN UPDATE SET 
				P.FECHA_EFECTO_POLIZA = SRC.FECHA_EFECTO_POLIZA,
				P.FECHA_MODIFICACION = CURRENT_TIMESTAMP,
			    P.FILE_NAME = SRC.FILE_NAME;
			
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en POLIZAS ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	END;	
		
		
		--GUARDAR DATOS MENSUALIDADES PARA CADA REGISTRO DEL FICHERO
		TBL_MENSUALIDADES = (
			SELECT 
				CR.*,
				(CASE WHEN CR.RAMO <> 'RRTT' 
					THEN 
						IFNULL((SELECT T.MENSUALIDADES FROM EXT.VW_FORMAS_PAGO T WHERE T.CODIGO = CR.FORMA_PAGO),12)
					ELSE --RRTT
						CASE WHEN IFNULL(CR.cobraComision,0) = 2
							THEN 
								CASE WHEN CR.CARGO_COMPENSACION >= TO_DATE('01/06/2024', 'DD/MM/YYYY') AND CR.MOTIVO_ALTA = 'TP' AND CR.PRODUCTO_CONTABLE = '0129023' 
									THEN (100/25)
									ELSE (100/21)
								END
							ELSE 
								CASE WHEN CR.CARGO_COMPENSACION >= TO_DATE('01/06/2024', 'DD/MM/YYYY') AND CR.MOTIVO_ALTA = 'TP' AND CR.PRODUCTO_CONTABLE = '0129023' 
									THEN 
										--JGE 20251007 se quita hasta agosto y se deja para siempre hasta que nos avisen
										CASE WHEN CR.CARGO_COMPENSACION >= TO_DATE('01/06/2025', 'DD/MM/YYYY') /*AND CR.CARGO_COMPENSACION <= TO_DATE('01/08/2025', 'DD/MM/YYYY')*/
											THEN  (100/41.65)
											ELSE (100/25)
										END 
									ELSE 
										--JGE 20251007 se quita hasta agosto y se deja para siempre hasta que nos avisen
										CASE WHEN CR.CARGO_COMPENSACION >= TO_DATE('01/06/2025', 'DD/MM/YYYY') /*AND CR.CARGO_COMPENSACION <= TO_DATE('01/08/2025', 'DD/MM/YYYY') */
											THEN (100/50)
											ELSE (100/41.65)
										END
								END
						END
				END	
				) AS v_mensualidades
			FROM :TBL_COBRA_COMISION CR
			
			
		);
		
		v_num_rows := RECORD_COUNT(:TBL_MENSUALIDADES);
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_MENSUALIDADES ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		------------------------------20251029 --TABLA DEBUG PENDIENTE BORRAR------------------------------
	    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_COBRA_COMISION_DEBUG';
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_COBRA_COMISION_DEBUG;
		END IF;
		CREATE TABLE EXT.TBL_COBRA_COMISION_DEBUG AS (SELECT * FROM :TBL_MENSUALIDADES);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_COBRA_COMISION_DEBUG' , v_log_count, i_id_proceso, 'debug');
	    ---------------------------------------------------------------------------------------------------
		
		--ACTUALIZAMOS GARANTIA DE RECIBO ANTERIOR SI HAY QUE EXTORNAR A ALGUN AGENTE
		-- Para v_cobraComision = 2 Se historifica y se cambia recibos y garantias_recibo 
		
		TBL_RECIBO_ANTERIOR = (
			SELECT 
				    R.*
			FROM EXT.RECIBOS R
			JOIN :TBL_COBRA_COMISION CR 
			    ON R.CODIGO_POLIZA = CR.CODIGO_POLIZA
			    AND R.CODIGO_RECIBO = CR.CODIGO_RECIBO
			    AND R.ESTADO_RECIBO = CR.ESTADO_RECIBO
			    AND R.CODIGO_SUPLEMENTO = CR.CODIGO_SUPLEMENTO
			JOIN POLIZAS P 
			    ON SUBSTR(P.CODIGO_POLIZA,1,22) = substr(R.CODIGO_POLIZA,1,22)  
			WHERE 
			    R.ESTADO_RECIBO = :CONST_RECIBO_COBRADO
			    AND R.CODIGO_RECIBO = :CONST_COD_RECIBO_SERCO
			    AND R.PERMANENCIA = :CONST_RECIBOS_ESPECIFICOS_11
			    AND R.MARCA_CUENTA = :CONST_S
			    AND R.EXCLUIDO_COMISIONES = :CONST_N_0
			    AND CR.cobraComision = 2
			ORDER BY 
			    R.FECHA_EFECTO_RECIBO DESC, 
			    P.FECHA_EFECTO_POLIZA DESC
		);
		
		v_num_rows := RECORD_COUNT(:TBL_RECIBO_ANTERIOR);
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_RECIBO_ANTERIOR ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO HISTORIFICAR RECIBOS ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
					
			ROLLBACK;
		
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en HISTORIFICAR RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
			END;
		
		--HISTORIFICAMOS
		INSERT INTO EXT.RECIBOS_HIST(
			SELECT
				i_id_proceso, 
				ANT.*
			FROM :TBL_RECIBO_ANTERIOR ANT
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en RECIBOS_HIST ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		--ACTUALIZAMOS
		MERGE INTO EXT.RECIBOS R
		USING (
			SELECT
				ANT.*
			FROM :TBL_RECIBO_ANTERIOR ANT
		) SRC 
		ON R.CODIGO_POLIZA = SRC.CODIGO_POLIZA
			AND R.ESTADO_RECIBO = SRC.ESTADO_RECIBO
			AND R.CODIGO_RECIBO = SRC.CODIGO_RECIBO
			AND R.CODIGO_SUPLEMENTO = SRC.CODIGO_SUPLEMENTO
		WHEN MATCHED THEN 
			UPDATE SET R.FILE_NAME = i_file_name,
			R.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
			
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en RECIBOS ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	END;
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO HISTORIFICAR GARANTIAS_RECIBOS ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
					
			ROLLBACK;
		
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en HISTORIFICAR GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
			END;
		
		--Buscamos la garantia de los recibos anteriores
		--HISTORIFACAMOS
		INSERT INTO EXT.GARANTIAS_RECIBO_HIST
		(
		    SELECT 
		        i_id_proceso,
		        GR.*
		    FROM EXT.GARANTIAS_RECIBO GR
		    JOIN :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
				ON GR.CODIGO_POLIZA = CR.CODIGO_POLIZA
				AND GR.ESTADO_RECIBO = CR.ESTADO_RECIBO
		        AND GR.CODIGO_RECIBO = CR.CODIGO_RECIBO
		        AND GR.CODIGO_SUPLEMENTO = CR.CODIGO_SUPLEMENTO
		        AND GR.PRODUCTO_CONTABLE = CR.PRODUCTO_CONTABLE
		    JOIN :TBL_RECIBO_ANTERIOR ANT 
		        ON GR.CODIGO_POLIZA = ANT.CODIGO_POLIZA
		    	AND GR.ESTADO_RECIBO = ANT.ESTADO_RECIBO
		        AND GR.CODIGO_RECIBO = ANT.CODIGO_RECIBO
		        AND GR.CODIGO_SUPLEMENTO = ANT.CODIGO_SUPLEMENTO
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en GARANTIAS_RECIBO_HIST ' || v_num_rows , v_log_count, i_id_proceso, 'info');
			
		--ACTUALIZAMOS 
		MERGE INTO EXT.GARANTIAS_RECIBO R
		USING (
			SELECT
				ANT.CODIGO_POLIZA,
				ANT.ESTADO_RECIBO,
				ANT.CODIGO_RECIBO,
				ANT.CODIGO_SUPLEMENTO,
				CR.PRODUCTO_CONTABLE,
				CR.PRIMA_NETA_RECIBO,
				CR.FILE_NAME,
				M.v_mensualidades
			FROM:TBL_RECIBO_ANTERIOR ANT
			INNER JOIN :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
				ON CR.CODIGO_POLIZA = ANT.CODIGO_POLIZA
		    	AND CR.ESTADO_RECIBO = ANT.ESTADO_RECIBO
		        AND CR.CODIGO_RECIBO = ANT.CODIGO_RECIBO
		        AND CR.CODIGO_SUPLEMENTO = ANT.CODIGO_SUPLEMENTO
			INNER JOIN :TBL_MENSUALIDADES M
				ON ANT.CODIGO_POLIZA = M.CODIGO_POLIZA
		) SRC
		ON R.CODIGO_POLIZA = SRC.CODIGO_POLIZA
			AND R.ESTADO_RECIBO = SRC.ESTADO_RECIBO
			AND R.CODIGO_RECIBO = SRC.CODIGO_RECIBO
			AND R.CODIGO_SUPLEMENTO = SRC.CODIGO_SUPLEMENTO
			AND R.PRODUCTO_CONTABLE = SRC.PRODUCTO_CONTABLE
		WHEN MATCHED THEN 
			UPDATE SET 
				R.PRIMA_COMISIONABLE = (CASE WHEN SRC.v_mensualidades = 0 THEN 0 
										    WHEN (R.PRIMA_COMISIONABLE - 
										              (CASE WHEN SUBSTR(SRC.PRIMA_NETA_RECIBO,1,1) = '0' 
										                   THEN 0 
										                   ELSE TO_NUMBER(SRC.PRIMA_NETA_RECIBO) 
										              END) / SRC.v_mensualidades) > 0 
										        THEN (-1) * R.PRIMA_COMISIONABLE
										    ELSE 
										        (R.PRIMA_COMISIONABLE - 
										            (CASE WHEN SUBSTR(SRC.PRIMA_NETA_RECIBO,1,1) = '0' 
										                THEN 0 
										                ELSE TO_NUMBER(SRC.PRIMA_NETA_RECIBO) 
										            END) / SRC.v_mensualidades)
										END),
				R.INCREMENTO_PRIMA_ANUAL = R.PRIMA_COMISIONABLE,
				R.FILE_NAME = SRC.FILE_NAME;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en GARANTIAS_RECIBO ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	END;
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO Insertar en POLIZAS ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
					
			ROLLBACK;
		
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en Insertar en POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
			END;
		
		--SI NO EXISTE POLIZA, SE INSERTA
		INSERT INTO EXT.POLIZAS (
			SELECT 
			    IDENTIFICADOR,
			    FILE_NAME,
			    ESTADO,
			    FECHA_MODIFICACION,
			    CODIGO_POLIZA,
			    RAMO,
			    MOTIVO_ALTA,
			    FECHA_EFECTO_POLIZA,
			    FECHA_EMISION_POLIZA,
			    FECHA_CESION_POLIZA,
			    MOTIVO_BAJA,
			    FECHA_BAJA,
			    FECHA_VENCIMIENTO,
			    FECHA_REHABILITACION,
			    FORMA_PAGO,
			    TIPO_CAMPANIA,
			    SEGUNDA_RESIDENCIA,
			    TARIFA,
			    ZONA,
			    CLAVE_RIESGO,
			    MODALIDAD,
			    DURACION,
			    CLAUSULA,
			    SUSTITUCION_INCENDIOS,
			    EXCLUIDO_COMISIONES,
			    TRASPASADA,
			    DTO_IMPT_SINIESTRALIDAD,
			    DTO_POR_PRIORITARIO,
			    RIESGO,
			    COLECTIVO,
			    AUTOLIQUIDA,
			    KILOMETROS,
			    MOVILIDAD,
			    POLIZA_CON_AGENTE,
			    AGENTE_CARTERA,
			    IMP_COMISION_CARTERA,
			    PORC_COMISION_CARTERA,
			    FECHA_FIN_COMISION_CARTERA
			FROM (
			    SELECT 
			        CS.IDENTIFICADOR,
			        CS.FILE_NAME,
			        :v_const_populate_status_ok AS ESTADO,
			        CURRENT_TIMESTAMP AS FECHA_MODIFICACION,
			        CS.CODIGO_POLIZA,
			        CS.RAMO,
			        CS.MOTIVO_ALTA,
			        CS.FECHA_EFECTO_POLIZA,
			        IFNULL(CS.FECHA_EMISION_POLIZA, CS.FECHA_EFECTO_POLIZA) AS FECHA_EMISION_POLIZA,
			        CS.FECHA_CESION_POLIZA,
			        CS.MOTIVO_BAJA,
			        CS.FECHA_BAJA,
			        CS.FECHA_VENCIMIENTO,
			        CS.FECHA_REHABILITACION,
			        CS.FORMA_PAGO,
			        CS.TIPO_CAMPANIA,
			        IFNULL(CS.SEGUNDA_RESIDENCIA,0) AS SEGUNDA_RESIDENCIA,
			        IFNULL(CS.TARIFA,0) AS TARIFA,
			        IFNULL(CS.ZONA,0) AS ZONA,
			        CS.CLAVE_RIESGO,
			        CS.MODALIDAD,
			        CS.DURACION,
			        CS.CLAUSULA,
			        CS.SUSTITUCION_INCENDIOS,
			        CS.EXCLUIDO_COMISIONES,
			        CS.TRASPASADA,
			        CS.DTO_IMPT_SINIESTRALIDAD,
			        CS.DTO_POR_PRIORITARIO,
			        CS.RIESGO,
			        CS.COLECTIVO,
			        CS.AUTOLIQUIDA,
			        CS.KILOMETROS,
			        CS.MOVILIDAD,
			        CS.POLIZA_CON_AGENTE,
			        '' AS AGENTE_CARTERA,
			        0 AS IMP_COMISION_CARTERA,
			        0 AS PORC_COMISION_CARTERA,
			        NULL AS FECHA_FIN_COMISION_CARTERA,
			        ROW_NUMBER() OVER (
			            PARTITION BY CS.CODIGO_POLIZA
			            ORDER BY CS.IDENTIFICADOR
			        ) AS RN
			    FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO CS
			    WHERE NOT EXISTS (
			        SELECT 1 
			        FROM EXT.POLIZAS P
			        WHERE SUBSTR(CS.CODIGO_POLIZA,1,22) = SUBSTR(P.CODIGO_POLIZA,1,22)
			    )
			) FILTRO
			WHERE RN = 1
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en POLIZAS ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		--VARIABLE SUPLEMENTO
		-- TBL_SUPLEMENTOS = (
		-- 	SELECT
		-- 		CR.*,
		-- 		IFNULL((
		-- 			SELECT MAX(R.CODIGO_SUPLEMENTO)
		-- 			FROM EXT.RECIBOS R
		-- 			WHERE R.CODIGO_POLIZA = CR.CODIGO_POLIZA
		-- 			AND R.PERMANENCIA = CONST_RECIBOS_ESPECIFICOS_11
		-- 			AND R.CODIGO_RECIBO = CONST_COD_RECIBO_SERCO
		-- 			), CR.CODIGO_SUPLEMENTO) AS SUPLEMENTO
		-- 	FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
		-- );
		
		-- v_num_rows := ::rowcount;
		-- CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_SUPLEMENTOS  ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
	END;
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO Insertar en RECIBOS ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
					
			ROLLBACK;
		
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en Insertar en RECIBOS- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
			END;
		
		
			TBL_DATOS_RECIBOS = (
				SELECT 
					CR.*, CC.cobraComision, CS.cobraSubvencion,
					(CASE WHEN (
							SELECT COUNT(*)
							FROM :TBL_GEN_CODIGOS_AGENTE
							WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
						) > 0 
					THEN (
							SELECT IFNULL(MAX(CODIGO_OCASO), :CONST_NO_ENCONTRADO) 
							FROM :TBL_GEN_CODIGOS_AGENTE
							WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
						) 
					ELSE CR.CODIGO_AGENTE_ORIGINAL
						
					END) AS CODIGO_AGENTE,
					(CASE WHEN 
					(
						SELECT COUNT(*)
						FROM :TBL_GEN_CODIGOS_AGENTE
						WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
						) > 0  
					THEN CR.CODIGO_AGENTE_ORIGINAL 
					ELSE 
						(
							SELECT IFNULL(MAX(CODIGO_UNICO), :CONST_NO_ENCONTRADO) 
							FROM :TBL_GEN_CODIGOS_AGENTE
							WHERE CODIGO_OCASO = CR.CODIGO_AGENTE_ORIGINAL
						)
					END) AS CODIGO_AGENTE_COMMI,
					IFNULL(CR.ESTADO_RECIBO,:CONST_RECIBO_COBRADO) AS ESTADO_RECIBO_TEST,
					ROW_NUMBER() OVER (PARTITION BY CR.CODIGO_POLIZA, CR.CODIGO_SUPLEMENTO_CALCULADO, CR.ESTADO_RECIBO ORDER BY CR.CODIGO_POLIZA ASC) AS ROW_NUN
				FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
				INNER JOIN :TBL_COBRA_COMISION CC
					ON CR.CODIGO_POLIZA = CC.CODIGO_POLIZA
					-- AND CR.CODIGO_RECIBO = CC.CODIGO_RECIBO
					AND CR.PERMANENCIA = CC.PERMANENCIA
					AND CR.ESTADO_RECIBO = CC.ESTADO_RECIBO
					-- AND CR.CODIGO_SUPLEMENTO = CC.CODIGO_SUPLEMENTO
					-- AND CR.CODIGO_SUPLEMENTO_CALCULADO = CC.CODIGO_SUPLEMENTO_CALCULADO
				INNER JOIN :TBL_COBRA_SUBVENCION CS
					ON CR.CODIGO_POLIZA = CS.CODIGO_POLIZA
					-- AND CR.CODIGO_RECIBO = CS.CODIGO_RECIBO
					AND CR.PERMANENCIA = CC.PERMANENCIA
					AND CR.ESTADO_RECIBO = CS.ESTADO_RECIBO
					-- AND CR.CODIGO_SUPLEMENTO = CS.CODIGO_SUPLEMENTO
					-- AND CR.CODIGO_SUPLEMENTO_CALCULADO = CS.CODIGO_SUPLEMENTO_CALCULADO
			);
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_DATOS_RECIBOS ' || v_num_rows , v_log_count, i_id_proceso, 'info');
			
			------------------------------20251029 --TABLA DEBUG PENDIENTE BORRAR------------------------------
		    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_DATOS_RECIBOS_DEBUG';
			IF v_existe_tabla > 0 THEN
				DROP TABLE EXT.TBL_DATOS_RECIBOS_DEBUG;
			END IF;
			CREATE TABLE EXT.TBL_DATOS_RECIBOS_DEBUG AS (SELECT * FROM :TBL_DATOS_RECIBOS);
		    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_DATOS_RECIBOS_DEBUG' , v_log_count, i_id_proceso, 'debug');
		    ---------------------------------------------------------------------------------------------------
			
			TBL_DATOS_RECIBOS = (
				SELECT * FROM :TBL_DATOS_RECIBOS WHERE ROW_NUN = 1
			);
			
			--RECIBO
			INSERT INTO EXT.RECIBOS
			SELECT DISTINCT
				CR.IDENTIFICADOR,											--IDENTIFICADOR
				CR.FILE_NAME,												--FILE_NAME
				:v_const_populate_status_ok,								--ESTADO
				CURRENT_TIMESTAMP,											--FECHA_MODIFICACION
				CR.CODIGO_POLIZA,											--CODIGO_POLIZA
				:CONST_COD_RECIBO_SERCO,										--CODIGO_RECIBO
				:CONST_RECIBOS_ESPECIFICOS_11,								--PERMANENCIA
				CR.TIPO_RECIBO,												--TIPO_RECIBO
				CR.ESTADO_RECIBO_TEST, --IFNULL(CR.ESTADO_RECIBO,CONST_RECIBO_COBRADO), 			--ESTADO_RECIBO
				CR.FECHA_COBRO,												--FECHA_COBRO
				CR.CARGO_COMPENSACION,										--FECHA_COMPENSACION
				CR.FECHA_EFECTO_RECIBO,										--FECHA_EFECTO_RECIBO
				CR.FECHA_VENCIMIENTO_RECIBO,								--FECHA_VTO_RECIBO
				CR.TIPO_MOVIMIENTO,											--TIPO_MOVIMIENTO
				NULL,														--PORCENTAJE_DESCUENTO_SOBRE_PC
				NULL,														--VALOR_POLIZA
				CR.CODIGO_AGENTE,												--CODIGO_UNICO_AGENTE
				CR.CODIGO_AGENTE,												--CODIGO_AGENTE_ORIGINAL
				CR.INSPECTOR,												--INSPECTOR
				NULL,														--OFICINA_COBRADORA
				CR.OFICINA_GESTORA,											--OFICINA_GESTORA
				NULL,														--MARCA_RECUPERADO
				'S',														--MARCA_CUENTA
				0,															--PRIMER_RECIBO
				0,															--ASEGURADOS_NETOS
				NULL,														--AUMENTO_ASEGURADOS
				CR.cobraComision,											--EXCLUIDO_COMISIONES
				0,															--BONIFICACION_POLIZA
				CR.cobraSubvencion,											--DISMINUCION_PRIMA
				(CASE 
				    WHEN CR.MARCA_RECUPERADO = COSNT_RECU_POLIZA THEN 
				        CASE 
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) <> '') 
				            THEN CONST_RP_NEG_CON_AGENTE
				            
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) = '') 
				            THEN CONST_RP_NEG_SIN_AGENTE
				
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) <> '') 
				            THEN CONST_RP_POS_CON_AGENTE
				
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) = '') 
				            THEN CONST_RP_POS_SIN_AGENTE
				        END
				        
				    WHEN CR.MARCA_RECUPERADO = CONST_RECU_RECIBO THEN 
				        CASE 
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) <> '') 
				            THEN CONST_RR_NEG_CON_AGENTE
				            
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) = '') 
				            THEN CONST_RR_NEG_SIN_AGENTE
				
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) <> '') 
				            THEN CONST_RR_POS_CON_AGENTE
				
				            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
				                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL OR TRIM(CR.CODIGO_AGENTE_ORIGINAL) = '') 
				            THEN CONST_RR_POS_SIN_AGENTE
				        END	
				END),														--TIPO_RECUPERACION
				NULL,														--ES_PERMANENCIA_20
				CR.CODIGO_AGENTE_COMMI,										--CODIGO_AGENTE_COMMISSIONS
				CR.FECHA_EMISION_REC,										--FECHA_EMISION_REC
				NULL,														--FCHA_EFECTO_SUPLEMENTO
				CR.CODIGO_SUPLEMENTO_CALCULADO,							
	            															--CODIGO_SUPLEMENTO
				CR.DISTRITO_COBRO,											--DISTRITO_COBRO
				NULL,														--CODIGO_SINIESTRO
				NULL,														--ZONA_EXIST_PLOTACION
				NULL														--CODIGO_AGENTE_ZONA
			FROM :TBL_DATOS_RECIBOS CR
			-- WHERE CR.RN = 1
			WHERE not exists (select 1 from ext.recibos R where 
				r.codigo_poliza = cr.codigo_poliza and 
				r.estado_Recibo = cr.estado_recibo and
				r.codigo_recibo = cr.codigo_Recibo and
				r.codigo_suplemento = cr.codigo_suplemento_calculado
			)
		;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en RECIBOS ' || v_num_rows , v_log_count, i_id_proceso, 'info');

	END;	
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO Insertar GARANTIAS_RECIBO ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en Insertar GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
			END;
	
		TBL_DATOS_GARANTIAS_RECIBO = (
			SELECT C.*, ROW_NUMBER() OVER (PARTITION BY C.CODIGO_POLIZA, C.CODIGO_RECIBO, C.PRODUCTO_CONTABLE, C.CODIGO_SUPLEMENTO_CALCULADO, C.ESTADO_RECIBO) AS RN
			FROM :TBL_MENSUALIDADES C	
		);
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_DATOS_GARANTIAS_RECIBO ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		--GARANTIAS_RECIBO
		INSERT INTO EXT.GARANTIAS_RECIBO
			SELECT DISTINCT
				--NULL,													--IDENTIFICADOR
				CR.IDENTIFICADOR,										--ID_RECIBO
				CR.FILE_NAME,											--FILE_NAME
				:v_const_populate_status_ok,							--ESTADO
				CURRENT_TIMESTAMP,										--FECHA_MODIFICACION
				CR.CODIGO_POLIZA,										--CODIGO_POLIZA
				CONST_COD_RECIBO_SERCO,									--CODIGO_RECIBO
				CR.PRODUCTO_CONTABLE,									--PRODUCTO_CONTABLE
				(CASE WHEN CR.ESTADO_RECIBO = 'S' THEN CONST_RECIBO_COBRADO ELSE IFNULL(CR.ESTADO_RECIBO,CONST_RECIBO_COBRADO) END),			
																		--ESTADO_RECIBO
				(CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END),													
																		--PRIMA_NETA_RECIBO
				NULL,													--PRIMA_BRUTA_RECIBO
				NULL,													--RECARGO
				NULL,													--PORCENTAJE_BONIFICACION
				CR.INCRE_PRIMA_ANUAL,									--INCREMENTO_PRIMA_ANUAL
				(CEIL(
				    (CASE 
				        WHEN SUBSTR(CR.PRIMA_NETA_RECIBO, 1, 1) = '0' 
				        THEN 0 
				        ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) 
				    END) / CR.v_mensualidades * 100
				) / 100),												--PRIMA_COMISIONABLE
				0,														--UNIDAD_DE_POLIZA
				0,														--MESES_COBRADOS
				NULL,													--FECHA_ALTA_GAR_POL
				NULL,													--FECHA_BAJA_GAR_POL
				NULL,													--PORCENTAJE_NIVELADA
				NULL,													--PERIODO_EXTORNABLE
				0,														--INDICADOR_COMISION_CALCULADA
				0,														--INDICADOR_PORCENTAJE_CALCULA
				NULL,													--PORCENTAJE_COMISION_CALCULADA
				NULL,													--IMPORTE_COMISION
				NULL,													--PRIMA_UNICA
				NULL,													--NUM_ORDEN_MOVIMIENTO
				NULL,													--AUMENTO_CAPITALES_GARANTIA
				NULL,													--PRIMA_NETA_ANUALIZADA
				NULL,													--PORC_COMISION_NP
				NULL,													--PORC_COMISION_CONSERVACION		
				--IFNULL(CR.SUPLEMENTO,0) + 1,						--CODIGO_SUPLEMENTO
				CODIGO_SUPLEMENTO_CALCULADO,							
	            														--CODIGO_SUPLEMENTO
				NULL													--PORC_COMISION_COBRO
			-- FROM :TBL_CODIGO_SUPLEMENTO_CALCULADO CR
			-- INNER JOIN (
			-- 	SELECT * ,
			-- 			ROW_NUMBER() OVER (PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO, PERMANENCIA ORDER BY CODIGO_POLIZA DESC) AS RN
			-- 	FROM :TBL_MENSUALIDADES
				
			-- ) M
			-- ON CR.CODIGO_POLIZA = M.CODIGO_POLIZA
			-- 		AND CR.CODIGO_RECIBO = M.CODIGO_RECIBO
			-- 		AND CR.CODIGO_SUPLEMENTO = M.CODIGO_SUPLEMENTO
			-- 		AND CR.ESTADO_RECIBO = M.ESTADO_RECIBO
			-- WHERE M.RN = 1
			FROM :TBL_DATOS_GARANTIAS_RECIBO CR
			WHERE CR.RN = 1
		;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en GARANTIAS_RECIBO ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	END;	
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO Insertar TNX SERCO ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en Insertar TRX SERCO- SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
			END;
		
		TBL_DATOS_SALESTRANSACTION = (
			SELECT DISTINCT
		        SERCO.*,
		        M.v_mensualidades,
		        CC.cobraComision,
		        CS.cobraSubvencion,
		        (
		        	CASE WHEN CC.v_ExistePoliza > 0 
		        	THEN
		        		(
		        			SELECT MIN(POL.FECHA_EMISION_POLIZA)
		        			FROM EXT.POLIZAS POL
		        			WHERE SUBSTR(POL.CODIGO_POLIZA,1,22) = SUBSTR(SERCO.CODIGO_POLIZA,1,22)
							AND POL.RAMO = SERCO.RAMO
		        		)
		        	ELSE SERCO.FECHA_EMISION_POLIZA
		        	END
		        ) AS ST_GENERICDATE3
		        ,ROW_NUMBER() OVER (
		            PARTITION BY (SERCO.PRODUCTO_CONTABLE || SUBSTR(SERCO.CODIGO_POLIZA,8) || SERCO.ESTADO_RECIBO || SERCO.TIPO_MOVIMIENTO),
		            			TO_NUMBER(SUBSTR(REPLACE(SERCO.CARGO_COMPENSACION, '-', ''), 1, 6)),
		            			TO_NUMBER(SUBSTR(SERCO.CODIGO_POLIZA, 1, 7)),
		            			SERCO.PERMANENCIA
		            ORDER BY SERCO.CODIGO_POLIZA
		        ) AS ROWNUM
		    FROM :TBL_C_SERCO_STAGE SERCO
		    INNER JOIN (
		    	SELECT *, ROW_NUMBER() OVER (PARTITION BY TRIM(CODIGO_POLIZA) ORDER BY FECHA_EFECTO_RECIBO DESC) AS RN
				FROM :TBL_MENSUALIDADES
		    ) M
		        ON SERCO.CODIGO_POLIZA = M.CODIGO_POLIZA
				-- AND SERCO.CODIGO_RECIBO = M.CODIGO_RECIBO
				-- AND SERCO.CODIGO_SUPLEMENTO = M.CODIGO_SUPLEMENTO
				-- AND SERCO.ESTADO_RECIBO = M.ESTADO_RECIBO
		    INNER JOIN :TBL_COBRA_COMISION CC
		        ON SERCO.CODIGO_POLIZA = CC.CODIGO_POLIZA
				-- AND SERCO.CODIGO_RECIBO = CC.CODIGO_RECIBO
				-- AND SERCO.CODIGO_SUPLEMENTO = CC.CODIGO_SUPLEMENTO
				-- AND SERCO.ESTADO_RECIBO = CC.ESTADO_RECIBO
		    INNER JOIN :TBL_COBRA_SUBVENCION CS
		        ON SERCO.CODIGO_POLIZA = CS.CODIGO_POLIZA
				-- AND SERCO.CODIGO_RECIBO = CS.CODIGO_RECIBO
				-- AND SERCO.CODIGO_SUPLEMENTO = CS.CODIGO_SUPLEMENTO
				-- AND SERCO.ESTADO_RECIBO = CS.ESTADO_RECIBO
		    WHERE (CS.cobraSubvencion = 1 OR IFNULL(CC.cobraComision,0) > 0)
		    AND M.RN = 1	
		);
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_DATOS_SALESTRANSACTION ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		--------------------------------TABLA DEBUG PENDIENTE BORRAR
	    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_DATOS_SALESTRANSACTION_DEBUG';
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_DATOS_SALESTRANSACTION_DEBUG;
		END IF;
		CREATE TABLE EXT.TBL_DATOS_SALESTRANSACTION_DEBUG AS (SELECT * FROM :TBL_DATOS_SALESTRANSACTION);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_DATOS_SALESTRANSACTION_DEBUG' , v_log_count, i_id_proceso, 'debug');
	    ------------------------------
		
		
		INSERT INTO EXT.SALESTRANSACTION
					SELECT 
							v_tenantid			AS TENANTID
							,EXT.SEQSTAGESALESTRANSACTION.NEXTVAL							
															AS STAGESALESTRANSACTIONSEQ
							,'TXSTA_' || CR.FILE_NAME		AS BATCHNAME
							,CR.FILE_NAME					AS FILE_IN_RECIBOS
							,(CR.PRODUCTO_CONTABLE||substr(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO)					
															AS ORDERID
							,TO_NUMBER(SUBSTR(REPLACE(CR.CARGO_COMPENSACION, '-', ''), 1, 6))						
															AS LINENUMBER
							,TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))					
															AS SUBLINENUMBER
							,CR.PERMANENCIA					AS EVENTTYPEID
							,NULL							AS SALESTRANSACTIONSEQ
							,NULL							AS SALESORDERSEQ
							,CR.CARGO_COMPENSACION			AS ACCOUNTINGDATE
							,CR.PRODUCTO_CONTABLE			AS PRODUCTID
							,NULL							AS PRODUCTNAME
							,NULL							AS PRODUCTDESCRIPTION
							,(CEIL((CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN CR.PRIMA_NETA_RECIBO ELSE CR.PRIMA_NETA_RECIBO / CR.v_mensualidades END) * 100 ) / 100)
															AS VALUE
							,CONST_TIPO_EURO				AS UNITTYPEFORVALUE
							,NULL							AS NUMBEROFUNITS
							,NULL							AS UNITVALUE
							,NULL							AS UNITTYPEFORUNITVALUE
							,CR.CARGO_COMPENSACION			AS COMPENSATIONDATE
							,NULL							AS PAYMENTTERMS
							,NULL							AS PONUMBER
							,SUBSTR(CR.CODIGO_POLIZA,1, 2)	AS CHANNEL
							,NULL							AS ALTERNATEORDERNUMBER
							,NULL							AS DATASOURCE
							,CASE WHEN (CR.RAMO = CONST_RAMA_RRTT) AND (CR.PRIMA_NETA_RECIBO / CR.v_mensualidades IS NOT NULL) THEN CONST_TIPO_EURO END 						
															AS NATIVECURRENCY
							,CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN CR.PRIMA_NETA_RECIBO / CR.v_mensualidades END
															AS NATIVECURRENCYAMOUNT
							,CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN 1/CR.v_mensualidades END
															AS DISCOUNTPERCENT
							,CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN CONST_TIPO_PERCENTAGE END
															AS DISCOUNTTYPE
							,NULL							AS BILLTOCUSTID
							,NULL							AS BILLTOCONTACT
							,NULL							AS BILLTOCOMPANY
							,NULL							AS BILLTOAREACODE
							,NULL							AS BILLTOPHONE
							,NULL							AS BILLTOFAX
							,NULL							AS BILLTOADDRESS1
							,NULL							AS BILLTOADDRESS2
							,NULL							AS BILLTOADDRESS3
							,NULL							AS BILLTOCITY
							,NULL							AS BILLTOSTATE
							,NULL							AS BILLTOCOUNTRY
							,NULL							AS BILLTOPOSTALCODE
							,NULL							AS BILLTOINDUSTRY
							,NULL							AS BILLTOGEOGRAPHY
							,NULL							AS SHIPTOCUSTID
							,NULL							AS SHIPTOCONTACT
							,NULL							AS SHIPTOCOMPANY
							,NULL							AS SHIPTOAREACODE
							,NULL							AS SHIPTOPHONE
							,NULL							AS SHIPTOFAX
							,NULL							AS SHIPTOADDRESS1
							,NULL							AS SHIPTOADDRESS2
							,NULL							AS SHIPTOADDRESS3
							,NULL							AS SHIPTOCITY
							,NULL							AS SHIPTOSTATE
							,NULL							AS SHIPTOCOUNTRY
							,NULL							AS SHIPTOPOSTALCODE
							,NULL							AS SHIPTOINDUSTRY
							,NULL							AS SHIPTOGEOGRAPHY
							,NULL							AS OTHERTOCUSTID
							,NULL							AS OTHERTOCONTACT
							,NULL							AS OTHERTOCOMPANY
							,NULL							AS OTHERTOAREACODE
							,NULL							AS OTHERTOPHONE
							,NULL							AS OTHERTOFAX
							,NULL							AS OTHERTOADDRESS1
							,NULL							AS OTHERTOADDRESS2
							,NULL							AS OTHERTOADDRESS3
							,NULL							AS OTHERTOCITY
							,NULL							AS OTHERTOSTATE
							,NULL							AS OTHERTOCOUNTRY
							,NULL							AS OTHERTOPOSTALCODE
							,NULL							AS OTHERTOINDUSTRY
							,NULL							AS OTHERTOGEOGRAPHY
							,NULL							AS REASONID
							,NULL							AS COMMENTS
							,CURRENT_TIMESTAMP				AS STAGEPROCESSDATE
							,0								AS STAGEPROCESSFLAG
							,CONST_TIPO_ESP					AS BUSINESSUNITNAME
							,NULL							AS BUSINESSUNITMAP
							,(CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN SUBSTR(CR.CODIGO_POLIZA,8) ELSE SUBSTR(CR.CODIGO_POLIZA,8,LENGTH(CR.CODIGO_POLIZA)-8) END)				
															AS GENERICATTRIBUTE1
							,CR.FORMA_PAGO					AS GENERICATTRIBUTE2
							,(CASE 
							    WHEN CR.MARCA_RECUPERADO = COSNT_RECU_POLIZA THEN 
							        CASE 
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR CR.CODIGO_AGENTE_ORIGINAL <> '') 
							            THEN CONST_RP_NEG_CON_AGENTE
							            
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL AND CR.CODIGO_AGENTE_ORIGINAL = '') 
							            THEN CONST_RP_NEG_SIN_AGENTE
							
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR CR.CODIGO_AGENTE_ORIGINAL <> '') 
							            THEN CONST_RP_POS_CON_AGENTE
							
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL AND CR.CODIGO_AGENTE_ORIGINAL = '') 
							            THEN CONST_RP_POS_SIN_AGENTE
							        END
							        
							    WHEN CR.MARCA_RECUPERADO = CONST_RECU_RECIBO THEN 
							        CASE 
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR CR.CODIGO_AGENTE_ORIGINAL <> '') 
							            THEN CONST_RR_NEG_CON_AGENTE
							            
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) < 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL AND CR.CODIGO_AGENTE_ORIGINAL = '') 
							            THEN CONST_RR_NEG_SIN_AGENTE
							
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NOT NULL OR CR.CODIGO_AGENTE_ORIGINAL <> '') 
							            THEN CONST_RR_POS_CON_AGENTE
							
							            WHEN (CASE WHEN SUBSTR(CR.PRIMA_NETA_RECIBO,1,1) = '0' THEN 0 ELSE TO_NUMBER(CR.PRIMA_NETA_RECIBO) END) >= 0 
							                 AND (CR.CODIGO_AGENTE_ORIGINAL IS NULL AND CR.CODIGO_AGENTE_ORIGINAL = '') 
							            THEN CONST_RR_POS_SIN_AGENTE
							        END
							END)							AS GENERICATTRIBUTE3
							,NULL 							AS GENERICATTRIBUTE4
							,NULL							AS GENERICATTRIBUTE5
							,CR.ESTADO_RECIBO				AS GENERICATTRIBUTE6
							,CR.TIPO_RECIBO					AS GENERICATTRIBUTE7
							,NULL							AS GENERICATTRIBUTE8
							,NULL							AS GENERICATTRIBUTE9
							,CR.DISTRITO_COBRO 				AS GENERICATTRIBUTE10
							,CR.MOTIVO_ALTA					AS GENERICATTRIBUTE11
							,NULL							AS GENERICATTRIBUTE12
							,NULL							AS GENERICATTRIBUTE13
							,NULL							AS GENERICATTRIBUTE14
							,NULL							AS GENERICATTRIBUTE15
							,NULL							AS GENERICATTRIBUTE16
							,NULL							AS GENERICATTRIBUTE17
							,NULL							AS GENERICATTRIBUTE18
							,NULL							AS GENERICATTRIBUTE19
							,NULL							AS GENERICATTRIBUTE20
							,NULL							AS GENERICATTRIBUTE21							
							,CR.MOTIVO_BAJA					AS GENERICATTRIBUTE22
							,NULL			 				AS GENERICATTRIBUTE23
							,NULL							AS GENERICATTRIBUTE24
							,CR.TIPO_MOVIMIENTO				AS GENERICATTRIBUTE25
							,NULL							AS GENERICATTRIBUTE26
							,NULL							AS GENERICATTRIBUTE27
							,NULL							AS GENERICATTRIBUTE28
							,NULL							AS GENERICATTRIBUTE29
							,NULL							AS GENERICATTRIBUTE30
							,NULL							AS GENERICATTRIBUTE31
							,NULL							AS GENERICATTRIBUTE32
							,(CEIL((CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN CR.PRIMA_NETA_RECIBO ELSE CR.PRIMA_NETA_RECIBO / CR.v_mensualidades END) * 100 ) / 100)
															AS GENERICNUMBER1 --PRIMA NETA RECIBIDA
							,CONST_TIPO_EURO				AS UNITTYPEFORGENERICNUMBER1 --UNIT TYPE PRIMA NETA RECIBIDA
							,NULL							AS GENERICNUMBER2
							,NULL							AS UNITTYPEFORGENERICNUMBER2
							,NULL							AS GENERICNUMBER3
							,NULL							AS UNITTYPEFORGENERICNUMBER3
							,NULL							AS GENERICNUMBER4
							,NULL							AS UNITTYPEFORGENERICNUMBER4
							,NULL							AS GENERICNUMBER5
							,NULL							AS UNITTYPEFORGENERICNUMBER5
							,NULL							AS GENERICNUMBER6
							,NULL							AS UNITTYPEFORGENERICNUMBER6
							,CR.FECHA_EFECTO_POLIZA			AS GENERICDATE1
							
							,CR.CARGO_COMPENSACION			AS GENERICDATE2 
							,CR.ST_GENERICDATE3				AS GENERICDATE3
							,NULL							AS GENERICDATE4
							,NULL							AS GENERICDATE5
							,NULL							AS GENERICDATE6		
							,NULL			 				AS GENERICBOOLEAN1
							,CR.cobraSubvencion 			AS GENERICBOOLEAN2	-- Es el campo RIESGO, pero vamos a mandar si cobraria Subvencion
							,(CASE WHEN CR.cobraComision > 1 THEN 1 ELSE CR.cobraComision END)
															AS GENERICBOOLEAN3  --Es el campo DISM. PRIMA, pero vamos a mandar si cobraria Comision
							,0								AS GENERICBOOLEAN4	--PERIODO EXTORNABLE
							,CASE WHEN CR.MOTIVO_ALTA IN ('TP','TS','DT','RC','DE') THEN 1 ELSE 0 END
															AS GENERICBOOLEAN5  -- Es el campo COLECTIVO pero vamos a mandar si es sustitucion de alta o no
							,CASE WHEN CR.MOTIVO_BAJA IN ('94','92','56','80') THEN 1 ELSE 0 END		 
															AS GENERICBOOLEAN6	--Es el campo AUTOLIQUIDA pero vamos a mandar si es sustitucion de baja o no
							,NULL							AS STAGEERRORCODE
							,NULL							AS COMPENSATIONDATE_OLD
							,NULL							AS PUSEQ_OLD
					FROM :TBL_DATOS_SALESTRANSACTION CR
					--WHERE CR.ROWNUM = 1
					WHERE NOT EXISTS (
						SELECT 1 FROM EXT.SALESTRANSACTION ST WHERE ST.ORDERID = (CR.PRODUCTO_CONTABLE || SUBSTR(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO)
						AND ST.LINENUMBER = TO_NUMBER(SUBSTR(REPLACE(CR.CARGO_COMPENSACION, '-', ''), 1, 6))
						AND ST.SUBLINENUMBER = TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))
						AND ST.EVENTTYPEID = CR.PERMANENCIA
					)
					AND CR.ROWNUM = 1
					;
					
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		TBL_DATOS_TRANSACTIONASSIGN = (
			SELECT DISTINCT
				CC.*
				,ROW_NUMBER() OVER (
		        	PARTITION BY (CC.PRODUCTO_CONTABLE || SUBSTR(CC.CODIGO_POLIZA,8) || CC.ESTADO_RECIBO || CC.TIPO_MOVIMIENTO),
		            			TO_NUMBER(SUBSTR(REPLACE(CC.CARGO_COMPENSACION, '-', ''), 1, 6)),
		            			TO_NUMBER(SUBSTR(CC.CODIGO_POLIZA, 1, 7)),
		            			CC.PERMANENCIA
		            ORDER BY CC.CODIGO_POLIZA
		        ) AS ROWNUM
		    FROM :TBL_COBRA_COMISION CC
			INNER JOIN :TBL_COBRA_SUBVENCION CS
		        ON CC.CODIGO_POLIZA = CS.CODIGO_POLIZA
				-- AND CC.CODIGO_RECIBO = CS.CODIGO_RECIBO
				-- AND CC.CODIGO_SUPLEMENTO = CS.CODIGO_SUPLEMENTO
				-- AND CC.ESTADO_RECIBO = CS.ESTADO_RECIBO
			WHERE (CS.cobraSubvencion = 1 OR IFNULL(CC.cobraComision,0) > 0)
		);
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_DATOS_TRANSACTIONASSIGN ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		--SE INSERTA TRANSACCION
		INSERT INTO EXT.TRANSACTIONASSIGN
					SELECT
						v_tenantid			AS TENANTID
						,NULL	
														AS STAGESALESTRANSACTIONSEQ
						,1								AS SETNUMBER
						,'TXSTA_' || CR.FILE_NAME		AS BATCHNAME
						,CR.FILE_NAME					AS FILE_IN_RECIBOS
						,(CR.PRODUCTO_CONTABLE||substr(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO)					
														AS ORDERID
						,TO_NUMBER(SUBSTR(REPLACE(CR.CARGO_COMPENSACION,'-',''), 1, 6))					
														AS LINENUMBER
						,TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))				
														AS SUBLINENUMBER
						,CR.PERMANENCIA				    AS EVENTTYPEID
						,NULL							AS SALESTRANSACTIONSEQ
						,NULL							AS PAYEEID				
						,NULL							AS PAYEETYPE			
						,CASE WHEN (
							SELECT COUNT(*)
							FROM :TBL_GEN_CODIGOS_AGENTE
							WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
							) > 0 
								THEN (
									SELECT IFNULL(MAX(CODIGO_UNICO), :CONST_NO_ENCONTRADO) 
									FROM :TBL_GEN_CODIGOS_AGENTE
									WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
									) 
								ELSE 
									(
										IFNULL(
											(SELECT MAX(X.CODIGO_UNICO) FROM (
												SELECT T.CODIGO_UNICO
												, ROW_NUMBER() OVER (
						        						PARTITION BY T.CODIGO_OCASO
						        						ORDER BY T.EFFECTIVEENDDATE DESC
						        							, CASE WHEN CR.CODIGO_AGENTE_ORIGINAL = T.CODIGO_OCASO
						        								THEN 1
						        								ELSE 2
						        							END ASC
						        					) AS ROW_NUM_COD_UNI 
												FROM :TBL_GEN_CODIGOS_AGENTE T
								                WHERE T.CODIGO_OCASO = CR.CODIGO_AGENTE_ORIGINAL
											) X WHERE X.ROW_NUM_COD_UNI = 1 
										), :CONST_NO_ENCONTRADO)
									)
						END								AS POSITIONNAME							
						,NULL							AS TITLENAME			
						,NULL							AS GENERICATTRIBUTE1	
						,NULL							AS GENERICATTRIBUTE2	
						,CASE WHEN (
									SELECT COUNT(*)
									FROM :TBL_GEN_CODIGOS_AGENTE
									WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
								) > 0 
							THEN (
									SELECT IFNULL(MAX(CODIGO_OCASO), :CONST_NO_ENCONTRADO) 
									FROM :TBL_GEN_CODIGOS_AGENTE
									WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
								) 
							ELSE CR.CODIGO_AGENTE_ORIGINAL
								
						END								AS GENERICATTRIBUTE3	
						,NULL							AS GENERICATTRIBUTE4
						,NULL							AS GENERICATTRIBUTE5
						,NULL							AS GENERICATTRIBUTE6
						,NULL							AS GENERICATTRIBUTE7
						,NULL							AS GENERICATTRIBUTE8
						,NULL							AS GENERICATTRIBUTE9
						,NULL							AS GENERICATTRIBUTE10
						,NULL							AS GENERICATTRIBUTE11
						,NULL							AS GENERICATTRIBUTE12
						,NULL							AS GENERICATTRIBUTE13
						,NULL							AS GENERICATTRIBUTE14
						,NULL							AS GENERICATTRIBUTE15
						,NULL							AS GENERICATTRIBUTE16
						,NULL							AS GENERICNUMBER1
						,NULL							AS UNITTYPEFORGENERICNUMBER1
						,NULL							AS GENERICNUMBER2
						,NULL							AS UNITTYPEFORGENERICNUMBER2
						,NULL							AS GENERICNUMBER3
						,NULL							AS UNITTYPEFORGENERICNUMBER3
						,NULL							AS GENERICNUMBER4
						,NULL							AS UNITTYPEFORGENERICNUMBER4
						,NULL							AS	GENERICNUMBER5
						,NULL							AS UNITTYPEFORGENERICNUMBER5
						,NULL							AS GENERICNUMBER6
						,NULL 							AS UNITTYPEFORGENERICNUMBER6
						,NULL							AS GENERICDATE1
						,NULL							AS GENERICDATE2
						,NULL							AS GENERICDATE3
						,NULL							AS GENERICDATE4
						,NULL							AS GENERICDATE5
						,NULL							AS GENERICDATE6
						,NULL							AS GENERICBOOLEAN1
						,NULL							AS GENERICBOOLEAN2
						,NULL							AS GENERICBOOLEAN3
						,NULL							AS GENERICBOOLEAN4
						,NULL							AS GENERICBOOLEAN5
						,NULL							AS GENERICBOOLEAN6
					FROM :TBL_DATOS_TRANSACTIONASSIGN CR
					WHERE NOT EXISTS (
						SELECT 1 FROM EXT.TRANSACTIONASSIGN ST WHERE ST.ORDERID = (CR.PRODUCTO_CONTABLE || SUBSTR(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO)
						AND ST.LINENUMBER = TO_NUMBER(SUBSTR(REPLACE(CR.CARGO_COMPENSACION, '-', ''), 1, 6))
						AND ST.SUBLINENUMBER = TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))
						AND ST.EVENTTYPEID = CR.PERMANENCIA
					)
					AND CR.ROWNUM = 1
					;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		
	END;
		
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'INICIO Insertar TRX para extornar 21% ',v_log_count, i_id_proceso, 'info');
	BEGIN
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
			BEGIN
			
			ROLLBACK;
			
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en Insertar TRX para extornar 21% - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
										|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');

				UPDATE EXT.IN_BATCH_CONTROL
				SET STATUS = :v_const_populate_status_error,
				END_DATE = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ID_PROCESO = :i_id_proceso;
			
				--Se actualizan los registros de STAGE_RECIBOS con estado err�neo
				UPDATE EXT.STAGE_RECIBOS
				SET ESTADO = :v_const_populate_status_error,
				FECHA_MODIFICACION = CURRENT_TIMESTAMP
				WHERE FILE_NAME = :i_file_name
				AND ESTADO = :v_const_stage_status_ok;
				
				COMMIT;
				RESIGNAL;
			END;
	
		TBL_DATOS_SALESTRANSACTION_EXTORNO = (
			SELECT DISTINCT
		        SERCO.*,
		        M.v_mensualidades,
		        CC.cobraComision,
		        CS.cobraSubvencion,
		        R.TIPO_RECUPERACION,
		        GR.PRIMA_COMISIONABLE,
		        (
		        	CASE WHEN CC.v_ExistePoliza > 0 
		        	THEN
		        		(
		        			SELECT MIN(POL.FECHA_EMISION_POLIZA)
		        			FROM EXT.POLIZAS POL
		        			WHERE SUBSTR(POL.CODIGO_POLIZA,1,22) = SUBSTR(SERCO.CODIGO_POLIZA,1,22)
							AND POL.RAMO = SERCO.RAMO
		        		)
		        	ELSE SERCO.FECHA_EMISION_POLIZA
		        	END
		        ) AS ST_GENERICDATE3
		        ,ROW_NUMBER() OVER (
		        	PARTITION BY (SERCO.PRODUCTO_CONTABLE || SUBSTR(SERCO.CODIGO_POLIZA,8) || SERCO.ESTADO_RECIBO || SERCO.TIPO_MOVIMIENTO),
		            			TO_NUMBER(SUBSTR(REPLACE(SERCO.CARGO_COMPENSACION, '-', ''), 1, 6)),
		            			TO_NUMBER(SUBSTR(SERCO.CODIGO_POLIZA, 1, 7)),
		            			SERCO.PERMANENCIA
		            ORDER BY SERCO.CODIGO_POLIZA
		        ) AS ROWNUM
		    FROM :TBL_C_SERCO_STAGE SERCO
		    INNER JOIN (
		    	SELECT *, ROW_NUMBER() OVER (PARTITION BY TRIM(CODIGO_POLIZA) ORDER BY FECHA_EFECTO_RECIBO DESC) AS RN
				FROM :TBL_MENSUALIDADES
		    ) M
				ON SERCO.CODIGO_POLIZA = M.CODIGO_POLIZA
				-- AND SERCO.CODIGO_RECIBO = M.CODIGO_RECIBO
				-- AND SERCO.CODIGO_SUPLEMENTO = M.CODIGO_SUPLEMENTO
				-- AND SERCO.ESTADO_RECIBO = M.ESTADO_RECIBO
		    INNER JOIN :TBL_COBRA_COMISION CC
		        ON SERCO.CODIGO_POLIZA = CC.CODIGO_POLIZA
				-- AND SERCO.CODIGO_RECIBO = CC.CODIGO_RECIBO
				-- AND SERCO.CODIGO_SUPLEMENTO = CC.CODIGO_SUPLEMENTO
				-- AND SERCO.ESTADO_RECIBO = CC.ESTADO_RECIBO
		    INNER JOIN :TBL_COBRA_SUBVENCION CS
		        ON SERCO.CODIGO_POLIZA = CS.CODIGO_POLIZA
				-- AND SERCO.CODIGO_RECIBO = CS.CODIGO_RECIBO
				-- AND SERCO.CODIGO_SUPLEMENTO = CS.CODIGO_SUPLEMENTO
				-- AND SERCO.ESTADO_RECIBO = CS.ESTADO_RECIBO
			LEFT JOIN EXT.RECIBOS R
				ON SERCO.CODIGO_POLIZA = R.CODIGO_POLIZA
				AND R.CODIGO_RECIBO = CONST_COD_RECIBO_SERCO
				AND IFNULL(SERCO.ESTADO_RECIBO,CONST_RECIBO_COBRADO) = R.ESTADO_RECIBO
				AND R.CODIGO_SUPLEMENTO = SERCO.CODIGO_SUPLEMENTO
			LEFT JOIN EXT.GARANTIAS_RECIBO GR
				ON SERCO.CODIGO_POLIZA = GR.CODIGO_POLIZA
				AND SERCO.CODIGO_RECIBO = CONST_COD_RECIBO_SERCO
				AND IFNULL(SERCO.ESTADO_RECIBO,CONST_RECIBO_COBRADO) = GR.ESTADO_RECIBO
				AND SERCO.PRODUCTO_CONTABLE = GR.PRODUCTO_CONTABLE
				AND SERCO.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
			WHERE CC.cobraComision = 2 AND CS.cobraSubvencion = 1
			AND M.RN = 1	
		);
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_DATOS_SALESTRANSACTION_EXTORNO ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
		--------------------------------TABLA DEBUG PENDIENTE BORRAR
	    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_DATOS_SALESTRANSACTION_EXTORNO_DEBUG';
		IF v_existe_tabla > 0 THEN
			DROP TABLE EXT.TBL_DATOS_SALESTRANSACTION_EXTORNO_DEBUG;
		END IF;
		CREATE TABLE EXT.TBL_DATOS_SALESTRANSACTION_EXTORNO_DEBUG AS (SELECT * FROM :TBL_DATOS_SALESTRANSACTION_EXTORNO);
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_DATOS_SALESTRANSACTION_EXTORNO_DEBUG' , v_log_count, i_id_proceso, 'debug');
		------------------------------
		
		--Insertamos una nueva trx para extornar el 21% al agente anterior si es necesario
		INSERT INTO EXT.SALESTRANSACTION
					SELECT 
							v_tenantid			AS TENANTID
							,EXT.SEQSTAGESALESTRANSACTION.NEXTVAL							
															AS STAGESALESTRANSACTIONSEQ
							,'TXSTA_' || CR.FILE_NAME		AS BATCHNAME
							,CR.FILE_NAME					AS FILE_IN_RECIBOS	
							,(CR.PRODUCTO_CONTABLE||substr(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO || 'E')					
															AS ORDERID
							,TO_NUMBER(TO_VARCHAR(CR.CARGO_COMPENSACION, 'YYYYMM'))				
															AS LINENUMBER
							,TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))					
															AS SUBLINENUMBER
							,CR.PERMANENCIA					AS EVENTTYPEID
							,NULL							AS SALESTRANSACTIONSEQ
							,NULL							AS SALESORDERSEQ
							,CR.CARGO_COMPENSACION			AS ACCOUNTINGDATE
							,CR.PRODUCTO_CONTABLE			AS PRODUCTID
							,NULL							AS PRODUCTNAME
							,NULL							AS PRODUCTDESCRIPTION
							,(CEIL((CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN CR.PRIMA_NETA_RECIBO ELSE CR.PRIMA_NETA_RECIBO / CR.v_mensualidades END) * 100 ) / 100)
															AS VALUE
							,CONST_TIPO_EURO				AS UNITTYPEFORVALUE
							,NULL							AS NUMBEROFUNITS
							,NULL							AS UNITVALUE
							,NULL							AS UNITTYPEFORUNITVALUE
							,CR.CARGO_COMPENSACION		    AS COMPENSATIONDATE
							,NULL							AS PAYMENTTERMS
							,NULL							AS PONUMBER
							,SUBSTR(CR.CODIGO_POLIZA,1, 2)	AS CHANNEL
							,NULL							AS ALTERNATEORDERNUMBER
							,NULL							AS DATASOURCE
							,CASE WHEN (CR.RAMO = CONST_RAMA_RRTT) AND (CR.PRIMA_NETA_RECIBO / CR.v_mensualidades) IS NOT NULL THEN CONST_TIPO_EURO END 						
															AS NATIVECURRENCY
							,(-1)*(CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN (CASE WHEN CR.PRIMA_NETA_RECIBO/CR.v_mensualidades > ABS(CR.PRIMA_COMISIONABLE) THEN ABS(CR.PRIMA_COMISIONABLE) ELSE CR.PRIMA_NETA_RECIBO / CR.v_mensualidades END) END)
															AS NATIVECURRENCYAMOUNT
							,CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN 1/CR.v_mensualidades END
															AS DISCOUNTPERCENT
							,CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN CONST_TIPO_PERCENTAGE END
															AS DISCOUNTTYPE
							,NULL							AS BILLTOCUSTID
							,NULL							AS BILLTOCONTACT
							,NULL							AS BILLTOCOMPANY
							,NULL							AS BILLTOAREACODE
							,NULL							AS BILLTOPHONE
							,NULL							AS BILLTOFAX
							,NULL							AS BILLTOADDRESS1
							,NULL							AS BILLTOADDRESS2
							,NULL							AS BILLTOADDRESS3
							,NULL							AS BILLTOCITY
							,NULL							AS BILLTOSTATE
							,NULL							AS BILLTOCOUNTRY
							,NULL							AS BILLTOPOSTALCODE
							,NULL							AS BILLTOINDUSTRY
							,NULL							AS BILLTOGEOGRAPHY
							,NULL							AS SHIPTOCUSTID
							,NULL							AS SHIPTOCONTACT
							,NULL							AS SHIPTOCOMPANY
							,NULL							AS SHIPTOAREACODE
							,NULL							AS SHIPTOPHONE
							,NULL							AS SHIPTOFAX
							,NULL							AS SHIPTOADDRESS1
							,NULL							AS SHIPTOADDRESS2
							,NULL							AS SHIPTOADDRESS3
							,NULL							AS SHIPTOCITY
							,NULL							AS SHIPTOSTATE
							,NULL							AS SHIPTOCOUNTRY
							,NULL							AS SHIPTOPOSTALCODE
							,NULL							AS SHIPTOINDUSTRY
							,NULL							AS SHIPTOGEOGRAPHY
							,NULL							AS OTHERTOCUSTID
							,NULL							AS OTHERTOCONTACT
							,NULL							AS OTHERTOCOMPANY
							,NULL							AS OTHERTOAREACODE
							,NULL							AS OTHERTOPHONE
							,NULL							AS OTHERTOFAX
							,NULL							AS OTHERTOADDRESS1
							,NULL							AS OTHERTOADDRESS2
							,NULL							AS OTHERTOADDRESS3
							,NULL							AS OTHERTOCITY
							,NULL							AS OTHERTOSTATE
							,NULL							AS OTHERTOCOUNTRY
							,NULL							AS OTHERTOPOSTALCODE
							,NULL							AS OTHERTOINDUSTRY
							,NULL							AS OTHERTOGEOGRAPHY
							,NULL							AS REASONID
							,NULL							AS COMMENTS
							,CURRENT_TIMESTAMP				AS STAGEPROCESSDATE
							,0								AS STAGEPROCESSFLAG
							,CONST_TIPO_ESP					AS BUSINESSUNITNAME
							,NULL							AS BUSINESSUNITMAP
							,(CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN SUBSTR(CR.CODIGO_POLIZA,8) ELSE SUBSTR(CR.CODIGO_POLIZA,8,LENGTH(CR.CODIGO_POLIZA)-8) END)				
															AS GENERICATTRIBUTE1			
							,CR.FORMA_PAGO					AS GENERICATTRIBUTE2
							,CR.TIPO_RECUPERACION			AS GENERICATTRIBUTE3
							,NULL 							AS GENERICATTRIBUTE4
							,NULL							AS GENERICATTRIBUTE5
							,CR.ESTADO_RECIBO				AS GENERICATTRIBUTE6
							,CR.TIPO_RECIBO					AS GENERICATTRIBUTE7
							,NULL							AS GENERICATTRIBUTE8
							,NULL							AS GENERICATTRIBUTE9
							,CR.DISTRITO_COBRO 				AS GENERICATTRIBUTE10
							,CR.MOTIVO_ALTA					AS GENERICATTRIBUTE11
							,NULL							AS GENERICATTRIBUTE12
							,NULL							AS GENERICATTRIBUTE13
							,NULL							AS GENERICATTRIBUTE14
							,NULL							AS GENERICATTRIBUTE15
							,NULL							AS GENERICATTRIBUTE16
							,NULL							AS GENERICATTRIBUTE17
							,NULL							AS GENERICATTRIBUTE18
							,NULL							AS GENERICATTRIBUTE19
							,NULL							AS GENERICATTRIBUTE20
							,NULL							AS GENERICATTRIBUTE21							
							,CR.MOTIVO_BAJA					AS GENERICATTRIBUTE22
							,NULL			 				AS GENERICATTRIBUTE23
							,NULL							AS GENERICATTRIBUTE24
							,CR.TIPO_MOVIMIENTO				AS GENERICATTRIBUTE25
							,NULL							AS GENERICATTRIBUTE26
							,NULL							AS GENERICATTRIBUTE27
							,NULL							AS GENERICATTRIBUTE28
							,NULL							AS GENERICATTRIBUTE29
							,NULL							AS GENERICATTRIBUTE30
							,NULL							AS GENERICATTRIBUTE31
							,NULL							AS GENERICATTRIBUTE32
							,(CEIL((CASE WHEN CR.RAMO = CONST_RAMA_RRTT THEN CR.PRIMA_NETA_RECIBO ELSE CR.PRIMA_NETA_RECIBO / CR.v_mensualidades END) * 100 ) / 100)
															AS GENERICNUMBER1 --PRIMA NETA RECIBIDA
							,CONST_TIPO_EURO				AS UNITTYPEFORGENERICNUMBER1 --UNIT TYPE PRIMA NETA RECIBIDA
							,NULL							AS GENERICNUMBER2
							,NULL							AS UNITTYPEFORGENERICNUMBER2
							,NULL							AS GENERICNUMBER3
							,NULL							AS UNITTYPEFORGENERICNUMBER3
							,NULL							AS GENERICNUMBER4
							,NULL							AS UNITTYPEFORGENERICNUMBER4
							,NULL							AS GENERICNUMBER5
							,NULL							AS UNITTYPEFORGENERICNUMBER5
							,NULL							AS GENERICNUMBER6
							,NULL							AS UNITTYPEFORGENERICNUMBER6
							,CR.FECHA_EFECTO_POLIZA			AS GENERICDATE1
							,CR.CARGO_COMPENSACION			AS GENERICDATE2 
							,CR.ST_GENERICDATE3				AS GENERICDATE3
							,NULL							AS GENERICDATE4
							,NULL							AS GENERICDATE5
							,NULL							AS GENERICDATE6		
							,NULL			 				AS GENERICBOOLEAN1
							,CR.cobraSubvencion 			AS GENERICBOOLEAN2	-- Es el campo RIESGO, pero vamos a mandar si cobrar�a Subvenci�n
							,(CASE WHEN CR.cobraComision > 1 THEN 1 ELSE CR.cobraComision END)
															AS GENERICBOOLEAN3  --Es el campo DISM. PRIMA, pero vamos a mandar si cobrar�a Comisi�n
							,'0'							AS GENERICBOOLEAN4	--PERIODO EXTORNABLE
							,CASE WHEN CR.MOTIVO_ALTA IN ('TP','TS','DT','RC','DE') THEN 1 ELSE 0 END
															AS GENERICBOOLEAN5  -- Es el campo COLECTIVO pero vamos a mandar si es sustituci�n de alta o no
							,CASE WHEN CR.MOTIVO_BAJA IN ('94','92','56','80') THEN 1 ELSE 0 END		 
															AS GENERICBOOLEAN6	--Es el campo AUTOLIQUIDA pero vamos a mandar si es sustituci�n de baja o no
							,NULL							AS STAGEERRORCODE
							,NULL							AS COMPENSATIONDATE_OLD
							,NULL							AS PUSEQ_OLD
					FROM :TBL_DATOS_SALESTRANSACTION_EXTORNO CR
					WHERE NOT EXISTS (
						SELECT 1 FROM EXT.SALESTRANSACTION ST 
						WHERE ST.ORDERID = (CR.PRODUCTO_CONTABLE || SUBSTR(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO||'E')
						AND ST.LINENUMBER = TO_NUMBER(TO_VARCHAR(CR.CARGO_COMPENSACION, 'YYYYMM'))	
						AND ST.SUBLINENUMBER = TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))
						AND ST.EVENTTYPEID = CR.PERMANENCIA
					)
					AND CR.ROWNUM = 1
					;
					
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en SALESTRANSACTION orderid E' || v_num_rows , v_log_count, i_id_proceso, 'info');
			
			
			
			TBL_DATOS_TRANSACTIONASSIGN_EXTORNO = (
				SELECT DISTINCT
					CC.*
					,ROW_NUMBER() OVER (
			        	PARTITION BY (CC.PRODUCTO_CONTABLE || SUBSTR(CC.CODIGO_POLIZA,8) || CC.ESTADO_RECIBO || CC.TIPO_MOVIMIENTO),
			            			TO_NUMBER(SUBSTR(REPLACE(CC.CARGO_COMPENSACION, '-', ''), 1, 6)),
			            			TO_NUMBER(SUBSTR(CC.CODIGO_POLIZA, 1, 7)),
			            			CC.PERMANENCIA
			            ORDER BY CC.CODIGO_POLIZA
			        ) AS ROWNUM
			    FROM :TBL_COBRA_COMISION CC
				INNER JOIN :TBL_COBRA_SUBVENCION CS
					ON CC.CODIGO_POLIZA = CS.CODIGO_POLIZA
					-- AND CC.CODIGO_RECIBO = CS.CODIGO_RECIBO
					-- AND CC.CODIGO_SUPLEMENTO = CS.CODIGO_SUPLEMENTO
					-- AND CC.ESTADO_RECIBO = CS.ESTADO_RECIBO
				WHERE CC.cobraComision = 2 AND CS.cobraSubvencion = 1
			);
			v_num_rows := ::rowcount;
			CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TBL_DATOS_TRANSACTIONASSIGN_EXTORNO ' || v_num_rows , v_log_count, i_id_proceso, 'info');
			
			--------------------------------TABLA DEBUG PENDIENTE BORRAR
		    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_DATOS_TRANSACTIONASSIGN_EXTORNO_DEBUG';
			IF v_existe_tabla > 0 THEN
				DROP TABLE EXT.TBL_DATOS_TRANSACTIONASSIGN_EXTORNO_DEBUG;
			END IF;
			CREATE TABLE EXT.TBL_DATOS_TRANSACTIONASSIGN_EXTORNO_DEBUG AS (SELECT * FROM :TBL_DATOS_TRANSACTIONASSIGN_EXTORNO);
		    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_DATOS_TRANSACTIONASSIGN_EXTORNO_DEBUG' , v_log_count, i_id_proceso, 'debug');
    		------------------------------
			
			INSERT INTO EXT.TRANSACTIONASSIGN
					SELECT 
						v_tenantid						AS TENANTID
						,NULL							AS STAGESALESTRANSACTIONSEQ
						,1								AS SETNUMBER
						,'TXSTA_' || CR.FILE_NAME		AS BATCHNAME
						,CR.FILE_NAME					AS FILE_IN_RECIBOS
						,(CR.PRODUCTO_CONTABLE||substr(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO || 'E')					
														AS ORDERID
						,TO_NUMBER(TO_VARCHAR(CR.CARGO_COMPENSACION, 'YYYYMM'))						
														AS LINENUMBER
						,TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))				
														AS SUBLINENUMBER
						,CR.PERMANENCIA				    AS EVENTTYPEID
						,NULL							AS SALESTRANSACTIONSEQ
						,NULL							AS PAYEEID				
						,NULL							AS PAYEETYPE			
						,CASE WHEN (
							SELECT COUNT(*)
							FROM :TBL_GEN_CODIGOS_AGENTE
							WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
						) > 0 
							THEN (
								SELECT IFNULL(MAX(CODIGO_UNICO), :CONST_NO_ENCONTRADO) 
								FROM :TBL_GEN_CODIGOS_AGENTE
								WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
							) 
							ELSE 
							(
								IFNULL(
									(SELECT MAX(X.CODIGO_UNICO) FROM (
										SELECT T.CODIGO_UNICO
										, ROW_NUMBER() OVER (
				        						PARTITION BY T.CODIGO_OCASO
				        						ORDER BY T.EFFECTIVEENDDATE DESC
				        							, CASE WHEN CR.CODIGO_AGENTE_ORIGINAL = T.CODIGO_OCASO
				        								THEN 1
				        								ELSE 2
				        							END ASC
				        					) AS ROW_NUM_COD_UNI 
										FROM :TBL_GEN_CODIGOS_AGENTE T
						                WHERE T.CODIGO_OCASO = CR.CODIGO_AGENTE_ORIGINAL
									) X WHERE X.ROW_NUM_COD_UNI = 1 
								), :CONST_NO_ENCONTRADO)
							)
							END							AS POSITIONNAME			
						,NULL							AS TITLENAME			
						,NULL							AS GENERICATTRIBUTE1	
						,NULL							AS GENERICATTRIBUTE2	
						,CASE WHEN (
									SELECT COUNT(*)
									FROM :TBL_GEN_CODIGOS_AGENTE
									WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
								) > 0 
							THEN (
									SELECT IFNULL(MAX(CODIGO_OCASO), :CONST_NO_ENCONTRADO) 
									FROM :TBL_GEN_CODIGOS_AGENTE
									WHERE CODIGO_UNICO = CR.CODIGO_AGENTE_ORIGINAL
								) 
							ELSE CR.CODIGO_AGENTE_ORIGINAL
								
						END								AS GENERICATTRIBUTE3		
						,NULL							AS GENERICATTRIBUTE4
						,NULL							AS GENERICATTRIBUTE5
						,NULL							AS GENERICATTRIBUTE6
						,NULL							AS GENERICATTRIBUTE7
						,NULL							AS GENERICATTRIBUTE8
						,NULL							AS GENERICATTRIBUTE9
						,NULL							AS GENERICATTRIBUTE10
						,NULL							AS GENERICATTRIBUTE11
						,NULL							AS GENERICATTRIBUTE12
						,NULL							AS GENERICATTRIBUTE13
						,NULL							AS GENERICATTRIBUTE14
						,NULL							AS GENERICATTRIBUTE15
						,NULL							AS GENERICATTRIBUTE16
						,NULL							AS GENERICNUMBER1
						,NULL							AS UNITTYPEFORGENERICNUMBER1
						,NULL							AS GENERICNUMBER2
						,NULL							AS UNITTYPEFORGENERICNUMBER2
						,NULL							AS GENERICNUMBER3
						,NULL							AS UNITTYPEFORGENERICNUMBER3
						,NULL							AS GENERICNUMBER4
						,NULL								AS UNITTYPEFORGENERICNUMBER4
						,NULL							AS	GENERICNUMBER5
						,NULL								AS UNITTYPEFORGENERICNUMBER5
						,NULL							AS GENERICNUMBER6
						,NULL 							AS UNITTYPEFORGENERICNUMBER6
						,NULL							AS GENERICDATE1
						,NULL							AS GENERICDATE2
						,NULL							AS GENERICDATE3
						,NULL							AS GENERICDATE4
						,NULL							AS GENERICDATE5
						,NULL							AS GENERICDATE6
						,NULL							AS GENERICBOOLEAN1
						,NULL							AS GENERICBOOLEAN2
						,NULL							AS GENERICBOOLEAN3
						,NULL							AS GENERICBOOLEAN4
						,NULL							AS GENERICBOOLEAN5
						,NULL							AS GENERICBOOLEAN6
					FROM :TBL_DATOS_TRANSACTIONASSIGN_EXTORNO CR
					WHERE NOT EXISTS (
						SELECT 1 FROM EXT.TRANSACTIONASSIGN ST WHERE ST.ORDERID =  (CR.PRODUCTO_CONTABLE || SUBSTR(CR.CODIGO_POLIZA,8) || CR.ESTADO_RECIBO || CR.TIPO_MOVIMIENTO||'E')
						AND ST.LINENUMBER = TO_NUMBER(TO_VARCHAR(CR.CARGO_COMPENSACION, 'YYYYMM'))	
						AND ST.SUBLINENUMBER = TO_NUMBER(SUBSTR(CR.CODIGO_POLIZA, 1, 7))
						AND ST.EVENTTYPEID = CR.PERMANENCIA
					)
					AND CR.ROWNUM = 1
					;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en TRANSACTIONASSIGN orderid E ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	END;	
	
	--actualizamos STAGESALESTRANSACTIONSEQ para la TRANSACTIONASSIGN
	MERGE INTO EXT.TRANSACTIONASSIGN src
		USING (
			SELECT ST.ORDERID, ST.LINENUMBER, ST.SUBLINENUMBER, ST.EVENTTYPEID, ST.STAGESALESTRANSACTIONSEQ FROM EXT.SALESTRANSACTION ST
			WHERE ST.FILE_IN_RECIBOS = i_file_name
		) x
		ON src.ORDERID = x.ORDERID AND src.LINENUMBER = x.LINENUMBER AND src.SUBLINENUMBER = x.SUBLINENUMBER AND src.EVENTTYPEID = x.EVENTTYPEID AND src.FILE_IN_RECIBOS = i_file_name
		WHEN MATCHED THEN UPDATE 
			SET src.STAGESALESTRANSACTIONSEQ = x.STAGESALESTRANSACTIONSEQ
		;
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'stagesalestransactionseq igualados: ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	v_num_rows := 1;
	--ACTUALIZAR POSITIONNAME A MANAGERS PARA AGENTES TIPO 15
	WHILE (v_num_rows > 0) DO
	
		UPDATE EXT.TRANSACTIONASSIGN TA
		SET (TA.POSITIONNAME, TA.GENERICATTRIBUTE3, TA.GENERICATTRIBUTE2) = (
					SELECT IFNULL(MAX(POS.NAME), :CONST_NO_ENCONTRADO), IFNULL(MAX(POS.GENERICATTRIBUTE3), :CONST_NO_ENCONTRADO) , TA.GENERICATTRIBUTE3
					FROM TCMP.CS_POSITION POS
					WHERE POS.RULEELEMENTOWNERSEQ = (
						SELECT MAX(P.MANAGERSEQ) FROM :TBL_GEN_CODIGOS_AGENTE P
						WHERE P.CODIGO_UNICO = TA.POSITIONNAME
	                    AND P.EFFECTIVESTARTDATE <= CASE WHEN TA.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) 
	                    							ELSE LAST_DAY((SELECT MAX(R.FECHA_EMISION_REC)  FROM EXT.RECIBOS R WHERE SUBSTR(R.CODIGO_POLIZA,1,21) = SUBSTR(TA.ORDERID,1,21) AND R.FILE_NAME = :i_file_name)) END
	                    AND P.EFFECTIVEENDDATE > CASE WHEN TA.EVENTTYPEID = '16' THEN LAST_DAY(:v_fecha_compensacion) 
	                    							ELSE LAST_DAY((SELECT MAX(R.FECHA_EMISION_REC)  FROM EXT.RECIBOS R WHERE SUBSTR(R.CODIGO_POLIZA,1,21) = SUBSTR(TA.ORDERID,1,21) AND R.FILE_NAME = :i_file_name)) END
					)
	                AND POS.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion)
	                AND POS.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
	                AND POS.TENANTID = :v_tenantid
	                AND POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
	                -- No tenemos en cuenta las Position de manager que no tengan plan (TTL_SIN_PLAN).
	                AND POS.TITLESEQ <> 5629499534213290
		)
		WHERE (
				SELECT MAX(T.TIPO_AGENTE_PRIN) FROM :TBL_GEN_CODIGOS_AGENTE T WHERE T.CODIGO_UNICO = TA.POSITIONNAME 
				AND T.EFFECTIVESTARTDATE <= LAST_DAY(:v_fecha_compensacion) 
	            AND T.EFFECTIVEENDDATE > LAST_DAY(:v_fecha_compensacion)
			) = 15 
		AND FILE_IN_RECIBOS = :i_file_name;
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name, v_vueltas || ' - POSITIONNAMEs actualizados a MANAGERS: ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		v_vueltas := v_vueltas + 1;
	
	END WHILE;
	
	
	--BORRAMOS DATOS PREVIOS PARA SOBREESCRIBIRLOS		
	DELETE FROM TCMP.CS_STAGESALESTRANSACTION
	WHERE BATCHNAME = 'TXSTA_' || i_file_name;
	
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'DELETE en TCMP.CS_STAGESALESTRANSACTION, filas : ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	
	
	DELETE FROM TCMP.CS_STAGETRANSACTIONASSIGN
	WHERE BATCHNAME = 'TXSTA_' || i_file_name;
	v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'DELETE en TCMP.CS_STAGETRANSACTIONASSIGN, filas : ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				
				ROLLBACK;
				
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error INSERT TCMP.CS_STAGESALESTRANSACTION - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, i_id_proceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_populate_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_stage_status_ok
					;
				
					COMMIT;
					RESIGNAL;
				END;
		
		--INSERTAR EN CS_SALESTRANSACTION Y CS_TRANSACTIONASSIGNMENT DE TCMP
		INSERT INTO TCMP.CS_STAGESALESTRANSACTION
		(
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
			 FROM EXT.SALESTRANSACTION ST
			WHERE ST.BATCHNAME = 'TXSTA_' || i_file_name
			AND (ST.ORDERID, ST.SUBLINENUMBER, ST.LINENUMBER, ST.EVENTTYPEID) IN (
				SELECT TA.ORDERID, TA.SUBLINENUMBER, TA.LINENUMBER, TA.EVENTTYPEID FROM EXT.TRANSACTIONASSIGN TA WHERE TA.FILE_IN_RECIBOS = :i_file_name AND TA.POSITIONNAME <> :CONST_NO_ENCONTRADO 
			)
			
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Insert en TCMP.CS_STAGESALESTRANSACTION, filas : ' || v_num_rows , v_log_count, i_id_proceso, 'info');
	END;
	
	BEGIN
			DECLARE EXIT HANDLER FOR SQLEXCEPTION
				BEGIN
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error INSERT TCMP.CS_STAGETRANSACTIONASSIGN - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, i_id_proceso, 'error');
	
					UPDATE EXT.IN_BATCH_CONTROL
					SET STATUS = :v_const_populate_status_error,
					END_DATE = CURRENT_TIMESTAMP
					WHERE FILE_NAME = :i_file_name
					AND STATUS = :v_const_stage_status_ok
					;
					
					COMMIT;
					RESIGNAL;
				END;
	
		INSERT INTO TCMP.CS_STAGETRANSACTIONASSIGN
		(
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
			 FROM EXT.TRANSACTIONASSIGN TA
			WHERE TA.BATCHNAME = 'TXSTA_' || i_file_name
			AND TA.POSITIONNAME <> :CONST_NO_ENCONTRADO 
		);
		
		v_num_rows := ::rowcount;
		CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Insert en TCMP.CS_STAGETRANSACTIONASSIGN, filas : ' || v_num_rows , v_log_count, i_id_proceso, 'info');
		
	END;
	
	
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Actualiza estado IN_BATCH_CONTROL: 9' , v_log_count, i_id_proceso, 'info');
	--Si todo OK, update status en inbatch
	UPDATE EXT.IN_BATCH_CONTROL
		SET STATUS = :v_const_carga_status_ok, --9
			END_DATE = CURRENT_TIMESTAMP
		WHERE FILE_NAME = :i_file_name
		AND STATUS = :v_const_stage_status_ok
		;
	
	--Se actualizan los registros de STAGE_RECIBOS con estado correcto
	UPDATE EXT.STAGE_RECIBOS
		SET ESTADO = :v_const_carga_status_ok,
			FECHA_MODIFICACION = CURRENT_TIMESTAMP
		WHERE FILE_NAME = :i_file_name
		AND ESTADO = :v_const_stage_status_ok;
	
	COMMIT;
END
