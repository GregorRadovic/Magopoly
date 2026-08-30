# Builds Magopoly into a single Windows executable: build\Magopoly.exe
#
#   Usage:   .\build.ps1
#            .\build.ps1 -Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe"
#            .\build.ps1 -Run          # build, then launch the result
#
# Requires Godot 4.7 export templates (a one-time ~700 MB download):
#   open the project in the editor > Editor menu > Manage Export Templates >
#   Download and Install.

param(
    [string]$Godot = "",
    [switch]$Run
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$OutFile    = Join-Path $ProjectDir "build\Magopoly.exe"
$Preset     = "Windows Desktop"

function Find-Godot {
    if ($Godot -and (Test-Path $Godot)) { return $Godot }

    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7-stable_win64_console.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.7\Godot_v4.7-stable_win64_console.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.7-stable_win64_console.exe",
        "$env:USERPROFILE\Desktop\Godot_v4.7-stable_win64_console.exe",
        "C:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }

    $onPath = Get-Command godot -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    throw "Couldn't find Godot 4.7. Pass its path:  .\build.ps1 -Godot `"C:\path\to\Godot_...console.exe`""
}

$godotExe = Find-Godot
Write-Host "Godot:    $godotExe"
Write-Host "Project:  $ProjectDir"
Write-Host "Output:   $OutFile"
Write-Host ""

# --- template check (nicer message than Godot's raw error) ---------------
$tplDir  = Join-Path $env:APPDATA "Godot\export_templates\4.7.stable"
$tplFile = Join-Path $tplDir "windows_release_x86_64.exe"
if (-not (Test-Path $tplFile)) {
    Write-Host "Export templates for 4.7.stable are not installed." -ForegroundColor Yellow
    Write-Host "Open the project in the Godot editor, then:" -ForegroundColor Yellow
    Write-Host "  Editor menu  >  Manage Export Templates  >  Download and Install" -ForegroundColor Yellow
    Write-Host "(one-time ~700 MB download), then run this script again."
    exit 1
}

# --- export -------------------------------------------------------------
New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
Remove-Item $OutFile -ErrorAction SilentlyContinue

& $godotExe --headless --path $ProjectDir --export-release $Preset $OutFile
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OutFile)) {
    throw "Export failed (Godot exit code $LASTEXITCODE)."
}

$sizeMB = [math]::Round((Get-Item $OutFile).Length / 1MB, 1)
Write-Host ""
Write-Host "Built $OutFile  ($sizeMB MB)" -ForegroundColor Green
Write-Host "This single file is the whole game -- send it to your friends as-is."

if ($Run) { & $OutFile }
