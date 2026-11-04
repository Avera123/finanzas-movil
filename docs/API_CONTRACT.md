Estado actual 0.3.0: PUT /api/state implementado con confirmación y versión; ver [validación de etapa 2](PHASE2_VALIDATION.md). Las referencias a cliente de solo lectura más abajo describen la auditoría original de Fase 0.

# Contrato de la API existente (multiusuario)

Revalidado por lectura del código de `Avera123/finanzas-backend`, rama `master`, el 3 de noviembre de 2026. No se modificó el backend ni se accedió directamente a PostgreSQL.

Referencias verificadas:

- `server/app.js`, blob `a5875753d9564f06f9c36a181995eee5dae8828c`.
- `server/db.js`, blob `cba3a4638415fd34ff363d3d6d2c8ec6e798178c`.

Auditoría completa fijada al commit `7a8380f999850900e4ed8cb5802cf92964bf16dd` (incluye inversiones y desplazamientos). [Inventario](FUNCTIONAL_INVENTORY.md) enumera los blobs de todos los archivos revisados.

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

El snapshot de lectura ahora conserva la versión positiva y todos los campos JSON de forma inmutable, además del resumen tipado. No incluye `toJson` ni un método de guardado. Una respuesta sin versión válida es un error recuperable, no un documento sobre el cual se pueda escribir.

El saldo neto de cuentas conserva la fórmula de la web: suma `bal` y resta `bal` para el tipo `Crédito`. No incluye deudas independientes ni equivale al patrimonio neto.

## Google e invitaciones

Se verificaron las rutas web de Google (`/api/auth/google` y callback) y de invitaciones. No se incorporan al móvil: el callback termina en el navegador, no existe un intercambio de sesión nativo verificado. Una cuenta de Google necesita configurar su contraseña desde la web para usar este login móvil. La aceptación de invitaciones y recuperación de contraseña también se realizan en la web, sin inventar endpoints móviles.

## Catálogo completo de operaciones existentes

Esta tabla documenta la paridad futura, **no habilita escrituras en Fase 0**. No se llamaron sus operaciones mutables contra producción. Los IDs de usuario se obtienen del servidor; nunca se usa un ID elegido por el cliente para consultar finanzas ajenas.

| Método/ruta | Acceso | Petición | Respuesta/efectos relevantes |
| --- | --- | --- | --- |
| GET /api/health | Público | — | `{ok:true}` tras SELECT 1 |
| GET /api/config | Público | — | `{google:boolean}` |
| POST /api/login | Público, limitado por IP | `{email,password}` | `{ok:true}` y cookie nueva; 401/429 |
| POST /api/logout | Público | — | `{ok:true}`; expira cookie local, sin revocación global |
| GET /api/auth/google | Solo si Google configurado | — | Redirección Google y cookie google_state de 10 min, SameSite=Lax |
| GET /api/auth/google/callback | Flujo web | query code/state | Valida estado/claims, crea/vincula usuario autorizado o invitado; cookie y redirección a /; errores /?error=... |
| GET /api/invites/check | Token válido | query token | `{email,kind}`; 404 inválido/usado/vencido |
| POST /api/invites/accept | Token válido | `{token,name,password}`; name para invite | `{ok:true}` y sesión; contraseña >=12; token de un uso. Reset incrementa sesión |
| GET /api/me | Sesión activa | — | Perfil público |
| PATCH /api/me | Sesión activa propia | `{name}` (trim, 1..80) | `{ok:true}`; cambia nombre |
| POST /api/me/password | Sesión activa propia | `{current,next}` | Verifica current si hasPassword; next>=12; `{ok:true}` y cookie renovada; revoca anteriores |
| GET /api/users | Admin | — | `{users:[perfil],invites:[{email,role,expiresAt}]}`; no datos financieros |
| POST /api/invites | Admin | `{email,role}` | `{token,expiresAt}`; siete días; 409 correo ya registrado; nueva invitación invalida la anterior |
| DELETE /api/invites/:email | Admin | email URL-encoded | `{ok:true}`; revoca invitación pendiente |
| PATCH /api/users/:id | Admin | `{role?,active?}` | `{ok:true}`; incrementa session_ver; si self, renueva cookie. 400 último admin, rol/estado inválido; 404 desconocido |
| POST /api/users/:id/reset | Admin | `{}` | `{token,expiresAt}` de reset, un uso; no envía email |
| GET /api/state | Sesión activa propia | — | `{version,...doc,savings,contrib}`; sin seed; 404 sin doc |
| PUT /api/state | Sesión activa propia | Documento completo y version entera | `{version:nueva}`; 400 formato, 409 versión obsoleta; transacción y reglas de fondos compartidos |
| GET /api/export | Sesión activa propia | — | Adjunto JSON con estado y exportedAt |
| GET /api/export.csv | Sesión activa propia | — | CSV con BOM, separador ;, columnas Mes/Nombre/Categoria/Tipo de pago/Cuenta/Monto/Pagado; neutraliza fórmulas |
| POST /api/restore | Sesión activa propia | Documento validado de respaldo | `{version:nueva}`; reemplaza sin expected version, con reglas de fondos. No ejecutar contra datos reales en esta misión |
| GET /api/trm | Sesión activa | — | `{rate,updated}`; USD→COP de open.er-api, cache de una hora, dos decimales; 502 si no hay COP. No es un endpoint bancario ni certificación de TRM |

Los errores previstos tienen JSON `{error:string}`. Los 500 deliberadamente no exponen mensajes internos. Express admite JSON hasta 5 MB. Las rutas de API inexistentes protegidas terminan en 404; un cliente sin sesión puede recibir 401 primero.

## Guardado futuro, versión y conflicto

1. GET obtiene snapshot completo D con versión v y contexto de usuario U. Conservar campos no usados, incluidos inversiones, reanudación de cuotas, tema y fundSeen.
2. Un comando prepara una copia y un resumen de impacto (importe, cuenta, mes, recurrencia, miembros afectados). Requiere confirmación del usuario antes de enviar.
3. Solo un guardado a la vez. PUT envía el documento confirmado y v. No hay PATCH de gastos ni pagos ni Idempotency-Key verificado.
4. Solo 2xx con versión entera nueva confirma éxito. Un 409 detiene la cola: preservar borrador, recargar en U y mostrar diferencias; no reenviar el viejo doc con una versión copiada de otro.
5. Timeout o desconexión pueden ocurrir después de un commit. Marcar resultado incierto, recargar y revisar IDs/paid/version antes de reintentar. No volver a mover cuentas a ciegas.
6. Un 401 invalida la sesión. Un borrador jamás se aplica a otra cuenta tras reautenticar. Cambiar cuenta descarta datos en memoria o mantiene borrador aislado por U; no lo sube a un usuario nuevo.
7. Después del éxito recargar: los aportes compartidos se mezclan en servidor, y la versión del documento de otro participante no es un contador global del fondo.

El servidor no es un motor de amortización ni recalcula saldos: persiste el documento del cliente, valida la forma y aplica el control de versión/permisos de fondos. Las reglas de finance.js deben portarse y probarse antes de cada comando financiero móvil.

## Permisos de fondos compartidos

- GET devuelve fondos cuyo owner_id es el usuario o cuyo miembro tiene su email. isOwner y mine se calculan en el servidor; acc/memberAcc provienen del vínculo privado de cada usuario.
- Solo propietario cambia metadatos y elimina el fondo. No se puede adoptar un id ajeno enviándolo en el doc.
- Cada usuario registrado modifica solo sus aportes; propietario también puede gestionar miembros sin email. Se permite preparar una fila pendiente ajena una vez por miembro/mes, nunca marcarla pagada.
- mergeContrib conserva cambios ajenos frente a pestañas antiguas. Una baja por propietario afecta a los demás participantes. El administrador no obtiene excepciones a estas reglas.

## Diferencias que impiden habilitar escrituras todavía

El login y lectura actuales están probados con mocks y builds. Persistencia de comandos, serialización íntegra de un draft, cola/concurrencia, respuesta perdida tras commit, 409 y confirmaciones financieras aún no están implementados. Forman la puerta de entrada de Fase 2. La restauración real queda expresamente excluida. La aplicación no presenta controles de guardar/pagar para esos flujos en Fase 0.
