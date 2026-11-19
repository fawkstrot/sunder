# Fishing

Sunder Fishing is an independent feature under `/sunder fish options`, available through standalone and Ellesmere settings. Source: `addon/Sunder/Sunder/Modules/Fishing.lua`. Disable Better Fishing and reload before testing; Sunder refuses to claim the key while that addon is loaded. No third-party addon is disabled automatically.

## Controls and saved settings

- `/sunder fish` or `/sunder fish toggle`: toggle the session's requested mode.
- `/sunder fish on` / `off`: explicit, repeatable mode commands.
- `/sunder fish key SPACE`: choose the temporary key (also configurable in settings).
- `/sunder fish auto on` / `auto off`: follow the main-hand fishing-pole subclass.
- `/sunder fish status`: report automatic detection, current mode, combat suspension or missing capability.
- `/sunder fish equipment`: open Equipment Manager when supported.
- `/sunder fish macro`: create/update the generated character macro.

AceDB stores `fishing = {key = "SPACE", autoPole = false, autoLoot = true}` in the active SunderDB profile. Mode itself is session-only. With pole detection enabled, login/equipment changes follow the actual main-hand item, regardless of its name, quality or upgrades. Unknown item metadata waits for an item-data event. Profile changes clear manual mode and reevaluate the new profile's pole option. Enter/Escape and primary mouse buttons are reserved.

Press the chosen key once to cast, wait for the splash, then press again to interact. The fishing channel is a proxy for an active bobber, not a bite detector. There is no automatic cast, bite detection, repeated interaction or background fishing loop. While channeling, the key invokes native `INTERACTTARGET`; native soft-target choice/range applies, so keep the bobber in view and avoid competing interactable objects.

Auto-loot is enabled by default **only while Fishing Mode is requested**, only outside combat, and only for loot flagged by the client as fishing loot. The `LOOT_READY` handler collects slots before the normal loot window opens, following the installed Better Fishing approach. It does not change global auto-loot settings, confirm binding dialogs, discard items, or collect ordinary combat/chest loot. Full bags/native confirmations may still expose a window. Turning this option off leaves native loot behavior intact. Actual no-window behavior requires client testing.

## Equipment-set setup

Open `/sunder fish options` and choose **Fishing equipment set** and **Normal equipment set** from your existing WoW sets. Then click **Create / update Sunder Fish macro** (or run `/sunder fish macro`). Open `/macro` and drag **Sunder Fish** from character macros to your action bar. Give it a different key from the temporary fishing cast/retrieve key.

If you need sets, click **Open Equipment Manager**. Equip your pole and save a Fishing set; equip normal weapons and save a Normal set. Include the main-hand slot in both. Ignore other slots if you only want weapons swapped, or retain them for full fishing outfits. The native manager remains responsible for creating/saving sets and selecting their gear; Sunder never silently changes them. Update the corresponding set after upgrades. No individual weapon/pole names or captured item payloads are baked into the generated macro.

Selections are stored by stable set ID per character (`db.char.fishingGear.fishingSet` and `normalSet`), independent of the settings profile. Current names are resolved when writing the native `/equipset` line. Set renames, changed contents and equipment-swap events refresh the owned macro on the next frame, outside combat. Two distinct sets are required; where item APIs are available, Fishing must include a pole and Normal a non-pole main hand, with neither ignoring that slot. Deleted selections stay visibly missing until you choose a replacement; Sunder never guesses a replacement by name. Macro parser delimiters and overlong names are rejected with instructions to rename.

The macro equips the Fishing set when no pole is out, and the Normal set when a pole is equipped. Its final `/sunder fish auto on` command enables equipment following. Mode uses actual equipped state, not an assumed successful swap; native inventory-space, item-lock and equipment restrictions remain in force. The separate fishing key (default SPACE) casts/retrieves. Permanent keybindings are unchanged.

`/sunder fish auto on` does not equip a pole. Without one equipped, mode correctly stays off and the reply says to equip a pole. The user confirmed that this explained the initial off report; there was no demonstrated detection failure.

`FishingMacro.lua` generates native `/stopmacro [combat]` and `/equipset` commands. Equipment events never equip anything. A queued next-frame refresh ensures the current macro finishes before its next destination is updated. Setup uses the [Forever EquipmentSet API](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated/EquipmentManagerDocumentation.lua), [native equipment-set command](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua), and capability-checked [Forever PaperDoll manager](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua). Unsupported clients show guidance and retain manual Fishing Mode.

Sunder manages the macro named **Sunder Fish** by name. It updates that macro in place even if its contents were edited, as requested by the user. A character macro takes precedence; if absent, an account-wide copy is reused. If neither exists, Sunder creates a character macro, including during a configured automatic refresh. Other macro names are untouched. Keeping the existing macro index preserves its action-bar references. Missing/invalid sets replace its stale swap command with `/sunder fish options` until setup is repaired. Full storage, native save errors and combat restrictions still apply. The previous captured-gear macro is replaced in place; no stored-body match is required. Legacy captures remain unused.

Native set execution, Equipment Manager opening, action-bar continuity and dropdown appearance remain a user-run validation step. Automated checks cannot establish client UI/protected behavior.

## Equipment macros

Recommended for an existing gear-swap macro: run `/sunder fish auto on` once. Keep the existing macro; Sunder follows successful main-hand changes without needing a toggle line. This avoids mode drift if a gear swap fails. It detects any fishing pole by item class/subclass, not an item name. Sunder does not rewrite existing user macros or choose gear automatically.

Where the client provides Equipment Manager, save sets named `Fishing` and `Combat`, and update those sets when upgrading gear. The same macro can then remain unchanged:

```text
#showtooltip
/stopmacro [combat]
/equipset [equipped:Fishing Poles] Combat; Fishing
```

For explicit slash-command pairing, turn automatic pole detection off and start with combat weapons equipped and Fishing Mode off:

```text
#showtooltip
/stopmacro [combat]
/sunder fish toggle
/equipset [equipped:Fishing Poles] Combat; Fishing
```

The toggle goes before equipment changes. A failed equipment swap can leave this manual toggle out of sync; `/sunder fish off` recovers. Do not bind the gear macro to the key Fishing Mode temporarily takes over. `/equipset` availability and the localized `Fishing Poles` macro conditional depend on the client. An existing `/equip` or `/equipslot` macro works with automatic pole detection too; update its item references when upgrading gear. Updating an equipment set is preferable to baking item names into Sunder.

## API and combat design

The dedicated `SunderFishingFrame` owns temporary overrides; `SunderFishingButton` is a secure spell button. Out of combat, `SetOverrideBindingClick` selects casting and `SetOverrideBinding(..., "INTERACTTARGET")` selects interaction. `ClearOverrideBindings` releases that owner only. No `SetBinding`, `SaveBindings`, or writes to bindings-cache.wtf are used. Existing bindings, including a user's non-Jump SPACE action, remain intact underneath.

**Ordinary Lua cannot clear protected bindings from PLAYER_REGEN_DISABLED after lockdown starts.** Instead, an out-of-combat-installed `SecureHandlerStateTemplate` driver uses `[combat]` and restricted `self:ClearBindings()` on that same owner. This is supported by the [Forever exported restricted-frame implementation](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua). The insecure combat event only updates status. Configuration, secure attributes and normal override mutations defer until combat ends; the latest requested mode then resumes. There is no unbounded deferred-task queue. Module disable during combat retains one regeneration cleanup listener.

The [Forever secure action implementation](https://github.com/reckhou/WoWBlzCode/blob/main/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua) supports `useOnKeyDown`; Sunder registers both key edges and uses the native preference to execute one spell action. Physical key delivery and the combat state driver still require native validation.

Reference inspected: installed Better Fishing, including its Forever branch, channel detection, numeric pole subclass, `INTERACTTARGET`, `LOOT_READY` and temporary interaction CVars. Sunder independently implements the subset, without copying its double-click, sound/nameplate modifications or mouselook hooks. During the channel it temporarily sets SoftTargetInteract=3, SoftTargetInteractArc=2 and SoftTargetInteractRange=60; previous values are restored on channel end/mode exit (after combat if needed), unless subsequently changed by another owner. Icon CVars are left alone.

Modern Classic Era/Wrath-derived clients and original 3.3.5 clients are not interchangeable. `INTERACTTARGET` alone does not guarantee bobber interaction on a client without soft targeting. Sunder capability-checks the needed CVars/secure APIs and declines to take the key if absent; it does not invent a protected mouseover fallback. Forever is the development target; other clients are unverified. Auto-loot safely does nothing if `IsFishingLoot` is unavailable.

## Validation

The CLI's `work/test_fishing.py` exercises the production module: cast/channel/stop transitions, unrelated channels, exact-owner secure combat snippet, combat key/mode deferral, original binding preservation, changed keys, invalid/reserved keys, pole changes and missing metadata, profile/reset/disable/logout cleanup, interaction CVar restoration, conflicting Better Fishing, missing capabilities/skill, fishing-only auto-loot and exclusions. Equipment-set fixtures cover ID zero and stable selections, role/ignored-slot validation, upgrades, renames/deletion/replacement, safe stale-macro retirement, old-owned-macro conversion, parser/length limits, named-macro replacement, account/character precedence, missing-macro creation, unrelated-name preservation, capacity/save failures, deferred refresh, combat and native manager entry. Executing a snippet in a fixture is not native protected-execution proof.

Native checklist after disabling Better Fishing and reloading:

1. Enable Fishing Mode; SPACE casts once, then reels only on the next press after splash. Test key-down and key-up preferences.
2. Catch a fish: auto-loot without the loot window; verify ordinary loot is unchanged and full bags follow native rules.
3. Disable mode: original SPACE action returns. Change the fishing key; verify the old key is released and no permanent binding changes.
4. Equip/unequip two different fishing poles with auto mode; verify an existing weapon macro still works. Keep automatic mode and manual toggle macros separate.
5. Enter combat during both cast-ready and channel states: original binding returns, no blocked-action error; exit resumes requested mode. Change/off mode during combat and confirm the final request wins.
6. Cancel/timeout a channel, reload, change profiles, and verify CVar/key cleanup. Check settings in standalone and Ellesmere.
7. Choose two existing equipment sets and create/update the macro; exercise both swap directions, failed swaps, set upgrades/renames/deletion, manager opening and replacement of edited Sunder Fish macros and preservation of unrelated macros.

Deployment and actual observations are recorded separately in CONTEXT.md. Do not publish this preview as the already-tagged alpha.3.

## Dynamic macro icon

The generated macro shows the next destination set’s actual main-hand item: the pole when switching to Fishing, and the normal weapon when switching back. Its tooltip uses that item too. Both are derived from the selected set on each existing deferred refresh, so saved gear upgrades follow automatically. Equipment swapping still uses /equipset; the tooltip item ID does not select gear. Missing item artwork falls back to the equipment-set icon, then the fishing icon. Icon-only changes refresh without rewriting unrelated macros; combat changes wait until combat ends. Native action-bar appearance remains a user-run check.
