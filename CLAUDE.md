# CLAUDE.md

Este archivo da contexto a Claude Code (claude.ai/code) para trabajar en este repositorio.

## Qué es

**MTG Life Counter**: app Flutter de una sola pantalla que cuenta las vidas en partidas 1 contra 1 de Magic: The Gathering. Está pensada para dejar el móvil en la mesa entre los dos jugadores.

- Dos paneles de jugador, 20 vidas iniciales. Los colores y el fondo dependen de la skin elegida en Ajustes.
- Barra central con estos botones: reiniciar partida (con confirmación), girar 180º el panel de arriba, selector de cantidad por toque (1–99), moneda (Cara/Cruz), dado D20 y Ajustes.
- La partida se guarda en el dispositivo y sobrevive a cerrar la app (desactivable en Ajustes).
- La pantalla no se apaga (`wakelock_plus`, desactivable en Ajustes) y la app solo funciona en vertical.
- El texto de la interfaz está en español.

## Comandos

```bash
flutter pub get                       # instalar dependencias
flutter run                           # ejecutar en el dispositivo o emulador conectado
flutter analyze                       # lints (flutter_lints 5)
flutter test                          # tests (modelos y un test de toques)
flutter build apk --release           # APK de Android
dart run flutter_launcher_icons       # regenerar iconos desde assets/images/icono2.png
```

SDK de Dart: `^3.8.1`.

**Entorno en Windows:** `setup.bat` instala Git y Flutter (en `C:\src\flutter`, añadido al PATH del usuario) y ejecuta `pub get`. `setup-android.bat` añade el JDK 17 y el SDK de Android sin Android Studio. `setup.bat -Emulator` crea además el AVD `mtg_pixel`. La lógica está en `scripts/setup.ps1`.

**Ejecutar:** `run.bat` abre la app en Chrome con una ventana de tamaño móvil. `run.bat android` la lanza en el móvil por USB o en el emulador. La lógica está en `scripts/run.ps1`. Los `.ps1` deben guardarse en UTF-8 **con BOM** y CRLF (ver `.gitattributes`), porque PowerShell 5.1 lee mal los acentos sin BOM.

## Arquitectura

No hay gestor de estado: el estado compartido son `ChangeNotifier` de Flutter que los widgets escuchan con `ListenableBuilder`. `main()` los crea y se los pasa a `MyApp`.

- `lib/game_state.dart`: la partida.
  - `PlayerState`: vida e historial de un jugador. **Agrupación**: `change()` mueve la vida y `commit()` apunta **una** entrada `+N = vida` con lo acumulado. `committedLife` es la vida de la última entrada y `pending` el cambio aún sin apuntar (el que enseña la burbuja). Vida limitada a [-999, 999].
  - `GameState`: los dos jugadores y `rotated`. `reset()` no toca el giro.
  - `GameStorage`: guarda la partida en `shared_preferences` (clave `game`) medio segundo después del último cambio, y al momento con `flush()` cuando la app pasa a segundo plano. Al cargar, un grupo que quedó a medias se apunta.
- `lib/app_settings.dart`: `AppSettings`, las preferencias (skin, skin personalizada, foto de fondo, recordar partida, pantalla encendida). Se guardan en cuanto cambian. La foto de fondo va en base64 en las preferencias, así que se pide reducida (1440 px como mucho).
- `lib/skin.dart`: `Skin` (colores y `SkinBackground`) con las skins `alicante`, `fullTapped` y `customDefault`.
- `lib/main.dart`: `MyHomePage` contiene la disposición (2 `PlayerCounter` + barra), los diálogos (reinicio, moneda, dado) y `_lifeChangeAmount`, la cantidad que suma o resta cada toque.
- `lib/player_counter.dart`: panel de un jugador. La mitad superior suma y la inferior resta. Los últimos `kHistoryWidth` (76) px de la derecha son el historial y no cuentan como toque. El debounce de 750 ms que llama a `commit()` vive aquí.
- `lib/settings_page.dart`: pantalla de Ajustes (skins, colores con `flutter_colorpicker`, foto de fondo con `image_picker`, interruptores).
- `lib/number_stepper.dart`: selector de 1 a 99. Una pulsación larga suma o resta 10.

**Comunicación entre widgets:**
- Reinicio: `GameState.reset()` reinicia las vidas y `ValueNotifier<bool> _resetNotifier` avisa al `NumberStepper`, que vuelve a 1.
- Después de cada cambio de vida, `onLifeChanged` vuelve a poner `_lifeChangeAmount` a 1. Es intencionado: la cantidad personalizada sirve para un solo golpe.

## Assets y skins

- Fondos: `assets/images/BackgroundBW.png` (AlicanteMTG) y `assets/images/tap.png` (Full Tapped). Icono: `assets/images/icono2.png`.
- `flutter_01.png` (en la raíz) es una captura y no se usa en el código.
- **Una sola app con skins** elegibles en Ajustes: AlicanteMTG, Full Tapped y Personalizada (colores y fondo propios, incluida una foto). Antes eran dos ramas; sus valores están en [`branding/README.md`](branding/README.md). Si cambias los colores de una skin, actualiza esa tabla y el test `las skins publicadas no cambian por error`.
- El rediseño en curso (animaciones, sorteos, temporizador) se decidió sobre el prototipo https://claude.ai/artifact/QrwGhQdK3j9fqTt5Ed5pdU.

## Problemas conocidos

- `AutoSizeText` (paquete `auto_size_text` 3.0.0) solo acepta `textScaleFactor`, así que se sigue usando ahí aunque Flutter lo marque como obsoleto.
- Android usa Gradle 8.14.3, AGP 8.13.0 y Kotlin 2.3.20, que son los mínimos de Flutter 3.47. `gradle.properties` lleva `android.newDsl=false` y `android.builtInKotlin=false`, que puso el migrador de Flutter. Flutter avisa de que pronto exigirá AGP 9 y Gradle 9.1: habrá que migrar `build.gradle.kts` al DSL nuevo y quitar esos dos flags.
- La versión release se firma con la clave de depuración. Sirve para instalar el APK a mano, pero no para Google Play.
- El `applicationId` de Android es `mtg.premodern.alicante.lifecounter`, pero el bundle id de iOS sigue siendo `com.example.mtglifecounter`.

## Convenciones

- Comentarios y textos de la interfaz en español.
- Estilo de la UI: fondo con imagen, paneles semitransparentes (`withAlpha`), texto blanco y `AutoSizeText` para que los números ocupen el máximo espacio.
