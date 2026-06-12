# Generate-Assets.ps1
# Procedurally synthesizes 8-bit / chiptune-style WAV sound effects.
# No external assets required. Run once at install time.
#
# Design note: PowerShell's `,$array` return idiom re-wraps into a jagged
# Object[] when passed through nested function arguments. To avoid that whole
# class of bug, segments are appended into a [List[double]] passed by reference
# (mutation, no array returns), and only .ToArray() is handed to Write-Wav.
param([string]$OutDir = (Join-Path $PSScriptRoot 'assets'))

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$script:Rate = 22050
$script:Rng  = New-Object System.Random 1337   # fixed seed -> reproducible noise

function Write-Wav {
    param([double[]]$Samples, [string]$Path)
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $dataSize = $Samples.Length * 2
    $bw.Write([char[]]'RIFF'); $bw.Write([int](36 + $dataSize)); $bw.Write([char[]]'WAVE')
    $bw.Write([char[]]'fmt '); $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
    $bw.Write([int]$script:Rate); $bw.Write([int]($script:Rate * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
    $bw.Write([char[]]'data'); $bw.Write([int]$dataSize)
    foreach ($s in $Samples) {
        $c = $s; if ($c -gt 1.0) { $c = 1.0 } elseif ($c -lt -1.0) { $c = -1.0 }
        $bw.Write([int16]([int]($c * 32760)))
    }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
}

# Append a single tone/segment onto the buffer (mutates $Buf, returns nothing).
function Add-Tone {
    param([System.Collections.Generic.List[double]]$Buf,
          [double]$Freq, [double]$Dur, [string]$Wave = 'square', [double]$Vol = 0.6, [double]$Decay = 5.0)
    $n = [int]($script:Rate * $Dur)
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $script:Rate
        switch ($Wave) {
            'square' { if ([math]::Sin(2 * [math]::PI * $Freq * $t) -ge 0) { $v = 1.0 } else { $v = -1.0 } }
            'sine'   { $v = [math]::Sin(2 * [math]::PI * $Freq * $t) }
            'saw'    { $ph = $Freq * $t; $v = 2.0 * ($ph - [math]::Floor($ph + 0.5)) }
            'noise'  { $v = $script:Rng.NextDouble() * 2.0 - 1.0 }
            default  { $v = 0.0 }
        }
        $amp = [math]::Exp(-$t * $Decay) * [math]::Min(1.0, $i / 120.0) * $Vol
        $Buf.Add($v * $amp)
    }
}

function New-Buf { return , (New-Object 'System.Collections.Generic.List[double]') }

# --- Build the sound bank ---------------------------------------------------

# type: tiny keystroke tick
$b = New-Buf
Add-Tone $b 1200 0.035 'square' 0.30 40
Write-Wav $b.ToArray() (Join-Path $OutDir 'type.wav')

# blip: prompt-submit / generic (two quick notes up)
$b = New-Buf
Add-Tone $b 700 0.045 'square' 0.45 22
Add-Tone $b 950 0.05  'square' 0.45 18
Write-Wav $b.ToArray() (Join-Path $OutDir 'blip.wav')

# blip2: notification (two notes down)
$b = New-Buf
Add-Tone $b 1046 0.05 'square' 0.4 20
Add-Tone $b 784  0.06 'square' 0.4 16
Write-Wav $b.ToArray() (Join-Path $OutDir 'blip2.wav')

# explosion: noise burst overlaid with a low rumble (file edit / cmd success)
$b = New-Buf
$n = [int]($script:Rate * 0.32)
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $script:Rate
    $ns = $script:Rng.NextDouble() * 2.0 - 1.0
    $rm = [math]::Sin(2 * [math]::PI * 70 * $t)
    $env = [math]::Exp(-$t * 10) * [math]::Min(1.0, $i / 60.0)
    $b.Add(($ns * 0.55 + $rm * 0.5) * $env)
}
Write-Wav $b.ToArray() (Join-Path $OutDir 'explosion.wav')

# combo: rising arpeggio
$b = New-Buf
Add-Tone $b 523  0.05 'square' 0.45 12
Add-Tone $b 659  0.05 'square' 0.45 12
Add-Tone $b 784  0.05 'square' 0.45 12
Add-Tone $b 1046 0.10 'square' 0.50 8
Write-Wav $b.ToArray() (Join-Path $OutDir 'combo.wav')

# levelup: triumphant run
$b = New-Buf
Add-Tone $b 523  0.07 'square' 0.5 8
Add-Tone $b 659  0.07 'square' 0.5 8
Add-Tone $b 784  0.07 'square' 0.5 8
Add-Tone $b 1046 0.07 'square' 0.5 8
Add-Tone $b 1318 0.18 'square' 0.55 5
Write-Wav $b.ToArray() (Join-Path $OutDir 'levelup.wav')

# error: descending buzz
$b = New-Buf
Add-Tone $b 300 0.10 'saw' 0.45 8
Add-Tone $b 220 0.10 'saw' 0.45 8
Add-Tone $b 150 0.16 'saw' 0.50 6
Write-Wav $b.ToArray() (Join-Path $OutDir 'error.wav')

# complete: victory jingle (Claude finished a turn)
$b = New-Buf
Add-Tone $b 659  0.08 'square' 0.5 7
Add-Tone $b 784  0.08 'square' 0.5 7
Add-Tone $b 988  0.08 'square' 0.5 7
Add-Tone $b 1318 0.22 'square' 0.55 4
Write-Wav $b.ToArray() (Join-Path $OutDir 'complete.wav')

# boot: short power-on chord (new shell / session start)
$b = New-Buf
Add-Tone $b 392 0.06 'square' 0.45 9
Add-Tone $b 523 0.06 'square' 0.45 9
Add-Tone $b 784 0.14 'square' 0.50 6
Write-Wav $b.ToArray() (Join-Path $OutDir 'boot.wav')

Write-Host ("Generated {0} sound effects in {1}" -f (Get-ChildItem $OutDir -Filter *.wav).Count, $OutDir)
