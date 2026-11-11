# Development workflow

The Git root is the existing Sunder folder. The installable package is `addon/Sunder/`, with `Sunder.toc` directly inside it. Do not move the repository itself into AddOns.

Use Python 3.11+ and the pinned development requirements. The local `.venv` is already prepared on this machine. Windows commands are in the root README; macOS/Linux use `.venv/bin/python`.

## Change → check → deploy → observe

1. Create a task branch from the intended base and inspect existing changes.
2. Edit production code under `addon/Sunder/`, with focused regressions under `tests/`.
3. Run `python tools/sunder.py test`. It checks all shipping Lua under Lua 5.1, manifest/XML resources, assets and the behavior suites. The runner supplies `SUNDER_ADDON_ROOT` and isolates historical fixture paths under `tests/regression/`.
4. Run `python tools/sunder.py deploy --dry-run` to verify the destination. Run `deploy` to install the checked source and migration loader, backing up existing folders before replacement. No test or deployment command reads or rewrites account SavedVariables.
5. Restart WoW for the initial folder rebrand. Later Lua-only changes can use `/reload`. New textures or changed client discovery may require a restart.
6. Observe the actual behavior in-game and record what passed. Do not confuse native-client tests with the mocked regression suite.

## Recovery

`python tools/sunder.py rollback` restores the most recent recorded addon-folder backup. `rollback --backup ".local/backups/<id>"` selects another. This does not roll back saved settings/messages. Keep backups private. A failed deployment automatically restores the affected addon folders.

`python tools/sunder.py package` creates deterministic ZIPs and SHA-256 file hashes under ignored `dist/`. CI tests and builds the same artifacts. Publishing is a separate deliberate step.

## Historical fixtures

The regression suite was ported from the prior development workspace. Numeric suffixes identify feature milestones; tests run against this repository's current code, not historical installed files. Tests must not mutate production code. Native Blizzard UI source fixtures are included only for behavioral compatibility tests, not shipped in the addon ZIP.
