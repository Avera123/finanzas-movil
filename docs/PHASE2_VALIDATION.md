# Validación de Etapa 2 — 0.3.0+3

Fecha: 2026-11-04. Flutter 3.47.9 / Dart 3.13.7. Fuentes reconsultadas en lectura: App.jsx (cuentas, pagos, categorías, depósito), finance.js (incomeOf, movePayment, shiftSeries, syncPercentInvestments), server/app.js (PUT /api/state), commit 7a8380f999850900e4ed8cb5802cf92964bf16dd.

## Implementación

- Copia completa de documento, campos desconocidos conservados, versión base inalterable y payload congelado antes de confirmar.
- Un guardado simultáneo por cliente. Doble toque no duplica. Una operación confirmada, rechazada, cancelada o incierta no se reenvía.
- Confirmación explícita con filas afectadas, meses y saldos antes/después. Sin cuenta se informa que no cambia ningún saldo.
- PUT real con cookie de la misma generación de sesión; versión nueva válida y recarga obligatoria antes del mensaje de éxito.
- 409 exige recargar/revisar; 400/403 rechazo; timeout/500/respuesta inválida o fallo de recarga producen resultado incierto. No hay reintento automático. Cambio de sesión invalida el borrador.
- Gastos nuevos/repetidos, pago/deshacer, eliminar gasto con reversión, asignación de cuenta pendiente, movimiento individual o serie hacia adelante.
- Alta de cuenta, edición de saldo y depósito USD con tasa guardada; alta/baja de categorías y métodos sin eliminar opciones utilizadas.
- Ingreso por mes y vuelta al salario × tasa; cuotas porcentuales pendientes se sincronizan, pagadas se preservan.

## Límites de esta entrega

No se permite eliminar una cuota vinculada a un plan desde gastos. El desplazamiento de una deuda/inversión espera el módulo correspondiente. La baja de cuentas sigue pendiente de decidir el tratamiento de referencias a planes/ahorros: no se implementa la comprobación incompleta de la web. No hay renombrado en cascada ni transferencias inventadas. La proyección acumulada y módulos independientes pertenecen a próximas entregas.

El modo de resultado incierto exige verificación manual al recargar; no existe idempotency-key en la API. El borrador no persiste en disco. La revisión de permisos, mezclas de ahorro y versiones sigue siendo autoridad del servidor.

## Pruebas

Pruebas con adaptador HTTP falso, gateway controlable y fixtures sintéticos. Incluyen cancelación y confirmación desde widgets, payload íntegro, respuestas 400/401/403/409/500, timeout, doble toque/operaciones paralelas, sesión durante guardado, reversión débito/crédito, series entre años, inversión porcentual y versión manipulada. Resultado local final: pub get --enforce-lockfile correcto, analyze sin observaciones y 84 pruebas aprobadas con coverage. Builds nativos se registran en el PR.

No hubo PUT real ni acceso a PostgreSQL. El backend permaneció en modo lectura de código. No se afirma prueba manual con finanzas reales, iPhone físico, TalkBack ni firma de producción.

Exploración estructural: skill codebase-memory leído el 2026-11-04; sus herramientas MCP no están expuestas en esta sesión. Se usó lectura dirigida del código, sin afirmar cobertura ni análisis de impacto exhaustivo del grafo.
