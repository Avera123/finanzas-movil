# Finanzas Móvil — instrucciones permanentes

## Alcance

- Repositorio modificable: Avera123/finanzas-movil. Base: master; trabajar en rama y PR de fase, sin merge automático ni push directo a master.
- Avera123/finanzas-backend es SOLO LECTURA. No modificar sus archivos, publicar commits allí ni ejecutar sus migraciones, seeds, bootstrap o restauraciones sobre datos reales.
- No conectar a PostgreSQL. El móvil consume únicamente la API verificada. No inventar endpoints ni estructuras; fijar commit/blobs del contrato cuando se audite.
- La misión se entrega por fases. Completar Fase 0 y esperar revisión antes de avanzar a cambios que afecten datos financieros. No reunir todas las fases en un PR.

## Antes de implementar un módulo

Leer FUNCTIONAL_INVENTORY, API_CONTRACT, UX_STRATEGY, DESIGN_SYSTEM, ARCHITECTURE e IMPLEMENTATION_PLAN en docs/. Revalidar el módulo web y finance.js contra su commit; registrar cambios respecto a lo auditado. Revisar objetivo, camino corto, información principal, riesgos, interacción nativa, simplificaciones, estados y accesibilidad.

Conservar Flutter, Riverpod, GoRouter y el cliente HTTP salvo justificación técnica. No copiar negocio dentro de widgets. Modelos/cálculos puros en dominio, orquestación en aplicación, API/repositorios en datos, UI/componentes/temas en presentación compartida.

## Integridad y seguridad

- HTTPS, almacenamiento seguro, sin contraseñas persistidas ni logs de credenciales/cookies/tokens/datos financieros.
- Respetar roles y permisos reales; un admin no ve finanzas privadas ajenas. isOwner/mine del servidor no son permisos que el cliente pueda inventar.
- Snapshot completo y versionado; nunca reconstruir PUT desde el resumen parcial ni perder campos desconocidos.
- Mutación financiera: copia/draft, preview del impacto y **confirmación explícita del usuario antes de cada escritura**. Cancelar no cambia datos. Proteger doble toque y serializar guardados.
- No anunciar éxito sin respuesta válida. 409 detiene guardado y exige recargar/comparar; timeout posterior al envío es resultado incierto, no motivo para duplicar un pago. Un borrador no pasa a otra cuenta.
- Probar escrituras con mocks o entornos aislados expresamente autorizados; no realizar pruebas destructivas ni cambios financieros sobre producción. Restauraciones reales prohibidas en esta misión.
- Credenciales y firma privada nunca en Git, APK o artefactos. Solo URL pública configurable como dart-define. No instalar código/skills sin revisar procedencia, permisos y riesgos.

## UX y calidad

Material 3 personalizado; cuatro destinos frecuentes como máximo más acceso claro a secundarios; no diez pestañas. Cifras legibles/tabulares, etiquetas de real/proyectado, moneda/tasa explícita, estados útiles y errores recuperables. Sin pantallas decorativas o datos ficticios presentados como reales.

Respetar SafeArea/teclado, teléfono/tablet, texto 200%, TalkBack/VoiceOver, contraste y targets táctiles. Animaciones breves e intencionales con alternativa sin movimiento; no retrasar ni ocultar operaciones financieras. Propuestas de negocio nuevas se identifican y requieren aprobación antes de afectar datos.

## Verificación y entregas

Ejecutar según alcance: flutter pub get --enforce-lockfile; dart format --output=none --set-exit-if-changed lib test; flutter analyze --no-pub; flutter test --no-pub --coverage. CI valida Android debug e iOS simulador con API_BASE_URL=https://api.example.invalid; un segundo APK de preview puede usar la URL pública proporcionada, sin llamar a la API durante build.

iOS necesita macOS/Xcode; pruebas de Keychain/Keystore físico requieren dispositivo. Registrar solo resultados ejecutados, SHA/entorno, limitaciones, evidencia visual sin información privada y enlace al PR. No afirmar que se probó producción, accesibilidad física, portado financiero o distribución si solo existen mocks, documentación o simulador.

Mantener los siete entregables exigidos y el informe de fase. Un cambio de presentación reversible no necesita aprobación adicional salvo regla explícita del usuario; la aprobación financiera y la revisión entre fases sí son obligatorias. No solicitar contraseñas por chat.

<!-- codebase-memory-mcp:start -->
For structural codebase exploration, use the installed codebase-memory skill.
<!-- codebase-memory-mcp:end -->
