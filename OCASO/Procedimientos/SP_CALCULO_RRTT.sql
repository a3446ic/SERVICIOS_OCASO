CREATE or replace PROCEDURE EXT.SP_CALCULO_RRTT (IN i_file_name varchar(120), IN i_id_proceso BIGINT, INOUT i_log_count INT)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Tania Garcés Villanueva
    | Company: Inycom
    | Initial Version Date: 12-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta desde el procedimineto de SP_CALCULO, para calcular el ramo de RRTT
    |
    |
    | Version: 0.1  TGV 20250312        Initial Version.
    | Version: 1.0	RMF 20250919		Incluimos PERMANENCIA 71, 65 en el calculo de la prima comisionable de suplementos
    | Version: 1.1	RMF 20250924		Eliminamos la condición de RH_MAYOR_ANIO para NO_REHABILITACIONES y metemos como condición de CUENTA_COMO_ALTA una consulta a la VW_MOTIVOS_ALTA
    | Version: 1.2  TGV 20260520        Por peticion de Comercial (JGF) se deben generar 72+ para todas las comisiones anticipadas por lo que quitamos los filtros de ASISA
    |
    -----------------------------------------------------------------------
*/


BEGIN

    USING SQLSCRIPT_STRING AS LIBRARY;
    
    DECLARE v_idproceso INTEGER;
    DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
    DECLARE v_version VARCHAR2(10) := '1.2';
    DECLARE v_num_rows INTEGER := 0;
    DECLARE v_log_count INTEGER := 0;
    DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
    DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
    DECLARE v_existen_extornos INTEGER := 0;
    DECLARE v_const_n VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_N;
    DECLARE v_const_s VARCHAR(1) :=  EXT.LIB_CONSTANTES:CONST_S;
    DECLARE v_const_s_1 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_S_1;
    DECLARE v_const_n_0 VARCHAR(1) := EXT.LIB_CONSTANTES:CONST_N_0;
    DECLARE v_existe_tabla INTEGER := 0;
    DECLARE v_const_ramo_rrtt VARCHAR(4) := EXT.LIB_CONSTANTES:CONST_RAMA_RRTT;

    
    --CONSTANTES DE ESTADO FICHERO
    DECLARE v_const_populate_status_ok      INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK; --2
    DECLARE v_const_calculo_status_ok       INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_OK; --6
    DECLARE v_const_calculo_status_error    INT := EXT.LIB_CONSTANTES:CONST_CALCULO_STATUS_ERROR;--7
    
    --CONSTANTES TIPO MOVIENTO
     DECLARE v_const_tipo_mov_altapoli VARCHAR2(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_ALTAPOLI;
     DECLARE v_const_tipo_mov_supinase VARCHAR2(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPINASE;
     DECLARE v_const_tipo_mov_rehabili VARCHAR2(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_REHABILI;
     DECLARE v_const_tipo_mov_suplefps VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPLEFPS;
     DECLARE v_const_tipo_mov_suplefpn VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPLEFPN;
     DECLARE v_const_tipo_mov_supgener VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPGENER;
     DECLARE v_const_tipo_mov_supdeaut VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPDEAUT;
     DECLARE v_const_tipo_mov_supdiase VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPDIASE;
     DECLARE v_const_tipo_mov_suptrasp VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPTRASP;
     DECLARE v_const_tipo_mov_supingar VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPINGAR;
     DECLARE v_const_tipo_mov_supdigar VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPDIGAR;
     DECLARE v_const_tipo_mov_supaucap VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPAUCAP;
     DECLARE v_const_tipo_mov_supdicap VARCHAR(8) := EXT.LIB_CONSTANTES:CONST_TIPO_MOV_SUPDICAP;
         
     --CONSTANTES ESTADO RECIBO
     DECLARE v_const_recibo_cobrado VARCHAR2(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_COBRADO;
     DECLARE v_const_recibo_pendiente VARCHAR(6) := EXT.LIB_CONSTANTES:CONST_RECIBO_PENDIENTE;
    DECLARE v_const_recibo_anulado VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBO_ANULADO;
     
     --CONSTANTES CODIGO_RECIBO
    DECLARE v_const_cod_recibo_anul_rrtt VARCHAR2(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_RRTT;
    DECLARE v_const_cod_recibo_ini VARCHAR2(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_INI;
     
    DECLARE v_const_tipo_rec_anul_k5 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_TIPO_REC_ANUL_K5;
     
    DECLARE v_const_cod_recibo_anul_serco VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_ANUL_SERCO;
    DECLARE v_const_cod_recibo_serco VARCHAR(13) := EXT.LIB_CONSTANTES:CONST_COD_RECIBO_SERCO;
     
    --CONSTANTES DE TIPOS RECIBOS
    DECLARE v_const_recibos_especificos_66 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_66;
    DECLARE v_const_recibos_especificos_65 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_65;
    DECLARE v_const_recibos_especificos_71 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_71;
    DECLARE v_const_recibos_especificos_55 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_55;
    DECLARE v_const_recibos_cartera_72 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_72;
    DECLARE v_const_recibos_cartera_81 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_CARTERA_81;
    DECLARE v_const_recibos_especificos_10 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_10;
    DECLARE v_const_recibos_especificos_20 VARCHAR(2) := EXT.LIB_CONSTANTES:CONST_RECIBOS_ESPECIFICOS_20;
     
     --CONSTANTES MOTIVO_ALTA
     DECLARE v_const_motivo_alta_rc  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_RC;
     DECLARE v_const_motivo_alta_ro  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_RO;    
     DECLARE v_const_motivo_alta_np  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_NP;   
     DECLARE v_const_motivo_alta_co  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_CO;   
     DECLARE v_const_motivo_alta_re  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_RE;   
     DECLARE v_const_motivo_alta_de  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_DE; 
     DECLARE v_const_motivo_alta_su  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_SU;  
     DECLARE v_const_motivo_alta_tp  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_TP;  
     DECLARE v_const_motivo_alta_ts  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_TS;  
     DECLARE v_const_motivo_alta_dt  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_DT;  
     DECLARE v_const_motivo_alta_ac  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_ALTA_AC;  
     
     --CONSTANTES MOTIVO_BAJA
     DECLARE v_const_motivo_baja_bb  VARCHAR(2)     := EXT.LIB_CONSTANTES:CONST_MOTIVO_BAJA_BB;  
     DECLARE v_const_motivo_baja_rh  VARCHAR(2)     := EXT.LIB_CONSTANTES:  CONST_MOTIVO_ALTA_RH;
     
     --CONSTANTES DE PRODCUTO
     DECLARE v_const_producto_21021 VARCHAR(5) := EXT.LIB_CONSTANTES:CONST_PRODUCTO_21021;
     DECLARE v_const_producto_21030 VARCHAR(5) := EXT.LIB_CONSTANTES:CONST_PRODUCTO_21030;
     
     --CONSTANTES OFICINA
     DECLARE v_const_oficina_seci VARCHAR(10) := EXT.LIB_CONSTANTES:CONST_OFICINA_SECI;
     DECLARE v_const_corte_ingles VARCHAR(10) := EXT.LIB_CONSTANTES:CONST_CORTE_INGLES;
     
     --CONSTANTES UNIDAD_POLIZA
    DECLARE v_const_unidad_poliza           NUMBER(15,2) := EXT.LIB_CONSTANTES:CONST_UNIDAD_POLIZA;
    DECLARE v_const_unidad_poliza_cruzada   NUMBER(15,2) := EXT.LIB_CONSTANTES:CONST_UNIDAD_POLIZA_CRUZADA;
    DECLARE v_const_unidad_poliza_corrector NUMBER(15,2) := EXT.LIB_CONSTANTES:CONST_UNIDAD_POLIZA_CORRECTOR;
    DECLARE v_const_unidad_poliza_jun_2020  NUMBER(15,2) := EXT.LIB_CONSTANTES:CONST_UNIDAD_POLIZA_JUN_2020;
    DECLARE v_const_unidad_poliza_fijo_0    NUMBER := EXT.LIB_CONSTANTES:CONST_UNIDAD_POLIZA_FIJO_0;
    DECLARE v_const_unidad_poliza_fijo_1    NUMBER := EXT.LIB_CONSTANTES:CONST_UNIDAD_POLIZA_FIJO_1;

    --CONSTANTES CAMAPANIA
    DECLARE v_const_campania_cruzada VARCHAR2(255) :=  EXT.LIB_CONSTANTES:CONST_CAMPANIA_CRUZADA;
    DECLARE v_const_campania_duathlon VARCHAR2(255) :=  EXT.LIB_CONSTANTES:CONST_CAMPANIA_DUATHLON;
    DECLARE v_const_campania_duathlon_n1 VARCHAR2(255) :=  EXT.LIB_CONSTANTES:CONST_CAMPANIA_DUATHLON_N1;
      
      
     DECLARE v_const_365_dias NUMBER(3) := EXT.LIB_CONSTANTES:CONST_365_DIAS;
     DECLARE v_const_max_edad NUMBER(2) := EXT.LIB_CONSTANTES:CONST_MAX_EDAD; --70
     DECLARE v_const_mayor_edad NUMBER(2) := EXT.LIB_CONSTANTES:CONST_MAYOR_EDAD; --18
     
     
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                                                                                                                || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                                                                                                                
            
            --v_hayError := 1;
            v_num_rows := 0;
        
            UPDATE EXT.IN_BATCH_CONTROL
            SET STATUS = v_const_calculo_status_error,
                END_DATE = CURRENT_TIMESTAMP
            WHERE FILE_NAME = i_file_name
                AND ID_PROCESO = i_id_proceso;
            commit; 
            RESIGNAL;
        
        END;
    
    
    BEGIN
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, i_log_count, i_id_proceso, 'info');
    
    --Se comprueban si existen extornos para el fichero, y asi llamar a un procedimiento separado para el calculo de extornos
    SELECT COUNT(*) INTO v_existen_extornos 
        FROM EXT.RECIBOS R INNER JOIN EXT.POLIZAS P  ON R.CODIGO_POLIZA = P.CODIGO_POLIZA
            WHERE R.FILE_NAME = i_file_name and R.ESTADO = v_const_populate_status_ok 
            AND P.MOTIVO_ALTA =v_const_motivo_baja_bb AND P.FECHA_BAJA IS NOT NULL AND P.MOTIVO_BAJA IS NOT NULL;
            
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se comprueba la cantidad de extornos:  ' || v_existen_extornos || ' filas', i_log_count, i_id_proceso, 'debug');
    
    ------------------------------EXTORNOS------------------------------
    --ITL 29042025 desde calculo rrtt no se debería llamar a extornos rrgg rrpp
    -- IF v_existen_extornos > 0 THEN
        -- CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Se llama al procedimiento SP_CALCULO_EXTORNOS_RRTT', i_log_count, i_id_proceso, 'debug');
        -- CALL EXT.SP_CALCULO_EXTORNOS_RRGG_RRPP(i_file_name,i_id_proceso, v_log_count);
    -- END IF;
    ------------------------------EXTORNOS------------------------------
    TBL_GEN_CODIGOS_AGENTE = SELECT * FROM EXT.VW_CODIGOS_DE_AGENTE VW
                            WHERE 1=1
                                AND VW.CODIGO_OCASO <> '0' 
                                AND VW.CODIGO_OCASO <> '000000000' 
                                AND VW.CODIGO_OCASO <> '0000000000'
                            ;
    
    
    TBL_RECIBOS = SELECT R.*
        FROM EXT.RECIBOS R INNER JOIN EXT.POLIZAS P  ON R.CODIGO_POLIZA = P.CODIGO_POLIZA
            WHERE R.FILE_NAME = i_file_name and R.ESTADO = v_const_populate_status_ok 
            AND NOT (P.MOTIVO_ALTA =v_const_motivo_baja_bb AND P.FECHA_BAJA IS NOT NULL AND P.MOTIVO_BAJA IS NOT NULL)
            AND R.CODIGO_RECIBO NOT LIKE '%_A';
            
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS sin extornos: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    --Se calcula el numero se asegurdos para las permanencias 71, 66 y 65
    TBL_RECIBOS_71_66_65 =
        SELECT R.* FROM RECIBOS R 
        WHERE R.FILE_NAME = i_file_name and R.ESTADO = v_const_populate_status_ok 
        AND R.PERMANENCIA IN ( v_const_recibos_especificos_66,v_const_recibos_especificos_65,v_const_recibos_especificos_71)
        AND R.CODIGO_RECIBO NOT LIKE '%_A';
        
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_71_66_65);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_71_66_65: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

	TBL_GARANTIAS_RECIBO_NUM_ORDEN_MOVIMIENTO = 
		SELECT GR.* FROM EXT.GARANTIAS_RECIBO GR 
			WHERE GR.FILE_NAME = i_file_name 
			AND GR.ESTADO = v_const_populate_status_ok
			;
			
	v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO_NUM_ORDEN_MOVIMIENTO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_RECIBO_NUM_ORDEN_MOVIMIENTO: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en EXT.GARANTIAS_ASEGURADO para TBL_GARANTIAS_RECIBO_NUM_ORDEN_MOVIMIENTO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de RECIBOS con estado erróneo
        UPDATE EXT.GARANTIAS_ASEGURADO ga
        SET ESTADO = v_const_calculo_status_error,
            FECHA_MODIFICACION = CURRENT_TIMESTAMP
        FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_GARANTIAS_RECIBO_NUM_ORDEN_MOVIMIENTO src 
        WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
            AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
	     UPDATE EXT.GARANTIAS_ASEGURADO GA 
	        	SET GA.NUM_ORDEN_MOVIMIENTO = TBL.NUM_ORDEN_MOVIMIENTO,
	        		GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP
	        		FROM EXT.GARANTIAS_ASEGURADO GA , :TBL_GARANTIAS_RECIBO_NUM_ORDEN_MOVIMIENTO TBL
	        		WHERE  GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	                AND GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	                AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE;
	        
		v_num_rows := ::rowcount;
	    CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.GARANTIAS_ASEGURADO para TBL_GARANTIAS_RECIBO_NUM_ORDEN_MOVIMIENTO. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
	END;

    --OBTENEMOS LOS ASEGURADOS
    TBL_ASEGURADOS = 
        SELECT DISTINCT T_ASEGURADOS.*,T_GAR_ASE.SUBTIPO_MOVIMIENTO, REC.CODIGO_RECIBO AS REC_CODIGO_RECIBO, REC.ESTADO_RECIBO AS REC_ESTADO_RECIBO , REC.CODIGO_SUPLEMENTO AS REC_CODIGO_SUPLEMENTO, 
        T_GAR_ASE.PRODUCTO_CONTABLE ,REC.OFICINA_GESTORA, REC.PERMANENCIA AS REC_PERMANENCIA , REC.PORCENTAJE_DESCUENTO_SOBRE_PC AS REC_PORCENTAJE_DESCUENTO_SOBRE_PC
        , REC.FECHA_COMPENSACION
        FROM ASEGURADOS T_ASEGURADOS,GARANTIAS_ASEGURADO T_GAR_ASE, :TBL_RECIBOS_71_66_65 REC
            WHERE T_GAR_ASE.CODIGO_POLIZA = REC.CODIGO_POLIZA
            AND T_GAR_ASE.CODIGO_RECIBO = REC.CODIGO_RECIBO
            --AND T_GAR_ASE.CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
            AND T_ASEGURADOS.CODIGO_POLIZA = T_GAR_ASE.CODIGO_POLIZA
            AND T_ASEGURADOS.NUMERO_ASEGURADO = T_GAR_ASE.NUMERO_ASEGURADO
            AND T_ASEGURADOS.NUMERO_ASEGURADO NOT IN (
                SELECT DISTINCT IFNULL(T_ASEG.NUMERO_ASEGURADO,0)
                FROM ASEGURADOS T_ASEG, GARANTIAS_ASEGURADO T_GARASE
                WHERE T_ASEG.CODIGO_POLIZA = T_GARASE.CODIGO_POLIZA
                AND T_GARASE.SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli,v_const_tipo_mov_supinase)
                AND T_ASEG.NUMERO_ASEGURADO = T_GARASE.NUMERO_ASEGURADO
                AND T_GARASE.CODIGO_POLIZA = REC.CODIGO_POLIZA
                AND CAST(hextonum( SUBSTR((CASE WHEN T_GARASE.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' ELSE T_GARASE.CODIGO_RECIBO END),3)) AS bigint) 
                	< CAST(hextonum(SUBSTR(REC.CODIGO_RECIBO,3)) AS bigint)
            
    --          AND TO_NUMBER(SUBSTR((CASE WHEN T_GARASE.CODIGO_RECIBO IN ('C_INI','C_ANUL_RRTT') THEN '00000000000' ELSE T_GARASE.CODIGO_RECIBO END),3),'XXXXXXXXXX')  < TO_NUMBER(SUBSTR(par_reg_recibo_inout.CODIGO_RECIBO,3),'XXXXXXXXXX')
                
                AND (T_ASEG.CONTO_COMO_ALTA IS NULL OR T_ASEG.CONTO_COMO_ALTA NOT IN (v_const_n,v_const_n_0))
                AND T_ASEG.FECHA_ALTA = REC.FECHA_EFECTO_RECIBO
                AND (T_ASEG.FECHA_BAJA IS NULL or (T_ASEG.FECHA_BAJA IS NOT NULL
                AND T_ASEG.FECHA_ALTA <> T_ASEG.FECHA_BAJA AND T_ASEG.FECHA_ALTA <> T_ASEG.FECHA_REHABILITACION))
            )
            AND T_GAR_ASE.CODIGO_POLIZA = REC.CODIGO_POLIZA
            AND T_GAR_ASE.CODIGO_RECIBO = REC.CODIGO_RECIBO
            AND (T_ASEGURADOS.CONTO_COMO_ALTA IS NULL OR T_ASEGURADOS.CONTO_COMO_ALTA NOT IN (v_const_n,v_const_n_0))
            AND (T_ASEGURADOS.FECHA_ALTA = REC.FECHA_EFECTO_RECIBO
            OR T_ASEGURADOS.FECHA_BAJA = REC.FECHA_EFECTO_RECIBO
            OR T_GAR_ASE.SUBTIPO_MOVIMIENTO = v_const_tipo_mov_rehabili);
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
   

	--ALM 20250820: Creamos una tabla de DEBUG.
	--COMENTAR EN PRD
	SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_DEBUG' , i_log_count, i_id_proceso, 'debug');
	--COMENTAR EN PRD

    
    TBL_ASEGURADOS_ALTA_REHABILITACION =
        SELECT TBL.* 
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN FECHA_ALTA
            WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re,v_const_motivo_alta_ro) THEN POL.FECHA_EMISION_POLIZA
        END AS FECHA_REHABILITACION_ASE
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN POLIZA_ORIGEN
        END AS POLIZA_ORIGEN_ASE
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN ASEGURADO_ORIGEN
        END AS ASEG_ORIGEN
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN (
        		SELECT A.FECHA_BAJA FROM EXT.ASEGURADOS A
        		WHERE A.CODIGO_POLIZA = TRIM(TBL.POLIZA_ORIGEN) 
        		AND A.NUMERO_ASEGURADO = TRIM(TBL.ASEGURADO_ORIGEN)) 
            WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re,v_const_motivo_alta_ro) THEN TBL.FECHA_BAJA
        END AS FECHA_BAJA_ASE
        
    
        FROM :TBL_ASEGURADOS TBL INNER JOIN POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
            WHERE (TBL.FECHA_BAJA IS NULL OR (TBL.FECHA_BAJA IS NOT NULL AND TBL.FECHA_REHABILITACION IS NOT NULL))
            AND TBL.SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_supinase, v_const_tipo_mov_rehabili)
            AND TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc,v_const_motivo_alta_re,v_const_motivo_alta_ro);
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_REHABILITACION);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_REHABILITACION sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
    
    TBL_ASEGURADOS_ALTA_REHABILITACION_1 =
        SELECT ASE.*
        -- ,CASE WHEN DAYS_BETWEEN(FECHA_BAJA_ASE,FECHA_REHABILITACION_ASE) >= v_const_365_dias THEN v_const_s
        --     WHEN (DAYS_BETWEEN(FECHA_BAJA_ASE,FECHA_REHABILITACION_ASE) BETWEEN 0 AND 30 AND 
        --       --PRODUCTO_CONTABLE IN ('22020','22035','29018','29020') AND
        --       ((EXTRACT(MONTH FROM FECHA_BAJA_ASE) = EXTRACT(MONTH FROM FECHA_REHABILITACION_ASE)
        --             AND (EXTRACT(DAY FROM FECHA_REHABILITACION_ASE) < 19 OR EXTRACT(DAY FROM FECHA_BAJA_ASE) > 18)) OR
        --       (EXTRACT(MONTH FROM FECHA_BAJA_ASE) <> EXTRACT(MONTH FROM FECHA_REHABILITACION_ASE)
        --             AND EXTRACT(DAY FROM FECHA_BAJA_ASE) > 18 AND EXTRACT(DAY FROM FECHA_REHABILITACION_ASE) < 19))) THEN v_const_s
        --     ELSE v_const_n
    
        -- END AS RH_MAYOR_ANIO
		,(CASE WHEN SUBSTR(ASE.CODIGO_POLIZA,1,2) = '01' AND SUBSTR(ASE.POLIZA_ORIGEN,1,2) = '03'
        		THEN v_const_s_1
        	WHEN FECHA_BAJA_ASE IS NULL
        		THEN v_const_s_1
        	ELSE (CASE WHEN FECHA_REHABILITACION_ASE IS NULL
	                	THEN v_const_n_0
	                WHEN FECHA_BAJA_ASE IS NULL
            				OR DAYS_BETWEEN(IFNULL(FECHA_BAJA_ASE,TO_DATE('19000101','YYYYMMDD')), FECHA_REHABILITACION_ASE) >= v_const_365_dias
            				OR (DAYS_BETWEEN(IFNULL(FECHA_BAJA_ASE,TO_DATE('19000101','YYYYMMDD')), FECHA_REHABILITACION_ASE) BETWEEN 0 AND 30
            					AND substr(ASE.PRODUCTO_CONTABLE,3,5) IN ('22020','22035','29018','29020') 
            					AND ((EXTRACT(MONTH FROM IFNULL(FECHA_BAJA_ASE,TO_DATE('19000101','YYYYMMDD'))) = EXTRACT(MONTH FROM FECHA_REHABILITACION_ASE)
			                    		AND (EXTRACT(DAY FROM FECHA_REHABILITACION_ASE) < 19 OR EXTRACT(DAY FROM IFNULL(FECHA_BAJA_ASE,TO_DATE('19000101','YYYYMMDD'))) > 18))
			                    	OR (EXTRACT(MONTH FROM IFNULL(FECHA_BAJA_ASE,TO_DATE('19000101','YYYYMMDD'))) <> EXTRACT(MONTH FROM FECHA_REHABILITACION_ASE)
										AND EXTRACT(DAY FROM IFNULL(FECHA_BAJA_ASE,TO_DATE('19000101','YYYYMMDD'))) > 18 AND EXTRACT(DAY FROM FECHA_REHABILITACION_ASE) < 19)))
	                    THEN v_const_s_1
	                ELSE v_const_n_0
				END)
        END) AS CUENTO_COMO_ALTA
        FROM :TBL_ASEGURADOS_ALTA_REHABILITACION  ASE
        ;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_REHABILITACION_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_REHABILITACION_1 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
    
    TBL_ASEGURADOS_ALTA_REHABILITACION_2 = 
        SELECT ASE.* 
        --,CASE WHEN RH_MAYOR_ANIO = v_const_n THEN v_const_n_0 ELSE v_const_s_1 END AS CUENTA_COMO_ALTA
        , (SELECT CASE WHEN SUM(CAST(IFNULL(T_GAR_ASEG.PRIMA_UNICA, 0) AS DECIMAL(10, 2))) = 0 THEN v_const_n ELSE v_const_s END AS resultado
              FROM GARANTIAS_ASEGURADO T_GAR_ASEG
            --ALM 20250820: Usamos el CODIGO_POLIZA de la TBL
             --WHERE T_GAR_ASEG.CODIGO_POLIZA = REC.CODIGO_POLIZA
             WHERE T_GAR_ASEG.CODIGO_POLIZA = ASE.CODIGO_POLIZA
               AND T_GAR_ASEG.NUMERO_ASEGURADO = ASE.NUMERO_ASEGURADO
               AND T_GAR_ASEG.FECHA_BAJA_GAR_ASE IS NULL
        ) AS ES_PRIMA_UNICA
        ,IFNULL ((SELECT T_PRODUCTOS.UNIDAD_DE_POLIZA FROM EXT.VW_GEN_PRODUCTOS T_PRODUCTOS	WHERE T_PRODUCTOS.CODIGO = SUBSTR(ASE.CODIGO_POLIZA, 1,7)
		),1) AS UNIDAD_POLIZA_PRODUCTO
        FROM :TBL_ASEGURADOS_ALTA_REHABILITACION_1 ASE ;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_REHABILITACION_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_REHABILITACION_2 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
    
    TBL_ASEGURADOS_ALTA_REHABILITACION_3 = 
        SELECT ASE.*
        	,(CASE WHEN ASE.UNIDAD_POLIZA_PRODUCTO <> 0  AND ASE.EDAD > v_const_max_edad AND SUBSTR(ASE.CODIGO_POLIZA,1,4) <> '0124' AND ASE.ES_PRIMA_UNICA = v_const_s THEN 1
				WHEN ASE.CUENTO_COMO_ALTA = v_const_s_1 THEN 1
				ELSE 0
        	END) AS NUM_ASEG_NETOS
        FROM :TBL_ASEGURADOS_ALTA_REHABILITACION_2 ASE
        WHERE ASE.PRODUCTO_CONTABLE = SUBSTR(ASE.CODIGO_POLIZA,1,7);
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_REHABILITACION_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_REHABILITACION_3 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'info');
    
    -----------------ALM 20250820: Creamos una tabla de DEBUG.
	--COMENTAR EN PRD
	SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_ALTA_REHABILITACION_3_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_ALTA_REHABILITACION_3_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_ALTA_REHABILITACION_3_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_ALTA_REHABILITACION_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_REHABILITACION_3_DEBUG' , i_log_count, i_id_proceso, 'debug');
	------------------COMENTAR EN PRD
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para TBL_ASEGURADOS_ALTA_REHABILITACION_3 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de RECIBOS con estado erróneo
        UPDATE EXT.RECIBOS REC
        SET ESTADO = v_const_calculo_status_error,
            FECHA_MODIFICACION = CURRENT_TIMESTAMP
        FROM EXT.RECIBOS REC, :TBL_ASEGURADOS_ALTA_REHABILITACION_3 src 
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.REC_CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.REC_CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.REC_ESTADO_RECIBO
            
            AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        MERGE INTO EXT.RECIBOS REC
        USING (
            -- SELECT DISTINCT REC.* 
            -- FROM :TBL_ASEGURADOS_ALTA_REHABILITACION_2 ASE INNER JOIN :TBL_RECIBOS_71_66_65 REC 
            -- ON  REC.CODIGO_POLIZA = ASE.CODIGO_POLIZA
            -- 	--AND REC.CODIGO_RECIBO = ASE.CODIGO_RECIBO
            -- 	--AND REC.CODIGO_SUPLEMENTO = ASE.CODIGO_SUPLEMENTO
            -- 	--AND REC.ESTADO_RECIBO = ASE.ESTADO_RECIBO
            SELECT ASE.CODIGO_POLIZA,
	        	ASE.REC_CODIGO_RECIBO,
	        	ASE.REC_ESTADO_RECIBO,
	        	ASE.REC_CODIGO_SUPLEMENTO,
    			SUM(IFNULL(NUM_ASEG_NETOS,0)) AS SUM_NUM_ASEG_NETOS
            FROM :TBL_ASEGURADOS_ALTA_REHABILITACION_3 ASE
            GROUP BY ASE.CODIGO_POLIZA,
	        	ASE.REC_CODIGO_RECIBO,
	        	ASE.REC_ESTADO_RECIBO,
	        	ASE.REC_CODIGO_SUPLEMENTO
        ) src
        ON REC.CODIGO_RECIBO = src.REC_CODIGO_RECIBO
            AND REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.ESTADO_RECIBO = src.REC_ESTADO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.REC_CODIGO_SUPLEMENTO
        WHEN MATCHED THEN UPDATE
            SET REC.ASEGURADOS_NETOS = IFNULL(src.SUM_NUM_ASEG_NETOS,0),
                --REC.AUMENTO_ASEGURADOS = (CASE WHEN src.SUM_NUM_ASEG_NETOS > v_const_n_0 THEN v_const_s_1 ELSE v_const_n_0 END),
                REC.AUMENTO_ASEGURADOS = (CASE WHEN src.SUM_NUM_ASEG_NETOS <> 0 AND REC.PERMANENCIA = v_const_recibos_especificos_66 THEN v_const_s_1 ELSE v_const_n_0 END ),
                REC.FECHA_MODIFICACION = current_timestamp
        ;
        
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para TBL_ASEGURADOS_ALTA_REHABILITACION_3. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
END;

    -------------------------------------------------------------------------------------------------
    TBL_ASEGURADOS_ALTA_NO_REHABILITACION =
        SELECT TBL.* 
        ,CASE WHEN IFNULL(CONTO_COMO_ALTA,'X') NOT IN (v_const_n,v_const_n_0,v_const_s,v_const_s_1) THEN POL.FECHA_EMISION_POLIZA 
        END AS FECHA_REHABILITACION_ASE
        ,CASE WHEN IFNULL(CONTO_COMO_ALTA,'X') NOT IN (v_const_n,v_const_n_0,v_const_s,v_const_s_1) THEN TBL.FECHA_BAJA 
        END AS FECHA_BAJA_ASE
        
        ,(SELECT CASE WHEN SUM(CAST(IFNULL(T_GAR_ASEG.PRIMA_UNICA, 0) AS DECIMAL(10, 2))) = 0 THEN v_const_n ELSE v_const_s END AS resultado
              FROM GARANTIAS_ASEGURADO T_GAR_ASEG
            --ALM 20250820: Usamos el CODIGO_POLIZA de la TBL
             --WHERE T_GAR_ASEG.CODIGO_POLIZA = REC.CODIGO_POLIZA
             WHERE T_GAR_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
               AND T_GAR_ASEG.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
               AND T_GAR_ASEG.FECHA_BAJA_GAR_ASE IS NULL)
        AS ES_PRIMA_UNICA
        FROM :TBL_ASEGURADOS TBL
        --ALM 20250820: Quitamos el INNER por recibos para eliminar duplicados.
        --INNER JOIN :TBL_RECIBOS REC on TBL.CODIGO_POLIZA = REC.CODIGO_POLIZA
        INNER JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
            WHERE (TBL.FECHA_BAJA IS NULL OR (TBL.FECHA_BAJA IS NOT NULL AND TBL.FECHA_REHABILITACION IS NOT NULL))
            AND SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_supinase, v_const_tipo_mov_rehabili)
            AND TBL.MOTIVO_ALTA NOT IN (v_const_motivo_alta_rc,v_const_motivo_alta_re,v_const_motivo_alta_ro);
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_NO_REHABILITACION);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_NO_REHABILITACION sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_MOTIVOS_ALTA = SELECT T_ALTA.CODIGO,T_ALTA.CUENTA_COMO_ALTA
            			FROM EXT.VW_MOTIVOS_ALTA /*INYC_LP_VW_MOTIVOS_ALTA*/ T_ALTA
            			;
            			
    v_num_rows = RECORD_COUNT(:TBL_MOTIVOS_ALTA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MOTIVOS_ALTA: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_ALTA_NO_REHABILITACION_1 = 
        SELECT ASE.* 
           --20250924 RMF: Se elimina esta parte ya que no son rehabilitaciones: FT_CUENTA_COMO_ALTA
           /*,CASE WHEN DAYS_BETWEEN(FECHA_BAJA_ASE,FECHA_REHABILITACION_ASE) >= v_const_365_dias THEN v_const_s
            WHEN (DAYS_BETWEEN(FECHA_BAJA_ASE,FECHA_REHABILITACION_ASE) BETWEEN 0 AND 30 AND 
              --PRODUCTO_CONTABLE IN ('22020','22035','29018','29020') AND
              ((EXTRACT(MONTH FROM FECHA_BAJA_ASE) = EXTRACT(MONTH FROM FECHA_REHABILITACION_ASE)
                    AND (EXTRACT(DAY FROM FECHA_REHABILITACION_ASE) < 19 OR EXTRACT(DAY FROM FECHA_BAJA_ASE) > 18)) OR
              (EXTRACT(MONTH FROM FECHA_BAJA_ASE) <> EXTRACT(MONTH FROM FECHA_REHABILITACION_ASE)
                    AND EXTRACT(DAY FROM FECHA_BAJA_ASE) > 18 AND EXTRACT(DAY FROM FECHA_REHABILITACION_ASE) < 19))) THEN v_const_s
            ELSE v_const_n
    
        END AS RH_MAYOR_ANIO*/
        	, IFNULL(T_ALTA.CUENTA_COMO_ALTA,:v_const_n_0) AS CUENTA_COMO_ALTA_1
        FROM :TBL_ASEGURADOS_ALTA_NO_REHABILITACION ASE
        LEFT JOIN :TBL_MOTIVOS_ALTA T_ALTA ON ASE.MOTIVO_ALTA = T_ALTA.CODIGO;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_NO_REHABILITACION_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_NO_REHABILITACION_1 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_ALTA_NO_REHABILITACION_2 = 
        SELECT * 
        ,CASE WHEN IFNULL(TBL.CONTO_COMO_ALTA,'X')  IN (v_const_n,v_const_n_0,v_const_s,v_const_s_1) THEN CONTO_COMO_ALTA 
        ELSE
        --CASE WHEN RH_MAYOR_ANIO = v_const_n THEN v_const_n_0 ELSE v_const_s_1 END  END AS CUENTA_COMO_ALTA
        	TO_VARCHAR(TBL.CUENTA_COMO_ALTA_1) END AS CUENTA_COMO_ALTA
        
        FROM :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_1 TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_NO_REHABILITACION_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_NO_REHABILITACION_2 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3= 
        SELECT ASE.* 
        /*,CASE WHEN IFNULL(CONTO_COMO_ALTA,'X')  IN (v_const_n,v_const_n_0,v_const_s,v_const_s_1) THEN CONTO_COMO_ALTA 
        ELSE
        CASE WHEN CUENTA_COMO_ALTA IN (v_const_s, v_const_s_1) AND ES_PRIMA_UNICA = v_const_n THEN v_const_n_0 ELSE CUENTA_COMO_ALTA
        END END AS CUENTO_COMO_ALTA_2*/
        , CASE WHEN CUENTA_COMO_ALTA IN (v_const_s, v_const_s_1) THEN 
        	CASE WHEN ASE.EDAD > v_const_max_edad AND SUBSTR(ASE.CODIGO_POLIZA, 1, 4) <> '0124' AND ES_PRIMA_UNICA = v_const_n THEN v_const_n_0 ELSE v_const_s_1 END
        	ELSE v_const_n_0
    	END AS CUENTO_COMO_ALTA_2
        ,IFNULL((SELECT T_PRODUCTOS.UNIDAD_DE_POLIZA FROM EXT.VW_GEN_PRODUCTOS T_PRODUCTOS WHERE T_PRODUCTOS.CODIGO = SUBSTR(CODIGO_POLIZA,1,7) 
        	),1)        AS UNIDAD_POLIZA_PRODUCTO 
        FROM :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_2 ASE;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
	    	--------------------------------------------------COMENTAR EN PRD
	SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3);
	------------------------------------------------COMENTAR EN PRD
    
    TBL_ASEGURADOS_ALTA_NO_REHABILITACION_NUM_ASEGURADOS = 
        SELECT CODIGO_POLIZA,REC_CODIGO_RECIBO,REC_ESTADO_RECIBO,  REC_CODIGO_SUPLEMENTO 
        , SUM(CASE WHEN UNIDAD_POLIZA_PRODUCTO <> 0 AND CUENTO_COMO_ALTA_2 IN(v_const_s, v_const_s_1)  THEN 1 ELSE 0 END ) NUMERO_ASEGURADOS
        FROM :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3 ASE
        WHERE SUBSTR(ASE.PRODUCTO_CONTABLE,5,1) = '0'
        GROUP BY CODIGO_POLIZA,REC_CODIGO_RECIBO,REC_ESTADO_RECIBO,  REC_CODIGO_SUPLEMENTO;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_NO_REHABILITACION_NUM_ASEGURADOS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_NO_REHABILITACION_NUM_ASEGURADOS sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    

	
	
    -----------------PENDIENTE METERLO EN UN BEGIN POR CONTROLAR ERRORES---------------------------------------
    UPDATE EXT.RECIBOS REC
    SET REC.ASEGURADOS_NETOS = IFNULL(REC.ASEGURADOS_NETOS,0) + TBL.NUMERO_ASEGURADOS, 
    	REC.AUMENTO_ASEGURADOS = (CASE WHEN TBL.NUMERO_ASEGURADOS <> 0 AND REC.PERMANENCIA = v_const_recibos_especificos_66 THEN v_const_s_1 ELSE v_const_n_0 END )
    FROM EXT.RECIBOS REC,  :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_NUM_ASEGURADOS TBL 
    WHERE REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    AND  REC.CODIGO_RECIBO = TBL.REC_CODIGO_RECIBO
    AND REC.ESTADO_RECIBO = TBL.REC_ESTADO_RECIBO
    AND REC.CODIGO_SUPLEMENTO = TBL.REC_CODIGO_SUPLEMENTO
    ;
    
 /*  
    --NO CUENTAN COMO ALTA
    TBL_ASEGURADOS_ALTA_NO_REHABILITACION_4 = 
        SELECT DISTINCT ASE.* --ITL metemos el distinct para que no haya duplicados, sino da problemas el merge 
        ,(SELECT DISTINCT T_ASEGURADOS.CONTO_COMO_ALTA 
                                  FROM EXT.ASEGURADOS T_ASEGURADOS
                                 WHERE T_ASEGURADOS.CODIGO_POLIZA = ASE.CODIGO_POLIZA
                                   AND T_ASEGURADOS.NUMERO_ASEGURADO = ASE.NUMERO_ASEGURADO )
        AS CONTO_COMO_ALTA_ORIGINAL
        FROM :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3 ASE
        WHERE CUENTA_COMO_ALTA IN (v_const_n, v_const_n_0);
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_NO_REHABILITACION_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_NO_REHABILITACION_4 sin extornos '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
      */  
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE  en EXT.ASEGURADOS para CONTO_COMO_ALTA - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.ASEGURADOS ASE
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.ASEGURADOS ASE, :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3 src
        WHERE  ASE.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND ASE.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
    --  AND src.CUENTO_COMO_ALTA_2 = src.CONTO_COMO_ALTA_ORIGINALRECIBO
        AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        /*MERGE INTO EXT.ASEGURADOS ASE
        USING(
            SELECT a.*, m.CUENTA_COMO_ALTA AS CUENTA_M FROM :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_4 a-- ITL 19052025 esta condicion ya se aplica  en WHERE CUENTA_COMO_ALTA IN (v_const_n, v_const_n_0)
            --JGE 20250819 se usa la vista en vez de la tabla porque esta no tiene datos
            inner join EXT.VW_MOTIVOS_ALTA m on m.CODIGO = a.MOTIVO_ALTA
        )src
        ON ASE.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND ASE.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        --AND src.CUENTO_COMO_ALTA_2 = src.CONTO_COMO_ALTA_ORIGINAL -- ITL 19052025 esta condición nunca se cumple, uno es NULL y el otro es vacío 
        WHEN MATCHED THEN UPDATE 
        SET CONTO_COMO_ALTA = CASE 
            WHEN IFNULL(CUENTA_M,0) = 0 THEN v_const_n_0
            ELSE v_const_s_1 
            --ITL 19052025 SET CONTO_COMO_ALTA = src.CONTO_COMO_ALTA_ORIGINAL CAMBIO ITL PARA FIX DE CUENTA_COMO_ALTA
        END, ASE.FECHA_MODIFICACION = CURRENT_TIMESTAMP;*/
        
        --TGV 20250827 - CAMBIAMOS EL MERGE POR UN UPDATE YA QUE SE QUEDA PARADO EL CODIGO EN EL MERGE
        UPDATE EXT.ASEGURADOS ASE 
        	SET ASE.CONTO_COMO_ALTA = CASE WHEN IFNULL(M.CUENTA_COMO_ALTA,0) = 0 THEN v_const_n_0 ELSE v_const_s_1 END, 
        		ASE.FECHA_MODIFICACION = CURRENT_TIMESTAMP
        		FROM EXT.ASEGURADOS ASE , :TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3 TBL, EXT.VW_MOTIVOS_ALTA M 
        		WHERE  M.CODIGO = TBL.MOTIVO_ALTA
        		AND ASE.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        		AND ASE.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO;
        
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.ASEGURADOS para TBL_ASEGURADOS_ALTA_NO_REHABILITACION_3. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    END;
    --------------------------------------------------------------------------------------------
    /* ITL 20062025 FIX SUBCONSULTAS 
    TBL_ASEGURADOS_ALTA_RESTO = 
         SELECT TBL.* 
         ,REC.CODIGO_RECIBO
         ,REC.CODIGO_SUPLEMENTO
         ,REC.ESTADO_RECIBO
         ,REC.PERMANENCIA
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN FECHA_ALTA
            WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re,v_const_motivo_alta_ro) THEN POL.FECHA_EMISION_POLIZA
        END AS FECHA_REHABILITACION_ASE
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN POLIZA_ORIGEN
        END AS POLIZA_ORIGEN_ASE
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN ASEGURADO_ORIGEN
        END AS ASEG_ORIGEN
        ,CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN (SELECT FECHA_BAJA FROM ASEGURADOS WHERE CODIGO_POLIZA = TRIM(CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN POLIZA_ORIGEN END) AND NUMERO_ASEGURADO = TRIM(CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN ASEGURADO_ORIGEN END)) 
            WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re,v_const_motivo_alta_ro) THEN TBL.FECHA_BAJA
        END AS FECHA_BAJA_ASE
        ,(SELECT CUENTA_COMO_BAJA FROM VW_MOTIVOS_BAJA WHERE CODIGO = TBL.MOTIVO_BAJA) 
        AS CUENTO_COMO_BAJA
        , (SELECT COUNT(*) --INTO v_recibo_ini_cobrado
                FROM EXT.RECIBOS RECI
                WHERE RECI.CODIGO_POLIZA = REC.CODIGO_POLIZA
                    AND RECI.PERMANENCIA IN ( v_const_recibos_especificos_66,v_const_recibos_especificos_65,v_const_recibos_especificos_71)
                    AND RECI.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
                    AND (RECI.ESTADO_RECIBO = v_const_recibo_cobrado
                        OR RECI.FECHA_COMPENSACION = REC.FECHA_COMPENSACION)
                    AND RECI.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt AND RECI.CODIGO_RECIBO NOT LIKE '%_A'
                    AND (RECI.TIPO_RECIBO <> v_const_tipo_rec_anul_k5 OR RECI.TIPO_RECIBO IS NULL)
            
        ) AS RECIBO_INI_COBRADO
        ,(
            SELECT ROUND(MONTHS_BETWEEN(RECI.FECHA_VTO_RECIBO,RECI.FECHA_EFECTO_RECIBO),2) 
                    FROM EXT.RECIBOS RECI
                    WHERE RECI.CODIGO_POLIZA = REC.CODIGO_POLIZA
                        AND RECI.PERMANENCIA IN ( v_const_recibos_especificos_66,v_const_recibos_especificos_65,v_const_recibos_especificos_71)
                        AND RECI.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
                        AND (RECI.ESTADO_RECIBO = v_const_recibo_cobrado
                            OR RECI.FECHA_COMPENSACION = REC.FECHA_COMPENSACION)
                        AND RECI.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt AND RECI.CODIGO_RECIBO NOT LIKE '%_A'
                        AND (RECI.TIPO_RECIBO <> v_const_tipo_rec_anul_k5 OR RECI.TIPO_RECIBO IS NULL)
                        --ALM 20200615: Nos quedamos con el recibo que tenga la fecha de emision menor.
                        AND RECI.FECHA_EMISION_REC = (
                            SELECT MIN(X.FECHA_EMISION_REC)
                            FROM EXT.RECIBOS X
                            WHERE X.CODIGO_POLIZA = REC.CODIGO_POLIZA
                                AND X.PERMANENCIA IN (v_const_recibos_especificos_66,v_const_recibos_especificos_65,v_const_recibos_especificos_71)
                                AND X.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
                                AND (X.ESTADO_RECIBO = v_const_recibo_cobrado
                                    OR X.FECHA_COMPENSACION = REC.FECHA_COMPENSACION)
                                AND X.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
                                AND (X.TIPO_RECIBO <> v_const_tipo_rec_anul_k5 OR X.TIPO_RECIBO IS NULL)
            
        )) AS MESES_RECIBO_INI_MAYOR_1
        ,(
            SELECT ROUND(MONTHS_BETWEEN(RECI.FECHA_VTO_RECIBO,RECI.FECHA_EFECTO_RECIBO),2) 
                    FROM EXT.RECIBOS RECI
                    WHERE RECI.CODIGO_POLIZA = REC.CODIGO_POLIZA
                        AND RECI.PERMANENCIA IN (v_const_recibos_especificos_66,v_const_recibos_especificos_65,v_const_recibos_especificos_71)
                        AND RECI.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
                        AND (RECI.ESTADO_RECIBO = v_const_recibo_cobrado
                            OR RECI.FECHA_COMPENSACION = REC.FECHA_COMPENSACION)
                        AND RECI.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt AND RECI.CODIGO_RECIBO NOT LIKE '%_A'
                        AND (RECI.TIPO_RECIBO <> v_const_tipo_rec_anul_k5 OR RECI.TIPO_RECIBO IS NULL)
            
        ) AS MESES_RECIBO_INI_IGUAL_0
        , (
            SELECT SUM(ROUND(MONTHS_BETWEEN(RECI.FECHA_VTO_RECIBO,RECI.FECHA_EFECTO_RECIBO),2)) --INTO v_meses_cobrados
                FROM EXT.RECIBOS RECI                  
                WHERE RECI.CODIGO_POLIZA = REC.CODIGO_POLIZA
                    AND RECI.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
                    AND RECI.ESTADO_RECIBO = v_const_recibo_cobrado
                    AND RECI.MARCA_CUENTA = v_const_s
                    AND RECI.FECHA_EFECTO_RECIBO >  TBL.FECHA_ALTA
                    AND RECI.FECHA_COMPENSACION IN ( 
                            SELECT MAX(T.FECHA_COMPENSACION)
                            FROM EXT.RECIBOS T
                            WHERE T.CODIGO_POLIZA = REC.CODIGO_POLIZA
                                AND T.PERMANENCIA IN (v_const_recibos_cartera_72,v_const_recibos_cartera_81,v_const_recibos_especificos_55)
                                AND T.ESTADO_RECIBO IN (v_const_recibo_cobrado,v_const_recibo_pendiente,v_const_recibo_anulado)
                                AND T.CODIGO_RECIBO =RECI.CODIGO_RECIBO)
        )AS MESES_COBRADOS
        ,REC.ASEGURADOS_NETOS
        
            FROM :TBL_ASEGURADOS TBL INNER JOIN :TBL_RECIBOS REC on TBL.CODIGO_POLIZA = REC.CODIGO_POLIZA INNER JOIN EXT.POLIZAS POL ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA
            WHERE NOT (TBL.FECHA_BAJA IS NULL OR (TBL.FECHA_BAJA IS NOT NULL AND TBL.FECHA_REHABILITACION IS NOT NULL))
            AND SUBTIPO_MOVIMIENTO =  v_const_tipo_mov_supinase 
            AND TBL.MOTIVO_ALTA <> v_const_motivo_alta_de;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO sin extornos '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    */
    -- TABLA TEMPORAL VW_MOTIVOS_BAJA
    TBL_MOTIVOS_BAJA = 
        SELECT CODIGO, CUENTA_COMO_BAJA
        FROM VW_MOTIVOS_BAJA
    ;
    v_num_rows = RECORD_COUNT(:TBL_MOTIVOS_BAJA);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MOTIVOS_BAJA con: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

    -- TABLA TEMPORAL RECIBOS ESPECIFICOS
    TBL_RECIBOS_ESPECIFICOS = 
        SELECT REC.*
        FROM EXT.RECIBOS REC
        INNER JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA = REC.CODIGO_POLIZA
        	AND POL.RAMO = :v_const_ramo_rrtt
        WHERE REC.PERMANENCIA IN (v_const_recibos_especificos_66, v_const_recibos_especificos_65, v_const_recibos_especificos_71,v_const_n_0)
        --AND REC.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt
        AND REC.CODIGO_RECIBO NOT LIKE '%_A'
        AND IFNULL(REC.TIPO_RECIBO,'X') <> v_const_tipo_rec_anul_k5 
		AND REC.MARCA_CUENTA = v_const_s
    ;
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ESPECIFICOS);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ESPECIFICOS con: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

 
	TBL_RECIBOS_FECHA_MIN_0 = SELECT X.CODIGO_POLIZA AS CODIGO_POLIZA_MIN
    							, MIN(X.FECHA_EMISION_REC) AS FECHA_EMISION_MIN
    							--20251020 RMF: Incluimos el NUM_ASEGURADO_MIN para el cruce posterior por NUMERO_ASEGURADO
    							, TBL.NUMERO_ASEGURADO AS NUMERO_ASEGURADO_MIN
                            FROM EXT.RECIBOS X  
                            INNER JOIN :TBL_ASEGURADOS TBL
                            	ON X.CODIGO_POLIZA = TBL.CODIGO_POLIZA
									AND X.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
                            WHERE 1=1
                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
                            GROUP BY X.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO
                            ;
                            
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_MIN_0);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_MIN_0 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     -------------------------------TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_FECHA_MIN_0_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_FECHA_MIN_0_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_FECHA_MIN_0_DEBUG AS (SELECT * FROM :TBL_RECIBOS_FECHA_MIN_0);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_MIN_0_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    --20250901 RMF: Calculo de meses cobrados para el asegurado (FT_MESES_COBRADOS_ASEG_RRTT)
    TBL_RECIBO_INICIAL_COBRADO_0 = SELECT TBL.REC_CODIGO_RECIBO AS CODIGO_RECIBO
									, TBL.CODIGO_POLIZA
									, TBL.NUMERO_ASEGURADO
									, TBL.PRODUCTO_CONTABLE
    								, ROUND(MONTHS_BETWEEN(X.FECHA_EFECTO_RECIBO,X.FECHA_VTO_RECIBO),2) AS SUM_MESES
    							FROM EXT.RECIBOS X  
                            	INNER JOIN :TBL_ASEGURADOS TBL
                            		ON X.CODIGO_POLIZA = TBL.CODIGO_POLIZA
										AND X.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
								INNER JOIN :TBL_RECIBOS_FECHA_MIN_0 TBL_MIN
									ON X.CODIGO_POLIZA = TBL_MIN.CODIGO_POLIZA_MIN
										AND X.FECHA_EMISION_REC = TBL_MIN.FECHA_EMISION_MIN
										--20251020 RMF: Incluimos el cruce por NUMERO_ASEGURADO_MIN
										AND TBL_MIN.NUMERO_ASEGURADO_MIN = TBL.NUMERO_ASEGURADO
	                            WHERE 1=1
	                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
	                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
	                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
	                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
	                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
    						;
    								
    v_num_rows = RECORD_COUNT(:TBL_RECIBO_INICIAL_COBRADO_0);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBO_INICIAL_COBRADO_0: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
      ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBO_INICIAL_COBRADO_0_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBO_INICIAL_COBRADO_0_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBO_INICIAL_COBRADO_0_DEBUG AS (SELECT * FROM :TBL_RECIBO_INICIAL_COBRADO_0);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBO_INICIAL_COBRADO_0_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    TBL_RECIBOS_FECHA_COMP_MAX_0 = SELECT MAX(T.FECHA_COMPENSACION) AS FECHA_COMP_MAX
    								, T.CODIGO_RECIBO
    								, T.CODIGO_POLIZA
    								--, T.ESTADO_RECIBO_MAX
    								--, T.CODIGO_SUPLEMENTO_MAX
                                FROM EXT.RECIBOS T
                                INNER JOIN :TBL_ASEGURADOS TBL	ON T.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                                	--AND T.CODIGO_RECIBO = TBL.CODIGO_RECIBO
									--AND T.ESTADO_RECIBO = TBL.ESTADO_RECIBO
									--AND T.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                                WHERE 1=1
                                    AND T.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
                                    AND T.ESTADO_RECIBO IN (:v_const_recibo_cobrado,:v_const_recibo_pendiente,:v_const_recibo_anulado)
                                GROUP BY T.CODIGO_RECIBO, T.CODIGO_POLIZA
                                ;
                                
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_COMP_MAX_0);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_COMP_MAX_0 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    					
    
    TBL_RECIBOS_FILTRADOS_0 = SELECT TBL.CODIGO_POLIZA
    							, TBL.REC_CODIGO_RECIBO AS CODIGO_RECIBO
    							, TBL.NUMERO_ASEGURADO
    							, TBL.PRODUCTO_CONTABLE
    							, SUM(ROUND(MONTHS_BETWEEN(RECI.FECHA_EFECTO_RECIBO, RECI.FECHA_VTO_RECIBO),2)) AS SUM_MESES--INTO v_meses_cobrados
	                        FROM EXT.RECIBOS RECI
	                        INNER JOIN :TBL_ASEGURADOS TBL ON RECI.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	                        	--AND RECI.CODIGO_RECIBO = TBL.CODIGO_RECIBO
								--AND RECI.ESTADO_RECIBO = TBL.ESTADO_RECIBO
								--AND RECI.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	                        	AND RECI.FECHA_EFECTO_RECIBO > TBL.FECHA_ALTA
	                        INNER JOIN :TBL_RECIBOS_FECHA_COMP_MAX_0 TBL_MAX ON TBL_MAX.CODIGO_POLIZA = RECI.CODIGO_POLIZA
	                        	AND TBL_MAX.CODIGO_RECIBO = RECI.CODIGO_RECIBO
	                        	AND TBL_MAX.FECHA_COMP_MAX = RECI.FECHA_COMPENSACION
	                        WHERE 1=1
	                            AND RECI.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
	                            AND RECI.ESTADO_RECIBO = :v_const_recibo_cobrado
	                            AND RECI.MARCA_CUENTA = :v_const_s
	                        GROUP BY TBL.CODIGO_POLIZA, TBL.REC_CODIGO_RECIBO, TBL.NUMERO_ASEGURADO, TBL.PRODUCTO_CONTABLE
	                        ;
	                        
	v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FILTRADOS_0);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_0 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_FILTRADOS_0_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_FILTRADOS_0_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_FILTRADOS_0_DEBUG AS (SELECT * FROM :TBL_RECIBOS_FILTRADOS_0);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_0_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    


    -- TABLA FINAL TBL_ASEGURADOS_ALTA_RESTO
    TBL_ASEGURADOS_ALTA_RESTO = 
        SELECT
            TBL.*,
            REC.CODIGO_RECIBO,
            REC.CODIGO_SUPLEMENTO,
            REC.ESTADO_RECIBO,
            REC.PERMANENCIA,
            CASE
                WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN FECHA_ALTA
                WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re, v_const_motivo_alta_ro) THEN POL.FECHA_EMISION_POLIZA
            END AS FECHA_REHABILITACION_ASE,
            CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN POLIZA_ORIGEN END AS POLIZA_ORIGEN_ASE,
            CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN ASEGURADO_ORIGEN END AS ASEG_ORIGEN,
            CASE
                WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN (
                    SELECT MAX(FECHA_BAJA)
                    FROM ASEGURADOS
                    WHERE CODIGO_POLIZA = TRIM(POLIZA_ORIGEN)
                    AND NUMERO_ASEGURADO = TRIM(ASEGURADO_ORIGEN)
                )
                WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re, v_const_motivo_alta_ro) THEN TBL.FECHA_BAJA
            END AS FECHA_BAJA_ASE,
            MB.CUENTA_COMO_BAJA AS CUENTO_COMO_BAJA,
            /*COALESCE(RIC.RECIBO_INI_COBRADO, 0) AS RECIBO_INI_COBRADO,
            RIC.MESES_RECIBO_INI_MAYOR_1,
            NULL AS MESES_RECIBO_INI_IGUAL_0, -- Añadir lógica si se requiere
            COALESCE(MC.MESES_COBRADOS, 0) AS MESES_COBRADOS,*/
            
            IFNULL(TBL_RECI_FIL.SUM_MESES,0) + IFNULL(TBL_REC_INI_COB.SUM_MESES,19) AS MESES_COBRADOS_CALC,
            REC.ASEGURADOS_NETOS
        FROM :TBL_ASEGURADOS TBL
        INNER JOIN :TBL_RECIBOS REC
            ON TBL.CODIGO_POLIZA = REC.CODIGO_POLIZA
            AND TBL.REC_CODIGO_RECIBO = REC.CODIGO_RECIBO 
            AND TBL.REC_CODIGO_SUPLEMENTO = REC.CODIGO_SUPLEMENTO
            AND TBL.REC_ESTADO_RECIBO = REC.ESTADO_RECIBO
        INNER JOIN EXT.POLIZAS POL
            ON REC.CODIGO_POLIZA = POL.CODIGO_POLIZA
        LEFT JOIN :TBL_MOTIVOS_BAJA MB
            ON MB.CODIGO = TBL.MOTIVO_BAJA
        /*LEFT JOIN :TBL_RECIBO_INI_COBRADO RIC
            ON RIC.CODIGO_POLIZA = REC.CODIGO_POLIZA
        AND RIC.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
        LEFT JOIN :TBL_MESES_COBRADOS MC
            ON MC.CODIGO_POLIZA = REC.CODIGO_POLIZA*/
    	LEFT JOIN :TBL_RECIBOS_FILTRADOS_0 TBL_RECI_FIL
    		ON TBL_RECI_FIL.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    		AND TBL_RECI_FIL.CODIGO_RECIBO = TBL.REC_CODIGO_RECIBO
    		AND TBL_RECI_FIL.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
    		AND TBL_RECI_FIL.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
    		
    	LEFT JOIN :TBL_RECIBO_INICIAL_COBRADO_0 TBL_REC_INI_COB ON TBL_REC_INI_COB.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    		AND TBL_REC_INI_COB.CODIGO_RECIBO = TBL.REC_CODIGO_RECIBO
    		AND TBL_REC_INI_COB.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
    		AND TBL_REC_INI_COB.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE    
        /*WHERE NOT (TBL.FECHA_BAJA IS NULL OR (TBL.FECHA_BAJA IS NOT NULL AND TBL.FECHA_REHABILITACION IS NOT NULL))
        AND SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supdiase
        AND TBL.MOTIVO_ALTA <> v_const_motivo_alta_de*/
        WHERE NOT ((TBL.FECHA_BAJA IS NULL OR (TBL.FECHA_BAJA IS NOT NULL AND TBL.FECHA_REHABILITACION IS NOT NULL))
            AND SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_supinase, v_const_tipo_mov_rehabili))
            AND SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supdiase
            AND TBL.MOTIVO_ALTA <> v_const_motivo_alta_de 
    ;
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO sin extornos ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
	
	
	--ALM 20250820: Creamos una tabla de DEBUG.
	--------------------------------------------------COMENTAR EN PRD
	SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_ALTA_RESTO_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_ALTA_RESTO_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_ALTA_RESTO_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_ALTA_RESTO);
	------------------------------------------------COMENTAR EN PRD
	
    TBL_ASEGURADOS_ALTA_RESTO_1 = 
        SELECT ASE.*
        /*,CASE WHEN MESES_RECIBO_INI_MAYOR_1 < 0 AND MESES_RECIBO_INI_IGUAL_0 <0 THEN 0 
            WHEN MESES_RECIBO_INI_MAYOR_1 > 12 AND MESES_RECIBO_INI_IGUAL_0 > 12 THEN 12 END 
        
        AS MESES_RECIBO_INI*/
        ,CASE WHEN SUBSTR(ASE.PRODUCTO_CONTABLE,1,3) = '012' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = ASE.PRODUCTO_CONTABLE) IS NULL THEN 17
            WHEN SUBSTR(ASE.PRODUCTO_CONTABLE,1,3) = '032' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = ASE.PRODUCTO_CONTABLE)IS NULL THEN 18
            WHEN SUBSTR(ASE.PRODUCTO_CONTABLE,3,1) <> '2'  AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = ASE.PRODUCTO_CONTABLE)IS NULL THEN 12
            ELSE IFNULL((SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = ASE.PRODUCTO_CONTABLE),0)
            END AS PERIODO_EXTORNABLE
        FROM :TBL_ASEGURADOS_ALTA_RESTO ASE;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO_1 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
        
    TBL_ASEGURADOS_ALTA_RESTO_2 = 
        SELECT ASE.* 
        /*CASE WHEN RECIBO_INI_COBRADO < 0 THEN 19 ELSE IFNULL(MESES_RECIBO_INI,0) END 
        AS PAR_MESES_COBRADOS*/
        --, (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GR.PRODUCTO_CONTABLE)
        ,CASE WHEN (CASE WHEN IFNULL(ASE.PERIODO_EXTORNABLE,0) >= 0 THEN IFNULL(ASE.PERIODO_EXTORNABLE,0) - IFNULL(MESES_COBRADOS_CALC,0) ELSE 0 END) > 0 THEN v_const_s_1 ELSE v_const_n_0 END
        AS ES_PERIODO_EXTORNABLE
        ,IFNULL((SELECT T_PRODUCTOS.UNIDAD_DE_POLIZA FROM EXT.VW_GEN_PRODUCTOS T_PRODUCTOS WHERE T_PRODUCTOS.CODIGO = SUBSTR(ASE.CODIGO_POLIZA,1,7)
        	) ,1) AS UNIDAD_POLIZA_PRODUCTO
            FROM :TBL_ASEGURADOS_ALTA_RESTO_1 ASE /*INNER JOIN GARANTIAS_RECIBO GR
            ON ASE.CODIGO_POLIZA = GR.CODIGO_POLIZA
            AND ASE.CODIGO_RECIBO = GR.CODIGO_RECIBO
            AND ASE.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO*/
            ;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO_2 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    

    TBL_ASEGURADOS_ALTA_RESTO_3 = 
        SELECT ASE.* 
        --, CASE WHEN PERIODO_EXTORNABLE  >= 0 THEN PERIODO_EXTORNABLE - PAR_MESES_COBRADOS ELSE 0 END AS MESES_NO_COBRADOS
          ,CASE WHEN UNIDAD_POLIZA_PRODUCTO <> 0 AND ES_PERIODO_EXTORNABLE IN (v_const_s_1, v_const_s) THEN -1 END NUMERO_ASEGURADOS_NETOS
        FROM :TBL_ASEGURADOS_ALTA_RESTO_2 ASE
        WHERE ASE.PRODUCTO_CONTABLE = SUBSTR(ASE.CODIGO_POLIZA , 1, 7);
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO_3 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_ALTA_RESTO_4 = 
        SELECT ASE.*
        --,CASE WHEN MESES_NO_COBRADOS > 0 THEN v_const_s_1 ELSE v_const_n_0 END AS ES_EXTORNABLE
        , CASE WHEN IFNULL(NUMERO_ASEGURADOS_NETOS,0) <> 0 AND PERMANENCIA = v_const_recibos_especificos_66 THEN v_const_s_1 ELSE v_const_n_0 END AS AUMENTO_ASEGURADOS_CALC
        FROM :TBL_ASEGURADOS_ALTA_RESTO_3 ASE;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO_4 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
     --ALM 20250820: Creamos una tabla de DEBUG.
	--------------------------------------------------COMENTAR EN PRD
	SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_ALTA_RESTO_4_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_ALTA_RESTO_4_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_ALTA_RESTO_4_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_ALTA_RESTO_4);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO_4_DEBUG' , i_log_count, i_id_proceso, 'debug');
	--------------------------------------------------COMENTAR EN PRD
  /*  TBL_ASEGURADOS_ALTA_RESTO_5 = 
        SELECT ASE.*
        --,CASE WHEN ES_EXTORNABLE IN (v_const_s_1, v_const_s) THEN ASEGURADOS_NETOS-1 END NUMERO_ASEGURADOS_NETOS
        FROM :TBL_ASEGURADOS_ALTA_RESTO_4 ASE;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO_5);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO_5 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    

    TBL_ASEGURADOS_ALTA_RESTO_6 = 
        SELECT distinct ASE.*
        --, CASE WHEN NUMERO_ASEGURADOS_NETOS <> 0 AND PERMANENCIA = v_const_recibos_especificos_66 THEN v_const_s_1 ELSE v_const_n_0 END AS AUMENTO_ASEGURADOS_CALC
        FROM :TBL_ASEGURADOS_ALTA_RESTO_5 ASE
        WHERE NUMERO_ASEGURADOS_NETOS <> 0 AND PERMANENCIA = v_const_recibos_especificos_66; -- ITL 15052025 añadimos esta linea para que solo trate con las nuevas 

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ALTA_RESTO_6);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ALTA_RESTO_6 sin extornos: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');*/
    
   
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para TBL_ASEGURADOS_ALTA_RESTO_4 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.RECIBOS REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.RECIBOS REC, :TBL_ASEGURADOS_ALTA_RESTO_4 src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
/*  ITL 15052025 merge antiguo, lo cambio para que haga el sumatorio de asegurados y no de error de duplicados
        MERGE INTO EXT.RECIBOS REC
        USING ( 
            SELECT * FROM :TBL_ASEGURADOS_ALTA_RESTO_6
        )src
        ON REC.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND REC.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
        AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
        WHEN MATCHED THEN UPDATE SET
            REC.ASEGURADOS_NETOS =NUMERO_ASEGURADOS_NETOS
            ,REC.AUMENTO_ASEGURADOS = AUMENTO_ASEGURADOS_CALC
            ,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP
        ;
*/      
        MERGE INTO EXT.RECIBOS REC
        USING ( 
            SELECT 
                TBL.CODIGO_RECIBO,
                TBL.CODIGO_POLIZA,
                TBL.ESTADO_RECIBO,
                TBL.CODIGO_SUPLEMENTO,
                SUM(TBL.NUMERO_ASEGURADOS_NETOS) AS NUMERO_ASEGURADOS_NETOS,
                ----------------- 20250903 TGV SE CAMBIA LA PRIMERA CONDICION AUMENTO_ASEGURADOS_CALC <> v_const_s_1
                CASE WHEN SUM(CASE WHEN TBL.AUMENTO_ASEGURADOS_CALC <> 0 THEN 1 ELSE 0 END) > 0 THEN v_const_s_1 ELSE v_const_n_0 END AS AUMENTO_ASEGURADOS_CALC
            FROM :TBL_ASEGURADOS_ALTA_RESTO_4 TBL
            GROUP BY 
                TBL.CODIGO_RECIBO,
                TBL.CODIGO_POLIZA,
                TBL.ESTADO_RECIBO,
                TBL.CODIGO_SUPLEMENTO
        ) src
        ON REC.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND REC.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
        AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
        WHEN MATCHED THEN UPDATE SET
            REC.ASEGURADOS_NETOS = REC.ASEGURADOS_NETOS + IFNULL(src.NUMERO_ASEGURADOS_NETOS,0),
            --REC.AUMENTO_ASEGURADOS = src.AUMENTO_ASEGURADOS_CALC,
            REC.AUMENTO_ASEGURADOS = (CASE WHEN REC.PERMANENCIA = v_const_recibos_especificos_66 THEN AUMENTO_ASEGURADOS_CALC ELSE v_const_n_0 END ),
            REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para TBL_ASEGURADOS_ALTA_RESTO_4. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    END;
    
-------------FT_INI_REC_OFICCOBPER20
--Monta una tabla temporal con la mínima fecha efectiva de inicio y con la máxima fecha efectiva de fin para las distintas oficinas

    TBL_C_OFIC = -- itl 19052025 cambiamos la temporal para que recoja solo los 4 primeros digitos de la oficina 
        SELECT POS.GENERICATTRIBUTE3 AS COD_OCASO
                            , SUBSTR(POS.GENERICATTRIBUTE3,1,4) AS OFI_COBRADORA
                            , v_const_s AS ES_PERMANENCIA_20
                            , MIN(POS.EFFECTIVESTARTDATE) AS FECHA_DESDE
                            , MAX(POS.EFFECTIVEENDDATE) AS FECHA_HASTA
                    FROM TCMP.CS_POSITION POS
                    WHERE POS.REMOVEDATE = TO_DATE('22000101','YYYYMMDD')
                        AND POS.GENERICNUMBER2 = 100
                        AND POS.TITLESEQ <> 5629499534213290 --Se filtra por TTL distinto de TTL SIN PLAN
                    GROUP BY POS.GENERICATTRIBUTE3
                    --ORDER BY 1, 3
                    --Añadimos agencias del corte inglés
			        UNION ALL
						SELECT '0940', '0940', :v_const_s, TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy
					UNION ALL
						SELECT '0946', '0946', :v_const_s, TO_DATE('20200101','YYYYMMDD'), TO_DATE('22000101','YYYYMMDD') from dummy
                    ;

    v_num_rows = RECORD_COUNT(:TBL_C_OFIC);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_C_OFIC creada: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');       
 
-------------FT_MARCAR_ES_PERMANENCIA_20------------------------------------------------------------------------------------------------

--Marcamos todos los recibos a ES_PERMANENCIA_20 a N de primeras

BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para ES_PERMANENCIA_20 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.RECIBOS REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.RECIBOS REC, :TBL_RECIBOS src
            iNNER JOIN :TBL_C_OFIC OFI
            ON SRC.OFICINA_COBRADORA = OFI.OFI_COBRADORA
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
    UPDATE EXT.RECIBOS
    SET ES_PERMANENCIA_20 = v_const_n
    	--, MARCA_CUENTA = v_const_n --ITL 10062025 metemos marca_cuenta a N y luego actualizamos a S los pertinentes 
    WHERE FILE_NAME = i_file_name;
    
END;

BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para ES_PERMANENCIA_20 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.RECIBOS REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.RECIBOS REC, :TBL_RECIBOS src
            iNNER JOIN :TBL_C_OFIC OFI
            ON SRC.OFICINA_COBRADORA =  OFI.OFI_COBRADORA
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        MERGE INTO EXT.RECIBOS REC
        USING(
            SELECT TBL.*
            ,OFI.OFI_COBRADORA
            ,OFI.ES_PERMANENCIA_20 AS OFI_ES_PERMANENCIA_20
            ,OFI.FECHA_DESDE AS OFI_FECHA_DESDE
            ,OFI.FECHA_HASTA AS OFI_FECHA_HASTA
            FROM :TBL_RECIBOS TBL INNER JOIN :TBL_C_OFIC OFI
            ON TBL.OFICINA_COBRADORA = OFI.OFI_COBRADORA
            
        )src
        ON REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND IFNULL(OFI_ES_PERMANENCIA_20,v_const_n) = v_const_s
            AND src.FECHA_COMPENSACION >= OFI_FECHA_DESDE
            AND src.FECHA_COMPENSACION < OFI_FECHA_HASTA
        WHEN MATCHED THEN UPDATE  
        SET   REC.ES_PERMANENCIA_20 = v_const_s
             ,REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
                
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para ES_PERMANENCIA_20. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;

------------FT_PRIMA_COMISIONABLE_TNX_TODO

	TBL_RECIBOS_1 = SELECT R.*
        FROM EXT.RECIBOS R INNER JOIN EXT.POLIZAS P  ON R.CODIGO_POLIZA = P.CODIGO_POLIZA
            WHERE R.FILE_NAME = i_file_name and R.ESTADO = v_const_populate_status_ok 
            AND NOT (P.MOTIVO_ALTA =v_const_motivo_baja_bb AND P.FECHA_BAJA IS NOT NULL AND P.MOTIVO_BAJA IS NOT NULL)
            AND R.CODIGO_RECIBO NOT LIKE '%_A'
            AND R.MARCA_CUENTA = v_const_s;
            
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_RECIBOS_1 creada. Información de RECIBOS actualizada para cálculos posteriores: ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');   
	
    TBL_GARANTIAS_RECIBO = 
        SELECT GR.*
            ,TBL.IDENTIFICADOR AS IDEN_REC
            ,TBL.PERMANENCIA
            ,TBL.CODIGO_UNICO_AGENTE
            ,TBL.OFICINA_GESTORA
            ,TBL.FECHA_EFECTO_RECIBO
            ,TBL.TIPO_MOVIMIENTO
            ,TBL.ASEGURADOS_NETOS
            ,TBL.CODIGO_AGENTE_ORIGINAL
            ,TBL.INSPECTOR
            ,TBL.FECHA_COMPENSACION
            ,TBL.TIPO_RECIBO
            ,TBL.ZONA_EXPLOTACION
            ,TBL.CODIGO_AGENTE_ZONA
            ,TBL.FECHA_COBRO
            ,TBL.FECHA_VTO_RECIBO
            ,TBL.PORCENTAJE_DESCUENTO_SOBRE_PC
            ,TBL.VALOR_POLIZA
            ,TBL.OFICINA_COBRADORA
            ,TBL.MARCA_RECUPERADO
            ,TBL.MARCA_CUENTA
            ,TBL.PRIMER_RECIBO
            ,TBL.AUMENTO_ASEGURADOS 
            ,TBL.EXCLUIDO_COMISIONES
            ,TBL.BONIFICACION_POLIZA
            ,TBL.DISMINUCION_PRIMA  
            ,TBL.TIPO_RECUPERACION  
            ,TBL.ES_PERMANENCIA_20  
            ,TBL.CODIGO_AGENTE_COMMISSIONS
            ,TBL.FECHA_EMISION_REC  
            ,TBL.FCHA_EFECTO_SUPLEMENTO
            ,TBL.CODIGO_SUPLEMENTO AS COD_SUPLEMENTO
            ,TBL.DISTRITO_COBRO 
            ,TBL.CODIGO_SINIESTRO
            ,TBL.ESTADO_RECIBO AS ESTADO_RECIBO_REC

        FROM EXT.GARANTIAS_RECIBO GR INNER JOIN :TBL_RECIBOS_1 TBL
            ON GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
            AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
            AND GR.ESTADO_RECIBO = TBL.ESTADO_RECIBO
            AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
            ORDER BY GR.PRODUCTO_CONTABLE ASC;
            
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_RECIBO: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBO para PRIMA_COMISIONABLE - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_RECIBO GR
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_RECIBO GR, :TBL_GARANTIAS_RECIBO src
        WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND GR.ESTADO = v_const_populate_status_ok
            --BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
            --TGV 20260229 Añadimos el producto 0129024 por peticion de Javier Garcia Fraile
            AND ((src.OFICINA_GESTORA = '0900' OR src.OFICINA_GESTORA = '900') AND src.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560')
                or src.CODIGO_POLIZA LIKE '0129024%')
            AND src.PERMANENCIA <> v_const_recibos_cartera_81;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        MERGE INTO EXT.GARANTIAS_RECIBO GR
        USING(
            SELECT * FROM :TBL_GARANTIAS_RECIBO TBL
        )src
        ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
            AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
            --BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
            --TGV 20260229 Añadimos el producto 0129024 por peticion de Javier Garcia Fraile
            AND ((src.OFICINA_GESTORA = '0900' OR src.OFICINA_GESTORA = '900') AND src.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560')
             or src.CODIGO_POLIZA LIKE '0129024%')
            AND src.PERMANENCIA <> v_const_recibos_cartera_81
        WHEN MATCHED THEN UPDATE  
        SET GR.PRIMA_COMISIONABLE = GR.PRIMA_NETA_RECIBO
            ,GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para PRIMA_COMISIONABLE - OFICINA_GESTORA = 0900. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    END;
    
    TBL_GARANTIAS_ASEGURADO =
        SELECT 
            T_ASEG.NUMERO_ASEGURADO,
            T_ASEG.FECHA_NACIMIENTO,
            T_ASEG.FECHA_ALTA,
            T_ASEG.MOTIVO_ALTA,
            T_ASEG.FECHA_BAJA,
            T_ASEG.FECHA_REHABILITACION,
            T_ASEG.POLIZA_ORIGEN,
            T_ASEG.ASEGURADO_ORIGEN,
            T_ASEG.EDAD,
            T_GAR_ASEG.SUBTIPO_MOVIMIENTO,
            T_GAR_ASEG.PRIMA_COMISIONABLE,
            T_GAR_ASEG.PRODUCTO_CONTABLE,
            T_GAR_ASEG.GARANTIA_IP,
            T_GAR_ASEG.PRIMA_NETA_ASEGURADO,
            T_GAR_ASEG.PRIMA_UNICA,
            T_GAR_ASEG.MESES_COBRADOS,
            T_GAR_ASEG.FECHA_ALTA_GAR_ASE,
            T_GAR_ASEG.FECHA_BAJA_GAR_ASE,
            TBL.CODIGO_POLIZA,
            TBL.PERMANENCIA,
            TBL.CODIGO_RECIBO,
            TBL.CODIGO_SUPLEMENTO,
            TBL.OFICINA_GESTORA,
            TBL.PRIMA_NETA_RECIBO,
            TBL.PORCENTAJE_COMISION_CALCULAD,
            TBL.ESTADO_RECIBO,
            POL.FECHA_EMISION_POLIZA
            FROM EXT.GARANTIAS_ASEGURADO T_GAR_ASEG 
            INNER JOIN EXT.ASEGURADOS T_ASEG
            	ON T_ASEG.CODIGO_POLIZA = T_GAR_ASEG.CODIGO_POLIZA 
            	AND T_ASEG.NUMERO_ASEGURADO = T_GAR_ASEG.NUMERO_ASEGURADO
            INNER JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA = T_ASEG.CODIGO_POLIZA
            INNER JOIN :TBL_GARANTIAS_RECIBO TBL
            	ON T_GAR_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                AND T_GAR_ASEG.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
                AND T_GAR_ASEG.CODIGO_RECIBO = TBL.CODIGO_RECIBO  
                --AND T_GAR_ASEG.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                AND TBL.PERMANENCIA IN (v_const_recibos_especificos_66,v_const_recibos_especificos_65,v_const_recibos_especificos_71)
               WHERE
               --Añadimos condición para excluir ASISA
               --BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
               --TGV 20260229 Añadimos el producto 0129024 por peticion de Javier Garcia Fraile
               NOT ((((TBL.OFICINA_GESTORA = '0900' OR TBL.OFICINA_GESTORA = '900') AND TBL.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560'))
                    or TBL.CODIGO_POLIZA LIKE '0129024%')
            	AND TBL.PERMANENCIA <> v_const_recibos_cartera_81)
            	AND (T_ASEG.FECHA_BAJA IS NULL OR (
                    T_ASEG.FECHA_BAJA IS NOT NULL AND 
                    T_GAR_ASEG.SUBTIPO_MOVIMIENTO = v_const_tipo_mov_rehabili AND 
                    T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO
                   ))
          ORDER BY T_ASEG.FECHA_NACIMIENTO;
                 
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_GARANTIAS_ASEGURADO_REHABILITACION = 
        SELECT TBL.* 
            ,PRIMA_NETA_ASEGURADO AS PRIMA_NETA
            ,v_const_s AS COMISION_ANTICIPADA
            -- ,CASE WHEN  TBL.MOTIVO_ALTA NOT IN (v_const_motivo_alta_re, v_const_motivo_alta_ro) THEN v_const_n ELSE
	           -- CASE WHEN FECHA_BAJA IS NULL OR DAYS_BETWEEN(FECHA_BAJA, FECHA_REHABILITACION) >= v_const_365_dias OR 
	           -- (TBL.PRODUCTO_CONTABLE IN ('22020','22035','29018','29020') AND
	           --   ((EXTRACT(MONTH FROM FECHA_BAJA) = EXTRACT(MONTH FROM FECHA_REHABILITACION)
	           --         AND (EXTRACT(DAY FROM FECHA_REHABILITACION) < 19 OR EXTRACT(DAY FROM FECHA_BAJA) > 18)) OR
	           --   (EXTRACT(MONTH FROM FECHA_BAJA) <> EXTRACT(MONTH FROM FECHA_REHABILITACION)
	           --         AND EXTRACT(DAY FROM FECHA_BAJA) > 18 AND EXTRACT(DAY FROM FECHA_REHABILITACION) < 19)))
	           --         THEN v_const_s 
	           --     when FECHA_BAJA is null and  FECHA_REHABILITACION is null then v_const_n ELSE v_const_n
            --  END END  AS RH_MAYOR_ANIO
            , (CASE WHEN TBL.MOTIVO_ALTA NOT IN (v_const_motivo_alta_re, v_const_motivo_alta_ro) THEN v_const_s
            	ELSE (CASE WHEN FECHA_EMISION_POLIZA IS NULL
		                	THEN v_const_n
		                WHEN FECHA_BAJA IS NULL
	            				OR DAYS_BETWEEN(IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD')), FECHA_EMISION_POLIZA) >= v_const_365_dias
	            				OR (DAYS_BETWEEN(IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD')), FECHA_EMISION_POLIZA) BETWEEN 0 AND 30
	            					--20251018 RMF: Cambiamos el substr de producto_contable por substr de codigo de poliza sino las garantias no principales no se calculan
	            					--AND substr(PRODUCTO_CONTABLE,3,5) IN ('22020','22035','29018','29020') 
	            					AND SUBSTR(CODIGO_POLIZA,3,5) IN ('22020','22035','29018','29020') 
	            					AND ((EXTRACT(MONTH FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) = EXTRACT(MONTH FROM FECHA_EMISION_POLIZA)
				                    		AND (EXTRACT(DAY FROM FECHA_EMISION_POLIZA) < 19 OR EXTRACT(DAY FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) > 18))
				                    	OR (EXTRACT(MONTH FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) <> EXTRACT(MONTH FROM FECHA_EMISION_POLIZA)
											AND EXTRACT(DAY FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) > 18 AND EXTRACT(DAY FROM FECHA_EMISION_POLIZA) < 19)))
		                    THEN v_const_s
		                ELSE v_const_n
					END)
             END) AS RH_MAYOR_ANIO
        --   ,TBL.CODIGO_SUPLEMENTO AS CODIGO_SU
        FROM :TBL_GARANTIAS_ASEGURADO TBL;
       
    
     v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_REHABILITACION);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_REHABILITACION: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_REC_GA = SELECT T_RECIBOS.CODIGO_POLIZA,
                    	T_RECIBOS.CODIGO_RECIBO,
                    	T_GAR_ASEG.CODIGO_POLIZA AS CODIGO_POLIZA_ACTUAL
                    	, MAX (T_RECIBOS.FECHA_EMISION_REC) AS FECHA_EMISION_REC
				FROM   
                      :TBL_RECIBOS_ESPECIFICOS T_RECIBOS
                    	
                   INNER JOIN 
                      :TBL_GARANTIAS_ASEGURADO T_GAR_ASEG ON 
                          (CASE WHEN T_GAR_ASEG.MOTIVO_ALTA IN (v_const_motivo_alta_rc) 
                    	THEN T_GAR_ASEG.POLIZA_ORIGEN ELSE T_GAR_ASEG.CODIGO_POLIZA END ) = T_RECIBOS.CODIGO_POLIZA 
                    	AND T_GAR_ASEG.CODIGO_RECIBO <> T_RECIBOS.CODIGO_RECIBO
                    	--AND (T_GAR_ASEG.CODIGO_RECIBO LIKE 'YY%' OR T_GAR_ASEG.CODIGO_RECIBO IN (:v_const_cod_recibo_ini,:v_const_cod_recibo_anul_rrtt))
                    	AND CAST(hextonum( SUBSTR((CASE WHEN T_RECIBOS.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
                    								ELSE T_RECIBOS.CODIGO_RECIBO END),3)) AS bigint) < CAST(hextonum(SUBSTR(T_GAR_ASEG.CODIGO_RECIBO,3)) AS bigint)
                GROUP BY T_RECIBOS.CODIGO_POLIZA,T_RECIBOS.CODIGO_RECIBO, T_GAR_ASEG.CODIGO_POLIZA;
    
     v_num_rows = RECORD_COUNT(:TBL_REC_GA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_REC_GA: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     TBL_RECIBOS_ANT = SELECT 
                      T_RECIBOS.CODIGO_POLIZA,
                      T_RECIBOS.CODIGO_RECIBO,
                      GA.PRODUCTO_CONTABLE,
                      GA.NUMERO_ASEGURADO
                      , T_RECIBOS.CODIGO_POLIZA_ACTUAL
                      , ROW_NUMBER() OVER(
                      		PARTITION BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.CODIGO_POLIZA_ACTUAL, GA.PRODUCTO_CONTABLE, GA.NUMERO_ASEGURADO
                      		ORDER BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.FECHA_EMISION_REC DESC
                      ) AS RN_RECIBO
                   FROM 
                      :TBL_REC_GA T_RECIBOS
                    INNER JOIN EXT.GARANTIAS_ASEGURADO GA
                    	ON GA.CODIGO_POLIZA = T_RECIBOS.CODIGO_POLIZA 
                    	AND GA.CODIGO_RECIBO = T_RECIBOS.CODIGO_RECIBO
                   --ORDER BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.FECHA_EMISION_REC DESC
                   ;
    
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ANT: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_ANT_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_ANT_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_ANT_DEBUG AS (SELECT * FROM :TBL_RECIBOS_ANT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ANT_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    TBL_GARANTIAS_ASEGURADO_REHABILITACION_71 = 
        SELECT TBL.* 
        , CASE WHEN (SELECT max(v_const_s) FROM EXT.ASEGURADOS T_ASEG
                        WHERE T_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        AND T_ASEG.NUMERO_ASEGURADO <> TBL.NUMERO_ASEGURADO
                        AND T_ASEG.EDAD <= v_const_max_edad                        
          )  = v_const_s THEN v_const_s ELSE v_const_n END 
          AS EXISTEN_MENORES_70
         
            , RA.CODIGO_RECIBO AS CODIGO_RECIBO_ANT
            ,GR.IDENTIFICADOR
            ,CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc) THEN TBL.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END 
                AS CODIGO_POLIZA_CALC,
                CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc)  THEN TBL.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END 
                AS NUMERO_ASEGURADO_CALC,
                CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc)  THEN SUBSTR(TBL.POLIZA_ORIGEN,1,4)
                		|| SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) || SUBSTR(TBL.POLIZA_ORIGEN,6,2)
                    ELSE TBL.PRODUCTO_CONTABLE END 
                AS PRODUCTO_CONTABLE_CALC
			, IFNULL((SELECT FECHA_BAJA FROM EXT.ASEGURADOS A
				WHERE A.CODIGO_POLIZA = (CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc) THEN TBL.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END)
				AND A.NUMERO_ASEGURADO = (CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc)  THEN TBL.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END)
			),TO_DATE('19000101','YYYYMMDD')) AS FEC_BAJA_ASEG_ORI
        FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION TBL INNER JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA 
        INNER JOIN :TBL_GARANTIAS_RECIBO GR 
        	ON TBL.CODIGO_POLIZA = GR.CODIGO_POLIZA
        	AND TBL.CODIGO_RECIBO = GR.CODIGO_RECIBO
        	AND TBL.ESTADO_RECIBO = GR.ESTADO_RECIBO
        	AND TBL.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
        	AND TBL.PRODUCTO_CONTABLE = GR.PRODUCTO_CONTABLE
        LEFT JOIN :TBL_RECIBOS_ANT RA ON 
            RA.CODIGO_POLIZA = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc) THEN TBL.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END 
            
            AND RA.RN_RECIBO = 1
            AND RA.NUMERO_ASEGURADO = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc) THEN TBL.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END 
                    			
            AND RA.PRODUCTO_CONTABLE = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc) THEN SUBSTR(TBL.POLIZA_ORIGEN,1,4) || SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) || SUBSTR(TBL.POLIZA_ORIGEN,6,2)
										ELSE TBL.PRODUCTO_CONTABLE END
			AND RA.CODIGO_POLIZA_ACTUAL = TBL.CODIGO_POLIZA
                    	
        WHERE (TBL.PERMANENCIA = v_const_recibos_especificos_71 OR (TBL.PERMANENCIA = v_const_recibos_especificos_65 AND RH_MAYOR_ANIO = v_const_s))
	        AND GR.TIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_rehabili) 
	        AND GR.PERMANENCIA <> v_const_recibos_cartera_81 
	        AND NOT (GR.PERMANENCIA = v_const_recibos_especificos_71 AND POL.MOTIVO_ALTA = v_const_motivo_alta_de AND ifnull(GR.ASEGURADOS_NETOS,0) = 0)
	        ;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_REHABILITACION_71);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_REHABILITACION_71: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     TBL_PRIMA_NETA_ANT_CAL = 
		    SELECT 
		    	GA.CODIGO_RECIBO,
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        IFNULL(TBL.CODIGO_POLIZA_ACTUAL,GA.CODIGO_POLIZA) AS CODIGO_POLIZA_ACTUAL
		        , SUM(GA.PRIMA_NETA_ASEGURADO) AS PRIMA_NETA_ANT_CAL
		    --FROM :TBL_GARANTIAS_ASEGURADO
		    FROM EXT.GARANTIAS_ASEGURADO GA 
		    LEFT JOIN :TBL_RECIBOS_ANT TBL
			    ON GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			    AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			    AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			    AND GA.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
			    AND RN_RECIBO = 1
		    WHERE  (TBL.CODIGO_RECIBO IS NOT NULL OR GA.CODIGO_RECIBO = v_const_cod_recibo_ini)
		    GROUP BY 
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        GA.CODIGO_RECIBO
		        , TBL.CODIGO_POLIZA_ACTUAL;
		        
		v_num_rows = RECORD_COUNT(:TBL_PRIMA_NETA_ANT_CAL);
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_NETA_ANT_CAL: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
    TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_2 = 
            SELECT TBL.*
            /*,(SELECT IFNULL(SUM(T.PRIMA_NETA_ASEGURADO),0) 
                     FROM EXT.GARANTIAS_ASEGURADO T
                     WHERE T.CODIGO_POLIZA = TBL.CODIGO_POLIZA 
                     AND T.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
                     AND T.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
                     AND T.CODIGO_RECIBO IN (CODIGO_RECIBO_ANT,v_const_cod_recibo_ini)
                    ) */
            , (CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN IFNULL(TMP.PRIMA_NETA_ANT_CAL, 0) ELSE 0 END) AS PRIMA_NETA_ANT
            , (CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc THEN 
            		(CASE WHEN TBL.FECHA_ALTA = TBL.FEC_BAJA_ASEG_ORI
            				THEN v_const_s
            			WHEN TBL.FECHA_ALTA IS NULL
            				THEN v_const_n
            			WHEN TBL.FEC_BAJA_ASEG_ORI = TO_DATE('19000101','YYYYMMDD')
            				OR DAYS_BETWEEN(TBL.FEC_BAJA_ASEG_ORI, TBL.FECHA_ALTA) >= v_const_365_dias
            				OR (DAYS_BETWEEN(TBL.FEC_BAJA_ASEG_ORI, TBL.FECHA_ALTA) BETWEEN 0 AND 30
            					AND substr(TBL.PRODUCTO_CONTABLE,3,5) IN ('22020','22035','29018','29020')
            					AND ((EXTRACT(MONTH FROM TBL.FEC_BAJA_ASEG_ORI) = EXTRACT(MONTH FROM TBL.FECHA_ALTA)
            						AND (EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19 OR EXTRACT(DAY FROM TBL.FEC_BAJA_ASEG_ORI) > 18))
            					OR (EXTRACT(MONTH FROM TBL.FEC_BAJA_ASEG_ORI) <> EXTRACT(MONTH FROM TBL.FECHA_ALTA)
	                    			AND EXTRACT(DAY FROM TBL.FEC_BAJA_ASEG_ORI) > 18 AND EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19)))
		                    THEN v_const_s
		                ELSE v_const_n
            		END)
            END) AS RH_MAYOR_ANIO_RC
            FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION_71 TBL
            LEFT JOIN :TBL_PRIMA_NETA_ANT_CAL TMP
                ON TMP.CODIGO_POLIZA = TBL.CODIGO_POLIZA_CALC
                AND TMP.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO_CALC
                AND TMP.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE_CALC
                AND TMP.CODIGO_RECIBO = IFNULL(CODIGO_RECIBO_ANT, :v_const_cod_recibo_ini)
                AND TMP.CODIGO_POLIZA_ACTUAL = TBL.CODIGO_POLIZA;
            
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_3 = 
        SELECT TBL.*
        ,IFNULL(PRIMA_NETA - PRIMA_NETA_ANT,0) AS INCREMENTO_PRIMA
        FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_2 TBL;
            
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_3: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4 =
            SELECT TBL.* 
            , (CASE WHEN RH_MAYOR_ANIO = v_const_n THEN 0
            	ELSE (CASE WHEN TBL.EDAD <= v_const_max_edad
	            				OR (TBL.EDAD > v_const_max_edad AND IFNULL(TBL.PRIMA_UNICA,v_const_n_0) IN (v_const_s_1,v_const_s))
	            				OR (TBL.EDAD > v_const_max_edad AND IFNULL(TBL.GARANTIA_IP,v_const_n_0) IN (v_const_s_1,v_const_s) 
		                            AND IFNULL(TBL.PRIMA_NETA_ASEGURADO,0) > 0 
		                            AND TBL.EXISTEN_MENORES_70 = v_const_s)
                            THEN (CASE WHEN TBL.MOTIVO_ALTA <> v_const_motivo_alta_rc THEN IFNULL(PRIMA_NETA,0)
					            	WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc AND RH_MAYOR_ANIO_RC = v_const_n AND INCREMENTO_PRIMA <= 0 THEN 0
					                WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc AND RH_MAYOR_ANIO_RC = v_const_n AND INCREMENTO_PRIMA > 0 THEN INCREMENTO_PRIMA
					                WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc AND RH_MAYOR_ANIO_RC = v_const_s THEN ROUND(PRIMA_NETA/2,2)
					            	--WHEN FECHA_BAJA IS NULL THEN INCREMENTO_PRIMA
					                --ELSE INCREMENTO_PRIMA 
								END)
						WHEN SUBSTR(TBL.CODIGO_POLIZA,1,4) = '0124' THEN 0.01
            		END)
            END) AS PRIMA_COMISIONABLE_ASEG
            , ROW_NUMBER() OVER(
                      	PARTITION BY TBL.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO, TBL.PRODUCTO_CONTABLE, TBL.CODIGO_RECIBO
                      		ORDER BY TBL.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO, TBL.PRODUCTO_CONTABLE, TBL.CODIGO_RECIBO DESC
                      ) AS ROW_NUMBER_GA
           
            FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_3 TBL;
            
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4_DEBUG AS (SELECT * FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4_DEBUG' , i_log_count, i_id_proceso, 'debug');
------------------------------

BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_ASEGURADO para TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_ASEGURADO GA
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4 src
        WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA 
           AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
           AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
           AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND GA.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        MERGE INTO EXT.GARANTIAS_ASEGURADO GA
        USING (
            SELECT * FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4
        )src
        ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA 
           AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
           AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
           AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
           AND ROW_NUMBER_GA = 1
        WHEN MATCHED THEN UPDATE
        SET PRIMA_COMISIONABLE = src.PRIMA_COMISIONABLE_ASEG
            ,PORCENTAJE_PARTICIPACION = 0
            ,FECHA_MODIFICACION = CURRENT_TIMESTAMP;
    
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_ASEGURADO para TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    END;
    
    --20251018 RMR: añadimos la tabla para la actualización de las garantias de recibo
    TBL_PRIMA_COMIS_REHABILITACION_71_GR = SELECT CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO,  ESTADO_RECIBO, PRODUCTO_CONTABLE , 
    									--MAX(IFNULL(MESES_COBRADOS_CALC,0)) AS MESES_COBRADOS, 
    									--MAX(IFNULL(ES_PERIODO_EXTORNABLE,0)) AS ES_PERIODO_EXTORNABLE , 
    									SUM(PRIMA_COMISIONABLE_ASEG) AS PRIMA_COMISIONABLE
							            FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION_71_4 
							            GROUP BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO,  ESTADO_RECIBO, PRODUCTO_CONTABLE;
							            
      v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMIS_REHABILITACION_71_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_REHABILITACION_71_GR '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_PRIMA_COMIS_REHABILITACION_71_GR_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_PRIMA_COMIS_REHABILITACION_71_GR_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_PRIMA_COMIS_REHABILITACION_71_GR_DEBUG AS (SELECT * FROM :TBL_PRIMA_COMIS_REHABILITACION_71_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_REHABILITACION_71_GR_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
	
	--20251018 RMF: UPDATE GARANTIAS_RECIBO
	BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBOS para TBL_PRIMA_COMIS_REHABILITACION_71_GR - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_RECIBO GR
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_RECIBO GR, :TBL_PRIMA_COMIS_REHABILITACION_71_GR src
        WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
        AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
        AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
            AND GR.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
   
    
    	UPDATE EXT.GARANTIAS_RECIBO GR
    	SET --GR.MESES_COBRADOS = src.MESES_COBRADOS 
    	--, GR.PERIODO_EXTORNABLE = src.ES_PERIODO_EXTORNABLE
    	GR.PRIMA_COMISIONABLE = src.PRIMA_COMISIONABLE
    	, GR.INCREMENTO_PRIMA_ANUAL = src.PRIMA_COMISIONABLE
    	, GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
    	FROM  EXT.GARANTIAS_RECIBO GR , :TBL_PRIMA_COMIS_REHABILITACION_71_GR  src
    	WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
    	AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
    	AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE ;
    	
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.GARANTIAS_RECIBO para TBL_PRIMA_COMIS_REHABILITACION_71_GR. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
END;
	
	
	
    TBL_ASEGURADOS_MENORES_70 = SELECT DISTINCT CODIGO_POLIZA, NUMERO_ASEGURADO
                                FROM :TBL_ASEGURADOS
                                WHERE EDAD <= :v_const_max_edad;
	
	v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_MENORES_70);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_MENORES_70: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_FORMAS_PAGO = SELECT CODIGO, MENSUALIDADES 
                      FROM VW_FORMAS_PAGO;
                      
    v_num_rows = RECORD_COUNT(:TBL_FORMAS_PAGO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_FORMAS_PAGO: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
   
    
    
	TBL_REC_GA_2 = 
		SELECT T_RECIBOS.CODIGO_POLIZA,
               T_RECIBOS.CODIGO_RECIBO,
               T_GAR_ASEG.CODIGO_POLIZA AS CODIGO_POLIZA_ACTUAL,
               T_GAR_ASEG.CODIGO_RECIBO AS CODIGO_RECIBO_ACTUAL,
            	MAX (T_RECIBOS.FECHA_EMISION_REC) AS FECHA_EMISION_REC
		FROM   
              :TBL_RECIBOS_ESPECIFICOS T_RECIBOS
           INNER JOIN 
              :TBL_GARANTIAS_ASEGURADO T_GAR_ASEG 
            	ON T_GAR_ASEG.CODIGO_POLIZA = T_RECIBOS.CODIGO_POLIZA 
            	AND T_GAR_ASEG.CODIGO_RECIBO <> T_RECIBOS.CODIGO_RECIBO
            	AND CAST(hextonum( SUBSTR((CASE WHEN T_RECIBOS.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
            								ELSE T_RECIBOS.CODIGO_RECIBO END),3)) AS bigint) < CAST(hextonum(SUBSTR((CASE WHEN T_GAR_ASEG.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
            								ELSE T_GAR_ASEG.CODIGO_RECIBO END ),3)) AS bigint)
        GROUP BY T_RECIBOS.CODIGO_POLIZA,T_RECIBOS.CODIGO_RECIBO, T_GAR_ASEG.CODIGO_POLIZA, T_GAR_ASEG.CODIGO_RECIBO
    	UNION 
    	SELECT T_RECIBOS.CODIGO_POLIZA,
	        	T_RECIBOS.CODIGO_RECIBO,
	        	T_GAR_ASEG.CODIGO_POLIZA AS CODIGO_POLIZA_ACTUAL,
	        	T_GAR_ASEG.CODIGO_RECIBO AS CODIGO_RECIBO_ACTUAL,
	        	MAX (T_RECIBOS.FECHA_EMISION_REC) AS FECHA_EMISION_REC
		FROM   
	          :TBL_RECIBOS_ESPECIFICOS T_RECIBOS
	       INNER JOIN 
	          :TBL_GARANTIAS_ASEGURADO T_GAR_ASEG 
	          ON T_GAR_ASEG.POLIZA_ORIGEN = T_RECIBOS.CODIGO_POLIZA 
	              AND T_GAR_ASEG.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
	        	AND T_GAR_ASEG.CODIGO_RECIBO <> T_RECIBOS.CODIGO_RECIBO
	        	AND CAST(hextonum( SUBSTR((CASE WHEN T_RECIBOS.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
	        								ELSE T_RECIBOS.CODIGO_RECIBO END),3)) AS bigint) < 
	        								CAST(hextonum(SUBSTR((CASE WHEN T_GAR_ASEG.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
	        									ELSE T_GAR_ASEG.CODIGO_RECIBO END),3)) AS bigint)
	    GROUP BY T_RECIBOS.CODIGO_POLIZA,T_RECIBOS.CODIGO_RECIBO, T_GAR_ASEG.CODIGO_POLIZA, T_GAR_ASEG.CODIGO_RECIBO
                
                
                ;
    
     v_num_rows = RECORD_COUNT(:TBL_REC_GA_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_REC_GA_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
                    	
    TBL_RECIBOS_ANT_2 = SELECT 
                      T_RECIBOS.CODIGO_POLIZA,
                      T_RECIBOS.CODIGO_RECIBO,
                      GA.PRODUCTO_CONTABLE,
                      GA.NUMERO_ASEGURADO
                      , T_RECIBOS.CODIGO_POLIZA_ACTUAL
                      , T_RECIBOS.CODIGO_RECIBO_ACTUAL
                      , ROW_NUMBER() OVER(
                      	--PARTITION BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.CODIGO_RECIBO
                      	PARTITION BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.CODIGO_POLIZA_ACTUAL, T_RECIBOS.CODIGO_RECIBO_ACTUAL ,GA.PRODUCTO_CONTABLE, GA.NUMERO_ASEGURADO
                      		--ORDER BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.FECHA_COBRO DESC
                      		ORDER BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.FECHA_EMISION_REC DESC
                      ) AS RN_RECIBO
                   FROM 
                      :TBL_REC_GA_2 T_RECIBOS
                    INNER JOIN EXT.GARANTIAS_ASEGURADO GA
                    	ON GA.CODIGO_POLIZA = T_RECIBOS.CODIGO_POLIZA 
                    	AND GA.CODIGO_RECIBO = T_RECIBOS.CODIGO_RECIBO
                   
                   --ORDER BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.FECHA_EMISION_REC DESC
                   ;
    
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANT_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ANT_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_ANT_2_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_ANT_2_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_ANT_2_DEBUG AS (SELECT * FROM :TBL_RECIBOS_ANT_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ANT_2_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    --Funcion FT_PRIMA_COMIS_SUPLEMENTO de oracle, para calcular la prima comisionable de los suplementos
     TBL_GARANTIAS_ASEGURADO_SUP =
        SELECT 
            T_ASEG.NUMERO_ASEGURADO,
            T_ASEG.FECHA_NACIMIENTO,
            T_ASEG.FECHA_ALTA,
            T_ASEG.MOTIVO_ALTA,
            T_ASEG.FECHA_BAJA,
            T_ASEG.FECHA_REHABILITACION,
            T_ASEG.POLIZA_ORIGEN,
            T_ASEG.ASEGURADO_ORIGEN,
            T_ASEG.EDAD,
            T_GAR_ASEG.SUBTIPO_MOVIMIENTO,
            T_GAR_ASEG.PRIMA_COMISIONABLE,
            T_GAR_ASEG.PRODUCTO_CONTABLE,
            T_GAR_ASEG.GARANTIA_IP,
            T_GAR_ASEG.PRIMA_NETA_ASEGURADO,
            T_GAR_ASEG.PRIMA_UNICA,
            T_GAR_ASEG.MESES_COBRADOS,
            T_GAR_ASEG.FECHA_ALTA_GAR_ASE,
            T_GAR_ASEG.FECHA_BAJA_GAR_ASE,
            TBL.CODIGO_POLIZA,
            TBL.PERMANENCIA,
            TBL.CODIGO_RECIBO,
            TBL.CODIGO_SUPLEMENTO,
            TBL.OFICINA_GESTORA,
            TBL.PRIMA_NETA_RECIBO,
            TBL.PORCENTAJE_COMISION_CALCULAD,
            TBL.ESTADO_RECIBO,
            POL.FECHA_EMISION_POLIZA
            FROM EXT.GARANTIAS_ASEGURADO T_GAR_ASEG 
            INNER JOIN EXT.ASEGURADOS T_ASEG
            	ON T_ASEG.CODIGO_POLIZA = T_GAR_ASEG.CODIGO_POLIZA 
            	AND T_ASEG.NUMERO_ASEGURADO = T_GAR_ASEG.NUMERO_ASEGURADO
            INNER JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA = T_ASEG.CODIGO_POLIZA
            INNER JOIN :TBL_GARANTIAS_RECIBO TBL
            	ON T_GAR_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                AND T_GAR_ASEG.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
                AND T_GAR_ASEG.CODIGO_RECIBO = TBL.CODIGO_RECIBO  
                --AND T_GAR_ASEG.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                --25050919 RMF: Incluimos PERMANENCIA 71, 65 en el calculo de la prima comisionable de suplementos
                AND TBL.PERMANENCIA IN (v_const_recibos_especificos_66, v_const_recibos_especificos_71, v_const_recibos_especificos_65)
                
               WHERE
               --Añadimos condición para excluir ASISA
               --BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
               --TGV 20260229 Añadimos el producto 0129024 por peticion de Javier Garcia Fraile
               NOT ((((TBL.OFICINA_GESTORA = '0900' OR TBL.OFICINA_GESTORA = '900') AND TBL.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560'))
                    or TBL.CODIGO_POLIZA LIKE '0129024%')
            	AND TBL.PERMANENCIA <> v_const_recibos_cartera_81)
            	AND TBL.CODIGO_RECIBO NOT LIKE '%_A' AND TBL.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt
        	;
                 
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_SUP);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_SUP: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_GARANTIAS_ASEGURADO_SUP_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_GARANTIAS_ASEGURADO_SUP_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_GARANTIAS_ASEGURADO_SUP_DEBUG AS (SELECT * FROM :TBL_GARANTIAS_ASEGURADO_SUP);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_SUP_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    TBL_GARANTIAS_ASEGURADO_REHABILITACION_SUP = 
        SELECT TBL.* 
            ,PRIMA_NETA_ASEGURADO AS PRIMA_NETA
            ,v_const_s AS COMISION_ANTICIPADA
            , (CASE WHEN TBL.MOTIVO_ALTA NOT IN (v_const_motivo_alta_re, v_const_motivo_alta_ro) THEN v_const_s
            	ELSE (CASE WHEN FECHA_EMISION_POLIZA IS NULL
		                	THEN v_const_n
		                WHEN FECHA_BAJA IS NULL
	            				OR DAYS_BETWEEN(IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD')), FECHA_EMISION_POLIZA) >= v_const_365_dias
	            				OR (DAYS_BETWEEN(IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD')), FECHA_EMISION_POLIZA) BETWEEN 0 AND 30
	            					--20251018 RMF: Cambiamos el substr de PRODUCTO_CONTABLE por CODIGO_POLIZA
	            					--AND substr(PRODUCTO_CONTABLE,3,5) IN ('22020','22035','29018','29020') 
	            					AND substr(CODIGO_POLIZA,3,5) IN ('22020','22035','29018','29020') 
	            					AND ((EXTRACT(MONTH FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) = EXTRACT(MONTH FROM FECHA_EMISION_POLIZA)
				                    		AND (EXTRACT(DAY FROM FECHA_EMISION_POLIZA) < 19 OR EXTRACT(DAY FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) > 18))
				                    	OR (EXTRACT(MONTH FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) <> EXTRACT(MONTH FROM FECHA_EMISION_POLIZA)
											AND EXTRACT(DAY FROM IFNULL(FECHA_BAJA,TO_DATE('19000101','YYYYMMDD'))) > 18 AND EXTRACT(DAY FROM FECHA_EMISION_POLIZA) < 19)))
		                    THEN v_const_s
		                ELSE v_const_n
					END)
             END) AS RH_MAYOR_ANIO
        --   ,TBL.CODIGO_SUPLEMENTO AS CODIGO_SU
        FROM :TBL_GARANTIAS_ASEGURADO_SUP TBL;
       
    
     v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_REHABILITACION_SUP);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_REHABILITACION_SUP: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_REC_GA_SUP = 
		SELECT T_RECIBOS.CODIGO_POLIZA,
               T_RECIBOS.CODIGO_RECIBO,
               T_GAR_ASEG.CODIGO_POLIZA AS CODIGO_POLIZA_ACTUAL,
               T_GAR_ASEG.CODIGO_RECIBO AS CODIGO_RECIBO_ACTUAL,
            	MAX (T_RECIBOS.FECHA_EMISION_REC) AS FECHA_EMISION_REC
		FROM   
              :TBL_RECIBOS_ESPECIFICOS T_RECIBOS
           INNER JOIN 
              :TBL_GARANTIAS_ASEGURADO_SUP T_GAR_ASEG 
            	ON T_GAR_ASEG.CODIGO_POLIZA = T_RECIBOS.CODIGO_POLIZA 
            	AND T_GAR_ASEG.CODIGO_RECIBO <> T_RECIBOS.CODIGO_RECIBO
            	AND CAST(hextonum( SUBSTR((CASE WHEN T_RECIBOS.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
            								ELSE T_RECIBOS.CODIGO_RECIBO END),3)) AS bigint) 
            								< CAST(hextonum(SUBSTR((CASE WHEN T_GAR_ASEG.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
            								ELSE T_GAR_ASEG.CODIGO_RECIBO END),3)) AS bigint)
            	
        GROUP BY T_RECIBOS.CODIGO_POLIZA,T_RECIBOS.CODIGO_RECIBO, T_GAR_ASEG.CODIGO_POLIZA, T_GAR_ASEG.CODIGO_RECIBO
    	UNION 
    	SELECT T_RECIBOS.CODIGO_POLIZA,
	        	T_RECIBOS.CODIGO_RECIBO,
	        	T_GAR_ASEG.CODIGO_POLIZA AS CODIGO_POLIZA_ACTUAL,
	        	T_GAR_ASEG.CODIGO_RECIBO AS CODIGO_RECIBO_ACTUAL,
	        	MAX (T_RECIBOS.FECHA_EMISION_REC) AS FECHA_EMISION_REC
		FROM   
	          :TBL_RECIBOS_ESPECIFICOS T_RECIBOS
	       INNER JOIN 
	          :TBL_GARANTIAS_ASEGURADO_SUP T_GAR_ASEG 
	          ON T_GAR_ASEG.POLIZA_ORIGEN = T_RECIBOS.CODIGO_POLIZA 
	              AND T_GAR_ASEG.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
	        	AND T_GAR_ASEG.CODIGO_RECIBO <> T_RECIBOS.CODIGO_RECIBO
	        	AND CAST(hextonum( SUBSTR((CASE WHEN T_RECIBOS.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) THEN '00000000000' 
	        								ELSE T_RECIBOS.CODIGO_RECIBO END),3)) AS bigint) 
	        								< CAST(hextonum(SUBSTR((CASE WHEN T_GAR_ASEG.CODIGO_RECIBO IN (v_const_cod_recibo_ini,v_const_cod_recibo_anul_rrtt) 
	        								THEN '00000000000' 
	        								ELSE T_GAR_ASEG.CODIGO_RECIBO END),3)) AS bigint)
	    GROUP BY T_RECIBOS.CODIGO_POLIZA,T_RECIBOS.CODIGO_RECIBO, T_GAR_ASEG.CODIGO_POLIZA, T_GAR_ASEG.CODIGO_RECIBO
  
                ;
    
     v_num_rows = RECORD_COUNT(:TBL_REC_GA_SUP);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_REC_GA_SUP: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_REC_GA_SUP_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_REC_GA_SUP_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_REC_GA_SUP_DEBUG AS (SELECT * FROM :TBL_REC_GA_SUP);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_REC_GA_SUP_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
                    	
    TBL_RECIBOS_ANT_SUP = SELECT 
                      T_RECIBOS.CODIGO_POLIZA,
                      T_RECIBOS.CODIGO_RECIBO,
                      GA.PRODUCTO_CONTABLE,
                      GA.NUMERO_ASEGURADO
                      , T_RECIBOS.CODIGO_POLIZA_ACTUAL
                      ,T_RECIBOS.CODIGO_RECIBO_ACTUAL
                      , ROW_NUMBER() OVER(
                      	
                      	PARTITION BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.CODIGO_POLIZA_ACTUAL, T_RECIBOS.CODIGO_RECIBO_ACTUAL, GA.PRODUCTO_CONTABLE, GA.NUMERO_ASEGURADO
                      		--ORDER BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.FECHA_COBRO DESC
                      		ORDER BY T_RECIBOS.CODIGO_POLIZA, T_RECIBOS.FECHA_EMISION_REC DESC
                      ) AS RN_RECIBO
                   FROM 
                      :TBL_REC_GA_SUP T_RECIBOS
                    INNER JOIN EXT.GARANTIAS_ASEGURADO GA
                    	ON GA.CODIGO_POLIZA = T_RECIBOS.CODIGO_POLIZA 
                    	AND GA.CODIGO_RECIBO = T_RECIBOS.CODIGO_RECIBO

                   ;
    
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_ANT_SUP);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ANT_SUP: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_ANT_SUP_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_ANT_SUP_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_ANT_SUP_DEBUG AS (SELECT * FROM :TBL_RECIBOS_ANT_SUP);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_ANT_SUP_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS = 
        SELECT TBL.* 
           --, CASE WHEN AM70.CODIGO_POLIZA IS NOT NULL THEN :v_const_s ELSE :v_const_n END AS EXISTEN_MENORES_70
            ,CASE WHEN (SELECT max(v_const_s) FROM EXT.ASEGURADOS T_ASEG
                        WHERE T_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        AND T_ASEG.NUMERO_ASEGURADO <> TBL.NUMERO_ASEGURADO
                        AND T_ASEG.EDAD <= v_const_max_edad                        
			           )  = v_const_s THEN v_const_s ELSE v_const_n END 
          AS EXISTEN_MENORES_70
           , FP.MENSUALIDADES AS MENSUALIDADES
           ,RA.CODIGO_RECIBO AS CODIGO_RECIBO_ANT
           ,RA.CODIGO_POLIZA AS CODIGO_POLIZA_ANT
           ,RA.NUMERO_ASEGURADO AS NUMERO_ASEGURADO_ANT
           ,RA.PRODUCTO_CONTABLE AS PRODUCTO_CONTABLE_ANT
           ,(SELECT A.FECHA_ALTA FROM EXT.ASEGURADOS A WHERE A.CODIGO_POLIZA = RA.CODIGO_POLIZA AND A.NUMERO_ASEGURADO = RA.NUMERO_ASEGURADO)
        	AS FECHA_ALTA_ANT
           ,FECHA_EFECTO_RECIBO
           ,CODIGO_UNICO_AGENTE
           ,CODIGO_AGENTE_ORIGINAL
           ,GR.INSPECTOR
           ,POL.FORMA_PAGO
           ,FECHA_COMPENSACION
           ,MOTIVO_BAJA AS MOTIVO_BAJA_POL
           ,TBL.CODIGO_SUPLEMENTO AS COD_SUPLEMENTO
        FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION_SUP TBL 
        INNER JOIN EXT.POLIZAS POL 
            ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA 
        INNER JOIN :TBL_GARANTIAS_RECIBO GR 
            ON TBL.CODIGO_POLIZA = GR.CODIGO_POLIZA
            AND TBL.CODIGO_RECIBO = GR.CODIGO_RECIBO
            AND TBL.ESTADO_RECIBO = GR.ESTADO_RECIBO
            AND TBL.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
            AND TBL.PRODUCTO_CONTABLE = GR.PRODUCTO_CONTABLE
       /* LEFT JOIN :TBL_ASEGURADOS_MENORES_70 AM70 
            ON AM70.CODIGO_POLIZA = TBL.CODIGO_POLIZA
            AND AM70.NUMERO_ASEGURADO <> TBL.NUMERO_ASEGURADO*/
        LEFT JOIN :TBL_FORMAS_PAGO FP 
            ON FP.CODIGO = POL.FORMA_PAGO
        LEFT JOIN :TBL_RECIBOS_ANT_SUP RA ON 
            RA.CODIGO_POLIZA = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    			AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO THEN TBL.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END 
            
            AND RA.RN_RECIBO = 1
            AND RA.NUMERO_ASEGURADO = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    			AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO THEN TBL.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END 
                    			
            AND RA.PRODUCTO_CONTABLE = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    					AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO THEN SUBSTR(TBL.POLIZA_ORIGEN,1,4) || SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) || SUBSTR(TBL.POLIZA_ORIGEN,6,2)
										ELSE TBL.PRODUCTO_CONTABLE END 
			AND RA.CODIGO_POLIZA_ACTUAL = TBL.CODIGO_POLIZA
			AND RA.CODIGO_RECIBO_ACTUAL = TBL.CODIGO_RECIBO
                    			
        WHERE --NOT ((TBL.PERMANENCIA = v_const_recibos_especificos_71 OR (TBL.PERMANENCIA = v_const_recibos_especificos_65 AND RH_MAYOR_ANIO = v_const_s)) AND
         NOT ((GR.TIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_rehabili)
        		AND GR.PERMANENCIA <> v_const_recibos_cartera_81 
        		AND NOT (TBL.PERMANENCIA = v_const_recibos_especificos_71 AND POL.MOTIVO_ALTA = v_const_motivo_alta_de AND ifnull(ASEGURADOS_NETOS,0) = 0)))
        AND ((  GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_suplefps OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supgener OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supdeaut OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supinase OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supdiase OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_suptrasp OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supingar OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supdigar OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supaucap OR
                GR.TIPO_MOVIMIENTO = :v_const_tipo_mov_supdicap)
            OR (TBL.PERMANENCIA = v_const_recibos_especificos_71 AND POL.MOTIVO_ALTA =  v_const_motivo_alta_de
            AND ifnull(ASEGURADOS_NETOS,0) = 0))
           
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS_DEBUG AS (SELECT * FROM :TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    TBL_COMIS_ANTICIPA = SELECT X.OFICINA
    						, X.AGENTE
    						, X.PRODUCTO_CONTABLE
    						, X.TIENE_COMIS_ANTICI_SN
                    	FROM EXT.GEN_AGE_COMIS_ANTICIPA X
                    	--WHERE X.OFICINA = SUBSTR(IFNULL(TBL.CODIGO_UNICO_AGENTE, IFNULL(TBL.CODIGO_AGENTE_ORIGINAL,TBL.INSPECTOR)),1,4)
                    	--	AND X.AGENTE = SUBSTR(IFNULL(TBL.CODIGO_UNICO_AGENTE, IFNULL(TBL.CODIGO_AGENTE_ORIGINAL,TBL.INSPECTOR)),5)
                    	--	AND X.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
                    	;
                    	
    v_num_rows = RECORD_COUNT(:TBL_COMIS_ANTICIPA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_COMIS_ANTICIPA: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_MOTIVOS_BAJA = SELECT T_BAJA.CODIGO
    						,T_BAJA.CUENTA_COMO_BAJA-- INTO par_esBaja_SN_out
                    	FROM EXT.VW_MOTIVOS_BAJA  T_BAJA
                    	--WHERE T_BAJA.CODIGO = MOTIVO_BAJA
    					;
    
    v_num_rows = RECORD_COUNT(:TBL_MOTIVOS_BAJA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MOTIVOS_BAJA: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_FORMAS_PAGO = SELECT TBL.CODIGO
    						,TBL.MENSUALIDADES 
    					FROM EXT.VW_FORMAS_PAGO TBL 
    					--WHERE T.CODIGO = FORMA_PAGO
    				;
    				
    v_num_rows = RECORD_COUNT(:TBL_FORMAS_PAGO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_FORMAS_PAGO: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_GARANTIAS_ASEGURADO_MIN = SELECT GA.CODIGO_POLIZA
    									, GA.NUMERO_ASEGURADO
    									, MIN(GA.FECHA_ALTA_GAR_ASE) AS MIN_FECHA_ALTA
    								FROM EXT.GARANTIAS_ASEGURADO GA INNER JOIN :TBL_GARANTIAS_ASEGURADO_SUP TBL
    								ON GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    								AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
    								AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
    								AND GA.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
    								GROUP BY GA.CODIGO_POLIZA, GA.NUMERO_ASEGURADO
								;
								
	v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_MIN);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_MIN: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
	
	TBL_ASEGURADOS_MIN = SELECT A.CODIGO_POLIZA
								, A.NUMERO_ASEGURADO
								, MIN(A.FECHA_ALTA) AS MIN_FECHA_ALTA
    						FROM EXT.ASEGURADOS A INNER JOIN :TBL_ASEGURADOS TBL
    						ON A.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    						AND A.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
    					
    						GROUP BY A.CODIGO_POLIZA, A.NUMERO_ASEGURADO
    					;
	
	v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_MIN);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_MIN: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
	

    TBL_RECIBOS_FECHA_MIN_1 = SELECT X.CODIGO_POLIZA AS CODIGO_POLIZA_MIN
    							, MIN(X.FECHA_EMISION_REC) AS FECHA_EMISION_MIN
    							--20251020 RMF: Incluimos el NUM_ASEGURADO_MIN para el cruce posterior por NUMERO_ASEGURADO
    							, TBL.NUMERO_ASEGURADO AS NUMERO_ASEGURADO_MIN
                            FROM EXT.RECIBOS X  
                            INNER JOIN :TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS TBL
                            	--ON X.CODIGO_POLIZA = TBL.CODIGO_POLIZA
				                   ON X.CODIGO_POLIZA = IFNULL(TBL.CODIGO_POLIZA_ANT, TBL.CODIGO_POLIZA)
								   AND X.FECHA_EFECTO_RECIBO = IFNULL(TBL.FECHA_ALTA_ANT, TBL.FECHA_ALTA)
                            WHERE 1=1
                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
                            GROUP BY X.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO
                            ;
                            
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_MIN_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_MIN_1: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    --20250901 RMF: Calculo de meses cobrados para el asegurado (FT_MESES_COBRADOS_ASEG_RRTT)
    TBL_RECIBO_INICIAL_COBRADO_1 = SELECT TBL.CODIGO_RECIBO
									, TBL.CODIGO_POLIZA
									, TBL.NUMERO_ASEGURADO
									, TBL.PRODUCTO_CONTABLE
    								, ROUND(MONTHS_BETWEEN(X.FECHA_EFECTO_RECIBO,X.FECHA_VTO_RECIBO),2) AS SUM_MESES
    								
    							FROM EXT.RECIBOS X  
                            	INNER JOIN :TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS TBL
                            		--ON X.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                            		ON X.CODIGO_POLIZA = IFNULL(TBL.CODIGO_POLIZA_ANT, TBL.CODIGO_POLIZA)
									AND X.FECHA_EFECTO_RECIBO = IFNULL(TBL.FECHA_ALTA_ANT, TBL.FECHA_ALTA)
										
								INNER JOIN :TBL_RECIBOS_FECHA_MIN_1 TBL_MIN
									ON X.CODIGO_POLIZA = TBL_MIN.CODIGO_POLIZA_MIN
										AND X.FECHA_EMISION_REC = TBL_MIN.FECHA_EMISION_MIN
										--20251020 RMF: Incluimos el cruce por NUMERO_ASEGURADO_MIN
										AND TBL_MIN.NUMERO_ASEGURADO_MIN = TBL.NUMERO_ASEGURADO
	                            WHERE 1=1
	                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
	                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
	                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
	                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
	                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
    						;
    								
    v_num_rows = RECORD_COUNT(:TBL_RECIBO_INICIAL_COBRADO_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBO_INICIAL_COBRADO_1: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBO_INICIAL_COBRADO_1_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBO_INICIAL_COBRADO_1_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBO_INICIAL_COBRADO_1_DEBUG AS (SELECT * FROM :TBL_RECIBO_INICIAL_COBRADO_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBO_INICIAL_COBRADO_1_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    TBL_RECIBOS_FECHA_COMP_MAX_1 = SELECT MAX(T.FECHA_COMPENSACION) AS FECHA_COMP_MAX
    								, T.CODIGO_RECIBO
    								, T.CODIGO_POLIZA
    								--, T.ESTADO_RECIBO_MAX
    								--, T.CODIGO_SUPLEMENTO_MAX
                                FROM EXT.RECIBOS T
                                INNER JOIN :TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS TBL	
                                ON T.CODIGO_POLIZA = IFNULL(TBL.CODIGO_POLIZA_ANT, TBL.CODIGO_POLIZA)
                                	--ON T.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                                	--AND T.CODIGO_RECIBO = TBL.CODIGO_RECIBO
									--AND T.ESTADO_RECIBO = TBL.ESTADO_RECIBO
									--AND T.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                                WHERE 1=1
                                    AND T.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
                                    AND T.ESTADO_RECIBO IN (:v_const_recibo_cobrado,:v_const_recibo_pendiente,:v_const_recibo_anulado)
                                GROUP BY T.CODIGO_RECIBO, T.CODIGO_POLIZA
                                ;
                                
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_COMP_MAX_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_COMP_MAX_1: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    					
    
    TBL_RECIBOS_FILTRADOS_1 = SELECT TBL.CODIGO_POLIZA
    							, TBL.CODIGO_RECIBO
    							, TBL.NUMERO_ASEGURADO
    							, TBL.PRODUCTO_CONTABLE
    							, SUM(ROUND(MONTHS_BETWEEN(RECI.FECHA_EFECTO_RECIBO, RECI.FECHA_VTO_RECIBO),2)) AS SUM_MESES--INTO v_meses_cobrados
	                        FROM EXT.RECIBOS RECI
	                        INNER JOIN :TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS TBL 
	                        --ON RECI.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	                        ON RECI.CODIGO_POLIZA =  IFNULL(TBL.CODIGO_POLIZA_ANT, TBL.CODIGO_POLIZA)
	                        	--AND RECI.CODIGO_RECIBO = TBL.CODIGO_RECIBO
								--AND RECI.ESTADO_RECIBO = TBL.ESTADO_RECIBO
								--AND RECI.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	                        	AND RECI.FECHA_EFECTO_RECIBO > IFNULL(TBL.FECHA_ALTA_ANT, TBL.FECHA_ALTA)
	                        INNER JOIN :TBL_RECIBOS_FECHA_COMP_MAX_1 TBL_MAX ON TBL_MAX.CODIGO_POLIZA = RECI.CODIGO_POLIZA
	                        	AND TBL_MAX.CODIGO_RECIBO = RECI.CODIGO_RECIBO
	                        	AND TBL_MAX.FECHA_COMP_MAX = RECI.FECHA_COMPENSACION
	                        WHERE 1=1
	                            AND RECI.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
	                            AND RECI.ESTADO_RECIBO = :v_const_recibo_cobrado
	                            AND RECI.MARCA_CUENTA = :v_const_s
	                        GROUP BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.NUMERO_ASEGURADO, TBL.PRODUCTO_CONTABLE
	                        ;
	                        
	v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FILTRADOS_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_1: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_FILTRADOS_1_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_FILTRADOS_1_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_FILTRADOS_1_DEBUG AS (SELECT * FROM :TBL_RECIBOS_FILTRADOS_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_1_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    
    
    
    TBL_PRIMA_COMIS_SUPLEMENTO_GA = 
      SELECT T_ASEG.NUMERO_ASEGURADO,
                T_ASEG.FECHA_NACIMIENTO,
                T_ASEG.FECHA_ALTA,
                T_ASEG.MOTIVO_ALTA,
                T_ASEG.FECHA_BAJA,
                T_ASEG.MOTIVO_BAJA,
                T_ASEG.FECHA_REHABILITACION,
                T_ASEG.POLIZA_ORIGEN,
                TRIM(T_ASEG.ASEGURADO_ORIGEN) AS ASEGURADO_ORIGEN,
                T_ASEG.EDAD,
                T_GAR_ASEG.SUBTIPO_MOVIMIENTO,
                T_GAR_ASEG.PRIMA_COMISIONABLE,
                T_GAR_ASEG.GARANTIA_IP,
                T_GAR_ASEG.PRIMA_NETA_ASEGURADO,
                T_GAR_ASEG.PRODUCTO_CONTABLE,
                T_GAR_ASEG.MESES_COBRADOS,
                T_GAR_ASEG.PRIMA_UNICA,
                T_GAR_ASEG.FECHA_ALTA_GAR_ASE,
                T_GAR_ASEG.FECHA_BAJA_GAR_ASE,
                IFNULL(TBL_ANTICI.TIENE_COMIS_ANTICI_SN, v_const_s) AS COMISION_ANTICIPADA,
                TBL_BAJAS.CUENTA_COMO_BAJA AS ES_BAJA,
                CASE WHEN IFNULL(TBL_ANTICI.TIENE_COMIS_ANTICI_SN, :v_const_s) = :v_const_s 
                	THEN T_GAR_ASEG.PRIMA_NETA_ASEGURADO
                	ELSE CASE WHEN TBL_FPAGO.MENSUALIDADES IS NULL 
                			THEN 0
                			ELSE T_GAR_ASEG.PRIMA_NETA_ASEGURADO / TBL_FPAGO.MENSUALIDADES
                		END
                END AS PRIMA_NETA,
                CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    AND T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO THEN T_ASEG.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END 
                AS CODIGO_POLIZA_CALC,
                CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, 
                                            v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    AND T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO THEN T_ASEG.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END 
                AS NUMERO_ASEGURADO_CALC,
                CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, 
                                            v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    	AND T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO THEN SUBSTR(T_ASEG.POLIZA_ORIGEN,1,4)
                		|| SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) || SUBSTR(T_ASEG.POLIZA_ORIGEN,6,2)
                    ELSE TBL.PRODUCTO_CONTABLE END 
                AS PRODUCTO_CONTABLE_CALC
                , CASE WHEN T_GAR_ASEG.SUBTIPO_MOVIMIENTO IN (:v_const_tipo_mov_supgener,:v_const_tipo_mov_supaucap,:v_const_tipo_mov_supdicap)
        			THEN GAR_ASE.MIN_FECHA_ALTA
        			ELSE ASE.MIN_FECHA_ALTA
    			END AS FECHA_ALTA_ASEGURADO
            	--, TBL_RECI_RN_1.RN  AS RECIBO_INI_COBRADO --cuenta de recibos
            	--, TBL_RECI_RN_2.MESES_RECIBO AS MESES_RECIBO_INI_MAYOR_1
            	--, TBL_RECI_RN_1.MESES_RECIBO AS MESES_RECIBO_INI_MAYOR_1
            	--, TBL_RECI_RN_1.MESES_RECIBO AS MESES_RECIBO_INI_IGUAL_0
            	, IFNULL(TBL_RECI_FIL.SUM_MESES,0) + IFNULL(TBL_REC_INI_COB.SUM_MESES,19) AS MESES_COBRADOS_CALC
            	, CASE WHEN SUBSTR(TBL.PRODUCTO_CONTABLE,1,3) = '012' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE) IS NULL THEN 17
            		WHEN SUBSTR(TBL.PRODUCTO_CONTABLE,1,3) = '032' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE)IS NULL THEN 18
                	WHEN SUBSTR(TBL.PRODUCTO_CONTABLE,3,1) <> '2'  AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE)IS NULL THEN 12
                	ELSE IFNULL((SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE),0)
                END AS PERIODO_EXTORNABLE
            	,TBL.CODIGO_RECIBO_ANT
    			,TBL.CODIGO_POLIZA
                ,TBL.CODIGO_RECIBO
                ,TBL.ESTADO_RECIBO
                ,TBL.FORMA_PAGO
                ,TBL.FECHA_EFECTO_RECIBO
                ,TBL_BAJAS.CUENTA_COMO_BAJA AS CUENTO_COMO_BAJA
                ,RH_MAYOR_ANIO
                ,TBL.CODIGO_SUPLEMENTO
                --,TBL.PRODUCTO_CONTABLE
                ,TBL.FECHA_COMPENSACION
                ,TBL.PERMANENCIA
        	FROM :TBL_GARANTIAS_ASEGURADO_SUPLEMENTOS TBL
        
        	INNER JOIN EXT.GARANTIAS_ASEGURADO T_GAR_ASEG
        		ON T_GAR_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                AND T_GAR_ASEG.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
                AND T_GAR_ASEG.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                AND T_GAR_ASEG.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
            INNER JOIN EXT.ASEGURADOS T_ASEG
            	ON T_ASEG.CODIGO_POLIZA = T_GAR_ASEG.CODIGO_POLIZA 
                AND T_ASEG.NUMERO_ASEGURADO = T_GAR_ASEG.NUMERO_ASEGURADO
            LEFT JOIN :TBL_COMIS_ANTICIPA TBL_ANTICI
	           	ON TBL_ANTICI.OFICINA = SUBSTR(IFNULL(TBL.CODIGO_UNICO_AGENTE, IFNULL(TBL.CODIGO_AGENTE_ORIGINAL,TBL.INSPECTOR)),1,4)
    	           	AND TBL_ANTICI.AGENTE = SUBSTR(IFNULL(TBL.CODIGO_UNICO_AGENTE, IFNULL(TBL.CODIGO_AGENTE_ORIGINAL,TBL.INSPECTOR)),5)
                   	AND TBL_ANTICI.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
            LEFT JOIN :TBL_MOTIVOS_BAJA TBL_BAJAS
               	ON TBL_BAJAS.CODIGO = T_ASEG.MOTIVO_BAJA
            LEFT JOIN :TBL_FORMAS_PAGO TBL_FPAGO
              	ON TBL_FPAGO.CODIGO = TBL.FORMA_PAGO
            LEFT JOIN :TBL_GARANTIAS_ASEGURADO_MIN GAR_ASE 
            
            	ON GAR_ASE.CODIGO_POLIZA = CASE WHEN TBL.MOTIVO_ALTA IN (:v_const_motivo_alta_de,
            															:v_const_motivo_alta_dt,
            															:v_const_motivo_alta_su,
            															:v_const_motivo_alta_tp,
            															:v_const_motivo_alta_ts
        																) 
        											AND T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO 
        										THEN T_ASEG.POLIZA_ORIGEN 
        										ELSE TBL.CODIGO_POLIZA 
    										END
					AND GAR_ASE.NUMERO_ASEGURADO = CASE WHEN TBL.MOTIVO_ALTA IN (:v_const_motivo_alta_de,
            																	:v_const_motivo_alta_dt,
            																	:v_const_motivo_alta_su,
            																	:v_const_motivo_alta_tp,
            																	:v_const_motivo_alta_ts
        																)
        											AND T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO 
        										THEN T_ASEG.ASEGURADO_ORIGEN 
        										ELSE TBL.NUMERO_ASEGURADO 
    										END
			LEFT JOIN :TBL_ASEGURADOS_MIN ASE 
				ON ASE.CODIGO_POLIZA = CASE WHEN TBL.MOTIVO_ALTA IN (:v_const_motivo_alta_de,
														            :v_const_motivo_alta_dt,
														            :v_const_motivo_alta_su,
														            :v_const_motivo_alta_tp,
														            :v_const_motivo_alta_ts
        															) 
        									AND T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO 
        								THEN T_ASEG.POLIZA_ORIGEN 
        								ELSE TBL.CODIGO_POLIZA 
    								END
    				AND ASE.NUMERO_ASEGURADO = CASE WHEN TBL.MOTIVO_ALTA IN (:v_const_motivo_alta_de,
																            :v_const_motivo_alta_dt,
																            :v_const_motivo_alta_su,
																            :v_const_motivo_alta_tp,
																            :v_const_motivo_alta_ts
        																	) 
        											AND T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO 
        										THEN T_ASEG.ASEGURADO_ORIGEN 
        										ELSE TBL.NUMERO_ASEGURADO 
    										END
    	
        	LEFT JOIN :TBL_RECIBOS_FILTRADOS_1 TBL_RECI_FIL
        		ON TBL_RECI_FIL.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        		AND TBL_RECI_FIL.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        		AND TBL_RECI_FIL.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
        		AND TBL_RECI_FIL.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
        		
        	LEFT JOIN :TBL_RECIBO_INICIAL_COBRADO_1 TBL_REC_INI_COB ON TBL_REC_INI_COB.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        		AND TBL_REC_INI_COB.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        		AND TBL_REC_INI_COB.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
        		AND TBL_REC_INI_COB.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
     
            WHERE 1=1 
                AND ((T_ASEG.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO AND T_GAR_ASEG.SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supinase AND T_ASEG.FECHA_BAJA IS NULL
                AND T_ASEG.NUMERO_ASEGURADO NOT IN (
                    SELECT DISTINCT IFNULL(T_GARASE.NUMERO_ASEGURADO,0)
                	FROM EXT.GARANTIAS_ASEGURADO T_GARASE
                    WHERE T_GARASE.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        AND SUBSTR(T_GARASE.CODIGO_RECIBO,3)< SUBSTR(TBL.CODIGO_RECIBO,3)
                        AND T_GARASE.SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli,v_const_tipo_mov_supinase)))
                OR (T_ASEG.FECHA_BAJA is null and T_GAR_ASEG.SUBTIPO_MOVIMIENTO <> v_const_tipo_mov_supinase)
                OR (T_ASEG.FECHA_BAJA = TBL.FECHA_EFECTO_RECIBO AND 
                   (T_ASEG.FECHA_ALTA <> T_ASEG.FECHA_BAJA or T_GAR_ASEG.SUBTIPO_MOVIMIENTO <> v_const_tipo_mov_altapoli)) 
                OR (T_ASEG.FECHA_BAJA IS NOT NULL AND T_ASEG.FECHA_REHABILITACION IS NOT NULL))
            	AND (not T_GAR_ASEG.PRODUCTO_CONTABLE LIKE_REGEXPR '^0[0-9][0-9][0-9]5[0-9][0-9]$') or
            		(  (T_GAR_ASEG.PRODUCTO_CONTABLE LIKE_REGEXPR '^0[0-9][0-9][0-9]5[0-9][0-9]$') and
                	T_GAR_ASEG.SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_supinase, v_const_tipo_mov_supdiase))
    		;
    
    v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMIS_SUPLEMENTO_GA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_PRIMA_COMIS_SUPLEMENTO_GA_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GA_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GA_DEBUG AS (SELECT * FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GA_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------ 
    
    
    --ITL 05062025 bloque nuevo evitando subconsultas
        TBL_PRIMA_NETA_ANT_CAL_1 = 
		    SELECT 
		    	GA.CODIGO_RECIBO,
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        IFNULL(TBL.CODIGO_POLIZA_ACTUAL,GA.CODIGO_POLIZA) AS CODIGO_POLIZA_ACTUAL,
		        IFNULL(TBL.CODIGO_RECIBO_ACTUAL,GA.CODIGO_RECIBO) AS CODIGO_RECIBO_ACTUAL,
		        SUM(GA.PRIMA_NETA_ASEGURADO) AS PRIMA_NETA_ANT_CAL
		    FROM EXT.GARANTIAS_ASEGURADO GA 
		    LEFT JOIN :TBL_RECIBOS_ANT_SUP TBL
			    ON GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			    AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			    AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			    AND GA.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
			    AND RN_RECIBO = 1
		     WHERE  (TBL.CODIGO_RECIBO IS NOT NULL OR GA.CODIGO_RECIBO = v_const_cod_recibo_ini)
		    GROUP BY 
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        GA.CODIGO_RECIBO,
		        TBL.CODIGO_POLIZA_ACTUAL,
		        TBL.CODIGO_RECIBO_ACTUAL
		    ;
		        
		v_num_rows = RECORD_COUNT(:TBL_PRIMA_NETA_ANT_CAL_1);
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_NETA_ANT_CAL_1:'|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    	
    	 ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_PRIMA_NETA_ANT_CAL_1_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_PRIMA_NETA_ANT_CAL_1_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_PRIMA_NETA_ANT_CAL_1_DEBUG AS (SELECT * FROM :TBL_PRIMA_NETA_ANT_CAL_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_NETA_ANT_CAL_1_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------

        TBL_PRIMA_COMIS_SUPLEMENTO_GA_2 = 
        SELECT TBL.*
            , CASE WHEN IFNULL(PERIODO_EXTORNABLE,0) >= 0 THEN IFNULL(PERIODO_EXTORNABLE,0) - IFNULL(MESES_COBRADOS_CALC,0) ELSE 0 END 
            AS MESES_NO_COBRADOS
            ,CASE WHEN (CASE WHEN IFNULL(PERIODO_EXTORNABLE,0) >= 0 THEN IFNULL(PERIODO_EXTORNABLE,0) - IFNULL(MESES_COBRADOS_CALC,0) ELSE 0 END) > 0 THEN v_const_s_1 ELSE v_const_n_0 END
            AS ES_PERIODO_EXTORNABLE
            ,IFNULL(TMP.PRIMA_NETA_ANT_CAL, 0) AS PRIMA_NETA_ANT_CAL

            FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA TBL
            LEFT JOIN :TBL_PRIMA_NETA_ANT_CAL_1 TMP ON TMP.CODIGO_POLIZA = TBL.CODIGO_POLIZA_CALC
                AND TMP.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO_CALC
                AND TMP.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE_CALC
                AND TMP.CODIGO_RECIBO = IFNULL(CODIGO_RECIBO_ANT, :v_const_cod_recibo_ini)
                AND TMP.CODIGO_POLIZA_ACTUAL = TBL.CODIGO_POLIZA
                AND TMP.CODIGO_RECIBO_ACTUAL IN ( TBL.CODIGO_RECIBO, v_const_cod_recibo_ini)
            ;
                
		v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMIS_SUPLEMENTO_GA_2);
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GA_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
  
    TBL_PRIMA_COMIS_SUPLEMENTO_GA_3 = 
        SELECT TBL.*
            ,CASE WHEN COMISION_ANTICIPADA = v_const_n THEN PRIMA_NETA_ANT_CAL / (SELECT T.MENSUALIDADES FROM EXT.VW_FORMAS_PAGO  T WHERE T.CODIGO = FORMA_PAGO) ELSE 0 END 
            AS PRIMA_NETA_ANT
            , PRIMA_NETA - (CASE WHEN COMISION_ANTICIPADA = v_const_n THEN PRIMA_NETA_ANT_CAL / (SELECT T.MENSUALIDADES FROM EXT.VW_FORMAS_PAGO  T WHERE T.CODIGO = FORMA_PAGO) ELSE PRIMA_NETA_ANT_CAL END ) 
            AS INCREMENTO_PRIMA
            FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA_2 TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMIS_SUPLEMENTO_GA_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GA_3 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_PRIMA_COMIS_SUPLEMENTO_GA_3_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GA_3_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GA_3_DEBUG AS (SELECT * FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GA_3_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 = 
        SELECT TBL.* 
        -- ITL 23042025 casteamos a varchar campos GARANTIA_IP y CUENTO_COMO_BAJA para poder comparar con las constantes 
        ,CASE WHEN TBL.EDAD > :v_const_max_edad 
        		THEN 0
        	WHEN ((INCREMENTO_PRIMA <= 0 AND ES_PERIODO_EXTORNABLE = v_const_n_0 ) OR CAST(IFNULL(GARANTIA_IP,0) AS VARCHAR) IN (v_const_s , v_const_s_1)) AND TBL.PERMANENCIA = :v_const_recibos_especificos_71 AND TBL.MOTIVO_ALTA <> v_const_motivo_alta_de
                THEN PRIMA_NETA
            WHEN (INCREMENTO_PRIMA <= 0 AND ES_PERIODO_EXTORNABLE = v_const_n_0 ) OR CAST(IFNULL(GARANTIA_IP,0) AS VARCHAR) IN (v_const_s , v_const_s_1)
                THEN 0
            WHEN SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supdiase AND FECHA_BAJA = TBL.FECHA_EFECTO_RECIBO AND ES_PERIODO_EXTORNABLE = v_const_s_1 
                    AND CAST(CUENTO_COMO_BAJA AS VARCHAR) IN (v_const_s_1, v_const_s) AND FECHA_ALTA >= TO_DATE ('01/01/2017', 'dd/mm/yyyy')
                THEN PRIMA_NETA * (PERIODO_EXTORNABLE - MESES_COBRADOS) / PERIODO_EXTORNABLE * (-1)
            WHEN SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supdiase AND FECHA_BAJA = TBL.FECHA_EFECTO_RECIBO AND ES_PERIODO_EXTORNABLE = v_const_s_1 
                    AND CAST(CUENTO_COMO_BAJA AS VARCHAR) IN (v_const_s_1, v_const_s) AND FECHA_ALTA < TO_DATE ('01/01/2017', 'dd/mm/yyyy') 
                THEN 0
            WHEN SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supinase AND MOTIVO_ALTA = v_const_motivo_alta_rc AND FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO AND RH_MAYOR_ANIO = v_const_s
                THEN PRIMA_NETA/2
            WHEN SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supinase AND MOTIVO_ALTA = v_const_motivo_alta_rc AND FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO AND RH_MAYOR_ANIO = v_const_n
                THEN PRIMA_NETA - PRIMA_NETA_ANT
            WHEN SUBTIPO_MOVIMIENTO = v_const_tipo_mov_supdigar AND FECHA_BAJA_GAR_ASE IS NOT NULL AND INCREMENTO_PRIMA < 0
                THEN 0
            WHEN PRODUCTO_CONTABLE IN (v_const_producto_21021, v_const_producto_21030) AND FECHA_ALTA_GAR_ASE = TBL.FECHA_EFECTO_RECIBO
                THEN PRIMA_NETA
            WHEN PRODUCTO_CONTABLE IN (v_const_producto_21021, v_const_producto_21030) AND FECHA_ALTA_GAR_ASE <> TBL.FECHA_EFECTO_RECIBO
                THEN INCREMENTO_PRIMA /2
            WHEN SUBTIPO_MOVIMIENTO <> v_const_tipo_mov_supdiase 
                THEN INCREMENTO_PRIMA    
        END AS PRIMA_COMISIONABLE_ASEG
        FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA_3 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMIS_SUPLEMENTO_GA_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
	
	 ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_PRIMA_COMIS_SUPLEMENTO_GA_4_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GA_4_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GA_4_DEBUG AS (SELECT * FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GA_4_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------

	TBL_PRIMA_COMIS_SUPLEMENTO_GR = SELECT CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO,  ESTADO_RECIBO, PRODUCTO_CONTABLE , 
    									MAX(IFNULL(MESES_COBRADOS_CALC,0)) AS MESES_COBRADOS,
    									MAX(IFNULL(ES_PERIODO_EXTORNABLE,0)) AS ES_PERIODO_EXTORNABLE ,
    									SUM(PRIMA_COMISIONABLE_ASEG) AS PRIMA_COMISIONABLE
							            FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 
							            GROUP BY CODIGO_POLIZA, CODIGO_RECIBO, CODIGO_SUPLEMENTO,  ESTADO_RECIBO, PRODUCTO_CONTABLE;
							            
      v_num_rows = RECORD_COUNT(:TBL_PRIMA_COMIS_SUPLEMENTO_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GR '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_PRIMA_COMIS_SUPLEMENTO_GR_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GR_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_PRIMA_COMIS_SUPLEMENTO_GR_DEBUG AS (SELECT * FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_COMIS_SUPLEMENTO_GR_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_ASEGURADO para TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_ASEGURADO GA
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 src
        WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA 
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
        AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND GA.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
    	UPDATE EXT.GARANTIAS_ASEGURADO GA
    	SET  GA.PRIMA_COMISIONABLE = src.PRIMA_COMISIONABLE_ASEG,
             GA.PORCENTAJE_PARTICIPACION = v_const_n_0,
             GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP
        FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 src
        WHERE  GA.CODIGO_POLIZA = src.CODIGO_POLIZA 
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
        AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO;
 
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_ASEGURADO para TBL_PRIMA_COMIS_SUPLEMENTO_GA_4. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    END;
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBOS para TBL_PRIMA_COMIS_SUPLEMENTO_GR - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_RECIBO GR
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_RECIBO GR, :TBL_PRIMA_COMIS_SUPLEMENTO_GR src
        WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND GR.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
   
    
    	UPDATE EXT.GARANTIAS_RECIBO GR
    	SET GR.MESES_COBRADOS = src.MESES_COBRADOS 
    	, GR.PERIODO_EXTORNABLE = src.ES_PERIODO_EXTORNABLE
    	, GR.PRIMA_COMISIONABLE = src.PRIMA_COMISIONABLE
    	, GR.INCREMENTO_PRIMA_ANUAL = src.PRIMA_COMISIONABLE
    	, GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP
    	FROM  EXT.GARANTIAS_RECIBO GR , :TBL_PRIMA_COMIS_SUPLEMENTO_GR  src
    	WHERE GR.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
    	AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
    	AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE ;
    	
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE en EXT.GARANTIAS_RECIBO para TBL_PRIMA_COMIS_SUPLEMENTO_GA_4. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
END;

    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.RECIBOS REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.RECIBOS REC, :TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND REC.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        MERGE INTO EXT.RECIBOS R
        USING (
            SELECT  DISTINCT TBL.CODIGO_POLIZA,
                    TBL.CODIGO_RECIBO,
                    TBL.CODIGO_SUPLEMENTO,
                    REC.CODIGO_UNICO_AGENTE,
                    REC.CODIGO_AGENTE_ORIGINAL,
                    REC.CODIGO_AGENTE_COMMISSIONS,
                    REC.INSPECTOR,
                    TBL.ESTADO_RECIBO
                    FROM :TBL_PRIMA_COMIS_SUPLEMENTO_GA_4 TBL
            INNER JOIN EXT.RECIBOS REC
	            ON REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	            AND REC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	            AND REC.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	            AND REC.ESTADO_RECIBO = TBL.ESTADO_RECIBO
            where REC.PERMANENCIA IN (v_const_recibos_especificos_71,v_const_recibos_especificos_66,v_const_recibos_especificos_65)
            AND REC.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
            AND (REC.ESTADO_RECIBO = v_const_recibo_cobrado  OR REC.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
            AND REC.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt AND REC.CODIGO_RECIBO NOT LIKE '%_A'
            AND (REC.TIPO_RECIBO <> v_const_tipo_rec_anul_k5 OR REC.TIPO_RECIBO IS NULL)
            AND PRIMA_COMISIONABLE_ASEG <0 AND SUBSTR(PRODUCTO_CONTABLE,5,1) = '0'
        )src
        ON R.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND R.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND R.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
        AND R.ESTADO_RECIBO = src.ESTADO_RECIBO
        WHEN MATCHED THEN UPDATE SET
            R.CODIGO_UNICO_AGENTE = src.CODIGO_UNICO_AGENTE,
            R.CODIGO_AGENTE_ORIGINAL = src.CODIGO_AGENTE_ORIGINAL,
            R.CODIGO_AGENTE_COMMISSIONS = src.CODIGO_AGENTE_COMMISSIONS,
            R.INSPECTOR = src.INSPECTOR,
            R.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para TBL_PRIMA_COMIS_SUPLEMENTO_GA_4. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    END;    
    ----------------------------------------------- 
    
    ----ALTAPOLI 66
    
    -- Tabla temporal para EXISTEN_MENORES_70
    TBL_EXISTEN_MENORES_70_66 =
        SELECT DISTINCT
            T_ASEG.CODIGO_POLIZA,
            v_const_s AS EXISTEN_MENORES_70
        FROM EXT.ASEGURADOS T_ASEG
        WHERE T_ASEG.EDAD <= v_const_max_edad
    ;
    v_num_rows = RECORD_COUNT(:TBL_EXISTEN_MENORES_70_66);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_EXISTEN_MENORES_70_66 ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

    -- Tabla temporal para MENSUALIDADES
    TBL_MENSUALIDADES_66 =
        SELECT MFP.CODIGO, MFP.MENSUALIDADES
        FROM VW_FORMAS_PAGO MFP
    ;
    v_num_rows = RECORD_COUNT(:TBL_MENSUALIDADES_66);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MENSUALIDADES_66 ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

     -- Consulta principal con joins y alias
    TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66 =
        SELECT
            TBL.*,
            COALESCE(MENOR70.EXISTEN_MENORES_70, v_const_n) AS EXISTEN_MENORES_70,
            MENS.MENSUALIDADES,
            RA.CODIGO_RECIBO AS CODIGO_RECIBO_ANT,
            RA.CODIGO_POLIZA AS CODIGO_POLIZA_ANT,
            RA.PRODUCTO_CONTABLE AS PRODUCTO_CONTABLE_ANT,
            RA.NUMERO_ASEGURADO AS NUMERO_ASEGURADO_ANT,
           -- (SELECT A.FECHA_ALTA FROM EXT.ASEGURADOS A WHERE A.CODIGO_POLIZA = RA.CODIGO_POLIZA AND A.NUMERO_ASEGURADO = RA.NUMERO_ASEGURADO) 
            --AS FECHA_ALTA_ANT,
            FECHA_EFECTO_RECIBO,
            CODIGO_UNICO_AGENTE,
            CODIGO_AGENTE_ORIGINAL,
            GR.INSPECTOR,
            POL.FORMA_PAGO AS FORMA_PAGO_POLIZA,
            FECHA_COMPENSACION,
            POL.MOTIVO_BAJA AS MOTIVO_BAJA_POL,
            GR.CODIGO_SUPLEMENTO AS CODIGO_SUP,
            POL.FECHA_EFECTO_POLIZA AS FECHA_EFECTO_POLIZA,
            --FE. FECHA_EFECTO_RECIBO_66,
            NUM_ORDEN_MOVIMIENTO,
             CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    			AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO THEN TBL.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END 
                AS CODIGO_POLIZA_CALC,
             CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    			AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO  THEN TBL.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END 
                AS NUMERO_ASEGURADO_CALC,
            CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    			AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO  THEN SUBSTR(TBL.POLIZA_ORIGEN,1,4)
                		|| SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) || SUBSTR(TBL.POLIZA_ORIGEN,6,2)
                    ELSE TBL.PRODUCTO_CONTABLE END 
                AS PRODUCTO_CONTABLE_CALC,
            CASE WHEN SUBSTR(TBL.PRODUCTO_CONTABLE,1,3) = '012' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE) IS NULL THEN 17
            		WHEN SUBSTR(TBL.PRODUCTO_CONTABLE,1,3) = '032' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE)IS NULL THEN 18
                	WHEN SUBSTR(TBL.PRODUCTO_CONTABLE,3,1) <> '2'  AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE)IS NULL THEN 12
                	ELSE IFNULL((SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = TBL.PRODUCTO_CONTABLE),0)
                END AS PERIODO_EXTORNABLE
            , IFNULL((SELECT FECHA_BAJA FROM EXT.ASEGURADOS A
				WHERE A.CODIGO_POLIZA = (CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc) THEN TBL.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END)
				AND A.NUMERO_ASEGURADO = (CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_rc)  THEN TBL.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END)
			),TO_DATE('19000101','YYYYMMDD')) AS FEC_BAJA_ASEG_ORI    
			
			
			
            /*, ROW_NUMBER () OVER(
            	PARTITION BY TBL.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO, TBL.PRODUCTO_CONTABLE, TBL.CODIGO_RECIBO
            	ORDER BY TBL.CODIGO_RECIBO 
            ) AS RN_GAR_ASE*/
        FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION TBL
        INNER JOIN EXT.POLIZAS POL
            ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
        INNER JOIN :TBL_GARANTIAS_RECIBO GR
            ON TBL.CODIGO_POLIZA = GR.CODIGO_POLIZA
            AND TBL.CODIGO_RECIBO = GR.CODIGO_RECIBO
            AND TBL.ESTADO_RECIBO = GR.ESTADO_RECIBO
            AND TBL.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
            AND TBL.PRODUCTO_CONTABLE = GR.PRODUCTO_CONTABLE
        LEFT JOIN :TBL_EXISTEN_MENORES_70_66 MENOR70
            ON TBL.CODIGO_POLIZA = MENOR70.CODIGO_POLIZA
        LEFT JOIN :TBL_MENSUALIDADES_66 MENS
            ON POL.FORMA_PAGO = MENS.CODIGO
        /*LEFT JOIN :TBL_CODIGO_RECIBO_ANT_66 REC_ANT
            ON TBL.CODIGO_POLIZA = REC_ANT.CODIGO_POLIZA
        AND TBL.CODIGO_RECIBO = REC_ANT.CODIGO_RECIBO
        AND REC_ANT.RN = 1*/
         LEFT JOIN :TBL_RECIBOS_ANT_2 RA ON 
            RA.CODIGO_POLIZA = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    			AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO THEN TBL.POLIZA_ORIGEN ELSE TBL.CODIGO_POLIZA END 
            
            AND RA.RN_RECIBO = 1
            AND RA.NUMERO_ASEGURADO = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    			AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO THEN TBL.ASEGURADO_ORIGEN ELSE TBL.NUMERO_ASEGURADO END 
                    			
            AND RA.PRODUCTO_CONTABLE = CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_de,v_const_motivo_alta_dt, v_const_motivo_alta_su, v_const_motivo_alta_tp, v_const_motivo_alta_ts) 
                    					AND TBL.FECHA_ALTA = GR.FECHA_EFECTO_RECIBO THEN SUBSTR(TBL.POLIZA_ORIGEN,1,4) || SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) || SUBSTR(TBL.POLIZA_ORIGEN,6,2)
										ELSE TBL.PRODUCTO_CONTABLE END  
			AND RA.CODIGO_POLIZA_ACTUAL = TBL.CODIGO_POLIZA
            AND RA.CODIGO_RECIBO_ACTUAL = TBL.CODIGO_RECIBO 
            
        /*LEFT JOIN :TBL_FECHA_EFECTO_RECIBO_66 FE
            ON TBL.CODIGO_POLIZA = FE.CODIGO_POLIZA
        AND TBL.CODIGO_RECIBO = FE.CODIGO_RECIBO*/
        WHERE TBL.PERMANENCIA = v_const_recibos_especificos_66
	        AND GR.TIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_rehabili) 
	        AND GR.PERMANENCIA <> v_const_recibos_cartera_81 
	        AND NOT (GR.PERMANENCIA = v_const_recibos_especificos_71 AND POL.MOTIVO_ALTA = v_const_motivo_alta_de AND ifnull(GR.ASEGURADOS_NETOS,0) = 0)
	        
        --AND (TIPO_MOVIMIENTO <> v_const_tipo_mov_altapoli OR TIPO_MOVIMIENTO IS NULL)
    ;
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66 ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

    TBL_PRIMA_NETA_ANT_CAL_2 = 
		    SELECT 
		    	GA.CODIGO_RECIBO,
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        IFNULL(TBL.CODIGO_POLIZA_ACTUAL,GA.CODIGO_POLIZA) AS CODIGO_POLIZA_ACTUAL,
		        IFNULL(TBL.CODIGO_RECIBO_ACTUAL,GA.CODIGO_RECIBO) AS CODIGO_RECIBO_ACTUAL,
		        SUM(GA.PRIMA_NETA_ASEGURADO) AS PRIMA_NETA_ANT_CAL
		    --FROM :TBL_GARANTIAS_ASEGURADO
		    --FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66 GA 
		    FROM EXT.GARANTIAS_ASEGURADO GA 
		    LEFT JOIN :TBL_RECIBOS_ANT_2 TBL
			    ON GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			    AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			    AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			    AND GA.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
			    AND RN_RECIBO = 1
			WHERE  (TBL.CODIGO_RECIBO IS NOT NULL OR GA.CODIGO_RECIBO = v_const_cod_recibo_ini)
		    GROUP BY 
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        GA.CODIGO_RECIBO,
		        TBL.CODIGO_POLIZA_ACTUAL,
		        TBL.CODIGO_RECIBO_ACTUAL;
		        
		v_num_rows = RECORD_COUNT(:TBL_PRIMA_NETA_ANT_CAL_2);
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_NETA_ANT_CAL_2:'|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');


    TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 = 
        SELECT TBL.*
        , DAYS_BETWEEN (FECHA_EFECTO_RECIBO ,  FECHA_EFECTO_POLIZA ) AS DIFF_MESES
        ,CASE WHEN DAYS_BETWEEN (FECHA_EFECTO_RECIBO ,  FECHA_EFECTO_POLIZA ) < 365 THEN DAYS_BETWEEN (FECHA_EFECTO_RECIBO ,  FECHA_EFECTO_POLIZA ) /30 ELSE MENSUALIDADES
        END AS NUM_PERIODO
        ,PRIMA_COMISIONABLE / MENSUALIDADES AS PC_ASEGURADO
        ,CASE WHEN TBL.CODIGO_POLIZA <> TBL.CODIGO_POLIZA_CALC 
        	THEN (SELECT ASE.FECHA_ALTA FROM EXT.ASEGURADOS ASE WHERE ASE.CODIGO_POLIZA = TBL.CODIGO_POLIZA_CALC AND ASE.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO_CALC)
        	ELSE TBL.FECHA_ALTA
        END AS FECHA_ALTA_ASEG
        ,TBL.PRIMA_NETA_ASEGURADO - IFNULL(TMP.PRIMA_NETA_ANT_CAL,0) AS INCREMENTO_PRIMA
        FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66 TBL
        LEFT JOIN :TBL_PRIMA_NETA_ANT_CAL_2 TMP
                ON TMP.CODIGO_POLIZA = TBL.CODIGO_POLIZA_CALC
                AND TMP.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO_CALC
                AND TMP.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE_CALC
                AND TMP.CODIGO_RECIBO = IFNULL(CODIGO_RECIBO_ANT, :v_const_cod_recibo_ini)
                AND TMP.CODIGO_POLIZA_ACTUAL = TBL.CODIGO_POLIZA
                AND TMP.CODIGO_RECIBO_ACTUAL IN ( TBL.CODIGO_RECIBO, v_const_cod_recibo_ini)
        ;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
  
  TBL_RECIBOS_FECHA_MIN_2 = SELECT X.CODIGO_POLIZA AS CODIGO_POLIZA_MIN
    							, MIN(X.FECHA_EMISION_REC) AS FECHA_EMISION_MIN
    							--20251020 RMF: Incluimos el NUM_ASEGURADO_MIN para el cruce posterior por NUMERO_ASEGURADO
    							, TBL.NUMERO_ASEGURADO AS NUMERO_ASEGURADO_MIN
                            FROM EXT.RECIBOS X  
                            INNER JOIN :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 TBL
                            	ON X.CODIGO_POLIZA = IFNULL(TBL.CODIGO_POLIZA_ANT,TBL.CODIGO_POLIZA)
								AND X.FECHA_EFECTO_RECIBO = IFNULL(TBL.FECHA_ALTA_ASEG, TBL.FECHA_ALTA)
                            WHERE 1=1
                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
                            GROUP BY X.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO
                            ;
                            
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_MIN_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_MIN_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    --20250901 RMF: Calculo de meses cobrados para el asegurado (FT_MESES_COBRADOS_ASEG_RRTT)
    TBL_RECIBO_INICIAL_COBRADO_2 = SELECT TBL.CODIGO_RECIBO
									, TBL.CODIGO_POLIZA
									, TBL.NUMERO_ASEGURADO
									, TBL.PRODUCTO_CONTABLE
    								, ROUND(MONTHS_BETWEEN(X.FECHA_EFECTO_RECIBO,X.FECHA_VTO_RECIBO),2) AS SUM_MESES
    							FROM EXT.RECIBOS X  
                            	INNER JOIN :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 TBL
                            			ON X.CODIGO_POLIZA = IFNULL(TBL.CODIGO_POLIZA_ANT,TBL.CODIGO_POLIZA)
								AND X.FECHA_EFECTO_RECIBO = IFNULL(TBL.FECHA_ALTA_ASEG, TBL.FECHA_ALTA)
								INNER JOIN :TBL_RECIBOS_FECHA_MIN_2 TBL_MIN
									ON X.CODIGO_POLIZA = TBL_MIN.CODIGO_POLIZA_MIN
										AND X.FECHA_EMISION_REC = TBL_MIN.FECHA_EMISION_MIN
										--20251020 RMF: Incluimos el cruce por NUMERO_ASEGURADO_MIN
										AND TBL_MIN.NUMERO_ASEGURADO_MIN = TBL.NUMERO_ASEGURADO
	                            WHERE 1=1
	                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
	                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
	                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
	                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
	                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
    						;
    								
    v_num_rows = RECORD_COUNT(:TBL_RECIBO_INICIAL_COBRADO_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBO_INICIAL_COBRADO_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
    TBL_RECIBOS_FECHA_COMP_MAX_2 = SELECT MAX(T.FECHA_COMPENSACION) AS FECHA_COMP_MAX
    								, T.CODIGO_RECIBO
    								, T.CODIGO_POLIZA
    								--, T.ESTADO_RECIBO_MAX
    								--, T.CODIGO_SUPLEMENTO_MAX
                                FROM EXT.RECIBOS T
                                INNER JOIN :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 TBL	
                                	ON T.CODIGO_POLIZA = IFNULL(TBL.CODIGO_POLIZA_ANT,TBL.CODIGO_POLIZA)
                                	--AND T.CODIGO_RECIBO = TBL.CODIGO_RECIBO
									--AND T.ESTADO_RECIBO = TBL.ESTADO_RECIBO
									--AND T.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                                WHERE 1=1
                                    AND T.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
                                    AND T.ESTADO_RECIBO IN (:v_const_recibo_cobrado,:v_const_recibo_pendiente,:v_const_recibo_anulado)
                                GROUP BY T.CODIGO_RECIBO, T.CODIGO_POLIZA
                                ;
                                
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_COMP_MAX_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_COMP_MAX_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    					
    
    TBL_RECIBOS_FILTRADOS_2 = SELECT TBL.CODIGO_POLIZA
    							, TBL.CODIGO_RECIBO
    							, TBL.NUMERO_ASEGURADO
    							, TBL.PRODUCTO_CONTABLE
    							, SUM(ROUND(MONTHS_BETWEEN(RECI.FECHA_EFECTO_RECIBO, RECI.FECHA_VTO_RECIBO),2)) AS SUM_MESES--INTO v_meses_cobrados
	                        FROM EXT.RECIBOS RECI
	                        INNER JOIN :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 TBL 
	                        	ON RECI.CODIGO_POLIZA = IFNULL(TBL.CODIGO_POLIZA_ANT,TBL.CODIGO_POLIZA)
	                        	--AND RECI.CODIGO_RECIBO = TBL.CODIGO_RECIBO
								--AND RECI.ESTADO_RECIBO = TBL.ESTADO_RECIBO
								--AND RECI.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
								AND RECI.FECHA_EFECTO_RECIBO > IFNULL(TBL.FECHA_ALTA_ASEG, TBL.FECHA_ALTA)
	                        	
	                        INNER JOIN :TBL_RECIBOS_FECHA_COMP_MAX_2 TBL_MAX ON TBL_MAX.CODIGO_POLIZA = RECI.CODIGO_POLIZA
	                        	AND TBL_MAX.CODIGO_RECIBO = RECI.CODIGO_RECIBO
	                        	AND TBL_MAX.FECHA_COMP_MAX = RECI.FECHA_COMPENSACION
	                        WHERE 1=1
	                            AND RECI.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
	                            AND RECI.ESTADO_RECIBO = :v_const_recibo_cobrado
	                            AND RECI.MARCA_CUENTA = :v_const_s
	                        GROUP BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.NUMERO_ASEGURADO, TBL.PRODUCTO_CONTABLE
	                        ;
	                        
	v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FILTRADOS_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_FILTRADOS_2_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_FILTRADOS_2_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_FILTRADOS_2_DEBUG AS (SELECT * FROM :TBL_RECIBOS_FILTRADOS_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_2_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
  
	
    TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_2 = 
        SELECT TBL.*
        	, IFNULL(TBL_RECI_FIL.SUM_MESES,0) + IFNULL(TBL_REC_INI_COB.SUM_MESES,19) AS MESES_COBRADOS_CALC
        	,CASE WHEN (CASE WHEN IFNULL(PERIODO_EXTORNABLE,0) >= 0 THEN IFNULL(PERIODO_EXTORNABLE,0) - IFNULL(IFNULL(TBL_RECI_FIL.SUM_MESES,0) + IFNULL(TBL_REC_INI_COB.SUM_MESES,19),0) ELSE 0 END) > 0 
        		THEN v_const_s_1 ELSE v_const_n_0 END
            AS ES_PERIODO_EXTORNABLE
        FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 TBL
        LEFT JOIN :TBL_RECIBOS_FILTRADOS_2 TBL_RECI_FIL
        		ON TBL_RECI_FIL.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        		AND TBL_RECI_FIL.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        		AND TBL_RECI_FIL.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
        		AND TBL_RECI_FIL.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
        	LEFT JOIN :TBL_RECIBO_INICIAL_COBRADO_2 TBL_REC_INI_COB ON TBL_REC_INI_COB.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        		AND TBL_REC_INI_COB.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        		AND TBL_REC_INI_COB.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
        		AND TBL_REC_INI_COB.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
        ;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
  
   TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_3 = 
        SELECT TBL.*
        	,CASE WHEN (INCREMENTO_PRIMA <= 0 AND ES_PERIODO_EXTORNABLE = v_const_n_0 ) OR CAST(IFNULL(GARANTIA_IP,0) AS VARCHAR) IN (v_const_s , v_const_s_1) THEN 0  
                  WHEN TBL.EDAD <= v_const_max_edad OR (TBL.EDAD > v_const_max_edad AND IFNULL(TBL.PRIMA_UNICA,v_const_n_0) IN (v_const_s_1,v_const_s)) THEN INCREMENTO_PRIMA 
                  ELSE 0
            END AS PRIMA_COMISIONABLE_ASEG
            , (CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc  AND TBL.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO THEN 
            		(CASE WHEN TBL.FECHA_ALTA = TBL.FEC_BAJA_ASEG_ORI
            				THEN v_const_s
            			WHEN TBL.FECHA_ALTA IS NULL
            				THEN v_const_n
            			WHEN TBL.FEC_BAJA_ASEG_ORI = TO_DATE('19000101','YYYYMMDD')
            				OR DAYS_BETWEEN(TBL.FEC_BAJA_ASEG_ORI, TBL.FECHA_ALTA) >= v_const_365_dias
            				OR (DAYS_BETWEEN(TBL.FEC_BAJA_ASEG_ORI, TBL.FECHA_ALTA) BETWEEN 0 AND 30
            					AND substr(TBL.PRODUCTO_CONTABLE,3,5) IN ('22020','22035','29018','29020')
            					AND ((EXTRACT(MONTH FROM TBL.FEC_BAJA_ASEG_ORI) = EXTRACT(MONTH FROM TBL.FECHA_ALTA)
            						AND (EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19 OR EXTRACT(DAY FROM TBL.FEC_BAJA_ASEG_ORI) > 18))
            					OR (EXTRACT(MONTH FROM TBL.FEC_BAJA_ASEG_ORI) <> EXTRACT(MONTH FROM TBL.FECHA_ALTA)
	                    			AND EXTRACT(DAY FROM TBL.FEC_BAJA_ASEG_ORI) > 18 AND EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19)))
		                    THEN v_const_s
		                ELSE v_const_n
            		END)
            END) AS RH_MAYOR_ANIO_RC
            
        FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_2 TBL
        
        ;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_3: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
  
   TBL_PRIMA_NETA_ANT_CAL_RC = 
		    SELECT 
		    	GA.CODIGO_RECIBO,
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        IFNULL(TBL.CODIGO_POLIZA_ACTUAL,GA.CODIGO_POLIZA) AS CODIGO_POLIZA_ACTUAL
		        , SUM(GA.PRIMA_NETA_ASEGURADO) AS PRIMA_NETA_ANT_CAL
		    --FROM :TBL_GARANTIAS_ASEGURADO
		    --FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_3 GA 
		    FROM EXT.GARANTIAS_ASEGURADO GA 
		    LEFT JOIN :TBL_RECIBOS_ANT TBL
			    ON GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			    AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
			    AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
			    AND GA.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
			    AND RN_RECIBO = 1
		    WHERE  (TBL.CODIGO_RECIBO IS NOT NULL OR GA.CODIGO_RECIBO = v_const_cod_recibo_ini)
		    GROUP BY 
		        GA.CODIGO_POLIZA,
		        GA.NUMERO_ASEGURADO,
		        GA.PRODUCTO_CONTABLE,
		        GA.CODIGO_RECIBO
		        , TBL.CODIGO_POLIZA_ACTUAL;
		        
		v_num_rows = RECORD_COUNT(:TBL_PRIMA_NETA_ANT_CAL_RC);
    	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_NETA_ANT_CAL_RC:'|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

  
  
    TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4 = 
        SELECT TBL.*
        	,(CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_rc  AND TBL.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO 
        		THEN CASE WHEN RH_MAYOR_ANIO_RC = v_const_n AND (TBL.PRIMA_NETA_ASEGURADO - IFNULL(TMP.PRIMA_NETA_ANT_CAL,0)) <= 0 THEN 0
        				  WHEN RH_MAYOR_ANIO_RC = v_const_n AND (TBL.PRIMA_NETA_ASEGURADO - IFNULL(TMP.PRIMA_NETA_ANT_CAL,0)) > 0 THEN TBL.PRIMA_NETA_ASEGURADO - IFNULL(TMP.PRIMA_NETA_ANT_CAL,0)
        				  WHEN RH_MAYOR_ANIO_RC = v_const_s THEN TBL.PRIMA_NETA_ASEGURADO / 2
        				  END 
        		ELSE TBL.PRIMA_COMISIONABLE_ASEG
        	END  ) AS PRIMA_COMISIONABLE_ASEG_2
        	
            
        FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_3 TBL  
        LEFT JOIN :TBL_PRIMA_NETA_ANT_CAL_RC TMP
                ON TMP.CODIGO_POLIZA = TBL.CODIGO_POLIZA_CALC
                AND TMP.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO_CALC
                AND TMP.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE_CALC
                AND TMP.CODIGO_RECIBO = IFNULL(CODIGO_RECIBO_ANT, :v_const_cod_recibo_ini)
                AND TMP.CODIGO_POLIZA_ACTUAL = TBL.CODIGO_POLIZA
        
        ;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
  
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4_DEBUG AS (SELECT * FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
  
  
   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_ASEGURADO para TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_1 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_ASEGURADO GA
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4 src
        WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND GA.NUM_ORDEN_MOVIMIENTO = src.NUM_ORDEN_MOVIMIENTO
            AND GA.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
     
        MERGE INTO EXT.GARANTIAS_ASEGURADO GA
        USING(
            SELECT DISTINCT CODIGO_POLIZA, NUMERO_ASEGURADO, PRODUCTO_CONTABLE, CODIGO_RECIBO, PRIMA_COMISIONABLE_ASEG
           FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4
        )src
        ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
        --AND GA.NUM_ORDEN_MOVIMIENTO = src.NUM_ORDEN_MOVIMIENTO
        --AND src.RN_GAR_ASE = 1
        WHEN MATCHED THEN UPDATE SET
        	GA.PRIMA_COMISIONABLE = PRIMA_COMISIONABLE_ASEG,
            /*GA.PC_PERIODO = PC_ASEGURADO,
            GA.NUM_PERIODOS = NUM_PERIODO,*/
            GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_ASEGURADO para TBL_GARANTIAS_ASEGURADO_ALTAPOLI_66_4. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;    
    
    ----------------------TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81 LINEA 2904    
    --Recibos 81 que llegan en el periodo donde parte ser� 72 y parte 81.
    --DESDOBLES 81 Y 72 (+)
    CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Comienzo calculo desdobles 81 y 72+' , i_log_count, i_id_proceso, 'info');


     TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81 = 
        SELECT GR.* 
        	/*, CASE WHEN (SELECT distinct v_const_s FROM EXT.ASEGURADOS T_ASEG
                        WHERE T_ASEG.CODIGO_POLIZA = GR.CODIGO_POLIZA
                        AND T_ASEG.NUMERO_ASEGURADO <> GR.NUMERO_ASEGURADO
                        AND T_ASEG.EDAD <= v_const_max_edad                        
        	)  = v_const_s THEN v_const_s ELSE v_const_n END AS EXISTEN_MENORES_70*/
        	, (SELECT MENSUALIDADES FROM VW_FORMAS_PAGO WHERE CODIGO = POL.FORMA_PAGO) AS MENSUALIDADES
           --,CODIGO_UNICO_AGENTE
           --,CODIGO_AGENTE_ORIGINAL
           --,GR.INSPECTOR
           --,POL.FORMA_PAGO AS FORMA_PAGO_POLIZA
           --,FECHA_COMPENSACION
           --,MOTIVO_BAJA AS MOTIVO_BAJA_POL
           --,GR.CODIGO_SUPLEMENTO AS CODIGO_SUP
           --,NUM_ORDEN_MOVIMIENTO
           --,FECHA_EFECTO_RECIBO
           --, EXTRACT(MONTH FROM POL.FECHA_EFECTO_POLIZA) AS FECHA_EFECTO_POLIZA
           , POL.FECHA_EFECTO_POLIZA
           , 12/(SELECT MENSUALIDADES FROM EXT.VW_FORMAS_PAGO WHERE CODIGO = POL.FORMA_PAGO) AS MESES_PERIODO
           -- 20260326 TGV -- por peticion de garcia fraile se hace por dias
           ,(12/(SELECT MENSUALIDADES FROM EXT.VW_FORMAS_PAGO WHERE CODIGO = POL.FORMA_PAGO)) * 30 AS DIAS_PERIODO
           
           --, GR.PRIMA_NETA_RECIBO AS PRIMA_COMISIONABLE_RECIBO_INI
           --,GR.ESTADO_RECIBO AS ESTADO_RECIBO_GR
           --,GR.PORCENTAJE_DESCUENTO_SOBRE_PC
           , ROW_NUMBER() OVER(
        		PARTITION BY GR.CODIGO_POLIZA, GR.CODIGO_RECIBO, GR.CODIGO_SUPLEMENTO
           ) AS RN_REC
           , ROW_NUMBER() OVER (
            	PARTITION BY GR.CODIGO_POLIZA, GR.CODIGO_RECIBO, GR.CODIGO_SUPLEMENTO, GR.ESTADO_RECIBO, GR.PRODUCTO_CONTABLE
            ) AS RN_GAR_REC
        FROM :TBL_GARANTIAS_RECIBO GR 
        INNER JOIN EXT.POLIZAS POL ON POL.CODIGO_POLIZA = GR.CODIGO_POLIZA
        	WHERE GR.PERMANENCIA = :v_const_recibos_cartera_81 AND IFNULL(GR.TIPO_MOVIMIENTO,'ZZ') <> v_const_tipo_mov_altapoli
        		--BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
                --TGV 20260229 Añadimos el producto 0129024 por peticion de Javier Garcia Fraile
	        	AND NOT ((((GR.OFICINA_GESTORA = '0900' OR GR.OFICINA_GESTORA = '900') AND GR.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560'))
                    or GR.CODIGO_POLIZA LIKE '0129024%')
	            	AND GR.PERMANENCIA <> v_const_recibos_cartera_81)
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
    
    TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_1 = 
        SELECT TBL.* 
            --¿estamos dentro del primer año?
        ,CASE WHEN FECHA_EFECTO_RECIBO < ADD_MONTHS(FECHA_EFECTO_POLIZA,12) AND ADD_MONTHS(FECHA_EFECTO_RECIBO, MESES_PERIODO) > ADD_MONTHS(FECHA_EFECTO_POLIZA, 12)
            --THEN MONTHS_BETWEEN(ADD_MONTHS(FECHA_EFECTO_POLIZA, 12), FECHA_EFECTO_RECIBO)
            --TGV 20260123 - se detacta un error en el orden de la resta de meses a raiz de un correo de Garcia Fraile 
            THEN MONTHS_BETWEEN(FECHA_EFECTO_RECIBO, ADD_MONTHS(FECHA_EFECTO_POLIZA, 12))
            ELSE 0
            END AS MESES_72
       -- 20260326 TGV -- por peticion de garcia fraile se hace por dias
        ,CASE WHEN FECHA_EFECTO_RECIBO < ADD_MONTHS(FECHA_EFECTO_POLIZA,12) AND ADD_MONTHS(FECHA_EFECTO_RECIBO, MESES_PERIODO) > ADD_MONTHS(FECHA_EFECTO_POLIZA, 12)
            THEN DAYS_BETWEEN(FECHA_EFECTO_RECIBO, ADD_MONTHS(FECHA_EFECTO_POLIZA, 12))
            ELSE 0
            END AS DIAS_72

        FROM :TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81 TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
    TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2 = 
        SELECT TBL.*
        --BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
        --TGV 20260229 Añadimos el producto 0129024 por peticion de Javier Garcia Fraile
        /*,CASE WHEN ((OFICINA_GESTORA = '0900' OR OFICINA_GESTORA = '900' ) AND CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560') 
                    or CODIGO_POLIZA LIKE '0129024%')
            THEN (PRIMA_NETA_RECIBO/MESES_PERIODO) *MESES_72 ELSE 0 END */
        ,(PRIMA_NETA_RECIBO/MESES_PERIODO) *MESES_72 AS PRIMA_COMISIONABLE_72
        ,(PRIMA_NETA_RECIBO / MESES_PERIODO) * (MESES_PERIODO - MESES_72) 
        AS PRIMA_COMISIONABLE_RECIBO

         -- 20260326 TGV -- por peticion de garcia fraile se hace por dias

        /*,CASE WHEN ((OFICINA_GESTORA = '0900' OR OFICINA_GESTORA = '900' ) AND CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560') 
                    or CODIGO_POLIZA LIKE '0129024%')
            THEN (PRIMA_NETA_RECIBO/DIAS_PERIODO) * DIAS_72 ELSE 0 END */

        ,(PRIMA_NETA_RECIBO/DIAS_PERIODO) * DIAS_72 AS PRIMA_COMISIONABLE_72_DIAS
        ,(PRIMA_NETA_RECIBO / DIAS_PERIODO) * (DIAS_PERIODO - DIAS_72) 
        AS PRIMA_COMISIONABLE_RECIBO_DIAS



        --BRG 20251215 Añadido agente 00560 por petición de Cristian Sújar
        --TGV 20260229 Añadimos el producto 0129024 por peticion de Javier Garcia Fraile
        ,CASE WHEN ((OFICINA_GESTORA = '0900' OR OFICINA_GESTORA = '900' ) AND CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560') 
                 or CODIGO_POLIZA LIKE '0129024%')
            THEN 60 ELSE PORCENTAJE_COMISION_CALCULAD END 
        AS PORC_COMI    /*, 
        ROW_NUMBER() OVER (
			            PARTITION BY TBL.CODIGO_POLIZA ,
						TBL.CODIGO_RECIBO ,
						TBL.CODIGO_SUPLEMENTO ,
						TBL.ESTADO_RECIBO,
						TBL.PERMANENCIA
			            ORDER BY TBL.CODIGO_POLIZA ASC
		) AS ROW_NUM_R,
		ROW_NUMBER() OVER (
			            PARTITION BY TBL.CODIGO_POLIZA ,
						TBL.CODIGO_RECIBO ,
						TBL.CODIGO_SUPLEMENTO ,
						TBL.ESTADO_RECIBO,
						TBL.PRODUCTO_CONTABLE,
						TBL.PERMANENCIA
			            ORDER BY TBL.CODIGO_POLIZA ASC
		) AS ROW_NUM_GR*/
        FROM :TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_1 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
	 ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2_DEBUG AS (SELECT * FROM :TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2_DEBUG' , i_log_count, i_id_proceso, 'debug');
	 ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR


            -- ITL modificado orden de campos 
    INSERT INTO EXT.RECIBOS
        SELECT  TBL.IDENTIFICADOR,                  
                TBL.FILE_NAME,   
                --TBL.ESTADO,                
                v_const_calculo_status_ok, -- el estado debe ser calculo ok -- 6                
                TBL.FECHA_MODIFICACION, 
                TBL.CODIGO_POLIZA,          
                TBL.CODIGO_RECIBO||'+',     
                v_const_recibos_cartera_72, 
                TBL.TIPO_RECIBO,            
                TBL.ESTADO_RECIBO,              
                TBL.FECHA_COBRO,                
                TBL.FECHA_COMPENSACION,     
                TBL.FECHA_EFECTO_RECIBO,    
                TBL.FECHA_VTO_RECIBO,           
                TBL.TIPO_MOVIMIENTO,            
                TBL.PORCENTAJE_DESCUENTO_SOBRE_PC,
                TBL.VALOR_POLIZA,               
                TBL.CODIGO_UNICO_AGENTE,    
                TBL.CODIGO_AGENTE_ORIGINAL, 
                TBL.INSPECTOR,              
                TBL.OFICINA_COBRADORA,      
                TBL.OFICINA_GESTORA,        
                TBL.MARCA_RECUPERADO,           
                TBL.MARCA_CUENTA,               
                TBL.PRIMER_RECIBO,              
                TBL.ASEGURADOS_NETOS,           
                TBL.AUMENTO_ASEGURADOS,         
                TBL.EXCLUIDO_COMISIONES,        
                TBL.BONIFICACION_POLIZA,        
                TBL.DISMINUCION_PRIMA,          
                TBL.TIPO_RECUPERACION,          
               -- TBL.ES_PERMANENCIA_20,  
                --20260408 - TGV --Para los 72 + hay que poner el es_permanencia_20 a N para que no se generen las transacctiones tipo 20 
                v_const_n,      
                TBL.CODIGO_AGENTE_COMMISSIONS,  
                TBL.FECHA_EMISION_REC,          
                TBL.FCHA_EFECTO_SUPLEMENTO,     
                TBL.CODIGO_SUPLEMENTO,      
                TBL.DISTRITO_COBRO,             
                TBL.CODIGO_SINIESTRO,   
                TBL.ZONA_EXPLOTACION,       
                TBL.CODIGO_AGENTE_ZONA                          
        FROM :TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2 TBL
        WHERE (SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) = '0'
        	--and ROW_NUM_R = 1
        	--AND TBL.RN_REC = 1--Nos quedamos con un único recibo
        	--AND TBL.FECHA_EFECTO_RECIBO < ADD_MONTHS(TBL.FECHA_EFECTO_POLIZA,12) 
            --AND ADD_MONTHS(TBL.FECHA_EFECTO_RECIBO, TBL.MESES_PERIODO) > ADD_MONTHS(TBL.FECHA_EFECTO_POLIZA, 12)
            -- 20260326 TGV -- por peticion de garcia fraile se hace por dias
            AND TBL.FECHA_EFECTO_RECIBO < ADD_DAYS(TBL.FECHA_EFECTO_POLIZA,365) 
            AND ADD_DAYS(TBL.FECHA_EFECTO_RECIBO, TBL.DIAS_PERIODO) > ADD_DAYS(TBL.FECHA_EFECTO_POLIZA, 365)
            --20260406 TGV -- se incluye una comprobacion para evitar duplicados en las cargar de derechos de WF DDEE
            AND NOT EXISTS (
				SELECT 1 FROM EXT.RECIBOS R
				WHERE R.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                AND R.CODIGO_RECIBO = TBL.CODIGO_RECIBO||'+'
                AND R.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                AND R.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
			)
            --TGV 20260408 -- no se deben generar los recibos 72(+) para las comisiones anticipadas
            /*AND 1 = CASE WHEN ((TBL.OFICINA_GESTORA = '0900' OR TBL.OFICINA_GESTORA = '900' ) AND TBL.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560') 
                    or TBL.CODIGO_POLIZA LIKE '0129024%') THEN 1 ELSE 0 END*/
            )
            
        ;
    v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en RECIBOS: ' || v_num_rows , i_log_count, i_id_proceso, 'info');    
        
        -- ITL modificado orden de campos 
    INSERT INTO EXT.GARANTIAS_RECIBO
        SELECT  --IDENTIFICADOR,
                TBL.ID_RECIBO,
                TBL.FILE_NAME,
                TBL.ESTADO,
                TBL.FECHA_MODIFICACION,
                TBL.CODIGO_POLIZA,
                TBL.CODIGO_RECIBO || '+',
                TBL.PRODUCTO_CONTABLE,
                TBL.ESTADO_RECIBO,
                TBL.PRIMA_NETA_RECIBO,
                TBL.PRIMA_BRUTA_RECIBO,
                TBL.RECARGO,
                TBL.PORCENTAJE_BONIFICACION,
                --TGV 20260123 -------------------------------
                --TBL.INCREMENTO_PRIMA_ANUAL,
                --TBL.PRIMA_COMISIONABLE,
                --TBL.PRIMA_COMISIONABLE_72,
                --TBL.PRIMA_COMISIONABLE_72,
                -- 20260326 TGV -- por peticion de garcia fraile se hace por dias
                CASE WHEN ((TBL.OFICINA_GESTORA = '0900' OR TBL.OFICINA_GESTORA = '900' ) AND TBL.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560') 
                    or TBL.CODIGO_POLIZA LIKE '0129024%') THEN ROUND(TBL.PRIMA_COMISIONABLE_72_DIAS,2) ELSE 0 END,
                CASE WHEN ((TBL.OFICINA_GESTORA = '0900' OR TBL.OFICINA_GESTORA = '900' ) AND TBL.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560') 
                    or TBL.CODIGO_POLIZA LIKE '0129024%') THEN ROUND(TBL.PRIMA_COMISIONABLE_72_DIAS,2) ELSE 0 END,
                TBL.UNIDAD_DE_POLIZA,
                TBL.MESES_COBRADOS,
                TBL.FECHA_ALTA_GAR_POL,
                TBL.FECHA_BAJA_GAR_POL,
                TBL.PORCENTAJE_NIVELADA,
                TBL.PERIODO_EXTORNABLE,
                '0' , --TBL.INDICADOR_COMISION_CALCULADA, --20260408 TGV -- Por peticion de David el indicador de los 72 (+) debe ser siempre 0
                '0', --TBL.INDICADOR_PORCENTAJE_CALCULA,  ----20260408 TGV -- Por peticion de David el indicador de los 72 (+) debe ser siempre 0
                TBL.PORCENTAJE_COMISION_CALCULAD,
                TBL.IMPORTE_COMISION,
                TBL.PRIMA_UNICA,
                TBL.NUM_ORDEN_MOVIMIENTO,
                TBL.AUMENTO_CAPITALES_GARANTIA,
                TBL.PRIMA_NETA_ANUALIZADA,
                TBL.PORC_COMISION_NP,
                TBL.PORC_COMISION_CONSERVACION,
                TBL.CODIGO_SUPLEMENTO,
                TBL.PORC_COMISION_COBRO
            
                FROM :TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2 TBL 
        	WHERE --SUBSTR(TBL.PRODUCTO_CONTABLE,5,1) = '0'
        		--ROW_NUM_GR = 1
        		--AND TBL.RN_GAR_REC = 1
        		--TBL.FECHA_EFECTO_RECIBO < ADD_MONTHS(TBL.FECHA_EFECTO_POLIZA,12) AND ADD_MONTHS(TBL.FECHA_EFECTO_RECIBO, TBL.MESES_PERIODO) > ADD_MONTHS(TBL.FECHA_EFECTO_POLIZA, 12)
        	    -- 20260326 TGV -- por peticion de garcia fraile se hace por dias
                (TBL.FECHA_EFECTO_RECIBO < ADD_DAYS(TBL.FECHA_EFECTO_POLIZA,635) 
                AND ADD_DAYS(TBL.FECHA_EFECTO_RECIBO, TBL.DIAS_PERIODO) > ADD_DAYS(TBL.FECHA_EFECTO_POLIZA, 365)
                --TGV 20260408 -- no se deben generar los recibos 72(+) para las comisiones anticipadas
              /*  AND 1 = CASE WHEN ((TBL.OFICINA_GESTORA = '0900' OR TBL.OFICINA_GESTORA = '900' ) AND TBL.CODIGO_UNICO_AGENTE NOT IN ('0900000579','0900000580','0900000442','0900000560') 
                    or TBL.CODIGO_POLIZA LIKE '0129024%') THEN 1 ELSE 0 END*/
                )
             
            ; 

        
    v_num_rows := ::rowcount;
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin INSERT en GARANTIAS_RECIBO: ' || v_num_rows , i_log_count, i_id_proceso, 'info'); 

   

    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en GARANTIAS_RECIBO  en EXT.RECIBOS para TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_RECIBO REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_RECIBO REC, :TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2 src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND REC.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;    
    
        MERGE INTO EXT.GARANTIAS_RECIBO GR
        USING(
            SELECT DISTINCT CODIGO_POLIZA
            		, PRODUCTO_CONTABLE
            		, CODIGO_RECIBO
            		, CODIGO_SUPLEMENTO
            		, ESTADO_RECIBO
            		, PRIMA_COMISIONABLE_RECIBO
            		, PORCENTAJE_DESCUENTO_SOBRE_PC
            		, RN_GAR_REC
                    , PRIMA_NETA_RECIBO
                    , PRIMA_COMISIONABLE_72_DIAS
            		FROM :TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2
        )src
        ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
                AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
                AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
                AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
                AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
                AND src.RN_GAR_REC = 1
        WHEN MATCHED THEN UPDATE SET
            --GR.PRIMA_COMISIONABLE = src.PRIMA_COMISIONABLE_RECIBO * (1-IFNULL(src.PORCENTAJE_DESCUENTO_SOBRE_PC,0)),
            --GR.INCREMENTO_PRIMA_ANUAL = src.PRIMA_COMISIONABLE_RECIBO,
            --20260408 -TGV -- Tras reunion con Araque, David y Javier, se decide actualizar la prima del 81 a la resta de la prima_neta - prima del 72(+)
            GR.PRIMA_COMISIONABLE = src.PRIMA_NETA_RECIBO - ROUND(src.PRIMA_COMISIONABLE_72_DIAS,2),
            GR.INCREMENTO_PRIMA_ANUAL = src.PRIMA_NETA_RECIBO - ROUND(src.PRIMA_COMISIONABLE_72_DIAS,2),
            GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para TBL_GARANTIAS_ASEGURADO_NO_ALTAPOLI_81_2. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');

    END;    

      ----------------------TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72 LINEA 2916  
   
    -- Temporal para EXISTEN_MENORES_70
    --TGV 20250827 -- AÑADIMOS INNER CON TBL_ASEGURADO PARA QUE SOLO NOS OBTENGA LAS FILAS NECESARIAS
    TBL_EXISTEN_MENORES_70 =
        SELECT DISTINCT
            T_ASEG.CODIGO_POLIZA,
            v_const_s AS EXISTEN_MENORES_70
        FROM EXT.ASEGURADOS T_ASEG 
        INNER JOIN :TBL_ASEGURADOS TBL
        ON T_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND T_ASEG.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
        WHERE T_ASEG.EDAD <= v_const_max_edad
    ;
    v_num_rows = RECORD_COUNT(:TBL_EXISTEN_MENORES_70);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_EXISTEN_MENORES_70 ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

    -- Temporal para MENSUALIDADES
    TBL_MENSUALIDADES =
        SELECT MFP.CODIGO, MFP.MENSUALIDADES
        FROM VW_FORMAS_PAGO MFP
    ;
    v_num_rows = RECORD_COUNT(:TBL_MENSUALIDADES);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MENSUALIDADES ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

    -- Temporal para CODIGO_RECIBO_ANT
    TBL_CODIGO_RECIBO_ANT =
        SELECT
            TBL.CODIGO_POLIZA,
            TBL.CODIGO_RECIBO,
            T_REC.CODIGO_RECIBO AS CODIGO_RECIBO_ANT,
            ROW_NUMBER() OVER (
                PARTITION BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO
                ORDER BY T_REC.FECHA_COBRO DESC
            ) AS RN
        FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION TBL
        JOIN EXT.RECIBOS T_REC
            ON T_REC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND T_REC.CODIGO_RECIBO <> TBL.CODIGO_RECIBO
        AND T_REC.MARCA_CUENTA = v_const_s
        AND T_REC.CODIGO_RECIBO <> v_const_cod_recibo_anul_rrtt
        JOIN EXT.GARANTIAS_ASEGURADO T_GAR
            ON T_GAR.CODIGO_POLIZA = T_REC.CODIGO_POLIZA
        AND T_GAR.CODIGO_RECIBO = T_REC.CODIGO_RECIBO
        WHERE
            (TRIM(TBL.PRODUCTO_CONTABLE) IS NULL 
            OR (TRIM(TBL.PRODUCTO_CONTABLE) IS NOT NULL AND T_GAR.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE))
        OR (TRIM(TBL.NUMERO_ASEGURADO) IS NULL
            OR (TRIM(TBL.NUMERO_ASEGURADO) IS NOT NULL AND T_GAR.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO))
    ;
    v_num_rows = RECORD_COUNT(:TBL_CODIGO_RECIBO_ANT);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_CODIGO_RECIBO_ANT ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

    -- Consulta final sin subconsultas con alias
    TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72 =
        SELECT
            TBL.*,
            COALESCE(MENOR70.EXISTEN_MENORES_70, v_const_n) AS EXISTEN_MENORES_70,
            MENS.MENSUALIDADES,
            REC_ANT.CODIGO_RECIBO_ANT,
            CODIGO_UNICO_AGENTE,
            CODIGO_AGENTE_ORIGINAL,
            GR.INSPECTOR,
            POL.FORMA_PAGO AS FORMA_PAGO_POLIZA,
            FECHA_COMPENSACION,
            MOTIVO_BAJA AS MOTIVO_BAJA_POL,
            GR.CODIGO_SUPLEMENTO AS CODIGO_SUP,
            GR.NUM_ORDEN_MOVIMIENTO,
            GR.FECHA_EFECTO_RECIBO,
            EXTRACT(MONTH FROM POL.FECHA_EFECTO_POLIZA) AS FECHA_EFECTO_POLIZA,
            12 / MENS.MENSUALIDADES AS MESES_PERIODO,
            TBL.PRIMA_NETA_RECIBO AS PRIMA_COMISIONABLE_RECIBO_INI,
            GR.ESTADO_RECIBO AS ESTADO_RECIBO_GR,
            GR.PORCENTAJE_DESCUENTO_SOBRE_PC,
            OFICINA_COBRADORA
        FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION TBL
        INNER JOIN EXT.POLIZAS POL
            ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
        INNER JOIN :TBL_GARANTIAS_RECIBO GR
            ON TBL.CODIGO_POLIZA = GR.CODIGO_POLIZA
	        AND TBL.CODIGO_RECIBO = GR.CODIGO_RECIBO
	        AND TBL.CODIGO_SUPLEMENTO = GR.CODIGO_SUPLEMENTO
	        AND TBL.PRODUCTO_CONTABLE = GR.PRODUCTO_CONTABLE
	        AND TBL.ESTADO_RECIBO = GR.ESTADO_RECIBO
        LEFT JOIN :TBL_EXISTEN_MENORES_70 MENOR70
            ON TBL.CODIGO_POLIZA = MENOR70.CODIGO_POLIZA
        LEFT JOIN :TBL_MENSUALIDADES MENS
            ON POL.FORMA_PAGO = MENS.CODIGO
        LEFT JOIN :TBL_CODIGO_RECIBO_ANT REC_ANT
            ON TBL.CODIGO_POLIZA = REC_ANT.CODIGO_POLIZA
        	AND TBL.CODIGO_RECIBO = REC_ANT.CODIGO_RECIBO
	        AND REC_ANT.RN = 1
	        WHERE TBL.PERMANENCIA = v_const_recibos_cartera_72
    ;
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72);
    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72 ' || v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');


    TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1 = 
        SELECT  TBL.*
                ,CASE WHEN COMISION_ANTICIPADA = v_const_s and OFICINA_GESTORA <> v_const_oficina_seci AND  OFICINA_COBRADORA <> v_const_oficina_seci THEN
                    CASE WHEN RIGHT(OFICINA_GESTORA, 3) = v_const_oficina_seci OR RIGHT(OFICINA_COBRADORA, 3) = v_const_oficina_seci THEN PRIMA_NETA_RECIBO ELSE 0 END
                
                ELSE 
                    (SELECT (SUM(T_GAR_ASEG.PRIMA_NETA_ASEGURADO) / MENSUALIDADES)
                        FROM EXT.GARANTIAS_ASEGURADO T_GAR_ASEG
                        INNER JOIN EXT.ASEGURADOS T_ASEG
                            ON (T_ASEG.CODIGO_POLIZA = T_GAR_ASEG.CODIGO_POLIZA
                            AND T_ASEG.NUMERO_ASEGURADO = T_GAR_ASEG.NUMERO_ASEGURADO)
                        LEFT JOIN EXT.RECIBOS T_REC
                            ON (T_REC.CODIGO_POLIZA = T_GAR_ASEG.CODIGO_POLIZA
                            AND T_GAR_ASEG.CODIGO_RECIBO = T_REC.CODIGO_RECIBO
                            AND T_REC.PERMANENCIA IN (v_const_recibos_especificos_71))
                    WHERE T_GAR_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    AND T_GAR_ASEG.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
                    AND T_GAR_ASEG.FECHA_BAJA_GAR_ASE IS NULL
                    AND (T_REC.ESTADO_RECIBO ='C' OR T_REC.ESTADO_RECIBO IS NULL)
                    AND (T_ASEG.FECHA_BAJA IS NULL OR (T_ASEG.FECHA_BAJA IS NOT NULL AND T_ASEG.FECHA_REHABILITACION IS NOT NULL))
                    AND T_ASEG.EDAD_DERECHOS <= 70)
                
                END 
                AS PRIMA_COMISIONABLE_RECIBO
        FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72 TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1_DEBUG AS (SELECT * FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1_DEBUG' , i_log_count, i_id_proceso, 'debug');
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBO para TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_RECIBO REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_RECIBO REC, :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1 src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO_GR
            AND REC.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
    
        MERGE INTO EXT.GARANTIAS_RECIBO GR
        USING(
            SELECT * FROM :TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1
        )src
        ON  GR.CODIGO_POLIZA = src.CODIGO_POLIZA
              AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
              AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
              AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
              AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
        WHEN MATCHED THEN UPDATE SET
            GR.PRIMA_COMISIONABLE = CASE WHEN MOTIVO_ALTA = v_const_motivo_alta_np and src.PRODUCTO_CONTABLE LIKE '0123%'
               and src.FECHA_EMISION_POLIZA < TO_DATE ('14/12/2020', 'dd/mm/yyyy') THEN src.PRIMA_NETA_RECIBO ELSE src.PRIMA_COMISIONABLE_RECIBO END ,
            GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para TBL_GARANTIAS_ASEGURADO_ALTAPOLI_72_1. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;    
    
   
    
    -- Tabla final con todos los datos y sin subconsultas en el SELECT
    TBL_GARANTIAS_RECIBOS_10_20 =
        SELECT 
            TBL.*
        FROM :TBL_GARANTIAS_RECIBO TBL
        WHERE TBL.PERMANENCIA IN (v_const_recibos_especificos_10 , v_const_recibos_especificos_20)
    ;
    v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_RECIBOS_10_20);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_RECIBOS_10_20: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');

    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBO para TBL_GARANTIAS_RECIBOS_10_20 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_RECIBO REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_RECIBO REC, :TBL_GARANTIAS_RECIBOS_10_20 src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND rec.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;    
            ------------------------------------------------UPDATE PARA LAS 10 Y 20    
        MERGE INTO EXT.GARANTIAS_RECIBO GR
        USING(
            SELECT * FROM :TBL_GARANTIAS_RECIBOS_10_20
        )src
        ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
          AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
          AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
          AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
        WHEN MATCHED THEN UPDATE SET
            GR.PRIMA_COMISIONABLE = src.PRIMA_NETA_RECIBO
            , GR.INCREMENTO_PRIMA_ANUAL = 0
            , GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para TBL_GARANTIAS_RECIBOS_10_20. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
        
    END;    
    
    TBL_GARANTIAS_ASEGURADO_RESTO = 
        SELECT TBL.* 
        , CASE WHEN (SELECT DISTINCT 1 FROM EXT.ASEGURADOS T_ASEG
                        WHERE T_ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                        AND T_ASEG.NUMERO_ASEGURADO <> TBL.NUMERO_ASEGURADO
                        AND T_ASEG.EDAD <= v_const_max_edad                        
          )  = 1 THEN v_const_s ELSE v_const_n END 
          AS EXISTEN_MENORES_70
          , (SELECT MENSUALIDADES FROM VW_FORMAS_PAGO WHERE CODIGO = POL.FORMA_PAGO) 
          AS MENSUALIDADES
          --,( SELECT MAX(T_RECIBOS.CODIGO_RECIBO)
          --  FROM EXT.RECIBOS T_RECIBOS,
          --      EXT.GARANTIAS_ASEGURADO T_GAR_ASEG
          --  WHERE T_RECIBOS.CODIGO_POLIZA = TBL.CODIGO_POLIZA 
          --      AND T_RECIBOS.CODIGO_RECIBO <> TBL.CODIGO_RECIBO
          --      AND T_RECIBOS.MARCA_CUENTA = v_const_s
          --      AND T_GAR_ASEG.CODIGO_POLIZA = T_RECIBOS.CODIGO_POLIZA   
          --      AND T_GAR_ASEG.CODIGO_RECIBO = T_RECIBOS.CODIGO_RECIBO
          --      AND T_RECIBOS.CODIGO_RECIBO NOT IN (v_const_cod_recibo_anul_rrtt, v_const_cod_recibo_anul_serco, v_const_cod_recibo_serco)
          --      AND ((TRIM(TBL.PRODUCTO_CONTABLE) IS NULL OR ( TRIM(TBL.PRODUCTO_CONTABLE) IS NOT NULL AND T_GAR_ASEG.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE))
          --          OR (TRIM(TBL.NUMERO_ASEGURADO) IS NULL OR (TRIM(TBL.NUMERO_ASEGURADO) IS NOT NULL AND T_GAR_ASEG.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO)))      
          -- ) AS CODIGO_RECIBO_ANT
           ,CODIGO_UNICO_AGENTE
           ,CODIGO_AGENTE_ORIGINAL
           ,GR.INSPECTOR
           ,POL.FORMA_PAGO AS FORMA_PAGO_POLIZA
           ,FECHA_COMPENSACION
           ,MOTIVO_BAJA AS MOTIVO_BAJA_POL
           ,GR.CODIGO_SUPLEMENTO AS CODIGO_SUP
           ,NUM_ORDEN_MOVIMIENTO
           ,FECHA_EFECTO_RECIBO
           , EXTRACT(MONTH FROM POL.FECHA_EFECTO_POLIZA) AS FECHA_EFECTO_POLIZA
           ,12/(SELECT MENSUALIDADES FROM VW_FORMAS_PAGO WHERE CODIGO = POL.FORMA_PAGO) AS MESES_PERIODO
           ,TBL.PRIMA_NETA_RECIBO AS PRIMA_COMISIONABLE_RECIBO_INI
           --,GR.ESTADO_RECIBO
           ,GR.PORCENTAJE_DESCUENTO_SOBRE_PC
           ,OFICINA_COBRADORA
           ,(SELECT SUM(PRIMA_COMISIONABLE)
                          FROM EXT.GARANTIAS_ASEGURADO GA
                          WHERE GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                          AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO  
                          AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
                         
            
           ) AS SUM_PRIMA_COMISIONABLE
           ,(SELECT SUM(PRIMA_NETA_ASEGURADO)
                          FROM EXT.GARANTIAS_ASEGURADO GA
                          WHERE GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                          AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO  
                          AND GA.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
         
           ) AS INCREMENTO_PRIMA_ANUAL
           , ROW_NUMBER () OVER(
           		PARTITION BY TBL.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO, TBL.CODIGO_RECIBO, TBL.PRODUCTO_CONTABLE
           		ORDER BY TBL.CODIGO_RECIBO
           ) AS RN_GAR_ASE
        FROM :TBL_GARANTIAS_ASEGURADO_REHABILITACION TBL 
        INNER JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA 
        INNER JOIN :TBL_GARANTIAS_RECIBO GR ON TBL.CODIGO_POLIZA = GR.CODIGO_POLIZA AND TBL.CODIGO_RECIBO = GR.CODIGO_RECIBO AND tbl.CODIGO_SUPLEMENTO = gr.CODIGO_SUPLEMENTO AND TBL.PRODUCTO_CONTABLE = GR.PRODUCTO_CONTABLE
        WHERE TBL.PERMANENCIA NOT IN (v_const_recibos_especificos_10 , v_const_recibos_especificos_20, v_const_recibos_cartera_81)
        OR (TBL.PERMANENCIA = v_const_recibos_cartera_81 AND (TIPO_MOVIMIENTO <> v_const_tipo_mov_altapoli OR TIPO_MOVIMIENTO IS NULL));    
        
	 v_num_rows = RECORD_COUNT(:TBL_GARANTIAS_ASEGURADO_RESTO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_GARANTIAS_ASEGURADO_RESTO '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
	
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE en EXT.GARANTIAS_RECIBO para TBL_GARANTIAS_ASEGURADO_RESTO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_RECIBO REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_RECIBO REC, :TBL_GARANTIAS_ASEGURADO_RESTO src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND rec.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
            AND rec.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;    
        --F_UPDATE_GAR_RECIBO_PRIMACOMIS 2949
        MERGE INTO EXT.GARANTIAS_RECIBO GR
        USING(
            SELECT DISTINCT CODIGO_POLIZA
            				, CODIGO_RECIBO
            				, PRODUCTO_CONTABLE
            				, ESTADO_RECIBO
            				, CODIGO_SUPLEMENTO
            				, PRIMA_NETA_RECIBO
            				, SUM_PRIMA_COMISIONABLE
            				, INCREMENTO_PRIMA_ANUAL
            				, OFICINA_GESTORA
            				, PERMANENCIA
            				, PORCENTAJE_DESCUENTO_SOBRE_PC
            				, RN_GAR_ASE
            				FROM :TBL_GARANTIAS_ASEGURADO_RESTO
        )src
        ON  GR.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
            AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND src.RN_GAR_ASE = 1
        WHEN MATCHED THEN UPDATE SET
            GR.PRIMA_COMISIONABLE = CASE WHEN src.OFICINA_GESTORA = v_const_corte_ingles THEN src.PRIMA_NETA_RECIBO 
                                        WHEN src.PERMANENCIA IN (v_const_recibos_especificos_10,v_const_recibos_especificos_20,v_const_recibos_cartera_81,v_const_recibos_cartera_72) THEN src.PRIMA_NETA_RECIBO 
                                        ELSE src.SUM_PRIMA_COMISIONABLE * (1- IFNULL(src.PORCENTAJE_DESCUENTO_SOBRE_PC,0))
                                    END 
            ,GR.INCREMENTO_PRIMA_ANUAL = CASE WHEN src.OFICINA_GESTORA = v_const_corte_ingles THEN src.INCREMENTO_PRIMA_ANUAL
                WHEN PERMANENCIA IN (v_const_recibos_especificos_10,v_const_recibos_especificos_20,v_const_recibos_cartera_81,v_const_recibos_cartera_72) THEN src.PRIMA_NETA_RECIBO
                ELSE  src.SUM_PRIMA_COMISIONABLE
                END
            ,GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
        
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para TBL_GARANTIAS_ASEGURADO_RESTO. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;    
        
    --LA UNIDAD DE POLIZA SOLO SE CALCULA PARA LAS PERMANENCIAS 71,66 Y 65
    -- TBL_UNIDAD_POLIZA = 
    --     SELECT TBL.* 
    --         ,( SELECT distinct v_const_n
    --           FROM EXT.ASEGURADOS ASEG
    --          WHERE ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    --           AND (ASEG.CONTO_COMO_ALTA IN (v_const_s_1, v_const_s)
    --             OR ASEG.MOTIVO_ALTA IN (SELECT MA.CODIGO FROM VW_MOTIVOS_ALTA MA WHERE MA.CUENTA_COMO_ALTA = '1'))
    --           )
    --           AS ES_SIN_INCLUSION_ASEG
    --     FROM :TBL_RECIBOS_71_66_65 TBL;
    
    TBL_RECIBOS_71_66_65_UNI_POL =
        SELECT R.* FROM EXT.RECIBOS R 
        WHERE R.FILE_NAME = i_file_name and R.ESTADO = v_const_populate_status_ok 
        AND R.PERMANENCIA IN ( v_const_recibos_especificos_66,v_const_recibos_especificos_65,v_const_recibos_especificos_71);
        
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_71_66_65_UNI_POL);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_71_66_65_UNI_POL '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    --JGE 20250819 rehacer la consulta completando las condiciones que faltan
    TBL_UNIDAD_POLIZA = (
    	SELECT 
    		TBL.*, 
    		CASE WHEN (ifnull(TBL.ASEGURADOS_NETOS,0) = 0 AND TBL.PERMANENCIA <> v_const_recibos_especificos_66) THEN 0
    			 WHEN SUBSTR(TBL.CODIGO_POLIZA,5,1) <> 0 THEN 0
    			 WHEN TBL.PERMANENCIA = v_const_recibos_especificos_71 AND ASE.MOTIVO_ALTA = v_const_motivo_alta_de AND NOT EXISTS (
    					--corresponde a la funcion en oracle ES_SIN_INCLUSION_ASEG
	    			 	SELECT 1
			            FROM EXT.ASEGURADOS ASEG
			            WHERE ASEG.CODIGO_POLIZA = TBL.CODIGO_POLIZA
			            AND (ASEG.CONTO_COMO_ALTA IN (v_const_s_1, v_const_s)
			            OR ASEG.MOTIVO_ALTA IN (SELECT MA.CODIGO FROM VW_MOTIVOS_ALTA MA WHERE MA.CUENTA_COMO_ALTA = '1'))
	    			 ) THEN 
	    			
	    				(
    						SELECT T_PRODUCTOS.UNIDAD_DE_POLIZA
			            	FROM EXT.VW_GEN_PRODUCTOS T_PRODUCTOS
			            	WHERE T_PRODUCTOS.CODIGO = substr(TBL.CODIGO_POLIZA,1,2)|| substr(TBL.CODIGO_POLIZA,3,5) 
	    				)
	    			
	    	END AS v_unidad_de_poliza
		FROM EXT.ASEGURADOS ASE
    	JOIN :TBL_RECIBOS_71_66_65_UNI_POL TBL
    	ON ASE.CODIGO_POLIZA = TBL.CODIGO_POLIZA
    	
    );
    
    v_num_rows = RECORD_COUNT(:TBL_UNIDAD_POLIZA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_UNIDAD_POLIZA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_UNIDAD_POLIZA_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_UNIDAD_POLIZA_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_UNIDAD_POLIZA_DEBUG AS (SELECT * FROM :TBL_UNIDAD_POLIZA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_UNIDAD_POLIZA_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    
    TBL_ASEGURADOS_UNIDAD_POLIZA =  
            SELECT 
            ASE.EDAD,
            ASE.CONTO_COMO_NUEVO,
            ASE.NUMERO_ASEGURADO,
            ASE.FECHA_ALTA, 
            ASE.MOTIVO_ALTA, 
            GA.PRIMA_UNICA,
            TBL.CODIGO_POLIZA,
            TBL.CODIGO_RECIBO,
            TBL.PERMANENCIA,
            TBL.FECHA_EFECTO_RECIBO,
            TBL.CODIGO_SUPLEMENTO,
            TBL.ESTADO_RECIBO,
            TBL.FECHA_COMPENSACION
            FROM EXT.ASEGURADOS ASE INNER JOIN  EXT.GARANTIAS_ASEGURADO GA  
	            ON ASE.CODIGO_POLIZA = GA.CODIGO_POLIZA
	            AND ASE.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
	             
            INNER JOIN :TBL_UNIDAD_POLIZA  TBL 
            ON TBL.CODIGO_POLIZA = GA.CODIGO_POLIZA AND TBL.CODIGO_RECIBO= GA.CODIGO_RECIBO
            WHERE IFNULL(v_unidad_de_poliza,2) NOT IN (v_const_n_0, v_const_s_1)
            AND (ASE.FECHA_BAJA IS NULL OR (
		            ASE.FECHA_BAJA IS NOT NULL AND 
		            GA.SUBTIPO_MOVIMIENTO = v_const_tipo_mov_rehabili AND 
		            ASE.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO
		            ))
            GROUP BY 
            ASE.EDAD,
            ASE.CONTO_COMO_NUEVO,
            ASE.NUMERO_ASEGURADO, 
            ASE.FECHA_ALTA, 
            ASE.MOTIVO_ALTA, 
            GA.PRIMA_UNICA,
            TBL.CODIGO_POLIZA,
            TBL.CODIGO_RECIBO,
            TBL.PERMANENCIA,
            TBL.FECHA_EFECTO_RECIBO,
            TBL.CODIGO_SUPLEMENTO,
            TBL.ESTADO_RECIBO,
            TBL.FECHA_COMPENSACION
            ;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_1 = 
        SELECT  TBL.* 
                ,CASE WHEN CONTO_COMO_NUEVO IS NULL AND TBL.MOTIVO_ALTA = v_const_motivo_alta_de THEN 
                    (SELECT COUNT(T.MOTIVO_ALTA) 
                            FROM EXT.ASEGURADOS T
                            WHERE T.CODIGO_POLIZA = TBL.CODIGO_POLIZA  
                            AND T.MOTIVO_ALTA IN (v_const_motivo_alta_np,v_const_motivo_alta_co)) ELSE v_const_n_0
                END AS ALTA_DE
                ,CASE WHEN INSTR(UPPER(POL.TIPO_CAMPANIA),v_const_campania_cruzada) > 0 THEN v_const_unidad_poliza_cruzada
                    	ELSE CASE WHEN POL.FECHA_EMISION_POLIZA >= TO_DATE ('19/05/2020', 'dd/mm/yyyy') THEN v_const_unidad_poliza_jun_2020
                    		ELSE v_const_unidad_poliza END
                END AS MULTIPLICADOR_UNIDAD_POLIZA
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA TBL 
            INNER JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_1_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_1_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_1_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_1_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en UPDATE  en EXT.ASEGURADOS para CONTO_COMO_NUEVO - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.ASEGURADOS A
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.ASEGURADOS A, :TBL_ASEGURADOS_UNIDAD_POLIZA_1 src
        WHERE A.CODIGO_POLIZA = src.CODIGO_POLIZA
           AND A.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
           AND( src.MOTIVO_ALTA IN (v_const_motivo_alta_np, v_const_motivo_alta_co, v_const_motivo_alta_rc, v_const_motivo_alta_re, v_const_motivo_alta_ro) OR ALTA_DE >0)
            AND A.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        MERGE INTO EXT.ASEGURADOS A
        USING ( 
            SELECT  DISTINCT TBL.CODIGO_POLIZA,
            				TBL.NUMERO_ASEGURADO
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_1 TBL
            WHERE (MOTIVO_ALTA IN (v_const_motivo_alta_np, v_const_motivo_alta_co, v_const_motivo_alta_rc, v_const_motivo_alta_re, v_const_motivo_alta_ro) OR ALTA_DE >0)
        )src
        ON A.CODIGO_POLIZA = src.CODIGO_POLIZA
           AND A.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
           --AND( src.MOTIVO_ALTA IN (v_const_motivo_alta_np, v_const_motivo_alta_co, v_const_motivo_alta_rc, v_const_motivo_alta_re, v_const_motivo_alta_ro) OR ALTA_DE >0)
        WHEN MATCHED THEN UPDATE SET
            CONTO_COMO_NUEVO = v_const_s_1,
            FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.ASEGURADOS para CONTO_COMO_NUEVO. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END; 
 
 --------------------------------FT_UNIDAD_DE_POLIZA_71 5346   
    TBL_ASEGURADOS_UNIDAD_POLIZA_71 = 
        SELECT GA.*,
        ASE.FECHA_ALTA,
        ASE.MOTIVO_ALTA,
        ASE.FECHA_BAJA,
        ASE.FECHA_REHABILITACION,
        ASE.POLIZA_ORIGEN,
        ASE.ASEGURADO_ORIGEN,
        ASE.EDAD,
        CASE WHEN ASE.EDAD <= v_const_max_edad
                  OR (ASE.EDAD > v_const_max_edad AND IFNULL(GA.PRIMA_UNICA,v_const_n_0) = v_const_s_1)
                  OR (SUBSTR(TBL.CODIGO_POLIZA,1,4) = '0124')
        THEN v_const_s_1 ELSE v_const_n_0 
        END AS EDADMAX_PRIMAUNICA,
        CASE WHEN ASE.EDAD >= v_const_mayor_edad THEN v_const_s_1 ELSE v_const_n_0 
        END AS CORRECTOR_SN,
        CAPITAL_NIVELADO AS CAP_NIVELADO,
        CAPITAL_NATURAL AS CAP_NATURAL,
        POL.FECHA_EMISION_POLIZA,
        TBL.MULTIPLICADOR_UNIDAD_POLIZA,
	    TBL.ALTA_DE,
	    TBL.CODIGO_SUPLEMENTO,
        TBL.ESTADO_RECIBO
        
        FROM EXT.ASEGURADOS ASE 
        INNER JOIN EXT.GARANTIAS_ASEGURADO GA  
	        ON  ASE.CODIGO_POLIZA = GA.CODIGO_POLIZA
	        AND ASE.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
        INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_1  TBL 
        	ON TBL.CODIGO_POLIZA = GA.CODIGO_POLIZA 
        	AND TBL.CODIGO_RECIBO= GA.CODIGO_RECIBO 
        INNER JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
	        AND GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        AND ASE.MOTIVO_ALTA IN (v_const_motivo_alta_np,
	                              v_const_motivo_alta_co,
	                              v_const_motivo_alta_rc,
	                              v_const_motivo_alta_ro,
	                              v_const_motivo_alta_de)
	        AND GA.PRODUCTO_CONTABLE =  substr(TBL.CODIGO_POLIZA,1,2) || substr(TBL.CODIGO_POLIZA,3,5)
	        AND (ASE.FECHA_BAJA IS NULL OR (
	           ASE.FECHA_BAJA IS NOT NULL AND
	           GA.SUBTIPO_MOVIMIENTO = v_const_tipo_mov_rehabili AND
	           ASE.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO
	          ))
	        AND TBL.PERMANENCIA = v_const_recibos_especificos_71;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    

    TBL_ASEGURADOS_UNIDAD_POLIZA_71_1 = 
        SELECT TBL.*,
            CASE WHEN EDADMAX_PRIMAUNICA = v_const_s_1 THEN IFNULL(TBL.CAP_NIVELADO,0) ELSE v_const_n_0
            END AS CAPITAL_NIVELADO_CALC,
            
            CASE WHEN EDADMAX_PRIMAUNICA = v_const_s_1 THEN IFNULL(TBL.CAP_NATURAL,0) ELSE v_const_n_0
            --3251
            END AS CAPITAL_NATURAL_CALC
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    

    TBL_ASEGURADOS_UNIDAD_POLIZA_71_2 =
        SELECT TBL.*,
                CASE WHEN CAPITAL_NIVELADO_CALC + EDADMAX_PRIMAUNICA <> 0 THEN (CAPITAL_NIVELADO_CALC*100) / (CAPITAL_NATURAL_CALC + CAPITAL_NIVELADO_CALC) ELSE 0
                END AS V_TEMP
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_1 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_71_3 =
        SELECT TBL.*,
            CASE WHEN V_TEMP > 100 THEN 100 ELSE V_TEMP END AS PORCENTAJE_NIVELADA_CALC
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_2 TBL;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_3 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
     
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_71_4 = 
        SELECT TBL.*,
                CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC >= 70
                            THEN 100
                    WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC >= 56 AND PORCENTAJE_NIVELADA_CALC < 70
                        THEN PORCENTAJE_NIVELADA_CALC/0.7 
                            ELSE PORCENTAJE_NIVELADA_CALC END AS PORCENTAJE_NIVELADA_CALC_1
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_3 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_4 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
     
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_71_4_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_71_4_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_71_4_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_4_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------ 
     
     

     TBL_ASEGURADOS_UNIDAD_POLIZA_71_5 = 
            SELECT TBL.*,
                MULTIPLICADOR_UNIDAD_POLIZA * (PORCENTAJE_NIVELADA_CALC_1/100) AS UNIDAD_DE_POLIZA_CALC
             FROM   :TBL_ASEGURADOS_UNIDAD_POLIZA_71_4 TBL;
             
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_5);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_5 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
    
                 
    TBL_ASEGURADOS_UNIDAD_POLIZA_71_6 = 
        SELECT TBL.*,
            CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND UNIDAD_DE_POLIZA_CALC < 0.15 
                    THEN 0.15
                WHEN MULTIPLICADOR_UNIDAD_POLIZA = v_const_unidad_poliza_jun_2020 AND UNIDAD_DE_POLIZA_CALC < 0.10 AND UNIDAD_DE_POLIZA_CALC > 0
                    THEN 0.10
                ELSE UNIDAD_DE_POLIZA_CALC
            END AS UNIDAD_DE_POLIZA_CALC_1
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_5 TBL;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_6);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_6 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_71_6_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_71_6_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_71_6_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_6);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_6_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_ASEGURADO para TBL_ASEGURADOS_UNIDAD_POLIZA_71_6 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_ASEGURADO GA
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_ASEGURADOS_UNIDAD_POLIZA_71_6 src
        WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
            AND GA.PRODUCTO_CONTABLE =  substr(src.CODIGO_POLIZA,1,2) || substr(src.CODIGO_POLIZA,3,5)
            AND GA.CODIGO_RECIBO =  src.CODIGO_RECIBO
            AND GA.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;

        MERGE INTO EXT.GARANTIAS_ASEGURADO GA
        USING(
            SELECT  DISTINCT TBL.CODIGO_POLIZA,
            		TBL.CODIGO_RECIBO,
            		TBL.NUMERO_ASEGURADO,
            		TBL.UNIDAD_DE_POLIZA_CALC_1,
            		TBL.PORCENTAJE_NIVELADA_CALC_1
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_6 TBL
         
        )src
        ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
            AND GA.PRODUCTO_CONTABLE =  substr(src.CODIGO_POLIZA,1,2) || substr(src.CODIGO_POLIZA,3,5)
            AND GA.CODIGO_RECIBO =  src.CODIGO_RECIBO
        WHEN MATCHED THEN UPDATE SET
            GA.UNIDAD_DE_POLIZA = ROUND(src.UNIDAD_DE_POLIZA_CALC_1,4),
            GA.PORCENTAJE_NIVELADA = ROUND(src.PORCENTAJE_NIVELADA_CALC_1/100,2), 
            GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_ASEGURADO para TBL_ASEGURADOS_UNIDAD_POLIZA_71_6. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT = 
    	SELECT TBL.CODIGO_POLIZA,
			TBL.CODIGO_RECIBO,
			TBL.PRODUCTO_CONTABLE,
			TBL.CODIGO_SUPLEMENTO,
			TBL.ESTADO_RECIBO,
			TBL.NUMERO_ASEGURADO,
			POL.MOTIVO_ALTA, 
			MAX(TBL.ALTA_DE) AS ALTA_DE,
			TBL.UNIDAD_DE_POLIZA_CALC_1,
			TBL.PORCENTAJE_NIVELADA_CALC_1
		FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_6 TBL
    	INNER JOIN EXT.POLIZAS POL
    		ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
    	GROUP BY TBL.CODIGO_POLIZA,
			TBL.CODIGO_RECIBO,
			TBL.PRODUCTO_CONTABLE,
			TBL.CODIGO_SUPLEMENTO,
			TBL.ESTADO_RECIBO,
			TBL.NUMERO_ASEGURADO,
			POL.MOTIVO_ALTA, 
			TBL.UNIDAD_DE_POLIZA_CALC_1,
			TBL.PORCENTAJE_NIVELADA_CALC_1
    ;
    
     v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR = 
    	SELECT  distinct TBL.CODIGO_POLIZA,
    			TBL.CODIGO_RECIBO,
    			TBL.PRODUCTO_CONTABLE,
    			TBL.CODIGO_SUPLEMENTO,
    			TBL.ESTADO_RECIBO,
    			POL.MOTIVO_ALTA, 
    			TBL.ALTA_DE,
    			SUM(TBL.UNIDAD_DE_POLIZA_CALC_1) AS SUM_UNIDAD_DE_POLIZA_CALC_1,
    			ROUND(SUM(TBL.PORCENTAJE_NIVELADA_CALC_1)/ COUNT(DISTINCT NUMERO_ASEGURADO),2) AS SUM_PORCENTAJE_NIVELADA_CALC_1,
    			ROW_NUMBER() OVER(
				  	PARTITION BY TBL.CODIGO_POLIZA,TBL.CODIGO_RECIBO,TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.PRODUCTO_CONTABLE
				  	ORDER BY TBL.CODIGO_POLIZA DESC
		        ) AS RN_GR
    	
    	FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR_DISTINCT TBL
    	INNER JOIN EXT.POLIZAS POL
    	ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
    	GROUP BY	TBL.CODIGO_POLIZA,
	    			TBL.CODIGO_RECIBO,
	    			TBL.PRODUCTO_CONTABLE,
	    			TBL.CODIGO_SUPLEMENTO,
	    			TBL.ESTADO_RECIBO,
	    			POL.MOTIVO_ALTA, 
    				TBL.ALTA_DE;
    
      v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	    BEGIN
	        
	        ROLLBACK;
	        
	        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBO para TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
	                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
	                
	        --Se actualizan los registros de POLIZAS con estado erróneo
	        UPDATE EXT.GARANTIAS_RECIBO GR
	            SET ESTADO = v_const_calculo_status_error,
	                FECHA_MODIFICACION = CURRENT_TIMESTAMP
	            FROM EXT.GARANTIAS_RECIBO GR, :TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR src
	        WHERE  GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
	            AND GR.ESTADO = v_const_populate_status_ok;
	        
	        COMMIT;     
	        RESIGNAL;
	    END;
    	  MERGE INTO EXT.GARANTIAS_RECIBO GR
    	  USING (
    	  	SELECT distinct * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_71_GR WHERE RN_GR = 1
    	  ) src
	    	  ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
    	  WHEN MATCHED THEN UPDATE SET
    	   GR.UNIDAD_DE_POLIZA = ROUND(CASE WHEN src.MOTIVO_ALTA IN (v_const_motivo_alta_tp, v_const_motivo_alta_ts, v_const_motivo_alta_dt ) THEN src.SUM_UNIDAD_DE_POLIZA_CALC_1 
    									WHEN src.MOTIVO_ALTA = v_const_motivo_alta_de AND src.ALTA_DE = v_const_n_0 THEN src.SUM_UNIDAD_DE_POLIZA_CALC_1 
    									ELSE 	src.SUM_UNIDAD_DE_POLIZA_CALC_1 + v_const_unidad_poliza_corrector 
    								END,4),
           GR.PORCENTAJE_NIVELADA = ROUND(src.SUM_PORCENTAJE_NIVELADA_CALC_1/100,2), 
           GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
    
    
    
    END;
        
-------------------------------------FT_UNIDAD_DE_POLIZA_66 5394    
    TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS =  
            SELECT 
            ASE.EDAD,
            ASE.CONTO_COMO_NUEVO,
            ASE.NUMERO_ASEGURADO,
            ASE.FECHA_ALTA, 
            ASE.MOTIVO_ALTA, 
            GA.PRIMA_UNICA,
            TBL.CODIGO_POLIZA,
            TBL.CODIGO_RECIBO,
            TBL.PERMANENCIA,
            TBL.FECHA_EFECTO_RECIBO,
            TBL.CODIGO_SUPLEMENTO,
            TBL.ESTADO_RECIBO,
            TBL.FECHA_COMPENSACION
            FROM EXT.ASEGURADOS ASE INNER JOIN  EXT.GARANTIAS_ASEGURADO GA  
	            ON ASE.CODIGO_POLIZA = GA.CODIGO_POLIZA
	            AND ASE.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
	             
            INNER JOIN :TBL_UNIDAD_POLIZA  TBL 
            ON TBL.CODIGO_POLIZA = GA.CODIGO_POLIZA AND TBL.CODIGO_RECIBO= GA.CODIGO_RECIBO
            WHERE IFNULL(v_unidad_de_poliza,2) NOT IN (v_const_n_0, v_const_s_1)
           
            GROUP BY 
            ASE.EDAD,
            ASE.CONTO_COMO_NUEVO,
            ASE.NUMERO_ASEGURADO, 
            ASE.FECHA_ALTA, 
            ASE.MOTIVO_ALTA, 
            GA.PRIMA_UNICA,
            TBL.CODIGO_POLIZA,
            TBL.CODIGO_RECIBO,
            TBL.PERMANENCIA,
            TBL.FECHA_EFECTO_RECIBO,
            TBL.CODIGO_SUPLEMENTO,
            TBL.ESTADO_RECIBO,
            TBL.FECHA_COMPENSACION
            ;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 = 
        SELECT  TBL.* 
                ,CASE WHEN CONTO_COMO_NUEVO IS NULL AND TBL.MOTIVO_ALTA = v_const_motivo_alta_de THEN 
                    (SELECT COUNT(T.MOTIVO_ALTA) 
                            FROM EXT.ASEGURADOS T
                            WHERE T.CODIGO_POLIZA = TBL.CODIGO_POLIZA  
                            AND T.MOTIVO_ALTA IN (v_const_motivo_alta_np,v_const_motivo_alta_co)) ELSE v_const_n_0
                END AS ALTA_DE
                ,CASE WHEN INSTR(UPPER(POL.TIPO_CAMPANIA),v_const_campania_cruzada) > 0 THEN v_const_unidad_poliza_cruzada
                    	ELSE CASE WHEN POL.FECHA_EMISION_POLIZA >= TO_DATE ('19/05/2020', 'dd/mm/yyyy') THEN v_const_unidad_poliza_jun_2020
                    		ELSE v_const_unidad_poliza END
                END AS MULTIPLICADOR_UNIDAD_POLIZA
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS TBL 
            INNER JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
     ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
   
   
   
   
   
    
    TBL_RECIBOS_FECHA_MIN_2 = SELECT X.CODIGO_POLIZA AS CODIGO_POLIZA_MIN
    							, MIN(X.FECHA_EMISION_REC) AS FECHA_EMISION_MIN
    							--20251020 RMF: Incluimos el NUM_ASEGURADO_MIN para el cruce posterior por NUMERO_ASEGURADO
    							, TBL.NUMERO_ASEGURADO AS NUMERO_ASEGURADO_MIN
                            FROM EXT.RECIBOS X  
                            INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 TBL
                            	ON X.CODIGO_POLIZA = TBL.CODIGO_POLIZA
									AND X.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
                            WHERE 1=1
                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
                            GROUP BY X.CODIGO_POLIZA, TBL.NUMERO_ASEGURADO
                            ;
                            
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_MIN_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_MIN_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    --20250901 RMF: Calculo de meses cobrados para el asegurado (FT_MESES_COBRADOS_ASEG_RRTT)
    TBL_RECIBO_INICIAL_COBRADO_2 = SELECT TBL.CODIGO_RECIBO
									, TBL.CODIGO_POLIZA
									, TBL.NUMERO_ASEGURADO
									, SUBSTR(TBL.CODIGO_POLIZA,1,7) AS PRODUCTO_CONTABLE
    								, ROUND(MONTHS_BETWEEN(X.FECHA_EFECTO_RECIBO,X.FECHA_VTO_RECIBO),2) AS SUM_MESES
    							FROM EXT.RECIBOS X  
                            	INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 TBL
                            		ON X.CODIGO_POLIZA = TBL.CODIGO_POLIZA
										AND X.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA
								INNER JOIN :TBL_RECIBOS_FECHA_MIN_2 TBL_MIN
									ON X.CODIGO_POLIZA = TBL_MIN.CODIGO_POLIZA_MIN
										AND X.FECHA_EMISION_REC = TBL_MIN.FECHA_EMISION_MIN
										--20251020 RMF: Incluimos el cruce por NUMERO_ASEGURADO_MIN
										AND TBL_MIN.NUMERO_ASEGURADO_MIN = TBL.NUMERO_ASEGURADO
	                            WHERE 1=1
	                                AND X.PERMANENCIA IN (:v_const_recibos_especificos_66,:v_const_recibos_especificos_65,:v_const_recibos_especificos_71)
	                                AND (X.ESTADO_RECIBO = :v_const_recibo_cobrado
	                                    OR X.FECHA_COMPENSACION = TBL.FECHA_COMPENSACION)
	                                AND X.CODIGO_RECIBO <> :v_const_cod_recibo_anul_rrtt AND X.CODIGO_RECIBO NOT LIKE '%_A'
	                                AND IFNULL(X.TIPO_RECIBO,'ZZ') <> :v_const_tipo_rec_anul_k5
    						;
    								
    v_num_rows = RECORD_COUNT(:TBL_RECIBO_INICIAL_COBRADO_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBO_INICIAL_COBRADO_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
    TBL_RECIBOS_FECHA_COMP_MAX_2 = SELECT MAX(T.FECHA_COMPENSACION) AS FECHA_COMP_MAX
    								, T.CODIGO_RECIBO
    								, T.CODIGO_POLIZA
    								--, T.ESTADO_RECIBO_MAX
    								--, T.CODIGO_SUPLEMENTO_MAX
                                FROM EXT.RECIBOS T
                                INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 TBL	ON T.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                                	--AND T.CODIGO_RECIBO = TBL.CODIGO_RECIBO
									--AND T.ESTADO_RECIBO = TBL.ESTADO_RECIBO
									--AND T.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                                WHERE 1=1
                                    AND T.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
                                    AND T.ESTADO_RECIBO IN (:v_const_recibo_cobrado,:v_const_recibo_pendiente,:v_const_recibo_anulado)
                                GROUP BY T.CODIGO_RECIBO, T.CODIGO_POLIZA
                                ;
                                
    v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FECHA_COMP_MAX_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FECHA_COMP_MAX_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    					
    
    TBL_RECIBOS_FILTRADOS_2 = SELECT TBL.CODIGO_POLIZA
    							, TBL.CODIGO_RECIBO
    							, TBL.NUMERO_ASEGURADO
    							, SUBSTR(TBL.CODIGO_POLIZA,1,7) AS PRODUCTO_CONTABLE
    							, SUM(ROUND(MONTHS_BETWEEN(RECI.FECHA_EFECTO_RECIBO, RECI.FECHA_VTO_RECIBO),2)) AS SUM_MESES--INTO v_meses_cobrados
	                        FROM EXT.RECIBOS RECI
	                        INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 TBL ON RECI.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	                        	--AND RECI.CODIGO_RECIBO = TBL.CODIGO_RECIBO
								--AND RECI.ESTADO_RECIBO = TBL.ESTADO_RECIBO
								--AND RECI.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
	                        	AND RECI.FECHA_EFECTO_RECIBO > TBL.FECHA_ALTA
	                        INNER JOIN :TBL_RECIBOS_FECHA_COMP_MAX_2 TBL_MAX ON TBL_MAX.CODIGO_POLIZA = RECI.CODIGO_POLIZA
	                        	AND TBL_MAX.CODIGO_RECIBO = RECI.CODIGO_RECIBO
	                        	AND TBL_MAX.FECHA_COMP_MAX = RECI.FECHA_COMPENSACION
	                        WHERE 1=1
	                            AND RECI.PERMANENCIA IN (:v_const_recibos_cartera_72,:v_const_recibos_cartera_81,:v_const_recibos_especificos_55)
	                            AND RECI.ESTADO_RECIBO = :v_const_recibo_cobrado
	                            AND RECI.MARCA_CUENTA = :v_const_s
	                        GROUP BY TBL.CODIGO_POLIZA, TBL.CODIGO_RECIBO, TBL.NUMERO_ASEGURADO, SUBSTR(TBL.CODIGO_POLIZA,1,7)
	                        ;
	                        
	v_num_rows = RECORD_COUNT(:TBL_RECIBOS_FILTRADOS_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_2: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
     ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_RECIBOS_FILTRADOS_2_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_RECIBOS_FILTRADOS_2_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_RECIBOS_FILTRADOS_2_DEBUG AS (SELECT * FROM :TBL_RECIBOS_FILTRADOS_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_RECIBOS_FILTRADOS_2_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
	
	--ALTA POR DESGLOSE Y ALTA POR TRASPASO DE PRODUCTO O DESGLOSE TOTAL
    TBL_ASEGURADOS_UNIDAD_POLIZA_66 =
    SELECT 
        GA.*,
        ASE.FECHA_ALTA,
        ASE.MOTIVO_ALTA,
        ASE.FECHA_BAJA,
        ASE.FECHA_REHABILITACION,
        ASE.POLIZA_ORIGEN,
        ASE.ASEGURADO_ORIGEN,
        ASE.EDAD,
        CASE WHEN ASE.EDAD >= v_const_mayor_edad THEN v_const_s_1 ELSE v_const_n_0 END AS CORRECTOR_SN,
        CAPITAL_NIVELADO AS CAP_NIVELADO,
        CAPITAL_NATURAL AS CAP_NATURAL,
        POL.FECHA_EMISION_POLIZA,
       /* CASE 
            WHEN INSTR(UPPER(POL.TIPO_CAMPANIA), v_const_campania_cruzada) > 0 THEN v_const_unidad_poliza_cruzada
            WHEN POL.FECHA_EMISION_POLIZA >= TO_DATE('19/05/2020', 'dd/mm/yyyy') THEN v_const_unidad_poliza_jun_2020
            ELSE v_const_unidad_poliza
        END AS MULTIPLICADOR_UNIDAD_POLIZA,*/
        CASE 
            WHEN SUBSTR(GA.PRODUCTO_CONTABLE,1,3) = '012' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE) IS NULL THEN 17
            WHEN SUBSTR(GA.PRODUCTO_CONTABLE,1,3) = '032' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE) IS NULL THEN 18
            WHEN SUBSTR(GA.PRODUCTO_CONTABLE,3,1) <> '2' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE) IS NULL THEN 12
            ELSE IFNULL((SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE), 0)
        END AS PERIODO_EXTORNABLE,
        (SELECT IFNULL(MESES_COBRADOS,1) 
        FROM VW_FORMAS_PAGO
        WHERE CODIGO = (SELECT FORMA_PAGO FROM EXT.POLIZAS WHERE CODIGO_POLIZA = TBL.CODIGO_POLIZA)
        ) AS MESES_FORMA_PAGO,
        --MC.MESES_COBRADOS_CALC,
        POL.MOTIVO_BAJA,
        TBL.FECHA_EFECTO_RECIBO AS FECHA_EFECTO_REC,
        TBL.ESTADO_RECIBO,
        TBL.CODIGO_SUPLEMENTO,
        (CASE WHEN ASE.MOTIVO_ALTA IN (v_const_motivo_alta_rc,v_const_motivo_alta_ro) THEN (
                SELECT FECHA_BAJA FROM EXT.ASEGURADOS A
                WHERE A.CODIGO_POLIZA = TRIM(ASE.POLIZA_ORIGEN)
                AND A.NUMERO_ASEGURADO = TRIM(ASE.ASEGURADO_ORIGEN)
            )
        END) AS FECHA_BAJA_RH,
        IFNULL(TBL_RECI_FIL.SUM_MESES,0) + IFNULL(TBL_REC_INI_COB.SUM_MESES,19) AS MESES_COBRADOS_CALC
    FROM EXT.ASEGURADOS ASE
    INNER JOIN EXT.GARANTIAS_ASEGURADO GA
        ON ASE.CODIGO_POLIZA = GA.CODIGO_POLIZA
        AND ASE.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
    INNER JOIN EXT.RECIBOS RE
        ON RE.CODIGO_POLIZA = GA.CODIGO_POLIZA
        AND RE.CODIGO_RECIBO = GA.CODIGO_RECIBO
    INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 TBL 
        ON TBL.CODIGO_POLIZA = RE.CODIGO_POLIZA 
        AND TBL.CODIGO_RECIBO = RE.CODIGO_RECIBO
        AND TBL.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
    INNER JOIN EXT.POLIZAS POL 
        ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
   /*LEFT JOIN :TBL_MESES_COBRADOS_CALC MC
        ON MC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND MC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        AND MC.FECHA_ALTA = ASE.FECHA_ALTA*/
    LEFT JOIN :TBL_RECIBOS_FILTRADOS_2 TBL_RECI_FIL
		ON TBL_RECI_FIL.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		AND TBL_RECI_FIL.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		AND TBL_RECI_FIL.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
		AND TBL_RECI_FIL.PRODUCTO_CONTABLE = GA.PRODUCTO_CONTABLE
	LEFT JOIN :TBL_RECIBO_INICIAL_COBRADO_2 TBL_REC_INI_COB ON TBL_REC_INI_COB.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		AND TBL_REC_INI_COB.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		AND TBL_REC_INI_COB.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
		AND TBL_REC_INI_COB.PRODUCTO_CONTABLE = GA.PRODUCTO_CONTABLE
    WHERE 
        RE.PERMANENCIA = v_const_recibos_especificos_66
        AND RE.ESTADO_RECIBO = TBL.ESTADO_RECIBO
        AND GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        AND GA.PRODUCTO_CONTABLE = SUBSTR(TBL.CODIGO_POLIZA,1,2) || SUBSTR(TBL.CODIGO_POLIZA,3,5)
        AND (
            ASE.MOTIVO_ALTA IN (v_const_motivo_alta_np, v_const_motivo_alta_co)
            OR (ASE.MOTIVO_ALTA = v_const_motivo_alta_de AND ASE.CONTO_COMO_NUEVO = v_const_s_1 AND ASE.FECHA_ALTA = POL.FECHA_EFECTO_POLIZA)
            OR (ASE.MOTIVO_ALTA IN (v_const_motivo_alta_rc, v_const_motivo_alta_ro))
        )
        AND ASE.EDAD <= v_const_max_edad
        AND
        (
            (ASE.FECHA_ALTA = RE.FECHA_EFECTO_RECIBO AND ASE.FECHA_BAJA IS NULL
                AND ASE.NUMERO_ASEGURADO NOT IN (
                    SELECT DISTINCT IFNULL(T_GARASE.NUMERO_ASEGURADO,0)
                    FROM EXT.GARANTIAS_ASEGURADO T_GARASE
                    WHERE T_GARASE.CODIGO_POLIZA = TBL.CODIGO_POLIZA
                    AND CAST(HEXTONUM(SUBSTR((CASE WHEN T_GARASE.CODIGO_RECIBO IN (v_const_cod_recibo_ini, v_const_cod_recibo_anul_rrtt) 
                                                THEN '00000000000' 
                                                ELSE T_GARASE.CODIGO_RECIBO 
                                            END),3)) AS BIGINT) 
                        < CAST(HEXTONUM(SUBSTR((CASE WHEN TBL.CODIGO_RECIBO IN (v_const_cod_recibo_ini, v_const_cod_recibo_anul_rrtt) 
                                                THEN '00000000000' 
                                                ELSE TBL.CODIGO_RECIBO END),3)) AS BIGINT)
                    AND T_GARASE.SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_supinase)
                )
            )
            OR (ASE.FECHA_BAJA = RE.FECHA_EFECTO_RECIBO AND ASE.FECHA_ALTA <> ASE.FECHA_BAJA)
            OR (ASE.FECHA_BAJA IS NOT NULL AND ASE.FECHA_REHABILITACION IS NOT NULL)
        	
        )
        -- ALTA POR DESGLOSE Y ALTA POR TRASPASO DE PRODUCTO O DESGLOSE TOTAL
        AND POL.MOTIVO_ALTA IN (v_const_motivo_alta_de, v_const_motivo_alta_tp, v_const_motivo_alta_dt)
        AND ifnull(RE.ASEGURADOS_NETOS,0) <> 0
        ;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
    
    
      	 ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_66_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    
    TBL_MOTIVOS_BAJA_CUENTA =
    SELECT 
        CODIGO,
        CUENTA_COMO_BAJA
    FROM VW_MOTIVOS_BAJA;

    v_num_rows = RECORD_COUNT(:TBL_MOTIVOS_BAJA_CUENTA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_MOTIVOS_BAJA_CUENTA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');   

    TBL_FECHA_EMISION_ASEG =
    SELECT 
        CODIGO_POLIZA,
        CODIGO_RECIBO,
        FECHA_EFECTO_RECIBO,
        MAX(FECHA_EMISION_REC) AS FECHA_EMISION_ASEG
    FROM EXT.RECIBOS
    WHERE PERMANENCIA IN (v_const_recibos_especificos_71, v_const_recibos_especificos_66, v_const_recibos_especificos_65)
    GROUP BY 
        CODIGO_POLIZA,
        CODIGO_RECIBO,
        FECHA_EFECTO_RECIBO;

    v_num_rows = RECORD_COUNT(:TBL_FECHA_EMISION_ASEG);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_FECHA_EMISION_ASEG '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
   
   TBL_ASEGURADOS_UNIDAD_POLIZA_66_1 = 
    SELECT 
        TBL.*,
        -- Cálculo de ES_PERIODO_EXTORNABLE
        CASE 
            WHEN (CASE 
                      WHEN IFNULL(PERIODO_EXTORNABLE, 0) >= 0 
                      THEN IFNULL(PERIODO_EXTORNABLE, 0) - IFNULL(MESES_COBRADOS_CALC, 0) 
                      ELSE 0 
                  END) > 0 
            THEN v_const_s_1 
            ELSE v_const_n_0 
        END AS ES_PERIODO_EXTORNABLE,
        
        -- Join con CUENTA_COMO_BAJA
        MB.CUENTA_COMO_BAJA AS CUENTO_COMO_BAJA,
        
        -- Join con FECHA_EMISION_ASEG, con IFNULL
        IFNULL(FE.FECHA_EMISION_ASEG, TBL.FECHA_ALTA) AS FECHA_EMISION_ASEG
        
		, (CASE WHEN TBL.MOTIVO_ALTA NOT IN (v_const_motivo_alta_re, v_const_motivo_alta_ro) THEN v_const_s
            ELSE (CASE WHEN TBL.FECHA_ALTA = TBL.FECHA_BAJA_RH
        				THEN v_const_s
        			WHEN TBL.FECHA_ALTA IS NULL
	                	THEN v_const_n
	                WHEN TBL.FECHA_BAJA_RH IS NULL
            				OR DAYS_BETWEEN(IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD')), TBL.FECHA_ALTA) >= v_const_365_dias
            				OR (DAYS_BETWEEN(IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD')), TBL.FECHA_ALTA) BETWEEN 0 AND 30
            					AND substr(TBL.PRODUCTO_CONTABLE,3,5) IN ('22020','22035','29018','29020') 
            					AND ((EXTRACT(MONTH FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) = EXTRACT(MONTH FROM TBL.FECHA_ALTA)
			                    		AND (EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19 OR EXTRACT(DAY FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) > 18))
			                    	OR (EXTRACT(MONTH FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) <> EXTRACT(MONTH FROM TBL.FECHA_ALTA)
										AND EXTRACT(DAY FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) > 18 AND EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19)))
	                    THEN v_const_s
	                ELSE v_const_n
				END)
         END) AS RH_MAYOR_ANIO
             
    FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66 TBL
    LEFT JOIN :TBL_MOTIVOS_BAJA_CUENTA MB
        ON MB.CODIGO = TBL.MOTIVO_BAJA
    LEFT JOIN :TBL_FECHA_EMISION_ASEG FE
        ON FE.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND FE.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        AND FE.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
   

    TBL_ASEGURADOS_UNIDAD_POLIZA_66_2 = 
        SELECT TBL.* 
            ,CASE WHEN FECHA_EMISION_ASEG >=  TO_DATE ('19/05/2020', 'dd/mm/yyyy') THEN v_const_unidad_poliza_jun_2020 ELSE v_const_unidad_poliza
            END AS MULTIPLICADOR_UNIDAD_POLIZA
            -- ,CASE WHEN CAST(ES_PERIODO_EXTORNABLE AS VARCHAR) IN (v_const_s, v_const_s_1) AND FECHA_ALTA >= TO_DATE('01/01/2017', 'dd/mm/yyyy') AND (FECHA_BAJA IS NULL
            --           OR (FECHA_BAJA IS NOT NULL AND CAST(CUENTO_COMO_BAJA AS VARCHAR) IN (v_const_s, v_const_s_1)) 
            --           OR (FECHA_BAJA IS NOT NULL AND FECHA_REHABILITACION IS NOT NULL)) THEN 0
            -- END AS UNIDAD_DE_POLIZA_CALC
            ,CASE WHEN CAST(ES_PERIODO_EXTORNABLE AS VARCHAR) IN (v_const_s, v_const_s_1) AND FECHA_ALTA >= TO_DATE('01/01/2017', 'dd/mm/yyyy') AND (FECHA_BAJA IS NULL
                       OR (FECHA_BAJA IS NOT NULL AND CAST(CUENTO_COMO_BAJA AS VARCHAR) IN (v_const_s, v_const_s_1)) 
                       OR (FECHA_BAJA IS NOT NULL AND FECHA_REHABILITACION IS NOT NULL)) THEN 0
            END AS PORCENTAJE_NIVELADA_CALC
            ,CASE WHEN EDAD <= v_const_max_edad 
                          OR (EDAD > v_const_max_edad AND IFNULL(PRIMA_UNICA,v_const_n_0) = v_const_s_1) THEN v_const_s_1 ELSE v_const_n_0
            END AS EDADMAX_PRIMAUNICA
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_1 TBL
        --FILTRAMOS LOS CASOS QUE CALCULAN UNIDAD_DE_POLIZAS = 0
        WHERE (CAST(ES_PERIODO_EXTORNABLE AS VARCHAR) IN (v_const_s, v_const_s_1) OR TBL.FECHA_BAJA IS NULL)
	        AND FECHA_ALTA >= TO_DATE('01/01/2017', 'dd/mm/yyyy')
	        AND (
	        	FECHA_BAJA IS NULL
	            OR (FECHA_BAJA IS NOT NULL AND CAST(CUENTO_COMO_BAJA AS VARCHAR) IN (v_const_s, v_const_s_1)) 
	            OR (FECHA_BAJA IS NOT NULL AND FECHA_REHABILITACION IS NOT NULL)
        	)
        	--Excepcion: Si es RC o RO, solamente se tiene en cuenta si ha pasado mas de un año.
        	AND TBL.RH_MAYOR_ANIO = v_const_s
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
    
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_3 = 
        SELECT TBL.*
            ,IFNULL(CAP_NIVELADO,0) AS CAPITAL_NIVELADO_CALC
            ,IFNULL(CAP_NATURAL,0) AS CAPITAL_NATURAL_CALC
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_2 TBL
        WHERE EDADMAX_PRIMAUNICA = v_const_s_1
    ;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_3 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_4 = 
        SELECT TBL.*
            ,CASE WHEN CAPITAL_NIVELADO_CALC + EDADMAX_PRIMAUNICA <> 0 THEN (CAPITAL_NIVELADO_CALC*100) / (CAPITAL_NATURAL_CALC + CAPITAL_NIVELADO_CALC) ELSE 0
                END AS V_TEMP
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_3 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_4 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_5 =
        SELECT TBL.*,
            CASE WHEN V_TEMP > 100 THEN 100 ELSE V_TEMP END AS PORCENTAJE_NIVELADA_CALC_1
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_4 TBL;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_5);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_5 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_6 = 
        SELECT TBL.*,
                CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC_1 >= 70
                            THEN 100
                    WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC_1 >= 56 AND PORCENTAJE_NIVELADA_CALC < 70
                            THEN PORCENTAJE_NIVELADA_CALC_1/0.7 ELSE PORCENTAJE_NIVELADA_CALC_1 END AS PORCENTAJE_NIVELADA_CALC_2
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_5 TBL;    
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_6);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_6 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_7 = 
            SELECT TBL.*,
                MULTIPLICADOR_UNIDAD_POLIZA * (PORCENTAJE_NIVELADA_CALC_2/100) AS UNIDAD_DE_POLIZA_CALC_1
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_6 TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_7);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_7 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_8 = 
        SELECT TBL.*
        ,CASE WHEN CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_ASEG between TO_DATE ('20/07/2021', 'dd/mm/yyyy') AND TO_DATE ('18/08/2021', 'dd/mm/yyyy') AND (ABS(UNIDAD_DE_POLIZA_CALC_1) < 0.15)
                AND ((FECHA_BAJA IS NOT NULL) OR (FECHA_BAJA IS NULL AND FECHA_ALTA = TBL.FECHA_EFECTO_REC)) THEN 
                    CASE WHEN UNIDAD_DE_POLIZA_CALC_1 < 0 THEN -0.15 ELSE 0.15 END 
                WHEN MULTIPLICADOR_UNIDAD_POLIZA = v_const_unidad_poliza_jun_2020 AND   (ABS(UNIDAD_DE_POLIZA_CALC_1) < 0.10) AND ((FECHA_BAJA IS NOT NULL)
                               OR (FECHA_BAJA IS NULL AND FECHA_ALTA = TBL.FECHA_EFECTO_REC)) THEN
                    CASE WHEN UNIDAD_DE_POLIZA_CALC_1 < 0 THEN -0.10 ELSE 0.10 END  
                WHEN FECHA_BAJA IS NOT NULL THEN   UNIDAD_DE_POLIZA_CALC_1 * -1
                WHEN UNIDAD_DE_POLIZA_CALC_1 <0 AND ES_PERIODO_EXTORNABLE IN (v_const_n, v_const_n_0) THEN 0
                ELSE UNIDAD_DE_POLIZA_CALC_1
            END AS UNIDAD_DE_POLIZA_CALC_2
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_7 TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_8);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_8 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
    
      	 ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_8);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
    ROLLBACK;
    
    CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para ES_PERMANENCIA_20 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                        
    --Se actualizan los registros de POLIZAS con estado erróneo
    UPDATE EXT.GARANTIAS_ASEGURADO GA
        SET ESTADO = v_const_calculo_status_error,
            FECHA_MODIFICACION = CURRENT_TIMESTAMP
        FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_ASEGURADOS_UNIDAD_POLIZA_66_8 src
    WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.PRODUCTO_CONTABLE =  substr(src.CODIGO_POLIZA,1,2) || substr(src.CODIGO_POLIZA,3,5) 
        AND GA.CODIGO_RECIBO =  src.CODIGO_RECIBO
        AND src.ESTADO = v_const_populate_status_ok;
    
    COMMIT;     
    RESIGNAL;
    END;
    
        MERGE INTO EXT.GARANTIAS_ASEGURADO GA
        USING(
        	--SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_8
            SELECT DISTINCT CODIGO_POLIZA,NUMERO_ASEGURADO,CODIGO_RECIBO,UNIDAD_DE_POLIZA_CALC_2,PORCENTAJE_NIVELADA_CALC_2 
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_8
        )src
        ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.PRODUCTO_CONTABLE =  substr(src.CODIGO_POLIZA,1,2) || substr(src.CODIGO_POLIZA,3,5) 
        AND GA.CODIGO_RECIBO =  src.CODIGO_RECIBO
        WHEN MATCHED THEN UPDATE SET
            GA.UNIDAD_DE_POLIZA = ROUND(src.UNIDAD_DE_POLIZA_CALC_2,4),
            GA.PORCENTAJE_NIVELADA = ROUND(src.PORCENTAJE_NIVELADA_CALC_2/100,2),
            GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
    
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_ASEGURADO para TBL_ASEGURADOS_UNIDAD_POLIZA_66_8. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');

    END;
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT = 
    	SELECT DISTINCT TBL.CODIGO_POLIZA,
			TBL.CODIGO_RECIBO,
			TBL.PRODUCTO_CONTABLE,
			TBL.CODIGO_SUPLEMENTO,
			TBL.ESTADO_RECIBO,
			TBL.NUMERO_ASEGURADO,
			TBL.UNIDAD_DE_POLIZA_CALC_2,
			TBL.PORCENTAJE_NIVELADA_CALC_1
		FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_8 TBL
    ;
    
     v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
      TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR = 
    	SELECT  TBL.CODIGO_POLIZA,
    			TBL.CODIGO_RECIBO,
    			TBL.PRODUCTO_CONTABLE,
    			TBL.CODIGO_SUPLEMENTO,
    			TBL.ESTADO_RECIBO,
    			SUM(TBL.UNIDAD_DE_POLIZA_CALC_2) AS SUM_UNIDAD_DE_POLIZA_CALC_2,
    			ROUND(SUM(TBL.PORCENTAJE_NIVELADA_CALC_1)/ COUNT(DISTINCT NUMERO_ASEGURADO),2) AS SUM_PORCENTAJE_NIVELADA_CALC_1
    	FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT TBL
    	GROUP BY	TBL.CODIGO_POLIZA,
	    			TBL.CODIGO_RECIBO,
	    			TBL.PRODUCTO_CONTABLE,
	    			TBL.CODIGO_SUPLEMENTO,
	    			TBL.ESTADO_RECIBO;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	    BEGIN
	        
	        ROLLBACK;
	        
	        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBO para TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
	                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
	                
	        --Se actualizan los registros de POLIZAS con estado erróneo
	        UPDATE EXT.GARANTIAS_RECIBO GR
	            SET ESTADO = v_const_calculo_status_error,
	                FECHA_MODIFICACION = CURRENT_TIMESTAMP
	            FROM EXT.GARANTIAS_RECIBO GR, :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR src
	        WHERE  GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
	            AND GR.ESTADO = v_const_populate_status_ok;
	        
	        COMMIT;     
	        RESIGNAL;
	    END;
    	  MERGE INTO EXT.GARANTIAS_RECIBO GR
    	  USING (
    	  	SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR 
    	  ) src
	    	  ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
    	  WHEN MATCHED THEN UPDATE SET
    	   GR.UNIDAD_DE_POLIZA = ROUND(src.SUM_UNIDAD_DE_POLIZA_CALC_2,4),
           GR.PORCENTAJE_NIVELADA = ROUND(src.SUM_PORCENTAJE_NIVELADA_CALC_1/100,2), 
           GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
    
       v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;
    
    
	
	--AUMENTO ASEGURADOS O PRIMA NIVELADA O DISMINUCION DE PRIMA NIVELADA
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS =
    SELECT GA.*, 
        ASE.FECHA_NACIMIENTO, 
        ASE.FECHA_ALTA,
        ASE.MOTIVO_ALTA, 
        ASE.FECHA_BAJA, 
        ASE.MOTIVO_BAJA, 
        ASE.FECHA_REHABILITACION,
        ASE.EDAD,
        ASE.CONTO_COMO_NUEVO,
        ASE.POLIZA_ORIGEN,
        ASE.ASEGURADO_ORIGEN,
        --,CASE WHEN ASE.EDAD >= v_const_mayor_edad THEN v_const_s_1 ELSE v_const_n_0 END AS CORRECTOR_SN,
        CAPITAL_NIVELADO AS CAP_NIVELADO,
        CAPITAL_NATURAL AS CAP_NATURAL,
        POL.FECHA_EMISION_POLIZA,
        /*CASE 
            WHEN INSTR(UPPER(POL.TIPO_CAMPANIA), v_const_campania_cruzada) > 0 THEN v_const_unidad_poliza_cruzada
            WHEN POL.FECHA_EMISION_POLIZA >= TO_DATE('19/05/2020', 'dd/mm/yyyy') THEN v_const_unidad_poliza_jun_2020
            ELSE v_const_unidad_poliza
        END AS MULTIPLICADOR_UNIDAD_POLIZA,*/
        CASE 
            WHEN SUBSTR(GA.PRODUCTO_CONTABLE,1,3) = '012' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE) IS NULL THEN 17
            WHEN SUBSTR(GA.PRODUCTO_CONTABLE,1,3) = '032' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE) IS NULL THEN 18
            WHEN SUBSTR(GA.PRODUCTO_CONTABLE,3,1) <> '2' AND (SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE) IS NULL THEN 12
            ELSE IFNULL((SELECT PERIODO_EXTORNABLE FROM VW_GEN_PRODUCTOS WHERE CODIGO = GA.PRODUCTO_CONTABLE), 0)
        END AS PERIODO_EXTORNABLE,
        (SELECT IFNULL(MESES_COBRADOS,1) 
        FROM VW_FORMAS_PAGO
        WHERE CODIGO = (SELECT FORMA_PAGO FROM EXT.POLIZAS WHERE CODIGO_POLIZA = TBL.CODIGO_POLIZA)
        ) AS MESES_FORMA_PAGO,
        --MC.MESES_COBRADOS_CALC,
        IFNULL(TBL_RECI_FIL.SUM_MESES,0) + IFNULL(TBL_REC_INI_COB.SUM_MESES,19) AS MESES_COBRADOS_CALC,
        POL.MOTIVO_BAJA AS MOTIVO_BAJA_POL,
        TBL.FECHA_EFECTO_RECIBO AS FECHA_EFECTO_REC,
        TBL.ESTADO_RECIBO,
        TBL.CODIGO_SUPLEMENTO
        ,(CASE WHEN ASE.MOTIVO_ALTA IN (v_const_motivo_alta_rc,v_const_motivo_alta_ro) THEN (
                SELECT FECHA_BAJA FROM EXT.ASEGURADOS A
                WHERE A.CODIGO_POLIZA = TRIM(ASE.POLIZA_ORIGEN)
                AND A.NUMERO_ASEGURADO = TRIM(ASE.ASEGURADO_ORIGEN)
            )
        END) AS FECHA_BAJA_RH
        ,TBL.ALTA_DE
        ,RE.ASEGURADOS_NETOS
    FROM EXT.ASEGURADOS ASE
    INNER JOIN EXT.GARANTIAS_ASEGURADO GA
        ON ASE.CODIGO_POLIZA = GA.CODIGO_POLIZA
        AND ASE.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
    INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_CON_BAJAS_1 TBL 
        ON TBL.CODIGO_POLIZA = GA.CODIGO_POLIZA 
        AND TBL.CODIGO_RECIBO = GA.CODIGO_RECIBO
        AND TBL.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
    INNER JOIN EXT.POLIZAS POL 
        ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
    INNER JOIN EXT.RECIBOS RE
        ON RE.CODIGO_POLIZA = GA.CODIGO_POLIZA
        AND RE.CODIGO_RECIBO = GA.CODIGO_RECIBO
        AND RE.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
        AND RE.ESTADO_RECIBO = TBL.ESTADO_RECIBO
    /*LEFT JOIN :TBL_MESES_COBRADOS_CALC MC
        ON MC.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND MC.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        AND MC.FECHA_ALTA = ASE.FECHA_ALTA*/
    LEFT JOIN :TBL_RECIBOS_FILTRADOS_2 TBL_RECI_FIL
		ON TBL_RECI_FIL.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		AND TBL_RECI_FIL.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		AND TBL_RECI_FIL.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
		AND TBL_RECI_FIL.PRODUCTO_CONTABLE = GA.PRODUCTO_CONTABLE
	LEFT JOIN :TBL_RECIBO_INICIAL_COBRADO_2 TBL_REC_INI_COB ON TBL_REC_INI_COB.CODIGO_POLIZA = TBL.CODIGO_POLIZA
		AND TBL_REC_INI_COB.CODIGO_RECIBO = TBL.CODIGO_RECIBO
		AND TBL_REC_INI_COB.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
		AND TBL_REC_INI_COB.PRODUCTO_CONTABLE = GA.PRODUCTO_CONTABLE
    WHERE(ASE.MOTIVO_ALTA IN (v_const_motivo_alta_np, v_const_motivo_alta_co)
            OR (ASE.MOTIVO_ALTA IN (v_const_motivo_alta_rc,v_const_motivo_alta_ro)))
        --RMF 20251014: Añadimos condición de permanencia 66
        AND RE.PERMANENCIA = :v_const_recibos_especificos_66
        AND GA.PRODUCTO_CONTABLE = SUBSTR(TBL.CODIGO_POLIZA,1,7)
        AND ((ASE.FECHA_BAJA IS NULL
                AND (ASE.NUMERO_ASEGURADO NOT IN (
						SELECT DISTINCT IFNULL(T_GARASE.NUMERO_ASEGURADO,0)
						FROM EXT.GARANTIAS_ASEGURADO T_GARASE
						WHERE T_GARASE.CODIGO_POLIZA = TBL.CODIGO_POLIZA
						AND CAST(HEXTONUM(SUBSTR((CASE WHEN T_GARASE.CODIGO_RECIBO IN (v_const_cod_recibo_ini, v_const_cod_recibo_anul_rrtt) THEN '00000000000' ELSE T_GARASE.CODIGO_RECIBO END),3)) AS BIGINT) 
							< CAST(HEXTONUM(SUBSTR((CASE WHEN TBL.CODIGO_RECIBO IN (v_const_cod_recibo_ini, v_const_cod_recibo_anul_rrtt) THEN '00000000000' ELSE TBL.CODIGO_RECIBO END ),3)) AS BIGINT)
						AND T_GARASE.SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_altapoli, v_const_tipo_mov_supinase)
					)
					OR GA.SUBTIPO_MOVIMIENTO IN (v_const_tipo_mov_supaucap,v_const_tipo_mov_supdicap,v_const_tipo_mov_supgener))
        	)
			OR (ASE.FECHA_BAJA = TBL.FECHA_EFECTO_RECIBO)
			OR (ASE.FECHA_BAJA IS NOT NULL AND ASE.FECHA_REHABILITACION IS NOT NULL)
        )
		--AUMENTO ASEGURADOS O PRIMA NIVELADA O DISMINUCION DE PRIMA NIVELADA
		AND POL.MOTIVO_ALTA NOT IN (v_const_motivo_alta_de, v_const_motivo_alta_tp, v_const_motivo_alta_dt)
	;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
	
	 ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS_DEBUG' , i_log_count, i_id_proceso, 'debug');
	----------------------------------
	TBL_ASEGURADOS_UNIDAD_POLIZA_66_1_BIS =
    SELECT 
        TBL.*,
        
        -- Cálculo de ES_PERIODO_EXTORNABLE
        CASE WHEN (CASE 
                      WHEN IFNULL(PERIODO_EXTORNABLE, 0) >= 0 
                      THEN IFNULL(PERIODO_EXTORNABLE, 0) - IFNULL(MESES_COBRADOS_CALC, 0) 
                      ELSE 0 
                  END) > 0 
            THEN v_const_s_1 
            ELSE v_const_n_0 
        END AS ES_PERIODO_EXTORNABLE,
        
        -- Join con CUENTA_COMO_BAJA
        MB.CUENTA_COMO_BAJA AS CUENTO_COMO_BAJA,
        
        -- Join con FECHA_EMISION_ASEG, con IFNULL
        IFNULL(FE.FECHA_EMISION_ASEG, TBL.FECHA_ALTA) AS FECHA_EMISION_ASEG
        
		, (CASE WHEN TBL.MOTIVO_ALTA NOT IN (v_const_motivo_alta_re, v_const_motivo_alta_ro) THEN v_const_s
            ELSE (CASE WHEN TBL.FECHA_ALTA = TBL.FECHA_BAJA_RH
        				THEN v_const_s
        			WHEN TBL.FECHA_ALTA IS NULL
	                	THEN v_const_n
	                WHEN TBL.FECHA_BAJA_RH IS NULL
            				OR DAYS_BETWEEN(IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD')), TBL.FECHA_ALTA) >= v_const_365_dias
            				OR (DAYS_BETWEEN(IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD')), TBL.FECHA_ALTA) BETWEEN 0 AND 30
            					AND substr(TBL.PRODUCTO_CONTABLE,3,5) IN ('22020','22035','29018','29020') 
            					AND ((EXTRACT(MONTH FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) = EXTRACT(MONTH FROM TBL.FECHA_ALTA)
			                    		AND (EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19 OR EXTRACT(DAY FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) > 18))
			                    	OR (EXTRACT(MONTH FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) <> EXTRACT(MONTH FROM TBL.FECHA_ALTA)
										AND EXTRACT(DAY FROM IFNULL(TBL.FECHA_BAJA_RH,TO_DATE('19000101','YYYYMMDD'))) > 18 AND EXTRACT(DAY FROM TBL.FECHA_ALTA) < 19)))
	                    THEN v_const_s
	                ELSE v_const_n
				END)
         END) AS RH_MAYOR_ANIO
         
    FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_BIS TBL
    LEFT JOIN :TBL_MOTIVOS_BAJA_CUENTA MB
        ON MB.CODIGO = TBL.MOTIVO_BAJA
    LEFT JOIN :TBL_FECHA_EMISION_ASEG FE
        ON FE.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND FE.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        AND FE.FECHA_EFECTO_RECIBO = TBL.FECHA_ALTA;

    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_1_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_1_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
	
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_2_BIS = 
        SELECT TBL.* 
            ,CASE WHEN FECHA_EMISION_ASEG >=  TO_DATE ('19/05/2020', 'dd/mm/yyyy') THEN v_const_unidad_poliza_jun_2020 ELSE v_const_unidad_poliza
            END AS MULTIPLICADOR_UNIDAD_POLIZA
            ,CASE WHEN CAST(ES_PERIODO_EXTORNABLE AS VARCHAR) IN (v_const_s, v_const_s_1) AND FECHA_ALTA >= TO_DATE('01/01/2017', 'dd/mm/yyyy') AND (FECHA_BAJA IS NULL
                       OR (FECHA_BAJA IS NOT NULL AND CAST(CUENTO_COMO_BAJA AS VARCHAR) IN (v_const_s, v_const_s_1)) 
                       OR (FECHA_BAJA IS NOT NULL AND FECHA_REHABILITACION IS NOT NULL)) THEN 0
            END AS PORCENTAJE_NIVELADA_CALC
            ,CASE WHEN EDAD <= v_const_max_edad 
                          OR (EDAD > v_const_max_edad AND IFNULL(PRIMA_UNICA,v_const_n_0) = v_const_s_1) THEN v_const_s_1 ELSE v_const_n_0
            END AS EDADMAX_PRIMAUNICA
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_1_BIS TBL
        --FILTRAMOS LOS CASOS QUE CALCULAN UNIDAD_DE_POLIZAS = 0
        --20251016 RMF: Solo se comprueba periodo extornable si la fecha de baja es no nula
        WHERE (CAST(ES_PERIODO_EXTORNABLE AS VARCHAR) IN (v_const_s, v_const_s_1) OR TBL.FECHA_BAJA IS NULL)
            AND FECHA_ALTA >= TO_DATE('01/01/2017', 'dd/mm/yyyy')
	        AND (
	        	FECHA_BAJA IS NULL
	            OR (FECHA_BAJA IS NOT NULL AND CAST(CUENTO_COMO_BAJA AS VARCHAR) IN (v_const_s, v_const_s_1)) 
	            OR (FECHA_BAJA IS NOT NULL AND FECHA_REHABILITACION IS NOT NULL)
        	)
        	--Excepcion: Si es RC o RO, solamente se tiene en cuenta si ha pasado mas de un año.
        	AND TBL.RH_MAYOR_ANIO = v_const_s
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_2_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_2_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_3_BIS = 
        SELECT TBL.*
            ,IFNULL(CAP_NIVELADO,0) AS CAPITAL_NIVELADO_CALC
            ,IFNULL(CAP_NATURAL,0) AS CAPITAL_NATURAL_CALC
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_2_BIS TBL
        WHERE EDADMAX_PRIMAUNICA = v_const_s_1
    ;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_3_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_3_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_4_BIS = 
        SELECT TBL.*
            ,(CAPITAL_NIVELADO_CALC*100) / (CAPITAL_NATURAL_CALC + CAPITAL_NIVELADO_CALC) AS V_TEMP
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_3_BIS TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_4_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_4_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_5_BIS =
        SELECT TBL.*,
            CASE WHEN V_TEMP > 100 THEN 100 ELSE V_TEMP END AS PORCENTAJE_NIVELADA_CALC_1
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_4_BIS TBL;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_5_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_5_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');    
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_6_BIS = 
        SELECT TBL.*,
            CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC_1 >= 70
                        THEN 100
                WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC_1 >= 56 AND PORCENTAJE_NIVELADA_CALC < 70
                        THEN PORCENTAJE_NIVELADA_CALC_1/0.7 ELSE PORCENTAJE_NIVELADA_CALC_1
            END AS PORCENTAJE_NIVELADA_CALC_2
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_5_BIS TBL;    
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_6_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_6 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_ANT =
    	SELECT ASE_ANT.*,
			IFNULL(GA_ANT.CAPITAL_NATURAL,0) AS CAPITAL_NATURAL_ANT,
			IFNULL(GA_ANT.CAPITAL_NIVELADO,0) AS CAPITAL_NIVELADO_ANT,
			GA_ANT.UNIDAD_DE_POLIZA AS UNIDAD_POLIZA_ANT,
			(CASE WHEN (GA_ANT.CAPITAL_NIVELADO*100) / (GA_ANT.CAPITAL_NATURAL + GA_ANT.CAPITAL_NIVELADO) > 100
				THEN 100 ELSE (GA_ANT.CAPITAL_NIVELADO*100) / (GA_ANT.CAPITAL_NATURAL + GA_ANT.CAPITAL_NIVELADO)
			END) AS PORCENTAJE_NIVELADA_CALC_ANT,
			TBL.FECHA_EMISION_POLIZA,
			ROW_NUMBER() OVER(
			  	PARTITION BY TBL.CODIGO_POLIZA,TBL.NUMERO_ASEGURADO,TBL.CODIGO_RECIBO
			  	ORDER BY GA_ANT.FECHA_ALTA_GAR_ASE DESC,
		        	--DECODE en Oracle equivale a MAP en HANA.
		            MAP(GA_ANT.SUBTIPO_MOVIMIENTO,v_const_tipo_mov_supinase,2,1),
		            GA_ANT.NUM_ORDEN_MOVIMIENTO
			) AS RN_RECIBO
        FROM EXT.ASEGURADOS ASE_ANT
        INNER JOIN EXT.GARANTIAS_ASEGURADO GA_ANT
        	ON ASE_ANT.CODIGO_POLIZA = GA_ANT.CODIGO_POLIZA
        	AND ASE_ANT.NUMERO_ASEGURADO = GA_ANT.NUMERO_ASEGURADO
        INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_66_6_BIS TBL
        	ON GA_ANT.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        	AND GA_ANT.CODIGO_RECIBO <> TBL.CODIGO_RECIBO
        	AND GA_ANT.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
        	AND GA_ANT.NUMERO_ASEGURADO = TBL.NUMERO_ASEGURADO
        WHERE (ASE_ANT.FECHA_BAJA IS NULL
            OR (ASE_ANT.FECHA_BAJA IS NOT NULL AND ASE_ANT.FECHA_REHABILITACION IS NOT NULL))
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ANT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ANT '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
   ------------------------------TGV 20250828 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_ANT_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_ANT_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_ANT_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_ANT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ANT_DEBUG' , i_log_count, i_id_proceso, 'debug');
	----------------------------------
    
    
    TBL_ASEGURADOS_ANT_2 =
    	SELECT TBL.*,
    		
			CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC_ANT >= 70
                        THEN 100
                WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC_ANT >= 56 AND PORCENTAJE_NIVELADA_CALC_ANT < 70
                        THEN PORCENTAJE_NIVELADA_CALC_ANT/0.7 ELSE PORCENTAJE_NIVELADA_CALC_ANT
            END AS PORCENTAJE_NIVELADA_CALC_ANT_2,
            
            (CASE WHEN TBL.FECHA_ALTA >= TO_DATE ('19/05/2020', 'dd/mm/yyyy') THEN IFNULL(UNIDAD_POLIZA_ANT,0) ELSE 0
            END) AS UNIDAD_POLIZA_ANT_CALC,
            
            (CASE WHEN TBL.FECHA_ALTA >= TO_DATE ('19/05/2020', 'dd/mm/yyyy') THEN v_const_s ELSE v_const_n
            END) AS EXISTE_CALC_ASEG_ANT
            
        FROM :TBL_ASEGURADOS_ANT TBL
        WHERE RN_RECIBO = 1
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_ANT_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_ANT_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_7_BIS = 
        SELECT TBL.*,
        	ASEG_ANT.UNIDAD_POLIZA_ANT_CALC,
        	ASEG_ANT.PORCENTAJE_NIVELADA_CALC_ANT_2,
        	ASEG_ANT.EXISTE_CALC_ASEG_ANT,
        	
        	(CASE WHEN TBL.CAPITAL_NIVELADO_CALC <> ASEG_ANT.CAPITAL_NIVELADO_ANT THEN v_const_s ELSE v_const_n
            END) AS MODIF_CAPITAL_NIVELADO,
            
            (CASE WHEN ASEG_ANT.EXISTE_CALC_ASEG_ANT = v_const_s AND TBL.FECHA_BAJA IS NULL
            		THEN TBL.MULTIPLICADOR_UNIDAD_POLIZA * (TBL.PORCENTAJE_NIVELADA_CALC_2/100)
            	WHEN ASEG_ANT.UNIDAD_POLIZA_ANT_CALC IS NOT NULL OR TBL.MOTIVO_ALTA = v_const_motivo_alta_rc
            		THEN TBL.MULTIPLICADOR_UNIDAD_POLIZA * ((TBL.PORCENTAJE_NIVELADA_CALC_2 - ifnull(ASEG_ANT.PORCENTAJE_NIVELADA_CALC_ANT_2,0))/100)
            	ELSE
            		(CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_np,v_const_motivo_alta_co)
            				OR (TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re,v_const_motivo_alta_ro)
            					AND (CASE WHEN TBL.FECHA_BAJA IS NOT NULL AND TBL.FECHA_REHABILITACION IS NOT NULL
										THEN DAYS_BETWEEN(TBL.FECHA_BAJA, TBL.FECHA_REHABILITACION) ELSE 0
                    				END) > v_const_365_dias)
                        THEN TBL.MULTIPLICADOR_UNIDAD_POLIZA * (TBL.PORCENTAJE_NIVELADA_CALC_2/100)
                    END)
            		
			END) AS UNIDAD_DE_POLIZA_CALC_1,
            
            (CASE WHEN ASEG_ANT.EXISTE_CALC_ASEG_ANT = v_const_s AND TBL.FECHA_BAJA IS NULL
            		THEN v_const_n
            	WHEN ASEG_ANT.UNIDAD_POLIZA_ANT_CALC IS NOT NULL OR TBL.MOTIVO_ALTA = v_const_motivo_alta_rc
            		THEN v_const_s
            	ELSE
            		(CASE WHEN TBL.MOTIVO_ALTA IN (v_const_motivo_alta_np,v_const_motivo_alta_co)
            				OR (TBL.MOTIVO_ALTA IN (v_const_motivo_alta_re,v_const_motivo_alta_ro)
            					AND (CASE WHEN TBL.FECHA_BAJA IS NOT NULL AND TBL.FECHA_REHABILITACION IS NOT NULL
										THEN DAYS_BETWEEN(TBL.FECHA_BAJA, TBL.FECHA_REHABILITACION) ELSE 0
                    				END) > v_const_365_dias)
                        THEN v_const_s
                    END)
			END) AS EXISTE_ASEG_RC
			
			 , ROW_NUMBER() OVER(
                      		PARTITION BY TBL.CODIGO_POLIZA, TBL.PRODUCTO_CONTABLE, TBL.NUMERO_ASEGURADO
                      		ORDER BY TBL.CODIGO_POLIZA  DESC
                      ) AS RN
        	
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_6_BIS TBL
        LEFT JOIN :TBL_ASEGURADOS_ANT_2 ASEG_ANT
        	ON TBL.CODIGO_POLIZA = ASEG_ANT.CODIGO_POLIZA
        	AND TBL.NUMERO_ASEGURADO = ASEG_ANT.NUMERO_ASEGURADO
        	AND TBL.PRODUCTO_CONTABLE = SUBSTR(ASEG_ANT.CODIGO_POLIZA,1,7)
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_7_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_7_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_BIS = 
        SELECT TBL.*,
        
        (CASE WHEN TBL.EXISTE_CALC_ASEG_ANT = v_const_s AND TBL.FECHA_BAJA IS NULL
        	THEN
		        (CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND TBL.FECHA_EMISION_ASEG between TO_DATE ('20/07/2021', 'dd/mm/yyyy') AND TO_DATE ('18/08/2021', 'dd/mm/yyyy')
		        	AND (ABS(TBL.UNIDAD_DE_POLIZA_CALC_1) < 0.15)
		                THEN 0.15
		            WHEN TBL.MULTIPLICADOR_UNIDAD_POLIZA = v_const_unidad_poliza_jun_2020 AND TBL.UNIDAD_DE_POLIZA_CALC_1 < 0.10
		                THEN 0.10
		            ELSE TBL.UNIDAD_DE_POLIZA_CALC_1
		        END)
			ELSE TBL.UNIDAD_DE_POLIZA_CALC_1
		END) AS UNIDAD_DE_POLIZA_CALC_2
        
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_7_BIS TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_9_BIS = 
        SELECT TBL.*,
        
        (CASE WHEN TBL.EXISTE_CALC_ASEG_ANT = v_const_s AND TBL.FECHA_BAJA IS NULL
        	THEN 
		        (CASE WHEN TBL.UNIDAD_DE_POLIZA_CALC_2 > 0 AND TBL.UNIDAD_POLIZA_ANT_CALC = 0
		        	THEN TBL.MULTIPLICADOR_UNIDAD_POLIZA * ((TBL.PORCENTAJE_NIVELADA_CALC_2 - TBL.PORCENTAJE_NIVELADA_CALC_ANT_2)/100)
		        	ELSE TBL.UNIDAD_DE_POLIZA_CALC_2 - TBL.UNIDAD_POLIZA_ANT_CALC
        		END)
        	ELSE TBL.UNIDAD_DE_POLIZA_CALC_2
        END) AS UNIDAD_DE_POLIZA_CALC_3
        
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_8_BIS TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_9_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_9_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS = 
        SELECT TBL.*
        
        ,CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND TBL.FECHA_EMISION_ASEG between TO_DATE ('20/07/2021', 'dd/mm/yyyy') AND TO_DATE ('18/08/2021', 'dd/mm/yyyy')
        		AND (ABS(TBL.UNIDAD_DE_POLIZA_CALC_3) < 0.15)
                AND ((TBL.FECHA_BAJA IS NOT NULL)
                	OR (TBL.FECHA_BAJA IS NULL AND TBL.FECHA_ALTA = TBL.FECHA_EFECTO_REC AND TBL.UNIDAD_POLIZA_ANT_CALC IS NULL))
                THEN 
        			CASE WHEN TBL.UNIDAD_DE_POLIZA_CALC_3 < 0 THEN -0.15 ELSE 0.15 END 
            WHEN TBL.MULTIPLICADOR_UNIDAD_POLIZA = v_const_unidad_poliza_jun_2020 AND (ABS(TBL.UNIDAD_DE_POLIZA_CALC_3) < 0.10)
            	AND ((TBL.FECHA_BAJA IS NOT NULL)
                	OR (TBL.FECHA_BAJA IS NULL AND TBL.FECHA_ALTA = TBL.FECHA_EFECTO_REC AND TBL.UNIDAD_POLIZA_ANT_CALC IS NULL))
                THEN
                    CASE WHEN TBL.UNIDAD_DE_POLIZA_CALC_3 < 0 THEN -0.10 ELSE 0.10 END  
			WHEN TBL.FECHA_BAJA IS NOT NULL THEN TBL.UNIDAD_DE_POLIZA_CALC_3 * -1
            WHEN TBL.UNIDAD_DE_POLIZA_CALC_3 < 0 AND TBL.ES_PERIODO_EXTORNABLE IN (v_const_n, v_const_n_0) THEN 0
            ELSE TBL.UNIDAD_DE_POLIZA_CALC_3
        END AS UNIDAD_DE_POLIZA_CALC_4
        
       /*  , ROW_NUMBER() OVER(
                      		PARTITION BY CODIGO_POLIZA, NUMERO_ASEGURADO, PRODUCTO_CONTABLE, CODIGO_RECIBO
                      		ORDER BY CODIGO_POLIZA, NUMERO_ASEGURADO, PRODUCTO_CONTABLE, CODIGO_RECIBO DESC
                      ) AS RN_GA*/
                      
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_9_BIS TBL
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
      	 ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS = 
        SELECT TBL.*
        , CASE WHEN (CASE WHEN TBL.FECHA_BAJA IS NOT NULL THEN TBL.UNIDAD_DE_POLIZA_CALC_4 * -1 ELSE TBL.UNIDAD_DE_POLIZA_CALC_4 END) < 0 AND TBL.ES_PERIODO_EXTORNABLE IN (v_const_n, v_const_n_0) THEN 0
        	ELSE (CASE WHEN TBL.FECHA_BAJA IS NOT NULL AND TBL.UNIDAD_DE_POLIZA_CALC_4 > 0 THEN TBL.UNIDAD_DE_POLIZA_CALC_4 * -1 ELSE TBL.UNIDAD_DE_POLIZA_CALC_4 END)
        END AS UNIDAD_DE_POLIZA_CALC_5
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS TBL
    ;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    
    
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
    ROLLBACK;
    
    CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE en EXT.GARANTIAS_ASEGURADO para TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                        
    --Se actualizan los registros de POLIZAS con estado erróneo
    UPDATE EXT.GARANTIAS_ASEGURADO GA
        SET ESTADO = v_const_calculo_status_error,
            FECHA_MODIFICACION = CURRENT_TIMESTAMP
        FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS src
    WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
        AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
        AND src.ESTADO = v_const_populate_status_ok;
    
    COMMIT;     
    RESIGNAL;
    END;
    
     /*   MERGE INTO EXT.GARANTIAS_ASEGURADO GA
        USING(
            SELECT DISTINCT CODIGO_POLIZA,NUMERO_ASEGURADO,CODIGO_RECIBO,PRODUCTO_CONTABLE,UNIDAD_DE_POLIZA_CALC_4,PORCENTAJE_NIVELADA_CALC_2 
            
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS
            WHERE RN_GA = 1
        )src
        ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA
        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
        AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
        AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
        WHEN MATCHED THEN UPDATE SET
            GA.UNIDAD_DE_POLIZA = ROUND(src.UNIDAD_DE_POLIZA_CALC_4,4),
            GA.PORCENTAJE_NIVELADA = ROUND(src.PORCENTAJE_NIVELADA_CALC_2/100,2),
            GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
           */ 
            
        UPDATE EXT.GARANTIAS_ASEGURADO GA
        SET 	GA.UNIDAD_DE_POLIZA = ROUND(src.UNIDAD_DE_POLIZA_CALC_5,4),
            	GA.PORCENTAJE_NIVELADA = ROUND(src.PORCENTAJE_NIVELADA_CALC_2/100,2),
            	GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP
        FROM EXT.GARANTIAS_ASEGURADO GA INNER JOIN :TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS src
	        ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA
	        AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
	        AND GA.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
	        AND GA.CODIGO_RECIBO = src.CODIGO_RECIBO
	        --WHERE src.RN_GA = 1
	        WHERE RN = 1;
    
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_ASEGURADO para TBL_ASEGURADOS_UNIDAD_POLIZA_66_10_BIS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');

    END;
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT_BIS = 
    	SELECT DISTINCT TBL.CODIGO_POLIZA,
			TBL.CODIGO_RECIBO,
			TBL.PRODUCTO_CONTABLE,
			TBL.CODIGO_SUPLEMENTO,
			TBL.ESTADO_RECIBO,
			TBL.NUMERO_ASEGURADO,
			TBL.ALTA_DE,
			TBL.MOTIVO_ALTA,
			(CASE WHEN ifnull(TBL.ASEGURADOS_NETOS,0) <> 0 OR TBL.MODIF_CAPITAL_NIVELADO = v_const_s THEN TBL.UNIDAD_DE_POLIZA_CALC_5 ELSE 0 END) AS UNIDAD_DE_POLIZA_CALC_FINAL,
			TBL.PORCENTAJE_NIVELADA_CALC_2
		
		FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_11_BIS TBL
		WHERE TBL.RN = 1
    ;
    
     v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT_BIS: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
      TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS = 
    	SELECT  TBL.CODIGO_POLIZA,
    			TBL.CODIGO_RECIBO,
    			TBL.PRODUCTO_CONTABLE,
    			TBL.CODIGO_SUPLEMENTO,
    			TBL.ESTADO_RECIBO,
    			TBL.MOTIVO_ALTA,
				TBL.ALTA_DE,
    			SUM(TBL.UNIDAD_DE_POLIZA_CALC_FINAL) AS SUM_UNIDAD_DE_POLIZA_CALC_FINAL,
    			ROUND(SUM(TBL.PORCENTAJE_NIVELADA_CALC_2)/ COUNT(DISTINCT NUMERO_ASEGURADO),2) AS SUM_PORCENTAJE_NIVELADA_CALC_2
	    	/*	, ROW_NUMBER() OVER(
	                      		PARTITION BY CODIGO_POLIZA, PRODUCTO_CONTABLE, CODIGO_RECIBO, CODIGO_SUPLEMENTO, ESTADO_RECIBO
	                      		ORDER BY CODIGO_POLIZA DESC
	                      ) AS RN_GR*/
    		
    	FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_DISTINCT_BIS TBL
    	GROUP BY	TBL.CODIGO_POLIZA,
	    			TBL.CODIGO_RECIBO,
	    			TBL.PRODUCTO_CONTABLE,
	    			TBL.CODIGO_SUPLEMENTO,
	    			TBL.ESTADO_RECIBO,
    				TBL.MOTIVO_ALTA,
					TBL.ALTA_DE;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_2 = 
    	SELECT  TBL.*,
    			CASE WHEN TBL.MOTIVO_ALTA = v_const_motivo_alta_de AND TBL.ALTA_DE = v_const_s_1 THEN TBL.SUM_UNIDAD_DE_POLIZA_CALC_FINAL + v_const_unidad_poliza_corrector 
    				ELSE TBL.SUM_UNIDAD_DE_POLIZA_CALC_FINAL END AS SUM_UNIDAD_DE_POLIZA_CALC_FINAL_2
    	FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3 = 
    	SELECT  TBL.CODIGO_POLIZA,
    			TBL.CODIGO_RECIBO,
    			TBL.PRODUCTO_CONTABLE,
    			TBL.CODIGO_SUPLEMENTO,
    			TBL.ESTADO_RECIBO,
    			SUM(TBL.SUM_UNIDAD_DE_POLIZA_CALC_FINAL_2) AS SUM_UNIDAD_DE_POLIZA_CALC_FINAL_3,
    			MAX (TBL.SUM_PORCENTAJE_NIVELADA_CALC_2) AS SUM_PORCENTAJE_NIVELADA_CALC_3
    	FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_2 TBL
    	GROUP BY TBL.CODIGO_POLIZA,
	    		TBL.CODIGO_RECIBO,
	    		TBL.PRODUCTO_CONTABLE,
	    		TBL.CODIGO_SUPLEMENTO,
	    		TBL.ESTADO_RECIBO;
    			
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	    BEGIN
	        
	        ROLLBACK;
	        
	        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBO para TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
	                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
	                
	        --Se actualizan los registros de POLIZAS con estado erróneo
	        UPDATE EXT.GARANTIAS_RECIBO GR
	            SET ESTADO = v_const_calculo_status_error,
	                FECHA_MODIFICACION = CURRENT_TIMESTAMP
	            FROM EXT.GARANTIAS_RECIBO GR, :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3 src
	        WHERE  GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
	            AND GR.ESTADO = v_const_populate_status_ok;
	        
	        COMMIT;     
	        RESIGNAL;
	    END;
	    
    	  MERGE INTO EXT.GARANTIAS_RECIBO GR
    	  USING (
    	  	SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR_BIS_3 
    	  ) src
	    	  ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
	    	  --AND RN_GR = 1
    	  WHEN MATCHED THEN UPDATE SET
    	   GR.UNIDAD_DE_POLIZA = ROUND( src.SUM_UNIDAD_DE_POLIZA_CALC_FINAL_3, 4),
           GR.PORCENTAJE_NIVELADA = ROUND(src.SUM_PORCENTAJE_NIVELADA_CALC_3/100,2), 
           GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
    
       v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_RECIBO para TBL_ASEGURADOS_UNIDAD_POLIZA_66_GR. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;
    
    
    
----------------EXCEPCIONES LIN3906 CALCULO
    
---------------------------------FT_UNIDAD_DE_POLIZA_65 5414
   TBL_ASEGURADOS_UNIDAD_POLIZA_65 = 
        SELECT GA.*,
        ASE.FECHA_ALTA,
        ASE.MOTIVO_ALTA,
        ASE.FECHA_BAJA,
        ASE.FECHA_REHABILITACION,
        ASE.POLIZA_ORIGEN,
        ASE.ASEGURADO_ORIGEN,
        ASE.EDAD,
        CASE WHEN ASE.EDAD <= v_const_max_edad
                  OR (ASE.EDAD > v_const_max_edad AND IFNULL(GA.PRIMA_UNICA,v_const_n_0) = v_const_s_1)
                  OR (SUBSTR(TBL.CODIGO_POLIZA,1,4) = '0124')
        THEN v_const_s_1 ELSE v_const_n_0 
        END AS EDADMAX_PRIMAUNICA,
        CASE WHEN ASE.EDAD >= v_const_mayor_edad THEN v_const_s_1 ELSE v_const_n_0 
        END AS CORRECTOR_SN,
        CAPITAL_NIVELADO AS CAP_NIVELADO,
        CAPITAL_NATURAL AS CAP_NATURAL,
        POL.FECHA_EMISION_POLIZA,
        CASE WHEN INSTR(UPPER(POL.TIPO_CAMPANIA),v_const_campania_cruzada) > 0 THEN v_const_unidad_poliza_cruzada
                    WHEN POL.FECHA_EMISION_POLIZA >= TO_DATE ('19/05/2020', 'dd/mm/yyyy') THEN v_const_unidad_poliza_jun_2020
                    ELSE v_const_unidad_poliza
        END AS MULTIPLICADOR_UNIDAD_POLIZA,
        TBL.CODIGO_SUPLEMENTO,
        TBL.ESTADO_RECIBO,
        ASE.CONTO_COMO_NUEVO
        FROM EXT.ASEGURADOS ASE,
        EXT.GARANTIAS_ASEGURADO GA  INNER JOIN :TBL_RECIBOS_71_66_65_UNI_POL TBL ON TBL.CODIGO_POLIZA = GA.CODIGO_POLIZA AND TBL.CODIGO_RECIBO= GA.CODIGO_RECIBO INNER JOIN EXT.POLIZAS POL ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
        WHERE ASE.CODIGO_POLIZA = GA.CODIGO_POLIZA
        AND ASE.NUMERO_ASEGURADO = GA.NUMERO_ASEGURADO
        AND GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
        AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
        AND ASE.MOTIVO_ALTA IN (v_const_motivo_alta_np,
                              v_const_motivo_alta_co,
                              v_const_motivo_alta_rc,
                              v_const_motivo_alta_ro,
                              v_const_motivo_alta_de)
        AND GA.PRODUCTO_CONTABLE =  substr(TBL.CODIGO_POLIZA,1,2) || substr(TBL.CODIGO_POLIZA,3,5)
        AND (ASE.FECHA_BAJA IS NULL OR (
           ASE.FECHA_BAJA IS NOT NULL AND
           GA.SUBTIPO_MOVIMIENTO = v_const_tipo_mov_rehabili AND
           ASE.FECHA_ALTA = TBL.FECHA_EFECTO_RECIBO
          ))
        AND TBL.PERMANENCIA = v_const_recibos_especificos_65;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');       

    TBL_ASEGURADOS_UNIDAD_POLIZA_65_1 = 
        SELECT TBL.*,
            CASE WHEN EDADMAX_PRIMAUNICA = v_const_s_1 THEN IFNULL(TBL.CAP_NIVELADO,0) ELSE v_const_n_0
            END AS CAPITAL_NIVELADO_CALC,
            
            CASE WHEN EDADMAX_PRIMAUNICA = v_const_s_1 THEN IFNULL(TBL.CAP_NATURAL,0) ELSE v_const_n_0
            --3251
            END AS CAPITAL_NATURAL_CALC,
            CASE WHEN CONTO_COMO_NUEVO IS NULL AND TBL.MOTIVO_ALTA = v_const_motivo_alta_de THEN 
                    (SELECT COUNT(T.MOTIVO_ALTA) 
                            FROM EXT.ASEGURADOS T
                            WHERE T.CODIGO_POLIZA = TBL.CODIGO_POLIZA  
                            AND T.MOTIVO_ALTA IN (v_const_motivo_alta_np,v_const_motivo_alta_co)) ELSE v_const_n_0
                END AS ALTA_DE
          
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65 TBL;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_1);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_1 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');     

    
    TBL_ASEGURADOS_UNIDAD_POLIZA_65_2 =
        SELECT TBL.*,
                CASE WHEN CAPITAL_NIVELADO_CALC + EDADMAX_PRIMAUNICA <> 0 THEN (CAPITAL_NIVELADO_CALC*100) / (CAPITAL_NATURAL_CALC + CAPITAL_NIVELADO_CALC) ELSE 0
                END AS V_TEMP
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_1 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_2);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_2 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');        
    
        
    TBL_ASEGURADOS_UNIDAD_POLIZA_65_3 =
        SELECT TBL.*,
            CASE WHEN V_TEMP > 100 THEN 100 ELSE V_TEMP END AS PORCENTAJE_NIVELADA_CALC
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_2 TBL;
            
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_3);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_3 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');       

    TBL_ASEGURADOS_UNIDAD_POLIZA_65_4 = 
        SELECT TBL.*,
                CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC >= 70
                            THEN 100
                    WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA  BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND PORCENTAJE_NIVELADA_CALC >= 56 AND PORCENTAJE_NIVELADA_CALC < 70
                            THEN PORCENTAJE_NIVELADA_CALC/0.7 ELSE PORCENTAJE_NIVELADA_CALC END AS PORCENTAJE_NIVELADA_CALC_1
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_3 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_4);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_4 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');     


     TBL_ASEGURADOS_UNIDAD_POLIZA_65_5 = 
            SELECT TBL.*,
                MULTIPLICADOR_UNIDAD_POLIZA * (PORCENTAJE_NIVELADA_CALC_1/100) AS UNIDAD_DE_POLIZA_CALC
             FROM   :TBL_ASEGURADOS_UNIDAD_POLIZA_65_4 TBL;
             
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_5);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_5 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');      
 
             
    TBL_ASEGURADOS_UNIDAD_POLIZA_65_6 = 
        SELECT TBL.*,
            CASE WHEN TBL.CODIGO_POLIZA LIKE '01%' AND FECHA_EMISION_POLIZA BETWEEN TO_DATE('20/07/2021','dd/mm/yyyy') AND TO_DATE('18/08/2021','dd/mm/yyyy') AND UNIDAD_DE_POLIZA_CALC < 0.15 
                    THEN 0.15
                WHEN MULTIPLICADOR_UNIDAD_POLIZA = v_const_unidad_poliza_jun_2020 AND UNIDAD_DE_POLIZA_CALC < 0.10 
                    THEN 0.10
                ELSE UNIDAD_DE_POLIZA_CALC
            END AS UNIDAD_DE_POLIZA_CALC_1
            ,CASE WHEN FECHA_BAJA IS NULL OR DAYS_BETWEEN(FECHA_BAJA, FECHA_REHABILITACION) >= v_const_365_dias OR 
            (TBL.PRODUCTO_CONTABLE IN ('22020','22035','29018','29020') AND
              ((EXTRACT(MONTH FROM FECHA_BAJA) = EXTRACT(MONTH FROM FECHA_REHABILITACION)
                    AND (EXTRACT(DAY FROM FECHA_REHABILITACION) < 19 OR EXTRACT(DAY FROM FECHA_BAJA) > 18)) OR
              (EXTRACT(MONTH FROM FECHA_BAJA) <> EXTRACT(MONTH FROM FECHA_REHABILITACION)
                    AND EXTRACT(DAY FROM FECHA_BAJA) > 18 AND EXTRACT(DAY FROM FECHA_REHABILITACION) < 19)))
                    THEN v_const_s ELSE v_const_n
             END AS RH_MAYOR_ANIO
        FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_5 TBL;
        
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_6);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_6 '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');      
 
	 ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_65_6_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_65_6_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_65_6_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_6);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_6_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
 
 
 
 
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_ASEGURADO para TBL_ASEGURADOS_UNIDAD_POLIZA_65_6 - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.GARANTIAS_ASEGURADO GA
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.GARANTIAS_ASEGURADO GA, :TBL_ASEGURADOS_UNIDAD_POLIZA_65_6 src
        WHERE GA.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
            AND GA.PRODUCTO_CONTABLE =  substr(src.CODIGO_POLIZA,1,2) || substr(src.CODIGO_POLIZA,3,5)
            AND GA.CODIGO_RECIBO =  src.CODIGO_RECIBO
            AND src.RH_MAYOR_ANIO = v_const_s --solo los que sean RH_MAYOR_ANIO
            AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
    END;
    
        MERGE INTO EXT.GARANTIAS_ASEGURADO GA
         USING(
            SELECT  DISTINCT TBL.CODIGO_POLIZA,
            		TBL.CODIGO_RECIBO,
            		TBL.NUMERO_ASEGURADO,
            		TBL.RH_MAYOR_ANIO,
            		TBL.UNIDAD_DE_POLIZA_CALC_1,
            		TBL.PORCENTAJE_NIVELADA_CALC_1
            FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_6 TBL
           
        )src
        ON GA.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND GA.NUMERO_ASEGURADO = src.NUMERO_ASEGURADO
            AND GA.PRODUCTO_CONTABLE =  substr(src.CODIGO_POLIZA,1,2) || substr(src.CODIGO_POLIZA,3,5)
            AND GA.CODIGO_RECIBO =  src.CODIGO_RECIBO
            AND src.RH_MAYOR_ANIO = v_const_s --solo los que sean RH_MAYOR_ANIO
        WHEN MATCHED THEN UPDATE SET
            GA.UNIDAD_DE_POLIZA = ROUND(src.UNIDAD_DE_POLIZA_CALC_1,4),
            GA.PORCENTAJE_NIVELADA = ROUND(src.PORCENTAJE_NIVELADA_CALC_1/100,2),
            GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
            
        v_num_rows := ::rowcount;
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.GARANTIAS_ASEGURADO para TBL_ASEGURADOS_UNIDAD_POLIZA_65_6. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
    END;
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DISTINCT = 
    	SELECT DISTINCT TBL.CODIGO_POLIZA,
			TBL.CODIGO_RECIBO,
			TBL.PRODUCTO_CONTABLE,
			TBL.CODIGO_SUPLEMENTO,
			TBL.ESTADO_RECIBO,
			TBL.NUMERO_ASEGURADO,
			POL.MOTIVO_ALTA, 
			MAX(TBL.ALTA_DE) AS ALTA_DE,
			TBL.UNIDAD_DE_POLIZA_CALC_1,
			TBL.PORCENTAJE_NIVELADA_CALC_1
		FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_6 TBL
    	INNER JOIN EXT.POLIZAS POL
    		ON TBL.CODIGO_POLIZA = POL.CODIGO_POLIZA
    	GROUP BY TBL.CODIGO_POLIZA,
			TBL.CODIGO_RECIBO,
			TBL.PRODUCTO_CONTABLE,
			TBL.CODIGO_SUPLEMENTO,
			TBL.ESTADO_RECIBO,
			TBL.NUMERO_ASEGURADO,
			POL.MOTIVO_ALTA, 
			TBL.UNIDAD_DE_POLIZA_CALC_1,
			TBL.PORCENTAJE_NIVELADA_CALC_1
    ;
    
     v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DISTINCT);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DISTINCT: '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
    TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR = 
    	SELECT  TBL.CODIGO_POLIZA,
    			TBL.CODIGO_RECIBO,
    			TBL.PRODUCTO_CONTABLE,
    			TBL.CODIGO_SUPLEMENTO,
    			TBL.ESTADO_RECIBO,
    			TBL.MOTIVO_ALTA,
    			TBL.ALTA_DE,
    			SUM(TBL.UNIDAD_DE_POLIZA_CALC_1) AS SUM_UNIDAD_DE_POLIZA_CALC_1,
    			ROUND(SUM(TBL.PORCENTAJE_NIVELADA_CALC_1)/ COUNT(DISTINCT NUMERO_ASEGURADO),2) AS SUM_PORCENTAJE_NIVELADA_CALC_1,
    			ROW_NUMBER() OVER(
				  	PARTITION BY TBL.CODIGO_POLIZA,TBL.CODIGO_RECIBO,TBL.CODIGO_SUPLEMENTO, TBL.ESTADO_RECIBO, TBL.PRODUCTO_CONTABLE
				  	ORDER BY TBL.CODIGO_POLIZA DESC
		        ) AS RN_GR
    			
    	FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DISTINCT TBL
    	GROUP BY	TBL.CODIGO_POLIZA,
	    			TBL.CODIGO_RECIBO,
	    			TBL.PRODUCTO_CONTABLE,
	    			TBL.CODIGO_SUPLEMENTO,
	    			TBL.ESTADO_RECIBO,
	    			TBL.MOTIVO_ALTA,
    				TBL.ALTA_DE
    	;
    
    v_num_rows = RECORD_COUNT(:TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug'); 
    
    ------------------------------TGV 20250827 --TABLA DEBUG PENDIENTE BORRAR
    SELECT COUNT(1) INTO v_existe_tabla FROM SYS.TABLES WHERE TABLE_NAME = 'TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DEBUG';
	
	IF v_existe_tabla > 0 THEN
		DROP TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DEBUG;
	END IF;
	
	CREATE TABLE EXT.TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DEBUG AS (SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR_DEBUG' , i_log_count, i_id_proceso, 'debug');
    ------------------------------
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	    BEGIN
	        
	        ROLLBACK;
	        
	        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.GARANTIAS_RECIBO para TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
	                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
	                
	        --Se actualizan los registros de POLIZAS con estado erróneo
	        UPDATE EXT.GARANTIAS_RECIBO GR
	            SET ESTADO = v_const_calculo_status_error,
	                FECHA_MODIFICACION = CURRENT_TIMESTAMP
	            FROM EXT.GARANTIAS_RECIBO GR, :TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR src
	        WHERE  GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
	            AND GR.ESTADO = v_const_populate_status_ok;
	        
	        COMMIT;     
	        RESIGNAL;
	    END;
    	  MERGE INTO EXT.GARANTIAS_RECIBO GR
    	  USING (
    	  	SELECT * FROM :TBL_ASEGURADOS_UNIDAD_POLIZA_65_GR WHERE RN_GR = 1
    	  ) src
	    	  ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
	    	  AND GR.CODIGO_RECIBO = src.CODIGO_RECIBO
	    	  AND GR.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
	    	  AND GR.ESTADO_RECIBO = src.ESTADO_RECIBO
	    	  AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
    	  WHEN MATCHED THEN UPDATE SET
    	   GR.UNIDAD_DE_POLIZA = ROUND((CASE WHEN src.MOTIVO_ALTA IN (v_const_motivo_alta_tp, v_const_motivo_alta_ts, v_const_motivo_alta_dt ) THEN 	src.SUM_UNIDAD_DE_POLIZA_CALC_1 
    										WHEN src.MOTIVO_ALTA = v_const_motivo_alta_de AND src.ALTA_DE = v_const_n_0 THEN src.SUM_UNIDAD_DE_POLIZA_CALC_1 
    										ELSE 	src.SUM_UNIDAD_DE_POLIZA_CALC_1 + v_const_unidad_poliza_corrector 
    									END),4),
           GR.PORCENTAJE_NIVELADA = ROUND(src.SUM_PORCENTAJE_NIVELADA_CALC_1/100,2), 
           GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
    
    
    END;
    
    
    
-------------------------------------igual solo se estan actualizando las garantias principales------------- pendiente revision en pruebas


    -------- TGV 20250826 -- añadimos merge para la prima de las garantias de recibo
    /*
     TBL_SUMA_PRIMA_COMISIONABLE_GA = 
    	SELECT SUM(PRIMA_COMISIONABLE)  AS SUM_PRIMA_COMISIONABLE, GA.CODIGO_POLIZA, GA.CODIGO_RECIBO
    	FROM EXT.GARANTIAS_ASEGURADO GA INNER JOIN :TBL_RECIBOS_71_66_65 TBL
    	  ON GA.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	    AND GA.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	 
	    GROUP BY  GA.CODIGO_POLIZA, GA.CODIGO_RECIBO
    	;
    v_num_rows = RECORD_COUNT(:TBL_SUMA_PRIMA_COMISIONABLE_GA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_SUMA_PRIMA_COMISIONABLE_GA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');
    
    
    MERGE INTO EXT.GARANTIAS_RECIBO GR
    USING ( 
    	SELECT TBL.* , GR.PRIMA_NETA_RECIBO , TBL2.SUM_PRIMA_COMISIONABLE , GR.INCREMENTO_PRIMA_ANUAL FROM :TBL_ASEGURADOS TBL INNER JOIN EXT.GARANTIAS_RECIBO GR 
    	--	SELECT TBL.* , GR.PRIMA_NETA_RECIBO , TBL2.SUM_PRIMA_COMISIONABLE , GR.INCREMENTO_PRIMA_ANUAL FROM :TBL_ASEGURADOS_ALTA_RESTO_6 TBL INNER JOIN EXT.GARANTIAS_RECIBO GR 
    	 ON GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	    AND GR.CODIGO_RECIBO = TBL.REC_CODIGO_RECIBO
	    AND GR.PRODUCTO_CONTABLE = TBL.PRODUCTO_CONTABLE
	    AND GR.ESTADO_RECIBO = TBL.REC_ESTADO_RECIBO
	    AND GR.CODIGO_SUPLEMENTO = TBL.REC_CODIGO_SUPLEMENTO 
	    INNER JOIN :TBL_SUMA_PRIMA_COMISIONABLE_GA TBL2 
	    	ON TBL2.CODIGO_POLIZA = GR.CODIGO_POLIZA
	    	AND TBL2.CODIGO_RECIBO = GR.CODIGO_RECIBO
    ) src
    ON GR.CODIGO_POLIZA = src.CODIGO_POLIZA
    AND GR.CODIGO_RECIBO = src.REC_CODIGO_RECIBO
    AND GR.PRODUCTO_CONTABLE = src.PRODUCTO_CONTABLE
    AND GR.ESTADO_RECIBO = src.REC_ESTADO_RECIBO
    AND GR.CODIGO_SUPLEMENTO = src.REC_CODIGO_SUPLEMENTO
        
    WHEN MATCHED THEN UPDATE SET
        GR.PRIMA_COMISIONABLE = CASE WHEN src.OFICINA_GESTORA = v_const_corte_ingles THEN src.PRIMA_NETA_RECIBO 
                                    WHEN src.REC_PERMANENCIA IN (v_const_recibos_especificos_10,v_const_recibos_especificos_20,v_const_recibos_cartera_81,v_const_recibos_cartera_72) THEN src.PRIMA_NETA_RECIBO 
                                    ELSE src.SUM_PRIMA_COMISIONABLE * (1- IFNULL(src.REC_PORCENTAJE_DESCUENTO_SOBRE_PC,0))
                                END 
        ,GR.INCREMENTO_PRIMA_ANUAL = CASE WHEN src.OFICINA_GESTORA = v_const_corte_ingles THEN src.INCREMENTO_PRIMA_ANUAL
            WHEN REC_PERMANENCIA IN (v_const_recibos_especificos_10,v_const_recibos_especificos_20,v_const_recibos_cartera_81,v_const_recibos_cartera_72) THEN src.PRIMA_NETA_RECIBO
            ELSE  src.SUM_PRIMA_COMISIONABLE
            END
        ,GR.FECHA_MODIFICACION = CURRENT_TIMESTAMP;
*/
---------------------------------FT_DISMINUCION_DE_PRIMA
/* ITL 1906 original con subconsulta
 TBL_DISMINUCION_DE_PRIMA = 
        SELECT TBL.*
            ,(SELECT SUM(GR.INCREMENTO_PRIMA_ANUAL)
              --INTO v_prima_neta_recibo
                    FROM EXT.GARANTIAS_RECIBO GR
                    WHERE GR.CODIGO_POLIZA =TBL.CODIGO_POLIZA
                    AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
                    AND GR.ESTADO_RECIBO = TBL.ESTADO_RECIBO
                    AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
                    AND GR.FECHA_BAJA_GAR_POL IS NULL)
            AS PRIMA_NETA_RECIBO
        
        FROM :TBL_RECIBOS TBL;*/
    TBL_PRIMA_NETA_RECIBO =
        SELECT 
            GR.CODIGO_POLIZA,
            GR.CODIGO_RECIBO,
            GR.ESTADO_RECIBO,
            GR.CODIGO_SUPLEMENTO,
            SUM(GR.INCREMENTO_PRIMA_ANUAL) AS PRIMA_NETA_RECIBO
        FROM EXT.GARANTIAS_RECIBO GR INNER JOIN :TBL_RECIBOS TBL
        	ON GR.CODIGO_POLIZA = TBL.CODIGO_POLIZA
	        AND GR.CODIGO_RECIBO = TBL.CODIGO_RECIBO
	        AND GR.ESTADO_RECIBO = TBL.ESTADO_RECIBO
	        AND GR.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO
        WHERE FECHA_BAJA_GAR_POL IS NULL
        GROUP BY 
            GR.CODIGO_POLIZA,
            GR.CODIGO_RECIBO,
            GR.ESTADO_RECIBO,
            GR.CODIGO_SUPLEMENTO;

    v_num_rows = RECORD_COUNT(:TBL_PRIMA_NETA_RECIBO);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_PRIMA_NETA_RECIBO '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');             

    TBL_DISMINUCION_DE_PRIMA = 
       SELECT 
           TBL.*,
           TMP.PRIMA_NETA_RECIBO
       FROM :TBL_RECIBOS TBL
       LEFT JOIN :TBL_PRIMA_NETA_RECIBO TMP
           ON TMP.CODIGO_POLIZA = TBL.CODIGO_POLIZA
           AND TMP.CODIGO_RECIBO = TBL.CODIGO_RECIBO
           AND TMP.ESTADO_RECIBO = TBL.ESTADO_RECIBO
           AND TMP.CODIGO_SUPLEMENTO = TBL.CODIGO_SUPLEMENTO;
        
    v_num_rows = RECORD_COUNT(:TBL_DISMINUCION_DE_PRIMA);
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Creada la tabla temporal TBL_DISMINUCION_DE_PRIMA '|| v_num_rows || ' filas', i_log_count, i_id_proceso, 'debug');      
    
    BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        
        ROLLBACK;
        
        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en MERGE  en EXT.RECIBOS para TBL_DISMINUCION_DE_PRIMA - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
                            || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, i_log_count, i_id_proceso, 'error');
                
        --Se actualizan los registros de POLIZAS con estado erróneo
        UPDATE EXT.RECIBOS REC
            SET ESTADO = v_const_calculo_status_error,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.RECIBOS REC, :TBL_RECIBOS src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND src.ESTADO = v_const_populate_status_ok;
        
        COMMIT;     
        RESIGNAL;
        END;
            MERGE INTO EXT.RECIBOS REC
            USING(
                SELECT * FROM :TBL_DISMINUCION_DE_PRIMA
            )src
            ON REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO =  src.CODIGO_RECIBO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            WHEN MATCHED THEN UPDATE SET
                REC.DISMINUCION_PRIMA = CASE WHEN src.PRIMA_NETA_RECIBO < 0 THEN v_const_s_1 ELSE v_const_n_0 END,
                REC.FECHA_MODIFICACION = CURRENT_TIMESTAMP; 
                
            v_num_rows := ::rowcount;
            CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin MERGE en EXT.RECIBOS para TBL_DISMINUCION_DE_PRIMA. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'info');
    
        END;
    END;
    
    --ACTUALIZAMOS TODOS LOS RECIBOS A OK
        UPDATE EXT.RECIBOS REC
            SET ESTADO = v_const_calculo_status_ok,
                FECHA_MODIFICACION = CURRENT_TIMESTAMP
            FROM EXT.RECIBOS REC, :TBL_RECIBOS src
        WHERE REC.CODIGO_POLIZA = src.CODIGO_POLIZA
            AND REC.CODIGO_RECIBO = src.CODIGO_RECIBO
            AND REC.CODIGO_SUPLEMENTO = src.CODIGO_SUPLEMENTO
            AND REC.ESTADO_RECIBO = src.ESTADO_RECIBO
            AND src.ESTADO = v_const_populate_status_ok;
    
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE RECIBOS con estado CALCULO_OK', i_log_count, i_id_proceso, 'info');
    
        UPDATE EXT.IN_BATCH_CONTROL
            SET STATUS = v_const_calculo_status_ok
                , END_DATE = CURRENT_TIMESTAMP
        WHERE 1 = 1
            AND STATUS = v_const_populate_status_ok
            AND FILE_NAME = i_file_name
            ;

        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE IN_BATCH_CONTROL con estado CALCULO_OK', i_log_count, i_id_proceso, 'info');
    
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin CALCULO RRTT', i_log_count, i_id_proceso, 'info');
END
