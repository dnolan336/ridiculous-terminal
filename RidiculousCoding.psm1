# RidiculousCoding.psm1
# Makes your PowerShell prompt ridiculous: explosions, combos, XP, level-ups.
# Auto-loaded from your PowerShell profile. See install.ps1.

. (Join-Path $PSScriptRoot 'RcCore.ps1')

$script:RcOn       = $false
$script:RcLastHist = 0
$script:RcLastTick = 0
$script:RcExitReg  = $false

# --- Rank art ---------------------------------------------------------------
# One colour + emblem per rank tier (index = level-1, clamped).
$script:RcRankColors = @(
    '130;130;130', '160;160;160', '120;200;120', '100;200;255', '90;220;140',
    '120;180;255', '180;120;255', '220;120;220', '200;90;90', '255;215;0',
    '255;140;0', '0;220;200', '255;90;90', '230;180;255', '255;230;0'
)
$script:RcRankEmblems = @(
    0x00B7, 0x2022, 0x25AB, 0x25C6, 0x2691, 0x2261, 0x2734, 0x273F,
    0x2620, 0x2605, 0x2694, 0x269B, 0x2666, 0x265B, 0x2605
)

function Get-RcRankColor {
    param([int]$Level)
    $i = [math]::Max(0, [math]::Min($script:RcRankColors.Count - 1, $Level - 1))
    return $script:RcRankColors[$i]
}

function Get-RcRankEmblem {
    param([int]$Level)
    if (-not (Get-RcConfig).unicode) { return '*' }
    $i = [math]::Max(0, [math]::Min($script:RcRankEmblems.Count - 1, $Level - 1))
    if ($Level -ge $script:RcRankEmblems.Count) { return [char]::ConvertFromUtf32(0x1F451) } # CODEGOD crown
    return [string][char]$script:RcRankEmblems[$i]
}

function Get-RcComboCallout {
    param([int]$Combo)
    if ($Combo -ge 25) { return 'R-R-RIDICULOUS!!!' }
    elseif ($Combo -ge 20) { return 'UNSTOPPABLE!' }
    elseif ($Combo -ge 15) { return 'M-M-MONSTER COMBO!' }
    elseif ($Combo -ge 10) { return 'MEGA COMBO!' }
    elseif ($Combo -ge 5)  { return 'COMBO!' }
    return ''
}

# Draw a framed card around plain-text lines (frame coloured, content default fg).
function Write-RcBox {
    param([string[]]$Lines, [string]$Color = '255;215;0')
    $e = [char]27
    if ((Get-RcConfig).unicode) {
        $tl = [char]0x2554; $tr = [char]0x2557; $bl = [char]0x255A; $br = [char]0x255D; $h = [char]0x2550; $v = [char]0x2551
    } else {
        $tl = '+'; $tr = '+'; $bl = '+'; $br = '+'; $h = '-'; $v = '|'
    }
    $w = 0
    foreach ($l in $Lines) { if ($l.Length -gt $w) { $w = $l.Length } }
    $inner = $w + 2
    Write-Host ("$e[1;38;2;${Color}m  $tl" + ("$h" * $inner) + "$tr$e[0m")
    foreach ($l in $Lines) {
        $pad = $inner - 1 - $l.Length
        if ($pad -lt 0) { $pad = 0 }
        Write-Host ("$e[1;38;2;${Color}m  $v$e[0m " + $l + (' ' * $pad) + "$e[1;38;2;${Color}m$v$e[0m")
    }
    Write-Host ("$e[1;38;2;${Color}m  $bl" + ("$h" * $inner) + "$br$e[0m")
}

# --- Visual effects ---------------------------------------------------------

function Invoke-RcBurst {
    param([int]$Power = 1)
    $cfg = Get-RcConfig
    if (-not $cfg.visuals) { return }
    $e = [char]27
    if ($cfg.unicode) { $chars = ([char[]]'*+.oO0#@') + [char]0x2737 + [char]0x2022 + [char]0x00b0 + [char]0x273A + [char]0x2735 }
    else { $chars = [char[]]'*+.:oO=#' }
    $pal = @('255;60;60', '255;160;0', '255;230;0', '120;255;90', '80;200;255', '200;120;255', '255;255;255')
    $frames = 4 + [math]::Min(6, $Power)        # bigger combos -> longer blast
    $shake  = [math]::Min(10, $Power * 2)        # screen-shake amplitude
    for ($f = 0; $f -lt $frames; $f++) {
        $w = 4 + $f * 4 + $Power * 3
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append("`r$e[K")
        # white flash on the opening frame of a big blast
        if ($Power -ge 4 -and $f -eq 0) {
            [Console]::Write("`r$e[K$e[48;2;255;255;255m" + (' ' * ($w + 10)) + "$e[0m")
            Start-Sleep -Milliseconds 18
            [Console]::Write("`r$e[K")
        }
        # sine oscillation = left/right screen shake (falls back to small jitter)
        if ($shake -gt 0) { $amp = [int]([math]::Abs([math]::Sin($f * 1.4)) * $shake) }
        else { $amp = (Get-Random -Minimum 0 -Maximum 3) }
        [void]$sb.Append(' ' * $amp)
        for ($i = 0; $i -lt $w; $i++) {
            $c   = $chars[(Get-Random -Maximum $chars.Length)]
            $col = $pal[(Get-Random -Maximum $pal.Count)]
            [void]$sb.Append("$e[1;38;2;${col}m$c")
        }
        [void]$sb.Append("$e[0m")
        [Console]::Write($sb.ToString())
        Start-Sleep -Milliseconds 18
    }
    [Console]::Write("`r$e[K")
}

function Show-RcComboCallout {
    param([int]$Combo)
    $text = Get-RcComboCallout $Combo
    if (-not $text) { return }
    $e = [char]27
    if ((Get-RcConfig).unicode) { $fire = [char]::ConvertFromUtf32(0x1F525) } else { $fire = 'x' }
    $col = '255;200;0'
    if ($Combo -ge 15) { $col = '255;40;40' } elseif ($Combo -ge 10) { $col = '255;100;0' }
    [Console]::Write("`r$e[K")
    Write-Host "$e[1;38;2;${col}m  $fire x$Combo  $text$e[0m"
}

function Show-RcLevelBanner {
    param($Res)
    $e = [char]27
    $col = Get-RcRankColor $Res.level
    $em  = Get-RcRankEmblem $Res.level
    [Console]::Write("`r$e[K")
    Write-Host ""
    Write-RcBox @(
        "$em  LEVEL UP!",
        "LV.$($Res.level)   $($Res.rank)"
    ) $col
}

function Show-RcSummaryCard {
    $st   = Get-RcState
    $sess = $st.session
    $lvl  = Get-RcLevel ([int]$st.xp)
    $col  = Get-RcRankColor $lvl
    $em   = Get-RcRankEmblem $lvl
    $gain = [int]$st.xp - [int]$sess.startXp
    Write-Host ""
    Write-RcBox @(
        "$em  RIDICULOUS TERMINAL -- SESSION REPORT",
        "Rank    LV.$lvl  $(Get-RcRank $lvl)",
        "XP      +$gain  (career total $([int]$st.xp))",
        "Combo   best x$([int]$sess.maxCombo)  (career best x$([int]$st.maxCombo))",
        "Cmds $([int]$sess.cmds)   Edits $([int]$sess.edits)   Tools $([int]$sess.tools)",
        "Errors $([int]$sess.errors)   Prompts $([int]$sess.prompts)"
    ) $col
    Write-Host ""
}

# --- Prompt -----------------------------------------------------------------

function Build-RcPromptString {
    $cfg = Get-RcConfig
    $st  = Get-RcState
    $e   = [char]27
    $lvl  = Get-RcLevel ([int]$st.xp)
    $rank = Get-RcRank $lvl
    $cur  = [int]$st.xp - (Get-RcXpForLevel $lvl)
    $need = (Get-RcXpForLevel ($lvl + 1)) - (Get-RcXpForLevel $lvl)
    if ($need -le 0) { $need = 1 }
    $frac = [math]::Max(0.0, [math]::Min(1.0, $cur / [double]$need))
    $barLen = 12
    $fill = [int][math]::Round($frac * $barLen)

    if ($cfg.unicode) {
        $full = [char]0x2588; $empty = [char]0x2591; $fire = [char]::ConvertFromUtf32(0x1F525)
        $sword = [char]0x2694; $boom = [char]::ConvertFromUtf32(0x1F4A5); $arrow = [char]0x276F; $box = [char]0x2554
    } else {
        $full = '#'; $empty = '-'; $fire = 'x'; $sword = 'c'; $boom = 'e'; $arrow = '>'; $box = '+'
    }
    $bar = ("$full" * $fill) + ("$empty" * ($barLen - $fill))
    $combo = [int]$st.combo
    $comboCol = '255;120;0'
    if ($combo -ge 10) { $comboCol = '255;40;40' } elseif ($combo -ge 5) { $comboCol = '255;200;0' }

    $hud = "$e[38;2;255;215;0m$box LV.$lvl $rank $e[0m" +
           "$e[38;2;90;200;120m$bar$e[0m " +
           "$e[38;2;170;170;170m$([int]$st.xp) XP$e[0m  " +
           "$e[1;38;2;${comboCol}m$fire x$combo$e[0m  " +
           "$e[38;2;120;180;255m$sword $([int]$st.session.cmds)$e[0m  " +
           "$e[38;2;255;90;90m$boom $([int]$st.session.errors)$e[0m"
    Write-Host $hud

    $path = $PWD.Path
    return "$e[38;2;120;200;255m$path$e[0m`n$e[1;38;2;255;215;0m$arrow$e[0m "
}

function Invoke-RcPrompt {
    param([bool]$Ok = $true)
    $cfg = Get-RcConfig
    if (-not $cfg.enabled) { return ("PS " + $PWD.Path + "> ") }

    $hist  = @(Get-History)
    $count = $hist.Count
    if ($count -gt $script:RcLastHist) {
        $script:RcLastHist = $count
        $last = $hist[$count - 1]
        $cmdText = ''
        if ($last) { $cmdText = [string]$last.CommandLine }
        $failed = (-not $Ok)
        $base = 8 + [math]::Min(40, [int]($cmdText.Length / 2))
        $res = Add-RcXp -Amount $base -Kind 'cmd' -Failed:$failed
        if ($failed) {
            Play-RcSound 'error'
            Invoke-RcBurst -Power 0
        } else {
            if ($res.combo -ge 5) { Play-RcSound 'combo' } else { Play-RcSound 'explosion' }
            Invoke-RcBurst -Power ([math]::Min(6, 1 + [int]($res.combo / 3)))
            Show-RcComboCallout $res.combo
        }
        if ($res.leveledUp) { Play-RcSound 'levelup'; Show-RcLevelBanner $res }
    }
    return (Build-RcPromptString)
}

# --- Typing sounds (opt-in) -------------------------------------------------

function Invoke-RcKeyTick {
    $now = (Get-Date).Ticks
    if (($now - $script:RcLastTick) / 1e7 -lt 0.04) { return }
    $script:RcLastTick = $now
    Play-RcSound 'type'
}

function Enable-RcTyping {
    if (-not (Get-Module -ListAvailable PSReadLine)) { return }
    $sb = {
        param($key, $arg)
        [Microsoft.PowerShell.PSConsoleReadLine]::SelfInsert($key, $arg)
        Invoke-RcKeyTick
    }
    foreach ($k in ([char[]]'abcdefghijklmnopqrstuvwxyz0123456789')) {
        try { Set-PSReadLineKeyHandler -Chord "$k" -ScriptBlock $sb } catch {}
    }
    try { Set-PSReadLineKeyHandler -Chord 'Spacebar' -ScriptBlock $sb } catch {}
}

# --- Public control surface -------------------------------------------------

function Enable-RidiculousCoding {
    if ($script:RcOn) { return }
    $script:RcOn = $true
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    $st = Get-RcState
    $st = Reset-RcSession $st     # fresh stats for this shell, stamp starting XP
    Save-RcState $st
    $script:RcLastHist = @(Get-History).Count
    Set-Item -Path Function:global:prompt -Value {
        $ok = $?
        try { Invoke-RcPrompt -Ok $ok } catch { "PS " + $PWD.Path + "> " }
    }
    if ((Get-RcConfig).typingSounds) { Enable-RcTyping }
    # show a session report card when this shell closes
    if (-not $script:RcExitReg) {
        $script:RcExitReg = $true
        try {
            Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action {
                try { $c = Get-RcConfig; if ($c.enabled -and $c.visuals) { Show-RcSummaryCard } } catch {}
            } | Out-Null
        } catch {}
    }
    Play-RcSound 'boot'
}

function Disable-RidiculousCoding {
    $script:RcOn = $false
    Set-Item -Path Function:global:prompt -Value { "PS " + $PWD.Path + "> " }
    "Ridiculous Terminal disabled for this shell. Use 'rt start' or restart to re-enable."
}

function Set-RcConfigValue {
    param([string]$Name, $Value)
    $cfg = @{}
    if (Test-Path $script:RcCfgUser) {
        try { $j = Get-Content $script:RcCfgUser -Raw | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { $cfg[$p.Name] = $p.Value } } catch {}
    }
    $cfg[$Name] = $Value
    ($cfg | ConvertTo-Json) | Set-Content -Path $script:RcCfgUser -Encoding UTF8
}

function Show-RcStats {
    $st  = Get-RcState
    $lvl = Get-RcLevel ([int]$st.xp)
    $col = Get-RcRankColor $lvl
    $em  = Get-RcRankEmblem $lvl
    Write-Host ""
    Write-RcBox @(
        "$em  $(Get-RcRank $lvl)",
        "Level   $lvl",
        "XP      $([int]$st.xp)  (next at $(Get-RcXpForLevel ($lvl+1)))",
        "Best combo   x$([int]$st.maxCombo)",
        "This shell   cmds=$([int]$st.session.cmds) edits=$([int]$st.session.edits) tools=$([int]$st.session.tools) errors=$([int]$st.session.errors)"
    ) $col
    Write-Host ""
}

function Show-RcHelp {
    @"
Ridiculous Terminal -- commands (rt, or rc -- both work):
  rt start     start the chaos (this shell)   rt stop   stop it + show report
  rt stats     show your level / XP / best combo
  rt summary   show the session report card
  rt mute      silence sounds        rt unmute   restore sounds
  rt quiet     hide visuals          rt loud     restore visuals
  rt typing    toggle per-keystroke sounds
  rt test      fire every sound + an explosion
  rt reset     wipe progress back to Level 1
  rt config    show current settings
"@
}

function Invoke-Rc {
    param([string]$Cmd = 'stats')
    switch ($Cmd.ToLower()) {
        'stats'   { Show-RcStats }
        'summary' { Show-RcSummaryCard }
        'report'  { Show-RcSummaryCard }
        'start'   { Set-RcConfigValue enabled $true;  Enable-RidiculousCoding; Play-RcSound 'levelup'; "Ridiculous Terminal: STARTED -- go cause some chaos." }
        'stop'    { Set-RcConfigValue enabled $false; Show-RcSummaryCard; Disable-RidiculousCoding }
        'on'      { Set-RcConfigValue enabled $true;  Enable-RidiculousCoding; "Ridiculous Terminal: ON" }
        'off'     { Set-RcConfigValue enabled $false; Disable-RidiculousCoding }
        'mute'   { Set-RcConfigValue sounds $false;  "Sounds muted." }
        'unmute' { Set-RcConfigValue sounds $true;   Play-RcSound 'blip'; "Sounds on." }
        'quiet'  { Set-RcConfigValue visuals $false; "Visuals off." }
        'loud'   { Set-RcConfigValue visuals $true;  "Visuals on." }
        'typing' { $v = -not (Get-RcConfig).typingSounds; Set-RcConfigValue typingSounds $v; if ($v) { Enable-RcTyping }; "Typing sounds: $v (restart shell to fully apply when turning off)" }
        'test'   { foreach ($s in 'boot', 'blip', 'explosion', 'combo', 'levelup', 'error', 'complete') { Play-RcSound $s -Sync; Start-Sleep -Milliseconds 120 }; Invoke-RcBurst -Power 4 }
        'reset'  { Save-RcState (New-RcState); "Progress reset to Level 1." }
        'config' { (Get-RcConfig).GetEnumerator() | Sort-Object Name | Format-Table -AutoSize | Out-String }
        default  { Show-RcHelp }
    }
}

Set-Alias rt Invoke-Rc   # primary command
Set-Alias rc Invoke-Rc   # backward-compatible alias
Export-ModuleMember -Function Enable-RidiculousCoding, Disable-RidiculousCoding, Invoke-Rc, Invoke-RcPrompt, Invoke-RcKeyTick -Alias rt, rc
