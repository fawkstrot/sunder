# Friendly nameplates

Open `/sunder nameplates` or choose Nameplates in Sunder settings (standalone or Ellesmere). Management starts disabled to preserve existing game/nameplate-addon preferences. Enable **Manage friendly nameplates**, then choose Hidden, Names only, or Names and health bars. A separate dungeon/raid display preference can inherit the default. Battlegrounds and arenas use the default; this is not a claim of custom plate access there.

Names and health bars are Blizzard's native presentation, including on restricted dungeon plates. These settings apply to friendly players, not selectively to party members. Visibility otherwise follows the game's existing nameplate range/combat/display rules. Native names and health bars have independent class-color controls, each with Keep game setting. Optional overall size is explicitly global to native friendly and enemy plates, using the client's NamePlateSize enum. Names-only also affects native cast bars and auras; independent cast/aura controls are not shipped.

Changes wait until combat ends and apply the latest location/preferences. Turning management off restores previously captured values only if Sunder still owns them. Original/applied values persist per character across reloads in `nameplateOverrides`; preferences live in the profile. Yielded ownership persists per character in `nameplateYielded` until explicitly reacquired. If the game or another addon changes an owned setting, Sunder yields that setting instead of repeatedly overwriting it. **Apply preferences** explicitly reacquires settings using the current values as their restoration baseline. Do not have multiple addons continuously manage these settings. Before disabling Sunder itself in the AddOns list, turn off nameplate management to restore settings while its code can still run.

`Modules/Nameplates.lua` owns capability checks, CVar leases, event-driven location/combat reconciliation and feature options. No polling, plate acquisition, hooks into forbidden frames, group-management actions, new native slots or chat modifications. Unsupported CVars and rejected writes produce status feedback. Readback verifies CVar writes; it does not prove visual behavior.

## Reference material

Private ignored reference directory: `.local/references/`.

- `wow-ui-source-forever/` contains the complete [Gethe mirror of Blizzard UI source](https://github.com/Gethe/wow-ui-source), Forever commit `3d8abb1da73acd38e412e24fb3f99454a6392346`; `SUNDER_REFERENCE.json` records provenance and archive hash. This is a reference revision, not proof it exactly matches the installed binary.
- `df-friendly-nameplates/v2.10/` contains the original ZIP, extracted reference and provenance for [CurseForge file 8622290](https://www.curseforge.com/wow/addons/df-friendly-nameplates/files/8622290). Retail reference only; Wago's advertised Forever v2.12 was not retrieved because direct access returned 403. All Rights Reserved; no code/assets copied into Sunder.
- Blizzard `NamePlateUnitFrameMixin:UpdateShowOnlyName` forwards the native setting to health/cast/aura components. `NamePlateDriverMixin:UpdateNamePlateOptions` reads friendly bar class colors. Native settings expose friendly name colors and global size. Sunder uses those controls rather than DF's internal table/helper mutation techniques.

## Testing dungeon workflows

UI source is Lua/XML, not the game engine, server or a playable dungeon. It cannot independently reproduce native rendering, secure/forbidden frame enforcement, secret values, combat lockdown or world visibility.

1. **Current Sunder harness:** `tools/sunder.py test` runs `work/test_nameplates.py`. Scripted world → dungeon → raid → world transitions, combat deferral/latest state, external changes, profile reset, reload baseline, unsupported CVars, failed writes and restoration are covered. When the local source is available, the same test extracts and executes Blizzard's actual `UpdateShowOnlyName` with simulated component receivers, proving flag propagation into health/cast components. CI without that private reference explicitly skips this extra source check; portable behavior checks still run.
2. **[Wowless](https://github.com/wowless/wowless):** headless Lua/FrameXML interpreter for addon testing. Useful for broader API/UI integration; exact Forever profile coverage needs validation before adoption. Not installed for this task.
3. **[wow-ui-sim](https://github.com/Osso/wow-ui-sim):** interactive UI simulation with a documented [Forever profile](https://github.com/Osso/wow-ui-sim/blob/master/docs/wowforever-1.60.1.md). Useful for UI exploration and event scenarios. Its documentation explicitly disclaims native conformance; not installed or executed for this task.
4. **Real Forever client:** required acceptance layer. User controls reload/gameplay. Enable nameplates outdoors, enter a real dungeon, switch names/bars, observe health changes, check class colors and enemy size effects, test combat-deferred settings/location transitions, then disable and verify restoration. Repeat with existing nameplate addons active to verify conflict handling. No native dungeon/visual result is claimed from source-based tests.

Custom fonts/outlines, independent bar geometry/textures/percentages, per-person styling and chevrons remain outside this initial native-settings feature. Shared font overrides can affect other plates and multilingual glyphs; forbidden-frame helper tricks in a reference addon do not establish stable Forever support.
