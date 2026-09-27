# Removes the white background of a picture (flood fill from the borders, soft edges) and saves a trimmed PNG.
param([string]$In, [string]$Out, [int]$White = 225, [int]$Margin = 4)
Add-Type -AssemblyName System.Drawing
$src = New-Object System.Drawing.Bitmap $In
$w = $src.Width; $h = $src.Height
# copy the pixels into arrays (GetPixel is slow but 474x366 is fine)
$R = New-Object 'int[,]' $w, $h; $G = New-Object 'int[,]' $w, $h; $B = New-Object 'int[,]' $w, $h
for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $p = $src.GetPixel($x, $y); $R[$x, $y] = $p.R; $G[$x, $y] = $p.G; $B[$x, $y] = $p.B } }
$src.Dispose()
# background = near-white pixels reachable from the border
$bg = New-Object 'bool[,]' $w, $h
$queue = New-Object System.Collections.Generic.Queue[int[]]
function IsWhite($x, $y) { return ($R[$x, $y] -ge $White -and $G[$x, $y] -ge $White -and $B[$x, $y] -ge $White) }
for ($x = 0; $x -lt $w; $x++) { foreach ($y in 0, ($h - 1)) { if (-not $bg[$x, $y] -and (IsWhite $x $y)) { $bg[$x, $y] = $true; $queue.Enqueue(@($x, $y)) } } }
for ($y = 0; $y -lt $h; $y++) { foreach ($x in 0, ($w - 1)) { if (-not $bg[$x, $y] -and (IsWhite $x $y)) { $bg[$x, $y] = $true; $queue.Enqueue(@($x, $y)) } } }
while ($queue.Count -gt 0) {
    $c = $queue.Dequeue(); $cx = $c[0]; $cy = $c[1]
    foreach ($d in @(@(1,0),@(-1,0),@(0,1),@(0,-1))) {
        $nx = $cx + $d[0]; $ny = $cy + $d[1]
        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $w -or $ny -ge $h) { continue }
        if ($bg[$nx, $ny]) { continue }
        if (IsWhite $nx $ny) { $bg[$nx, $ny] = $true; $queue.Enqueue(@($nx, $ny)) }
    }
}
# alpha: background 0, edge pixels (foreground touching background) faded by their lightness, rest opaque
$dst = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$minX = $w; $minY = $h; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
    if ($bg[$x, $y]) { continue }
    $a = 255
    $edge = $false
    foreach ($d in @(@(1,0),@(-1,0),@(0,1),@(0,-1))) { $nx = $x + $d[0]; $ny = $y + $d[1]; if ($nx -ge 0 -and $ny -ge 0 -and $nx -lt $w -and $ny -lt $h -and $bg[$nx, $ny]) { $edge = $true } }
    $pr = $R[$x, $y]; $pg = $G[$x, $y]; $pb = $B[$x, $y]
    if ($edge) {
        $m = $pr; if ($pg -lt $m) { $m = $pg }; if ($pb -lt $m) { $m = $pb }
        if ($m -gt 170) { $a = [int](255 * (255 - $m) / 85); if ($a -lt 40) { $a = 40 } }
    }
    $dst.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $pr, $pg, $pb))
    if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }; if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
} }
$minX = [Math]::Max(0, $minX - $Margin); $minY = [Math]::Max(0, $minY - $Margin); $maxX = [Math]::Min($w - 1, $maxX + $Margin); $maxY = [Math]::Min($h - 1, $maxY + $Margin)
$cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1
$crop = $dst.Clone((New-Object System.Drawing.Rectangle $minX, $minY, $cw, $ch), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$crop.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$dst.Dispose(); $crop.Dispose()
"saved $Out : ${cw}x${ch} (from ${w}x${h}), background pixels removed: " + (($bg | Where-Object { $_ }).Count)

