# Script para ejecutar generate_manifest.py y mantener la ventana abierta
Write-Host "=== Ejecutando updateBackblaze_generate_manifest.py ===" -ForegroundColor Cyan

# Cambiar al directorio del proyecto
Set-Location "D:\GitHub\LauncherL2argento"

# Verificar si el archivo Python existe
if (-not (Test-Path "updateBackblaze_generate_manifest.py")) {
    Write-Host "ERROR: No se encuentra updateBackblaze_generate_manifest.py" -ForegroundColor Red
    Write-Host "Presiona cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Ejecutar el script Python CON PY en lugar de python
Write-Host "Ejecutando updateBackblaze_generate_manifest.py..." -ForegroundColor Yellow
py updateBackblaze_generate_manifest.py

# Verificar el resultado
if ($LASTEXITCODE -eq 0) {
    Write-Host "SCRIPT EJECUTADO EXITOSAMENTE" -ForegroundColor Green
    
    # Verificar si se creó el archivo update.json
    if (Test-Path "update.json") {
        $fileInfo = Get-Item "update.json"
        $fileSize = "{0:N2} KB" -f ($fileInfo.Length / 1KB)
        Write-Host "Archivo update.json creado - Tamaño: $fileSize" -ForegroundColor Green
        
        # Mostrar información básica del manifest
        try {
            $manifest = Get-Content "update.json" | ConvertFrom-Json
            Write-Host "Archivos en el manifest: $($manifest.files.Count)" -ForegroundColor Cyan
            Write-Host "Version: $($manifest.version)" -ForegroundColor Cyan
        }
        catch {
            Write-Host "No se pudo leer el archivo update.json" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "No se encontro update.json despues de la ejecucion" -ForegroundColor Red
    }
}
else {
    Write-Host "Error al ejecutar el script Python (Codigo: $LASTEXITCODE)" -ForegroundColor Red
}

# Mantener la ventana abierta
Write-Host "`nPresiona cualquier tecla para cerrar esta ventana..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")