# git-push.ps1 - Script para subir cambios con LFS de forma segura
# Uso: .\git-push.ps1 "Mensaje del commit"

param(
    [Parameter(Mandatory=$true)]
    [string]$CommitMessage
)

# Configuracion de colores
$ErrorColor = "Red"
$SuccessColor = "Green" 
$WarningColor = "Yellow"
$InfoColor = "Cyan"
$StepColor = "Magenta"

# Funciones de escritura sin caracteres especiales
function Write-Step { 
    param($message) 
    Write-Host "`n[PASO] $message" -ForegroundColor $StepColor 
}

function Write-Success { 
    param($message) 
    Write-Host "[EXITO] $message" -ForegroundColor $SuccessColor 
}

function Write-ErrorMsg { 
    param($message) 
    Write-Host "[ERROR] $message" -ForegroundColor $ErrorColor 
}

function Write-Info { 
    param($message) 
    Write-Host "[INFO] $message" -ForegroundColor $InfoColor 
}

function Write-Warning { 
    param($message) 
    Write-Host "[ADVERTENCIA] $message" -ForegroundColor $WarningColor 
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Pause-Script {
    Write-Host "`n" -NoNewline
    Write-Host "Presiona cualquier tecla para continuar..." -ForegroundColor $InfoColor
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

try {
    # Verificar que Git esta instalado
    Write-Step "Verificando dependencias..."
    if (-not (Test-Command "git")) {
        Write-ErrorMsg "Git no esta instalado o no esta en el PATH"
        Pause-Script
        exit 1
    }

    if (-not (Test-Command "git-lfs")) {
        Write-ErrorMsg "Git LFS no esta instalado. Instalalo desde: https://git-lfs.github.com/"
        Pause-Script
        exit 1
    }

    Write-Success "Dependencias verificadas correctamente"

    # Paso 1: Configurar LFS para tipos de archivos grandes comunes
    Write-Step "Configurando Git LFS para archivos grandes..."
    $lfsPatterns = @("*.ukx", "*.usx", "*.utx", "*.dll", "*.exe", "*.zip", "*.rar", "*.7z", "*.pak", "*.bin")

    foreach ($pattern in $lfsPatterns) {
        $result = git lfs track $pattern 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Configurado LFS para: $pattern"
        }
    }

    # Paso 2: Verificar estado del repositorio
    Write-Step "Verificando estado del repositorio..."
    git status
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Error al verificar el estado del repositorio"
        Pause-Script
        exit 1
    }

    # Paso 3: Agregar archivos al staging
    Write-Step "Agregando archivos al staging area..."
    git add .
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Error al agregar archivos al staging"
        Pause-Script
        exit 1
    }
    Write-Success "Archivos agregados al staging"

    # Paso 4: Verificar archivos grandes antes del commit
    Write-Step "Verificando archivos grandes..."
    $largeFiles = git lfs ls-files 2>$null
    if ($largeFiles -and ($largeFiles -notmatch "error|not found")) {
        Write-Info "Archivos manejados por LFS:"
        $largeFiles | ForEach-Object { Write-Info "  - $_" }
    } else {
        Write-Info "No se detectaron archivos grandes manejados por LFS"
    }

    # Paso 5: Hacer commit
    Write-Step "Realizando commit..."
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Error al hacer commit"
        
        # Verificar si hay archivos demasiado grandes
        $status = git status --porcelain
        if ($status -match "M\s+.*\.(ukx|usx|utx|dll|exe)") {
            Write-Warning "Parece que hay archivos grandes sin trackear por LFS"
            Write-Info "Ejecuta manualmente: git lfs track '*.extension' para los archivos problematicos"
        }
        Pause-Script
        exit 1
    }
    Write-Success "Commit realizado: $CommitMessage"

    # Paso 6: Intentar push normal primero
    Write-Step "Intentando push normal..."
    $pushOutput = git push origin main 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Push completado exitosamente!"
        Pause-Script
        exit 0
    }

    # Paso 7: Si falla, verificar si es por archivos grandes
    Write-Warning "El push normal fallo, verificando errores de archivos grandes..."

    if ($pushOutput -match "exceeds GitHub's file size limit") {
        Write-Warning "Se detectaron archivos demasiado grandes en el historial"
        Write-Info "Ejecutando limpieza de archivos grandes..."
        
        # Identificar archivos problematicos
        $largeFileErrors = $pushOutput | Select-String -Pattern "File (.+) is (\d+\.\d+) MB" -AllMatches
        $problemFiles = @()
        
        if ($largeFileErrors) {
            foreach ($match in $largeFileErrors.Matches) {
                $fileName = $match.Groups[1].Value
                $fileSize = $match.Groups[2].Value
                $problemFiles += $fileName
                Write-Warning "Archivo problematico: $fileName ($fileSize MB)"
            }
        }
        
        # Si no se detectaron archivos especificos, usar los conocidos
        if ($problemFiles.Count -eq 0) {
            $problemFiles = @(
                "animations/iPerfect_new_custom.ukx",
                "staticmeshes/GiranM_S.usx", 
                "systextures/costume_t_euro__com.utx"
            )
        }
        
        # Eliminar archivos problematicos del cache
        foreach ($file in $problemFiles) {
            Write-Info "Eliminando del cache: $file"
            git rm --cached $file 2>$null
        }
        
        # Re-hacer commit sin los archivos grandes
        git commit -m "Remover archivos grandes del tracking - $CommitMessage"
        
        # Push forzado para limpiar el historial
        Write-Step "Realizando push forzado para limpiar historial..."
        git push origin main --force-with-lease
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Historial limpiado exitosamente"
            
            # Ahora agregar los archivos con LFS
            if ($problemFiles.Count -gt 0) {
                Write-Step "Configurando LFS para los archivos problematicos..."
                foreach ($file in $problemFiles) {
                    $extension = [System.IO.Path]::GetExtension($file)
                    git lfs track "*$extension" 2>$null
                    Write-Info "Configurado LFS para: *$extension"
                }
                
                Write-Step "Re-agregando archivos con LFS..."
                foreach ($file in $problemFiles) {
                    git add $file 2>$null
                    Write-Info "Re-agregado: $file"
                }
                git add .gitattributes
                
                git commit -m "Agregar archivos grandes con LFS - $CommitMessage"
                git push origin main
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Proceso completado exitosamente! Archivos grandes manejados con LFS"
                } else {
                    Write-ErrorMsg "Error en el push final. Revisa manualmente."
                }
            }
        } else {
            Write-ErrorMsg "Error en el push forzado. Revisa manualmente."
        }
    } else {
        Write-ErrorMsg "Error desconocido en el push. Revisa el mensaje de error:"
        Write-Host $pushOutput -ForegroundColor $ErrorColor
    }
}
catch {
    Write-ErrorMsg "Error inesperado: $($_.Exception.Message)"
}
finally {
    Write-Step "Proceso finalizado"
    Pause-Script
}