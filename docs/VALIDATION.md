# Validación de esta base

Fecha: 3 de noviembre de 2026 (America/Bogota).
Entorno: Windows, Flutter 3.47.9 stable (`c197ca5199`), Dart 3.13.7.

| Comando | Resultado real |
| --- | --- |
| `flutter create --platforms=android,ios --org com.avera --project-name finanzas_movil --no-pub .` | Ejecutado; proyectos generados con el SDK oficial. |
| `flutter pub get` | Correcto; dependencias resueltas y lock generado. |
| `flutter analyze --no-pub` | Correcto: `No issues found!`. |
| `flutter test --no-pub --reporter expanded` | **26 pruebas pasaron**. |
| `flutter pub outdated --no-dev-dependencies` | Ejecutado; actualizaciones mayores pendientes documentadas en README. |
| Android debug | Correcto en CI Linux: flutter build apk --debug --no-pub. Intento Windows detenido al no avanzar la descarga del NDK 28.2.13676358; sin APK local. |
| iOS | Correcto en CI macOS: flutter build ios --simulator --debug --no-codesign --no-pub. Se generó build/ios/iphonesimulator/Runner.app. No ejecutado localmente en Windows. |

Cobertura funcional: saldo con crédito, valores negativos/fracciones y cuenta vacía; rechazo de formato inválido; login correcto/401/429; cookies inválidas y vencidas; fallo al guardar sesión; restauración; borrado por 401; timeout/500; logout offline; URL HTTPS y redirecciones; aislamiento por API; limpieza de la cookie anterior; pantallas reales con login, restauración, cierre, sesión vencida y teclado en pantalla pequeña.

Todas las respuestas HTTP de las pruebas son sintéticas y se interceptan antes de cualquier red. Las cadenas usadas como cookie se generan con una firma ficticia: no son tokens válidos de ningún servidor.

El SDK emitió avisos de `Unblock-File` sobre `Zone.Identifier` porque el volumen D: no soporta ese atributo. No impidieron generar proyectos, resolver paquetes, analizar ni ejecutar tests. `flutter doctor` reporta cmdline-tools Android faltantes y estado de licencias desconocido; no se afirmó que el toolchain completo estuviera validado.

No se probó login contra producción, no se accedió a PostgreSQL y no se realizaron llamadas reales a `/api/state`. Backend revisado únicamente en lectura. Pendientes: ejecución física Android/iOS, persistencia segura tras reinicio/desinstalación, comportamiento del Keychain con dispositivo bloqueado, firma/distribución y validación TLS con la URL real.

CI con código y workflow del commit 75835d57785f96626bdad57c07e4795548fe01f4: [ejecución verificada](https://github.com/Avera123/finanzas-movil/actions/runs/41765936931). Dependencias, formato, análisis y tests correctos también en Linux. Ambas compilaciones usan https://api.example.invalid como configuración pública, sin autenticación ni peticiones a producción. Los commits posteriores de documentación no alteran el código probado.
