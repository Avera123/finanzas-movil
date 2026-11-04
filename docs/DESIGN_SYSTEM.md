# Sistema de diseño propuesto — Fase 0

Estado: especificación para Fase 1. El móvil actual solo tiene un tema Material 3 oscuro y las pantallas reales de acceso/resumen. No se afirma que este catálogo esté implementado.

## Identidad y temas

Conservar la identidad de la web: superficies sobrias, acento reconocible, importes protagonistas, curvas discretas y estado semántico claro. Mantener IDs estables en preferencias: auto, oscuro, claro, bosque, oceano, arena.

| Tema | Fondo | Superficie | Texto | Secundario | Acento de acción | Sobre acento |
| --- | --- | --- | --- | --- | --- | --- |
| Oscuro | #0D1016 | #151A23 | #ECEFF5 | #B4BDCF | #F2B84B | #241A05 |
| Claro | #F5F6F8 | #FFFFFF | #171B24 | #525C70 | #F2B84B | #241A05 |
| Bosque | #0C1410 | #131E18 | #E9F2EC | #AFC1B5 | #63C98F | #06210F |
| Océano | #0B1220 | #111B2E | #E8EEFB | #AEBBD3 | #7CB8FF | #04182F |
| Arena | #F6F1E7 | #FFFDF8 | #2A2318 | #5F5546 | #D9913A | #1F1405 |

Los colores provienen de styles.css del snapshot auditado; no confiar en que un ColorScheme.fromSeed reproduzca todos automáticamente. Definir ThemeExtension para superficies/semántica/series y contrastar pares efectivos, incluidos botones, hints y error. auto selecciona claro/oscuro según el sistema y cambia en vivo. Estado financiero usa signo, texto e icono, no solo color.

Persistencia propuesta: tema local en clave de preferencia separada de la sesión. No hacer PUT financiero al elegir una paleta en Fase 1. La preferencia remota por usuario se incorporará cuando exista guardado completo/versionado aprobado; al cambiar usuario no se debe reenviar su documento anterior.

## Tipografía y cifras

- Fuentes del sistema para inicio rápido y sin descargas externas. No añadir Google Fonts o assets con licencia sin revisarlos.
- Escala inicial: indicador 32/40, título 24/32, sección 20/28, texto 16/24, etiqueta/nota 14/20. Cifras grandes podrán envolver; no usar FittedBox para contrarrestar la ampliación del usuario.
- FontFeature.tabularFigures para importes. Alineación de cifras coherente en listas y tablas. Mostrar COP cuando sea ambiguo; separadores es-CO y redondeo coherente con fmt.
- Diferenciar visualmente cifra real, comprometida y estimada. Nunca poner una cifra de ejemplo durante loading como si fuese saldo real.
- Conservar un valor semántico final para lectores de pantalla durante animaciones numéricas; no anunciar cada frame.

## Espaciado y componentes

Malla 4/8: 4, 8, 12, 16, 24, 32. Márgenes 16 en teléfono, 24 en tablet; ancho de lectura de formularios 560 y de contenido 1200. Radios 12 en controles, 16 en tarjetas, 24 solo para hojas. Elevación mínima; no gradientes detrás de texto sin contraste verificado.

| Componente previsto | Responsabilidad | Estados/verificación |
| --- | --- | --- |
| AppScaffold / AdaptiveNavigation | SafeArea, barra/rail, contexto de usuario | Back, teclado, tablet, rutas restauradas |
| MoneyText / MetricCard | Valor + unidad + alcance/período | Cero/negativo/grande, texto 200%, lectura semántica |
| MonthSelector / DayField | Período local y fecha civil | Límites de año, febrero, foco y teclado |
| MoneyField / PercentField | Entrada local clara y validada | No alterar valor al perder foco; preview antes de confirmar |
| FinanceListTile / StatusChip | Origen, monto y estado | Pendiente/pagado/vencido, nombres largos, target 48dp |
| ConfirmImpactSheet | Importe, cuenta, fecha, recurrencia, efectos y confirmar | Cancelar sin mutar; busy; duplicado; error recuperable |
| AsyncContent / Skeleton | Carga, error, vacío, datos con actualización | Skeleton sin semántica monetaria; no spinner infinito |
| ChartPanel / LegendToggle | Filtros, selección y tabla alternativa | Voz/teclado, modo sin movimiento, series ocultas |
| SyncStatusBanner | Confirmación pendiente, guardando, incierto, conflicto | No toast de éxito antes de 2xx válido |
| EmptyState / InlineError | Siguiente paso específico | CTA no destructivo, liveRegion y foco |

Son contratos de componentes, no clases vacías creadas para simular avance. Material 3 aporta botones, menús, inputs, diálogos y navegación; solo personalizar lo necesario.

## Adaptación

| Ancho lógico disponible | Tratamiento previsto |
| --- | --- |
| <600dp | Una columna, NavigationBar inferior, formulario a pantalla completa |
| 600–839dp | NavigationRail, tarjetas flexibles; detalle a pantalla completa si no cabe |
| >=840dp | Rail expandido opcional y lista/detalle cuando haya espacio real |

Breakpoints son decisiones móviles propuestas, no traducción de píxeles CSS. No forzar columnas ni diez pestañas al aumentar ancho. Respetar SafeArea, insets del teclado, orientación horizontal y navegación por teclado en tablet.

Validar 320, 375/390, 600, 768 y 1024dp; portrait/landscape; escala 1.0, 1.3, 2.0. La tabla anual puede desplazarse dentro de su contenedor, nunca provocar overflow de toda la pantalla. Estos tamaños no están aún aprobados para las pantallas futuras.

## Accesibilidad

Objetivos de aceptación: texto normal >=4.5:1 y texto grande/iconos significativos >=3:1; controles táctiles >=48dp; labels y errores asociados; orden de foco, TalkBack/VoiceOver; sin acciones solo al deslizar o al interpretar color. Deshabilitado no equivale a texto negro ni a contraste ilegible.

Alerta y cifra relevante deben seguir siendo legibles con temas claros, brillo elevado y reducción de movimiento. Hacer tests Flutter de contraste/targets cuando se implementen tokens y componentes en Fase 1; la especificación de Fase 0 no afirma haber ejecutado esos tests de colores.

## Movimiento e interacción

Transición de destino 150–200ms, aparición 120–180ms, cambio de gráfico 250–350ms. Propuesta más breve que los 450–500ms de la web para no retrasar lecturas frecuentes. Preferir AnimatedSwitcher/AnimatedSize/TweenAnimationBuilder, sin librería de animación nueva.

MediaQuery.disableAnimations y accessibleNavigation eliminan transformaciones e interpolación numérica; el valor final aparece inmediatamente. Haptics suaves solo después de una confirmación exitosa, nunca como señal de un guardado que todavía no llegó. Skeleton discreto y estático si se reduce movimiento.

No animar un pago antes de confirmarlo, esconder errores con un toast breve ni bloquear el formulario mientras se dibuja un gráfico. Acciones largas muestran progreso y siguen siendo recuperables.
