--DTB 20250526: Tabla para el Detalle de Polizas y Productos del S4 de OCASO
IF :i_lista_informes = 'S4' OR :i_lista_informes LIKE '%,S4,%' OR :i_lista_informes LIKE '%,S4' OR :i_lista_informes LIKE 'S4,%' OR :i_lista_informes = 'ALL' THEN
        --ALM 20170420: Comprobamos si el periodo esta cerrado y si no lo esta cargamos las tablas de cierre
        --ALM 20171113: Comprobamos si el periodo esta posteado y si no lo esta cargamos las tablas de cierre
        --IF v_periodo_finalizado = 0 THEN
        IF v_periodo_posteado = 0 THEN

            --DTB 20250526: Borrado tabla TEST_OUT_S4_POLIZAS_REP
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
			DELETE FROM EXT.TEST_OUT_S4_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_S4_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
            
            
            --DTB 20250526: Insert tabla TEST_OUT_S4_POLIZAS_REP Creditos (Nueva Produccion)
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_POLIZAS_REP. Creditos (Nueva Produccion)', i_log_count, i_id_proceso, 'debug');            
            INSERT INTO EXT.TEST_OUT_S4_POLIZAS_REP 
                SELECT 
                    PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                    PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                    PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                    RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                    PAD_INS.POS_PRIN,
                    PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                    ST.CHANNEL AS COMPANIA,
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                    C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                    --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                    CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' AND ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                    CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                    --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                    CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                    ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                    ST.GENERICNUMBER1 AS PRIMA_NETA,
                    PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                        ELSE 4
                    END AS NIVEL_PTO_VENTA,
                    PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                    PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        ELSE 3
                    END AS NIVEL_OFICINA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        ELSE 2
                    END AS NIVEL_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                    END AS COD_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                            ELSE PAD_PTO_VENTA.LASTNAME END 
                    END AS SUCURSAL,
                    1 AS NIVEL_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END
                    END END AS COD_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END
                    END END AS REGIONAL,
                    --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                    PAD_INS.SUPERRAPEL,
                    C.GENERICNUMBER1 AS ASEGURADOS,
                    --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                    ST.GENERICATTRIBUTE7 AS COD_RECIBO
                FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                    AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                    AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                    --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                    AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0) 
                    AND C.NAME LIKE 'DC-O-COM-NuevaProduccion%'
                INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                    AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
                    AND REG.COD_INFORME = 100.2 
                --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
                    --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                    --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                    --AND ST.PRODUCTID like '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA    
                ;
            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_POLIZAS_REP. Creditos (Nueva Produccion). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
            
            --DTB 20250526: Insert tabla TEST_OUT_S4_POLIZAS_REP Creditos (Asistencias)
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_POLIZAS_REP. Creditos (Asistencias)', i_log_count, i_id_proceso, 'debug');            
            INSERT INTO EXT.TEST_OUT_S4_POLIZAS_REP 
                SELECT 
                    PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                    PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                    PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                    RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                    PAD_INS.POS_PRIN,
                    PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                    ST.CHANNEL AS COMPANIA,
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                    C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                    --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                    --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                    CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                    CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                    --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                    CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                    ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                    ST.GENERICNUMBER1 AS PRIMA_NETA,
                    PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                        ELSE 4
                    END AS NIVEL_PTO_VENTA,
                    PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                    PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        ELSE 3
                    END AS NIVEL_OFICINA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        ELSE 2
                    END AS NIVEL_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                    END AS COD_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                            ELSE PAD_PTO_VENTA.LASTNAME END 
                    END AS SUCURSAL,
                    1 AS NIVEL_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END
                    END END AS COD_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END
                    END END AS REGIONAL,
                    --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                    PAD_INS.SUPERRAPEL,
                    C.GENERICNUMBER1 AS ASEGURADOS,
                    --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                    ST.GENERICATTRIBUTE7 AS COD_RECIBO
                FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                    AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                    AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                    --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                    AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                    --ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
                    --AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
                    AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
                    AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                    --ALM 20170329: Filtramos para quedarnos con creditos de Ocaso igual que hacemos en Eterna
                    AND C.GENERICATTRIBUTE9 = '01'
                INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                    AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                    AND REG.COD_INFORME = 100.2
                --ALM 20160907: Para las Asistencias filtramos para agentes segun su PLAN
                INNER JOIN :TBL_AGENTES_MES PAD_AG ON PAD_INS.PARTICIPANTSEQ = PAD_AG.PARTICIPANTSEQ 
                    AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
                    AND PAD_INS.POSITIONSEQ = PAD_AG.POSITIONSEQ
                    AND PAD_AG.PLANNAME LIKE 'Plan_O_%'
                --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                    --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                    --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                    --AND ST.PRODUCTID LIKE '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA    
                ;
            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
           
            --DTB 20250526: Insert tabla TEST_OUT_S4_POLIZAS_REP Creditos (Resto Creditos)
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_POLIZAS_REP. Creditos (Resto Creditos)', i_log_count, i_id_proceso, 'debug');      
            INSERT INTO EXT.TEST_OUT_S4_POLIZAS_REP 
                SELECT 
                    PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                    PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                    PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                    RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                    PAD_INS.POS_PRIN,
                    PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                    ST.CHANNEL AS COMPANIA,
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                    C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                    --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                    --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                    CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                    CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                    --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                    CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                    ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                    ST.GENERICNUMBER1 AS PRIMA_NETA,
                    PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                        ELSE 4
                    END AS NIVEL_PTO_VENTA,
                    PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                    PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        ELSE 3
                    END AS NIVEL_OFICINA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        ELSE 2
                    END AS NIVEL_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                    END AS COD_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                            ELSE PAD_PTO_VENTA.LASTNAME END 
                    END AS SUCURSAL,
                    1 AS NIVEL_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END
                    END END AS COD_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END
                    END END AS REGIONAL,
                    --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                    PAD_INS.SUPERRAPEL,
                    --ALM 20220530: Los creditos de las Gestiones traen en el GN1 el objetivo por lo que ponemos este valor a 0.
                    --C.GENERICNUMBER1 AS ASEGURADOS
                    (CASE WHEN C.NAME = 'DC-O-COM-GestionExplotacion' THEN 0 ELSE C.GENERICNUMBER1 END) AS ASEGURADOS,
                    --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                    ST.GENERICATTRIBUTE7 AS COD_RECIBO
                FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                    AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                    AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                    --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                    AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                    --ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
                    --AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                    AND C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
                    AND C.NAME NOT LIKE 'DC-O-COM-NuevaProduccion%'
                INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                    AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
                    AND REG.COD_INFORME = 100.2 
                --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                    --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                    --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                    --AND ST.PRODUCTID like '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA      
                ;              
            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_POLIZAS_REP. Creditos (Resto Creditos). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
            
            --DTB 20250526: Insert tabla TEST_OUT_S4_POLIZAS_REP Pagos Comerciales 1** y 2**
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**', i_log_count, i_id_proceso, 'debug');        
            INSERT INTO EXT.TEST_OUT_S4_POLIZAS_REP               
                SELECT 
                    PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                    PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                    PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                    RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                    PAD_INS.POS_PRIN,
                    PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                    SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                    D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                    --ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
                    SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                    '999999900000000' AS POLIZA,
                    CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                        THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
                    D.DEPOSITDATE AS FEC_CARGO,
                    0 AS PRIMA_COMISIONABLE,
                    --ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
                    --              depende del concepto de pago.
                    --(SELECT ET.DESCRIPTION FROM TCMP.CS_EVENTTYPE ET WHERE ET.EVENTTYPEID = 'Pago Comercial' AND ET.REMOVEDATE = :v_eot)
                    CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
                        WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
                        --ALM 20180420: Anadimos los pagos comerciales de concepto 107 a las recuperaciones por peticion de Miguel Angel Arrabe
                        WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('107') THEN 'Recuperacion'
                        WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
                        --ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
                        WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
                        WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
                        ELSE 'Division Comercial'
                    END AS EVENTO,
                    PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                    '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                    PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                        ELSE 4
                    END AS NIVEL_PTO_VENTA,
                    PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                    PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        ELSE 3
                    END AS NIVEL_OFICINA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        ELSE 2
                    END AS NIVEL_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                    END AS COD_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                            ELSE PAD_PTO_VENTA.LASTNAME END 
                    END AS SUCURSAL,
                    1 AS NIVEL_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END
                    END END AS COD_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END
                    END END AS REGIONAL,
                    --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                    PAD_INS.SUPERRAPEL,
                    0 AS ASEGURADOS,
                    --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                    '' AS COD_RECIBO
                FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                    AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                    AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                    AND D.TENANTID = :v_idtenant
                    --ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
                    AND D.EARNINGGROUPID LIKE '%S4%'
                    --ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
                    --              Correo de Afonso el 06/09/2016
                    AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                --ALM 20180822: Nos quedamos con las 15 primeras letras del nombre del deposito para tener en cuenta los depositos antiguos de Abril y Mayo
                --              de 2016 que pueden venir con diferentes nombre (D-O-Pagos-Fijos-x)    
                --INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME, = REG.REGLA
                INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,15) = REG.REGLA
                    AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                    AND REG.COD_INFORME = 100.2 
                --ALM 20160701: Utilizamos un INNER porque si el Pago Comercial viene sin producto no queremos que aparezca en el detalle (correo Javier 21/06)
                --              Unimos por el Producto que vendra en el EARNINGCODEID (ej: 101-0121000)
                --INNER JOIN TCMP.CS_CLASSIFIER CL ON SUBSTR(D.EARNINGCODEID,5,7) = CL.CLASSIFIERID
                --ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
                --              Necesario para Pagos Comerciales de Abril y Mayo 2016
                INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                        THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
                    AND CL.REMOVEDATE = :v_eot  
                    AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                    AND CL.TENANTID = :v_idtenant
                LEFT OUTER JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                    AND PROD.REMOVEDATE = :v_eot  
                    AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                    AND PROD.TENANTID = :v_idtenant
                --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                    --ALM 20160617: Pueden llegar Pagos Comerciales sin Producto
                    --No es necesario filtrar por la compania porque el Deposito ya lo distingue (D-O-Pagos-Fijos o D-E-Pagos-Fijos)
                    --AND SUBSTR(D.GENERICATTRIBUTE1,1,2) = '01';    
                ;
            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                      
            --LLS 20220124: Caso especifico del deposito D-O-GestionExplotacion-PagoInicial (regla D-O-COM-GestionExplotacion-PagoInicial) de Enero 2022
            --DTB 20250526: Insert tabla TEST_OUT_S4_POLIZAS_REP caso especifico            
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_POLIZAS_REP.  Pago Inicial Gestion Explotacion', i_log_count, i_id_proceso, 'debug');
            INSERT INTO EXT.TEST_OUT_S4_POLIZAS_REP               
                SELECT 
                    PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                    PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                    PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                    RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                    PAD_INS.POS_PRIN,
                    PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                    SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                        ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                        ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                    D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                    SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                    '999999900000000' AS POLIZA,
                    CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                        THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
                    D.DEPOSITDATE AS FEC_CARGO,
                    0 AS PRIMA_COMISIONABLE,
                    'Gestiones referencias explotacion' AS EVENTO,
                    PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                    '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                    PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                    ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                        ELSE 4
                    END AS NIVEL_PTO_VENTA,
                    PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                    PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        ELSE 3
                    END AS NIVEL_OFICINA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        ELSE 2
                    END AS NIVEL_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                    END AS COD_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                            ELSE PAD_PTO_VENTA.LASTNAME END 
                    END AS SUCURSAL,
                    1 AS NIVEL_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END
                    END END AS COD_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END
                    END END AS REGIONAL,
                    PAD_INS.SUPERRAPEL,
                    0 AS ASEGURADOS,
                    --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                    '' AS COD_RECIBO
                FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                    AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                    AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                    AND D.TENANTID = :v_idtenant
                    AND D.EARNINGGROUPID LIKE '%S4%'
                    AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                    AND D.NAME = 'D-O-GestionExplotacion-PagoInicial'
                INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
                    AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                    AND REG.COD_INFORME = 100.2 
                LEFT JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                        THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
                    AND CL.REMOVEDATE = :v_eot  
                    AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                    AND CL.TENANTID = :v_idtenant
                LEFT OUTER JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                    AND PROD.REMOVEDATE = :v_eot  
                    AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                    AND PROD.TENANTID = :v_idtenant
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                ;
            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
           
            --DTB 20250526: Insert tabla TEST_OUT_S4_POLIZAS_REP Agentes DDEE            
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_S4_POLIZAS_REP. Agentes Derechos Económicos', i_log_count, i_id_proceso, 'debug');
            INSERT INTO EXT.TEST_OUT_S4_POLIZAS_REP        
                SELECT 
                    PAD_INS.PARTICIPANTSEQ, 
                    PAD_INS.POSITIONSEQ_PRIN,
                    PAD_INS.PERIODSEQ,
                    PAD_INS.PERIODO,
                    PAD_INS.BOUSERID,
                    PAD_INS.POSITIONNAME,
                    PAD_INS.NIF,
                    RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                    PAD_INS.POS_PRIN,
                    PAD_INS.CUADRO_RRGG_OCASO,
                    PAD_INS.CUADRO_RRTT_OCASO,
                    SUBSTR (CAR_LP.ORDERID,1,2) AS COMPANIA, --order id 2 primeros digitos
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                    'CARTERA_LP' AS NAME, --C.NAME,
                    CAR_LP.IMPORTE AS VALUE, --C.VALUE,
                    0 AS POLIZ_CORR,
                    0 AS POLIZ_NP,
                    CAR_LP.ORDERID || CAST(CAR_LP.SUBLINENUMBER AS VARCHAR2(127)) AS SALESTRANSACTIONSEQ,
                    CAR_LP.POLIZA, --ST.GENERICATTRIBUTE1 AS POLIZA,
                    CAR_LP.PRODUCTID,
                    CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
                    CAR_LP.VALUE AS PRIMA_COMISIONABLE,
                    CAR_LP.EVENTO,--ST.EVENTO,
                    CAR_LP.PRODUCTO,--ST.PRODUCTO,
                    CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
                    CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
                    PAD_INS.ID_TIPO_AGENTE,
                    PAD_INS.TIPO_AGENTE,
                    CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                        ELSE 4
                    END AS NIVEL_PTO_VENTA,
                    PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                    PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                        ELSE 3
                    END AS NIVEL_OFICINA,
                    CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                        ELSE 2
                    END AS NIVEL_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                            ELSE PAD_PTO_VENTA.POSITIONNAME END 
                    END AS COD_SUCURSAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                            ELSE PAD_PTO_VENTA.LASTNAME END 
                    END AS SUCURSAL,
                    1 AS NIVEL_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END
                    END END AS COD_REGIONAL,
                    CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                        ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END
                    END END AS REGIONAL,
                    PAD_INS.SUPERRAPEL,
                    0 AS ASEGURADOS,
                    --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                    '' AS COD_RECIBO
                FROM :TBL_AGENTES_PRIN_MES PAD_INS
                INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
                    --LLS 20220125: Filtro para tener solo Ocaso
                    AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
                    --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                    --ATV 20250205 Anyadimos el estado N
                    --AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO = 'C'))
                    AND (v_FV_EstadoTrx = 0 OR (v_FV_EstadoTrx = 1 AND CAR_LP.ESTADO IN ('C', 'N')))
                    --ALM 20220603: No incluimos registros sin importe de comision.
                    AND CAR_LP.IMPORTE <> 0
                --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
                        AND Y.TENANTID = :v_idtenant
                        AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                        AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                --dejamos estos left join para tener los datos de las oficinas
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                    AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                    AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                    AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                    AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                WHERE Y.POSITIONSEQ IS NULL;
            v_num_rows := ::ROWCOUNT;
            CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_S4_POLIZAS_REP. Agentes Derechos Económicos. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
                                        
            --ALM 20220221: Quitamos el uso del parametro v_licencias para reducir codigo.
            --END IF;
            --DTB 20250526: --Actualización fechas_webi tabla TEST_OUT_S4_POLIZAS_REP
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
            CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_S4_POLIZAS_REP');
            CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
    
        --ALM 20170420: Si el periodo esta cerrado cargamos las tablas de balances
        ELSE
            --ALM 20171113: Si el periodo esta posteado, comprobamos si esta finalizado y si no lo esta cargamos las tablas de liquidacion complementaria
            IF v_periodo_finalizado = 0 THEN
            
                --DTB 20250526: Borrado tabla TEST_OUT_LC_S4_POLIZAS_REP 
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_LC_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
			    DELETE FROM EXT.TEST_OUT_LC_S4_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
			    v_num_rows := ::ROWCOUNT;
			    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_LC_S4_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                --DTB 20250526: Insert tabla TEST_OUT_LC_S4_POLIZAS_REP Creditos (Nueva Producción)
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_POLIZAS_REP. Creditos (Nueva producción)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_LC_S4_POLIZAS_REP 
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        ST.CHANNEL AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170719: Para los nuevos creditos del Corte Ingles (SECI) no contamos polizas
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' AND ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' AND ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        C.GENERICNUMBER1 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        ST.GENERICATTRIBUTE7 AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        AND C.NAME LIKE 'DC-O-COM-NuevaProduccion%'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                    --ALM 20161221: Al tener TXN de mas de 3 meses no podemos unir con este tipo de tablas directamente porque hacen que el proceso se eternice.
                    --INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    --    AND TA.TENANTID = :v_idtenant
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
                        --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                        --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                        --AND ST.PRODUCTID like '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA    
                    ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_POLIZAS_REP. Creditos (Nueva producción). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');
           
                --DTB 20250526: Insert tabla TEST_OUT_LC_S4_POLIZAS_REP Creditos (Asistencias)
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_POLIZAS_REP. Creditos (Asistencias)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_LC_S4_POLIZAS_REP 
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        ST.CHANNEL AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        C.GENERICNUMBER1 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        ST.GENERICATTRIBUTE7 AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        --ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
                        --AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
                        AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
                        AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                        --ALM 20170329: Filtramos para quedarnos con creditos de Ocaso igual que hacemos en Eterna
                        AND C.GENERICATTRIBUTE9 = '01'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                    --INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    --    AND TA.TENANTID = :v_idtenant
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2
                    --ALM 20160907: Para las Asistencias filtramos para agentes segun su PLAN
                    INNER JOIN :TBL_AGENTES_MES PAD_AG ON PAD_INS.PARTICIPANTSEQ = PAD_AG.PARTICIPANTSEQ
                        AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = PAD_AG.POSITIONSEQ
                        AND PAD_AG.PLANNAME LIKE 'Plan_O_%'
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ 
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                        --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                        --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                        --AND ST.PRODUCTID LIKE '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA    
                    ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                
                --DTB 20250526: Insert tabla TEST_OUT_LC_S4_POLIZAS_REP Creditos (Resto Creditos)
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_POLIZAS_REP. Creditos (Resto Creditos)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_LC_S4_POLIZAS_REP 
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        ST.CHANNEL AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        --ALM 20220530: Los creditos de las Gestiones traen en el GN1 el objetivo por lo que ponemos este valor a 0.
                        --C.GENERICNUMBER1 AS ASEGURADOS
                        (CASE WHEN C.NAME = 'DC-O-COM-GestionExplotacion' THEN 0 ELSE C.GENERICNUMBER1 END) AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        ST.GENERICATTRIBUTE7 AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        --ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no hya que cogerlo.
                        --AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                        AND C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
                        AND C.NAME NOT LIKE 'DC-O-COM-NuevaProduccion%'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                    --INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    --    AND TA.TENANTID = :v_idtenant
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                        --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                        --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                        --AND ST.PRODUCTID like '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA      
                    ;              
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_POLIZAS_REP. Creditos (Resto Creditos). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                
                --DTB 20250526: Insert tabla TEST_OUT_LC_S4_POLIZAS_REP Pagos Comerciales 1** y 2**
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**)', i_log_count, i_id_proceso, 'debug');                        
                INSERT INTO EXT.TEST_OUT_LC_S4_POLIZAS_REP               
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                        --ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
                        SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                        '999999900000000' AS POLIZA,
                        CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
                        D.DEPOSITDATE AS FEC_CARGO,
                        0 AS PRIMA_COMISIONABLE,
                        --ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
                        --              depende del concepto de pago.
                        --(SELECT ET.DESCRIPTION FROM TCMP.CS_EVENTTYPE ET WHERE ET.EVENTTYPEID = 'Pago Comercial' AND ET.REMOVEDATE = :v_eot)
                        CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
                            --ALM 20180420: Anadimos los pagos comerciales de concepto 107 a las recuperaciones por peticion de Miguel Angel Arrabe
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('107') THEN 'Recuperacion'
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
                            --ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
                            ELSE 'Division Comercial'
                        END AS EVENTO,
                        PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                        '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        '' AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                        AND D.TENANTID = :v_idtenant
                        --ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
                        AND D.EARNINGGROUPID LIKE '%S4%'
                        --ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
                        --              Correo de Afonso el 06/09/2016
                        AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                    --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                    INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                    --ALM 20180822: Nos quedamos con las 15 primeras letras del nombre del deposito para tener en cuenta los depositos antiguos de Abril y Mayo
                    --              de 2016 que pueden venir con diferentes nombre (D-O-Pagos-Fijos-x)    
                    --INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME, = REG.REGLA
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,15) = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    --ALM 20160701: Utilizamos un INNER porque si el Pago Comercial viene sin producto no queremos que aparezca en el detalle (correo Javier 21/06)
                    --              Unimos por el Producto que vendra en el EARNINGCODEID (ej: 101-0121000)
                    --INNER JOIN TCMP.CS_CLASSIFIER CL ON SUBSTR(D.EARNINGCODEID,5,7) = CL.CLASSIFIERID
                    --ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
                    --              Necesario para Pagos Comerciales de Abril y Mayo 2016
                    INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
                        AND CL.REMOVEDATE = :v_eot  
                        AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND CL.TENANTID = :v_idtenant
                    LEFT OUTER JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                        AND PROD.REMOVEDATE = :v_eot  
                        AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND PROD.TENANTID = :v_idtenant
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                        --ALM 20160617: Pueden llegar Pagos Comerciales sin Producto
                        --No es necesario filtrar por la compania porque el Deposito ya lo distingue (D-O-Pagos-Fijos o D-E-Pagos-Fijos)
                        --AND SUBSTR(D.GENERICATTRIBUTE1,1,2) = '01';    
                    ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                         
                --LLS 20220124: Caso espec�fico del dep�sito D-O-GestionExplotacion-PagoInicial (regla D-O-COM-GestionExplotacion-PagoInicial) de Enero 2022
                --DTB 20250526: Insert tabla TEST_OUT_LC_S4_POLIZAS_REP caso especifico
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion.)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_LC_S4_POLIZAS_REP
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                        SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                        '999999900000000' AS POLIZA,
                        CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
                        D.DEPOSITDATE AS FEC_CARGO,
                        0 AS PRIMA_COMISIONABLE,
                        'Gestiones referencias explotacion' AS EVENTO,
                        PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                        '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        '' AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                        AND D.TENANTID = :v_idtenant
                        AND D.EARNINGGROUPID LIKE '%S4%'
                        AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                        AND D.NAME = 'D-O-GestionExplotacion-PagoInicial'
                    INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    LEFT JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
                        AND CL.REMOVEDATE = :v_eot  
                        AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND CL.TENANTID = :v_idtenant
                    LEFT OUTER JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                        AND PROD.REMOVEDATE = :v_eot  
                        AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND PROD.TENANTID = :v_idtenant
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    ;           
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                            
                --DTB 20250526: Insert tabla TEST_OUT_LC_S4_POLIZAS_REP Agentes Derechos Economicos
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_LC_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS.)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_LC_S4_POLIZAS_REP        
                     SELECT 
                        PAD_INS.PARTICIPANTSEQ, 
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.POSITIONNAME,
                        PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR (CAR_LP.ORDERID,1,2) AS COMPANIA, /*order id 2 primeros digitos*/
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        'CARTERA_LP' AS NAME, --C.NAME,
                        CAR_LP.IMPORTE AS VALUE, --C.VALUE,
                        0 as POLIZ_CORR,
                        0 as POLIZ_NP,
                        CAR_LP.ORDERID ||CAST(CAR_LP.SUBLINENUMBER AS VARCHAR2(127)) AS SALESTRANSACTIONSEQ,
                        CAR_LP.POLIZA, --ST.GENERICATTRIBUTE1 AS POLIZA,
                        CAR_LP.PRODUCTID,
                        CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
                        CAR_LP.VALUE AS PRIMA_COMISIONABLE,
                        CAR_LP.EVENTO,--ST.EVENTO,
                        CAR_LP.PRODUCTO,--ST.PRODUCTO,
                        CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
                        CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,
                        PAD_INS.TIPO_AGENTE,
                        CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        '' AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
                        --LLS 20220125: Filtro para tener solo Ocaso
                        AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
                        --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                        --ATV 20250205 Anyadimos el estado N
                        --AND CAR_LP.ESTADO = 'C'
                        AND CAR_LP.ESTADO IN ('C', 'N')
                        --ALM 20220603: No incluimos registros sin importe de comision.
                        AND CAR_LP.IMPORTE <> 0
                    --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                    LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
                        AND Y.TENANTID = :v_idtenant
                        AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                        AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                    /** dejamos estos left join para tener los datos de las oficinas **/
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                    WHERE Y.POSITIONSEQ IS NULL
                     ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_LC_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                
                
                --DTB 20250526: --Actualización fechas_webi tabla TEST_OUT_LC_S4_POLIZAS_REP
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_LC_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_LC_S4_POLIZAS_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_LC_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
                
            
            --ALM 20171113: Si el periodo esta posteado y finalizado cargamos las tablas de balances
            ELSE
                --DTB 20250526: Borrado tabla TEST_OUT_BAL_S4_POLIZAS_REP
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Borrado TEST_OUT_BAL_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
			    DELETE FROM EXT.TEST_OUT_BAL_S4_POLIZAS_REP WHERE PERIODSEQ = :i_PeriodSeq;
			    v_num_rows := ::ROWCOUNT;
			    CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Borrado TEST_OUT_BAL_S4_POLIZAS_REP. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                --DTB 20250526: Insert tabla TEST_OUT_BAL_S4_POLIZAS_REP Creditos (Nueva Produccion)
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_BAL_S4_POLIZAS_REP. Creditos (Nueva Produccion).)', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_BAL_S4_POLIZAS_REP 
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        ST.CHANNEL AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170719: Para los nuevos creditos del Corte Ingles (SECI) no contamos polizas
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' AND ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CASE WHEN C.NAME <> 'DC-O-COM-NuevaProduccion-SECI' AND ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        C.GENERICNUMBER1 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        ST.GENERICATTRIBUTE7 AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        AND C.NAME LIKE 'DC-O-COM-NuevaProduccion%'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                    --ALM 20161221: Al tener TXN de mas de 3 meses no podemos unir con este tipo de tablas directamente porque hacen que el proceso se eternice.
                    --INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    --    AND TA.TENANTID = :v_idtenant
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ
                        --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                        --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                        --AND ST.PRODUCTID like '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA    
                    ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_BAL_S4_POLIZAS_REP. Creditos (Nueva Produccion). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');

                --DTB 20250526: Insert tabla TEST_OUT_BAL_S4_POLIZAS_REP Creditos (Asistencias)
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_BAL_S4_POLIZAS_REP. Creditos (Asistencias).)', i_log_count, i_id_proceso, 'debug');                
                INSERT INTO EXT.TEST_OUT_BAL_S4_POLIZAS_REP 
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        ST.CHANNEL AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        C.GENERICNUMBER1 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        ST.GENERICATTRIBUTE7 AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        --ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no haya que cogerlo.
                        --AND C.NAME = 'DC-O-COM-ServiciosAsistencia-Importe'
                        AND C.NAME LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
                        AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                        --ALM 20170329: Filtramos para quedarnos con creditos de Ocaso igual que hacemos en Eterna
                        AND C.GENERICATTRIBUTE9 = '01'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ
                    --INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    --    AND TA.TENANTID = :v_idtenant
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2
                    --ALM 20160907: Para las Asistencias filtramos para agentes segun su PLAN
                    INNER JOIN :TBL_AGENTES_MES PAD_AG ON PAD_INS.PARTICIPANTSEQ = PAD_AG.PARTICIPANTSEQ 
                        AND PAD_INS.PERIODSEQ = PAD_AG.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = PAD_AG.POSITIONSEQ
                        AND PAD_AG.PLANNAME LIKE 'Plan_O_%'
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                        --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                        --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                        --AND ST.PRODUCTID LIKE '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA    
                    ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_BAL_S4_POLIZAS_REP. Creditos (Asistencias). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                
                
                --DTB 20250526: Insert tabla TEST_OUT_BAL_S4_POLIZAS_REP Creditos (Resto Creditos)
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_BAL_S4_POLIZAS_REP. Creditos (Resto Creditos).', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_BAL_S4_POLIZAS_REP 
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        ST.CHANNEL AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        C.NAME,C.VALUE,C.GENERICNUMBER4 AS POLIZ_CORR,
                        --ALM 20170911: Utilizamos el EVENTYPESEQ de la transaccion en lugar de la descripcion para evitar problemas con las tildes
                        --CASE WHEN ST.EVENTO = 'Alta Nueva Produccion' AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CASE WHEN ST.EVENTTYPESEQ = 16607023625928867 AND ST.GARANTIA = 0 THEN 1*SIGN(C.VALUE) ELSE 0 END AS POLIZ_NP,
                        CAST(ST.SALESTRANSACTIONSEQ AS VARCHAR2(127 BYTE)),ST.GENERICATTRIBUTE1 AS POLIZA,ST.PRODUCTID,ST.ACCOUNTINGDATE AS FEC_CARGO,
                        --ALM 20160819: Para las TXN de Asistencias (Tipo de Evento => AS50,AS90,AS91,AS10) la Prima Comisionable es 0 y en la txn viene un 1. 
                        CASE WHEN ST.EVENTTYPESEQ in (16607023625929186,16607023625929187,16607023625929188,16607023625929189,16607023625932997) THEN 0 ELSE ST.VALUE END AS PRIMA_COMISIONABLE, 
                        ST.EVENTO,ST.PRODUCTO,ST.FEC_VTO_REC,
                        ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        --ALM 20220530: Los creditos de las Gestiones traen en el GN1 el objetivo por lo que ponemos este valor a 0.
                        --C.GENERICNUMBER1 AS ASEGURADOS
                        (CASE WHEN C.NAME = 'DC-O-COM-GestionExplotacion' THEN 0 ELSE C.GENERICNUMBER1 END) AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        ST.GENERICATTRIBUTE7 AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN :TBL_CREDITOS_MES C ON PAD_INS.PARTICIPANTSEQ = C.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = C.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = C.POSITIONSEQ
                        --ALM 20161222: Modificamos el filtro de los creditos para que muestre aquellos que tengan valor o n� de polizas corregidas distinto de 0 
                        AND (C.VALUE <> 0 OR C.GENERICNUMBER4 <> 0)
                        --ALM 20230316: Los nuevos creditos de asistencia llevan el numerico correspondiente al final, pero sigue existiendo el generico y no haya que cogerlo.
                        --AND C.NAME <> 'DC-O-COM-ServiciosAsistencia-Importe'
                        AND C.NAME NOT LIKE 'DC-O-COM-ServiciosAsistencia-Importe%'
                        AND C.NAME NOT LIKE 'DC-O-COM-NuevaProduccion%'
                    INNER JOIN :TBL_TXN_MES ST ON ST.SALESTRANSACTIONSEQ = C.SALESTRANSACTIONSEQ 
                    --INNER JOIN TCMP.CS_TRANSACTIONASSIGNMENT TA ON ST.SALESTRANSACTIONSEQ = TA.SALESTRANSACTIONSEQ
                    --    AND TA.TENANTID = :v_idtenant
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON C.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                        --ALM 20160907: No podemos filtrar la compania por el producto de la TXN, debemos utilizar el PLAN como hace Callidus
                        --              Separamos la carga en dos partes. Sin Asistencia y Solo Asistencias
                        --AND ST.PRODUCTID like '01%' --Para las asistencias que utilizan el mismo CREDITO en OCASO y ETERNA      
                    ;              
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_BAL_S4_POLIZAS_REP. Creditos (Resto Creditos). Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                
                
                --DTB 20250526: Insert tabla TEST_OUT_BAL_S4_POLIZAS_REP Pagos Comerciales 1** y 2**
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_BAL_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**.', i_log_count, i_id_proceso, 'debug');
                INSERT INTO EXT.TEST_OUT_BAL_S4_POLIZAS_REP               
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        --PAD_OF.POSITIONNAME AS COD_OFICINA,PAD_OF.LASTNAME AS OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                        --ALM 20160907: Como este campo no usa para Pagos Comerciales devolvemos el concepto de pago para utilizarlo en el informe
                        SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                        '999999900000000' AS POLIZA,
                        CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
                        D.DEPOSITDATE AS FEC_CARGO,
                        0 AS PRIMA_COMISIONABLE,
                        --ALM 20160914: Segun el correo de Alfonso del 06/09/2016 17:30 el tipo de recibo (EVENTO) de los pagos comerciales
                        --              depende del concepto de pago.
                        --(SELECT ET.DESCRIPTION FROM TCMP.CS_EVENTTYPE ET WHERE ET.EVENTTYPEID = 'Pago Comercial' AND ET.REMOVEDATE = :v_eot)
                        CASE WHEN SUBSTR(D.EARNINGCODEID,1,3) = '101' THEN 'Comision Produccion' 
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '102' THEN 'Comision Cartera'
                            --ALM 20180420: Anadimos los pagos comerciales de concepto 107 a las recuperaciones por peticion de Miguel Angel Arrabe
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('107') THEN 'Recuperacion'
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '109' THEN 'Domiciliacion'
                            --ALM 20170330: Anadimos los pagos comerciales de concepto 150 a las tramitaciones por peticion de Javier
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) in ('150','153') THEN 'Tramitacion'
                            WHEN SUBSTR(D.EARNINGCODEID,1,3) = '201' THEN 'Regularizacion'
                            ELSE 'Division Comercial'
                        END AS EVENTO,
                        PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                        '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        --ALM 20180119: Anadimos campos a incluir para el PAC 2018
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        '' AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                        AND D.TENANTID = :v_idtenant
                        --ALM 20160704: Solo nos quedamos con los Pagos Comerciales que tengan EarningGroup %S4% (ej: 04-S4-03)
                        AND D.EARNINGGROUPID LIKE '%S4%'
                        --ALM 20160907: Solo nos quedamos con los conceptos de pago 100 y 200, el resto no deben aparecer en el detalle del S4
                        --              Correo de Afonso el 06/09/2016
                        AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                    --ALM 20191008: Anadimos condicion para no coger posibles resultados de los MODELS
                    INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                    --ALM 20180822: Nos quedamos con las 15 primeras letras del nombre del deposito para tener en cuenta los depositos antiguos de Abril y Mayo
                    --              de 2016 que pueden venir con diferentes nombre (D-O-Pagos-Fijos-x)    
                    --INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME, = REG.REGLA
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON SUBSTR(D.NAME,1,15) = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    --ALM 20160701: Utilizamos un INNER porque si el Pago Comercial viene sin producto no queremos que aparezca en el detalle (correo Javier 21/06)
                    --              Unimos por el Producto que vendra en el EARNINGCODEID (ej: 101-0121000)
                    --INNER JOIN TCMP.CS_CLASSIFIER CL ON SUBSTR(D.EARNINGCODEID,5,7) = CL.CLASSIFIERID
                    --ALM 20160822: Como existen pagos comerciales antiguos en los que el producto venia informado en el GA1 del deposito cambiamos la join
                    --              Necesario para Pagos Comerciales de Abril y Mayo 2016
                    INNER JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
                        AND CL.REMOVEDATE = :v_eot  
                        AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND CL.TENANTID = :v_idtenant
                    LEFT OUTER JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                        AND PROD.REMOVEDATE = :v_eot  
                        AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND PROD.TENANTID = :v_idtenant
                    --ALM 20170331: Anadimos la estructura jerarquica de oficinas para poder realizar filtros en el informe
                    --LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_INS.PERIODSEQ = PAD_OF.PERIODSEQ
                    --    AND PAD_OF.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --WHERE PAD_INS.PERIODSEQ = v_periodRow.PERIODSEQ;
                        --ALM 20160617: Pueden llegar Pagos Comerciales sin Producto
                        --No es necesario filtrar por la compania porque el Deposito ya lo distingue (D-O-Pagos-Fijos o D-E-Pagos-Fijos)
                        --AND SUBSTR(D.GENERICATTRIBUTE1,1,2) = '01';    
                    ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_BAL_S4_POLIZAS_REP. Pagos Comerciales 1** y 2**. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                           
                    
        
                --LLS 20220124: Caso espec�fico del dep�sito D-O-GestionExplotacion-PagoInicial (regla D-O-COM-GestionExplotacion-PagoInicial) de Enero 2022
                --DTB 20250526: Insert tabla TEST_OUT_BAL_S4_POLIZAS_REP Pagos Comerciales 1** y 2**
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_BAL_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion.', i_log_count, i_id_proceso, 'debug');                        
                INSERT INTO EXT.TEST_OUT_BAL_S4_POLIZAS_REP               
                    SELECT 
                        PAD_INS.PARTICIPANTSEQ,PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,PAD_INS.POSITIONNAME,PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR(D.EARNINGGROUPID,7,2) AS COMPANIA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME  
                            ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME  
                            ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        D.NAME,D.VALUE,0 AS POLIZ_CORR,0 AS POLIZ_NP,
                        SUBSTR(D.EARNINGCODEID,1,3) AS SALESTRANSACTIONSEQ,
                        '999999900000000' AS POLIZA,
                        CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END AS PRODUCTID,
                        D.DEPOSITDATE AS FEC_CARGO,
                        0 AS PRIMA_COMISIONABLE,
                        'Gestiones referencias explotacion' AS EVENTO,
                        PROD.GENERICATTRIBUTE5 AS PRODUCTO,
                        '' AS FEC_VTO_REC,0 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,PAD_INS.TIPO_AGENTE
                        ,CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS,
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        '' AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN TCMP.CS_DEPOSIT D ON PAD_INS.PARTICIPANTSEQ = D.PAYEESEQ 
                        AND PAD_INS.PERIODSEQ = D.PERIODSEQ
                        AND PAD_INS.POSITIONSEQ = D.POSITIONSEQ
                        AND D.TENANTID = :v_idtenant
                        AND D.EARNINGGROUPID LIKE '%S4%'
                        AND SUBSTR(D.EARNINGCODEID,1,1) in ('1','2')
                        AND D.NAME = 'D-O-GestionExplotacion-PagoInicial'
                    INNER JOIN TCMP.CS_PLRUN PL ON D.PIPELINERUNSEQ = PL.PIPELINERUNSEQ AND PL.MODELSEQ = 0
                    INNER JOIN EXT.CONF_REGLAS_REP REG ON D.NAME = REG.REGLA
                        AND REG.F_INICIO <= PAD_INS.STARTDATE AND  REG.F_FIN > PAD_INS.STARTDATE
                        AND REG.COD_INFORME = 100.2 
                    LEFT JOIN TCMP.CS_CLASSIFIER CL ON CL.CLASSIFIERID = CASE WHEN SUBSTR(D.EARNINGCODEID,5,7) IS NOT NULL 
                            THEN SUBSTR(D.EARNINGCODEID,5,7) ELSE D.GENERICATTRIBUTE1 END
                        AND CL.REMOVEDATE = :v_eot  
                        AND CL.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND CL.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND CL.TENANTID = :v_idtenant
                    LEFT OUTER JOIN TCMP.CS_PRODUCT PROD ON CL.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ 
                        AND PROD.REMOVEDATE = :v_eot  
                        AND PROD.EFFECTIVESTARTDATE <= PAD_INS.STARTDATE AND PROD.EFFECTIVEENDDATE > PAD_INS.STARTDATE
                        AND PROD.TENANTID = :v_idtenant
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ    
                    ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_BAL_S4_POLIZAS_REP. Pago Inicial Gestion Explotacion. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                           
                    
                --DTB 20250526: Insert tabla TEST_OUT_BAL_S4_POLIZAS_REP Agentes Derechos Economicos
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Inicio Carga TEST_OUT_BAL_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS.', i_log_count, i_id_proceso, 'debug');                        
                INSERT INTO EXT.TEST_OUT_BAL_S4_POLIZAS_REP        
                     SELECT 
                        PAD_INS.PARTICIPANTSEQ, 
                        PAD_INS.POSITIONSEQ_PRIN,
                        PAD_INS.PERIODSEQ,
                        PAD_INS.PERIODO,
                        PAD_INS.BOUSERID,
                        PAD_INS.POSITIONNAME,
                        PAD_INS.NIF,
                        RTRIM(PAD_INS.FIRSTNAME) || ' ' || RTRIM(PAD_INS.LASTNAME) || ' ' || RTRIM(PAD_INS.SUFFIX) AS NOMBRE,
                        PAD_INS.POS_PRIN,
                        PAD_INS.CUADRO_RRGG_OCASO,
                        PAD_INS.CUADRO_RRTT_OCASO,
                        SUBSTR (CAR_LP.ORDERID,1,2) AS COMPANIA, /*order id 2 primeros digitos*/
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME ELSE PAD_PTO_VENTA.POSITIONNAME END AS COD_OFICINA,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.LASTNAME ELSE PAD_PTO_VENTA.LASTNAME END AS OFICINA,
                        'CARTERA_LP' AS NAME, --C.NAME,
                        CAR_LP.IMPORTE AS VALUE, --C.VALUE,
                        0 AS POLIZ_CORR,
                        0 AS POLIZ_NP,
                        CAR_LP.ORDERID ||CAST(CAR_LP.SUBLINENUMBER AS VARCHAR2(127)) AS SALESTRANSACTIONSEQ,
                        CAR_LP.POLIZA, --ST.GENERICATTRIBUTE1 AS POLIZA,
                        CAR_LP.PRODUCTID,
                        CAR_LP.ACCOUNTINGDATE AS FEC_CARGO,
                        CAR_LP.VALUE AS PRIMA_COMISIONABLE,
                        CAR_LP.EVENTO,--ST.EVENTO,
                        CAR_LP.PRODUCTO,--ST.PRODUCTO,
                        CAR_LP.FEC_VTO_REC,--ST.FEC_VTO_REC,
                        CAR_LP.PRIMA_NETA,--ST.GENERICNUMBER1 AS PRIMA_NETA,
                        PAD_INS.ID_TIPO_AGENTE,
                        PAD_INS.TIPO_AGENTE,
                        CASE WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            WHEN PAD_PTO_VENTA.POSITIONNAME = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                                                ELSE PAD_PTO_VENTA.POSITIONNAME END) THEN 3
                            ELSE 4
                        END AS NIVEL_PTO_VENTA,
                        PAD_PTO_VENTA.POSITIONNAME AS COD_PTO_VENTA,
                        PAD_PTO_VENTA.LASTNAME AS PTO_VENTA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                                                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                                                            ELSE PAD_PTO_VENTA.POSITIONNAME END END) THEN 2
                            ELSE 3
                        END AS NIVEL_OFICINA,
                        CASE WHEN (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME 
                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME 
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END END) = (CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                                                                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                                                                    ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                                                                        ELSE PAD_PTO_VENTA.POSITIONNAME END END END) THEN 1
                            ELSE 2
                        END AS NIVEL_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.POSITIONNAME
                                ELSE PAD_PTO_VENTA.POSITIONNAME END 
                        END AS COD_SUCURSAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_SUC.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_OF.LASTNAME
                                ELSE PAD_PTO_VENTA.LASTNAME END 
                        END AS SUCURSAL,
                        1 AS NIVEL_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.POSITIONNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.POSITIONNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.POSITIONNAME
                                    ELSE PAD_PTO_VENTA.POSITIONNAME END
                        END END AS COD_REGIONAL,
                        CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (5) THEN PAD_REG.LASTNAME
                            ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (4,7) THEN PAD_SUC.LASTNAME
                                ELSE CASE WHEN PAD_PTO_VENTA.POSITIONGENERICNUMBER3 IN (3,6,8,10) THEN PAD_OF.LASTNAME
                                    ELSE PAD_PTO_VENTA.LASTNAME END
                        END END AS REGIONAL,
                        PAD_INS.SUPERRAPEL,
                        0 AS ASEGURADOS, 
                        --ATV 20221124: Anyadimos campo a incluir para el informe s4 Corredores
                        '' AS COD_RECIBO
                    FROM :TBL_AGENTES_PRIN_MES PAD_INS
                    INNER JOIN EXT.CARTERA_DDEE CAR_LP ON PAD_INS.POS_CALLIDUS = CAR_LP.POSITIONNAME AND PAD_INS.STARTDATE = CAR_LP.COMPENSATIONDATE 
                        --LLS 20220125: Filtro para tener solo Ocaso
                        AND SUBSTR(CAR_LP.EARNINGGROUPID,7,2) = '01'
                        --ALM 20220221: Segun el nuevo parametro v_FV_EstadoTrx filtramos transacciones cobradas o no. Para Balances y LC siempre estado Cobrado.
                        --ATV 20250205 Anyadimos el estado N
                        --AND CAR_LP.ESTADO = 'C'
                        AND CAR_LP.ESTADO IN ('C', 'N')
                        --ALM 20220603: No incluimos registros sin importe de comision.
                        AND CAR_LP.IMPORTE <> 0
                    --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                    LEFT JOIN :TBL_PAGOS_MES Y ON PAD_INS.POSITIONSEQ_PRIN = Y.POSITIONSEQ
                        AND PAD_INS.PARTICIPANTSEQ = Y.PAYEESEQ
                        AND PAD_INS.PERIODSEQ = Y.PERIODSEQ
                        AND Y.TENANTID = :v_idtenant
                        AND SUBSTR(Y.EARNINGGROUPID,7,2) = '01'
                        AND SUBSTR(Y.EARNINGGROUPID,4,2) = 'S4'
                    /** dejamos estos left join para tener los datos de las oficinas **/
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_PTO_VENTA ON PAD_INS.PERIODSEQ = PAD_PTO_VENTA.PERIODSEQ
                        AND PAD_PTO_VENTA.POSITIONNAME = SUBSTR(PAD_INS.POS_PRIN,1,4)
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_OF ON PAD_PTO_VENTA.PERIODSEQ = PAD_OF.PERIODSEQ
                        AND PAD_OF.POSITIONSEQ = PAD_PTO_VENTA.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_SUC ON PAD_OF.PERIODSEQ = PAD_SUC.PERIODSEQ
                        AND PAD_SUC.POSITIONSEQ = PAD_OF.MANAGERSEQ
                    LEFT OUTER JOIN :TBL_OFICINAS_MES PAD_REG ON PAD_SUC.PERIODSEQ = PAD_REG.PERIODSEQ
                        AND PAD_REG.POSITIONSEQ = PAD_SUC.MANAGERSEQ
                    --LLS 20220127: Cruce para que no salgan los agentes calculados en LP si se han calculado en comisions
                    WHERE Y.POSITIONSEQ IS NULL
                     ;
                v_num_rows := ::ROWCOUNT;
                CALL LIB_GLOBAL:WRITE_LOG(v_permisos_log, proc_name, 'Fin Carga TEST_OUT_BAL_S4_POLIZAS_REP. AGENTES DERECHOS ECONOMICOS. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');     
                
                    
                
                --ALM 20220221: Quitamos el uso del parametro v_licencias para reducir codigo.
                --END IF;
                
                
                --DTB 20250526: --Actualización fechas_webi tabla TEST_OUT_BAL_S4_POLIZAS_REP
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio actualización de fecha en TEST_OUT_BAL_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
                CALL EXT.LIB_CREAR_TABLAS:UPDATE_FECHAS_WEBI(i_PeriodSeq, 'TEST_OUT_BAL_S4_POLIZAS_REP');
                CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin actualización de fecha en TEST_OUT_BAL_S4_POLIZAS_REP', i_log_count, i_id_proceso, 'debug');
        
            END IF;
            
        END IF;        
        
        -- Revisamos si se debe detener el proceso
		CALL EXT.LIB_CREAR_TABLAS:w_stop(v_stop);
		IF v_stop = 0 THEN
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'CONTROL PARA NO EJECUTAR EL PROCESO. REVISAR CLASIFICACION!!!!!!!' , i_log_count, i_id_proceso, 'warning');    	
			RETURN;
		END IF;

    END IF;