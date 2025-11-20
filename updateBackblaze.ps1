param(
    [Parameter(Mandatory=$true)]
    [string]$CommitMessage
)

# ============================
# CONFIG BACKBLAZE B2
# ============================
$B2KeyId = "4ec3ca24458a"
$B2AppKey = "0053a2cb02b2e9ffab565ab0c112f7eb86646181bc"
$BucketName = "L2argentoLauncher"
$BucketId = "042e9ce38c6a92d494a5081a"
$UploadBaseUrl = "https://f004.backblazeb2.com/file/L2argentoLauncher/"
# IMPORTANTE: este URL es el que irá en update.json
# Ejemplo: https://f004.backblazeb2.com/file/l2argento-patch/

# ============================
# FUNCIONES
# ============================

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[ERR]  $msg" -ForegroundColor Red }

function Pause-Now() {
    Write-Host "Presiona una tecla para continuar..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ============================
# AUTENTICAR
# ============================

Write-Info "Autenticando en Backblaze..."
$authString = "${B2KeyId}:${B2AppKey}"
$authHeader = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($authString))

$auth = Invoke-RestMethod `
    -Uri "https://api.backblazeb2.com/b2api/v2/b2_authorize_account" `
    -Headers @{ Authorization = "Basic $authHeader" } `
    -Method Get

if (-not $auth.accountId) {
    Write-Err "Autenticación falló."
    Pause-Now
    exit
}

Write-Ok "Autenticado."
$apiUrl = $auth.apiUrl

# ============================
# PAGINACIÓN: LISTAR ARCHIVOS (100% CORRECTO)
# ============================

Write-Info "Listando archivos remotos..."

$remoteFiles = @{}
$nextFileName = ""

do {
    $body = @{ bucketId = $BucketId }
    if ($nextFileName -ne "") { $body.startFileName = $nextFileName }

    $resp = Invoke-RestMethod `
        -Uri "$apiUrl/b2api/v2/b2_list_file_names" `
        -Method Post `
        -Body ($body | ConvertTo-Json) `
        -Headers @{ Authorization = $auth.authorizationToken }

    foreach ($f in $resp.files) {
        # NO usar contentSha1 si viene con "none" o valores inválidos
        if ($f.contentSha1 -match "^[A-Fa-f0-9]{40}$") {
            $remoteFiles[$f.fileName] = $f.contentSha1.ToLower()
        }
    }

    $nextFileName = $resp.nextFileName
}
while ($nextFileName)

Write-Ok "Archivos remotos cargados: $($remoteFiles.Count)"

# ============================
# LISTAR ARCHIVOS LOCALES
# ============================

$excludeFiles = @(
    ".gitattributes",
    "batch_update.bat",
    "generate_manifest.py",
    "powershell_manifest.ps1",
    "powershell_update.ps1",
    "updateBackblaze.json",
    "updateBackblaze.ps1"
)

$excludeExtensions = @(".ps1", ".py", ".bat")

$localFiles = Get-ChildItem -Recurse -File |
    Where-Object {
        $_.FullName -notmatch "\\\.git" -and
        $excludeFiles -notcontains $_.Name -and
        $excludeExtensions -notcontains $_.Extension
    }

Write-Info "Archivos locales: $($localFiles.Count)"

# ============================
# SUBIR CAMBIOS
# ============================

foreach ($file in $localFiles) {

    $basePath = (Get-Location).Path + "\"
    $relativePath = $file.FullName.Replace($basePath, "").Replace("\", "/")

    $localSha1 = (Get-FileHash $file.FullName -Algorithm SHA1).Hash.ToLower()

    # Evitar re-subidas
    if ($remoteFiles.ContainsKey($relativePath) -and $remoteFiles[$relativePath] -eq $localSha1) {
        Write-Info "Sin cambios -> $relativePath"
        continue
    }

    Write-Info "Nuevo o modificado -> $relativePath"

    $uploadUrl = Invoke-RestMethod `
        -Uri "$apiUrl/b2api/v2/b2_get_upload_url" `
        -Method Post `
        -Body (@{ bucketId = $BucketId } | ConvertTo-Json) `
        -Headers @{ Authorization = $auth.authorizationToken }

    $headers = @{
        Authorization       = $uploadUrl.authorizationToken
        "X-Bz-File-Name"    = $relativePath
        "Content-Type"      = "b2/x-auto"
        "X-Bz-Content-Sha1" = $localSha1
    }

    Invoke-RestMethod `
        -Uri $uploadUrl.uploadUrl `
        -Method Post `
        -Headers $headers `
        -InFile $file.FullName `
        -ContentType "b2/x-auto"

    Write-Ok "Subido -> $relativePath"
}

Write-Ok "Proceso completado."
Pause-Now