# Skins de la app

> **Desde octubre de 2026 hay una sola app** y las skins se eligen en Ajustes. Sus colores viven en `lib/skin.dart` y el fondo de Full Tapped se ha copiado a `assets/images/tap.png`. La tabla de abajo es el registro de cómo se publicaron las dos apps por separado. Nombre, icono e id ya no cambian por skin: la app sigue siendo `AlicanteMTG` / `mtg.premodern.alicante.lifecounter`.

La app se ha publicado con dos "skins". Cambian el fondo, los colores de los paneles, el icono, el nombre y el id de la app; la lógica es la misma. Este archivo guarda los valores de cada una para poder recuperarlas aunque se modifique el código.

| | **AlicanteMTG** (rama `main`) | **Full Tapped** (rama `fulltapped`, tag `skin-fulltapped`) |
|---|---|---|
| Nombre (Android `android:label`) | `AlicanteMTG` | `Full Tapped` |
| `applicationId` Android | `mtg.premodern.alicante.lifecounter` | `mtg.premodern.fulltapped.lifecounter` |
| Imagen de fondo | `assets/images/BackgroundBW.png` | `tap.png` → [`branding/fulltapped/tap.png`](fulltapped/tap.png) |
| Color jugador de arriba | `Colors.deepPurple.withAlpha(225)` | `Color(0xFF9B1D20).withAlpha(225)` (granate) |
| Color jugador de abajo | `Colors.green.withAlpha(225)` | `Color(0xFF3D2B3D).withAlpha(225)` (berenjena) |
| Barra central | `Colors.grey[800]!.withAlpha(248)` | igual |
| Fondo del `Scaffold` | sin definir | `Colors.black` |
| Icono (`flutter_launcher_icons`) | `assets/images/icono2.png` | `logo_full_tapped2.jpg` → [`branding/fulltapped/logo_full_tapped2.jpg`](fulltapped/logo_full_tapped2.jpg) |
| Modo de las barras del sistema | `SystemUiMode.manual` con todas las barras visibles | `SystemUiMode.edgeToEdge` + `AnnotatedRegion` con barra de estado negra |
| Barra de navegación | negra, iconos claros | blanca, iconos oscuros |

El bundle id de iOS sigue siendo `com.example.mtglifecounter` en las dos skins.

## Archivos

- `assets/images/` (en `main`): recursos de AlicanteMTG. `BackgroundColor.jpg`, `IconoBW.png`, `icono.png` e `iconoColor.jpg` son variantes anteriores que no usa el código.
- `branding/fulltapped/`: recursos de Full Tapped sacados de la rama. Están fuera de `assets/` para que no entren en el APK de la skin AlicanteMTG. `logo_full_tapped.jpg` es una versión anterior del logo.

## Recuperar la skin Full Tapped

1. Copia `branding/fulltapped/tap.png` y `logo_full_tapped2.jpg` a `assets/images/`.
2. En `lib/main.dart` cambia el `AssetImage` del fondo y los dos `color:` de los `PlayerCounter` por los valores de la tabla.
3. Cambia `applicationId` en `android/app/build.gradle.kts`, `android:label` en `AndroidManifest.xml` y `image_path` / `adaptive_icon_foreground` en `pubspec.yaml`.
4. Ejecuta `dart run flutter_launcher_icons` para regenerar los iconos de Android e iOS.

También puedes consultar el código completo de la skin con `git show skin-fulltapped:lib/main.dart`.

> Si vas a mantener las dos skins, lo razonable es convertirlas en *flavors* de Flutter (o una clase `AppSkin` con estos valores) en lugar de tener dos ramas que divergen.

## Old School (desde octubre de 2026)

Skin para [Old School MTG Channel](https://www.oldschoolmtgchannel.com/), nacida ya dentro de la app única (nunca fue una rama). Los colores salen de su web:

| | **Old School** (`Skin.oldSchool`, id `oldschool`) |
|---|---|
| Nombre en el lanzador (Android) | `Old School MTG` (`AliasOldSchool`) |
| Imagen de fondo | `assets/images/oldschool.jpg`: su logo con la gorra y el micro sobre blanco, a 1000 px. Con una imagen para toda la pantalla, `oldschool_pantalla.jpg`: el mismo con blanco arriba y abajo |
| Color jugador de arriba | `Color(0xFF006AA9)`: el azul de la cabecera de la web |
| Color jugador de abajo | `Color(0xFF484848)`: el gris carbón del logo |
| Barra central | `Color(0xFF1F2020)`: el casi negro de los textos de la web |
| Icono | `ic_osm`: el logo entero sobre el azul `#006AA9` (fondo del icono adaptativo `ic_osm_background`) |
