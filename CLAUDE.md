# CLAUDE.md

Este archivo da contexto a Claude Code (claude.ai/code) para trabajar en este repositorio.

## Qué es

**MTG Life Counter**: app Flutter de una sola pantalla que cuenta las vidas en partidas 1 contra 1 de Magic: The Gathering. Está pensada para dejar el móvil en la mesa entre los dos jugadores.

- Dos paneles de jugador (morado arriba, verde abajo), 20 vidas iniciales.
- Barra central con estos botones: reiniciar partida (con confirmación), girar 180º el panel de arriba, selector de cantidad por toque (1–99), moneda (Cara/Cruz) y dado D20.
- La pantalla no se apaga (`wakelock_plus`) y la app solo funciona en vertical.
- El texto de la interfaz está en español.

## Comandos

```bash
flutter pub get                       # instalar dependencias
flutter run                           # ejecutar en el dispositivo o emulador conectado
flutter analyze                       # lints (flutter_lints 5)
flutter test                          # tests (ver "Problemas conocidos")
flutter build apk --release           # APK de Android
dart run flutter_launcher_icons       # regenerar iconos desde assets/images/icono2.png
```

SDK de Dart: `^3.8.1`. Flutter no está en el PATH de esta máquina, así que hay que instalarlo o añadirlo antes de ejecutar estos comandos.

## Arquitectura

Solo hay 3 archivos en `lib/` y el estado vive en `StatefulWidget`s. No se usa ningún gestor de estado ni persistencia: al cerrar la app se pierde la partida.

- `lib/main.dart`: `MyHomePage` contiene la disposición (2 `PlayerCounter` + barra), los diálogos (reinicio, moneda, dado) y `_lifeChangeAmount`, la cantidad que suma o resta cada toque.
- `lib/player_counter.dart`: panel de un jugador.
  - **Zona de toque**: la mitad superior suma y la inferior resta. Los últimos 78 px de la derecha están reservados para el historial y no cuentan como toque.
  - **Agrupación con debounce**: los toques seguidos se acumulan y, 750 ms después del último, se añade **una** entrada `+N = vida` al historial (`_finalizeTap`). `_lifeOld` es la vida en la última entrada del historial. Mientras `_life != _lifeOld` se muestra la burbuja con el cambio pendiente.
  - Vida limitada a [-999, 999].
- `lib/number_stepper.dart`: selector de 1 a 99. Una pulsación larga suma o resta 10.

**Comunicación entre widgets:**
- Reinicio: `ValueNotifier<bool> _resetNotifier`. Se invierte su valor y los `PlayerCounter` y el `NumberStepper` se suscriben con `addListener`. Si añades un widget que deba reiniciarse, suscríbelo así y quita el listener en `dispose`.
- Después de cada cambio de vida, `onLifeChanged` vuelve a poner `_lifeChangeAmount` a 1. Es intencionado: la cantidad personalizada sirve para un solo golpe.

## Assets y skins

- Fondo: `assets/images/BackgroundBW.png`. Icono: `assets/images/icono2.png`.
- `flutter_01.png` (en la raíz) es una captura y no se usa en el código.
- La app tiene dos skins: **AlicanteMTG** (`main`) y **Full Tapped** (rama `fulltapped` / tag `skin-fulltapped`). Sus colores, fondos, iconos e ids están en [`branding/README.md`](branding/README.md) y sus imágenes en `branding/`. Si cambias colores, fondo, icono o id de la app, actualiza esa tabla. `branding/` está fuera de `assets/` a propósito para que no entre en el APK.

## Problemas conocidos

- `test/widget_test.dart` es la plantilla del contador de Flutter y **falla** (busca el texto `'0'` y el icono `Icons.add`). Hay que reescribirlo antes de fiarse de `flutter test`.
- `_rollDice` usa `nextInt(19) + 1`, que da de 1 a 19: **nunca sale 20**. Debería ser `nextInt(20) + 1`.
- El botón de girar tiene el tooltip `'Reiniciar vidas'` copiado del botón de reinicio.
- Se usa `withOpacity` y `textScaleFactor`, que están obsoletos en Flutter 3.27+. Los sustitutos son `withValues(alpha:)` y `textScaler: TextScaler.noScaling`.
- El `applicationId` de Android es `mtg.premodern.alicante.lifecounter`, pero el bundle id de iOS sigue siendo `com.example.mtglifecounter`.

## Convenciones

- Comentarios y textos de la interfaz en español.
- Estilo de la UI: fondo con imagen, paneles semitransparentes (`withAlpha`), texto blanco y `AutoSizeText` para que los números ocupen el máximo espacio.
