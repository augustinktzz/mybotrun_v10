# Cuts the glyphs of a known text out of a capture strip and saves them as PNG templates for the bot's OCR.
# Usage: . .\Extract-Glyphs.ps1 ; Extract-Glyphs -Image now.png -X 705 -Y 23 -W 110 -H 16 -Text "7028173" -OutDir "...\OCR\coc-ms" -Thr 88
Add-Type -AssemblyName System.Drawing

function Extract-Glyphs {
    param(
        [string]$Image, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Text, [string]$OutDir,
        [int]$Thr = 88, [int]$White = 200, [int]$MinGap = 1, [switch]$Overwrite
    )
    $bmp = New-Object System.Drawing.Bitmap $Image
    # occupancy per column / row of "bright" pixels inside the strip
    $col = New-Object int[] $W; $row = New-Object int[] $H
    for ($yy = 0; $yy -lt $H; $yy++) { for ($xx = 0; $xx -lt $W; $xx++) {
        $p = $bmp.GetPixel($X + $xx, $Y + $yy)
        if ($p.R -gt $White -and $p.G -gt $White -and $p.B -gt $White) { $col[$xx]++; $row[$yy]++ }
    } }
    # vertical extent of the text
    $top = -1; $bottom = -1
    for ($yy = 0; $yy -lt $H; $yy++) { if ($row[$yy] -gt 0) { if ($top -lt 0) { $top = $yy }; $bottom = $yy } }
    # runs of occupied columns
    $runs = @(); $inRun = $false; $start = 0; $gap = 0
    for ($xx = 0; $xx -le $W; $xx++) {
        $occ = ($xx -lt $W) -and ($col[$xx] -gt 0)
        if ($occ) { if (-not $inRun) { $inRun = $true; $start = $xx }; $gap = 0 }
        else { if ($inRun) { $gap++; if ($gap -ge $MinGap -or $xx -eq $W) { $runs += ,@($start, ($xx - $gap)); $inRun = $false; $gap = 0 } } }
    }
    $chars = ($Text -replace ' ', '').ToCharArray()
    "strip ${X},${Y} ${W}x${H}: text rows $top..$bottom, $($runs.Count) run(s) for $($chars.Count) char(s): " + (($runs | ForEach-Object { "$($_[0])-$($_[1])" }) -join ' ')
    if ($runs.Count -ne $chars.Count) { Write-Warning "run count differs from the text length, nothing saved"; $bmp.Dispose(); return }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    for ($i = 0; $i -lt $runs.Count; $i++) {
        $c = [string]$chars[$i]
        $name = switch ($c) { ':' {'colon'} '/' {'slash'} ',' {'comma'} '.' {'dot'} '%' {'percent'} '-' {'minus'} '+' {'plus'} default { if ($c -cmatch '[A-Z]') { 'up_' + $c } else { $c } } }
        $x0 = $X + $runs[$i][0] - 1; $x1 = $X + $runs[$i][1] + 1; $y0 = $Y + $top - 1; $y1 = $Y + $bottom + 1
        $gw = $x1 - $x0 + 1; $gh = $y1 - $y0 + 1
        $out = Join-Path $OutDir ("{0}_{1}.png" -f $name, $Thr)
        if ((Test-Path $out) -and -not $Overwrite) { "  $c : exists, kept"; continue }
        $g = New-Object System.Drawing.Bitmap $gw, $gh
        $gr = [System.Drawing.Graphics]::FromImage($g)
        $gr.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $gw, $gh), (New-Object System.Drawing.Rectangle $x0, $y0, $gw, $gh), [System.Drawing.GraphicsUnit]::Pixel)
        $g.Save($out); $gr.Dispose(); $g.Dispose()
        "  $c -> $(Split-Path $out -Leaf) ${gw}x${gh}"
    }
    $bmp.Dispose()
}

