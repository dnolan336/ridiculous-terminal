# uninstall.ps1
# Removes the profile auto-load and the Claude Code hooks. Leaves the project
# folder and your career stats intact unless you pass -Purge.
param([switch]$Purge)

$ErrorActionPreference = 'Stop'
$marker0 = '# >>> Ridiculous Coding >>>'
$marker1 = '# <<< Ridiculous Coding <<<'

# 1) profile
if (Test-Path $PROFILE) {
    $txt = Get-Content $PROFILE -Raw
    $pattern = '\r?\n?' + [regex]::Escape($marker0) + '.*?' + [regex]::Escape($marker1) + '\r?\n?'
    $txt = [regex]::Replace($txt, $pattern, '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    Set-Content -Path $PROFILE -Value $txt -Encoding UTF8
    Write-Host "Removed auto-load from $PROFILE"
}

# 2) Claude Code hooks
$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($settings.PSObject.Properties['hooks']) {
            foreach ($n in 'SessionStart', 'UserPromptSubmit', 'PostToolUse', 'Notification', 'SubagentStop', 'Stop') {
                if ($settings.hooks.PSObject.Properties[$n]) { $settings.hooks.PSObject.Properties.Remove($n) }
            }
            if (@($settings.hooks.PSObject.Properties).Count -eq 0) { $settings.PSObject.Properties.Remove('hooks') }
        }
        ($settings | ConvertTo-Json -Depth 12) | Set-Content -Path $settingsPath -Encoding UTF8
        Write-Host "Removed Claude Code hooks from $settingsPath"
    } catch { Write-Host "Could not edit $settingsPath ($_)" }
}

# 3) optional purge of saved progress
if ($Purge) {
    $data = Join-Path $env:LOCALAPPDATA 'RidiculousCoding'
    if (Test-Path $data) { Remove-Item $data -Recurse -Force; Write-Host "Purged saved progress in $data" }
}

Write-Host "Uninstalled. Restart your shell to drop the custom prompt."
