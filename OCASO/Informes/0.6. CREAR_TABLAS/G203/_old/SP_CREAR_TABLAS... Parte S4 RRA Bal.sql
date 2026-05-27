------------------------Parte mensual
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_S4_RPA_RESUMEN_FINAL_REP (Mensual). Balances', i_log_count, i_id_proceso, 'debug'); --LLS 20251112: añadido texto mensual
			
			INSERT INTO EXT.OUT_S4_RPA_RESUMEN_FINAL_REP (COMPANYA,TIPO_PAGO,ORIGEN,PERIODSEQ,STARTDATE,PERIODO_ORIGINAL,PERIODO_CAMPO,PERIODO,QUARTER,POSITIONSEQ,N_MEDIDA,COMISION_RESUMEN,COMISION_OBJ,COMISION_PAGO,COMISION_REG,V_MEDIDA,CUMPLE_OBJ,POS_PRIN,NOMBRE,POS_CALLIDUS,AGENTE,POSITIONNAME,M_GN1,TIPO_AGENTE,ID_TIPO_AGENTE,NIF,NIF_NOMBRE,FEC_ACTUALIZACION,FEC_ACTUALIZACION_FORMATO)
				WITH CTE_DATOS_PER AS (
					SELECT DISTINCT MONTH(MAX(STARTDATE)) MES, YEAR(MAX(STARTDATE)) ANYO FROM CS_PERIOD
						WHERE 1=1
						AND PERIODSEQ = :i_PeriodSeq
						AND REMOVEDATE = :v_eot), 
				CTE_MESES_NUM AS (
					SELECT DISTINCT
						PERIODO,
						CASE
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%ENERO%' THEN 1
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%FEBRERO%' THEN 2
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%MARZO%' THEN 3
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%ABRIL%' THEN 4
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%MAYO%' THEN 5
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%JUNIO%' THEN 6
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%JULIO%' THEN 7
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%AGOSTO%' THEN 8
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%SEPTIEMBRE%' THEN 9
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%OCTUBRE%' THEN 10
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%NOVIEMBRE%' THEN 11
							WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%DICIEMBRE%' THEN 12
						END AS MES_NUM
					FROM EXT.OUT_RPA_RESUMEN_REP INYC_RPA_RESUMEN
				),
				RPA AS (
					SELECT DISTINCT  'BAL' TIPO_PAGO
							,  'BAL' ORIGEN
							, INYC_RPA_RESUMEN.PERIODSEQ
							, INYC_RPA_RESUMEN.STARTDATE 
							, INYC_RPA_RESUMEN.PERIODO PERIODO_ORIGINAL
							, CASE WHEN SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Enero' OR SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Febrero'
									THEN 'Marzo ' || SUBSTR_AFTER(INYC_RPA_RESUMEN.PERIODO, ' ')
								WHEN SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Abril' OR SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Mayo'
									THEN 'Junio ' || SUBSTR_AFTER(INYC_RPA_RESUMEN.PERIODO, ' ')
								WHEN SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Julio' OR SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Agosto'
									THEN 'Septiembre ' || SUBSTR_AFTER(INYC_RPA_RESUMEN.PERIODO, ' ')
								WHEN SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Octubre' OR SUBSTR_BEFORE(INYC_RPA_RESUMEN.PERIODO, ' ') = 'Noviembre'
									THEN 'Diciembre ' || SUBSTR_AFTER(INYC_RPA_RESUMEN.PERIODO, ' ')
								ELSE INYC_RPA_RESUMEN.PERIODO
								END PERIODO
							, INYC_RPA_RESUMEN.QUARTER
							, INYC_RPA_RESUMEN.POSITIONSEQ_PRIN POSITIONSEQ
							, INYC_RPA_RESUMEN.N_MEDIDA
							, INYC_RPA_RESUMEN.V_MEDIDA
							, INYC_RPA_RESUMEN.POS_PRIN
							, IFNULL(RTRIM(INYC_RPA_RESUMEN.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(INYC_RPA_RESUMEN.MIDDLENAME) || ' ', '') || IFNULL(RTRIM(INYC_RPA_RESUMEN.LASTNAME), '') NOMBRE
							, J.POS_CALLIDUS
							, INYC_RPA_RESUMEN.POSITIONNAME
							, INYC_RPA_RESUMEN.M_GN1
							, INYC_RPA_RESUMEN.ID_TIPO_AGENTE
							, INYC_RPA_RESUMEN.TIPO_AGENTE
							, INYC_RPA_RESUMEN.NIF
							, NULL FEC_ACTUALIZACION
						FROM EXT.OUT_BAL_RPA_RESUMEN_REP INYC_RPA_RESUMEN
						INNER JOIN (SELECT DISTINCT POSITIONSEQ_PRIN, PERIODSEQ, POS_CALLIDUS
									FROM EXT.OUT_JERARQUIA_REP) J
							ON INYC_RPA_RESUMEN.POSITIONSEQ_PRIN = J.POSITIONSEQ_PRIN
								AND INYC_RPA_RESUMEN.PERIODSEQ = J.PERIODSEQ
						INNER JOIN CTE_MESES_NUM ON CTE_MESES_NUM.PERIODO = INYC_RPA_RESUMEN.PERIODO
						WHERE 1 = 1
							AND RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) = (SELECT ANYO FROM CTE_DATOS_PER)
							AND CTE_MESES_NUM.MES_NUM <= (SELECT MES FROM CTE_DATOS_PER)
							AND
								(((RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) >= 2022 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE IN (28,32,37,38,39,40,42,43,44,45,49))
										OR (RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) = 2021 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE IN (32,39,40,42,44,45))
										OR (RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) < 2021 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE = 42))
								 AND (CTE_MESES_NUM.MES_NUM / 3 = (SELECT (MES-1) / 3 FROM CTE_DATOS_PER)) -- DTB 20251105 Agrupa datos trimestralmente)
								OR (((RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) < 2021 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE IN (32,39,40,44,45))
									AND (CTE_MESES_NUM.MES_NUM / 4 = (SELECT (MES-1) / 4 FROM CTE_DATOS_PER))) -- DTB 20251105 Agrupa datos cuatrimestral
								OR (INYC_RPA_RESUMEN.ID_TIPO_AGENTE NOT IN (28,32,37,38,39,40,42,43,44,45,49) AND INYC_RPA_RESUMEN.PERIODSEQ = :i_PeriodSeq))
								)
				)
				SELECT DISTINCT 'OCASO' COMPANYA
					, TIPO_PAGO
					, ORIGEN
					, RPA.PERIODSEQ
					, STARTDATE 
					, PERIODO_ORIGINAL
					, RPA.PERIODO PERIODO_CAMPO
					, SUBSTR_AFTER(RPA.PERIODO, ' ') ||
										CASE WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Enero' THEN ' 01 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Febrero' THEN ' 02 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Marzo' THEN ' 03 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Abril' THEN ' 04 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Mayo' THEN ' 05 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Junio' THEN ' 06 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Julio' THEN ' 07 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Agosto' THEN ' 08 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Septiembre' THEN ' 09 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Octubre' THEN ' 10 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Noviembre' THEN ' 11 '
											WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Diciembre' THEN ' 12 '
											END
										|| SUBSTR_BEFORE(RPA.PERIODO, ' ') PERIODO
					, QUARTER
					, POSITIONSEQ
					, N_MEDIDA
					, CASE	--tabla Tabla_Resumen_Total
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes' THEN 'Pólizas Corregidas'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-Prima-998-TotalMes' THEN 'Prima Rappel'
							--tabla Tabla_Resumen_Productos
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-01503-Recup-AgNO20-SinResto' THEN 'Periodo Actual'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-Campania-SinResto' THEN 'Periodo Actual'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Otros-Productos' THEN 'Periodo Actual'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Resto-01501-01503-AgNO20-Mes-Anterior' THEN 'Contabilizadas en el Periodo Anterior'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Resto-01501-Campania-Mes-Anterior' THEN 'Contabilizadas en el Periodo Anterior'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Resto-Mes-Anterior' THEN 'Contabilizadas en el Periodo Anterior'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-01503-Recup-AgNO20-Resto' THEN 'Contabilizadas para el Próximo Periodo'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-Campania-Resto' THEN 'Contabilizadas para el Próximo Periodo'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes-Resto' THEN 'Contabilizadas para el Próximo Periodo'
							ELSE NULL
						END COMISION_RESUMEN
					, CASE	--tabla Tabla_Objetivos
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumAsegurados-TotalMes' THEN 'Aseg. RRTT'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-001-TotalMes' AND M_GN1 = 1 THEN 'RRTT'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-002-TotalMes' AND M_GN1 = 1 THEN 'Hogar'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-003-TotalMes' AND M_GN1 = 1 THEN 'Vida Riesgo'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-004-TotalMes' AND M_GN1 = 1 THEN 'Vida Ahorro'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-005-SINCC-TotalMes' AND M_GN1 = 1 THEN 'Accidentes Sin CC'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-906-TotalMes' AND M_GN1 = 1 THEN 'RRPP'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-997-TotalMes' AND M_GN1 = 1 THEN 'Productos Prioritarios'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-Prima-998-TotalMes' AND M_GN1 = 1 THEN 'Prima Total Productos'
							ELSE NULL
						END COMISION_OBJ
					, CASE	--tabla Tabla_Pago_Mensual
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-Mensual' THEN 'Importe Rappel'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-Rappel-Pago-Mensual' THEN 'Importe Rappel'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-SuperRappel-Pago-Mensual' THEN 'Importe Superrappel'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-SuperRappel-Pago-Mensual' THEN 'Importe Superrappel'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXXL' THEN 'Importe Rappel XL/XXL'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXL' THEN 'Importe Rappel XL/XXL'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-Pago-Fijo-Mensual' AND V_MEDIDA <> 0 THEN 'Incentivo Especial'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-Pago-Fijo-Mensual' AND V_MEDIDA <> 0 THEN 'Incentivo Especial'
							ELSE NULL
						END COMISION_PAGO
					, CASE	--tabla Tabla_Trim_por_mes
						WHEN (RPA.PERIODO LIKE 'Mar%' OR RPA.PERIODO LIKE 'Jun%' OR RPA.PERIODO LIKE 'Sep%' OR RPA.PERIODO LIKE 'Dic%')
							AND ID_TIPO_AGENTE IN (28, 32, 37, 38, 39, 40, 43, 44, 45)
						THEN CASE
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumAsegurados-TotalMes' THEN 'Aseg. RRTT'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizasCorregidas-998-TotalMes' THEN 'Pólizas T.R.'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-001-TotalMes' THEN 'Pólizas RRTT'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-906-TotalMes' THEN 'Pólizas RRPP'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-002-TotalMes' THEN 'Pólizas Hogar'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-007-TotalMes' THEN 'Pólizas Ocaso Oro'
							WHEN N_MEDIDA = 'SM-O-GEN-Agente-Prima-998-TotalMes' THEN 'Primas T.R.'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-Rappel-Pago-Mensual' THEN 'Rappel Abonado Trimestre'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-SuperRappel-Pago-Mensual' THEN 'Rappel Abonado Trimestre'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXXL' THEN 'Rappel Abonado Trimestre'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXL' THEN 'Rappel Abonado Trimestre'
							--dato Cumple Objetivos Reg. Trim.
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-CumpleObjetivos-RegulTrimestral' THEN 'Cumple Objetivos Reg. Trim.'
							--tabla 
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-Importe-RegTrim' THEN 'Escalado Reg. Trim.'
							WHEN N_MEDIDA = 'SM-O-RPP-Agente-ImporteNeto-RegTrim' THEN 'Total Abono Reg. Trim.'

							ELSE NULL END
						ELSE NULL
						END COMISION_REG
					, V_MEDIDA
					, CASE WHEN N_MEDIDA = 'SM-O-RPP-Agente-CumpleObjetivos-RegulTrimestral' AND V_MEDIDA = 1 THEN 'SI' ELSE 'NO' END CUMPLE_OBJ
					, POS_PRIN
					, NOMBRE
					, POS_CALLIDUS
					, RIGHT(POS_PRIN,4) ||' - '|| POS_CALLIDUS ||' - ' || NOMBRE AGENTE
					, POSITIONNAME
					, M_GN1
					, TO_INTEGER(ID_TIPO_AGENTE) ||' - '|| TIPO_AGENTE AS TIPO_AGENTE
					, ID_TIPO_AGENTE
					, NIF
					, NIF || ' - ' || NOMBRE AS NIF_NOMBRE
					, FEC_ACTUALIZACION
					, TO_VARCHAR(FEC_ACTUALIZACION, 'DD/MM/YYYY') FEC_ACTUALIZACION_FORMATO

				FROM RPA;
			v_num_rows := ::ROWCOUNT;
			CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_S4_RPA_RESUMEN_FINAL_REP (Mensual). BALANCES. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug'); --LLS 20251112: añadido texto mensual
			
			
------------------------Parte trimestral

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Borrado OUT_S4_RPA_RESUMEN_FINAL_REP (Trimestre). Balances' || v_PeriodSeq_2, i_log_count, i_id_proceso, 'debug');--LLS 20251112: añadido texto Trimestre
				DELETE FROM EXT.OUT_S4_RPA_RESUMEN_FINAL_REP WHERE PERIODSEQ = :i_PeriodSeq AND TIPO_PAGO = 'BAL';
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Borrado OUT_S4_RPA_RESUMEN_FINAL_REP (Trimestre). Filas borradas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');--LLS 20251112: añadido texto Trimestre

				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Inicio Carga OUT_S4_RPA_RESUMEN_FINAL_REP (Trimestre). Balances', i_log_count, i_id_proceso, 'debug');--LLS 20251112: añadido texto Trimestre
				INSERT INTO EXT.OUT_S4_RPA_RESUMEN_FINAL_REP (COMPANYA,TIPO_PAGO,ORIGEN,PERIODSEQ,STARTDATE,PERIODO_ORIGINAL,PERIODO_CAMPO,PERIODO,QUARTER,POSITIONSEQ,N_MEDIDA,COMISION_RESUMEN,COMISION_OBJ,COMISION_PAGO,COMISION_REG,V_MEDIDA,CUMPLE_OBJ,POS_PRIN,NOMBRE,POS_CALLIDUS,AGENTE,POSITIONNAME,M_GN1,TIPO_AGENTE,ID_TIPO_AGENTE,NIF,NIF_NOMBRE,FEC_ACTUALIZACION,FEC_ACTUALIZACION_FORMATO)
					WITH CTE_DATOS_PER AS (
						SELECT DISTINCT MONTH(MAX(STARTDATE)) MES, YEAR(MAX(STARTDATE)) ANYO FROM CS_PERIOD
							WHERE 1=1
							AND PERIODSEQ = :i_PeriodSeq
							AND REMOVEDATE = :v_eot), 
					CTE_MESES_NUM AS (
						SELECT DISTINCT
							PERIODO,
							CASE
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%ENERO%' THEN 1
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%FEBRERO%' THEN 2
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%MARZO%' THEN 3
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%ABRIL%' THEN 4
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%MAYO%' THEN 5
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%JUNIO%' THEN 6
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%JULIO%' THEN 7
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%AGOSTO%' THEN 8
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%SEPTIEMBRE%' THEN 9
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%OCTUBRE%' THEN 10
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%NOVIEMBRE%' THEN 11
								WHEN UPPER(INYC_RPA_RESUMEN.PERIODO) LIKE '%DICIEMBRE%' THEN 12
							END AS MES_NUM
						FROM EXT.OUT_RPA_RESUMEN_REP INYC_RPA_RESUMEN
					),
					RPA AS (
						SELECT DISTINCT  'BAL' TIPO_PAGO
								,  'BAL' ORIGEN
								, INYC_RPA_RESUMEN.PERIODSEQ
								, INYC_RPA_RESUMEN.STARTDATE 
								, INYC_RPA_RESUMEN.PERIODO PERIODO_ORIGINAL
								, INYC_RPA_RESUMEN.PERIODO PERIODO
								, INYC_RPA_RESUMEN.QUARTER
								, INYC_RPA_RESUMEN.POSITIONSEQ_PRIN POSITIONSEQ
								, INYC_RPA_RESUMEN.N_MEDIDA
								, INYC_RPA_RESUMEN.V_MEDIDA
								, INYC_RPA_RESUMEN.POS_PRIN
								, IFNULL(RTRIM(INYC_RPA_RESUMEN.FIRSTNAME) || ' ', '') || IFNULL(RTRIM(INYC_RPA_RESUMEN.MIDDLENAME) || ' ', '') || IFNULL(RTRIM(INYC_RPA_RESUMEN.LASTNAME), '') NOMBRE
								, J.POS_CALLIDUS
								, INYC_RPA_RESUMEN.POSITIONNAME
								, INYC_RPA_RESUMEN.M_GN1
								, INYC_RPA_RESUMEN.ID_TIPO_AGENTE
								, INYC_RPA_RESUMEN.TIPO_AGENTE
								, INYC_RPA_RESUMEN.NIF
								, NULL FEC_ACTUALIZACION
							FROM EXT.OUT_BAL_RPA_RESUMEN_REP INYC_RPA_RESUMEN
							INNER JOIN (SELECT DISTINCT POSITIONSEQ_PRIN, PERIODSEQ, POS_CALLIDUS
										FROM EXT.OUT_JERARQUIA_REP) J
								ON INYC_RPA_RESUMEN.POSITIONSEQ_PRIN = J.POSITIONSEQ_PRIN
									AND INYC_RPA_RESUMEN.PERIODSEQ = J.PERIODSEQ
							INNER JOIN CTE_MESES_NUM ON CTE_MESES_NUM.PERIODO = INYC_RPA_RESUMEN.PERIODO
							WHERE 1 = 1
								AND RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) = (SELECT ANYO FROM CTE_DATOS_PER)
								AND CTE_MESES_NUM.MES_NUM <= (SELECT MES FROM CTE_DATOS_PER)
								AND
									(((RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) >= 2022 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE IN (28,32,37,38,39,40,42,43,44,45,49))
											OR (RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) = 2021 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE IN (32,39,40,42,44,45))
											OR (RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) < 2021 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE = 42))
									 AND (CTE_MESES_NUM.MES_NUM / 3 = (SELECT (MES-1) / 3 FROM CTE_DATOS_PER)) -- DTB 20251105 Agrupa datos trimestralmente)
									OR (((RIGHT(INYC_RPA_RESUMEN.PERIODO, 4) < 2021 AND INYC_RPA_RESUMEN.ID_TIPO_AGENTE IN (32,39,40,44,45))
										AND (CTE_MESES_NUM.MES_NUM / 4 = (SELECT (MES-1) / 4 FROM CTE_DATOS_PER))) -- DTB 20251105 Agrupa datos cuatrimestral
									OR (INYC_RPA_RESUMEN.ID_TIPO_AGENTE NOT IN (28,32,37,38,39,40,42,43,44,45,49) AND INYC_RPA_RESUMEN.PERIODSEQ = :i_PeriodSeq))
									)
					)
					SELECT DISTINCT 'OCASO' COMPANYA
						, TIPO_PAGO
						, ORIGEN
						, RPA.PERIODSEQ
						, STARTDATE 
						, PERIODO_ORIGINAL
						, RPA.PERIODO PERIODO_CAMPO
						, SUBSTR_AFTER(RPA.PERIODO, ' ') ||
											CASE WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Enero' THEN ' 01 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Febrero' THEN ' 02 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Marzo' THEN ' 03 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Abril' THEN ' 04 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Mayo' THEN ' 05 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Junio' THEN ' 06 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Julio' THEN ' 07 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Agosto' THEN ' 08 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Septiembre' THEN ' 09 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Octubre' THEN ' 10 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Noviembre' THEN ' 11 '
												WHEN SUBSTR_BEFORE(RPA.PERIODO, ' ') = 'Diciembre' THEN ' 12 '
												END
											|| SUBSTR_BEFORE(RPA.PERIODO, ' ') PERIODO
						, QUARTER
						, POSITIONSEQ
						, N_MEDIDA
						, CASE	--tabla Tabla_Resumen_Total
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes' THEN 'Pólizas Corregidas'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-Prima-998-TotalMes' THEN 'Prima Rappel'
								--tabla Tabla_Resumen_Productos
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-01503-Recup-AgNO20-SinResto' THEN 'Periodo Actual'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-Campania-SinResto' THEN 'Periodo Actual'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Otros-Productos' THEN 'Periodo Actual'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Resto-01501-01503-AgNO20-Mes-Anterior' THEN 'Contabilizadas en el Periodo Anterior'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Resto-01501-Campania-Mes-Anterior' THEN 'Contabilizadas en el Periodo Anterior'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Resto-Mes-Anterior' THEN 'Contabilizadas en el Periodo Anterior'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-01503-Recup-AgNO20-Resto' THEN 'Contabilizadas para el Próximo Periodo'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-01501-Campania-Resto' THEN 'Contabilizadas para el Próximo Periodo'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-NumeroPolizas-998-Total-Mes-Resto' THEN 'Contabilizadas para el Próximo Periodo'
								ELSE NULL
							END COMISION_RESUMEN
						, CASE	--tabla Tabla_Objetivos
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumAsegurados-TotalMes' THEN 'Aseg. RRTT'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-001-TotalMes' AND M_GN1 = 1 THEN 'RRTT'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-002-TotalMes' AND M_GN1 = 1 THEN 'Hogar'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-003-TotalMes' AND M_GN1 = 1 THEN 'Vida Riesgo'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-004-TotalMes' AND M_GN1 = 1 THEN 'Vida Ahorro'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-005-SINCC-TotalMes' AND M_GN1 = 1 THEN 'Accidentes Sin CC'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-906-TotalMes' AND M_GN1 = 1 THEN 'RRPP'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-997-TotalMes' AND M_GN1 = 1 THEN 'Productos Prioritarios'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-Prima-998-TotalMes' AND M_GN1 = 1 THEN 'Prima Total Productos'
								ELSE NULL
							END COMISION_OBJ
						, CASE	--tabla Tabla_Pago_Mensual
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-Mensual' THEN 'Importe Rappel'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-Rappel-Pago-Mensual' THEN 'Importe Rappel'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-SuperRappel-Pago-Mensual' THEN 'Importe Superrappel'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-SuperRappel-Pago-Mensual' THEN 'Importe Superrappel'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXXL' THEN 'Importe Rappel XL/XXL'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXL' THEN 'Importe Rappel XL/XXL'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-Pago-Fijo-Mensual' AND V_MEDIDA <> 0 THEN 'Incentivo Especial'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-Pago-Fijo-Mensual' AND V_MEDIDA <> 0 THEN 'Incentivo Especial'
								ELSE NULL
							END COMISION_PAGO
						, CASE	--tabla Tabla_Trim_por_mes
							WHEN (RPA.PERIODO LIKE 'Mar%' OR RPA.PERIODO LIKE 'Jun%' OR RPA.PERIODO LIKE 'Sep%' OR RPA.PERIODO LIKE 'Dic%')
								AND ID_TIPO_AGENTE IN (28, 32, 37, 38, 39, 40, 43, 44, 45)
							THEN CASE
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumAsegurados-TotalMes' THEN 'Aseg. RRTT'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizasCorregidas-998-TotalMes' THEN 'Pólizas T.R.'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-001-TotalMes' THEN 'Pólizas RRTT'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-906-TotalMes' THEN 'Pólizas RRPP'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-002-TotalMes' THEN 'Pólizas Hogar'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-NumeroPolizas-007-TotalMes' THEN 'Pólizas Ocaso Oro'
								WHEN N_MEDIDA = 'SM-O-GEN-Agente-Prima-998-TotalMes' THEN 'Primas T.R.'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-Rappel-Pago-Mensual' THEN 'Rappel Abonado Trimestre'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-N2N3-SuperRappel-Pago-Mensual' THEN 'Rappel Abonado Trimestre'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXXL' THEN 'Rappel Abonado Trimestre'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-Rappel-Pago-MensualXL' THEN 'Rappel Abonado Trimestre'
								--dato Cumple Objetivos Reg. Trim.
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-CumpleObjetivos-RegulTrimestral' THEN 'Cumple Objetivos Reg. Trim.'
								--tabla 
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-Importe-RegTrim' THEN 'Escalado Reg. Trim.'
								WHEN N_MEDIDA = 'SM-O-RPP-Agente-ImporteNeto-RegTrim' THEN 'Total Abono Reg. Trim.'

								ELSE NULL END
							ELSE NULL
							END COMISION_REG
						, V_MEDIDA
						, CASE WHEN N_MEDIDA = 'SM-O-RPP-Agente-CumpleObjetivos-RegulTrimestral' AND V_MEDIDA = 1 THEN 'SI' ELSE 'NO' END CUMPLE_OBJ
						, POS_PRIN
						, NOMBRE
						, POS_CALLIDUS
						, RIGHT(POS_PRIN,4) ||' - '|| POS_CALLIDUS ||' - ' || NOMBRE AGENTE
						, POSITIONNAME
						, M_GN1
						, TO_INTEGER(ID_TIPO_AGENTE) ||' - '|| TIPO_AGENTE AS TIPO_AGENTE
						, ID_TIPO_AGENTE
						, NIF
						, NIF || ' - ' || NOMBRE AS NIF_NOMBRE
						, FEC_ACTUALIZACION
						, TO_VARCHAR(FEC_ACTUALIZACION, 'DD/MM/YYYY') FEC_ACTUALIZACION_FORMATO

					FROM RPA;
				v_num_rows := ::ROWCOUNT;
				CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin Carga OUT_S4_RPA_RESUMEN_FINAL_REP (Trimestre). BALANCES. Filas: ' || v_num_rows, i_log_count, i_id_proceso, 'debug');--LLS 20251112: añadido texto Trimestre