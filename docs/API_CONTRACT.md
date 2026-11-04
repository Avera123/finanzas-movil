# Contrato de la API existente (multiusuario)

Revalidado por lectura del código de `Avera123/finanzas-backend`, rama `master`, el 3 de noviembre de 2026. No se modificó el backend ni se accedió directamente a PostgreSQL.

Referencias verificadas:

- `server/app.js`, blob `a5875753d9564f06f9c36a181995eee5dae8828c`.
- `server/db.js`, blob `89fe70eb0dc99cdef7ade1410d64835d8bb03a3b`.

| Operación del móvil | Contrato verificado |
| --- | --- |
| `POST /api/login` | JSON con `email` y `password`. Correo normalizado con trim/lowercase; contraseña sin transformar. Éxito: `{"ok":true}` y cookie `sesion`, HttpOnly, Path=/, SameSite=Strict, Max-Age=2592000; Secure sobre HTTPS. |
| `GET /api/me` | Requiere cookie. Devuelve `id`, `email`, `name`, `role` (`admin` o `user`), `active`, `hasPassword` y `google`. El móvil valida identidad/rol/estado y muestra nombre y correo del perfil del servidor. |
| `GET /api/state` | Requiere cookie. Devuelve el documento privado del usuario y los ahorros visibles. `acc` y `exp` siguen siendo listas; cada cuenta contiene `id`, `name`, `type` y `bal` numérico. |
| `POST /api/logout` | Expira la cookie con Max-Age=0 y responde `{"ok":true}`. No modifica datos financieros. |

Login incorrecto o cuenta inactiva/sin contraseña: 401, sin revelar cuál de esos motivos ocurrió. Tras cinco intentos fallidos desde una IP: 429 por 15 minutos. Sesión vencida o revocada: 401. Un 403 se presenta como falta de permiso sin borrar una sesión válida. Fallos de red/500 permiten reintentar sin fabricar datos.

## Cookie y revocación

El valor es `id.version.vencimientoMs.hmacSha256`. El id generado por el servidor usa base64url; la versión empieza en 1. El móvil comprueba formato y vencimiento, pero solo el servidor valida la firma, la cuenta activa y que la versión siga vigente. No se incluye la clave de firma en el cliente.

Las cookies antiguas de dos segmentos se borran localmente y exigen volver a entrar. Las sesiones actuales persisten en almacenamiento seguro y se eliminan al cerrar sesión o recibir 401.

Cambiar contraseña, permisos o desactivar una cuenta incrementa `session_ver` en el backend y revoca las cookies previas. Logout solo elimina/expira la cookie de este dispositivo: no incrementa la versión ni revoca otras copias por sí solo.

## Consulta y aislamiento

El dashboard obtiene primero `/api/me` y después `/api/state`; un fallo de identidad no permite mostrar finanzas. Tras logout/login se invalida el estado en memoria. Una prueba completa de dos cuentas verifica que los saldos de la primera no reaparecen en la segunda.

El nuevo `readUserState` solo ejecuta SELECT para armar la respuesta. Ya no inicializa el seed desde el GET. Si falta el documento del usuario devuelve 404; el móvil lo presenta como error, sin crear datos. La inicialización/migración del administrador ocurre en el servidor fuera del flujo móvil.

El cliente no implementa PUT, PATCH, DELETE, restauración, invitaciones ni operaciones administrativas. Las pruebas usan transporte falso y datos sintéticos; no se envían credenciales reales ni se escriben finanzas.

El saldo neto de cuentas conserva la fórmula de la web: suma `bal` y resta `bal` para el tipo `Crédito`. No incluye deudas independientes ni equivale al patrimonio neto.

## Google e invitaciones

Se verificaron las rutas web de Google (`/api/auth/google` y callback) y de invitaciones. No se incorporan al móvil: el callback termina en el navegador, no existe un intercambio de sesión nativo verificado. Una cuenta de Google necesita configurar su contraseña desde la web para usar este login móvil. La aceptación de invitaciones y recuperación de contraseña también se realizan en la web, sin inventar endpoints móviles.
