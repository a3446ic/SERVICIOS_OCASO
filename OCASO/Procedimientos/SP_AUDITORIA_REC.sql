CREATE PROCEDURE EXT.SP_AUDITORIA_REC (OUT FILENAME VARCHAR(120), IN i_pPlRunSeq VARCHAR(50)) 
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT AS
/*  --------------------------------------------------------------------- 
    | Author: Brais Romero Garcia
    | Company: Inycom 
    | Initial Version Date: 10-Junio-2025
    |
    |-------------------------------------------------------------------- 
    | Procedure Purpose: Fichero de auditoría de Recibos
    | Version: 0.1	BRG 		20250610	Initial Version
    | Version: 0.2  DTB 		20250611	Añadida modificación al FILENAME para que coincida con Oracle.
    | Version: 0.3  DTB 		20250716	Modificación FILENAME.
    | Version: 0.4	BRG			20250813	Cambio FILENAME
    |
    ---------------------------------------------------------------------
*/ 
BEGIN 
    USING SQLSCRIPT_STRING AS LIBRARY; 

    -- DECLARACION DE CONSTANTES Y VARIABLES
    DECLARE v_proc_name VARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
    DECLARE v_version VARCHAR(10) := '0.4';
    DECLARE v_num_rows INTEGER := 0;
    DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
    DECLARE v_log_count INTEGER := 0;
    DECLARE v_idproceso INTEGER; 
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
    DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot; 
    DECLARE v_PeriodSeq BIGINT;
    DECLARE v_PeriodName VARCHAR(255);
    DECLARE v_PeriodStartDate TIMESTAMP;
    DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
	DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
	DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
    DECLARE v_fechaliquidacion VARCHAR(6);
    DECLARE v_fechafichero DATE;
    DECLARE v_period_name VARCHAR(50);
    DECLARE v_period_startdate DATE;
    DECLARE v_period_enddate DATE;
    --DECLARE v_file_name_start VARCHAR(250) := 'RECIBOS.RECIBOS_';
    --DECLARE v_file_name_empresa VARCHAR(10) := '_OCASO';
	--DECLARE v_file_name_end VARCHAR(20) := '_RECIGWCAFTP212602P';
	DECLARE v_file_name VARCHAR(50) := 'RECI2126_AUDITO_RECIBOS_';

    -- CONTROLADOR DE EXCEPCIONES
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	    BEGIN	
	    	ROLLBACK;		
	    	CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
	    	v_num_rows := 0;
	    	UPDATE EXT.OUT_BATCH_CONTROL
	    	SET STATUS = v_const_out_batch_control_error,
	    		END_DATE = CURRENT_TIMESTAMP
	    	WHERE FILE_NAME = FILENAME
	    		AND ID_PROCESO = v_idproceso;
	    	 commit;	
	    --	RESIGNAL;		
	  END;

    
    -- BORRADO E INSERT EN EXT.OUT_AUDITORIA_INF_TIP_FILE
    BEGIN
		-- Iniciamos ID Proceso
    	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
    	
        -- INICIALIZAMOS EL PROCESO
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq , v_log_count, v_idproceso, 'info');
    	
	    -- SELECCIONAMOS PERIODSEQ
	    SELECT PERIODSEQ, NAME, STARTDATE, TO_VARCHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate, v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
    	
    	-- Informamos v_fechafichero
    	SELECT TO_DATE(SUBSTR(:v_fechaliquidacion,1,6) || '01','YYYYMMDD') INTO v_fechafichero FROM DUMMY;
    	
	    --FICHERO DE SALIDA  
        --SELECT v_file_name || '.txt' INTO FILENAME from dummy;
        --BRG 20250813 Nuevos nombres de ficheros por petición de MAA
		SELECT v_file_name||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME from dummy;
	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA ' || FILENAME, v_log_count, v_idproceso, 'info');
	    
	    BEGIN
			--REGISTRO OUT_BATCH_CONTROL
			INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO, FILE_NAME, PROCEDURE_NAME, TARGET_ROWS, STATUS, START_DATE, END_DATE)
			VALUES (v_idproceso, FILENAME, ::CURRENT_OBJECT_NAME, 0, :v_const_out_batch_control_load, CURRENT_TIMESTAMP, NULL);
			COMMIT;
		END;

		------------------- Variables tabla -----------------------
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio creación de la variable tabla TBL_REPEXT_REC_CREDIT', v_log_count, v_idproceso, 'debug');
		-- TCPRE.INYC_REPEXT_REC_CREDIT_TEMP es TBL_REPEXT_REC_CREDIT
		TBL_REPEXT_REC_CREDIT = SELECT C.VALUE, C.SALESTRANSACTIONSEQ 
            FROM TCMP.CS_CREDIT C
            WHERE C.PERIODSEQ = :v_PeriodSeq
	            AND C.TENANTID = :v_idtenant AND C.PROCESSINGUNITSEQ = 38280596832649217 
	            AND C.NAME IN ('DC-E-COM-GestionCobro', 'DC-O-COM-GestionCobro');
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin creación de la variable tabla TBL_REPEXT_REC_CREDIT. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
        
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio creación de la variable tabla TBL_REPEXT_REC_SALESTNX', v_log_count, v_idproceso, 'debug');
		-- TCPRE.INYC_REPEXT_REC_SALESTNX_TEMP es TBL_REPEXT_REC_SALESTNX
		TBL_REPEXT_REC_SALESTNX = SELECT X.LINENUMBER, X.SUBLINENUMBER, X.SALESORDERSEQ, X.SALESTRANSACTIONSEQ
            FROM TCMP.CS_SALESTRANSACTION X
            INNER JOIN TCMP.CS_EVENTTYPE E ON E.DATATYPESEQ = X.EVENTTYPESEQ
            	AND E.TENANTID = :v_idtenant AND E.EVENTTYPEID = '20' AND E.REMOVEDATE = :v_eot
            WHERE X.TENANTID = :v_idtenant AND X.PROCESSINGUNITSEQ = 38280596832649217
            	AND X.COMPENSATIONDATE = :v_fechafichero;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin creación de la variable tabla TBL_REPEXT_REC_SALESTNX. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
        
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio creación de la variable tabla TBL_REPEXT_REC_COM_COB', v_log_count, v_idproceso, 'debug');
		-- TCPRE.INYC_REPEXT_REC_COM_COB_TEMP es TBL_REPEXT_REC_COM_COB
		TBL_REPEXT_REC_COM_COB = SELECT /*+ ORDERED */
                   C.VALUE,
                   X.LINENUMBER,
                   X.SUBLINENUMBER,
                   X.SALESORDERSEQ,
                   X.SALESTRANSACTIONSEQ
            FROM :TBL_REPEXT_REC_SALESTNX X
            INNER JOIN :TBL_REPEXT_REC_CREDIT C ON X.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin creación de la variable tabla TBL_REPEXT_REC_COM_COB. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
        
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio creación de la variable tabla TBL_BASES_REPARTO_POLIZA', v_log_count, v_idproceso, 'debug');
		-- TCPRE.INYC_BASES_REPARTO_POLIZA_TEMP es TBL_BASES_REPARTO_POLIZA
		TBL_BASES_REPARTO_POLIZA = SELECT 
                BR.PERIODSEQ,
                BR.SALESTRANSACTIONSEQ,
                BR.COD_AGENTE,
                BR.MAN_ACT_POS_PRIN,
                BR.POLIZA_CORREGIDA,
                BR.DIF_INSP,
                BR.PRIMA_CORREGIDA,
                BR.MANAGER_POS_PRIN,
                BR.CODIGO_POLIZA,
                BR.IMPORTE_COMISION,
                BR.ORDERID,
                BR.LINENUMBER,
                BR.SUBLINENUMBER,
                BR.COMPENSATIONDATE,
                BR.ESTADO,
                SUBSTR(BR.ORDERID,29,11)
            FROM EXT.FINAL_BASES_REPARTO_POLIZA_FILE BR
            WHERE BR.PERIODSEQ = :v_PeriodSeq;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin creación de la variable tabla TBL_BASES_REPARTO_POLIZA. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
        
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio creación de la variable tabla TBL_POSREL', v_log_count, v_idproceso, 'debug');
        -- Nueva variable tabla TBL_POSREL
        TBL_POSREL = SELECT PRP.PARENTPOSITIONSEQ,PRP.CHILDPOSITIONSEQ
            FROM TCMP.CS_POSITIONRELATION PRP
            INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT ON PRP.POSITIONRELATIONTYPESEQ = PRT.DATATYPESEQ
                AND PRT.TENANTID = :v_idtenant AND PRT.REMOVEDATE = :v_eot
                AND PRT.NAME='Contract Rollup'
            WHERE PRP.TENANTID = :v_idtenant
                AND PRP.CREATEDATE < LAST_DAY(:v_fechafichero)
                AND PRP.REMOVEDATE > LAST_DAY(:v_fechafichero)
                --ALM 20220519: Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
                AND PRP.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
                AND PRP.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero);
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin creación de la variable tabla TBL_POSREL. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
        
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio creación de la variable tabla TBL_POSREL_M', v_log_count, v_idproceso, 'debug');
        -- Nueva variable tabla TBL_POSREL_M
        TBL_POSREL_M = SELECT PRP_M.PARENTPOSITIONSEQ,PRP_M.CHILDPOSITIONSEQ
            FROM TCMP.CS_POSITIONRELATION PRP_M
            INNER JOIN TCMP.CS_POSITIONRELATIONTYPE PRT_M ON PRP_M.POSITIONRELATIONTYPESEQ = PRT_M.DATATYPESEQ
                AND PRT_M.TENANTID = :v_idtenant AND PRT_M.REMOVEDATE = :v_eot
                AND PRT_M.NAME='Contract Rollup'
            WHERE PRP_M.TENANTID = :v_idtenant
                AND PRP_M.CREATEDATE < LAST_DAY(:v_fechafichero)
                AND PRP_M.REMOVEDATE > LAST_DAY(:v_fechafichero)
                AND PRP_M.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
                AND PRP_M.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero);
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin creación de la variable tabla TBL_POSREL_M. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'debug');
        
        ------------------- Tabla OUT_AUDITORIA_INF_REC_FILE -----------------------
        -- BORRADO EXT.OUT_AUDITORIA_INF_REC_FILE
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio borrado de la tabla EXT.OUT_AUDITORIA_INF_REC_FILE', v_log_count, v_idproceso, 'info');
        TRUNCATE TABLE EXT.OUT_AUDITORIA_INF_REC_FILE;
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Borrado de la tabla EXT.OUT_AUDITORIA_INF_REC_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

		-- INSERT EN EXT.OUT_AUDITORIA_INF_REC_FILE
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Insert en la tabla EXT.OUT_AUDITORIA_INF_REC_FILE', v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.OUT_AUDITORIA_INF_REC_FILE
	        --ALM 20220810: Anadimos un HINT para forzar a la consulta a que se haga en el orden indicado y asi optimizar el insert.
	        SELECT
	            --JGE 20231030 modificacion del proyecto de Reparto de Costes. Correo JavierGF y Reuniones Sergio Urrutia
	            LPAD(IFNULL(ST.CHANNEL,'0'),2,'0') ||                                    -- COMPANIA                                               (1:2)
	            LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,1,4),'0'),4,'0') ||                                         -- OFICINA CONTABLE - OFIC-AGTE-DOC - Cod. oficina para doc. del agente   (3:4)
	            LPAD(IFNULL(CASE WHEN (TA.GENERICATTRIBUTE3 IS NULL OR TA.GENERICATTRIBUTE3 = '0')
	                     THEN SUBSTR(POS.GENERICATTRIBUTE3,7,4)
	                     ELSE CAST(SUBSTR(TA.GENERICATTRIBUTE3,7,4) AS NVARCHAR(100))
	                     END,'0'),6,'0') ||                                         -- CODIGO AGENTE - Codigo de agente de la poliza                          (7:6)
	            RPAD('   ',3)  ||                                                   -- LINEA                                                                  (13:3)
	            LPAD(IFNULL(SUBSTR(ST.PRODUCTID,3,5),'0'),5,'0') ||                    -- PRODUCTO                                                               (16:5)                                              
	            LPAD(IFNULL(REPLACE(CASE WHEN BR.CODIGO_POLIZA LIKE '%S%' THEN '99999999999' ELSE (
	            CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2'
	                    THEN IFNULL(SUBSTR(ST.GENERICATTRIBUTE1,1,11),'0')
	                    ELSE IFNULL(SUBSTR(ST.GENERICATTRIBUTE1,1,7),'0')
	                    END) 
	            END,' ',''),'0'),11, '0') ||                                       -- POLIZA                                                                 (21:7)                                               
	            LPAD(IFNULL(REPLACE(CASE WHEN BR.CODIGO_POLIZA LIKE '%S%' THEN '00000' ELSE (
	            CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2'
	                THEN IFNULL(SUBSTR(ST.GENERICATTRIBUTE1,12,5),'0')
	                ELSE IFNULL(SUBSTR(ST.GENERICATTRIBUTE1,8,5),'0')
	                END) 
	            END,' ',''),'0'),5, '0') ||                                       -- SUBPOLIZA                                                              (28:5)   
	            LPAD(IFNULL(REPLACE(CASE WHEN BR.CODIGO_POLIZA LIKE '%S%' THEN '000' ELSE (
	            CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2'
	                THEN '0'
	                ELSE IFNULL(TO_VARCHAR(SUBSTR(BR.CODIGO_POLIZA,LENGTH(BR.CODIGO_POLIZA)-2, 3)),'0')
	            END)
	            END,' ',''),'0'),3,'0') ||                                          -- ORDEN                                                                  (33:3)
	            LPAD(IFNULL(TO_VARCHAR(ST.COMPENSATIONDATE,'YYYYMM'), '0'),6,'0') ||      -- FECHA_CARGO                                                            (36:6)
	            RPAD(' ',2)  ||                                                     -- TIPO                                                                   (42:2)
	            LPAD(IFNULL(CASE WHEN LENGTH((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)) > 4 
	            THEN (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)
	            ELSE CONCAT((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END), '000000') END,'0'), 10, '0')   ||   -- INSPECTOR                                                              (44:6)
	            LPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE12,1,2),'0'),2,'0') ||           -- DURACION                                                               (50:2)
	            RPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE8,1,5),' '),5,' ')||             -- CLV-RIESGO                                                             (52:5)
	            RPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE2,1,1),' '),1,' ')||             -- FORMA PAGO                                                             (57:1)
	            RPAD(' ',1)||                                                       -- INVAR                                                                  (58;1)                             
	            LPAD(IFNULL(CASE WHEN ET.EVENTTYPEID = 'Pago Comercial' THEN
	                CASE WHEN ST.GENERICATTRIBUTE2 IN ('101','701','201','205') THEN '72'
	                WHEN SUBSTR(ST.GENERICATTRIBUTE2,1,1) = '1' THEN '81' END
	            WHEN ET.EVENTTYPEID LIKE 'AS%' THEN '81'        
	            ELSE SUBSTR(ET.EVENTTYPEID,1,2)
	            END,'0'),2,'0') ||                                                  -- PERMANENCIA - 71.- nueva produccion, 72.- Recibos primer anno.         (59:2) 
	            RPAD(IFNULL(CASE WHEN ST.GENERICNUMBER1 < 0
	            THEN '-' ELSE '+' END,'+'),1,' ' ) ||                               -- SIGNO                                                                  (61:1)
	            LPAD(IFNULL(ABS(CAST(ROUND(ST.GENERICNUMBER1, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND(ST.GENERICNUMBER1,2),1)*100),'0'),2,'0')  || -- PRIMA NETA                                                             (62:10)
	            RPAD(IFNULL(CASE WHEN ST.GENERICNUMBER2 < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ' ) ||                                                 -- SIGNO                                                                  (72:1)
	            LPAD(IFNULL(ABS(CAST(ROUND(ST.GENERICNUMBER2, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND(ST.GENERICNUMBER2,2),1)*100),'0'),2,'0')  || -- INCREMENTO PRIMA NETA                                                  (73:10)                                           
	            RPAD(IFNULL(CASE WHEN ET.EVENTTYPEID = 'Pago Comercial' THEN 
	            CASE WHEN ST.GENERICATTRIBUTE2 IN ('101','701','201','205') THEN '1' ELSE '2' END 
	            WHEN ET.EVENTTYPEID IN ('71', '72', '65', '66') THEN '1'
	            ELSE '2' END,' '),1,' ')      ||                                    --INDICADOR COMISION - Tipo comision: 1- Gestion, 2.-Conservacion         (83:1)
	            RPAD(IFNULL(CASE WHEN ET.EVENTTYPEID = '20'
	                THEN '0' ELSE CASE WHEN BR.IMPORTE_COMISION < 0 THEN '-' ELSE '+' END
	            END,'+'),1,' ' ) ||                                                 -- SIGNO                                                                  (84:1)
	            LPAD(IFNULL(CASE WHEN ET.EVENTTYPEID <> '20'
	                THEN (LPAD(IFNULL(ABS(CAST(ROUND(BR.IMPORTE_COMISION, 2) AS INTEGER)),'0'),4,'0') ||
	                    LPAD(IFNULL(ABS(MOD(ROUND(BR.IMPORTE_COMISION,2),1)*100),'0'),2,'0'))
	                ELSE '0'
	            END,'0'),6,'0')  ||                                                 -- COMISION                                                               (85:6)
	            RPAD(IFNULL(((CASE WHEN X.VALUE < 0 THEN  '-' ELSE '+' END)),'+'),1,' ') || --SIGNO                                         
	            LPAD(IFNULL(
	                    LPAD(IFNULL(ABS(CAST(ROUND(X.VALUE, 2) AS INTEGER)),'0'),4,'0') ||
	                    LPAD(IFNULL(ABS(MOD(ROUND(X.VALUE,2),1)*100),'0'),2,'0')
	            ,'0'),6,'0') ||                                                       -- COMISION COBRO                                                         (92:6)
	            LPAD(IFNULL(TO_VARCHAR(ST.COMPENSATIONDATE,'YYYYMM'), '0'),6,'0') ||      -- FECHA_CARGO                                                            (98:6)
	            LPAD(IFNULL(TO_VARCHAR(ST.GENERICDATE1,'YYYYMM'), '0'),6,'0') ||          -- FECHA EFECTO                                                           (104:6)
	            LPAD(IFNULL((
	                SELECT MAX(SUBSTR(OFICINA_GESTORA,1,4))
	                FROM EXT.RECIBOS
	                WHERE CODIGO_POLIZA LIKE (
	                        CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2'
	                            THEN SUBSTR(ST.PRODUCTID,1,4) || '0' ||SUBSTR(ST.PRODUCTID,LENGTH(ST.PRODUCTID)-1,2) || BR.CODIGO_POLIZA
	                            ELSE  SUBSTR(ST.PRODUCTID,1,5) || '00' || BR.CODIGO_POLIZA
	                        END) || '%'
	                    AND CODIGO_RECIBO = ST.GENERICATTRIBUTE7
	                    AND FECHA_COMPENSACION = ST.COMPENSATIONDATE
	                    AND ESTADO_RECIBO = ST.GENERICATTRIBUTE6
	                    AND CODIGO_SUPLEMENTO = ST.GENERICATTRIBUTE9
	            ),'0'),4,'0') ||                                                    -- OFIGINA GESTORA                                                        (110:4)
	            LPAD(IFNULL((
	                SELECT MAX(SUBSTR(OFICINA_COBRADORA,1,4))
	                FROM EXT.RECIBOS
	                WHERE CODIGO_POLIZA LIKE (
	                        CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2'
	                            THEN SUBSTR(ST.PRODUCTID,1,4) || '0' ||SUBSTR(ST.PRODUCTID,LENGTH(ST.PRODUCTID)-1,2) || BR.CODIGO_POLIZA
	                            ELSE  SUBSTR(ST.PRODUCTID,1,5) || '00' || BR.CODIGO_POLIZA
	                        END) || '%'
	                    AND CODIGO_RECIBO = ST.GENERICATTRIBUTE7
	                    AND FECHA_COMPENSACION = ST.COMPENSATIONDATE
	                    AND ESTADO_RECIBO = ST.GENERICATTRIBUTE6
	                    AND CODIGO_SUPLEMENTO = ST.GENERICATTRIBUTE9
	            ),'0'),4, '0')        ||                                            -- OFICINA COBRADORA                                                      (114:4)
	            RPAD(IFNULL(CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2' THEN
	            SUBSTR(ST.GENERICATTRIBUTE7,1,11) ELSE '0' END,'0'),11,'0') ||      -- CODD-RECIBO-RT                                                         (118:11)
	            RPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE10,1,5),' '),5,' ') ||           -- DISTCOB - Distrito Cobro                                               (129:5)
	            RPAD(IFNULL(CASE WHEN ST.VALUE < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  -- SIGNO                                                                  (134:1)
	            LPAD(IFNULL(ABS(CAST(ROUND(ST.VALUE, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND(ST.VALUE,2),1)*100),'0'),2,'0')  ||          -- PRIMA COMISIONABLE                                                     (135:10)
	            RPAD(' ',1) ||                                                      -- IND-PASE                                                               (145:1)
	            RPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE6,1,1),' '),1,' ' ) ||           -- SITUACION (Situacion recibo: Cobrado, Pendiente, devuelto, emitido)    (146:1)
	            RPAD(IFNULL(CASE WHEN POS.TITLESEQ <> 5629499534213290 THEN '1' ELSE '0'
	                END,' '),1,' ') ||                                              -- ACTIVO, Indicador Agente Activo. Si tiene TTL SIN PLAN es 0 si no es 1 (147:1)
	            LPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE9,1,3),'0'),3,'0')  ||           -- SUPLEMENTO                                                             (148:3)
	            RPAD(IFNULL(CASE WHEN SUBSTR(ST.PRODUCTID,1,2) = '01'
	                THEN (CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2' THEN SUBSTR(POS.GENERICATTRIBUTE7,1,3) ELSE SUBSTR(POS.GENERICATTRIBUTE6,1,3) END)
	                ELSE (CASE WHEN SUBSTR(ST.PRODUCTID,3,1) = '2' THEN SUBSTR(POS.GENERICATTRIBUTE12,1,3) ELSE SUBSTR(POS.GENERICATTRIBUTE11,1,3) END)
	            END,' '),3, ' ') ||                                                 -- CUADRO AGENTE                                                          (151:3)
	            RPAD('+0000000',7) ||                                               -- PREMIO                                                                 (154:7)
	            RPAD(IFNULL(CASE WHEN BR.PRIMA_CORREGIDA < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  --SIGNO
	            LPAD(IFNULL(ABS(CAST(ROUND(BR.PRIMA_CORREGIDA, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND( BR.PRIMA_CORREGIDA,2),1)*100),'0'),2,'0')  ||                   --'PRIMCORR',                                                             (161:11)
	            RPAD('+000000',6) ||                                                --'COEF-CORR',                                                            (172:6)
	            RPAD('+000000',6)||                                                 --'COEF-DIFER',                                                           (178:6)
	            RPAD(IFNULL(CASE WHEN BR.DIF_INSP < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  --SIGNO
	            LPAD(IFNULL(ABS(CAST(ROUND(BR.DIF_INSP, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND( BR.DIF_INSP,2),1)*100),'0'),2,'0')  ||                        --'IMP-DIFER',                                                            (184:11)
	            RPAD(IFNULL(CASE WHEN BR.POLIZA_CORREGIDA < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  --SIGNO
	            LPAD(IFNULL(ABS(CAST(ROUND(BR.POLIZA_CORREGIDA, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND( BR.POLIZA_CORREGIDA,2),1)*100),'0'),2,'0')  ||                     -- POL-CORRE',                                                            (195:3)
	            LPAD(IFNULL(CASE WHEN SUBSTR(ST.PRODUCTID,3,1) <> '2' THEN
	            ST.GENERICATTRIBUTE7 ELSE '0' END,'0'), 11, '0') ||                   --'COD-RECIB',                                                            (198:9)
	            -- LPAD(IFNULL(SUBSTR(BR.MAN_ACT_POS_PRIN,-6),'0'),6,'0')||                        -- RESP-COMER' CODIGO DE RESPONSABLE COMERCIAL                            (207:6)
	            LPAD(IFNULL(CASE WHEN LENGTH(BR.MAN_ACT_POS_PRIN) > 4 THEN BR.MAN_ACT_POS_PRIN
	            ELSE CONCAT(BR.MAN_ACT_POS_PRIN, '000000') END,'0'), 10, '0')  ||   -- RESP-COMER' CODIGO DE RESPONSABLE COMERCIAL                            (207:6)
	            RPAD('000',3)||                                                     --'CLV-MEC',                                                              (213:3)
	            LPAD(IFNULL(SUBSTR(BR.COD_AGENTE,LENGTH(BR.COD_AGENTE)-5,6),'0'),6,'0')||                              --'AGTE-DOC',                                                             (216:6)
	            LPAD(IFNULL(CASE WHEN LENGTH((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)) > 4 
	            THEN (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)
	            ELSE CONCAT((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END), '000000') END,'0'), 10, '0')         --'INSP-DOC'                                                              (226:6)
	        FROM TCMP.CS_SALESTRANSACTION ST
	        INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
	            AND TA.TENANTID = :v_idtenant AND TA.PROCESSINGUNITSEQ = 38280596832649217
	            AND ST.COMPENSATIONDATE = TA.COMPENSATIONDATE AND TA.SETNUMBER = 1
	        INNER JOIN TCMP.CS_EVENTTYPE ET ON ET.DATATYPESEQ = ST.EVENTTYPESEQ
	            AND ET.TENANTID = :v_idtenant AND ET.REMOVEDATE = :v_eot
	        INNER JOIN TCMP.CS_POSITION POS ON TA.POSITIONNAME = POS.NAME
	            AND POS.TENANTID = :v_idtenant AND POS.PROCESSINGUNITSEQ = 38280596832649217
	            AND POS.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND POS.REMOVEDATE = :v_eot
	            AND POS.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND POS.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
	        INNER JOIN :TBL_BASES_REPARTO_POLIZA BR ON ST.SALESTRANSACTIONSEQ = BR.SALESTRANSACTIONSEQ
	        LEFT  JOIN :TBL_REPEXT_REC_COM_COB X ON X.SALESORDERSEQ = ST.SALESORDERSEQ
	            AND X.SUBLINENUMBER = ST.SUBLINENUMBER
	            AND  X.LINENUMBER = (ST.LINENUMBER || CASE WHEN ET.EVENTTYPEID  NOT IN ('AS10','AS50','Pago Comercial','A','B','AS110','AS90','AS91','REC-RRTT') THEN ET.EVENTTYPEID END)
	        --ALM 20211117: Incluimos la jerarquia de Contract Rollup para quedarnos con la Positon principal de cada agente porque sera esta la que cobre el pago.
	        LEFT JOIN :TBL_POSREL PR ON POS.RULEELEMENTOWNERSEQ = PR.CHILDPOSITIONSEQ
	        LEFT JOIN TCMP.CS_POSITION P ON PR.PARENTPOSITIONSEQ = P.RULEELEMENTOWNERSEQ
	            AND P.TENANTID = :v_idtenant
	            AND P.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND P.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            --ALM 20220519: Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
	            AND P.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND P.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
	        --ALM 20221114: Incluimos los INNER necesarios para poder atacar al manager principal de la position sin usar subconsultas que influyen demasiado en el rendimiento.
	        --Buscamos la Position Principal del agente de la transaccion en la fecha de emision de la poliza (PP) ya que el manager que buscamos es el de esa fecha.
	        LEFT JOIN TCMP.CS_POSITION PP ON PP.RULEELEMENTOWNERSEQ = (CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END) 
	            AND PP.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND PP.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            AND PP.EFFECTIVESTARTDATE <= ST.GENERICDATE2--(CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
	            AND PP.EFFECTIVEENDDATE > ST.GENERICDATE2--(CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
	            AND PP.TENANTID = :v_idtenant
	        --Cogemos la version a cierre del periodo del manager (MAN) que tenia la Posicion Principal del agente en la fecha emision de la poliza (PP). 
	        LEFT JOIN TCMP.CS_POSITION MAN ON MAN.RULEELEMENTOWNERSEQ = PP.MANAGERSEQ
	            AND MAN.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND MAN.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            AND MAN.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND MAN.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero) 
	            AND MAN.TENANTID = :v_idtenant
	        --Comprobamos con la Contract Rollup cual es la position proncipal del Manager (MAN).
	        LEFT JOIN :TBL_POSREL_M PR_M ON MAN.RULEELEMENTOWNERSEQ = PR_M.CHILDPOSITIONSEQ
	        LEFT JOIN TCMP.CS_POSITION P_M ON PR_M.PARENTPOSITIONSEQ = P_M.RULEELEMENTOWNERSEQ
	            AND P_M.TENANTID = :v_idtenant
	            AND P_M.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND P_M.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            AND P_M.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND P_M.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
            WHERE ST.TENANTID = :v_idtenant AND ST.PROCESSINGUNITSEQ = 38280596832649217
                AND ST.MODELSEQ = 0
                AND ST.COMPENSATIONDATE = :v_fechafichero
                AND NOT (
                        ET.EVENTTYPEID = 'Pago Comercial' 
                        AND SUBSTR(ST.GENERICATTRIBUTE2, 1, 1) IN ('4', '5', '3', '8')
                    )
                AND ET.EVENTTYPEID NOT IN ('A','B','S','20','15');
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insert en la tabla EXT.OUT_AUDITORIA_INF_TIP_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        UPDATE EXT.OUT_BATCH_CONTROL
	    SET STATUS = v_const_out_batch_control_ok,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    WHERE FILE_NAME = FILENAME
	    	AND ID_PROCESO = v_idproceso;
 
-------------------------------------------------------------------------------------------------
-- Añadimos el segundo insert

        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio segundo Insert en la tabla EXT.OUT_AUDITORIA_INF_REC_FILE', v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.OUT_AUDITORIA_INF_REC_FILE
	        SELECT
	            --JGE 20231030 modificacion del proyecto de Reparto de Costes. Correo JavierGF y Reuniones Sergio Urrutia
	            LPAD(IFNULL(CAR_LP.PRODUCTID,'0'),2,'0') ||                                    -- COMPANIA                                               (1:2)
	            LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,1,4),'0'),4,'0') ||                                         -- OFICINA CONTABLE - OFIC-AGTE-DOC - Cod. oficina para doc. del agente   (3:4)
	            LPAD(IFNULL(CASE WHEN (CAR_LP.COD_AGENTE IS NULL OR CAR_LP.COD_AGENTE = '0')
	                     THEN SUBSTR(POS.GENERICATTRIBUTE3,7,4)
	                     ELSE CAST(SUBSTR(CAR_LP.COD_AGENTE,7,4) AS NVARCHAR(100))
	                     END,'0'),6,'0') ||                                         -- CODIGO AGENTE - Codigo de agente de la poliza                          (7:6)
	            RPAD('   ',3)  ||                                                   -- LINEA                                                                  (13:3)
	            LPAD(IFNULL(SUBSTR(CAR_LP.PRODUCTID,3,5),'0'),5,'0') ||                    -- PRODUCTO                                                               (16:5)                                              
	            LPAD(IFNULL(REPLACE(CASE WHEN CAR_LP.POLIZA LIKE '%-%' THEN '99999999999' ELSE (
	            CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2'
	                    THEN IFNULL(SUBSTR(CAR_LP.POLIZA,1,11),'0')
	                    ELSE IFNULL(SUBSTR(CAR_LP.POLIZA,1,7),'0')
	                    END) 
	            END,' ',''),'0'),11, '0') ||                                       -- POLIZA                                                                 (21:7)                                               
	            LPAD(IFNULL(REPLACE(CASE WHEN CAR_LP.POLIZA LIKE '%-%' THEN '00000' ELSE (
	            CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2'
	                THEN IFNULL(SUBSTR(CAR_LP.POLIZA,12,5),'0')
	                ELSE IFNULL(SUBSTR(CAR_LP.POLIZA,8,5),'0')
	                END) 
	            END,' ',''),'0'),5, '0') ||                                       -- SUBPOLIZA                                                              (28:5)   
	            LPAD(IFNULL(REPLACE(CASE WHEN CAR_LP.POLIZA LIKE '%-%' THEN '000' ELSE (
	            CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2'
	                THEN '0'
	                ELSE IFNULL(TO_VARCHAR(SUBSTR(CAR_LP.POLIZA,LENGTH(CAR_LP.POLIZA)-2, 3)),'0')
	            END)
	            END,' ',''),'0'),3,'0') ||                                          -- ORDEN                                                                  (33:3)
	            LPAD(IFNULL(TO_VARCHAR(CAR_LP.COMPENSATIONDATE,'YYYYMM'), '0'),6,'0') ||      -- FECHA_CARGO                                                            (36:6)
	            RPAD(' ',2)  ||                                                     -- TIPO                                                                   (42:2)
	            LPAD(IFNULL(CASE WHEN LENGTH((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)) > 4 
	            THEN (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)
	            ELSE CONCAT((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END), '000000') END,'0'), 10, '0')   ||   -- INSPECTOR                                                              (44:6)
	            LPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE12,1,2),'0'),2,'0') ||           -- DURACION                                                               (50:2)
	            RPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE8,1,5),' '),5,' ')||             -- CLV-RIESGO                                                             (52:5)
	            RPAD(IFNULL(SUBSTR(CAR_LP.FORMA_PAGO,1,1),' '),1,' ')||             -- FORMA PAGO                                                             (57:1)
	            RPAD(' ',1)||                                                       -- INVAR                                                                  (58;1)                             
	            LPAD(IFNULL(CASE WHEN CAR_LP.EVENTTYPEID = 'Pago Comercial' THEN
	                CASE WHEN CAR_LP.FORMA_PAGO IN ('101','701','201','205') THEN '72'
	                WHEN SUBSTR(CAR_LP.FORMA_PAGO,1,1) = '1' THEN '81' END
	            WHEN CAR_LP.EVENTTYPEID LIKE 'AS%' THEN '81'        
	            ELSE SUBSTR(CAR_LP.EVENTTYPEID,1,2)
	            END,'0'),2,'0') ||                                                  -- PERMANENCIA - 71.- nueva produccion, 72.- Recibos primer anno.         (59:2) 
	            RPAD(IFNULL(CASE WHEN CAR_LP.PRIMA_NETA < 0
	            THEN '-' ELSE '+' END,'+'),1,' ' ) ||                               -- SIGNO                                                                  (61:1)
	            LPAD(IFNULL(ABS(CAST(ROUND(CAR_LP.PRIMA_NETA, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND(CAR_LP.PRIMA_NETA,2),1)*100),'0'),2,'0')  || -- PRIMA NETA                                                             (62:10)
	            RPAD(IFNULL(CASE WHEN ST.GENERICNUMBER2 < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ' ) ||                                                 -- SIGNO                                                                  (72:1)
	            LPAD(IFNULL(ABS(CAST(ROUND(ST.GENERICNUMBER2, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND(ST.GENERICNUMBER2,2),1)*100),'0'),2,'0')  || -- INCREMENTO PRIMA NETA                                                  (73:10)                                           
	            RPAD(IFNULL(CASE WHEN CAR_LP.EVENTTYPEID = 'Pago Comercial' THEN 
	            CASE WHEN CAR_LP.FORMA_PAGO IN ('101','701','201','205') THEN '1' ELSE '2' END 
	            WHEN CAR_LP.EVENTTYPEID IN ('71', '72', '65', '66') THEN '1'
	            ELSE '2' END,' '),1,' ')      ||                                    --INDICADOR COMISION - Tipo comision: 1- Gestion, 2.-Conservacion         (83:1)
	            RPAD(IFNULL(CASE WHEN CAR_LP.EVENTTYPEID = '20'
	                THEN '0' ELSE CASE WHEN CAR_LP.NATIVECURRENCYAMOUNT < 0 THEN '-' ELSE '+' END
	            END,'+'),1,' ' ) ||                                                 -- SIGNO                                                                  (84:1)
	            LPAD(IFNULL(CASE WHEN CAR_LP.EVENTTYPEID <> '20'
	                THEN (LPAD(IFNULL(ABS(CAST(ROUND(CAR_LP.NATIVECURRENCYAMOUNT, 2) AS INTEGER)),'0'),4,'0') || 
	                    LPAD(IFNULL(ABS(MOD(ROUND(CAR_LP.NATIVECURRENCYAMOUNT,2),1)*100),'0'),2,'0'))
	                ELSE '0'
	            END,'0'),6,'0')  ||                                                 -- COMISION                                                               (85:6)
	            RPAD(IFNULL(((CASE WHEN X.VALUE < 0 THEN  '-' ELSE '+' END)),'+'),1,' ') || --SIGNO                                         
	            LPAD(IFNULL(
	                    LPAD(IFNULL(ABS(CAST(ROUND(X.VALUE, 2) AS INTEGER)),'0'),4,'0') ||
	                    LPAD(IFNULL(ABS(MOD(ROUND(X.VALUE,2),1)*100),'0'),2,'0')
	            ,'0'),6,'0') ||                                                       -- COMISION COBRO                                                         (92:6)
	            LPAD(IFNULL(TO_VARCHAR(CAR_LP.COMPENSATIONDATE,'YYYYMM'), '0'),6,'0') ||      -- FECHA_CARGO                                                            (98:6)
	            LPAD(IFNULL(TO_VARCHAR(CAR_LP.FECHA_EFECTO,'YYYYMM'), '0'),6,'0') ||          -- FECHA EFECTO                                                           (104:6)
	            LPAD(IFNULL((
	                SELECT MAX(SUBSTR(OFICINA_GESTORA,1,4))
	                FROM EXT.RECIBOS
	                WHERE CODIGO_POLIZA LIKE (
	                        CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2'
	                            THEN SUBSTR(CAR_LP.PRODUCTID,1,4) || '0' ||SUBSTR(CAR_LP.PRODUCTID,LENGTH(CAR_LP.PRODUCTID)-1,2) || BR.CODIGO_POLIZA
	                            ELSE  SUBSTR(CAR_LP.PRODUCTID,1,5) || '00' || BR.CODIGO_POLIZA
	                        END) || '%'
	                    AND CODIGO_RECIBO = ST.GENERICATTRIBUTE7
	                    AND FECHA_COMPENSACION = CAR_LP.COMPENSATIONDATE
	                    AND ESTADO_RECIBO = BR.ESTADO
	                    AND CODIGO_SUPLEMENTO = CAR_LP.COD_SUPLEMENTO
	            ),'0'),4,'0') ||                                                    -- OFIGINA GESTORA                                                        (110:4)
	            LPAD(IFNULL((
	                SELECT MAX(SUBSTR(OFICINA_COBRADORA,1,4))
	                FROM EXT.RECIBOS
	                WHERE CODIGO_POLIZA LIKE (
	                        CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2'
	                            THEN SUBSTR(CAR_LP.PRODUCTID,1,4) || '0' ||SUBSTR(CAR_LP.PRODUCTID,LENGTH(CAR_LP.PRODUCTID)-1,2) || BR.CODIGO_POLIZA
	                            ELSE  SUBSTR(CAR_LP.PRODUCTID,1,5) || '00' || BR.CODIGO_POLIZA
	                        END) || '%'
	                    AND CODIGO_RECIBO = ST.GENERICATTRIBUTE7
	                    AND FECHA_COMPENSACION = CAR_LP.COMPENSATIONDATE
	                    AND ESTADO_RECIBO = BR.ESTADO
	                    AND CODIGO_SUPLEMENTO = CAR_LP.COD_SUPLEMENTO                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
	            ),'0'),4, '0')        ||                                            -- OFICINA COBRADORA                                                      (114:4)
	            RPAD(IFNULL(CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2' THEN
	            SUBSTR(ST.GENERICATTRIBUTE7,1,11) ELSE '0' END,'0'),11,'0') ||      -- CODD-RECIBO-RT                                                         (118:11)
	            RPAD(IFNULL(SUBSTR(ST.GENERICATTRIBUTE10,1,5),' '),5,' ') ||           -- DISTCOB - Distrito Cobro                                               (129:5)
	            RPAD(IFNULL(CASE WHEN ST.VALUE < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  -- SIGNO                                                                  (134:1)
	            LPAD(IFNULL(ABS(CAST(ROUND(CAR_LP.VALUE, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND(CAR_LP.VALUE,2),1)*100),'0'),2,'0')  ||          -- PRIMA COMISIONABLE                                                     (135:10)
	            RPAD(' ',1) ||                                                      -- IND-PASE                                                               (145:1)
	            RPAD(IFNULL(SUBSTR(BR.ESTADO,1,1),' '),1,' ' ) ||           -- SITUACION (Situacion recibo: Cobrado, Pendiente, devuelto, emitido)    (146:1)
	            RPAD(IFNULL(CASE WHEN POS.TITLESEQ <> 5629499534213290 THEN '1' ELSE '0'
	                END,' '),1,' ') ||                                              -- ACTIVO, Indicador Agente Activo. Si tiene TTL SIN PLAN es 0 si no es 1 (147:1)
	            LPAD(IFNULL(SUBSTR(CAR_LP.COD_SUPLEMENTO,1,3),'0'),3,'0')  ||           -- SUPLEMENTO                                                             (148:3)
	            RPAD(IFNULL(CASE WHEN SUBSTR(CAR_LP.PRODUCTID,1,2) = '01'
	                THEN (CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2' THEN SUBSTR(POS.GENERICATTRIBUTE7,1,3) ELSE SUBSTR(POS.GENERICATTRIBUTE6,1,3) END)
	                ELSE (CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) = '2' THEN SUBSTR(POS.GENERICATTRIBUTE12,1,3) ELSE SUBSTR(POS.GENERICATTRIBUTE11,1,3) END)
	            END,' '),3, ' ') ||                                                 -- CUADRO AGENTE                                                          (151:3)
	            RPAD('+0000000',7) ||                                               -- PREMIO                                                                 (154:7)
	            RPAD(IFNULL(CASE WHEN BR.PRIMA_CORREGIDA < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  --SIGNO
	            LPAD(IFNULL(ABS(CAST(ROUND(BR.PRIMA_CORREGIDA, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND( BR.PRIMA_CORREGIDA,2),1)*100),'0'),2,'0')  ||                   --'PRIMCORR',                                                             (161:11)
	            RPAD('+000000',6) ||                                                --'COEF-CORR',                                                            (172:6)
	            RPAD('+000000',6)||                                                 --'COEF-DIFER',                                                           (178:6)
	            RPAD(IFNULL(CASE WHEN BR.DIF_INSP < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  --SIGNO
	            LPAD(IFNULL(ABS(CAST(ROUND(BR.DIF_INSP, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND( BR.DIF_INSP,2),1)*100),'0'),2,'0')  ||                        --'IMP-DIFER',                                                            (184:11)
	            RPAD(IFNULL(CASE WHEN BR.POLIZA_CORREGIDA < 0 THEN '-' ELSE '+'
	            END,'+'),1,' ') ||                                                  --SIGNO
	            LPAD(IFNULL(ABS(CAST(ROUND(BR.POLIZA_CORREGIDA, 2) AS INTEGER)),'0'),8,'0') ||
	            LPAD(IFNULL(ABS(MOD(ROUND( BR.POLIZA_CORREGIDA,2),1)*100),'0'),2,'0')  ||                     -- POL-CORRE',                                                            (195:3)
	            LPAD(IFNULL(CASE WHEN SUBSTR(CAR_LP.PRODUCTID,3,1) <> '2' THEN
	            ST.GENERICATTRIBUTE7 ELSE '0' END,'0'), 11, '0') ||                   --'COD-RECIB',                                                            (198:9)
	            -- LPAD(IFNULL(SUBSTR(BR.MAN_ACT_POS_PRIN,-6),'0'),6,'0')||                        -- RESP-COMER' CODIGO DE RESPONSABLE COMERCIAL                            (207:6)
	            LPAD(IFNULL(CASE WHEN LENGTH(BR.MAN_ACT_POS_PRIN) > 4 THEN BR.MAN_ACT_POS_PRIN
	            ELSE CONCAT(BR.MAN_ACT_POS_PRIN, '000000') END,'0'), 10, '0')  ||   -- RESP-COMER' CODIGO DE RESPONSABLE COMERCIAL                            (207:6)
	            RPAD('000',3)||                                                     --'CLV-MEC',                                                              (213:3)
	            LPAD(IFNULL(SUBSTR(BR.COD_AGENTE,LENGTH(BR.COD_AGENTE)-5,6),'0'),6,'0')||                              --'AGTE-DOC',                                                             (216:6)
	            LPAD(IFNULL(CASE WHEN LENGTH((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)) > 4 
	            THEN (CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END)
	            ELSE CONCAT((CASE WHEN P_M.GENERICATTRIBUTE3 IS NULL 
	            THEN MAN.GENERICATTRIBUTE3 ELSE P_M.GENERICATTRIBUTE3 END), '000000') END,'0'), 10, '0')         --'INSP-DOC'                                                              (226:6)
			FROM EXT.CARTERA_DDEE CAR_LP
			LEFT JOIN :TBL_BASES_REPARTO_POLIZA BR ON CAR_LP.ORDERID = BR.ORDERID
				AND CAR_LP.LINENUMBER = BR.LINENUMBER
				AND CAR_LP.SUBLINENUMBER = BR.SUBLINENUMBER
				
	        LEFT  JOIN :TBL_REPEXT_REC_COM_COB X ON X.SALESORDERSEQ = BR.SALESTRANSACTIONSEQ
	            AND X.SUBLINENUMBER = CAR_LP.SUBLINENUMBER
	            AND  X.LINENUMBER = (CAR_LP.LINENUMBER || CASE WHEN CAR_LP.EVENTTYPEID  NOT IN ('AS10','AS50','Pago Comercial','A','B','AS110','AS90','AS91','REC-RRTT') THEN CAR_LP.EVENTTYPEID END)

	        INNER JOIN TCMP.CS_POSITION POS ON CAR_LP.POSITIONNAME = POS.NAME
	            AND POS.TENANTID = :v_idtenant AND POS.PROCESSINGUNITSEQ = 38280596832649217
	            AND POS.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND POS.REMOVEDATE = :v_eot								
	            AND POS.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND POS.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)		
	       
	        --ALM 20211117: Incluimos la jerarquia de Contract Rollup para quedarnos con la Positon principal de cada agente porque sera esta la que cobre el pago.
	        LEFT JOIN :TBL_POSREL PR ON POS.RULEELEMENTOWNERSEQ = PR.CHILDPOSITIONSEQ
	        
			LEFT JOIN TCMP.CS_POSITION P ON PR.PARENTPOSITIONSEQ = P.RULEELEMENTOWNERSEQ
	            AND P.TENANTID = :v_idtenant
	            AND P.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND P.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            --ALM 20220519: Utilizamos el ultimo dia del mes actual igual que se hace en el PAGEXT en lugar de la fecha del Post.
	            AND P.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND P.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
	        --ALM 20221114: Incluimos los INNER necesarios para poder atacar al manager principal de la position sin usar subconsultas que influyen demasiado en el rendimiento.
	        --Buscamos la Position Principal del agente de la transaccion en la fecha de emision de la poliza (PP) ya que el manager que buscamos es el de esa fecha.
	        LEFT JOIN TCMP.CS_POSITION PP ON PP.RULEELEMENTOWNERSEQ = (CASE WHEN P.RULEELEMENTOWNERSEQ IS NULL THEN POS.RULEELEMENTOWNERSEQ ELSE P.RULEELEMENTOWNERSEQ END) 
	            AND PP.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND PP.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            AND PP.EFFECTIVESTARTDATE <= CAR_LP.FECHA_EMISION --(CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
	            AND PP.EFFECTIVEENDDATE > CAR_LP.FECHA_EMISION --(CASE WHEN ST.FECHA_EMISION < to_date('20140101','yyyymmdd') THEN to_date('20140101','yyyymmdd') ELSE ST.FECHA_EMISION END)
	            AND PP.TENANTID = :v_idtenant
	        --Cogemos la version a cierre del periodo del manager (MAN) que tenia la Posicion Principal del agente en la fecha emision de la poliza (PP). 
	        LEFT JOIN TCMP.CS_POSITION MAN ON MAN.RULEELEMENTOWNERSEQ = PP.MANAGERSEQ
	            AND MAN.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND MAN.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            AND MAN.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND MAN.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero) 
	            AND MAN.TENANTID = :v_idtenant
	        --Comprobamos con la Contract Rollup cual es la position proncipal del Manager (MAN).
	      
		    LEFT JOIN :TBL_POSREL_M PR_M ON MAN.RULEELEMENTOWNERSEQ = PR_M.CHILDPOSITIONSEQ
	        LEFT JOIN TCMP.CS_POSITION P_M ON PR_M.PARENTPOSITIONSEQ = P_M.RULEELEMENTOWNERSEQ
	            AND P_M.TENANTID = :v_idtenant
	            AND P_M.CREATEDATE < LAST_DAY(:v_fechafichero)
	            AND P_M.REMOVEDATE > LAST_DAY(:v_fechafichero)
	            AND P_M.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND P_M.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
		
		    LEFT JOIN TCMP.CS_SALESTRANSACTION ST ON BR.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
				AND ST.COMPENSATIONDATE = CAR_LP.COMPENSATIONDATE
				AND ST.TENANTID = :v_idtenant AND ST.PROCESSINGUNITSEQ = 38280596832649217
                AND ST.MODELSEQ = 0
                
            INNER JOIN TCMP.CS_POSITION POS1 ON CAR_LP.POSITIONNAME = POS1.NAME
                AND POS1.TENANTID = :v_idtenant AND POS.PROCESSINGUNITSEQ = 38280596832649217
                AND POS1.CREATEDATE < :v_fechafichero
                AND POS1.REMOVEDATE > :v_fechafichero
                AND POS1.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
                AND POS1.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
	        
			LEFT JOIN TCMP.CS_PARTICIPANT PART ON POS.PAYEESEQ = PART.PAYEESEQ
	            AND PART.TENANTID = :v_idtenant
	            AND PART.CREATEDATE < :v_fechafichero
	            AND PART.REMOVEDATE > :v_fechafichero
	            AND PART.EFFECTIVESTARTDATE <= LAST_DAY(:v_fechafichero)
	            AND PART.EFFECTIVEENDDATE > LAST_DAY(:v_fechafichero)
            WHERE CAR_LP.COMPENSATIONDATE = :v_fechafichero
                AND CAR_LP.ESTADO = 'C'
                AND CAR_LP.IMPORTE <> 0
                AND NOT (
                        CAR_LP.EVENTTYPEID = 'Pago Comercial' 
                        AND SUBSTR(CAR_LP.EARNINGCODEID, 1, 1) IN ('4', '5', '3', '8')
                    )
                AND CAR_LP.EVENTTYPEID NOT IN ('A','B','S','20','15');
       

	   v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insert en la tabla EXT.OUT_AUDITORIA_INF_TIP_FILE. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

        UPDATE EXT.OUT_BATCH_CONTROL
	    SET STATUS = v_const_out_batch_control_ok,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    WHERE FILE_NAME = FILENAME
	    	AND ID_PROCESO = v_idproceso;
    
    	CALL EXT.LIB_GLOBAL:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');

    END;


END
