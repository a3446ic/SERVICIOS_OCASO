CREATE PROCEDURE EXT.SP_OUT_CUSTOMPURGE (OUT o_filename varchar(120), IN i_pipelinerunseq BIGINT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
	| Author: RMF
	| Company: Inycom
	| Initial Version Date: 28/01/2025
	|----------------------------------------------------------------------
	| Procedure Purpose: Procedimiento ejecutado mediante pipeline de Data Extract que borra registros de las tablas configuradas en la clasificacion Configuracion Purge de IM
	|
	| Version: 0.01	RMF 		20250128	Initial Version
---------------------------------------------------------------------*/

BEGIN
	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE v_idproceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_dummy DECIMAL(20,4);
	
	DECLARE custom_error CONDITION FOR SQL_ERROR_CODE 10000;
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
			--v_hayError := 1;
			RESIGNAL;
		END;
	
	
	BEGIN
	
		--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || proc_name, v_log_count, v_idproceso, 'info');
		
		--Insertamos un registro en la tabla OUT_BATCH_CONTROL en estado 0. PENDIENTE
		--INSERT INTO EXT.IN_BATCH_CONTROL (ID_PROCESO, FILE_NAME, PROCEDURE_NAME, SOURCE_ROWS, STATUS, START_DATE)
		--VALUES (v_idproceso, i_file_name, proc_name, 0, v_in_batch_preload, CURRENT_TIMESTAMP);
		
		TABLA_PURGADO = SELECT CGC.GENERICATTRIBUTE1 AS NOMBRE_TABLA
						, CGC.GENERICATTRIBUTE2 AS CAMPO_BORRADO
						, CGC.GENERICNUMBER1 AS PROFUNDIDAD_PURGADO
						FROM TCMP.CS_CLASSIFIER CLAS
						INNER JOIN TCMP.CS_GENERICCLASSIFIERTYPE GCT ON GCT.GENERICCLASSIFIERTYPESEQ = CLAS.SELECTORID
							AND GCT.NAME = 'Configuracion Purge'
						INNER JOIN TCMP.CS_GENERICCLASSIFIER CGC ON CLAS.CLASSIFIERSEQ = CGC.CLASSIFIERSEQ
							AND CGC.REMOVEDATE = v_eot 
							AND CGC.EFFECTIVEENDDATE > CURRENT_DATE
							AND CGC.EFFECTIVESTARTDATE <= CURRENT_DATE
							AND CGC.GENERICBOOLEAN1 = 1
						WHERE CLAS.REMOVEDATE = v_eot
							AND CLAS.EFFECTIVEENDDATE > CURRENT_DATE
							AND CLAS.EFFECTIVESTARTDATE <= CURRENT_DATE
					; 
					
		SIGNAL custom_error SET MESSAGE_TEXT = 'Throw Exception Test';
		
		o_filename = 'OUT_CUSTOMPURGE_' || TO_CHAR(CURRENT_TIMESTAMP,'YYYYMMDD_HH24MISS.txt');
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin Procedure', v_log_count, v_idproceso, 'info');
	
	END;
	
END
