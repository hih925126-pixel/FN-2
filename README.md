# Flux — Fortnite performance & tuning

A zero-dependency Windows desktop app that applies the Fortnite performance tweaks you select, one tweak or one section at a time.

## Requirements

- Windows 11, Build 26300 or newer (tested there).
- Administrator rights for Apply / Restore. Flux asks for elevation if needed.
- Nothing else. It uses only Windows features and the system PowerShell (5.1) + WPF.

## Run it

- Double-click **Flux.exe**, or
- Double-click **Launch Flux.cmd** (located next to `Flux.ps1`).

Flux keeps one instance open. Cancel during elevation if you do not want changes yet.

## What it does

- **11 sections of tweaks**, all reversible. Open each tweak for an explanation of the change and its risk level.
- **Per-tweak backup**: the previous value is saved for every change Flux makes, and Revert / Revert All restores them.
- **Restore points**: Flux also creates a Windows restore point before any Apply that asks for one; System Protection changes won't create restore points, and Windows/OS updates may supersede tweaks.
- **Fortnite High priority + all cores** when the Processes guard is on. It automatically reopens background apps that Flux closed while the game ran.
- **Crosshair overlay** (F6) with a Studio to change style, size, color, opacity and presets. Needs a borderless or windowed-fullscreen mode.
- **GPU / network / power**: automated where the OS allows, guided elsewhere.

## Guided-only items

Flux explains and opens the control panel for these, but does not automate them:

- NVIDIA/AMD driver performance recommendations (or use those apps/drivers directly).
- Wallpaper slideshow mode.
- Some WMI/CIM or third-party dependency notes may show as guidance.

## Data and safety

- `%APPDATA%\Flux\backup.json` — Flux's per-tweak backups and scheduled task/registry/service/DNS records.
- `%APPDATA%\Flux\restore-apps.json` — background apps waiting to reopen when Fortnite exits.
- `%APPDATA%\Flux\agent.pid` and `%APPDATA%\Flux\agent-status.json` — Processes guard status.
- `%APPDATA%\Flux\logs\` — logs, including `flux-*.log`, `agent-*.log`, and `launch-*.log`.

Anything you do in another program — System Settings, DISPLAY settings, NVIDIA app, drivers, Windows App Control, other apps — stays yours and can be reverted by Windows or by the app itself.

## Known limitations

- No third-party libraries; running on Windows PowerShell 5.1.
- Driver tuning (NVIDIA, AMD) is manual by design.
- Developer wants: automation in lab/code labs is not guaranteed — e.g. updates or protections can win over Flux.
- Deleting recent temps or RAM is done by Flux, but the memory comes back naturally.

## License

None included. Fork and adapt the PowerShell sources if that fits you.
