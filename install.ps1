# install.ps1
# One-shot installer for Ridiculous Terminal.
#   * generates the sound assets
#   * adds the module import to your PowerShell profile (auto-loads every shell)
#   * wires Claude Code hooks into ~/.claude/settings.json
param([switch]$NoClaude)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Write-Host "Installing Ridiculous Terminal from $root" -ForegroundColor Cyan

# 1) sound assets ------------------------------------------------------------
if (-not (Test-Path (Join-Path $root 'assets\boot.wav'))) {
    Write-Host "  - generating sound assets..."
    & (Join-Path $root 'Generate-Assets.ps1') | Out-Null
} else {
    Write-Host "  - sound assets already present (skip; run Generate-Assets.ps1 to rebuild)"
}

# 2) PowerShell profile ------------------------------------------------------
$marker0 = '# >>> Ridiculous Coding >>>'
$marker1 = '# <<< Ridiculous Coding <<<'
$block = @"
$marker0
Import-Module '$root\RidiculousCoding.psm1' -ErrorAction SilentlyContinue
if (Get-Command Enable-RidiculousCoding -ErrorAction SilentlyContinue) { Enable-RidiculousCoding }
$marker1
"@

$profilePath = $PROFILE
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

$existing = ''
if (Test-Path $profilePath) { $existing = Get-Content $profilePath -Raw }
if ($existing -match [regex]::Escape($marker0)) {
    # replace the existing block (idempotent re-install / path change)
    $pattern = [regex]::Escape($marker0) + '.*?' + [regex]::Escape($marker1)
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $block }
    $updated = [regex]::Replace($existing, $pattern, $evaluator, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    Set-Content -Path $profilePath -Value $updated -Encoding UTF8
    Write-Host "  - updated profile block in $profilePath"
} else {
    Add-Content -Path $profilePath -Value "`r`n$block`r`n" -Encoding UTF8
    Write-Host "  - added auto-load to $profilePath"
}

# 3) Claude Code hooks -------------------------------------------------------
if (-not $NoClaude) {
    $settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
    $claudeDir = Split-Path $settingsPath -Parent
    if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }

    # Recursively turn a ConvertFrom-Json PSCustomObject graph into hashtables/arrays.
    function ConvertTo-HashtableDeep { param($Obj)
        if ($Obj -is [System.Management.Automation.PSCustomObject]) {
            $h = [ordered]@{}
            foreach ($p in $Obj.PSObject.Properties) { $h[$p.Name] = ConvertTo-HashtableDeep $p.Value }
            return $h
        } elseif ($Obj -is [System.Collections.IEnumerable] -and $Obj -isnot [string]) {
            $a = @(); foreach ($i in $Obj) { $a += , (ConvertTo-HashtableDeep $i) }
            return , $a
        } else { return $Obj }
    }

    $settingsH = [ordered]@{}
    if (Test-Path $settingsPath) {
        # keep the first (clean) backup; don't overwrite it on re-install
        if (-not (Test-Path "$settingsPath.rcbak")) { Copy-Item $settingsPath "$settingsPath.rcbak" -Force }
        try { $settingsH = ConvertTo-HashtableDeep (Get-Content $settingsPath -Raw | ConvertFrom-Json) } catch { $settingsH = [ordered]@{} }
    }
    if ($settingsH.Contains('hooks')) { $settingsH.Remove('hooks') }

    $exe = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$root\cc-hook.ps1`""
    function New-HookGroup { param([string]$EventName, [bool]$WithMatcher)
        $h = @{ type = 'command'; command = "$exe $EventName" }
        if ($WithMatcher) { return , @(@{ matcher = ''; hooks = @($h) }) }
        else { return , @(@{ hooks = @($h) }) }
    }

    $hooksH = [ordered]@{}
    $hooksH['SessionStart']     = (New-HookGroup 'SessionStart'     $false)
    $hooksH['UserPromptSubmit'] = (New-HookGroup 'UserPromptSubmit' $false)
    $hooksH['PostToolUse']      = (New-HookGroup 'PostToolUse'      $true)
    $hooksH['Notification']     = (New-HookGroup 'Notification'     $false)
    $hooksH['SubagentStop']     = (New-HookGroup 'SubagentStop'     $false)
    $hooksH['Stop']             = (New-HookGroup 'Stop'             $false)
    $settingsH['hooks'] = $hooksH

    # JavaScriptSerializer preserves single-element arrays (ConvertTo-Json does not).
    Add-Type -AssemblyName System.Web.Extensions
    $js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $out = $js.Serialize($settingsH)
    try { $null = $out | ConvertFrom-Json } catch { throw "Generated settings JSON failed validation; aborting. Backup is at $settingsPath.rcbak" }
    Set-Content -Path $settingsPath -Value $out -Encoding UTF8
    Write-Host "  - wired Claude Code hooks into $settingsPath (backup: settings.json.rcbak)"
} else {
    Write-Host "  - skipped Claude Code hooks (-NoClaude)"
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host "Open a NEW PowerShell window (or run: . `$PROFILE) to start the chaos."
Write-Host "Try 'rt test' to preview the effects, or 'rt' for all commands."
