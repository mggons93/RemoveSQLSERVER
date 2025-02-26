# Definir la ruta del disco virtual
$VHDPath = "C:\MSSQL\MSSQL2019.vhdx"

# Crear la carpeta si no existe
if (!(Test-Path "C:\MSSQL")) {
    New-Item -Path "C:\MSSQL" -ItemType Directory | Out-Null
}

# Verificar si el VHDX ya existe
if (!(Test-Path $VHDPath)) {
    Write-Host "Creando disco virtual de 8GB en: $VHDPath..."

    # Crear un archivo de script para diskpart
    $diskpartScript = @"
create vdisk file="$VHDPath" maximum=30720 type=expandable
select vdisk file="$VHDPath"
attach vdisk
convert gpt
create partition primary
format fs=ntfs quick label="MSSQL_VHD"
assign letter=D
exit
"@
    $scriptPath = "C:\MSSQL\CreateVHD.txt"
    $diskpartScript | Out-File $scriptPath -Encoding ASCII

    # Ejecutar diskpart
    Start-Process -FilePath "diskpart.exe" -ArgumentList "/s $scriptPath" -Wait -NoNewWindow

    # Verificar si el VHDX se creó correctamente
    if (Test-Path $VHDPath) {
        Write-Host "✅ Disco virtual creado y montado como D:."
    } else {
        Write-Host "❌ Error: No se pudo crear el disco virtual."
        exit
    }
} else {
    Write-Host "El disco virtual ya existe en: $VHDPath"
    
    # Intentar montarlo si ya existe
    $mountScript = @"
select vdisk file="$VHDPath"
attach vdisk
assign letter=D
exit
"@
    $mountPath = "C:\MSSQL\MountVHD.txt"
    $mountScript | Out-File $mountPath -Encoding ASCII
    Start-Process -FilePath "diskpart.exe" -ArgumentList "/s $mountPath" -Wait -NoNewWindow
    Write-Host "✅ Disco virtual montado como D:."
}

# Guardar la ruta del VHDX en un archivo de configuración
$ConfigFile = "C:\MSSQL\VHD_Config.txt"
$VHDPath | Out-File $ConfigFile
Write-Host "⚙️ Configuración guardada en: $ConfigFile"

# Crear script de auto-montaje
$MountScript = "C:\MSSQL\Mount-VHD.ps1"
@"
`$VHDPath = Get-Content '$ConfigFile'
if (Test-Path `$VHDPath) {
    `$Disk = Mount-DiskImage -ImagePath `$VHDPath -PassThru
    `$DiskNumber = (`$Disk | Get-Disk).Number
    `$Partition = Get-Partition -DiskNumber `$DiskNumber
    if (`$Partition.DriveLetter -ne 'D') {
        Set-Partition -PartitionNumber `$Partition.PartitionNumber -DiskNumber `$DiskNumber -NewDriveLetter 'D'
    }
} else {
    Write-Host 'El archivo VHD no existe: `$VHDPath'
}
"@ | Out-File $MountScript -Encoding UTF8

# Registrar tarea programada para el montaje en cada inicio
$TaskName = "Montar VHD MSSQL en D al inicio"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$MountScript`""
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Eliminar tarea si ya existe
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Description "Monta el VHD en la unidad D: al iniciar Windows" | Out-Null

Write-Host "✅ El disco virtual se montará automáticamente en D: al iniciar Windows."
