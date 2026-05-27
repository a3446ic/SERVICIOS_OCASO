CREATE or replace PROCEDURE EXT.SP_BKPCIERRE ( OUT o_file_name VARCHAR(120), IN i_file_name VARCHAR(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
 
/*---------------------------------------------------------------------
    | Author: Tania Garc�s Villanueva 
    | Company: Inycom
    | Initial Version Date: 23-Octubre-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que realiza tablas de Backup para las principales tablas. 
    |						
	|
	| Version: 0.1	TGV 20251023		Initial Version.
	| Version: 0.2	TGV 20251023		Se añade la tabla de CARTERA_DDEE
	|
    -----------------------------------------------------------------------
*/
 
BEGIN
	USING SQLSCRIPT_STRING AS LIBRARY;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_idproceso INTEGER;
	DECLARE v_version VARCHAR2(10) := '0.2';
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
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------POLIZAS-------------------------------------------------------------------
		BEGIN
		DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
			BEGIN
			
			
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de POLIZAS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
				
			END;
			
			DROP TABLE EXT.POLIZAS_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.POLIZAS_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.POLIZAS);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'POLIZAS. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."POLIZAS_BKP" AS (SELECT * FROM EXT.POLIZAS);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla POLIZAS_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------RECIBOS-------------------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
				
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de RECIBOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
		DROP TABLE EXT.RECIBOS_BKP;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.RECIBOS_BKP', v_log_count, v_idproceso, 'info');
		
		v_num_rows := record_count(EXT.RECIBOS);
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'RECIBOS. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		CREATE TABLE "EXT"."RECIBOS_BKP" AS (SELECT * FROM EXT.RECIBOS);
		v_num_rows := ::rowcount;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla RECIBOS_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------GARANTIAS_RECIBO----------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de GARANTIAS_RECIBO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.GARANTIAS_RECIBO_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.GARANTIAS_RECIBO_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.GARANTIAS_RECIBO);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'GARANTIAS_RECIBO. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."GARANTIAS_RECIBO_BKP" AS (SELECT * FROM EXT.GARANTIAS_RECIBO);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla GARANTIAS_RECIBO_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------ASEGURADOS----------------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de ASEGURADOS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.ASEGURADOS_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.ASEGURADOS_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.ASEGURADOS);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'ASEGURADOS. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."ASEGURADOS_BKP" AS (SELECT * FROM EXT.ASEGURADOS);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla ASEGURADOS_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------GARANTIAS_ASEGURADO-------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
				
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de GARANTIAS_ASEGURADO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.GARANTIAS_ASEGURADO_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.GARANTIAS_ASEGURADO_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.GARANTIAS_ASEGURADO);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'GARANTIAS_ASEGURADO. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."GARANTIAS_ASEGURADO_BKP" AS (SELECT * FROM EXT.GARANTIAS_ASEGURADO);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla GARANTIAS_ASEGURADO_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------SALESTRANSACTION----------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de SALESTRANSACTION - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.SALESTRANSACTION_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.SALESTRANSACTION_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.SALESTRANSACTION);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'SALESTRANSACTION. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."SALESTRANSACTION_BKP" AS (SELECT * FROM EXT.SALESTRANSACTION);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla SALESTRANSACTION_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------TRANSACTIONASSIGN---------------------------------------------------------
		BEGIN
				DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
					BEGIN
					
						
						CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de TRANSACTIONASSIGN - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
						
					END;
			DROP TABLE EXT.TRANSACTIONASSIGN_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.TRANSACTIONASSIGN_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.TRANSACTIONASSIGN);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TRANSACTIONASSIGN. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."TRANSACTIONASSIGN_BKP" AS (SELECT * FROM EXT.TRANSACTIONASSIGN);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla TRANSACTIONASSIGN_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------POLIZAS_HIST--------------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
				
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de POLIZAS_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.POLIZAS_HIST_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.POLIZAS_HIST_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.POLIZAS_HIST);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'POLIZAS_HIST. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."POLIZAS_HIST_BKP" AS (SELECT * FROM EXT.POLIZAS_HIST);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla POLIZAS_HIST_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------RECIBOS_HIST--------------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de RECIBOS_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
			DROP TABLE EXT.RECIBOS_HIST_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.RECIBOS_HIST_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.RECIBOS_HIST);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'RECIBOS_HIST. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."RECIBOS_HIST_BKP" AS (SELECT * FROM EXT.RECIBOS_HIST);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla RECIBOS_HIST_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------GARANTIAS_RECIBO_HIST-----------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
				
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de GARANTIAS_RECIBO_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.GARANTIAS_RECIBO_HIST_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.GARANTIAS_RECIBO_HIST_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.GARANTIAS_RECIBO_HIST);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'GARANTIAS_RECIBO_HIST. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."GARANTIAS_RECIBO_HIST_BKP" AS (SELECT * FROM EXT.GARANTIAS_RECIBO_HIST);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla GARANTIAS_RECIBO_HIST_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
	
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------ASEGURADOS_HIST-----------------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de ASEGURADOS_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.ASEGURADOS_HIST_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.ASEGURADOS_HIST_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.ASEGURADOS_HIST);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'ASEGURADOS_HIST. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."ASEGURADOS_HIST_BKP" AS (SELECT * FROM EXT.ASEGURADOS_HIST);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla ASEGURADOS_HIST_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
	
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------GARANTIAS_ASEGURADO_HIST--------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de GARANTIAS_ASEGURADO_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.GARANTIAS_ASEGURADO_HIST_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.GARANTIAS_ASEGURADO_HIST_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.GARANTIAS_ASEGURADO_HIST);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'GARANTIAS_ASEGURADO_HIST. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."GARANTIAS_ASEGURADO_HIST_BKP" AS (SELECT * FROM EXT.GARANTIAS_ASEGURADO_HIST);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla GARANTIAS_ASEGURADO_HIST_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
	
		END;
		
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------SALESTRANSACTION_HIST-----------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de SALESTRANSACTION_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.SALESTRANSACTION_HIST_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.SALESTRANSACTION_HIST_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.SALESTRANSACTION_HIST);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'SALESTRANSACTION_HIST. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."SALESTRANSACTION_HIST_BKP" AS (SELECT * FROM EXT.SALESTRANSACTION_HIST);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla SALESTRANSACTION_HIST_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
	
		END;
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------TRANSACTIONASSIGN_HIST----------------------------------------------------
		BEGIN
			DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
				BEGIN
				
					
					CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de TRANSACTIONASSIGN_HIST - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
					
				END;
				
			DROP TABLE EXT.TRANSACTIONASSIGN_HIST_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.TRANSACTIONASSIGN_HIST_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.TRANSACTIONASSIGN_HIST);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TRANSACTIONASSIGN_HIST. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."TRANSACTIONASSIGN_HIST_BKP" AS (SELECT * FROM EXT.TRANSACTIONASSIGN_HIST);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla TRANSACTIONASSIGN_HIST_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		
		END;
		-----------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------CARTERA_DDEE-------------------------------------------------------------------
		BEGIN
		DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
			BEGIN
			
			
				CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error bloque de CARTERA_DDEE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
				
			END;
			
			DROP TABLE EXT.CARTERA_DDEE_BKP;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'DROP EXT.CARTERA_DDEE_BKP', v_log_count, v_idproceso, 'info');
			
			v_num_rows := record_count(EXT.CARTERA_DDEE);
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CARTERA_DDEE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
			
			CREATE TABLE "EXT"."CARTERA_DDEE_BKP" AS (SELECT * FROM EXT.CARTERA_DDEE);
			v_num_rows := ::rowcount;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creamos tabla CARTERA_DDEE_BKP. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
		END;

			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin del procedimiento', v_log_count, v_idproceso, 'info');
	END;	
 
END
