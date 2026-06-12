# RcCore.ps1
# Shared state, scoring (XP / combo / levels) and sound playback.
# Dot-sourced by RidiculousCoding.psm1 (interactive) and cc-hook.ps1 (Claude Code).

$script:RcRoot    = $PSScriptRoot
$script:RcAssets  = Join-Path $PSScriptRoot 'assets'
$script:RcData    = Join-Path $env:LOCALAPPDATA 'RidiculousCoding'
$script:RcStateF  = Join-Path $script:RcData 'state.json'
$script:RcCfgUser = Join-Path $script:RcData 'config.json'
$script:RcCfgDef  = Join-Path $PSScriptRoot 'config.json'

if (-not (Test-Path $script:RcData)) { New-Item -ItemType Directory -Path $script:RcData -Force | Out-Null }

$script:RcRanks = @(
    'Null Pointer', 'Script Kiddie', 'Tab Masher', 'Code Monkey', 'Bug Hunter',
    'Stack Overflower', 'Refactor Wizard', 'Regex Sorcerer', 'Kernel Hacker',
    '10x Developer', 'Keyboard Warlord', 'Compiler Whisperer', 'Segfault Slayer',
    'Merge Conflict Conqueror', 'CODEGOD'
)

function Get-RcConfig {
    $cfg = @{
        enabled = $true; sounds = $true; visuals = $true; typingSounds = $false
        unicode = $true; comboWindowSeconds = 10; ccSounds = $true
    }
    foreach ($f in @($script:RcCfgDef, $script:RcCfgUser)) {
        if (Test-Path $f) {
            try {
                $j = Get-Content $f -Raw | ConvertFrom-Json
                foreach ($p in $j.PSObject.Properties) { $cfg[$p.Name] = $p.Value }
            } catch {}
        }
    }
    return $cfg
}

function New-RcSession {
    return [pscustomobject]@{ cmds = 0; edits = 0; tools = 0; errors = 0; prompts = 0; maxCombo = 0; startXp = 0; startTicks = (Get-Date).Ticks }
}

# Reset the session block AND stamp its starting XP so the summary card can
# report XP gained / best combo for just this shell or Claude Code session.
function Reset-RcSession {
    param($State)
    $s = New-RcSession
    $s.startXp = [int]$State.xp
    $State.session = $s
    return $State
}

function New-RcState {
    return [pscustomobject]@{ xp = 0; combo = 0; maxCombo = 0; lastTicks = 0; session = (New-RcSession) }
}

function Get-RcState {
    $st = $null
    if (Test-Path $script:RcStateF) {
        try { $st = Get-Content $script:RcStateF -Raw | ConvertFrom-Json } catch {}
    }
    if ($null -eq $st) { $st = New-RcState }
    foreach ($k in 'xp', 'combo', 'maxCombo', 'lastTicks') {
        if ($null -eq $st.PSObject.Properties[$k]) { $st | Add-Member NoteProperty $k 0 }
    }
    if ($null -eq $st.PSObject.Properties['session'] -or $null -eq $st.session) {
        $st | Add-Member NoteProperty session (New-RcSession) -Force
    }
    foreach ($sk in 'cmds', 'edits', 'tools', 'errors', 'prompts', 'maxCombo', 'startXp', 'startTicks') {
        if ($null -eq $st.session.PSObject.Properties[$sk]) { $st.session | Add-Member NoteProperty $sk 0 }
    }
    return $st
}

function Save-RcState {
    param($State)
    try { ($State | ConvertTo-Json -Depth 6) | Set-Content -Path $script:RcStateF -Encoding UTF8 } catch {}
}

function Get-RcLevel {
    param([int]$Xp)
    if ($Xp -lt 0) { $Xp = 0 }
    return [int]([math]::Floor([math]::Sqrt($Xp / 80.0))) + 1
}

function Get-RcXpForLevel {
    param([int]$Level)
    if ($Level -lt 1) { $Level = 1 }
    return [int](80.0 * ($Level - 1) * ($Level - 1))
}

function Get-RcRank {
    param([int]$Level)
    $i = $Level - 1
    if ($i -lt 0) { $i = 0 }
    if ($i -ge $script:RcRanks.Count) { $i = $script:RcRanks.Count - 1 }
    return $script:RcRanks[$i]
}

function Add-RcXp {
    param([int]$Amount, [string]$Kind = 'cmd', [switch]$Failed)
    $st  = Get-RcState
    $cfg = Get-RcConfig
    $now = (Get-Date).Ticks
    $elapsed = 999.0
    if ([long]$st.lastTicks -gt 0) { $elapsed = ($now - [long]$st.lastTicks) / 1e7 }

    if ($Failed) {
        $st.combo = 0
    } else {
        if ($elapsed -le [double]$cfg.comboWindowSeconds) { $st.combo = [int]$st.combo + 1 } else { $st.combo = 1 }
        if ([int]$st.combo -gt [int]$st.maxCombo) { $st.maxCombo = [int]$st.combo }
        if ($null -eq $st.session.PSObject.Properties['maxCombo']) { $st.session | Add-Member NoteProperty maxCombo 0 -Force }
        if ([int]$st.combo -gt [int]$st.session.maxCombo) { $st.session.maxCombo = [int]$st.combo }
    }

    $mult = [math]::Max(1, [int]$st.combo)
    $gain = 0
    if (-not $Failed) { $gain = [int]($Amount * $mult) }

    $oldXp    = [int]$st.xp
    $oldLevel = Get-RcLevel $oldXp
    $st.xp    = $oldXp + $gain
    $newLevel = Get-RcLevel ([int]$st.xp)
    $st.lastTicks = $now

    switch ($Kind) {
        'edit'   { $st.session.edits = [int]$st.session.edits + 1; $st.session.tools = [int]$st.session.tools + 1 }
        'tool'   { $st.session.tools = [int]$st.session.tools + 1 }
        'cmd'    { $st.session.cmds  = [int]$st.session.cmds + 1 }
        'prompt' { $st.session.prompts = [int]$st.session.prompts + 1 }
    }
    if ($Failed) { $st.session.errors = [int]$st.session.errors + 1 }

    Save-RcState $st
    return [pscustomobject]@{
        combo = [int]$st.combo; gain = $gain; xp = [int]$st.xp
        level = $newLevel; oldLevel = $oldLevel; leveledUp = ($newLevel -gt $oldLevel)
        rank = (Get-RcRank $newLevel); failed = [bool]$Failed; state = $st
    }
}

function Play-RcSound {
    param([string]$Name, [switch]$Sync)
    $cfg = Get-RcConfig
    if (-not $cfg.sounds) { return }
    $p = Join-Path $script:RcAssets ($Name + '.wav')
    if (-not (Test-Path $p)) { return }
    try {
        if ($Sync) {
            $sp = New-Object System.Media.SoundPlayer $p
            $sp.PlaySync(); $sp.Dispose()
        } else {
            if ($null -eq $script:RcPlayers) { $script:RcPlayers = @{} }
            if ($null -eq $script:RcPlayers[$Name]) {
                $pl = New-Object System.Media.SoundPlayer $p; $pl.Load()
                $script:RcPlayers[$Name] = $pl
            }
            $script:RcPlayers[$Name].Play()
        }
    } catch {}
}
