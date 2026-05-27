CREATE PROCEDURE EXT.SP_HIST_TRANSACTIONASSIGN (IN i_file_name varchar(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Rubén Martínez
    | Company: Inycom
    | Initial Version Date: 26/03/2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta cuando se sube un fichero para historicos de TRANSACTIONASSIGN a traves del CDL
    |
    | Version: 0.1  RMF 20250326    Initial Version.
    |
    -----------------------------------------------------------------------
*/

BEGIN
	
	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE v_id_proceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_const_prestage_status_load INT = EXT.LIB_CONSTANTES:CONST_PRESTAGE_STATUS_LOAD; --0
	DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK; --1
	DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR; --3
	DECLARE v_tenantId VARCHAR(4) := EXT.LIB_GLOBAL:getTenantID();
	
	BEGIN
	
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_id_proceso, 'error');
			--v_hayError := 1;
			v_num_rows := 0;
		
			UPDATE EXT.IN_BATCH_CONTROL
			SET STATUS = v_const_stage_status_error,
				END_DATE = CURRENT_TIMESTAMP
			WHERE FILE_NAME = i_file_name
				AND ID_PROCESO = v_id_proceso;
			
			COMMIT;
			
			RESIGNAL;
		END;
	
	--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_id_proceso FROM DUMMY;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_id_proceso, 'info');
	
		SELECT COUNT(*) INTO v_num_rows
		FROM EXT.PRESTAGE_HISTTRANSACTIONASSIGN;
		
		INSERT INTO EXT.IN_BATCH_CONTROL (ID_PROCESO, FILE_NAME, PROCEDURE_NAME, SOURCE_ROWS, STATUS, START_DATE)
		VALUES (v_id_proceso, i_file_name, proc_name, v_num_rows, :v_const_prestage_status_load, CURRENT_TIMESTAMP);
		
		INSERT INTO EXT.EJEC_HIST_CONTROL
		SELECT DISTINCT :v_id_proceso 
			, :i_file_name
			, HIST.FILE_NAME_OUT
		FROM EXT.PRESTAGE_HISTTRANSACTIONASSIGN HIST;
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en EJEC_HIST_CONTROL. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
		TBL_EJEC_HIST_CONTROL = SELECT TBL.FILE_NAME_EXTRACCION
									, TBL.FILE_NAME_LP
								FROM EXT.EJEC_HIST_CONTROL TBL
								WHERE ID_PROCESO = :v_id_proceso
								;
		
		v_num_rows = RECORD_COUNT(:TBL_EJEC_HIST_CONTROL);
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_EJEC_HIST_CONTROL creada. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		/*	
		DELETE FROM EXT.TRANSACTIONASSIGN REC
		WHERE BATCHNAME IN (SELECT FILE_NAME_LP FROM :TBL_EJEC_HIST_CONTROL);
			
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin DELETE en TRANSACTIONASSIGN. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		*/
		INSERT INTO EXT.TRANSACTIONASSIGN
		SELECT :v_tenantId AS TENANTID
			, 99999999 AS STAGESALESTRANSACTIONSEQ
			, 0 AS SETNUMBER
			, HIST.FILE_NAME_OUT AS BATCHNAME
			, HIST.FILE_IN_RECIBOS
			, HIST.ORDERID
			, TO_BIGINT(HIST.LINENUMBER)
			, TO_BIGINT(HIST.SUBLINENUMBER)
			, HIST.EVENTTYPEID
			, 99999999 AS SALESTRANSACTIONSEQ
			, HIST.PAYEEID
			, HIST.PAYEETYPE
			, HIST.POSITIONNAME
			, HIST.TITLENAME
			, HIST.GENERICATTRIBUTE1
			, HIST.GENERICATTRIBUTE2
			, HIST.GENERICATTRIBUTE3
			, HIST.GENERICATTRIBUTE4
			, HIST.GENERICATTRIBUTE5
			, HIST.GENERICATTRIBUTE6
			, HIST.GENERICATTRIBUTE7
			, HIST.GENERICATTRIBUTE8
			, HIST.GENERICATTRIBUTE9
			, HIST.GENERICATTRIBUTE10
			, HIST.GENERICATTRIBUTE11
			, HIST.GENERICATTRIBUTE12
			, HIST.GENERICATTRIBUTE13
			, HIST.GENERICATTRIBUTE14
			, HIST.GENERICATTRIBUTE15
			, HIST.GENERICATTRIBUTE16
			, TO_DECIMAL(REPLACE(HIST.GENERICNUMBER1,',','.'),25,10)
			, HIST.UNITTYPEFORGENERICNUMBER1
			, TO_DECIMAL(REPLACE(HIST.GENERICNUMBER2,',','.'),25,10)
			, HIST.UNITTYPEFORGENERICNUMBER2
			, TO_DECIMAL(REPLACE(HIST.GENERICNUMBER3,',','.'),25,10)
			, HIST.UNITTYPEFORGENERICNUMBER3
			, TO_DECIMAL(REPLACE(HIST.GENERICNUMBER4,',','.'),25,10)
			, HIST.UNITTYPEFORGENERICNUMBER4
			, TO_DECIMAL(REPLACE(HIST.GENERICNUMBER5,',','.'),25,10)
			, HIST.UNITTYPEFORGENERICNUMBER5
			, TO_DECIMAL(REPLACE(HIST.GENERICNUMBER6,',','.'),25,10)
			, HIST.UNITTYPEFORGENERICNUMBER6
			, TO_DATE(HIST.GENERICDATE1,'DD/MM/YYYY')
			, TO_DATE(HIST.GENERICDATE2,'DD/MM/YYYY')
			, TO_DATE(HIST.GENERICDATE3,'DD/MM/YYYY')
			, TO_DATE(HIST.GENERICDATE4,'DD/MM/YYYY')
			, TO_DATE(HIST.GENERICDATE5,'DD/MM/YYYY')
			, TO_DATE(HIST.GENERICDATE6,'DD/MM/YYYY')
			, HIST.GENERICBOOLEAN1
			, HIST.GENERICBOOLEAN2
			, HIST.GENERICBOOLEAN3
			, HIST.GENERICBOOLEAN4
			, HIST.GENERICBOOLEAN5
			, HIST.GENERICBOOLEAN6

		FROM EXT.PRESTAGE_HISTTRANSACTIONASSIGN HIST
		;
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en TRANSACTIONASSIGN. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = :v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP WHERE FILE_NAME = i_file_name AND ID_PROCESO = v_id_proceso;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || i_file_name, v_log_count, v_id_proceso, 'info');
		
	END;
		
END
