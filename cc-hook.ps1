# cc-hook.ps1  <Event>
# Claude Code hook entry point. Reads the event JSON on stdin, awards XP and
# plays a sound. Stays SILENT on stdout so nothing is injected into Claude's
# context. Always exits 0 so it can never block a tool call.
param([string]$Event = 'Unknown')

$ErrorActionPreference = 'SilentlyContinue'
try {
    . (Join-Path $PSScriptRoot 'RcCore.ps1')
    $cfg = Get-RcConfig
    if (-not $cfg.enabled -or -not $cfg.ccSounds) { exit 0 }

    $raw = ''
    if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }
    $data = $null
    if ($raw) { try { $data = $raw | ConvertFrom-Json } catch {} }

    $tool = ''
    if ($data -and $data.PSObject.Properties['tool_name']) { $tool = [string]$data.tool_name }

    $isErr = $false
    if ($data -and $data.PSObject.Properties['tool_response'] -and $data.tool_response) {
        $tr = $data.tool_response
        if ($tr -is [string]) { if ($tr -match '(?i)error|fail') { $isErr = $true } }
        elseif ($tr.PSObject.Properties['is_error'] -and $tr.is_error) { $isErr = $true }
        elseif ($tr.PSObject.Properties['error'] -and $tr.error) { $isErr = $true }
    }

    switch ($Event) {
        'SessionStart'     { $st = Reset-RcSession (Get-RcState); Save-RcState $st; Play-RcSound 'boot' -Sync }
        'UserPromptSubmit' { Add-RcXp -Amount 12 -Kind 'prompt' | Out-Null; Play-RcSound 'blip' -Sync }
        'PostToolUse'      {
            if ($isErr) { Add-RcXp -Amount 6 -Kind 'tool' -Failed | Out-Null; Play-RcSound 'error' -Sync }
            elseif ($tool -match '^(Edit|Write|MultiEdit|NotebookEdit)$') { Add-RcXp -Amount 20 -Kind 'edit' | Out-Null; Play-RcSound 'explosion' -Sync }
            else { Add-RcXp -Amount 8 -Kind 'tool' | Out-Null; Play-RcSound 'type' -Sync }
        }
        'Notification'     { Play-RcSound 'blip2' -Sync }
        'SubagentStop'     { Play-RcSound 'combo' -Sync }
        'Stop'             { Add-RcXp -Amount 25 -Kind 'tool' | Out-Null; Play-RcSound 'complete' -Sync }
        default            { }
    }
} catch {}
exit 0
