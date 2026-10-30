# MTG Life Counter

Contador de vidas para partidas 1 contra 1 de Magic: The Gathering, hecho en Flutter.

## Preparar el entorno (Windows)

En una máquina nueva solo hace falta **Git** para clonar el repositorio. Después:

```bat
setup.bat
```

Este script instala lo que falte y se puede ejecutar todas las veces que haga falta:

| Qué | Para qué | Cómo |
|---|---|---|
| Git | Clonar Flutter | `winget install Git.Git` si falta |
| SDK de Flutter (canal stable) | Compilar y ejecutar | Se clona en `C:\src\flutter` y se añade al PATH del usuario |
| Modo de desarrollador de Windows | Flutter crea enlaces simbólicos para los plugins | Abre Ajustes y espera a que lo actives (solo la primera vez) |
| Chrome o Edge | Probar la app en el navegador | Solo comprueba que esté |
| Dependencias del proyecto | `flutter pub get` | Automático |

Para probar en un **móvil Android** o generar el APK, usa `setup-android.bat` (o `setup.bat -Android`). Además instala:

| Qué | Cómo |
|---|---|
| JDK 17 | `winget install Microsoft.OpenJDK.17` |
| SDK de Android (sin Android Studio) | Command-line tools en `%LOCALAPPDATA%\Android\Sdk`, plataforma y build-tools 36, `platform-tools` (adb) en el PATH |
| Licencias del SDK | Te las pide para que las aceptes con `y` |

Con `setup.bat -Emulator` también crea un emulador de Android (`mtg_pixel`). Ocupa unos cuantos GB y necesita la virtualización activada en el PC.

## Probar la app

```bat
run.bat
```

Abre la app en Chrome con una ventana del tamaño de un móvil. Con la app abierta, en la consola:

- `r`: recarga en caliente. Aplica los cambios del código sin perder el estado.
- `R`: reinicio completo.
- `q`: salir.

Para probarla en el móvil:

1. Activa las *Opciones de desarrollador* y la *Depuración USB* en el móvil.
2. Conéctalo por USB y acepta el aviso de confianza que sale en el móvil.
3. Ejecuta `run.bat android`. Si no hay ningún móvil conectado pero existe el emulador, lo arranca.

Para generar el APK: `flutter build apk --release`. Se guarda en `build\app\outputs\flutter-apk\app-release.apk`.
