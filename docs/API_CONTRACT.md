# Contrato de la API existente

Verificado por lectura de código el 3 de noviembre de 2026, sin solicitudes a datos financieros ni conexión a PostgreSQL.

Fuentes en `Avera123/finanzas-backend`, rama `master`:

- `server/app.js`, blob `bf96aee6832e26b1a3bbdb2bff70f26ab8a9eae4`.
- `server/db.js`, blob `0246ad7aa2c3d1d59dacf8fffef21748ee52627d`.

| Operación del móvil | Contrato verificado |
| --- | --- |
| `POST /api/login` | JSON con `password` (entrada del usuario en memoria). Éxito: `{"ok":true}` y `Set-Cookie: sesion=…; Path=/; HttpOnly; SameSite=Strict; Max-Age=2592000`, con `Secure` sobre HTTPS. |
| `GET /api/state` | Requiere `Cookie: sesion=…`. Respuesta objeto: `acc` y `exp` son listas. Cuentas: `id`, `name`, `type` (strings) y `bal` (número). |
| `POST /api/logout` | Expira la cookie del cliente con Max-Age=0; responde `{"ok":true}`. No modifica finanzas. |

Login incorrecto: 401. Tras cinco intentos fallidos, bloqueo por IP de 15 minutos: 429. La API protegida responde 401 sin sesión válida. Errores internos: 500.

La cookie tiene un vencimiento en milisegundos seguido de un punto y un HMAC SHA-256 hexadecimal. El móvil verifica formato y vencimiento; **solo el servidor verifica la firma**. Nunca se incorpora la clave de firma al móvil.

El saldo neto de cuentas suma `bal` y resta `bal` para `type == 'Crédito'`, igual que la web. No es patrimonio neto: no incluye otras deudas, préstamos ni ahorros separados. Se conserva la aritmética numérica de la API, sin inferir una contabilidad distinta.

## Restricción de lectura

El cliente solo implementa las tres operaciones anteriores; no tiene PUT, PATCH, DELETE ni restauración de datos. No se ejecutaron estas operaciones contra producción durante esta tarea. Las pruebas interceptan HTTP con respuestas sintéticas y no acceden a bases de datos.

**El GET existente puede escribir en el servidor:** si la base está vacía, `/api/state` carga el seed automáticamente. Por ello no puede garantizarse lectura estricta desde el móvil sin cambiar el backend, lo que está fuera de alcance. Conecta la aplicación únicamente a una instancia ya inicializada; si se requiere garantía absoluta, hace falta un cambio futuro aprobado en la API. En esta tarea no se tocó ese servidor.

## Límites de la sesión existente

No hay usuarios individuales, OAuth, refresh token ni endpoint de revocación. Logout borra el secreto local y pide expirar la cookie; una copia extraída previamente sigue siendo válida hasta vencer o cambiar la contraseña del servidor. No se inventaron endpoints para solucionar esos límites.
