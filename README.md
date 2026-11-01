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

Para generar el APK en el PC (en PowerShell):

```powershell
flutter build apk --release --build-number (git rev-list --count HEAD)
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

El número de compilación es el número de commits, el mismo que usan las versiones publicadas (ver más abajo). Sin él, el APK sale con un número más bajo que el instalado y Android no deja instalarlo encima.

## Cómo se trabaja

Llevar algo a `main` en GitHub **publica una versión nueva para todo el mundo**. Por eso:

1. Cada funcionalidad o arreglo se hace en **una rama sacada de `main`**.
2. Mientras está en la rama, se prueba en el móvil con un APK compilado en el PC. Eso no se publica.
3. Solo cuando está terminado y funciona, se lleva a `main`. En ese momento se publica.

```powershell
git switch main
git pull
git switch -c nombre-de-la-rama     # trabajar y hacer commits aquí
```

## Publicar una versión nueva

Al subir a `main`, GitHub lo hace todo solo con el action **Publicar** (`.github/workflows/publicar.yml`). No hay que compilar nada en el PC:

1. Pasa los tests. Si alguno falla, no publica nada y se queda la versión anterior.
2. Publica la web en GitHub Pages: <https://grevenilgh.github.io/mtglifecounter2/>. Es la que usan los iPhone.
3. Compila el APK, comprueba que lleva la firma de siempre y lo sube como release: <https://github.com/grevenilgh/mtglifecounter2/releases>. Los Android que ya tienen la app ven un aviso para actualizar.

Para publicar, con la rama terminada y los tests pasando (`flutter analyze` y `flutter test`):

```powershell
git switch main
git pull
git merge nombre-de-la-rama
git push origin main
```

Tarda unos 10 minutos. Para ver cómo va: pestaña **Actions** del repositorio en GitHub. Las releases salen en la columna de la derecha de la página principal del repositorio (**Releases**), y la web en **Deployments** o en **Settings → Pages**.

### Números de versión

- El nombre (por ejemplo `2.0.0`) es el de `version:` en `pubspec.yaml`. Se cambia a mano cuando se quiera.
- El número de compilación lo pone solo el action: es el número de commits de `main`. Siempre sube, y es lo que la app compara para saber si hay una versión nueva.
- En la app se ve en Ajustes → ⓘ: «Versión 2.0.0 (51)».

## La firma del APK

Android solo deja instalar una actualización encima si el APK nuevo está firmado con **la misma clave** que el instalado. La app se firma con la clave de depuración del PC del autor (`%USERPROFILE%\.android\debug.keystore`, alias `androiddebugkey`, contraseña `android`). No vale para Google Play, pero no se va a publicar ahí.

- **En GitHub**, la clave está guardada como el secreto `ANDROID_KEYSTORE_BASE64` del repositorio (Settings → Secrets and variables → Actions), en base64. Antes de publicar, el action comprueba que el certificado del APK tiene la huella de siempre (`e451460b…`). Si no, no publica.
- **Copia de seguridad**: en el PC del autor está en la carpeta `%USERPROFILE%\mtglifecounter-firma` (con un `LEEME.txt`), y debe haber otra copia fuera del PC. **Nunca se sube al repositorio.** Si se pierde la clave, todos los móviles tendrían que desinstalar la app para pasar a una nueva.
- **En un PC nuevo**: copia `firma.keystore` de esa carpeta a `%USERPROFILE%\.android\debug.keystore`. Si no, los APK que compiles ahí llevarán otra firma y no se podrán instalar encima.
- **Si hubiera que volver a poner el secreto**: en PowerShell, `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore")) | Set-Clipboard`, y pegarlo en GitHub como `ANDROID_KEYSTORE_BASE64`.

## Pasar la app a la gente

- **Android**: este enlace descarga siempre el último APK: <https://github.com/grevenilgh/mtglifecounter2/releases/latest/download/MTGLifeCounter.apk>. Se abre el archivo y se pulsa «Instalar». Si lo pide, se da permiso para instalar apps desconocidas, y ante el aviso de Play Protect se pulsa «Más detalles → Instalar de todas formas». Después, las actualizaciones avisan solas: en Ajustes, la ⓘ lleva un punto rojo que parpadea, y se actualiza ahí, en «Actualizar».
- **iPhone**: se abre <https://grevenilgh.github.io/mtglifecounter2/> con Safari y se pulsa Compartir → «Añadir a pantalla de inicio». Se actualiza sola al cerrarla del todo y volver a abrirla.

## Si algo sale mal

- **El action falla en los tests**: no se publica nada. El resumen de la ejecución en Actions dice cuántos fallan; el detalle está en el log del paso «Run flutter test», que solo se ve con la sesión de GitHub iniciada.
- **Falla «Clave de firma» o «Comprobar la firma»**: el secreto falta o no es la clave buena. La web se publica igual, pero el APK no.
- **Se publica algo roto**: se arregla en una rama y se vuelve a llevar a `main`; sale una versión con un número mayor que sustituye a la mala. Si hace falta, la release mala se borra a mano en GitHub (Releases → la release → papelera).
