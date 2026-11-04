# Plan de implementación y aceptación

Referencia funcional: commit web/backend 7a8380f999850900e4ed8cb5802cf92964bf16dd. Fase 0 es el trabajo autorizado ahora; no se inicia la siguiente fase que afecte finanzas sin revisión. Ninguna fase se concentra en un PR único con todos los módulos.

## Fase 0 — auditoría y base verificable (este PR)

- [x] Leer App, Debts, Annual, Savings, Investments, Loans, Users, Access, MovePanel, finance, charts, theme, styles, app/db y pruebas.
- [x] Inventariar campos, permisos, cálculos, vínculos, operaciones y dependencias con SHAs.
- [x] Corregir email+password y cookie multiusuario; validar perfil y aislamiento de cuenta.
- [x] Separar repositorio/provider/snapshot de la presentación existente.
- [x] Conservar snapshot completo e inmutable con versión, sin habilitar mutaciones.
- [x] Definir navegación, estrategia UX por módulo, tokens/componentes propuestos y gates de sincronización.
- [x] Crear instrucciones permanentes y documentos exigidos.
- [x] Registrar resultados locales de comandos/coverage y el procedimiento de checks nativos en PHASE0_VALIDATION.md; el PR muestra las ejecuciones por commit.
- [ ] Revisión humana del PR. No hacer merge automático.

No completado ni prometido aquí: motor financiero total, CRUD, sincronización mutable, diez pantallas o login Google nativo. La app de Fase 0 es funcional en acceso/perfil/consulta, no una versión completa maquillada.

## Fase 1 — diseño y Resumen (uno o dos PRs)

Implementar ThemeExtension y seis temas, preferencias locales separadas de sesión, MoneyText/AsyncContent/listas/selectores, NavigationBar/Rail y Resumen con datos reales. La navegación solo muestra módulos funcionales; la incorporación de destinos se hace conforme se entregan, sin pantallas decorativas.

Aceptar cuando: períodos/cifras reales y estimadas estén diferenciados, gráficos tengan alternativa de lectura, estados vacío/error/loading útiles; sin overflow en 320–1024dp con texto 200%; temas contrastados y reducción de movimiento. Pruebas de navegación/estado/contraste y evidencia visual con fixtures marcados como pruebas. No PUT financiero para guardar tema.

## Fase 2 — Cuentas, Categorías y Movimientos (PRs separados)

1. Portar calendario/COP, ingreso, cuentas/pagos/monthly y preservar fields/version en DTO de escritura.
2. Implementar el controlador draft→preview→confirmación→save/uncertain/conflict, primero con mocks.
3. Cuentas/categorías: altas/bajas/edición soportadas y depósito USD con preview. Gastos/pagos/ingreso y repetición con confirmaciones.
4. Mover pago suelto/serie con las reglas verificadas. Los planes vinculados se activan cuando sus módulos y pruebas existan.

**Gate obligatorio antes de habilitar guardar:** revisión del contrato de serialización completo; tests de campos desconocidos, versión vieja, doble toque, timeout después de commit, 401 a mitad de operación, cambio de cuenta con draft, rollback local y recarga. Aprobación humana del PR. Todas las escrituras de prueba con mocks o entorno aislado expresamente autorizado, nunca producción.

Aceptar cuando: ningún pago se duplica, una operación fallida no muestra éxito, un 409 no pisa datos, y cancelar una confirmación no altera cuentas. No crear transferencias/libro mayor inexistentes sin aprobación de negocio.

## Fase 3 — Deudas y Préstamos (dos PRs)

Deudas: cinco modos de entrada, interés implícito/anticipado, plazo/abonos/atrasos/cuotas abiertas y movimiento con preview. Préstamos: alta/fecha/recibir/deshacer/baja con efectos verificados.

Aceptar con equivalencia JS/Dart de tasa cero/no cero, última cuota, límite 600, fast sin libre, fechas locales, abonos y reanudación; préstamos en límites de vencimiento y cobros parciales. Ninguna prueba usa préstamos reales.

## Fase 4 — Ahorros e Inversiones (dos PRs)

Ahorros con propietario/miembros, cuenta separada/vinculada, aportes, reconciliación y metas; inversiones fijas/%/meta y trayectoria estimada/reprogramación. Mantener rentabilidad como estimación.

Aceptar con fixtures de permisos, mismo origen/destino, aportes ajenos, doble marca, valores históricos, borrado y conflictos de participante; porcentaje según ingreso, pagados inmutables y desplazamiento de inversión. Decidir explícitamente cualquier cambio de interés por huecos de calendario.

## Fase 5 — Anual, Ajustes y Usuarios (PR por módulo)

Anual con ventana de 12 meses, detalle y edición confirmada de ingreso. Ajustes financieros, perfil y contraseña usando cookie renovada; exportaciones explícitas. La restauración **real** sigue prohibida en esta misión; se puede probar con mocks y diseñar una vista previa para revisión, sin habilitarla en producción. Usuarios solo para admin con server-side authorization, enlaces sensibles y prevención de perder último admin.

Aceptar con roles reales, 403/401, renovación de sesión, export sin tokens en logs, permisos de shared funds conservados y datos históricos/proyectados diferenciados. Google nativo requiere contrato verificable que hoy no existe; proponer vía web segura o cambio de API por otro encargo, nunca improvisar intercambio de cookies.

## Fase 6 — calidad y distribución (PRs de pulido)

Auditoría TalkBack/VoiceOver, alto escalado, contraste, targets, orientación y hardware; rendimiento de listas/gráficos, estrés de red y regresiones; instalación Android/iOS, ciclo de vida de almacenamiento y firma privada fuera de Git. No distribuir como release con firma debug.

Aceptar con resultados medidos en dispositivos/entornos identificados, builds firmadas por su propietario y checklist cerrado de accesibilidad, integridad y errores. No presentar simulador o mock como validación de hardware real.

## Para cada PR

Objetivo y comportamiento observable; trazabilidad de regla al snapshot; decisión UX previa; pruebas ejecutadas con salida real; capturas/evidencia sin datos privados; pendientes y limitaciones. Evitar cambios de dependencias mayores mezclados con reglas financieras. Actualizar el inventario ante nuevas funciones web y revalidar contrato antes de consumirlas.

## Registro de decisiones pendientes

| Decisión | Motivo | Cuándo resolver |
| --- | --- | --- |
| Indicadores de Resumen frente a Anual | Totales/alcances diferentes en fuente | Antes de unificarlos en Fase 1/2 |
| Borrado de cuentas con referencias fuera de exp | Regla web incompleta | Antes de activar baja en Fase 2 |
| Transferencias/libro mayor | No existe endpoint ni historial completo | Propuesta separada, no requisito inventado |
| Rendimiento en meses diferidos | Fuente aplica rendimiento por fila | Antes de cambiar fórmula de inversiones |
| Google nativo | Callback termina en web sin intercambio seguro | Revisar con propietario de API; backend intacto aquí |
| Límite de interés implícito y precisión | Bisección 0..100% mensual/JS double | Portar equivalencia primero; cambio exige aprobación |
| Preferencias remotas | Tema vive en doc financiero versionado | Solo tras controlador de sincronización aprobado |
