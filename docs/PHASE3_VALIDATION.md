# Validación de Etapa 3 — 0.4.0+4

Fecha 2026-11-04. Flutter 3.47.9 / Dart 3.13.7. Contrato fijado a backend 7a8380f999850900e4ed8cb5802cf92964bf16dd. Debts.jsx, Loans.jsx y finance.js releídos con conector GitHub en modo lectura.

## Entregado

- Deudas: cuota fija, cuota/plazo conocidos con interés implícito, división en meses, menor tiempo por presupuesto y cuotas abiertas sin saldo conocido.
- Creación y edición con recalculo de pendientes, conservación de pagados, conversión de cuotas existentes sin regenerar los valores históricos, abonos, pago/deshacer y eliminación conservando gastos pagados.
- Aplazamiento de deuda hacia adelante: interés sigue corriendo; abierta conserva montos. Extensión de 12 meses solo como operación explícita y confirmada, nunca al cargar.
- Consulta de cuotas, plazo y proyección de saldo a 12 meses suponiendo pagos previstos; la deuda abierta no se presenta como saldo conocido.
- Préstamos: registro, vencimiento, cobro parcial, deshacer cobro, cambio de fecha y eliminación con reversión de movimientos.
- Toda mutación atraviesa el mismo borrador/preview/confirmación/versión de etapa 2.

## Equivalencia y resultados

Se ejecutó el finance.js auditado como módulo puro con Node fuera del repositorio móvil; no se ejecutó servidor, SQL ni endpoints. Generó 8 cronogramas y 5 casos de cuota/tasa implícita. test/fixtures/debt_reference.json contiene exclusivamente datos sintéticos, salida y referencia de fuente. El generador reproducible está en tool/generate_debt_reference.mjs y recibe como argumento un archivo local del snapshot auditado (no usa API ni descarga datos).

Pruebas finales locales: 105 aprobadas; formato sin cambios; analyze sin observaciones. Comparación de cuotas y meses exacta; interés acumulado tolerancia 1e-7 e interés implícito 1e-8 por aritmética double. También cubre abonos/cobros/reversión, fechas civiles, aplazamiento con interés, conversión abierta, persistencia de montos, pantallas 320/768dp a texto 200% y regresión de etapas anteriores. CI nativa se registra en checks del PR.

## Exploración estructural

Se usó el skill codebase-memory: proyecto D-Claude-Monify-finanzas-movil, índice fast generado 2026-11-04T05:37:20Z, modo Verify limitado al camino de planes/guardado. search_graph, trace_path en ambos sentidos y check_index_coverage no reportaron incidencias en los cuatro archivos consultados. El snippet Dart de applyDebt solo incluyó su firma, por lo que el cuerpo se verificó leyendo el archivo. No se presenta ese índice como cobertura exhaustiva; este proyecto requiere reindexar porque no es el proyecto activo del MCP.

## Límites

No hubo escrituras de prueba en producción ni modificación del backend. No se modificaron deudas reales del usuario. Las cuotas negativas nuevas se rechazan; la sustitución explícita de gastos excluye filas vinculadas a inversiones para no romper otro plan. Los cálculos respetan pago anticipado, límite 600 y promedio histórico de la web. No se promete recomendación financiera óptima ni rentabilidad garantizada.

Faltan ahorros/inversiones, anual/ajustes/usuarios y auditoría física en sus etapas. La baja de cuentas continúa pendiente de definir referencias; no se implementa un borrado incompleto.
