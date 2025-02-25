# Ejecutar como Administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
    exit
}

Write-Host "🔹 Deteniendo servicios de SQL Server..." -ForegroundColor Yellow
$services = @("MSSQL$SQLEXPRESS", "MSSQLSERVER", "SQLAgent$SQLEXPRESS", "SQLWriter", "SQLBrowser")

foreach ($service in $services) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        sc.exe delete $service
        Write-Host "✔ Servicio eliminado: $service"
    }
}

Write-Host "🔹 Desinstalando SQL Server con Get-Package..." -ForegroundColor Yellow
$packages = Get-Package | Where-Object { $_.Name -like "*SQL Server*" }

foreach ($package in $packages) {
    Uninstall-Package -Name $package.Name -Force -ErrorAction SilentlyContinue
    Write-Host "✔ Desinstalado: $($package.Name)"
}

Write-Host "🔹 Desinstalando SQL Server con Winget..." -ForegroundColor Yellow
$wingetPackages = winget list | Select-String "SQL Server"

foreach ($wingetPackage in $wingetPackages) {
    $packageName = $wingetPackage -split '\s{2,}' | Select-Object -First 1
    Start-Process "winget" -ArgumentList "uninstall --silent --accept-source-agreements --accept-package-agreements $packageName" -NoNewWindow -Wait
    Write-Host "✔ Desinstalado con Winget: $packageName"
}

Write-Host "🔹 Eliminando archivos de SQL Server..." -ForegroundColor Yellow
$folders = @(
    "C:\Program Files\Microsoft SQL Server",
    "C:\Program Files (x86)\Microsoft SQL Server",
    "C:\ProgramData\Microsoft\Microsoft SQL Server",
    "$env:USERPROFILE\AppData\Local\Microsoft\Microsoft SQL Server"
)

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✔ Carpeta eliminada: $folder"
    }
}

Write-Host "🔹 Eliminando claves de registro de SQL Server..." -ForegroundColor Yellow
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server",
    "HKLM:\SOFTWARE\Microsoft\MSSQLServer",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server",
    "HKLM:\SYSTEM\CurrentControlSet\Services\MSSQL$SQLEXPRESS",
    "HKLM:\SYSTEM\CurrentControlSet\Services\MSSQLSERVER",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SQLAgent$SQLEXPRESS",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SQLWriter",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SQLBrowser"
)

foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✔ Registro eliminado: $regPath"
    }
}

Write-Host "🔹 Proceso completado. Reinicie su equipo para finalizar la limpieza." -ForegroundColor Green
