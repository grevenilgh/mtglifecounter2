# CLAUDE.md

Este archivo da contexto a Claude Code (claude.ai/code) para trabajar en este repositorio.

## Qué es

**MTG Life Counter**: app Flutter de una sola pantalla que cuenta las vidas en partidas 1 contra 1 de Magic: The Gathering. Está pensada para dejar el móvil en la mesa entre los dos jugadores.

- Dos paneles de jugador, 20 vidas iniciales. Los colores y el fondo dependen de la skin elegida en Ajustes.
- Barra central con estos botones: reiniciar partida (con confirmación), girar 180º el panel de arriba, temporizador de ronda, selector de cantidad por toque (1–99, oculto por defecto), Sorteos (abre a pantalla completa la moneda, el dado D20 y el duelo de piedra, papel o tijera, cada uno en su pestaña) y Ajustes.
- La partida se guarda en el dispositivo y sobrevive a cerrar la app (desactivable en Ajustes).
- La pantalla no se apaga (`wakelock_plus`, desactivable en Ajustes) y la app solo funciona en vertical.
- El texto de la interfaz está en español.

## Comandos

```bash
flutter pub get                       # instalar dependencias
flutter run                           # ejecutar en el dispositivo o emulador conectado
flutter analyze                       # lints (flutter_lints 5)
flutter test                          # tests (modelos, casos límite y la pantalla en 14 tamaños)
flutter build apk --release           # APK de Android
dart run flutter_launcher_icons       # regenerar el icono de AlicanteMTG desde assets/images/icono2.png
```

**Tests:** `test/widget_test.dart` (modelos y temporizador), `test/edge_cases_test.dart` (bordes del rango de vidas, datos guardados corruptos, reloj del móvil atrasado, toques rápidos) y `test/layout_test.dart`, que monta la app en 14 pantallas (del Fold cerrado al iPad Pro, más pantalla partida y horizontal) con los cuatro temas, valores extremos (−999, 999, burbuja de +1998, cronómetro de 100 h) y letra del sistema al 200 %, y comprueba que nada se desborda, que el número cabe entero, que la barra no tapa nada y que los toques suman y restan donde toca. Carga Roboto del SDK de Flutter para medir el texto de verdad (las de Google Fonts se sustituyen por las más parecidas). Con `--dart-define=SHOTS=<carpeta>` guarda una captura de cada caso y con `--dart-define=VERBOSE=true` enseña los desbordamientos enteros. Las pantallas con `supported: false` solo se exige que no se rompan.

SDK de Dart: `^3.8.1`.

**Entorno en Windows:** `setup.bat` instala Git y Flutter (en `C:\src\flutter`, añadido al PATH del usuario) y ejecuta `pub get`. `setup-android.bat` añade el JDK 17 y el SDK de Android sin Android Studio. `setup.bat -Emulator` crea además el AVD `mtg_pixel`. La lógica está en `scripts/setup.ps1`.

**Ejecutar:** `run.bat` abre la app en Chrome con una ventana de tamaño móvil. `run.bat android` la lanza en el móvil por USB o en el emulador. La lógica está en `scripts/run.ps1`. Los `.ps1` deben guardarse en UTF-8 **con BOM** y CRLF (ver `.gitattributes`), porque PowerShell 5.1 lee mal los acentos sin BOM.

## Arquitectura

No hay gestor de estado: el estado compartido son `ChangeNotifier` de Flutter que los widgets escuchan con `ListenableBuilder`. `main()` los crea y se los pasa a `MyApp`.

- `lib/game_state.dart`: la partida.
  - `PlayerState`: vida e historial de un jugador. **Agrupación**: `change()` mueve la vida y `commit()` apunta **una** entrada `+N = vida` con lo acumulado. `committedLife` es la vida de la última entrada y `pending` el cambio aún sin apuntar (el que enseña la burbuja). Vida limitada a [-999, 999].
  - `GameState`: los dos jugadores y `rotated`. `reset()` no toca el giro.
  - `GameStorage`: guarda la partida en `shared_preferences` (clave `game`) medio segundo después del último cambio, y al momento con `flush()` cuando la app pasa a segundo plano. Al cargar, un grupo que quedó a medias se apunta.
- `lib/app_settings.dart`: `AppSettings`, las preferencias (skin, skin personalizada, foto de fondo, recordar partida, pantalla encendida, y el aspecto: tema, variante, imagen para toda la pantalla o por jugador, opacidad de la imagen, de la barra central, del historial y del marco del borde antiguo (las de barra e historial, mientras no se toquen, son las de cada tema), foco en el número, mitades que suman y restan (`ZoneMarks`), animaciones, si la barra enseña la cantidad por toque y el temporizador, y el temporizador: modo, minutos, aviso y vibración). Se guardan en cuanto cambian. La foto de fondo va en base64 en las preferencias, así que se pide reducida (1440 px como mucho).
- `lib/skin.dart`: `Skin` (colores y `SkinBackground`) con las skins `alicante`, `fullTapped` y `customDefault`.
- `lib/main.dart`: `MyHomePage` monta la barra central y la pantalla (`CounterLayout`), el diálogo de reinicio, el botón que abre los sorteos (`showDraws`) y `_lifeChangeAmount`, la cantidad que suma o resta cada toque. `_syncSettings` pasa los ajustes al guardado, al temporizador y al icono.
- `lib/round_timer.dart`: `RoundTimer`, el temporizador de ronda: cuenta atrás (50 min por defecto, aviso a falta de 5) o cronómetro. Guarda cuándo arrancó y lo acumulado, no un contador, así que sigue bien con la app cerrada. El modo y la duración se le pasan al crearlo. `lib/timer_view.dart`: el botón de la barra y la hoja con los controles, donde también se cambia entre cuenta atrás y cronómetro sin perder el tiempo que lleva.
- `lib/draws.dart`: los sorteos a pantalla completa. `showDraws` abre `_DrawsScreen`, con una pestaña por sorteo arriba (`DrawKind`, se abre en el dado) y debajo el sorteo elegido, que se lanza solo al entrar. Cada uno pone el resultado una sola vez, sobre los botones (`_DrawLayout`, `_Footer`, que ocupa lo mismo en los tres para que los botones no salten); solo el duelo gira la carta de arriba si el panel de arriba está girado. Los sorteos: moneda con Chaos Orb y Ankh, un disco 3D con canto (`_Coin3D`) que se lanza, vuela, bota dos veces y se queda echada en la mesa; D20 en 3D de resina granate, con una textura jaspeada que se genera al abrirlo (`_D20Painter.loadTexture`) y los números grabados sobre el plano de cada cara, el que sale siempre derecho (`_D20._straighten`); duelo con cartas de Unglued que llenan cada mitad, la ganadora con un aura dorada que late y un trofeo en la esquina, sin rótulo. Traídos de mtgtournament. Imágenes en `assets/images/sorteos/`. La moneda también se lanza con un golpe de muñeca de arriba abajo y el dado agitando el móvil como un cubilete; la fuerza del gesto decide la altura y las vueltas. El dado se pinta sobre toda la pantalla (`_DiceDrawState` mide el hueco del centro con `_slotKey`): al tirarlo entra desde el borde de un jugador, choca con una pared lateral y se para en el centro; en el cubilete la mano lo empuja, la mesa lo frena y rebota en los bordes (`_push`, `_friction`, `_bounce`, `_maxSpeed`). El rótulo del resultado solo cambia cuando el dado o la moneda se paran, para no destripar lo que sale.
- `lib/hand_motion.dart`: el acelerómetro (`sensors_plus`) para esos gestos. `HandMotion` separa la gravedad del movimiento de la mano con un filtro y saca la parte vertical de verdad, tenga el móvil como lo tenga; `FlickDetector` reconoce el golpe de la moneda y `ShakeDetector` el cubilete (empieza con dos sacudidas seguidas y acaba al parar la mano). Solo se enciende en Android e iOS (también desde el navegador del móvil, `HandMotion.supported`); en el resto, o sin sensor, la línea de ayuda bajo los botones no sale y solo queda el botón. Los umbrales están afinados a ojo: si saltan solos al dejar el móvil en la mesa o cuestan de disparar, se tocan ahí.
- `lib/app_icon.dart`: cambia el icono y el nombre de la app según la skin (AlicanteMTG, Full Tapped y «Contador de vidas» para la personalizada). En Android son tres `activity-alias` en el manifiesto y `MainActivity.kt` activa la buena por el canal `mtglifecounter/app_icon` cuando la app pasa a segundo plano. Los iconos de Full Tapped (`ic_ft`) y de la personalizada (`ic_mesa`) se generaron con `System.Drawing`, no con `flutter_launcher_icons`. En la versión de depuración el icono se queda siempre en AlicanteMTG: `flutter run` abre la app por ese alias y, desde Android 14, `adb` no puede volver a encenderlo (`pm enable` da SecurityException). El cambio de icono solo se ve en la release.
- `lib/look.dart`: los tres temas (`AppTheme`: «De siempre», «Borde nuevo» con sus variantes `ModernVariant` Cristal y Tarjetas, y «Old Border»; en Ajustes se eligen como cuatro: De siempre, Cristal, Tarjetas y Old Border) y `Look`, que resuelve lo que cambia de uno a otro (fuente del número, color encima de la imagen, hueco de la barra). También `CardFrame`, el marco de carta del Old Border: siete tiras de marco recortadas de escaneos de cartas de verdad (ver Assets) y la regla que da a cada jugador el que mejor va con su color, sin repetir. El jaspeado (`Mottled`) queda para la barra. Y `withFont`, que pone las fuentes de `google_fonts` (en los tests se desactiva con `useGoogleFonts = false`, porque no hay red, y la fuente se pide solo por su nombre).
- `lib/player_counter.dart`: panel de un jugador. La mitad superior suma y la inferior resta. A la derecha va el historial, que no cuenta como toque (`_historyReserve`). El debounce de 750 ms que llama a `commit()` vive aquí, y también el efecto «golpe» (al perder el número se sacude y el borde se tiñe de rojo; al ganar brilla en verde). Las capas de la zona del número, de abajo arriba: color del jugador, imagen con su opacidad, velo de color, foco, tono de las mitades, número, botones + y −, borde del golpe, burbuja e historial.
- `lib/counter_layout.dart`: `CounterLayout`, la pantalla del contador (fondo, los dos paneles y la barra), que usan la pantalla principal y la miniatura de Ajustes, y `barColorFor`.
- `lib/screen_image.dart`: con «una imagen para toda la pantalla», cada panel pinta solo su trozo de la imagen, alineado con la pantalla y derecho aunque el panel esté girado.
- `lib/center_bar.dart`: la barra central de cada tema. La cantidad por toque (− 1 +) solo sale si está activada en Ajustes; sin ella cada toque cuenta 1.
- `lib/settings_page.dart`: pantalla de Ajustes en dos pestañas, «Diseño» (arriba, fijos, el tema y una miniatura del contador (`_Preview`, la pantalla de verdad en pequeño con una partida de ejemplo); debajo skin y sus colores con `flutter_colorpicker` y foto con `image_picker`, imagen de fondo, paneles, transparencia) y «Partida» (barra central, temporizador, partida). Cada grupo va en una tarjeta `_Group`.
- `lib/number_stepper.dart`: selector de 1 a 99. Una pulsación larga suma o resta 10.

**Comunicación entre widgets:**
- Reinicio: `GameState.reset()` reinicia las vidas y `ValueNotifier<bool> _resetNotifier` avisa al `NumberStepper`, que vuelve a 1.
- Después de cada cambio de vida, `onLifeChanged` vuelve a poner `_lifeChangeAmount` a 1. Es intencionado: la cantidad personalizada sirve para un solo golpe.

## Assets y skins

- Fondos: `assets/images/BackgroundBW.png` (AlicanteMTG) y `assets/images/tap.png` (Full Tapped). Icono: `assets/images/icono2.png`.
- Marcos del Old Border: `assets/images/marcos/*.jpg` son el borde derecho (x 670–705, y 110–915 de los PNG de 745×1040 de Scryfall) de Ancestral Recall, Savannah Lions, Demonic Tutor, Fireball, Regrowth y Time Vault de Alpha, y de Mishra's Workshop de Antiquities (x 682–715). El multicolor (`oro`) sale de Sol'kanar the Swamp King de Legends (x 680–715), con su caja de texto y una tira horizontal (`oro_h.jpg`). `caja_*.jpg` son trozos sin texto de la caja de texto de cartas con poco texto (Counterspell, Disenchant, Dark Ritual, Lightning Bolt, Giant Growth, Mox Pearl y Library of Alexandria de Arabian Nights), puestos de pie: son el fondo del historial de cada marco. Sobre las cinco claras el historial va en tinta oscura y sobre el rojo y la madera del verde (`CardFrame.darkTextBox`) en tinta clara, con la caja oscurecida un 30 %; los colores están medidos para pasar de 4,5:1 de contraste. `verde_h.jpg` es la franja de marco bajo la ilustración de Giant Growth: el verde (y el oro) van en bandas horizontales y, girados, parecían cortados, así que arriba y abajo usan esa tira, repetida en espejo las veces que haga falta. Son imágenes de Wizards of the Coast: valen para una app gratuita de fans (Fan Content Policy), no para venderla. En el Old Border cada panel es una carta tumbada: `_CardBands` pinta la tira en la franja del nombre, los bordes y la línea de tipo, el número va en la ventana de la ilustración y el historial en la caja de texto (medidas `_kFrame`, `_kNameBand`, `_kTypeBand`, `_kTextBox`). Si cambias la regla de `CardFrame.rankFor`, revisa el test `cada jugador lleva un marco de carta distinto`.
- `flutter_01.png` (en la raíz) es una captura y no se usa en el código.
- **Una sola app con skins** elegibles en Ajustes: AlicanteMTG, Full Tapped y Personalizada (colores y fondo propios, incluida una foto). Antes eran dos ramas; sus valores están en [`branding/README.md`](branding/README.md). Si cambias los colores de una skin, actualiza esa tabla y el test `las skins publicadas no cambian por error`.
- El rediseño en curso (animaciones, sorteos, temporizador) se decidió sobre el prototipo https://claude.ai/artifact/QrwGhQdK3j9fqTt5Ed5pdU.

## Problemas conocidos

- Las fuentes de los temas (Barlow Condensed, Outfit, Vollkorn) las baja `google_fonts` la primera vez que se usan; sin internet se ve la del sistema. Para no depender de la red habría que meter los `.ttf` en `assets/`.
- `AutoSizeText` (paquete `auto_size_text` 3.0.0) solo acepta `textScaleFactor`, así que se sigue usando ahí aunque Flutter lo marque como obsoleto.
- Android usa Gradle 8.14.3, AGP 8.13.0 y Kotlin 2.3.20, que son los mínimos de Flutter 3.47. `gradle.properties` lleva `android.newDsl=false` y `android.builtInKotlin=false`, que puso el migrador de Flutter. Flutter avisa de que pronto exigirá AGP 9 y Gradle 9.1: habrá que migrar `build.gradle.kts` al DSL nuevo y quitar esos dos flags.
- La versión release se firma con la clave de depuración. Sirve para instalar el APK a mano, pero no para Google Play.
- El `applicationId` de Android es `mtg.premodern.alicante.lifecounter`, pero el bundle id de iOS sigue siendo `com.example.mtglifecounter`.

## Convenciones

- Comentarios y textos de la interfaz en español.
- Estilo de la UI: fondo con imagen, paneles semitransparentes (`withAlpha`), texto blanco y `AutoSizeText` para que los números ocupen el máximo espacio.
