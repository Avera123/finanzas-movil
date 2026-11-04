# Evidencia de Fase 0

Fecha: 3 de noviembre de 2026 (America/Bogota). Referencia auditada: web/backend `7a8380f999850900e4ed8cb5802cf92964bf16dd`. Código móvil en el PR de Fase 0, con los resultados nativos asociados a su commit en GitHub Actions.

## Resultados locales ejecutados

Windows; Flutter 3.47.9 stable, Dart 3.13.7. Se usó el SDK oficial local; sin modificar las dependencias resueltas.

| Comando | Resultado real |
| --- | --- |
| flutter pub get --enforce-lockfile | Correcto |
| dart format --output=none --set-exit-if-changed lib test | 18 archivos, 0 cambios; correcto |
| flutter analyze --no-pub | No issues found! |
| flutter test --no-pub --coverage --reporter expanded | **47 pruebas aprobadas** |
| Lectura de coverage/lcov.info | **275/290 líneas instrumentadas, 94,83 %** |
| git diff --check | Sin errores de whitespace |

El porcentaje describe los diez archivos instrumentados que constan en LCOV; no incluye bootstrap main.dart, código nativo, módulos futuros ni todas las ramas posibles. No es una certificación de cobertura de la aplicación completa.

## Qué se probó

- Autenticación por correo/contraseña, normalización solo de correo, 401/403/429/500, timeouts, formato y redirecciones.
- Cookie vigente/vencida/antigua/malformada, almacenamiento por origen, limpieza y logout sin red.
- Perfil válido/inactivo/rol no reconocido y capacidad admin.
- Versión positiva del documento; conservación de campos no modelados, inversiones/resumeM y extensiones desconocidas; copia profunda e inmutabilidad.
- Carga perfil→documento; cambio de sesión en mitad de una petición descarta el contexto anterior; un 401 tardío no borra la nueva sesión.
- Pantallas reales: login, validación, restauración, logout, reintento y cambio de usuario sin saldos ajenos; teclado en 320×480.
- Neto de cuentas con crédito, fracciones, negativos, vacíos y respuesta inválida.
- Lista exacta de operaciones del cliente: login, GET perfil, GET documento y logout. Ninguna escritura financiera.

Mocks de HTTP y almacenamiento; datos sintéticos en test/. No se usó ninguna base de datos ni credencial real para ejecutar estas pruebas.

## Validación nativa reproducible del PR

El workflow .github/workflows/flutter.yml ejecuta en Linux:

```sh
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=https://api.example.invalid
```

Y en macOS:

```sh
flutter build ios --simulator --debug --no-codesign --no-pub --dart-define=API_BASE_URL=https://api.example.invalid
```

Los checks `android` e `ios` del [PR de Fase 0](https://github.com/Avera123/finanzas-movil/pull/4) publican la salida real por commit. Verificar esos checks: tener el comando configurado no implica haberlo ejecutado correctamente. Un segundo build Android produce el APK de preview con la URL pública del servicio, sin llamadas de red a la API al compilar.

No se repitió el build Android local que antes se detuvo descargando NDK; iOS no se puede compilar en Windows. Los builds de la base anterior están documentados en VALIDATION.md y no se presentan como resultados del código nuevo. El resumen del PR registra el resultado de CI al finalizar esta fase.

## Evidencia visual y alcance

La pantalla nativa funcional de correo/contraseña ya se observó en el emulador Pixel 10 Pro en esta sesión. El APK anterior de acceso está documentado por su PR; no se sustituyó el emulador por un mockup. La Fase 0 no rediseña esa pantalla ni el resumen: separa su carga interna y conserva el comportamiento probado.

Los mapas Mermaid de [UX_STRATEGY.md](UX_STRATEGY.md) y [ARCHITECTURE.md](ARCHITECTURE.md) son evidencia visual del mapa de información y de la arquitectura propuesta/implementada. No son capturas de módulos terminados. No se incorporan capturas con nombres/saldos/correos reales al repositorio.

## Limitaciones y revisión

- El backend y sus pruebas se inspeccionaron en lectura: **33 tests de API y 58 financieros declarados**, no ejecutados por esta fase.
- El motor JS aún no está portado completamente; no se afirma equivalencia Dart de amortización, ahorro o inversiones todavía. Hay gates y casos de portado en el inventario y el plan.
- No se ha implementado cola de escrituras/409/resultado incierto; se diseñó su protocolo y se bloquearon los métodos financieros de escritura por ausencia en el cliente.
- No se prueban escrituras, migraciones, seeds, restauraciones ni activación administrativa sobre producción.
- Login real, hardware Keychain/Keystore, TalkBack/VoiceOver, temas futuros, rendimiento y distribución firmada requieren sus fases/entornos.
- Fase 1 y cualquier cambio que afecte datos financieros esperan revisión humana; no hay merge automático.
