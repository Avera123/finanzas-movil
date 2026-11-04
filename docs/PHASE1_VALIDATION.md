# Validación de Etapa 1 — 0.2.0+2

Fecha: 2026-11-04. Flutter 3.47.9 / Dart 3.13.7, Windows. Fuente de reglas: App.jsx (tot, incomeOf y categorías) y finance.js del commit backend 7a8380f999850900e4ed8cb5802cf92964bf16dd, reconsultados en GitHub en modo lectura.

## Comportamiento entregado

Resumen, movimientos por mes/categoría, cuentas y apariencia son destinos funcionales de consulta. No hay botones de módulos futuros. El saldo actual no cambia al elegir un mes. Ingreso ausente muestra configuración pendiente; override cero es válido. Ingreso menos gastos se etiqueta con su alcance limitado, sin confundirlo con monthly.left ni patrimonio. No se calcula aún el cierre acumulado de Anual.

Preferencia de apariencia local en clave appearance_v1, separada de sesión. Tema automático sigue el sistema. Acento claro ajustado para texto legible. El catálogo ThemeExtension conserva el acento de marca. UI sin animaciones financieras personalizadas.

## Verificación

- pub get --enforce-lockfile: correcto; ninguna dependencia nueva.
- analyze --no-pub: sin observaciones, incluido el ajuste final de contraste.
- 57 pruebas aprobadas en la ejecución final; suite incluye contraste, reglas mensuales, aislamiento, sesión y navegación a 320/390/600/768/1024dp con texto 200%.
- CI: Android debug con URL reservada, APK conectado a la URL pública e iOS simulador; consultar checks del PR para resultado del commit final.

No se hizo login con credenciales reales ni prueba de pago. No se consultaron datos financieros de producción. La revisión visual en emulador, TalkBack/VoiceOver físico y firma de distribución quedan pendientes. Los tests de contraste cubren pares superficie/texto, botón/texto y enlaces; no equivalen a auditoría completa de toda combinación de estados Material.

## Continuidad

Ver VERSIONING.md. Etapa 2 incorpora un controlador draft/preview/confirm/save y pruebas de 409, sesión y resultado incierto antes de habilitar mutaciones. Deudas, ahorros, inversiones y anual se entregan en sus versiones posteriores, no se anuncian como implementados en este APK.
