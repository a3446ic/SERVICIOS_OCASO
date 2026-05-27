CREATE OR REPLACE LIBRARY EXT.LIB_CREAR_TABLAS LANGUAGE SQLSCRIPT AS
BEGIN
  PUBLIC PROCEDURE UPDATE_FECHAS_WEBI (IN i_PeriodSeq BIGINT, IN i_tabla_informe NVARCHAR(255))
	/*---------------------------------------------------------------------
		| Author: Brais Romero García
		| Company: Inycom
		| Initial Version Date: 21-Mayo-2025
		|----------------------------------------------------------------------
		| Procedure Purpose: Procedimiento que actualiza la tabla EXT.OUT_FECHAS_WEBI_REP cuando
		| se crea una nueva versión de una tabla con el SP_CREAR_TABLAS
		| Version:	0.1	BRG 20250521	Initial Version.
		|			1.0 BRG 20250521	Cambiado el nombre de iperiodseq a i_PeriodSeq para seguir la nomenclatura de SP_CREAR_TABLAS
		|			1.1 BRG 20250521	Añadido WHERE PER.REMOVEDATE = TO_DATE('2200-01-01','YYYY-MM-DD') a la llamada de CS_PERIOD
    -----------------------------------------------------------------------
	*/
	LANGUAGE SQLSCRIPT
	SQL SECURITY INVOKER
	AS
	BEGIN
		MERGE INTO EXT.OUT_FECHAS_WEBI_REP AS FEC_WEBI
		USING (
			SELECT
				PER.NAME AS periodo,
				:i_PeriodSeq AS periodseq,
				:i_tabla_informe AS tabla
			FROM CS_PERIOD PER
			WHERE PER.PERIODSEQ = :i_PeriodSeq
				AND PER.REMOVEDATE = TO_DATE('2200-01-01','YYYY-MM-DD')
		) AS CONDICION
		ON FEC_WEBI.PERIODSEQ = CONDICION.periodseq
			AND FEC_WEBI.tabla = CONDICION.tabla
		WHEN MATCHED THEN
			UPDATE SET
				FEC_WEBI.ULTIMA_ACTUALIZACION = UTCTOLOCAL(CURRENT_TIMESTAMP, 'CET')
		WHEN NOT MATCHED THEN
			INSERT (PERIODO, TABLA, ULTIMA_ACTUALIZACION, DESCRIPCION, PERIODSEQ)
			VALUES (
				CONDICION.periodo,
				CONDICION.tabla,
				UTCTOLOCAL(CURRENT_TIMESTAMP, 'CET'),
				'Ultima carga de la tabla ' || :i_tabla_informe,
				CONDICION.periodseq
			);
	END;
  PUBLIC PROCEDURE w_stop (OUT v_stop NUMBER(1))
	/*---------------------------------------------------------------------
	    | Author: Brais Romero García
	    | Company: Inycom
	    | Initial Version Date: 21-Mayo-2025
	    |----------------------------------------------------------------------
	    | Procedure Purpose: Procedimiento para parar la ejecución si fuese necesario
		| Version:	0.1	BRG 20250521	Initial Version.
		|
	    -----------------------------------------------------------------------
	*/
	LANGUAGE SQLSCRIPT
	SQL SECURITY INVOKER
	AS
	BEGIN
	    SELECT GC.GENERICBOOLEAN1 INTO v_stop FROM CS_CLASSIFIER C 
	    INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
	        AND GC.REMOVEDATE = TO_DATE('22000101','YYYYMMDD') AND GC.ISLAST = 1
	    INNER JOIN CS_CATEGORY_CLASSIFIERS CCC ON CCC.CLASSIFIERSEQ = C.CLASSIFIERSEQ
	        AND CCC.REMOVEDATE = TO_DATE('22000101','YYYYMMDD') AND CCC.ISLAST = 1
	        AND CCC.MODELSEQ = 0
	    INNER JOIN CS_CATEGORYTREE CT ON CCC.CATEGORYTREESEQ = CT.CATEGORYTREESEQ AND 
	        CT.REMOVEDATE = TO_DATE('22000101','YYYYMMDD') AND CT.ISLAST = 1
	    WHERE CT.NAME = 'Permisos' AND
	        C.CLASSIFIERID = 'RECARGA' AND
	        C.REMOVEDATE = TO_DATE('22000101','YYYYMMDD') AND C.ISLAST = 1;
	END;
END