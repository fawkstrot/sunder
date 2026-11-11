# Saved-data migration

WoW loads SavedVariables from the saved file associated with each addon folder. Declaring a differently named variable in Sunder does not itself load the previous addon's saved file.

The upgrade bundle/local deploy installs two folders:

- `Sunder`: the only executable addon implementation; saves `SunderDB`.
- `ROTBOTForever`: a metadata-only `.toc` declaring `ROTBOTForeverDB`. Optional dependency ordering loads this data before Sunder initializes. There are no Lua files in the loader.

`Sunder/Migration.lua` runs before AceDB initialization. If `SunderDB` is absent, it deep-copies the loaded legacy database in priority order: `ROTBOTForeverDB`, `RunestoneDB`, `GlassyDB`. Runestone was not present in the source being rebranded; its identifier is accepted for compatibility if its data is loaded. An already-installed Glassy migration loader remains optional. The shipped upgrade loader specifically supports the actual prior ROTBOT installation.

The entire account/profile/character tree is copied: profiles and profile keys, saved history and timestamps, contacts/favorites, item GUID records, layouts, visibility, minimap position and other settings. Original data is not modified. Known media/font identifiers are remapped in profiles; conversation text is never rewritten. An existing `SunderDB` always wins, making repeated starts idempotent.

Keep the legacy data loader enabled for the first Sunder login, then log out or reload successfully so WoW writes `Sunder.lua` SavedVariables. Only then disable the loader. Do not delete old saved files as part of normal migration. A fresh install does not need the loader.

If a real old addon is still executing, Sunder disables its own activation and reports how to install the upgrade loader. This prevents duplicate implementations. Local deployment backs up and replaces the old folder with the data-only loader automatically.

`/sunder` is primary. Old `/rotbot`, `/rotbotforever`, `/rb`, `/gl` commands and the `ROTBOT_FOREVER_PROTECT_ITEM` binding are compatibility aliases. New profile exports use `SUNDER1:`; legacy `GLASSY1:`, `ROTBOT1:` and `RUNESTONE1:` input prefixes remain accepted by the bounded data parser.

## Verify in-game

Check the intended profile, a saved conversation and its history, favorite contacts, protected-item records, minimap placement and window positions. Reload and confirm Sunder retains the migrated state without importing over it. Those native write/reload checks remain necessary even when migration unit tests pass.
