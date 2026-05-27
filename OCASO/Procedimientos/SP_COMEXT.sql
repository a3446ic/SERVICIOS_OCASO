CREATE or replace PROCEDURE EXT.SP_COMEXT(OUT FILENAME VARCHAR(120) , IN i_ficheroTXSTA VARCHAR(250), IN i_fecha_cargo VARCHAR(6))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS 
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 26-Marzo-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Generacion datos para el fichero de interface de consolidacion de comisiones en polizas
    | Paquete PL/SQl que nos permite obtener en la tabla OUT_COMEXT_INFORME_FILE
    | el contenido del fichero de Consolidacion porcentaje comisiones en polizas.

    | Para los ficheros de "Emitido diario de nueva produccion" y de "Cartera", se debe enviar un registro 
    | de salida por cada transaccion de entrada.para los ficehros del "Resultado del Cobro" solo vendran 
    | los que se hayan modificado.
    | 
    | Aquellas que no se ha calculado porcentaje de comisiones al generar los creditos, 
    | no se informaran los campos de porcentajes. 
   
    | El importe sera el que aparezca calcualdo en el credito, excepto cuando no se hayan calculado credito ,
    | que se extraera del valor de la transaccion.
    |    
    | Se genera a partir de las transacciones enviadas y los creditos generados en los calculos 
    | Parametros de entrada: 
    | - Nombre del fichero de transacciones (TXSTA)
    | - Fecha de cargo del fichero (Formato YYYYMM)
	|
	| Version: 0.1	SMM 20251505		Initial Version.
	| Version: 0.2	SMM 20251007		Se obtiene el último pipelinerunseq válido y que esté en las transacciones.
	|
    -----------------------------------------------------------------------
*/
BEGIN
	
	-- DECLARACIÓN DE CONSTANTES Y VARIABLES
	DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso INTEGER;
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE = EXT.LIB_CONSTANTES:v_eot; 
	DECLARE v_PeriodSeq BIGINT;
	DECLARE v_PeriodName VARCHAR2(255);
	DECLARE v_PeriodStartDate TIMESTAMP;
	DECLARE v_fechaliquidacion VARCHAR(6);
	DECLARE v_const_out_batch_control_load INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD;
	DECLARE v_const_out_batch_control_ok INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK;
	DECLARE v_const_out_batch_control_error INTEGER := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR;
	DECLARE v_file_name VARCHAR(25) := 'COMEXT';
	DECLARE v_error_code VARCHAR(10);
	DECLARE v_calendar_name VARCHAR2(21) := EXT.LIB_CONSTANTES:CONST_CALENDAR_NAME;
	DECLARE v_hay_error INTEGER := 0;
	
	DECLARE v_posIni INTEGER;
	DECLARE v_posFin INTEGER;
	DECLARE v_tipoficheroTXSTA VARCHAR(250);
	DECLARE v_descTipoFic VARCHAR(250);
	DECLARE v_totalTxnTabla VARCHAR(2);
	DECLARE v_totalTransacciones BOOLEAN;
	DECLARE v_compTipoFic INTEGER;
	DECLARE v_error_track VARCHAR(50);
    DECLARE v_error_msg VARCHAR(500);
    DECLARE v_pipeSeq BIGINT;
    DECLARE v_pipeDate DATE;
    DECLARE v_totalFilas INTEGER;
    DECLARE v_mod_poL INTEGER = 0;
    DECLARE v_mod_rec INTEGER = 0;
    
    
    --TABLA TEMPORAL
    DECLARE TEMP_NOMINA_FILE TABLE (
        CIA VARCHAR(2),
        DNI VARCHAR(11),
        CONCEPTO VARCHAR(6),
        IMPORTE DECIMAL(15,2),
        FCH_INI VARCHAR(6),
        FCH_FIN VARCHAR(6),
        FCH_PAGA VARCHAR(6)
    );
	
	
	--CONTROLADOR DE EXCEPCIONES
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;

        CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
    																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');

        v_num_rows := 0;

        UPDATE EXT.OUT_BATCH_CONTROL
        SET STATUS = v_const_out_batch_control_error,
            END_DATE = CURRENT_TIMESTAMP
        WHERE FILE_NAME = FILENAME
          AND ID_PROCESO = v_idproceso;

        RESIGNAL;
    END;
	
	
	--INICIALIZAMOS IDPROCESO
	SELECT EXT.ID_PROCESO.NEXTVAL INTO v_idproceso FROM DUMMY;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Version: ' || v_version || ' - Procedure starting...' , v_log_count, v_idproceso, 'info');
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Parámetros. i_fechaCargo: ' || i_fecha_cargo , v_log_count, v_idproceso, 'info');
	
	-- SELECCIONAMOS PERIODSEQ
	--SELECT PERIODSEQ, NAME, STARTDATE, TO_CHAR(STARTDATE,'YYYYMM') INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate,v_fechaliquidacion FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
	SELECT per.periodseq, per.name, per.startDate, to_char(per.startDate,'YYYYMM') 
	INTO v_PeriodSeq, v_PeriodName,v_PeriodStartDate,v_fechaliquidacion
    FROM cs_calendar cal   
    JOIN cs_period per ON cal.calendarseq = per.calendarseq
        AND per.removedate = v_eot
        AND TO_DATE(i_fecha_cargo,'YYYYMM')  >= PER.STARTDATE 
        AND ADD_MONTHS(TO_DATE(i_fecha_cargo,'YYYYMM'), -1) <= PER.STARTDATE
        AND TO_DATE(i_fecha_cargo,'YYYYMM')  < PER.ENDDATE 
        AND ADD_MONTHS(TO_DATE(i_fecha_cargo,'YYYYMM'), 1) >= PER.ENDDATE
    WHERE cal.removedate = v_eot     
      AND cal.name = v_calendar_name;
	
	
	--FICHERO DE SALIDA  
    --EJ COMEXT: INYC_COMEXT_PRD_20250326_110753_OCASO_ABLFTP165402P_23pyc.txt_0
    --SELECT v_file_name||TO_VARCHAR(v_PeriodStartDate, 'YYYYMMDD')||'_'||TO_VARCHAR(CURRENT_TIME, 'HH24MISS')||'_OCASO_ABLFTP165402P.txt' INTO FILENAME FROM dummy;
    SELECT REPLACE(i_ficheroTXSTA,'TXSTA','COMEXT') INTO FILENAME FROM DUMMY;
	
	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FICHERO DE SALIDA ' || FILENAME, v_log_count, v_idproceso, 'info');      
	
	BEGIN
		--REGISTRO OUT_BATCH_CONTROL
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_idproceso,FILENAME,::CURRENT_OBJECT_NAME,0,EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD,CURRENT_TIMESTAMP,NULL);
		COMMIT;
	END;

    
    BEGIN
	
  
    
       
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Parámetros: Fichero TXSTA: "' || i_ficheroTXSTA || '" - Fecha Cargo (YYYYMM): ' || v_fechaliquidacion , v_log_count, v_idproceso, 'info');     

        ----------------------------------------------------
        -- PERIODO
        ----------------------------------------------------

        -- Obtenemos el periodo anadiendo el dia 01 a la fecha de cargo. Se genera error si no es una fecha correcta 

        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Periodo asociado a : ' || v_PeriodStartDate || ' : ' || v_PeriodName || ' periodseq: ' ||  TO_CHAR(v_PeriodSeq) , v_log_count, v_idproceso, 'info');     



        ----------------------------------------------------
        -- Borrado Tablas auxiliares
        ----------------------------------------------------
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Borrado Tablas auxiliares'  , v_log_count, v_idproceso, 'info');     

          -- Se borran tablas auxiliares
          EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.FINAL_COMEXT_FILE';
          EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.OUT_COMEXT_INFORME_FILE';
          COMMIT;
          
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Fin Borrado Tablas auxiliares'  , v_log_count, v_idproceso, 'info');     

        ----------------------------------------------------
        -- EXTRACCION DE TIPO DE FICHERO TXSTA
        ----------------------------------------------------
        -- Se cargan los datos del tipo de fichero de la clasificacion 'Tipos ficheros'
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Inicio carga de tipos de ficheros en TEMP_COMEXT_TIPOS_FICHEROS_FILE ', v_log_count, v_idproceso, 'info');     
        TEMP_COMEXT_TIPOS_FICHEROS_FILE = 
            SELECT  c.NAME CLAVEFICHERO,  
                    c.DESCRIPTION DESCRIPCION, 
                    GC.GENERICATTRIBUTE1 TOTALTRANSACCIONES
            FROM CS_CLASSIFIER c 
                inner JOIN CS_GENERICCLASSIFIER gc ON C.CLASSIFIERSEQ=GC.CLASSIFIERSEQ AND 
                                                      gc.REMOVEDATE  = to_date('22000101','yyyymmdd')  AND gc.islast=1
                inner JOIN CS_CATEGORY_CLASSIFIERS ccc ON  ccc.CLASSIFIERSEQ = c.CLASSIFIERSEQ AND 
                                                            CCC.REMOVEDATE= to_date('22000101','yyyymmdd') AND CCC.ISLAST=1
                inner JOIN CS_CATEGORYTREE ct ON CCC.CATEGORYTREESEQ=CT.CATEGORYTREESEQ AND 
                                                 ct.REMOVEDATE= to_date('22000101','yyyymmdd') AND ct.ISLAST=1
            WHERE CT.NAME='Tipos Ficheros' AND 
                  c.REMOVEDATE= to_date('22000101','yyyymmdd') AND c.ISLAST=1
        ;

        v_num_rows = RECORD_COUNT(:TEMP_COMEXT_TIPOS_FICHEROS_FILE);
        COMMIT;
        
        
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Fin carga de tipos de ficheros en TEMP_COMEXT_TIPOS_FICHEROS_FILE - ' || v_num_rows || ' filas' , v_log_count, v_idproceso, 'info');     
    
        -- Formato nombre TXSTA :INYC_TXSTA_PRD_20160426_104306_OCASO_OBFTP165302S_218wv.txt
        -- Buscamos posicion del 6º y 7º caracter '_' entre los que esta el tipo de fichero  
        v_posIni := INSTR(i_ficheroTXSTA, '_', 1, 1) + 1;
        v_posFin := INSTR(i_ficheroTXSTA, '_', 1, 2);

        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Variables tipo Ficheros: v_posIni= ' || v_posIni || ', v_posFin= ' || v_posFin , v_log_count, v_idproceso, 'info');     

        IF ( v_posFin > v_posIni ) then
            v_tipoficheroTXSTA := substr(i_ficheroTXSTA,v_posIni, v_posFin - v_posIni );
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Variables tipo Ficheros: v_tipoficheroTXSTA= ' ||v_tipoficheroTXSTA , v_log_count, v_idproceso, 'info');     


            --ALM 20180511: Creamos una nueva varaible para la comprobacion
            SELECT count(totalTransacciones) INTO v_compTipoFic FROM :TEMP_COMEXT_TIPOS_FICHEROS_FILE WHERE CLAVEFICHERO=v_tipoficheroTXSTA;

            --ALM 20180511: Una vez sabemos si el fichero tiene correspondencia o no lo buscamos en la tabla correspondiente
            IF v_compTipoFic > 0 then
                SELECT UPPER(totalTransacciones), DESCRIPCION 
                INTO  v_totalTxnTabla, v_descTipoFic 
                FROM :TEMP_COMEXT_TIPOS_FICHEROS_FILE WHERE CLAVEFICHERO=v_tipoficheroTXSTA;
            ELSE
                --ALM 20180219: Anadimos el caso de ficheros no registrados en la clasificacion para que devuelvan todos los registros de entrada por defecto.
                v_descTipoFic := 'Tipo no encontrado';
                v_totalTxnTabla := 'SI';
            END IF;


            IF v_totalTxnTabla='SI' then
                v_totalTransacciones := true;  -- SI Se envian todas las transacciones : "Emitido diario de nueva produccion" y de "Cartera"
            ELSE
                v_totalTransacciones := false;  -- NO Se envian todas las transacciones : "Cobros"        
            END IF;

            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Extraccion Tipo Fichero : ' || v_tipoficheroTXSTA || ' - ' || v_descTipoFic || ' Incluir total transacciones: ' || v_totalTxnTabla, v_log_count, v_idproceso, 'info');     

        ELSE
            v_tipoficheroTXSTA := '';
            v_descTipoFic := 'Tipo no encontrado';
            --ALM 20180208: Modificamos a true para que se devuelvan todos los registros de entrada por defecto. 
            --v_totalTransacciones := false;    
            v_totalTransacciones := true;    
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Extraccion Tipo Fichero : no definido. Se incluye el total de transacciones' , v_log_count, v_idproceso, 'info');     

        END IF;
    


        ----------------------------------------------------
        -- EXTRACCION DE DATOS TEMPORALES
        ----------------------------------------------------
        v_error_track :='CS_PLRUN';
        -- se buscan transacciones asociadas a fichero
        -- Se determina la ultima carga correcta del fichero
        
        IF NOT EXISTS(SELECT 1 FROM CS_PLRUN p 
        	INNER JOIN CS_SALESTRANSACTION saltx ON p.PIPELINERUNSEQ = saltx.PIPELINERUNSEQ
        	WHERE command='Import' 
        	--Filtramos por la sequencia de ejecucion que indica la carga del fichero, asi evitamos que se coja el purgado del mismo
        		AND runparameters LIKE '%[Sequence]ValidateAndTransfer%' 
        		AND BATCHNAME =i_ficheroTXSTA 
        		AND UPPER(STATUS)='SUCCESSFUL' ) THEN
        	
        	v_hay_error := 1;
        	v_error_code := 'E002';
        	v_num_rows :=0;
        ELSE
        
        	SELECT DISTINCT p.PIPELINERUNSEQ, p.datesubmitted INTO v_pipeSeq, v_pipeDate 
        	FROM CS_PLRUN p 
        		INNER JOIN CS_SALESTRANSACTION saltx ON p.PIPELINERUNSEQ = saltx.PIPELINERUNSEQ
        	WHERE command='Import' 
        	--Filtramos por la sequencia de ejecucion que indica la carga del fichero, asi evitamos que se coja el purgado del mismo
        		AND runparameters LIKE '%[Sequence]ValidateAndTransfer%' 
        		AND BATCHNAME =i_ficheroTXSTA 
        		AND UPPER(STATUS)='SUCCESSFUL' 
        	ORDER BY datesubmitted DESC
        	LIMIT 1;
	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' Pipeline de carga: ' || v_pipeSeq || ' Fecha Carga txsta:' || to_char(v_pipeDate,'YYYY-MM-DD HH24:MI:SS') , v_log_count, v_idproceso, 'info');    
        	
        	----------------------------------------------------
        	--  TRANSACCIONES
        	--  CS_SALESTRANSACTION (SALTX) 
        	----------------------------------------------------
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Filtro de TRANSACCIONES - TEMP_COMEXT_TXN_FILE ', v_log_count, v_idproceso, 'info');    
        	TEMP_COMEXT_TXN_FILE = 
        	    SELECT
        	        saltx.TENANTID,
        	        saltx.SALESORDERSEQ,
        	        saltx.SALESTRANSACTIONSEQ,            
        	        saltx.LINENUMBER,
        	        saltx.SUBLINENUMBER,
        	        saltx.EVENTTYPESEQ,
        	        saltx.COMPENSATIONDATE,
        	        saltx.NATIVECURRENCYAMOUNT,
        	        saltx.DISCOUNTPERCENT,
        	        saltx.GENERICATTRIBUTE13,
        	        saltx.GENERICATTRIBUTE14,
        	        saltx.GENERICDATE1,            
        	        saltx.PIPELINERUNSEQ,
        	        ta.POSITIONNAME,
        	        ta.GenericAttribute3 as COD_HOST
        	    FROM CS_SALESTRANSACTION saltx
        	    INNER JOIN CS_TRANSACTIONASSIGNMENT ta ON saltx.SALESTRANSACTIONSEQ = ta.SALESTRANSACTIONSEQ
        	    WHERE saltx.TENANTID = v_idtenant AND
        	          saltx.PIPELINERUNSEQ = v_pipeSeq
        	    ;
	
        	v_num_rows = RECORD_COUNT(:TEMP_COMEXT_TXN_FILE);
        	-- COMMIT;
	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FIN Filtro de TRANSACCIONES - TEMP_COMEXT_TXN_FILE : '|| v_num_rows || ' filas.' , v_log_count, v_idproceso, 'info');    
    	
        	IF v_num_rows = 0 THEN
        		v_hay_error := 1;
        		v_error_code := 'E001';
	    	 END IF;
	
        	----------------------------------------------------
        	--  TRANSACCIONES
        	--  CS_SALESORDER  (SLORD) y TXN_TEMP
        	----------------------------------------------------
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Filtro de ORDENES DE TXN - TEMP_COMEXT_TXNORDER_FILE ', v_log_count, v_idproceso, 'info');    
        	
        	TEMP_COMEXT_TXNORDER_FILE =
        	  SELECT -- INDEX(TEMP_COMEXT_TXN_FILE TEMP_COMEXT_TXN_FILE_IX1) 
        	        saltx.TENANTID,            
        	        saltx.SALESORDERSEQ,
        	        saltx.SALESTRANSACTIONSEQ,
        	        slord.ORDERID,
        	        saltx.LINENUMBER,
        	        saltx.SUBLINENUMBER,
        	        saltx.EVENTTYPESEQ,
        	        saltx.COMPENSATIONDATE,
        	        saltx.NATIVECURRENCYAMOUNT,
        	        saltx.DISCOUNTPERCENT,
        	        saltx.GENERICATTRIBUTE13,
        	        saltx.GENERICATTRIBUTE14,
        	        saltx.GENERICDATE1,
        	        saltx.PIPELINERUNSEQ,
        	        saltx.POSITIONNAME,
        	        saltx.COD_HOST
        	    FROM :TEMP_COMEXT_TXN_FILE saltx 
        	    INNER JOIN CS_SALESORDER slord   ON saltx.SALESORDERSEQ = slord.SALESORDERSEQ AND 
        	                                                saltx.TENANTID = v_idtenant  
        	    WHERE slord.TENANTID = v_idtenant AND 
        	          slord.REMOVEDATE = v_eot
        	;
        	v_num_rows = RECORD_COUNT(:TEMP_COMEXT_TXNORDER_FILE);   
        	-- COMMIT;
	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Filtro de ORDENES DE TXN - TEMP_COMEXT_TXNORDER_FILE : '|| to_char(v_num_rows) || ' filas.' , v_log_count, v_idproceso, 'info');    
	
        	----------------------------------------------------
        	--  CREDITOS
        	--  CS_CREDIT (CREDIT) : Se filtran los creditos que se van a tratar
        	----------------------------------------------------
	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Inicio Filtro de CREDITOS - TEMP_COMEXT_CREDIT_FILE '  , v_log_count, v_idproceso, 'info');    
        	IF v_totalTransacciones = TRUE then
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Filtro de CREDITOS - Todos los creditos de Comisiones '  , v_log_count, v_idproceso, 'info');    
	
        	    TEMP_COMEXT_CREDIT_FILE =
        	    	SELECT 
	    	            credit.TENANTID,
	    	            credit.CREDITSEQ,
	    	            credit.SALESORDERSEQ,
	    	            credit.SALESTRANSACTIONSEQ,
	    	            credit.PERIODSEQ,
	    	            credit.PIPELINERUNSEQ,
	    	            credit.PIPELINERUNDATE,
	    	            credit.VALUE,
	    	            credit.UNITTYPEFORVALUE,
	    	            credit.GENERICATTRIBUTE8,
	    	            credit.GENERICNUMBER3,
	    	            credit.UNITTYPEFORGENERICNUMBER3,
	    	            credit.GENERICNUMBER6,
	    	            credit.UNITTYPEFORGENERICNUMBER6,
	    	            credit.GENERICDATE2,
	    	            credit.GENERICBOOLEAN2,
	    	            ctype.CREDITTYPEID
	    	        FROM CS_CREDIT credit
	    	            INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ AND
	    	                                         ctype.TENANTID = v_idtenant AND 
	    	                                         ctype.REMOVEDATE  = v_eot AND
	    	                                         ctype.CREDITTYPEID IN ( 'Comision Nueva Produccion','Comision Candidatos', 
	    	                                                                 'Comision Cartera', 'Comision Conservacion','Comision Recuperacion',
	    	                                                                 --ALM 20190226: Anadimos tipologias para los creditos de Autoliquidacion
	    	                                                                 'Comision Nueva Produccion-AUT','Comision Candidatos-AUT', 
	    	                                                                 'Comision Cartera-AUT', 'Comision Conservacion-AUT','Comision Recuperacion-AUT'
																			 --TGV 20260331: Se añaden las tipologias N por peticion de David Rubio
																			 ,'Comision Conservacion N', 'Comision Nueva Produccion N', 'Comisiones Cartera Agentes de Zona N')  
	    	        WHERE
	    	            credit.TENANTID = v_idtenant AND 
	    	            credit.PERIODSEQ =  v_PeriodSeq
	    	      ;
	
        	ELSE
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name,'Filtro de CREDITOS - Solo creditos de Comisiones marcados para enviar'  , v_log_count, v_idproceso, 'info');  
	
        	    TEMP_COMEXT_CREDIT_FILE =
        	    	SELECT 
        	    	    credit.TENANTID,
        	    	    credit.CREDITSEQ,
        	    	    credit.SALESORDERSEQ,
        	    	    credit.SALESTRANSACTIONSEQ,
        	    	    credit.PERIODSEQ,
        	    	    credit.PIPELINERUNSEQ,
        	    	    credit.PIPELINERUNDATE,
        	    	    credit.VALUE,
        	    	    credit.UNITTYPEFORVALUE,
        	    	    credit.GENERICATTRIBUTE8,
        	    	    credit.GENERICNUMBER3,
        	    	    credit.UNITTYPEFORGENERICNUMBER3,
        	    	    credit.GENERICNUMBER6,
        	    	    credit.UNITTYPEFORGENERICNUMBER6,
        	    	    credit.GENERICDATE2,
        	    	    credit.GENERICBOOLEAN2,
        	    	    ctype.CREDITTYPEID
        	    	FROM CS_CREDIT credit
        	    	    INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ AND
        	    	                                 ctype.TENANTID = v_idtenant AND 
        	    	                                 ctype.REMOVEDATE  = v_eot AND
        	    	                                 ctype.CREDITTYPEID IN ( 'Comision Nueva Produccion','Comision Candidatos', 
        	    	                                                         'Comision Cartera', 'Comision Conservacion','Comision Recuperacion',
        	    	                                                         --ALM 20190226: Anadimos tipologias para los creditos de Autoliquidacion
        	    	                                                         'Comision Nueva Produccion-AUT','Comision Candidatos-AUT', 
        	    	                                                         'Comision Cartera-AUT', 'Comision Conservacion-AUT','Comision Recuperacion-AUT'
																			 --TGV 20260331: Se añaden las tipologias N por peticion de David Rubio
																			 , 'Comision Conservacion N', 'Comision Nueva Produccion N', 'Comisiones Cartera Agentes de Zona N')    
        	    	WHERE
        	    	    credit.TENANTID = v_idtenant AND 
        	    	    credit.PERIODSEQ =  v_PeriodSeq AND
        	    	    credit.GENERICBOOLEAN2 = 1 -- Creditos Marcados para enviar
        	    	;
	
        	END IF;        
	
        	v_num_rows = RECORD_COUNT(:TEMP_COMEXT_CREDIT_FILE);   
--      	   COMMIT;
	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin Filtro Creditos TEMP_COMEXT_CREDIT_FILE : '|| to_char(v_num_rows) || ' filas.' , v_log_count, v_idproceso, 'info');    
	
    	
        	----------------------------------------------------
        	--  TEMPORAL
        	--  JOIN CREDIT_TEMP y TXNORDER_TEMP
        	----------------------------------------------------
	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio TEMP_COMEXT_FILE : JOIN CREDITOS y TRANSACCIONES', v_log_count, v_idproceso, 'info');    
        	IF v_totalTransacciones = TRUE then
        	    --  TEMP_COMEXT_FILE: Se extraen los datos del total de transacciones del fichero solicitado      
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' TEMP_COMEXT_FILE (LEFT JOIN) : TOTAL DE TRANSACCIONES', v_log_count, v_idproceso, 'info');             
        	    TEMP_COMEXT_FILE =
        	        SELECT txtmp.ORDERID, 
        	            txtmp.LINENUMBER,
        	            txtmp.SUBLINENUMBER,
        	            etype.EVENTTYPEID,
        	            cretmp.CREDITTYPEID,
        	            -- cretmp.GENERICDATE2,   v3.1 
        	            case WHEN cretmp.GENERICDATE2 is null THEN  TXTMP.GENERICDATE1 ELSE cretmp.GENERICDATE2 END as GENERICDATE2,
        	            case WHEN cretmp.VALUE is null or abs(cretmp.GENERICNUMBER3)> 0  THEN cretmp.GENERICNUMBER3 ELSE 0  END as GENERICNUMBER3,
        	            cretmp.GENERICATTRIBUTE8,
        	            case WHEN cretmp.VALUE is null or abs(cretmp.GENERICNUMBER6)> 0  THEN cretmp.GENERICNUMBER6 ELSE 0  END as GENERICNUMBER6,
        	            cretmp.GENERICBOOLEAN2,
        	            cretmp.VALUE,
        	            NATIVECURRENCYAMOUNT,
        	            DISCOUNTPERCENT,
        	            GENERICATTRIBUTE13,
        	            GENERICATTRIBUTE14,
        	            cretmp.PIPELINERUNDATE,
        	            txtmp.POSITIONNAME,
        	            txtmp.COD_HOST
        	          FROM :TEMP_COMEXT_TXNORDER_FILE txtmp
        	          INNER JOIN  CS_EVENTTYPE etype ON txtmp.EVENTTYPESEQ = etype.DATATYPESEQ AND
        	                                etype.TENANTID = v_idtenant AND 
        	                                etype.REMOVEDATE  = v_eot
        	          LEFT JOIN :TEMP_COMEXT_CREDIT_FILE cretmp  ON cretmp.SALESTRANSACTIONSEQ = txtmp.SALESTRANSACTIONSEQ
        	          WHERE txtmp.TENANTID = v_idtenant
        	    ;
        	ELSE
        	    --  TEMP_COMEXT_FILE: Se extraen los datos de las transacciones asociadas a los creditos modificados
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, ' TEMP_COMEXT_FILE (INNER JOIN) : SOLO TRANSACCIONES CON CREDITOS MODIFICADOS', v_log_count, v_idproceso, 'info');    
        	    TEMP_COMEXT_FILE =
        	        SELECT txtmp.ORDERID, 
        	            txtmp.LINENUMBER,
        	            txtmp.SUBLINENUMBER,
        	            etype.EVENTTYPEID,
        	            cretmp.CREDITTYPEID,
        	            cretmp.GENERICDATE2,
        	            case WHEN cretmp.VALUE is null or abs(cretmp.GENERICNUMBER3)> 0  THEN cretmp.GENERICNUMBER3 ELSE 0  END as GENERICNUMBER3,
        	            cretmp.GENERICATTRIBUTE8,
        	            case WHEN cretmp.VALUE is null or abs(cretmp.GENERICNUMBER6)> 0  THEN cretmp.GENERICNUMBER6 ELSE 0  END as GENERICNUMBER6,
        	            cretmp.GENERICBOOLEAN2,
        	            cretmp.VALUE,
        	            NATIVECURRENCYAMOUNT,
        	            DISCOUNTPERCENT,
        	            GENERICATTRIBUTE13,
        	            GENERICATTRIBUTE14,
        	            cretmp.PIPELINERUNDATE,
        	            txtmp.POSITIONNAME,
        	            txtmp.COD_HOST
        	        FROM :TEMP_COMEXT_CREDIT_FILE cretmp
        	          INNER JOIN :TEMP_COMEXT_TXNORDER_FILE txtmp   ON cretmp.SALESTRANSACTIONSEQ = txtmp.SALESTRANSACTIONSEQ AND
        	                                                    txtmp.TENANTID = v_idtenant
        	          INNER JOIN  CS_EVENTTYPE etype ON txtmp.EVENTTYPESEQ = etype.DATATYPESEQ AND
        	                                etype.TENANTID = v_idtenant AND 
        	                                etype.REMOVEDATE  = v_eot;
        	END IF;
	
        	v_num_rows = RECORD_COUNT(:TEMP_COMEXT_FILE);   
        	-- COMMIT;
    	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin TEMP_COMEXT_FILE '|| to_char(v_num_rows) || ' filas.' , v_log_count, v_idproceso, 'info');    
	
    	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio FINAL_COMEXT_FILE', v_log_count, v_idproceso, 'info');    
        	v_totalFilas := 0;
	
        	 --INCLUIMOS LOS REGISTROS CON CREDITOS PARA ENVIAR GB2=1
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FINAL_COMEXT_FILE - Inicio Registros con creditos para enviar GB2=1', v_log_count, v_idproceso, 'info');    
        	INSERT INTO EXT.FINAL_COMEXT_FILE (ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,CREDITTYPEID,GENERICDATE2,PC_GESTION,MOD_GEST,PC_CONSERVACION2,MOD_CONS2,PC_CONSERVACION,MOD_CONS
     		    ,PC_CARTERA,MOD_CARTERA,PC_COBRO,MOD_COBRO,IMPORTE,COD_HOST,POSITIONNAME,MOD_POL,MOD_REC)
        	SELECT distinct
        	    ORDERID                                                                                              as ORDERID,
        	    LINENUMBER                                                                                           as LINENUMBER,
        	    SUBLINENUMBER                                                                                        as SUBLINENUMBER,
        	    EVENTTYPEID                                                                                          as EVENTTYPEID,
        	    CREDITTYPEID                                                                                         as CREDITTYPEID,
        	    GENERICDATE2                                                                                         as FECHA_EFECTO,
        	    case CREDITTYPEID  WHEN 'Comision Nueva Produccion'      THEN GENERICNUMBER3   
        	                      WHEN 'Comision Candidatos'            THEN GENERICNUMBER3
        	                      --ALM 20190226: Anadimos tipologias para los creditos de Autoliquidacion
        	                      WHEN 'Comision Nueva Produccion-AUT'  THEN GENERICNUMBER3   
        	                      WHEN 'Comision Candidatos-AUT'        THEN GENERICNUMBER3
								 --TGV 20260331: Se añaden las tipologias N por peticion de David Rubio
								  WHEN 'Comision Nueva Produccion N'    THEN GENERICNUMBER3
        	                                                            ELSE 0 END                                  as PC_GESTION,
        	    case CREDITTYPEID  WHEN 'Comision Nueva Produccion'      THEN 1   
        	                      WHEN 'Comision Candidatos'            THEN 1
        	                      --ALM 20190226: Anadimos tipologias para los creditos de Autoliquidacion
        	                      WHEN 'Comision Nueva Produccion-AUT'  THEN 1   
        	                      WHEN 'Comision Candidatos-AUT'        THEN 1
								--TGV 20260331: Se añaden las tipologias N por peticion de David Rubio
								  WHEN 'Comision Nueva Produccion N'    THEN 1
        	                                                            ELSE 0 END                                  as MOD_GEST,
        	    DISCOUNTPERCENT                                                                                      as PC_CONSERVACION2,   
        	    TO_NUMBER(IFNULL(GENERICATTRIBUTE14,0))                                                                 as MOD_CONS2,
        	    case GENERICATTRIBUTE8 WHEN '1' THEN  GENERICNUMBER6 ELSE 0   END                                    as PC_CONSERVACION,
        	    case GENERICATTRIBUTE8 WHEN '1' THEN  1              ELSE 0   END                                    as MOD_CONS,
        	    case GENERICATTRIBUTE8 WHEN '3' THEN  GENERICNUMBER6 ELSE 0   END                                    as PC_CARTERA,
        	    case GENERICATTRIBUTE8 WHEN '3' THEN  1              ELSE 0   END                                    as MOD_CARTERA,
        	    case GENERICATTRIBUTE8 WHEN '2' THEN  GENERICNUMBER6 ELSE 0   END                                    as PC_COBRO,
        	    case GENERICATTRIBUTE8 WHEN '2' THEN  1              ELSE 0   END                                    as MOD_COBRO,
        	    VALUE                                                                                                as IMPORTE,
        	    COD_HOST																							 as COD_HOST,
        	    POSITIONNAME																						 as POSITIONNAME,
        	    v_mod_pol																							 as MOD_POL,
        	    v_mod_rec																							 as MOD_REC
        	FROM :TEMP_COMEXT_FILE ctmp 
        	WHERE ctmp.GENERICBOOLEAN2 = 1;
	
        	v_num_rows = RECORD_COUNT(EXT.FINAL_COMEXT_FILE);
        	-- COMMIT;
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FINAL_COMEXT_FILE - Fin Registros con creditos para enviar GB2=1 '|| to_char(v_num_rows) || ' filas.' , v_log_count, v_idproceso, 'info');    
        	v_totalFilas := v_totalFilas + v_num_rows;
	
        	IF v_totalTransacciones = TRUE then      
	
        	    --INCLUIMOS LOS REGISTROS CON CREDITOS GB2=0
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FINAL_COMEXT_FILE - Inicio Registros con creditos GB2=0', v_log_count, v_idproceso, 'info');    
        	    INSERT INTO EXT.FINAL_COMEXT_FILE (ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,CREDITTYPEID,GENERICDATE2,PC_GESTION,MOD_GEST,PC_CONSERVACION2,MOD_CONS2,PC_CONSERVACION,MOD_CONS
     		    	,PC_CARTERA,MOD_CARTERA,PC_COBRO,MOD_COBRO,IMPORTE,COD_HOST,POSITIONNAME,MOD_POL,MOD_REC)
        	        SELECT distinct
        	            ORDERID                                                                                              as ORDERID,
        	            LINENUMBER                                                                                           as LINENUMBER,
        	            SUBLINENUMBER                                                                                        as SUBLINENUMBER,
        	            EVENTTYPEID                                                                                          as EVENTTYPEID,
        	            CREDITTYPEID                                                                                         as CREDITTYPEID,
        	            GENERICDATE2                                                                                         as FECHA_EFECTO,
        	            0                                                                                                    as PC_GESTION,
        	            0                                                                                                    as MOD_GEST,
        	            DISCOUNTPERCENT                                                                                      as PC_CONSERVACION2,   
        	            TO_NUMBER(IFNULL(GENERICATTRIBUTE14,0))                                                                 as MOD_CONS2,
        	            0                                                                                                    as PC_CONSERVACION,
        	            0                                                                                                    as MOD_CONS,
        	            0                                                                                                    as PC_CARTERA,
        	            0                                                                                                    as MOD_CARTERA,
        	            0                                                                                                    as PC_COBRO,
        	            0                                                                                                    as MOD_COBRO,
        	            VALUE                                                                                                as IMPORTE,
        	            COD_HOST																							 as COD_HOST,
        	    		POSITIONNAME																						 as POSITIONNAME,
        	    		v_mod_pol																							 as MOD_POL,
        	    		v_mod_rec																							 as MOD_REC
        	    FROM :TEMP_COMEXT_FILE ctmp 
        	    WHERE ctmp.GENERICBOOLEAN2 = 0;
        	
        	    v_num_rows = RECORD_COUNT(EXT.FINAL_COMEXT_FILE);
        	    -- COMMIT;
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FINAL_COMEXT_FILE - Fin Registros creditos GB2=0 '|| to_char(v_num_rows) || ' filas.' , v_log_count, v_idproceso, 'info');    
        	    v_totalFilas := v_totalFilas + v_num_rows;
	
	
        	    --INCLUIMOS LOS REGISTROS SIN CREDITOS GB2 is NULL
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FINAL_COMEXT_FILE - Inicio Registros sin creditos GB2 is Null', v_log_count, v_idproceso, 'info');    
        	    INSERT INTO EXT.FINAL_COMEXT_FILE (ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,CREDITTYPEID,GENERICDATE2,PC_GESTION,MOD_GEST,PC_CONSERVACION2,MOD_CONS2,PC_CONSERVACION,MOD_CONS
     		    ,PC_CARTERA,MOD_CARTERA,PC_COBRO,MOD_COBRO,IMPORTE,COD_HOST,POSITIONNAME,MOD_POL,MOD_REC)
        	        SELECT distinct
        	            ORDERID                                                                                              as ORDERID,
        	            LINENUMBER                                                                                           as LINENUMBER,
        	            SUBLINENUMBER                                                                                        as SUBLINENUMBER,
        	            EVENTTYPEID                                                                                          as EVENTTYPEID,
        	            CREDITTYPEID                                                                                         as CREDITTYPEID,
        	            GENERICDATE2                                                                                         as FECHA_EFECTO,
        	            0                                                                                                    as PC_GESTION,
        	            0                                                                                                    as MOD_GEST,
        	            COALESCE(DISCOUNTPERCENT,0.0000000000)                                                                                      as PC_CONSERVACION2,   
        	            TO_NUMBER(IFNULL(GENERICATTRIBUTE14,0))                                                                 as MOD_CONS2,
        	            0                                                                                                    as PC_CONSERVACION,
        	            0                                                                                                    as MOD_CONS,
        	            0                                                                                                    as PC_CARTERA,
        	            0                                                                                                    as MOD_CARTERA,
        	            0                                                                                                    as PC_COBRO,
        	            0                                                                                                    as MOD_COBRO,
        	            IFNULL(NATIVECURRENCYAMOUNT, 0)                                                                      as IMPORTE,
        	            COD_HOST																							 as COD_HOST,
        	    		POSITIONNAME																						 as POSITIONNAME,
        	    		v_mod_pol																							 as MOD_POL,
        	    		v_mod_rec																							 as MOD_REC
        	    FROM :TEMP_COMEXT_FILE ctmp 
        	    WHERE ctmp.GENERICBOOLEAN2 is null;
	
        	    v_num_rows = RECORD_COUNT(EXT.FINAL_COMEXT_FILE);
        	    -- COMMIT;
        	    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'FINAL_COMEXT_FILE - Fin Registros sin creditos GB2 is Null '|| to_char(v_num_rows) || ' filas.' , v_log_count, v_idproceso, 'info');    
        	    v_totalFilas := v_totalFilas + v_num_rows;
	
        	END IF;
	
        	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin FINAL_COMEXT_FILE. Total Filas '|| to_char(v_totalFilas) || ' filas.' , v_log_count, v_idproceso, 'info');    
	
        	CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Inicio OUT_COMEXT_INFORME_FILE', v_log_count, v_idproceso, 'info');    
        	     
        	     
        	     
        	INSERT INTO EXT.OUT_COMEXT_INFORME_FILE ( 
        	    SELECT RPAD(ORDERID,40,' ') || 
        	            LPAD(LINENUMBER, 16,'0') || 
        	            LPAD(SUBLINENUMBER, 16,'0') || 
        	            RPAD(EVENTTYPEID, 40,' ')   ||
        	            CASE WHEN GENERICDATE2 is null then '000000' ELSE  TO_CHAR(GENERICDATE2,'YYYYMM') END ||
        	            CASE WHEN PC_GESTION >= 0 THEN '+' ELSE '-' END || LPAD(floor(abs(PC_GESTION*100)),3,'0') ||','|| LPAD(( abs(mod(PC_GESTION*100,1)*100) ),2,'0') ||
        	            MOD_GEST ||
        	            CASE WHEN COALESCE(PC_CONSERVACION2,0) >= 0 THEN '+' ELSE '-' END || LPAD(floor(abs(COALESCE(PC_CONSERVACION2,0)*100)),3,'0') ||','|| LPAD(( abs(mod(COALESCE(PC_CONSERVACION2,0)*100,1)*100) ),2,'0') ||
        	            MOD_CONS2 ||
        	            CASE WHEN COALESCE(PC_CONSERVACION,0) >= 0 THEN '+' ELSE '-' END || LPAD(floor(abs(COALESCE(PC_CONSERVACION,0)*100)),3,'0') ||','|| LPAD(( abs(mod(COALESCE(PC_CONSERVACION,0)*100,1)*100) ),2,'0') ||
        	            MOD_CONS ||
        	            CASE WHEN COALESCE(PC_CARTERA,0) >= 0 THEN '+' ELSE '-' END || LPAD(floor(abs(COALESCE(PC_CARTERA,0)*100)),3,'0') ||','|| LPAD(( abs(mod(COALESCE(PC_CARTERA,0)*100,1)*100) ),2,'0') ||
        	            MOD_CARTERA ||
        	            CASE WHEN COALESCE(PC_COBRO,0) >= 0 THEN '+' ELSE '-' END || LPAD(floor(abs(COALESCE(PC_COBRO,0)*100)),3,'0') ||','|| LPAD(( abs(mod(COALESCE(PC_COBRO,0)*100,1)*100) ),2,'0') ||
        	            MOD_COBRO ||
        	            CASE WHEN COALESCE(IMPORTE,0) >= 0 THEN '+' ELSE '-' END || LPAD(floor(abs(COALESCE(IMPORTE,0))),9,'0') ||','|| LPAD(( abs(mod(COALESCE(IMPORTE,0),1)*100) ),2,'0') ||
        	            --',' || COD_HOST || ',' || POSITIONNAME || ',' || MOD_POL || ',' || MOD_REC
        	           RPAD(COD_HOST,10,0) || RPAD(POSITIONNAME,13,' ') || MOD_POL || MOD_REC
        	    FROM EXT.FINAL_COMEXT_FILE
        	  );
	
        	v_num_rows = RECORD_COUNT(EXT.OUT_COMEXT_INFORME_FILE);
        	-- COMMIT;
        END IF;
       
        CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'Fin OUT_COMEXT_INFORME_FILE '|| to_char(v_num_rows) || ' filas.' , v_log_count, v_idproceso, 'info');   

        
        ----------------------------------------------------
        --  FIN DEL PROCEDIMIENTO
        ----------------------------------------------------

        IF v_hay_error = 1 THEN
    
	    	IF :v_error_code = 'E001' THEN
	    		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error: No se han encontrado transacciones asociadas al fichero', v_log_count, v_idproceso, 'error');
	    	END IF;
	    	
	    	IF :v_error_code = 'E002' THEN
	    		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name , 'Error: No se ha realizado correctamente el VALIDATE para el fichero. Se cancela el COMEXT', v_log_count, v_idproceso, 'error');
	    	END IF;
    
	    	UPDATE EXT.OUT_BATCH_CONTROL
        	SET STATUS = v_const_out_batch_control_error,
	            END_DATE = CURRENT_TIMESTAMP
	        WHERE FILE_NAME = FILENAME
        	AND ID_PROCESO = v_idproceso;
    
	    
	    ELSE
	    	UPDATE EXT.OUT_BATCH_CONTROL
	    	SET STATUS = v_const_out_batch_control_ok,
	    	TARGET_ROWS = v_num_rows,
	    	END_DATE = CURRENT_TIMESTAMP
	    	WHERE FILE_NAME = FILENAME
	    	AND ID_PROCESO = v_idproceso;
	    END IF;
   
    END;
  
	
  
-- --     exception
-- --     WHEN NO_DATA_FOUND THEN
-- --         v_error_msg := 'Error: no se ha encontrado datos';
-- --         IF v_error_track = 'CS_PLRUN' then
-- --             v_error_msg := 'Error: No se ha encontrado un proceso de Validacion y Transferencia  del fichero  "'|| i_ficheroTXSTA ||'" finalizado correctamente.';
-- --         END IF;
-- --         CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_error_msg ,100);
-- --         raise_application_error(-20000, v_error_msg, true);
-- --     when cero_transacciones then    
-- --         v_error_msg := 'Error: No se han encontrado transacciones asociadas al fichero ' || i_ficheroTXSTA || ' para el proceso de Validacion y Transferencia : ' || v_pipeSeq;
-- --         CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, v_error_msg ,100);
-- --         raise_application_error(-20000,v_error_msg , true);
-- --     when others then
-- --       CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, v_proc_name, 'ERROR : ' || SQLERRM  ,100);
-- --       raise_application_error(-20000 ,  SQLERRM, true);
-- --      END;
      
	      
	--FIN
	CALL EXT.LIB_CONSTANTES:WRITE_LOG(v_permisos_log,v_proc_name,'Procedure completed...', v_log_count, v_idproceso, 'info');
    
END;
