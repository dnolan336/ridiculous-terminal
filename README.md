# Ridiculous Terminal — arcade effects for Claude Code & PowerShell

Turns your terminal into an arcade. Inspired by the **Ridiculous Coding** VS Code
extension (itself a port of jotson's Godot plugin): explosions, flying particles,
combo counters, XP, level-ups, and 8-bit sound effects — but driven by your
**Claude Code** sessions and your **PowerShell** commands instead of editor keystrokes.

Pure native Windows PowerShell. No Node, Python, or downloads. The sound effects are
synthesized procedurally at install time (square-wave blips, noise-burst explosions,
rising combo arpeggios).

## What you get

**In PowerShell (full visuals + sound):**
- A pixel explosion + arcade sound after every command you run
- A live HUD prompt: `LV.4 Bug Hunter ████░░░░ 1240 XP  🔥x5  ⚔ 37  💥 2`
- Combo multiplier that climbs while you keep typing commands quickly, resets on errors
- Persistent XP and rank that level up over your whole career (Null Pointer → … → CODEGOD)

**In Claude Code (sound + scoring — see note):**
- Sounds fire on Claude's events: prompt submitted, each tool run, file edits (boom!),
  errors (buzz), and turn complete (victory jingle)
- XP/combo accrue during the session, so when you drop back to your PowerShell prompt
  the HUD reflects the epic session you just had

> **Why no animations *inside* Claude Code?** Claude Code paints a live full-screen TUI,
> so a background hook can't reliably draw particles over it without corrupting the view.
> Sound + scoring work great there; the fireworks play at your normal PowerShell prompt.

## Requirements

- Windows with **Windows PowerShell 5.1** (or PowerShell 7)
- **Windows Terminal** strongly recommended (for ANSI colour + emoji)
- Optional: **Claude Code** (for the in-session sound effects)

## Install

```powershell
git clone https://github.com/dnolan336/ridiculous-terminal.git
cd ridiculous-terminal
.\install.ps1
```

(Or download the ZIP, extract it anywhere, and run `.\install.ps1` from that folder.)

> **"running scripts is disabled on this system"?** Windows blocks PowerShell
> scripts by default. Fix it once (no admin needed), then re-run the installer:
>
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

Then open a **new** PowerShell window (or run `. $PROFILE`). Try `rt test`.

The installer:
1. generates the sound assets into `assets\`
2. adds an auto-load block to your `$PROFILE`
3. wires Claude Code hooks into `~/.claude/settings.json` (a backup is saved as
   `settings.json.rcbak`). Use `.\install.ps1 -NoClaude` to skip this.

## Commands

The command is **`rt`** (and **`rc`** also works, for muscle memory):

| Command      | Effect                                            |
|--------------|---------------------------------------------------|
| `rt`         | show help                                         |
| `rt start` / `stop` | enable / disable (`stop` also prints a session report) |
| `rt stats`   | your level / XP / best combo                      |
| `rt summary` | show the session report card                      |
| `rt test`    | preview every sound + an explosion                |
| `rt mute` / `unmute` | silence / restore sounds                  |
| `rt quiet` / `loud`  | hide / restore visuals                    |
| `rt typing`  | toggle per-keystroke typing sounds (off by default) |
| `rt reset`   | wipe progress back to Level 1                     |
| `rt config`  | show current settings                             |

## Configuration

Defaults live in `config.json`; per-user overrides are written to
`%LOCALAPPDATA%\RidiculousCoding\config.json` by the `rt` commands. Keys:

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `true` | master switch |
| `sounds` | `true` | play sound effects |
| `visuals` | `true` | prompt explosions / HUD |
| `typingSounds` | `false` | tick on every keystroke (PowerShell only) |
| `unicode` | `true` | emoji + box glyphs (set false for plain ASCII) |
| `comboWindowSeconds` | `10` | keep your combo alive if you act within N seconds |
| `ccSounds` | `true` | play sounds for Claude Code hook events |

## A note on latency in Claude Code

Each Claude Code hook launches a short PowerShell process that plays a (short) sound
synchronously, adding a fraction of a second per event. If heavy tool use feels sluggish,
set `ccSounds` to `false` (or trim which events fire in `~/.claude/settings.json`).

## Uninstall

```powershell
.\uninstall.ps1          # remove profile hook + Claude hooks, keep your stats
.\uninstall.ps1 -Purge   # also wipe saved XP/progress
```

## Files

| File | Role |
|------|------|
| `RcCore.ps1` | shared state, scoring, sound (dot-sourced by both sides) |
| `RidiculousCoding.psm1` | interactive prompt HUD, explosions, `rt` command |
| `cc-hook.ps1` | Claude Code hook entry point |
| `Generate-Assets.ps1` | procedural 8-bit WAV synthesizer |
| `install.ps1` / `uninstall.ps1` | setup / teardown |
| `config.json` | default settings |

> Note: `assets\*.wav` are **generated** by `install.ps1` (or `Generate-Assets.ps1`),
> so they aren't checked into the repo.

## Credits

Inspired by the **Ridiculous Coding** VS Code extension, itself a port of
**jotson's** original Godot editor plugin
([github.com/jotson/ridiculous_coding](https://github.com/jotson/ridiculous_coding)).
This project is an independent reimplementation for the Windows terminal and
Claude Code — no original code or assets are used; all sounds are synthesized
from scratch.

## License

[MIT](LICENSE) — do whatever you like, no warranty.
