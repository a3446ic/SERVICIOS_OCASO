CREATE PROCEDURE EXT.SP_POPULATE_ASEGURADOS (
    IN i_file_name VARCHAR(120), 
    IN i_id_proceso BIGINT, 
    INOUT i_log_count INT
)
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Isaac Torrado Loureiro
    | Company: Inycom
    | Initial Version Date: 05-Febrero-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Procedimiento que se ejecuta una vez que entra un fichero de ASEGURADOS e inserta las modificaciones oportunas en  ASEGURADOS y GARANTIAS DE ASEGURADOS
    |   
    |           
    |   ID_PROCESO
    | Version: 0.1  ITL 20250205        Initial Version.
    | Version: 1.0  JGE 20250922        Rehacer consultas que extraen datos de stage y modificar las que insertar o actualizan en tablas, completar el procedimiento con logs
    | Version: 1.1	RMF	20250924		Forzamos un NULL al insertar el CONTO_COMO_ALTA
    |
    -----------------------------------------------------------------------
*/

BEGIN
    USING SQLSCRIPT_STRING AS LIBRARY;
    DECLARE proc_name VARCHAR(50) := ::CURRENT_OBJECT_SCHEMA || '.' || ::CURRENT_OBJECT_NAME;
    DECLARE v_version VARCHAR(10) := '0.1';
    DECLARE v_num_rows INTEGER := 0;
    DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
    DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();

    DECLARE v_const_n_0 INT := EXT.LIB_CONSTANTES:CONST_N_0; -- 0
    DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK; -- 1
    DECLARE v_const_stage_status_error INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_ERROR; -- 3
    DECLARE v_const_populate_status_ok INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_OK; -- 2
    DECLARE v_const_populate_status_error INT := EXT.LIB_CONSTANTES:CONST_POPULATE_STATUS_ERROR; -- 4

    DECLARE result_merge_aseg INT := v_const_populate_status_ok; -- Variable para almacenar el resultado del MERGE

    -- Manejador de excepciones para errores generales
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
    
    	ROLLBACK;
    	
        CALL EXT.LIB_GLOBAL:WRITE_LOG(
            v_permisos_log, 
            proc_name, 
            'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE, '') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, 
            i_log_count, 
            i_id_proceso, 
            'error'
        );

        -- Actualizar el estado de los registros en STAGE_ASEGURADOS
        UPDATE EXT.STAGE_ASEGURADOS
        SET ESTADO = v_const_populate_status_error,
            FECHA_MODIFICACION = CURRENT_TIMESTAMP
        WHERE FILE_NAME = i_file_name
            AND ESTADO = v_const_stage_status_ok;

        --Se actualizan los campos de la in_batch_control para indicar el error
        UPDATE EXT.IN_BATCH_CONTROL
        SET REJECTED_ROWS = v_num_rows,
            STATUS = v_const_populate_status_error,
            END_DATE = CURRENT_TIMESTAMP
        WHERE FILE_NAME = i_file_name
            AND ID_PROCESO = i_id_proceso;

        COMMIT;
        RESIGNAL; -- Relanza la excepción para que se propague
    END;

    -- Inicio del procedimiento
    BEGIN
        CALL EXT.LIB_GLOBAL:WRITE_LOG(
            v_permisos_log, 
            proc_name, 
            'Version: ' || v_version || ' - Procedure starting for ' || i_file_name, 
            i_log_count, 
            i_id_proceso, 
            'info'
        );

        -- Crear tablas temporales de GARANTIAS
        -- TBL_GAR_ASEGURADOS_A_TRATAR = SELECT * FROM EXT.STAGE_ASEGURADOS WHERE FILE_NAME = :i_file_name AND estado = :v_const_stage_status_ok;
		
		
		-- ahora la tabla temporal de ASEGURADOS
		TBL_STAGE_ASEGURADOS = 
			SELECT 
				*,
                EXT.LIB_GLOBAL:HEX_TO_DECIMAL(SUBSTR(CODIGO_RECIBO, 3))  AS CODIGO_RECIBO_HEX
	         FROM EXT.STAGE_ASEGURADOS
	         WHERE FILE_NAME = :i_file_name
	         AND ESTADO = :v_const_stage_status_ok
	   --      ORDER BY NUMERO_ASEGURADO, 
		  --  	--JGE 20250821 usar codigo_recibo en vez de codigo_poliza
		  --      CASE WHEN /*CODIGO_POLIZA*/ CODIGO_RECIBO LIKE 'C_ANUL_%' THEN 999999999999 
		  --      	ELSE EXT.LIB_GLOBAL:HEX_TO_DECIMAL(SUBSTR(CODIGO_RECIBO, 3)) END DESC,
				-- PRODUCTO_CONTABLE
        ;
            
        v_num_rows := RECORD_COUNT(:TBL_STAGE_ASEGURADOS);
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_STAGE_ASEGURADOS. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');
        
        
	    --se pone un rownum para poder filtrar cuando lo necesitemos
	    TBL_ASEGURADOS_A_TRATAR = (
    		SELECT 
    			IDENTIFICADOR,
                TRIM(FILE_NAME) AS FILE_NAME,
                TRIM(ESTADO) AS ESTADO,
                FECHA_MODIFICACION,
                TRIM(CODIGO_POLIZA) AS CODIGO_POLIZA,
                TRIM(NUMERO_ASEGURADO) AS NUMERO_ASEGURADO,
                TRIM(NIF) AS NIF,
                FECHA_NACIMIENTO,
                FECHA_DERECHOS AS FECHA_DE_DERECHOS,
                TRIM(MOTIVO_ALTA) AS MOTIVO_ALTA,
                -- 20250924 Cambiamos a NULL
                --'' AS CONTO_COMO_ALTA,
                --'' AS CONTO_COMO_NUEVO,
                NULL AS CONTO_COMO_ALTA,
                NULL AS CONTO_COMO_NUEVO,
                FECHA_ALTA,
                TRIM(MOTIVO_BAJA) AS MOTIVO_BAJA,
                FECHA_BAJA,
                FECHA_REHABILITACION,
                TRIM(POLIZA_ORIGEN) AS POLIZA_ORIGEN,
                TRIM(ASEGURADO_ORIGEN) AS ASEGURADO_ORIGEN,
                0 AS EDAD,
                0 AS EDAD_DERECHOS,
    			 ROW_NUMBER() OVER (PARTITION BY CODIGO_POLIZA, 
                                    NUMERO_ASEGURADO ORDER BY NUMERO_ASEGURADO, 
		                        	--JGE 20250821 usar codigo_recibo en vez de codigo_poliza
				                    CASE WHEN CODIGO_RECIBO LIKE 'C_ANUL_%' 
				                    	THEN 999999999999 
				                    	ELSE 
				                    		CODIGO_RECIBO_HEX
				                    END DESC,
		                    		PRODUCTO_CONTABLE) AS RN
            FROM :TBL_STAGE_ASEGURADOS
            -- WHERE RN = 1
	    );
		
		v_num_rows := RECORD_COUNT(:TBL_ASEGURADOS_A_TRATAR);
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'TBL_ASEGURADOS_A_TRATAR. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');
   
   
        --  Insertar en historial de GARANTIAS
		-- Versión corregida del INSERT en GARANTIAS_ASEGURADO_HIST
		INSERT INTO EXT.GARANTIAS_ASEGURADO_HIST (
		    ID_PROCESO,
		    IDENTIFICADOR,
		    ID_ASEGURADO,
		    ID_REAJUSTE,
		    FILE_NAME,
		    ESTADO,
		    FECHA_MODIFICACION,
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
		)
		SELECT 
		    :i_id_proceso,
		    GA.IDENTIFICADOR,
		    GA.ID_ASEGURADO,
		    GA.ID_REAJUSTE,
		    GA.FILE_NAME,
		    GA.ESTADO,
		    GA.FECHA_MODIFICACION,
		    GA.CODIGO_POLIZA,
		    GA.NUMERO_ASEGURADO,
		    GA.PRODUCTO_CONTABLE,
		    GA.CODIGO_RECIBO,
		    GA.PRIMA_UNICA,
		    GA.GARANTIA_IP,
		    GA.PRIMA_NETA_ASEGURADO,
		    GA.PORCENTAJE_PARTICIPACION,
		    GA.PORCENTAJE_NIVELADA,
		    GA.CAPITAL_NATURAL,
		    GA.CAPITAL_NIVELADO,
		    GA.SUBTIPO_MOVIMIENTO,
		    GA.MARCA_CUENTA,
		    GA.PRIMA_COMISIONABLE,
		    GA.UNIDAD_DE_POLIZA,
		    GA.MESES_COBRADOS,
		    GA.FECHA_ALTA_GAR_ASE,
		    GA.FECHA_BAJA_GAR_ASE,
		    GA.NUM_ORDEN_MOVIMIENTO,
		    GA.PC_PERIODO,
		    GA.NUM_PERIODOS
		FROM EXT.GARANTIAS_ASEGURADO GA
	    INNER JOIN (
		        SELECT *, 
		               ROW_NUMBER() OVER (PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, PRODUCTO_CONTABLE, 
		                                  NUMERO_ASEGURADO ORDER BY FECHA_MODIFICACION DESC) AS RN
		        FROM :TBL_STAGE_ASEGURADOS
		    ) TBL_GA   
        ON GA.CODIGO_POLIZA = TBL_GA.CODIGO_POLIZA
        AND GA.NUMERO_ASEGURADO = TBL_GA.NUMERO_ASEGURADO
        AND GA.PRODUCTO_CONTABLE = TBL_GA.PRODUCTO_CONTABLE
        AND GA.CODIGO_RECIBO = TBL_GA.CODIGO_RECIBO
	    WHERE TBL_GA.RN = 1
	    ;
		
		v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'HISTORIFICAR GARANTIAS_ASEGURADO_HIST. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');
		

		 --Insertar en historial de ASEGURADOS

        INSERT INTO EXT.ASEGURADOS_HIST
            SELECT :i_id_proceso, A.* 
            FROM EXT.ASEGURADOS A
            INNER JOIN :TBL_ASEGURADOS_A_TRATAR TBL_A
                ON A.CODIGO_POLIZA = TBL_A.CODIGO_POLIZA
                AND A.NUMERO_ASEGURADO = TBL_A.NUMERO_ASEGURADO
            WHERE TBL_A.RN = 1
                ;

        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'HISTORIFICAR ASEGURADOS_HIST. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');

        -- MERGE en ASEGURADOS
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                result_merge_aseg := v_const_populate_status_error;
                CALL EXT.LIB_CONSTANTES:WRITE_LOG(
                    v_permisos_log, 
                    proc_name, 
                    'FALLO MERGE en ASEGURADOS ' || v_num_rows, 
                    i_log_count, 
                    i_id_proceso, 
                    'error'
                );
                RESIGNAL;
            END;

            CALL EXT.LIB_CONSTANTES:WRITE_LOG(
                    v_permisos_log, 
                    proc_name, 
                    'INICIO MERGE en ASEGURADOS ' , 
                    i_log_count, 
                    i_id_proceso, 
                    'info'
                );

            MERGE INTO EXT.ASEGURADOS A
            USING (
                SELECT  * 
                FROM :TBL_ASEGURADOS_A_TRATAR
                WHERE RN = 1
            ) X
            ON 
                TRIM(A.CODIGO_POLIZA) = TRIM(X.CODIGO_POLIZA)
                AND TRIM(A.NUMERO_ASEGURADO) = TRIM(X.NUMERO_ASEGURADO)
            
            WHEN MATCHED THEN
                UPDATE SET
                    A.IDENTIFICADOR = X.IDENTIFICADOR,
                    A.FILE_NAME = X.FILE_NAME,
                    A.ESTADO = X.ESTADO,
                    A.FECHA_MODIFICACION = CURRENT_TIMESTAMP,
                    A.CODIGO_POLIZA = X.CODIGO_POLIZA,
                    A.NUMERO_ASEGURADO = X.NUMERO_ASEGURADO,
                    A.NIF = X.NIF,
                    A.FECHA_NACIMIENTO = X.FECHA_NACIMIENTO,
                    A.FECHA_DE_DERECHOS = X.FECHA_DE_DERECHOS,
                    A.MOTIVO_ALTA = X.MOTIVO_ALTA,
                    --20250924 RMF: Eliminamos el COALESCE y actualizamos con lo que venga
                    --A.CONTO_COMO_ALTA = COALESCE(TRIM(X.CONTO_COMO_ALTA), ''),
                    --A.CONTO_COMO_NUEVO = COALESCE(TRIM(X.CONTO_COMO_NUEVO), ''),
                    A.CONTO_COMO_ALTA = X.CONTO_COMO_ALTA,
                    A.CONTO_COMO_NUEVO = X.CONTO_COMO_NUEVO,
                    A.FECHA_ALTA = X.FECHA_ALTA,
                    A.MOTIVO_BAJA = X.MOTIVO_BAJA,
                    A.FECHA_BAJA = X.FECHA_BAJA,
                    A.FECHA_REHABILITACION = X.FECHA_REHABILITACION,
                    A.POLIZA_ORIGEN = X.POLIZA_ORIGEN,
                    A.ASEGURADO_ORIGEN = X.ASEGURADO_ORIGEN,
                    A.EDAD = X.EDAD,
                    A.EDAD_DERECHOS = X.EDAD_DERECHOS
            WHEN NOT MATCHED THEN INSERT
                VALUES(
                    X.IDENTIFICADOR,
                    X.FILE_NAME,
                    :v_const_populate_status_ok,
                    CURRENT_TIMESTAMP,
                    X.CODIGO_POLIZA,
                    X.NUMERO_ASEGURADO,
                    X.NIF,
                    X.FECHA_NACIMIENTO,
                    X.FECHA_DE_DERECHOS,
                    X.MOTIVO_ALTA,
                    --20250924 RMF: Eliminamos los COALESCES
                    --COALESCE(TRIM(X.CONTO_COMO_ALTA), ''),
                    --COALESCE(TRIM(X.CONTO_COMO_NUEVO), ''),
                    X.CONTO_COMO_ALTA,
                    X.CONTO_COMO_NUEVO,
                    X.FECHA_ALTA,
                    X.MOTIVO_BAJA,
                    X.FECHA_BAJA,
                    X.FECHA_REHABILITACION,
                    X.POLIZA_ORIGEN,
                    X.ASEGURADO_ORIGEN,
                    X.EDAD,
                    X.EDAD_DERECHOS
                )
            ;
            
            
            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'FIN MERGE EN ASEGURADOS. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');
        END;

        

        -- MERGE en GARANTIAS_ASEGURADO (similar al MERGE en ASEGURADOS)
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                CALL EXT.LIB_CONSTANTES:WRITE_LOG(
                    v_permisos_log, 
                    proc_name, 
                    'FALLO MERGE en GARANTIAS_ASEGURADO', 
                    i_log_count, 
                    i_id_proceso, 
                    'error'
                );
                RESIGNAL;
            END;

-- ITL modificado orden columnas 
		MERGE INTO EXT.GARANTIAS_ASEGURADO GA
		USING (
		    SELECT  
		        -- :v_const_n_0 AS ID_REAJUSTE,
		        T.FILE_NAME AS FILE_NAME,
		        T.ESTADO AS ESTADO,
		        CURRENT_TIMESTAMP AS FECHA_MODIFICACION,
		        T.CODIGO_POLIZA AS CODIGO_POLIZA,
		        T.NUMERO_ASEGURADO AS NUMERO_ASEGURADO,
		        T.PRODUCTO_CONTABLE AS PRODUCTO_CONTABLE,
		        T.CODIGO_RECIBO AS CODIGO_RECIBO,
		        T.PRIMA_UNICA,
		        T.GARANTIA_IP,
		        T.PRIMA_NETA_ASEGURADO,
		        :v_const_n_0 AS PORCENTAJE_PARTICIPACION,
		        :v_const_n_0 AS PORCENTAJE_NIVELADA,
		        T.CAPITAL_NATURAL,
		        T.CAPITAL_NIVELADO,
		        T.SUB_TIPO_MOVIMIENTO AS SUBTIPO_MOVIMIENTO, 
		        '' AS MARCA_CUENTA,
		       	:v_const_n_0 AS PRIMA_COMISIONABLE,
		        :v_const_n_0 AS UNIDAD_DE_POLIZA,
		        :v_const_n_0 AS MESES_COBRADOS,
		        T.FECHA_ALTA_GAR_ASE,
		        T.FECHA_BAJA_GAR_ASE,
		        IFNULL(
		           (SELECT MIN(GR.NUM_ORDEN_MOVIMIENTO)
		           FROM EXT.GARANTIAS_RECIBO GR
		           WHERE GR.CODIGO_RECIBO = T.CODIGO_RECIBO
		             AND GR.CODIGO_POLIZA = T.CODIGO_POLIZA
		             AND GR.PRODUCTO_CONTABLE = T.PRODUCTO_CONTABLE)
		        ,0) AS NUM_ORDEN_MOVIMIENTO,
		        :v_const_n_0 AS PC_PERIODO,
		        :v_const_n_0 AS NUM_PERIODOS
		    FROM (
		        SELECT *, 
		               ROW_NUMBER() OVER (PARTITION BY CODIGO_POLIZA, CODIGO_RECIBO, PRODUCTO_CONTABLE, 
		                                  NUMERO_ASEGURADO ORDER BY FECHA_MODIFICACION DESC) AS RN
		        FROM :TBL_STAGE_ASEGURADOS
		    ) T   
		    WHERE T.RN = 1
		) X
		ON (
		    TRIM(GA.CODIGO_RECIBO) = TRIM(X.CODIGO_RECIBO)
		    AND TRIM(GA.CODIGO_POLIZA) = TRIM(X.CODIGO_POLIZA)
		    AND TRIM(GA.PRODUCTO_CONTABLE) = TRIM(X.PRODUCTO_CONTABLE)
		    AND TRIM(GA.NUMERO_ASEGURADO) = TRIM(X.NUMERO_ASEGURADO)
		)
		WHEN MATCHED THEN
		    UPDATE SET
		        -- GA.ID_ASEGURADO = X.ID_ASEGURADO,
		        -- GA.ID_REAJUSTE = X.ID_REAJUSTE,
		        GA.FILE_NAME = TRIM(X.FILE_NAME),
		        GA.ESTADO = v_const_populate_status_ok,
		        GA.FECHA_MODIFICACION = CURRENT_TIMESTAMP,
		        GA.PRIMA_COMISIONABLE = IFNULL(ROUND(X.PRIMA_COMISIONABLE,2), v_const_n_0),
		        GA.UNIDAD_DE_POLIZA = IFNULL(ROUND(X.UNIDAD_DE_POLIZA,4), v_const_n_0),
		        GA.MESES_COBRADOS = IFNULL(ROUND(X.MESES_COBRADOS,2), v_const_n_0),
		        GA.FECHA_ALTA_GAR_ASE = X.FECHA_ALTA_GAR_ASE,
		        GA.FECHA_BAJA_GAR_ASE = X.FECHA_BAJA_GAR_ASE,
		        GA.NUM_ORDEN_MOVIMIENTO = X.NUM_ORDEN_MOVIMIENTO,
		        GA.PC_PERIODO = IFNULL(ROUND(X.PC_PERIODO,2), v_const_n_0),
		        GA.NUM_PERIODOS = IFNULL(ROUND(X.NUM_PERIODOS,2), v_const_n_0),
		        GA.PRIMA_UNICA = X.PRIMA_UNICA,
		        GA.GARANTIA_IP = X.GARANTIA_IP,
		        GA.PRIMA_NETA_ASEGURADO = ROUND(X.PRIMA_NETA_ASEGURADO,2),
		        GA.PORCENTAJE_PARTICIPACION = IFNULL(ROUND(X.PORCENTAJE_PARTICIPACION,2), v_const_n_0),
		        GA.PORCENTAJE_NIVELADA = IFNULL(ROUND(X.PORCENTAJE_NIVELADA,2), v_const_n_0),
		        GA.CAPITAL_NATURAL = ROUND(X.CAPITAL_NATURAL,2),
		        GA.CAPITAL_NIVELADO = ROUND(X.CAPITAL_NIVELADO,2),
		        GA.SUBTIPO_MOVIMIENTO = X.SUBTIPO_MOVIMIENTO,
		        GA.MARCA_CUENTA = ''
		WHEN NOT MATCHED THEN 
		    INSERT (
		        -- ID_ASEGURADO,
		        -- ID_REAJUSTE,
		        FILE_NAME,
		        ESTADO,
		        FECHA_MODIFICACION,
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
		    )
		    VALUES(
		        -- X.ID_ASEGURADO,
		        -- X.ID_REAJUSTE,
		        X.FILE_NAME,
		        v_const_populate_status_ok,
		        CURRENT_TIMESTAMP,
		        X.CODIGO_POLIZA,
		        X.NUMERO_ASEGURADO,
		        X.PRODUCTO_CONTABLE,
		        X.CODIGO_RECIBO,
		        X.PRIMA_UNICA,
		        X.GARANTIA_IP,
		        ROUND(X.PRIMA_NETA_ASEGURADO,2),
		        IFNULL(ROUND(X.PORCENTAJE_PARTICIPACION,2), v_const_n_0),
		        IFNULL(ROUND(X.PORCENTAJE_NIVELADA,2), v_const_n_0),
		        ROUND(X.CAPITAL_NATURAL,2),
		        ROUND(X.CAPITAL_NIVELADO,2),
		        X.SUBTIPO_MOVIMIENTO,
		        '', --MARCA CUENTA
		        IFNULL(ROUND(X.PRIMA_COMISIONABLE,2), v_const_n_0),
				IFNULL(ROUND(X.UNIDAD_DE_POLIZA,4), v_const_n_0),
				IFNULL(ROUND(X.MESES_COBRADOS,2), v_const_n_0),
				X.FECHA_ALTA_GAR_ASE,
				X.FECHA_BAJA_GAR_ASE,
				X.NUM_ORDEN_MOVIMIENTO,
				IFNULL(ROUND(X.PC_PERIODO,2), v_const_n_0),
				IFNULL(ROUND(X.NUM_PERIODOS,2), v_const_n_0)
		    );

            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'FIN MERGE EN GARANTIAS_ASEGURADOS. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');
        END;

		-- Actualizar el estado en STAGE_ASEGURADOS
        UPDATE EXT.STAGE_ASEGURADOS
            SET ESTADO = :v_const_stage_status_ok
            WHERE FILE_NAME = :i_file_name;
        
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Registros STAGE_ASEGURADOS actualizado estado OK. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');
                
        -- Finalizar el procedimiento
        CALL EXT.LIB_GLOBAL:WRITE_LOG(
            v_permisos_log, 
            proc_name, 
            'Procedimiento SP_POPULATE_ASEGURADOS finalizado correctamente', 
            i_log_count, 
            i_id_proceso, 
            'info'
        );

        -- Actualizar IN_BATCH_CONTROL con el estado de éxito

        UPDATE EXT.IN_BATCH_CONTROL
        SET STATUS = :v_const_populate_status_ok
            , END_DATE = CURRENT_TIMESTAMP
        WHERE STATUS = :v_const_stage_status_ok
            AND FILE_NAME = :i_file_name
        ;
        
        v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Registros IN_BATCH_CONTROL actualizado estado OK. Filas: ' || v_num_rows || ' filas' , i_log_count, i_id_proceso, 'info');
        
        CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,proc_name,'Fin UPDATE IN_BATCH_CONTROL con estado POPULATE_OK', i_log_count, i_id_proceso, 'info');
    END;
END
