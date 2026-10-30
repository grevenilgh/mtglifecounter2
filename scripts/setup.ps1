<#
.SYNOPSIS
  Prepara una máquina Windows para desarrollar MTG Life Counter.
.DESCRIPTION
  Instala lo que falte (Git y el SDK de Flutter), añade Flutter al PATH del usuario
  y descarga las dependencias del proyecto. Con eso ya se puede probar en Chrome.

  -Android  instala además el JDK 17 y el SDK de Android (sin Android Studio) para
            probar en un móvil conectado por USB y generar el APK.
  -Emulator igual que -Android y además crea un emulador de Android.

  Se puede ejecutar todas las veces que haga falta: lo que ya está instalado se salta.
#>
param(
    [switch]$Android,
    [switch]$Emulator,
    [string]$FlutterDir = 'C:\src\flutter',
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk"
)

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
if ($Emulator) { $Android = $true }

# Lo que se instala de Android. El resto (NDK, otras build-tools) lo descarga Gradle al compilar.
$AndroidApi = 36
$CmdlineToolsUrl = 'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip'
$AvdName = 'mtg_pixel'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    AVISO: $msg" -ForegroundColor Yellow }

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Add-UserPath($dir) {
    $parts = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ })
    if ($parts -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $dir) -join ';'), 'User')
        Write-Ok "Añadido al PATH del usuario: $dir"
    }
    Update-SessionPath
}

# Ejecuta un comando externo y corta el script si devuelve error.
function Invoke-Checked([string]$what, [scriptblock]$block) {
    & $block
    if ($LASTEXITCODE -ne 0) { throw "$what ha fallado (código $LASTEXITCODE)." }
}

function Install-WithWinget($id, $name) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "No está winget. Instala '$name' a mano o instala 'App Installer' desde la Microsoft Store."
    }
    Write-Host "    Instalando $name con winget..."
    Invoke-Checked "Instalar $name" { winget install --id $id --exact --source winget }
    Update-SessionPath
}

# ---------------------------------------------------------------- Git
Write-Step 'Git'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Install-WithWinget 'Git.Git' 'Git'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $env:Path += ";$env:ProgramFiles\Git\cmd" }
}
Write-Ok (git --version)

# ---------------------------------------------------------------- Flutter
Write-Step 'SDK de Flutter'
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $FlutterDir = Split-Path -Parent (Split-Path -Parent $flutterCmd.Source)
    Write-Ok "Ya estaba instalado en $FlutterDir"
} else {
    if (-not (Test-Path "$FlutterDir\bin\flutter.bat")) {
        if ($FlutterDir -match ' ') { throw "Flutter no funciona en rutas con espacios: $FlutterDir" }
        Write-Host "    Clonando Flutter (canal stable) en $FlutterDir. Tarda unos minutos..."
        New-Item -ItemType Directory -Force (Split-Path -Parent $FlutterDir) | Out-Null
        Invoke-Checked 'Clonar Flutter' { git clone --branch stable https://github.com/flutter/flutter.git $FlutterDir }
    }
    Add-UserPath "$FlutterDir\bin"
}
# La primera ejecución descarga el SDK de Dart y las herramientas.
Invoke-Checked 'flutter --version' { flutter --version }

# ---------------------------------------------------------------- Modo de desarrollador
# Flutter crea enlaces simbólicos para los plugins y Windows solo lo permite con este modo.
Write-Step 'Modo de desarrollador de Windows'
$devModeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$isDevMode = { (Get-ItemProperty $devModeKey -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1 }
if (-not (& $isDevMode)) {
    Write-Warn 'Flutter lo necesita. Se abre Ajustes: activa "Modo de desarrollador" y acepta el aviso.'
    Start-Process 'ms-settings:developers'
    while (-not (& $isDevMode)) { Start-Sleep -Seconds 2 }
}
Write-Ok 'Activado'

# ---------------------------------------------------------------- Navegador
Write-Step 'Navegador para probar en web'
$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($chrome) { Write-Ok "Chrome en $chrome" }
else { Write-Warn 'No está Chrome; run.bat usará Edge. Para instalarlo: winget install Google.Chrome' }

# ---------------------------------------------------------------- Android
if ($Android) {
    Write-Step 'JDK 17 (para compilar Android)'
    $findJdk = { Get-ChildItem "$env:ProgramFiles\Microsoft" -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue |
                 Sort-Object Name | Select-Object -Last 1 }
    $jdk = & $findJdk
    if (-not $jdk) { Install-WithWinget 'Microsoft.OpenJDK.17' 'OpenJDK 17'; $jdk = & $findJdk }
    if (-not $jdk) { throw 'No se encuentra el JDK 17 en Program Files\Microsoft.' }
    $env:JAVA_HOME = $jdk.FullName
    Invoke-Checked 'flutter config --jdk-dir' { flutter config --jdk-dir $jdk.FullName }
    Write-Ok $jdk.FullName

    Write-Step 'SDK de Android'
    $sdkmanager = "$AndroidSdk\cmdline-tools\latest\bin\sdkmanager.bat"
    if (-not (Test-Path $sdkmanager)) {
        $tmp = Join-Path $env:TEMP 'mtg-android-cmdline-tools'
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory $tmp | Out-Null
        Write-Host '    Descargando Android command-line tools...'
        $ProgressPreference = 'SilentlyContinue'  # sin barra de progreso Invoke-WebRequest va mucho más rápido
        Invoke-WebRequest $CmdlineToolsUrl -OutFile "$tmp\tools.zip" -UseBasicParsing
        Expand-Archive "$tmp\tools.zip" "$tmp\x"
        New-Item -ItemType Directory -Force "$AndroidSdk\cmdline-tools" | Out-Null
        Move-Item "$tmp\x\cmdline-tools" "$AndroidSdk\cmdline-tools\latest"
        Remove-Item $tmp -Recurse -Force
    }
    $env:ANDROID_HOME = $AndroidSdk
    [Environment]::SetEnvironmentVariable('ANDROID_HOME', $AndroidSdk, 'User')
    Add-UserPath "$AndroidSdk\platform-tools"
    Invoke-Checked 'flutter config --android-sdk' { flutter config --android-sdk $AndroidSdk }

    Write-Step 'Licencias del SDK de Android: léelas y responde "y" para aceptarlas'
    Invoke-Checked 'Aceptar licencias' { flutter doctor --android-licenses }

    Write-Step 'Paquetes del SDK de Android'
    $packages = @('platform-tools', "platforms;android-$AndroidApi", "build-tools;$AndroidApi.0.0")
    if ($Emulator) { $packages += @('emulator', "system-images;android-$AndroidApi;google_apis;x86_64") }
    Invoke-Checked 'sdkmanager' { & $sdkmanager @packages }

    if ($Emulator) {
        Write-Step "Emulador '$AvdName'"
        $avdmanager = "$AndroidSdk\cmdline-tools\latest\bin\avdmanager.bat"
        $existing = & $avdmanager list avd -c
        if ($existing -contains $AvdName) { Write-Ok 'Ya existía' }
        else {
            # avdmanager pregunta si se quiere un perfil de hardware a medida: se le contesta que no.
            Invoke-Checked 'Crear emulador' {
                'no' | & $avdmanager create avd -n $AvdName -k "system-images;android-$AndroidApi;google_apis;x86_64" -d pixel_7
            }
            Write-Ok "Creado. Se arranca solo con: run.bat android"
        }
    }
}

# ---------------------------------------------------------------- Proyecto
Write-Step 'Dependencias del proyecto (flutter pub get)'
Push-Location $ProjectDir
try { Invoke-Checked 'flutter pub get' { flutter pub get } }
finally { Pop-Location }

Write-Step 'Resumen (flutter doctor)'
flutter doctor

Write-Host "`nListo. Para arrancar la app: run.bat (Chrome) o run.bat android (móvil)." -ForegroundColor Green
Write-Host 'Si abres otra terminal, ciérrala y ábrela de nuevo para que coja el PATH nuevo.'
