CREATE PROCEDURE EXT.SP_MIGRATE_TABLES_BKP( IN i_file_name VARCHAR(120) )
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Tania Garces
    | Company: Inycom
    | Initial Version Date: 1-Septiembre-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Migraci�n de tablas de inyc_lp a tablas definitivas
    | -- cdl filetype outbound MIGRATETABLAS
	| -- cdl table EXT.OUT_MIGRATE_TABLES_FILE 
    |
	| Version: 0.1	itl 20250911	Initial Version.
	|
    -----------------------------------------------------------------------
*/

BEGIN
    DECLARE v_version NVARCHAR(20) = '0.1';
    DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
    DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_idproceso BIGINT := 0;
	DECLARE v_log_count INTEGER := 0;
    DECLARE nombretabla NVARCHAR(250);

    --- nombre de la tabla a SELECT tablename into nombretabla FROM ext.OUT_MIGRATETABLES_FILES ;
    nombretabla := REPLACE(i_file_name, 'MIGRATETABLESBKP_', '');
    nombretabla := REPLACE(nombretabla, '.txt', '');

    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - TABLA A PROCESAR = ' || nombretabla, v_log_count, v_idproceso, 'info');

    IF nombretabla = 'ASEGURADOS' THEN
        -- ASEGURADOS
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                ROLLBACK;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - Error en ASEGURADOS', v_log_count, v_idproceso, 'error');
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
            FROM EXT.ASEGURADOS_BKP;
            COMMIT;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - ASEGURADOS cargada correctamente', v_log_count, v_idproceso, 'info');
        END;




    ELSEIF nombretabla = 'GARANTIAS_ASEGURADO' THEN 
    --GARANTIAS_ASEGURADO
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - Error en GARANTIAS_ASEGURADO', v_log_count, v_idproceso, 'error');
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
        FROM EXT.GARANTIAS_ASEGURADO_BKP;
        COMMIT;
        CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - GARANTIAS_ASEGURADO cargada correctamente', v_log_count, v_idproceso, 'info');
    END;

   
    ELSEIF nombretabla = 'GARANTIAS_RECIBO' THEN 
    --GARANTIAS_RECIBO
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - Error en GARANTIAS_RECIBO', v_log_count, v_idproceso, 'error');
        END;
        INSERT INTO EXT.GARANTIAS_RECIBO
        select 
           ID_RECIBO,
			FILE_NAME,
			ESTADO,
			FECHA_MODIFICACION,
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
        FROM EXT.GARANTIAS_RECIBO_BKP;
        COMMIT;
        CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - GARANTIAS_RECIBO cargada correctamente', v_log_count, v_idproceso, 'info');
    END;

   

   

   

    ELSEIF nombretabla = 'POLIZAS' THEN 
    --POLIZAS
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - Error en POLIZAS', v_log_count, v_idproceso, 'error');
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
        FROM EXT.POLIZAS_BKP;
        COMMIT;
        CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - POLIZAS cargada correctamente', v_log_count, v_idproceso, 'info');
    END;

   

    ELSEIF nombretabla = 'RECIBOS' THEN 
    --RECIBOS
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - Error en RECIBOS', v_log_count, v_idproceso, 'error');
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
        FROM EXT.RECIBOS_BKP ;
        COMMIT;
        CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - RECIBOS cargada correctamente', v_log_count, v_idproceso, 'info');
    END;

   

    ELSEIF nombretabla = 'SALESTRANSACTION' THEN 
    --SALESTRANSACTION
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - Error en SALESTRANSACTION', v_log_count, v_idproceso, 'error');
        END;
         INSERT INTO EXT.SALESTRANSACTION
        SELECT 
            *
        FROM EXT.SALESTRANSACTION_BKP;
        COMMIT;
        CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - SALESTRANSACTION cargada correctamente', v_log_count, v_idproceso, 'info');
    END;

       

    

    ELSEIF nombretabla = 'TRANSACTIONASSIGN' THEN 
    --TRANSACTIONASSIGN
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - Error en TRANSACTIONASSIGN', v_log_count, v_idproceso, 'error');
        END;
      
       
        -----------------------------TRANSACTIONASSIGN-----------------------------
        INSERT INTO EXT.TRANSACTIONASSIGN
        SELECT  *
        FROM EXT.TRANSACTIONASSIGN_BKP ;
        COMMIT;
        CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, 'EXT.SP_MIGRATE_TABLES_BKP', 'Version: ' || v_version || ' - TRANSACTIONASSIGN cargada correctamente', v_log_count, v_idproceso, 'info');
    END;

   
    
    END IF; -- FINAL DEL IF DE SELECCI�N DE TABLA 

END
