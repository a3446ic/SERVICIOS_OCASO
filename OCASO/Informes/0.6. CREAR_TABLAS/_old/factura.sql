
        IF :i_lista_informes = 'FAC_S4' OR :i_lista_informes LIKE '%,FAC_S4,%' OR :i_lista_informes LIKE '%,FAC_S4' OR :i_lista_informes LIKE 'FAC_S4,%' 
            
            OR :i_lista_informes = 'FAC_S5' OR :i_lista_informes LIKE '%,FAC_S5,%' OR :i_lista_informes LIKE '%,FAC_S5' OR :i_lista_informes LIKE 'FAC_S5,%'
                    
            OR :i_lista_informes = 'FAC_S4_E' OR :i_lista_informes LIKE '%,FAC_S4_E,%' OR :i_lista_informes LIKE '%,FAC_S4_E' OR :i_lista_informes LIKE 'FAC_S4_E,%'

            OR :i_lista_informes = 'ALL'
            
        THEN
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, '----------------------------------------', i_log_count, i_id_proceso, 'info');
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Informes S4 Factura Ocaso', i_log_count, i_id_proceso, 'info');
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Informes S4 Factura Eterna', i_log_count, i_id_proceso, 'info');
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Creación Informes S5 Factura Ocaso', i_log_count, i_id_proceso, 'info');

            --ALM 20171113: Comprobamos si el periodo esta posteado y si no lo esta cargamos las tablas de cierre
            IF v_periodo_posteado = 0 THEN
            
                -- LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Inicio borrado y carga de INYC_S4_FACTURA 
                -- BRG 20250527: INYC_S4_FACTURA pasa a ser OUT_S4_FACTURA_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                DELETE FROM EXT.TEST_OUT_S4_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_S4_FACTURA_REP
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE 
                            WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END) 
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END AS IRPF,   
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        SUM(PAY.VALUE) AS IMPORTE,
                        NULL AS SECUENCIAL,
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        PAD_INS.NUMERO,
                        PAD_INS.RESTO_DOMICILIO
                    FROM (SELECT DISTINCT  
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                            X.CUADRO_RRGG_OCASO,X.CUADRO_RRTT_OCASO,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                        FROM :TBL_AGENTES_PRIN_MES X 
                        INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ 
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                    ) PAD_INS
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME
                    --ALM 20160908: Solo cogemos agentes con pagos
                    --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                    INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                        AND PAY.TENANTID = :v_idtenant
                        --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                        --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                        AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                        AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot 
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)    
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
                    GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END) 
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907: Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END,   
                        PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2),
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_S4_FACTURA_REP
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END AS IRPF,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        --SUBSTR(CAR_LP.COD_AGENTE, 1, 4) AS COD_OFICINA,
                        PAD_OF.POSITIONNAME AS COD_OFICINA,
                        PAD_OF.LASTNAME AS OFICINA,
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        sum(CAR_LP.importe) as importe, --SUM(PAY.VALUE) AS IMPORTE
                        NULL AS SECUENCIAL,
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        PAD_INS.NUMERO,
                        PAD_INS.RESTO_DOMICILIO
                    FROM (SELECT DISTINCT
                        x.startdate, x.pos_callidus, /* variables a�adidas, daba error al no encontrarlas */
                        X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                            X.CUADRO_RRGG_OCASO,X.CUADRO_RRTT_OCASO,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                        FROM :TBL_AGENTES_PRIN_MES X
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                        WHERE Y.POSITIONSEQ IS NULL
                    ) PAD_INS
                    INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                        --LLS 20220125: Filtro para tener solo Ocaso
                        AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
                        --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                        --ATV 20250205 Anyadimos el estado N
                        --ATV 20250313 Quitamos el estado N
                        AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
                        --AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO IN ('C', 'N')))
                        --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                        AND CAR_LP.IMPORTE <> 0
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    GROUP BY
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        --SUBSTR(CAR_LP.COD_AGENTE, 1, 4),
                        PAD_OF.POSITIONNAME,
                        PAD_OF.LASTNAME,
                        EC.DESCRIPTION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2),
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                    --ATV 20250321 Modificamos para evitar facturas a 0
                    HAVING SUM(CAR_LP.importe) <> 0;
                v_num_rows := ::ROWCOU
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                --LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Fin borrado y carga de INYC_S4_FACTURA 
                
                --LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Inicio borrado y carga de INYC_S5_FACTURA             
                -- BRG 20250527: INYC_S5_FACTURA pasa a ser OUT_S5_FACTURA_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                DELETE FROM EXT.TEST_OUT_S5_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_S5_FACTURA_REP
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_INSP_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                        --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                        THEN 0 ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END AS IRPF,   
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        SUM(PAY.VALUE) AS IMPORTE,
                        NULL AS SECUENCIAL,
                        --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        PAD_INS.NUMERO,
                        PAD_INS.RESTO_DOMICILIO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    --INNER JOIN INYCEXT.INYC_TABLA_IRPF IRPF ON CASE WHEN PAD_INS.TAXID IS NULL THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END = IRPF.NAME
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME   
                    INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ = PAY.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                        AND PAY.TENANTID = :v_idtenant
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    WHERE SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                        AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S5'
                        --AND PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
                    GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.BOUSERID,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_INSP_OCASO,
                        SUBSTR(PAY.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                        --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                        THEN 0 ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END,   
                        PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2);
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                --LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Fin borrado y carga de INYC_S5_FACTURA             
                
                --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_S4_FACTURA
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL TEST_OUT_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                UPDATE EXT.TEST_OUT_S4_FACTURA_REP F
                    SET SECUENCIAL = 1 + (
                        SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                        FROM (
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_LC_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_LC_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            ) Y 
                    );
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL TEST_OUT_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_S4_FACTURA_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');

                --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_S5_FACTURA
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL TEST_OUT_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                UPDATE EXT.TEST_OUT_S5_FACTURA_REP F
                    SET SECUENCIAL = 1 + (
                        SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                        FROM (
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_LC_S4_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_LC_S5_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            ) Y 
                    );
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL TEST_OUT_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_S5_FACTURA_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');


                -- BRG 20250528: Inicio borrado y carga de OUT_S4_E_FACTURA_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                DELETE FROM EXT.TEST_OUT_S4_E_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_S4_E_FACTURA_REP
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                        SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END AS IRPF,   
                        PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        SUM(PAY.VALUE) AS IMPORTE,
                        NULL AS SECUENCIAL
                    FROM (SELECT DISTINCT  
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                            X.CUADRO_RRGG_ETERNA,X.CUADRO_RRTT_ETERNA,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                        FROM :TBL_AGENTES_PRIN_MES X 
                        INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ 
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                    ) PAD_INS
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME
                    --ALM 20160908: Solo cogemos agentes con pagos
                    --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                    INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                        AND PAY.TENANTID = :v_idtenant
                        --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                        --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                        AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '03'
                        AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                        PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                        SUBSTR(PAY.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                            -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                            --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                            --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                            WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0 
                        END,   
                        PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2);
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_S4_E_FACTURA_REP
                    SELECT
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END AS IRPF,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        PAD_OF.POSITIONNAME AS COD_OFICINA,
                        PAD_OF.LASTNAME AS OFICINA,
                        EC.DESCRIPTION AS COMISION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                        sum(CAR_LP.importe) as importe,--SUM(PAY.VALUE) AS IMPORTE
                        NULL AS SECUENCIAL
                    FROM (SELECT DISTINCT
                            x.startdate, x.pos_callidus, /* variables a�adidas, daba error al no encontrarlas */
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                            X.CUADRO_RRGG_OCASO,X.CUADRO_RRTT_OCASO,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                        FROM :TBL_AGENTES_PRIN_MES X
                        --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                        LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                            AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                            AND X.PERIODSEQ = Y.PERIODSEQ
                            AND Y.TENANTID = :v_idtenant
                            AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                        WHERE Y.POSITIONSEQ IS NULL
                    ) PAD_INS
                    INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                        --LLS 20220125: Filtro para tener solo Eterna
                        AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03'
                        --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                        AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
                        --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                        AND CAR_LP.IMPORTE <> 0
                    --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                    INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                        THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME
                    INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                        AND EC.TENANTID = :v_idtenant
                        AND EC.REMOVEDATE = :v_eot
                    LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    GROUP BY
                        PAD_INS.PARTICIPANTSEQ,
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                        PAD_INS.MUNICIPIO,
                        PAD_INS.DOMICILIO,
                        PAD_INS.CP,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                        CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                            AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                        THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                THEN IRPF.GENERICNUMBER1
                            ELSE 0
                        END,
                        --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                        --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                        --SUBSTR(CAR_LP.COD_AGENTE, 1, 4),
                        PAD_OF.POSITIONNAME,
                        PAD_OF.LASTNAME,
                        EC.DESCRIPTION,
                        SUBSTR(CAR_LP.EARNINGGROUPID,4,2)
                    --ATV 20250321 Modificamos para evitar facturas a 0
                    HAVING SUM(CAR_LP.importe) <> 0;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                -- BRG 20250528: Fin borrado y carga de OUT_S4_E_FACTURA_REP

                -- BRG 20250528: Update campo SECUENCIAL de OUT_S4_E_FACTURA_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL TEST_OUT_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                UPDATE EXT.TEST_OUT_S4_E_FACTURA_REP F
                    SET SECUENCIAL = 1 + (
                        SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                        FROM (
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_S4_E_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            
                            UNION
                            
                            SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                            FROM EXT.TEST_OUT_LC_S4_E_FACTURA_REP X
                            WHERE X.POS_PRIN = F.POS_PRIN
                            --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                            --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                            AND X.PERIODSEQ IN (
                                SELECT P.PERIODSEQ 
                                FROM TCMP.CS_PERIOD P
                                INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                    AND PT.REMOVEDATE = :v_eot
                                    AND PT.NAME = 'month'
                                WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                    AND P.REMOVEDATE = :v_eot)
                            ) Y 
                    );
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL TEST_OUT_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_S4_E_FACTURA_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');


            ELSE
                --ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria            
                IF v_periodo_finalizado = 0 THEN
                
                    --LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Inicio borrado y carga de INYC_LC_S4_FACTURA                         
                    -- BRG 20250527: INYC_LC_S4_FACTURA pasa a ser OUT_LC_S4_FACTURA_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_LC_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.TEST_OUT_LC_S4_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_LC_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.TEST_OUT_LC_S4_FACTURA_REP
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END AS IRPF,   
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            SUM(PAY.VALUE) AS IMPORTE,
                            NULL AS SECUENCIAL,
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                        FROM (SELECT DISTINCT  
                                X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                                X.CUADRO_RRGG_OCASO,X.CUADRO_RRTT_OCASO,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                            FROM :TBL_AGENTES_PRIN_MES X 
                            INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ 
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                                --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                                AND (Y.POSTPIPELINERUNSEQ IS NULL
                                    --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                    OR (v_periodo_posteado > 1
                                        AND Y.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        ) PAD_INS
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME 
                        --ALM 20160908: Solo cogemos agentes con pagos
                        --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                        INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                            AND PAY.TENANTID = :v_idtenant
                            --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                            --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                            AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                            --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                            AND (PAY.POSTPIPELINERUNSEQ IS NULL
                                --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                OR (v_periodo_posteado > 1
                                    AND PAY.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot 
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)    
                        GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END,   
                            PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2),
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.TEST_OUT_LC_S4_FACTURA_REP
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END)
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END AS IRPF,
                            PAD_OF.POSITIONNAME AS COD_OFICINA,
                            PAD_OF.LASTNAME AS OFICINA,
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            sum(CAR_LP.importe) as importe,
                            NULL AS SECUENCIAL,
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                            --ATV 20250509 Anyadimos los campos numero y resto_domicilio a la factura.
                        FROM (SELECT DISTINCT
                            x.startdate, x.pos_callidus, /* variables a�adidas, daba error al no encontrarlas */
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                                X.CUADRO_RRGG_OCASO,X.CUADRO_RRTT_OCASO,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID,X.NUMERO,X.RESTO_DOMICILIO
                            FROM :TBL_AGENTES_PRIN_MES X
                            --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                            LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                            WHERE Y.POSITIONSEQ IS NULL
                        ) PAD_INS
                        INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                            --LLS 20220125: Filtro para tener solo Ocaso
                            AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
                            --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                            AND CAR_LP.ESTADO = 'C'
                            --ALM 20220425: Filtramos para datos no posteados asi evitamos coger los ya pagados en el cierre.
                            AND CAR_LP.SEQ_POST IS NULL
                            --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                            AND CAR_LP.IMPORTE <> 0
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        GROUP BY
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END,
                            PAD_OF.POSITIONNAME,
                            PAD_OF.LASTNAME,
                            EC.DESCRIPTION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2),
                            --ATV 20250509 Anyadimos los campos numero y rersto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                        --ATV 20250321 Modificamos para evitar facturas a 0
                        HAVING SUM(CAR_LP.importe) <> 0;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                    --LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Fin borrado y carga de INYC_LC_S4_FACTURA                         
                
                    --LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Inicio borrado y carga de INYC_LC_S5_FACTURA                                     
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_LC_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.TEST_OUT_LC_S5_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_LC_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.TEST_OUT_LC_S5_FACTURA_REP
                        SELECT 
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_INSP_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                            THEN 0 ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END AS IRPF,   
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            SUM(PAY.VALUE) AS IMPORTE,
                            NULL AS SECUENCIAL,
                            --ATV 20250509 Anyadimos los campos numero y rersto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO
                        FROM :TBL_AGENTES_PRIN_MES PAD_INS
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME   
                        INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ = PAY.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                            AND PAY.TENANTID = :v_idtenant
                            --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                            AND (PAY.POSTPIPELINERUNSEQ IS NULL
                                --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                OR (v_periodo_posteado > 1
                                    AND PAY.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        WHERE SUBSTR(PAY.EARNINGGROUPID,7,2) = '01'
                            AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S5'
                        GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,PAD_INS.BOUSERID,PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_INSP_OCASO,
                            SUBSTR(PAY.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN (CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                            --ALM 20160811: A los pagos del S5 de los empleados no se les aplica IRPF
                                            THEN 0 ELSE IRPF.GENERICNUMBER1 END)
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907: Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END,   
                            PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2),
                            --ATV 20250509 Anyadimos los campos numero y rersto_domicilio a la factura.
                            PAD_INS.NUMERO,
                            PAD_INS.RESTO_DOMICILIO;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                    --LLS 20220103: Lanzamiento conjunto de FAC_S4 y FAC_S5. Fin borrado y carga de INYC_LC_S5_FACTURA                                                 

                    --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_LC_S4_FACTURA
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL TEST_OUT_LC_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    UPDATE EXT.TEST_OUT_LC_S4_FACTURA_REP F
                        SET SECUENCIAL = 1 + (
                            SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                            FROM (
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_LC_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_LC_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                ) Y 
                        );
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL TEST_OUT_LC_S4_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_LC_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_LC_S4_FACTURA_REP');
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_LC_S4_FACTURA_REP', i_log_count, i_id_proceso, 'debug');

                    --LLS 20211215: Petici�n PAC 2022, campo SECUENCIAL INYC_LC_S5_FACTURA
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL TEST_OUT_LC_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    UPDATE EXT.TEST_OUT_LC_S5_FACTURA_REP F
                        SET SECUENCIAL = 1 + (
                            SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                            FROM (
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_LC_S4_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_LC_S5_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                ) Y 
                        );
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL TEST_OUT_LC_S5_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_LC_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_LC_S5_FACTURA_REP');
                    CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_LC_S5_FACTURA_REP', i_log_count, i_id_proceso, 'debug');


                    -- BRG 20250528: Borrado de la tabla OUT_LC_S4_E_FACTURA_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_LC_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    DELETE FROM EXT.TEST_OUT_LC_S4_E_FACTURA_REP WHERE PERIODSEQ = :i_PeriodSeq;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_LC_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    -- BRG 20250528: Carga de la tabla OUT_LC_S4_E_FACTURA_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.TEST_OUT_LC_S4_E_FACTURA_REP
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(PAY.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END AS IRPF,   
                            PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA, 
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(PAY.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            SUM(PAY.VALUE) AS IMPORTE,
                            NULL AS SECUENCIAL
                        FROM (SELECT DISTINCT  
                                X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                                X.CUADRO_RRGG_ETERNA,X.CUADRO_RRTT_ETERNA,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                            FROM :TBL_AGENTES_PRIN_MES X 
                            INNER JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ 
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                                --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                                AND (Y.POSTPIPELINERUNSEQ IS NULL
                                    --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                    OR (v_periodo_posteado > 1
                                        AND Y.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        ) PAD_INS
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        --INNER JOIN INYCEXT.INYC_TABLA_IRPF IRPF ON CASE WHEN PAD_INS.TAXID IS NULL THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END = IRPF.NAME
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME 
                        --ALM 20160908: Solo cogemos agentes con pagos
                        --              Unimos por la Position Principal porque los pagos solo llegaran a las Posiciones Principales
                        INNER JOIN :TBL_PAGOS_MES PAY ON PAD_INS.POSITIONSEQ_PRIN = PAY.POSITIONSEQ
                            AND PAD_INS.PARTICIPANTSEQ = PAY.PAYEESEQ
                            AND PAD_INS.PERIODSEQ = PAY.PERIODSEQ 
                            AND PAY.TENANTID = :v_idtenant
                            --ALM 20160216: Aplicamos los filtros de Compania y Tipo de Informe dentro de la tabla de Pagos
                            --              para que les salga Factura a los agentes sin Pagos, pero si con recibos de Comisiones
                            AND SUBSTR(PAY.EARNINGGROUPID,7,2) = '03'
                            AND SUBSTR(PAY.EARNINGGROUPID,4,2) = 'S4'
                            --ALM 20171201: Filtramos para pagos sin postear, asi no cogemos los pagos del cierre
                            AND (PAY.POSTPIPELINERUNSEQ IS NULL
                                --ALM 20190122: Anadimos un control para quedarnos con el ultimo Post en caso de que haya mas de uno
                                OR (v_periodo_posteado > 1
                                    AND PAY.POSTPIPELINERUNSEQ = (SELECT MAX(PY.POSTPIPELINERUNSEQ) FROM :TBL_PAGOS_MES PY)))
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(PAY.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
                        GROUP BY PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                            PAD_INS.MUNICIPIO,PAD_INS.DOMICILIO,PAD_INS.CP,PAD_INS.POS_PRIN,PAD_INS.CUADRO_RRGG_ETERNA,PAD_INS.CUADRO_RRTT_ETERNA,
                            SUBSTR(PAY.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0 
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(PAY.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END 
                                -- Juridicas que comiencen por estas letras, aplical el tipo de IRPF
                                --ALM 20170907:    Por peticion de Javier quitamos los CIF que empiezan por U
                                --ALM 20180521: A peticion de Javier ponemos IRPF 0 a la CIF pedido.
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0 
                            END,   
                            PAD_OF.POSITIONNAME,PAD_OF.LASTNAME,EC.DESCRIPTION,SUBSTR(PAY.EARNINGGROUPID,4,2);
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
    
                    -- BRG 20250528: Carga de la tabla OUT_LC_S4_E_FACTURA_REP
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');
                    INSERT INTO EXT.TEST_OUT_LC_S4_E_FACTURA_REP
                        SELECT
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2) AS COMPANIA,
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END AS IRPF,
                            --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                            --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                            PAD_OF.POSITIONNAME AS COD_OFICINA,
                            PAD_OF.LASTNAME AS OFICINA,
                            EC.DESCRIPTION AS COMISION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2) AS TIPO_INFORME,
                            sum(CAR_LP.importe) as importe,--SUM(PAY.VALUE) AS IMPORTE
                            NULL AS SECUENCIAL
                        FROM (SELECT DISTINCT
                            x.startdate, x.pos_callidus, /* variables a�adidas, daba error al no encontrarlas */
                            X.PARTICIPANTSEQ,X.POSITIONSEQ_PRIN,X.PERIODSEQ,X.PERIODO,X.BOUSERID,X.NIF,X.FIRSTNAME,X.LASTNAME,X.SUFFIX,X.MUNICIPIO,X.DOMICILIO,X.CP,X.POS_PRIN,
                                X.CUADRO_RRGG_OCASO,X.CUADRO_RRTT_OCASO,X.TIPO_PERSONA,X.ID_EMPLEADO,X.IRPF_EMPLEADO,X.CIA_EMPLEADO,X.TAXID
                            FROM :TBL_AGENTES_PRIN_MES X
                            --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                            LEFT JOIN :TBL_PAGOS_MES Y ON X.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                                AND X.PARTICIPANTSEQ = Y.PAYEESEQ
                                AND X.PERIODSEQ = Y.PERIODSEQ
                                AND Y.TENANTID = :v_idtenant
                                AND SUBSTR(Y.EARNINGGROUPID,7,2) = '03'
                                AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                            WHERE Y.POSITIONSEQ IS NULL
                        ) PAD_INS
                        INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE
                            --LLS 20220125: Filtro para tener solo Eterna
                            AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '03'
                            --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                            AND CAR_LP.ESTADO = 'C'
                            --ALM 20220425: Filtramos para datos no posteados asi evitamos coger los ya pagados en el cierre.
                            AND CAR_LP.SEQ_POST IS NULL
                            --ATV 20241218 No incluimos los registros con importe 0. Cambio debido a problemas en factura
                            AND CAR_LP.IMPORTE <> 0
                        --ALM 20220628: Anadimos una condicion mas para tratar los casos no registrados como los nulos.
                        INNER JOIN :TBL_TABLA_IRPF IRPF ON (CASE WHEN PAD_INS.TAXID IS NULL OR CAST(PAD_INS.TAXID AS VARCHAR2(15)) NOT IN ('I','E','S','C') 
                            THEN 'P' ELSE CAST(PAD_INS.TAXID AS VARCHAR2(15)) END) = IRPF.NAME
                        INNER JOIN TCMP.CS_EARNINGCODE EC ON (SUBSTR(CAR_LP.EARNINGCODEID,1,1) || '00') = EC.EARNINGCODEID
                            AND EC.TENANTID = :v_idtenant
                            AND EC.REMOVEDATE = :v_eot
                        LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                            AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                        GROUP BY
                            PAD_INS.PARTICIPANTSEQ,
                            PAD_INS.POSITIONSEQ_PRIN,
                            PAD_INS.PERIODSEQ,
                            PAD_INS.PERIODO,
                            PAD_INS.BOUSERID,
                            PAD_INS.NIF,
                            RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX),
                            PAD_INS.MUNICIPIO,
                            PAD_INS.DOMICILIO,
                            PAD_INS.CP,
                            PAD_INS.POS_PRIN,
                            PAD_INS.CUADRO_RRGG_OCASO,
                            PAD_INS.CUADRO_RRTT_OCASO,
                            SUBSTR(CAR_LP.EARNINGGROUPID,7,2),
                            CASE WHEN PAD_INS.TIPO_PERSONA = 'F'
                                    THEN CASE WHEN PAD_INS.ID_EMPLEADO IS NOT NULL AND PAD_INS.ID_EMPLEADO <> 0
                                                AND PAD_INS.CIA_EMPLEADO = SUBSTR(CAR_LP.EARNINGGROUPID,7,2)
                                            THEN PAD_INS.IRPF_EMPLEADO ELSE IRPF.GENERICNUMBER1 END
                                WHEN PAD_INS.TIPO_PERSONA = 'J' AND SUBSTR(PAD_INS.NIF,1,1) in ('G','J','E','V') AND PAD_INS.NIF <> 'J72106826'
                                    THEN IRPF.GENERICNUMBER1
                                ELSE 0
                            END,
                            --ALM 20220512: Debemos usar el campo de la tabla de oficinas, no el cod_agente de la tabla de cartera porque puede haber mas de uno distinto para el mismo agente.
                            --              Ej: Agente 42930529V0000, con codigos 0157005922 y 0380005922 para el mes de abril 2022.
                            PAD_OF.POSITIONNAME,
                            PAD_OF.LASTNAME,
                            EC.DESCRIPTION,
                            SUBSTR(CAR_LP.EARNINGGROUPID,4,2)
                        --ATV 20250321 Modificamos para evitar facturas a 0
                        HAVING SUM(CAR_LP.importe) <> 0;
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_E_FACTURA_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Update Campo SECUENCIAL TEST_OUT_LC_S4_E_FACTURA_REP', i_log_count, i_id_proceso, 'debug');
                    UPDATE EXT.TEST_OUT_LC_S4_E_FACTURA_REP F
                        SET SECUENCIAL = 1 + (
                            SELECT IFNULL(MAX(Y.SECUENCIAL),0)
                            FROM (
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_S4_E_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                
                                UNION
                                
                                SELECT MAX(X.SECUENCIAL) AS SECUENCIAL
                                FROM EXT.TEST_OUT_LC_S4_E_FACTURA_REP X
                                WHERE X.POS_PRIN = F.POS_PRIN
                                --ALM 20220228: Usamos el PERIODSEQ para que la consulta vaya mejor ya que la tabla esta particionada por ese campo.
                                --AND X.PERIODO LIKE '%' || SUBSTR(F.PERIODO,-4)
                                AND X.PERIODSEQ IN (
                                    SELECT P.PERIODSEQ 
                                    FROM TCMP.CS_PERIOD P
                                    INNER JOIN TCMP.CS_PERIODTYPE PT ON PT.PERIODTYPESEQ = P.PERIODTYPESEQ
                                        AND PT.REMOVEDATE = :v_eot
                                        AND PT.NAME = 'month'
                                    WHERE P.NAME LIKE '%' || SUBSTR(F.PERIODO,-4)
                                        AND P.REMOVEDATE = :v_eot)
                                ) Y 
                        );
                    v_num_rows := ::ROWCOUNT;
                    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Update Campo SECUENCIAL TEST_OUT_LC_S4_E_FACTURA_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                    
                END IF;
                
            END IF;
            
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Informes S4 Factura Ocaso', i_log_count, i_id_proceso, 'info');
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Informes S4 Factura Eterna', i_log_count, i_id_proceso, 'info');
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Creación Informes S5 Factura Ocaso', i_log_count, i_id_proceso, 'info');
            
            -- Revisamos si se debe detener el proceso
			CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
			IF v_stop = 0 THEN
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
				RETURN;
			END IF;

        END IF;