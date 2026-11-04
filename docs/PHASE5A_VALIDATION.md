# Etapa 5a — resumen anual — 0.6.0+6

Acceso desde Resumen → Resumen anual. Ventana de doce meses (cinco anteriores, actual y seis siguientes), desplazamiento de seis meses y selección de mes para consultar pagos o editar el ingreso con vista previa y confirmación. Dejarlo vacío restablece salario por tasa; cero se conserva como ingreso explícito. Tabla horizontal con flujos, saldos al cierre y detalle de gastos por categoría/nombre. Los pendientes llevan texto explícito; no dependen de un color.

Se conservan las reglas verificadas en `src/Annual.jsx` y `src/finance.js` del backend/web en commit `7a8380f999850900e4ed8cb5802cf92964bf16dd`. No se modifica el backend. El resumen distingue aportes propios de saldo compartido; inversiones al cierre representan aportes y no incluyen rendimiento. Cobros previstos se proyectan en el vencimiento, no se presentan como garantizados. No hay escrituras ni generación automática de pagos al consultar.

`tool/generate_annual_reference.mjs` ejecuta el módulo puro de referencia y genera datos sintéticos en `test/fixtures/annual_reference.json`. Se comparan todos los campos calculados para seis meses, incluyendo historia, mes actual, ingreso cero, interés, cobro parcial y vencido, aportes compartidos y horizonte posterior a doce meses. El test verifica que el cálculo no mute su entrada.

Pruebas de interfaz: selección real de mes y tabla a 320 y 768 dp con texto al 200 %. No equivalen a prueba manual con lector de pantalla o dispositivo físico.

Validación local realizada: `flutter pub get --enforce-lockfile` correcto, `flutter analyze --no-pub` sin incidencias y `flutter test --no-pub --coverage` con 129 pruebas aprobadas. Compilaciones nativas verificadas por separado en el CI del PR; consultar su resultado antes de descargar el APK.

La etapa 5 continúa con ajustes completos, perfil, usuarios y exportación en 0.6.1. Esta entrega no los anuncia como implementados. No se agrega restauración real ni Google nativo sin contrato verificado.
