# Validación de Etapa 4 — 0.5.0+5

Fecha 2026-11-04. Fuente: Savings.jsx, Investments.jsx, finance.js y reglas de fondos en server/db.js del commit 7a8380f999850900e4ed8cb5802cf92964bf16dd. Código leído mediante GitHub; ninguna conexión a PostgreSQL ni modificación del backend.

## Funciones entregadas

- Ahorros propios/compartidos, miembros, correo de participación, banco, cuenta vinculada o separada, saldo inicial, meta y aporte mensual.
- Edición y baja solo para propietario; cada integrante registrado cambia sus aportes, y el propietario puede gestionar miembros sin correo. Sin privilegio adicional por ser administrador.
- Aportes mensuales, extra/retiro, deshacer, cambio de monto pendiente y vinculación de cuentas. Mismo origen/destino no mueve saldo. Baja de ahorro no revierte cuentas, conforme a la web.
- Extensión y actualización de aportes ajenos son operaciones explícitas con preview/confirmación, nunca mutaciones automáticas al cargar.
- Inversiones fijas, porcentuales y meta con fecha; rendimiento anual estimado, cuotas, pagos/deshacer, edición, desplazamiento y baja conservando historia pagada.
- Proyecciones desplegables y detalles textuales; rendimiento por fila de cuota como en la web, sin cambiar silenciosamente a interés por huecos de calendario.

## Validación real

Flutter 3.47.9/Dart 3.13.7: pub get --enforce-lockfile correcto, analyze sin observaciones, 121 pruebas aprobadas con coverage. Incluye regresiones previas, 14 pruebas de dominio de capital y 2 de interfaz a 320/768dp con texto 200%.

Fixture capital_reference.json generado ejecutando finance.js puro con Node: cuatro planes de inversión con sus trayectorias, dos metas, dos aportes y actualización compartida. Generador reproducible en tool/generate_capital_reference.mjs. Solo entradas sintéticas. Las pruebas comparan montos/meses, idempotencia, reversión, permisos y cuotas pagadas inmutables. No se ejecutó la capa servidor/SQL.

Exploración: codebase-memory, índice fast 2026-11-04T05:48:14Z, búsqueda y traza en ambos sentidos de setContribution; coverage exacta de capital_commands, capital_engine, capital_screen y operation_screen sin incidencias registradas. Cuerpo crítico leído directamente porque el parser Dart anterior delimitaba solo firmas. No se afirma análisis exhaustivo del grafo.

## Límites

No se probaron aportes ni invitaciones reales; el servidor sigue siendo autoridad de permisos/mezcla y se recarga tras guardar. La marca de propiedad debe ser explícita para controles sensibles. La actualización compartida no garantiza sincronización en tiempo real: requiere recarga y confirmación del impacto. Las proyecciones no garantizan rendimiento. La versión privada del documento no es una versión global del fondo compartido.

CI nativa y APK: resultados del commit en el PR. Pendientes anual/ajustes/usuarios, auditoría física y firma de distribución. La baja de cuentas con referencias sigue sin habilitarse.
