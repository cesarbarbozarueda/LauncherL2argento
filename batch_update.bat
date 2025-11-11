@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo    SCRIPT DE PUSH CON GIT LFS
echo ========================================

if "%1"=="" (
    echo Error: Debes proporcionar un mensaje de commit
    echo Uso: quick-push.bat "Tu mensaje de commit"
    exit /b 1
)

set COMMIT_MSG=%1

echo.
echo Paso 1: Configurando LFS...
git lfs track "*.ukx" 2>nul
git lfs track "*.usx" 2>nul  
git lfs track "*.utx" 2>nul
git lfs track "*.dll" 2>nul
git lfs track "*.exe" 2>nul

echo.
echo Paso 2: Agregando archivos...
git add .

echo.
echo Paso 3: Haciendo commit...
git commit -m "%COMMIT_MSG%"

echo.
echo Paso 4: Intentando push...
git push origin main

if !errorlevel! neq 0 (
    echo.
    echo ========================================
    echo    PUSH FALLADO - Limpiando historial
    echo ========================================
    
    echo Eliminando archivos grandes del cache...
    git rm --cached animations/iPerfect_new_custom.ukx 2>nul
    git rm --cached staticmeshes/GiranM_S.usx 2>nul
    git rm --cached systextures/costume_t_euro__com.utx 2>nul
    
    echo Re-haciendo commit...
    git commit -m "Clean: %COMMIT_MSG%"
    
    echo Push forzado...
    git push origin main --force
    
    if !errorlevel! equ 0 (
        echo.
        echo ¡Repositorio limpiado! Ahora configura LFS manualmente para nuevos archivos grandes.
    ) else (
        echo.
        echo ERROR: No se pudo completar la limpieza.
    )
) else (
    echo.
    echo ========================================
    echo    ¡PUSH EXITOSO!
    echo ========================================
)

echo.
pause