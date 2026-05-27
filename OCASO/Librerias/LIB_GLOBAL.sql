CREATE LIBRARY "EXT"."LIB_GLOBAL" LANGUAGE SQLSCRIPT AS
BEGIN
  PUBLIC FUNCTION getTenantID() RETURNS o_TI VARCHAR(4)
  AS
	BEGIN
		SELECT DISTINCT TENANTID
		INTO o_TI
		FROM TCMP.CS_TENANT;
	END;
  PUBLIC FUNCTION GET_PERMISOS_LOG () RETURNS o_permisos VARCHAR(4)LANGUAGE SQLSCRIPT AS
	BEGIN 
		  DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
		SELECT STRING_AGG(CGC.GENERICBOOLEAN1 ORDER BY CGC.CLASSIFIERSEQ ASC) INTO o_permisos
			FROM TCMP.CS_CLASSIFIER CLAS
			INNER JOIN TCMP.CS_GENERICCLASSIFIERTYPE GCT ON GCT.GENERICCLASSIFIERTYPESEQ = CLAS.SELECTORID
				AND GCT.NAME = 'Parametros Log'
			INNER JOIN TCMP.CS_GENERICCLASSIFIER CGC ON CLAS.CLASSIFIERSEQ = CGC.CLASSIFIERSEQ
				AND CGC.REMOVEDATE = v_eot 
				AND CGC.EFFECTIVEENDDATE > CURRENT_DATE
				AND CGC.EFFECTIVESTARTDATE <= CURRENT_DATE
			WHERE CLAS.REMOVEDATE = v_eot
				AND CLAS.EFFECTIVEENDDATE > CURRENT_DATE
				AND CLAS.EFFECTIVESTARTDATE <= CURRENT_DATE
;
	END;
  PUBLIC PROCEDURE WRITE_LOG (IN i_array_permmisos VARCHAR2(4), IN i_object VARCHAR2(400), IN i_txt VARCHAR2(4000), INOUT io_valor INT, IN i_idproceso BIGINT,IN i_loglevel VARCHAR(20) ) LANGUAGE SQLSCRIPT 
  AS
	BEGIN
		
		BEGIN AUTONOMOUS TRANSACTION
	
			IF( SUBSTR(i_array_permmisos,1,1) = 1 AND i_loglevel = 'debug' )THEN
				INSERT INTO "EXT"."CSE_LOG" (DATETIME, OBJECT, TEXT, VALUE, ID_PROCESO,LEVEL)
				VALUES (CURRENT_TIMESTAMP, i_object, i_txt, io_valor, i_idproceso,i_loglevel);
			
				io_valor:= io_valor + 1;
			
			END IF;
			
			IF( SUBSTR(i_array_permmisos,2,1) = 1 AND i_loglevel = 'info' )THEN
				INSERT INTO "EXT"."CSE_LOG" (DATETIME, OBJECT, TEXT, VALUE, ID_PROCESO,LEVEL)
				VALUES (CURRENT_TIMESTAMP, i_object, i_txt, io_valor, i_idproceso,i_loglevel);
			
				io_valor:= io_valor + 1;
			
			END IF;
			
			IF( SUBSTR(i_array_permmisos,3,1) = 1 AND i_loglevel = 'warning' )THEN
				INSERT INTO "EXT"."CSE_LOG" (DATETIME, OBJECT, TEXT, VALUE, ID_PROCESO,LEVEL)
				VALUES (CURRENT_TIMESTAMP, i_object, i_txt, io_valor, i_idproceso,i_loglevel);
			
				io_valor:= io_valor + 1;
			
			END IF;
			
			IF( SUBSTR(i_array_permmisos,4,1) = 1 AND i_loglevel = 'error' )THEN
				INSERT INTO "EXT"."CSE_LOG" (DATETIME, OBJECT, TEXT, VALUE, ID_PROCESO,LEVEL)
				VALUES (CURRENT_TIMESTAMP, i_object, i_txt, io_valor, i_idproceso,i_loglevel);
			
				io_valor:= io_valor + 1;
			
			END IF;
		
		END;
		
	END;
  PUBLIC FUNCTION genera_batchname (IN file_name_recibos NVARCHAR(255))
/*
	----------------------------------------------------------------------------------------------- 
	| Autor: Jorge Gracia Estaun
	|---------------------------------------------------------------------------------------------- 
	| Parámetros de entrada:
	|	file_name_recibos NVARCHAR(255)
	| Parámetros de salida:
	|	batchname VARCHAR(90)
    | Genera nombre de salida para las transacciones
    | 
	|
	----------------------------------------------------------------------------------------------- 
*/
	RETURNS batchname VARCHAR(90)
	LANGUAGE SQLSCRIPT
	SQL SECURITY INVOKER
	AS
	BEGIN

	    -- Asignación de compañía
	    batchname := CASE WHEN LENGTH(file_name_recibos) = 50
			THEN 
				SUBSTR(file_name_recibos, 20, 15) || '_' || CASE 
					    WHEN SUBSTR(file_name_recibos, 5, 1) = 'O' THEN 'OCASO'
					    -- WHEN SUBSTR(file_name_recibos, 5, 1) = 'A' THEN 'ETERNA'
					    ELSE 'OCASO'
				END || '_' || SUBSTR(file_name_recibos, 5, 14) || '_' || SUBSTR(file_name_recibos, 42, 5)
			ELSE
				SUBSTR(file_name_recibos, 23, 15) || '_' || CASE 
					    WHEN SUBSTR(file_name_recibos, 5, 1) = 'O' THEN 'OCASO'
					    -- WHEN SUBSTR(file_name_recibos, 5, 1) = 'A' THEN 'ETERNA'
					    ELSE 'OCASO'
				END || '_' || SUBSTR(file_name_recibos, 5, 17) || '_' || SUBSTR(file_name_recibos, 45, 5)
		END;
	END;
  PUBLIC FUNCTION limpiar_campo (IN input NVARCHAR(255))
  /*
	----------------------------------------------------------------------------------------------- 
	| Autor: Jorge Gracia Estaun
	|---------------------------------------------------------------------------------------------- 
	| Parámetros de entrada:
	|	input NVARCHAR(255)
	| Parámetros de salida:
	|	input_procesado VARCHAR(90)
    | Se crea porque el codigo_agente_zona especificamente no viene con el espacio estandar (ASCII 32)
    | 
	|
	----------------------------------------------------------------------------------------------- 
*/
    RETURNS input_procesado NVARCHAR(255)
	LANGUAGE SQLSCRIPT
	SQL SECURITY INVOKER
	AS
	BEGIN
		input_procesado := TRIM(
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
             input,
             CHAR(160), ''),  -- No-break space
             CHAR(9), ''),    -- TAB
             CHAR(10), ''),   -- Line feed
             CHAR(13), ''),   -- Carriage return
             CHAR(0), '')     -- Null character
         );
    END;
  PUBLIC FUNCTION HEX_TO_DECIMAL (IN HEX_STRING NVARCHAR(50))
/*
	----------------------------------------------------------------------------------------------- 
	| Autor: Jorge Gracia Estaun
	|---------------------------------------------------------------------------------------------- 
	| Parámetros de entrada:
	|	HEX_STRING NVARCHAR(255)
	| Parámetros de salida:
	|	v_result DECIMAL(38,0)
    | Funcion necesaria para ordenar por codigo_recibo en asegurados igual que hace en ORACLE 
    | dado que estos son alfanumericos y no tenemos una funcion que haga lo mismo en HANA
    | 
	|
	----------------------------------------------------------------------------------------------- 
*/
	RETURNS v_result DECIMAL(38,0)
	LANGUAGE SQLSCRIPT
	SQL SECURITY INVOKER AS
	BEGIN
	    DECLARE v_len INT;
	    DECLARE v_pos INT;
	    DECLARE v_char NVARCHAR(1);
	    DECLARE v_val INT;
	
	    v_len := LENGTH(HEX_STRING);
	    v_pos := 1;
		v_result := 0;
		
	    WHILE v_pos <= v_len DO
	        v_char := SUBSTRING(HEX_STRING, v_pos, 1);
	
	        -- convertir caracter a valor hexadecimal
	        v_val := CASE UPPER(v_char)
			            WHEN '0' THEN 0
			            WHEN '1' THEN 1
			            WHEN '2' THEN 2
			            WHEN '3' THEN 3
			            WHEN '4' THEN 4
			            WHEN '5' THEN 5
			            WHEN '6' THEN 6
			            WHEN '7' THEN 7
			            WHEN '8' THEN 8
			            WHEN '9' THEN 9
			            WHEN 'A' THEN 10
			            WHEN 'B' THEN 11
			            WHEN 'C' THEN 12
			            WHEN 'D' THEN 13
			            WHEN 'E' THEN 14
			            WHEN 'F' THEN 15
			            ELSE 0
			         END;
	
	        -- acumular valor en base 16
	        v_result := v_result * 16 + v_val;
	
	        v_pos := v_pos + 1;
	    END WHILE;
	END;
  PUBLIC FUNCTION getPeriodRow(i_Tenant VARCHAR(4), pPlRunSeq BIGINT ) 
/*
	----------------------------------------------------------------------------------------------- 
	| Autor: Samuel Miralles Manresa 
	|---------------------------------------------------------------------------------------------- 
	| Parámetros de entrada:
	|	i_Tenant:	VARCHAR(4)
	|	pPlRunSeq:	BIGINT
    | Obtiene datos relaciones con el PeriodSeq
    | 
	|
	----------------------------------------------------------------------------------------------- 
*/
	RETURNS TABLE (
		TENANTID VARCHAR(4)
		, PPLRUNSEQ BIGINT
		, PERIODSEQ BIGINT
		, NAME VARCHAR(50)
		, STARTDATE TIMESTAMP
		, ENDDATE TIMESTAMP
	) LANGUAGE SQLSCRIPT 
	AS
	BEGIN
		RETURN SELECT i_Tenant AS TENANTID, pPlRunSeq, PER.PERIODSEQ, PER.NAME, PER.STARTDATE, PER.ENDDATE 
		FROM TCMP.CS_CALENDAR CAL
		JOIN TCMP.CS_PERIOD PER
			ON CAL.CALENDARSEQ = PER.CALENDARSEQ
		JOIN TCMP.CS_PLRUN PLRUN
			ON PLRUN.CALENDARSEQ = CAL.CALENDARSEQ
			AND PLRUN.PERIODSEQ = PER.PERIODSEQ
		WHERE PER.REMOVEDATE = EXT.LIB_CONSTANTES:v_eot
			AND CAL.REMOVEDATE = EXT.LIB_CONSTANTES:v_eot
			AND PLRUN.PIPELINERUNSEQ = pPlRunSeq
			AND PER.TENANTID = i_Tenant;
	END;
  PUBLIC FUNCTION getPeriodRowFromFecha(i_Tenant VARCHAR(4), i_fecha VARCHAR(8) ) 
/*
	----------------------------------------------------------------------------------------------- 
	| Autor: Samuel Miralles Manresa 
	|---------------------------------------------------------------------------------------------- 
	| Parámetros de entrada:
	|	i_Tenant:	VARCHAR(4)
	|	i_fecha:	VARCHAR(8)
    | Obtiene datos relaciones con el PeriodSeq a partir de una fecha
    | 
	|
	----------------------------------------------------------------------------------------------- 
*/
	RETURNS TABLE (
		TENANTID VARCHAR(4)
		, FECHA VARCHAR(8)
		, PERIODSEQ BIGINT
		, NAME VARCHAR(50)
		, STARTDATE TIMESTAMP
		, ENDDATE TIMESTAMP
	) LANGUAGE SQLSCRIPT 
	AS
	BEGIN
		RETURN SELECT i_Tenant AS TENANTID, i_fecha AS FECHA, per.PERIODSEQ, per.NAME, per.STARTDATE, per.ENDDATE
		FROM CS_CALENDAR cal   
        JOIN CS_PERIOD per ON cal.CALENDARSEQ = per.CALENDARSEQ AND per.TENANTID = i_Tenant
            AND per.removedate = EXT.LIB_CONSTANTES:v_eot
            AND TO_DATE(i_fecha,'YYYYMMDD') >= per.STARTDATE 
            AND ADD_MONTHS(TO_DATE(i_fecha,'YYYYMMDD'), -1) <= per.STARTDATE
            AND TO_DATE(i_fecha,'YYYYMMDD') < PER.ENDDATE 
            AND ADD_MONTHS(TO_DATE(i_fecha,'YYYYMMDD'), 1) >= per.ENDDATE
        WHERE cal.REMOVEDATE = EXT.LIB_CONSTANTES:v_eot
            AND cal.NAME = EXT.LIB_CONSTANTES:CONST_CALENDAR_NAME
            AND cal.TENANTID = i_Tenant;
	END;
  PUBLIC PROCEDURE getPeriodSeqFromPlrunseq (IN i_Tenant VARCHAR2(4), IN pPlRunSeq BIGINT,  OUT o_periodSeq  BIGINT ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
		SELECT PLR.PERIODSEQ INTO o_periodSeq
		FROM TCMP.CS_PLRUN PLR
		WHERE PLR.PIPELINERUNSEQ = :pPlRunSeq;
	END;
  PUBLIC PROCEDURE getPeriodSeqFromDate (IN i_Tenant VARCHAR2(4), IN i_fecha VARCHAR(8), i_calendar_name VARCHAR(50), i_period_type VARCHAR(20), OUT o_periodSeq  BIGINT ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
		SELECT PER.PERIODSEQ INTO o_periodSeq
		FROM TCMP.CS_PERIOD PER
		INNER JOIN TCMP.CS_CALENDAR CAL ON PER.CALENDARSEQ = CAL.CALENDARSEQ
			AND CAL.NAME = :i_calendar_name
			AND CAL.REMOVEDATE = :v_eot
		INNER JOIN TCMP.CS_PERIODTYPE PERT ON PER.PERIODTYPESEQ = PERT.PERIODTYPESEQ
			AND PERT.NAME = :i_period_type
			AND PERT.REMOVEDATE = :v_eot
		WHERE PER.REMOVEDATE = :v_eot
			AND PER.STARTDATE <= TO_DATE(i_fecha,'YYYYMMDD')
			AND PER.ENDDATE > TO_DATE(i_fecha,'YYYYMMDD')
		;
			
		
	END;
  PUBLIC PROCEDURE getPeriodName (IN i_Tenant VARCHAR2(4), IN pPlRunSeq BIGINT,  OUT o_PeriodName  VARCHAR(255) ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
		SELECT PER.NAME INTO o_PeriodName
		FROM TCMP.CS_CALENDAR CAL
		JOIN TCMP.CS_PERIOD PER
			ON CAL.CALENDARSEQ = PER.CALENDARSEQ
		JOIN TCMP.CS_PLRUN PLRUN
			ON PLRUN.CALENDARSEQ = CAL.CALENDARSEQ
			AND PLRUN.PERIODSEQ = PER.PERIODSEQ
		WHERE PER.REMOVEDATE = v_eot
			AND CAL.REMOVEDATE = v_eot
			AND PLRUN.PIPELINERUNSEQ = PPLRUNSEQ;
	END;
  PUBLIC PROCEDURE getPeriodSeq (IN i_Tenant VARCHAR2(4), IN i_PeriodName VARCHAR(255) ,  OUT o_PeriodSeq  BIGINT ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
	
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
		SELECT PERIODSEQ INTO o_PeriodSeq
		FROM TCMP.CS_PERIOD  
		WHERE REMOVEDATE = v_eot
			AND NAME = i_PeriodName
			AND TENANTID =i_Tenant;
	END;
  PUBLIC PROCEDURE getCalendarName (IN i_Tenant VARCHAR2(4), IN pPlRunSeq BIGINT,  OUT o_CalendarName  VARCHAR(255) ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
	
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
		SELECT CAL.NAME INTO o_CalendarName
		FROM TCMP.CS_PLRUN PLRUN
		INNER JOIN TCMP.CS_CALENDAR CAL
			ON PLRUN.CALENDARSEQ = CAL.CALENDARSEQ
				AND CAL.REMOVEDATE = v_eot
				AND CAL.TENANTID = i_Tenant
		WHERE PLRUN.PIPELINERUNSEQ = pPlRunSeq
			AND PLRUN.TENANTID = i_Tenant;
			
	END;
  PUBLIC PROCEDURE getCalendarSeq (IN i_Tenant VARCHAR2(4), IN i_CalendarName VARCHAR(255),  OUT o_CalendarSeq  BIGINT ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
	
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	
		SELECT CAL.CALENDARSEQ INTO o_CalendarSeq 
		FROM TCMP.CS_CALENDAR CAL
		WHERE CAL.TENANTID = i_Tenant
			AND CAL.REMOVEDATE = v_eot
			AND CAL.NAME = i_CalendarName;
	END;
  PUBLIC PROCEDURE getProcessingUnitName (IN i_Tenant VARCHAR2(4), IN pPlRunSeq BIGINT,  OUT o_ProcessingUnitName  VARCHAR(255) ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
	
		SELECT PU.NAME INTO o_ProcessingUnitName
		FROM TCMP.CS_PLRUN PLRUN
		INNER JOIN TCMP.CS_PROCESSINGUNIT PU
			ON PLRUN.PROCESSINGUNITSEQ = PU.PROCESSINGUNITSEQ
				AND PU.TENANTID = i_Tenant
		WHERE PLRUN.PIPELINERUNSEQ = pPlRunSeq
			AND PLRUN.TENANTID = i_Tenant;
	END;
  PUBLIC PROCEDURE getProcessingUnitSeq (IN i_Tenant VARCHAR2(4), IN i_ProcessingUnitName VARCHAR(255),  OUT o_ProcessingUnitSeq  BIGINT ) LANGUAGE SQLSCRIPT
  AS
	BEGIN
		SELECT PU.PROCESSINGUNITSEQ INTO o_ProcessingUnitSeq 
		FROM TCMP.CS_PROCESSINGUNIT PU
		WHERE PU.TENANTID = i_Tenant
			AND PU.NAME = i_ProcessingUnitName;
	END;
  PUBLIC FUNCTION getBuMap (i_Tenant VARCHAR2(4), i_BuName VARCHAR(255))
  RETURNS BUMAP INT AS
	BEGIN
		SELECT BU.MASK INTO BUMAP 
		FROM TCMP.CS_BUSINESSUNIT BU
		WHERE BU.TENANTID = i_Tenant
			AND BU.NAME = i_BuName;
	END;
  PUBLIC PROCEDURE getNextStageSTSeq (OUT o_stSeq BIGINT, INOUT io_count INT )
  LANGUAGE SQLSCRIPT AS
	BEGIN
		
		DECLARE max_tcmp BIGINT;
		DECLARE max_ext BIGINT;
		
		SELECT IFNULL(MAX(STAGESALESTRANSACTIONSEQ), 0) + io_count 
		INTO max_tcmp
		FROM TCMP.CS_STAGESALESTRANSACTION;
		
	/*	SELECT IFNULL(MAX(STAGESALESTRANSACTIONSEQ), 0) + io_count 
		INTO max_ext
		FROM EXT.SALESTRANSACTION;*/
		
		IF max_tcmp >= max_ext THEN
			o_stSeq := max_tcmp;
		ELSE
			o_stSeq := max_ext;
		END IF;
		
		io_count := io_count + 1;
		
	END;
  PUBLIC PROCEDURE getNextStageParticipantSeq (OUT o_ParticipantSeq BIGINT, INOUT io_count INT )
  LANGUAGE SQLSCRIPT AS
	BEGIN
		
		SELECT IFNULL(MAX(STAGEPARTICIPANTSEQ), 0) + io_count 
		INTO o_ParticipantSeq
		FROM TCMP.CS_STAGEPARTICIPANT;
		
		io_count:= io_count + 1;
		
	END;
  PUBLIC PROCEDURE getNextStagePositionRelationSeq (OUT o_PositionRelationSeq BIGINT, INOUT io_count INT )
  LANGUAGE SQLSCRIPT AS
	BEGIN
		
		SELECT IFNULL(MAX(STAGEPOSITIONRELATIONSEQ), 0) + io_count 
		INTO o_PositionRelationSeq
		FROM TCMP.CS_STAGEPOSITIONRELATION;
		
		io_count:= io_count + 1;
		
	END;
  PUBLIC PROCEDURE getNextStagePositionSeq (OUT o_PositionSeq BIGINT, INOUT io_count INT )
  LANGUAGE SQLSCRIPT AS
	BEGIN
		
		SELECT IFNULL(MAX(STAGEPOSITIONSEQ), 0) + io_count 
		INTO o_PositionSeq
		FROM TCMP.CS_STAGEPOSITION;
		
		io_count:= io_count + 1;
		
	END;
  PUBLIC FUNCTION VALIDAR_NIF_NIE(IN IN_NIF_NIE VARCHAR(20)) RETURNS OUT_valida BOOLEAN
	AS
	BEGIN
		
		IF IN_NIF_NIE LIKE_REGEXPR '^[KLMXYZ0-9][0-9]{7}[TRWAGMYFPDXBNJZSQVHLCKE]$' THEN
			DECLARE letra CHAR(1);
			DECLARE numeros INT;
			
			IF		LEFT(IN_NIF_NIE,1) IN ('K','L','M','X') THEN	numeros = TO_INTEGER('0' || SUBSTRING(IN_NIF_NIE, 2, 7));
				ELSEIF	LEFT(IN_NIF_NIE,1) = 'Y' THEN					numeros = TO_INTEGER('1' || SUBSTRING(IN_NIF_NIE, 2, 7));
				ELSEIF	LEFT(IN_NIF_NIE,1) = 'Z' THEN					numeros = TO_INTEGER('2' || SUBSTRING(IN_NIF_NIE, 2, 7));
			ELSE													numeros = TO_INTEGER(SUBSTRING(IN_NIF_NIE, 1, 8)); END IF;
			letra = SUBSTRING(IN_NIF_NIE, 9, 1);
			
			SELECT CASE
				WHEN MOD(numeros,23) = 0	AND letra = 'T' THEN	TRUE
				WHEN MOD(numeros,23) = 1	AND letra = 'R' THEN	TRUE
				WHEN MOD(numeros,23) = 2	AND letra = 'W' THEN	TRUE
				WHEN MOD(numeros,23) = 3	AND letra = 'A' THEN	TRUE
				WHEN MOD(numeros,23) = 4	AND letra = 'G' THEN	TRUE
				WHEN MOD(numeros,23) = 5	AND letra = 'M' THEN	TRUE
				WHEN MOD(numeros,23) = 6	AND letra = 'Y' THEN	TRUE
				WHEN MOD(numeros,23) = 7	AND letra = 'F' THEN	TRUE
				WHEN MOD(numeros,23) = 8	AND letra = 'P' THEN	TRUE
				WHEN MOD(numeros,23) = 9	AND letra = 'D' THEN	TRUE
				WHEN MOD(numeros,23) = 10	AND letra = 'X' THEN	TRUE
				WHEN MOD(numeros,23) = 11	AND letra = 'B' THEN	TRUE
				WHEN MOD(numeros,23) = 12	AND letra = 'N' THEN	TRUE
				WHEN MOD(numeros,23) = 13	AND letra = 'J' THEN	TRUE
				WHEN MOD(numeros,23) = 14	AND letra = 'Z' THEN	TRUE
				WHEN MOD(numeros,23) = 15	AND letra = 'S' THEN	TRUE
				WHEN MOD(numeros,23) = 16	AND letra = 'Q' THEN	TRUE
				WHEN MOD(numeros,23) = 17	AND letra = 'V' THEN	TRUE
				WHEN MOD(numeros,23) = 18	AND letra = 'H' THEN	TRUE
				WHEN MOD(numeros,23) = 19	AND letra = 'L' THEN	TRUE
				WHEN MOD(numeros,23) = 20	AND letra = 'C' THEN	TRUE
				WHEN MOD(numeros,23) = 21	AND letra = 'K' THEN	TRUE
				WHEN MOD(numeros,23) = 22	AND letra = 'E' THEN	TRUE
					ELSE FALSE
				END AS B INTO OUT_valida from dummy;
				ELSE
				OUT_valida = FALSE;
		END IF;
	END;
  PUBLIC FUNCTION GET_LAST_COMPENSATE_AND_PAY_TIME_BEFORE_LAST_POST_AFTER_FINALIZE(IN in_periodseq BIGINT) RETURNS out_date TIMESTAMP
	AS
	BEGIN
		
		SELECT MAX(PL.STARTTIME) into out_date
        FROM TCMP.CS_PLRUN PL
        WHERE PL.RUNPARAMETERS LIKE '%[Sequence]%Pay%'
		AND PL.COMMAND = 'PipelineRun'
		AND PL.STATUS = 'Successful'
		AND PL.PERIODSEQ = in_periodseq
		AND PL.STARTTIME < (
			--Usamos la fecha del ultimo Post ejecutado anterior al Finalize del periodo, si se ha realizado sino cogemos la fecha del ultimo Post ejecutado anterior a la fecha actual. 
			SELECT MAX(X.STARTTIME) FROM TCMP.CS_PLRUN X
			WHERE 1=1
			AND X.RUNPARAMETERS LIKE '%[Sequence]Post%'
			AND X.COMMAND = 'PipelineRun'
			AND X.STATUS = 'Successful'
			AND X.PERIODSEQ = in_periodseq
			AND X.STARTTIME < (
				--Usamos la fecha del Finalize del periodo, si aun no se ha realizado (lo normal cuando se lance el REPEXT) se coge la fecha actual.
				--Nos vale por si hay que repetir un REPEXT pasado el Posteo de los balances, ya que estos no se deben de tener en cuenta.
				SELECT IFNULL(MIN(Y.STARTTIME),CURRENT_TIMESTAMP) FROM TCMP.CS_PLRUN Y
				WHERE Y.RUNPARAMETERS LIKE '%[Sequence]Finalize%'
				AND Y.COMMAND = 'PipelineRun'
				AND Y.STATUS = 'Successful'
				AND Y.PERIODSEQ = in_periodseq
			)
		)
		;
	END;
  PUBLIC FUNCTION VALIDAR_CIF(IN IN_CIF VARCHAR(20)) RETURNS OUT_valida BOOLEAN
	AS
	BEGIN
		
		OUT_valida = FALSE;
		
		IF IN_CIF LIKE_REGEXPR '^[ABCDEFGHJNPQRSUVW][0-9]{7}[ABCDEFGHIJ0-9]$' THEN
			DECLARE numeros VARCHAR(7);
			DECLARE final CHAR(1);
			DECLARE control_final CHAR(1);
			DECLARE suma_A INT;
			DECLARE suma_B INT;
			DECLARE suma_C INT;
			DECLARE last_digit SMALLINT;
			
			numeros = SUBSTRING(IN_CIF,2,7);
			final = SUBSTRING(IN_CIF,9,1);
			
			--Pares
			suma_A = TO_INTEGER(SUBSTRING(numeros,6,1)) + TO_INTEGER(SUBSTRING(numeros,4,1)) + TO_INTEGER(SUBSTRING(numeros,2,1));
			--Impares
			suma_B = LEFT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,7,1))*2,'00'),1) + RIGHT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,7,1))*2,'00'),1)
	    	+ LEFT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,5,1))*2,'00'),1) + RIGHT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,5,1))*2,'00'),1)
	    	+ LEFT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,3,1))*2,'00'),1) + RIGHT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,3,1))*2,'00'),1)
	    	+ LEFT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,1,1))*2,'00'),1) + RIGHT(TO_VARCHAR(TO_INTEGER(SUBSTRING(numeros,1,1))*2,'00'),1);
			suma_C = suma_A + suma_B;
			last_digit = MOD(10-MOD(suma_C,10),10);
			
			IF (last_digit = 0) THEN
				control_final = 'J';
				ELSE control_final = CHAR(64 + last_digit);
			END IF;
			
			IF LEFT(IN_CIF,1) IN ('N','P','Q','R','S','W') OR SUBSTRING(IN_CIF,2,2) = '00' AND final LIKE_REGEXPR '[A-Z]' AND final LIKE control_final THEN OUT_valida = TRUE; --Letter
				ELSEIF LEFT(IN_CIF,1) IN ('A','B','E','H') AND final LIKE_REGEXPR '[0-9]' AND final LIKE last_digit THEN OUT_valida = TRUE; --Number
				ELSEIF LEFT(IN_CIF,1) NOT IN ('A','B','E','H','N','P','Q','R','S','W') AND (final LIKE last_digit OR final LIKE control_final) THEN OUT_valida = TRUE; --Both
			END IF;
		END IF;
	END;
  PUBLIC FUNCTION VALIDAR_IBAN(IN IN_IBAN VARCHAR(100)) RETURNS OUT_valida BOOLEAN
	AS
	BEGIN
		
		DECLARE iban_prefix VARCHAR(4);
		DECLARE iban_country_code VARCHAR(2);
		DECLARE iban_check_digits VARCHAR(2);
		DECLARE iban_account_number VARCHAR(30);
		DECLARE iban_numeric VARCHAR(30);
		DECLARE iban_remainder INT;
		DECLARE iban_check_digit INT;
		DECLARE iban VARCHAR(34);
		
		OUT_valida = TRUE;
		-- Eliminar espacios en blanco y guiones del IBAN
		iban = REPLACE(REPLACE(IN_IBAN, ' ', ''), '-', '');
		
		-- Obtener partes del IBAN
		iban_country_code = SUBSTRING(iban, 1, 2);
		iban_check_digits = SUBSTRING(iban, 3, 2);
		iban_account_number = SUBSTRING(iban, 5);
		
		-- Validar la longitud del IBAN y el formato
		IF LENGTH(iban) != 24 OR iban_country_code NOT LIKE_REGEXPR '^[A-Z]{2}$' OR iban_account_number NOT LIKE_REGEXPR '^[0-9]{1,30}$' OR IN_IBAN IS NULL THEN
			OUT_valida = FALSE;
		END IF;
		
		-- Reorganizar el IBAN para calcular los dígitos de control
		iban_numeric = iban_account_number || iban_country_code || '00';
		
		-- Convertir letras a números where A = 10, B = 11, ..., Z = 35
		iban_numeric = 
		REPLACE(
			REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE(
													REPLACE(
														REPLACE(
															REPLACE(
																REPLACE(
																	REPLACE(
																		REPLACE(
																			REPLACE(
																				REPLACE(
																					REPLACE(
																						REPLACE(
																							REPLACE(
																								REPLACE(
																									REPLACE(
																										REPLACE(
																											REPLACE(
																												iban_numeric,
																												'A', '10'
																											),
																											'B', '11'
																										),
																										'C', '12'
																									),
																									'D', '13'
																								),
																								'E', '14'
																							),
																							'F', '15'
																						),
																						'G', '16'
																					),
																					'H', '17'
																				),
																				'I', '18'
																			),
																			'J','19'
																		),
																		'K', '20'
																	),
																	'L', '21'
																),
																'M', '22'
															),
															'N', '23'
														),
														'O', '24'
													),
													'P', '25'
												),
												'Q', '26'
											),
											'R', '27'
										),
										'S', '28'
									),
								'T','29'),
								'U', '30'
							),
							'V', '31'
						),
						'W', '32'
					),
					'X', '33'
				),
				'Y', '34'
			),
			'Z', '35'
		);
		
		-- Calcular el dígito de control
		iban_remainder = MOD(SUBSTRING(iban_numeric,1,9), 97);
		iban_remainder = MOD(iban_remainder || SUBSTRING(iban_numeric,10,7),97);
		iban_remainder = MOD(iban_remainder || SUBSTRING(iban_numeric,17,7),97);
		iban_remainder = MOD(iban_remainder || SUBSTRING(iban_numeric,24),97);
		
		iban_check_digit = 98 - iban_remainder;
		
		-- Verificar si el dígito de control es válido
		IF iban_check_digit NOT LIKE iban_check_digits THEN
			OUT_valida = FALSE;
		END IF;
	END;
  PUBLIC FUNCTION FT_SPLIT_ARRAY (cadena VARCHAR(5000), delimitador VARCHAR(255), num INTEGER) 
  RETURNS v_ret VARCHAR(255) --LANGUAGE SQLSCRIPT SQL SECURITY DEFINER
  AS
	BEGIN
		DECLARE v_start integer;
		DECLARE v_end integer;
		
		IF :num = 1 THEN
			v_start := 1;
		ELSE
			v_start := INSTR(:cadena, :delimitador, 1, :num - 1);
			
			IF :v_start = 0 THEN
				RETURN;
			END if;
			
			v_start := :v_start + 1;
		END IF;
		
		v_end := INSTR(:cadena, :delimitador, 1, :num);
		
		IF :v_end = 0 THEN
			v_end := LENGTH(:cadena);
		ELSE
			v_end := :v_end - 1;
		END IF;
		
		v_ret := SUBSTR(:cadena, :v_start, :v_end - :v_start + 1);
		
	END;
  PUBLIC FUNCTION FT_SPLIT_ARRAY_CLOB (cadena CLOB, delimitador VARCHAR(255), num INTEGER) 
  RETURNS v_ret VARCHAR(255) --LANGUAGE SQLSCRIPT SQL SECURITY DEFINER
  AS
	BEGIN
		DECLARE v_start integer;
		DECLARE v_end integer;
		
		IF :num = 1 THEN
			v_start := 1;
		ELSE
			v_start := INSTR(:cadena, :delimitador, 1, :num - 1);
			
			IF :v_start = 0 THEN
				RETURN;
			END if;
			
			v_start := :v_start + 1;
		END IF;
		
		v_end := INSTR(:cadena, :delimitador, 1, :num);
		
		IF :v_end = 0 THEN
			v_end := LENGTH(:cadena);
		ELSE
			v_end := :v_end - 1;
		END IF;
		
		v_ret := SUBSTR(:cadena, :v_start, :v_end - :v_start + 1);
		
	END;
  PUBLIC FUNCTION getUnitTypeName (i_Tenant VARCHAR2(4), IN i_unitTypeSeq BIGINT )
RETURNS o_unitTypeName  VARCHAR(255) 
  AS
	BEGIN
		DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
		
		SELECT UT.NAME INTO o_unitTypeName 
		FROM TCMP.CS_UNITTYPE UT
		WHERE UT.TENANTID = i_Tenant
			AND UT.UNITTYPESEQ = i_unitTypeSeq
			AND UT.REMOVEDATE = v_eot;
	END;
  PUBLIC PROCEDURE SP_insertaStageRecibos (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_sql_statement NVARCHAR(5000);
		--DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_CONSTANTES:GET_PERMISOS_LOG();
		DECLARE num_rows INTEGER := 0;
		DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
		
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_insertaStageRecibos: Revisad el insert dinamico de Recibos'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Inicio SP_insertaStageRecibos: '  , i_log_count, i_id_proceso, 'info');
		
		--Pasamos validaciones de tipo de datos para recibos
		CALL EXT.LIB_ERRORES:SP_validarRecibos (v_permisos_log, i_nombre_procedure, i_tabla, i_file_name, i_log_count, i_id_proceso);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Validaciones de tipo de dato terminadas'  , i_log_count, i_id_proceso, 'info');
			
		IF i_nombre_procedure NOT LIKE '%GESTIONES%' AND i_nombre_procedure NOT LIKE '%SERCO%' THEN

			v_sql_statement := 'INSERT INTO EXT.STAGE_RECIBOS SELECT''' || 
					:i_file_name || ''',' ||
					'1' || ',' ||
					'CURRENT_TIMESTAMP '
					',RAMO' ||
					',CODIGO_POLIZA'||	
					',MOTIVO_ALTA' ||
					',TO_DATE(FECHA_EFECTO_POLIZA,''YYYYMMDD'')'|| 
					',TO_DATE(FECHA_EMISION_POLIZA,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_CESION_POLIZA,''YYYYMMDD'')' ||
					',MOTIVO_BAJA' ||
					',TO_DATE(FECHA_BAJA,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_EFECTO_SUPLEMENTO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_VENCIMIENTO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_REHABILITACION,''YYYYMMDD'')' ||
					',FORMA_PAGO' ||
					',TIPO_CAMPANIA' ||
					',CODIGO_AGENTE_ORIGINAL' ||
					',CODIGO_UNICO_AGENTE' ||
					',INSPECTOR' ||
					',OFICINA_COBRADORA' ||
					',OFICINA_GESTORA' ||
					',SEGUNDA_RESIDENCIA' ||
					',TARIFA' ||
					',ZONA' ||
					',CLAVE_RIESGO' ||
					',CODIGO_SUPLEMENTO' ||
					',DISTRITO_COBRO' ||
					',MODALIDAD' ||
					',DURACION' ||
					',ROUND(TO_DECIMAL(IND_COMI_CALCULADA,25,6),4)' ||
					',ROUND(TO_DECIMAL(IND_POR_CALCULADO,25,6),4)' ||
					',ROUND(TO_DECIMAL(POR_COMI_CALCULADA,25,6),4)' ||
					',ROUND(TO_DECIMAL(IMPORTE_COMISION,25,6),4)' ||
					',CLAUSULA' ||
					',AUMENTO_CAPITALES_GAR' ||
					',SUSTITUCION_INCENDIOS' ||
					',CODIGO_SINIESTRO' ||
					',EXCLUIDO_COMISIONES' ||
					',TRASPASADA' ||
					',ROUND(TO_DECIMAL(INCRE_PRIMA_ANUAL,25,6),4)' ||
					',ROUND(TO_DECIMAL(DTO_IMPT_SINIESTRALIDAD,25,6),4)' ||
					',ROUND(TO_DECIMAL(DTO_POR_PRIORITARIO,25,6),4)' ||
					',RIESGO' ||
					',COLECTIVO' ||
					',AUTOLIQUIDA' ||
					',ROUND(TO_DECIMAL(KILOMETROS,25,6),4)' ||
					',PRIMER_RECIBO' ||
					',CODIGO_RECIBO' ||
					',PERMANENCIA' ||
					',TIPO_RECIBO' ||
					',ESTADO_RECIBO' ||
					',TO_DATE(FECHA_COBRO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_EFECTO_RECIBO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_VENCIMIENTO_RECIBO,''YYYYMMDD'')' ||
					',TIPO_MOVIMIENTO' ||
					',ROUND(TO_DECIMAL(PORC_DESTO_SOBREPC,25,6),4)' ||
					',VALOR_POLIZA' ||
					',MARCA_RECUPERADO' ||
					',PRODUCTO_CONTABLE' ||
					',TO_DATE(FECHA_ALTA_GAR_POL,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_BAJA_GAR_POL,''YYYYMMDD'')' ||
					',ROUND(TO_DECIMAL(PRIMA_NETA_RECIBO,25,6),4)' ||
					',ROUND(TO_DECIMAL(PRIMA_BRUTA_RECIBO,25,6),4)' ||
					',RECARGO' ||
					',ROUND(TO_DECIMAL(PORCENTAJE_BONIFICACION,25,6),4)' ||
					',POLIZA_CON_AGENTE' ||
					',MOVILIDAD' ||
					',PRIMA_UNICA' ||
					',TO_INTEGER(NUM_ORDEN_MOVIMIENTO)' ||
					',TO_DATE(FECHA_EMISION_REC,''YYYYMMDD'')' ||
					',TO_DATE(TRIM(CARGO_COMPENSACION),''YYYYMMDD'')' ||
					',ZONA_EXPLOTACION' ||
					',TRIM(CODIGO_AGENTE_ZONA)'--'' ||
				--	:i_file_name || ''',' ||
				--	'1' || ',' ||
				--	'CURRENT_TIMESTAMP '
					||' FROM '|| :i_tabla ;

		ELSE
				v_sql_statement := 'INSERT INTO EXT.STAGE_RECIBOS SELECT ''' || 
					:i_file_name || ''',' ||
					'1' || ',' ||
					'CURRENT_TIMESTAMP '
					',RAMO' ||
					',CODIGO_POLIZA'||	
					',MOTIVO_ALTA' ||
					',TO_DATE(FECHA_EFECTO_POLIZA,''YYYYMMDD'')'|| 
					',TO_DATE(FECHA_EMISION_POLIZA,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_CESION_POLIZA,''YYYYMMDD'')' ||
					',MOTIVO_BAJA' ||
					',TO_DATE(FECHA_BAJA,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_EFECTO_SUPLEMENTO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_VENCIMIENTO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_REHABILITACION,''YYYYMMDD'')' ||
					',FORMA_PAGO' ||
					',TIPO_CAMPANIA' ||
					',CODIGO_AGENTE_ORIGINAL' ||
					',CODIGO_UNICO_AGENTE' ||
					',INSPECTOR' ||
					',OFICINA_COBRADORA' ||
					',OFICINA_GESTORA' ||
					',SEGUNDA_RESIDENCIA' ||
					',TARIFA' ||
					',ZONA' ||
					',CLAVE_RIESGO' ||
					',CODIGO_SUPLEMENTO' ||
					',DISTRITO_COBRO' ||
					',MODALIDAD' ||
					',DURACION' ||
					',ROUND(TO_DECIMAL(IND_COMI_CALCULADA,25,6),4)' ||
					',ROUND(TO_DECIMAL(IND_POR_CALCULADO,25,6),4)' ||
					',ROUND(TO_DECIMAL(POR_COMI_CALCULADA,25,6),4)' ||
					',ROUND(TO_DECIMAL(IMPORTE_COMISION,25,6),4)' ||
					',CLAUSULA' ||
					',AUMENTO_CAPITALES_GAR' ||
					',SUSTITUCION_INCENDIOS' ||
					',CODIGO_SINIESTRO' ||
					',EXCLUIDO_COMISIONES' ||
					',TRASPASADA' ||
					',ROUND(TO_DECIMAL(INCRE_PRIMA_ANUAL,25,6),4)' ||
					',ROUND(TO_DECIMAL(DTO_IMPT_SINIESTRALIDAD,25,6),4)' ||
					',ROUND(TO_DECIMAL(DTO_POR_PRIORITARIO,25,6),4)' ||
					',RIESGO' ||
					',COLECTIVO' ||
					',AUTOLIQUIDA' ||
					',ROUND(TO_DECIMAL(KILOMETROS,25,6),4)' ||
					',PRIMER_RECIBO' ||
					',CODIGO_RECIBO' ||
					',PERMANENCIA' ||
					',TIPO_RECIBO' ||
					',ESTADO_RECIBO' ||
					',TO_DATE(FECHA_COBRO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_EFECTO_RECIBO,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_VENCIMIENTO_RECIBO,''YYYYMMDD'')' ||
					',TIPO_MOVIMIENTO' ||
					',ROUND(TO_DECIMAL(PORC_DESTO_SOBREPC,25,6),4)' ||
					',VALOR_POLIZA' ||
					',MARCA_RECUPERADO' ||
					',PRODUCTO_CONTABLE' ||
					',TO_DATE(FECHA_ALTA_GAR_POL,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_BAJA_GAR_POL,''YYYYMMDD'')' ||
					',ROUND(TO_DECIMAL(PRIMA_NETA_RECIBO,25,6),4)' ||
					',ROUND(TO_DECIMAL(PRIMA_BRUTA_RECIBO,25,6),4)' ||
					',RECARGO' ||
					',ROUND(TO_DECIMAL(PORCENTAJE_BONIFICACION,25,6),4)' ||
					',POLIZA_CON_AGENTE' ||
					',MOVILIDAD' ||
					',PRIMA_UNICA' ||
					',TO_INTEGER(NUM_ORDEN_MOVIMIENTO)' ||
					',TO_DATE(FECHA_EMISION_REC,''YYYYMMDD'')' ||
					',TO_DATE(TRIM(CARGO_COMPENSACION),''YYYYMMDD'')' ||
					','''||--',ZONA_EXPLOTACION' || -- Para Serco viene dos campos menos por lo que lo dejamos vacio en la tabla de STAGE_RECIBOS
					','''||--',TRIM(CODIGO_AGENTE_ZONA),''' || -- Para Serco viene dos campos menos por lo que lo dejamos vacio en la tabla de STAGE_RECIBOS
				
					' FROM '|| :i_tabla ;

		END IF;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement , i_log_count, i_id_proceso, 'debug');
				
		EXECUTE IMMEDIATE :v_sql_statement;
			
		num_rows := ::rowcount;
			
		--Actualizamos la IN_BATCH_CONTROL y ponemos el estado a 1
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP , SOURCE_ROWS = num_rows WHERE FILE_NAME = i_file_name AND ID_PROCESO = i_id_proceso;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en EXT.STAGE_RECIBOS ' || num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'info');
	
	END;
  PUBLIC PROCEDURE SP_insertaStageRecibosGestiones (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_sql_statement NVARCHAR(5000);
		--DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_CONSTANTES:GET_PERMISOS_LOG();
		DECLARE num_rows INTEGER := 0;
		DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
		
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_insertaStageRecibos: Revisad el insert dinamico de Recibos'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Inicio SP_insertaStageRecibos: '  , i_log_count, i_id_proceso, 'info');
		
		--Pasamos validaciones de tipo de datos para recibos
		-- CALL EXT.LIB_ERRORES:SP_validarRecibosGestiones (v_permisos_log, i_nombre_procedure, i_tabla, i_file_name, i_log_count, i_id_proceso);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Validaciones de tipo de dato terminadas'  , i_log_count, i_id_proceso, 'info');
			
		v_sql_statement := 'INSERT INTO EXT.STAGE_RECIBOS SELECT ''' || 
		:i_file_name || ''',' ||
		'1' || ',' ||
		'CURRENT_TIMESTAMP '
		',RAMO' ||
		',CODIGO_POLIZA'||	
		',MOTIVO_ALTA' ||
		',TO_DATE(FECHA_EFECTO_POLIZA,''YYYYMMDD'')'|| 
		',TO_DATE(FECHA_EMISION_POLIZA,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_CESION_POLIZA,''YYYYMMDD'')' ||
		',MOTIVO_BAJA' ||
		',TO_DATE(FECHA_BAJA,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_EFECTO_SUPLEMENTO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_VENCIMIENTO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_REHABILITACION,''YYYYMMDD'')' ||
		',FORMA_PAGO' ||
		',TIPO_CAMPANIA' ||
		',CODIGO_AGENTE_ORIGINAL' ||
		',CODIGO_UNICO_AGENTE' ||
		',INSPECTOR' ||
		',OFICINA_COBRADORA' ||
		',OFICINA_GESTORA' ||
		',SEGUNDA_RESIDENCIA' ||
		',TARIFA' ||
		',ZONA' ||
		',CLAVE_RIESGO' ||
		',CODIGO_SUPLEMENTO' ||
		',DISTRITO_COBRO' ||
		',MODALIDAD' ||
		',DURACION' ||
		',ROUND(TO_DECIMAL(IND_COMI_CALCULADA,25,6),4)' ||
		',ROUND(TO_DECIMAL(IND_POR_CALCULADO,25,6),4)' ||
		',ROUND(TO_DECIMAL(POR_COMI_CALCULADA,25,6),4)' ||
		',ROUND(TO_DECIMAL(IMPORTE_COMISION,25,6),4)' ||
		',CLAUSULA' ||
		',AUMENTO_CAPITALES_GAR' ||
		',SUSTITUCION_INCENDIOS' ||
		',CODIGO_SINIESTRO' ||
		',EXCLUIDO_COMISIONES' ||
		',TRASPASADA' ||
		',ROUND(TO_DECIMAL(INCRE_PRIMA_ANUAL,25,6),4)' ||
		',ROUND(TO_DECIMAL(DTO_IMPT_SINIESTRALIDAD,25,6),4)' ||
		',ROUND(TO_DECIMAL(DTO_POR_PRIORITARIO,25,6),4)' ||
		',RIESGO' ||
		',COLECTIVO' ||
		',AUTOLIQUIDA' ||
		',ROUND(TO_DECIMAL(KILOMETROS,25,6),4)' ||
		',PRIMER_RECIBO' ||
		',CODIGO_RECIBO' ||
		',PERMANENCIA' ||
		',TIPO_RECIBO' ||
		',ESTADO_RECIBO' ||
		',TO_DATE(FECHA_COBRO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_EFECTO_RECIBO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_VENCIMIENTO_RECIBO,''YYYYMMDD'')' ||
		',TIPO_MOVIMIENTO' ||
		',ROUND(TO_DECIMAL(PORC_DESTO_SOBREPC,25,6),4)' ||
		',VALOR_POLIZA' ||
		',MARCA_RECUPERADO' ||
		',PRODUCTO_CONTABLE' ||
		',TO_DATE(FECHA_ALTA_GAR_POL,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_BAJA_GAR_POL,''YYYYMMDD'')' ||
		',ROUND(TO_DECIMAL(PRIMA_NETA_RECIBO,25,6),4)' ||
		',ROUND(TO_DECIMAL(PRIMA_BRUTA_RECIBO,25,6),4)' ||
		',RECARGO' ||
		',ROUND(TO_DECIMAL(PORCENTAJE_BONIFICACION,25,6),4)' ||
		',POLIZA_CON_AGENTE' ||
		',MOVILIDAD' ||
		',PRIMA_UNICA' ||
		',TO_INTEGER(NUM_ORDEN_MOVIMIENTO)' ||
		',TO_DATE(FECHA_EMISION_REC,''YYYYMMDD'')' ||
		',TO_DATE(TRIM(CARGO_COMPENSACION),''YYYYMMDD'')' ||
		',NULL'||--',ZONA_EXPLOTACION' || -- Para Serco viene dos campos menos por lo que lo dejamos vacio en la tabla de STAGE_RECIBOS
		',NULL'||--',TRIM(CODIGO_AGENTE_ZONA),''' || -- Para Serco viene dos campos menos por lo que lo dejamos vacio en la tabla de STAGE_RECIBOS
	
		' FROM '|| :i_tabla ;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement , i_log_count, i_id_proceso, 'debug');
				
		EXECUTE IMMEDIATE :v_sql_statement;
			
		num_rows := ::rowcount;
			
		--Actualizamos la IN_BATCH_CONTROL y ponemos el estado a 1
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP , SOURCE_ROWS = num_rows WHERE FILE_NAME = i_file_name AND ID_PROCESO = i_id_proceso;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en EXT.STAGE_RECIBOS ' || num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'info');
	
	END;
  PUBLIC PROCEDURE SP_insertaStageSerco (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_sql_statement NVARCHAR(5000);
		--DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_CONSTANTES:GET_PERMISOS_LOG();
		DECLARE num_rows INTEGER := 0;
		DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
		
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_insertaStageRecibos: Revisad el insert dinamico de Recibos'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Inicio SP_insertaStageSerco: '  , i_log_count, i_id_proceso, 'info');
		
		--Pasamos validaciones de tipo de datos para recibos
		-- CALL EXT.LIB_ERRORES:SP_validarRecibosGestiones (v_permisos_log, i_nombre_procedure, i_tabla, i_file_name, i_log_count, i_id_proceso);
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Validaciones de tipo de dato terminadas'  , i_log_count, i_id_proceso, 'info');
			
		v_sql_statement := 'INSERT INTO EXT.STAGE_RECIBOS SELECT ''' || 
		:i_file_name || ''',' ||
		'1' || ',' ||
		'CURRENT_TIMESTAMP '
		',RAMO' ||
		',CODIGO_POLIZA'||	
		',MOTIVO_ALTA' ||
		',TO_DATE(FECHA_EFECTO_POLIZA,''YYYYMMDD'')'|| 
		',TO_DATE(FECHA_EMISION_POLIZA,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_CESION_POLIZA,''YYYYMMDD'')' ||
		',MOTIVO_BAJA' ||
		',TO_DATE(FECHA_BAJA,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_EFECTO_SUPLEMENTO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_VENCIMIENTO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_REHABILITACION,''YYYYMMDD'')' ||
		',FORMA_PAGO' ||
		',TIPO_CAMPANIA' ||
		',CODIGO_AGENTE_ORIGINAL' ||
		',CODIGO_UNICO_AGENTE' ||
		',INSPECTOR' ||
		',OFICINA_COBRADORA' ||
		',OFICINA_GESTORA' ||
		',SEGUNDA_RESIDENCIA' ||
		',TARIFA' ||
		',ZONA' ||
		',CLAVE_RIESGO' ||
		',CODIGO_SUPLEMENTO' ||
		',DISTRITO_COBRO' ||
		',MODALIDAD' ||
		',DURACION' ||
		',ROUND(TO_DECIMAL(IND_COMI_CALCULADA,25,6),4)' ||
		',ROUND(TO_DECIMAL(IND_POR_CALCULADO,25,6),4)' ||
		',ROUND(TO_DECIMAL(POR_COMI_CALCULADA,25,6),4)' ||
		',ROUND(TO_DECIMAL(IMPORTE_COMISION,25,6),4)' ||
		',CLAUSULA' ||
		',AUMENTO_CAPITALES_GAR' ||
		',SUSTITUCION_INCENDIOS' ||
		',CODIGO_SINIESTRO' ||
		',EXCLUIDO_COMISIONES' ||
		',TRASPASADA' ||
		',ROUND(TO_DECIMAL(INCRE_PRIMA_ANUAL,25,6),4)' ||
		',ROUND(TO_DECIMAL(DTO_IMPT_SINIESTRALIDAD,25,6),4)' ||
		',ROUND(TO_DECIMAL(DTO_POR_PRIORITARIO,25,6),4)' ||
		',RIESGO' ||
		',COLECTIVO' ||
		',AUTOLIQUIDA' ||
		',ROUND(TO_DECIMAL(KILOMETROS,25,6),4)' ||
		',PRIMER_RECIBO' ||
		',CODIGO_RECIBO' ||
		',PERMANENCIA' ||
		',TIPO_RECIBO' ||
		',ESTADO_RECIBO' ||
		',TO_DATE(FECHA_COBRO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_EFECTO_RECIBO,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_VENCIMIENTO_RECIBO,''YYYYMMDD'')' ||
		',TIPO_MOVIMIENTO' ||
		',ROUND(TO_DECIMAL(PORC_DESTO_SOBREPC,25,6),4)' ||
		',VALOR_POLIZA' ||
		',MARCA_RECUPERADO' ||
		',PRODUCTO_CONTABLE' ||
		',TO_DATE(FECHA_ALTA_GAR_POL,''YYYYMMDD'')' ||
		',TO_DATE(FECHA_BAJA_GAR_POL,''YYYYMMDD'')' ||
		',ROUND(TO_DECIMAL(PRIMA_NETA_RECIBO,25,6),4)' ||
		',ROUND(TO_DECIMAL(PRIMA_BRUTA_RECIBO,25,6),4)' ||
		',RECARGO' ||
		',ROUND(TO_DECIMAL(PORCENTAJE_BONIFICACION,25,6),4)' ||
		',POLIZA_CON_AGENTE' ||
		',MOVILIDAD' ||
		',PRIMA_UNICA' ||
		',TO_INTEGER(NUM_ORDEN_MOVIMIENTO)' ||
		',TO_DATE(FECHA_EMISION_REC,''YYYYMMDD'')' ||
		',TO_DATE(TRIM(CARGO_COMPENSACION),''YYYYMMDD'')' ||
		',NULL'||--',ZONA_EXPLOTACION' || -- Para Serco viene dos campos menos por lo que lo dejamos vacio en la tabla de STAGE_RECIBOS
		',NULL'||--',TRIM(CODIGO_AGENTE_ZONA),''' || -- Para Serco viene dos campos menos por lo que lo dejamos vacio en la tabla de STAGE_RECIBOS
	
		' FROM '|| :i_tabla ;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement , i_log_count, i_id_proceso, 'debug');
				
		EXECUTE IMMEDIATE :v_sql_statement;
			
		num_rows := ::rowcount;
			
		--Actualizamos la IN_BATCH_CONTROL y ponemos el estado a 1
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP , SOURCE_ROWS = num_rows WHERE FILE_NAME = i_file_name AND ID_PROCESO = i_id_proceso;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en EXT.STAGE_RECIBOS ' || num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'info');
	
	END;
  PUBLIC PROCEDURE SP_insertaStageAsegurados (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_sql_statement NVARCHAR(5000);
		--DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_CONSTANTES:GET_PERMISOS_LOG();
		DECLARE num_rows INTEGER := 0;
		DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
		DECLARE v_log_count INT := i_log_count;
		
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_insertaStageAsegurados: Revisad el insert dinamico de Asegurados'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Inicio SP_insertaStageAsegurados: '  , i_log_count, i_id_proceso, 'info');
		
		--Pasamos validaciones de tipo de datos para recibos
		CALL EXT.LIB_ERRORES:SP_validarAsegurados (v_permisos_log, i_nombre_procedure, i_tabla, i_file_name, i_log_count, i_id_proceso);
	
		v_sql_statement := 'INSERT INTO EXT.STAGE_ASEGURADOS SELECT ''' ||
			:i_file_name || ''',' ||
			'1' || ',' ||
			'CURRENT_TIMESTAMP '
			',CODIGO_POLIZA'||	
			',NUMERO_ASEGURADO' ||
			',CODIGO_RECIBO' || 
			',NIF' ||
			',TO_DATE(FECHA_NACIMIENTO,''YYYYMMDD'')' ||
			',TO_DATE(FECHA_DERECHOS,''YYYYMMDD'')' ||
			',MOTIVO_ALTA' ||
			',TO_DATE(FECHA_ALTA,''YYYYMMDD'')' ||
			',MOTIVO_BAJA' ||
			',TO_DATE(FECHA_BAJA,''YYYYMMDD'')' ||
			',TO_DATE(FECHA_REHABILITACION,''YYYYMMDD'')' ||
			',SUB_TIPO_MOVIMIENTO' ||
			',PRODUCTO_CONTABLE' ||
			',TO_DATE(FECHA_ALTA_GAR_ASE,''YYYYMMDD'')' ||
			',TO_DATE(FECHA_BAJA_GAR_ASE,''YYYYMMDD'')' ||
			',PRIMA_UNICA' ||
			',GARANTIA_IP' ||
			',PRIMA_NETA_ASEGURADO' ||
			',CAPITAL_NATURAL' ||
			',CAPITAL_NIVELADO' ||
			',POLIZA_ORIGEN' ||
			',TRIM(ASEGURADO_ORIGEN)' ||
			--',TRIM(ASEGURADO_ORIGEN),' ||
		
			' FROM '|| :i_tabla ;

			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement , i_log_count, i_id_proceso, 'debug');
		
		EXECUTE IMMEDIATE :v_sql_statement;
			
		num_rows := ::rowcount;
			
		--Actualizamos la IN_BATCH_CONTROL y ponemos el estado a 1
		UPDATE EXT.IN_BATCH_CONTROL SET STATUS = v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP , SOURCE_ROWS = num_rows WHERE FILE_NAME = i_file_name AND ID_PROCESO = i_id_proceso;
			
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en EXT.STAGE_ASEGURADOS ' || num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'info');

				
		
	
	END;
  PUBLIC PROCEDURE SP_insertaStageReajustes (IN v_permisos_log VARCHAR(50), IN i_nombre_procedure VARCHAR2(100) , IN i_tabla VARCHAR2(100), In i_file_name VARCHAR(120), INOUT i_log_count INTEGER, IN i_id_proceso BIGINT)
  LANGUAGE SQLSCRIPT AS
	BEGIN
		DECLARE v_sql_statement NVARCHAR(5000);
		--DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_CONSTANTES:GET_PERMISOS_LOG();
		DECLARE num_rows INTEGER := 0;
		DECLARE v_const_stage_status_ok INT := EXT.LIB_CONSTANTES:CONST_STAGE_STATUS_OK;
		DECLARE v_log_count INT := i_log_count;
		
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		  BEGIN
		    CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Error en SP_insertaStageReajustes: Revisad el insert dinamico de Reajustes'  , i_log_count, i_id_proceso, 'error');
		    --COMMIT;
		    RESIGNAL;
		 
		  END;
		
		CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log,i_nombre_procedure, 'Inicio SP_insertaStageReajustes: '  , i_log_count, i_id_proceso, 'info');
			
	
				v_sql_statement := 'INSERT INTO EXT.STAGE_REAJUSTES SELECT ''' ||
					:i_file_name || ''',' ||
					'1' || ',' ||
					'CURRENT_TIMESTAMP '
					',CODIGO_POLIZA'||	
					',NUMERO_ASEGURADO' ||
					',PRODUCTO_CONTABLE' ||
					',PRIMA_NETA_ASEGURADO' ||
					',CAPITAL_NATURAL' ||
					',CAPITAL_NIVELADO' ||
					',TO_DATE(FECHA_BAJA_GAR_ASE,''YYYYMMDD'')' ||
					',TO_DATE(FECHA_EFECTO_SUPLEMENTO,''YYYYMMDD'')' ||
					',TRIM(NUM_ORDEN_MOVIMIENTO)' ||
					
					' FROM '|| :i_tabla ;
	
					
				CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Sentencia: ' || v_sql_statement , i_log_count, i_id_proceso, 'debug');
				
				EXECUTE IMMEDIATE :v_sql_statement;
					
				num_rows := ::rowcount;
					
				--Actualizamos la IN_BATCH_CONTROL y ponemos el estado a 1
				UPDATE EXT.IN_BATCH_CONTROL SET STATUS = v_const_stage_status_ok, END_DATE = CURRENT_TIMESTAMP , SOURCE_ROWS = num_rows WHERE FILE_NAME = i_file_name AND ID_PROCESO = i_id_proceso;
					
				CALL EXT.LIB_CONSTANTES:WRITE_LOG (v_permisos_log, i_nombre_procedure, 'Fin INSERT en EXT.STAGE_REAJUSTES ' || num_rows || ' filas para el fichero ' || i_file_name, i_log_count, i_id_proceso, 'info');

				
		
	
	END;
  PUBLIC PROCEDURE SP_ES_EMITIDO_DIARIO(IN i_file_name VARCHAR(120), OUT o_es_emitido_diario VARCHAR(1), OUT o_origen_fichero VARCHAR(6)) 
	LANGUAGE SQLSCRIPT AS
	BEGIN 
	
		DECLARE v_const_ocaso VARCHAR2(5) := EXT.LIB_CONSTANTES:CONST_OCASO;
		DECLARE v_const_eterna VARCHAR2(6) := EXT.LIB_CONSTANTES:CONST_ETERNA;
		DECLARE v_const_n VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_N;
		DECLARE v_const_s VARCHAR2(1) := EXT.LIB_CONSTANTES:CONST_S;
	    DECLARE v_const_emi_diario_rrtt_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_OCASO;
	    DECLARE v_const_emi_diario_solnet_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_SOLNET_OCASO;
	    DECLARE v_const_emi_diario_rrggrrpp_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_OC;
	    DECLARE v_const_emi_diario_rrtt_eterna VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRTT_ETERNA;
	    DECLARE v_const_emi_diario_rrggrrpp_eterna VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_EMI_DIARIO_RRGGRRPP_ET;
	    DECLARE v_const_cartera_rrtt_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_RRTT_OCASO;
	    DECLARE v_const_cartera_rrggrrpp_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_RRGGRRPP_OCASO;
	    DECLARE v_const_minicartera_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_MINICARTERA_OCASO;
	    DECLARE v_const_cartera_solnet_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_CARTERA_SOLNET_OCASO;
	    DECLARE v_const_cobros_rrtt_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRTT_OCASO;
	    DECLARE v_const_cobros_rrggrrpp_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGGRRPP_OCASO;
	    
	    DECLARE v_const_cobros_solnet_ocaso VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_SOLNET_OCASO;
	    
	    DECLARE v_const_cobros_rrtt_eterna VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRTT_ETERNA;
	    DECLARE v_const_cobros_rrggrrpp_eterna VARCHAR2(20) := EXT.LIB_CONSTANTES:CONST_COBROS_RRGGRRPP_ETERNA;
	    

		IF (INSTR(i_file_name, v_const_emi_diario_rrtt_ocaso) <> 0 
	         OR INSTR(i_file_name, v_const_emi_diario_solnet_ocaso) > 0 
	         OR INSTR(i_file_name, v_const_emi_diario_rrggrrpp_ocaso) > 0)
	    THEN 
	        SELECT v_const_s, v_const_ocaso INTO o_es_emitido_diario, o_origen_fichero FROM DUMMY;
	        
	    ELSEIF INSTR(i_file_name, v_const_emi_diario_rrtt_eterna) > 0 
	         OR INSTR(i_file_name, v_const_emi_diario_rrggrrpp_eterna) > 0 
	    	THEN
	        	SELECT v_const_s, v_const_eterna INTO o_es_emitido_diario, o_origen_fichero FROM DUMMY;
	        
		    ELSEIF INSTR(i_file_name, v_const_cartera_rrtt_ocaso) > 0 
		        OR INSTR(i_file_name, v_const_cartera_rrggrrpp_ocaso) > 0 
		        OR INSTR(i_file_name, v_const_minicartera_ocaso) > 0 
		        OR INSTR(i_file_name, v_const_cartera_solnet_ocaso) > 0 
		        OR INSTR(i_file_name, v_const_cobros_rrtt_ocaso) > 0 
		        OR INSTR(i_file_name, v_const_cobros_rrggrrpp_ocaso) > 0 
		        OR INSTR(i_file_name, v_const_cobros_solnet_ocaso) > 0 
		    	THEN
		        	SELECT v_const_n, v_const_ocaso INTO o_es_emitido_diario, o_origen_fichero FROM DUMMY;
		        
		    	ELSEIF INSTR(i_file_name, v_const_cobros_rrtt_eterna) > 0 
		         OR INSTR(i_file_name, v_const_cobros_rrggrrpp_eterna) > 0 
		    		THEN
		        		SELECT v_const_n, v_const_eterna INTO o_es_emitido_diario, o_origen_fichero FROM DUMMY;

				END IF;	
		
	END;
END