# Finanzas Móvil

Aplicación Flutter para Android e iOS. Proyecto separado de `finanzas-backend`.

## Preparación

1. Instala el SDK de Flutter y comprueba `flutter doctor`.
2. Clona este repositorio y ejecuta `flutter create --platforms=android,ios .` para generar los proyectos nativos (todavía no versionados).
3. Ejecuta `flutter pub get`.
4. Ejecuta `flutter run --dart-define=API_BASE_URL=https://TU_BACKEND`.
5. Valida con `flutter analyze` y `flutter test`.

## Alcance inicial

- Login con `POST /api/login`, cookie de sesión en almacenamiento seguro del dispositivo.
- Dashboard inicial que consulta `GET /api/state`, muestra saldo neto y cantidad de cuentas/gastos.
- Logout mediante `POST /api/logout`.
- Sin endpoints de modificación desde Flutter.

**Advertencia:** en el backend actual, `GET /api/state` puede inicializar datos cuando la base está vacía. Por eso no se garantiza lectura estricta a nivel del servidor, aunque el cliente móvil solo envía consultas. No se modifica el backend en este trabajo.

## Seguridad

No incluir `DATABASE_URL`, `APP_PASSWORD` ni secretos en el cliente. Usar URL HTTPS en producción. El manejo de cookies móviles y el comportamiento en plataformas deben validarse en dispositivos reales antes del despliegue.

## Estado de verificación

Scaffold guardado en GitHub. `flutter analyze`, `flutter test` y compilaciones nativas pendientes de ejecución en un entorno con Flutter SDK.
