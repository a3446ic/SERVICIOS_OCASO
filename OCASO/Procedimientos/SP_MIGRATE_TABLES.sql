CREATE PROCEDURE EXT.SP_MIGRATE_TABLES( IN i_file_name VARCHAR(120) )
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Isaac Torrado
    | Company: Inycom
    | Initial Version Date: 1-Septiembre-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Migración de tablas de inyc_lp a tablas definitivas
    | -- cdl filetype outbound MIGRATETABLAS
	| -- cdl table EXT.OUT_MIGRATE_TABLES_FILE 
    |
	| Version:	0.1	itl 20250911	Initial Version.
	|			0.2	DTB 20251031	RPP_DETALLE, RPP_RESUMEN, RPI_RESUMEN,
									PEPA_RESUMEN, PEPI_RESUMEN
	|			0.3 BRG 20251111    Añadidas varias tablas que faltaban
	|			0.4	BRG	20251112	Añadido ROWCOUNT a los INSERT en CSE_LOG
	|			0.5	BRG	20251201	Añadido WF_REPEXT_BASE_REPARTO_FILE
	|			0.6	BRG	20251218	Añadidas tablas RE
	|
    -----------------------------------------------------------------------
*/

BEGIN
    DECLARE v_version NVARCHAR(20) = '0.6';
    DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
    DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_idproceso BIGINT := 0;
	DECLARE v_log_count INTEGER := 0;
    DECLARE nombretabla NVARCHAR(250);
    DECLARE v_num_rows INTEGER := 0;

    SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, v_log_count, v_idproceso, 'info');
    
    --- nombre de la tabla a SELECT tablename into nombretabla FROM ext.OUT_MIGRATETABLES_FILES ;
    nombretabla := REPLACE(i_file_name, 'MIGRATETABLES_', '');
    nombretabla := REPLACE(nombretabla, '.txt', '');

    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TABLA A PROCESAR = ' || nombretabla, v_log_count, v_idproceso, 'info');

    IF nombretabla = 'ASEGURADOS' THEN
        -- ASEGURADOS
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en ASEGURADOS', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.ASEGURADOS
            SELECT
                -99999999,
                FILE_NAME,
                '9',
                current_timestamp,
                CODIGO_POLIZA,
                NUMERO_ASEGURADO,
                NIF,
                FECHA_NACIMIENTO,
                FECHA_DE_DERECHOS,
                MOTIVO_ALTA,
                CONTO_COMO_ALTA,
                CONTO_COMO_NUEVO,
                FECHA_ALTA,
                MOTIVO_BAJA,
                FECHA_BAJA,
                FECHA_REHABILITACION,
                POLIZA_ORIGEN,
                ASEGURADO_ORIGEN,
                EDAD,
                EDAD_DERECHOS
            FROM EXT.inyc_lp_ASEGURADOS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - ASEGURADOS cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;

    ELSEIF nombretabla = 'ASEGURADOS_HIST' THEN 
        -- ASEGURADOS_HIST 
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en ASEGURADOS_HIST', v_log_count, v_idproceso, 'error');
            END;
            insert into ext.asegurados_hist
            SELECT 
                IDPROCESO,
                -99999999,
                FILE_NAME,
                9,
                current_timestamp,
                CODIGO_POLIZA,
                NUMERO_ASEGURADO,
                NIF,
                FECHA_NACIMIENTO,
                FECHA_DE_DERECHOS,
                MOTIVO_ALTA,
                CONTO_COMO_ALTA,
                CONTO_COMO_NUEVO,
                FECHA_ALTA,
                MOTIVO_BAJA,
                FECHA_BAJA,
                FECHA_REHABILITACION,
                POLIZA_ORIGEN,
                ASEGURADO_ORIGEN,
                EDAD,
                EDAD_DERECHOS
            FROM EXT.inyc_lp_asegurados_hist;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - ASEGURADOS_HIST cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;

    ELSEIF nombretabla = 'CARTERA_DDEE' THEN 
    --CARTERA_DDEE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CARTERA_DDEE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CARTERA_DDEE SELECT * FROM 	EXT.INYC_CARTERA_LP_DET;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CARTERA_DDEE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'CONF_AGENTES_REP' THEN 
    --CONF_AGENTES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CONF_AGENTES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CONF_AGENTES_REP SELECT * FROM 	EXT.INYC_CONF_INF_AGENTES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CONF_AGENTES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'CONF_INFORMES_REP' THEN 
    --CONF_INFORMES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CONF_INFORMES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CONF_INFORMES_REP SELECT * FROM 	EXT.INYC_CONF_INFORMES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CONF_INFORMES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'CONF_PARAMETROS_FILE' THEN 
    --CONF_PARAMETROS_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CONF_PARAMETROS_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CONF_PARAMETROS_FILE SELECT * FROM 	EXT.INYC_PARAMETROS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CONF_PARAMETROS_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;


    ELSEIF nombretabla = 'CONF_REGLAS_REP' THEN 
    --CONF_REGLAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CONF_REGLAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CONF_REGLAS_REP SELECT * FROM 	EXT.INYC_CONF_INF_REGLAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CONF_REGLAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'CONF_REPEXT_CONCEPTOS_CDA_FILE' THEN 
    --CONF_REPEXT_CONCEPTOS_CDA_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CONF_REPEXT_CONCEPTOS_CDA_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CONF_REPEXT_CONCEPTOS_CDA_FILE SELECT * FROM 	EXT.INYC_REPEXT_CONCEPTOS_CDA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CONF_REPEXT_CONCEPTOS_CDA_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'CONF_REPEXT_CONCEPTOS_CONTABLES_FILE' THEN 
    --CONF_REPEXT_CONCEPTOS_CONTABLES_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CONF_REPEXT_CONCEPTOS_CONTABLES_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CONF_REPEXT_CONCEPTOS_CONTABLES_FILE SELECT * FROM 	EXT.INYC_CONCEPTOS_CONTABLES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CONF_REPEXT_CONCEPTOS_CONTABLES_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'CONF_REPEXT_CONTROL_FILE' THEN 
    --CONF_REPEXT_CONTROL_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en CONF_REPEXT_CONTROL_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.CONF_REPEXT_CONTROL_FILE SELECT * FROM 	EXT.INYC_REPEXT_CONTROL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - CONF_REPEXT_CONTROL_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_BASES_REPARTO_POLIZA_FILE' THEN 
    --FINAL_BASES_REPARTO_POLIZA_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_BASES_REPARTO_POLIZA_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_BASES_REPARTO_POLIZA_FILE (DIF_CAPT, CAPTADOR_POS_PRIN, PRIMA_NETA_ANUAL, PRIMA_NETA, NUM_ASEG, POLIZA_CORREGIDA, POLIZA_FISICA, IMP_SERV_ASISTENCIAS, SERVICIO_ASISTENCIAS, IMPORTE_GRATIF, IMPORTE_COMISION, AUTOLIQUIDA, ESTADO, COMPENSATIONDATE, COD_AGENTE, SALESTRANSACTIONSEQ, PRIMA_COMIS_S5, PRIMA_COMIS_S4, LOC_RESP, LOC_INSP, DIF_RESP, DIF_INSP, POLIZA_CORR_MANAGER, POLIZA_FISICA_MANAGER, PRIMA_CORREGIDA, CODIGO_POLIZA, PRODUCTID, EVENTTYPEID, SUBLINENUMBER, LINENUMBER, ORDERID, MAN_ACT_POS_PRIN, MANAGER_POS_PRIN, POS_PRIN, POSITIONNAME, PERIODSEQ, POSITIONSEQ, PARTICIPANTSEQ, CAMBIO_AG_INSP )
        SELECT
            DIF_CAPT, CAPTADOR_POS_PRIN, PRIMA_NETA_ANUAL, PRIMA_NETA, NUM_ASEG, POLIZA_CORREGIDA, POLIZA_FISICA, IMP_SERV_ASISTENCIAS, SERVICIO_ASISTENCIAS, IMPORTE_GRATIF, IMPORTE_COMISION, AUTOLIQUIDA, ESTADO, COMPENSATIONDATE, COD_AGENTE, SALESTRANSACTIONSEQ, PRIMA_COMIS_S5, PRIMA_COMIS_S4, LOC_RESP, LOC_INSP, DIF_RESP, DIF_INSP, POLIZA_CORR_MANAGER, POLIZA_FISICA_MANAGER, PRIMA_CORREGIDA, CODIGO_POLIZA, PRODUCTID, EVENTTYPEID, SUBLINENUMBER, LINENUMBER, ORDERID, MAN_ACT_POS_PRIN, MANAGER_POS_PRIN, POS_PRIN, POSITIONNAME, PERIODSEQ, POSITIONSEQ, PARTICIPANTSEQ, CAMBIO_AG_INSP
        FROM EXT.INYC_BASES_REPARTO_POLIZA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_BASES_REPARTO_POLIZA_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_COMEXT_FILE' THEN 
    --FINAL_COMEXT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_COMEXT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_COMEXT_FILE (IMPORTE,MOD_COBRO,PC_COBRO,MOD_CARTERA,PC_CARTERA,MOD_CONS,PC_CONSERVACION,MOD_CONS2,PC_CONSERVACION2,MOD_GEST,PC_GESTION,GENERICDATE2,CREDITTYPEID,EVENTTYPEID,SUBLINENUMBER,LINENUMBER,ORDERID)
        SELECT IMPORTE, MOD_COBRO, PC_COBRO, MOD_CARTERA, PC_CARTERA, MOD_CONS, PC_CONSERVACION, MOD_CONS2, PC_CONSERVACION2, MOD_GEST, PC_GESTION, GENERICDATE2, CREDITTYPEID, EVENTTYPEID, SUBLINENUMBER, LINENUMBER, ORDERID
        FROM EXT.INYC_COMEXT_FINAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_COMEXT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_COMREC_FILE' THEN 
    --FINAL_COMREC_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_COMREC_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_COMREC_FILE SELECT * FROM 	EXT.INYC_COMREC_FINAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_COMREC_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_EXTRACTPAGOS_FILE' THEN 
    --FINAL_EXTRACTPAGOS_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_EXTRACTPAGOS_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_EXTRACTPAGOS_FILE SELECT * FROM 	EXT.INYC_EXTRACTPAGOS_FINAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_EXTRACTPAGOS_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_LIQEXT_CABECERA_FILE' THEN 
    --FINAL_LIQEXT_CABECERA_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_LIQEXT_CABECERA_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_LIQEXT_CABECERA_FILE SELECT * FROM 	EXT.INYC_LIQEXT_CABECERA_FINAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_LIQEXT_CABECERA_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_LIQEXT_FILE' THEN 
    --FINAL_LIQEXT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_LIQEXT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_LIQEXT_FILE SELECT * FROM 	EXT.INYC_LIQEXT_FINAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_LIQEXT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;


    ELSEIF nombretabla = 'FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE' THEN 
    --FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE SELECT * FROM 	EXT.INYC_LIQEXT_CABECERA_ONLINE;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_REPEXT_CDA_FILE' THEN 
    --FINAL_REPEXT_CDA_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_REPEXT_CDA_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_REPEXT_CDA_FILE SELECT * FROM 	EXT.INYC_REPEXT_INF_CDA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_REPEXT_CDA_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_REPEXT_FILE' THEN 
    --FINAL_REPEXT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_REPEXT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_REPEXT_FILE SELECT * FROM 	EXT.INYC_REPEXT_FINAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_REPEXT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_REPEXT_INF_PYG_FILE' THEN 
    --FINAL_REPEXT_INF_PYG_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_REPEXT_INF_PYG_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_REPEXT_INF_PYG_FILE SELECT * FROM 	EXT.INYC_REPEXT_INF_PYG;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_REPEXT_INF_PYG_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_REPEXT_INF_SAP_FILE' THEN 
    --FINAL_REPEXT_INF_SAP_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_REPEXT_INF_SAP_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_REPEXT_INF_SAP_FILE SELECT * FROM 	EXT.INYC_REPEXT_INF_SAP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_REPEXT_INF_SAP_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_REPEXT_INR_SAP_FILE' THEN 
    --FINAL_REPEXT_INR_SAP_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_REPEXT_INR_SAP_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_REPEXT_INR_SAP_FILE SELECT * FROM 	EXT.INYC_REPEXT_INR_SAP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_REPEXT_INR_SAP_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'FINAL_REPEXT_PAGOS_FILE' THEN 
    --FINAL_REPEXT_PAGOS_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_REPEXT_PAGOS_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_REPEXT_PAGOS_FILE SELECT * FROM 	EXT.INYC_REPEXT_PAGOS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_REPEXT_PAGOS_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'GARANTIAS_ASEGURADO' THEN 
    --GARANTIAS_ASEGURADO
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en GARANTIAS_ASEGURADO', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.GARANTIAS_ASEGURADO
        SELECT 
        	-99999999,
        	---99999999,
        	-99999999,
        	FILE_NAME,
        	'9',
        	current_timestamp,
        	CODIGO_POLIZA,
        	NUMERO_ASEGURADO,
        	PRODUCTO_CONTABLE,
        	CODIGO_RECIBO,
        	PRIMA_UNICA,
        	GARANTIA_IP,
        	PRIMA_NETA_ASEGURADO,
        	PORCENTAJE_PARTICIPACION,
        	PORCENTAJE_NIVELADA,
        	CAPITAL_NATURAL,
        	CAPITAL_NIVELADO,
        	SUBTIPO_MOVIMIENTO,
        	MARCA_CUENTA,
        	PRIMA_COMISIONABLE,
        	UNIDAD_DE_POLIZA,
        	MESES_COBRADOS,
        	FECHA_ALTA_GAR_ASE,
        	FECHA_BAJA_GAR_ASE,
        	NUM_ORDEN_MOVIMIENTO,
        	PC_PERIODO,
        	NUM_PERIODOS
        FROM EXT.INYC_LP_GARANTIAS_ASEGURADO;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - GARANTIAS_ASEGURADO cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'GARANTIAS_ASEGURADO_HIST' THEN 
    --GARANTIAS_ASEGURADO_HIST
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en GARANTIAS_ASEGURADO_HIST', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.GARANTIAS_ASEGURADO_HIST
        SELECT
        	IDPROCESO,
        	-99999999,
        	-99999999,
        	-99999999,
        	FILE_NAME,
        	9,
        	current_timestamp,
        	CODIGO_POLIZA,
        	NUMERO_ASEGURADO,
        	PRODUCTO_CONTABLE,
        	CODIGO_RECIBO,
        	PRIMA_UNICA,
        	GARANTIA_IP,
        	PRIMA_NETA_ASEGURADO,
        	PORCENTAJE_PARTICIPACION,
        	PORCENTAJE_NIVELADA,
        	CAPITAL_NATURAL,
        	CAPITAL_NIVELADO,
        	SUBTIPO_MOVIMIENTO,
        	MARCA_CUENTA,
        	PRIMA_COMISIONABLE,
        	UNIDAD_DE_POLIZA,
        	MESES_COBRADOS,
        	FECHA_ALTA_GAR_ASE,
        	FECHA_BAJA_GAR_ASE,
        	NUM_ORDEN_MOVIMIENTO,
        	PC_PERIODO,
        	NUM_PERIODOS
        FROM EXT.INYC_LP_GARANTIAS_ASEGUR_HIST;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - GARANTIAS_ASEGURADO_HIST cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'GARANTIAS_RECIBO' THEN 
    --GARANTIAS_RECIBO
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en GARANTIAS_RECIBO', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.GARANTIAS_RECIBO
        select 
            -99999999 ,
            FILE_NAME ,
            '6',
            current_timestamp/*FECHA_MODIFICACION <TIMESTAMP>*/,
            CODIGO_POLIZA ,
            CODIGO_RECIBO ,
            PRODUCTO_CONTABLE ,
            ESTADO_RECIBO ,
            PRIMA_NETA_RECIBO ,
            PRIMA_BRUTA_RECIBO,
            RECARGO ,
            PORCENTAJE_BONIFICACION ,
            INCREMENTO_PRIMA_ANUAL ,
            PRIMA_COMISIONABLE ,
            UNIDAD_DE_POLIZA ,
            MESES_COBRADOS ,
            FECHA_ALTA_GAR_POL ,
            FECHA_BAJA_GAR_POL ,
            PORCENTAJE_NIVELADA ,
            PERIODO_EXTORNABLE,
            INDICADOR_COMISION_CALCULADA ,
            INDICADOR_PORCENTAJE_CALCULA ,
            PORCENTAJE_COMISION_CALCULAD ,
            IMPORTE_COMISION ,
            PRIMA_UNICA ,
            NUM_ORDEN_MOVIMIENTO ,
            AUMENTO_CAPITALES_GARANTIA ,
            PRIMA_NETA_ANUALIZADA ,
            PORC_COMISION_NP ,
            PORC_COMISION_CONSERVACION ,
            CODIGO_SUPLEMENTO ,
            PORC_COMISION_COBRO 
        FROM EXT.INYC_LP_GARANTIAS_RECIBO;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - GARANTIAS_RECIBO cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'GARANTIAS_RECIBO_HIST' THEN 
    --GARANTIAS_RECIBO_HIST
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en GARANTIAS_RECIBO_HIST', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.GARANTIAS_RECIBO_HIST
        SELECT 
            IDPROCESO,
            -99999999,
            -99999999,
            FILE_NAME,
            9,
            current_timestamp,
            CODIGO_POLIZA,
            CODIGO_RECIBO,
            PRODUCTO_CONTABLE,
            ESTADO_RECIBO,
            PRIMA_NETA_RECIBO,
            PRIMA_BRUTA_RECIBO,
            RECARGO,
            PORCENTAJE_BONIFICACION,
            INCREMENTO_PRIMA_ANUAL,
            PRIMA_COMISIONABLE,
            UNIDAD_DE_POLIZA,
            MESES_COBRADOS,
            FECHA_ALTA_GAR_POL,
            FECHA_BAJA_GAR_POL,
            PORCENTAJE_NIVELADA,
            PERIODO_EXTORNABLE,
            INDICADOR_COMISION_CALCULADA,
            INDICADOR_PORCENTAJE_CALCULA,
            PORCENTAJE_COMISION_CALCULAD,
            IMPORTE_COMISION,
            PRIMA_UNICA,
            NUM_ORDEN_MOVIMIENTO,
            AUMENTO_CAPITALES_GARANTIA,
            PRIMA_NETA_ANUALIZADA,
            PORC_COMISION_NP,
            PORC_COMISION_CONSERVACION,
            CODIGO_SUPLEMENTO,
            PORC_COMISION_COBRO
        FROM EXT.inyc_lp_GARANTIAS_RECIBO_HIST;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - GARANTIAS_RECIBO_HIST cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'GEN_AGE_COMIS_ANTICIPA' THEN 
    --GEN_AGE_COMIS_ANTICIPA
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en GEN_AGE_COMIS_ANTICIPA', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.GEN_AGE_COMIS_ANTICIPA SELECT * FROM 	EXT.INYC_LP_GEN_AGE_COMIS_ANTICIPA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - GEN_AGE_COMIS_ANTICIPA cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_ASI_RESUMEN_REP' THEN 
    --OUT_ASI_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_ASI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_ASI_RESUMEN_REP SELECT * FROM 	EXT.INYC_ASI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_ASI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_ASI_RESUMEN_REP' THEN 
    --OUT_BAL_ASI_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_ASI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_ASI_RESUMEN_REP SELECT * FROM 	EXT.INYC_BAL_ASI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_ASI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_GES_RESUMEN_REP' THEN 
    --OUT_BAL_GES_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_GES_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_GES_RESUMEN_REP SELECT * FROM 	EXT.INYC_BAL_GES_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_GES_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_RPA_RESUMEN_REP' THEN 
    --OUT_BAL_RPA_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_RPA_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_RPA_RESUMEN_REP SELECT * FROM 	EXT.INYC_BAL_RPA_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_RPA_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_S4_E_FACTURA_REP' THEN 
    --OUT_BAL_S4_E_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S4_E_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S4_E_FACTURA_REP SELECT * FROM 	EXT.INYC_BAL_S4_E_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S4_E_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_S4_E_POLIZAS_REP' THEN 
    --OUT_BAL_S4_E_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S4_E_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S4_E_POLIZAS_REP SELECT * FROM 	EXT.INYC_BAL_S4_E_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S4_E_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;
    
    ELSEIF nombretabla = 'OUT_BAL_S4_FACTURA_REP' THEN 
    --OUT_BAL_S4_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S4_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S4_FACTURA_REP SELECT * FROM 	EXT.INYC_BAL_S4_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S4_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_S4_POLIZAS_REP' THEN 
    --OUT_BAL_S4_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S4_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S4_POLIZAS_REP SELECT * FROM 	EXT.INYC_BAL_S4_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S4_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_S5_E_FACTURA_REP' THEN 
    --OUT_BAL_S5_E_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S5_E_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S5_E_FACTURA_REP SELECT * FROM 	EXT.INYC_BAL_S5_E_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S5_E_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_S5_E_POLIZAS_REP' THEN 
    --OUT_BAL_S5_E_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S5_E_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S5_E_POLIZAS_REP SELECT * FROM 	EXT.INYC_BAL_S5_E_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S5_E_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_S5_FACTURA_REP' THEN 
    --OUT_BAL_S5_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S5_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S5_FACTURA_REP SELECT * FROM 	EXT.INYC_BAL_S5_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S5_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_BAL_S5_POLIZAS_REP' THEN 
    --OUT_BAL_S5_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_S5_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_BAL_S5_POLIZAS_REP SELECT * FROM 	EXT.INYC_BAL_S5_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_S5_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_COMEXT_INFORME_FILE' THEN 
    --OUT_COMEXT_INFORME_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_COMEXT_INFORME_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_COMEXT_INFORME_FILE SELECT * FROM 	EXT.INYC_COMEXT_INFORME;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_COMEXT_INFORME_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_COMREC_INFORME_FILE' THEN 
    --OUT_COMREC_INFORME_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_COMREC_INFORME_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_COMREC_INFORME_FILE SELECT * FROM 	EXT.INYC_COMREC_INFORME;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_COMREC_INFORME_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_EXTRACTPAGOS_INFORME_FILE' THEN 
    --OUT_EXTRACTPAGOS_INFORME_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_EXTRACTPAGOS_INFORME_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_EXTRACTPAGOS_INFORME_FILE SELECT * FROM 	EXT.INYC_EXTRACTPAGOS_INFORME;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_EXTRACTPAGOS_INFORME_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_FECHAS_WEBI_REP' THEN 
    --OUT_FECHAS_WEBI_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_FECHAS_WEBI_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_FECHAS_WEBI_REP ( PERIODO, DESCRIPCION, ULTIMA_ACTUALIZACION, TABLA, PERIODSEQ )
        SELECT f.PERIODO,f.DESCRIPCION,f.ULTIMA_ACTUALIZACION,f.TABLA,p.PERIODSEQ
        FROM EXT.INYC_FECHAS_WEBI f  --11991
        JOIN CS_PERIOD p
            ON f.PERIODO = p.NAME and p.REMOVEDATE='2200-01-01' ;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_FECHAS_WEBI_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_GES_RESUMEN_REP' THEN 
    --OUT_GES_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_GES_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_GES_RESUMEN_REP SELECT * FROM 	EXT.INYC_GES_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_GES_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_INSP_ACTIVOS_REP' THEN 
    --OUT_INSP_ACTIVOS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_INSP_ACTIVOS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_INSP_ACTIVOS_REP SELECT * FROM 	EXT.INYC_INSP_ACTIVOS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_INSP_ACTIVOS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_JERARQUIA_REP' THEN 
    --OUT_JERARQUIA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_JERARQUIA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_JERARQUIA_REP SELECT * FROM 	EXT.INYC_JERARQUIA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_JERARQUIA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_ASI_RESUMEN_REP' THEN 
    --OUT_LC_ASI_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_ASI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_ASI_RESUMEN_REP SELECT * FROM 	EXT.INYC_LC_ASI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_ASI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_GES_RESUMEN_REP' THEN 
    --OUT_LC_GES_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_GES_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_GES_RESUMEN_REP SELECT * FROM 	EXT.INYC_LC_GES_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_GES_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_RPA_RESUMEN_REP' THEN 
    --OUT_LC_RPA_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_RPA_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_RPA_RESUMEN_REP SELECT * FROM 	EXT.INYC_LC_RPA_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_RPA_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S4_E_FACTURA_REP' THEN 
    --OUT_LC_S4_E_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S4_E_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S4_E_FACTURA_REP SELECT * FROM 	EXT.INYC_LC_S4_E_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S4_E_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S4_E_POLIZAS_REP' THEN 
    --OUT_LC_S4_E_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S4_E_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S4_E_POLIZAS_REP SELECT * FROM 	EXT.INYC_LC_S4_E_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S4_E_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S4_FACTURA_REP' THEN 
    --OUT_LC_S4_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S4_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S4_FACTURA_REP SELECT * FROM 	EXT.INYC_LC_S4_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S4_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S4_POLIZAS_REP' THEN 
    --OUT_LC_S4_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S4_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S4_POLIZAS_REP SELECT * FROM 	EXT.INYC_LC_S4_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S4_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S5_E_FACTURA_REP' THEN 
    --OUT_LC_S5_E_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S5_E_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S5_E_FACTURA_REP SELECT * FROM 	EXT.INYC_LC_S5_E_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S5_E_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S5_E_POLIZAS_REP' THEN 
    --OUT_LC_S5_E_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S5_E_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S5_E_POLIZAS_REP SELECT * FROM 	EXT.INYC_LC_S5_E_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S5_E_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S5_FACTURA_REP' THEN 
    --OUT_LC_S5_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S5_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S5_FACTURA_REP SELECT * FROM 	EXT.INYC_LC_S5_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S5_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LC_S5_POLIZAS_REP' THEN 
    --OUT_LC_S5_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_S5_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LC_S5_POLIZAS_REP SELECT * FROM 	EXT.INYC_LC_S5_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_S5_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LIQEXT_CAB_INFORME_FILE' THEN 
    --OUT_LIQEXT_CAB_INFORME_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LIQEXT_CAB_INFORME_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LIQEXT_CAB_INFORME_FILE SELECT * FROM 	EXT.INYC_LIQEXT_CAB_INFORME;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LIQEXT_CAB_INFORME_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_LIQEXT_DET_INFORME_FILE' THEN 
    --OUT_LIQEXT_DET_INFORME_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LIQEXT_DET_INFORME_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_LIQEXT_DET_INFORME_FILE SELECT * FROM 	EXT.INYC_LIQEXT_DET_INFORME;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LIQEXT_DET_INFORME_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_PERC_AGENTES_REP' THEN 
    --OUT_PERC_AGENTES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_PERC_AGENTES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_PERC_AGENTES_REP SELECT * FROM 	EXT.INYC_PERC_AGENTES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_PERC_AGENTES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_PERC_INSPECTORES_REP' THEN 
    --OUT_PERC_INSPECTORES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_PERC_INSPECTORES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_PERC_INSPECTORES_REP SELECT * FROM 	EXT.INYC_PERC_INSPECTORES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_PERC_INSPECTORES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_PROD_AGENTES_REP' THEN 
    --OUT_PROD_AGENTES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_PROD_AGENTES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_PROD_AGENTES_REP SELECT * FROM 	EXT.INYC_PROD_AGENTES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_PROD_AGENTES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_PROD_E_AGENTES_REP' THEN 
    --OUT_PROD_E_AGENTES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_PROD_E_AGENTES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_PROD_E_AGENTES_REP SELECT * FROM 	EXT.INYC_PROD_E_AGENTES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_PROD_E_AGENTES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_PROD_INSPECTORES_REP' THEN 
    --OUT_PROD_INSPECTORES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_PROD_INSPECTORES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_PROD_INSPECTORES_REP SELECT * FROM 	EXT.INYC_PROD_INSPECTORES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_PROD_INSPECTORES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_RA_RESUMEN_REP' THEN 
    --OUT_RA_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_RA_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_RA_RESUMEN_REP SELECT * FROM 	EXT.INYC_RA_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_RA_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_REPEXT_INF_PYG_P_FILE' THEN 
    --OUT_REPEXT_INF_PYG_P_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_REPEXT_INF_PYG_P_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_REPEXT_INF_PYG_P_FILE SELECT * FROM 	EXT.INYC_REPEXT_INF_PYG_P;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_REPEXT_INF_PYG_P_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_RPA_RESUMEN_REP' THEN 
    --OUT_RPA_RESUMEN_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_RPA_RESUMEN_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_RPA_RESUMEN_REP SELECT * FROM 	EXT.INYC_RPA_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_RPA_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S4_E_FACTURA_REP' THEN 
    --OUT_S4_E_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S4_E_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S4_E_FACTURA_REP SELECT * FROM 	EXT.INYC_S4_E_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S4_E_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S4_E_POLIZAS_REP' THEN 
    --OUT_S4_E_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S4_E_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S4_E_POLIZAS_REP SELECT * FROM 	EXT.INYC_S4_E_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S4_E_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S4_FACTURA_REP' THEN 
    --OUT_S4_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S4_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S4_FACTURA_REP SELECT * FROM 	EXT.INYC_S4_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S4_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S4_POLIZAS_REP' THEN 
    --OUT_S4_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S4_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S4_POLIZAS_REP SELECT * FROM 	EXT.INYC_S4_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S4_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S5_E_FACTURA_REP' THEN 
    --OUT_S5_E_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S5_E_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S5_E_FACTURA_REP SELECT * FROM 	EXT.INYC_S5_E_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S5_E_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S5_E_POLIZAS_REP' THEN 
    --OUT_S5_E_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S5_E_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S5_E_POLIZAS_REP SELECT * FROM 	EXT.INYC_S5_E_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S5_E_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S5_FACTURA_REP' THEN 
    --OUT_S5_FACTURA_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S5_FACTURA_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S5_FACTURA_REP SELECT * FROM 	EXT.INYC_S5_FACTURA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S5_FACTURA_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_S5_POLIZAS_REP' THEN 
    --OUT_S5_POLIZAS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_S5_POLIZAS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_S5_POLIZAS_REP SELECT * FROM 	EXT.INYC_S5_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_S5_POLIZAS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_USUARIOS_REP' THEN 
    --OUT_USUARIOS_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_USUARIOS_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.OUT_USUARIOS_REP SELECT * FROM 	EXT.INYC_USUARIOS_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_USUARIOS_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'POLIZAS' THEN 
    --POLIZAS
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en POLIZAS', v_log_count, v_idproceso, 'error');
        END;
        insert into ext.polizas
        select 
            -99999999 /*IDENTIFICADOR <BIGINT>*/,
            ---99999999 ,--ID_RECIBO,
            FILE_NAME,
            '9',
            current_timestamp,
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
        FROM EXT.inyc_lp_POLIZAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - POLIZAS cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'POLIZAS_HIST' THEN 
    --POLIZAS_HIST
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en POLIZAS_HIST', v_log_count, v_idproceso, 'error');
        END;
        insert into ext.polizas_hist
        SELECT 
            IDPROCESO,
            -99999999,
            -99999999,
            FILE_NAME,
            9,
            current_timestamp,
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
        FROM EXT.inyc_lp_POLIZAS_HIST;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - POLIZAS_HIST cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'RECIBOS' THEN 
    --RECIBOS
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en RECIBOS', v_log_count, v_idproceso, 'error');
        END;
        insert into EXT.RECIBOS
        SELECT 
            -99999999 /*IDENTIFICADOR <BIGINT>*/,
            FILE_NAME ,
            '9'/*ESTADO <VARCHAR(255)>*/,
            current_timestamp /*FECHA_MODIFICACION <TIMESTAMP>*/,
            CODIGO_POLIZA,
            CODIGO_RECIBO,
            PERMANENCIA ,
            TIPO_RECIBO ,
            ESTADO_RECIBO,
            FECHA_COBRO ,
            FECHA_COMPENSACION ,
            FECHA_EFECTO_RECIBO,
            FECHA_VTO_RECIBO ,
            TIPO_MOVIMIENTO,
            PORCENTAJE_DESCUENTO_SOBRE_PC,
            VALOR_POLIZA,
            CODIGO_UNICO_AGENTE,
            CODIGO_AGENTE_ORIGINAL ,
            INSPECTOR ,
            OFICINA_COBRADORA ,
            OFICINA_GESTORA ,
            MARCA_RECUPERADO ,
            MARCA_CUENTA ,
            PRIMER_RECIBO ,
            ASEGURADOS_NETOS,
            AUMENTO_ASEGURADOS ,
            EXCLUIDO_COMISIONES,
            BONIFICACION_POLIZA,
            DISMINUCION_PRIMA ,
            TIPO_RECUPERACION ,
            ES_PERMANENCIA_20 ,
            CODIGO_AGENTE_COMMISSIONS,
            FECHA_EMISION_REC,
            FCHA_EFECTO_SUPLEMENTO ,
            CODIGO_SUPLEMENTO ,
            DISTRITO_COBRO,
            CODIGO_SINIESTRO ,
            ZONA_EXPLOTACION,
            CODIGO_AGENTE_ZONA
        FROM EXT.INYC_LP_RECIBOS ;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - RECIBOS cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'RECIBOS_HIST' THEN 
    -- RECIBOS_HIST
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en RECIBOS_HIST', v_log_count, v_idproceso, 'error');
        END;
        insert into ext.recibos_hist
        SELECT
            IDPROCESO,
            -99999999,
            FILE_NAME,
            9,
            current_timestamp,
            CODIGO_POLIZA,
            CODIGO_RECIBO,
            PERMANENCIA,
            TIPO_RECIBO,
            ESTADO_RECIBO,
            FECHA_COBRO,
            FECHA_COMPENSACION,
            FECHA_EFECTO_RECIBO,
            FECHA_VTO_RECIBO,
            TIPO_MOVIMIENTO,
            PORCENTAJE_DESCUENTO_SOBRE_PC,
            VALOR_POLIZA,
            CODIGO_UNICO_AGENTE,
            CODIGO_AGENTE_ORIGINAL,
            INSPECTOR,
            OFICINA_COBRADORA,
            OFICINA_GESTORA,
            MARCA_RECUPERADO,
            MARCA_CUENTA,
            PRIMER_RECIBO,
            ASEGURADOS_NETOS,
            AUMENTO_ASEGURADOS,
            EXCLUIDO_COMISIONES,
            BONIFICACION_POLIZA,
            DISMINUCION_PRIMA,
            TIPO_RECUPERACION,
            ES_PERMANENCIA_20,
            CODIGO_AGENTE_COMMISSIONS,
            FECHA_EMISION_REC,
            FCHA_EFECTO_SUPLEMENTO,
            CODIGO_SUPLEMENTO,
            DISTRITO_COBRO,
            CODIGO_SINIESTRO,
            ZONA_EXPLOTACION,
            CODIGO_AGENTE_ZONA
        FROM EXT.inyc_lp_RECIBOS_HIST;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - RECIBOS_HIST cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'STAGE_RECIBOS' THEN
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en STAGE_RECIBOS', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.STAGE_RECIBOS (FILE_NAME, ESTADO, FECHA_MODIFICACION, RAMO, CODIGO_POLIZA, MOTIVO_ALTA, FECHA_EFECTO_POLIZA, FECHA_EMISION_POLIZA, FECHA_CESION_POLIZA, MOTIVO_BAJA, FECHA_BAJA, FECHA_EFECTO_SUPLEMENTO, FECHA_VENCIMIENTO, FECHA_REHABILITACION, FORMA_PAGO, TIPO_CAMPANIA, CODIGO_AGENTE_ORIGINAL, CODIGO_UNICO_AGENTE, INSPECTOR, OFICINA_COBRADORA, OFICINA_GESTORA, SEGUNDA_RESIDENCIA, TARIFA, ZONA, CLAVE_RIESGO, CODIGO_SUPLEMENTO, DISTRITO_COBRO, MODALIDAD, DURACION, IND_COMI_CALCULADA, IND_POR_CALCULADO, POR_COMI_CALCULADA, IMPORTE_COMISION, CLAUSULA, AUMENTO_CAPITALES_GAR, SUSTITUCION_INCENDIOS, CODIGO_SINIESTRO, EXCLUIDO_COMISIONES, TRASPASADA, INCRE_PRIMA_ANUAL, DTO_IMPT_SINIESTRALIDAD, DTO_POR_PRIORITARIO, RIESGO, COLECTIVO, AUTOLIQUIDA, KILOMETROS, PRIMER_RECIBO, CODIGO_RECIBO, PERMANENCIA, TIPO_RECIBO, ESTADO_RECIBO, FECHA_COBRO, FECHA_EFECTO_RECIBO, FECHA_VENCIMIENTO_RECIBO, TIPO_MOVIMIENTO, PORC_DESTO_SOBREPC, VALOR_POLIZA, MARCA_RECUPERADO, PRODUCTO_CONTABLE, FECHA_ALTA_GAR_POL, FECHA_BAJA_GAR_POL, PRIMA_NETA_RECIBO, PRIMA_BRUTA_RECIBO, RECARGO, PORCENTAJE_BONIFICACION, POLIZA_CON_AGENTE, MOVILIDAD, PRIMA_UNICA, NUM_ORDEN_MOVIMIENTO, FECHA_EMISION_REC, CARGO_COMPENSACION, ZONA_EXPLOTACION, CODIGO_AGENTE_ZONA)
            SELECT 
                FILE_NAME,
                2,
                CURRENT_DATE,
                RAMO,
                CODIGOPOLIZA,
                MOTIVOALTA,
                FECHAEFECTOPOLIZA,
                FECHAEMISIONPOLIZA,
                FECHACESIONPOLIZA,
                MOTIVOBAJA,
                FECHABAJA,
                FECHAEFECTOSUPLEMENTO,
                FECHAVENCIMIENTO,
                FECHAREHABILITACION,
                FORMAPAGO,
                TIPOCAMPANIA,
                CODIGOAGENTEORIGINAL,
                CODIGOUNICOAGENTE,
                INSPECTOR,
                OFICINACOBRADORA,
                OFICINAGESTORA,
                SEGUNDARESIDENCIA,
                TARIFA,
                ZONA,
                CLAVERIESGO,
                CODIGOSUPLEMENTO,
                DISTRITOCOBRO,
                MODALIDAD,
                DURACION,
                INDCOMICALCULADA,
                INDPORCALCULADO,
                PORCOMICALCULADA,
                IMPORTE_COMISION,
                CLAUSULA,
                AUMENTOCAPITALESGAR,
                SUSTITUCION_INCENDIOS,
                CODIGOSINIESTRO,
                EXCLUIDOCOMISIONES,
                TRASPASADA,
                INCREPRIMAANUAL,
                DTOIMPTSINIESTRALIDAD,
                DTOPORPRIORITARIO,
                RIESGO,
                COLECTIVO,
                AUTOLIQUIDA,
                KILOMETROS,
                PRIMERRECIBO,
                CODIGORECIBO,
                PERMANENCIA,
                TIPORECIBO,
                ESTADORECIBO,
                FECHACOBRO,
                FECHAEFECTORECIBO,
                FECHAVENCIMIENTORECIBO,
                TIPOMOVIMIENTO,
                PORCDESTOSOBREPC,
                VALORPOLIZA,
                MARCARECUPERADO,
                PRODUCTOCONTABLE,
                FECHAALTAGARPOL,
                FECHABAJAGARPOL,
                PRIMANETARECIBO,
                PRIMABRUTARECIBO,
                RECARGO,
                PORCENTAJEBONIFICACION,
                POLIZACONAGENTE,
                MOVILIDAD,
                PRIMAUNICA,
                NUMORDENMOVIMIENTO,
                FECHA_EMISION_REC,
                CARGO_COMPENSACION,
                ZONA_EXPLOTACION,
                CODIGO_AGENTE_ZONA
            FROM EXT.INYC_LP_STAGE_RECIBOS
            WHERE CARGO_COMPENSACION > '20240101';
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - STAGE_RECIBOS cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'SALESTRANSACTION' THEN 
    --SALESTRANSACTION
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en SALESTRANSACTION', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.SALESTRANSACTION 
        SELECT 
            'G204',
            99999999 , --STAGESALESTRANSACTIONSEQ,
            FILE_NAME_OUT,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            NULL,
            NULL,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            '0', --STAGEPROCESSFLAG,
            BUSINESSUNITNAME,
            NULL,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            NULL,
            NULL
        FROM EXT.inyc_lp_cs_SALESTRANSACTION;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - SALESTRANSACTION cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'SALESTRANSACTION_HIST' THEN 
    --SALESTRANSACTION_HIST
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en SALESTRANSACTION_HIST', v_log_count, v_idproceso, 'error');
        END;
        -----------------------------SALESTRANSACTION_HIST-----------------------------
        truncate table ext.SALESTRANSACTION_HIST ;
        insert into ext.SALESTRANSACTION_HIST 
        SELECT 
            IDPROCESO,
            'G204',
            99999999,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            null,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            0,
            BUSINESSUNITNAME,
            null,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            null,
            null
        FROM EXT.INYC_LP_CS_SALESTRANS_HIST  where year(COMPENSATIONDATE)=2019;
        commit;
        -----------------------------SALESTRANSACTION_HIST-----------------------------
        insert into ext.SALESTRANSACTION_HIST 
        SELECT 
            IDPROCESO,
            'G204',
            99999999,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            null,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            0,
            BUSINESSUNITNAME,
            null,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            null,
            null
        FROM EXT.INYC_LP_CS_SALESTRANS_HIST  where year(COMPENSATIONDATE)=2020;
        commit;
        -----------------------------SALESTRANSACTION_HIST-----------------------------
        insert into ext.SALESTRANSACTION_HIST 
        SELECT 
            IDPROCESO,
            'G204',
            99999999,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            null,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            0,
            BUSINESSUNITNAME,
            null,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            null,
            null
        FROM EXT.INYC_LP_CS_SALESTRANS_HIST  where year(COMPENSATIONDATE)=2021;
        commit;
        -----------------------------SALESTRANSACTION_HIST-----------------------------
        insert into ext.SALESTRANSACTION_HIST 
        SELECT 
            IDPROCESO,
            'G204',
            99999999,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            null,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            0,
            BUSINESSUNITNAME,
            null,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            null,
            null
        FROM EXT.INYC_LP_CS_SALESTRANS_HIST  where year(COMPENSATIONDATE)=2022;
        commit;
        -----------------------------SALESTRANSACTION_HIST-----------------------------
        insert into ext.SALESTRANSACTION_HIST 
        SELECT 
            IDPROCESO,
            'G204',
            99999999,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            null,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            0,
            BUSINESSUNITNAME,
            null,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            null,
            null
        FROM EXT.INYC_LP_CS_SALESTRANS_HIST  where year(COMPENSATIONDATE)=2023;
        commit;
        -----------------------------SALESTRANSACTION_HIST-----------------------------
        insert into ext.SALESTRANSACTION_HIST 
        SELECT 
            IDPROCESO,
            'G204',
            99999999,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            null,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            0,
            BUSINESSUNITNAME,
            null,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            null,
            null
        FROM EXT.INYC_LP_CS_SALESTRANS_HIST  where year(COMPENSATIONDATE)=2024;
        commit;
        -----------------------------SALESTRANSACTION_HIST-----------------------------
        insert into ext.SALESTRANSACTION_HIST 
        SELECT 
            IDPROCESO,
            'G204',
            99999999,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            null,
            ACCOUNTINGDATE,
            PRODUCTID,
            PRODUCTNAME,
            PRODUCTDESCRIPTION,
            VALUE,
            UNITTYPEFORVALUE,
            NUMBEROFUNITS,
            UNITVALUE,
            UNITTYPEFORUNITVALUE,
            COMPENSATIONDATE,
            PAYMENTTERMS,
            PONUMBER,
            CHANNEL,
            ALTERNATEORDERNUMBER,
            DATASOURCE,
            NATIVECURRENCY,
            NATIVECURRENCYAMOUNT,
            DISCOUNTPERCENT,
            DISCOUNTTYPE,
            BILLTOCUSTID,
            BILLTOCONTACT,
            BILLTOCOMPANY,
            BILLTOAREACODE,
            BILLTOPHONE,
            BILLTOFAX,
            BILLTOADDRESS1,
            BILLTOADDRESS2,
            BILLTOADDRESS3,
            BILLTOCITY,
            BILLTOSTATE,
            BILLTOCOUNTRY,
            BILLTOPOSTALCODE,
            BILLTOINDUSTRY,
            BILLTOGEOGRAPHY,
            SHIPTOCUSTID,
            SHIPTOCONTACT,
            SHIPTOCOMPANY,
            SHIPTOAREACODE,
            SHIPTOPHONE,
            SHIPTOFAX,
            SHIPTOADDRESS1,
            SHIPTOADDRESS2,
            SHIPTOADDRESS3,
            SHIPTOCITY,
            SHIPTOSTATE,
            SHIPTOCOUNTRY,
            SHIPTOPOSTALCODE,
            SHIPTOINDUSTRY,
            SHIPTOGEOGRAPHY,
            OTHERTOCUSTID,
            OTHERTOCONTACT,
            OTHERTOCOMPANY,
            OTHERTOAREACODE,
            OTHERTOPHONE,
            OTHERTOFAX,
            OTHERTOADDRESS1,
            OTHERTOADDRESS2,
            OTHERTOADDRESS3,
            OTHERTOCITY,
            OTHERTOSTATE,
            OTHERTOCOUNTRY,
            OTHERTOPOSTALCODE,
            OTHERTOINDUSTRY,
            OTHERTOGEOGRAPHY,
            REASONID,
            COMMENTS,
            STAGEPROCESSDATE,
            0,
            BUSINESSUNITNAME,
            null,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICATTRIBUTE17,
            GENERICATTRIBUTE18,
            GENERICATTRIBUTE19,
            GENERICATTRIBUTE20,
            GENERICATTRIBUTE21,
            GENERICATTRIBUTE22,
            GENERICATTRIBUTE23,
            GENERICATTRIBUTE24,
            GENERICATTRIBUTE25,
            GENERICATTRIBUTE26,
            GENERICATTRIBUTE27,
            GENERICATTRIBUTE28,
            GENERICATTRIBUTE29,
            GENERICATTRIBUTE30,
            GENERICATTRIBUTE31,
            GENERICATTRIBUTE32,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6,
            STAGEERRORCODE,
            null,
            null
        FROM EXT.INYC_LP_CS_SALESTRANS_HIST  where year(COMPENSATIONDATE)=2025;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - SALESTRANSACTION_HIST cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_CARTERA_DDEE_NOMEXT_FILE' THEN 
    --TEMP_CARTERA_DDEE_NOMEXT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_CARTERA_DDEE_NOMEXT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_CARTERA_DDEE_NOMEXT_FILE SELECT * FROM 	EXT.INYC_CARTERA_LP_DET_NOMEXT;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_CARTERA_DDEE_NOMEXT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_COMEXT_FILE' THEN 
    --TEMP_COMEXT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_COMEXT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_COMEXT_FILE SELECT * FROM 	EXT.INYC_COMEXT_TEMPORAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_COMEXT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_COMEXT_TIPOS_FICHEROS_FILE' THEN 
    --TEMP_COMEXT_TIPOS_FICHEROS_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_COMEXT_TIPOS_FICHEROS_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_COMEXT_TIPOS_FICHEROS_FILE SELECT * FROM 	EXT.INYC_COMEXT_TIPOSFICHEROS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_COMEXT_TIPOS_FICHEROS_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_COMEXT_TXN_FILE' THEN 
    --TEMP_COMEXT_TXN_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_COMEXT_TXN_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_COMEXT_TXN_FILE SELECT * FROM 	EXT.INYC_COMEXT_TXN_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_COMEXT_TXN_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_CUNEXT_FILE' THEN 
    --TEMP_CUNEXT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_CUNEXT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_CUNEXT_FILE SELECT * FROM 	EXT.INYC_CUNEXT_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_CUNEXT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_LIQEXT_CAB_DEPOSITOS_FILE' THEN 
    --TEMP_LIQEXT_CAB_DEPOSITOS_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_CAB_DEPOSITOS_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_CAB_DEPOSITOS_FILE SELECT * FROM 	EXT.INYC_LIQEXT_CAB_DEPOSITOS_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_CAB_DEPOSITOS_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;
    
    ELSEIF nombretabla = 'TEMP_LIQEXT_CAB_CREDIMED_FILE' THEN 
    --TEMP_LIQEXT_CAB_CREDIMED_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_CAB_CREDIMED_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_CAB_CREDIMED_FILE SELECT * FROM 	EXT.INYC_LIQEXT_CAB_CREDIMED_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_CAB_CREDIMED_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_LIQEXT_CABECERA_FILE' THEN 
    --TEMP_LIQEXT_CABECERA_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_CABECERA_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_CABECERA_FILE SELECT * FROM 	EXT.INYC_LIQEXT_CABECERA_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_CABECERA_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_LIQEXT_COMMISSION_FILE' THEN 
    --TEMP_LIQEXT_COMMISSION_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_COMMISSION_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_COMMISSION_FILE SELECT * FROM 	EXT.INYC_LIQEXT_COMMISSION;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_COMMISSION_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_LIQEXT_CREDIT_FILE' THEN 
    --TEMP_LIQEXT_CREDIT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_CREDIT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_CREDIT_FILE SELECT * FROM 	EXT.INYC_LIQEXT_CREDIT_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_CREDIT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_LIQEXT_DET_PADIMENSION_FILE' THEN 
    --TEMP_LIQEXT_DET_PADIMENSION_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_DET_PADIMENSION_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_DET_PADIMENSION_FILE SELECT * FROM 	EXT.INYC_LIQEXT_DET_PADIMENSION;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_DET_PADIMENSION_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_LIQEXT_IMP_COMISION_FILE' THEN 
    --TEMP_LIQEXT_IMP_COMISION_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_IMP_COMISION_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_IMP_COMISION_FILE SELECT * FROM 	EXT.INYC_LIQEXT_IMP_COMISION;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_IMP_COMISION_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_LIQEXT_TXN_FILE' THEN 
    --TEMP_LIQEXT_TXN_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_TXN_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_LIQEXT_TXN_FILE SELECT * FROM 	EXT.INYC_LIQEXT_TXN_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_TXN_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_REPEXT_CREDITOS_FILE' THEN 
    --TEMP_REPEXT_CREDITOS_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_REPEXT_CREDITOS_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_REPEXT_CREDITOS_FILE SELECT * FROM 	EXT.INYC_REPEXT_CREDITOS_MES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_REPEXT_CREDITOS_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_REPEXT_FILE' THEN 
    --TEMP_REPEXT_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_REPEXT_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_REPEXT_FILE SELECT * FROM 	EXT.INYC_REPEXT_TEMPORAL;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_REPEXT_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_REPEXT_PAGOS_REPARTO_FILE' THEN 
    --TEMP_REPEXT_PAGOS_REPARTO_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_REPEXT_PAGOS_REPARTO_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_REPEXT_PAGOS_REPARTO_FILE SELECT * FROM 	EXT.INYC_REPEXT_PAGOS_REPARTO_MES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_REPEXT_PAGOS_REPARTO_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_REPEXT_PERCEPCIONES_FILE' THEN 
    --TEMP_REPEXT_PERCEPCIONES_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_REPEXT_PERCEPCIONES_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_REPEXT_PERCEPCIONES_FILE SELECT * FROM 	EXT.INYC_REPEXT_PERCEPCIONES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_REPEXT_PERCEPCIONES_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_REPEXT_TXN_FILE' THEN 
    --TEMP_REPEXT_TXN_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_REPEXT_TXN_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_REPEXT_TXN_FILE SELECT * FROM 	EXT.INYC_REPEXT_TXN_MES;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_REPEXT_TXN_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TEMP_TXN_MES_REP' THEN 
    --TEMP_TXN_MES_REP
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_TXN_MES_REP', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.TEMP_TXN_MES_REP SELECT * FROM 	EXT.INYC_TXN_MES_TEMP;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_TXN_MES_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TRANSACTIONASSIGN' THEN 
    --TRANSACTIONASSIGN
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TRANSACTIONASSIGN', v_log_count, v_idproceso, 'error');
        END;
        UPDATE EXT.INYC_LP_CS_TRANSACTIONASSIGN
            SET sublinenumber = sublinenumber / 100000
            WHERE sublinenumber > 9223372036854775807
            and RIGHT(TO_VARCHAR(sublinenumber), 5) = '00000';
        UPDATE EXT.INYC_LP_CS_TRANSACTIONASSIGN
            SET sublinenumber = sublinenumber / 1000
            WHERE sublinenumber > 9223372036854775807
            and RIGHT(TO_VARCHAR(sublinenumber), 5) <> '00000';
        UPDATE EXT.INYC_LP_CS_TRANSACTIONASSIGN
            SET sublinenumber = sublinenumber / 10
            WHERE sublinenumber > 9223372036854775807
            and RIGHT(TO_VARCHAR(sublinenumber), 1) = '0';
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        SELECT --2019
            'G204',
            99999999, --STAGESALESTRANSACTIONSEQ,
            0 , --SETNUMBER,
            FILE_NAME_OUT, --BATCHNAME,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,--SALESTRANSACTIONSEQ,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTIONASSIGN  where year(COMPENSATIONDATE)=2019;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.TRANSACTIONASSIGN
        SELECT  --2020
            'G204',
            99999999, --STAGESALESTRANSACTIONSEQ,
            0 , --SETNUMBER,
            FILE_NAME_OUT, --BATCHNAME,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,--SALESTRANSACTIONSEQ,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTIONASSIGN  where year(COMPENSATIONDATE)=2020;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.TRANSACTIONASSIGN
        SELECT  --2021
            'G204',
            99999999, --STAGESALESTRANSACTIONSEQ,
            0 , --SETNUMBER,
            FILE_NAME_OUT, --BATCHNAME,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,--SALESTRANSACTIONSEQ,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTIONASSIGN  where year(COMPENSATIONDATE)=2021;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.TRANSACTIONASSIGN
        SELECT  --2022
            'G204',
            99999999, --STAGESALESTRANSACTIONSEQ,
            0 , --SETNUMBER,
            FILE_NAME_OUT, --BATCHNAME,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,--SALESTRANSACTIONSEQ,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTIONASSIGN  where year(COMPENSATIONDATE)=2022;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.TRANSACTIONASSIGN
        SELECT  --2023
            'G204',
            99999999, --STAGESALESTRANSACTIONSEQ,
            0 , --SETNUMBER,
            FILE_NAME_OUT, --BATCHNAME,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,--SALESTRANSACTIONSEQ,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTIONASSIGN  where year(COMPENSATIONDATE)=2023;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.TRANSACTIONASSIGN
        SELECT  --2024
            'G204',
            99999999, --STAGESALESTRANSACTIONSEQ,
            0 , --SETNUMBER,
            FILE_NAME_OUT, --BATCHNAME,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,--SALESTRANSACTIONSEQ,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTIONASSIGN  where year(COMPENSATIONDATE)=2024;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        INSERT INTO EXT.TRANSACTIONASSIGN
        SELECT  --2025
            'G204',
            99999999, --STAGESALESTRANSACTIONSEQ,
            0 , --SETNUMBER,
            FILE_NAME_OUT, --BATCHNAME,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,--SALESTRANSACTIONSEQ,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTIONASSIGN  where year(COMPENSATIONDATE)=2025;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'TRANSACTIONASSIGN_HIST' THEN 
    --TRANSACTIONASSIGN_HIST
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en TEMP_LIQEXT_COMMISSION_FILE', v_log_count, v_idproceso, 'error');
        END;
        insert into ext.TRANSACTIONASSIGN_HIST
        SELECT 
            1,
            'G204',
            99999999,
            0,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTION_HIST  where year(COMPENSATIONDATE)=2019;
        commit;
        -----------------------------TRANSACTIONASSIGN_HIST-----------------------------
        insert into ext.TRANSACTIONASSIGN_HIST
        SELECT 
            1,
            'G204',
            99999999,
            0,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTION_HIST  where year(COMPENSATIONDATE)=2020;
        commit;
        -----------------------------TRANSACTIONASSIGN_HIST-----------------------------
        insert into ext.TRANSACTIONASSIGN_HIST
        SELECT 
            1,
            'G204',
            99999999,
            0,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTION_HIST  where year(COMPENSATIONDATE)=2021;
        commit;
        -----------------------------TRANSACTIONASSIGN_HIST-----------------------------
        insert into ext.TRANSACTIONASSIGN_HIST
        SELECT 
            1,
            'G204',
            99999999,
            0,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTION_HIST  where year(COMPENSATIONDATE)=2022;
        commit;
        -----------------------------TRANSACTIONASSIGN_HIST-----------------------------
        insert into ext.TRANSACTIONASSIGN_HIST
        SELECT 
            1,
            'G204',
            99999999,
            0,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTION_HIST  where year(COMPENSATIONDATE)=2023;
        commit;
        -----------------------------TRANSACTIONASSIGN_HIST-----------------------------
        insert into ext.TRANSACTIONASSIGN_HIST
        SELECT 
            1,
            'G204',
            99999999,
            0,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTION_HIST  where year(COMPENSATIONDATE)=2024;
        commit;
        -----------------------------TRANSACTIONASSIGN_HIST-----------------------------
        insert into ext.TRANSACTIONASSIGN_HIST
        SELECT 
            1,
            'G204',
            99999999,
            0,
            file_name_out,
            FILE_IN_RECIBOS,
            ORDERID,
            LINENUMBER,
            SUBLINENUMBER,
            EVENTTYPEID,
            null,
            PAYEEID,
            PAYEETYPE,
            POSITIONNAME,
            TITLENAME,
            GENERICATTRIBUTE1,
            GENERICATTRIBUTE2,
            GENERICATTRIBUTE3,
            GENERICATTRIBUTE4,
            GENERICATTRIBUTE5,
            GENERICATTRIBUTE6,
            GENERICATTRIBUTE7,
            GENERICATTRIBUTE8,
            GENERICATTRIBUTE9,
            GENERICATTRIBUTE10,
            GENERICATTRIBUTE11,
            GENERICATTRIBUTE12,
            GENERICATTRIBUTE13,
            GENERICATTRIBUTE14,
            GENERICATTRIBUTE15,
            GENERICATTRIBUTE16,
            GENERICNUMBER1,
            UNITTYPEFORGENERICNUMBER1,
            GENERICNUMBER2,
            UNITTYPEFORGENERICNUMBER2,
            GENERICNUMBER3,
            UNITTYPEFORGENERICNUMBER3,
            GENERICNUMBER4,
            UNITTYPEFORGENERICNUMBER4,
            GENERICNUMBER5,
            UNITTYPEFORGENERICNUMBER5,
            GENERICNUMBER6,
            UNITTYPEFORGENERICNUMBER6,
            GENERICDATE1,
            GENERICDATE2,
            GENERICDATE3,
            GENERICDATE4,
            GENERICDATE5,
            GENERICDATE6,
            GENERICBOOLEAN1,
            GENERICBOOLEAN2,
            GENERICBOOLEAN3,
            GENERICBOOLEAN4,
            GENERICBOOLEAN5,
            GENERICBOOLEAN6
        FROM EXT.INYC_LP_CS_TRANSACTION_HIST  where year(COMPENSATIONDATE)=2025;
        commit;
        CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - TEMP_LIQEXT_COMMISSION_FILE cargada correctamente', v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'WF_REPEXT_COEFICIENTES_REPARTO_FILE' THEN 
    --WF_REPEXT_COEFICIENTES_REPARTO_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_REPEXT_COEFICIENTES_REPARTO_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_REPEXT_COEFICIENTES_REPARTO_FILE SELECT * FROM 	EXT.INYC_COEFICIENTES_REPARTO;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_REPEXT_COEFICIENTES_REPARTO_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'WF_REPEXT_REPARTO_FILE' THEN 
    --WF_REPEXT_REPARTO_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_REPEXT_REPARTO_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_REPEXT_REPARTO_FILE (FECHA_BAJA, FECHA_ALTA, USUARIO, FECHA_FIN, FECHA_INICIO, TIPO_BASE_TRAMO2, PORCENTAJE_TRAMO2, TIPO_BASE_TRAMO1, PORCENTAJE_TRAMO1, NOMBRE_PERIODO, DESC_TIPO_REPARTO, TIPO_REPARTO, CIA_CODIGO, ID_REPARTO)
            SELECT
                FECHA_BAJA,
                FECHA_ALTA,
                USUARIO,
                FECHA_FIN,
                FECHA_INICIO,
                TIPO_BASE_TRAMO2,
                PORCENTAJE_TRAMO2,
                TIPO_BASE_TRAMO1,
                PORCENTAJE_TRAMO1,
                NOMBRE_PERIODO,
                DESC_TIPO_REPARTO,
                TIPO_REPARTO,
                CIA_CODIGO,
                ID_REPARTO 
            FROM EXT.INYC_REPARTO;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_REPEXT_REPARTO_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;
    
    ELSEIF nombretabla = 'WF_REPEXT_TIPO_REPARTO_FILE' THEN
    --WF_REPEXT_TIPO_REPARTO_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_REPEXT_TIPO_REPARTO_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_REPEXT_TIPO_REPARTO_FILE(FECHA_BAJA, FECHA_ALTA, USUARIO, FECHA_FIN, FECHA_INICIO, TIPO_REPARTO, TIPO_AGENTE, TIPO_PAGO, CIA_CODIGO, ID_TIPO_REPARTO)
            SELECT FECHA_BAJA, FECHA_ALTA, USUARIO, FECHA_FIN, FECHA_INICIO, TIPO_REPARTO, TIPO_AGENTE, TIPO_PAGO, CIA_CODIGO, ID_TIPO_REPARTO
            FROM EXT.INYC_TIPO_REPARTO;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_REPEXT_TIPO_REPARTO_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'WF_PAGEXT_DAC_RETEN_FILE' THEN
    --WF_PAGEXT_DAC_RETEN_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_PAGEXT_DAC_RETEN_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_PAGEXT_DAC_RETEN_FILE SELECT * FROM 	EXT.INYC_DAC_RETEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_PAGEXT_DAC_RETEN_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'WF_REPEXT_PERIODO_CALCULO_FILE' THEN
    --WF_REPEXT_PERIODO_CALCULO_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_REPEXT_PERIODO_CALCULO_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_REPEXT_PERIODO_CALCULO_FILE(ID_PERIODO_CALCULO, NOMBRE_PERIODO, DESCRIPCION, FECHA_ALTA, FECHA_BAJA, EXPLICACION)
            SELECT ID_PERIODO_CALCULO, NOMBRE_PERIODO, DESCRIPCION, FECHA_ALTA, FECHA_BAJA, EXPLICACION FROM EXT.INYC_PERIODO_CALCULO;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_REPEXT_PERIODO_CALCULO_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'WF_POSICIONES_BAJAS' THEN
    --WF_POSICIONES_BAJAS
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_POSICIONES_BAJAS', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_POSICIONES_BAJAS
            SELECT * FROM EXT.INYC_POSICIONES_BAJAS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_POSICIONES_BAJAS cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'WF_PROVINCIAS_MUNICIPIOS' THEN
    --WF_PROVINCIAS_MUNICIPIOS
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_PROVINCIAS_MUNICIPIOS', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_PROVINCIAS_MUNICIPIOS (NOM_MUNICIPI, COD_MUNIC_PK, NOM_PROVINCI, COD_PROVI_PK, COD_PAIS_PK)
            SELECT 
                NOM_MUNICIPI, 
                COD_MUNIC_PK, 
                NOM_PROVINCI, 
                COD_PROVI_PK, 
                COD_PAIS_PK
            FROM EXT.INYC_PROVINCIAS_MUNICIPIOS;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_PROVINCIAS_MUNICIPIOS cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'WF_TIPO_VIA' THEN
    --WF_TIPO_VIA
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_TIPO_VIA', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.WF_TIPO_VIA (NOM_TIPOVIA, COD_TIVIA_PK)
            SELECT
                NOM_TIPOVIA,
                COD_TIVIA_PK
            FROM EXT.INYC_TIPO_VIA;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_TIPO_VIA cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;
    
    ELSEIF nombretabla = 'FINAL_EXTRACTPAGOS_ONLINE_FILE' THEN
    --FINAL_EXTRACTPAGOS_ONLINE_FILE
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en FINAL_EXTRACTPAGOS_ONLINE_FILE', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE (ORIGEN_CODIGO, CIA_CODIGO, PAG_OFICINA, PER_CIF_NIF, DC_CODPER, PAG_AGENTE, TIPPER_CODIGO, CONCEP_CODIGO, FPG_CODIGO, PAG_REFERENCIA_ORIGEN, PAG_FECHA_FACTURA, PAG_FECHA_LIQUIDACION, PAG_TEXTO_PAGO, PAG_BANCO_DESTINO, PAG_CARGO_O_ABONO, PAG_IMPORTE, PAG_MONEDA, ACCION, AGENTE_RETA, DC_PE_NOMBRE, DC_PE_DOMICILIO, DC_PE_PROVINCIA, DC_PE_POBLACION, DC_PE_COD_POSTAL, COD_DATO1, DC_IMPORTE1, COD_DATO2, DC_IMPORTE2, COD_DATO3, DC_IMPORTE3, COD_DATO4, DC_IMPORTE4, COD_DATO5, SECUENCIAL, DC_IMPORTE5, COD_DATO9, DC_IMPORTE9, COD_DATO10, DC_IMPORTE10, COD_DATO11, DC_IMPORTE11, COD_DATO13, DC_IMPORTE13, COD_DATO16, DC_IMPORTE16, COD_DATO17, DC_IMPORTE17, COD_DATO30, DC_IMPORTE30, COD_DATO31, DC_IMPORTE31, COD_DATO32, DC_IMPORTE32, IBAN, ENVIO_SII, SERCO_CANARIAS, ESTADO, FECHA_ESTADO, USUARIO_DAC, PERIODSEQ, PAG_COD_UNICO, PAG_CLASIF_AGENTE)
            SELECT
                ORIGEN_CODIGO,
                CIA_CODIGO,
                PAG_OFICINA,
                PER_CIF_NIF,
                DC_CODPER,
                PAG_AGENTE,
                TIPPER_CODIGO,
                CONCEP_CODIGO,
                FPG_CODIGO,
                PAG_REFERENCIA_ORIGEN,
                PAG_FECHA_FACTURA,
                PAG_FECHA_LIQUIDACION,
                PAG_TEXTO_PAGO,
                PAG_BANCO_DESTINO,
                PAG_CARGO_O_ABONO,
                PAG_IMPORTE,
                PAG_MONEDA,
                ACCION,
                AGENTE_RETA,
                DC_PE_NOMBRE,
                DC_PE_DOMICILIO,
                DC_PE_PROVINCIA,
                DC_PE_POBLACION,
                DC_PE_COD_POSTAL,
                COD_DATO1,
                DC_IMPORTE1,
                COD_DATO2,
                DC_IMPORTE2,
                COD_DATO3,
                DC_IMPORTE3,
                COD_DATO4,
                DC_IMPORTE4,
                COD_DATO5,
                SECUENCIAL,
                DC_IMPORTE5,
                COD_DATO9,
                DC_IMPORTE9,
                COD_DATO10,
                DC_IMPORTE10,
                COD_DATO11,
                DC_IMPORTE11,
                COD_DATO13,
                DC_IMPORTE13,
                COD_DATO16,
                DC_IMPORTE16,
                COD_DATO17,
                DC_IMPORTE17,
                COD_DATO30,
                DC_IMPORTE30,
                COD_DATO31,
                DC_IMPORTE31,
                COD_DATO32,
                DC_IMPORTE32,
                IBAN,
                ENVIO_SII,
                SERCO_CANARIAS,
                ESTADO,
                FECHA_ESTADO,
                USUARIO_DAC,
                PERIODSEQ,
                PAG_COD_UNICO,
                PAG_CLASIF_AGENTE
            FROM EXT.INYC_EXTRACTPAGOS_ONLINE;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - FINAL_EXTRACTPAGOS_ONLINE_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
    END;

    ELSEIF nombretabla = 'OUT_RPP_DETALLE_REP' THEN 
        --OUT_RPP_DETALLE_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_RPP_DETALLE_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_RPP_DETALLE_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,NAME,VALUE,C_GN1,ST_GA1,PRODUCTID,ACCOUNTINGDATE,ST_GN1,ST_GN2,ST_GN3,ST_GD3,EVENTO,TIPO_CREDITO,PRODUCTO,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,SALESTRANSACTIONSEQ,NIF)
                SELECT
                	PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            NAME,
    	            VALUE,
    	            C_GN1,
    	            ST_GA1,
    	            PRODUCTID,
    	            ACCOUNTINGDATE,
    	            ST_GN1,
    	            ST_GN2,
    	            ST_GN3,
    	            ST_GD3,
    	            EVENTO,
    	            TIPO_CREDITO,
    	            PRODUCTO,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            SALESTRANSACTIONSEQ,
    	            NIF
                FROM EXT.INYC_RPP_DETALLE;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_RPP_DETALLE_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_BAL_RPP_DETALLE_REP' THEN 
        --OUT_BAL_RPP_DETALLE_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_RPP_DETALLE_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_BAL_RPP_DETALLE_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,NAME,VALUE,C_GN1,ST_GA1,PRODUCTID,ACCOUNTINGDATE,ST_GN1,ST_GN2,ST_GN3,ST_GD3,EVENTO,TIPO_CREDITO,PRODUCTO,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,SALESTRANSACTIONSEQ,NIF)
                SELECT
                    PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            NAME,
    	            VALUE,
    	            C_GN1,
    	            ST_GA1,
    	            PRODUCTID,
    	            ACCOUNTINGDATE,
    	            ST_GN1,
    	            ST_GN2,
    	            ST_GN3,
    	            ST_GD3,
    	            EVENTO,
    	            TIPO_CREDITO,
    	            PRODUCTO,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            SALESTRANSACTIONSEQ,
    	            NIF
                FROM EXT.INYC_BAL_RPP_DETALLE;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_RPP_DETALLE_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_LC_RPP_DETALLE_REP' THEN 
        --OUT_LC_RPP_DETALLE_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_RPP_DETALLE_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_LC_RPP_DETALLE_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,NAME,VALUE,C_GN1,ST_GA1,PRODUCTID,ACCOUNTINGDATE,ST_GN1,ST_GN2,ST_GN3,ST_GD3,EVENTO,TIPO_CREDITO,PRODUCTO,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,SALESTRANSACTIONSEQ,NIF)
                SELECT
                   	PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            NAME,
    	            VALUE,
    	            C_GN1,
    	            ST_GA1,
    	            PRODUCTID,
    	            ACCOUNTINGDATE,
    	            ST_GN1,
    	            ST_GN2,
    	            ST_GN3,
    	            ST_GD3,
    	            EVENTO,
    	            TIPO_CREDITO,
    	            PRODUCTO,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            SALESTRANSACTIONSEQ,
    	            NIF
                FROM EXT.INYC_LC_RPP_DETALLE;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_RPP_DETALLE_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_RPP_RESUMEN_REP' THEN 
        --OUT_RPP_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_RPP_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_RPP_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,QUARTER,YEAR,STARTDATE,N_MEDIDA,V_MEDIDA,M_GN1,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,POSITIONNAME,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,NIF)
                SELECT
                    PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            QUARTER,
    	            YEAR,
    	            STARTDATE,
    	            N_MEDIDA,
    	            V_MEDIDA,
    	            M_GN1,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            POSITIONNAME,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            NIF
                FROM EXT.INYC_RPP_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_RPP_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_BAL_RPP_RESUMEN_REP' THEN 
        --OUT_BAL_RPP_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_RPP_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_BAL_RPP_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,QUARTER,YEAR,STARTDATE,N_MEDIDA,V_MEDIDA,M_GN1,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,POSITIONNAME,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,NIF)
                SELECT
                	PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            QUARTER,
    	            YEAR,
    	            STARTDATE,
    	            N_MEDIDA,
    	            V_MEDIDA,
    	            M_GN1,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            POSITIONNAME,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            NIF
                FROM EXT.INYC_BAL_RPP_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_RPP_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_LC_RPP_RESUMEN_REP' THEN 
        --OUT_LC_RPP_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_RPP_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_LC_RPP_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,QUARTER,YEAR,STARTDATE,N_MEDIDA,V_MEDIDA,M_GN1,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,POSITIONNAME,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,NIF)
                SELECT
                    PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            QUARTER,
    	            YEAR,
    	            STARTDATE,
    	            N_MEDIDA,
    	            V_MEDIDA,
    	            M_GN1,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            POSITIONNAME,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            NIF
                FROM EXT.INYC_LC_RPP_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_RPP_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_RPI_RESUMEN_REP' THEN 
        --OUT_RPI_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_RPI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_RPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,QUARTER,YEAR,STARTDATE,N_MEDIDA,V_MEDIDA,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,POSITIONNAME,N_CREDITO,V_CREDITO,FIRSTNAME_AG,MIDDLENAME_AG,LASTNAME_AG,POSITIONNAME_AG,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,NIF,NIVEL_PTO_VENTA,COD_PTO_VENTA,PTO_VENTA,NIVEL_OFICINA,COD_OFICINA,OFICINA,NIVEL_SUCURSAL,COD_SUCURSAL,SUCURSAL,NIVEL_REGIONAL,COD_REGIONAL,REGIONAL,C_GN4)
                SELECT
                	PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            QUARTER,
    	            YEAR,
    	            STARTDATE,
    	            N_MEDIDA,
    	            V_MEDIDA,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            POSITIONNAME,
    	            N_CREDITO,
    	            V_CREDITO,
    	            FIRSTNAME_AG,
    	            MIDDLENAME_AG,
    	            LASTNAME_AG,
    	            POSITIONNAME_AG,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            NIF,
    	            NIVEL_PTO_VENTA,
    	            COD_PTO_VENTA,
    	            PTO_VENTA,
    	            NIVEL_OFICINA,
    	            COD_OFICINA,
    	            OFICINA,
    	            NIVEL_SUCURSAL,
    	            COD_SUCURSAL,
    	            SUCURSAL,
    	            NIVEL_REGIONAL,
    	            COD_REGIONAL,
    	            REGIONAL,
    	            C_GN4
                FROM EXT.INYC_RPI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_RPI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_BAL_RPI_RESUMEN_REP' THEN 
        --OUT_BAL_RPI_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_RPI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_BAL_RPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,QUARTER,YEAR,STARTDATE,N_MEDIDA,V_MEDIDA,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,POSITIONNAME,N_CREDITO,V_CREDITO,FIRSTNAME_AG,MIDDLENAME_AG,LASTNAME_AG,POSITIONNAME_AG,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,NIF,NIVEL_PTO_VENTA,COD_PTO_VENTA,PTO_VENTA,NIVEL_OFICINA,COD_OFICINA,OFICINA,NIVEL_SUCURSAL,COD_SUCURSAL,SUCURSAL,NIVEL_REGIONAL,COD_REGIONAL,REGIONAL,C_GN4)
                SELECT
                    PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            QUARTER,
    	            YEAR,
    	            STARTDATE,
    	            N_MEDIDA,
    	            V_MEDIDA,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            POSITIONNAME,
    	            N_CREDITO,
    	            V_CREDITO,
    	            FIRSTNAME_AG,
    	            MIDDLENAME_AG,
    	            LASTNAME_AG,
    	            POSITIONNAME_AG,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            NIF,
    	            NIVEL_PTO_VENTA,
    	            COD_PTO_VENTA,
    	            PTO_VENTA,
    	            NIVEL_OFICINA,
    	            COD_OFICINA,
    	            OFICINA,
    	            NIVEL_SUCURSAL,
    	            COD_SUCURSAL,
    	            SUCURSAL,
    	            NIVEL_REGIONAL,
    	            COD_REGIONAL,
    	            REGIONAL,
    	            C_GN4
                FROM EXT.INYC_BAL_RPI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_RPI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_LC_RPI_RESUMEN_REP' THEN 
        --OUT_LC_RPI_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_RPI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_LC_RPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,QUARTER,YEAR,STARTDATE,N_MEDIDA,V_MEDIDA,BOUSERID,FIRSTNAME,MIDDLENAME,LASTNAME,POSITIONNAME,N_CREDITO,V_CREDITO,FIRSTNAME_AG,MIDDLENAME_AG,LASTNAME_AG,POSITIONNAME_AG,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,NIF,NIVEL_PTO_VENTA,COD_PTO_VENTA,PTO_VENTA,NIVEL_OFICINA,COD_OFICINA,OFICINA,NIVEL_SUCURSAL,COD_SUCURSAL,SUCURSAL,NIVEL_REGIONAL,COD_REGIONAL,REGIONAL,C_GN4)
                SELECT
               	PARTICIPANTSEQ,
    	            POSITIONSEQ_PRIN,
    	            PERIODSEQ,
    	            PERIODO,
    	            QUARTER,
    	            YEAR,
    	            STARTDATE,
    	            N_MEDIDA,
    	            V_MEDIDA,
    	            BOUSERID,
    	            FIRSTNAME,
    	            MIDDLENAME,
    	            LASTNAME,
    	            POSITIONNAME,
    	            N_CREDITO,
    	            V_CREDITO,
    	            FIRSTNAME_AG,
    	            MIDDLENAME_AG,
    	            LASTNAME_AG,
    	            POSITIONNAME_AG,
    	            POS_PRIN,
    	            ID_TIPO_AGENTE,
    	            TIPO_AGENTE,
    	            NIF,
    	            NIVEL_PTO_VENTA,
    	            COD_PTO_VENTA,
    	            PTO_VENTA,
    	            NIVEL_OFICINA,
    	            COD_OFICINA,
    	            OFICINA,
    	            NIVEL_SUCURSAL,
    	            COD_SUCURSAL,
    	            SUCURSAL,
    	            NIVEL_REGIONAL,
    	            COD_REGIONAL,
    	            REGIONAL,
    	            C_GN4
                FROM EXT.INYC_LC_RPI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_RPI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
        
    ELSEIF nombretabla = 'OUT_PEPA_RESUMEN_REP' THEN 
        --OUT_PEPA_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_PEPA_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
                SELECT
                    PARTICIPANTSEQ,
                    POSITIONSEQ_PRIN,
                    PERIODSEQ,
                    PERIODO,
                    BOUSERID,
                    NIF,
                    NOMBRE,
                    POS_PRIN,
                    ID_TIPO_AGENTE,
                    TIPO_AGENTE,
                    CUADRO_RRGG,
                    CUADRO_RRTT,
                    PROMOCION,
                    SUPERRAPEL,
                    COD_OFICINA,
                    OFICINA,
                    COD_SUCURSAL,
                    SUCURSAL,
                    COD_REGIONAL,
                    REGIONAL,
                    COMISION,
                    IMPORTE,
                    IMPORTE_ACUMULADO,
                    N_MEDIDA,
                    V_MEDIDA,
                    EARNINGCODEID,
                    EARNINGGROUPID
                FROM 	EXT.INYC_PEPA_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_PEPA_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_BAL_PEPA_RESUMEN_REP' THEN 
        --OUT_BAL_PEPA_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_PEPA_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_BAL_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
                SELECT
                    PARTICIPANTSEQ,
                    POSITIONSEQ_PRIN,
                    PERIODSEQ,
                    PERIODO,
                    BOUSERID,
                    NIF,
                    NOMBRE,
                    POS_PRIN,
                    ID_TIPO_AGENTE,
                    TIPO_AGENTE,
                    CUADRO_RRGG,
                    CUADRO_RRTT,
                    PROMOCION,
                    SUPERRAPEL,
                    COD_OFICINA,
                    OFICINA,
                    COD_SUCURSAL,
                    SUCURSAL,
                    COD_REGIONAL,
                    REGIONAL,
                    COMISION,
                    IMPORTE,
                    IMPORTE_ACUMULADO,
                    N_MEDIDA,
                    V_MEDIDA,
                    EARNINGCODEID,
                    EARNINGGROUPID
                FROM EXT.INYC_BAL_PEPA_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_PEPA_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_LC_PEPA_RESUMEN_REP' THEN 
        --OUT_LC_PEPA_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_PEPA_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_LC_PEPA_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_RRGG,CUADRO_RRTT,PROMOCION,SUPERRAPEL,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
                SELECT
                    PARTICIPANTSEQ,
                    POSITIONSEQ_PRIN,
                    PERIODSEQ,
                    PERIODO,
                    BOUSERID,
                    NIF,
                    NOMBRE,
                    POS_PRIN,
                    ID_TIPO_AGENTE,
                    TIPO_AGENTE,
                    CUADRO_RRGG,
                    CUADRO_RRTT,
                    PROMOCION,
                    SUPERRAPEL,
                    COD_OFICINA,
                    OFICINA,
                    COD_SUCURSAL,
                    SUCURSAL,
                    COD_REGIONAL,
                    REGIONAL,
                    COMISION,
                    IMPORTE,
                    IMPORTE_ACUMULADO,
                    N_MEDIDA,
                    V_MEDIDA,
                    EARNINGCODEID,
                    EARNINGGROUPID
                FROM EXT.INYC_LC_PEPA_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_PEPA_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_PEPI_RESUMEN_REP' THEN 
        --OUT_PEPI_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_PEPI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
                SELECT
                PARTICIPANTSEQ,
                POSITIONSEQ_PRIN,
                PERIODSEQ,
                PERIODO,
                BOUSERID,
                NIF,
                NOMBRE,
                POS_PRIN,
                ID_TIPO_AGENTE,
                TIPO_AGENTE,
                CUADRO_INSP,
                COD_OFICINA,
                OFICINA,
                COD_SUCURSAL,
                SUCURSAL,
                COD_REGIONAL,
                REGIONAL,
                COMISION,
                IMPORTE,
                IMPORTE_ACUMULADO,
                N_MEDIDA,
                V_MEDIDA,
                EARNINGCODEID,
                EARNINGGROUPID  
                FROM EXT.INYC_PEPI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_PEPI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_BAL_PEPI_RESUMEN_REP' THEN 
        --OUT_BAL_PEPI_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_PEPI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_BAL_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
                SELECT
                    PARTICIPANTSEQ,
                    POSITIONSEQ_PRIN,
                    PERIODSEQ,
                    PERIODO,
                    BOUSERID,
                    NIF,
                    NOMBRE,
                    POS_PRIN,
                    ID_TIPO_AGENTE,
                    TIPO_AGENTE,
                    CUADRO_INSP,
                    COD_OFICINA,
                    OFICINA,
                    COD_SUCURSAL,
                    SUCURSAL,
                    COD_REGIONAL,
                    REGIONAL,
                    COMISION,
                    IMPORTE,
                    IMPORTE_ACUMULADO,
                    N_MEDIDA,
                    V_MEDIDA,
                    EARNINGCODEID,
                    EARNINGGROUPID
                FROM EXT.INYC_BAL_PEPI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
            COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_PEPI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_LC_PEPI_RESUMEN_REP' THEN 
        --OUT_LC_PEPI_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_PEPI_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_LC_PEPI_RESUMEN_REP(PARTICIPANTSEQ,POSITIONSEQ_PRIN,PERIODSEQ,PERIODO,BOUSERID,NIF,NOMBRE,POS_PRIN,ID_TIPO_AGENTE,TIPO_AGENTE,CUADRO_INSP,COD_OFICINA,OFICINA,COD_SUCURSAL,SUCURSAL,COD_REGIONAL,REGIONAL,COMISION,IMPORTE,IMPORTE_ACUMULADO,N_MEDIDA,V_MEDIDA,EARNINGCODEID,EARNINGGROUPID)
                SELECT
                    PARTICIPANTSEQ,
                    POSITIONSEQ_PRIN,
                    PERIODSEQ,
                    PERIODO,
                    BOUSERID,
                    NIF,
                    NOMBRE,
                    POS_PRIN,
                    ID_TIPO_AGENTE,
                    TIPO_AGENTE,
                    CUADRO_INSP,
                    COD_OFICINA,
                    OFICINA,
                    COD_SUCURSAL,
                    SUCURSAL,
                    COD_REGIONAL,
                    REGIONAL,
                    COMISION,
                    IMPORTE,
                    IMPORTE_ACUMULADO,
                    N_MEDIDA,
                    V_MEDIDA,
                    EARNINGCODEID,
                    EARNINGGROUPID
                FROM EXT.INYC_LC_PEPI_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_PEPI_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
        
    ELSEIF nombretabla = 'WF_REPEXT_BASE_REPARTO_FILE' THEN 
        --WF_REPEXT_BASE_REPARTO_FILE
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_REPEXT_BASE_REPARTO_FILE', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.WF_REPEXT_BASE_REPARTO_FILE
				SELECT ID_BASE_REPARTO,
					TIPO_BASE,
					DESCRIPCION,
					FECHA_ALTA,
					FECHA_BAJA,
					EXPLICACION
				FROM EXT.INYC_BASE_REPARTO;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_REPEXT_BASE_REPARTO_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'WF_REPEXT_PERIODO_CALCULO_FILE' THEN 
        --WF_REPEXT_PERIODO_CALCULO_FILE
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en WF_REPEXT_PERIODO_CALCULO_FILE', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.WF_REPEXT_PERIODO_CALCULO_FILE
				SELECT 
					ID_PERIODO_CALCULO,
					NOMBRE_PERIODO,
					DESCRIPCION,
					FECHA_ALTA,
					FECHA_BAJA,
					EXPLICACION
				FROM EXT.inyc_periodo_calculo;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - WF_REPEXT_PERIODO_CALCULO_FILE cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END; 
    
    ELSEIF nombretabla = 'OUT_RE_RESUMEN_REP' THEN 
        --OUT_RE_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_RE_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_RE_RESUMEN_REP (TIPO_AGENTE, ID_TIPO_AGENTE, POS_PRIN, POSITIONNAME_AG, LASTNAME_AG, MIDDLENAME_AG, FIRSTNAME_AG, V_CREDITO, N_CREDITO, POSITIONNAME, LASTNAME, MIDDLENAME, FIRSTNAME, BOUSERID, V_MEDIDA, N_MEDIDA, STARTDATE, YEAR, QUARTER, PERIODO, PERIODSEQ, POSITIONSEQ_PRIN, PARTICIPANTSEQ, VCORRECCION)
				SELECT TIPO_AGENTE, ID_TIPO_AGENTE, POS_PRIN, POSITIONNAME_AG, LASTNAME_AG, MIDDLENAME_AG, FIRSTNAME_AG, V_CREDITO, N_CREDITO, POSITIONNAME, LASTNAME, MIDDLENAME, FIRSTNAME, BOUSERID, V_MEDIDA, N_MEDIDA, STARTDATE, YEAR, QUARTER, PERIODO, PERIODSEQ, POSITIONSEQ_PRIN, PARTICIPANTSEQ, VCORRECCION
				FROM EXT.INYC_RE_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_RE_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_LC_RE_RESUMEN_REP' THEN 
        --OUT_LC_RE_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_LC_RE_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_LC_RE_RESUMEN_REP (TIPO_AGENTE, ID_TIPO_AGENTE, POS_PRIN, POSITIONNAME_AG, LASTNAME_AG, MIDDLENAME_AG, FIRSTNAME_AG, V_CREDITO, N_CREDITO, POSITIONNAME, LASTNAME, MIDDLENAME, FIRSTNAME, BOUSERID, V_MEDIDA, N_MEDIDA, STARTDATE, YEAR, QUARTER, PERIODO, PERIODSEQ, POSITIONSEQ_PRIN, PARTICIPANTSEQ, VCORRECCION)
				SELECT TIPO_AGENTE, ID_TIPO_AGENTE, POS_PRIN, POSITIONNAME_AG, LASTNAME_AG, MIDDLENAME_AG, FIRSTNAME_AG, V_CREDITO, N_CREDITO, POSITIONNAME, LASTNAME, MIDDLENAME, FIRSTNAME, BOUSERID, V_MEDIDA, N_MEDIDA, STARTDATE, YEAR, QUARTER, PERIODO, PERIODSEQ, POSITIONSEQ_PRIN, PARTICIPANTSEQ, VCORRECCION
				FROM EXT.INYC_LC_RE_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_LC_RE_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    ELSEIF nombretabla = 'OUT_BAL_RE_RESUMEN_REP' THEN 
        --OUT_BAL_RE_RESUMEN_REP
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - Error en OUT_BAL_RE_RESUMEN_REP', v_log_count, v_idproceso, 'error');
            END;
            INSERT INTO EXT.OUT_BAL_RE_RESUMEN_REP (TIPO_AGENTE, ID_TIPO_AGENTE, POS_PRIN, POSITIONNAME_AG, LASTNAME_AG, MIDDLENAME_AG, FIRSTNAME_AG, V_CREDITO, N_CREDITO, POSITIONNAME, LASTNAME, MIDDLENAME, FIRSTNAME, BOUSERID, V_MEDIDA, N_MEDIDA, STARTDATE, YEAR, QUARTER, PERIODO, PERIODSEQ, POSITIONSEQ_PRIN, PARTICIPANTSEQ, VCORRECCION)
				SELECT TIPO_AGENTE, ID_TIPO_AGENTE, POS_PRIN, POSITIONNAME_AG, LASTNAME_AG, MIDDLENAME_AG, FIRSTNAME_AG, V_CREDITO, N_CREDITO, POSITIONNAME, LASTNAME, MIDDLENAME, FIRSTNAME, BOUSERID, V_MEDIDA, N_MEDIDA, STARTDATE, YEAR, QUARTER, PERIODO, PERIODSEQ, POSITIONSEQ_PRIN, PARTICIPANTSEQ, VCORRECCION
				FROM EXT.INYC_BAL_RE_RESUMEN;
		v_num_rows := ::ROWCOUNT;
        COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES', 'Version: ' || v_version || ' - OUT_BAL_RE_RESUMEN_REP cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');
        END;
    
    END IF; 
    -- FINAL DEL IF DE SELECCIÓN DE TABLA 

END