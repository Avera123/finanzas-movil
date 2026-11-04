# Inventario funcional verificado — Fase 0

Fecha: 3 de noviembre de 2026 (America/Bogota). Referencia web/backend fijada al commit `7a8380f999850900e4ed8cb5802cf92964bf16dd`, no a un master cambiante. Inspección de los 17 archivos exigidos y de package.json. Los archivos de pruebas se **leyeron**, no se ejecutaron en el repositorio de referencia. No se accedió a su PostgreSQL ni se ejecutaron seeds, migraciones o restauraciones.

## Estado del móvil y brecha

El móvil implementa login por correo/contraseña, restauración/cierre seguro, perfil y resumen de cuentas de consulta. No tiene todavía paridad funcional con la web. Esta fase establece el contrato y la arquitectura: **no añade pantallas de módulos ficticias ni operaciones financieras de escritura**.

| Módulo | Web verificada | Móvil al cerrar Fase 0 | Fase de paridad |
| --- | --- | --- | --- |
| Acceso | Correo/contraseña, Google condicionado, invitación y reset | Correo/contraseña, cookie nueva y revocación 401; Google/enlaces pendientes | 0; enlaces/seguridad en 5 |
| Resumen | Proyección de cierre, seis meses, categorías y alertas | Perfil, saldo de cuentas y conteos; sin proyecciones | 1 |
| Gastos/ingresos | Pago, deshacer, repetir, cuenta, mover, ingreso mensual | Consulta de resumen; ninguna mutación | 2 |
| Cuentas | Crear/tipos/saldos/depósito USD/eliminar si no tiene gastos | Saldo neto proyectado por modelo de lectura | 2 |
| Categorías/pagos | Listas, conteos y alta/baja restringida por uso | Pendiente | 2 |
| Deudas | Cinco formas de plan, abonos, interés, cuotas abiertas/desplazadas | Pendiente | 3 |
| Préstamos | Prestado, vencimiento, recibir/deshacer y reversión al eliminar | Pendiente | 3 |
| Ahorros | Compartidos, aportes, metas, permisos por miembro | Pendiente | 4 |
| Inversiones | Cuota fija/%/meta, rendimiento estimado, reprogramación | Pendiente | 4 |
| Anual | Ventana de 12 meses, ingresos editables, gráficos/detalle | Pendiente | 5 |
| Ajustes | Salario/cambio/base/tema/perfil/contraseña/respaldos | Logout; tema único oscuro | 1 y 5 |
| Usuarios | Admin: permisos, activación, invitación/reset | Perfil con capacidad admin calculada; sin UI administrativa | 5 |

## Documento y campos

Todos estos módulos privados se guardan por el mismo PUT /api/state; no existen endpoints separados para cuentas, deudas, préstamos o inversiones.

| Entidad | Campos observados |
| --- | --- |
| Estado raíz | version; usd, rate, startM, start, living, inc, cats, meths, acc, exp; opcionales debts, savings, contrib, investments, loans, loanPay, theme, fundSeen; otros campos deben conservarse |
| Cuenta | id, name, type, bal. UI: Ahorros, Corriente, Efectivo, Crédito, Inversión |
| Gasto/cuota | id, m (YYYY-MM), name, cat, amt, meth, acc nullable, paid; enlaces debtId, investId, seriesId opcionales |
| Deuda | id, name, total, rate mensual %, cuota, startM, acc, mode=fixed/fast/open; endM y resumeM opcionales |
| Ahorro visible | id, name, bank, acc del usuario, start, startM, target/endM opcionales; members; isOwner generado por servidor |
| Miembro | id, name, monthly, email opcional, mine generado por servidor, acc solo para el propio miembro |
| Aporte/retiro | id, savingId, memberId, m, amt (negativo para retiro), done, extra |
| Inversión | id, name, kind, mode=fixed/percent, value, startM, months (1..600), rate anual, acc; target/resumeM opcionales |
| Préstamo | id, person, total, lentOn/dueOn (YYYY-MM-DD), acc opcional, note |
| Cobro | id, loanId, on, amt, acc opcional |
| Perfil | id, email, name, role=admin/user, active, hasPassword, google |
| Gestión de accesos | users y invites; enlace temporal con token y expiresAt. Tokens no se incluyen en este inventario |

Los meses son períodos locales, no instantes UTC. Las fechas de préstamo son días locales. Formato monetario COP sin decimales visibles; los cálculos internos conservan números antes de redondear. No se incluyen números de cuenta, correos reales ni datos del seed.

## Operaciones y reglas por módulo

### Resumen y gastos (App.jsx)

- Ingreso del mes = inc[mes] si existe; de otro modo usd × rate. Cambiar el dólar afecta meses sin override: no inferir que son ingresos históricos verificados.
- Neto en cuentas = suma de bal, restando las de tipo exacto Crédito. No es patrimonio neto.
- Proyección desde startM: start + suma de monthly(...).left hasta el mes elegido. La diferencia compara cuentas actuales contra cierre previsto; no presentarla como saldo disponible hoy.
- Gráficos: cierre esperado en seis meses; gasto registrado por categoría; barras de gastos y referencia de ingreso. Una categoría abre sus filas.
- Crear gasto repetido genera r filas consecutivas con seriesId común; no es un cron del servidor. Pagar/deshacer mueve la cuenta e invierte paid. Si no hay cuenta se avisa; se permite saldo negativo con advertencia.
- Crédito: pagar una compra aumenta bal de crédito; ingresar dinero lo reduce. No crear una transferencia automática de pago de tarjeta: no hay ese flujo explícito en la web.
- La cuenta solo se cambia mientras la fila está pendiente. Eliminar un gasto pagado revierte su efecto. Filas de deuda/inversión se administran en su módulo.
- No hay edición general de todos los campos de un gasto ni libro mayor independiente de movimientos de cuenta. El móvil no debe fingir disponer de ellos.

### Cuentas y categorías

- Alta de cuenta con saldo inicial; edición directa de bal; depósito USD a COP usando rate; baja bloqueada si hay exp.acc vinculados.
- La comprobación de baja de cuenta de la web solo mira gastos, no todos los enlaces de ahorros/préstamos/deudas/inversiones. Riesgo pendiente: no extender ni relajar la regla sin definir cómo conservar enlaces.
- cats y meths son listas de nombres. No hay renombrado en cascada; alta exige nombre nuevo; baja bloqueada si un gasto lo usa.
- Un depósito cambia el saldo pero no añade una transacción histórica separada. El detalle móvil podrá reunir movimientos existentes con su origen, nunca inventar movimientos faltantes.

### Deudas

- Formas de entrada: cuota fija elegida; cuota y cantidad conocidas (interés implícito); número de meses (cuota calculada); menor tiempo (todo lo libre); solo cuota sin saldo.
- Se persisten fixed/fast/open; las formas conocidas/número de meses se convierten a cuota y tasa. Un plazo no equivale a un préstamo con interés bancario estándar: **la primera cuota se paga antes del primer interés**.
- schedule recorre como máximo 600 meses; total inicial, interés desde el segundo mes, resta pagos hechos y calcula pendientes desde max(startM, hoy, resumeM). Última cuota limita saldo y usa ceil; saldo <1 termina. Plan inviable devuelve ok=false sin filas.
- cuotaForN usa anualidad anticipada: B·r/[1-(1+r)^(-n)]/(1+r), con ceil; r=rate/100. Sin interés ceil(B/n).
- impliedRate hace 80 bisecciones en tasa mensual [0,1]; rechaza cuota×n menor que capital. No extrapolar tasas fuera de esa búsqueda sin aprobación.
- fast usa incomeOf menos max(gasto base, gasto registrado de vida), otras cuotas/inversiones y aportes propios. No cuenta cobros futuros de préstamos como dinero seguro.
- living manual o promedio de los últimos tres meses **con registros**, no necesariamente consecutivos, excluyendo deudas e inversiones.
- Recalcular conserva pagados y reemplaza pendientes. Un abono es una fila pagada con prefijo Abono:, mueve cuenta y acorta/recalcula plan; no cuenta como cuota ordinaria.
- open genera 12 meses móviles sin duplicar por deuda/mes; conserva montos modificados y respeta endM. No suma un saldo total desconocido.
- Detectar cuotas usa categoría Deuda o coincidencia cuota/alkomprar/crédito. La sugerencia de sustitución por primera palabra del nombre no es identidad fiable: el móvil debe pedir elección explícita antes de reemplazar.

### Movimiento de pagos (MovePanel.jsx)

- Una fila suelta pendiente puede cambiar a otro mes. Una pagada no se mueve.
- Una serie común se desplaza X meses positivos desde la fila elegida, dejando anteriores y pagados.
- Una deuda desplaza **todas** las pendientes. Con saldo recalcula interés durante espera; muestra antes nuevo plan/interés y bloquea si inviable. Sin saldo conserva valores y desplaza endM cuando existe.
- Una inversión desplaza todas las pendientes y recalcula el porcentaje con el ingreso del mes de destino.
- Persistir resumeM impide que un recálculo rellene el período de espera. No convertir meses en intervalos de 30 días.

### Ahorros compartidos

- Crear/editar: nombre, banco, cuenta vinculada o separada, saldo inicial, inicio/final/meta y miembros. Se generan 12 meses futuros por miembro con monthly>0, sin duplicados.
- resyncSaving conserva aportes hechos y extras; rehace pendientes. Solo propietario edita metadatos/borra el fondo; todos ven los fondos compartidos con su correo.
- canEditMember permite lo propio, o al propietario gestionar miembros sin correo. No permite marcar a otro usuario registrado ni siquiera al administrador.
- setContribution cambia saldos una sola vez (guard c.done === done). Del origen propio al destino; si ambos son iguales no cambia el saldo. Aporte ajeno llega solo a la cuenta propia vinculada al fondo.
- reconcileShared usa fundSeen para aplicar una sola vez diferencias de aportes ajenos; markFundSeen evita sumar otra vez al vincular fondos existentes.
- El saldo real solo incluye done. Proyección incluye planeado desde hoy. Meta usa saldo real y suma mensual de todos; indica alcanzada/imposible antes del final.
- Retiro es aporte extra negativo, limitado al saldo. Eliminar fondo borra sus aportes compartidos, **no** revierte saldos de cuentas; explicar esta diferencia antes de confirmar.
- El servidor separa doc privado y funds/fund_members: no enviar acc de otro miembro ni usar mine/isOwner como autorización propia.

### Inversiones

- Tipos UI: CDT, Fondo, Acciones, Cripto, Finca raíz, Otra. Son etiquetas, no conectores de mercado.
- Valor fijo o porcentaje del incomeOf de cada mes. Porcentaje UI hasta 100%; se guarda redondeado con Math.round. Los pagados no cambian al modificar ingreso.
- Meta con fecha se convierte a mode=fixed y cuotaForGoal; monthsBetween cuenta meses inclusivos; plazo 1..600.
- Tasa mensual efectiva r=(1+anual/100)^(1/12)-1; cuota objetivo ceil(T·r/[((1+r)^n-1)·(1+r)]), o ceil(T/n).
- applyInvestment conserva pagados y rehace pendientes para completar months; no son aportes a un broker ni rentabilidad recibida.
- investStatus acumula (valor+cuota)·(1+r) por cada fila registrada, con trayectoria ordenada. No sustituir por interés por huecos de calendario al portar: es una decisión pendiente, no un arreglo UX.
- Pagar usa el mismo movePayment de gastos. Borrar deja pagados como gastos sin enlace. Cuotas diferidas usan resumeM; las porcentuales se actualizan en el nuevo mes.
- Mostrar rendimiento como estimación no garantizada. No obtener precios ni ejecutar inversiones reales.

### Préstamos

- Registrar person/total/fechas/cuenta/nota; valida devolución no anterior al préstamo y resta cuenta solo si acc existe.
- Recibir requiere 0<importe<=pendiente; agrega loanPay y suma cuenta si se elige. Deshacer invierte la cuenta y borra el cobro.
- Eliminar préstamo revierte salida inicial y todos los cobros. No es la regla de borrado de un ahorro.
- Estado: pagado si saldo<1; vencido si días<0; por vencer si <=30; normal en otro caso. La alerta de Resumen usa vencidos y próximos.
- loansIn suma recibido y, desde hoy, proyecta saldo por vencer en su mes. Un vencido de un mes pasado no reaparece como ingreso futuro. loansOut cuenta salida solo si tiene cuenta.
- No hay intereses de préstamos a terceros ni cobro automático del banco.

### Anual

- Ventana de 12 meses, inicial hoy-5; saltos de seis meses. No es obligatoriamente enero-diciembre.
- Detalle por categoría/nombre con pagados/pendientes; prefijo Abono: agrupado con el nombre.
- monthly.total = vida + pagos de deuda + ahorro propio + inversión; left = ingreso + cobros - préstamos salientes - total.
- Mes futuro usa max(vida registrada, gasto base); pasado/hoy usa lo registrado. Invest/deuda no contaminan el promedio.
- Saldos de cierre: deuda, ahorrado, invertido (aportes, no rendimiento estimado) y por cobrar; no se suman saldos de cierre en una columna total anual.
- Tabla permite sobreescribir ingreso del mes; vacío vuelve al salario×dólar. Leyendas filtran series y tocar mes abre detalle/Gastos.

### Ajustes, acceso y usuarios

- Ajustes: usd/rate (consulta /api/trm), startM/start, living, theme, nombre y contraseña propia, export JSON/CSV y restore.
- Seis temas: auto, oscuro, claro, bosque, oceano, arena. Web guarda localmente y en doc. El móvil aún no los implementa.
- Mínimo 12 caracteres para nueva contraseña/invitación/reset; login solo exige credenciales presentes. Hashes y secreto de firma quedan en servidor.
- Invitación/reset por enlace de un solo uso de 7 días; admin lo comparte manualmente. No hay envío automático de correo ni endpoint de contraseña olvidada por email.
- Admin gestiona accesos, no finanzas ajenas. API impide quitar el último admin activo. Cambio de rol/actividad/contraseña incrementa sesión; si es uno mismo devuelve cookie renovada.
- Google web solo con configuración y correo autorizado/invitado. No existe contrato nativo de transferencia de sesión; no simular Google dentro de un WebView inseguro.
- Operaciones administrativas y restauraciones no se prueban contra producción desde esta misión.

## Dependencias y pruebas inspeccionadas

- Web: React 18.3, Recharts 2.12, Lucide, Vite; servidor Express 4, pg, scrypt nativo y fetch; tests Node con PGlite en memoria.
- Móvil: Flutter 3.47.9/Dart 3.13.7, Riverpod 2.6.1, GoRouter 14.8.1, Dio 5.11.1 resuelto, almacenamiento seguro 9.2.4. No se añade dependencia de diseño ni motor financiero externo en Fase 0.
- src/finance.test.js contiene **58 casos declarados**: deuda/cuotas/interés y desplazamientos, inversiones, aportes/idempotencia/reconciliación/permisos, préstamos/fechas y monthly.
- server/app.test.js contiene **33 casos declarados**: auth, aislamiento, admin/invites/Google, versiones/backup, shared funds y migración. Son cobertura leída, no resultados ejecutados por nosotros.
- No se portaron aún las 58 reglas a Dart: fases 2–5 requieren fixtures sintéticos de equivalencia con el JS fijado. La equivalencia hoy implementada se limita al saldo neto de cuentas.

## Diferencias y decisiones de seguridad

| Hallazgo | Tratamiento móvil / decisión |
| --- | --- |
| Login antiguo enviaba solo password y esperaba cookie de 2 partes | Corregido: email+password y 4 partes; tests; se descarta cookie antigua |
| Modelo resumen descartaba version y campos no usados | Snapshot inmutable completo con versión positiva; summary separado. No hay serializer de escritura |
| Web autosalva tras carga/reconciliaciones | No copiar: presentar plan/cambios y confirmar antes de un PUT futuro |
| Web retiene S al recibir 401 y en onOk puede ejecutar flush sin releer si S existe | Riesgo si se cambia de usuario durante reautenticación. Móvil invalida snapshot y vuelve a leer perfil/documento; test de dos cuentas |
| PUT reemplaza doc completo | Conservar campos desconocidos; no serializar desde saldos/conteos. 409 requiere recarga y revisión, nunca sobrescritura automática |
| Fondos compartidos se actualizan fuera del número de versión de otro integrante | Reload posterior obligatorio; servidor mergeContrib decide permisos; no hacer merge local de datos ajenos |
| No hay idempotency-key ni endpoint de transacciones | Serializar operaciones, IDs estables y estado ambiguo en timeout; probar commit-servidor/respuesta-perdida antes de habilitar pagos |
| Algunas validaciones web son laxas (p.ej. baja de cuenta y formato de mes) | Registrar como decisión pendiente; no alterar fórmula o permiso de negocio por interpretación UX |
| Resumen/Anual pueden mostrar cifras distintas al tener cobros, aportes o inversión | Etiquetas explícitas de real/proyectado y de qué incluye cada indicador; confirmar criterio financiero antes de unificar cálculos |

## Fuentes y trazabilidad

| Archivo inspeccionado | Blob SHA |
| --- | --- |
| [src/App.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/App.jsx) | `1eafa31c5b7c2b92965b8ad2e88eed56635c6fe7` |
| [src/Debts.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/Debts.jsx) | `580b48087ccbe676f53b178fac1ab7a9e7314b51` |
| [src/Annual.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/Annual.jsx) | `ee54f0ad94a596026cc79f4c2e3d81e854da0f93` |
| [src/Savings.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/Savings.jsx) | `1c9275c822caef37a0c1b8be89210f1120cf743d` |
| [src/Investments.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/Investments.jsx) | `2d25031e20ce049236d37535816aa1b8ab95c996` |
| [src/Loans.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/Loans.jsx) | `9e207e9de4bb34d08f08edd88d1b530b268d59eb` |
| [src/Users.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/Users.jsx) | `9c95c44fe581ba5945f1c87c3148b6cf8a118b36` |
| [src/Access.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/Access.jsx) | `a14d2a828f8d276b91d557e5e6ab2b4a123af997` |
| [src/MovePanel.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/MovePanel.jsx) | `8065411bb01cd3d37c008807c9178fb49abef1c6` |
| [src/finance.js](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/finance.js) | `9f60756f549f6b6d0d112394d81e9eecae92097f` |
| [src/charts.jsx](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/charts.jsx) | `c640b2f78eaf42782751ed8ffe9e2200c2cb6e16` |
| [src/theme.js](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/theme.js) | `2c7af2dab40543279e9a53337dcc03e2c0b8c8d1` |
| [src/styles.css](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/styles.css) | `b63a36e2bf0a7756f1f7aff58abddc0e27dc4bc3` |
| [server/app.js](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/server/app.js) | `a5875753d9564f06f9c36a181995eee5dae8828c` |
| [server/db.js](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/server/db.js) | `cba3a4638415fd34ff363d3d6d2c8ec6e798178c` |
| [server/app.test.js](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/server/app.test.js) | `6f1046e43f0da2bbaf18f800f196a2f747f6325a` |
| [src/finance.test.js](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/src/finance.test.js) | `efdeab96215049099d20a40b97516763577d47dd` |
| [package.json](https://github.com/Avera123/finanzas-backend/blob/7a8380f999850900e4ed8cb5802cf92964bf16dd/package.json) | `cf6e61fc2bbc923e5f1dd41a80d74fc513722166` |

Los snapshots se leyeron desde GitHub con permisos de lectura. No se incorporan datos del seed ni copias del backend a este repositorio.
