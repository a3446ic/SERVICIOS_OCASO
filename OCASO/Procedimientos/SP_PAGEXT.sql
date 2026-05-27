CREATE or replace PROCEDURE EXT.SP_PAGEXT(
	OUT FILENAME VARCHAR(120),
    IN i_pPlRunSeq VARCHAR(50))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS 
/*---------------------------------------------------------------------
	| Author: Victor Garcia Bascunyana
	| Company: Inycom
	| Initial Version Date: 07-April-2025
	|----------------------------------------------------------------------
	| Procedure Purpose: Paquete PL/SQl que nos permite obtener en la tabla OUT_EXTRACTPAGOS_INFORME_FILE
    | el contenido del fichero de pago.
    | Con par?metros de entrada, la fecha de liquidacion, v_PeriodStartDate'YYYYMMDD'
    | y la fecha a la que se calcula el pago, fechapago 'YYYYMMDD_HHMM' 
	|
	| Version: 0.1	VGB 20250407		Initial Version.
    | Version: 0.2	DTB 20250827		Cambio en el orden de los campos de FINAL_EXTRACTPAGOS_ONLINE_FILE al hacer el insert.
	| Version: 0.3	DTB 20251009		Cambio en el FILENAME dependiendo de primera ejecucion o no.
	-----------------------------------------------------------------------
*/

	BEGIN
	
	DECLARE v_proc_name VARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR(10) := '0.3';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso INTEGER;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE = EXT.LIB_CONSTANTES:v_eot; 
	DECLARE v_PeriodSeq BIGINT;
	DECLARE v_PeriodName VARCHAR(255);
	DECLARE v_fechaserver TIMESTAMP;
	DECLARE v_PeriodStartDate TIMESTAMP;
	DECLARE v_PeriodEndDate TIMESTAMP;
	DECLARE v_fechapago VARCHAR(6);
	-- DECLARE v_PeriodStartDate VARCHAR(6);
	DECLARE v_filas NUMBER; --Para el DEBUG de los INSERT
    DECLARE v_fecha_ultimo_pagext DATE;
    DECLARE v_fecha_start_periodo DATE;
    DECLARE v_ejecucion_inicial_pagext NUMBER;
    --ALM 20191002: Nuevas variables para las Liquidaciones Complementarias
    DECLARE v_conteo_pagos_lc NUMBER;
    DECLARE v_seq_ultimo_pago_lc NUMBER;
    DECLARE v_fecha_ultimo_pago_lc DATE;
    DECLARE v_pagos_a_tratar VARCHAR(3);
    DECLARE v_fechaserver_lc DATE;
	DECLARE v_fechalocal TIMESTAMP;
	
	DECLARE v_const_calculo_status_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
    DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_LOAD;
    DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_OK;
    DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES :CONST_OUT_BATCH_CONTROL_ERROR;	
    
    DECLARE TEMP_EXTRACTPAGOS_FILE TABLE(
		"SERCO_CANARIAS" CHAR(1),
		"ENVIO_SII" CHAR(1),
		"IRPF" DECIMAL(12, 5),
		"IBAN" CHAR(24),
		"DC_IMPORTE32" DECIMAL(12, 5),
		"COD_DATO32" CHAR(2),
		"DC_IMPORTE31" DECIMAL(12, 5),
		"COD_DATO31" CHAR(2),
		"DC_IMPORTE30" DECIMAL(12, 5),
		"COD_DATO30" CHAR(2),
		"DC_IMPORTE17" DECIMAL(12, 5),
		"COD_DATO17" CHAR(2),
		"DC_IMPORTE16" DECIMAL(12, 5),
		"COD_DATO16" CHAR(2),
		"DC_IMPORTE13" DECIMAL(12, 5),
		"COD_DATO13" CHAR(2),
		"DC_IMPORTE11" DECIMAL(12, 5),
		"COD_DATO11" CHAR(2),
		"DC_IMPORTE10" DECIMAL(12, 5),
		"COD_DATO10" CHAR(2),
		"DC_IMPORTE9" DECIMAL(12, 5),
		"COD_DATO9" CHAR(2),
		"DC_IMPORTE5" DECIMAL(12, 5),
		"COD_DATO5" CHAR(2),
		"DC_IMPORTE4" DECIMAL(12, 5),
		"COD_DATO4" CHAR(2),
		"DC_IMPORTE3" DECIMAL(12, 5),
		"COD_DATO3" CHAR(2),
		"DC_IMPORTE2" DECIMAL(12, 5),
		"COD_DATO2" CHAR(2),
		"DC_IMPORTE1" DECIMAL(12, 5),
		"COD_DATO1" CHAR(2),
		"DC_PE_COD_POSTAL" CHAR(5) ,
		"DC_PE_POBLACION" CHAR(7) ,
		"DC_PE_PROVINCIA" CHAR(2) ,
		"DC_PE_DOMICILIO" CHAR(35) ,
		"DC_PE_NOMBRE" CHAR(30) ,
		"AGENTE_RETA" CHAR(1) ,
		"ACCION" CHAR(1) ,
		"PAG_MONEDA" CHAR(5) ,
		"PAG_IMPORTE" CHAR(14) ,
		"PAG_CARGO_O_ABONO" CHAR(1) ,
		"PAG_BANCO_DESTINO" CHAR(20) ,
		"PAG_TEXTO_PAGO" CHAR(30) ,
		"PAG_FECHA_LIQUIDACION" CHAR(8) ,
		"PAG_FECHA_FACTURA" CHAR(8) ,
		"PAG_REFERENCIA_ORIGEN" CHAR(16) ,
		"FPG_CODIGO" CHAR(1) ,
		"CONCEP_CODIGO" CHAR(4) ,
		"TIPPER_CODIGO" CHAR(4) ,
		"PAG_AGENTE" CHAR(6) ,
		"DC_CODPER" CHAR(12) ,
		"PER_CIF_NIF" CHAR(10) ,
		"PAG_OFICINA" CHAR(4) ,
		"CIA_CODIGO" CHAR(2) ,
		"ORIGEN_CODIGO" CHAR(4) ,
		"PAG_CLASIF_AGENTE" CHAR(2) ,
		"PAG_COD_UNICO" CHAR(14) ,
		"AUTOLIQUIDA" BIGINT 
	);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
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
    
	SELECT UTCTOLOCAL (current_utctimestamp, 'CET') INTO v_fechalocal FROM DUMMY;			

--Inicializamos el idProceso
	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq, v_log_count, v_idproceso, 'info');
	--REGISTRO OUT_BATCH_CONTROL
	INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
	VALUES (v_idproceso,FILENAME,::CURRENT_OBJECT_NAME,0,EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD,CURRENT_TIMESTAMP,NULL);
	COMMIT;
	
--------------- Funcion que nos permite obtener el PERIODSEQ a partir de una fecha dada --------------
	SELECT PERIODSEQ, NAME, STARTDATE, ENDDATE, TO_CHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName, v_PeriodStartDate,v_PeriodEndDate, v_fechapago FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_pPlRunSeq: ' || i_pPlRunSeq ||', v_PeriodSeq: '||v_PeriodSeq||', v_PeriodName: '||v_PeriodName||', v_PeriodStartDate: '||v_PeriodStartDate||', v_PeriodEndDate: '||v_PeriodEndDate||', v_fechapago: '||v_fechapago, v_log_count, v_idproceso, 'info');
	
    --FICHERO DE SALIDA  
    --EJ PAGEXT: INYC_PAGEXT_PRD_20250225_183700_OCASO_OTFTP166402_21jxv.txt
    --SELECT 'PAGEXT_PRD_'||TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_OFTP166402.txt' INTO FILENAME from dummy;
      	
	
    
	
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');

        --RMF 20190125: UPDATE del parametro PAGEXT_STATUS en CONF_PARAMETROS_FILE a 1
        --ALM 20190617: No usamos este par�tro para la prueba de SAP

        UPDATE EXT.CONF_PARAMETROS_FILE
            SET VALOR = 1
        WHERE NOMBRE = 'PAGEXT_STATUS';

        COMMIT;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Actualizacion parametro PAGEXT_STATUS = 1 ', v_log_count, v_idproceso, 'info');  	



    --     --Extraemos los parametros (fechas y flag de primera ejecucion) de la tabla de PARAMETROS
        SELECT F_FIN INTO v_fecha_ultimo_pagext FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'FECHA_ULT_EJEC_PAGEXT';
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fecha ultima ejecucion PAGEXT: ' || TO_CHAR(v_fecha_ultimo_pagext,'YYYYMMDD_HH24MI') || '.', v_log_count, v_idproceso, 'info');  	

		SELECT F_INICIO INTO v_fecha_start_periodo FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'FECHA_ULT_EJEC_PAGEXT';
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Inicio periodo ejecucion ultimo PAGEXT = ' || TO_CHAR(v_fecha_start_periodo,'YYYYMMDD_HH24MI') || '.', v_log_count, v_idproceso, 'info');  	

		SELECT VALOR INTO v_ejecucion_inicial_pagext FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'FECHA_ULT_EJEC_PAGEXT';


    --     --Comprobamos si es la primera ejecucion del periodo en cuestion, si lo es actualizamos los parametros necesarios.
        IF (v_fecha_start_periodo < v_PeriodStartDate) THEN
            v_ejecucion_inicial_pagext := 0;

            --ALM 20190911: Actualizamos la fecha de inicio del parametro PAGEXT_STATUS si es la primera vez que se ejecuta este periodo.
            UPDATE EXT.CONF_PARAMETROS_FILE
                SET F_INICIO = (
                    SELECT MAX(PL.STARTTIME)
                    FROM TCMP.CS_PLRUN PL
                    WHERE PL.RUNPARAMETERS LIKE '%[Sequence]CompensateAndPay%'
                        AND PL.COMMAND = 'PipelineRun'
                        AND PL.STATUS = 'Successful'
                        AND PL.PERIODSEQ = v_periodSeq
                        AND PL.STARTTIME < (
                            --Usamos la fecha del ultimo Post ejecutado anterior al Finalize del periodo, si se ha realizado sino cogemos la fecha del ultimo Post ejecutado anterior a la fecha actual.
                            SELECT MAX(X.STARTTIME) FROM TCMP.CS_PLRUN X
                            WHERE X.RUNPARAMETERS LIKE '%[Sequence]Post%'
                                AND X.COMMAND = 'PipelineRun'
                                AND X.STATUS = 'Successful'
                                AND X.PERIODSEQ = v_periodSeq
                                AND X.STARTTIME < (
                                    --Usamos la fecha del Finalize del periodo, si aun no se ha realizado (lo normal cuando se lance el REPEXT) se coge la fecha actual.
                                    --Nos vale por si hay que repetir un REPEXT pasado el Posteo de los balances, ya que estos no se deben de tener en cuenta.
                                    SELECT IFNULL(MIN(Y.STARTTIME),CURRENT_TIMESTAMP) FROM TCMP.CS_PLRUN Y
                                    WHERE Y.RUNPARAMETERS LIKE '%[Sequence]Finalize%'
                                        AND Y.COMMAND = 'PipelineRun'
                                        AND Y.STATUS = 'Successful'
                                        AND Y.PERIODSEQ = v_periodSeq
                                )
                        )
                  )
            WHERE NOMBRE = 'PAGEXT_STATUS';

            -- COMMIT;
        END IF;


        --DTB 20251009 Nombre de fichero depende de si es la ejec inicial
        IF (v_ejecucion_inicial_pagext = 0) THEN
            --BRG 20250813 Nuevos nombres de ficheros por petición de MAA
	        --SELECT 'PAGEXT1900_'||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIMESTAMP, 7200), 'HH24MISS')||'.txt' INTO FILENAME FROM DUMMY;
			-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA		
			SELECT 'PAGEXT1900_'||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME FROM DUMMY;
        ELSE
            --SELECT 'PAGEXT1664_'||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIMESTAMP, 7200), 'HH24MISS')||'.txt' INTO FILENAME FROM DUMMY;
			-- LFC 20251207: Cambio a fecha y hora locales por petición de MAA
			SELECT 'PAGEXT1664_'||TO_VARCHAR(v_fechalocal, 'YYYYMMDD')||'_'||TO_VARCHAR(v_fechalocal, 'HH24MISS')||'.txt' INTO FILENAME FROM DUMMY;
        END IF;
	    
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA: ' || FILENAME, v_log_count, v_idproceso, 'info');		
        
    --     --ALM 20191002: Cambiamos de lugar el comentario por si actualiza el valor la LC
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Ejecucion inicial PAGEXT (0=>SI,1=>NO): ' || TO_CHAR(v_ejecucion_inicial_pagext) || '.', v_log_count, v_idproceso, 'info');  
        --ALM 20190911: Cogemos la fecha en la que se ejecuto el primer cierre del periodo actual que la tenemos guardada en el parametro PAGEXT_STATUS.
        --              Una vez tenemos esta fecha controlada la utilizamos para todo el proceso de calculo.
        SELECT F_INICIO INTO v_fechaserver FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'PAGEXT_STATUS';
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fecha del cierre del periodo actual (fechaserver): ' || TO_CHAR(v_fechaserver,'YYYYMMDD_HH24MI'), v_log_count, v_idproceso, 'info');  



        ---------------  LIQUIDACION COMPLEMENTARIA --------------
        --ALM 20191002: Extraemos los parametros para la LC
        --ALM 20210111: Modificacmos la fecha para ponerle la hora de aqui
        SELECT COUNT(DISTINCT POSTPIPELINERUNSEQ),IFNULL(MAX(POSTPIPELINERUNSEQ),0),--MAX(POSTPIPELINERUNDATE)
            IFNULL(MAX(POSTPIPELINERUNDATE),'0')
        INTO v_conteo_pagos_lc, v_seq_ultimo_pago_lc, v_fecha_ultimo_pago_lc
        FROM TCMP.CS_PAYMENT
        WHERE PERIODSEQ = v_periodSeq
        --ALM 20191228: Quitamos el primer pipelinerunseq 20547673299901402 de Diciembre 2019 para que no se tenga en cuenta ya que se ha cancelado
        --ALM 20230228: Anadimos el primer pipelinerunseq 20547673299924040 de Febrero 2023 para que no se tenga en cuenta ya que se ha cancelado
    	AND POSTPIPELINERUNSEQ NOT IN (20547673299901402,20547673299924040);

		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Numero de pagos ejecutado en el mes: ' || TO_CHAR(v_conteo_pagos_lc) || ' - mas de 1 es que se ha ejecutado LC.', v_log_count, v_idproceso, 'info');
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fecha del ultimo pago ejecutado: ' || TO_CHAR(v_fecha_ultimo_pago_lc,'YYYYMMDD_HH24MI') || '. Postpipelinerunseq= ' || TO_CHAR(v_seq_ultimo_pago_lc) || '.', v_log_count, v_idproceso, 'info');
		


        --ALM 20190102: Inicializzamos el parametro v_pagos_a_tratar a ALL para que por defecto coja todos los pagos del periodo en la ejecucion del proceso.
        v_pagos_a_tratar := 'ALL';

        --ALM 20191002: Comprobamos si ha habido LC y si es la primera vez que se ejecuta el PAGEXT despues de ella. Si es asi se actualizan los parametros necesarios.
        IF (v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext AND v_ejecucion_inicial_pagext = 1) THEN

            v_ejecucion_inicial_pagext := 0;

            --ALM 20191008: No usamos este parametro para la prueba de SAP
            UPDATE EXT.CONF_PARAMETROS_FILE
                --ALM 20220519: Usamos la fecha del ultimo calculo antes del Post de la LC.
                --SET F_FIN = TO_DATE(TO_CHAR(FROM_TZ(CAST(sysdate AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                SET F_FIN = (
                    SELECT MAX(PL.STARTTIME)
                    FROM TCMP.CS_PLRUN PL
                    WHERE PL.RUNPARAMETERS LIKE '%[Sequence]CompensateAndPay%'
                        AND PL.COMMAND = 'PipelineRun'
                        AND PL.STATUS = 'Successful'
                        AND PL.PERIODSEQ = v_PeriodSeq
                        AND PL.STARTTIME < (
                            --Usamos la fecha del ultimo Post ejecutado anterior al Finalize del periodo, si se ha realizado sino cogemos la fecha del ultimo Post ejecutado anterior a la fecha actual.
                            SELECT MAX(X.STARTTIME) FROM TCMP.CS_PLRUN X
                            WHERE X.RUNPARAMETERS LIKE '%[Sequence]Post%'
                                AND X.COMMAND = 'PipelineRun'
                                AND X.STATUS = 'Successful'
                                AND X.PERIODSEQ = v_PeriodSeq
                                AND X.STARTTIME < (
                                    --Usamos la fecha del Finalize del periodo, si aun no se ha realizado (lo normal cuando se lance el REPEXT) se coge la fecha actual.
                                    --Nos vale por si hay que repetir un REPEXT pasado el Posteo de los balances, ya que estos no se deben de tener en cuenta.
                                    SELECT IFNULL(MIN(Y.STARTTIME),CURRENT_TIMESTAMP) FROM TCMP.CS_PLRUN Y
                                    WHERE Y.RUNPARAMETERS LIKE '%[Sequence]Finalize%'
                                        AND Y.COMMAND = 'PipelineRun'
                                        AND Y.STATUS = 'Successful'
                                        AND Y.PERIODSEQ = v_PeriodSeq
                                )
                        )
                  )
            WHERE NOMBRE = 'PAGEXT_STATUS';

            v_pagos_a_tratar := 'MAX';

        END IF;

        --ALM 20191002: Cogemos la fecha en la que se ha ejecutado la primera LC del periodo actual que la tenemos guardada en el parametro PAGEXT_STATUS.
        --              Una vez tenemos esta fecha controlada la utilizamos para el proceso de calculo.
        SELECT F_FIN INTO v_fechaserver_lc FROM EXT.CONF_PARAMETROS_FILE WHERE NOMBRE = 'PAGEXT_STATUS';

		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fecha del cierre del periodo actual (v_fechaserver_lc): ' || IFNULL(TO_CHAR(v_fechaserver_lc,'YYYYMMDD_HH24MI'),'SIN DATOS'), v_log_count, v_idproceso, 'info');


		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Ejecucion inicial PAGEXT (0=>SI,1=>NO): ' || TO_CHAR(v_ejecucion_inicial_pagext) || '.', v_log_count, v_idproceso, 'info');


        --------------- Creacion de TEMP_TABLA_IRPF_REP --------------
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de IRPF.', v_log_count, v_idproceso, 'info');

        --ALM 20191002: Sequimos usando la fechaserver del PAGEXT inicial sin tener en cuenta la de la LC si la hay, ya que esta clasificacion no deberia de modificarse casi nunca!!!!!
        --ALM 20200110: Utilizamos la fecha de fin de periodo ya que es la situacion a final del periodo la que tenemos que tener en cuenta.
        TEMP_TABLA_IRPF_REP =
							SELECT 
							    C.CLASSIFIERID AS CLASSIFIERID, 
							    LEFT(C.NAME, 1) AS NAME, 
							    GC.GENERICNUMBER1 AS GENERICNUMBER1
							FROM TCMP.CS_CLASSIFIER C
							JOIN TCMP.CS_GENERICCLASSIFIERTYPE GCT 
							    ON C.SELECTORID = GCT.GENERICCLASSIFIERTYPESEQ
							JOIN TCMP.CS_GENERICCLASSIFIER GC 
							    ON GC.CLASSIFIERSEQ = C.CLASSIFIERSEQ
							LEFT JOIN TCMP.CS_CATEGORY_CLASSIFIERS CC 
							    ON CC.CLASSIFIERSEQ = C.CLASSIFIERSEQ
							    AND CC.REMOVEDATE = v_eot
							    AND CC.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
							    AND CC.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
							LEFT JOIN TCMP.CS_CATEGORYTREE CT 
							    ON CT.CATEGORYTREESEQ = CC.CATEGORYTREESEQ
							    AND CT.REMOVEDATE = v_eot
							    AND CT.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
							    AND CT.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
							LEFT JOIN TCMP.CS_CATEGORY CAT 
							    ON CAT.RULEELEMENTSEQ = CC.CATEGORYSEQ
							    AND CAT.REMOVEDATE = v_eot
							    AND CAT.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
							    AND CAT.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
							WHERE 
							    C.REMOVEDATE = v_eot
							    AND C.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
							    AND C.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
							    AND GC.REMOVEDATE = v_eot
							    AND GC.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
							    AND GC.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
							    AND CT.NAME = 'Tipo IRPF'
							    AND GCT.NAME = 'Tipo IRPF'
							    AND GCT.TENANTID = v_idtenant
							    AND C.TENANTID = v_idtenant
							    AND GC.TENANTID = v_idtenant
							    AND CC.TENANTID = v_idtenant
							    AND CT.TENANTID = v_idtenant
							    AND CAT.TENANTID = v_idtenant;


   v_num_rows = RECORD_COUNT(:TEMP_TABLA_IRPF_REP);
   
          --COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de IRPF: '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info');          


        --------------- Creacion de TEMP_EXTRACTPAGOS_FILE --------------
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de TEMP_EXTRACTPAGOS_FILE.', v_log_count, v_idproceso, 'info');          


        INSERT INTO :TEMP_EXTRACTPAGOS_FILE(ORIGEN_CODIGO,CIA_CODIGO,PAG_OFICINA,PER_CIF_NIF,DC_CODPER,PAG_AGENTE,TIPPER_CODIGO,CONCEP_CODIGO,FPG_CODIGO,PAG_REFERENCIA_ORIGEN,PAG_FECHA_FACTURA
       		,PAG_FECHA_LIQUIDACION,PAG_TEXTO_PAGO,PAG_BANCO_DESTINO,PAG_CARGO_O_ABONO,PAG_IMPORTE,PAG_MONEDA,ACCION,AGENTE_RETA,DC_PE_NOMBRE,DC_PE_DOMICILIO,DC_PE_PROVINCIA,DC_PE_POBLACION,DC_PE_COD_POSTAL,COD_DATO1,DC_IMPORTE1
			,COD_DATO2,DC_IMPORTE2,COD_DATO3,DC_IMPORTE3,COD_DATO4,DC_IMPORTE4,COD_DATO5,DC_IMPORTE5,COD_DATO9,DC_IMPORTE9,COD_DATO10,DC_IMPORTE10,COD_DATO11,DC_IMPORTE11,COD_DATO13,DC_IMPORTE13
			,COD_DATO16,DC_IMPORTE16,COD_DATO17,DC_IMPORTE17,COD_DATO30,DC_IMPORTE30,COD_DATO31,DC_IMPORTE31,COD_DATO32,DC_IMPORTE32,IBAN,IRPF,ENVIO_SII,SERCO_CANARIAS,AUTOLIQUIDA,PAG_COD_UNICO,PAG_CLASIF_AGENTE
        )
			
		SELECT	    'COMI' AS ORIGEN_CODIGO,
			    SUBSTRING(PAY.EARNINGGROUPID, 7, 2) AS CIA_CODIGO,
			    LPAD(IFNULL(SUBSTRING(POS.GENERICATTRIBUTE3, 1, 4), '0'), 4, '0') AS PAG_OFICINA,
			    RPAD(PAR.GENERICATTRIBUTE1, 10, ' ') AS PER_CIF_NIF,
			    RPAD(PAYEE.PAYEEID, 12, ' ') AS DC_CODPER,
			    LPAD(IFNULL(SUBSTRING(POS.GENERICATTRIBUTE3, 5, 6), '0'), 6, '0') AS PAG_AGENTE,
			    CASE SUBSTRING(PAY.EARNINGGROUPID, 4, 2)
			        WHEN 'S4' THEN 'AGEN'
			        ELSE 'INSP'
			    END AS TIPPER_CODIGO,
			   CASE SUBSTRING(PAY.EARNINGGROUPID, 4, 2)
			        WHEN 'S4' THEN 'S-4'
			        ELSE 'S-5'
			    END AS CONCEP_CODIGO,
			
			    CASE
			        WHEN SUBSTRING(PAY.EARNINGGROUPID, 7, 2) = '01' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16, ' ', '')) = 24 THEN
			            CASE
			                WHEN PAR.SALARY IN (1, 2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
							) = 1
			            THEN '3'
			            ELSE '2'
			            END
			        WHEN SUBSTRING(PAY.EARNINGGROUPID, 7, 2) = '03' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16, ' ', '')) = 24 THEN
			            CASE
			                WHEN PAR.SALARY IN (3, 2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
							) = 1
			            THEN '3'
			            ELSE '2'
			            END
			        ELSE '2'
			    END AS FPG_CODIGO,
			
			    RPAD(
			        SUBSTRING(PAY.EARNINGGROUPID, 8, 1) ||
			        CASE
			            WHEN :v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN
			                CASE
			                    WHEN SUBSTRING(PAY.EARNINGGROUPID, 5, 1) = '4' THEN '7'
			                    WHEN SUBSTRING(PAY.EARNINGGROUPID, 5, 1) = '5' THEN '8'
			                    ELSE SUBSTRING(PAY.EARNINGGROUPID, 5, 1)
			                END
			            ELSE SUBSTRING(PAY.EARNINGGROUPID, 5, 1)
			        END ||
			        SUBSTRING(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'), 1, 6) ||
			        LPAD(IFNULL(SUBSTRING(POS.GENERICATTRIBUTE3, 2, 3), '0'), 3, '0') ||
			        LPAD(IFNULL(SUBSTRING(POS.GENERICATTRIBUTE3, 7, 4), '0'), 4, '0'),
			        16, ' '
			    ) AS PAG_REFERENCIA_ORIGEN,
			
			    TO_VARCHAR(
			        CASE
			            WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN
			                CASE
			                    WHEN MONTH(v_fechaserver_lc) <> MONTH(TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')) AND v_fechaserver_lc > TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')
			                        THEN v_PeriodStartDate
			                    ELSE v_fechaserver_lc
			                END
			            ELSE
			                CASE
			                    WHEN MONTH(v_fechaserver) <> MONTH(TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')) AND v_fechaserver > TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')
			                        THEN v_PeriodStartDate
			                    ELSE v_fechaserver
			                END
			        END, 'YYYYMMDD'
			    )  AS PAG_FECHA_FACTURA,
			
			    TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD') AS PAG_FECHA_LIQUIDACION,
			
			    'LIQ.AGENTE:' || LPAD(IFNULL(SUBSTRING(POS.GENERICATTRIBUTE3, 5, 6), '0'), 6, '0') || ' FECHA:' || SUBSTRING(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'), 1, 6) AS PAG_TEXTO_PAGO,
			
			    RPAD(' ', 20, ' ') AS PAG_BANCO_DESTINO,
			    'X' AS PAG_CARGO_O_ABONO,
			    'X' AS PAG_IMPORTE,
			    'EUR' AS PAG_MONEDA,
			    'A' AS ACCION,
			
			    CASE WHEN PAR.GENERICBOOLEAN4 = 1 THEN 'R' ELSE ' ' END AS AGENTE_RETA,
			
			    CASE WHEN PAR.FIRSTNAME IS NULL THEN RPAD(' ', 30)
			         ELSE RPAD(PAR.FIRSTNAME, 30, ' ')
			    END AS DC_PE_NOMBRE,
			
		--	    RPAD(SUBSTR(PAR.GENERICATTRIBUTE9,1,32)|| ' ' || PAR.GENERICATTRIBUTE10, 35) AS DC_PE_DOMICILIO,
				CASE WHEN LENGTH(PAR.GENERICATTRIBUTE9 || ' ' || PAR.GENERICATTRIBUTE10) > 35 THEN 	SUBSTR(PAR.GENERICATTRIBUTE9 ||' '|| PAR.GENERICATTRIBUTE10 ,1,25)
			    ELSE RPAD(PAR.GENERICATTRIBUTE9|| ' ' || PAR.GENERICATTRIBUTE10, 35) END AS DC_PE_DOMICILIO,
			
			    LPAD(
			        IFNULL(LEFT(TO_VARCHAR(PAR.GENERICNUMBER2), 2), '0'),
			        2, '0'
			    ) AS DC_PE_PROVINCIA,
			
			    LPAD(
			        IFNULL(LEFT(TO_VARCHAR(PAR.GENERICNUMBER3), 7), '0'),
			        7, '0'
			    ) AS DC_PE_POBLACION,
			
			    LPAD(
			        IFNULL(LEFT(TO_VARCHAR(PAR.GENERICNUMBER1), 5), ' '),
			        5, '0'
			    ) AS DC_PE_COD_POSTAL,
			
			'01' AS COD_DATO1,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '01' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE1,
			
			'02' AS COD_DATO2,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '02' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE2,
			
			'03' AS COD_DATO3,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '03' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE3,
			
			'04' AS COD_DATO4,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '04' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE4,
			
			'05' AS COD_DATO5,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '05' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE5,
			
			'09' AS COD_DATO9,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '09' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE9,
			
			'10' AS COD_DATO10,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '10' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE10,
			
			'11' AS COD_DATO11,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '11' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE11,
			
			'13' AS COD_DATO13,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '13' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE13,
			
			'16' AS COD_DATO16,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '16' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE16,
			
			'17' AS COD_DATO17,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '17' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE17,
			
			'30' AS COD_DATO30,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '30' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE30,
			
			'31' AS COD_DATO31,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '31' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE31,
			
			'32' AS COD_DATO32,
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN CASE WHEN SUBSTRING(PAY.EARNINGGROUPID, 1, 2) = '32' THEN PAY.VALUE ELSE 0 END
			    ELSE 0
			END AS DC_IMPORTE32,
			
			-- IBAN validado
			CASE
			    WHEN SUBSTRING(PAY.EARNINGGROUPID, 7, 2) = '01' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16, ' ', '')) = 24 THEN
			        CASE
			            WHEN PAR.SALARY IN (1,2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
							) = 1
			            THEN REPLACE(PAR.GENERICATTRIBUTE16, ' ', '')
			            ELSE RPAD(' ', 24)
			        END
			    WHEN SUBSTRING(PAY.EARNINGGROUPID, 7, 2) = '03' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16, ' ', '')) = 24 THEN
			        CASE
			            WHEN PAR.SALARY IN (3,2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
						) = 1
			            THEN REPLACE(PAR.GENERICATTRIBUTE16, ' ', '')
			            ELSE RPAD(' ', 24)
			        END
			    ELSE RPAD(' ', 24)
			END AS IBAN,
			
			-- IRPF
			CASE
			    WHEN PAR.GENERICATTRIBUTE3 = 'F' THEN
			        CASE
			            WHEN PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4 <> 0
			                AND PAR.GENERICATTRIBUTE5 = SUBSTRING(PAY.EARNINGGROUPID, 7, 2)
			            THEN IFNULL(PAR.GENERICNUMBER5, 0)
			            ELSE IRPF.GENERICNUMBER1
			        END
			    --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                    -- Juridicas que comiencen por estas letras, aplica el tipo de IRPF
                    --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and SUBSTR(PAR.GENERICATTRIBUTE1,1,1) in ('G','J','E','U','V') THEN IRPF.GENERICNUMBER1
                    --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                    -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                    --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and SUBSTR(PAR.GENERICATTRIBUTE1,1,1) in ('G','J','E','V') THEN IRPF.GENERICNUMBER1
                    --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
                    --WHEN (PAR.GENERICATTRIBUTE3 = 'J') AND SUBSTR(PAR.GENERICATTRIBUTE1,1,1) in ('G','J','E','V') AND PAR.GENERICATTRIBUTE1 <> 'J72106826'
                WHEN (PAR.GENERICATTRIBUTE3 = 'J') 
                	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
	            	--AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
	            	AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V') 
                	AND PAR.GENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
                    THEN IRPF.GENERICNUMBER1 -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                ELSE 0
			END AS IRPF,
			
			-- ENVIO_SII
			CASE WHEN PAR.GENERICBOOLEAN3 = 0 THEN 'N' ELSE 'S' END AS ENVIO_SII,
			
			-- SERCO_CANARIAS (subquery escalar)
			CASE WHEN (SELECT MAX(J.COD_REGIONAL) FROM EXT.OUT_JERARQUIA_REP J
                           WHERE J.PERIODSEQ = PAY.PERIODSEQ AND J.PARTICIPANTSEQ = PAY.PAYEESEQ
                             --ALM 20200507: Incluimos la regional de Canarias de Eterna
                             --AND J.POSITIONSEQ = PAY.POSITIONSEQ) = '0557'
                             AND J.POSITIONSEQ = PAY.POSITIONSEQ) IN ('0557','0661')
                    THEN 'C'
                END,        
			
			-- AUTOLIQUIDA
			CASE
			    WHEN (
			        (PAR.GENERICBOOLEAN1 = 0 OR PAR.GENERICBOOLEAN1 IS NULL)
			        OR RIGHT(PAY.EARNINGGROUPID,4) <> '-AUT'
			        OR (RIGHT(PAY.EARNINGGROUPID,4) = '-AUT' AND PAY.VALUE < 0)
			        OR SUBSTRING(PAY.EARNINGGROUPID, 1, 2) <> '01'
			        OR (SUBSTRING(PAY.EARNINGGROUPID, 7, 2) LIKE '03' AND PAR.USERID <> 'A82473349')
			    )
			    THEN 0
			    ELSE 1
			END AS AUTOLIQUIDA,
			
			-- SAP: código único de posición
			RPAD(POS.NAME, 14, ' ') AS PAG_COD_UNICO,
			
			-- SAP: clasificación del agente
			CASE
			    WHEN PAR.GENERICBOOLEAN1 = 1 THEN
			        CASE WHEN PAR.GENERICNUMBER4 IS NULL THEN 'AA' ELSE 'EA' END
			    ELSE
			        CASE WHEN PAR.GENERICNUMBER4 IS NULL THEN '  ' ELSE 'EM' END
			END AS PAG_CLASIF_AGENTE
			
			FROM TCMP.CS_POSITION POS
			JOIN TCMP.CS_PARTICIPANT PAR
			  ON POS.PAYEESEQ = PAR.PAYEESEQ
			 AND PAR.TENANTID = v_idtenant
			
			JOIN TCMP.CS_PAYEE PAYEE
			  ON PAYEE.PAYEESEQ = PAR.PAYEESEQ
			 AND PAYEE.PAYEESEQ = POS.PAYEESEQ
			 AND PAYEE.TENANTID = v_idtenant
			
			JOIN TCMP.CS_PAYMENT PAY
			  ON PAR.PAYEESEQ = PAY.PAYEESEQ
			 AND POS.RULEELEMENTOWNERSEQ = PAY.POSITIONSEQ
			 AND PAY.TENANTID = v_idtenant
			 AND PAY.PROCESSINGUNITSEQ = 38280596832649217
			 AND PAY.PERIODSEQ = v_PeriodSeq
			
			JOIN :TEMP_TABLA_IRPF_REP IRPF
			  ON CASE
			       WHEN PAR.TAXID IS NULL OR PAR.TAXID NOT IN ('I','E','S','C')
			       THEN 'P'
			       ELSE PAR.TAXID
			     END = IRPF.NAME
			WHERE
			
				--20170202 ALM: Por peticion de Javier quitamos las oficinas 0931 y 0936
				--and
				LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3 ,1,4),'0'),4,'0') NOT IN ('0931','0936')
			
				AND (PAR.TERMINATIONDATE IS NULL or PAR.TERMINATIONDATE > ADD_DAYS(v_PeriodEndDate, -1))
			
				AND ((v_pagos_a_tratar = 'MAX' AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc)
					or (v_pagos_a_tratar = 'ALL' AND PAY.POSTPIPELINERUNSEQ IS NOT NULL))
			
				--TODOS menos si es S5 y empleado.
				--Todos participants sin ID_EMPLEADO
				AND ((PAR.GENERICNUMBER4 IS NULL OR PAR.GENERICNUMBER4=0)
					--AGENTES ('S4') con ID_EMPLEADO
					 OR (SUBSTR(PAY.EARNINGGROUPID,4,2)='S4' AND (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0))
					 --ALM 20170518: Por peticion de Javier anadimos los pagos de los empleados de S5 de Eterna
					 OR (SUBSTR(PAY.EARNINGGROUPID,4,2)='S5' AND SUBSTR(PAY.EARNINGGROUPID,7,2) LIKE '03'
						AND (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0)))
			
				--ALM 20170619: Quitamos a los agentes pedidos por Javier que apareceran en el NOMEXT
				AND PAR.GENERICATTRIBUTE1 NOT IN ('50115742F','52096024N')
				
			
				-- No mostramos las AGENCIAS
				AND (POS.GENERICNUMBER4<>2 OR POS.GENERICNUMBER4 is NULL)
			
				-- No mostramos pagos a posiciones con 6 nueves
				AND SUBSTR(POS.GENERICATTRIBUTE3,5,6) <>'999999'
			
				AND POS.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
				AND POS.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
				AND POS.CREATEDATE
					<= (CASE WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
				AND POS.REMOVEDATE
					> (CASE WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
			
				AND PAR.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
				AND PAR.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
				AND PAR.CREATEDATE
					<= (CASE WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
				AND PAR.REMOVEDATE
					> (CASE WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
			
				AND PAYEE.EFFECTIVESTARTDATE <= ADD_DAYS(v_PeriodEndDate, -1)
				AND PAYEE.EFFECTIVEENDDATE > ADD_DAYS(v_PeriodEndDate, -1)
				AND PAYEE.CREATEDATE
					<= (CASE WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
				AND PAYEE.REMOVEDATE
					> (CASE WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
				
				
					
		;

		 v_num_rows = RECORD_COUNT(:TEMP_EXTRACTPAGOS_FILE);
   
          --COMMIT;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de IRPF (TEMP_EXTRACTPAGOS_FILE): '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info');  


		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio Carga de la tabla de TEMP_CARTERA_DDEE_PAGEXT_FILE.', v_log_count, v_idproceso, 'info');   


		TEMP_CARTERA_DDEE_PAGEXT_FILE =
            SELECT X.POSITIONNAME,X.COMPENSATIONDATE,X.EARNINGGROUPID,X.SEQ_POST,SUM(IFNULL(X.IMPORTE,0)) AS IMPORTE
            FROM EXT.CARTERA_DDEE X
            WHERE X.COMPENSATIONDATE = v_PeriodStartDate
            --ALM 20220218: Incluimos el filtro por el nuevo campo ESTADO para quedarnos unicamente con los registros cobrados.
            AND X.ESTADO = 'C'
            GROUP BY X.POSITIONNAME,X.COMPENSATIONDATE,X.EARNINGGROUPID,X.SEQ_POST
        ;
    
	v_num_rows = RECORD_COUNT(:TEMP_CARTERA_DDEE_PAGEXT_FILE);

		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Carga de la tabla de IRPF (TEMP_CARTERA_DDEE_PAGEXT_FILE): '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 


   


        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla de TEMP_EXTRACTPAGOS_FILE. DDEE.', v_log_count, v_idproceso, 'info'); 
        	
        
        
        INSERT INTO :TEMP_EXTRACTPAGOS_FILE(ORIGEN_CODIGO,CIA_CODIGO,PAG_OFICINA,PER_CIF_NIF,DC_CODPER,PAG_AGENTE,TIPPER_CODIGO,CONCEP_CODIGO,FPG_CODIGO,PAG_REFERENCIA_ORIGEN,PAG_FECHA_FACTURA
       		,PAG_FECHA_LIQUIDACION,PAG_TEXTO_PAGO,PAG_BANCO_DESTINO,PAG_CARGO_O_ABONO,PAG_IMPORTE,PAG_MONEDA,ACCION,AGENTE_RETA,DC_PE_NOMBRE,DC_PE_DOMICILIO,DC_PE_PROVINCIA,DC_PE_POBLACION,DC_PE_COD_POSTAL,COD_DATO1,DC_IMPORTE1
			,COD_DATO2,DC_IMPORTE2,COD_DATO3,DC_IMPORTE3,COD_DATO4,DC_IMPORTE4,COD_DATO5,DC_IMPORTE5,COD_DATO9,DC_IMPORTE9,COD_DATO10,DC_IMPORTE10,COD_DATO11,DC_IMPORTE11,COD_DATO13,DC_IMPORTE13
			,COD_DATO16,DC_IMPORTE16,COD_DATO17,DC_IMPORTE17,COD_DATO30,DC_IMPORTE30,COD_DATO31,DC_IMPORTE31,COD_DATO32,DC_IMPORTE32,IBAN,IRPF,ENVIO_SII,SERCO_CANARIAS,AUTOLIQUIDA,PAG_COD_UNICO,PAG_CLASIF_AGENTE
        )
            SELECT 
                'COMI'                                                                                                      as ORIGEN_CODIGO,
                SUBSTR(CAR_LP.EARNINGGROUPID,7,2)                                                                              as CIA_CODIGO,
                LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3 ,1,4),'0'),4,'0')                                                     as PAG_OFICINA,
                RPAD(PAR.GENERICATTRIBUTE1,10,' ')                                                                          as PER_CIF_NIF,
                RPAD(PAYEE.PAYEEID,12,' ')                                                                                  as DC_CODPER,
                LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,5,6),'0'),6,'0')                                                      as PAG_AGENTE,
                CASE SUBSTR(CAR_LP.EARNINGGROUPID,4,2) WHEN 'S4'    THEN 'AGEN'   ELSE 'INSP' END                             as TIPPER_CODIGO,
                CASE SUBSTR(CAR_LP.EARNINGGROUPID,4,2) WHEN 'S4'    THEN 'S-4'    ELSE 'S-5'  END                             as CONCEP_CODIGO,
                  CASE WHEN SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16,' ','')) = 24
                    THEN CASE WHEN PAR.SALARY IN (1,2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
							) = 1                                                                           --si el resto de dividir por 97 lo anterior es 1 el IBAN es correcto sino no
                            THEN '3' ELSE '2' END
                WHEN SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16,' ','')) = 24
                    THEN CASE WHEN PAR.SALARY IN (3,2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
							) = 1                                                                           --si el resto de dividir por 97 lo anterior es 1 el IBAN es correcto sino no
                            THEN '3' ELSE '2' END
                ELSE '2' END                                                                                                as FPG_CODIGO,

                RPAD(   CONCAT(SUBSTR(CAR_LP.EARNINGGROUPID,8,1),
                        CONCAT(CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc
                                    THEN CASE WHEN SUBSTR(CAR_LP.EARNINGGROUPID,5,1) = '4' THEN '7' WHEN SUBSTR(CAR_LP.EARNINGGROUPID,5,1) = '5' THEN '8' END
                                    ELSE SUBSTR(CAR_LP.EARNINGGROUPID,5,1) END,
                        CONCAT(SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6),
                        CONCAT(LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,2,3),'0'),3,'0'),LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,7,4),'0'),4,'0'))))),16,' ')        as PAG_REFERENCIA_ORIGEN,

               (CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc
                    THEN (CASE WHEN EXTRACT(MONTH FROM v_fechaserver_lc) <> EXTRACT(MONTH FROM TO_VARCHAR(v_PeriodStartDate,'yyyymmdd')) AND v_fechaserver_lc > TO_VARCHAR(v_PeriodStartDate,'yyyymmdd')
                            THEN TO_VARCHAR(v_PeriodStartDate,'yyyymmdd')
                            ELSE TO_VARCHAR(v_fechaserver_lc,'yyyymmdd')
                        END)
                    ELSE (CASE WHEN EXTRACT(MONTH FROM v_fechaserver) <> EXTRACT(MONTH FROM TO_VARCHAR(v_PeriodStartDate,'yyyymmdd')) AND v_fechaserver > TO_VARCHAR(v_PeriodStartDate,'yyyymmdd')
                            THEN TO_VARCHAR(v_PeriodStartDate,'yyyymmdd')
                            ELSE TO_VARCHAR(v_fechaserver,'yyyymmdd')
                        END)
                END)                                                                                         as PAG_FECHA_FACTURA,

                TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD') AS PAG_FECHA_LIQUIDACION,

                'LIQ.AGENTE:'||LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,5,6),'0'),6,'0')||' FECHA:'||SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6)                                 as PAG_TEXTO_PAGO,

                RPAD(' ' ,20,' ')                                                                                           AS PAG_BANCO_DESTINO,

                'X'                                                                                                         AS PAG_CARGO_O_ABONO, -- a indicar a posteriori.
                'X'                                                                                                         AS PAG_IMPORTE,       -- ?'09'-'13'?
                'EUR'                                                                                                       AS PAG_MONEDA,
                'A'                                                                                                         AS ACCION,
                CASE WHEN (PAR.GENERICBOOLEAN4) = 1 THEN 'R' ELSE ' ' END                                                   AS AGENTE_RETA,
                CASE WHEN PAR.FIRSTNAME IS NULL THEN RPAD(' ',30) ELSE RPAD(PAR.FIRSTNAME,30,' ') END                       AS DC_PE_NOMBRE,
             --   RPAD((SUBSTR(PAR.GENERICATTRIBUTE9,1,32)||' '||PAR.GENERICATTRIBUTE10),35)                                               AS DC_PE_DOMICILIO,
				CASE WHEN LENGTH(PAR.GENERICATTRIBUTE9 || ' ' || PAR.GENERICATTRIBUTE10) > 35 THEN 	SUBSTR(PAR.GENERICATTRIBUTE9 ||' '|| PAR.GENERICATTRIBUTE10 ,1,25)
			    ELSE RPAD(PAR.GENERICATTRIBUTE9|| ' ' || PAR.GENERICATTRIBUTE10, 35) END AS DC_PE_DOMICILIO,
                

                CASE WHEN PAR.GENERICNUMBER2 IS NULL THEN LPAD('0',2,'0') ELSE LPAD(SUBSTR(TO_CHAR(PAR.GENERICNUMBER2),1,2),2,'0')  END         AS DC_PE_PROVINCIA,
                CASE WHEN PAR.GENERICNUMBER3 IS NULL THEN LPAD('0',7,'0') ELSE LPAD(SUBSTR(TO_CHAR(PAR.GENERICNUMBER3),1,7),7,'0')  END         AS DC_PE_POBLACION,
                CASE WHEN PAR.GENERICNUMBER1 IS NULL THEN LPAD(' ',5) ELSE LPAD(SUBSTR(TO_CHAR(PAR.GENERICNUMBER1),1,5),5,'0')  END             AS DC_PE_COD_POSTAL,

                '01'                                                                                                        AS COD_DATO1,
                CAR_LP.IMPORTE           AS DC_IMPORTE1,

                '02'                                                                                                        AS COD_DATO2,
                0           AS DC_IMPORTE2,

                '03'                                                                                                        AS COD_DATO3,
                0           AS DC_IMPORTE3,

                '04'                                                                                                        AS COD_DATO4,
                0           AS DC_IMPORTE4,

                '05'                                                                                                        AS COD_DATO5,
                0           AS DC_IMPORTE5,

                '09'                                                                                                        AS COD_DATO9,
                0           AS DC_IMPORTE9,

                '10'                                                                                                        AS COD_DATO10,
                0           AS DC_IMPORTE10,

                '11'                                                                                                        AS COD_DATO11,
                0           AS DC_IMPORTE11,

                '13'                                                                                                        AS COD_DATO13,
                0           AS DC_IMPORTE13,

                '16'                                                                                                        AS COD_DATO16,
                0           AS DC_IMPORTE16,

                '17'                                                                                                        AS COD_DATO17,
                0           AS DC_IMPORTE17,

                '30'                                                                                                        AS COD_DATO30,
                0           AS DC_IMPORTE30,

                '31'                                                                                                        AS COD_DATO31,
                0           AS DC_IMPORTE31,

                '32'                                                                                                        AS COD_DATO32,
                0           AS DC_IMPORTE32,

                CASE WHEN SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16,' ','')) = 24
                    THEN CASE WHEN PAR.SALARY IN (1,2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
							) = 1                                                                           --si el resto de dividir por 97 lo anterior es 1 el IBAN es correcto sino no
                            THEN REPLACE(PAR.GENERICATTRIBUTE16,' ','') ELSE RPAD(' ',24) END
                WHEN SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03' AND LENGTH(REPLACE(PAR.GENERICATTRIBUTE16,' ','')) = 24
                    THEN CASE WHEN PAR.SALARY IN (3,2) AND TO_NUMBER(
			                	MOD(
									((TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ',''),5)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 1, 1)) - 55)) * 100 +
									(ASCII(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 2, 1)) - 55)) * 100 +
									TO_NUMBER(SUBSTRING(REPLACE(PAR.GENERICATTRIBUTE16, ' ', ''), 3, 2))
								,97)
							) = 1                                                                           --si el resto de dividir por 97 lo anterior es 1 el IBAN es correcto sino no
                            THEN REPLACE(PAR.GENERICATTRIBUTE16,' ','') ELSE RPAD(' ',24) END
                ELSE RPAD(' ',24) END                                                                                       AS IBAN,

                CASE WHEN (PAR.GENERICATTRIBUTE3 = 'F')
                    THEN
                    CASE  WHEN (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0) AND PAR.GENERICATTRIBUTE5=SUBSTR(CAR_LP.EARNINGGROUPID,7,2) --(SUBSTR(CAR_LP.EARNINGGROUPID,4,2)='S4' AND
                            THEN IFNULL(PAR.GENERICNUMBER5,0)
                            ELSE IRPF.GENERICNUMBER1
                    END
                     --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
                    --WHEN (PAR.GENERICATTRIBUTE3 = 'J') AND SUBSTR(PAR.GENERICATTRIBUTE1,1,1) in ('G','J','E','V') AND PAR.GENERICATTRIBUTE1 <> 'J72106826'
                    WHEN (PAR.GENERICATTRIBUTE3 = 'J') 
                    	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		            	--AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
		            	AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')  
                    	AND PAR.GENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
                       THEN IRPF.GENERICNUMBER1 -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                    ELSE 0
                END                                                                                                         AS IRPF,

                CASE WHEN PAR.GENERICBOOLEAN3 = 0 THEN 'N' ELSE 'S' END                                                     AS ENVIO_SII,

                CASE WHEN (SELECT MAX(J.COD_REGIONAL) FROM EXT.OUT_JERARQUIA_REP J
                          --ALM 20211102: Utilizamos el PERIODSEQ para filtrar ya que es clave en esta tabla.
                          --WHERE J.STARTDATE = CAR_LP.COMPENSATIONDATE
                          WHERE J.PERIODSEQ = v_periodSeq
                          AND J.POS_CALLIDUS = CAR_LP.POSITIONNAME ) IN ('0557','0661')                 -- AIH MODIFICADO
                    THEN 'C'
                END                                                                                                         AS SERCO_CANARIAS,

                
                0      AS AUTOLIQUIDA,

                RPAD(POS.NAME,14,' ')                                                                                       AS PAG_COD_UNICO,
                CASE WHEN PAR.GENERICBOOLEAN1 = 1
                    THEN CASE WHEN PAR.GENERICNUMBER4 IS NULL THEN 'AA' ELSE 'EA' END
                    ELSE CASE WHEN PAR.GENERICNUMBER4 IS NULL THEN '  ' ELSE 'EM' END
                END                                                                                                         AS PAG_CLASIF_AGENTE

            FROM TCMP.CS_POSITION POS
            INNER JOIN TCMP.CS_PARTICIPANT PAR ON POS.PAYEESEQ = PAR.PAYEESEQ AND PAR.TENANTID = v_idtenant
            INNER JOIN TCMP.CS_PAYEE PAYEE ON PAYEE.PAYEESEQ = PAR.PAYEESEQ AND  PAYEE.PAYEESEQ = POS.PAYEESEQ AND PAYEE.TENANTID = v_idtenant
            INNER JOIN :TEMP_CARTERA_DDEE_PAGEXT_FILE CAR_LP on POS.NAME = CAR_LP.POSITIONNAME
            INNER JOIN :TEMP_TABLA_IRPF_REP irpf ON (CASE WHEN PAR.TAXID IS NULL OR PAR.TAXID NOT IN ('I','E','S','C') THEN 'P' ELSE PAR.TAXID END) = IRPF.NAME

            WHERE
                LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3 ,1,4),'0'),4,'0') NOT IN ('0931','0936')

                AND (PAR.TERMINATIONDATE IS NULL OR PAR.TERMINATIONDATE > ADD_DAYS(v_periodEndDate,-1))

                AND ((v_pagos_a_tratar = 'MAX' AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc)
                    OR (v_pagos_a_tratar = 'ALL' AND CAR_LP.SEQ_POST IS NOT NULL))

                AND ((PAR.GENERICNUMBER4 IS NULL OR PAR.GENERICNUMBER4=0)
                     OR (SUBSTR(CAR_LP.EARNINGGROUPID,4,2)='S4' AND (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0))
                     OR (SUBSTR(CAR_LP.EARNINGGROUPID,4,2)='S5' AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) LIKE '03'
                        AND (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0)))

                AND PAR.GENERICATTRIBUTE1 NOT IN ('50115742F','52096024N')

                AND (POS.GENERICNUMBER4<>2 OR POS.GENERICNUMBER4 is NULL)

                AND SUBSTR(POS.GENERICATTRIBUTE3,5,6) <>'999999'
                AND POS.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND POS.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
                --AND TO_DATE(TO_CHAR(FROM_TZ(CAST(POS.CREATEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(POS.CREATEDATE AS TIMESTAMP)
                    <= (CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(POS.REMOVEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(POS.REMOVEDATE AS TIMESTAMP)
                    > (CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)

                AND PAR.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND PAR.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
                --AND TO_DATE(TO_CHAR(FROM_TZ(CAST(PAR.CREATEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(PAR.CREATEDATE AS TIMESTAMP)
                    <= (CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(PAR.REMOVEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(PAR.REMOVEDATE AS TIMESTAMP)
                    > (CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)

                AND PAYEE.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND PAYEE.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(PAYEE.CREATEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(PAYEE.CREATEDATE AS TIMESTAMP)
                    <= (CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(PAYEE.REMOVEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(PAYEE.REMOVEDATE AS TIMESTAMP)
                    > (CASE WHEN v_conteo_pagos_lc > 1 AND CAR_LP.SEQ_POST = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)

                --AND CAR_LP.PERIODSEQ = v_periodSeq
                AND pos.TENANTID = v_idtenant
                --JGE 20230925: Peticion Celeste para que no salgan importes 0 y excluir Ocaso
                -- AND (CAR_LP.IMPORTE <> 0 OR SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01');
                --JGE 20250225: Ya no se excluye a Ocaso
                AND CAR_LP.IMPORTE <> 0
                ;
                
               

        v_num_rows = ::ROWCOUNT;--RECORD_COUNT(:TEMP_EXTRACTPAGOS_FILE);
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla de TEMP_EXTRACTPAGOS_FILE. DDEE: '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 

    --     --ALM 20220218: Quitamos el uso del parametro v_licencias para reducir codigo.
    --     --END IF;

    --     -- RAP 20220117
    --     --ALM 20190605: Cargamos una tabla temporal con los resultados de las Autoliquidaciones. Necesario para el proyecto SAP
       
    

        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio borrado de la tabla de FINAL_EXTRACTPAGOS_AUT_FILE.', v_log_count, v_idproceso, 'info'); 

        DELETE FROM EXT.FINAL_EXTRACTPAGOS_AUT_FILE WHERE PERIODSEQ = v_periodSeq;

        v_num_rows = RECORD_COUNT(EXT.FINAL_EXTRACTPAGOS_AUT_FILE);
        COMMIT;

        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Borrado FINAL_EXTRACTPAGOS_AUT_FILE: '|| TO_CHAR(v_num_rows) || ' filas borradas.', v_log_count, v_idproceso, 'info'); 


        --------------- Creacion de FINAL_EXTRACTPAGOS_AUT_FILE --------------

        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla de FINAL_EXTRACTPAGOS_AUT_FILE', v_log_count, v_idproceso, 'info'); 
        INSERT INTO EXT.FINAL_EXTRACTPAGOS_AUT_FILE(CCOMPANI,COFICINA,FCARGO,CAGENTE,IMPCOMIS,IMPSUBVE,IMPPREMI,IRPF,ENVIO_SII,SERCO_CANARIAS,PERIODSEQ,PAG_REFERENCIA_ORIGEN)
            SELECT
                SUBSTR(PAY.EARNINGGROUPID,8,1)                                                                  as CCOMPANI,
                SUBSTR(POS.GENERICATTRIBUTE3,1,4)                                                               as COFICINA,
                SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6)                                                                    as FCARGO,
                SUBSTR(POS.GENERICATTRIBUTE3,6,5)                                                               as CAGENTE,
                CASE SUBSTR (PAY.EARNINGGROUPID,1,2)  WHEN '01' THEN PAY.VALUE ELSE 0 END                       AS IMPCOMIS,
                CASE SUBSTR (PAY.EARNINGGROUPID,1,2)  WHEN '04' THEN PAY.VALUE ELSE 0 END                       AS IMPSUBVE,
                CASE SUBSTR (PAY.EARNINGGROUPID,1,2)  WHEN '03' THEN PAY.VALUE ELSE 0 END                       AS IMPPREMI,
                CASE WHEN (PAR.GENERICATTRIBUTE3 = 'F')
                    THEN
                    CASE  WHEN (PAR.GENERICNUMBER4 IS NOT NULL AND PAR.GENERICNUMBER4<>0) AND PAR.GENERICATTRIBUTE5=SUBSTR(PAY.EARNINGGROUPID,7,2)
                            --ALM 20181004: Controlamos que si el campo del Participant no esta relleno (es nulo) ponemos un 0.
                            THEN IFNULL(PAR.GENERICNUMBER5,0)
                            ELSE IRPF.GENERICNUMBER1
                    END
                    --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                    -- Juridicas que comiencen por estas letras, aplica el tipo de IRPF
                    --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and SUBSTR(PAR.GENERICATTRIBUTE1,1,1) in ('G','J','E','U','V') THEN IRPF.GENERICNUMBER1
                    --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                    -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                    --WHEN (PAR.GENERICATTRIBUTE3 = 'J') and SUBSTR(PAR.GENERICATTRIBUTE1,1,1) in ('G','J','E','V') THEN IRPF.GENERICNUMBER1
                    --ALM 20250730: A peticion de Cristian ponemos IRPF 0 a la CIF pedido.
                    --WHEN (PAR.GENERICATTRIBUTE3 = 'J') AND SUBSTR(PAR.GENERICATTRIBUTE1,1,1) in ('G','J','E','V') AND PAR.GENERICATTRIBUTE1 <> 'J72106826'
                    WHEN (PAR.GENERICATTRIBUTE3 = 'J') 
                    	--BRG 20251219 Eliminamos los empezados por G porque están exentos de IRPF
		            	--AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('G', 'J', 'E', 'V')
		            	AND SUBSTR(PAR.GENERICATTRIBUTE1, 1, 1) IN ('J', 'E', 'V')
                    	AND PAR.GENERICATTRIBUTE1 NOT IN ('J72106826','J45884319')
                        THEN IRPF.GENERICNUMBER1 -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                    ELSE 0
                END                                                                                             AS IRPF,

                --ALM 20180418: Nuevo campo en la posicion 81.
                --ALM 20200601: Esto se ha modificado en el ALIEXT, pero como aqui no usamos este campo lo dejamos tal cual estaba por el momento
                CASE WHEN PAR.GENERICBOOLEAN3 = 0 AND PAR.GENERICBOOLEAN2 = 1 THEN 'N' ELSE 'S' END             AS ENVIO_SII,

                --ALM 20180612: Nuevo campo en la posicion 82.
                --ALM 20180720: Anadimos un MAX para evitar errores con casos de m�de una version
                CASE WHEN (SELECT MAX(J.COD_REGIONAL) FROM EXT.OUT_JERARQUIA_REP J
                          WHERE J.PERIODSEQ = PAY.PERIODSEQ AND J.PARTICIPANTSEQ = PAY.PAYEESEQ
                             --ALM 20200507: Incluimos la regional de Canarias de Eterna
                             --AND J.POSITIONSEQ = PAY.POSITIONSEQ) = '0557'
                             AND J.POSITIONSEQ = PAY.POSITIONSEQ) IN ('0557','0661')
                    THEN 'C'
                END                                                                                             AS SERCO_CANARIAS,
                
                --JGE 20230111 Anadimos PERIODSEQ y PAG_REFERENCIA_ORIGEN
                PAY.PERIODSEQ                                                                       AS PERIODSEQ,
                
                RPAD(   CONCAT(SUBSTR(PAY.EARNINGGROUPID,8,1),
                        CONCAT(CASE WHEN v_conteo_pagos_lc > 1 AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc
                                    THEN CASE WHEN SUBSTR(PAY.EARNINGGROUPID,5,1) = '4' THEN '7' WHEN SUBSTR(PAY.EARNINGGROUPID,5,1) = '5' THEN '8' END
                                    ELSE SUBSTR(PAY.EARNINGGROUPID,5,1) END,
                        CONCAT(SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6),
                        CONCAT(LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,2,3),'0'),3,'0'),LPAD(IFNULL(SUBSTR(POS.GENERICATTRIBUTE3,7,4),'0'),4,'0'))))),16,' ')        as PAG_REFERENCIA_ORIGEN

            FROM TCMP.CS_POSITION POS
            INNER JOIN TCMP.CS_PARTICIPANT PAR ON POS.PAYEESEQ = PAR.PAYEESEQ AND PAR.TENANTID = v_idtenant
            INNER JOIN TCMP.CS_PAYMENT PAY ON PAR.PAYEESEQ = PAY.PAYEESEQ AND POS.RULEELEMENTOWNERSEQ = PAY.POSITIONSEQ AND PAY.TENANTID = v_idtenant
            --ALM 20191205: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
            --INNER JOIN :TEMP_TABLA_IRPF_REP irpf ON (CASE WHEN PAR.TAXID IS NULL THEN 'P' ELSE PAR.TAXID END) = irpf.name
            INNER JOIN :TEMP_TABLA_IRPF_REP irpf ON (CASE WHEN PAR.TAXID IS NULL OR PAR.TAXID NOT IN ('I','E','S','C') THEN 'P' ELSE PAR.TAXID END) = IRPF.NAME

            WHERE
                --Autoliquidacion TRUE
                --ALM 20181024: Finalmente no es necesario incluir los nuevos Pagos de Autoliquidaci�AUT). Seguira como hasta ahora.
                --(PAR.GENERICBOOLEAN1=1
                 --ALM 20180831: Incluimos los nuevos pagos de Autoliquidacion
                 --or (SUBSTR(PAY.EARNINGGROUPID,-4) = '-AUT')
                PAR.GENERICBOOLEAN1 = 1

                --ALM 20170202: Los pagos de Eterna nunca van al fichero de autoliquidaci�                --ALM 20170919: Incluimos a una nueva corredur�de Eterna que si tiene que autoliquidarse
                --and not(SUBSTR(PAY.EARNINGGROUPID,7,2) LIKE '03')
                AND (NOT(SUBSTR(PAY.EARNINGGROUPID,7,2) LIKE '03') OR PAR.USERID = 'A82473349')

                --No mostramos las AGENCIAS
                AND (POS.GENERICNUMBER4<>2 OR POS.GENERICNUMBER4 is NULL)

                -- No mostramos pagos a posiciones con 6 nueves
                AND SUBSTR(POS.GENERICATTRIBUTE3,5,6) <>'999999'

                --ALM 20170608: Por petici�e Javier quitamos a los agentes dados de baja
                --ALM 20191002: Comprobamos si se ha ejecutado LC y si el PIPELINURUNSEQ del pago es el ultimo del periodo, si lo es usamos la fechaserver de la LC y sino la del cierre.
                --and (PAR.TERMINATIONDATE IS NULL or PAR.TERMINATIONDATE > fechaserver)
                --ALM 20200110: Utilizamos la fecha de final de periodo para comprobar si se ha dado de baja el agente
                --and (PAR.TERMINATIONDATE IS NULL or PAR.TERMINATIONDATE > (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END))
                AND (PAR.TERMINATIONDATE IS NULL OR PAR.TERMINATIONDATE > ADD_DAYS(v_periodEndDate,-1))

                --nos quedamos con la ultima ejecucion
                --ALM 20171109: Para poder tener en cuenta todos y �nicamente los pagos posteados como se indica en la PE000169
                --and PAY.POSTPIPELINERUNDATE is NULL
                --ALM 20191002: Si es la primera ejecucion de la LC en el periodo actual devolvemos solo los pagos posteados de la LC sino todos los pagos posteados.
                --AND PAY.POSTPIPELINERUNSEQ = (select MAX(x.POSTPIPELINERUNSEQ) from cs_payment x where x.periodseq = v_periodSeq)
                --ALM 20230201: Siempre cogemos todos los pagos aunque sea la primera ejecucion de la LC porque ya filtrara la tabla de informe y se quedara con los que necesita.
                --and ((v_pagos_a_tratar = 'MAX' AND PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc)
                --    or (v_pagos_a_tratar = 'ALL' AND PAY.POSTPIPELINERUNSEQ IS NOT NULL))
                AND PAY.POSTPIPELINERUNSEQ IS NOT NULL

                --ALM 20191002: Comprobamos si se ha ejecutado LC y si el PIPELINURUNSEQ del pago es el ultimo del periodo, si lo es usamos la fechaserver de la LC y sino la del cierre.
                --AND POS.EFFECTIVESTARTDATE <= fechaserver
                --AND POS.EFFECTIVEENDDATE > fechaserver
                --AND POS.CREATEDATE <= fechaserver
                --AND POS.removedate > fechaserver  --Cojemos la version valida en el periodo seleccionado para la posicion
                --AND PAR.EFFECTIVESTARTDATE <= fechaserver
                --AND PAR.EFFECTIVEENDDATE > fechaserver
                --AND PAR.CREATEDATE <= fechaserver
                --AND PAR.removedate > fechaserver  --Cojemos la version valida en el periodo seleccionado para el participante
                --AND pos.removedate=v_eot             --Usare esto para pruebas
                --AND PAR.removedate=v_eot             --Usare esto para pruebas
                --ALM 20200110: Utilizamos la fecha final del periodo para cager las fechas efectivas de la jerarquia
                --AND POS.EFFECTIVESTARTDATE <= (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)
                --AND POS.EFFECTIVEENDDATE > (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)
                AND POS.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND POS.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)

                --ALM 20200730: Modificacmos los filtros que utilizan la fechaserver para que sean comparadas en la misma franja horaria.
                --AND POS.CREATEDATE <= (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)
                --AND pos.removedate > (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(POS.CREATEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(POS.CREATEDATE AS TIMESTAMP)
                    <= (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(POS.REMOVEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(POS.REMOVEDATE AS TIMESTAMP)
                    > (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
                --AND PAR.EFFECTIVESTARTDATE <= (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)
                --AND PAR.EFFECTIVEENDDATE > (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)

                AND PAR.EFFECTIVESTARTDATE <= ADD_DAYS(v_periodEndDate,-1)
                AND PAR.EFFECTIVEENDDATE > ADD_DAYS(v_periodEndDate,-1)

                --ALM 20200730: Modificacmos los filtros que utilizan la fechaserver para que sean comparadas en la misma franja horaria.
                --AND PAR.CREATEDATE <= (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)
                --AND PAR.removedate > (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE fechaserver END)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(PAR.CREATEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(PAR.CREATEDATE AS TIMESTAMP)
                    <= (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)
                -- AND TO_DATE(TO_CHAR(FROM_TZ(CAST(PAR.REMOVEDATE AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                AND CAST(PAR.REMOVEDATE AS TIMESTAMP)
                    > (CASE WHEN v_conteo_pagos_lc > 1 and PAY.POSTPIPELINERUNSEQ = v_seq_ultimo_pago_lc THEN v_fechaserver_lc ELSE v_fechaserver END)

                --Solo cogemos el mes que le indico en el paquete
                AND PAY.PERIODSEQ = v_periodSeq
                AND pos.TENANTID = v_idtenant;

        v_num_rows = RECORD_COUNT(EXT.FINAL_EXTRACTPAGOS_AUT_FILE);
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla de FINAL_EXTRACTPAGOS_AUT_FILE: '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 
        -- FIN RAP 20220117


        --RMF 20190125: cambio del truncate de FINAL_EXTRACTPAGOS_FILE_SAP por delete con el periodseq = v_periodSeq
        --ALM 20191002: Incluimos una condicion para no borrar los pagos en la ejecucion inicial de la LC
        --------------- Borrado de FINAL_EXTRACTPAGOS_FILE_SAP --------------
        IF (v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext AND v_ejecucion_inicial_pagext = 0) THEN

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'No borramos la tabla FINAL_EXTRACTPAGOS_FILE porque es la ejecucion inicial de la LC.', v_log_count, v_idproceso, 'info'); 

        ELSE

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio borrado de la tabla de FINAL_EXTRACTPAGOS_FILE.', v_log_count, v_idproceso, 'info'); 

            DELETE FROM EXT.FINAL_EXTRACTPAGOS_FILE WHERE PERIODSEQ = v_periodSeq;

            v_num_rows = RECORD_COUNT(EXT.FINAL_EXTRACTPAGOS_FILE);
            COMMIT;

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Borrado FINAL_EXTRACTPAGOS_FILE: '|| TO_CHAR(v_num_rows) || ' filas borradas.', v_log_count, v_idproceso, 'info'); 

        END IF;


        --------------- Creacion de FINAL_EXTRACTPAGOS_FILE_SAP --------------
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla de FINAL_EXTRACTPAGOS_FILE.', v_log_count, v_idproceso, 'info'); 

        INSERT INTO EXT.FINAL_EXTRACTPAGOS_FILE(ORIGEN_CODIGO,CIA_CODIGO,PAG_OFICINA,PER_CIF_NIF,DC_CODPER,PAG_AGENTE
        	,TIPPER_CODIGO,CONCEP_CODIGO
        	,FPG_CODIGO
        	,PAG_REFERENCIA_ORIGEN,PAG_FECHA_FACTURA,PAG_FECHA_LIQUIDACION
        	,PAG_TEXTO_PAGO,PAG_BANCO_DESTINO,PAG_CARGO_O_ABONO,PAG_IMPORTE,PAG_MONEDA,ACCION,AGENTE_RETA,DC_PE_NOMBRE,DC_PE_DOMICILIO,DC_PE_PROVINCIA,DC_PE_POBLACION,DC_PE_COD_POSTAL
        	,COD_DATO1,DC_IMPORTE1,COD_DATO2,DC_IMPORTE2,COD_DATO3,DC_IMPORTE3,COD_DATO4,DC_IMPORTE4,COD_DATO5,DC_IMPORTE5,COD_DATO9,DC_IMPORTE9,COD_DATO10,DC_IMPORTE10,COD_DATO11,DC_IMPORTE11
        	,COD_DATO13,DC_IMPORTE13,COD_DATO16,DC_IMPORTE16,COD_DATO17,DC_IMPORTE17,COD_DATO30,DC_IMPORTE30,COD_DATO31,DC_IMPORTE31,COD_DATO32,DC_IMPORTE32
        	,IBAN,ENVIO_SII,SERCO_CANARIAS,ESTADO,FECHA_ESTADO,USUARIO_DAC
        	,PERIODSEQ
        	,PAG_COD_UNICO,PAG_CLASIF_AGENTE,SECUENCIAL
        )
            SELECT ORIGEN_CODIGO,CIA_CODIGO,PAG_OFICINA,PER_CIF_NIF,DC_CODPER,PAG_AGENTE,

                TIPPER_CODIGO,
                CONCEP_CODIGO,
                --ALM 20161209: Comprobamos el valor del campo "PAG_CARGO_O_ABONO" para ver si modificamos el campo a 8 o lo dejamos como esta
                --ALM 20170202: Por peticion de Javier lo dejamos vacio de momento
                --ALM 20190605: Devolvemos de nuevo el valor de este campo porque es necesario para SAP
                --FPG_CODIGO,
                --' ' as FPG_CODIGO,
                --ALM 20200303: Devolvemos de nuevo el valor de este campo porque es necesario para SAP
                --CASE WHEN ROUND(SUM((DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)
                --        -((DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)*IRPF)
                --        --20170202 ALM: Por peticion Javier restamos el importe del DATO16 (concepto de pago 801 - "Anticipos") del importe final calculado.
                --        --              Como el importe del campo 16 es negativo, sumamos en lugar de restar.
                --        +(DC_IMPORTE16)),2) >= 0
                --                  THEN FPG_CODIGO ELSE '8' END                                                                      AS FPG_CODIGO,
                FPG_CODIGO,

                PAG_REFERENCIA_ORIGEN,PAG_FECHA_FACTURA,PAG_FECHA_LIQUIDACION,
                PAG_TEXTO_PAGO,PAG_BANCO_DESTINO,
                CASE WHEN ROUND(SUM((DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)
                        -((DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)*IRPF)
                        --20170202 ALM: Por peticion Javier restamos el importe del DATO16 (concepto de pago 801 - "Anticipos") del importe final calculado.
                        --              Como el importe del campo 16 es negativo, sumamos en lugar de restar.
                        +(DC_IMPORTE16)),2) >= 0
                                  THEN 'D' ELSE 'H' END                                                                             AS PAG_CARGO_O_ABONO,

                ROUND(SUM(CASE WHEN AUTOLIQUIDA = 1
                    THEN 0
                    ELSE (DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)
                        -((DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)*IRPF)
                        --20170202 ALM: Por peticion Javier restamos el importe del DATO16 (concepto de pago 801 - "Anticipos") del importe final calculado.
                        --              Como el importe del campo 16 es negativo, sumamos en lugar de restar.
                        +(DC_IMPORTE16)
                END),2)                                                                                                                AS PAG_IMPORTE,

                PAG_MONEDA,ACCION,AGENTE_RETA,
                DC_PE_NOMBRE,DC_PE_DOMICILIO,DC_PE_PROVINCIA,DC_PE_POBLACION,DC_PE_COD_POSTAL,
                COD_DATO1,SUM(DC_IMPORTE1)                                                                                          AS DC_IMPORTE1,
                COD_DATO2,SUM(DC_IMPORTE2)                                                                                          AS DC_IMPORTE2,
                COD_DATO3,SUM(DC_IMPORTE3)                                                                                          AS DC_IMPORTE3,
                COD_DATO4,SUM(DC_IMPORTE4)                                                                                          AS DC_IMPORTE4,
                COD_DATO5,SUM(DC_IMPORTE5)                                                                                          AS DC_IMPORTE5,
                COD_DATO9,SUM(DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)                             AS DC_IMPORTE9,
                COD_DATO10,SUM(DC_IMPORTE31)*SUM(DC_IMPORTE32)                                                                      AS DC_IMPORTE10,
                COD_DATO11,SUM(DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)-SUM(DC_IMPORTE10)          AS DC_IMPORTE11,
                COD_DATO13,ROUND(SUM(DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)*IRPF,2)              AS DC_IMPORTE13,
                COD_DATO16,SUM(DC_IMPORTE16)                                                                                        AS DC_IMPORTE16,
                COD_DATO17,SUM(DC_IMPORTE17)                                                                                        AS DC_IMPORTE17,
                COD_DATO30,IRPF*100                                                                                                 AS DC_IMPORTE30,
                COD_DATO31,SUM(DC_IMPORTE31)                                                                                        AS DC_IMPORTE31,
                COD_DATO32,SUM(DC_IMPORTE32)                                                                                        AS DC_IMPORTE32,
                IBAN,
                ENVIO_SII,
                SERCO_CANARIAS,
                --RMF 20190125: Nuevas columnas para Retencion/Liberacion de pagos (DAC)********************
                0                                                                                                                   AS ESTADO,
                --ALM 20190529: Usamos la fecha actual para cargar la fecha de los pagos iniciales sino usa la de final de mes y no es coherente. Aunque no afecta al funcionamiento.
                --fechaserver                                                                                                         AS FECHA_ESTADO,
                -- TO_DATE(TO_CHAR(FROM_TZ(CAST(sysdate AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')   AS FECHA_ESTADO,
                CURRENT_TIMESTAMP AS FECHA_ESTADO,
                ''                                                                                                                  AS USUARIO_DAC,
                v_periodSeq                                                                                               AS PERIODSEQ,
                --ALM 20190605: Nuevos campos necesarios para el Proyecto SAP
                PAG_COD_UNICO,
                PAG_CLASIF_AGENTE,
                NULL AS SECUENCIAL

            FROM :TEMP_EXTRACTPAGOS_FILE

            GROUP BY ORIGEN_CODIGO,CIA_CODIGO,PAG_OFICINA,PER_CIF_NIF,DC_CODPER,PAG_AGENTE,TIPPER_CODIGO,
                PAG_COD_UNICO,PAG_CLASIF_AGENTE,
                CONCEP_CODIGO,FPG_CODIGO,PAG_REFERENCIA_ORIGEN,PAG_FECHA_FACTURA,PAG_FECHA_LIQUIDACION,
                PAG_TEXTO_PAGO,PAG_BANCO_DESTINO,PAG_CARGO_O_ABONO,PAG_IMPORTE,PAG_MONEDA,ACCION,AGENTE_RETA,
                DC_PE_NOMBRE,DC_PE_DOMICILIO,DC_PE_PROVINCIA,DC_PE_POBLACION,DC_PE_COD_POSTAL,COD_DATO1,
                COD_DATO2,COD_DATO3,COD_DATO4,COD_DATO5,COD_DATO9,COD_DATO10,COD_DATO11,COD_DATO13,COD_DATO16,
                COD_DATO17,COD_DATO30,IRPF,COD_DATO31,COD_DATO32,IBAN,ENVIO_SII,SERCO_CANARIAS,v_periodSeq

            --ATV 20250321 Modificamos para evitar pagos cuya suma final sea 0.
            HAVING SUM(CASE WHEN AUTOLIQUIDA = 1 THEN 1
                    --20260323 --TGV --   quitamos el importe de anticipo  ya que desde contabilidad necesitan que aparezcan esas lineas 
                    WHEN DC_IMPORTE16 <> 0 THEN 1    
                    ELSE (DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)
                        -((DC_IMPORTE1+DC_IMPORTE2+DC_IMPORTE3+DC_IMPORTE4+DC_IMPORTE5+DC_IMPORTE17)*IRPF)
                       
                        +(DC_IMPORTE16)
                END) <> 0

            ORDER BY PAG_REFERENCIA_ORIGEN; --En el ejemplo pasado lo ordena por este campo.

        v_num_rows = RECORD_COUNT(EXT.FINAL_EXTRACTPAGOS_FILE);
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla de FINAL_EXTRACTPAGOS_FILE: '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 


        --RMF 20190125: Actualizacion de FINAL_EXTRACTPAGOS_FILE_SAP con la informacion de WF_PAGEXT_DAC_RETEN_FILE.
        --              Importante en el PAGEXT inicial para retener a los agentes que tengan pagos retenidos anteriores en automatico.
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Actualizacion de la tabla FINAL_EXTRACTPAGOS_FILE con WF_PAGEXT_DAC_RETEN_FILE.', v_log_count, v_idproceso, 'info'); 

        UPDATE EXT.FINAL_EXTRACTPAGOS_FILE EPF
            SET EPF.ESTADO = (SELECT IDR.ESTADO_RETENIDO
                      FROM EXT.WF_PAGEXT_DAC_RETEN_FILE IDR
                      WHERE EPF.PAG_AGENTE = IDR.PAG_AGENTE
                        AND EPF.PAG_OFICINA = IDR.PAG_OFICINA
                        AND IDR.ESTADO_RETENIDO IN (1,3,5)),
                EPF.FECHA_ESTADO = (SELECT IDR.FECHA_MODIFICACION
                      FROM EXT.WF_PAGEXT_DAC_RETEN_FILE IDR
                      WHERE EPF.PAG_AGENTE = IDR.PAG_AGENTE
                        AND EPF.PAG_OFICINA = IDR.PAG_OFICINA
                        AND IDR.ESTADO_RETENIDO IN (1,3,5)),
                EPF.USUARIO_DAC = (SELECT IDR.USUARIO_DAC
                      FROM EXT.WF_PAGEXT_DAC_RETEN_FILE IDR
                      WHERE EPF.PAG_AGENTE = IDR.PAG_AGENTE
                        AND EPF.PAG_OFICINA = IDR.PAG_OFICINA
                        AND IDR.ESTADO_RETENIDO IN (1,3,5))
            WHERE EXISTS (
                    SELECT 1
                    FROM EXT.WF_PAGEXT_DAC_RETEN_FILE IDR
                    WHERE EPF.PAG_AGENTE = IDR.PAG_AGENTE
                        AND EPF.PAG_OFICINA = IDR.PAG_OFICINA
                        AND IDR.ESTADO_RETENIDO IN (1,3,5)
                )
                AND EPF.ESTADO NOT IN (2,4,6,7,8,9);

        v_num_rows = RECORD_COUNT(EXT.FINAL_EXTRACTPAGOS_FILE);
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Actualizacion de la tabla FINAL_EXTRACTPAGOS_FILE con WF_PAGEXT_DAC_RETEN_FILE: ' || TO_CHAR(v_num_rows) ||' filas.', v_log_count, v_idproceso, 'info'); 


        --RMF 20190125: Actualizacion de FINAL_EXTRACTPAGOS_FILE_SAP con la informacion de FINAL_EXTRACTPAGOS_ONLINE_FILE_SAP
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Actualizacion de la tabla FINAL_EXTRACTPAGOS_FILE con FINAL_EXTRACTPAGOS_ONLINE_FILE.', v_log_count, v_idproceso, 'info'); 

        UPDATE EXT.FINAL_EXTRACTPAGOS_FILE EPF
            SET EPF.ESTADO = (SELECT EPO.ESTADO
                      FROM EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE EPO
                      WHERE EPF.PAG_REFERENCIA_ORIGEN = EPO.PAG_REFERENCIA_ORIGEN
                        AND EPF.PER_CIF_NIF = EPO.PER_CIF_NIF
                        --ALM 20200330: Unimos por PAG_COD_UNICO porque un mismo agente puedo cobrar por dos Position
                        AND EPF.PAG_COD_UNICO = EPO.PAG_COD_UNICO),
                EPF.FECHA_ESTADO = (SELECT EPO.FECHA_ESTADO
                      FROM EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE EPO
                      WHERE EPF.PAG_REFERENCIA_ORIGEN = EPO.PAG_REFERENCIA_ORIGEN
                        AND EPF.PER_CIF_NIF = EPO.PER_CIF_NIF
                        --ALM 20200330: Unimos por PAG_COD_UNICO porque un mismo agente puedo cobrar por dos Position
                        AND EPF.PAG_COD_UNICO = EPO.PAG_COD_UNICO),
                EPF.USUARIO_DAC = (SELECT EPO.USUARIO_DAC
                      FROM EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE EPO
                      WHERE EPF.PAG_REFERENCIA_ORIGEN = EPO.PAG_REFERENCIA_ORIGEN
                        AND EPF.PER_CIF_NIF = EPO.PER_CIF_NIF
                        --ALM 20200330: Unimos por PAG_COD_UNICO porque un mismo agente puedo cobrar por dos Position
                        AND EPF.PAG_COD_UNICO = EPO.PAG_COD_UNICO)
            WHERE EXISTS (
                    SELECT 1
                    FROM EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE EPO
                    WHERE EPF.PAG_REFERENCIA_ORIGEN = EPO.PAG_REFERENCIA_ORIGEN
                        AND EPF.PER_CIF_NIF = EPO.PER_CIF_NIF
                        --ALM 20200330: Unimos por PAG_COD_UNICO porque un mismo agente puedo cobrar por dos Position
                        AND EPF.PAG_COD_UNICO = EPO.PAG_COD_UNICO
                );

        v_num_rows = RECORD_COUNT(EXT.FINAL_EXTRACTPAGOS_FILE);
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Actualizacion de la tabla FINAL_EXTRACTPAGOS_FILE con FINAL_EXTRACTPAGOS_ONLINE_FILE: ' || TO_CHAR(v_num_rows) ||' filas.', v_log_count, v_idproceso, 'info'); 


        --LLS 20211216: Petici�AC 2022, campo SECUENCIAL

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Update campo SECUENCIAL FINAL_EXTRACTPAGOS_FILE.', v_log_count, v_idproceso, 'info'); 


            -- Actualizaci�acturas de tipo 4

                UPDATE EXT.FINAL_EXTRACTPAGOS_FILE F
                SET SECUENCIAL = 1 +
                    (    SELECT IFNULL(MAX(X.SECUENCIAL),0)
                        FROM EXT.FINAL_EXTRACTPAGOS_FILE X
                        WHERE X.PAG_AGENTE = F.PAG_AGENTE
                            AND X.PAG_OFICINA = F.PAG_OFICINA
                            AND X.CIA_CODIGO = F.CIA_CODIGO
                            AND SUBSTR(X.PAG_FECHA_LIQUIDACION, 1, 4) = SUBSTR(F.PAG_FECHA_LIQUIDACION, 1, 4) ------------------CRUCE POR A�
                    )
                WHERE F.PERIODSEQ = v_periodSeq
                    AND F.SECUENCIAL IS NULL
                    AND SUBSTR(PAG_REFERENCIA_ORIGEN, 2, 1) = 4
                    ;

                COMMIT;

            -- Actualizaci�acturas de tipo 5

                UPDATE EXT.FINAL_EXTRACTPAGOS_FILE F
                SET SECUENCIAL = 1 +
                    (    SELECT IFNULL(MAX(X.SECUENCIAL),0)
                        FROM EXT.FINAL_EXTRACTPAGOS_FILE X
                        WHERE X.PAG_AGENTE = F.PAG_AGENTE
                            AND X.PAG_OFICINA = F.PAG_OFICINA
                            AND X.CIA_CODIGO = F.CIA_CODIGO
                            AND SUBSTR(X.PAG_FECHA_LIQUIDACION, 1, 4) = SUBSTR(F.PAG_FECHA_LIQUIDACION, 1, 4) ------------------CRUCE POR A�
                    )
                WHERE F.PERIODSEQ = v_periodSeq
                    AND F.SECUENCIAL IS NULL
                    AND SUBSTR(PAG_REFERENCIA_ORIGEN, 2, 1) = 5
                    ;

                COMMIT;

            -- Actualizaci�acturas de tipo 7

                UPDATE EXT.FINAL_EXTRACTPAGOS_FILE F
                SET SECUENCIAL = 1 +
                    (    SELECT IFNULL(MAX(X.SECUENCIAL),0)
                        FROM EXT.FINAL_EXTRACTPAGOS_FILE X
                        WHERE X.PAG_AGENTE = F.PAG_AGENTE
                            AND X.PAG_OFICINA = F.PAG_OFICINA
                            AND X.CIA_CODIGO = F.CIA_CODIGO
                            AND SUBSTR(X.PAG_FECHA_LIQUIDACION, 1, 4) = SUBSTR(F.PAG_FECHA_LIQUIDACION, 1, 4) ------------------CRUCE POR A�
                    )
                WHERE F.PERIODSEQ = v_periodSeq
                    AND F.SECUENCIAL IS NULL
                    AND SUBSTR(PAG_REFERENCIA_ORIGEN, 2, 1) = 7
                    ;

                COMMIT;

            -- Actualizaci�acturas de tipo 8

                UPDATE EXT.FINAL_EXTRACTPAGOS_FILE F
                SET SECUENCIAL = 1 +
                    (    SELECT IFNULL(MAX(X.SECUENCIAL),0)
                        FROM EXT.FINAL_EXTRACTPAGOS_FILE X
                        WHERE X.PAG_AGENTE = F.PAG_AGENTE
                            AND X.PAG_OFICINA = F.PAG_OFICINA
                            AND X.CIA_CODIGO = F.CIA_CODIGO
                            AND SUBSTR(X.PAG_FECHA_LIQUIDACION, 1, 4) = SUBSTR(F.PAG_FECHA_LIQUIDACION, 1, 4) ------------------CRUCE POR A�
                    )
                WHERE F.PERIODSEQ = v_periodSeq
                    AND F.SECUENCIAL IS NULL
                    AND SUBSTR(PAG_REFERENCIA_ORIGEN, 2, 1) = 8
                    ;

                COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Update campo SECUENCIAL FINAL_EXTRACTPAGOS_FILE.', v_log_count, v_idproceso, 'info'); 


        --RMF 20200302 : Primera ejecucion de PAGEXT y NO hay liquidacion complementaria
        IF(v_ejecucion_inicial_pagext = 0 AND v_conteo_pagos_lc = 1) THEN
            --------------- Truncado de FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE ----------------
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'v_ejecucion_inicial_pagext: ' || v_ejecucion_inicial_pagext || '; v_conteo_pagos_lc: ' || v_conteo_pagos_lc || '.', v_log_count, v_idproceso, 'info'); 
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Truncado de la tabla de FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE.', v_log_count, v_idproceso, 'info'); 

            execute immediate 'truncate table FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE';

            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Truncado de la tabla de FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE.', v_log_count, v_idproceso, 'info'); 

            --------------- Carga de FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE ----------------
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE', v_log_count, v_idproceso, 'info'); 

            INSERT INTO EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE(DEPOSITSEQ, DEPOSITO, EARNINGGROUPID, COMPANIA, TIPODOCUMENTO, FECHA, POSICION_COMERCIAL, COD_CONCEPTO, PRODUCTO, IMPORTE, PROGRAMA
            	, DOC_NIF, POLIZAS,PAG_REFERENCIA_ORIGEN,PERIODSEQ)
                SELECT DEPOSITSEQ, DEPOSITO, EARNINGGROUPID, COMPANIA, TIPODOCUMENTO, FECHA, POSICION_COMERCIAL, COD_CONCEPTO, PRODUCTO, IMPORTE, PROGRAMA, DOC_NIF, POLIZAS,
                RPAD(   CONCAT(SUBSTR(COMPANIA,2,1),
                        CONCAT(TIPODOCUMENTO,
                        CONCAT(SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6),
                        CONCAT(LPAD(IFNULL(SUBSTR(POSICION_COMERCIAL,2,3),'0'),3,'0'),LPAD(IFNULL(SUBSTR(POSICION_COMERCIAL,7,4),'0'),4,'0'))))),16,' ')  as PAG_REFERENCIA_ORIGEN,
                v_periodSeq
                FROM EXT.TEMP_LIQEXT_CABECERA_FILE;

            v_num_rows = RECORD_COUNT(EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE);
            COMMIT;

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE: ' || TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 

        END IF;

        --RMF 20200302: Primera ejecucion del PAGEXT con liquidacion complementaria
        IF(v_ejecucion_inicial_pagext = 0 AND v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext) THEN
            --------------- INSERT de FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE ----------------
            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'v_ejecucion_inicial_pagext: ' || v_ejecucion_inicial_pagext || '; v_conteo_pagos_lc: ' || v_conteo_pagos_lc || '.', v_log_count, v_idproceso, 'info'); 

            --------------- Carga de FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE ----------------
            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE con informacion de LC', v_log_count, v_idproceso, 'info'); 
            INSERT INTO EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE(DEPOSITSEQ, DEPOSITO, EARNINGGROUPID, COMPANIA, TIPODOCUMENTO, FECHA, POSICION_COMERCIAL, COD_CONCEPTO, PRODUCTO, IMPORTE, PROGRAMA,
            	DOC_NIF, POLIZAS, PAG_REFERENCIA_ORIGEN, PERIODSEQ)
                SELECT IFNULL(LIQ_LC.DEPOSITSEQ,LIQ_NO_LC.DEPOSITSEQ) AS DEPOSITSEQ,
                      IFNULL(LIQ_LC.DEPOSITO,LIQ_NO_LC.DEPOSITO) AS DEPOSITO,
                      IFNULL(LIQ_LC.EARNINGGROUPID,LIQ_NO_LC.EARNINGGROUPID) AS EARNINGGROUPID,
                      IFNULL(LIQ_LC.COMPANIA,LIQ_NO_LC.COMPANIA) AS COMPANIA,
                      IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) AS TIPODOCUMENTO,
                      IFNULL(LIQ_LC.FECHA,LIQ_NO_LC.FECHA) AS FECHA,
                      IFNULL(LIQ_LC.POSICION_COMERCIAL,LIQ_NO_LC.POSICION_COMERCIAL) AS POSICION_COMERCIAL,
                      IFNULL(LIQ_LC.COD_CONCEPTO,LIQ_NO_LC.COD_CONCEPTO) AS COD_CONCEPTO,
                      IFNULL(LIQ_LC.PRODUCTO,LIQ_NO_LC.PRODUCTO) AS PRODUCTO,
                      IFNULL(LIQ_LC.IMPORTE,0) - IFNULL(LIQ_NO_LC.IMPORTE,0) AS IMPORTE,
                      IFNULL(LIQ_LC.PROGRAMA,LIQ_NO_LC.PROGRAMA) AS PROGRAMA,
                      IFNULL(LIQ_LC.DOC_NIF,LIQ_NO_LC.DOC_NIF) AS DOC_NIF,
                      IFNULL(LIQ_LC.POLIZAS,LIQ_NO_LC.POLIZAS) AS POLIZAS,
                      RPAD(
                            CONCAT(SUBSTR(IFNULL(LIQ_LC.COMPANIA,LIQ_NO_LC.COMPANIA),2,1),
                            CONCAT(CASE WHEN v_conteo_pagos_lc > 1
                                        THEN CASE WHEN IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) = '4' THEN '7' WHEN IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) = '5' THEN '8' END
                                        ELSE IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) END,
                            CONCAT(SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6),
                            CONCAT(LPAD(IFNULL(SUBSTR(IFNULL(LIQ_LC.POSICION_COMERCIAL,LIQ_NO_LC.POSICION_COMERCIAL),2,3),'0'),3,'0'),
                            LPAD(IFNULL(SUBSTR(IFNULL(LIQ_LC.POSICION_COMERCIAL,LIQ_NO_LC.POSICION_COMERCIAL),7,4),'0'),4,'0'))))),16,' ') AS PAG_REFERENCIA_ORIGEN,
                        v_periodSeq
                FROM (SELECT * FROM EXT.TEMP_LIQEXT_CABECERA_FILE WHERE PRODUCTO IS NOT NULL) LIQ_LC
                FULL OUTER JOIN (SELECT * FROM EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE WHERE PRODUCTO IS NOT NULL) LIQ_NO_LC ON LIQ_NO_LC.PAG_REFERENCIA_ORIGEN =
                        RPAD(
                            CONCAT(SUBSTR(LIQ_LC.COMPANIA,2,1),
                            CONCAT(LIQ_LC.TIPODOCUMENTO,
                            CONCAT(SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6),
                            CONCAT(LPAD(IFNULL(SUBSTR(LIQ_LC.POSICION_COMERCIAL,2,3),'0'),3,'0'),
                            LPAD(IFNULL(SUBSTR(LIQ_LC.POSICION_COMERCIAL,7,4),'0'),4,'0'))))),16,' ')
                    AND LIQ_NO_LC.PERIODSEQ = v_periodSeq
                    AND LIQ_NO_LC.DOC_NIF = LIQ_LC.DOC_NIF
                    AND LIQ_NO_LC.TIPODOCUMENTO = LIQ_LC.TIPODOCUMENTO
                    AND LIQ_NO_LC.PRODUCTO  = LIQ_LC.PRODUCTO
                    AND LIQ_NO_LC.COD_CONCEPTO = LIQ_LC.COD_CONCEPTO
                    --ALM 20220323: Incluimos la union por el EARNINGGROUPID para poder distinguir pagos que en el cierre son AUT y en la LC no y al reves.
                    AND LIQ_NO_LC.EARNINGGROUPID = LIQ_LC.EARNINGGROUPID
                    --ALM 20220325: Incluimos la union por el DEPOSITO para poder distinguir pagos de la DD-O-COLC de distintos Qs.
                    AND LIQ_NO_LC.DEPOSITO = LIQ_LC.DEPOSITO
                    --AND LIQ_NO_LC.PRODUCTO IS NOT NULL
                --WHERE LIQ_LC.PRODUCTO IS NOT NULL
                ;

            v_num_rows = RECORD_COUNT(EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE);
            COMMIT;

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE PRODUCTO IS NOT NULL: ' || TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 

            INSERT INTO EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE(DEPOSITSEQ, DEPOSITO, EARNINGGROUPID, COMPANIA, TIPODOCUMENTO, FECHA, POSICION_COMERCIAL, COD_CONCEPTO, PRODUCTO, IMPORTE, PROGRAMA,
            	DOC_NIF, POLIZAS, PAG_REFERENCIA_ORIGEN, PERIODSEQ)
                SELECT IFNULL(LIQ_LC.DEPOSITSEQ,LIQ_NO_LC.DEPOSITSEQ) AS DEPOSITSEQ,
                      IFNULL(LIQ_LC.DEPOSITO,LIQ_NO_LC.DEPOSITO) AS DEPOSITO,
                      IFNULL(LIQ_LC.EARNINGGROUPID,LIQ_NO_LC.EARNINGGROUPID) AS EARNINGGROUPID,
                      IFNULL(LIQ_LC.COMPANIA,LIQ_NO_LC.COMPANIA) AS COMPANIA,
                      IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) AS TIPODOCUMENTO,
                      IFNULL(LIQ_LC.FECHA,LIQ_NO_LC.FECHA) AS FECHA,
                      IFNULL(LIQ_LC.POSICION_COMERCIAL,LIQ_NO_LC.POSICION_COMERCIAL) AS POSICION_COMERCIAL,
                      IFNULL(LIQ_LC.COD_CONCEPTO,LIQ_NO_LC.COD_CONCEPTO) AS COD_CONCEPTO,
                      IFNULL(LIQ_LC.PRODUCTO,LIQ_NO_LC.PRODUCTO) AS PRODUCTO,
                      IFNULL(LIQ_LC.IMPORTE,0) - IFNULL(LIQ_NO_LC.IMPORTE,0) AS IMPORTE,
                      IFNULL(LIQ_LC.PROGRAMA,LIQ_NO_LC.PROGRAMA) AS PROGRAMA,
                      IFNULL(LIQ_LC.DOC_NIF,LIQ_NO_LC.DOC_NIF) AS DOC_NIF,
                      IFNULL(LIQ_LC.POLIZAS,LIQ_NO_LC.POLIZAS) AS POLIZAS,
                      RPAD(
                            CONCAT(SUBSTR(IFNULL(LIQ_LC.COMPANIA,LIQ_NO_LC.COMPANIA),2,1),
                            CONCAT(CASE WHEN v_conteo_pagos_lc > 1
                                    THEN CASE WHEN IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) = '4' THEN '7' WHEN IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) = '5' THEN '8' END
                                    ELSE IFNULL(LIQ_LC.TIPODOCUMENTO,LIQ_NO_LC.TIPODOCUMENTO) END,
                            CONCAT(SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6),
                            CONCAT(LPAD(IFNULL(SUBSTR(IFNULL(LIQ_LC.POSICION_COMERCIAL,LIQ_NO_LC.POSICION_COMERCIAL),2,3),'0'),3,'0'),
                            LPAD(IFNULL(SUBSTR(IFNULL(LIQ_LC.POSICION_COMERCIAL,LIQ_NO_LC.POSICION_COMERCIAL),7,4),'0'),4,'0'))))),16,' ') AS PAG_REFERENCIA_ORIGEN,
                        v_periodSeq
                FROM (SELECT * FROM EXT.TEMP_LIQEXT_CABECERA_FILE WHERE PRODUCTO IS NULL) LIQ_LC
                FULL OUTER JOIN (SELECT * FROM EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE WHERE PRODUCTO IS NULL) LIQ_NO_LC ON LIQ_NO_LC.PAG_REFERENCIA_ORIGEN =
                        RPAD(
                            CONCAT(SUBSTR(LIQ_LC.COMPANIA,2,1),
                            CONCAT(LIQ_LC.TIPODOCUMENTO,
                            CONCAT(SUBSTR(TO_VARCHAR(v_PeriodStartDate,'YYYYMMDD'),1,6),
                            CONCAT(LPAD(IFNULL(SUBSTR(LIQ_LC.POSICION_COMERCIAL,2,3),'0'),3,'0'),
                            LPAD(IFNULL(SUBSTR(LIQ_LC.POSICION_COMERCIAL,7,4),'0'),4,'0'))))),16,' ')
                    AND LIQ_NO_LC.PERIODSEQ = v_periodSeq
                    AND LIQ_NO_LC.DOC_NIF = LIQ_LC.DOC_NIF
                    AND LIQ_NO_LC.TIPODOCUMENTO = LIQ_LC.TIPODOCUMENTO
                    AND LIQ_NO_LC.COD_CONCEPTO = LIQ_LC.COD_CONCEPTO
                    --ALM 20220323: Incluimos la union por el EARNINGGROUPID para poder distinguir pagos que en el cierre son AUT y en la LC no y al reves.
                    AND LIQ_NO_LC.EARNINGGROUPID = LIQ_LC.EARNINGGROUPID
                    AND LIQ_NO_LC.DEPOSITO = LIQ_LC.DEPOSITO
                --    AND LIQ_NO_LC.PRODUCTO IS NULL
                --WHERE LIQ_LC.PRODUCTO IS NULL
                ;

            v_num_rows = RECORD_COUNT(EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE);
            COMMIT;

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE PRODUCTO IS NULL: ' || TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 

        END IF;

        ---------------  Borrado de FINAL_LIQEXT_CABECERA_FILE ---------------
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Borrado de la tabla de FINAL_LIQEXT_CABECERA_FILE.', v_log_count, v_idproceso, 'info'); 

        DELETE FROM EXT.FINAL_LIQEXT_CABECERA_FILE WHERE PERIODSEQ = v_periodSeq;

        v_num_rows = RECORD_COUNT(EXT.FINAL_LIQEXT_CABECERA_FILE);
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Borrado FINAL_LIQEXT_CABECERA_FILE: '|| TO_CHAR(v_num_rows) || ' filas borradas.', v_log_count, v_idproceso, 'info'); 

        ---------------  Carga de FINAL_LIQEXT_CABECERA_FILE ---------------
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla de FINAL_LIQEXT_CABECERA_FILE.', v_log_count, v_idproceso, 'info'); 

        INSERT INTO EXT.FINAL_LIQEXT_CABECERA_FILE(PERIODSEQ,PAG_REFERENCIA_ORIGEN,POLIZAS,DOC_NIF,PROGRAMA,IMPORTE,PRODUCTO,COD_CONCEPTO,POSICION_COMERCIAL,FECHA,TIPODOCUMENTO,COMPANIA,EARNINGGROUPID,DEPOSITO,DEPOSITSEQ)
            SELECT PERIODSEQ,PAG_REFERENCIA_ORIGEN,POLIZAS,DOC_NIF,PROGRAMA,IMPORTE,PRODUCTO,COD_CONCEPTO,POSICION_COMERCIAL,FECHA,TIPODOCUMENTO,COMPANIA,EARNINGGROUPID,DEPOSITO,DEPOSITSEQ
            FROM EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE;

        v_num_rows = RECORD_COUNT(EXT.FINAL_LIQEXT_CABECERA_FILE);
        COMMIT;
-- SELECT 'SMM',DOC_NIF,LENGTH(DOC_NIF) FROM EXT.FINAL_PAGEXT_LIQ_CAB_ONLINE_FILE;
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga FINAL_LIQEXT_CABECERA_FILE: '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 

        --------------- Truncado de FINAL_EXTRACTPAGOS_ONLINE_FILE_SAP ---------------

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Truncado de la tabla de FINAL_EXTRACTPAGOS_ONLINE_FILE.', v_log_count, v_idproceso, 'info'); 

        execute immediate 'truncate table EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE';

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Truncado de la tabla de FINAL_EXTRACTPAGOS_ONLINE_FILE.', v_log_count, v_idproceso, 'info'); 


        --------------- Carga de FINAL_EXTRACTPAGOS_ONLINE_FILE_SAP ---------------

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla FINAL_EXTRACTPAGOS_ONLINE_FILE.', v_log_count, v_idproceso, 'info'); 

        INSERT INTO EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE(ORIGEN_CODIGO,CIA_CODIGO,PAG_OFICINA,PER_CIF_NIF,DC_CODPER,PAG_AGENTE,TIPPER_CODIGO,CONCEP_CODIGO,FPG_CODIGO,PAG_REFERENCIA_ORIGEN,
        PAG_FECHA_FACTURA,PAG_FECHA_LIQUIDACION,PAG_TEXTO_PAGO,PAG_BANCO_DESTINO,PAG_CARGO_O_ABONO,PAG_IMPORTE,PAG_MONEDA,ACCION,AGENTE_RETA,
        DC_PE_NOMBRE,DC_PE_DOMICILIO,DC_PE_PROVINCIA,DC_PE_POBLACION,DC_PE_COD_POSTAL,COD_DATO1,DC_IMPORTE1,COD_DATO2,DC_IMPORTE2,COD_DATO3,DC_IMPORTE3,
        COD_DATO4,DC_IMPORTE4,COD_DATO5,SECUENCIAL,DC_IMPORTE5,COD_DATO9,DC_IMPORTE9,COD_DATO10,DC_IMPORTE10,COD_DATO11,DC_IMPORTE11,COD_DATO13,
        DC_IMPORTE13,COD_DATO16,DC_IMPORTE16,COD_DATO17,DC_IMPORTE17,COD_DATO30,DC_IMPORTE30,COD_DATO31,DC_IMPORTE31,COD_DATO32,DC_IMPORTE32,IBAN,ENVIO_SII,SERCO_CANARIAS,ESTADO,FECHA_ESTADO,
        USUARIO_DAC,PERIODSEQ,PAG_COD_UNICO,PAG_CLASIF_AGENTE)
            SELECT *
            FROM EXT.FINAL_EXTRACTPAGOS_FILE
            WHERE PERIODSEQ = v_periodSeq;

        v_num_rows = RECORD_COUNT(EXT.FINAL_EXTRACTPAGOS_ONLINE_FILE);
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla FINAL_EXTRACTPAGOS_ONLINE_FILE: '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 


        --------------- Truncado de OUT_EXTRACTPAGOS_INFORME_FILE_SAP --------------

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Truncado de la tabla de OUT_EXTRACTPAGOS_INFORME_FILE.', v_log_count, v_idproceso, 'info'); 

        execute immediate 'truncate table EXT.OUT_EXTRACTPAGOS_INFORME_FILE';

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Truncado de la tabla de OUT_EXTRACTPAGOS_INFORME_FILE.', v_log_count, v_idproceso, 'info'); 


        --------------- Creacion de OUT_EXTRACTPAGOS_INFORME_FILE_SAP --------------

        --ALM 20190605: Nueva carga de la tabla de informe con los cambios del proyecto SAP
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Carga de la tabla de OUT_EXTRACTPAGOS_INFORME_FILE.', v_log_count, v_idproceso, 'info'); 

        INSERT INTO EXT.OUT_EXTRACTPAGOS_INFORME_FILE

            SELECT
                PAGOS.TIPO_REGISTRO ||';'||
                PAGOS.CIA_CODIGO ||';'||
                PAGOS.PER_CIF_NIF ||';'||
                PAGOS.PAG_REFERENCIA_ORIGEN ||';'||
                PAGOS.TIPO_PAGO ||';'||
                PAGOS.CARGO_LIQUIDACION ||';'||
                PAGOS.PAG_OFICINA ||';'||
                PAGOS.PAG_AGENTE ||';'||
                COALESCE(PAGOS.PAG_COD_UNICO,'') ||';'||
                COALESCE(PAGOS.PAG_CLASIF_AGENTE,'') ||';'||
                PAGOS.PAG_FECHA_FACTURA ||';'||
                PAGOS.IRPF ||';'||
                PAGOS.MONEDA ||';'||
                --LIQEXT
                PAGOS.COD_CONCEPTO ||';'||
                PAGOS.OFICINA_GASTO ||';'||
                PAGOS.PRODUCTO ||';'||
                PAGOS.IMPORTE_COMISION ||';'||
                PAGOS.CARGO_ABONO ||';'||
                PAGOS.AUTORIZA_FACTURA ||';'||
                PAGOS.ENVIAR_SII_AEAT ||';'||
                PAGOS.ENVIAR_SII_ATC ||';'||
                --PAGOS
                PAGOS.PAG_IMPORTE ||';'||
                PAGOS.SIGNO_PAG_IMPORTE ||';'||
                PAGOS.AUT_IMPORTE ||';'||
                PAGOS.SIGNO_AUT_IMPORTE ||';'||
                PAGOS.VIA_PAGO ||';'||
                PAGOS.ESTADO ||';'||
                PAGOS.FECHA_ESTADO ||';'||
                RPAD(PAGOS.IBAN, 24, ' ') AS LINE
            FROM (
                SELECT 'PA' AS TIPO_REGISTRO,
                    PAG.CIA_CODIGO,
                    RPAD(PAG.PER_CIF_NIF,10,' ') AS PER_CIF_NIF,
                    
                    --LLS 20220201: Poner el secuencial solo si la ejecucion y la factura es de 2022 o superior
                    CASE WHEN EXTRACT(YEAR FROM v_periodSTARTDATE) > '2021' AND SUBSTR(PAG.PAG_REFERENCIA_ORIGEN, 3, 4) > '2021'
                        --THEN CAST(RPAD(( SUBSTR(PAG.PAG_REFERENCIA_ORIGEN, 1, 2) || SUBSTR(PAG.PAG_REFERENCIA_ORIGEN, 5, 11) || '/' || SUBSTR( '0' || PAG.SECUENCIAL, -2)) ,23,' ') AS VARCHAR(23))
                        THEN CAST(RPAD(( SUBSTR(PAG.PAG_REFERENCIA_ORIGEN, 1, 2) || SUBSTR(PAG.PAG_REFERENCIA_ORIGEN, 5, 11) || '/' || SUBSTR('0' || PAG.SECUENCIAL, LENGTH('0' || PAG.SECUENCIAL) - 1, 2)) ,23,' ') AS VARCHAR(23))
                        ELSE CAST(RPAD(PAG.PAG_REFERENCIA_ORIGEN,23,' ') AS VARCHAR(23))
                        END AS PAG_REFERENCIA_ORIGEN,
                    SUBSTR(PAG.PAG_REFERENCIA_ORIGEN,2,1) AS TIPO_PAGO,
                    SUBSTR(PAG.PAG_FECHA_LIQUIDACION,1,6) AS CARGO_LIQUIDACION,
                    PAG.PAG_OFICINA,
                    PAG.PAG_AGENTE,
                    RPAD(PAG.PAG_COD_UNICO,14,' ') AS PAG_COD_UNICO,
                    RPAD(PAG.PAG_CLASIF_AGENTE,2,' ') AS PAG_CLASIF_AGENTE,
                    SUBSTR(PAG.PAG_FECHA_FACTURA,7,2) || SUBSTR(PAG.PAG_FECHA_FACTURA,5,2) || SUBSTR(PAG.PAG_FECHA_FACTURA,1,4) AS PAG_FECHA_FACTURA,
                    LPAD(FLOOR(CAST(ABS(PAG.DC_IMPORTE30) AS INT)),2,0)||','||LPAD((ABS(MOD(ROUND(PAG.DC_IMPORTE30,2),1)*100)),2,'0') AS IRPF,
                    'EUR' AS MONEDA,

                    --LIQEXT
                    RPAD(' ',3) AS COD_CONCEPTO,
                    RPAD(' ',4) AS OFICINA_GASTO,
                    RPAD(' ',5) AS PRODUCTO,
                    RPAD(' ',16) AS IMPORTE_COMISION,
                    --PAG.PAG_CARGO_O_ABONO AS CARGO_ABONO, --Devolvemos el valor que tiene en el PAGEXT para las pruebas
                    RPAD(' ',1) AS CARGO_ABONO,
                    --PAG.ENVIO_SII AS AUTORIZA_FACTURA, --Devolvemos el valor que tiene en el PAGEXT para las pruebas
                    RPAD(' ',1) AS AUTORIZA_FACTURA,
                    --(CASE WHEN PAG.ENVIO_SII = 'S' AND PAG.SERCO_CANARIAS IS NULL
                    --    THEN 'S'
                    --    ELSE ''
                    --END) AS ENVIAR_SII_AEAT, --Devolvemos el valor que tiene en el PAGEXT para las pruebas
                    RPAD(' ',1) AS ENVIAR_SII_AEAT,
                    --(CASE WHEN PAG.ENVIO_SII = 'S' AND PAG.SERCO_CANARIAS = 'C'
                    --    THEN 'S'
                    --    ELSE ''
                    --END) AS ENVIAR_SII_ATC, --Devolvemos el valor que tiene en el PAGEXT para las pruebas
                    RPAD(' ',1) AS ENVIAR_SII_ATC,

                    --PAGEXT
                    --RPAD(trunc(PAG.DC_IMPORTE9) || SUBSTR(PAG.DC_IMPORTE9*100,-2),16,' ') AS PAG_IMPORTE,   --Devolvemos el importe sin restar el IRPF. NO
                    --RPAD(TRUNC(ABS(PAG.PAG_IMPORTE)) || LPAD((ABS(MOD(ROUND(PAG.PAG_IMPORTE,2),1)*100)),2,'0'),16,' ') AS PAG_IMPORTE,   --Devolvemos el importe con IRPF aplicado. OK
     --               
					-- RPAD(CAST(ABS(PAG.PAG_IMPORTE) AS INTEGER) || LPAD(TO_VARCHAR(ROUND(MOD(ABS(PAG.PAG_IMPORTE),1) * 100),0),2,'0'),16, ' ') AS PAG_IMPORTE,
                    RPAD(CAST(ABS(PAG.PAG_IMPORTE) AS INTEGER) || LPAD((ABS(MOD(ROUND(PAG.PAG_IMPORTE,2),1)*100)),2,'0'),16,' ') AS PAG_IMPORTE,
                    CASE WHEN PAG.PAG_IMPORTE < 0 THEN '-' ELSE ' ' END AS SIGNO_PAG_IMPORTE,

                    --ALM 20190718: Anadimos la compania y quitamos el IRPF
                    --RPAD(NVL(TRUNC(ABS((select SUM(AUT.IMPCOMIS) from EXT.FINAL_EXTRACTPAGOS_AUT_FILE AUT where AUT.COFICINA = PAG.PAG_OFICINA and AUT.CAGENTE = SUBSTR(PAG.PAG_AGENTE,-5)) - PAG.DC_IMPORTE1))
                    --    || SUBSTR(((select SUM(AUT.IMPCOMIS) from EXT.FINAL_EXTRACTPAGOS_AUT_FILE AUT where AUT.COFICINA = PAG.PAG_OFICINA and AUT.CAGENTE = SUBSTR(PAG.PAG_AGENTE,-5)) - PAG.DC_IMPORTE1)*100,-2)
                    --,0),16,' ') AS AUT_IMPORTE,
                    RPAD(IFNULL(FLOOR(ABS(
                        (SELECT SUM(AUT.IMPCOMIS) - ROUND(SUM(AUT.IMPCOMIS) * MAX(AUT.IRPF),2) FROM EXT.FINAL_EXTRACTPAGOS_AUT_FILE AUT  WHERE AUT.PERIODSEQ = PAG.PERIODSEQ AND AUT.PAG_REFERENCIA_ORIGEN = PAG.PAG_REFERENCIA_ORIGEN)
                        - (CASE 
                            WHEN PAG.PAG_IMPORTE = 0 
                            THEN 0 
                            ELSE ROUND(PAG.DC_IMPORTE1 * (100 - PAG.DC_IMPORTE30)/100,2) 
                        END)
                    )),0)                    
                    || 
                    IFNULL(LPAD(ABS(MOD(
                        ROUND(
                          (SELECT SUM(AUT.IMPCOMIS) - ROUND(SUM(AUT.IMPCOMIS)*MAX(AUT.IRPF),2)
                              FROM EXT.FINAL_EXTRACTPAGOS_AUT_FILE AUT  
                             WHERE AUT.PERIODSEQ = PAG.PERIODSEQ
                              AND AUT.PAG_REFERENCIA_ORIGEN = PAG.PAG_REFERENCIA_ORIGEN
                          )
                          - (CASE 
                                WHEN PAG.PAG_IMPORTE = 0 
                                THEN 0 
                                ELSE ROUND(PAG.DC_IMPORTE1 * (100 - PAG.DC_IMPORTE30)/100,2) 
                              END)
                        ,2),1
                        ) * 100
                    ),2,'0'),'')
                    ,16,' ') AS AUT_IMPORTE,
                    --ALM 20220708: Hay que usar la misma resta que para el importe porque sino puede dar problemas.
                    --              Ej: Cargo = 202206, pag_referencia_origen = 142022067690612
                    --CASE WHEN ((SELECT SUM(AUT.IMPCOMIS) FROM EXT.FINAL_EXTRACTPAGOS_AUT_FILE AUT where AUT.COFICINA = PAG.PAG_OFICINA AND AUT.CAGENTE = SUBSTR(PAG.PAG_AGENTE,-5)) - PAG.DC_IMPORTE1) < 0
                    CASE WHEN ((SELECT SUM(AUT.IMPCOMIS) - ROUND((SUM(AUT.IMPCOMIS)*MAX(AUT.IRPF)),2)
                                FROM EXT.FINAL_EXTRACTPAGOS_AUT_FILE AUT
                                --where AUT.COFICINA = PAG.PAG_OFICINA AND AUT.CAGENTE = SUBSTR(PAG.PAG_AGENTE,-5) AND AUT.CCOMPANI = SUBSTR(PAG.CIA_CODIGO,-1))
                                WHERE AUT.PERIODSEQ = PAG.PERIODSEQ AND AUT.PAG_REFERENCIA_ORIGEN = PAG.PAG_REFERENCIA_ORIGEN)
                            - (CASE WHEN PAG.PAG_IMPORTE = 0 THEN 0 ELSE ROUND((PAG.DC_IMPORTE1 * (100 - PAG.DC_IMPORTE30)/100),2) END)) < 0
                        THEN '-' ELSE ' '
                    END AS SIGNO_AUT_IMPORTE,

                    --ALM 20200204: Para los empleados (PAG.PAG_CLASIF_AGENTE = 'EM' ponemos siempre 'T'
                    (CASE WHEN PAG.PAG_CLASIF_AGENTE = 'EM' THEN 'T' ELSE
                        (CASE WHEN PAG.FPG_CODIGO = '2' THEN 'E'      --Hay que devolver este campo FPG_CODIGO en la tabla FINAL ahora siempre viene vacio
                              WHEN PAG.FPG_CODIGO = '3' THEN 'T'
                              ELSE ' '
                        END)
                    END) AS VIA_PAGO,

                    (CASE WHEN PAG.ESTADO IN (0,1,3,5) THEN 'R'  --Incluimos en estado incial como Retenido, para la primera ejecucion
                          WHEN PAG.ESTADO IN (2,4,6) THEN 'X'    --Nunca van a ir en el PAGEXT
                          WHEN PAG.ESTADO IN (7) THEN 'L'        --Solo el estado 7 (CONFIRMADO) se devuelve como pago liberado
                          WHEN PAG.ESTADO IN (8) THEN 'A'        --Pagos Anulados
                          WHEN PAG.ESTADO IN (9) THEN 'C'        --Pagos Compensados (Pago sin Pago)
                    END) AS ESTADO,

                    TO_CHAR(PAG.FECHA_ESTADO,'DDMMYYYY') AS FECHA_ESTADO,

                    RPAD(PAG.IBAN,24,' ') AS IBAN

                FROM EXT.FINAL_EXTRACTPAGOS_FILE PAG
                --ALM 20190902: Anadimos el control -> ejecucion_inicial_pagext > 0
                --ALM 20191002: Si es la ejecucion inicial de la LC solo devolvemos los pagos generados en la LC (SUBSTR(PAG_REFERENCIA_ORIGEN,2,1) in ('7','8')
                WHERE ((v_ejecucion_inicial_pagext > 0 AND ESTADO IN (7,8,9) AND FECHA_ESTADO > v_fecha_ultimo_pagext)                 --las ejecuciones diarias entran por aqui
                    OR (v_ejecucion_inicial_pagext = 0 AND PERIODSEQ = v_periodSeq                                         --las ejecuciones iniciales entran por aqui
                        --dentro de las ejecuciones iniciales, si es la del LC solo se cogen los pagos generados en ella
                        AND (((v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext) AND SUBSTR(PAG_REFERENCIA_ORIGEN,2,1) in ('7','8'))
                            --dentro de las ejecuciones iniciales, si NO es la del LC se cogen todos los pagos
                            OR not(v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext))))

                --ALM 20210303: Ponemos un UNION ALL porque si hay gastos de los mismos conceptos con los mismos importes solo se muestra uno de ellos
                UNION ALL

                SELECT 'GA' AS TIPO_REGISTRO,
                    PAGEXT.CIA_CODIGO,
                    RPAD(PAGEXT.PER_CIF_NIF,10,' ') AS PER_CIF_NIF,
                    --LLS 20220201: Poner el secuencial solo si la ejecucion y la factura es de 2022 o superior
                    CASE WHEN EXTRACT(YEAR FROM v_periodSTARTDATE) > '2021' AND SUBSTR(PAGEXT.PAG_REFERENCIA_ORIGEN, 3, 4) > '2021'
                        --THEN CAST(RPAD(( SUBSTR(PAGEXT.PAG_REFERENCIA_ORIGEN, 1, 2) || SUBSTR(PAGEXT.PAG_REFERENCIA_ORIGEN, 5, 11) || '/' || SUBSTR( '0' || PAGEXT.SECUENCIAL, -2)) ,23,' ') AS VARCHAR(23))
                        THEN CAST(RPAD(( SUBSTR(PAGEXT.PAG_REFERENCIA_ORIGEN, 1, 2) || SUBSTR(PAGEXT.PAG_REFERENCIA_ORIGEN, 5, 11) || '/' || SUBSTR('0' || PAGEXT.SECUENCIAL, LENGTH('0' || PAGEXT.SECUENCIAL) - 1, 2)) ,23,' ') AS VARCHAR(23))
                        ELSE CAST(RPAD(PAGEXT.PAG_REFERENCIA_ORIGEN,23,' ') AS VARCHAR(23))
                        END AS PAG_REFERENCIA_ORIGEN,
                    SUBSTR(PAGEXT.PAG_REFERENCIA_ORIGEN,2,1) AS TIPO_PAGO,
                    SUBSTR(PAGEXT.PAG_FECHA_LIQUIDACION,1,6) AS CARGO_LIQUIDACION,
                    PAGEXT.PAG_OFICINA,
                    PAGEXT.PAG_AGENTE,
                    RPAD(PAGEXT.PAG_COD_UNICO,14,' ') AS PAG_COD_UNICO,
                    RPAD(PAGEXT.PAG_CLASIF_AGENTE,2,' ') AS PAG_CLASIF_AGENTE,
                    SUBSTR(PAGEXT.PAG_FECHA_FACTURA,7,2) || SUBSTR(PAGEXT.PAG_FECHA_FACTURA,5,2) || SUBSTR(PAGEXT.PAG_FECHA_FACTURA,1,4) AS PAG_FECHA_FACTURA,
                    LPAD(FLOOR(CAST(ABS(PAGEXT.DC_IMPORTE30) AS INT)),2,0)||','||LPAD((ABS(MOD(ROUND(PAGEXT.DC_IMPORTE30,2),1)*100)),2,'0') AS IRPF,
                    'EUR' AS MONEDA,

                    --LIQEXT
                    RPAD(LIQ.COD_CONCEPTO,3,' ') AS COD_CONCEPTO,
                    CAST(SUBSTR(LIQ.POSICION_COMERCIAL,1,4) AS VARCHAR(4)) AS OFICINA_GASTO,
                    (CASE WHEN LIQ.PRODUCTO IS NULL OR LIQ.PRODUCTO = '00000' OR LIQ.PRODUCTO = '' THEN LPAD(' ',5) ELSE LIQ.PRODUCTO END) AS PRODUCTO,
                    RPAD(CAST(abs(round(LIQ.IMPORTE,2)) AS INTEGER) || LPAD((ABS(MOD(ROUND(LIQ.IMPORTE,2),1)*100)),2,'0'),16,' ') AS IMPORTE_COMISION,

                    (CASE WHEN LIQ.IMPORTE >= 0 THEN 'D' ELSE 'H' END) AS CARGO_ABONO,              --Correcto AS� Preguntar
                    --RPAD(PAGEXT.PAG_CARGO_O_ABONO,1,' ') AS CARGO_ABONO,                          --NO SE PUEDE USAR ESTO PORQUE TIENE QUE TOMARSE CADA PAGO POR SEPARADO, PUEDE HABER POSITIVOS Y NEGATIVOS

                    --RPAD(' ',1) AS AUTORIZA_FACTURA,                                            --Anadir a la tabla CABECERA_TEMP. Preguntar???
                    --(select distinct ENVIO_SII from EXT.FINAL_EXTRACTPAGOS_FILE_SAP x where x.PER_CIF_NIF = RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ') and x.PERIODSEQ = v_periodRow.PERIODSEQ
                    --) AS AUTORIZA_FACTURA,
                    RPAD(PAGEXT.ENVIO_SII,1,' ') AS AUTORIZA_FACTURA,

                    --RPAD(' ',1) AS ENVIAR_SII_AEAT,                                             --Anadir a la tabla CABECERA_TEMP. Preguntar???
                    --(CASE WHEN (select distinct ENVIO_SII from EXT.FINAL_EXTRACTPAGOS_FILE_SAP x where x.PER_CIF_NIF = RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ') and x.periodseq = v_periodRow.PERIODSEQ) = 'S'
                    --            AND (select distinct SERCO_CANARIAS from EXT.FINAL_EXTRACTPAGOS_FILE_SAP x where x.PER_CIF_NIF = RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ') and x.periodseq = v_periodRow.PERIODSEQ) IS NULL
                    --    THEN 'S'
                    --    ELSE ''
                    --END) AS ENVIAR_SII_AEAT,
                    (CASE WHEN PAGEXT.ENVIO_SII = 'S' AND PAGEXT.SERCO_CANARIAS IS NULL THEN 'S' ELSE ' ' END) AS ENVIAR_SII_AEAT,

                    --RPAD(' ',1) AS ENVIAR_SII_ATC,                                              --Anadir a la tabla CABECERA_TEMP. Preguntar???
                    --(CASE WHEN (select distinct ENVIO_SII from EXT.FINAL_EXTRACTPAGOS_FILE_SAP x where x.PER_CIF_NIF = RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ') and x.periodseq = v_periodRow.PERIODSEQ) = 'S'
                    --            AND (select distinct SERCO_CANARIAS from EXT.FINAL_EXTRACTPAGOS_FILE_SAP x where x.PER_CIF_NIF = RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ') and x.periodseq = v_periodRow.PERIODSEQ) = 'C'
                    --    THEN 'S'
                    --    ELSE ''
                    --END) AS ENVIAR_SII_ATC,                                              --Anadir a la tabla CABECERA_TEMP. Preguntar???
                    (CASE WHEN PAGEXT.ENVIO_SII = 'S' AND PAGEXT.SERCO_CANARIAS = 'C' THEN 'S' ELSE ' ' END) AS ENVIAR_SII_ATC,

                    --PAGEXT
                    RPAD(' ',16) AS PAG_IMPORTE,
                    RPAD(' ',1) AS SIGNO_PAG_IMPORTE,
                    RPAD(' ',16) AS AUT_IMPORTE,
                    RPAD(' ',1) AS SIGNO_AUT_IMPORTE,
                    RPAD(' ',1) AS VIA_PAGO,
                    RPAD(' ',1) AS ESTADO,
                    RPAD(' ',8) AS FECHA_ESTADO,
                    RPAD(' ',24) AS IBAN
                --RMF 20200302: Cambiamos la tabla de origen de TEMP_LIQEXT_CABECERA_FILE a FINAL_LIQEXT_CABECERA_FILE
                --FROM EXT.TEMP_LIQEXT_CABECERA_FILE LIQ
                FROM EXT.FINAL_LIQEXT_CABECERA_FILE LIQ
                --ALM 20191112: Para casos en los que GA2 del Participant no este informado modificamos la union entre PAG y LIQ. Por ejemplo: 23302935W
                --INNER JOIN EXT.FINAL_EXTRACTPAGOS_FILE_SAP PAGEXT ON PAGEXT.PER_CIF_NIF = RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ')
                INNER JOIN EXT.FINAL_EXTRACTPAGOS_FILE PAGEXT ON TRIM(PAGEXT.PER_CIF_NIF) = (CASE WHEN LENGTH(LIQ.DOC_NIF) = 9
                                                                                              THEN SUBSTR(LIQ.DOC_NIF,1,9) ELSE SUBSTR(LIQ.DOC_NIF,2,9) END) 
                    AND PAGEXT.CIA_CODIGO = LIQ.COMPANIA
                    AND SUBSTR(PAGEXT.CONCEP_CODIGO,3,1) = LIQ.TIPODOCUMENTO
                    AND PAGEXT.PAG_OFICINA = SUBSTR(LIQ.POSICION_COMERCIAL,1,4)
                    AND PAGEXT.PAG_AGENTE = SUBSTR(LIQ.POSICION_COMERCIAL,5,6)
                    --AND PAGEXT.PERIODSEQ = v_periodRow.PERIODSEQ
                    AND PAGEXT.PERIODSEQ = LIQ.PERIODSEQ
                    AND TRIM(PAGEXT.PAG_REFERENCIA_ORIGEN) = TRIM(LIQ.PAG_REFERENCIA_ORIGEN)
                WHERE LIQ.DOC_NIF IS NOT NULL
                    --ALM 20191002: Si es la ejecucion inicial de la LC solo devolvemos los pagos generados en la LC (SUBSTR(PAG_REFERENCIA_ORIGEN,2,1) in ('7','8')
                    --ALM 20200303: Ahora se devuelven los GA para todos los diarios, asi que usamos el mismo filtro que en la anterior.
                    --AND (ejecucion_inicial_pagext = 0
                    AND ((v_ejecucion_inicial_pagext > 0 AND PAGEXT.ESTADO IN (7,8,9) AND FECHA_ESTADO > v_fecha_ultimo_pagext)             --las ejecuciones diarias entran por aqui
                        OR (v_ejecucion_inicial_pagext = 0 AND PAGEXT.PERIODSEQ = v_periodSeq                                   --las ejecuciones iniciales entran por aqui
                            --dentro de las ejecuciones iniciales, si es la del LC solo se cogen los pagos generados en ella
                            AND (((v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext) AND SUBSTR(PAGEXT.PAG_REFERENCIA_ORIGEN,2,1) in ('7','8'))
                                --dentro de las ejecuciones iniciales, si NO es la del LC se cogen todos los pagos
                                OR not(v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext))))
                ORDER BY 3,4,1,14,16
            ) PAGOS
        ;
   v_num_rows = RECORD_COUNT(EXT.OUT_EXTRACTPAGOS_INFORME_FILE);
-- SELECT 'SMMGA', 'GA' AS TIPO_REGISTRO,LIQ.DOC_NIF ,LENGTH(LIQ.DOC_NIF) LENGTH_DOC_NIF,RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ')
-- ,PAGEXT.PER_CIF_NIF,LENGTH(PAGEXT.PER_CIF_NIF)
-- ,PAGEXT.PAG_REFERENCIA_ORIGEN , LIQ.PAG_REFERENCIA_ORIGEN
-- --, PAGEXT.PER_CIF_NIF C1,LENGTH(PAGEXT.PER_CIF_NIF) CO1,LIQ.DOC_NIF N1,LENGTH(LIQ.DOC_NIF) CO2
--                 FROM EXT.FINAL_LIQEXT_CABECERA_FILE LIQ
--                 -- INNER JOIN EXT.FINAL_EXTRACTPAGOS_FILE PAGEXT ON PAGEXT.PER_CIF_NIF = (CASE WHEN LENGTH(LIQ.DOC_NIF) = 9
--                 --                                                                               THEN RPAD(SUBSTR(LIQ.DOC_NIF,1,9),10,' ') ELSE RPAD(SUBSTR(LIQ.DOC_NIF,2,9),10,' ') END)
--                 INNER JOIN EXT.FINAL_EXTRACTPAGOS_FILE PAGEXT ON PAGEXT.PER_CIF_NIF = (CASE WHEN LENGTH(LIQ.DOC_NIF) = 9
--                                                                                               THEN SUBSTR(LIQ.DOC_NIF,1,9) ELSE SUBSTR(LIQ.DOC_NIF,2,9) END) 
--                 --     AND PAGEXT.CIA_CODIGO = LIQ.COMPANIA
--                 --     AND SUBSTR(PAGEXT.CONCEP_CODIGO,3,1) = LIQ.TIPODOCUMENTO
--                 --     AND PAGEXT.PAG_OFICINA = SUBSTR(LIQ.POSICION_COMERCIAL,1,4)
--                 --     AND PAGEXT.PAG_AGENTE = SUBSTR(LIQ.POSICION_COMERCIAL,5,6)
--                   AND PAGEXT.PAG_REFERENCIA_ORIGEN = TRIM(LIQ.PAG_REFERENCIA_ORIGEN)
--                 -- WHERE LIQ.DOC_NIF IS NOT NULL
                    
--                 ORDER BY 1;
     
        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Carga de la tabla de OUT_EXTRACTPAGOS_INFORME_FILE: '|| TO_CHAR(v_num_rows) || ' filas.', v_log_count, v_idproceso, 'info'); 

	
        --ALM 20190529: Movemos este update al final para que solo se actualice si acaba bien el proceso.
        --ALM 20191004: Pasamos el update del campo VALOR al final
     IF v_fecha_start_periodo < v_periodSTARTDATE THEN

        UPDATE EXT.CONF_PARAMETROS_FILE
            SET --VALOR = 1,
                F_INICIO = v_periodSTARTDATE
        WHERE NOMBRE = 'FECHA_ULT_EJEC_PAGEXT';

        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' Actualizacion de F_INICIO a ' || v_periodSTARTDATE || ' del parametro FECHA_ULT_EJEC_PAGEXT.', v_log_count, v_idproceso, 'info'); 

        END IF;


        --ALM 20191002: Incluimos una condicion para no actualizar la fecha de la ultima ejecucion del PAGEXT en la ejecucion inicial de la LC.
        --ALM 20191003: Debemos actualizar la fecha porque sino siempre se cumpliria que la ejecucion seria la inicial de la LC
        --ALM 20191004: Actualizamos el campo VALOR si la ultima ejecucion ha sido la inicial del LC a 2 y sino a 1.
        IF (v_conteo_pagos_lc > 1 AND v_fecha_ultimo_pago_lc > v_fecha_ultimo_pagext AND v_ejecucion_inicial_pagext = 0) THEN

            UPDATE EXT.CONF_PARAMETROS_FILE
                SET VALOR = 2
            WHERE NOMBRE = 'FECHA_ULT_EJEC_PAGEXT';

            COMMIT;

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Actualizamos el parametro VALOR a 2 (fin de la ejecucion inicial del LC).', v_log_count, v_idproceso, 'info'); 

        --ALM 20191121: Si es la primera ejecucion del periodo no actualizamos el parametro que guarda la v_fecha_ultimo_pagext para que en la siguiente ejecucion se cojan los posibles pagos confirmados desde el ultimo PAGEXT diario.
        ELSEIF (v_fecha_start_periodo < v_periodSTARTDATE) THEN

            UPDATE EXT.CONF_PARAMETROS_FILE
                SET VALOR = 1
            WHERE NOMBRE = 'FECHA_ULT_EJEC_PAGEXT';

            COMMIT;

            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Actualizamos el parametro VALOR a 1 (fin de la primera ejecucion inicial).', v_log_count, v_idproceso, 'info'); 

        ELSE

            UPDATE EXT.CONF_PARAMETROS_FILE
                SET VALOR = 1,
                    -- F_FIN = TO_DATE(TO_CHAR(FROM_TZ(CAST(sysdate AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS')
                    F_FIN = CURRENT_TIMESTAMP
            WHERE NOMBRE = 'FECHA_ULT_EJEC_PAGEXT';

            COMMIT;

            	-- CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' Actualizacion de VALOR a 1 y F_FIN a ' || TO_CHAR(FROM_TZ(CAST(sysdate AS TIMESTAMP),DBTIMEZONE) AT TIME ZONE 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS') || ' del parametro FECHA_ULT_EJEC_PAGEXT.', v_log_count, v_idproceso, 'info');
            	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' Actualizacion de VALOR a 1 y F_FIN a ' || TO_CHAR(CURRENT_TIMESTAMP) || ' del parametro FECHA_ULT_EJEC_PAGEXT.', v_log_count, v_idproceso, 'info'); 

        END IF;


        --RMF 20190125: UPDATE del parametro PAGEXT_STATUS en CONF_PARAMETROS_FILE a 1
        --ALM 20190617: No usamos este par�tro para la prueba de SAP

        UPDATE EXT.CONF_PARAMETROS_FILE
            SET VALOR = 0
        WHERE NOMBRE = 'PAGEXT_STATUS';

        COMMIT;

        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' Actualizacion parametro PAGEXT_STATUS a 0 ', v_log_count, v_idproceso, 'info'); 
        --	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,' NO actualizamos el parametro PAGEXT_STATUS a 0 en la prueba de SAP ', v_log_count, v_idproceso, 'info'); 

	UPDATE EXT.OUT_BATCH_CONTROL
	SET STATUS = v_const_out_batch_control_ok,
		FILE_NAME = FILENAME,
		TARGET_ROWS = v_num_rows,
		END_DATE = CURRENT_TIMESTAMP
	WHERE  ID_PROCESO = v_idproceso;
		
    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso, 'info'); 

    -- END;

END