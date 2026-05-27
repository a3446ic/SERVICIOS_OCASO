CREATE OR REPLACE PROCEDURE EXT.SP_ALIEXT(
	OUT FILENAME VARCHAR(120),
    IN i_pPlRunSeq VARCHAR(50))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS 
/*---------------------------------------------------------------------
	| Author: Victor Garcia Bascunyana
	| Company: Inycom
	| Initial Version Date: 01-April-2025
	|----------------------------------------------------------------------
	| Procedure Purpose: Procedimiento que nos permite obtener en la tabla INYC_AUTOLIQUIDACION_INFORME
	| el contenido del fichero de autoliquidacion. 
	|
	| Version: 0.1	VGB 20250327		Initial Version.
	|		   0.2	BRG	20250813		Cambio de FILENAME
	| Version: 0.3  TGV 20260126		Creamos la variable de fechaserver para que obtenga la Fecha del cierre del periodo actual
	|
	-----------------------------------------------------------------------
*/
	BEGIN
	
	DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.3';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso INTEGER;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE = EXT.LIB_CONSTANTES:v_eot; 
	DECLARE v_PeriodSeq BIGINT;
	DECLARE v_PeriodName VARCHAR2(255);
	DECLARE v_fechaserver TIMESTAMP;
	DECLARE v_fechaliquidacion VARCHAR(8);
	DECLARE v_const_calculo_status_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
    DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_LOAD;
    DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_OK;
    DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_ERROR;
	DECLARE v_fechalocal TIMESTAMP;
	

    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK;
        CALL EXT.LIB_GLOBAL :WRITE_LOG (v_permisos_log,v_proc_name,'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE, '') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE,v_log_count,v_idproceso,'error');
        v_num_rows := 0;
        UPDATE
            EXT.OUT_BATCH_CONTROL
        SET
            STATUS = v_const_out_batch_control_error,
            END_DATE = CURRENT_TIMESTAMP
        WHERE
            COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
            AND ID_PROCESO = v_idproceso;
	    COMMIT;
        RESIGNAL;

    END;
   


--Inicializamos el idProceso
	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros entrada. i_pPlRunSeq: ' || i_pPlRunSeq , v_log_count, v_idproceso, 'info');
	
	BEGIN
		--REGISTRO OUT_BATCH_CONTROL
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_idproceso,FILENAME,::CURRENT_OBJECT_NAME,0,EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD,CURRENT_TIMESTAMP,NULL);
		COMMIT;
	END;
	
--------------- Funcion que nos permite obtener el PERIODSEQ a partir de una fecha dada --------------
	SELECT PERIODSEQ, NAME,  TO_CHAR(STARTDATE,'YYYYMMDD') INTO v_PeriodSeq, v_PeriodName,v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros getPeriodRow. v_PeriodSeq: ' || v_PeriodSeq || ', v_PeriodName: ' || v_PeriodName || ', v_fechaliquidacion: ' || v_fechaliquidacion , v_log_count, v_idproceso, 'info');
	--FICHERO DE SALIDA  

	--20260126 - TGV -- OBTENEMOS LA FECHA DEL ULTIMO CIERRE DEL PERIODO
	SELECT F_INICIO INTO v_fechaserver FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'PAGEXT_STATUS';
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fecha del cierre del periodo actual (fechaserver): ' || TO_CHAR(v_fechaserver,'YYYYMMDD_HH24MI'), v_log_count, v_idproceso, 'info');  
	

    --SELECT 'ALIEXT_PRD'||TO_VARCHAR(v_fechaserver, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_OCFTP167102P.txt' INTO FILENAME from dummy;
    --BRG 20250813 Nuevos nombres de ficheros por petición de MAA
	--SELECT 'ALIEXT1671_'||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME from dummy;
		-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA
	SELECT UTCTOLOCAL (current_utctimestamp, 'CET') INTO v_fechalocal FROM DUMMY;
    SELECT 'ALIEXT1671_'||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME from dummy;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA: ' || FILENAME, v_log_count, v_idproceso, 'info');  	
 
--  --------------- Creacion de variable tabla TEMP_TABLA_IRPF_ALIEXT_FILE --------------
    
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla TEMP_TABLA_IRPF_ALIEXT_FILE.', v_log_count, v_idproceso, 'info');  
	TEMP_TABLA_IRPF_ALIEXT_FILE =
				SELECT 
				    c.classifierID,
				    SUBSTRING(c.name, 1, 1) AS NAME,
				    gc.genericnumber1
				FROM 
				    cs_classifier c
				    INNER JOIN cs_genericclassifiertype gct 
				        ON c.selectorid = gct.genericclassifiertypeseq
				    INNER JOIN cs_genericclassifier gc 
				        ON gc.classifierseq = c.classifierseq
				        AND gc.removedate = :v_eot
				        AND gc.effectivestartdate <= v_fechaserver
				        AND gc.effectiveenddate > v_fechaserver
				    LEFT OUTER JOIN cs_category_classifiers cc 
				        ON cc.classifierseq = c.classifierseq
				        AND cc.removedate = :v_eot
				        AND cc.effectivestartdate <= v_fechaserver
				        AND cc.effectiveenddate > v_fechaserver
				    LEFT OUTER JOIN cs_categorytree ct 
				        ON ct.categorytreeseq = cc.categorytreeseq
				        AND ct.removedate = :v_eot
				        AND ct.effectivestartdate <= v_fechaserver
				        AND ct.effectiveenddate > v_fechaserver
				    LEFT OUTER JOIN cs_category cat 
				        ON cat.ruleelementseq = cc.categoryseq
				        AND cat.removedate = :v_eot
				        AND cat.effectivestartdate <= v_fechaserver
				        AND cat.effectiveenddate > v_fechaserver
				WHERE 
				    c.removedate = :v_eot
				    AND c.effectivestartdate <= v_fechaserver
				    AND c.effectiveenddate > v_fechaserver
				    AND ct.NAME = 'Tipo IRPF'
				    -- AND cat.NAME = 'Clase IRPF'
				    AND gct.NAME = 'Tipo IRPF'
				    AND gct.tenantid = v_idtenant
				    AND c.tenantid = v_idtenant
				    AND gc.tenantid = v_idtenant
				    AND cc.tenantid = v_idtenant
				    AND ct.tenantid = v_idtenant
				    AND cat.tenantid = v_idtenant;


	 v_num_rows = RECORD_COUNT(:TEMP_TABLA_IRPF_ALIEXT_FILE);
	--   COMMIT;
	 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla TEMP_TABLA_IRPF_ALIEXT_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');       


--   --------------- Creacion variable tabla TEMP_AUTOLIQUIDACION_FILE --------------  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla TEMP_CARTERA_DDEE_ALIEXT_FILE.', v_log_count, v_idproceso, 'info'); 
    
    TEMP_CARTERA_DDEE_ALIEXT_FILE =
        SELECT X.POSITIONNAME,X.COMPENSATIONDATE,X.EARNINGGROUPID,X.SEQ_POST,SUM(IFNULL(X.IMPORTE,0)) AS IMPORTE
        FROM EXT.CARTERA_DDEE X
        WHERE X.COMPENSATIONDATE = v_fechaserver
        --ALM 20220218: Incluimos el filtro por el nuevo campo ESTADO para quedarnos unicamente con los registros cobrados.
        AND X.ESTADO = 'C'
        GROUP BY X.POSITIONNAME,X.COMPENSATIONDATE,X.EARNINGGROUPID,X.SEQ_POST
    ;

	 v_num_rows = RECORD_COUNT(:TEMP_CARTERA_DDEE_ALIEXT_FILE);
	--   COMMIT;
	 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla TEMP_CARTERA_DDEE_ALIEXT_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');     

  
  --------------- Creacion variable tabla TEMP_AUTOLIQUIDACION_FILE --------------  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla TEMP_AUTOLIQUIDACION_FILE.', v_log_count, v_idproceso, 'info'); 
    
    TEMP_AUTOLIQUIDACION_FILE =
SELECT
    SUBSTRING(PAY.EARNINGGROUPID, 8, 1) AS CCOMPANI,
    SUBSTRING(POS.GENERICATTRIBUTE3, 1, 4) AS COFICINA,
    SUBSTR(v_fechaliquidacion,1,6) AS FCARGO,
    SUBSTRING(POS.GENERICATTRIBUTE3, 6, 5) AS CAGENTE,
    
    CASE SUBSTRING(PAY.EARNINGGROUPID, 1, 2)
        WHEN '01' THEN PAY.VALUE ELSE 0
    END AS IMPCOMIS,
    
    CASE SUBSTRING(PAY.EARNINGGROUPID, 1, 2)
        WHEN '04' THEN PAY.VALUE ELSE 0
    END AS IMPSUBVE,
    
    CASE SUBSTRING(PAY.EARNINGGROUPID, 1, 2)
        WHEN '03' THEN PAY.VALUE ELSE 0
    END AS IMPPREMI,
    
    CASE 
        WHEN PAR.GENERICATTRIBUTE3 = 'F' THEN
            CASE 
                WHEN PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4 <> 0
                     AND PAR.GENERICATTRIBUTE5 = SUBSTRING(PAY.EARNINGGROUPID, 7, 2)
                THEN IFNULL(PAR.GENERICNUMBER5, 0)
                ELSE IRPF.GENERICNUMBER1
            END
        --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
        --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and substr(PAR.genericattribute1,1,1) in ('G','J','E','U','V') THEN IRPF.GENERICNUMBER1 -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
        --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
        --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and substr(PAR.genericattribute1,1,1) in ('G','J','E','V') THEN IRPF.GENERICNUMBER1 -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
        --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
        --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and substr(PAR.genericattribute1,1,1) in ('G','J','E','V') AND PAR.GENERICATTRIBUTE1 <> 'J72106826'
        WHEN (PAR.GENERICATTRIBUTE3 = 'J') 
        	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	        --and substr(PAR.genericattribute1,1,1) in ('G','J','E','V')
	        AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')
	        AND PAR.GENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
            THEN IRPF.GENERICNUMBER1 -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
        ELSE 0
    END AS IRPF,
    
    'N' AS ENVIO_SII,

    CASE 
        WHEN (
            SELECT MAX(J.COD_REGIONAL)
            FROM EXT.OUT_JERARQUIA_REP J
            WHERE J.PERIODSEQ = PAY.PERIODSEQ 
              AND J.PARTICIPANTSEQ = PAY.PAYEESEQ 
              AND J.POSITIONSEQ = PAY.POSITIONSEQ
        ) = '0557'
        THEN 'C'
    END AS SERCO_CANARIAS

FROM cs_position POS
INNER JOIN cs_participant PAR 
    ON POS.PAYEESEQ = PAR.PAYEESEQ AND PAR.TENANTID = v_idtenant
INNER JOIN cs_payment PAY 
    ON PAR.PAYEESEQ = PAY.PAYEESEQ 
    AND POS.RULEELEMENTOWNERSEQ = PAY.POSITIONSEQ 
    AND PAY.TENANTID = v_idtenant
INNER JOIN :TEMP_TABLA_IRPF_ALIEXT_FILE IRPF 
    ON (
        CASE 
            WHEN PAR.TAXID IS NULL OR PAR.TAXID NOT IN ('I', 'E', 'S', 'C') 
            THEN 'P' 
            ELSE PAR.TAXID 
        END
    ) = IRPF.NAME

WHERE 
    PAR.GENERICBOOLEAN1 = 1
    AND (NOT(SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03') OR PAR.USERID = 'A82473349')
    AND (POS.GENERICNUMBER4 <> 2 OR POS.GENERICNUMBER4 IS NULL)
    AND SUBSTRING(POS.GENERICATTRIBUTE3, 5, 6) <> '999999'
    AND (PAR.TERMINATIONDATE IS NULL OR PAR.TERMINATIONDATE > v_fechaserver)
    AND PAY.POSTPIPELINERUNDATE IS NOT NULL
    AND POS.EFFECTIVESTARTDATE <= v_fechaserver
    AND POS.EFFECTIVEENDDATE > v_fechaserver
    AND PAR.EFFECTIVESTARTDATE <= v_fechaserver
    AND PAR.EFFECTIVEENDDATE > v_fechaserver
    AND POS.REMOVEDATE = :v_eot
    AND PAR.REMOVEDATE = :v_eot
    AND PAY.PERIODSEQ = v_PeriodSeq
    AND POS.TENANTID = v_idtenant
	
UNION ALL 
        SELECT
        SUBSTR(CAR_LP.EARNINGGROUPID,8,1)                                                                       as CCOMPANI,
        SUBSTR(POS.GENERICATTRIBUTE3,1,4)                                                                       as COFICINA,
        SUBSTR(v_fechaliquidacion,1,6)                                                                          as FCARGO,
        SUBSTR(POS.GENERICATTRIBUTE3,6,5)                                                                       as CAGENTE,
        CASE SUBSTR (CAR_LP.EARNINGGROUPID,1,2)  WHEN '01' THEN CAR_LP.IMPORTE ELSE 0 END                       AS IMPCOMIS,
        CASE SUBSTR (CAR_LP.EARNINGGROUPID,1,2)  WHEN '04' THEN CAR_LP.IMPORTE ELSE 0 END                       AS IMPSUBVE,
        CASE SUBSTR (CAR_LP.EARNINGGROUPID,1,2)  WHEN '03' THEN CAR_LP.IMPORTE ELSE 0 END                       AS IMPPREMI,   
        CASE WHEN (PAR.GENERICATTRIBUTE3 = 'F')
            THEN
            CASE  WHEN (PAR.GENERICNUMBER4 is not null AND PAR.GENERICNUMBER4<>0) AND PAR.GENERICATTRIBUTE5=substr(CAR_LP.EARNINGGROUPID,7,2) 
                    THEN IFNULL(PAR.GENERICNUMBER5,0)
                    ELSE IRPF.GENERICNUMBER1
            END
            --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
            --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and substr(PAR.genericattribute1,1,1) in ('G','J','E','V') AND PAR.GENERICATTRIBUTE1 <> 'J72106826'
            WHEN (PAR.GENERICATTRIBUTE3 = 'J') 
	            --BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		        --and substr(PAR.genericattribute1,1,1) in ('G','J','E','V')
		        AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V') 
	            AND PAR.GENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
                THEN IRPF.GENERICNUMBER1 -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
            ELSE 0
        END                                                                                             AS IRPF,
            
         'N'                                                                                             AS ENVIO_SII,
            
        CASE WHEN (SELECT MAX(J.COD_REGIONAL) FROM EXT.OUT_JERARQUIA_REP J WHERE J.STARTDATE = CAR_LP.COMPENSATIONDATE AND J.POS_CALLIDUS = CAR_LP.POSITIONNAME) = '0557'
            THEN 'C' 
        END                                                                                           AS SERCO_CANARIAS ---AIH cambiado 
            
            
        FROM cs_position pos                                                                        
        INNER JOIN cs_participant par ON pos.payeeseq=par.payeeseq AND par.tenantid= v_idtenant
        INNER JOIN :TEMP_CARTERA_DDEE_ALIEXT_FILE CAR_LP ON POS.NAME = CAR_LP.POSITIONNAME AND CAR_LP.COMPENSATIONDATE = v_fechaserver
        INNER JOIN :TEMP_TABLA_IRPF_ALIEXT_FILE IRPF ON (CASE WHEN PAR.TAXID IS NULL OR PAR.TAXID NOT IN ('I','E','S','C') THEN 'P' ELSE PAR.TAXID END) = IRPF.NAME
        
        WHERE 
            par.genericboolean1=1
            and (not(substr(CAR_LP.EARNINGGROUPID,7,2) like '03') or par.userid = 'A82473349')
            AND (POS.GENERICNUMBER4<>2 OR POS.GENERICNUMBER4 is NULL)
            and substr(pos.genericattribute3,5,6) <>'999999'
            and (par.TERMINATIONDATE is null or par.TERMINATIONDATE > v_fechaserver)
            
            --ALM 20220218: Como no tenemos el campo FECHA_POST usamos el SEQ_POST que funciona igual.
            --and CAR_LP.FECHA_POST is not NULL--- AIH CREADA EN TABLA
            AND CAR_LP.SEQ_POST IS NOT NULL
                         
            AND POS.EFFECTIVESTARTDATE <= v_fechaserver
            AND POS.EFFECTIVEENDDATE > v_fechaserver
            AND PAR.EFFECTIVESTARTDATE <= v_fechaserver
            AND PAR.EFFECTIVEENDDATE > v_fechaserver
            AND pos.removedate=v_eot             --Usare esto para pruebas              
            AND par.removedate=v_eot             --Usare esto para pruebas
            --AND CAR_LP.PERIODSEQ=v_periodRow.PERIODSEQ   
            AND pos.tenantid=v_idtenant; 

	 v_num_rows = RECORD_COUNT(:TEMP_AUTOLIQUIDACION_FILE);
	--   COMMIT;
	 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla TEMP_AUTOLIQUIDACION_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');  
	 
	 
--     --------------- Truncado de FINAL_AUTOLIQUIDACION_FILE -------------- 
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Truncado de la tabla de FINAL_AUTOLIQUIDACION_FILE.', v_log_count, v_idproceso, 'info');
    TRUNCATE TABLE FINAL_AUTOLIQUIDACION_FILE;  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Truncado de la tabla de FINAL_AUTOLIQUIDACION_FILE.', v_log_count, v_idproceso, 'info');	 
    
--   --------------- Creacion variable tabla FINAL_AUTOLIQUIDACION_FILE --------------  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla FINAL_AUTOLIQUIDACION_FILE.', v_log_count, v_idproceso, 'info');   

	INSERT INTO EXT.FINAL_AUTOLIQUIDACION_FILE (
	    CCOMPANI,
	    COFICINA,
	    FCARGO,
	    CAGENTE,
	    IMPCOMIS,
	    IMPSUBVE,
	    IMPPREMI,
	    IRPF,
	    ENVIO_SII,
	    SERCO_CANARIAS,
	    PAGCOMIS,
	    PAGSUBVE,
	    PAGPREMI
	)
	SELECT 
	    temp.CCOMPANI,
	    temp.COFICINA,
	    temp.FCARGO,
	    temp.CAGENTE,
	    SUM(temp.IMPCOMIS),
	    SUM(temp.IMPSUBVE),
	    SUM(temp.IMPPREMI),
	    temp.IRPF,
	    temp.ENVIO_SII,
	    temp.SERCO_CANARIAS,
	    
	    -- Aquí calculamos los pagos
	    IFNULL((SELECT SUM(PAGEXT.DC_IMPORTE1) 
	            FROM EXT.FINAL_EXTRACTPAGOS_FILE PAGEXT
	            WHERE PAGEXT.CIA_CODIGO = ('0' || temp.CCOMPANI) 
	            AND PAGEXT.PAG_OFICINA = temp.COFICINA 
	            AND PAGEXT.PAG_AGENTE = ('0' || temp.CAGENTE) 
	            AND PAGEXT.PERIODSEQ = v_PeriodSeq), 0) AS PAGCOMIS,
	
	    IFNULL((SELECT SUM(PAGEXT.DC_IMPORTE4) 
	            FROM EXT.FINAL_EXTRACTPAGOS_FILE PAGEXT
	            WHERE PAGEXT.CIA_CODIGO = ('0' || temp.CCOMPANI) 
	            AND PAGEXT.PAG_OFICINA = temp.COFICINA 
	            AND PAGEXT.PAG_AGENTE = ('0' || temp.CAGENTE) 
	            AND PAGEXT.PERIODSEQ = v_PeriodSeq), 0) AS PAGSUBVE,
	
	    IFNULL((SELECT SUM(PAGEXT.DC_IMPORTE3) 
	            FROM EXT.FINAL_EXTRACTPAGOS_FILE PAGEXT
	            WHERE PAGEXT.CIA_CODIGO = ('0' || temp.CCOMPANI) 
	            AND PAGEXT.PAG_OFICINA = temp.COFICINA 
	            AND PAGEXT.PAG_AGENTE = ('0' || temp.CAGENTE) 
	            AND PAGEXT.PERIODSEQ = v_PeriodSeq), 0) AS PAGPREMI
	
	FROM :TEMP_AUTOLIQUIDACION_FILE temp
	
	GROUP BY 
	    temp.CCOMPANI,
	    temp.COFICINA,
	    temp.FCARGO,
	    temp.CAGENTE,
	    temp.IRPF,
	    temp.ENVIO_SII,
	    temp.SERCO_CANARIAS;
     
	 v_num_rows = RECORD_COUNT(EXT.FINAL_AUTOLIQUIDACION_FILE);
	--   COMMIT;
	 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla FINAL_AUTOLIQUIDACION_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');  
	 
	 
--     --------------- Truncado de OUT_AUTOLIQUIDACION_INFORME_FILE -------------- 
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Truncado de la tabla de OUT_AUTOLIQUIDACION_INFORME_FILE.', v_log_count, v_idproceso, 'info');
    TRUNCATE TABLE OUT_AUTOLIQUIDACION_INFORME_FILE;  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Truncado de la tabla de OUT_AUTOLIQUIDACION_INFORME_FILE.', v_log_count, v_idproceso, 'info');	 

--   --------------- Creacion variable tabla OUT_AUTOLIQUIDACION_INFORME_FILE --------------  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla OUT_AUTOLIQUIDACION_INFORME_FILE.', v_log_count, v_idproceso, 'info');   
    
	INSERT INTO OUT_AUTOLIQUIDACION_INFORME_FILE
    SELECT
    fin.CCOMPANI || fin.COFICINA || fin.FCARGO || fin.CAGENTE
    ||CASE WHEN fin.IMPCOMIS >= 0 THEN '+' ELSE '-' END|| LPAD(floor(abs(fin.IMPCOMIS)),12,'0')||','||LPAD((abs(mod(fin.IMPCOMIS,1)*100)),2,'0')
    ||CASE WHEN fin.IMPSUBVE >= 0 THEN '+' ELSE '-' END|| LPAD(floor(abs(fin.IMPSUBVE)),12,'0')||','||LPAD((abs(mod(fin.IMPSUBVE,1)*100)),2,'0')
    ||CASE WHEN fin.IMPPREMI >= 0 THEN '+' ELSE '-' END|| LPAD(floor(abs(fin.IMPPREMI)),12,'0')||','||LPAD((abs(mod(fin.IMPPREMI,1)*100)),2,'0')
    ||CASE WHEN round(((fin.IMPCOMIS + fin.IMPSUBVE + fin.IMPPREMI) * fin.IRPF),2) >= 0 THEN '+' ELSE '-' END|| LPAD(floor(abs(round(((fin.IMPCOMIS + fin.IMPSUBVE + fin.IMPPREMI) * fin.IRPF),2))),12,'0')||','||LPAD((abs(mod(round(((fin.IMPCOMIS + fin.IMPSUBVE + fin.IMPPREMI) * fin.IRPF),2),1)*100)),2,'0')
    --ALM 20180418: Nuevo campo en la posicion 81.
    || ENVIO_SII 
    --ALM 20180612: Nuevo campo en la posicion 82.
    ||CASE WHEN SERCO_CANARIAS IS NULL THEN ' ' ELSE SERCO_CANARIAS END
    --ALM 20181023: Tres nuevos campos de 16 digitos de longitud. De la posicion 83 a la 130.
    ||CASE WHEN fin.PAGCOMIS >= 0 THEN '+' ELSE '-' END|| LPAD(floor(abs(fin.PAGCOMIS)),12,'0')||','||LPAD((abs(mod(fin.PAGCOMIS,1)*100)),2,'0')
    ||CASE WHEN fin.PAGSUBVE >= 0 THEN '+' ELSE '-' END|| LPAD(floor(abs(fin.PAGSUBVE)),12,'0')||','||LPAD((abs(mod(fin.PAGSUBVE,1)*100)),2,'0')
    ||CASE WHEN fin.PAGPREMI >= 0 THEN '+' ELSE '-' END|| LPAD(floor(abs(fin.PAGPREMI)),12,'0')||','||LPAD((abs(mod(fin.PAGPREMI,1)*100)),2,'0')
    --ALM 20191120: Anadimos un nuevo campo con la fecha del ultimo dia del mes de pago
    ||TO_VARCHAR(CURRENT_TIMESTAMP, 'YYYYMMDD')
    FROM FINAL_AUTOLIQUIDACION_FILE fin;
     
	 v_num_rows = RECORD_COUNT(EXT.OUT_AUTOLIQUIDACION_INFORME_FILE);
	--   COMMIT;
	 CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla OUT_AUTOLIQUIDACION_INFORME_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');  

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