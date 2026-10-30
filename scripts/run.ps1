<#
.SYNOPSIS
  Arranca MTG Life Counter en modo desarrollo.
.DESCRIPTION
  web      (por defecto) abre la app en Chrome (o Edge) con una ventana del tamaño de un móvil.
  android  la instala en el móvil conectado por USB; si no hay ninguno, arranca el emulador
           creado con setup.bat -Emulator.

  Con la app abierta, en esta consola: r = recarga en caliente, R = reinicio completo, q = salir.
#>
param(
    [ValidateSet('web', 'android')]
    [string]$Target = 'web',
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
$AvdName = 'mtg_pixel'

# Coge el PATH del registro por si setup.bat acaba de instalar Flutter y esta consola es anterior.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'No se encuentra Flutter. Ejecuta antes setup.bat'
}

function Get-AndroidDevice {
    $out = (flutter devices --machine) -join "`n"
    $json = $out.Substring([Math]::Max(0, $out.IndexOf('[')))
    ConvertFrom-Json $json | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1
}

Set-Location $ProjectDir
$flutterArgs = @('run')
if ($Release) { $flutterArgs += '--release' }

if ($Target -eq 'web') {
    $hasChrome = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { Test-Path $_ }
    $browser = if ($hasChrome) { 'chrome' } else { 'edge' }
    $flutterArgs += @('-d', $browser, '--web-browser-flag=--window-size=420,880')
} else {
    $device = Get-AndroidDevice
    if (-not $device) {
        $emulators = (flutter emulators) -join "`n"
        if ($emulators -notmatch $AvdName) {
            throw ("No hay ningún móvil Android conectado. Conéctalo por USB con la depuración USB activada " +
                   "(Ajustes > Opciones de desarrollador) o crea un emulador con: setup.bat -Emulator")
        }
        Write-Host "No hay móvil conectado: arrancando el emulador $AvdName..." -ForegroundColor Cyan
        flutter emulators --launch $AvdName
        for ($i = 0; $i -lt 60 -and -not $device; $i++) {
            Start-Sleep -Seconds 3
            $device = Get-AndroidDevice
        }
        if (-not $device) { throw 'El emulador no ha arrancado en 3 minutos.' }
    }
    Write-Host "Dispositivo: $($device.name)" -ForegroundColor Cyan
    $flutterArgs += @('-d', $device.id)
}

flutter @flutterArgs
