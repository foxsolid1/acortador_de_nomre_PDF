# Unidad que contiene los archivos
$driveLetter = "C:"
$sourceFolderPath = "C:\Users\gtrejo\Downloads\ANEXOS PRUEBA\Anexos"
$destinationFolderPath = "C:\Users\gtrejo\Downloads\ANEXOS PRUEBA\cortos"

# Verificar si BitLocker está habilitado en la unidad
$bitlockerStatus = Get-BitLockerVolume -MountPoint $driveLetter

if ($bitlockerStatus.ProtectionStatus -eq "On") {
    Write-Host "La unidad $driveLetter está protegida por BitLocker."

    # Verificar si la unidad está desbloqueada
    if ($bitlockerStatus.LockStatus -eq "Locked") {
        Write-Host "La unidad está bloqueada. Intentando desbloquear..."

        # Intentar desbloquear la unidad. Debes proporcionar la clave de recuperación o contraseña.
        $password = Read-Host -AsSecureString "Introduce la contraseña de BitLocker"
        Unlock-BitLocker -MountPoint $driveLetter -Password $password

        # Verificar si se desbloqueó exitosamente
        $bitlockerStatus = Get-BitLockerVolume -MountPoint $driveLetter
        if ($bitlockerStatus.LockStatus -eq "Unlocked") {
            Write-Host "Unidad desbloqueada exitosamente."
        } else {
            Write-Host "Error: No se pudo desbloquear la unidad."
            exit
        }
    } else {
        Write-Host "La unidad ya está desbloqueada."
    }
} else {
    Write-Host "La unidad no está protegida por BitLocker."
}

# A partir de aquí, puedes ejecutar tu script de copia
# ...

# Crear la carpeta de destino si no existe
if (-not (Test-Path $destinationFolderPath)) {
    New-Item -Path $destinationFolderPath -ItemType Directory
}

# Obtener todos los archivos del directorio original y sus subdirectorios
$files = Get-ChildItem -Path $sourceFolderPath -Recurse

foreach ($file in $files) {
    $originalName = $file.BaseName
    $extension = $file.Extension

    # Crear estructura de carpetas en la carpeta de destino
    $relativePath = $file.FullName.Substring($sourceFolderPath.Length)
    $relativeFolder = Split-Path -Path $relativePath -Parent
    $newDestinationFolder = Join-Path $destinationFolderPath $relativeFolder

    if (-not (Test-Path $newDestinationFolder)) {
        New-Item -Path $newDestinationFolder -ItemType Directory -Force
    }

    # Manejo de rutas largas
    $longSourcePath = "\\?\$($file.FullName)"

    # Si el archivo es PDF y tiene un nombre largo, acortarlo
    if ($extension -ieq ".pdf") {
        if ($originalName.Length -gt 70) {
            # Acortar el nombre a los primeros 50 caracteres
            $newName = $originalName.Substring(0, 70) + $extension
        } else {
            # Mantener el nombre original
            $newName = $originalName + $extension
        }
    } else {
        # Para otros archivos, mantener el nombre completo
        $newName = $file.Name
    }

    $longDestinationPath = "\\?\$newDestinationFolder\$newName"

    # Verificar si ya existe un archivo con el mismo nombre en la carpeta de destino
    $duplicateCount = 1
    while (Test-Path $longDestinationPath) {
        # Si existe un duplicado, agregar un sufijo numérico antes de la extensión
        $newNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($newName)
        $newName = "$newNameWithoutExtension($duplicateCount)$extension"
        $longDestinationPath = "\\?\$newDestinationFolder\$newName"
        $duplicateCount++
    }

    # Copiar el archivo al nuevo directorio
    if (Test-Path $longSourcePath) {
        try {
            Copy-Item -Path $longSourcePath -Destination $longDestinationPath
            Write-Host "Archivo copiado: $($file.FullName) a $longDestinationPath"
        } catch {
            Write-Host "Error copiando $($file.FullName): $_"
        }
    } else {
        Write-Host "Advertencia: No se encuentra el archivo $($file.FullName)"
    }
}
