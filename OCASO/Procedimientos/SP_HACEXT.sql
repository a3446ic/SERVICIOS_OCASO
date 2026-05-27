CREATE OR REPLACE PROCEDURE EXT.SP_HACEXT(
	OUT FILENAME VARCHAR(120),
    IN i_pPlRunSeq VARCHAR(50))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS 
/*---------------------------------------------------------------------
    | Author: Victor Garcia Bascunyana
    | Company: Inycom
    | Initial Version Date: 27-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Generacion datos para los fichero del interface de Hacienda 
	|
	| Version: 0.1	VGB 20250327		Initial Version.
	| Version: 0.2  TGV 20260126		Creamos la variable de fechaserver para que obtenga la Fecha del cierre del periodo actual
    -----------------------------------------------------------------------
*/
	BEGIN
	DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.2';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso INTEGER;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE = EXT.LIB_CONSTANTES:v_eot; 
	DECLARE v_PeriodSeq BIGINT;
	DECLARE v_PeriodName VARCHAR2(255);
	DECLARE v_PeriodStartDate TIMESTAMP;
	DECLARE v_fechaserver TIMESTAMP;
	DECLARE v_fechapago VARCHAR(6);
	DECLARE v_const_calculo_status_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
	DECLARE v_fechalocal TIMESTAMP;
	
    DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_LOAD;
    DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_OK;
    DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_ERROR;	

    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN 
        CALL EXT.LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE, '') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE,v_log_count,v_idproceso,'error');
        
        
        UPDATE
            EXT.OUT_BATCH_CONTROL
        SET
            STATUS = v_const_out_batch_control_error,
            END_DATE = CURRENT_TIMESTAMP
        WHERE COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
            AND ID_PROCESO = v_idproceso;
            
            
        COMMIT;
        RESIGNAL;
    END;
   



	--Inicializamos el idProceso
	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	BEGIN
		--REGISTRO OUT_BATCH_CONTROL
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_idproceso,FILENAME,::CURRENT_OBJECT_NAME,0,EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD,CURRENT_TIMESTAMP,NULL);
		COMMIT;
	END;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq , v_log_count, v_idproceso, 'info');
--------------- Funcion que nos permite obtener el PERIODSEQ a partir de una fecha dada --------------
	SELECT PERIODSEQ, NAME, STARTDATE, TO_CHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate,v_fechapago FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
	
	--20260126 - TGV -- OBTENEMOS LA FECHA DEL ULTIMO CIERRE DEL PERIODO
	SELECT F_INICIO INTO v_fechaserver FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'PAGEXT_STATUS';
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fecha del cierre del periodo actual (fechaserver): ' || TO_CHAR(v_fechaserver,'YYYYMMDD_HH24MI'), v_log_count, v_idproceso, 'info');  
	
	--FICHERO DE SALIDA  
    --SELECT 'HACEXT_PRD'||TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_OHFTP166602.txt' INTO FILENAME from dummy;
    
    --20250812 BRG - A PETICION DE MIGUEL ANGEL ARENAS SE CAMBIAR EL NOMBRE DE SALIDA A HACEXT_AAAAMMDD_HHMMSS.txt
	--SELECT 'HACEXT1666_'||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME FROM dummy;
	-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA
	SELECT UTCTOLOCAL (current_utctimestamp, 'CET') INTO v_fechalocal FROM DUMMY;
    SELECT 'HACEXT1666_'||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME FROM dummy;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA: ' || FILENAME, v_log_count, v_idproceso, 'info');  	
	
	

--   --------------- Creacion de TEMP_TABLA_IRPF_HACEXT_FILE --------------
CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla TEMP_TABLA_IRPF_HACEXT_FILE.' , v_log_count, v_idproceso, 'info');
	TEMP_TABLA_IRPF_HACEXT_FILE = 
	SELECT 
	    C.CLASSIFIERID, 
	    SUBSTRING(C.NAME, 1, 1) AS NAME, --FIRST_LETTER, 
	    GC.GENERICNUMBER1
	FROM TCMP.CS_CLASSIFIER C
	JOIN TCMP.CS_GENERICCLASSIFIERTYPE GCT 
	    ON C.SELECTORID = GCT.GENERICCLASSIFIERTYPESEQ
	    AND GCT.NAME = 'Tipo IRPF'
	    AND GCT.TENANTID = v_idtenant
	JOIN TCMP.CS_GENERICCLASSIFIER GC 
	    ON GC.CLASSIFIERSEQ = C.CLASSIFIERSEQ
	    AND GC.REMOVEDATE = v_eot
	    AND GC.EFFECTIVESTARTDATE <= v_fechaserver
	    AND GC.EFFECTIVEENDDATE > v_fechaserver
	    AND GC.TENANTID = v_idtenant
	LEFT OUTER JOIN TCMP.CS_CATEGORY_CLASSIFIERS CC 
	    ON CC.CLASSIFIERSEQ = C.CLASSIFIERSEQ
	    AND CC.REMOVEDATE = v_eot
	    AND CC.EFFECTIVESTARTDATE <= v_fechaserver
	    AND CC.EFFECTIVEENDDATE > v_fechaserver
	    AND CC.TENANTID = v_idtenant
	LEFT OUTER JOIN TCMP.CS_CATEGORYTREE CT 
	    ON CT.CATEGORYTREESEQ = CC.CATEGORYTREESEQ
	    AND CT.REMOVEDATE = v_eot
	    AND CT.EFFECTIVESTARTDATE <= v_fechaserver
	    AND CT.EFFECTIVEENDDATE > v_fechaserver
	    AND CT.NAME = 'Tipo IRPF'
	    AND CT.TENANTID = v_idtenant
	LEFT OUTER JOIN TCMP.CS_CATEGORY CAT 
	    ON CAT.RULEELEMENTSEQ = CC.CATEGORYSEQ
	    AND CAT.REMOVEDATE = v_eot
	    AND CAT.EFFECTIVESTARTDATE <= v_fechaserver
	    AND CAT.EFFECTIVEENDDATE > v_fechaserver
	    AND CAT.TENANTID = v_idtenant
	WHERE 
	    C.REMOVEDATE = v_eot
	    AND C.EFFECTIVESTARTDATE <= v_fechaserver
	    AND C.EFFECTIVEENDDATE > v_fechaserver
	    AND C.TENANTID = v_idtenant;

   v_num_rows = RECORD_COUNT(:TEMP_TABLA_IRPF_HACEXT_FILE);
--   COMMIT;
 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla TEMP_TABLA_IRPF_HACEXT_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');       


CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla TEMP_CARTERA_DDEE_HACEXT_FILE.', v_log_count, v_idproceso, 'info'); 

    TEMP_CARTERA_DDEE_HACEXT_FILE =
        SELECT X.POSITIONNAME,X.COMPENSATIONDATE,X.EARNINGGROUPID,X.SEQ_POST,SUM(IFNULL(X.IMPORTE,0)) AS IMPORTE
        FROM EXT.CARTERA_DDEE X
        WHERE X.COMPENSATIONDATE = v_PeriodStartDate
        AND X.ESTADO = 'C'
        GROUP BY X.POSITIONNAME,X.COMPENSATIONDATE,X.EARNINGGROUPID,X.SEQ_POST
    ;
    
  v_num_rows = RECORD_COUNT(:TEMP_CARTERA_DDEE_HACEXT_FILE);
--   COMMIT;
 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla TEMP_CARTERA_DDEE_HACEXT_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info'); 
---------------------
--     --------------- Creacion de TEMP_HACEXT_FILE --------------
CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla TEMP_HACEXT_FILE.' , v_log_count, v_idproceso, 'info');
 TEMP_HACEXT_FILE =
    SELECT 
		LPAD(PAR.GENERICATTRIBUTE1,9,'0')                               AS NIF,
		SUBSTR(PAY.EARNINGGROUPID,7,2)                                  AS CIA,
		SUBSTR(POS.GENERICATTRIBUTE3,1,4)                                            AS OFICINA,
		CASE SUBSTR(PAY.EARNINGGROUPID,4,2) WHEN 'S5' THEN '10'  --Inspectores
													ELSE  CASE SUBSTR(PAY.EARNINGGROUPID,10,2) WHEN 'RT' THEN '08' --Agente producto de decesos
																										ELSE '01' --Agente resto productos
															END
		END                                                             as ORIGEN,
		CASE SUBSTR(PAY.EARNINGGROUPID,1,2)  WHEN '01' THEN CASE WHEN SUBSTR(PAY.EARNINGGROUPID,10,2) = 'RT' THEN '01' --Productos de decesos
																										ELSE '02' --Resto de productos
															END
											WHEN '02' THEN CASE WHEN SUBSTR(PAY.EARNINGGROUPID,10,2) = 'RT' THEN '01' --Productos de decesos
																										ELSE '02' --Resto de productos
															END
											WHEN '17' THEN CASE WHEN SUBSTR(PAY.EARNINGGROUPID,10,2) = 'RT' THEN '01' --Productos de decesos
																										ELSE '02' --Resto de productos
															END
											WHEN '03' THEN '03'
											WHEN '04' THEN '04' 
											WHEN '05' THEN '07' 
		END                                                             AS CAUSA,
		ROUND(PAY.VALUE,2)                                              AS DEVENGO,
		'+00000000,00'                                                  AS SSOCIAL,
		CASE WHEN (PAR.GENERICATTRIBUTE3 = 'F') THEN
			CASE  WHEN (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0) AND PAR.GENERICATTRIBUTE5=SUBSTR(PAY.EARNINGGROUPID,7,2) 
				
					THEN ROUND(IFNULL(PAR.GENERICNUMBER5,0)*ROUND(PAY.VALUE,2),2)
					ELSE ROUND(IRPF.GENERICNUMBER1*ROUND(PAY.VALUE,2),2)
			END
			--ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
			--WHEN (PAR.GENERICATTRIBUTE3 = 'J') AND SUBSTR(PAR.GENERICATTRIBUTE1,1,1) IN ('G','J','E','V') AND PAR.GENERICATTRIBUTE1 <> 'J72106826' 
			WHEN (PAR.GENERICATTRIBUTE3 = 'J') 
				--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
                --AND SUBSTR(PAR.GENERICATTRIBUTE1,1,1) IN ('G','J','E','V')
                AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('J','E','V')
				AND PAR.GENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
				THEN ROUND(IRPF.GENERICNUMBER1*ROUND(PAY.VALUE,2),2) -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
			ELSE 0
		END                                                                                                         AS IRPF,
		'AGENTE: '                                                      AS FILLER1,
		SUBSTR(PAY.EARNINGGROUPID,7,2)                                  AS CIA_ID,
		'-'                                                             AS FILLER2,
		SUBSTR(POS.GENERICATTRIBUTE3,1,4)                                            AS OFIC_ID,
		'-'                                                             AS FILLER3,
		SUBSTR(POS.GENERICATTRIBUTE3,6,5)                                            AS COMER_ID,
		'    '                                                          AS FILLER4,
		SUBSTR(v_fechapago,1,6)                                           AS CARGO, --Fecha en la que se calcula, variable entrada.
		'CO'                                                            AS APLICACION,
		'0000'                                                          AS EJERCICIO
			FROM TCMP.CS_POSITION POS                                                                        
			INNER JOIN TCMP.CS_PARTICIPANT PAR ON POS.PAYEESEQ=PAR.PAYEESEQ AND PAR.TENANTID= v_idtenant
				AND PAR.EFFECTIVESTARTDATE <= v_fechaserver
				AND PAR.EFFECTIVEENDDATE > v_fechaserver

				AND PAR.REMOVEDATE = v_eot            --Usare esto para pruebas                                
			INNER JOIN TCMP.CS_PAYMENT PAY ON PAR.PAYEESEQ = PAY.PAYEESEQ AND POS.RULEELEMENTOWNERSEQ = PAY.POSITIONSEQ AND PAY.TENANTID = v_idtenant
            INNER JOIN :TEMP_TABLA_IRPF_HACEXT_FILE IRPF ON (CASE WHEN PAR.TAXID IS NULL OR PAR.TAXID NOT IN ('I','E','S','C') THEN 'P' ELSE PAR.TAXID END) = IRPF.NAME
			WHERE
				PAY.POSTPIPELINERUNDATE IS NOT NULL
				AND LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3 ,1,4),'0'),4,'0') NOT IN ('0931','0936')
				AND NOT(SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S5' AND (PAR.GENERICNUMBER4 IS NOT NULL and PAR.GENERICNUMBER4 <> 0))
				AND (PAR.TERMINATIONDATE IS NULL OR PAR.TERMINATIONDATE > v_fechaserver)
				AND POS.EFFECTIVESTARTDATE <= v_fechaserver       --Version PRD
				AND POS.EFFECTIVEENDDATE > v_fechaserver          --Version PRD
				AND POS.REMOVEDATE = v_eot                        
				AND SUBSTR(POS.GENERICATTRIBUTE3,6,5) NOT IN ('99999')
				AND PAR.GENERICATTRIBUTE1 NOT IN ('50115742F','52096024N')
				--Solo cojo el mes que le paso
				AND PAY.PERIODSEQ = v_periodSeq
				AND POS.TENANTID = v_idtenant

	UNION ALL
    SELECT 
    LPAD(PAR.GENERICATTRIBUTE1,9,'0')                               AS NIF,
    SUBSTR(CAR_LP.EARNINGGROUPID,7,2)                                  AS CIA,
    SUBSTR(POS.GENERICATTRIBUTE3,1,4)                                            AS OFICINA,
    CASE SUBSTR(CAR_LP.EARNINGGROUPID,4,2) WHEN 'S5' THEN '10'  --Inspectores
                                                  ELSE  CASE SUBSTR(CAR_LP.EARNINGGROUPID,10,2) WHEN 'RT' THEN '08' --Agente producto de decesos
                                                                                                      ELSE '01' --Agente resto productos
                                                        END
    END                                                             as ORIGEN,
    CASE SUBSTR(CAR_LP.EARNINGGROUPID,1,2)  WHEN '01' THEN CASE WHEN SUBSTR(CAR_LP.EARNINGGROUPID,10,2) = 'RT' THEN '01' --Productos de decesos
                                                                                                      ELSE '02' --Resto de productos
                                                        END
                                         WHEN '02' THEN CASE WHEN SUBSTR(CAR_LP.EARNINGGROUPID,10,2) = 'RT' THEN '01' --Productos de decesos
                                                                                                      ELSE '02' --Resto de productos
                                                        END
                                         WHEN '17' THEN CASE WHEN SUBSTR(CAR_LP.EARNINGGROUPID,10,2) = 'RT' THEN '01' --Productos de decesos
                                                                                                      ELSE '02' --Resto de productos
                                                        END
                                         WHEN '03' THEN '03'
                                         WHEN '04' THEN '04' 
                                         WHEN '05' THEN '07' 
    END                                                             AS CAUSA,
    ROUND(CAR_LP.IMPORTE,2)                                              AS DEVENGO,
    '+00000000,00'                                                  AS SSOCIAL,
    CASE WHEN (PAR.GENERICATTRIBUTE3 = 'F') THEN
        CASE  WHEN (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0) AND PAR.GENERICATTRIBUTE5=SUBSTR(CAR_LP.EARNINGGROUPID,7,2) 
                THEN ROUND(IFNULL(PAR.GENERICNUMBER5,0)*ROUND(CAR_LP.IMPORTE,2),2)
                ELSE ROUND(IRPF.GENERICNUMBER1*ROUND(CAR_LP.IMPORTE,2),2)
        END
        --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
        -- WHEN (PAR.GENERICATTRIBUTE3 = 'J') AND SUBSTR(PAR.genericattribute1,1,1) in ('G','J','E','V') AND PAR.GENERICATTRIBUTE1 <> 'J72106826' 
        WHEN (PAR.GENERICATTRIBUTE3 = 'J') 
        	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
            --AND SUBSTR(PAR.GENERICATTRIBUTE1,1,1) IN ('G','J','E','V')
            AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('J','E','V') 
        	AND PAR.GENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
            THEN ROUND(IRPF.GENERICNUMBER1*ROUND(CAR_LP.IMPORTE,2),2) -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
        ELSE 0
    END                                                                                                         AS IRPF,
    'AGENTE: '                                                      AS FILLER1,
    SUBSTR(CAR_LP.EARNINGGROUPID,7,2)                                  AS CIA_ID,
    '-'                                                             AS FILLER2,
    SUBSTR(POS.GENERICATTRIBUTE3,1,4)                                            AS OFIC_ID,
    '-'                                                             AS FILLER3,
    SUBSTR(POS.GENERICATTRIBUTE3,6,5)                                            AS COMER_ID,
    '    '                                                          AS FILLER4,
    SUBSTR(v_fechapago,1,6)                                    AS CARGO, --Fecha en la que se calcula, variable entrada.
    'CO'                                                            AS APLICACION,
    '0000'                                                          AS EJERCICIO
        FROM TCMP.CS_POSITION POS                                                                        
        INNER JOIN TCMP.CS_PARTICIPANT PAR ON POS.PAYEESEQ = PAR.PAYEESEQ AND PAR.TENANTID = v_idtenant 
            AND PAR.EFFECTIVESTARTDATE <= v_fechaserver
            AND PAR.EFFECTIVEENDDATE > v_fechaserver
            AND PAR.REMOVEDATE = v_eot            --Usare esto para pruebas     

        INNER JOIN :TEMP_CARTERA_DDEE_HACEXT_FILE CAR_LP ON POS.NAME = CAR_LP.POSITIONNAME AND CAR_LP.COMPENSATIONDATE = v_PeriodStartDate 
        INNER JOIN :TEMP_TABLA_IRPF_HACEXT_FILE IRPF ON (CASE WHEN PAR.TAXID IS NULL OR PAR.TAXID NOT IN ('I','E','S','C') THEN 'P' ELSE PAR.TAXID END) = IRPF.NAME
        WHERE
            CAR_LP.SEQ_POST IS NOT NULL
            AND LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3 ,1,4),'0'),4,'0') NOT IN ('0931','0936')
            AND NOT(SUBSTR(CAR_LP.EARNINGGROUPID,4,2) = 'S5' AND (PAR.GENERICNUMBER4 IS NOT NULL and PAR.GENERICNUMBER4 <> 0))
            AND (PAR.TERMINATIONDATE IS NULL OR PAR.TERMINATIONDATE > v_fechaserver)
            AND POS.EFFECTIVESTARTDATE <= v_fechaserver       --Version PRD
            AND POS.EFFECTIVEENDDATE > v_fechaserver          --Version PRD
            AND POS.REMOVEDATE = v_eot                        
            AND SUBSTR(POS.GENERICATTRIBUTE3,6,5) NOT IN ('99999')
            AND PAR.GENERICATTRIBUTE1 NOT IN ('50115742F','52096024N')
            AND POS.TENANTID=v_idtenant;
                
--     -- EXCEPTION
--     --     WHEN OTHERS THEN
--     --         w_debug('ERROR: SQLCOD(' || SQLCODE || ') ' ||SQLERRM, v_contador);
--     -- END;
                
v_num_rows = RECORD_COUNT(:TEMP_HACEXT_FILE);
--     -- COMMIT;
CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla TEMP_HACEXT_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');             

    --------------- Truncado de FINAL_HACEXT_FILE -------------- 
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Truncado de la tabla de FINAL_HACEXT_FILE.', v_log_count, v_idproceso, 'info');
    TRUNCATE TABLE EXT.FINAL_HACEXT_FILE;  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Truncado de la tabla de FINAL_HACEXT_FILE.', v_log_count, v_idproceso, 'info');

--  --------------- Creacion de FINAL_HACEXT_FILE --------------
CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla FINAL_HACEXT_FILE.', v_log_count, v_idproceso, 'info'); 

	INSERT INTO EXT.FINAL_HACEXT_FILE
	SELECT 
	    RPAD(TEMP.NIF, 9) || TEMP.CIA || TEMP.OFICINA || TEMP.ORIGEN || TEMP.CAUSA ||
	    CASE WHEN SUM(TEMP.DEVENGO) >= 0 THEN '+' ELSE '-' END || 
	    TRIM(TO_VARCHAR(ABS(SUM(TEMP.DEVENGO)), '00000000.00')) ||
	    '+00000000,00' ||
	    CASE WHEN SUM(TEMP.IRPF) >= 0 THEN '+' ELSE '-' END ||
	    TRIM(TO_VARCHAR(ABS(SUM(TEMP.IRPF)), '00000000.00')) ||
	    TEMP.FILLER1 || TEMP.CIA_ID || TEMP.FILLER2 || TEMP.OFIC_ID || 
	    TEMP.FILLER3 || TEMP.COMER_ID || TEMP.FILLER4 || 
	    RPAD(TEMP.CARGO, 6) || TEMP.APLICACION || TEMP.EJERCICIO 
	    AS LINE  
	FROM :TEMP_HACEXT_FILE TEMP
	WHERE TEMP.CAUSA IS NOT NULL
	GROUP BY TEMP.NIF, TEMP.ORIGEN, TEMP.CAUSA, TEMP.OFICINA, TEMP.CIA, 
	         TEMP.FILLER1, TEMP.CIA_ID, TEMP.FILLER2, TEMP.OFIC_ID, 
	         TEMP.FILLER3, TEMP.COMER_ID, TEMP.FILLER4, TEMP.CARGO, 
	         TEMP.APLICACION, TEMP.EJERCICIO
	ORDER BY TEMP.NIF, TEMP.CIA, TEMP.OFICINA, TEMP.ORIGEN, TEMP.CAUSA;

  
v_num_rows = RECORD_COUNT(EXT.FINAL_HACEXT_FILE);
--     -- COMMIT;
CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla FINAL_HACEXT_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');  

	UPDATE EXT.OUT_BATCH_CONTROL
	    	SET STATUS = v_const_out_batch_control_ok,
	    	FILE_NAME = FILENAME,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    	WHERE 1=1--COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
	    	AND ID_PROCESO = v_idproceso;
	    	
	--FIN
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');

END