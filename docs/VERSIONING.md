# Versiones por etapa

Cada etapa incrementa la versión minor y el número de compilación. Las correcciones de una entrega incrementan patch y build. El APK, pubspec, pantalla Apariencia y changelog identifican la entrega. Ninguna versión se fusiona automáticamente con master.

| Versión | Etapa | Estado |
| --- | --- | --- |
| 0.1.0+1 | Base, auditoría y sesión | PR #4 |
| 0.2.0+2 | Consulta útil y apariencia | PR #5, 57 tests; Android/iOS CI aprobados |
| 0.3.0+3 | Guardado seguro, cuentas/categorías/gastos y movimientos de pagos | Implementada, validación en PHASE2_VALIDATION.md; baja de cuentas pendiente |
| 0.4.0+4 | Deudas y préstamos | Implementada, PHASE3_VALIDATION.md |
| 0.5.0+5 | Ahorros e inversiones | Implementada, PHASE4_VALIDATION.md |
| 0.6.0+6 | Etapa 5a: resumen anual | Implementada, PHASE5A_VALIDATION.md |
| 0.6.1+7 | Etapa 5b: ajustes, perfil, usuarios y exportación | Pendiente |
| 0.7.0+8 | Accesibilidad y distribución de prueba | Pendiente |
| 1.0.0 | Distribución estable | Solo tras aceptación y firma del propietario |

El usuario autorizó continuar las etapas el 4 de noviembre de 2026. Sigue vigente la confirmación explícita dentro de la app antes de cada escritura financiera y la prohibición de probar escrituras contra producción. La revisión del PR no implica merge automático.
