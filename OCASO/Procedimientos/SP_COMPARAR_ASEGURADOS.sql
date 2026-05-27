CREATE PROCEDURE EXT.SP_COMPARAR_ASEGURADOS (OUT FILENAME VARCHAR(200) , IN i_fichero_entrada VARCHAR(500))
LANGUAGE SQLSCRIPT  
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Diego Teijo Barral
    | Company: Inycom
    | Initial Version Date: 26-Septiembre-2025
    |----------------------------------------------------------------------
    | Procedure Purpose: Exporta las asegurados
	|
	| Version: 0.1	DTB 20250926		Initial Version.
	|
    -----------------------------------------------------------------------
*/
BEGIN

    -- DECLARACIÓN DE NOMBRE FICHERO FINAL
    DECLARE v_file_name VARCHAR(25) := 'DEBUG_ASEGURADOS';
    SELECT :v_file_name || :i_fichero_entrada INTO FILENAME FROM DUMMY;
	
    TRUNCATE TABLE EXT.COMPARAR_ASEGURADOS_DEBUG;

    INSERT INTO EXT.COMPARAR_ASEGURADOS_DEBUG
        SELECT 
			IFNULL(TO_VARCHAR(CODIGO_POLIZA),'') ||';'|| IFNULL(TO_VARCHAR(NUMERO_ASEGURADO),'') ||';'|| IFNULL(TO_VARCHAR(TRIM(NIF)),'') ||';'|| IFNULL(TO_VARCHAR(FECHA_NACIMIENTO,'YYYY-MM-DD'),'') ||';'|| IFNULL(TO_VARCHAR(FECHA_DE_DERECHOS,'YYYY-MM-DD'),'') ||';'|| IFNULL(TO_VARCHAR(MOTIVO_ALTA),'') ||';'|| IFNULL(TO_VARCHAR(CONTO_COMO_ALTA),'') ||';'|| IFNULL(TO_VARCHAR(CONTO_COMO_NUEVO),'') ||';'|| IFNULL(TO_VARCHAR(FECHA_ALTA,'YYYY-MM-DD'),'') ||';'|| IFNULL(TO_VARCHAR(MOTIVO_BAJA),'') ||';'|| IFNULL(TO_VARCHAR(FECHA_BAJA,'YYYY-MM-DD'),'') ||';'|| IFNULL(TO_VARCHAR(FECHA_REHABILITACION,'YYYY-MM-DD'),'') ||';'|| IFNULL(TO_VARCHAR(POLIZA_ORIGEN),'') ||';'|| IFNULL(TO_VARCHAR(ASEGURADO_ORIGEN),'') ||';'|| IFNULL(TO_VARCHAR(EDAD),'') ||';'|| IFNULL(TO_VARCHAR(EDAD_DERECHOS),'') ||';'|| IFNULL(TO_VARCHAR(FILE_NAME),'') 
        FROM EXT.ASEGURADOS WHERE FILE_NAME = :i_fichero_entrada;
        
END
