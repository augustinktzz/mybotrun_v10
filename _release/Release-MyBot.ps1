<#
.SYNOPSIS
    Publie une version de MyBot : numero de version partout, CHANGELOG, compilation, zip sur le Bureau.

.PARAMETER Version
    Nouveau numero, ex. 10.2.0 (mineur = nouveautes, patch = correctifs).
.PARAMETER Notes
    Fichier texte des notes de version (une ligne par point, en anglais). Ajoute en tete du CHANGELOG.
.PARAMETER NoBuild
    Ne recompile pas (juste les numeros + changelog + zip).

.EXAMPLE
    .\Release-MyBot.ps1 -Version 10.2.0 -Notes notes-10.2.0.txt
#>
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [string]$Notes = "",
    [switch]$NoBuild
)
$ErrorActionPreference = "Stop"
$R    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)   # racine du projet
$Dist = "C:\Users\augus\Desktop\MyBotRun DISTRIBUTABLE"
$Tmp  = Join-Path $env:TEMP "MyBot_dist\MyBot_v10"
$Au3Check = "C:\Program Files (x86)\AutoIt3\AU3Check.exe"
$Aut2Exe  = "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe"

function Replace-InFile($Path, $Pattern, $Replacement, $Encoding = "ASCII") {
    $raw = [IO.File]::ReadAllText($Path)
    $new = [regex]::Replace($raw, $Pattern, $Replacement)
    if ($new -eq $raw) { Write-Warning "rien remplace dans $(Split-Path $Path -Leaf) pour '$Pattern'" }
    # garde les fins de ligne du fichier (LF ou CRLF) et son encodage sans BOM
    $enc = if ($Encoding -eq "UTF8") { New-Object Text.UTF8Encoding($false) } else { [Text.Encoding]::ASCII }
    [IO.File]::WriteAllText($Path, $new, $enc)
}

# 1. numero de version -------------------------------------------------------------------------
$vf = Join-Path $R "MyBot.run.version.au3"
Replace-InFile $vf '#pragma compile\(ProductVersion, [\d.]+\)' "#pragma compile(ProductVersion, $Version)" "UTF8"
Replace-InFile $vf '#pragma compile\(FileVersion, [\d.]+\)' "#pragma compile(FileVersion, $Version)" "UTF8"
Replace-InFile $vf 'Global \$g_sBotVersion = "v[\d.]+"' "Global `$g_sBotVersion = `"v$Version`"" "UTF8"
Replace-InFile (Join-Path $R "README - MyBot v10.txt") '^MyBot v[\d.]+ - ' "MyBot v$Version - "
Replace-InFile (Join-Path $R "Lancer MyBot v10.bat") 'MyBot v[\d.]+ \(MyBot\.run\.exe\)' "MyBot v$Version (MyBot.run.exe)"
Write-Host "version -> v$Version" -ForegroundColor Green

# 2. changelog ---------------------------------------------------------------------------------
if ($Notes) {
    if (-not (Test-Path $Notes)) { throw "notes introuvables : $Notes" }
    $lines = Get-Content $Notes -Encoding UTF8 | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $t = $_.Trim(); if ($t -notmatch '^\*') { "* $t" } else { $t } }
    $cl = Join-Path $R "CHANGELOG"
    $old = [IO.File]::ReadAllText($cl)
    if ($old -match "(?m)^\* v$([regex]::Escape($Version)) \*\*") { Write-Warning "CHANGELOG contient deja v$Version, pas ajoute" }
    else {
        $entry = "* v$Version **`r`n" + ($lines -join "`r`n") + "`r`n`r`n"
        [IO.File]::WriteAllText($cl, $entry + $old, (New-Object Text.UTF8Encoding($false)))
        Write-Host "CHANGELOG : entree v$Version ajoutee ($($lines.Count) lignes)" -ForegroundColor Green
    }
}

# 3. compilation -------------------------------------------------------------------------------
if (-not $NoBuild) {
    foreach ($chk in @("MyBot.run.au3", "MyBot.run.MiniGui.au3", "MultiBot.au3")) { & $Au3Check -q -d (Join-Path $R $chk); if ($LASTEXITCODE -ne 0) { throw "AU3Check a echoue sur $chk" } }
    foreach ($s in @(@{in="MyBot.run.au3"; out="MyBot.run.exe"}, @{in="MyBot.run.MiniGui.au3"; out="MyBot.run.MiniGui.exe"}, @{in="MyBot.run.Watchdog.au3"; out="MyBot.run.Watchdog.exe"}, @{in="MyBot.run.Wmi.au3"; out="MyBot.run.Wmi.exe"}, @{in="MultiBot.au3"; out="MultiBot.exe"})) {
        if (Get-Process -Name ($s.out -replace '\.exe$', '') -ErrorAction SilentlyContinue) { throw "$($s.out) est en cours d'execution : ferme le bot avant de publier" }
        $pr = Start-Process -FilePath $Aut2Exe -ArgumentList @("/in", "`"$R\$($s.in)`"", "/out", "`"$R\$($s.out)`"", "/x86", "/nopack") -Wait -PassThru -NoNewWindow
        if ($pr.ExitCode -ne 0) { throw "compilation de $($s.out) : exit $($pr.ExitCode)" }
        $f = Get-Item "$R\$($s.out)"; "{0,-24} {1,6:N0} KB  v{2}" -f $s.out, ($f.Length/1KB), $f.VersionInfo.FileVersion
    }
}

# 4. zip -----------------------------------------------------------------------------------------
New-Item -ItemType Directory -Path $Dist -Force | Out-Null
$args = @($R, $Tmp, "/MIR", "/XD", "_backup_avant_fix_bs5", "_release", "_tools", "Profiles", ".git", "/XF", "*.bak-*", "*.zip", "Lancer MyBot (corrige).bat", "/NFL", "/NDL", "/NJH", "/NJS", "/NP")
$p = Start-Process -FilePath "robocopy.exe" -ArgumentList $args -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ge 8) { throw "robocopy exit $($p.ExitCode)" }
New-Item -ItemType Directory -Path "$Tmp\Profiles" -Force | Out-Null
$zip = Join-Path $Dist "MyBot_v$Version.zip"
if (Test-Path $zip) { [IO.File]::Delete($zip) }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($Tmp, $zip, [IO.Compression.CompressionLevel]::Optimal, $true)
$z = [IO.Compression.ZipFile]::OpenRead($zip)
$bad = @($z.Entries | Where-Object { $_.Name -eq "config.ini" -or $_.Name -like "*.bak-*" -or $_.Name -eq "token.txt" }).Count
$z.Dispose()
if ($bad -gt 0) { [IO.File]::Delete($zip); throw "le zip contenait des fichiers prives, supprime" }
Get-ChildItem $Dist -Filter "MyBot_v*.zip" | Where-Object { $_.Name -ne "MyBot_v$Version.zip" } | ForEach-Object { Remove-Item $_.FullName -Force; "ancien zip supprime : $($_.Name)" }
"zip : {0}  ({1:N0} MB)" -f $zip, ((Get-Item $zip).Length/1MB)
