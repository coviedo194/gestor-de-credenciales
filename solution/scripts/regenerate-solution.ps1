# Regenera solution/package/ y solution/canvas-src/ exportando desde Dataverse.
# Uso: pwsh solution/scripts/regenerate-solution.ps1
# Lee GC_PAC_PROFILE del .env de la raíz del repo.

param(
    [string]$PacProfileName,
    [string]$SolutionName = "OVGGestordecontraseas"
)

$ErrorActionPreference = "Stop"

# Estructura esperada:
#   solution/
#   ├── package/      ← solución desempaquetada
#   ├── canvas-src/   ← fuentes legibles de las custom pages
#   ├── scripts/
#   │   └── regenerate-solution.ps1
#   └── solution.zip  ← zip temporal (se borra al terminar)
$SolutionDir = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $SolutionDir
$PackageDir = Join-Path $SolutionDir "package"
$CanvasSourcesDir = Join-Path $SolutionDir "canvas-src"
$ZipPath = Join-Path $SolutionDir "solution.zip"

foreach ($Path in @($PackageDir, $CanvasSourcesDir, $ZipPath)) {
    if (Test-Path -LiteralPath $Path) {
        $Item = Get-Item -LiteralPath $Path -Force
        if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "No se permiten enlaces simbólicos en las rutas de salida: '$Path'."
        }
    }
}

if (-not $PSBoundParameters.ContainsKey('PacProfileName')) {
    $EnvPath = Join-Path $RepoRoot ".env"
    if (-not (Test-Path -LiteralPath $EnvPath -PathType Leaf)) {
        throw "Falta $EnvPath. Copia .env.example como .env en la raíz del repo y configura GC_PAC_PROFILE con el nombre de perfil de 'pac auth list', o indica -PacProfileName."
    }

    $ProfileEntries = @(Get-Content -LiteralPath $EnvPath | Where-Object { $_ -match '^\s*GC_PAC_PROFILE\s*=' })
    if ($ProfileEntries.Count -ne 1) {
        throw "Configura una única entrada GC_PAC_PROFILE en $EnvPath con el nombre de perfil de 'pac auth list'."
    }

    $PacProfileName = ($ProfileEntries[0] -split '=', 2)[1].Trim()
    if ($PacProfileName.StartsWith('"') -or $PacProfileName.StartsWith("'")) {
        $Quote = $PacProfileName.Substring(0, 1)
        if ($PacProfileName.Length -lt 2 -or -not $PacProfileName.EndsWith($Quote)) {
            throw "GC_PAC_PROFILE tiene comillas sin cerrar en $EnvPath."
        }
        $PacProfileName = $PacProfileName.Substring(1, $PacProfileName.Length - 2).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($PacProfileName)) {
        throw "GC_PAC_PROFILE está vacío en $EnvPath. Indica el perfil del entorno fuente no administrado; consulta 'pac auth list'."
    }
}

# Perfil activo antes de empezar, para restaurarlo al terminar.
$PreviousProfile = $null
$ActiveLine = pac auth list | Where-Object { $_ -match '^\[\d+\]\s+\*\s+\S+\s+(\S+)' } | Select-Object -First 1
if ($ActiveLine -and $ActiveLine -match '^\[\d+\]\s+\*\s+\S+\s+(\S+)') { $PreviousProfile = $Matches[1] }

try {
    if ([string]::IsNullOrWhiteSpace($PacProfileName)) {
        Write-Host "Usando el perfil PAC activo..." -ForegroundColor Cyan
    }
    else {
        Write-Host "Seleccionando perfil PAC '$PacProfileName'..." -ForegroundColor Cyan
        pac auth select --name $PacProfileName
        if ($LASTEXITCODE -ne 0) { throw "No se pudo seleccionar el perfil PAC '$PacProfileName'." }
    }

    Write-Host "Exportando solución '$SolutionName' como no administrada..." -ForegroundColor Cyan
    pac solution export --name $SolutionName --path $ZipPath --managed false --overwrite
    if ($LASTEXITCODE -ne 0) { throw "Falló la exportación de '$SolutionName'." }

    foreach ($Folder in @($PackageDir, $CanvasSourcesDir)) {
        if (Test-Path -LiteralPath $Folder) {
            Write-Host "Limpiando '$Folder'..." -ForegroundColor Cyan
            Remove-Item -LiteralPath $Folder -Recurse -Force
        }
    }

    Write-Host "Desempaquetando en '$PackageDir'..." -ForegroundColor Cyan
    pac solution unpack --zipfile $ZipPath --folder $PackageDir --packagetype Unmanaged
    if ($LASTEXITCODE -ne 0) { throw "Falló el desempaquetado. Se conserva '$ZipPath'." }

    # Los flujos exportados guardan como defaultValue el valor actual de las
    # variables de entorno (URL de la app con el host del entorno y el ID de la
    # app). Se sustituyen por la plantilla de la definición para no publicar
    # datos del entorno de desarrollo; cada entorno configura su valor actual.
    Write-Host "Ocultando URLs del entorno en los flujos..." -ForegroundColor Cyan
    $Guid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    $AppUrlPattern = "https://[a-z0-9-]+\.crm[0-9]*\.dynamics\.com/main\.aspx\?appid=$Guid"
    $AppUrlPlaceholder = 'https://{TU ID DE ENTORNO}.{crm4 U OTRA REGION}.dynamics.com/main.aspx?appid={APP GUID}'
    Get-ChildItem -LiteralPath (Join-Path $PackageDir "Workflows") -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
        $Text = [System.IO.File]::ReadAllText($_.FullName)
        $Clean = [regex]::Replace($Text, $AppUrlPattern, $AppUrlPlaceholder)
        if ($Clean -ne $Text) { [System.IO.File]::WriteAllText($_.FullName, $Clean) }
    }

    $CanvasAppsDir = Join-Path $PackageDir "CanvasApps"
    $CustomPageCount = 0
    if (Test-Path -LiteralPath $CanvasAppsDir) {
        foreach ($MetadataFile in Get-ChildItem -LiteralPath $CanvasAppsDir -Filter "*.meta.xml" -File) {
            $Metadata = [xml](Get-Content -LiteralPath $MetadataFile.FullName -Raw)
            if ($Metadata.CanvasApp.CanvasAppType -ne "2") { continue }

            $AppName = [string]$Metadata.CanvasApp.Name
            $DocumentUri = [string]$Metadata.CanvasApp.DocumentUri
            if ([string]::IsNullOrWhiteSpace($AppName) -or
                [string]::IsNullOrWhiteSpace($DocumentUri) -or
                $AppName -in @(".", "..") -or $AppName -match '[/\\]') {
                throw "Metadatos de custom page inválidos: '$($MetadataFile.FullName)'. Se conserva el ZIP."
            }
            $MsappName = ($DocumentUri -replace '\\', '/').Split('/')[-1]
            $MsappPath = Join-Path $CanvasAppsDir $MsappName
            if (-not (Test-Path -LiteralPath $MsappPath -PathType Leaf) -or
                [System.IO.Path]::GetExtension($MsappPath) -ne ".msapp") {
                throw "No se encuentra el MSAPP de '$AppName': '$MsappPath'. Se conserva el ZIP."
            }

            $SourcesDir = Join-Path $CanvasSourcesDir $AppName
            Write-Host "Extrayendo custom page '$AppName' en '$SourcesDir'..." -ForegroundColor Cyan
            pac canvas unpack --msapp $MsappPath --sources $SourcesDir --layout SourceCode
            if ($LASTEXITCODE -ne 0) { throw "Falló la extracción de '$AppName'. Se conserva el ZIP." }
            $CustomPageCount++
        }
    }
    Write-Host "Custom pages extraídas: $CustomPageCount" -ForegroundColor Cyan

    Write-Host "Eliminando ZIP temporal '$ZipPath'..." -ForegroundColor Cyan
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
}
finally {
    if ($PreviousProfile -and $PreviousProfile -ne $PacProfileName) {
        Write-Host "Restaurando perfil PAC '$PreviousProfile'..." -ForegroundColor Cyan
        pac auth select --name $PreviousProfile | Out-Null
    }
}

Write-Host ""
Write-Host "Proceso completado. La solución está en: $PackageDir" -ForegroundColor Green
Write-Host "Recuerda commitear los cambios en solution/." -ForegroundColor Yellow
