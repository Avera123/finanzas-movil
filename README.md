# Finanzas Móvil

## Entrega actual: 0.5.0+5

Esta entrega incluye Resumen, Movimientos mensuales, Cuentas y Apariencia. Son consultas reales tras iniciar sesión. Ver [versiones por etapa](docs/VERSIONING.md), [changelog](CHANGELOG.md) y [validación de la entrega](docs/PHASE4_VALIDATION.md). Esta versión incorpora gastos, pagos, cuentas, categorías e ingreso con vista previa y confirmación antes de guardar. Deudas y préstamos están disponibles desde Resumen. Ahorros e inversiones también están disponibles desde Resumen. Anual, ajustes completos y usuarios siguen pendientes.

- [Inventario funcional y referencias verificadas](docs/FUNCTIONAL_INVENTORY.md)
- [Contrato completo de API, permisos, versiones y conflictos](docs/API_CONTRACT.md)
- [Estrategia UX y mapa de navegación propuesto](docs/UX_STRATEGY.md)
- [Sistema de diseño para la siguiente fase](docs/DESIGN_SYSTEM.md)
- [Arquitectura implementada y sincronización futura](docs/ARCHITECTURE.md)
- [Fases y criterios de aceptación](docs/IMPLEMENTATION_PLAN.md)
- [Instrucciones permanentes](AGENTS.md)
- [Validación de Fase 0](docs/PHASE0_VALIDATION.md)

La referencia de la auditoría está fijada en el commit web/backend `7a8380f999850900e4ed8cb5802cf92964bf16dd`. No se modifica ese repositorio ni PostgreSQL. La versión del documento y los campos desconocidos se conservan como snapshot inmutable de lectura; no se reconstruyen futuros guardados desde los conteos de la pantalla.

Cliente Flutter para Android e iOS. Consume exclusivamente la API existente de `Avera123/finanzas-backend`: login por correo y contraseña, perfil, estado y logout. Las modificaciones usan únicamente PUT /api/state confirmado y versionado. No hay conexión directa a PostgreSQL.

## Requisitos

- Flutter **3.47.9 stable**, con Dart **3.13.7** (versiones usadas para generar y validar esta base).
- Android: Android Studio, SDK y cmdline-tools, licencias aceptadas y JDK compatible con Gradle 9.3.1 (CI usa Java 21). Ejecutar `flutter doctor -v` y `flutter doctor --android-licenses` en tu equipo.
- iOS: **macOS**, Xcode y CocoaPods. El proyecto requiere iOS **15.0+**. La configuración incluye Swift Package Manager y Podfile para plugins que aún usan CocoaPods.
- Una instancia HTTPS de la API multiusuario actual, con la cuenta creada o invitación aceptada desde la web. No hace falta volver a ejecutar `flutter create`: `android/` e `ios/` están versionados.

## Instalar y ejecutar

```sh
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <ID_DEL_DISPOSITIVO> --dart-define=API_BASE_URL=https://tu-api.example
```

`API_BASE_URL` es solo el origen HTTPS, sin `/api`, ruta, query, fragmento ni credenciales. Es configuración pública compilada en la aplicación. No pasar contraseñas, cookies, tokens ni `DATABASE_URL` mediante dart-define. El correo y la contraseña de tu cuenta se introducen en el login. No se utiliza la antigua APP_PASSWORD compartida.

En Android, ejecutar en un emulador o dispositivo con depuración USB. La build de desarrollo se obtiene con:

```sh
flutter build apk --debug --dart-define=API_BASE_URL=https://tu-api.example
```

En Mac, ejecutar `flutter pub get` y después `flutter run -d <ID_IOS>` con el mismo dart-define; Flutter instala los pods necesarios. Si los instalas manualmente: `cd ios && pod install && cd ..`. Abrir **ios/Runner.xcworkspace**, no el proyecto aislado, para configurar equipo e identificador de firma.

Para verificar iOS sin publicar ni firmar:

```sh
flutter build ios --simulator --debug --no-codesign --dart-define=API_BASE_URL=https://tu-api.example
```

Los identificadores provisionales son `com.avera.finanzas_movil` (Android) y `com.avera.finanzasMovil` (iOS). Revisarlos antes de distribuir. Android release no usa la clave debug: configurar una firma privada fuera de Git para distribuir. No se incluyen certificados ni claves.

## Validación reproducible

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter pub outdated
```

Las pruebas usan un adaptador HTTP falso y almacenamiento en memoria: no hay peticiones a producción ni operaciones financieras. Las de almacenamiento verifican la integración Dart del plugin con su mock; no sustituyen comprobar Keychain/Keystore en dispositivos físicos.

La automatización en `.github/workflows/flutter.yml` ejecuta análisis, pruebas y compilaciones Android debug e iOS simulador al abrir un PR hacia `master`. El APK Android de prueba se configura con la URL pública https://finanzas-backend-vnr8.onrender.com; la build iOS usa una URL reservada. Compilar no hace solicitudes a esas APIs. No necesita secretos ni despliega.

Ver [resultados y limitaciones](docs/VALIDATION.md).

## Seguridad y autenticación

- HTTPS obligatorio, redirecciones deshabilitadas y timeouts de conexión, envío y recepción. Se conserva la validación TLS normal; no se aceptan certificados inválidos.
- Cookie multiusuario `sesion` (usuario, versión, vencimiento y firma) guardada con `flutter_secure_storage`: almacenamiento cifrado de Android y Keychain de iOS, accesible solo con el dispositivo desbloqueado y sin migración a otro dispositivo en iOS. Android excluye backups y transferencias.
- Las claves de sesión están separadas por URL de API. La cookie global del scaffold anterior se elimina y requiere volver a iniciar sesión.
- La contraseña no se persiste. No hay logs HTTP con contraseñas/cookies ni caché financiera en disco.
- Sesión restaurada al abrir, con comprobación local de formato y vencimiento. El servidor valida la firma en cada consulta. Un 401 borra la sesión y ofrece volver a entrar; red/500 permite reintentar sin inventar datos.
- Logout borra la sesión local incluso si la red falla. El backend actual solo expira la cookie y no revoca una copia robada del token.
- Login por correo y contraseña con el contrato actual. El dashboard muestra el perfil obtenido de GET /api/me y consulta únicamente los datos autorizados por esa sesión. Se descartan las cookies antiguas y el estado anterior al cambiar de cuenta. Google nativo no está implementado; configura una contraseña desde la web si tu cuenta solo usa Google.

Contrato verificado y referencias de código en [docs/API_CONTRACT.md](docs/API_CONTRACT.md).

**Contrato actualizado:** el GET /api/state actual llama readUserState y solo consulta los datos del usuario. Ya no carga el seed automáticamente. Si no existe su documento devuelve 404; la app muestra un error y no crea datos.

## Estructura

- `lib/src/core/api/`: cliente API, errores y almacenamiento de sesión inyectable.
- `lib/src/core/models/`: modelo validado y cálculo de saldo de cuentas.
- `lib/src/features/auth/`: login y restauración de sesión.
- `lib/src/features/dashboard/`: consulta, reintento y cierre de sesión.
- `android/`, `ios/`: proyectos nativos generados por Flutter.
- `test/`: saldo, autenticación, transporte, almacenamiento y pantallas reales.

El saldo de cuentas suma ahorros/efectivo y resta las cuentas cuyo tipo es `Crédito`, respetando la web. No incluye deudas independientes ni equivale a patrimonio neto.

## Dependencias

`pubspec.lock` fija las versiones resueltas: Dio 5.11.1, Riverpod 2.6.1, go_router 14.8.1, flutter_secure_storage 9.2.4 y flutter_lints 5.0.0. Se ajustó el mínimo Dart a 3.5 por los lints, y se fijó el mínimo Flutter a la versión que generó los archivos nativos. La resolución efectiva del lock requiere Dart 3.13, incluido en Flutter 3.47.9.

`flutter pub outdated` confirma versiones mayores disponibles de Riverpod, go_router y almacenamiento seguro; no se hicieron migraciones mayores a ciegas. La cadena multiplataforma antigua de almacenamiento también trae paquetes descontinuados para web/macOS (`js`, `flutter_secure_storage_macos`), aunque esta app solo apunta a Android/iOS. Las compilaciones Android debug e iOS simulador también pasaron en CI. Esto no equivale a una auditoría de vulnerabilidades ni comprueba Keystore/Keychain en hardware; verificar su funcionamiento antes de distribución.

## APK para probar

En GitHub Actions, abre una ejecución correcta de Flutter verification y descarga el artefacto finanzas-movil-android-debug. El ZIP contiene app-debug.apk, configurado para tu servicio de Render. Los artefactos se conservan 7 días. Es una build de desarrollo; al abrirla introduce el correo y la contraseña de tu cuenta de Finanzas, como en la web. No uses APP_PASSWORD ni las credenciales de PostgreSQL. No hay contraseñas incluidas en el APK.
