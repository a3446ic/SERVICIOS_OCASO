CREATE OR REPLACE PROCEDURE EXT.SP_NOMEXT(OUT FILENAME VARCHAR(120) , IN i_pPlRunSeq VARCHAR(50))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS 
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 26-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: nos permite obtener en la tabla OUT_NOMINA_INFORME_FILE el contenido del fichero de nomina.
    | Con parametros de entrada, la fecha de liquidacion, v_fechaliquidacion'YYYYMM' y la fecha a la que se calcula el pago, fechapago 'YYYYMMDD_HHMM' 
	|
	| Version: 0.1	SMM 20250326		Initial Version.
	| Version: 0.2  DTB 20250902        Cambio en DECIMAL(15,2) para el campo IMPORTE de la tabla TEMP_NOMINA_FILE, ahora DECIMAL(15,>2).
    |                                   Cambio en el redondeo de la parte decimal de IMPORTE en la tabla final EXT_OUT_NOMINA_INFORME_FILE
	| Version: 0.3  TGV 20260126		Creamos la variable de fechaserver para que obtenga la Fecha del cierre del periodo actual
    -----------------------------------------------------------------------
*/
BEGIN
	
	-- DECLARACIÓN DE CONSTANTES Y VARIABLES
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
	DECLARE v_PeriodStartDate TIMESTAMP;
    DECLARE v_fechaserver TIMESTAMP;
	DECLARE v_fechaliquidacion VARCHAR(6);
	DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
	DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
	DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
	DECLARE v_file_name VARCHAR(20) := 'NOMEXT1669_';
	DECLARE v_fechalocal TIMESTAMP;
    
    --TABLA TEMPORAL
    DECLARE TEMP_NOMINA_FILE TABLE (
        CIA VARCHAR(2),
        DNI VARCHAR(11),
        CONCEPTO VARCHAR(6),
        IMPORTE DECIMAL(15,4),
        FCH_INI VARCHAR(6),
        FCH_FIN VARCHAR(6),
        FCH_PAGA VARCHAR(6)
    );
	
	
	--CONTROLADOR DE EXCEPCIONES
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		
		-- ROLLBACK;
			
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		v_num_rows := 0;
		
		UPDATE EXT.OUT_BATCH_CONTROL
		SET STATUS = v_const_out_batch_control_error,
			END_DATE = CURRENT_TIMESTAMP
		WHERE COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
			AND ID_PROCESO = v_idproceso;
		commit;	
			RESIGNAL;
			
	END;
	
	--INICIALIZAMOS IDPROCESO
	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq , v_log_count, v_idproceso, 'info');
	BEGIN
		--REGISTRO OUT_BATCH_CONTROL
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_idproceso,FILENAME,::CURRENT_OBJECT_NAME,0,EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD,CURRENT_TIMESTAMP,NULL);
		COMMIT;
	END;
	
	-- SELECCIONAMOS PERIODSEQ
	SELECT PERIODSEQ, NAME, STARTDATE, TO_CHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate,v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq || ' Periodo: ' || v_PeriodName || ' Fecha liquidación: ' || v_fechaliquidacion || ' PeriodSeq: '|| v_PeriodSeq, v_log_count, v_idproceso, 'info');
	
    --20260126 - TGV -- OBTENEMOS LA FECHA DEL ULTIMO CIERRE DEL PERIODO
    SELECT F_INICIO INTO v_fechaserver FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'PAGEXT_STATUS';
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fecha del cierre del periodo actual (fechaserver): ' || TO_CHAR(v_fechaserver,'YYYYMMDD_HH24MI'), v_log_count, v_idproceso, 'info');  
	
	
	--FICHERO DE SALIDA 
	--EJ NOMEXT: INYC_NOMEXT_PRD_20250128_092808_OCASO_OPFTP166902_1zgwc.txt
    --SELECT v_file_name||TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_OPFTP166902.txt' INTO FILENAME FROM dummy;
    
    --20250812 BRG - A PETICION DE MIGUEL ANGEL ARENAS SE CAMBIAR EL NOMBRE DE SALIDA A LIQEXT_AAAAMMDD_HHMMSS.txt
--    SELECT v_file_name||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME FROM dummy;
	-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA
	SELECT UTCTOLOCAL (current_utctimestamp, 'CET') INTO v_fechalocal FROM DUMMY;
	SELECT v_file_name||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME FROM dummy;
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA ' || FILENAME, v_log_count, v_idproceso, 'info');      
	
	
	

    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de TEMP_NOMINA_FILE.', v_log_count, v_idproceso, 'info');     
    
	INSERT INTO :TEMP_NOMINA_FILE
	SELECT 
	    SUBSTR(PAY.EARNINGGROUPID,7,2) as CIA,
	    RPAD(PAR.GENERICATTRIBUTE1,11,' ') as DNI,
	    CASE
            SUBSTR(pay.EARNINGCODEID,1,1) 
                WHEN '1' THEN '477230'
                WHEN '2' THEN 
                    CASE SUBSTR(pay.EARNINGCODEID,1,3) 
                        WHEN '206' THEN '477230'
                        WHEN '207' THEN '482630'
                        WHEN '217' THEN '482630'
                        WHEN '202' THEN 
                            CASE WHEN SUBSTR(v_fechaliquidacion,LENGTH(v_fechaliquidacion)-1,2) between '06' and '11' 
                                THEN '482730'
                                ELSE '477430' 
                            END
                        ELSE '477230' 
                    END--Casos 2**         
                WHEN '3' THEN 
                    CASE SUBSTR(pay.EARNINGCODEID,1,3) 
                        WHEN '301' THEN 
                            CASE WHEN (SUBSTR(pay.earninggroupid,10,2) ='AM' OR pay.earninggroupid = '03-S5-01') 
                                THEN '479630'
                                ELSE '477430'
                            END                         
                        WHEN '302' THEN 
                            CASE WHEN pay.earninggroupid = '03-S5-01'
                                THEN '483130'
                                ELSE '477430'
                            END
                        WHEN '305' THEN 
                            CASE 
                                WHEN SUBSTR(v_fechaliquidacion,LENGTH(v_fechaliquidacion)-1,2) = '06' 
                                    THEN '483230'
                                WHEN SUBSTR(v_fechaliquidacion,LENGTH(v_fechaliquidacion)-1,2) = '12' 
                                    THEN '483130'
                                ELSE '477430' 
                            END
                        WHEN '307' THEN '483130'
                        WHEN '309' THEN '479630'
                        WHEN '310' THEN '483130'                                                                           
                        ELSE '477330' 
                    END
                    
                WHEN '4' THEN 
                    CASE SUBSTR(pay.earninggroupid,10,2) 
                        WHEN 'RE' THEN '477430' --4** y Regularizacion Rappel Inspectores
                        ELSE '477330' --4** y NO Regularizacion Rappel Inspectores
                    END
                WHEN '5' THEN '478130'
        END AS CONCEPTO,                                  
    --FALTA DEFINIR LOS CONCEPTOS ESPECIALES
    ROUND(pay.value,2)     as IMPORTE,
    --ALM 20170619: Anadimos los conceptos 1** para los agentes anadidos a mano a peticion de Javier
    CASE 
        SUBSTR(pay.EARNINGCODEID,1,1) 
            WHEN '1' THEN v_fechaliquidacion
            WHEN '2' THEN 
                CASE 
                    SUBSTR(pay.EARNINGCODEID,1,3) 
                        WHEN '206' THEN v_fechaliquidacion
                        WHEN '202' THEN SUBSTR(v_fechaliquidacion,1,4)||'01' --Enero del ano de la liquidacion
                        ELSE v_fechaliquidacion
                END
            WHEN '3' THEN 
                CASE 
                    SUBSTR(pay.EARNINGCODEID,1,3)
                        WHEN '301' THEN
                            CASE 
                                SUBSTR(pay.earninggroupid,10,2) 
                                    WHEN 'AM' THEN v_fechaliquidacion
                                    ELSE SUBSTR(v_fechaliquidacion,1,4)||'01'--Enero del ano de la liquidacion
                            END                                                                 
                        WHEN '302' THEN SUBSTR(v_fechaliquidacion,1,4)||'01'--Enero del ano de la liquidacion
                        WHEN '305' THEN SUBSTR(v_fechaliquidacion,1,4)||'01'--Enero del ano de la liquidacion
                        WHEN '307' THEN v_fechaliquidacion
                        WHEN '309' THEN v_fechaliquidacion
                        WHEN '310' THEN (SUBSTR(v_fechaliquidacion,1,4)-'0001')||'01' --Enero ejercicio anterior
                        ELSE v_fechaliquidacion
                END
                                       
            WHEN '4' THEN 
                CASE 
                    SUBSTR(pay.earninggroupid,10,2) 
                        WHEN 'RE' THEN
                            CASE 
                                SUBSTR(v_fechaliquidacion,5,2) 
                                    WHEN '12' THEN SUBSTR(v_fechaliquidacion,1,4)||'01'
                                    ELSE SUBSTR(v_fechaliquidacion,1,4)||LPAD((SUBSTR(v_fechaliquidacion,5,2)-'02'),2,'0')
                            END   --4** y Regularizacion Rappel Inspectores
                        ELSE v_fechaliquidacion --4** y NO Regularizacion Rappel Inspectores                                             
                END
            WHEN '5' THEN v_fechaliquidacion
    END AS FCH_INI,
    /*Copiar consulta anterior, y en el THEN poner la FCH-INI para cada caso*/
    --ALM 20170619: Anadimos los conceptos 1** para los agentes anadidos a mano a peticion de Javier
    CASE 
        SUBSTR(pay.EARNINGCODEID,1,1) 
            WHEN '1' THEN v_fechaliquidacion
            WHEN '2' THEN 
                CASE 
                    SUBSTR(pay.EARNINGCODEID,1,3) 
                        WHEN '206' THEN v_fechaliquidacion
                        WHEN '202' THEN SUBSTR(v_fechaliquidacion,1,4)||'12' --Diciembre del ano de la liquidacion
                        ELSE v_fechaliquidacion
                END                                                                          
            WHEN '3' THEN 
                CASE 
                    SUBSTR(pay.EARNINGCODEID,1,3)
                        WHEN '301' THEN v_fechaliquidacion                                                                                                                        
                        WHEN '302' THEN v_fechaliquidacion
                        WHEN '305' THEN v_fechaliquidacion
                        WHEN '307' THEN v_fechaliquidacion
                        WHEN '309' THEN v_fechaliquidacion
                        WHEN '310' THEN (SUBSTR(v_fechaliquidacion,1,4)-'0001')||'12' --Diciembre ejercicio anterior 
                        ELSE v_fechaliquidacion
                END                                                       
            WHEN '4' THEN v_fechaliquidacion
            WHEN '5' THEN v_fechaliquidacion
    END AS FCH_FIN,
    /*FCH-PAGA, mes siguiente al del cierre de cobros de las liquidaciones*/    
    CASE 
        WHEN SUBSTR(v_fechaliquidacion,5,2)='12' 
            THEN  concat((SUBSTR(v_fechaliquidacion,1,4)+'0001'),'01')
            ELSE SUBSTR(v_fechaliquidacion,1,4)||LPAD((SUBSTR(v_fechaliquidacion,5,2)+'01'),2,'0') 
    END AS FCH_PAGA
    FROM cs_participant par                                 
    INNER JOIN cs_payment pay ON par.payeeseq=pay.payeeseq
        AND pay.tenantid= v_idtenant
    WHERE   1=1
        --nos quedamos con la ultima ejecucion
        AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'        
        --Nos quedamos con S5 y empleado
        --ALM 20170518: Nos piden agregar a dos agentes (S4) al NOMEXT y quitarlos del PAGEXT
        --AND (SUBSTR(PAY.EARNINGGROUPID,4,2)='S5' AND (PAR.GENERICNUMBER4 is not null and PAR.GENERICNUMBER4 <> 0))
        AND ((SUBSTR(PAY.EARNINGGROUPID,4,2)='S5' AND (PAR.GENERICNUMBER4 is not null and PAR.GENERICNUMBER4 <> 0))
            OR (PAR.GENERICATTRIBUTE1 IN ('50115742F','52096024N')))
        
        --ALM 20170608: Por peticion de Javier quitamos a los agentes dados de baja
        and (par.TERMINATIONDATE is null or par.TERMINATIONDATE > v_fechaserver)
        
        ----No mostramos las AGENCIAS
        --AND (POS.GENERICNUMBER4<>2 OR POS.GENERICNUMBER4 is NULL)
        
        --Autoliquidacion FALSE
        --ALN 20180530: Tomamos un nulo en el campo Autoliquida (GB1) del Participant como 0
        --AND par.genericboolean1=0
        AND (par.genericboolean1=0 or par.genericboolean1 is null)
        
        AND PAR.EFFECTIVESTARTDATE <= v_fechaserver
        AND PAR.EFFECTIVEENDDATE > v_fechaserver
        
        --Usaremos esto para versiones finales
        --AND PAR.CREATEDATE <= fechaserver
        --AND PAR.removedate > fechaserver
        
        --Usado para pruebas
        --AND par.ISLAST=1
        AND par.removedate=to_date('22000101','YYYYMMDD')
        
        --Solo cogemos el mes que se pasa
        AND PAY.PERIODSEQ=v_periodSeq
        AND par.tenantid=v_idtenant
        
        --JGE 20240326 por peticion de david se excluyen estos 3 agentes
        AND NOT(PAR.GENERICATTRIBUTE1 IN ('16533809Y','31675710H','34821283L') AND PAY.EARNINGCODEID = '308');
    COMMIT;

    v_num_rows = RECORD_COUNT(:TEMP_NOMINA_FILE);

	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de TEMP_NOMINA_FILE ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de TEMP_CARTERA_DDEE_NOMEXT_FILE', v_log_count, v_idproceso, 'info');
	
	TEMP_CARTERA_DDEE_NOMEXT_FILE = 
        SELECT X.POSITIONNAME
            ,X.COMPENSATIONDATE
            ,X.EARNINGCODEID
            ,X.EARNINGGROUPID
            ,X.SEQ_POST
            ,SUM(IFNULL(X.IMPORTE,0)) AS IMPORTE
        FROM EXT.CARTERA_DDEE X
        WHERE X.COMPENSATIONDATE = v_periodStartDate
        --ALM 20220218: Incluimos el filtro por el nuevo campo ESTADO para quedarnos unicamente con los registros cobrados.
            AND X.ESTADO = 'C'
        GROUP BY X.POSITIONNAME
            ,X.COMPENSATIONDATE
            ,X.EARNINGCODEID
            ,X.EARNINGGROUPID
            ,X.SEQ_POST;
    
    v_num_rows = RECORD_COUNT(:TEMP_CARTERA_DDEE_NOMEXT_FILE);

	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de TEMP_CARTERA_DDEE_NOMEXT_FILE ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');
	
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de TEMP_NOMINA_FILE. DDEE', v_log_count, v_idproceso, 'info');

	INSERT INTO :TEMP_NOMINA_FILE
	SELECT
        SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS CIA,
        RPAD(PAR.GENERICATTRIBUTE1,11,' ') AS DNI,
        CASE 
            SUBSTR(CAR_LP.EARNINGCODEID,1,1)
                WHEN '1' THEN '477230'
                WHEN '2' THEN
                    CASE
                        SUBSTR(CAR_LP.EARNINGCODEID,1,3)
                            WHEN '206' THEN '477230'
                            --JGE 20240401 correo Javier Incentivo Trismestal Inspectores Reglados
                            WHEN '207' THEN '482630'
                            WHEN '217' THEN '482630'
                            WHEN '202' THEN
                                CASE
                                    WHEN SUBSTR(v_fechaliquidacion,LENGTH(v_fechaliquidacion)-1,2) between '06' and '11'
                                        THEN '482730'
                                        ELSE '477430'
                                END
                            ELSE '477230'
                    END--Casos 2**
                WHEN '3' THEN
                    CASE
                        SUBSTR(CAR_LP.EARNINGCODEID,1,3)
                            WHEN '301' THEN
                                CASE
                                    WHEN (SUBSTR(CAR_LP.earninggroupid,10,2) ='AM' OR CAR_LP.earninggroupid = '03-S5-01')
                                        THEN '479630'
                                        ELSE '477430'
                                END
                            WHEN '302' THEN
                                --'477430' 
                                CASE
                                    WHEN CAR_LP.earninggroupid = '03-S5-01'
                                        THEN '483130'
                                        ELSE '477430'
                                END
                            WHEN '305' THEN 
                                --ALM 20170915: Por peticion de Javier utilizamos la v_fechaliquidacion
                                -- para mostrar un valor u otro
                                CASE 
                                    WHEN SUBSTR(v_fechaliquidacion,LENGTH(v_fechaliquidacion)-1,2) = '06' 
                                        THEN '483230'
                                    WHEN SUBSTR(v_fechaliquidacion,LENGTH(v_fechaliquidacion)-1,2) = '12' 
                                        THEN '483130'
                                    ELSE '477430'
                                END
                            WHEN '307' THEN '483130'
                            WHEN '309' THEN '479630'
                            WHEN '310' THEN '483130'
                            ELSE '477330' END
                WHEN '4' THEN 
                    CASE 
                        SUBSTR(CAR_LP.earninggroupid,10,2)
                            WHEN 'RE' THEN '477430' --4** y Regularizacion Rappel Inspectores
                            ELSE '477330' --4** y NO Regularizacion Rappel Inspectores
                    END
                WHEN '5' THEN '478130'
        END AS CONCEPTO,
        CAR_LP.IMPORTE     as IMPORTE,
        CASE
            SUBSTR(CAR_LP.EARNINGCODEID,1,1)
                WHEN '1' THEN v_fechaliquidacion
                WHEN '2' THEN
                    CASE
                        SUBSTR(CAR_LP.EARNINGCODEID,1,3)
                            WHEN '206' THEN v_fechaliquidacion
                            WHEN '202' THEN SUBSTR(v_fechaliquidacion,1,4)||'01' --Enero del ano de la liquidacion
                            ELSE v_fechaliquidacion
                    END
                WHEN '3' THEN 
                    CASE 
                        SUBSTR(CAR_LP.EARNINGCODEID,1,3)
                            WHEN '301' THEN
                                CASE
                                    SUBSTR(CAR_LP.earninggroupid,10,2)
                                        WHEN 'AM' THEN v_fechaliquidacion
                                        ELSE SUBSTR(v_fechaliquidacion,1,4)||'01'--Enero del ano de la liquidacion
                                END
                            WHEN '302' THEN SUBSTR(v_fechaliquidacion,1,4)||'01'--Enero del ano de la liquidacion
                            WHEN '305' THEN SUBSTR(v_fechaliquidacion,1,4)||'01'--Enero del ano de la liquidacion
                            WHEN '307' THEN v_fechaliquidacion
                            WHEN '309' THEN v_fechaliquidacion
                            WHEN '310' THEN (SUBSTR(v_fechaliquidacion,1,4)-'0001')||'01' --Enero ejercicio anterior
                            ELSE v_fechaliquidacion
                    END
                WHEN '4' THEN
                    CASE
                        SUBSTR(CAR_LP.earninggroupid,10,2)
                            WHEN 'RE' THEN
                                CASE
                                    SUBSTR(v_fechaliquidacion,5,2) 
                                        WHEN '12' THEN SUBSTR(v_fechaliquidacion,1,4)||'01'
                                        ELSE SUBSTR(v_fechaliquidacion,1,4)||LPAD((SUBSTR(v_fechaliquidacion,5,2)-'02'),2,'0')
                                END   --4** y Regularizacion Rappel Inspectores
                            ELSE v_fechaliquidacion --4** y NO Regularizacion Rappel Inspectores
                    END
                WHEN '5' THEN v_fechaliquidacion
        END AS FCH_INI,
        CASE 
            SUBSTR(CAR_LP.EARNINGCODEID,1,1)
                wHEN '1' THEN v_fechaliquidacion
                WHEN '2' THEN 
                    CASE
                        SUBSTR(CAR_LP.EARNINGCODEID,1,3)
                            WHEN '206' THEN v_fechaliquidacion
                            WHEN '202' THEN SUBSTR(v_fechaliquidacion,1,4)||'12' --Diciembre del ano de la liquidacion
                            ELSE v_fechaliquidacion
                    END
                WHEN '3' THEN
                    CASE
                        SUBSTR(CAR_LP.EARNINGCODEID,1,3)
                            WHEN '301' THEN v_fechaliquidacion
                            WHEN '302' THEN v_fechaliquidacion
                            WHEN '305' THEN v_fechaliquidacion
                            WHEN '307' THEN v_fechaliquidacion
                            WHEN '309' THEN v_fechaliquidacion
                            WHEN '310' THEN (SUBSTR(v_fechaliquidacion,1,4)-'0001')||'12' --Diciembre ejercicio anterior 
                            ELSE v_fechaliquidacion
                    END
                WHEN '4' THEN v_fechaliquidacion                                                                                              
                WHEN '5' THEN v_fechaliquidacion
        END AS FCH_FIN,
        CASE
            WHEN SUBSTR(v_fechaliquidacion,5,2)='12' 
                THEN  concat((SUBSTR(v_fechaliquidacion,1,4)+'0001'),'01')
                ELSE SUBSTR(v_fechaliquidacion,1,4)||LPAD((SUBSTR(v_fechaliquidacion,5,2)+'01'),2,'0')
        END AS FCH_PAGA
        FROM cs_position pos
        INNER JOIN cs_participant par ON pos.payeeseq=par.payeeseq AND par.tenantid=v_idtenant
             
        --ALM 20220218: Utilizamos la nueva tabla propia para el NOMEXT.
        INNER JOIN :TEMP_CARTERA_DDEE_NOMEXT_FILE CAR_LP  on pos.name= CAR_LP.POSITIONNAME  and  CAR_LP.COMPENSATIONDATE = v_periodStartDate
        WHERE   
            --ALM 20220218: Como no tenemos el campo FECHA_POST usamos el SEQ_POST que funciona igual.
            --CAR_LP.FECHA_POST is not NULL
            CAR_LP.SEQ_POST IS NOT NULL
                  
            AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
            AND ((SUBSTR(CAR_LP.EARNINGGROUPID,4,2)='S5' AND (PAR.GENERICNUMBER4 is not null and PAR.GENERICNUMBER4 <> 0))
                OR (PAR.GENERICATTRIBUTE1 IN ('50115742F','52096024N')))
                
            AND (par.TERMINATIONDATE is null or par.TERMINATIONDATE > v_fechaserver)
            AND (par.genericboolean1=0 or par.genericboolean1 is null)
                
            AND PAR.EFFECTIVESTARTDATE <= v_fechaserver
            AND PAR.EFFECTIVEENDDATE > v_fechaserver
            AND par.removedate=to_date('22000101','YYYYMMDD')
              
            -- AIH TAMBI�N PARA POS.
            AND POS.EFFECTIVESTARTDATE <= v_fechaserver
            AND POS.EFFECTIVEENDDATE > v_fechaserver
            AND POS.removedate = to_date('22000101','YYYYMMDD')
            --   AIH QUITAMOS ESTO, NO HACE FALTA       AND PAY.PERIODSEQ=v_periodRow.PERIODSEQ
            AND par.tenantid=v_idtenant;
      
    v_num_rows = RECORD_COUNT(:TEMP_NOMINA_FILE);

	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de TEMP_NOMINA_FILE. DDEE ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');

    --------------- Truncado de FINAL_NOMINA_FILE -------------- 
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Truncado de la tabla de FINAL_NOMINA_FILE.', v_log_count, v_idproceso, 'info');
    execute immediate 'truncate table EXT.FINAL_NOMINA_FILE';  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Truncado de la tabla de FINAL_NOMINA_FILE.', v_log_count, v_idproceso, 'info'); 

    --------------- Creacion de FINAL_NOMINA_FILE -------------- 
     
   
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de FINAL_NOMINA_FILE', v_log_count, v_idproceso, 'info');
    
    INSERT INTO EXT.FINAL_NOMINA_FILE(CIA,DNI,CONCEPTO,IMPORTE,FCH_INI,FCH_FIN,FCH_PAGA)
    SELECT
        TEMP.CIA,TEMP.DNI,TEMP.CONCEPTO,SUM(TEMP.IMPORTE),TEMP.FCH_INI,TEMP.FCH_FIN,TEMP.FCH_PAGA
    FROM :TEMP_NOMINA_FILE temp
    GROUP BY TEMP.CIA, TEMP.DNI, TEMP.CONCEPTO, TEMP.FCH_INI, TEMP.FCH_FIN, TEMP.FCH_PAGA;
    COMMIT;

    v_num_rows = RECORD_COUNT(EXT.FINAL_NOMINA_FILE);
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de FINAL_NOMINA_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');        
   
        
      
   --------------- Insertamos ultima linea de FINAL_NOMINA_FILE -------------- 
   
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Insertar ultima linea en la tabla de FINAL_NOMINA_FILE.', v_log_count, v_idproceso, 'info');
    
    INSERT INTO EXT.FINAL_NOMINA_FILE(CIA,DNI,CONCEPTO,IMPORTE,FCH_INI,FCH_FIN,FCH_PAGA)
    SELECT
        '01',RPAD(' ', 11),
        --ALM 20161228: El concepto ha pasado a ser de 6 carateres por lo que anadios 2 ceros mas para cuadrarlo
        '000000',
        0,v_fechaliquidacion,v_fechaliquidacion,
        CASE 
            WHEN SUBSTR(v_fechaliquidacion,5,2)='12' 
                THEN  concat((SUBSTR(v_fechaliquidacion,1,4)+'0001'),'01')
                ELSE SUBSTR(v_fechaliquidacion,1,4)||LPAD((SUBSTR(v_fechaliquidacion,5,2)+'01'),2,'0')
        END
    FROM DUMMY;
    COMMIT;

    v_num_rows = RECORD_COUNT(EXT.FINAL_NOMINA_FILE);
    
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insertar ultima linea en la tabla de FINAL_NOMINA_FILE: ' || v_num_rows || ' filas.', v_log_count, v_idproceso, 'info');        
      
    --------------- Truncado de OUT_NOMINA_INFORME_FILE -------------- 
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Truncado de la tabla de OUT_NOMINA_INFORME_FILE.', v_log_count, v_idproceso, 'info');
    
    TRUNCATE TABLE EXT.OUT_NOMINA_INFORME_FILE;  
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Truncado de la tabla de OUT_NOMINA_INFORME_FILE.', v_log_count, v_idproceso, 'info');
      
   --------------- Creacion de OUT_NOMINA_INFORME_FILE --------------
   
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de OUT_NOMINA_INFORME_FILE.', v_log_count, v_idproceso, 'info');
    INSERT INTO EXT.OUT_NOMINA_INFORME_FILE
    SELECT
        temp.CIA 
        || RPAD(temp.DNI,11, ' ')
        || temp.CONCEPTO 
        || CASE 
            WHEN temp.IMPORTE >= 0 
                THEN '+' 
                ELSE '-' 
            END
        || LPAD(FLOOR(ABS(temp.IMPORTE)),7,'0')
        ||','
        ||LPAD(ROUND(ABS(MOD(temp.IMPORTE,1)),2)*100,2,'0')
        || temp.FCH_INI 
        || temp.FCH_FIN 
        || temp.FCH_PAGA    
    FROM EXT.FINAL_NOMINA_FILE temp
    WHERE TEMP.CONCEPTO IS NOT NULL
    ORDER BY temp.DNI DESC;
    COMMIT;
    
    v_num_rows = RECORD_COUNT(EXT.OUT_NOMINA_INFORME_FILE);
    
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Insertar ultima linea en la tabla de OUT_NOMINA_INFORME_FILE: ' || To_VARCHAR(::ROWCOUNT) || ' filas.', v_log_count, v_idproceso, 'info');           
   

	UPDATE EXT.OUT_BATCH_CONTROL
	SET STATUS = v_const_out_batch_control_ok,
		FILE_NAME = FILENAME,
		TARGET_ROWS = v_num_rows,
		END_DATE = CURRENT_TIMESTAMP
	WHERE  ID_PROCESO = v_idproceso;
      
	      
	--FIN
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');
END