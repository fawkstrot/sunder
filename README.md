# Sunder

Ancient craft. Modern utility.

Sunder is a modular World of Warcraft addon focused on clear messaging today and optional quality-of-life tools as it grows. It combines smooth chat, unified Whispers, saved conversations, notifications and per-copy item protection. EllesmereUI styling and Edit UI integration are optional.

![Sunder emblem](assets/branding/Sunder-project-icon.png)

## Repository layout

| Path | Purpose |
| --- | --- |
| `addon/Sunder/` | Installable addon; production source |
| `compat/ROTBOTForever/` | Data-only upgrade loader |
| `assets/branding/` | Emblem master and project icon |
| `tools/` | Checks, tests, packaging and backed-up deployment |
| `tests/` | Lua 5.1 regressions and migration checks |
| `docs/` | Architecture, branding, migration and release guides |

Start with [AGENTS.md](AGENTS.md) for agent work and [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for local setup.

## Local development

```powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
.venv/Scripts/python.exe tools/sunder.py test
.venv/Scripts/python.exe tools/sunder.py deploy --dry-run
.venv/Scripts/python.exe tools/sunder.py deploy
```

Deployment defaults to `C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns`. Override with `--addons ".../Interface/AddOns"`. Edit repository files, not installed copies. Every deployment backs up both addon folders under ignored `.local/backups/` and verifies installed hashes. SavedVariables are untouched. Use `rollback` to restore the last folder backup.

## Install and commands

A clean install uses the `Sunder/` folder from the normal release ZIP. Existing installations should use the manual upgrade bundle once; it also replaces the old addon with a data-only loader. Keep the loader enabled through the first Sunder login and logout, then it may be disabled. Restart the client for the new folder; later Lua edits can use `/reload`.

- `/sunder`: settings; `/sun` when that alias is available.
- `/sunder whispers`, `/sunder appearance`, `/sunder items`: feature settings.
- `/sunder messages`: open Whispers; `/sunder favorites`: its Favorites filter.
- `/sunder lock`: standalone layout editing; Ellesmere Edit UI is also supported.
- Previous slash commands and saved item-lock bindings remain compatible.

See [migration](docs/MIGRATION.md), [releases](docs/RELEASING.md), and [CurseForge setup](docs/CURSEFORGE.md). The current development target is WoW Forever; other WoW clients still need direct validation.

## License and provenance

MIT; retain bundled notices. Chat began as Glassy/Glass. Original contributors and library licenses are preserved in the addon. See [LICENSE](LICENSE) and `addon/Sunder/UPSTREAM_README.md`.
